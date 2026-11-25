extends RefCounted
## PoweredUnit / PowersUnit adapter. Each owner needs one living, completed controller.
## Orders already in progress pause without losing their destination when power fails.

var offline := false
var initialized := false

static func reason(unit) -> String:
	var controller := str(unit.data.get("powered_by", ""))
	if controller.is_empty():
		return ""
	var world = unit._navigation_world()
	if not is_instance_valid(world):
		return "停机：缺少己方机器人控制中心"
	var found := false
	var complete := false
	for building in world.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() \
				or building.hp <= 0.0 or building._dead or building.side != unit.side \
				or building.building_id != controller:
			continue
		found = true
		if building.under_construction or building._buildup_play >= 0.0:
			continue
		complete = true
		if building.is_operational():
			return ""
	if not found:
		return "停机：缺少己方机器人控制中心"
	if not complete:
		return "停机：等待机器人控制中心展开完成"
	if world.side_power_low(unit.side):
		return "停机：电力不足，请补建电厂"
	return "停机：机器人控制中心未运转"

func tick(unit, delta: float) -> bool:
	if str(unit.data.get("powered_by", "")).is_empty():
		return false
	var disabled := not reason(unit).is_empty()
	if disabled != offline or not initialized:
		var world = unit._navigation_world()
		if initialized and (unit.side == "ally" or (is_instance_valid(world) and world.actor_visible_to("ally", unit))):
			Ra2Sfx.play_voice(unit.data, "deactivate" if disabled else "activate", unit.global_position, 100)
		unit.queue_redraw()
		offline = disabled
		initialized = true
	if not offline:
		return false
	unit.velocity = Vector2.ZERO
	unit._cancel_burst()
	unit._stun_timer = maxf(0.0, unit._stun_timer - delta)
	unit._tick_buffs(delta)
	unit.decorate_tick(delta)
	return true
