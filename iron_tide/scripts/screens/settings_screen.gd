extends Control
## 设置（B2）：边缘滚屏开关 / 滚屏速度 / 事件字幕。
## 入口：主菜单「设 置」。改动即写 MetaProgress 并落盘（user://iron_tide_meta.json）。
## 滚屏速度以当前基准（50 = 1170 px/s，原速度的 1.5 倍）线性缩放，见 MetaProgress.scroll_px_per_sec()。

@onready var kit = UiKit



func _ready() -> void:
	Music.set_context("menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func add_name_setting(parent:VBoxContainer) -> void:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	row.add_child(kit.make_label("指挥官名字",15,kit.COL_TEXT))
	var input:=LineEdit.new()
	input.name="CommanderNameInput"
	input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	input.text=MetaProgress.commander_alias
	var login:=MetaProgress.system_login()
	input.placeholder_text="输入名字" if login.is_empty() else "默认使用 "+login
	row.add_child(input)
	var save_button:=kit.make_button("保存名字",15)
	row.add_child(save_button)
	var feedback:=kit.make_label("",13,kit.COL_GOLD)
	parent.add_child(feedback)
	feedback.visible=false
	var apply:=func():
		if MetaProgress.set_commander_alias(input.text):
			input.text=MetaProgress.commander_alias
			var current:=MetaProgress.commander_name()
			feedback.text="尚未起名" if current.is_empty() else "当前指挥官："+current
		else:feedback.text="名字未能保存，请重试。"
		feedback.show()
	save_button.pressed.connect(apply)
	input.text_submitted.connect(func(_value:String):apply.call())

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.065)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)

	var box := kit.make_panel(Color(0.07, 0.085, 0.115, 0.94), Color(0.3, 0.5, 0.72))
	box.custom_minimum_size = Vector2(580, 430)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)

	var t1 := kit.make_label("设 置", 30, kit.COL_ACCENT_2)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t1)
	var t2 := kit.make_label("操控手感 · 显示 · 背景音乐", 13, kit.COL_GOLD)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t2)
	vb.add_child(kit.divider())

	add_name_setting(vb)
	vb.add_child(preload("res://scripts/ui/camera_controls.gd").new())

	# —— 事件字幕 ——
	var c3 := HBoxContainer.new()
	c3.add_theme_constant_override("separation", 12)
	c3.add_child(kit.make_label("事件字幕", 15, kit.COL_TEXT))
	var chk2 := CheckBox.new()
	chk2.text = "显示战斗事件字幕"
	chk2.button_pressed = MetaProgress.subtitles
	chk2.add_theme_font_size_override("font_size", 14)
	chk2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk2.toggled.connect(func(on: bool) -> void: MetaProgress.set_subtitles(on))
	c3.add_child(chk2)
	vb.add_child(c3)

	vb.add_child(preload("res://scripts/ui/display_controls.gd").new())
	vb.add_child(preload("res://scripts/ui/model_display_controls.gd").new())
	vb.add_child(preload("res://scripts/ui/music_controls.gd").new())
	preload("res://scripts/ui/battle_hotkeys.gd").add_button(vb)
	vb.add_child(kit.hsep(6))
	vb.add_child(kit.hsep(4))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var bback := kit.make_button("返 回 主 菜 单", 15)
	bback.custom_minimum_size = Vector2(240, 42)
	bback.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(bback)
