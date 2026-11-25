extends "res://tests/base_recovery_regression.gd"
const Reference = preload("res://tests/path_iteration_reference.gd")
const Idle = preload("res://scripts/units/unit_expansion_idle.gd")
const OldIdle = preload("res://tests/unit_idle_iteration_reference.gd")
var timing: Dictionary = {}

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	var prior := Reference.new()
	var current := PathService.new()
	prior.cols = 30; prior.rows = 30; current.cols = 30; current.rows = 30
	prior.map_size = 1200; current.map_size = 1200
	var rng := RandomNumberGenerator.new(); rng.seed = 719
	var grid := PackedFloat32Array(); grid.resize(900)
	var zones := PackedInt32Array(); zones.resize(900)
	for layout in 12:
		for i in 900:
			grid[i] = -1.0 if rng.randf() < 0.22 else 0.0
			zones[i] = rng.randi_range(1,3)
		for sample in 30:
			var sc := Vector2i(rng.randi_range(0,29),rng.randi_range(0,29))
			var gc := Vector2i(rng.randi_range(0,29),rng.randi_range(0,29))
			grid[sc.y*30+sc.x] = 0; grid[gc.y*30+gc.x] = 0
			for budget in [0,1,17,900]:
				for temporary in [false,true]:
					var from := Vector2(sc)*40+Vector2(13,17)
					var to := Vector2(gc)*40+Vector2(5,9)
					var expected := prior._bounded_grid_path(from,to,sc,gc,grid,budget,temporary)
					var actual := current._bounded_grid_path(from,to,sc,gc,grid,budget,temporary)
					check(actual == expected, "exact route including tie, corner and partial path %d/%d/%d/%s" % [layout,sample,budget,temporary])
			for zone in [0,1,2,3]:
				for radius in [-1,0,1,5]:
					var point := sc-Vector2i(3,3)
					check(current._nearest_walkable(point,grid,zones,zone,radius) == prior._nearest_walkable(point,grid,zones,zone,radius),"nearest cell preserves ring ties, zone and map bounds")
	check(current.stats_path_fail == prior.stats_path_fail,"path failure counters identical")
	# Alternating batches avoid comparing separate machine-load windows.
	var old_samples: Array = []; var new_samples: Array = []
	for batch in 40:
		for version in ([prior,current] if batch%2==0 else [current,prior]):
			var begin := Time.get_ticks_usec()
			for repeat in 20: version._bounded_grid_path(Vector2(20,20),Vector2(1180,1180),Vector2i.ZERO,Vector2i(29,29),grid,900,false)
			(old_samples if version == prior else new_samples).append((Time.get_ticks_usec()-begin)/1000.0)
	old_samples.sort(); new_samples.sort()
	timing = {"old_batch_p50_ms":old_samples[19],"new_batch_p50_ms":new_samples[19],"old_batch_p95_ms":old_samples[37],"new_batch_p95_ms":new_samples[37],"paths_per_batch":20}
	prior.free(); current.free()
	start(MatchRules.EXTENDED)
	var unit: Unit = battle.spawn_unit("MTNK","ally",Vector2(1200,1200))
	AlliedAbilities.change_side(unit,"enemy")
	var keys := Idle.INERT_KEYS.keys()
	for mask in 256:
		var state := {}
		for bit in keys.size():
			if mask & (1 << bit): state[keys[bit]] = 0.0
		unit.special.progression_v1 = state.duplicate(true)
		check(Idle.try_tick(unit,0.1),"native key whitelist accepts inert combination "+str(mask))
		check(unit.special.progression_v1.arc_count == 0 and unit.special.progression_v1.shot_idle == 0.1,"inert bookkeeping preserved")
		state.unknown_effect = 1
		unit.special.progression_v1 = state.duplicate(true)
		check(not Idle.try_tick(unit,0.1) and unit.special.progression_v1 == state,"unknown effect immediately falls back without mutation")
	var old_idle: Array = []; var new_idle: Array = []
	unit.special.progression_v1 = {"arc_count":0,"shot_idle":0.0,"rest":0.0,"volley":0,"scrap_idle":0.0,"scrap_drop":0.0}
	for batch in 30:
		for version in ([OldIdle,Idle] if batch%2==0 else [Idle,OldIdle]):
			var begin := Time.get_ticks_usec()
			for repeat in 10000: version.try_tick(unit,1.0/15.0)
			(old_idle if version == OldIdle else new_idle).append((Time.get_ticks_usec()-begin)/1000.0)
	old_idle.sort(); new_idle.sort()
	timing.idle_old_batch_p50_ms = old_idle[14]
	timing.idle_new_batch_p50_ms = new_idle[14]
	timing.idle_updates_per_batch = 10000
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"timing":timing},"  "))
	get_tree().quit(0 if failed == 0 else 1)
