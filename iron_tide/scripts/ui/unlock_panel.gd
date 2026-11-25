extends PanelContainer
## Persistent, read-only navigation for a requested production goal.

signal locate_requested(id: String)
signal return_requested
signal description_requested
signal close_requested
signal alternative_selected(token: String, id: String)

var route_buttons: Dictionary = {}
var alternative_buttons: Dictionary = {}
var back_button: Button
var close_button: Button
var message: Label
var _title: Label
var _scroll: ScrollContainer
var _routes: VBoxContainer
var _signature := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.12, 0.98)
	style.border_color = UiKit.RA_CYAN
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
		style.set_content_margin(side, 6)
	add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	_title = UiKit.make_label("", 13, UiKit.RA_CYAN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	header.add_child(_title)
	var info := UiKit.ra_button(12, 24)
	info.name = "UnlockDescriptionButton"
	info.text = "简介"
	info.pressed.connect(func(): description_requested.emit())
	header.add_child(info)
	close_button = UiKit.ra_button(12, 24)
	close_button.text = "关闭"
	close_button.pressed.connect(func(): close_requested.emit())
	header.add_child(close_button)
	message = UiKit.make_label("", 12, UiKit.RA_TEXT)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_routes = VBoxContainer.new()
	_routes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_routes.add_theme_constant_override("separation", 3)
	_scroll.add_child(_routes)
	back_button = UiKit.ra_button(12, 26)
	back_button.pressed.connect(func(): return_requested.emit())
	body.add_child(back_button)
	hide()

func present(source_name: String, guide: Dictionary) -> void:
	show()
	var signature := source_name + JSON.stringify(guide)
	if signature == _signature:
		return
	_signature = signature
	_title.text = "解锁目标：" + source_name
	_title.tooltip_text = _title.text
	back_button.text = "返回：" + source_name
	var steps: Array = guide.get("steps", [])
	message.text = "点击前置建筑，定位建造卡片" if not steps.is_empty() else str(guide.get("summary", ""))
	if not str(guide.get("restriction", "")).is_empty():
		message.text = str(guide.restriction) + "\n" + message.text
	if message.text.is_empty():
		message.text = "科技条件已满足，可返回生产栏"
	if not str(guide.get("notice", "")).is_empty():
		message.text = str(guide.notice)
	# Only rebuild when requirements change, not on every HUD refresh.
	route_buttons.clear()
	alternative_buttons.clear()
	for child in _routes.get_children():
		_routes.remove_child(child)
		child.queue_free()
	var groups: Array = guide.get("alternatives", [])
	_scroll.visible = not steps.is_empty() or not groups.is_empty()
	var row_count := steps.size()
	for group in groups:
		row_count += group.options.size() + 1
		var heading := UiKit.make_label(str(group.name) + "（任选其一）", 12, UiKit.RA_CYAN)
		_routes.add_child(heading)
		var buttons := ButtonGroup.new()
		buttons.allow_unpress = false
		for option in group.options:
			var token := str(group.token)
			var id := str(option.id)
			var button := UiKit.ra_button(12, 26)
			button.toggle_mode = true
			button.button_group = buttons
			button.button_pressed = id == str(group.selected)
			button.text = "%s%s · %s" % ["已选：" if button.button_pressed else "", option.name, option.state]
			button.clip_text = true
			button.disabled = not bool(option.can_choose)
			button.tooltip_text = str(option.reason) if button.disabled else "选择此解锁路线，不自动建造"
			button.pressed.connect(func(): alternative_selected.emit(token, id))
			button.gui_input.connect(func(event):
				if button.disabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					message.text = str(option.reason))
			_routes.add_child(button)
			alternative_buttons[token + ":" + id] = button
	if not groups.is_empty():
		_routes.add_child(UiKit.make_label("建造顺序（点击定位）", 12, UiKit.RA_CYAN))
		row_count += 1
	_scroll.custom_minimum_size.y = minf(140, row_count * 31)
	for step in steps:
		var id := str(step.id)
		var button := UiKit.ra_button(12, 28)
		button.text = "%s · %s" % [step.name, step.state]
		button.clip_text = true
		button.disabled = not bool(step.can_locate)
		button.tooltip_text = "查看：" + str(step.name) if not button.disabled else "选中基地车，在空地按 J 展开为建造场；没有基地车时，需要保有战车工厂和维修厂来生产"
		button.pressed.connect(func(): locate_requested.emit(id))
		_routes.add_child(button)
		route_buttons[id] = button
