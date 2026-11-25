extends CanvasLayer
## Shared battle/menu slot browser. Opening is modal and preserves the previous pause state.
var battle = null
var root: Control
var slots_box: VBoxContainer
var status: Label
var confirmation: ConfirmationDialog
var _was_paused := false
var _battle_was_paused := false
var _action := ""
var _slot := ""
var slot_buttons: Dictionary = {}

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := UiKit.make_panel(UiKit.COL_PANEL_2)
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiKit.make_label("对局存档", 23, UiKit.COL_ACCENT_2))
	box.add_child(UiKit.make_label("每 60 秒自动保存 · F5 快存 · F9 读档 · 读取后空格继续", 13, UiKit.COL_DIM))
	slots_box = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	box.add_child(slots_box)
	status = UiKit.make_label("", 13, UiKit.COL_WARN)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	if is_instance_valid(battle):
		var suspend_button := UiKit.make_button("快速保存并返回主菜单")
		suspend_button.tooltip_text = "保存后返回主菜单。下次可以接着打，这次离开不计胜负。"
		suspend_button.pressed.connect(func(): request_action("suspend", "quick"))
		box.add_child(suspend_button)
	var close_button := UiKit.make_button("返回游戏" if is_instance_valid(battle) else "返回主菜单")
	close_button.pressed.connect(close)
	box.add_child(close_button)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "确认存档操作"
	confirmation.ok_button_text = "确认"
	confirmation.cancel_button_text = "取消"
	confirmation.confirmed.connect(_confirm)
	add_child(confirmation)
	root.hide()

func open() -> void:
	if root.visible: return
	_was_paused = get_tree().paused
	if is_instance_valid(battle):
		_battle_was_paused = battle.paused
		battle.cancel_pointer_gestures()
		battle.paused = true
	get_tree().paused = true
	root.show()
	status.text = ""
	refresh()

func close() -> void:
	confirmation.hide()
	root.hide()
	get_tree().paused = _was_paused
	if is_instance_valid(battle): battle.paused = _battle_was_paused

func refresh() -> void:
	for child in slots_box.get_children(): child.free()
	slot_buttons.clear()
	for slot in BattleSaves.SLOTS:
		var result: Dictionary = BattleSaves.read_slot(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slots_box.add_child(row)
		var text := UiKit.make_label(slot_caption(slot, result), 13, UiKit.COL_TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.x = 390
		row.add_child(text)
		var save_button := UiKit.make_button("保存", 14)
		save_button.disabled = slot == "auto" or not is_instance_valid(battle) or battle.ended
		save_button.pressed.connect(func(): request_action("save", slot))
		row.add_child(save_button)
		var load_button := UiKit.make_button("读取", 14)
		load_button.disabled = not result.ok
		load_button.pressed.connect(func(): request_action("load", slot))
		row.add_child(load_button)
		slot_buttons[slot] = {"save": save_button, "load": load_button, "caption": text}

func slot_caption(slot: String, result: Dictionary) -> String:
	var caption := BattleSaves.label(slot) + "  ·  "
	if result.ok:
		caption += "%s\n%s · %s · 资金 %d" % [result.info.time, "RA2" if result.info.mode == MatchRules.RA2 else "扩展", result.info.title, int(result.info.funds)]
	else: caption += result.message
	return caption

func request_action(action: String, slot: String) -> void:
	_action = action
	_slot = slot
	var occupied := FileAccess.file_exists(BattleSaves.slot_path(slot))
	if (action in ["save", "suspend"] and occupied) or (action == "load" and is_instance_valid(battle) and not battle.ended):
		confirmation.dialog_text = "覆盖「%s」？原存档会保留一份备份。" % BattleSaves.label(slot) if action in ["save", "suspend"] else "读取「%s」？当前对局尚未保存的进度将会丢失。" % BattleSaves.label(slot)
		confirmation.popup_centered(Vector2i(520, 140))
	else:
		_confirm()

func _confirm() -> void:
	var result: Dictionary
	if _action in ["save", "suspend"]:
		result = BattleSaves.save_slot(battle, _slot)
		if result.ok and slot_buttons.has(_slot):
			slot_buttons[_slot].caption.text = slot_caption(_slot, result)
			slot_buttons[_slot].load.disabled = false
		elif not result.ok:
			refresh()
		if result.ok and _action == "suspend":
			get_tree().paused = false
			BattleClock.leave_battle()
			if get_tree().change_scene_to_file("res://scenes/main.tscn") != OK:
				get_tree().paused = true
				result = BattleSaves.fail("存档成功，但无法返回主菜单")
	else:
		result = BattleSaves.load_into_scene(_slot)
	status.text = result.message

func _input(event: InputEvent) -> void:
	if not root.visible: return
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE and not confirmation.visible: close()
		get_viewport().set_input_as_handled()
