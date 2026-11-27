extends Node
## Saved display, HUD and battle preferences; fullscreen uses the monitor's native mode.

signal changed
signal battle_speeds_changed
const SETTINGS_PATH := "user://display_settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const BATTLE_SPEEDS: Array[float] = [1.0, 1.25, 1.5, 2.0, 3.0]
const DEFAULT_INDEX := 3
const SETTINGS_VERSION := 2
var resolution_index := DEFAULT_INDEX
var fullscreen := false
var show_production_details := true
var automatic_building_repair := false
var battle_speeds: Array[float] = BATTLE_SPEEDS.duplicate()
var campaign_growth := false
var campaign_difficulty := 1
var save_error: Error = OK
var applying := false
var _display_revision := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload()
	# Godot consumes its own window flags before get_cmdline_args(). Use an
	# explicit user override, and preserve our isolated runner's display setup.
	var isolated := str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("CodexIronTideValidation/")
	var overridden := "--keep-display" in OS.get_cmdline_user_args() or (isolated and not OS.get_environment("IRON_TIDE_REPORT_DIR").is_empty())
	if not overridden and DisplayServer.get_name() != "headless":
		apply_window()
	get_window().size_changed.connect(func(): changed.emit())

func reload() -> void:
	resolution_index = DEFAULT_INDEX
	fullscreen = false
	show_production_details = true
	automatic_building_repair = false
	campaign_growth = false
	campaign_difficulty = 1
	battle_speeds.assign(BATTLE_SPEEDS)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_speeds = config.get_value("battle", "speeds", [])
		if saved_speeds is Array:
			var enabled: Array[float] = []
			for speed in BATTLE_SPEEDS:
				if speed in saved_speeds: enabled.append(speed)
			if not enabled.is_empty(): battle_speeds = enabled
		var growth = config.get_value("campaign", "growth", false)
		if growth is bool: campaign_growth = growth
		var level = config.get_value("campaign", "difficulty", 1)
		if level is int and level in [0, 1, 2]: campaign_difficulty = level
		var repair = config.get_value("hud", "automatic_building_repair", false)
		if repair is bool: automatic_building_repair = repair
		var details = config.get_value("hud", "show_production_details", true)
		if details is bool: show_production_details = details
		var width = config.get_value("display", "width", 2560)
		var height = config.get_value("display", "height", 1440)
		if typeof(width) == TYPE_INT and typeof(height) == TYPE_INT:
			var index := RESOLUTIONS.find(Vector2i(width, height))
			if index >= 0: resolution_index = index
		# Earlier releases defaulted to fullscreen. Keep their resolution, but
		# require a new explicit mode choice before restoring fullscreen again.
		var version = config.get_value("display", "version", 0)
		var saved_mode = config.get_value("display", "fullscreen", false)
		if typeof(version) == TYPE_INT and version == SETTINGS_VERSION and typeof(saved_mode) == TYPE_BOOL:
			fullscreen = saved_mode
	changed.emit()
	battle_speeds_changed.emit()

func set_resolution(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size(): return
	resolution_index = index
	apply_window()
	save()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_window()
	save()

func set_show_production_details(enabled: bool) -> void:
	if show_production_details == enabled: return
	show_production_details = enabled
	save()

func set_automatic_building_repair(enabled: bool) -> void:
	if automatic_building_repair == enabled: return
	automatic_building_repair = enabled
	save()

func set_battle_speed_enabled(speed: float, enabled: bool) -> void:
	if speed not in BATTLE_SPEEDS or enabled == battle_speeds.has(speed): return
	if not enabled and battle_speeds.size() == 1: return
	if enabled:
		battle_speeds.append(speed)
		battle_speeds.sort()
	else:
		battle_speeds.erase(speed)
	save()
	battle_speeds_changed.emit()

func next_battle_speed(current: float) -> float:
	for speed in battle_speeds:
		if speed > current and not is_equal_approx(speed, current): return speed
	return battle_speeds[0]

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("battle", "speeds", battle_speeds)
	config.set_value("hud", "show_production_details", show_production_details)
	config.set_value("hud", "automatic_building_repair", automatic_building_repair)
	config.set_value("campaign", "growth", campaign_growth)
	config.set_value("campaign", "difficulty", campaign_difficulty)
	config.set_value("display", "version", SETTINGS_VERSION)
	config.set_value("display", "width", RESOLUTIONS[resolution_index].x)
	config.set_value("display", "height", RESOLUTIONS[resolution_index].y)
	config.set_value("display", "fullscreen", fullscreen)
	save_error = config.save(SETTINGS_PATH)
	changed.emit()

static func fitted_size(requested: Vector2i, available: Vector2i) -> Vector2i:
	# Reserve room for the title bar/borders, including displays smaller than 4K.
	var limit := Vector2i(maxi(1, available.x - 64), maxi(1, available.y - 80))
	var factor := minf(1.0, minf(float(limit.x) / requested.x, float(limit.y) / requested.y))
	return Vector2i(maxi(1, floori(requested.x * factor)), maxi(1, floori(requested.y * factor)))

func apply_window() -> void:
	if DisplayServer.get_name() == "headless": return
	_display_revision += 1
	applying = true
	# OptionButton emits item_selected inside PopupMenu activation. Let the
	# menu finish closing before changing its owning native window.
	_apply_window_deferred.call_deferred(_display_revision)

func _apply_window_deferred(revision: int) -> void:
	if revision != _display_revision: return
	var window := get_window()
	var target_mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if window.mode != target_mode:
		window.mode = target_mode
		# Windows delivers the mode transition through native resize messages.
		await get_tree().process_frame
		if revision != _display_revision: return
	if not fullscreen:
		var area := DisplayServer.screen_get_usable_rect(window.current_screen)
		apply_windowed(window, RESOLUTIONS[resolution_index], area)
	await get_tree().process_frame
	if revision != _display_revision: return
	# Reconcile the canvas and input transform with the actual client area
	# after native resize messages, rather than trusting the requested size.
	var actual := DisplayServer.window_get_size(window.get_window_id())
	if actual.x > 0 and actual.y > 0:
		window.size = actual
	applying = false
	changed.emit()

static func apply_windowed(window: Window, requested: Vector2i, area: Rect2i) -> void:
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window.size = fitted_size(requested, area.size)
	window.position = area.position + (area.size - window.size) / 2

func actual_size() -> Vector2i:
	var window := get_window()
	if DisplayServer.get_name() == "headless": return window.size
	return DisplayServer.window_get_size(window.get_window_id())

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	var window := get_window()
	set_fullscreen(window.mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN])
