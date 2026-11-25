extends RefCounted
const KEY := "ai_blocked_route"
const RETRY := 6.0
static func waiting(world,unit) -> bool:
	var state:Dictionary=unit.special.get(KEY,{})
	if state.is_empty():return false
	if state.epoch!=world.path_service.epoch or unit._anim>=float(state.until):
		unit.special.erase(KEY)
		return false
	preload("res://scripts/world/battle_call_counters.gd").iterations(77,1)
	return true
static func failed(world,unit,requested:Vector2,resolved:Vector2) -> bool:
	if unit.is_air or unit.is_naval or requested.distance_to(unit.position)<220.0 or resolved.distance_to(unit.position)>Unit.ARRIVE_EPS:return false
	unit.special[KEY]={"goal":requested,"epoch":world.path_service.epoch,"until":unit._anim+RETRY}
	return true
