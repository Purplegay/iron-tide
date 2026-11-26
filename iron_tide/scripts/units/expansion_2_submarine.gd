extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const SHIELD:="ps_depth_pressure"
static var SHIELD_DURATION:float:
	get:return P.number("mechanic/submarine_v2","shield_seconds")
const FORK:="wake_fork"
const FLIGHT:="expansion_torpedo"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func eligible(unit) -> bool:
	return unit.unit_id=="SUB" and R.active(unit) and unit.passive.get("id")==SHIELD

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	R.timer(s,"pressure_cd",dt)
	if s.has("pressure_shield"):
		s.pressure_shield.left-=dt
		if s.pressure_shield.left<=.000001:s.erase("pressure_shield")
		unit.queue_redraw()
	if not eligible(unit) or unit.embarked_in!=null:return
	s=state(unit);s.pressure_idle=minf(P.number("mechanic/submarine_v2","idle_seconds"),float(s.get("pressure_idle",0))+dt)
	if s.pressure_idle>=P.number("mechanic/submarine_v2","idle_seconds")-.000001 and not s.has("pressure_cd"):
		s.pressure_shield={"hp":unit.max_hp*R.value(unit,SHIELD,"shield"),"left":SHIELD_DURATION}
		s.pressure_cd=P.number("mechanic/submarine_v2","cooldown");unit.queue_redraw()

static func firing(unit) -> void:
	if eligible(unit):state(unit).pressure_idle=0.0

static func absorb(unit,amount:float) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has("pressure_shield") or s.get("side",unit.side)!=unit.side:return amount
	var taken:=minf(amount,float(s.pressure_shield.hp));s.pressure_shield.hp-=taken
	if s.pressure_shield.hp<=0:s.erase("pressure_shield")
	unit.queue_redraw();return amount-taken

static func shot(unit,bonus:Dictionary) -> void:
	if unit.unit_id!="SUB" or R.talent_rank(unit,FORK)<0:return
	bonus[FLIGHT]={"weapon":unit._active_weapon().duplicate(true),"range":R.talent(unit,FORK,"range")*R.CELL,"damage":R.talent(unit,FORK,"damage")}

static func initialize(projectile) -> void:
	if not projectile.attacker_bonus.has(FLIGHT) or projectile.attacker_bonus.get("expansion_extra",false):return
	projectile.splinters[FLIGHT]={"previous":projectile.global_position,"distance":0.0,"used":false}

static func world(projectile):
	var host=projectile.get_parent()
	return host.get_parent() if host!=null and host.get_parent() is Battle else null

static func travel(projectile) -> void:
	var battle=world(projectile)
	if battle==null:return
	if projectile.splinters.has("expansion_fork"):
		var fork:Dictionary=projectile.splinters.expansion_fork
		if fork.get("lost",false):return
		if not target_allowed(projectile,projectile.target) or fork.origin.distance_to(projectile.target.global_position)>float(fork.range):
			# Native lost-target flight continues to its last known point, without reacquisition.
			projectile.target=null;fork.lost=true
		return
	if not projectile.splinters.has(FLIGHT):return
	var f:Dictionary=projectile.splinters[FLIGHT]
	var before:Vector2=f.previous;var after:Vector2=projectile.global_position
	var distance:=before.distance_to(after)
	if distance>0:
		var steps:=maxi(1,ceili(distance/(R.CELL*.25)))
		for i in steps:
			if battle.path_service.in_naval_water(before.lerp(after,(float(i)+.5)/steps)):f.distance+=distance/steps
	f.previous=after

static func target_allowed(projectile,target) -> bool:
	if not AlliedAbilities.alive(target) or target.side=="neutral" or BattleRequest.friendly(projectile.owner_side,target.side):return false
	if target is Unit:
		if not target.is_naval or target.is_air_target() or target.embarked_in!=null:return false
		if AlliedAbilities.concealed(target,projectile.owner_side):return false
	elif target is Building:
		if not target.data.get("water_bound",false) or float(target.special.get("force_shield_left",0))>0:return false
	else:return false
	if AlliedAbilities.alive(target.special.get("temporal_by")) or target.ignores_warhead(projectile.ra2_warhead):return false
	var battle=world(projectile)
	if battle==null or not battle.actor_visible_to(projectile.owner_side,target):return false
	# Preserve the native SUB naval targeting permission even after the launcher has died.
	if NavalContact.underwater_type(target):
		if GameData.unit_naval_targeting("SUB") not in [1,2,3,4,5]:return false
	return true

static func hit(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not source is Projectile or not source.splinters.has(FLIGHT):return
	if source.target!=target or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return
	# Capture accepted direct contact before shields/HP subtraction; an in-flight shot need not reacquire its primary.
	if not AlliedAbilities.alive(target) or target.side=="neutral" or BattleRequest.friendly(source.owner_side,target.side):return
	if (target is Unit and target.is_naval and not target.is_air_target() and target.embarked_in==null) or (target is Building and target.data.get("water_bound",false)):
		source.splinters[FLIGHT].contact=true

static func finish(projectile) -> void:
	if not BattleRequest.extensions_enabled() or not projectile.splinters.has(FLIGHT):return
	var f:Dictionary=projectile.splinters[FLIGHT]
	if f.used or not f.get("contact",false) or float(f.distance)<P.number("mechanic/submarine_v2","fork_distance")*R.CELL-.000001:return
	f.used=true
	var config:Dictionary=projectile.attacker_bonus[FLIGHT]
	var battle=world(projectile)
	if battle==null:return
	var chosen=null;var closest:float=float(config.range)+.000001
	for target in battle.units+battle.buildings:
		if target==projectile.target or not target_allowed(projectile,target):continue
		var distance:float=projectile.target_point.distance_to(target.global_position)
		if distance<closest:chosen=target;closest=distance
	if chosen==null:return
	var weapon:Dictionary=config.weapon.duplicate(true)
	weapon.damage=float(weapon.damage)*float(config.damage);weapon.range=float(config.range)
	var bonus:Dictionary=projectile.attacker_bonus.duplicate(true)
	bonus.erase(FLIGHT);bonus.erase("expansion_volley");bonus.erase("expansion_origin")
	bonus.expansion_extra=true;bonus.reference_weapon=weapon.duplicate(true)
	var damage:=CombatMath.full_damage(weapon,chosen.armor,bonus,null,chosen.ra2_armor,0.0,chosen)
	var child:=Projectile.new();child.setup(projectile.target_point,chosen,weapon,damage,bonus,projectile.owner_side,projectile.shooter())
	child._heading=projectile.target_point.direction_to(chosen.global_position)
	child.splinters.expansion_fork={"origin":projectile.target_point,"range":float(config.range),"lost":false}
	projectile.get_parent().add_child(child)

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	if s.has("pressure_shield"):
		var row:=V.row("深水耐压护盾",s.pressure_shield.left,false,"guard");row.text="剩余护盾 %.0f"%s.pressure_shield.hp;out.append(row)
	if s.has("pressure_cd"):out.append(V.row("深水耐压冷却",s.pressure_cd,false,"reload"))
	elif eligible(unit):out.append(V.row("深水耐压 · 停火蓄盾",maxf(0,4-float(s.get("pressure_idle",0))),false,"guard"))
	return out
