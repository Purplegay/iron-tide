extends VBoxContainer
## Shared display controls for the main menu and the battle settings panel.

var mode_select: OptionButton
var resolution_select: OptionButton
var status: Label
var details_toggle: CheckBox

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var mode_row := HBoxContainer.new()
	add_child(mode_row)
	var mode_label := UiKit.make_label("显示模式", 13, UiKit.COL_TEXT)
	mode_label.custom_minimum_size.x = 82
	mode_row.add_child(mode_label)
	mode_select = OptionButton.new()
	mode_select.name = "DisplayMode"
	mode_select.add_item("全屏（原生分辨率）")
	mode_select.add_item("窗口")
	mode_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(mode_select)
	var resolution_row := HBoxContainer.new()
	add_child(resolution_row)
	var resolution_label := UiKit.make_label("窗口分辨率", 13, UiKit.COL_TEXT)
	resolution_label.custom_minimum_size.x = 82
	resolution_row.add_child(resolution_label)
	resolution_select = OptionButton.new()
	resolution_select.name = "WindowResolution"
	for dimensions in DisplayPreferences.RESOLUTIONS:
		resolution_select.add_item("%d × %d（%dp）" % [dimensions.x, dimensions.y, dimensions.y])
	resolution_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_row.add_child(resolution_select)
	status = UiKit.make_label("", 11, UiKit.COL_DIM)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	details_toggle = CheckBox.new()
	details_toggle.name = "ShowProductionDetails"
	details_toggle.text = "显示生产详情栏"
	details_toggle.toggled.connect(DisplayPreferences.set_show_production_details)
	add_child(details_toggle)
	mode_select.item_selected.connect(func(index): DisplayPreferences.set_fullscreen(index == 0))
	resolution_select.item_selected.connect(DisplayPreferences.set_resolution)
	DisplayPreferences.changed.connect(refresh)
	refresh()

func refresh() -> void:
	details_toggle.set_pressed_no_signal(DisplayPreferences.show_production_details)
	mode_select.select(0 if DisplayPreferences.fullscreen else 1)
	resolution_select.select(DisplayPreferences.resolution_index)
	resolution_select.disabled = DisplayPreferences.fullscreen
	var actual := DisplayPreferences.actual_size()
	status.text = "实际输出 %d × %d · F11 切换全屏／窗口\n" % [actual.x, actual.y]
	status.text += "全屏使用显示器原生分辨率；切换窗口后可选择尺寸。" if DisplayPreferences.fullscreen else "选择自动保存；尺寸超过屏幕时会按比例缩小。"
	if DisplayPreferences.applying:
		status.text += "\n正在应用显示设置…"
	if DisplayPreferences.save_error != OK:
		status.text += "\n设置保存失败，本次生效但无法记住。"
