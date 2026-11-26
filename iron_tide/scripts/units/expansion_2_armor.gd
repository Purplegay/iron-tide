extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Native V3 launch phases and APOC shared reload/burst stay authoritative.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const ARCHIVE:="ps_ballistic_archive"
const ARMOR:="ps_anchor_armor"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func card(unit,id:String) -> bool:
	return R.active(unit) and unit.passive.get("id")==id

static func eligible(unit) -> bool:
	return (unit.unit_id=="V3" and (card(unit,ARCHIVE) or R.talent_rank(unit,"launch_bulkhead")>=0)) or (unit.unit_id=="APOC" and (card(unit,ARMOR) or R.talent_rank(unit,"split_hunt")>=0))

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	for key in ["archive_left","bulkhead_cd","armor_incoming"]:
		if s.has(key):
			s[key]=maxf(0,float(s[key])-dt)
			if s[key]<=.000001:s.erase(key)
	if s.has("archive_target") and (not s.has("archive_left") or not R.enemy(unit,s.archive_target) or (is_instance_valid(unit.attack_target) and not is_same(unit.attack_target,s.archive_target))):
		s.erase("archive_target");s.erase("archive_left")
	if s.has("bulkhead_shield"):
		s.bulkhead_shield.left-=dt
		if s.bulkhead_shield.left<=.000001:s.erase("bulkhead_shield");unit.queue_redraw()
	if unit.unit_id!="APOC" or not card(unit,ARMOR):return
	var previous:Vector2=s.get("armor_position",unit.position)
	s.armor_position=unit.position
	var moving:bool=unit._moving() or previous.distance_squared_to(unit.position)>.0001
	if s.get("armor_ready",false):
		s.armor_left=maxf(0,float(s.get("armor_left",P.number("mechanic/armor_v2","guard_seconds")))-dt)
		if s.armor_left<=.000001:s.erase("armor_ready");s.erase("armor_left");s.armor_still=0.0
		unit.queue_redraw()
		return
	if moving:
		s.armor_still=0.0
	else:
		if (R.enemy(unit,unit.attack_target) and unit._weapon_target_valid(unit.attack_target)) or s.has("armor_incoming"):
			s.armor_still=minf(P.number("mechanic/armor_v2","prepare"),float(s.get("armor_still",0))+dt)
			if s.armor_still>=P.number("mechanic/armor_v2","prepare")-.000001:s.armor_ready=true;s.armor_left=P.number("mechanic/armor_v2","guard_seconds");s.armor_still=0.0;unit.queue_redraw()
		else:s.armor_still=0.0

static func rocket_created(unit,missile,target) -> void:
	if unit.unit_id!="V3" or not card(unit,ARCHIVE):return
	var s:=state(unit);var flight:Dictionary=missile.special.flight
	flight.expansion_archive_target=target if target is Building and R.enemy(unit,target) else null
	flight.expansion_owner_side=unit.side
	if s.has("archive_left") and is_same(s.get("archive_target"),target):flight.damage*=1.0+R.value(unit,ARCHIVE,"damage")
	s.erase("archive_left");s.erase("archive_target")

static func rack_remaining(unit,missile,remaining:float) -> float:
	var flight:Dictionary=missile.special.get("flight",{})
	var cut:float=float(flight.get("expansion_reload_cut",0))
	# A current-cycle discount never shortens the native raising animation or frees an occupied rail.
	var raising:float=maxf(0,remaining-float(unit.data.rocket.reload)) if flight.get("phase")=="rack" else 0.0
	return maxf(raising,remaining-cut)

static func rocket_hit(missile,target,health_loss:float) -> void:
	var flight:Dictionary=missile.special.flight
	var unit=flight.get("source")
	if health_loss<=0 or not AlliedAbilities.alive(unit) or unit.unit_id!="V3" or not card(unit,ARCHIVE):return
	if flight.get("expansion_archive_used",false) or unit.side!=flight.get("expansion_owner_side","") or not is_same(flight.get("expansion_archive_target"),target):return
	if not target is Building or BattleRequest.friendly(unit.side,target.side) or target.side=="neutral" or missile.position.distance_to(target.position)>.01:return
	flight.expansion_archive_used=true
	var s:=state(unit)
	if AlliedAbilities.alive(target):s.archive_target=target;s.archive_left=P.number("mechanic/armor_v2","archive_seconds")
	var fraction:=R.value(unit,ARCHIVE,"reload")
	unit.special.launcher_rof=float(unit.special.get("launcher_rof",0))*(1.0-fraction)
	var racks:Array=unit.special.get("missile_racks",[])
	for i in racks.size():
		var raising=unit.special.get("raising_missile_"+str(i))
		if AlliedAbilities.alive(raising) and raising.special.flight.get("phase")=="rack":
			var f:Dictionary=raising.special.flight
			f.expansion_reload_cut=minf(float(unit.data.rocket.reload),float(f.get("expansion_reload_cut",0))+float(racks[i])*fraction)
		else:racks[i]=float(racks[i])*(1.0-fraction)
	unit.SovietWeapons.tick_racks(unit,0.0)
	R.label(unit,"弹道留档")

