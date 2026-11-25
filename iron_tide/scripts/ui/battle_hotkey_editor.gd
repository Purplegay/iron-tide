extends CanvasLayer
const Keys=preload("res://scripts/ui/battle_hotkeys.gd")
var waiting:=""
var message:Label
var buttons:Dictionary={}

func _ready() -> void:
	layer=110;process_mode=Node.PROCESS_MODE_ALWAYS;Keys.modal_count+=1
	var shade:=ColorRect.new();shade.color=Color(0.02,0.03,0.05,0.92);add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();shade.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	var column:=VBoxContainer.new();margin.add_child(column)
	column.add_child(UiKit.make_label("战斗快捷键",24,UiKit.COL_ACCENT_2))
	var hint:=UiKit.make_label("Shift＋空格显示或收起可见目标的血条；只有自己的单位和建筑显示数值。有护盾时盾条常显。点击指令后按一个单键。数字编队、方向滚屏、Ctrl+G、Ctrl+F、F11、Esc 与 Ctrl/Shift 鼠标组合保留。",14,UiKit.COL_TEXT)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(hint)
	message=UiKit.make_label("修改即保存；Shift 可继续配合技能和追加指令。",14,UiKit.COL_GOLD);column.add_child(message)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for id:String in Keys.ACTIONS:
		var button:=UiKit.make_button("",16);button.focus_mode=Control.FOCUS_NONE;list.add_child(button);buttons[id]=button
		button.pressed.connect(func():waiting=id;refresh();message.text="请按「%s」的新键；Esc 取消本次改键。"%Keys.ACTIONS[id][0])
	var row:=HBoxContainer.new();column.add_child(row)
	var reset:=UiKit.make_button("恢复默认");row.add_child(reset)
	reset.pressed.connect(func():
		waiting=""
		message.text="已恢复默认快捷键。" if Keys.save(Keys.defaults()) else "保存失败，原设置保持不变。"
		refresh())
	var close:=UiKit.make_button("完成／关闭");row.add_child(close);close.pressed.connect(queue_free)
	refresh()

func refresh() -> void:
	for id in buttons:buttons[id].text="%s　　%s"%[Keys.ACTIONS[id][0],"请按键…" if waiting==id else Keys.label(id)]

func _input(event:InputEvent) -> void:
	if not event is InputEventKey:return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:return
	if event.keycode==KEY_ESCAPE:
		if waiting.is_empty():queue_free()
		else:waiting="";message.text="已取消改键。";refresh()
		return
	if waiting.is_empty():return
	if event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed:
		message.text="请使用单键；组合键保留原有操作。";return
	var error:=Keys.assign(waiting,event.keycode)
	if not error.is_empty():message.text=error;return
	message.text="已保存：%s → %s"%[Keys.ACTIONS[waiting][0],Keys.label(waiting)];waiting="";refresh()

func _exit_tree() -> void:
	Keys.modal_count=maxi(0,Keys.modal_count-1)
