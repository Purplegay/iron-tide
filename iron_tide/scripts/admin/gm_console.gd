extends Control
class_name GMConsole
## GM 控制台：局内作弊开关 + 局外货币发放 + 数据热重载。
## 可浮在战斗界面（battle_hud 已设置）或嵌在后台面板里（embed_mode = true）。

@onready var kit = UiKit

var battle_hud = null
var embed_mode: bool = false

var _body: VBoxContainer
var _status: Label
var _flag_checks: Dictionary={}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	var panel := kit.make_panel(Color(0.07, 0.085, 0.12, 0.98), Color(0.5, 0.35, 0.3))
	add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if embed_mode:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		# 浮动在右侧
		panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		panel.offset_left = -500
		panel.offset_right = -12
		panel.offset_top = 62
		panel.offset_bottom = -12

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)

	var head := HBoxContainer.new()
	outer.add_child(head)
	head.add_child(kit.make_label("GM 控制台", 18, Color(1.0, 0.7, 0.5)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	if not embed_mode:
		var close := kit.make_button("关闭 (Ctrl+G)")
		close.pressed.connect(func(): visible = false)
		head.add_child(close)

	_status = kit.make_label("", 12, kit.COL_OK)
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_status)

	var sc := kit.make_scroll()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(sc)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)

	_build_sections()
	refresh()

