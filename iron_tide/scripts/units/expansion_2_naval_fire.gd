extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Ordinary volleys retain their target and reload; extra fire never enters the firing state machine.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const CROSS:="ps_sea_air_crossfire"
const GAUGE:="intercept_ranging"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func eligible(unit) -> bool:
	if not is_instance_valid(unit) or unit.unit_id not in ["HYD","AEGIS"]:return false
	return R.active(unit) and ((unit.unit_id=="HYD" and unit.passive.get("id")==CROSS) or (unit.unit_id=="AEGIS" and R.talent_rank(unit,GAUGE)>=0))

static func domain(target) -> int:
	if not AlliedAbilities.alive(target) or not target is Unit or target.embarked_in!=null:return 0
	if target.is_air_target():return 1
	return 2 if target.is_naval and not NavalContact.underwater_type(target) else 0

static func sync_target(unit) -> void:
	var s:=state(unit)
	var target=unit.attack_target if R.enemy(unit,unit.attack_target) and domain(unit.attack_target)==1 else null
	if not is_same(s.get("gauge_target"),target):
		s.gauge_target=target;s.gauge_epoch=int(s.get("gauge_epoch",0))+1
		s.gauge_hits=[];s.gauge_charges=0;s.gauge_discounted=false;unit.queue_redraw()

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	R.timer(s,"cross_cd",dt)
	if unit.unit_id=="AEGIS" and eligible(unit):sync_target(unit)

static func reload_time(unit,seconds:float) -> float:
	if unit.unit_id!="AEGIS" or not eligible(unit):return seconds
	sync_target(unit)
	var s:=state(unit);s.gauge_discounted=false
	if s.get("side",unit.side)!=unit.side or s.get("gauge_target")==null or int(s.get("gauge_charges",0))<=0:return seconds
	s.gauge_charges-=1;s.gauge_discounted=true;unit.queue_redraw()
	return seconds*(1.0-R.talent(unit,GAUGE,"reload"))

static func shot(unit,bonus:Dictionary) -> void:
	if unit.unit_id!="AEGIS" or not eligible(unit):return
	sync_target(unit)
	var s:=state(unit)
	bonus.expansion_gauge_epoch=int(s.get("gauge_epoch",0))
	bonus.expansion_gauge_skip=s.get("gauge_discounted",false)
	bonus.expansion_gauge_side=unit.side

static func damaged(unit,target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not unit is Unit or unit.unit_id!="AEGIS" or not eligible(unit):return
	if not bonus.has("expansion_gauge_epoch") or bonus.get("expansion_gauge_skip",false) or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return
	if source is Projectile and source.target!=target:return
	sync_target(unit)
	var s:=state(unit)
	if s.get("side",unit.side)!=unit.side or bonus.get("expansion_gauge_side")!=unit.side or bonus.expansion_gauge_epoch!=s.get("gauge_epoch",0) or not is_same(s.get("gauge_target"),target) or int(s.get("gauge_charges",0))>0:return
	var volley:int=int(bonus.get("expansion_volley",-1))
	var hits:Array=s.get_or_add("gauge_hits",[])
	if volley<0 or volley in hits:return
	hits.append(volley)
	if hits.size()>=P.count("mechanic/naval_fire_v2","hits"):
		s.gauge_charges=P.count("mechanic/naval_fire_v2","charges");s.gauge_hits=[];s.gauge_epoch=int(s.get("gauge_epoch",0))+1
	unit.queue_redraw()

static func firing(unit,primary) -> void:
	if unit.unit_id!="HYD" or not eligible(unit) or domain(primary)==0 or not R.enemy(unit,primary):return
	var s:=state(unit);var volley:int=int(R.state(unit).get("volley",0))
	if s.get("side",unit.side)!=unit.side or int(s.get("cross_volley",-1))==volley:return
	s.cross_volley=volley
	if s.has("cross_cd") or unit._stun_timer>0 or AlliedAbilities.frozen(unit) or unit.embarked_in!=null or unit.repairing:return
	var world=R.world(unit)
	if world==null:return
	var other= null;var distance:=INF
	for candidate in world.units:
		if not R.enemy(unit,candidate) or domain(candidate)!=3-domain(primary):continue
		var weapon:Dictionary=unit._weapon_for_target(candidate)
		if not unit._weapon_target_valid(candidate,weapon) or not unit._weapon_aligned(candidate):continue
		var d:float=unit.position.distance_squared_to(candidate.position)
		if d<distance:other=candidate;distance=d
	if other==null:return
	# A miss still spends the trigger interval, just like an ordinary discharged round.
	s.cross_cd=R.value(unit,CROSS,"interval");unit.queue_redraw()
	var weapon:Dictionary=unit._weapon_for_target(other).duplicate(true)
	weapon.damage=float(weapon.damage)*R.value(unit,CROSS,"damage")
	var muzzle:Vector2=unit._weapon_muzzle()
	unit._spawn_muzzle_fx(muzzle,str(weapon.get("ra2_weapon_id","")));Ra2Sfx.play_weapon(weapon,muzzle)
	world.reveal_attack(unit,other)
	var chance:float=clampf(1.0+unit.buff_value("accuracy")-unit._target_evade(other),.05,1.0)
	if chance<.999 and randf()>chance:return
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.reference_weapon=weapon.duplicate(true)
	bonus.impact_weapon=weapon.get("ra2_weapon_id","")
	var crit:float=clampf(unit.buff_value("crit"),0,.95)
	if crit>0 and randf()<crit:bonus.attack_bonus=float(bonus.get("attack_bonus",1))*P.number("mechanic/naval_fire_v2","critical")
	var damage:=CombatMath.full_damage(weapon,other.armor,bonus,null,other.ra2_armor,0.0,other)
	if float(weapon.get("projectile_speed",0))>0:
		var projectile:=Projectile.new();projectile.setup(muzzle,other,weapon,damage,bonus,unit.side,unit)
		unit._pick_projectile_parent().add_child(projectile)
	else:
		Ra2Fx.play_impact(Effects._host(),str(weapon.get("ra2_warhead","")),damage,Effects.hit_position(other))
		other.receive_hit(damage,str(weapon.get("attack_type","shell")),bonus,unit,str(weapon.get("ra2_warhead","")))

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	if s.has("cross_cd"):out.append(V.row("海空交叉火控 · 共用冷却",s.cross_cd,false,"reload"))
	if unit.unit_id=="AEGIS" and s.get("gauge_target")!=null:
		var charges:int=int(s.get("gauge_charges",0))
		out.append(V.row("拦空测距 · 快速装填 %d/2"%charges if charges>0 else "拦空测距 · 命中 %d/3"%s.get("gauge_hits",[]).size(),0,false,"focus"))
	return out

static func draw(unit) -> void:
	if int(unit.special.get(KEY,{}).get("gauge_charges",0))>0:unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+5,0,TAU,24,Color.GOLD,2,true)
