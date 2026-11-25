extends Node

var checks: Array = []
var failed := 0
var output_dir := ""
var results: Array = []
var screen
var battle
var prefix := ""
var deaths := 0

func check(ok: bool, label: String, details = null) -> void:
	checks.append({"name": label, "passed": ok, "details": details})
	if not ok:
		failed += 1
		print("FAIL ", label, " ", details)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	Events.battle_ended.connect(func(result): results.append(result))
	Events.unit_died.connect(func(_unit): deaths += 1)
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise_deployment(mode)
		for side in ["ally", "enemy"]:
			await exercise_defeat(mode, side)
			await exercise_remaining_defenses(mode, side)
		await exercise_ai(mode)
		await exercise_simultaneous(mode)
	await exercise_campaign()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	f.close()
	get_tree().quit(0 if failed == 0 else 1)

func start(mode: String) -> void:
	prefix = mode + ": "
	BattleRequest.configure_skirmish(mode, {"map_size": 2400, "starting_funds": 8000, "enemy_base": "allied"})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	# Controlled open arena, retaining actual scene, actors, production and path service.
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group):
			node.free()
	for unit in battle.units:
		unit.free()
	battle.units.clear()
	battle.water_rects.clear()
	battle.path_service.water_rects.clear()
	battle._refresh_pathing()
	for building in battle.buildings:
		building._buildup_play = -1.0

func finish() -> void:
	screen.free()
	await get_tree().process_frame

func destroy_buildings(side: String, only_hq: bool = false) -> void:
	for building in battle.buildings:
		if is_instance_valid(building) and building.side == side and (not only_hq or building.is_hq):
			building._die()

