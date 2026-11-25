extends VBoxContainer
## Shared menu and in-battle camera settings. Persist only when a drag finishes.
var slider: HSlider
var readout: Label
var edge: CheckBox

func _ready() -> void:
	name = "CameraControls"
	add_theme_constant_override("separation", 6)
	edge = CheckBox.new()
	edge.text = "边缘滚屏"
	edge.set_pressed_no_signal(MetaProgress.edge_scroll)
	edge.toggled.connect(MetaProgress.set_edge_scroll)
	add_child(edge)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(UiKit.make_label("镜头速度", 14, UiKit.COL_TEXT))
	readout = UiKit.make_label("", 14, UiKit.COL_OK)
	row.add_child(readout)
	slider = HSlider.new()
	slider.min_value = 10
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 24)
	slider.value = MetaProgress.scroll_speed
	slider.value_changed.connect(_preview)
	slider.drag_ended.connect(_commit_drag)
	add_child(slider)
	var reset := UiKit.make_button("恢复默认 · 1.50 倍", 13)
	reset.pressed.connect(func(): slider.value = 50)
	add_child(reset)
	var hint := UiKit.make_label("边缘和方向键共用，立即生效并保存。\n上移可贴资源栏下沿，右移可贴生产面板左侧。\n也可按住右键或中键拖动地图。", 12, UiKit.COL_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	MetaProgress.camera_settings_changed.connect(_sync)
	_sync()

func _preview(value: float) -> void:
	MetaProgress.set_scroll_speed(roundi(value), not slider.is_dragging())

func _commit_drag(changed: bool) -> void:
	if changed: MetaProgress.save()

func _sync() -> void:
	edge.set_pressed_no_signal(MetaProgress.edge_scroll)
	slider.set_value_no_signal(MetaProgress.scroll_speed)
	readout.text = "%.2f 倍 · %d 像素/秒" % [MetaProgress.scroll_px_per_sec() / 780.0, roundi(MetaProgress.scroll_px_per_sec())]
