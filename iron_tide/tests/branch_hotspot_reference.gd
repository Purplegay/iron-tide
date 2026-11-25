extends RefCounted
# Frozen functions immediately before the branch-filter optimization.

static func fighter(world, unit, owner := "enemy") -> bool:
	if not world.actor_alive(unit) or unit.side != owner or unit.embarked_in != null: return false
	if unit.unit_id == "BFRT" and unit._anim < float(unit.special.get("ai_crew_wait", -1.0)):
		if unit.logistics.used_capacity() < unit.logistics.capacity: return false
	return not unit.special.has("ai_oil_post") \
		and unit.logistics.ammo_max == 0 and not unit.is_naval and unit.unit_id != "SHAD" \
		and unit.special.get("action", "") not in ["tesla_charge", "allied_garrison"] \
		and not unit.special.get("ai_transport_reserved", false) \
		and not unit.is_harvester and unit.deploy_building_id().is_empty() \
		and float(unit._active_weapon().get("damage", 0)) > 0.0

static func miners(ai, queued := true) -> int:
	var n := 0
	for u in ai.battle.units:
		if ai.battle.actor_alive(u) and u.side == ai.house_id and u.is_harvester: n += 1
	if queued:
		var miner_id: String = ai.battle.roster_id("CMIN", ai.house_id)
		for b in ai.battle.buildings:
			if ai.battle.actor_alive(b) and b.side == ai.house_id:
				n += b.production.count(miner_id)
				if b.special.get("construction_free_unit", "") == miner_id: n += 1
	return n

static func sellable(ai, building) -> bool:
	if not ai.battle.actor_alive(building) or building.side!=ai.house_id or building.under_construction: return false
	if building.is_hq or building.is_refinery() or building.building_id=="CAOILD" or building.data.get("tags",[]).has("civilian"): return false
	var raw:Dictionary=GameData.ra2_source_buildings.get(building.building_id,{}).get("extra",{})
	if GameData._ra2_flag(raw.get("Unsellable",false)): return false
	if WallArt.is_wall(building.data): return true
	# Preserve the last production/tech building and every power generator.
	if building.power>0: return false
	var copies:=0
	for other in ai.battle.buildings:
		if ai.battle.actor_alive(other) and other.side==ai.house_id and other.building_id==building.building_id and not other.under_construction: copies+=1
	return copies>1

static func micro_tick(ai, dt: float) -> void:
	var world = ai.battle
	if world.paused or world.ended or world.get_tree().paused or ai.enemy_base == "swarm": return
	var elapsed := float(ai.ai_state.get("ai_micro_elapsed", 0.0)) + dt
	if elapsed < 0.5:
		ai.ai_state.ai_micro_elapsed = elapsed
		return
	ai.ai_state.ai_micro_elapsed = 0.0
	var contacts := {}
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side != ai.house_id: continue
		if unit.unit_id not in ["E1","GGI","DESO","SCHP"] and not (unit.is_naval and unit._return_timer>0.0): continue
		if not world.ai_dispatch.defer_job(world,unit,"micro",elapsed): preload("res://scripts/world/skirmish_micro.gd").unit_decision(ai,unit,null,elapsed,contacts)