func exercise_deployment(mode: String) -> void:
	start(mode)
	var pos := Vector2(1200, 1200)
	var mcv = battle.spawn_unit("AMCV", "ally", pos)
	check(mcv.can_deploy() and mcv.deploy_building_id() == "GACNST", prefix + "raw DeploysInto resolves supported construction yard")
	check(battle.construction_deploy_check(mcv).ok, prefix + "open remote terrain permits standalone deployment")
	check(not battle.build_spot_ok(pos, GameData.get_building("GACNST"), true).ok, prefix + "ordinary construction retains placement restrictions")
	var funds_before: float = battle.funds
	var count_before: int = battle.buildings.size()
	for blocked_pos in [Vector2.ZERO, battle._player_hq().global_position]:
		mcv.global_position = blocked_pos
		var reason: Dictionary = battle.construction_deploy_check(mcv)
		check(not reason.ok and not str(reason.reason).is_empty() and not mcv.deploy(), prefix + "invalid boundary or building overlap refuses deployment", reason)
	mcv.global_position = pos
	var blocker = battle.spawn_unit("MTNK", "ally", pos)
	check(battle.construction_deploy_check(mcv).reason == "与单位重叠" and not mcv.deploy(), prefix + "other ground unit blocks deployment")
	battle.units.erase(blocker)
	blocker.free()
	var ore = preload("res://scripts/world/resource_node.gd").new()
	ore.position = pos
	battle.add_child(ore)
	check(battle.construction_deploy_check(mcv).reason == "与矿点重叠" and not mcv.deploy(), prefix + "ore blocks deployment")
	ore.free()
	var obstacle = preload("res://scripts/world/obstacle.gd").new()
	obstacle.position = pos
	battle.add_child(obstacle)
	check(battle.construction_deploy_check(mcv).reason == "地形不可建" and not mcv.deploy(), prefix + "terrain obstacle blocks deployment")
	obstacle.free()
	battle.water_rects.append(Rect2(pos - Vector2(1, 400), Vector2(2, 800)))
	check(battle.construction_deploy_check(mcv).reason == "不能建在水面" and not mcv.deploy(), prefix + "thin water crossing footprint interior blocks deployment")
	battle.water_rects.clear()
	mcv.embarked_in = battle.spawn_unit("LCRF", "ally", Vector2(1800, 1200))
	check(not mcv.deploy(), prefix + "embarked MCV cannot deploy from transport")
	var transport = mcv.embarked_in
	mcv.embarked_in = null
	battle.units.erase(transport)
	transport.free()
	check(battle.funds == funds_before and battle.buildings.size() == count_before and not mcv._dead, prefix + "all rejected deployments preserve vehicle money and buildings")
	battle.request_structure("GAPOWR")
	battle._tick_structure_queue(2.0)
	var paid: float = battle.struct_queue[0].paid
	destroy_buildings("ally", true)
	battle._check_end()
	check(not battle.ended, prefix + "losing HQ alone does not defeat remaining base")
	var guide = preload("res://scripts/ui/unlock_guidance.gd").new(battle).describe("GAPILE")
	check(str(guide.detail).contains("按 J 展开"), prefix + "unlock guidance explains concrete base recovery action")
	battle._tick_structure_queue(10.0)
	check(battle.struct_queue[0].paid == paid, prefix + "paid structure queue pauses without construction yard")
	mcv.hp = mcv.max_hp * 0.4
	battle.funds = 0.0
	battle.select_unit(mcv, false)
	battle._emit_selection()
	battle.control_groups["1"] = [mcv]
	battle.follow_target = mcv
	screen.hud._refresh_deploy_cmd()
	check(not screen.hud.cmd_buttons.deploy.disabled and screen.hud.cmd_buttons.deploy.tooltip_text.contains("展开建造厂"), prefix + "actual command button explains MCV deployment")
	var deaths_before := deaths
	var kills_before: int = battle.kills
	screen.hud._cmd("deploy")
	var hq = battle._player_hq()
	check(hq != null and hq.global_position == pos and hq.side == "ally", prefix + "HUD deployment creates correctly owned construction yard at snapped position")
	if hq != null:
		check(is_equal_approx(hq.hp / hq.max_hp, 0.4) and not hq.under_construction and hq._buildup_play >= 0.0, prefix + "transformation preserves damage fraction and uses real buildup animation")
		check(battle.selected_building == hq and battle.selected_units.is_empty(), prefix + "selected MCV hands selection to new yard")
	check(mcv._dead and mcv.is_queued_for_deletion() and not battle.units.has(mcv), prefix + "consumed vehicle is removed immediately")
	check(not mcv.deploy() and battle.control_groups["1"].is_empty() and battle.follow_target == null, prefix + "repeat deployment cannot duplicate building and stale references are cleared")
	check(deaths == deaths_before and battle.kills == kills_before and battle.funds == 0.0, prefix + "deployment produces no death kill credit or second payment")
	check(battle.path_service.is_blocked(pos), prefix + "new construction yard blocks navigation")
	battle.funds = 1000.0
	battle._tick_structure_queue(1.0)
	check(battle.struct_queue[0].paid > paid, prefix + "existing paid production resumes after rebuilding")
	if DisplayServer.get_name() != "headless" and hq != null:
		hq._process(10.0)
		battle.camera.position = pos
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-rebuilt-base.png"))
	await finish()

