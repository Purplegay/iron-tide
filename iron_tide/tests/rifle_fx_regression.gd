extends "res://tests/base_recovery_regression.gd"
const Batch = preload("res://scripts/core/rifle_fx_batch.gd")
var metrics: Array = []

class VisibilityWorld extends Node2D:
	var shown := true
	var last_point := Vector2.ZERO
	func position_visible_to(_side: String, point: Vector2) -> bool:
		last_point = point
		return shown

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await animation_cases()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		await volleys(mode)
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failed": failed, "metrics": metrics}, "  "))
	get_tree().quit(0 if failed == 0 else 1)

func animation_cases() -> void:
	var world := VisibilityWorld.new()
	add_child(world)
	var host := Node2D.new()
	world.add_child(host)
	host.position = Vector2(100, 200)
	for image in ["PIFF", "PIFFPIFF", "MGUN-N", "MGUN-NE", "MGUN-E", "MGUN-SE", "MGUN-S", "MGUN-SW", "MGUN-W", "MGUN-NW"]:
		for bright in [false, true]:
			var at := Vector2(35, 55)
			var reference = Ra2Fx.play(host, at, image, 1.25, bright)
			reference.set_process(false)
			check(Ra2Fx.play_transient(host, at, image, 1.25, bright), image + " starts")
			var batch = host.get_node(Batch.NAME + ("Bright" if bright else "Normal"))
			batch.set_process(false)
			check(batch.entries.size() == 1 and batch.entries[0].point == at and batch.entries[0].scale == 1.25, image + " position and scale")
			check(world.last_point == host.to_global(at), image + " fog uses world position")
			check(batch.material == reference.material and batch.z_index == reference.z_index and batch.is_in_group("per_piece_fog_visibility"), image + " blend depth and individual fog")
			var entry = batch.entries[0]
			for step in ceili(float(reference.anim.count) / reference.fps * 120.0) + 2:
				reference._process(1.0 / 120.0)
				batch._process(1.0 / 120.0)
				if reference.is_queued_for_deletion():
					check(batch.entries.is_empty() and not batch.is_processing(), image + " exact expiry and idle sleep")
					break
				check(entry.frame == reference.frame, image + " exact frame " + str(step))
			reference.free()
	# Staggered shots keep separate clocks and stable order through compaction.
	Ra2Fx.play_transient(host, Vector2(1, 2), "MGUN-N")
	var batch = host.get_node(Batch.NAME + "Normal")
	batch.set_process(false)
	batch._process(0.3)
	Ra2Fx.play_transient(host, Vector2(3, 4), "MGUN-E")
	batch.set_process(false)
	batch._process(0.15)
	check(batch.entries.size() == 1 and batch.entries[0].point == Vector2(3, 4) and batch.entries[0].frame == 2, "independent clocks and stable compaction")
	world.shown = false
	batch._process(0.0)
	check(not batch.entries[0].visible, "fog hides an existing flash")
	world.shown = true
	batch._process(0.0)
	check(batch.entries[0].visible, "fog reveals an existing flash")
	# Exercise the actual draw callback without capturing a screenshot.
	var draws := [0]
	batch.draw.connect(func(): draws[0] += 1)
	batch.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(draws[0] > 0, "batched canvas draw executes")
	check(not Ra2Fx.play_transient(host, Vector2.ZERO, "MISSING_RIFLE_TEST"), "missing art preserves fallback")
	check(Ra2Fx.play_transient(host, Vector2.ZERO, "APMUZZLE") and host.get_children().any(func(n): return n is Ra2Fx and n.anim.image == "APMUZZLE"), "other weapons retain node playback")
	world.free()
	await get_tree().process_frame

func volleys(mode: String) -> void:
	var gi = battle.spawn_unit("E1", "ally", Vector2(1200, 1200))
	var victim = battle.spawn_unit("HTNK", "enemy", Vector2(1350, 1200))
	victim.hp = 10000000; victim.max_hp = victim.hp
	for deployed in [false, true]:
		gi._deployed = deployed
		var damages: Array = []
		for pass_id in 8:
			var hp_before: float = victim.hp
			var begin := Time.get_ticks_usec()
			for shot in 100: gi._fire_shot(victim)
			var elapsed := (Time.get_ticks_usec() - begin) / 1000.0
			var nodes := 0
			var animations := 0
			for child in battle.effects_root.get_children():
				if child is Batch:
					nodes += 1
					animations += child.entries.size()
					child._process(10.0)
				else: child.queue_free()
			check(animations == 200 and nodes <= 2, mode + " 100 shots retain 200 muzzle/impact animations in bounded nodes", {"animations": animations, "nodes": nodes})
			damages.append(hp_before - victim.hp)
			metrics.append({"mode": mode, "deployed": deployed, "pass": pass_id, "shots_100_ms": elapsed, "damage": hp_before - victim.hp})
			await get_tree().process_frame
		check(damages.all(func(value): return is_equal_approx(value, damages[0])) and damages[0] > 0, mode + " sustained shots keep damage timing and amount")
