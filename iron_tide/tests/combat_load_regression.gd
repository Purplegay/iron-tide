extends "res://tests/base_recovery_regression.gd"
var metrics: Array = []

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	seed(21102026)
	for count in [20,50,100,200]: await exercise_load(count)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed,"metrics":metrics,
		"scope":"headless actual unit targeting, firing and projectile update; excludes rendering, HUD and audio mixing"}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func exercise_load(count: int) -> void:
	start(MatchRules.RA2)
	GM.god_mode = false
	GM.one_shot_kill = false
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	var actors: Array = []
	var initial_hp := 0.0
	for i in count:
		var side := "ally" if i < count / 2 else "enemy"
		var index := i % (count / 2)
		var column := index % 5
		var row := index / 5
		var pos := Vector2(1050 - column * 32 if side == "ally" else 1200 + column * 32, 600 + row * 32)
		var u = battle.spawn_unit("MTNK" if index % 3 == 0 else "E1", side, pos)
		u.process_mode = Node.PROCESS_MODE_ALWAYS
		u.set_process(false)
		u.set_physics_process(false)
		u.order_guard()
		actors.append(u)
		initial_hp += u.hp
	var holder: Node = actors[0]._pick_projectile_parent()
	var times: Array = []
	var shots := 0
	var invalid_targets := 0
	for tick in 360:
		await get_tree().physics_frame
		var begin := Time.get_ticks_usec()
		for u in actors:
			if not is_instance_valid(u) or u.is_queued_for_deletion(): continue
			u._physics_process(1.0/60.0)
			if is_instance_valid(u.attack_target) and u.attack_target.side == u.side: invalid_targets += 1
		for shot in holder.get_children():
			if not shot is Projectile: continue
			if not shot.has_meta("counted"):
				shot.set_meta("counted",true)
				shots += 1
			if shot.is_queued_for_deletion(): continue
			shot.set_physics_process(false)
			shot._physics_process(1.0/60.0)
		times.append((Time.get_ticks_usec()-begin)/1000.0)
	var remaining_hp := 0.0
	var survivors := 0
	for u in actors:
		if is_instance_valid(u) and u.hp > 0.0:
			remaining_hp += u.hp
			survivors += 1
	check(shots > 0 and remaining_hp < initial_hp, "load " + str(count) + ": actual auto-targeted combat emits shots and applies damage", {"shots":shots,"damage":initial_hp-remaining_hp})
	check(invalid_targets == 0, "load " + str(count) + ": no friendly automatic targets")
	times.sort()
	var metric := {"starting_units":count,"survivors_after_6_seconds":survivors,"shots":shots,
		"logic_p95_ms":times[int(times.size()*0.95)],"logic_p99_ms":times[int(times.size()*0.99)],"logic_max_ms":times.back()}
	metrics.append(metric)
	print("COMBAT_LOAD ",metric)
	await finish()