func exercise_remaining_defenses(mode: String, side: String) -> void:
	start(mode)
	var point := Vector2(1200, 1200)
	for b in battle.buildings.duplicate():
		if b.side == side:
			battle.buildings.erase(b)
			b.free()
	var defenses: Array = []
	for id in ["GAPILL", "ATESLA", "GTGCAN", "NASAM", "GAWALL", "TESLA", "NAFLAK", "NABNKR", "NAWALL"]:
		defenses.append(battle._place_building(id, side, point, true))
		point.x += 48
	battle.mission.victory_condition = "annihilation"
	battle._check_end()
	check(not battle.ended and battle.has_surviving_assets(side), prefix + side + " surviving defenses count in annihilation")
	battle.mission.victory_condition = "short"
	check(not battle.has_surviving_assets(side), prefix + side + " only defenses do not sustain a short game")
	for id in ["GAPOWR", "NAWEAP", "GAWEAT", "NAMISL"]:
		var structure = battle._place_building(id, side, point, true)
		check(battle.has_surviving_assets(side), prefix + side + " counts remaining base structure " + id)
		battle.buildings.erase(structure)
		structure.free()
	var mcv = battle.spawn_unit("SMCV" if side == "enemy" else "AMCV", side, point)
	battle._check_end()
	check(not battle.ended and battle.has_surviving_assets(side), prefix + side + " remaining MCV preserves short game")
	battle.units.erase(mcv)
	mcv.free()
	var count := results.size()
	battle._check_end()
	check(battle.ended and results.size() == count + 1 and results.back().outcome == ("win" if side == "enemy" else "loss"), prefix + side + " short game settles with defenses standing")
	check(defenses.all(func(b): return battle.actor_alive(b)), prefix + side + " defenses need no cleanup for settlement")
	await finish()

func exercise_defeat(mode: String, side: String) -> void:
	start(mode)
	var mcv = battle.spawn_unit("AMCV", side, Vector2(1200, 1200))
	destroy_buildings(side)
	battle._check_end()
	check(not battle.ended and battle.has_base_assets(side), prefix + side + " lone MCV prevents premature elimination")
	var transport = battle.spawn_unit("LCRF", side, Vector2(1600, 1200))
	mcv.embarked_in = transport
	battle._check_end()
	check(not battle.ended, prefix + side + " transported MCV retains recovery eligibility")
	mcv.embarked_in = null
	if side == "enemy":
		battle.skirmish_ai._train_t = 0.0
		battle.skirmish_ai._process(0.1)
		check(battle.owned_building_ids(side).has("GACNST"), prefix + side + " AI still updates and deploys with zero surviving buildings")
	else:
		check(mcv.deploy(), prefix + side + " MCV restores completely destroyed base")
	var recovered = battle.buildings.back()
	destroy_buildings(side)
	# Keep a tank alive: this is explicitly the current short-game rule, not annihilation.
	battle.spawn_unit("MTNK", side, Vector2(1800, 1200))
	var before_results := results.size()
	var before_battles := int(MetaProgress.stats.get("battles", 0))
	battle._check_end()
	check(battle.ended and results.size() == before_results + 1 and results.back().win == (side == "enemy"),
		prefix + side + " destroyed buildings and consumed MCV do not delay same-frame settlement")
	battle._check_end()
	battle.end_battle(side == "ally")
	check(results.size() == before_results + 1, prefix + side + " outcome is emitted exactly once")
	check(int(MetaProgress.stats.get("battles", 0)) == before_battles + (0 if mode == MatchRules.RA2 else 1),
		prefix + side + " settlement respects progression isolation")
	check(not battle.deploy_construction_vehicle(mcv) and recovered.is_dead(), prefix + side + " ended match rejects further construction")
	await finish()
	start(mode)
	var doomed = battle.spawn_unit("AMCV", side, Vector2(1200, 1200))
	destroy_buildings(side)
	doomed.receive_hit(9999999.0, "tesla", {})
	battle._check_end()
	check(battle.ended and results.back().win == (side == "enemy"), prefix + side + " last MCV destruction ends match without waiting for deletion")
	await finish()

