extends RefCounted

const EconomyCycle = preload("res://scripts/world/economy_cycle.gd")

static func vehicle_type(building) -> String:
	var source:Dictionary = GameData.ra2_source_buildings.get(building.building_id,{}).get("extra",{})
	return str(building.data.get("undeploys_into",source.get("UndeploysInto","")))

static func check(world, building) -> Dictionary:
	if not is_instance_valid(building) or not world.buildings.has(building) or building._dead \
			or building.hp <= 0.0 or building.is_queued_for_deletion() or world.ended:
		return {"ok": false, "reason": "建筑当前不可收起"}
	var uid := vehicle_type(building)
	if uid.is_empty() or GameData.get_unit(uid).is_empty():
		return {"ok": false, "reason": "该建筑不能收起为基地车"}
	if building.under_construction or building._buildup_play >= 0.0:
		return {"ok": false, "reason": "等待建造场展开完成"}
	if world.paused:
		return {"ok": false, "reason": "游戏暂停中"}
	if not world.skirmish and building.side == "ally" and building.is_hq:
		var others := 0
		for b in world.buildings:
			if is_instance_valid(b) and b != building and b.side == "ally" and b.is_hq and not b._dead:
				others += 1
		if others == 0:
			return {"ok": false, "reason": "本任务要求保留主基地"}
	var radius := float(GameData.get_unit(uid).get("radius", 18.0))
	var pos: Vector2 = building.global_position
	if not EconomyCycle.landing_clear(world, pos, radius + 4.0, null, building):
		return {"ok": false, "reason": "建造场中心被占用，请移开单位或障碍"}
	return {"ok": true, "reason": "", "unit": uid, "position": pos}

static func execute(world, building) -> bool:
	var status := check(world, building)
	if not status.ok:
		Events.emit_message("无法收起：" + str(status.reason), Color(1.0, 0.75, 0.4))
		return false
	var fraction: float = clampf(building.hp / building.max_hp, 0.0, 1.0)
	var selected: bool = world.selected_building == building
	# Add surviving MCV first. Conversion never enters death, bounty or refund paths.
	var mcv = world.spawn_unit(status.unit, building.side, status.position)
	if mcv == null:
		return false
	mcv.hp = mcv.max_hp * fraction
	if building.special.has(Ra3Clearance.KEY):
		mcv.special[Ra3Clearance.KEY] = building.special[Ra3Clearance.KEY].duplicate(true)
	preload("res://scripts/world/construction_transition.gd").repacking(mcv, building)
	if selected:
		world.clear_selection()
	building._dead = true
	building.set_process(false)
	building.set_physics_process(false)
	for group in building.get_groups():
		building.remove_from_group(group)
	world.buildings.erase(building)
	if world.hover_entity == building:
		world.hover_entity = null
	building.queue_free()
	world._refresh_pathing()
	world._update_power()
	if selected:
		world.select_unit(mcv, false)
		world._emit_selection()
	if mcv.side == "ally":
		Events.emit_message("矿场已收起。" if mcv.unit_id=="SMIN" else "建造场已收起 · 已付建造进度保留，重新展开后继续。", Color(0.6, 0.95, 0.8))
	return true
