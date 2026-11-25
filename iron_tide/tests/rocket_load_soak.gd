extends "res://tests/special_mechanics_regression.gd"
const Counters = preload("res://scripts/world/battle_call_counters.gd")
var missiles: Array = []
var frame_samples: Array = []
var step_samples: Array = []
var spawned := 0
var detonated := 0

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await get_tree().process_frame
	seed(713)
	arena(MatchRules.RA2)
	battle.gm_unit_lab = true
	Engine.time_scale = 1.0
	Engine.max_fps = 60
	for i in 600:
		var actor = spawn("MTNK", "enemy", Vector2(500 + i % 30 * 55, 100 + i / 30 * 55))
		actor.hp = 100000000; actor.max_hp = actor.hp
	# Real projectile movement, splash, effects and draw callbacks. Only the
	# stationary target army/AI is disabled, isolating a repeatable rocket load.
	battle.projectiles_root.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.effects_root.process_mode = Node.PROCESS_MODE_ALWAYS
	var duration := float(OS.get_environment("IRON_ROCKET_SECONDS"))
	if duration <= 0: duration = 60
	var limit := roundi(duration * 15)
	var ticks := 0
	var started := Time.get_ticks_usec()
	var last := started
	var counts: Array = []
	Counters.start(get_instance_id())
	while ticks < limit:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_samples.append((now-last)/1000.0)
		last = now
		var due := mini(limit, floori((now-started)/1000000.0*15.0))
		while ticks < due:
			var step_started := Time.get_ticks_usec()
			step(ticks)
			step_samples.append((Time.get_ticks_usec()-step_started)/1000.0)
			ticks += 1
	var elapsed := (Time.get_ticks_usec()-started)/1000000.0
	counts = Counters.take(get_instance_id())
	Counters.stop(get_instance_id())
	var hp: Array = []
	for actor in battle.units: hp.append(actor.hp)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"wall_s":elapsed,"sim_s":ticks/15.0,"actual_speed":ticks/15.0/elapsed,
		"actors":600,"spawned":spawned,"detonated":detonated,"in_flight":missiles.size(),
		"frame":stats(frame_samples),"rocket_step":stats(step_samples),"counters":counts,"hp":hp,
		"scope":"headless CPU; 600 stationary targets, 240 real FV rockets/sec; no AI/unit updates; no GPU measurement"},"  "))
	await finish()
	get_tree().quit()

func step(tick: int) -> void:
	for i in 16:
		var target = battle.units[(tick*16+i)*17 % 600]
		var shot := Projectile.new()
		shot.setup(target.position-Vector2(400,0), target, GameData.get_unit("FV").weapon, 50, {}, "ally")
		shot.ra2_warhead = "AP"
		shot.ra2_inviso = false
		battle.projectiles_root.add_child(shot)
		shot.set_physics_process(false)
		missiles.append(shot)
		spawned += 1
	for i in range(missiles.size()-1,-1,-1):
		var shot = missiles[i]
		shot._physics_process(1.0/15.0)
		if shot.is_queued_for_deletion():
			if shot._detonated: detonated += 1
			missiles.remove_at(i)

func stats(samples: Array) -> Dictionary:
	samples.sort()
	var total := 0.0
	for value in samples: total += value
	return {"count":samples.size(),"mean_ms":total/samples.size(),"p95_ms":samples[ceili(samples.size()*.95)-1],"max_ms":samples.back()}
