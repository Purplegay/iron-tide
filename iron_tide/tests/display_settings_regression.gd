extends "res://tests/input_ownership_regression.gd"

const Controls = preload("res://scripts/ui/display_controls.gd")
const Preferences = preload("res://scripts/autoload/display_preferences.gd")

func settle() -> void:
	for i in 5: await get_tree().process_frame

func find_controls(node: Node):
	if node.get_script() == Controls: return node
	for child in node.get_children():
		var result = find_controls(child)
		if result != null: return result
	return null

func exercise_mode(mode: String) -> void:
	if DisplayServer.get_name() != "headless":
		check(get_window().mode == Window.MODE_WINDOWED, "isolated runner keeps its windowed mode")
	if mode == MatchRules.RA2 and DisplayServer.get_name() == "headless":
		await exercise_preferences()
	for dimensions in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		stage.size = dimensions
		var settings = load("res://scenes/settings.tscn").instantiate()
		stage.add_child(settings)
		await settle()
		var controls = find_controls(settings)
		check(controls != null, "main settings contain display controls")
		controls.details_toggle.button_pressed = false
		check(not DisplayPreferences.show_production_details, "main settings hide the production dock")
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(controls.get_global_rect()), "main display controls fit " + str(dimensions), str(controls.get_global_rect()))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-menu-" + str(dimensions.y) + ".png"))
		settings.free()
		BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 7600})
		screen = load("res://scenes/battle.tscn").instantiate()
		stage.add_child(screen)
		battle = screen.battle
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
		screen.hud.set_process(false)
		screen.hud.settings_panel.show()
		await settle()
		controls = find_controls(screen.hud.settings_panel)
		check(controls != null, "battle settings contain same display controls")
		check(not controls.details_toggle.button_pressed and not screen.hud._production_inspector.visible, "new battle honors the saved hidden dock")
		controls.details_toggle.button_pressed = true
		check(screen.hud._production_inspector.visible, "battle settings reopen the dock")
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(screen.hud.settings_panel.get_global_rect()), "battle settings fit " + str(dimensions), str(screen.hud.settings_panel.get_global_rect()))
		check(controls.resolution_select.disabled == DisplayPreferences.fullscreen, "native fullscreen clearly disables window size")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-battle-" + str(dimensions.y) + ".png"))
		screen.free()
		await get_tree().process_frame
	if mode == MatchRules.EXTENDED and DisplayServer.get_name() != "headless":
		await exercise_native_window()

func exercise_native_window() -> void:
	# Exercise real native resizing in an offscreen work area with monitor dimensions.
	var window := get_window()
	var settings = load("res://scenes/settings.tscn").instantiate()
	window.add_child(settings)
	await settle()
	var controls = find_controls(settings)
	var available := DisplayServer.screen_get_usable_rect(window.current_screen)
	available.position = Vector2i(-8000, -8000)
	var keep_offscreen := func(): window.position = available.position
	RenderingServer.frame_pre_draw.connect(keep_offscreen)
	for index in [2, 3, 0, 4, 1, 2]:
		controls.resolution_select.show_popup()
		await settle()
		var popup: PopupMenu = controls.resolution_select.get_popup()
		popup.set_focused_item(index)
		var accept := InputEventKey.new()
		accept.keycode = KEY_ENTER
		accept.pressed = true
		for item in popup.item_count: popup.set_item_accelerator(item, KEY_NONE)
		popup.set_item_accelerator(index, KEY_ENTER)
		var before_size := window.size
		popup.activate_item_by_event(accept)
		check(window.size == before_size, "native resize waits until popup activation returns")
		window.position = available.position
		await settle()
		var expected := Preferences.fitted_size(DisplayPreferences.RESOLUTIONS[index], available.size)
		check(window.size == expected, "native window applies selected size " + str(index), str(window.size))
		check(window.size == DisplayServer.window_get_size(window.get_window_id()) and not DisplayPreferences.applying, "OS client area and viewport agree after applying")
		check(not popup.visible and DisplayPreferences.resolution_index == index, "real dropdown accepts selected resolution")
		check(available.encloses(Rect2i(window.position, window.size)), "native window remains inside supplied work area")
		check(window.position.x < 0 and window.position.y < 0 and window.mode == Window.MODE_WINDOWED, "native size check remains offscreen and windowed")
		await RenderingServer.frame_post_draw
		var picture := window.get_texture().get_image()
		picture.save_png(output_dir.path_join("native-" + str(index) + ".png"))
		check(picture.get_size() == window.size, "root framebuffer follows native window", str(picture.get_size()))
		var background: Color = settings.get_child(0).color
		for corner in [Vector2i(8, 8), Vector2i(picture.get_width() - 9, 8), Vector2i(8, picture.get_height() - 9), picture.get_size() - Vector2i(9, 9)]:
			var pixel := picture.get_pixelv(corner)
			check(absf(pixel.r - background.r) < 0.015 and absf(pixel.g - background.g) < 0.015, "settings fills resized framebuffer corner", {"point": str(corner), "color": str(pixel), "root": str(window.get_visible_rect()), "settings": str(settings.get_global_rect())})
		var checkbox: CheckBox = settings.find_children("*", "CheckBox", true, false)[0]
		var was_pressed := checkbox.button_pressed
		var at := window.get_final_transform() * checkbox.get_global_rect().get_center()
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = at
			click.global_position = at
			window.push_input(click, false)
		check(checkbox.button_pressed != was_pressed, "native pixel click hits checkbox after resize")
	for index in [0, 4, 1]:
		DisplayPreferences.set_resolution(index)
	await settle()
	check(DisplayPreferences.resolution_index == 1 and window.size == Preferences.fitted_size(Vector2i(1600, 900), available.size), "rapid changes apply only the latest resolution")
	check(not DisplayPreferences.applying, "rapid change finishes without a stale pending request")
	RenderingServer.frame_pre_draw.disconnect(keep_offscreen)
	settings.free()

