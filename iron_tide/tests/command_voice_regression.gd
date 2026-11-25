extends Node
var checks: Array = []
var failed := 0
var capture := AudioEffectCapture.new()
var output := ""

func check(ok: bool, label: String, detail = null) -> void:
	checks.append({"passed": ok, "name": label, "detail": detail})
	if not ok:
		failed += 1
		print("FAIL ", label, " ", detail)

func reset() -> void:
	Ra2Sfx.stop_all()
	await get_tree().create_timer(0.2).timeout
	capture.clear_buffer()

func peak() -> float:
	await get_tree().create_timer(0.6).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	check(not frames.is_empty(), "real WASAPI mixer supplies frames")
	var value := 0.0
	for frame in frames: value = maxf(value, maxf(absf(frame.x), absf(frame.y)))
	return value

func _ready() -> void:
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise(mode, "E1")
		await exercise(mode, "GGI")
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "driver": AudioServer.get_output_device()}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func exercise(mode: String, unit_id: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 8000, "fog_of_war": false})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var battle = screen.battle
	battle.camera.position = Vector2(2200, 2200)
	battle.camera.zoom = Iso.cam_zoom(0.3)
	battle.camera.make_current()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var unit = battle.spawn_unit(unit_id, "ally", Vector2(3600, 2200))
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(3800, 2200))
	await get_tree().process_frame
	await get_tree().physics_frame
	mode += " " + unit_id
	var screen_pos: Vector2 = unit.get_global_transform_with_canvas().origin
	check(get_viewport().get_visible_rect().has_point(screen_pos), mode + " command source is still on screen at wide zoom", screen_pos)
	await reset()
	battle.select_unit(unit, false)
	battle._emit_selection()
	check(await peak() > 0.001, mode + " actual selection response audible away from camera center")
	await reset()
	battle._command_move(Vector2(3650, 2200))
	check(await peak() > 0.001, mode + " actual move response audible away from camera center")
	await reset()
	unit.set_deployed(true)
	await reset()
	battle.force_attack(target)
	check(unit.is_deployed() and not unit.has_move_order, mode + " deployed attack remains stationary")
	check(await peak() > 0.001, mode + " actual deployed attack response audible away from camera center")
	await reset()
	Ra2Sfx.play_voice(unit.data, "feedback", unit.global_position, 0)
	check(await peak() > 0.001, mode + " rejected command response audible away from camera center")
	await reset()
	Ra2Sfx.play_weapon({"report": "GrizzlyTankAttack"}, unit.global_position)
	check(await peak() < 0.0001, mode + " remote weapon effects still obey spatial attenuation")
	await reset()
	Ra2Sfx.play_voice(unit.data, "die", unit.global_position, 0)
	check(await peak() < 0.0001, mode + " remote death effects remain spatial")
	await reset()
	Ra2Sfx.play_eva("EVA_Building", "allied", 0)
	check(await peak() > 0.001, mode + " EVA building announcement remains audible")
	await reset()
	check(Ra2Sfx.play_voice(unit.data, "attack", unit.global_position, 1000), mode + " first command response accepted")
	check(not Ra2Sfx.play_voice(unit.data, "attack", unit.global_position, 1000), mode + " repeated command still throttled")
	await reset()
	if unit_id == "GGI":
		Ra2Sfx.play_weapon(unit.data.deployed_weapon, Vector2.INF)
		check(await peak() > 0.001, mode + " original missile launch has real PCM output")
		await reset()
	screen.free()
	await get_tree().process_frame
