extends RefCounted
## Plan against the owner's live grid and committed buildings, not temporary blackouts.

static func margin(ai) -> float:
	var world=ai.battle
	var grid:Dictionary=world._side_power(ai.house_id)
	var result:float=grid.produced-grid.drain
	for job in world.allied_state.get("house_ai",{}).get(ai.house_id,{}).get("construction_jobs",[]):
		result+=float(GameData.get_building(job.id).get("power",0))
	for b in world.buildings:
		if world.actor_alive(b) and b.side==ai.house_id and b.under_construction:
			result+=b.power
	if ai.house_id=="enemy":
		for job in world.enemy_struct_queue: result+=float(GameData.get_building(job.id).get("power",0))
		for id in world.enemy_struct_ready:
			result+=float(GameData.get_building(id).get("power",0))*int(world.enemy_struct_ready[id])
	return result

static func pending(ai) -> bool:
	var world=ai.battle
	for job in world.allied_state.get("house_ai",{}).get(ai.house_id,{}).get("construction_jobs",[]):
		if float(GameData.get_building(job.id).get("power",0))>0: return true
	for b in world.buildings:
		if world.actor_alive(b) and b.side==ai.house_id and b.under_construction and b.power>0: return true
	if ai.house_id=="enemy":
		for job in world.enemy_struct_queue:
			if float(GameData.get_building(job.id).get("power",0))>0: return true
		for id in world.enemy_struct_ready:
			if int(world.enemy_struct_ready[id])>0 and float(GameData.get_building(id).get("power",0))>0: return true
	return false

static func needed(ai) -> bool:
	if not ai.battle.owned_building_ids(ai.house_id).has(ai.battle.roster_id("GACNST",ai.house_id)): return false
	var base: Array = ai.battle.owned_building_ids(ai.house_id)
	var reserve_power := 0.0
	if base.has(ai.battle.roster_id("GAREFN",ai.house_id)) and base.has(ai.battle.roster_id("GAWEAP",ai.house_id)):
		reserve_power = float(preload("res://data/ra2/retail_skirmish.json").data.power_surplus)
	return margin(ai)<reserve_power-0.001 and not pending(ai)

static func reserve(ai) -> float:
	if not needed(ai): return 0.0
	return float(GameData.get_building(ai.battle.roster_id("GAPOWR",ai.house_id)).cost)

static func before_build(ai,id:String) -> String:
	if float(GameData.get_building(id).get("power",0))<0 and margin(ai)+float(GameData.get_building(id).power)<-0.001:
		return ai.battle.roster_id("GAPOWR",ai.house_id)
	return id
