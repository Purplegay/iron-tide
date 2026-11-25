extends "res://tests/base_recovery_regression.gd"
const Clearance=preload("res://scripts/units/ai_wall_clearance.gd")
const Operations=preload("res://scripts/world/skirmish_operations.gd")
const Tactics=preload("res://scripts/world/skirmish_tactics.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		for owner in ["enemy","ai2"]: await exercise(mode,owner)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("AI WALL checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise(mode:String,owner:String) -> void:
	start(mode)
	BattleRequest.house_teams={"ally":1,"enemy":2,"ai2":1}
	battle.paused=false
	get_tree().paused=false
	GM.god_mode=false
	GM.one_shot_kill=false
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle.wall_cells.clear()
	battle._refresh_pathing()
	prefix=mode+" "+owner+" "
	var foe="ally" if owner=="enemy" else "enemy"
	var ai=battle.skirmish_ai
	ai.house_id=owner
	ai.rally=Vector2(1200,1200)
	var tank=battle.spawn_unit("MTNK",owner,Vector2(1200,1200))
	var wall=battle._place_building("GAWALL",foe,Vector2(1320,1200),true)
	wall._buildup_play=-1.0
	var target=battle._place_building("GAPOWR",foe,Vector2(1400,1400),true)
	target._buildup_play=-1.0
	check(not Operations.targets(ai).has(wall) and Operations.targets(ai).has(target),prefix+"strategic contacts exclude walls")
	check(Operations.preferred(ai,tank,[wall,target])==target,prefix+"supplied contact lists cannot reintroduce a wall target")
	check(Tactics.attack_position(ai,[tank])==target.position,prefix+"attack wave selects a real objective rather than nearby wall")
	tank.attack_move=true
	tank.fire_stance="free"
	check(not tank._automatic_target_allowed(wall),prefix+"automatic combat rejects unrelated wall")
	var player=battle.spawn_unit("MTNK","ally",Vector2(1100,1100))
	player.attack_move=true
	check(player._automatic_target_allowed(wall),prefix+"player wall-target policy remains unchanged")
	var turret=battle._place_building("ATESLA",owner,Vector2(1200,1280),true)
	check(not turret._valid_weapon_target(wall),prefix+"stationary AI defenses do not shoot walls")
	var defender=battle.spawn_unit("GGI",owner,Vector2(1200,1240))
	preload("res://scripts/world/skirmish_micro.gd").unit_decision(ai,defender,[wall],3.0)
	check(not defender.is_deployed() and defender.attack_target!=wall,prefix+"deployment micro does not turn a wall into a combat objective")
	defender.free()
	battle.units.erase(defender)
	tank.order_target(wall,false,false)
	tank._refresh_target()
	check(tank.attack_target!=wall and not tank.attack_ordered,prefix+"legacy explicit AI wall order is discarded")
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle.wall_cells.clear()
	player.free()
	battle.units.erase(player)
	battle._refresh_pathing()
	# A solitary wall has a complete detour: never fire at it just because it is near.
	tank.position=Vector2(1320,1600)
	wall=battle._place_building("GAWALL",foe,Vector2(1480,1600),true)
	wall._buildup_play=-1.0
	var goal=Vector2(1600,1600)
	tank.order_move(goal,true)
	check(Clearance.reaches(battle.path_for_unit(tank,goal),goal),prefix+"real navigation can detour around solitary wall")
	tank._refresh_target()
	check(tank.attack_target!=wall and not tank.special.has(Clearance.STATE),prefix+"clear detour prevents demolition")
	# Enclose the destination. This is a genuine route failure, not a distance heuristic.
	var walls=[wall]
	for x in range(1480,1721,40):
		for y in [1480,1720]: walls.append(battle._place_building("GAWALL",foe,Vector2(x,y),true))
	for y in range(1520,1720,40):
		for x in [1480,1720]:
			if Vector2(x,y)!=wall.position: walls.append(battle._place_building("GAWALL",foe,Vector2(x,y),true))
	for b in walls: b._buildup_play=-1.0
	tank.order_move(goal,true)
	check(not Clearance.reaches(battle.path_for_unit(tank,goal),goal),prefix+"enclosure truly blocks the destination")
	tank._refresh_target()
	check(Clearance.wall(tank.attack_target) and tank.special.has(Clearance.STATE),prefix+"blocked route selects its first hostile wall")
	var paths:int=battle.path_service.stats_paths
	tank._refresh_target()
	check(battle.path_service.stats_paths==paths,prefix+"clearance probe is cached between retries")
	if tank.special.has(Clearance.STATE):
		check(tank._weapon_target_valid(tank.attack_target),prefix+"clearance wall passes actual firing eligibility")
	var rifle=battle.spawn_unit("E1",owner,Vector2(1320,1640))
	rifle.order_move(goal,true)
	rifle._refresh_target()
	check(not rifle.special.has(Clearance.STATE),prefix+"rifle cannot waste shots on concrete walls")
	rifle.free()
	battle.units.erase(rifle)
	# Open a vehicle-width breach through actual wall damage/removal.
	for b in walls:
		if b.position.x==1480 and absf(b.position.y-1600)<=40: b.receive_hit(100000,"explosion",{},tank,"AP")
	await get_tree().process_frame
	await get_tree().process_frame
	tank._refresh_target()
	check(not tank.special.has(Clearance.STATE) and not Clearance.wall(tank.attack_target),prefix+"open breach stops wall attacks immediately")
	check(tank.has_move_order and tank.attack_move and tank.move_target==goal,prefix+"original attack-move resumes after opening the gap")
	check(Clearance.reaches(battle.path_for_unit(tank,goal),goal),prefix+"actual navigation now reaches the original destination")
	# New commands cancel any clearance metadata instead of resurrecting an old goal.
	tank.order_stop(false)
	check(not tank.special.has(Clearance.GOAL) and not tank.special.has(Clearance.STATE),prefix+"stop cancels clearance and its saved destination")
	for y in [1560,1600,1640]:
		var replacement=battle._place_building("GAWALL",foe,Vector2(1480,y),true)
		replacement._buildup_play=-1.0
		walls.append(replacement)
	for b in walls:
		if is_instance_valid(b): b.side=owner
	tank.order_move(goal,true)
	tank._refresh_target()
	check(not tank.special.has(Clearance.STATE) and not Clearance.wall(tank.attack_target),prefix+"blocked friendly walls are never attacked")
	for b in walls:
		if is_instance_valid(b): b.side=foe
	tank.position=Vector2(1360,1600)
	var victim=battle.spawn_unit("E1",foe,Vector2(1680,1600))
	tank.order_target(victim,false,false)
	check(not tank._weapon_target_valid(victim),prefix+"explicit target is beyond current firing reach")
	tank._refresh_target()
	check(tank.special.has(Clearance.STATE) and Clearance.wall(tank.attack_target),prefix+"explicit attack can temporarily clear a blocking wall")
	if tank.special.has(Clearance.STATE):
		check(tank.special[Clearance.STATE].target==victim and tank.special[Clearance.STATE].ordered,prefix+"clearance retains explicit target identity")
	for b in walls:
		if is_instance_valid(b) and b.position.x==1480 and absf(b.position.y-1600)<=40: b.receive_hit(100000,"explosion",{},tank,"AP")
	await get_tree().process_frame
	await get_tree().process_frame
	tank._refresh_target()
	check(tank.attack_ordered and tank.attack_target==victim and not tank.special.has(Clearance.STATE),prefix+"explicit target resumes after clearance")
	var survivor=battle.buildings.filter(func(b):return is_instance_valid(b) and b.hp>0 and WallArt.is_wall(b.data))[0]
	Operations.order_attack(tank,survivor)
	battle.ai_dispatch.pump(battle)
	check(tank.attack_target==victim,prefix+"strategic dispatcher refuses a direct wall order")
	var jet=battle.spawn_unit("BEAG",owner,Vector2(1320,1400))
	jet.order_target(survivor,false,false)
	jet._refresh_target()
	check(not Clearance.wall(jet.attack_target) and not jet.special.has(Clearance.STATE),prefix+"aircraft never treat ground walls as a movement obstruction")
	await finish()
