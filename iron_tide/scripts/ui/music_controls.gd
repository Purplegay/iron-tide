extends VBoxContainer
## Shared by main-menu settings and the in-battle settings popover.
var toggle: CheckBox
var slider: HSlider
var percent: Label
var title: Label
var next_button: Button

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	add_child(row)
	toggle = CheckBox.new()
	toggle.text = "背景音乐"
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(toggle)
	next_button = UiKit.make_button("下一首", 12)
	row.add_child(next_button)
	title = UiKit.make_label("", 12, UiKit.COL_ACCENT_2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.tooltip_text = "进入地图先播放探索曲，首次交火后切至己方阵营战斗曲。"
	add_child(title)
	var volume_row := HBoxContainer.new()
	add_child(volume_row)
	slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(120, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "仅调整背景音乐，不影响单位语音和战斗音效"
	volume_row.add_child(slider)
	percent = UiKit.make_label("", 12, UiKit.COL_TEXT)
	percent.custom_minimum_size.x = 40
	volume_row.add_child(percent)
	toggle.toggled.connect(Music.set_enabled)
	slider.value_changed.connect(func(value): Music.set_volume(value / 100.0))
	next_button.pressed.connect(Music.skip_or_replay)
	Music.changed.connect(refresh)
	refresh()

func refresh() -> void:
	toggle.set_pressed_no_signal(Music.enabled)
	slider.set_value_no_signal(Music.volume * 100.0)
	slider.editable = Music.enabled
	percent.text = "%d%%" % roundi(Music.volume * 100.0)
	title.text = Music.current_title() if Music.enabled else "背景音乐已关闭"
	if Music.enabled and Music.context not in ["battle","camp"]:
		title.text = "远征营地或进入地图后播放"
	next_button.text = "下一首" if Music.stage=="explore" else "重播"
	next_button.disabled = not Music.enabled or Music.tracks.is_empty() or Music.context not in ["battle","camp"]
