extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const OBSERVE:="ps_low_observation"
const HOVER:="hover_sighting"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func observes(unit) -> bool:
	return unit.unit_id in ["JUMPJET","SHAD","SCHP"] and unit.passive.get("id")==OBSERVE

static func eligible(unit) -> bool:
	if not is_instance_valid(unit) or unit.unit_id not in ["JUMPJET","SHAD","SCHP"]:return false
	return R.active(unit) and (observes(unit) or (unit.unit_id=="JUMPJET" and R.talent_rank(unit,HOVER)>=0))

static func airborne(unit) -> bool:
	return unit.is_air_target() and unit.embarked_in==null and not unit.special.has("para_height")

static func still(unit) -> bool:
	return not unit._moving() and unit.position.distance_squared_to(unit.special.get(KEY,{}).get("air_position",unit.position))<=.0001

static func tick(unit,dt:float) -> void:
	if not eligible(unit):return
	var s:=state(unit)
	var before:=int(float(s.get("air_observe",0))>=P.number("mechanic/air_observation","observe_prepare"))+2*int(float(s.get("hover_age",0))>=P.number("mechanic/air_observation","hover_prepare"))
	if not airborne(unit):s.erase("air_observe");s.erase("hover_age")
	else:
		if observes(unit):s.air_observe=minf(P.number("mechanic/air_observation","observe_prepare"),float(s.get("air_observe",0))+dt)
		if unit.unit_id=="JUMPJET" and R.talent_rank(unit,HOVER)>=0:
			s.hover_age=minf(P.number("mechanic/air_observation","hover_prepare"),float(s.get("hover_age",0))+dt) if still(unit) else 0.0
	s.air_position=unit.position
	var after:=int(float(s.get("air_observe",0))>=P.number("mechanic/air_observation","observe_prepare"))+2*int(float(s.get("hover_age",0))>=P.number("mechanic/air_observation","hover_prepare"))
	if before!=after:unit.queue_redraw()

static func firing(unit) -> void:
	if not eligible(unit) or not observes(unit):return
	state(unit).air_observe=0.0;unit.queue_redraw()

static func hovering(unit) -> bool:
	var s:Dictionary=unit.special.get(KEY,{})
	return unit.unit_id=="JUMPJET" and R.talent_rank(unit,HOVER)>=0 and s.get("side",unit.side)==unit.side and airborne(unit) and still(unit) and float(s.get("hover_age",0))>=P.number("mechanic/air_observation","hover_prepare")-.000001

static func shot(unit,bonus:Dictionary) -> void:
	if hovering(unit):bonus.expansion_hover_damage=R.talent(unit,HOVER,"damage")

static func impact(target,source,amount:float,bonus:Dictionary) -> float:
	if not bonus.has("expansion_hover_damage") or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return amount
	if source is Projectile and source.target!=target:return amount
	return amount*(1.0+float(bonus.expansion_hover_damage))

static func sight(unit) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	if not eligible(unit) or not observes(unit) or not airborne(unit) or s.get("side",unit.side)!=unit.side:return 0.0
	return R.value(unit,OBSERVE,"sight")*R.CELL if float(s.get("air_observe",0))>=P.number("mechanic/air_observation","observe_prepare")-.000001 else 0.0

static func entries(unit) -> Array:
	if not eligible(unit):return []
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	if observes(unit) and airborne(unit):out.append(V.row("低空观察 · 视野增加" if sight(unit)>0 else "低空观察 · 停火观察",maxf(0,P.number("mechanic/air_observation","observe_prepare")-float(s.get("air_observe",0))),false,"sight"))
	if unit.unit_id=="JUMPJET" and R.talent_rank(unit,HOVER)>=0 and airborne(unit):out.append(V.row("悬停校枪 · 普通直击强化" if hovering(unit) else "悬停校枪 · 静止校准",maxf(0,P.number("mechanic/air_observation","hover_prepare")-float(s.get("hover_age",0))),false,"attack"))
	return out

static func draw(unit) -> void:
	if sight(unit)>0:unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+9,0,TAU,24,Color.CYAN,1.2,true)
	if hovering(unit):unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+4,0,TAU,20,Color.GOLD,1.5,true)
