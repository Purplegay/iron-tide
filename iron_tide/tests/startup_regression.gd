extends Node
## Test-only autoload: traverse the normal main menu and lobby, without a preloaded Battle class.
var checks: Array = []
var output_dir := ""

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	get_tree().create_timer(25.0).timeout.connect(func(): finish(false))
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks.append({"passed": ok, "name": label})
	return ok

func press(label: String) -> bool:
	for button in get_tree().current_scene.find_children("*", "Button", true, false):
		if button.text == label:
			button.pressed.emit()
			return true
	return false

func run() -> void:
	await get_tree().process_frame
	if not check(get_tree().current_scene.scene_file_path == "res://scenes/main.tscn", "normal main scene loaded"): finish(false); return
	if not check(press("战 役"), "real main menu button opens lobby"): finish(false); return
	await get_tree().process_frame
	await get_tree().process_frame
	if not check(get_tree().current_scene.scene_file_path == "res://scenes/lobby.tscn", "real lobby loaded"): finish(false); return
	if not check(press("开始遭遇战"), "real lobby button starts battle"): finish(false); return
	await get_tree().process_frame
	await get_tree().process_frame
	var screen = get_tree().current_scene
	if not check(screen.scene_file_path == "res://scenes/battle.tscn" and is_instance_valid(screen.get("battle")), "Battle constructed successfully"): finish(false); return
	check(is_instance_valid(screen.get("hud")), "HUD constructed successfully")
	check(screen.battle.units.size() > 0 and screen.battle.buildings.size() > 0, "real starting actors exist")
	var soldier = screen.battle.spawn_unit("E1", "ally", Vector2(800, 800))
	check(soldier.ability_at(0) != null and soldier.ability_at(0).id == "allied_deploy", "new allied abilities available after launcher import")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	picture.save_png(output_dir.path_join("battle.png"))
	var lit := 0
	for y in range(100, picture.get_height() - 100, 40):
		for x in range(100, picture.get_width() - 100, 40):
			var color := picture.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.15: lit += 1
	check(lit > 100, "rendered battle is not a black frame")
	finish(true)

func finish(completed: bool) -> void:
	var failed := checks.filter(func(row): return not row.passed).size()
	if not completed and failed == 0: failed = 1
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "completed": completed}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)
