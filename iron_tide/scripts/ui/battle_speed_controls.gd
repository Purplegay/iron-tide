extends VBoxContainer
## Shared between the main menu and the battle settings panel.

var toggles: Dictionary = {}

func _ready() -> void:
	name = "BattleSpeedControls"
	add_theme_constant_override("separation", 4)
	add_child(UiKit.make_label("战斗倍速", 15, UiKit.COL_TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for speed in DisplayPreferences.BATTLE_SPEEDS:
		var toggle := CheckBox.new()
		toggle.text = "×" + str(speed).trim_suffix(".0")
		toggle.add_theme_font_size_override("font_size", 14)
		row.add_child(toggle)
		toggles[speed] = toggle
		toggle.toggled.connect(_toggle_speed.bind(speed))
	var hint := UiKit.make_label("倍速按钮和快捷键只切换已勾选的档位，至少保留一档。", 12, UiKit.COL_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	DisplayPreferences.battle_speeds_changed.connect(_sync)
	_sync()

func _toggle_speed(enabled: bool, speed: float) -> void:
	DisplayPreferences.set_battle_speed_enabled(speed, enabled)
	_sync()

func _sync() -> void:
	for speed in toggles:
		var toggle: CheckBox = toggles[speed]
		var enabled := DisplayPreferences.battle_speeds.has(speed)
		toggle.set_pressed_no_signal(enabled)
		toggle.disabled = enabled and DisplayPreferences.battle_speeds.size() == 1
		toggle.tooltip_text = "至少保留一档倍速。" if toggle.disabled else ""