func exercise_ai(mode: String) -> void:
	start(mode)
	destroy_buildings("enemy")
	await get_tree().process_frame
	var factory = battle._place_building("GAWEAP", "enemy", Vector2(1200, 800), true)
	var depot = battle._place_building("GADEPT", "enemy", Vector2(1800, 800), true)
	factory._buildup_play = -1.0
	depot._buildup_play = -1.0
	battle.enemy_funds = 10000.0
	var ai = battle.skirmish_ai
	ai._recover_base()
	ai._recover_base()
	check(factory.production.count("AMCV") == 1, prefix + "AI queues exactly one legal replacement MCV at surviving factory")
	var funds_before: float = battle.enemy_funds
	var time: float = GameData.ra2_build_time(GameData.get_unit("AMCV")) / factory.build_speed
	factory._process(time + 1.0)
	var mcvs: Array = battle.units.filter(func(u): return u.unit_id == "AMCV")
	check(mcvs.size() == 1 and is_equal_approx(funds_before - battle.enemy_funds, 3000.0), prefix + "AI MCV is actually manufactured and fully paid")
	if not mcvs.is_empty():
		var mcv = mcvs[0]
		check(not ai._army.has(mcv), prefix + "AI MCV excluded from assault army")
		# Force an obstructed start, then let real movement reach AI's selected open site.
		mcv.global_position = factory.global_position + Vector2(180, 0)
		var obstacle = battle._place_building("GAPOWR", "enemy", mcv.global_position, true)
		ai._recover_base()
		check(mcv.has_move_order and not mcv.attack_move, prefix + "AI seeks legal reachable deployment position")
		var goal: Vector2 = mcv.move_target
		ai._recover_base()
		check(mcv.move_target == goal, prefix + "AI preserves recovery route between decisions")
		# Remove overlapping fixture so physics can exit; keep the chosen destination.
		# This artificial obstruction is not a crew-ejection case. New escaped,
		# deliberately frozen infantry would replace it with a different blocker.
		obstacle.special.no_crew = true
		obstacle._die()
		await get_tree().process_frame
		battle._refresh_pathing()
		screen.process_mode = Node.PROCESS_MODE_ALWAYS
		for actor in battle.get_children():
			actor.process_mode = Node.PROCESS_MODE_DISABLED
		battle.set_process(false)
		battle.set_physics_process(false)
		battle.enemy_root.process_mode = Node.PROCESS_MODE_ALWAYS
		for actor in battle.enemy_root.get_children():
			actor.process_mode = Node.PROCESS_MODE_DISABLED
		mcv.process_mode = Node.PROCESS_MODE_ALWAYS
		for tick in 1200:
			await get_tree().physics_frame
			if mcv.global_position.distance_to(goal) < 24.0:
				break
		mcv.process_mode = Node.PROCESS_MODE_DISABLED
		check(mcv.global_position.distance_to(goal) < 24.0, prefix + "AI replacement MCV reaches deployment site through actual physics", mcv.global_position)
		ai._recover_base()
		check(battle.owned_building_ids("enemy").has("GACNST"), prefix + "AI deploys replacement yard")
		screen.process_mode = Node.PROCESS_MODE_DISABLED
	ai._try_build()
	check(not battle.enemy_struct_queue.is_empty(), prefix + "AI resumes base construction after recovery")
	await finish()

func exercise_campaign() -> void:
	BattleRequest.configure_mission("m01", {})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	battle.spawn_unit("AMCV", "ally", Vector2(1200, 1200))
	destroy_buildings("ally", true)
	battle._check_end()
	check(battle.ended and not results.back().win, "campaign keeps protect-HQ defeat condition even with MCV alive")
	await finish()

func exercise_simultaneous(mode: String) -> void:
	start(mode)
	var a = battle.spawn_unit("AMCV", "ally", Vector2(1200, 1200))
	var b = battle.spawn_unit("AMCV", "ally", Vector2(1600, 1200))
	battle.select_unit(a, false)
	battle.select_unit(b, true)
	var before: int = battle.buildings.size()
	battle.deploy_selected()
	check(battle.buildings.size() == before + 2 and a._dead and b._dead, prefix + "multi-selection deploys both MCVs without skipping array member")
	destroy_buildings("ally")
	destroy_buildings("enemy")
	var count := results.size()
	battle._check_end()
	check(battle.ended and results.size() == count + 1 and results.back().get("draw", false) and not results.back().win and results.back().rewards.is_empty(), prefix + "simultaneous elimination draws once without progression rewards")
	await finish()