func _build_sections() -> void:
	var tuning:=kit.make_button("天赋／技能数值编辑器")
	tuning.name="OpenProgressionEditor"
	tuning.pressed.connect(func():
		if has_node("ProgressionEditor"):get_node("ProgressionEditor").move_to_front();return
		var editor=preload("res://scripts/admin/progression_editor.gd").new()
		editor.name="ProgressionEditor";add_child(editor))
	_body.add_child(tuning)
	var tools_panel=preload("res://scripts/admin/gm_unit_panel.gd").new()
	tools_panel.notify=Callable(self,"_set_status")
	_body.add_child(tools_panel)
	# ---- 战斗作弊 ----
	_section("战斗作弊（局内）")
	var toggles := [
		["god_mode", "我方无敌"],
		["one_shot_kill", "我方一击必杀"],
		["infinite_funds", "无限资金"],
		["infinite_power", "无限电力"],
		["no_build_time", "快速建造（建筑、防御和单位生产）"],
		["unlock_production_tech", "调试：解锁矿场制造矿车科技"],
	]
	for t in toggles:
		var chk := kit.make_check(t[1], (GM.get(t[0]) == true))
		_flag_checks[t[0]]=chk
		chk.toggled.connect(func(on):
			GM.set_flag(t[0], on)
			_refresh_flags())
		_body.add_child(chk)

	var reservations := kit.make_button("解锁科技：建筑预约（仅本局我方）")
	reservations.name = "UnlockStructureQueue"
	reservations.pressed.connect(func(): _battle_cmd("建筑预约", GM.cmd_unlock_structure_queue()))
	_body.add_child(reservations)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	_body.add_child(row1)
	var b1 := kit.make_button("+1000 资金")
	b1.pressed.connect(func(): _battle_cmd("资金 +1000", GM.cmd_add_funds(1000.0)))
	var b2 := kit.make_button("+10000 资金")
	b2.pressed.connect(func(): _battle_cmd("资金 +10000", GM.cmd_add_funds(10000.0)))
	row1.add_child(b1); row1.add_child(b2)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	_body.add_child(row2)
	var b3 := kit.make_button("清场（灭敌方）")
	b3.pressed.connect(func(): _battle_cmd("清场", GM.cmd_kill_all_enemies()))
	var b4 := kit.make_button("跳过倒计时")
	b4.pressed.connect(func(): _battle_cmd("跳波", GM.cmd_skip_wave()))
	row2.add_child(b3); row2.add_child(b4)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	_body.add_child(row3)
	var b5 := kit.make_button("强制胜利")
	b5.pressed.connect(func(): _battle_cmd("强制胜利", GM.cmd_force_win()))
	var b6 := kit.make_button("强制失败")
	b6.pressed.connect(func(): _battle_cmd("强制失败", GM.cmd_force_lose()))
	row3.add_child(b5); row3.add_child(b6)

	# ---- 局外养成 ----
	_section("局外养成")
	var cur_row := HBoxContainer.new()
	cur_row.add_theme_constant_override("separation", 6)
	_body.add_child(cur_row)
	var c1 := kit.make_button("+10000 军需券")
	c1.pressed.connect(func(): _meta_cmd(GM.cmd_grant_currency("credits", 10000)))
	var c2 := kit.make_button("+500 战略核心")
	c2.pressed.connect(func(): _meta_cmd(GM.cmd_grant_currency("cores", 500)))
	var diamonds := kit.make_button("+9000 钻石")
	diamonds.name = "GrantDiamonds"
	diamonds.pressed.connect(func(): _meta_cmd(GM.cmd_grant_currency("diamonds", 9000)))
	cur_row.add_child(c1); cur_row.add_child(c2)
	cur_row.add_child(diamonds)

	var idle_row := HBoxContainer.new()
	idle_row.add_theme_constant_override("separation", 6)
	_body.add_child(idle_row)
	var hours_sp := kit.make_spin(6, 1, 240, 1)
	hours_sp.custom_minimum_size = Vector2(70, 30)
	idle_row.add_child(hours_sp)
	var idle_btn := kit.make_button("模拟挂机 N 小时")
	idle_btn.pressed.connect(func(): _meta_cmd(GM.cmd_set_idle_hours(float(hours_sp.value))))
	idle_row.add_child(idle_btn)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	_body.add_child(meta_row)
	var m1 := kit.make_button("升至最高档位")
	m1.pressed.connect(func(): _meta_cmd(GM.cmd_grant_all_tiers()))
	var m2 := kit.make_button("拉满全部升级")
	m2.pressed.connect(func(): _meta_cmd(GM.cmd_max_upgrades()))
	meta_row.add_child(m1); meta_row.add_child(m2)

	var meta_row2 := HBoxContainer.new()
	meta_row2.add_theme_constant_override("separation", 6)
	_body.add_child(meta_row2)
	var m3 := kit.make_button("重置局外存档")
	m3.pressed.connect(func(): _meta_cmd(GM.cmd_reset_meta()))
	var m4 := kit.make_button("热重载 data/")
	m4.pressed.connect(func(): _meta_cmd(GM.cmd_reload_data()))
	meta_row2.add_child(m3); meta_row2.add_child(m4)

	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 6)
	_body.add_child(skill_row)
	var m5 := kit.make_button("解锁全部技能")
	m5.pressed.connect(func(): _meta_cmd(GM.cmd_unlock_all_skills()))
	var m6 := kit.make_button("清空抽取技能")
	m6.pressed.connect(func(): _meta_cmd(GM.cmd_reset_skills()))
	skill_row.add_child(m5); skill_row.add_child(m6)
	var heroes:=kit.make_button("一键解锁所有英雄")
	heroes.name="UnlockAllHeroes"
	heroes.tooltip_text="补齐所有英雄的生产解锁门槛并保存；已有更高进度保留。开新局体验出场，不升级天赋、不完成专属卡契约。"
	heroes.pressed.connect(func():_meta_cmd(GM.cmd_unlock_all_heroes()))
	_body.add_child(heroes)
	var school:=kit.make_button("一键解锁百合子栏目与剧情")
	school.name="UnlockYurikoStory"
	school.pressed.connect(func():_meta_cmd(preload("res://scripts/units/yuriko_bonds.gd").gm_unlock()))
	_body.add_child(school)
	var hero_contracts := kit.make_button("一键完成全部英雄契约")
	hero_contracts.name="CompleteHeroContracts"
	hero_contracts.tooltip_text="获得全部英雄契约、补齐任务进度并解锁专属技能。已有技能等级保留。"
	hero_contracts.pressed.connect(func(): _meta_cmd(GM.cmd_complete_hero_contracts()))
	_body.add_child(hero_contracts)

	# ---- 时间倍率 ----
	_section("时间倍率")
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 6)
	_body.add_child(speed_row)
	for s in [0.5, 1.0, 2.0, 4.0, 8.0]:
		var sb := kit.make_button("×%s" % str(s))
		sb.pressed.connect(func():
			BattleClock.set_speed(s)
			_set_status("时间倍率 ×%s" % str(s)))
		speed_row.add_child(sb)

func _section(title: String) -> void:
	_body.add_child(kit.hsep(4))
	_body.add_child(kit.make_label(title, 14, kit.COL_ACCENT))
	_body.add_child(kit.divider())

func _battle_cmd(label: String, result: String) -> void:
	_set_status("%s → %s" % [label, result])

func _meta_cmd(result: String) -> void:
	refresh()
	_set_status(result)

func _set_status(t: String) -> void:
	if _status != null:
		_status.text = t

func _refresh_flags() -> void:
	_set_status("无敌=%s  秒杀=%s  无限资金=%s  无限电力=%s  秒建造=%s" % [
		str(GM.god_mode), str(GM.one_shot_kill), str(GM.infinite_funds), str(GM.infinite_power), str(GM.no_build_time)
	])

func refresh() -> void:
	# 同步勾选状态
	_refresh_flags()
	if battle_hud == null and not embed_mode:
		_set_status("当前不在战斗场景：仅可发放货币与调整养成")

func _process(_delta: float) -> void:
	if not visible:
		return
	for key in _flag_checks:
		_flag_checks[key].set_pressed_no_signal(GM.get(key)==true)
