extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")

static func tick(unit,dt:float) -> void:
	var s:=R.state(unit)
	for key in ["afterheat_cd","capacitor_cd","dive_boost","dive_cloak","move_lock"]:R.timer(s,key,dt)
	if R.talent_rank(unit,"mirage_afterheat")>=0:
		if AlliedAbilities.mirage_at_rest(unit) and float(unit.special.get("reveal",0))<=0:
			s.hidden=float(s.get("hidden",0))+dt
			if s.hidden>=P.number("mechanic/talents_legacy","hidden_prepare"):s.heat_armed=true
		else:s.hidden=0.0
	if R.talent_rank(unit,"ground_capacitor")>=0:
		if unit.velocity.length_squared()<1:
			s.rest=float(s.get("rest",0))+dt
			if s.rest>=P.number("mechanic/talents_legacy","capacitor_prepare") and float(s.get("shot_idle",0))>=P.number("mechanic/talents_legacy","capacitor_prepare") and not s.has("capacitor_origin"):s.capacitor_origin=unit.position
		else:s.rest=0.0
		if s.has("capacitor_origin") and unit.position.distance_to(s.capacitor_origin)>=P.number("mechanic/talents_legacy","capacitor_distance")*R.CELL and not s.has("capacitor_cd"):
			var cap={"point":s.capacitor_origin,"left":R.talent(unit,"ground_capacitor","life"),"damage":R.talent(unit,"ground_capacitor","damage")}
			s.capacitor=cap;s.erase("capacitor_origin");s.capacitor_cd=P.number("mechanic/talents_legacy","capacitor_cooldown");R.label(unit,"接地电容")
	if s.has("capacitor"):
		s.capacitor.left-=dt
		if s.capacitor.left<=0:s.erase("capacitor")
		else:
			var victims:Array=[]
			for enemy in R.world(unit).units:
				if R.enemy(unit,enemy) and not enemy.is_air_target() and R.world(unit).actor_visible_to(unit.side,enemy) and enemy.position.distance_to(s.capacitor.point)<=P.number("mechanic/talents_legacy","capacitor_radius")*R.CELL:
					victims.append(enemy)
			if not victims.is_empty():
				var cap:Dictionary=s.capacitor
				s.erase("capacitor")
				for enemy in victims:R.hit(unit,enemy,cap.damage,cap.point)
	if s.has("capacitor") or unit.has_meta(preload("res://scripts/units/ground_capacitor_token.gd").META):
		preload("res://scripts/units/ground_capacitor_token.gd").sync(unit)
	s.shot_idle=float(s.get("shot_idle",0))+dt
	if s.has("tracking"):
		s.tracking.left-=dt
		if s.tracking.left<=0 or not AlliedAbilities.alive(s.tracking.target):s.erase("tracking")
	if unit.unit_id=="BEAG" and unit.logistics.air_state=="parked":
		s.erase("dive_cloak");s.erase("dive_boost")
		if unit.logistics.ammo==unit.logistics.ammo_max:s.erase("dive_used")

static func shot(unit,target,bonus:Dictionary) -> void:
	var s:=R.state(unit)
	s.shot_idle=0.0;s.rest=0.0;s.erase("capacitor_origin");s.shot_origin=unit.position
	if unit.unit_id=="HTK" and unit.logistics.passengers.is_empty():
		bonus.attack_bonus=float(bonus.get("attack_bonus",1))*(1.0+R.talent(unit,"empty_firepower","damage"))
	if s.has("afterburn"):bonus.attack_bonus=float(bonus.get("attack_bonus",1))*(1.0+s.afterburn.damage)
	if R.talent_rank(unit,"third_sonic")>=0:
		s.sonic_count=(int(s.get("sonic_count",0))+1)%P.count("mechanic/talents_legacy","sonic_hits")
		if s.sonic_count==0:bonus.expansion_sonic=R.talent(unit,"third_sonic","damage");R.label(unit,"贯穿声波")
	if R.talent_rank(unit,"dive_momentum")>=0 and R.enemy(unit,target) and not s.get("dive_used",false):
		s.dive_used=true;s.dive_boost=P.number("mechanic/talents_legacy","boost_seconds")
		s.dive_cloak=R.talent(unit,"dive_momentum","cloak")
		R.label(unit,"俯冲余势 · 隐身 %ss"%String.num(s.dive_cloak,2))

static func hit(actor,target,extra:bool) -> void:
	if extra or not R.active(actor) or not (actor is Unit):return
	var s:=R.state(actor)
	if R.talent_rank(actor,"mirage_afterheat")>=0 and s.get("heat_armed",false) and not s.has("afterheat_cd") and int(s.get("heat_charges",0))==0:
		s.heat_charges=P.count("mechanic/talents_legacy","heat_charges");s.afterheat_cd=P.number("mechanic/talents_legacy","heat_cooldown");s.erase("heat_armed");s.hidden=0.0;R.label(actor,"伪装余温 · 3次填弹")
	var ship=actor if actor.unit_id=="DEST" else actor.logistics.carrier_owner
	if AlliedAbilities.alive(ship) and ship.unit_id=="DEST" and R.talent_rank(ship,"naval_tracking")>=0 and NavalContact.underwater_type(target):
		R.state(ship).tracking={"target":target,"left":R.talent(ship,"naval_tracking","life")};R.label(ship,"航标续追")

static func injured(unit,source,damage:float) -> void:
	if damage<=0 or not R.enemy(unit,R.owner(source)) or unit.hp<=0:return
	var carrier=unit.logistics.carrier_owner
	var s:=R.state(unit)
	if AlliedAbilities.alive(carrier) and carrier.unit_id=="CARRIER" and R.talent_rank(carrier,"sortie_afterburn")>=0 and not s.get("afterburn_used",false):
		s.afterburn_used=true;s.afterburn={"speed":R.talent(carrier,"sortie_afterburn","speed"),"damage":R.talent(carrier,"sortie_afterburn","damage")}
		unit._recompute_bonuses();R.label(unit,"受击加力 · 本次出航")

static func modify_reload(unit,seconds:float) -> float:
	var s:=R.state(unit)
	if int(s.get("heat_charges",0))>0:
		s.heat_charges-=1;seconds*=1.0-R.talent(unit,"mirage_afterheat","reload")
	return seconds

static func missile_destroyed(missile,source) -> void:
	if not is_instance_valid(source):return
	var flight:Dictionary=missile.special.get("flight",{})
	var launcher=flight.get("source")
	if not AlliedAbilities.alive(launcher) or R.talent_rank(launcher,"lost_missile")<0:return
	if flight.get("phase","")=="rack" or float(flight.get("elapsed",0))<float(flight.get("windup",0)):return
	var enemy=R.owner(source)
	if not is_instance_valid(enemy) or BattleRequest.friendly(enemy.side,missile.side):return
	var slot:int=flight.get("rack_slot",0)
	var racks:Array=launcher.special.get("missile_racks",[])
	if slot>=0 and slot<racks.size() and not flight.get("talent_used",false):
		flight.talent_used=true;racks[slot]*=1.0-R.talent(launcher,"lost_missile","reload")
		R.label(launcher,"失联预案 · 填弹加速")
