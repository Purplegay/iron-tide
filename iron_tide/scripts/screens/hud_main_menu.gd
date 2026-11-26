extends Control
## 主菜单。入口：战役（选关） / 驻防（局外养成） / 后台 / 退出。

const MenuIcon = preload("res://scripts/ui/progression_icon.gd")

@onready var kit = UiKit

var title_ctrl: Control
var save_panel

func _ready() -> void:
	var missing := GameData.missing_battle_resources()
	if not missing.is_empty():
		var dialog := AcceptDialog.new()
		dialog.title = "游戏资源不完整"
		dialog.dialog_text = "无法进入战场。请将完整游戏包解压到新文件夹，再从那里启动游戏。\n\n缺少或无法读取的文件：\n" + "\n".join(missing)
		dialog.ok_button_text = "退出游戏"
		dialog.confirmed.connect(get_tree().quit)
		dialog.canceled.connect(get_tree().quit)
		add_child(dialog)
		dialog.popup_centered()
		return
	Music.set_context("menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.065)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var lines := Control.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.draw.connect(_draw_bg.bind(lines))
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lines)

	# 主面板（用 CenterContainer 保证居中）
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)

	var box := kit.make_panel(Color(0.07, 0.085, 0.115, 0.9), Color(0.3, 0.5, 0.72))
	box.custom_minimum_size = Vector2(430, 600)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)

	var t1 := kit.make_label("IRON TIDE", 40, kit.COL_ACCENT_2)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t1)
	var t2 := kit.make_label("铁 潮 · 即时战略", 15, kit.COL_GOLD)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t2)
	vb.add_child(kit.divider())

	const CostIcon=preload("res://scripts/ui/resource_cost_icon.gd")
	var wallet:=HBoxContainer.new()
	wallet.alignment=BoxContainer.ALIGNMENT_CENTER
	vb.add_child(wallet)
	CostIcon.balance_label(wallet,"credits","军需券 %d"%MetaProgress.balance("credits"),13,kit.COL_TEXT)
	CostIcon.balance_label(wallet,"cores","战略核心 %d"%MetaProgress.balance("cores"),13,kit.COL_TEXT)
	wallet.add_child(kit.make_label("档位 %s"%MetaProgress.current_tier_data().get("short",MetaProgress.current_tier),13,kit.COL_TEXT))
	var pending:=MetaProgress.pending_rewards()
	if pending.credits>=1.0 or pending.cores>=0.5:
		var reward:=HBoxContainer.new()
		reward.alignment=BoxContainer.ALIGNMENT_CENTER
		vb.add_child(reward)
		reward.add_child(kit.make_label("待领取挂机收益",13,kit.COL_OK))
		CostIcon.balance_label(reward,"credits","军需券 %d"%pending.credits,13,kit.COL_OK)
		CostIcon.balance_label(reward,"cores","战略核心 %d"%pending.cores,13,kit.COL_OK)
	vb.add_child(kit.hsep(6))

	var play_modes := HBoxContainer.new()
	play_modes.add_theme_constant_override("separation", 12)
	vb.add_child(play_modes)
	_add_menu_button(play_modes, "战 役", "banner", "选择阵营与任务", func(): get_tree().change_scene_to_file("res://scenes/campaign_command.tscn"))
	_add_menu_button(play_modes, "遭遇战", "banner", "设置地图和对手", func(): get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	var expedition := _add_menu_button(play_modes, "肉鸽远征", "compass", "招募部队，率领幸存者连闯 %d 关" % preload("res://scripts/expedition/catalog.gd").TOTAL, func(): get_tree().change_scene_to_file("res://scenes/expedition.tscn"))
	var attention = preload("res://scripts/expedition/attention.gd")
	preload("res://scripts/ui/attention_dot.gd").mark(expedition, attention.any(Expedition.state), attention.summary(Expedition.state))
	var load_button := kit.make_button("读取对局存档", 16)
	load_button.icon = MenuIcon.texture("folder")
	load_button.add_theme_constant_override("icon_max_width", 22)
	load_button.pressed.connect(func():
		if not is_instance_valid(save_panel):
			save_panel = preload("res://scripts/ui/save_panel.gd").new()
			add_child(save_panel)
		save_panel.open())
	var references:=HBoxContainer.new()
	vb.add_child(references)
	load_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	references.add_child(load_button)
	var guide:=kit.make_button("支线百科",16)
	guide.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	guide.icon = MenuIcon.texture("handbook")
	guide.add_theme_constant_override("icon_max_width", 22)
	guide.pressed.connect(preload("res://scripts/expedition/field_guide.gd").open.bind(self))
	references.add_child(guide)
	var collection := kit.make_button("CG 收藏",16)
	collection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/cg_collection.tscn"))
	references.add_child(collection)
	var progression := HBoxContainer.new()
	progression.add_theme_constant_override("separation", 12)
	vb.add_child(progression)
	_add_menu_button(progression, "驻防基地", "fort", "挂机收益 · 升级 · 改造", func(): get_tree().change_scene_to_file("res://scenes/meta.tscn"))
	_add_menu_button(progression, "英雄养成", "rank", "解锁 · 训练 · 专属皮肤", func(): get_tree().change_scene_to_file("res://scenes/heroes.tscn"))
	_add_menu_button(progression, "科技树", "research_tree", "局外研究 · 永久解锁", func(): get_tree().change_scene_to_file("res://scenes/technology.tscn"))
	_add_menu_button(progression, "每日任务", "receipt_stamp", "进度 · 钻石奖励", func(): get_tree().change_scene_to_file("res://scenes/daily_tasks.tscn"))
	var sections:=HBoxContainer.new()
	vb.add_child(sections)
	for entry in [["百合子手记","handbook","yuriko_school"],["远征养成","expedition_map","expedition_research"],["技能抽卡","draw_cards","skill_draw"],["单位养成","unit_training","unit_training"]]:
		var shortcut:=kit.make_button(entry[0],16)
		shortcut.icon=MenuIcon.texture(entry[1])
		shortcut.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		shortcut.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/%s.tscn"%entry[2]))
		if entry[2]=="yuriko_school" and not preload("res://scripts/units/yuriko_school.gd").met():
			shortcut.text="？？？"
			shortcut.icon=MenuIcon.texture("lock")
			shortcut.disabled=true
		sections.add_child(shortcut)
		if entry[2]=="yuriko_school":preload("res://scripts/units/yuriko_unread.gd").mark_entry(shortcut)
		if entry[2]=="expedition_research":
			preload("res://scripts/expedition/research.gd").watch_entry(shortcut)
	vb.add_child(HouseColor.menu_picker())
	_add_menu_button(vb, "涂 装", "roller", "单位外观 · 整套皮肤与独立挂件", func(): get_tree().change_scene_to_file("res://scenes/paint.tscn"))
	var settings:=_add_menu_button(vb, "设 置", "sliders", "起名 · 操控 · 显示与声音", func(): get_tree().change_scene_to_file("res://scenes/settings.tscn"))
	settings.name="SettingsButton"
	preload("res://scripts/ui/progression_upgrade.gd").mark(settings,MetaProgress.commander_name().is_empty())
	_add_menu_button(vb, "后 台", "console", "单位测试场、数值调整与 GM 工具", func(): get_tree().change_scene_to_file("res://scenes/admin.tscn"))
	_add_menu_button(vb, "退 出", "exit_door", "结束游戏", func(): get_tree().quit())

	vb.add_child(kit.hsep(4))
	var tip := kit.make_label("想试试不同兵种？打开「后台」中的 GM 控制台即可进入单位测试场。", 12, kit.COL_DIM)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(380, 0)
	vb.add_child(tip)

func _add_menu_button(parent: Node, label: String, icon_id: String, hint: String, cb: Callable) -> Button:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 1)
	parent.add_child(wrap)
	var b := kit.make_button(label, 18)
	b.custom_minimum_size = Vector2(0, 46)
	b.icon = MenuIcon.texture(icon_id)
	b.add_theme_constant_override("icon_max_width", 20 if icon_id in ["fort", "rank", "research_tree", "receipt_stamp"] else 28)
	b.pressed.connect(cb)
	wrap.add_child(b)
	var h := kit.make_label(hint, 12, kit.COL_DIM)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(h)
	return b

func _draw_bg(ctrl: Control) -> void:
	var s := ctrl.size
	# 斜向科技网格
	var step := 46.0
	var c := Color(0.12, 0.2, 0.3, 0.35)
	var x := -s.y
	while x < s.x:
		ctrl.draw_line(Vector2(x, 0), Vector2(x + s.y, s.y), c, 1.0)
		x += step
	# 顶部光晕
	ctrl.draw_rect(Rect2(0, 0, s.x, 3), Color(0.35, 0.65, 1.0, 0.5))
