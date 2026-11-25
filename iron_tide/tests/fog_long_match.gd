extends Node
const EconomyCycle = preload("res://scripts/world/economy_cycle.gd")
## Reproducible single-player economy soak. Fixed 60 Hz, an isolated profile,
## and only the allied yard's HP enlarged so the unattended match can run 30 min.
var directory: String
var screen
var world
var checks: Array = []
var minutes: Array = []
var traces: Array = []
var frame_us: Array[int] = []
var drained: Array[Vector2] = []
var mines: Array[Vector2] = []
var unloads := 0
var income := 0.0
var after_income := 0.0
var after_produced := 0
var mined_outside := false
var last_load: Dictionary = {}
var miners: Array = []

func record(ok: bool, name: String, value = null) -> void:
	checks.append({"passed":ok,"name":name,"details":value})
	if not ok: print("FAIL ",name," ",value)

func new_screen() -> void:
	screen = preload("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	world = screen.battle

func _ready() -> void:
	directory = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if directory.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or Engine.physics_ticks_per_second != 60:
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(20261102)
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size":2400, "starting_funds":8000,"difficulty":1,"enemy_base":"allied","opening":"prebuilt","fog_of_war":true})
	new_screen()
	world.skirmish_ai._rng.seed = 20261102
	var hq = world._player_hq()
	hq.max_hp = 10000000.0
	hq.hp = hq.max_hp
	var center: Vector2 = world.enemy_base_center
	var size: float = world.map_size
	mines.assign([center + size*Vector2(-0.24,0.05),center+size*Vector2(0.24,0.05),center+size*Vector2(0,0.26)])
	var begin := Time.get_ticks_usec()
	var prev := begin
	var frames := 0
	while frames < 108000 and not world.ended:
		await get_tree().process_frame
		frames += 1
		var now := Time.get_ticks_usec()
		frame_us.append(now - prev)
		prev = now
		if frames % 60 == 1:
			miners = world.units.filter(func(u): return world.actor_alive(u) and u.side == "enemy" and u.is_harvester)
		for miner in miners:
			if not is_instance_valid(miner) or miner._dead: continue
			var id: int = miner.get_instance_id()
			var value: float = miner.cargo_value()
			var old: float = last_load.get(id,0.0)
			if old > 0.0 and value == 0.0:
				unloads += 1
				income += old * EconomyCycle.income_factor(world,"enemy")
			if drained.size() == 2 and value > old and is_instance_valid(miner.resource_node):
				var pos: Vector2 = miner.resource_node.position
				if pos.distance_to(drained[0]) > 220 and pos.distance_to(drained[1]) > 220: mined_outside = true
			last_load[id] = value
		if frames in [18000,36000]:
			drain_working_field()
			if drained.size() == 2:
				after_income = income
				after_produced = world.skirmish_ai.a_spawned
		if frames == 54000:
			if not reload_checkpoint(): break
			prev = Time.get_ticks_usec()
		if frames % 3600 == 0:
			frame_us.sort()
			var data := {"minute":frames/3600,"funds":world.enemy_funds,"unloads":unloads,"ore_income":income,"produced":world.skirmish_ai.a_spawned,"attacks":world.skirmish_ai.a_attacks,"miners":miners.size(),"units":world.units.size(),"ore_cells":get_tree().get_nodes_in_group("resource_nodes").size(),"relief":world.allied_state.get("ai_relief_total",0),"p50_ms":float(frame_us[1800])/1000.0,"p95_ms":float(frame_us[3420])/1000.0,"p99_ms":float(frame_us[3564])/1000.0}
			minutes.append(data)
			print("SOAK ",JSON.stringify(data))
			FileAccess.open(directory.path_join("minutes.json"),FileAccess.WRITE).store_string(JSON.stringify(minutes))
			frame_us.clear()
			prev = Time.get_ticks_usec()
	record(frames == 108000 and not world.ended,"30 simulation minutes completed",frames)
	record(drained.size() == 2 and mined_outside,"AI harvests beyond both exhausted fields")
	record(drained.size() == 2 and income > after_income and world.skirmish_ai.a_spawned > after_produced,"AI delivers ore and produces after second depletion",[income-after_income,world.skirmish_ai.a_spawned-after_produced])
	var failed := checks.filter(func(row):return not row.passed).size()
	var report := {"failed":failed,"checks":checks,"minutes":minutes,"depletions":traces,"wall_seconds":(Time.get_ticks_usec()-begin)/1000000.0,"ore_income_after_second":income-after_income,"produced_after_second":world.skirmish_ai.a_spawned-after_produced,"scope":"60 Hz headless frame intervals, includes HUD/AI/physics, excludes GPU presentation. Controlled exhaustion at minutes 5/10. Allied yard HP enlarged."}
	FileAccess.open(directory.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	screen.free(); Ra2Sfx.stop_all(); Music.stop(); Music.player.stream=null
	OS.delay_msec(150)
	await get_tree().process_frame
	get_tree().quit(0 if failed == 0 else 1)

func drain_working_field() -> void:
	var anchor: Vector2 = world.enemy_base_center
	for miner in miners:
		if is_instance_valid(miner) and is_instance_valid(miner.resource_node):
			anchor = miner.resource_node.position
			break
	var choice := Vector2.INF
	for mine in mines:
		if drained.has(mine): continue
		if choice == Vector2.INF or anchor.distance_to(mine) < anchor.distance_to(choice): choice = mine
	var removed := 0.0
	var count := 0
	for ore in get_tree().get_nodes_in_group("resource_nodes"):
		if ore.position.distance_to(choice) <= 220:
			removed += ore.amount
			EconomyCycle.fill(ore,0.0)
			count += 1
	drained.append(choice)
	traces.append({"center":str(choice),"tiles":count,"removed":removed})
	record(count > 0,"controlled field exhaustion " + str(drained.size()),traces.back())

func reload_checkpoint() -> bool:
	var match_id: String = world.match_id
	var funds: float = world.enemy_funds
	var produced: int = world.skirmish_ai.a_spawned
	var explored: PackedByteArray = world.fog.explored_cells.enemy.duplicate()
	var queue = world.enemy_struct_queue.duplicate(true)
	var saved: Dictionary = BattleSaves.save_slot(world,"slot1")
	record(saved.ok,"minute 15 save",saved.get("reason",""))
	if not saved.ok: return false
	DirAccess.copy_absolute(BattleSaves.slot_path("slot1"),directory.path_join("minute15.itsave"))
	var ready: Dictionary = BattleSaves.prepare_load("slot1")
	record(ready.ok,"minute 15 load validation",ready.get("reason",""))
	if not ready.ok: return false
	screen.free()
	new_screen()
	record(world.paused and get_tree().paused and BattleSaves.pending.is_empty() and world.match_id == match_id and is_equal_approx(world.enemy_funds,funds) and world.skirmish_ai.a_spawned == produced and world.fog.explored_cells.enemy == explored and world.enemy_struct_queue == queue,"match identity, funds, production, structure queue and explored terrain restored")
	world.paused = false
	get_tree().paused = false
	miners.clear()
	last_load.clear()
	return true
