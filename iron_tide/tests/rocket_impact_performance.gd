extends "res://tests/special_mechanics_regression.gd"
const Counters = preload("res://scripts/world/battle_call_counters.gd")
var measurements: Array = []

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await get_tree().process_frame
	seed(713)
	arena(MatchRules.RA2)
	battle.gm_unit_lab = true
	for i in 600:
		var actor = spawn("MTNK", "ally" if i % 2 == 0 else "enemy", Vector2(100 + i % 30 * 70, 100 + i / 30 * 70))
		actor.hp = 100000000; actor.max_hp = actor.hp
	var victim = battle.units[300]
	var shot := Projectile.new()
	shot.setup(victim.position - Vector2(100, 0), victim, GameData.get_unit("FV").weapon, 50, {}, "ally")
	shot.ra2_inviso = false
	shot.ra2_warhead = "AP"
	battle.projectiles_root.add_child(shot)
	for warmup in 20: ForceFire.impact_candidates(shot)
	Counters.start(get_instance_id())
	for batch in 100:
		var started := Time.get_ticks_usec()
		for impact in 20: ForceFire.impact_candidates(shot)
		measurements.append((Time.get_ticks_usec() - started) / 1000.0)
	var counts := Counters.take(get_instance_id())
	Counters.stop(get_instance_id())
	measurements.sort()
	var report := {"actors":battle.units.size(), "impacts_per_batch":20, "batches":100,
		"candidate_batch_p50_ms":measurements[49], "candidate_batch_p95_ms":measurements[94], "counters":counts}
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await finish()
	get_tree().quit()
