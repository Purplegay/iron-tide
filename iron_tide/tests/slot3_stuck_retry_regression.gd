extends Node
var world
var cohort: Array = []
var checks: Array = []
var failed := 0

func check(ok: bool, name: String, details = null) -> void:
	checks.append({"passed":ok,"name":name,"details":details})
	if not ok:
		failed += 1
		print("FAIL ",name," ",details)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	get_tree().current_scene = null
	run.call_deferred()

func _process(_delta: float) -> void:
	# Reproduce the reported scheduling pressure without altering production
	# budgets, combat, unit orders, collision rules or the saved population.
	if is_instance_valid(world): world.frame_pacing.tier = 3

func run() -> void:
	var out := OS.get_environment("IRON_TIDE_REPORT_DIR")
	var source := OS.get_environment("IRON_SAVE")
	if out.is_empty() or source.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	check(DirAccess.copy_absolute(source,BattleSaves.slot_path("slot3")) == OK,"copy save into isolated profile")
	var loaded := BattleSaves.load_into_scene("slot3")
	check(loaded.ok,"real slot3 validates and loads",loaded.get("message"))
	if loaded.ok:
		while get_tree().current_scene == null: await get_tree().process_frame
		world = get_tree().current_scene.battle
		for unit: Unit in world.units:
			if unit.side != "enemy" or unit.is_air or unit.embarked_in != null or unit.unit_id == "E1": continue
			if unit.position.distance_to(Vector2(3730,4530)) >= 100: continue
			cohort.append({"unit":unit,"type":unit.unit_id,"origin":unit.position,"goal":unit.move_target,
				"distance":0.0,"was_dry":unit._domain_ok(unit.position),"recovered":false})
		check(cohort.size() == 9,"2026-11-17 slot3 contains the nine reported vehicles",cohort.size())
		world.frame_pacing.tier = 3
		world.paused = false
		get_tree().paused = false
		for tick in 450:
			await get_tree().physics_frame
			for row in cohort:
				var unit = row.unit
				if not is_instance_valid(unit) or unit.hp <= 0: continue
				row.distance = maxf(row.distance,unit.position.distance_to(row.origin))
				row.recovered = row.recovered or unit._domain_ok(unit.position)
		for row in cohort:
			check(row.distance > 60,"saved "+row.type+" physically leaves its jam before any combat death",row.distance)
			if not row.was_dry: check(row.recovered,"saved "+row.type+" returns to dry ground through normal movement")
	var metrics: Array = []
	for row in cohort:
		metrics.append({"type":row.type,"origin":row.origin,"original_goal":row.goal,"max_distance":row.distance,"recovered":row.recovered})
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,
		"metrics":metrics,"physics_ticks":450,"forced_load_tier":3,"user_dir":OS.get_user_data_dir(),"source_save":source},"  "))
	get_tree().quit(0 if failed == 0 else 1)