static func departed(missile) -> void:
	var flight:Dictionary=missile.special.get("flight",{})
	var unit=flight.get("source")
	if not AlliedAbilities.alive(unit) or unit.unit_id!="V3" or unit.side!=missile.side or R.talent_rank(unit,"launch_bulkhead")<0:return
	if flight.get("phase")=="rack" or flight.get("expansion_departed",false):return
	flight.expansion_departed=true
	var s:=state(unit)
	if s.has("bulkhead_cd"):return
	var hp:float=unit.max_hp*R.talent(unit,"launch_bulkhead","shield")
	s.bulkhead_shield={"hp":hp,"left":P.number("mechanic/armor_v2","shield_seconds")};s.bulkhead_cd=P.number("mechanic/armor_v2","shield_cooldown");unit.queue_redraw()

static func absorb(unit,amount:float) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has("bulkhead_shield") or s.get("side",unit.side)!=unit.side:return amount
	var used:=minf(amount,float(s.bulkhead_shield.hp));s.bulkhead_shield.hp-=used
	if s.bulkhead_shield.hp<=0:s.erase("bulkhead_shield")
	unit.queue_redraw();return amount-used

static func prepare_wait(unit,target) -> void:
	if unit.unit_id!="APOC" or not card(unit,ARMOR) or unit._burst_left>0 or not R.enemy(unit,target):return
	var s:=state(unit)
	if s.get("side",unit.side)!=unit.side or int(s.get("armor_credit",0))<=0 or s.get("armor_wait_used",false) or unit._cd_timer<=0 or AlliedAbilities.frozen(unit) or not unit._weapon_target_valid(target) or not unit._weapon_aligned(target):return
	consume_credit(s);s.armor_wait_used=true
	unit._cd_timer*=1.0-R.value(unit,ARMOR,"reload")
	unit.queue_redraw()

static func consume_credit(s:Dictionary) -> void:
	s.armor_credit=maxi(0,mini(P.count("mechanic/armor_v2","credits"),int(s.get("armor_credit",0)))-1)
	if s.armor_credit==0:s.erase("armor_credit")

static func begin_volley(unit,seconds:float) -> float:
	if unit.unit_id!="APOC" or not card(unit,ARMOR):return seconds
	var s:=state(unit)
	s.armor_reused=s.get("armor_wait_used",false);s.erase("armor_wait_used");s.armor_granted=false
	# A stored credit is useful even after a long idle: if no waiting CD was cut, shorten this new cycle once.
	if not s.armor_reused and s.get("side",unit.side)==unit.side and int(s.get("armor_credit",0))>0:
		consume_credit(s);s.armor_reused=true;seconds*=1.0-R.value(unit,ARMOR,"reload")
	unit.queue_redraw()
	return seconds

static func ground_cannon(unit) -> bool:
	return unit.unit_id=="APOC" and unit._active_weapon().get("name") in ["120mmx","120mmxE"]

static func split_target(unit,target):
	if not ground_cannon(unit) or R.talent_rank(unit,"split_hunt")<0 or not R.enemy(unit,target):return target
	var weapon:Dictionary=unit._active_weapon()
	if posmod(int(weapon.burst)-unit._burst_left,2)!=1:return target
	var found=target;var best:=INF
	for candidate in R.world(unit).units:
		if is_same(candidate,target) or not R.enemy(unit,candidate) or candidate.is_air_target():continue
		var distance:float=candidate.position.distance_squared_to(target.position)
		if distance>pow(R.talent(unit,"split_hunt","radius")*R.CELL,2) or distance>=best:continue
		if not unit._weapon_target_valid(candidate,weapon) or not unit._weapon_aligned(candidate):continue
		best=distance;found=candidate
	return found

static func shot(unit,target,bonus:Dictionary) -> void:
	if unit.unit_id!="APOC" or not R.active(unit):return
	if ground_cannon(unit) and R.talent_rank(unit,"split_hunt")>=0:bonus.expansion_hunt=true
	if not card(unit,ARMOR):return
	var s:=state(unit)
	if target is Unit and target.is_air_target() and R.enemy(unit,target) and not s.get("armor_reused",false) and not s.get("armor_granted",false):
		s.armor_credit=P.count("mechanic/armor_v2","credits");s.armor_granted=true;unit.queue_redraw()

