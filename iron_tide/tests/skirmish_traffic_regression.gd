extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	for factory_id in ["GAWEAP", "NAWEAP"]:
		await factory_traffic(factory_id)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)

func factory_traffic(id: String) -> void:
	start(MatchRules.RA2)
	var ai = battle.skirmish_ai
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	var uid := "HTNK" if id == "NAWEAP" else "MTNK"
	var factory = battle._place_building(id,"enemy",Vector2(1200,1200),true)
	factory._buildup_play = -1
	var door: Vector2 = factory._spawn_point(uid)
	ai.rally = door
	var tanks: Array = []
	var goals: Array[Vector2] = []
	for i in 8:
		var spawn_at: Vector2 = factory._spawn_point(uid)
		if not spawn_at.is_finite(): break
		var u = battle.spawn_unit(uid,"enemy",spawn_at,factory)
		u.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		tanks.append(u)
		goals.append(u.move_target)
		for tick in 60:
			await get_tree().physics_frame
			for t in tanks: t._physics_process(1.0/60.0)
	for tick in 540:
		await get_tree().physics_frame
		for t in tanks: t._physics_process(1.0/60.0)
	check(tanks.size()==8, id+" eight consecutive production exits")
	check(goals.all(func(p): return goals.count(p)==1),id+" distinct waiting positions")
	check(tanks.all(func(t): return not t.has_move_order and t.position.distance_to(door)>t.radius+15),id+" all eight settled clear of primary door",tanks.map(func(t):return [str(t.position),t.has_move_order]))
	check(factory._spawn_point(uid).is_equal_approx(door),id+" primary door still usable by ninth tank")
	var legacy = tanks.back()
	legacy.special.erase("ai_assembly_point")
	legacy.order_move(ai.rally)
	var snapshot = BattleSaves.Snapshot.new()
	snapshot.restore(battle,snapshot.capture(battle))
	get_tree().paused = false
	battle.paused = false
	ai = battle.skirmish_ai
	legacy = ai._army.filter(func(t): return not t.special.has("ai_assembly_point"))[0]
	ai._recruit_idle()
	check(legacy.has_move_order and legacy.move_target.distance_to(door) > legacy.radius + 15, id+" legacy shared destination reassigned")
	var old_goal: Vector2 = legacy.move_target
	var structure = battle._place_building("GAPOWR","enemy",old_goal,true)
	ai._recruit_idle()
	check(legacy.has_move_order and not battle.path_service.is_blocked(legacy.move_target) and not legacy.move_target.is_equal_approx(old_goal),id+" new construction invalidates occupied parking goal")
	structure._die()

	await finish()
