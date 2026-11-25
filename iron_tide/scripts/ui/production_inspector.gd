extends PanelContainer
## Sidebar-owned details: hover never creates a window over the battlefield.

signal folded_changed(value: bool)

const UnitIcon = preload("res://scripts/ui/unit_icon.gd")
var title: Label
var status: Label
var description: RichTextLabel
var fold_button: Button
var icon
var _source: WeakRef
var _folded := false
# Keep shaped text for recently inspected cards; live text still refreshes below.
const DESCRIPTION_CACHE_LIMIT := 24
var _description_host: VBoxContainer
var _idle_description: RichTextLabel
var _descriptions: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = 156
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.09, 0.97)
	style.border_color = Color(0.22, 0.52, 0.64)
	style.border_width_top = 2
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 7)
	add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	body.add_child(header)
	icon = UnitIcon.new()
	icon.custom_minimum_size = Vector2(40, 32)
	icon.show_status = false
	icon.animate = false
	header.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 0)
	header.add_child(labels)
	title = UiKit.make_label("", 13, UiKit.RA_CYAN)
	title.clip_text = true
	labels.add_child(title)
	status = UiKit.make_label("", 11, UiKit.COL_GOLD)
	status.clip_text = true
	labels.add_child(status)
	fold_button = UiKit.ra_button(11, 27)
	fold_button.text = "收起"
	fold_button.tooltip_text = "收起单位简介，释放生产列表空间"
	fold_button.focus_mode = Control.FOCUS_NONE
	fold_button.custom_minimum_size = Vector2(52, 27)
	fold_button.pressed.connect(func():
		_set_folded(not _folded)
		folded_changed.emit(_folded))
	header.add_child(fold_button)
	var close_button := UiKit.ra_button(11, 27)
	close_button.name = "CloseProductionDetails"
	close_button.text = "关闭"
	close_button.tooltip_text = "隐藏生产详情栏，可在设置中重新打开"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(DisplayPreferences.set_show_production_details.bind(false))
	header.add_child(close_button)
	_description_host = body
	description = _make_description()
	_idle_description = description
	clear()

func _set_folded(value: bool) -> void:
	_folded = value
	if is_instance_valid(description): description.visible = not value
	if is_instance_valid(fold_button):
		fold_button.text = "展开" if value else "收起"
		fold_button.tooltip_text = "展开单位简介" if value else "收起单位简介，释放生产列表空间"
	custom_minimum_size.y = 64.0 if value else 156.0
	queue_sort()

func _make_description() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.custom_minimum_size.y = 86
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 12)
	label.add_theme_color_override("default_color", UiKit.RA_TEXT)
	label.bbcode_enabled = false
	label.scroll_following = false
	if is_instance_valid(description): label.size = description.size
	_description_host.add_child(label)
	label.visible = not _folded
	return label

func _select_description(control: Control) -> void:
	description.hide()
	var id := control.get_instance_id()
	for key in _descriptions.keys():
		if _descriptions[key].source.get_ref() == null:
			_descriptions[key].label.queue_free()
			_descriptions.erase(key)
	if _descriptions.has(id):
		preload("res://scripts/world/battle_call_counters.gd").iterations(81, 1)
		var entry: Dictionary = _descriptions[id]
		_descriptions.erase(id)
		_descriptions[id] = entry
		description = entry.label
	else:
		if _descriptions.size() >= DESCRIPTION_CACHE_LIMIT:
			var oldest = _descriptions.keys()[0]
			_descriptions[oldest].label.queue_free()
			_descriptions.erase(oldest)
		description = _make_description()
		_descriptions[id] = {"source": weakref(control), "label": description}
	description.visible = not _folded

func bind(button: Button, caption: String, data: Dictionary = {}) -> void:
	button.docked_details = true
	button.set_meta("docked_details_bound", true)
	button.set_meta("inspector_title", caption)
	button.set_meta("inspector_data", data)
	button.mouse_entered.connect(func(): inspect(button))

func bind_hint(control: Control, caption: String, text: String, data: Dictionary = {}) -> void:
	control.tooltip_text = ""
	control.set_meta("inspector_title", caption)
	control.set_meta("inspector_data", data)
	control.set_meta("inspector_hint", text)
	control.mouse_entered.connect(func(): inspect(control))

func _highlight(control, value: bool) -> void:
	if is_instance_valid(control) and control.has_meta("docked_details_bound"):
		control.detail_highlight = value

func inspect(button: Control) -> void:
	if not DisplayPreferences.show_production_details: return
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(81)
	var previous = _source.get_ref() if _source != null else null
	if previous == button:
		refresh()
		return
	_highlight(previous, false)
	_source = weakref(button)
	_highlight(button, true)
	var data: Dictionary = button.get_meta("inspector_data", {})
	icon.visible = not data.is_empty()
	if icon.visible:
		icon.setup(data, Color.WHITE, 1, 1.0, true)
	title.text = str(button.get_meta("inspector_title", "生产情报"))
	_select_description(button)
	refresh()
	description.scroll_to_line(0)

func refresh() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(82)
	if _source == null: return
	var button = _source.get_ref()
	if not is_instance_valid(button) or not button.is_inside_tree():
		clear()
		return
	var text: String = str(button.get_meta("inspector_hint")) if button.has_meta("inspector_hint") else button.tooltip_text
	if text.begins_with(title.text + "\n"):
		text = text.substr(title.text.length() + 1)
	var data: Dictionary = button.get_meta("inspector_data", {})
	if not data.is_empty():
		var summary := EntityDescription.text(data)
		var details := text.replace(summary, "").strip_edges()
		text = "简介　" + summary
		if not details.is_empty(): text += "\n\n" + details
	# Avoid resetting the reader's scroll position on each HUD tick.
	if description.text != text:
		preload("res://scripts/world/battle_call_counters.gd").iterations(82, text.length())
		var scroll := description.get_v_scroll_bar().value
		description.text = text
		description.get_v_scroll_bar().value = scroll
	var state = button.get_meta("inspector_status") if button.has_meta("inspector_status") else null
	status.text = str(state.text).replace("\n", " · ") if is_instance_valid(state) else "操作说明"
	status.modulate = Color(1.0, 0.65, 0.35) if button is Button and button.disabled else Color.WHITE

func clear() -> void:
	var previous = _source.get_ref() if _source != null else null
	_highlight(previous, false)
	_source = null
	if not is_instance_valid(title): return
	for entry in _descriptions.values():
		entry.label.hide()
		entry.label.queue_free()
	_descriptions.clear()
	description = _idle_description
	description.visible = not _folded
	icon.hide()
	title.text = "生产情报"
	status.text = "悬停查看 · 说明固定在此处"
	status.modulate = Color.WHITE
	description.text = "左键：生产／放置就绪建筑\nShift + 左键／长按：批量生产单位\n右键：暂停；已暂停时再次右键取消\n无法生产时，点击卡片查看解锁路线。"