static func defend(unit,amount:float,bonus:Dictionary,source) -> float:
	if amount<=0 or unit.unit_id!="APOC" or not card(unit,ARMOR):return amount
	var attacker=R.owner(source)
	if not is_instance_valid(attacker) or not (attacker is Unit or attacker is Building) or BattleRequest.friendly(unit.side,attacker.side):return amount
	var s:=state(unit);s.armor_incoming=P.number("mechanic/armor_v2","combat_window")
	if s.get("side",unit.side)!=unit.side or not s.get("armor_ready",false) or not bonus.has("expansion_origin") or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false):return amount
	if source is Projectile and not is_same(source.target,unit):return amount
	var direction:Vector2=Vector2(bonus.expansion_origin)-unit.position
	if direction.is_zero_approx() or Vector2.from_angle(unit.hull_angle).dot(direction.normalized())<P.number("mechanic/armor_v2","frontal_cosine")-.000001:return amount
	return amount*(1.0-R.value(unit,ARMOR,"defense"))

static func finish_projectile(projectile) -> void:
	if not projectile.attacker_bonus.get("expansion_hunt",false) or projectile.splinters.get("expansion_hunt_done",false):return
	projectile.splinters.expansion_hunt_done=true
	var world=projectile.get_parent()
	while world!=null and not world is Battle:world=world.get_parent()
	if world==null:return
	for target in world.units+world.buildings:
		if not AlliedAbilities.alive(target) or target.side=="neutral" or BattleRequest.friendly(projectile.owner_side,target.side):continue
		if target is Unit and (target.is_air_target() or target.embarked_in!=null or NavalContact.submerged(target)):continue
		if target.position.distance_to(projectile.target_point)>P.number("mechanic/armor_v2","splash_radius")*R.CELL:continue
		var raw:=Ra2Damage.target_damage(projectile.base_damage,projectile.ra2_warhead,target,0.0)*P.number("mechanic/armor_v2","splash_damage")
		var damage:=CombatMath.with_offense(raw,projectile.attacker_bonus)
		var packet:Dictionary=projectile.hit_modifiers(target,0.0,P.number("mechanic/armor_v2","splash_damage")).duplicate(true)
		packet.erase("expansion_hunt");packet.expansion_extra=true
		target.receive_hit(damage,projectile.attack_type,packet,projectile,projectile.ra2_warhead)
	if world.position_visible_to("ally",projectile.target_point):Effects.spawn_impact(projectile.target_point,Color.ORANGE,P.number("mechanic/armor_v2","splash_radius")*R.CELL)

static func entries(unit) -> Array:
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	const V=preload("res://scripts/units/expansion_visual.gd")
	for row in [["archive_left","弹道留档 · 同目标增伤"],["bulkhead_cd","发射隔舱冷却"]]:
		if s.has(row[0]):out.append(V.row(row[1],s[row[0]],false,"reload"))
	if s.has("bulkhead_shield"):
		var row:=V.row("发射隔舱护盾",s.bulkhead_shield.left,false,"guard");row.text="剩余护盾 %.0f"%s.bulkhead_shield.hp;out.append(row)
	if int(s.get("armor_credit",0))>0:
		var row:=V.row("压阵装甲 · 保留减CD额度",0,false,"reload");row.stacks=int(s.armor_credit);row.limit=P.count("mechanic/armor_v2","credits");out.append(row)
	if s.get("armor_ready",false):out.append(V.row("压阵装甲 · 正面120°减伤",float(s.get("armor_left",0)),false,"guard"))
	elif float(s.get("armor_still",0))>0:out.append(V.row("压阵装甲 · 静止交火",P.number("mechanic/armor_v2","prepare")-s.armor_still,false,"guard"))
	return out

static func draw(unit) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if int(s.get("armor_credit",0))>0:
		for i in P.count("mechanic/armor_v2","credits"):unit.draw_circle(Vector2(-7+i*7,-unit.radius-8-unit._visual_lift()),2,Color.GOLD if i<int(s.armor_credit) else Color.DIM_GRAY)
	if s.get("armor_ready",false):
		var points:=PackedVector2Array()
		for i in 17:points.append(Iso.dir(Vector2.from_angle(unit.hull_angle-PI/3+i*PI/24)*(unit.radius+10)))
		unit.draw_polyline(points,Color.GOLD,2,true)
