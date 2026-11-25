extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	Music.set_enabled(true)
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_window().size = size
		var settings = load("res://scenes/settings.tscn").instantiate()
		add_child(settings)
		await picture("settings-" + str(size.x))
		inspect(settings, "settings " + str(size.x))
		settings.free()
		start(MatchRules.RA2)
		screen.hud.settings_panel.show()
		await picture("battle-" + str(size.x))
		inspect(screen.hud.settings_panel, "battle " + str(size.x))
		await finish()
	Music.stop()
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func inspect(node: Node, label: String) -> void:
	var controls := find_controls(node)
	check(controls != null, label + " shared music settings exist")
	if controls == null: return
	var viewport := get_viewport().get_visible_rect()
	for widget in [controls.toggle, controls.slider, controls.title, controls.next_button]:
		check(widget.is_visible_in_tree() and viewport.encloses(widget.get_global_rect()), label + " music control visible within viewport: " + widget.get_class())
	check(controls.next_button.text == "重播" and controls.next_button.disabled == (Music.tracks.is_empty() or Music.context != "battle"), label + " replay requires an active battle and a local track")
	if Music.context != "battle" and not Music.tracks.is_empty():
		check(controls.title.text.contains("开战后播放"), label + " menu explains playback timing")

func find_controls(node: Node) -> Node:
	if node.get_script() == preload("res://scripts/ui/music_controls.gd"):
		return node
	for child in node.get_children():
		var match_node := find_controls(child)
		if match_node != null: return match_node
	return null

func picture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