func exercise_preferences() -> void:
	check(not DisplayPreferences.fullscreen and DisplayPreferences.resolution_index == 3, "fresh profile starts windowed at 1440p")
	var first = Controls.new()
	var second = Controls.new()
	stage.add_child(first)
	stage.add_child(second)
	check(first.resolution_select.item_count == 5, "five standard resolution options")
	first.mode_select.item_selected.emit(1)
	check(not DisplayPreferences.fullscreen and not second.resolution_select.disabled, "window selection updates both panels")
	for index in 5:
		first.resolution_select.item_selected.emit(index)
		check(DisplayPreferences.resolution_index == index and second.resolution_select.selected == index, "resolution selection synchronizes " + str(index))
		var restored = Preferences.new()
		add_child(restored)
		check(restored.resolution_index == index and not restored.fullscreen, "fresh preferences instance restores saved choice " + str(index))
		restored.free()
	var before := FileAccess.get_file_as_string(DisplayPreferences.SETTINGS_PATH)
	DisplayPreferences.set_resolution(-1)
	DisplayPreferences.set_resolution(99)
	check(before == FileAccess.get_file_as_string(DisplayPreferences.SETTINGS_PATH), "invalid selection cannot corrupt saved configuration")
	first.mode_select.item_selected.emit(0)
	check(DisplayPreferences.fullscreen and second.resolution_select.disabled, "fullscreen disables window-only selection in both panels")
	DisplayPreferences.reload()
	check(DisplayPreferences.fullscreen, "new explicit fullscreen selection survives reload")
	var config := ConfigFile.new()
	config.set_value("display", "width", 1920)
	config.set_value("display", "height", 1080)
	config.set_value("display", "fullscreen", true)
	config.save(DisplayPreferences.SETTINGS_PATH)
	DisplayPreferences.reload()
	check(not DisplayPreferences.fullscreen and DisplayPreferences.resolution_index == 2, "legacy fullscreen migrates to windowed while preserving resolution")
	config.set_value("display", "version", DisplayPreferences.SETTINGS_VERSION)
	config.set_value("display", "width", "invalid")
	config.set_value("display", "height", -1)
	config.set_value("display", "fullscreen", "invalid")
	config.save(DisplayPreferences.SETTINGS_PATH)
	DisplayPreferences.reload()
	check(DisplayPreferences.resolution_index == 3 and not DisplayPreferences.fullscreen, "invalid stored types recover to 1440p windowed defaults")
	config.set_value("display", "width", 777)
	config.set_value("display", "height", 555)
	config.set_value("display", "fullscreen", false)
	config.save(DisplayPreferences.SETTINGS_PATH)
	DisplayPreferences.reload()
	check(DisplayPreferences.resolution_index == 3 and not DisplayPreferences.fullscreen, "unknown stored dimensions fall back without losing valid mode")
	for area in [Vector2i(1280, 720), Vector2i(2560, 1392), Vector2i(3840, 2112)]:
		for requested in DisplayPreferences.RESOLUTIONS:
			var fitted := Preferences.fitted_size(requested, area)
			check(fitted.x <= area.x - 64 and fitted.y <= area.y - 80 and fitted.x <= requested.x and fitted.y <= requested.y, "window fits usable display " + str(area) + " request " + str(requested))
			check(absf(float(fitted.x) / fitted.y - 16.0 / 9.0) < 0.005, "window fit preserves 16:9")
	DisplayPreferences.set_resolution(3)
	DisplayPreferences.set_fullscreen(false)
	first.free()
	second.free()
