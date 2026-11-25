extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const TALENT:="escort_magazine"

static func enabled(unit) -> bool:
	return unit.unit_id=="DRED" and R.talent_rank(unit,TALENT)>=0

static func reload_time(unit) -> float:
	var seconds:float=unit.data.rocket.reload
	return seconds*(1.0-R.talent(unit,TALENT,"reload")) if enabled(unit) else seconds

static func departed(missile) -> void:
	if missile.unit_id!="DMISL":return
	var flight:Dictionary=missile.special.get("flight",{})
	var ship=flight.get("source")
	if not AlliedAbilities.alive(ship) or not enabled(ship) or ship.side!=missile.side:return
	if flight.get("phase","rack")=="rack" or flight.get("escort_departed",false):return
	flight.escort_departed=true
	var hp:float=missile.max_hp*R.talent(ship,TALENT,"shield")
	missile.special.get_or_add(KEY,{"side":missile.side}).escort_shield={"hp":hp,"maximum":hp}
	missile.queue_redraw()

static func shield(unit) -> Dictionary:
	var state:Dictionary=unit.special.get(KEY,{})
	return state.get("escort_shield",{}) if unit.unit_id=="DMISL" and R.active(unit) and state.get("side",unit.side)==unit.side else {}

static func absorb(unit,damage:float) -> float:
	var protection:=shield(unit)
	if damage<=0 or protection.is_empty():return damage
	var used:=minf(damage,float(protection.hp))
	protection.hp-=used
	if protection.hp<=0:unit.special[KEY].erase("escort_shield")
	unit.queue_redraw()
	return damage-used

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	if enabled(unit):
		var row:=V.row("护航弹仓",0,false,"reload")
		row.text="导弹架补弹 -%d%% · 每枚离架护盾 %d%%耐久"%[100*R.talent(unit,TALENT,"reload"),100*R.talent(unit,TALENT,"shield")]
		return [row]
	var protection:=shield(unit)
	if protection.is_empty():return []
	var row:=V.row("护航弹仓 · 导弹护盾",0,false,"guard")
	row.text="护盾 %.1f / %.1f · 耗尽后仍可击落"%[protection.hp,protection.maximum]
	return [row]

static func draw(unit) -> void:
	var protection:=shield(unit)
	if protection.is_empty():return
	var center:=Vector2(0,-unit._visual_lift())
	unit.draw_arc(center,unit.radius+7,0,TAU,24,Color(.3,.85,1,.75),1.5,true)
	unit.draw_line(center+Vector2(-12,-unit.radius-10),center+Vector2(12,-unit.radius-10),Color(.1,.2,.3),3)
	unit.draw_line(center+Vector2(-12,-unit.radius-10),center+Vector2(-12+24*protection.hp/protection.maximum,-unit.radius-10),Color.CYAN,3)
