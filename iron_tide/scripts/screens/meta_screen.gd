extends Control
class_name MetaScreen
const NewContent=preload("res://scripts/ui/progression_new.gd")
const Upgrade=preload("res://scripts/ui/progression_upgrade.gd")
## 驻防（老家）：挂机收菜、后勤升级、档位解锁，以及「单位改造」（逐单位强化 + 技能装配）。
## 所有改动永久生效。

@onready var kit = UiKit
const TICK := 1.0
const CardScope=preload("res://scripts/rules/skill_scope.gd")
const AutoSkills=preload("res://scripts/rules/auto_skill_loadout.gd")
const ContractPool=preload("res://scripts/rules/hero_contract_pool.gd")
@export var initial_page: String = "logistics"

var _tick_timer: float = 0.0
var _page: String = "logistics"

var credits_label: Label
var cores_label: Label
var diamonds_label: Label
var pending_cores_label: Label
var rate_label: Label
var pending_label: Label
var cap_bar: ProgressBar
var bonus_label: Label
var tier_list: VBoxContainer
var upgrade_list: VBoxContainer

# 页签
var tab_logi_btn: Button
var hero_tab: Button
var heroes = preload("res://scripts/ui/hero_progression.gd").new()
var expedition_tab: Button
var expedition_scroll := ScrollContainer.new()
var expedition_tree := VBoxContainer.new()
var tab_units_btn: Button
var logistics_body: VBoxContainer
var units_body: VBoxContainer
var tab_technology_btn: Button
var technology_body: ScrollContainer
var technology_tree
var pool_tab: Button
var pool_scroll: ScrollContainer
var pool_body: VBoxContainer
const CostIcon=preload("res://scripts/ui/resource_cost_icon.gd")
const ProgressIcon = preload("res://scripts/ui/progression_icon.gd")
var selected_card := ""
var training_group := "通用"
var pool_result := ""
var pool_date := ""
var refit_roster: Array = []
var tasks_tab: Button
var tasks = preload("res://scripts/ui/daily_tasks.gd").new()
var shop_tab:Button
var shop_body:VBoxContainer

# 单位改造页
var exclusive_cards_by_unit:Dictionary={}
var exclusive_filter:=CheckBox.new()
var unit_filter_opt: OptionButton
var unit_list: VBoxContainer
var unit_detail: VBoxContainer
var auto_skill_selected: Button
var auto_skill_all: Button
var auto_skill_result: Label
var bookmarks = preload("res://scripts/ui/progression_bookmarks.gd").new()
var _unit_sel: String = ""
var _unit_filter: String = ""
var _faction_ids: Array = []
var unit_paint: Control

func _open_unit_paint() -> void:
	if is_instance_valid(unit_paint): return
	_save_bookmarks()
	var workshop = preload("res://scripts/screens/paint_screen.gd").new()
	workshop.initial_unit = _unit_sel
	workshop.return_to_refit = true
	unit_paint = workshop
	workshop.tree_exited.connect(func():
		unit_paint = null
		# Workshop and refit share UI preferences; keep the workshop's latest selections.
		bookmarks.config.load(bookmarks.PATH)
		show()
		set_process(true)
		_refresh())
	get_parent().add_child(workshop)
	workshop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	set_process(false)

func _ready() -> void:
	Music.set_context("menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_unit_sel=str(bookmarks.get_value("unit",""))
	_unit_filter=str(bookmarks.get_value("faction",""))
	exclusive_filter.set_pressed_no_signal(bookmarks.get_value("exclusive",false)==true)
	_build()
	Events.meta_changed.connect(_refresh)
	Events.idle_income_claimed.connect(func(r):
		Events.emit_message("已领取 军需券 %d · 核心 %d" % [int(r.credits), int(r.cores)], kit.COL_OK))
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.068)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	vb.offset_left = 20
	vb.offset_right = -20
	vb.offset_top = 14
	vb.offset_bottom = -14
	add_child(vb)

	# 顶栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	top.add_child(kit.make_label("驻 防 基 地", 26, kit.COL_ACCENT_2))
	credits_label = CostIcon.balance_label(top,"credits","",16,kit.COL_GOLD)
	cores_label = CostIcon.balance_label(top,"cores","",16,kit.COL_ACCENT)
	diamonds_label = CostIcon.balance_label(top,"diamonds","",16,kit.COL_ACCENT)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var back := kit.make_button("返回主菜单")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	top.add_child(back)

	var tabs := HFlowContainer.new()
	vb.add_child(tabs)
	tab_logi_btn = kit.make_button("后勤 / 档位")
	tab_logi_btn.custom_minimum_size = Vector2(130, 34)
	tab_logi_btn.pressed.connect(func(): _set_page("logistics"))
	tabs.add_child(tab_logi_btn)
	tab_units_btn = kit.make_button("单位养成")
	tab_units_btn.icon = ProgressIcon.texture("unit_training")
	tab_units_btn.custom_minimum_size = Vector2(130, 34)
	tab_units_btn.pressed.connect(func(): _set_page("units"))
	tabs.add_child(tab_units_btn)
	hero_tab = kit.make_button("英雄养成")
	hero_tab.pressed.connect(func(): _set_page("heroes"))
	tabs.add_child(hero_tab)
	var school:=kit.make_button("百合子" if preload("res://scripts/units/yuriko_school.gd").met() else "？？？")
	school.name="YurikoBaseTab"
	preload("res://scripts/units/yuriko_unread.gd").mark_entry(school)
	school.disabled=not preload("res://scripts/units/yuriko_school.gd").met()
	school.icon=ProgressIcon.texture("lock" if school.disabled else "heart")
	school.pressed.connect(func():
		get_tree().set_meta("yuriko_from_base",true)
		get_tree().change_scene_to_file("res://scenes/yuriko_school.tscn"))
	tabs.add_child(school)
	expedition_tab = kit.make_button("远征养成")
	expedition_tab.icon = ProgressIcon.texture("expedition_map")
	expedition_tab.pressed.connect(_set_page.bind("expedition"))
	tabs.add_child(expedition_tab)
	pool_tab = kit.make_button("技能抽卡")
	pool_tab.icon = ProgressIcon.texture("draw_cards")
	pool_tab.pressed.connect(func(): _set_page("pool"))
	tabs.add_child(pool_tab)
	tab_technology_btn = kit.make_button("科技树")
	tab_technology_btn.custom_minimum_size = Vector2(100, 34)
	tab_technology_btn.pressed.connect(func(): _set_page("technology"))
	tabs.add_child(tab_technology_btn)
	tasks_tab = kit.make_button("每日任务")
	tasks_tab.pressed.connect(func(): _set_page("tasks"))
	tabs.add_child(tasks_tab)
	shop_tab = kit.make_button("商店")
	shop_tab.pressed.connect(func(): _set_page("shop"))
	tabs.add_child(shop_tab)

	vb.add_child(kit.divider())

	logistics_body = VBoxContainer.new()
	logistics_body.add_theme_constant_override("separation", 8)
	logistics_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(logistics_body)

	units_body = VBoxContainer.new()
	units_body.add_theme_constant_override("separation", 8)
	units_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	units_body.visible = false
	vb.add_child(units_body)
	heroes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	heroes.bookmarks=bookmarks
	heroes.equipment.demo_requested.connect(_open_card_demo)
	heroes.contract_panel.demo_requested.connect(_open_card_demo)
	heroes.expansion_contract.demo_requested.connect(_open_card_demo)
	vb.add_child(heroes)
	tasks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tasks)
	technology_body = kit.make_scroll()
	technology_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	technology_body.visible = false
	vb.add_child(technology_body)
	expedition_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	vb.add_child(expedition_scroll)
	expedition_scroll.add_child(expedition_tree)
	shop_body=VBoxContainer.new()
	shop_body.add_theme_constant_override("separation",12)
	vb.add_child(shop_body)
	pool_scroll = kit.make_scroll()
	pool_scroll.name = "SkillPoolScroll"
	pool_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(pool_scroll)
	pool_body = VBoxContainer.new()
	pool_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_body.add_theme_constant_override("separation", 10)
	pool_scroll.add_child(pool_body)
	technology_tree = preload("res://scripts/ui/technology_tree.gd").new()
	technology_body.add_child(technology_tree)

	_build_logistics_page()
	_build_units_page()
	_set_page(initial_page)

# ------------------------------------------------------------------ 页签

func _set_page(p: String) -> void:
	_save_bookmarks()
	_page = p
	expedition_scroll.visible = p == "expedition"
	expedition_tab.disabled = expedition_scroll.visible
	if expedition_scroll.visible:preload("res://scripts/expedition/research.gd").populate(expedition_tree)
	logistics_body.visible = p == "logistics"
	units_body.visible = p == "units"
	heroes.visible = p == "heroes"
	hero_tab.disabled = heroes.visible
	if heroes.visible: heroes.open_page()
	technology_body.visible = p == "technology"
	pool_scroll.visible = p == "pool"
	pool_body.visible = p == "pool"
	pool_tab.disabled = p == "pool"
	if p == "pool": _refresh_pool()
	tasks.visible = p == "tasks"
	tasks_tab.disabled = tasks.visible
	if tasks.visible: tasks.refresh()
	shop_body.visible = p == "shop"
	shop_tab.disabled = p == "shop"
	if p == "shop":_refresh_shop()
	tab_logi_btn.disabled = p == "logistics"
	tab_units_btn.disabled = p == "units"
	tab_technology_btn.disabled = p == "technology"
	if p == "units":
		_rebuild_unit_list()
		_rebuild_unit_detail()

func _build_logistics_page() -> void:
	# 挂机收益区
	var idle_panel := kit.make_panel(Color(0.1, 0.13, 0.17), Color(0.35, 0.6, 0.85))
	logistics_body.add_child(idle_panel)
	var idle_hb := HBoxContainer.new()
	idle_hb.add_theme_constant_override("separation", 16)
	idle_panel.add_child(idle_hb)

	var idle_left := VBoxContainer.new()
	idle_left.add_theme_constant_override("separation", 3)
	idle_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idle_hb.add_child(idle_left)
	idle_left.add_child(kit.make_label("挂机补给（收菜）", 16, kit.COL_ACCENT_2))
	rate_label = kit.make_label("", 13, kit.COL_TEXT)
	idle_left.add_child(rate_label)
	var pending_row:=HFlowContainer.new()
	idle_left.add_child(pending_row)
	pending_row.add_child(kit.make_label("待领取",16,kit.COL_OK))
	pending_label=CostIcon.balance_label(pending_row,"credits","",16,kit.COL_OK)
	pending_cores_label=CostIcon.balance_label(pending_row,"cores","",16,kit.COL_OK)
	cap_bar = ProgressBar.new()
	cap_bar.custom_minimum_size = Vector2(360, 14)
	cap_bar.show_percentage = false
	cap_bar.max_value = 100.0
	cap_bar.add_theme_stylebox_override("background", kit.panel_style(Color(0.06, 0.08, 0.1), Color(0.25, 0.35, 0.45), 3, 1, 0))
	cap_bar.add_theme_stylebox_override("fill", kit.panel_style(Color(0.4, 0.85, 0.55), Color(0.5, 1.0, 0.7), 3, 1, 0))
	idle_left.add_child(cap_bar)

	var idle_right := VBoxContainer.new()
	idle_right.add_theme_constant_override("separation", 6)
	idle_right.custom_minimum_size = Vector2(200, 0)
	idle_hb.add_child(idle_right)
	var claim := kit.make_button("领 取 补 给", 17)
	claim.custom_minimum_size = Vector2(200, 48)
	claim.pressed.connect(func():
		MetaProgress.claim_idle()
		_refresh())
	idle_right.add_child(claim)
	var refresh_btn := kit.make_button("刷新")
	refresh_btn.pressed.connect(func():
		MetaProgress.accrue_idle()
		MetaProgress.save()
		_refresh())
	idle_right.add_child(refresh_btn)

	# 主体两栏
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logistics_body.add_child(cols)

	# 左：档位 + 加成
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 6)
	left_col.custom_minimum_size = Vector2(400, 0)
	cols.add_child(left_col)
	left_col.add_child(kit.make_label("档位（决定挂机收益与全局加成）", 15, kit.COL_ACCENT))
	var lsc := kit.make_scroll()
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lsc.custom_minimum_size = Vector2(390, 0)
	left_col.add_child(lsc)
	tier_list = VBoxContainer.new()
	tier_list.add_theme_constant_override("separation", 6)
	tier_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(tier_list)

	# 右：升级
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right_col)
	right_col.add_child(kit.make_label("后勤升级（永久生效，作用于所有战斗）", 15, kit.COL_ACCENT))
	bonus_label = kit.make_label("", 13, kit.COL_OK)
	right_col.add_child(bonus_label)
	var rsc := kit.make_scroll()
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(rsc)
	upgrade_list = VBoxContainer.new()
	upgrade_list.add_theme_constant_override("separation", 6)
	upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.add_child(upgrade_list)

# ------------------------------------------------------------------ 单位改造页

func _build_units_page() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	units_body.add_child(head)
	var t := kit.make_label("逐单位改造：定制火力 / 定制装甲 / 专属天赋，永久生效；Q 固有主动、W 装配主动、1 个装配被动、E 特殊操作。", 14, kit.COL_ACCENT_2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)

	var names: Array = ["全部阵营"]
	refit_roster = AutoSkills.roster()
	_faction_ids = [""]
	for f in GameData.factions:
		if f.id not in ["allied", "soviet"]: continue
		_faction_ids.append(str(f.get("id", "")))
		names.append(str(f.get("name", f.get("id", ""))))
	if not _faction_ids.has(_unit_filter):_unit_filter=""
	unit_filter_opt = kit.make_option(names, _faction_ids.find(_unit_filter), 14)
	unit_filter_opt.custom_minimum_size = Vector2(150, 32)
	unit_filter_opt.item_selected.connect(func(i):
		_unit_filter = str(_faction_ids[i]) if i < _faction_ids.size() else ""
		_unit_sel = ""
		_rebuild_unit_list()
		_rebuild_unit_detail())
	head.add_child(unit_filter_opt)
	for card in MetaProgress.skill_draw_candidates():
		for uid in card.get("allowed_units",[]):
			exclusive_cards_by_unit.get_or_add(uid,[]).append(card)
	exclusive_filter.text="仅看有专属卡／天赋的单位"
	head.add_child(exclusive_filter)
	exclusive_filter.toggled.connect(func(_on:bool):
		_rebuild_unit_list()
		_rebuild_unit_detail())
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation",10)
	units_body.add_child(auto_row)
	auto_skill_selected = kit.make_button("为当前兵种装配技能",14)
	auto_skill_selected.name = "AutoEquipSelected"
	auto_skill_selected.pressed.connect(_auto_configure_skills.bind(false))
	auto_row.add_child(auto_skill_selected)
	auto_skill_all = kit.make_button("为全部单位装配技能",14)
	auto_skill_all.name = "AutoEquipAll"
	auto_skill_all.pressed.connect(_auto_configure_skills.bind(true))
	auto_skill_all.tooltip_text = "为所有可改造单位装配技能，包括防御建筑和当前筛选隐藏的单位。英雄保留原有装配。"
	auto_row.add_child(auto_skill_all)
	auto_skill_result = kit.make_label("",13,kit.COL_OK)
	auto_skill_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_skill_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auto_row.add_child(auto_skill_result)
	var auto_hint := kit.make_label("自动装配会从已解锁的技能中挑选 W 技能和被动技能。先选专属，再看品质和等级。条件相同时保留现有技能。装配免费，从下一场扩展对局生效。",12,kit.COL_DIM)
	auto_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	units_body.add_child(auto_hint)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	units_body.add_child(cols)

	# 左：单位列表
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(320, 0)
	cols.add_child(left)
	left.add_child(kit.make_label("单位列表", 15, kit.COL_ACCENT))
	var lsc := kit.make_scroll()
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lsc.custom_minimum_size = Vector2(310, 0)
	left.add_child(lsc)
	unit_list = VBoxContainer.new()
	unit_list.add_theme_constant_override("separation", 4)
	unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(unit_list)

	# 右：详情
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(kit.make_label("改造详情", 15, kit.COL_ACCENT))
	var rsc := kit.make_scroll()
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rsc)
	unit_detail = VBoxContainer.new()
	unit_detail.add_theme_constant_override("separation", 8)
	unit_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.add_child(unit_detail)

func _refresh_shop() -> void:
	_clear(shop_body)
	var legend:=HFlowContainer.new()
	shop_body.add_child(legend)
	CostIcon.balance_label(legend,"credits","军需券 · 后勤、单位与英雄训练",15,kit.COL_GOLD)
	CostIcon.balance_label(legend,"cores","战略核心 · 科技、天赋与技能卡升级",15,kit.COL_GOLD)
	CostIcon.balance_label(legend,"diamonds","钻石 · 皮肤与抽卡",15,kit.COL_GOLD)
	var day := MetaProgress.Academy.today(MetaProgress)
	var pieces := int(MetaProgress.academy.get("victory_shards",0))
	var inventory:=HFlowContainer.new()
	shop_body.add_child(inventory)
	inventory.add_child(kit.make_label("每日首胜 %d/1"%day.win,15,kit.COL_GOLD))
	CostIcon.balance_label(inventory,"victory_shards","胜利券碎片 %d"%pieces,15,kit.COL_GOLD)
	CostIcon.balance_label(inventory,"skin_ticket","皮肤券 %d"%MetaProgress.academy.get("skin_ticket",0),15,kit.COL_GOLD)
	CostIcon.balance_label(inventory,"tickets","技能券 %d"%MetaProgress.academy.get("tickets",0),15,kit.COL_GOLD)
	for key in ["skin_ticket","tickets"]:
		var btn := kit.make_button("10 个胜利券碎片 → 1 张" + ("皮肤券" if key=="skin_ticket" else "技能券"))
		btn.text=""
		btn.custom_minimum_size=Vector2(320,38)
		var line:=HBoxContainer.new()
		line.alignment=BoxContainer.ALIGNMENT_CENTER
		line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		btn.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		CostIcon.balance_label(line,"victory_shards","10 个胜利券碎片",15,kit.COL_TEXT)
		line.add_child(kit.make_label("→",15,kit.COL_DIM))
		CostIcon.balance_label(line,key,"1 张"+("皮肤券" if key=="skin_ticket" else "技能券"),15,kit.COL_GOLD)
		for part in line.find_children("*","Control",true,false):part.mouse_filter=Control.MOUSE_FILTER_IGNORE
		btn.accessibility_name="10 个胜利券碎片兑换 1 张"+("皮肤券" if key=="skin_ticket" else "技能券")
		if pieces<10:line.modulate=Color(.7,.7,.7)
		btn.disabled = pieces < 10
		btn.pressed.connect(func(): MetaProgress.Academy.purchase(MetaProgress,key))
		shop_body.add_child(btn)

func _build_unit_talents(unit_id:String) -> void:
	unit_detail.add_child(kit.make_label("专属天赋　·　未分配点数 %d" % MetaProgress.unassigned_talent_points(),16,kit.COL_ACCENT))
	var slots:=MetaProgress.talent_capacity(unit_id)
	var used:=MetaProgress.selected_talents(unit_id,MetaProgress.unit_talents).size()
	var available:=MetaProgress.available_talent_slots(unit_id)
	unit_detail.add_child(kit.make_label("本兵种天赋格　已开 %d / %d　·　已用 %d 格" % [slots,maxi(slots,available),used],14,kit.COL_ACCENT))
	if slots>available:
		unit_detail.add_child(kit.make_label("历史已购空格保留，待新天赋开放后可使用。",13,kit.COL_DIM))
	var options:=MetaProgress.talent_options(unit_id)
	if options.is_empty():
		unit_detail.add_child(kit.make_label("该兵种的专属天赋尚未开放，暂时无法开启天赋格。",13,kit.COL_DIM))
		return
	unit_detail.add_child(kit.make_label("直接解锁 0 级天赋，优先使用已有天赋点与已开格子；不足部分计入按钮费用。之后升级消耗战略核心，在新开的扩展对局生效。",14,kit.COL_DIM))
	var rank_costs:Array=GameData.meta_config.get("talent_rank_costs",[])
	var prices:=PackedStringArray()
	for i in rank_costs.size(): prices.append("%d→%d 级：%d" % [i,i+1,int(rank_costs[i])])
	unit_detail.add_child(kit.make_label("升级费用（战略核心）　"+"　／　".join(prices),14,kit.COL_GOLD))
	for id:String in options:
		var talent:Dictionary=options[id]
		var equipped:bool=id in MetaProgress.selected_talents(unit_id,MetaProgress.unit_talents)
		var rank:=MetaProgress.talent_rank(unit_id,id,MetaProgress.unit_talents)
		var ranks:Array=talent.get("ranks",[])
		var title:=NewContent.talent_name(unit_id,id)
		if equipped and not ranks.is_empty():title+="　Lv.%d / %d" % [rank,ranks.size()]
		var description:=str(talent.desc)
		if talent.has("base"):description+="\n0 级　%s %s%s" % [talent.stat,str(talent.base),talent.suffix]
		if talent.has("intervals"):description+=" · 每 %s 秒叠层" % str(talent.intervals[0])
		if talent.has("stack_limits"):description+=" · 最多 %d 层" % talent.stack_limits[0]
		if talent.has("heal_seconds"):description+=" · 回血 %d 秒" % talent.heal_seconds[0]
		if talent.has("cooldown_reduction"):description+=" · 攻击间隔 -%d%%" % talent.cooldown_reduction[0]
		for i in ranks.size():
			var rule:Dictionary=ranks[i]
			if rule.has("value"):
				description+="\n%d 级　%s %s%s" % [i+1,talent.stat,str(rule.value),talent.suffix]
				if talent.has("intervals"):description+=" · 每 %s 秒叠层" % str(talent.intervals[i+1])
				if talent.has("stack_limits"):description+=" · 最多 %d 层" % talent.stack_limits[i+1]
				if talent.has("heal_seconds"):description+=" · 回血 %d 秒" % talent.heal_seconds[i+1]
				if talent.has("cooldown_reduction"):description+=" · 攻击间隔 -%d%%" % talent.cooldown_reduction[i+1]
				continue
			var percent:=roundi(float(rule.damage)*100)
			if rule.has("charge_seconds"):
				description+="\n%d 级　集中攻击：主目标与 W 指定的副目标分别计时。从各自首发起，每持续攻击 %s 秒叠 1 层 Heat，每层 +%d%% 伤害、持续 %s 秒，最多 %d 层。分区侧炮命中热目标时还会刷新已有层的时间。" % [i+1,str(rule.charge_seconds),percent-100,str(rule.linger),ceili(float(rule.linger)/float(rule.charge_seconds))]
			else:
				description+="\n%d 级　分配给副目标的侧炮造成 %d%% 伤害。" % [i+1,percent]
		if id=="bunker_optics":
			description=str(talent.desc)
			for r in 4:description+="\n%d 级　驻军总射程 %.2f 格" % [r,preload("res://scripts/rules/bunker_talent.gd").range_cells(r)]
		if talent.has("native_profile"):description=str(talent.desc)+"\n"+Unit.Training.talent_description(unit_id)
		if id=="dive_momentum":
			description=str(talent.desc)
			for r in 4:description+="\n%d 级　加速 %d%% 持续 2 秒 · 投弹后隐身 %s 秒"%[r,roundi(float(talent.values.speed[r])*100),String.num(float(talent.values.cloak[r]),2)]
		description=preload("res://scripts/rules/progression_parameters.gd").describe(id,description)
		var detail:=kit.make_label("%s · %s" % [title,description],14,kit.COL_TEXT)
		detail.name="TalentTitle_"+id
		detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		unit_detail.add_child(detail)
		var play:=kit.make_button("▶  演示 · "+NewContent.talent_name(unit_id,id))
		play.icon = ProgressIcon.texture(id)
		unit_detail.add_child(play)
		play.pressed.connect(_show_talent_demo.bind(unit_id,id,rank))
		if equipped:
			unit_detail.add_child(kit.make_label("已分配 1 个天赋点",14,kit.COL_DIM))
			if rank<ranks.size():
				var price:=MetaProgress.talent_upgrade_cost(unit_id,id)
				var upgrade:=kit.make_button("升至 %d 级　·　%d 战略核心" % [rank+1,price])
				upgrade.icon = CostIcon.texture("cores")
				upgrade.name="UpgradeTalent_"+id
				upgrade.disabled=price<=0 or MetaProgress.balance("cores") < price
				upgrade.pressed.connect(func():
					if not MetaProgress.upgrade_talent(unit_id,id,rank):Events.emit_message("升级未完成，请检查核心余额或存档。",kit.COL_WARN))
				unit_detail.add_child(upgrade)
				Upgrade.mark(upgrade,Upgrade.talent(unit_id,id))
			_add_effect_switch(unit_detail,"talent",id,unit_id)
			continue
		var offer:=MetaProgress.talent_unlock_quote(unit_id,id)
		var label:="天赋格已满"
		if not offer.is_empty():
			label="解锁　·　使用 1 个已有天赋点" if offer.cost==0 else "解锁　·　%d %s" % [offer.cost,MetaProgress.currency_name(offer.currency)]
		var button:=kit.make_button(label,15)
		button.icon = ProgressIcon.texture(id)
		button.name="Talent_"+id
		button.disabled=offer.is_empty() or MetaProgress.balance(offer.currency)<float(offer.cost)
		if not offer.is_empty():
			button.icon=CostIcon.texture(str(offer.currency) if offer.cost>0 else "talent_points")
			button.tooltip_text="一次解锁并分配：开格 %d，补足点数 %d %s。%s" % [offer.slot_cost,offer.point_cost,MetaProgress.currency_name(offer.currency),"消耗 1 个已有天赋点。" if not offer.need_point else "不留下额外未分配点数。"]
			button.pressed.connect(func():
				if not MetaProgress.unlock_unit_talent(unit_id,id,int(offer.cost)):
					Events.emit_message("解锁未完成，请检查余额、当前天赋状态或存档。",kit.COL_WARN))
		unit_detail.add_child(button)
		Upgrade.mark(button,Upgrade.talent_unlock(unit_id,id))

func _show_talent_demo(id:String,talent:String,rank:int) -> void:
	if has_node("TalentDemo"):return
	var shade:=ColorRect.new()
	shade.name="TalentDemo"
	shade.color=Color(0.02,0.04,0.06,0.88)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel=kit.make_panel(kit.COL_PANEL,kit.COL_ACCENT)
	panel.custom_minimum_size.x=minf(580,get_viewport_rect().size.x-32)
	center.add_child(panel)
	var content:=VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	var definition:Dictionary=MetaProgress.talent_options(id)[talent]
	content.add_child(kit.make_label("%s · 天赋演示" % NewContent.talent_name(id,talent),21,kit.COL_ACCENT_2))
	if talent=="bunker_optics":
		var preview=preload("res://scripts/ui/bunker_talent_preview.gd").new()
		preview.rank=rank;content.add_child(preview)
		var levels=kit.make_option(["解锁 0 级","演示 1 级","演示 2 级","演示 3 级"],rank,14)
		content.add_child(levels)
		levels.item_selected.connect(func(i):preview.rank=i;preview.queue_redraw())
		var dismiss=kit.make_button("关闭演示")
		content.add_child(dismiss);dismiss.pressed.connect(shade.queue_free)
		return
	if definition.has("native_profile"):
		var demonstration=preload("res://scripts/ui/native_talent_demo.gd").new()
		demonstration.name="NativeTalentDemo";content.add_child(demonstration)
		demonstration.configure(id,rank)
		var dismiss=kit.make_button("关闭演示")
		content.add_child(dismiss);dismiss.pressed.connect(shade.queue_free)
		return
	var preview=preload("res://scripts/ui/unit_showcase.gd").new()
	preview.name="Preview"
	content.add_child(preview)
	preview.show_unit(id,talent,rank)
	var choices:Array=["解锁 0 级"]
	for i in definition.get("ranks",[]).size():choices.append("演示 %d 级" % (i+1))
	var levels=kit.make_option(choices,rank,14)
	content.add_child(levels)
	var playback=preload("res://scripts/ui/demo_playback.gd").new();content.add_child(playback)
	playback.bind(preview,&"age",preview.demo_duration,preview._animate)
	playback.add_transport()
	levels.item_selected.connect(func(i):preview.rank=i;playback.restore_position(preview.age,preview.playing))
	var caption := kit.make_label(str(definition.desc),15,kit.COL_TEXT)
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(caption)
	var close=kit.make_button("关闭演示")
	content.add_child(close)
	close.pressed.connect(shade.queue_free)
	close.grab_focus()

func _add_effect_switch(parent:Control,kind:String,id:String,unit_id:String) -> void:
	var toggle:=CheckButton.new()
	toggle.tooltip_text="关闭只暂停效果；等级和已投入的天赋点都会保留。"
	toggle.name="Enable_"+id
	toggle.text="在新对局中启用"
	toggle.button_pressed=MetaProgress.effect_enabled(kind,id,unit_id)
	toggle.toggled.connect(func(enabled:bool):
		if not MetaProgress.set_effect_enabled(kind,id,unit_id,enabled):
			toggle.set_pressed_no_signal(not enabled)
			Events.emit_message("开关未保存，请重试。",kit.COL_WARN))
	parent.add_child(toggle)

func _faction_name(fid: String) -> String:
	for f in GameData.factions:
		if str(f.get("id", "")) == fid:
			return str(f.get("name", fid))
	return fid

func _has_exclusive_progression(unit_id:String) -> bool:
	return exclusive_cards_by_unit.get(unit_id,[]).any(func(card):return CardScope.exclusive(card)) or not MetaProgress.talent_options(unit_id).is_empty()

func _rebuild_unit_list() -> void:
	if unit_list == null or not is_instance_valid(unit_list):
		return
	bookmarks.remember(unit_list.get_parent())
	bookmarks.restore(unit_list.get_parent(),"unit_list")
	_clear(unit_list)
	if not refit_roster.has(_unit_sel) or (not _unit_filter.is_empty() and GameData.get_entity(_unit_sel).get("faction","")!=_unit_filter):_unit_sel=""
	var featured:=0
	if exclusive_filter.button_pressed:
		var matches:=refit_roster.filter(func(id):
			return _has_exclusive_progression(id) and (_unit_filter.is_empty() or GameData.get_entity(id).get("faction","")==_unit_filter))
		if not matches.has(_unit_sel): _unit_sel=matches.front() if not matches.is_empty() else ""
	for uid: String in refit_roster:
		var u: Dictionary = GameData.get_entity(uid)
		if _unit_filter != "" and str(u.get("faction", "")) != _unit_filter:
			continue
		if exclusive_filter.button_pressed and not _has_exclusive_progression(uid): continue
		var row := kit.make_panel(kit.COL_PANEL_2, kit.COL_LINE)
		row.set_meta("refit_unit",uid)
		if uid == _unit_sel:
			row.add_theme_stylebox_override("panel", kit.panel_style(Color(0.12, 0.22, 0.3), Color(0.45, 0.9, 1.0), 6, 2, 8))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)
		var portrait := UnitIcon.new()
		portrait.animate = false
		portrait.show_status = false
		portrait.setup(u, kit.COL_ACCENT_2)
		portrait.custom_minimum_size = Vector2(48, 38)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(portrait)
		portrait.set_process(false)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		info.add_child(kit.make_label(str(u.get("name", uid)), 14, kit.COL_TEXT))
		var lo := MetaProgress.unit_effective_loadout(uid)
		var has_w: bool = not str(lo.active[0]).is_empty()
		info.add_child(kit.make_label("%s · W %s · 被动%s" % [
			_faction_name(str(u.faction)), "已装配" if has_w else "空",
			"已装配" if not str(lo.passive).is_empty() else "空"], 11, kit.COL_DIM))
		var btn := kit.make_button("查看", 12)
		btn.name="ViewUnit_"+uid
		btn.custom_minimum_size = Vector2(64, 30)
		btn.pressed.connect(func():
			_unit_sel = uid
			_rebuild_unit_list()
			_rebuild_unit_detail())
		hb.add_child(btn)
		Upgrade.mark(btn,Upgrade.unit_talents(uid) or Upgrade.skills(uid))
		unit_list.add_child(row)
		if _has_exclusive_progression(uid):
			unit_list.move_child(row,featured)
			featured+=1
		if not MetaProgress.talent_options(uid).is_empty():
			info.add_child(kit.make_label((NewContent.MARK if NewContent.unit_talents(uid) else "")+"专属天赋",11,kit.COL_GOLD if NewContent.unit_talents(uid) else kit.COL_ACCENT))

func _rebuild_unit_detail() -> void:
	if unit_detail == null or not is_instance_valid(unit_detail):
		return
	bookmarks.remember(unit_detail.get_parent())
	bookmarks.restore(unit_detail.get_parent(),"unit/"+_unit_sel)
	bookmarks.set_value("unit",_unit_sel)
	bookmarks.set_value("faction",_unit_filter)
	bookmarks.set_value("exclusive",exclusive_filter.button_pressed)
	_clear(unit_detail)
	auto_skill_selected.disabled = not refit_roster.has(_unit_sel)
	Upgrade.mark(auto_skill_selected,not auto_skill_selected.disabled and Upgrade.skills(_unit_sel))
	auto_skill_selected.tooltip_text = "先在左侧选择兵种。" if auto_skill_selected.disabled else "自动配置 %s 的 W 主动和被动技能。" % GameData.get_entity(_unit_sel).get("name",_unit_sel)
	if _unit_sel == "":
		_detail_hint("← 左侧选择一个单位，开始改造与技能装配。")
		return
	if preload("res://scripts/rules/skill_scope.gd").defense(_unit_sel):
		_detail_hint(str(GameData.get_building(_unit_sel).get("name",_unit_sel))+" · 防御建筑技能装配")
		_build_exclusive_cards()
		_build_unit_talents(_unit_sel)
		var active_options:=MetaProgress.owned_skills("active").filter(func(card):return UnitSkillLayout.equippable(_unit_sel,card.id))
		var passive_options:=MetaProgress.owned_skills("passive").filter(func(card):return UnitSkillLayout.compatible(_unit_sel,card.id))
		_build_skill_slot("W 装配主动","active",0,MetaProgress.unit_effective_loadout(_unit_sel).active[0],active_options)
		_build_skill_slot("被动技能","passive",0,MetaProgress.unit_effective_loadout(_unit_sel).passive,passive_options)
		return
	var u := GameData.get_unit(_unit_sel)
	if u.is_empty():
		_detail_hint("暂时无法查看这个兵种的资料，请重新选择。")
		return

	# 头部
	var head := kit.make_panel(kit.COL_PANEL_2, kit.COL_ACCENT)
	unit_detail.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 3)
	head.add_child(hv)
	hv.add_child(kit.make_label("%s   <%s>" % [str(u.get("name", _unit_sel)), _faction_name(str(u.get("faction", "")))], 18, kit.COL_ACCENT_2))
	var showcase = preload("res://scripts/ui/unit_showcase.gd").new()
	hv.add_child(showcase)
	showcase.show_unit(_unit_sel)
	hv.add_child(kit.make_label("左键点击暂停 · 按住左右拖动看朝向 · 静置 5 秒归位",12,kit.COL_DIM))
	var skins = preload("res://scripts/ui/unit_skin_picker.gd").new()
	hv.add_child(skins)
	skins.setup(_unit_sel,showcase)
	var paint_button := kit.make_button("转入涂装")
	paint_button.name = "OpenUnitPaint"
	paint_button.tooltip_text = "进入当前兵种的涂装工房，装配皮肤、装饰与武器特效。"
	paint_button.pressed.connect(_open_unit_paint)
	hv.add_child(paint_button)
	var ub := MetaProgress.unit_stat_bonus(_unit_sel)
	var benefits := MetaProgress.skill_training_benefits(_unit_sel)
	var bonus_text := "当前改造加成：攻击 ×%.2f  ·  减伤 ×%.2f" % [float(ub.get("attack_bonus", 1.0)), float(ub.get("defense_bonus", 1.0))]
	if not benefits.is_empty(): bonus_text += "  ·  机制强化 Lv.%d" % MetaProgress.unit_level(_unit_sel, "skill")
	hv.add_child(kit.make_label(bonus_text, 13, kit.COL_OK))
	var overview := kit.make_label(EntityDescription.text(u), 13, kit.COL_TEXT)
	overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(overview)

	_build_exclusive_cards()
	_build_unit_talents(_unit_sel)
	# 三条改造轨道
	unit_detail.add_child(kit.make_label("属性改造", 15, kit.COL_ACCENT))
	for track in MetaProgress.unit_upgrade_tracks():
		if track.get("id") == "skill" and benefits.is_empty(): continue
		_build_track_row(track)
	if benefits.is_empty():
		_detail_hint("这个兵种暂时无法强化自身能力。已购买的等级（Lv.%d）会保留。Q 卡牌、W 技能和装配的被动技能不受影响。" % MetaProgress.unit_level(_unit_sel, "skill"))

	# 技能装配
	unit_detail.add_child(kit.make_label("技能装配（W 主动 + 1 被动）", 15, kit.COL_ACCENT))
	var note := kit.make_label("主动技能在战斗中显示在屏幕底部技能栏，Q 为单位固有主动，W 为装配主动，E 为特殊操作，也可点击释放。通用主动和被动需在技能卡池解锁，抽到后可为多个单位装配。", 11, kit.COL_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_detail.add_child(note)
	_build_skill_editor()

func _detail_hint(text: String) -> void:
	var l := kit.make_label(text, 14, kit.COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_detail.add_child(l)

func _build_track_row(track: Dictionary) -> void:
	var tid := str(track.get("id", ""))
	var lvl := MetaProgress.unit_level(_unit_sel, tid)
	var maxl := int(track.get("max_level", 0))
	var maxed := MetaProgress.unit_upgrade_maxed(_unit_sel, tid)
	var cost := MetaProgress.unit_upgrade_cost(_unit_sel, tid)
	var cur_name := MetaProgress.currency_name(MetaProgress.unit_upgrade_currency(tid))

	var p := kit.make_panel(kit.COL_PANEL_2)
	unit_detail.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	info.add_child(kit.make_label("%s   Lv.%d / %d" % [str(track.get("name", tid)), lvl, maxl], 15, kit.COL_ACCENT_2))
	var detail := str(track.get("desc", ""))
	if tid == "skill":
		detail = preload("res://scripts/rules/skill_training.gd").description(MetaProgress.skill_training_benefits(_unit_sel), maxed)
		detail += "\n从下一局起，上述能力获得强化。更换或升级卡牌不会改变这项加成。"
		if not MetaProgress.effect_enabled("track", tid, _unit_sel): detail += "\n技能强化已停用：以上为重新启用后的数值。"
	var detail_label := kit.make_label(detail, 12, kit.COL_TEXT)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, 10)
	bar.show_percentage = false
	bar.max_value = float(max(1, maxl))
	bar.value = lvl
	bar.add_theme_stylebox_override("background", kit.panel_style(Color(0.06, 0.08, 0.1), Color(0.25, 0.35, 0.45), 3, 1, 0))
	bar.add_theme_stylebox_override("fill", kit.panel_style(Color(0.4, 0.7, 1.0), Color(0.6, 0.9, 1.0), 3, 1, 0))
	info.add_child(bar)
	if lvl>0:_add_effect_switch(info,"track",tid,_unit_sel)

	var btn := kit.make_button("满级" if maxed else "升级 %d %s" % [int(cost), cur_name])
	btn.icon = ProgressIcon.texture("track_"+tid) if maxed else CostIcon.texture(MetaProgress.unit_upgrade_currency(tid))
	btn.custom_minimum_size = Vector2(150, 40)
	if maxed:
		btn.disabled = true
	else:
		btn.disabled = not MetaProgress.can_buy_unit_upgrade(_unit_sel, tid)
		btn.pressed.connect(func():
			if MetaProgress.buy_unit_upgrade(_unit_sel, tid):
				Events.emit_message("%s · %s 升至 Lv.%d" % [
					GameData.get_unit(_unit_sel).get("name", _unit_sel),
					track.get("name", tid), MetaProgress.unit_level(_unit_sel, tid)
				], kit.COL_OK))
	hb.add_child(btn)

func _card_growth_step(card:Dictionary,r:int) -> String:
	if card.get("expansion",false):return MetaProgress.Academy.skill_description(card,r)
	if card.has("objective_by_rank"):return "%d 级 %d 次" % [r,int(card.objective_by_rank[r])]
	var id:String=card.id
	if id=="ap_tesla_chain":return "%d 级 主伤害 +%s%% · 分支 %s%% · 冷却 %s 秒" % [r,MetaProgress.Academy.skill_number(card.primary_bonus_by_rank[r]*100),MetaProgress.Academy.skill_number(card.branch_by_rank[r]*100),Ability.cooldown_text(Ability.cooldown_at_rank(card,r))]
	var seconds:bool=id=="ap_buoy" or card.effect=="stun"
	var value:=float(card.duration if card.effect=="stun" else card.value)*MetaProgress.Academy.card_strength(r,card)
	if card.effect in ["defense_buff","passive_armor"]: value=value/(1.0+value)
	if id == "ap_shock_pulse": return "%d 级 攻击力 %s%% · 冷却 %s 秒" % [r,MetaProgress.Academy.skill_number(value*100),Ability.cooldown_text(Ability.cooldown_at_rank(card,r))]
	var step:="%d 级 %s%s" % [r,MetaProgress.Academy.skill_number(value if seconds else value*100)," 秒" if seconds else "%"]
	if card.has("cooldown_by_rank"): step+=" · 冷却 %s 秒" % Ability.cooldown_text(Ability.cooldown_at_rank(card,r))
	if id=="ap_twin": step+=" · 校射窗口 "+Unit.FactionCards.twin_summary(r)
	if id=="ap_slope": step+=" · 加速 %d%%" % roundi(Unit.FactionCards.slope_speed(r)*100)
	if id=="ps_contact": step+=" · 视野 %s 秒 · 冷却 %d 秒" % [Ability.cooldown_text(Unit.FactionCards.contact_seconds(r)),Unit.FactionCards.contact_cooldown(r)]
	return step

func _open_exclusive_card(id:String) -> void:
	selected_card=id
	training_group=CardScope.group(GameData.get_skill(id))
	_set_page("pool")

func _open_card_demo(id:="",unit_id:="") -> void:
	if id in ["furnace_contract", Unit.Furnace.ACTIVE, Unit.Furnace.PASSIVE]:
		if has_node("FurnaceDemo"): return
		var demo := preload("res://scripts/ui/furnace_demo.gd").new()
		demo.name = "FurnaceDemo"
		demo.entry = id
		demo.return_text = "返回英雄养成" if _page == "heroes" else "返回卡池"
		add_child(demo)
		return
	if has_node("FactionCardDemos"): return
	var gallery:=preload("res://scripts/ui/faction_card_gallery.gd").new()
	if _page=="heroes":gallery.return_label="返回英雄养成"
	elif _page=="pool":gallery.return_label="返回卡池"
	if not id.is_empty():
		gallery.selected=gallery.preview_ids().find(id)
		if gallery.selected<0:
			gallery.free()
			return
		gallery.rank=MetaProgress.Academy.card_rank(MetaProgress,id)
		gallery.refit_unit=unit_id
	gallery.name="FactionCardDemos"
	add_child(gallery)

func _build_exclusive_cards() -> void:
	var cards:Array=exclusive_cards_by_unit.get(_unit_sel,[])
	if cards.is_empty(): return
	unit_detail.add_child(kit.make_label("适用技能卡 · 培养与成长表",17,kit.COL_ACCENT_2))
	for card:Dictionary in cards:
		var id:String=card.id
		var owned:=MetaProgress.skill_unlocked(id)
		var rank:=MetaProgress.Academy.card_rank(MetaProgress,id)
		var panel:=kit.make_panel(kit.COL_PANEL_2,kit.COL_LINE)
		unit_detail.add_child(panel)
		var column:=VBoxContainer.new()
		panel.add_child(column)
		var header:=HBoxContainer.new()
		column.add_child(header)
		var icon:=TextureRect.new()
		icon.texture=ProgressIcon.texture(id)
		header.add_child(icon)
		var title:=kit.make_label("%s · %s %s · %s　%s" % [_rarity_label(card.rarity),CardScope.group(card),"W" if card.type=="active" else "被动",NewContent.card_name(id),"Lv.%d / 3" % rank if owned else "未获得"],15,CardScope.rarity_color(card))
		title.name="CardTitle_"+id
		header.add_child(title)
		var demo:=kit.make_button("▶ 技能演示")
		demo.name="Demo_"+id
		demo.pressed.connect(_open_card_demo.bind(id,_unit_sel))
		header.add_child(demo)
		var spacer:=Control.new()
		spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		var action:=kit.make_button("")
		action.name="Train_"+id
		header.add_child(action)
		if not owned:
			action.text="去卡池获取"
			action.pressed.connect(_open_exclusive_card.bind(id))
		elif rank>=MetaProgress.Academy.CARD_MAX_RANK:
			action.text="已满级"
			action.disabled=true
		else:
			var cost:int=MetaProgress.Academy.card_upgrade_cost(id,rank)
			var missing:=maxi(0,cost-MetaProgress.balance("cores"))
			action.icon=CostIcon.texture("cores")
			action.text="升级至 Lv.%d · %d 战略核心" % [rank+1,cost]
			if missing>0: action.text+="（还差 %d）" % missing
			action.disabled=missing>0
			action.pressed.connect(func():
				if not MetaProgress.Academy.purchase(MetaProgress,"level",id): Events.emit_message("升级未保存，请检查余额或存档。",kit.COL_WARN))
		Upgrade.mark(action,Upgrade.card(id))
		var equip_row:=HBoxContainer.new()
		column.add_child(equip_row)
		var loadout:=MetaProgress.unit_effective_loadout(_unit_sel)
		var slot:String="W" if card.type=="active" else "被动"
		var current:String=str(loadout.active[0]) if card.type=="active" else str(loadout.passive)
		var installed:bool=current==id
		var compatible:bool=UnitSkillLayout.equippable(_unit_sel,id) if card.type=="active" else UnitSkillLayout.compatible(_unit_sel,id)
		var quick:=kit.make_button("已装配到 "+slot if installed else "快速装配到 "+slot)
		quick.name="QuickEquip_"+id
		quick.disabled=installed or not owned or not compatible
		quick.tooltip_text="已装配此技能。" if installed else ("先获取此技能卡。" if not owned else ("该单位无法装配此卡。" if not compatible else "立即装配并保存；替换当前 "+slot+" 槽位技能。"))
		quick.pressed.connect(_quick_equip_card.bind(_unit_sel,id))
		equip_row.add_child(quick)
		Upgrade.mark(quick,current.is_empty() and not quick.disabled)
		var status:String="当前："+str(GameData.get_skill(current).get("name",current)) if not current.is_empty() else "当前槽位为空"
		equip_row.add_child(kit.make_label(status,13,kit.COL_DIM))
		column.add_child(kit.make_label(str(card.get("stat","各级技能效果")),13,kit.COL_TEXT))
		var chart:=HBoxContainer.new()
		chart.name="Growth_"+id
		column.add_child(chart)
		for r in range(MetaProgress.Academy.CARD_MAX_RANK+1):
			var cell:=kit.make_label(_card_growth_step(card,r).replace(" · ","\n"),13,CardScope.rarity_color(card) if owned and rank==r else kit.COL_TEXT)
			cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			cell.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			cell.mouse_filter=Control.MOUSE_FILTER_PASS
			cell.tooltip_text=MetaProgress.Academy.skill_description(card,r)
			chart.add_child(cell)

func _quick_equip_card(unit_id:String,id:String) -> void:
	var card:=GameData.get_skill(id)
	if card.is_empty():return
	if not MetaProgress.set_unit_skill(unit_id,str(card.type),0,id):
		Events.emit_message("装配未保存，请检查卡牌是否已获取、是否适用或存档是否可写。",kit.COL_WARN)
		return
	Events.emit_message("已装配 %s 到 %s 槽位" % [card.name,"W" if card.type=="active" else "被动"],kit.COL_OK)

func _auto_configure_skills(all_units: bool) -> void:
	if not all_units and not refit_roster.has(_unit_sel): return
	var result := MetaProgress.auto_configure_unit_skills(refit_roster if all_units else [_unit_sel])
	if not result.ok:
		auto_skill_result.text = "技能装配未能保存，请重试。"
		auto_skill_result.add_theme_color_override("font_color",kit.COL_WARN)
		return
	auto_skill_result.add_theme_color_override("font_color",kit.COL_OK)
	auto_skill_result.text = "已调整 %d / %d 种单位的技能，从下一场扩展对局生效。" % [result.changed,result.total] if result.changed > 0 else "没有需要替换的技能。"

func _build_skill_editor() -> void:
	var lo := MetaProgress.unit_effective_loadout(_unit_sel)
	var active_pool := MetaProgress.owned_skills("active")
	active_pool = active_pool.filter(func(skill): return UnitSkillLayout.equippable(_unit_sel, str(skill.id)))
	var passive_pool := MetaProgress.owned_skills("passive").filter(func(skill): return UnitSkillLayout.compatible(_unit_sel,skill.id))

	var open_pool := kit.make_button("去技能卡池")
	open_pool.pressed.connect(func(): _set_page("pool"))
	unit_detail.add_child(open_pool)

	var innate := UnitSkillLayout.primary_id(_unit_sel)
	var innate_name := str(GameData.get_skill(innate).get("name", {"ggi_guard": "固守", "allied_engineer": "工程作业", "allied_infiltrate": "渗透", "allied_c4": "安装 C4", "allied_chrono": "超时空移动"}.get(innate, "暂无")))
	unit_detail.add_child(kit.make_label("Q 固有主动：%s（单位自带，不可替换）" % innate_name, 14, kit.COL_ACCENT_2))
	var cur_active: Array = lo.get("active", [])
	_build_skill_slot("W 装配主动", "active", 0, str(cur_active[0]) if not cur_active.is_empty() else "", active_pool)

	_build_skill_slot("被动技能", "passive", 0, str(lo.get("passive", "")), passive_pool)
	unit_detail.add_child(kit.make_label("E 特殊操作：保留给卧倒、模式切换、卸载乘员等单位原有操作；无对应操作时留空。", 12, kit.COL_DIM))

	var clr := kit.make_button("清空装配（恢复默认）", 13)
	clr.custom_minimum_size = Vector2(220, 34)
	clr.pressed.connect(func():
		MetaProgress.clear_unit_loadout(_unit_sel)
		Events.emit_message("已恢复 %s 的默认技能装配" % GameData.get_unit(_unit_sel).get("name", _unit_sel), kit.COL_OK))
	unit_detail.add_child(clr)

func _rarity_label(r: String) -> String:
	match r:
		"ultimate":return "究极传说"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legend":
			return "传说"
		_:
			return "普通"

func _colored_card(card:Dictionary,text:String) -> String:
	return "[color=#%s]%s[/color]" % [CardScope.rarity_color(card).to_html(false),text]

func _card_text(text:String,font_size:int=14) -> RichTextLabel:
	var label:=RichTextLabel.new()
	label.bbcode_enabled=true;label.fit_content=true;label.scroll_active=false
	label.add_theme_font_size_override("normal_font_size",font_size)
	label.text=text
	return label

func _roll_cards(count: int, daily_free := false) -> void:
	var rows := MetaProgress.Academy.draw(MetaProgress, count, daily_free)
	var names := PackedStringArray()
	for row in rows:
		var contract:=ContractPool.entry(str(row.id))
		if not contract.is_empty():
			names.append("[color=#ffd454]究极传说 · %s[/color]"%contract.name)
			continue
		var card:=GameData.get_skill(row.id)
		names.append(_colored_card(card,str(card.name) + ("（重复 +%d）" % row.extra if row["duplicate"] else "（新）")))
	pool_result = "、".join(names) if not names.is_empty() else "抽取未完成"
	_refresh_pool()

func _refresh_pool() -> void:
	_clear(pool_body)
	var cards := MetaProgress.skill_draw_candidates()
	var remaining := cards.filter(func(card): return not MetaProgress.skill_unlocked(card.id)).size()
	var state := MetaProgress.academy
	var contract_count:=ContractPool.entries().size()
	var contract_owned:=ContractPool.owned_count(MetaProgress)
	var collection:=kit.make_label("技能卡池　已收集 %d / %d（常规卡 %d/%d · 英雄契约 %d/%d）" % [cards.size()-remaining+contract_owned,cards.size()+contract_count,cards.size()-remaining,cards.size(),contract_owned,contract_count],20,kit.COL_ACCENT_2)
	collection.name="PoolCollection"
	collection.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pool_body.add_child(collection)
	var pool_wallet:=HBoxContainer.new()
	pool_body.add_child(pool_wallet)
	CostIcon.balance_label(pool_wallet,"card_shards","兑换碎片 %d"%state.get("card_shards",0),16,kit.COL_ACCENT_2)
	CostIcon.balance_label(pool_wallet,"tickets","技能券 %d"%state.get("tickets",0),16,kit.COL_ACCENT_2)
	var rarity_rates:=PackedStringArray()
	for rarity in MetaProgress.skill_draw_rules().rarity_weight:
		rarity_rates.append("%s %s%%"%[_rarity_label(rarity),String.num(float(MetaProgress.skill_draw_rules().rarity_weight[rarity]),2)])
	var regular_rules:=kit.make_label("常规卡稀有度　"+"　".join(rarity_rates)+"　｜　每抽 1 碎片，重复额外 +1/2/5/12。史诗 50 碎片，传说 200 碎片。",14,kit.COL_TEXT)
	regular_rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pool_body.add_child(regular_rules)
	var contract_rules:=kit.make_label(ContractPool.summary(MetaProgress)+" 未抽中契约时，按上方常规卡稀有度抽取。",14,kit.COL_GOLD)
	contract_rules.name="ContractDrawRules"
	contract_rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pool_body.add_child(contract_rules)
	var controls := HBoxContainer.new()
	pool_body.add_child(controls)
	pool_date = MetaProgress.Academy.day()
	var available := MetaProgress.Academy.daily_draw_available(MetaProgress, pool_date)
	var free_draw := kit.make_button("每日免费单抽" if available else "今日已抽 · 明日刷新")
	free_draw.name = "FreeDailySkill"
	free_draw.disabled = not available or not MetaProgress.skill_draw_enabled()
	free_draw.pressed.connect(_roll_cards.bind(1, true))
	controls.add_child(free_draw)
	for n in [1,10]:
		var tickets := mini(n, int(state.get("tickets", 0)))
		var cost: float = (n - tickets) * MetaProgress.skill_draw_cost()
		var price := "%d 钻石" % cost if tickets == 0 else "%d 张券" % tickets
		if tickets > 0 and cost > 0: price += " + %d 钻石" % cost
		var draw := kit.make_button("抽 %d 次 · %s" % [n, price])
		draw.icon=CostIcon.texture("tickets","diamonds" if cost>0 else "") if tickets>0 else CostIcon.texture("diamonds")
		draw.name = "DrawSkill" if n == 1 else "DrawTen"
		draw.disabled = not MetaProgress.skill_draw_enabled() or MetaProgress.balance("diamonds") < cost
		draw.pressed.connect(_roll_cards.bind(n))
		controls.add_child(draw)
	if not pool_result.is_empty():
		var result_label := _card_text(pool_result,15)
		pool_body.add_child(result_label)
	var demos := kit.make_button("技能卡演示 · %d 张常规卡 · %d 个英雄契约 / %d 张奖励卡" % [cards.size(),contract_count,ContractPool.reward_count()])
	demos.name = "CardDemos"
	demos.pressed.connect(_open_card_demo)
	pool_body.add_child(demos)
	pool_body.add_child(kit.make_label("技能培养　获得即为 0 级　｜　最高 3 级，选中卡牌可查看各级效果", 15, kit.COL_GOLD))
	var groups:Dictionary={"通用":[],"多单位":[],"专属":[],"英雄":[]}
	var legend:=kit.make_label("品质：传说黄／史诗紫／稀有蓝／普通白；专属仅限一个兵种。图标轮廓表示适用场景，右下角表示效果；多兵种卡列为多单位。",12,kit.COL_DIM)
	legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;pool_body.add_child(legend)
	for card in cards:
		var category:=CardScope.group(card)
		groups[category].append(card)
	for id in MetaProgress.unlocked_skills:
		var card:=GameData.get_skill(id)
		if GameData.is_gacha_skill(id) and not card.is_empty() and not cards.has(card):
			groups.get_or_add("已退池",[]).append(card)
	var group_picker:=OptionButton.new()
	group_picker.name="TrainingGroup"
	pool_body.add_child(group_picker)
	if not groups.has(training_group): training_group="通用"
	for category in groups:
		group_picker.add_item("英雄（%d 个契约 · %d 张奖励卡）"%[contract_count,ContractPool.reward_count()] if category=="英雄" else "%s（%d 张）" % [category,groups[category].size()])
		if groups[category].any(func(card):return Upgrade.legend_unlock(str(card.id))):
			group_picker.set_item_text(group_picker.item_count-1,group_picker.get_item_text(group_picker.item_count-1)+" · 传说可解锁")
			Upgrade.mark(group_picker,true)
		group_picker.set_item_metadata(group_picker.item_count-1,category)
		if category==training_group: group_picker.select(group_picker.item_count-1)
	group_picker.item_selected.connect(func(index):
		training_group=group_picker.get_item_metadata(index)
		_refresh_pool())
	if training_group=="英雄":
		for contract in ContractPool.entries():
			if contract.hero_id=="E2":
				var panel:=preload("res://scripts/ui/furnace_contract_panel.gd").new()
				panel.demo_requested.connect(_open_card_demo)
				pool_body.add_child(panel)
				panel.refresh()
			else:
				var hero_panel:=preload("res://scripts/ui/expansion_contract_panel.gd").new()
				hero_panel.name="HeroContract_"+str(contract.hero_id)
				hero_panel.demo_requested.connect(_open_card_demo)
				pool_body.add_child(hero_panel)
				hero_panel.refresh(str(contract.hero_id))
	else:
		_build_pool_training(groups[training_group],state)
	for kind in ["active", "passive"]:
		pool_body.add_child(kit.make_label("W 主动" if kind == "active" else "被动", 16, kit.COL_ACCENT))
		var entries:=HFlowContainer.new()
		entries.name="PoolEntries_"+kind
		entries.add_theme_constant_override("h_separation",6)
		entries.add_theme_constant_override("v_separation",4)
		pool_body.add_child(entries)
		for card in cards:
			if card.type == kind:
				var entry:=preload("res://scripts/ui/skill_pool_entry.gd").new()
				entry.setup(card,"%s（%s%s）" % [NewContent.card_name(card.id),_rarity_label(str(card.get("rarity","common")))," · 已有" if MetaProgress.skill_unlocked(card.id) else ""])
				entries.add_child(entry)
				entry.pressed.connect(func():
					training_group=CardScope.group(card)
					selected_card=card.id
					_refresh_pool())

func _build_pool_training(entries:Array,state:Dictionary) -> void:
	var selector := OptionButton.new()
	selector.name="TrainingCard"
	pool_body.add_child(selector)
	var preview_rank:=kit.make_option(["预览 0 级","预览 1 级","预览 2 级","预览 3 级"],0,14)
	preview_rank.name="TrainingPreviewRank"
	pool_body.add_child(preview_rank)
	var growth := kit.make_label("",14,kit.COL_ACCENT_2)
	growth.name="TrainingDescription"
	growth.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pool_body.add_child(growth)
	var comparison:=kit.make_label("",14,kit.COL_GOLD)
	comparison.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pool_body.add_child(comparison)
	var action := kit.make_button("")
	action.name="TrainingUpgrade"
	pool_body.add_child(action)
	for card:Dictionary in entries:
		var owned:=MetaProgress.skill_unlocked(str(card.id))
		var rank:=MetaProgress.Academy.card_rank(MetaProgress,str(card.id))
		var progress:="已获得 · Lv.%d/%d" % [rank,MetaProgress.Academy.CARD_MAX_RANK] if owned else "未获得"
		var label := "%s · %s　｜　%s" % [_rarity_label(card.rarity),NewContent.card_name(card.id),progress]
		if Upgrade.card(str(card.id)):label+=" · 可升级"
		elif Upgrade.legend_unlock(str(card.id)):label+=" · 可解锁"
		selector.add_icon_item(ProgressIcon.texture(str(card.id)), label)
		selector.set_item_metadata(selector.item_count-1,card.id)
		if card.id == selected_card: selector.select(selector.item_count-1)
	var update := func(index):
		var id: String = selector.get_item_metadata(index)
		selected_card = id
		var card := GameData.get_skill(id)
		var level := MetaProgress.Academy.card_rank(MetaProgress,id)
		for style_key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:selector.add_theme_color_override(style_key,CardScope.rarity_color(card))
		comparison.add_theme_color_override("font_color",CardScope.rarity_color(card))
		preview_rank.select(level)
		var steps:=PackedStringArray()
		for r in range(MetaProgress.Academy.CARD_MAX_RANK+1):
			preview_rank.get_popup().set_item_tooltip(r,MetaProgress.Academy.skill_description(card,r))
			steps.append(_card_growth_step(card,r))
		comparison.text="%s　｜　%s" % [card.get("stat","效果成长"),"　→　".join(steps)]
		growth.text=MetaProgress.Academy.skill_description(card,level)
		var maxed := level >= MetaProgress.Academy.CARD_MAX_RANK
		var next_cost := MetaProgress.Academy.card_upgrade_cost(id,level)
		var owned := MetaProgress.skill_unlocked(id)
		var cost := int(MetaProgress.Academy.EXCHANGE.get(GameData.get_skill(id).rarity,0))
		action.text = ("技能 3 级 · 已满级" if maxed else "技能 %d 级 → %d 级 · %d 战略核心" % [level,level+1,next_cost]) if owned else ("兑换需 %d 碎片" % cost if cost>0 else "通过抽取获得")
		action.disabled = (maxed or MetaProgress.balance("cores")<next_cost) if owned else (cost==0 or int(state.get("card_shards",0))<cost)
		action.icon = CostIcon.texture("cores") if owned and not maxed else CostIcon.texture("card_shards") if not owned and cost>0 else null
		Upgrade.mark(action,Upgrade.card(id) or Upgrade.legend_unlock(id))
	preview_rank.item_selected.connect(func(rank:int):
		growth.text=MetaProgress.Academy.skill_description(GameData.get_skill(selected_card),rank))
	selector.item_selected.connect(update)
	if selector.item_count>0: update.call(selector.selected)
	action.pressed.connect(func():
		var id: String = selector.get_item_metadata(selector.selected)
		MetaProgress.Academy.purchase(MetaProgress,"level" if MetaProgress.skill_unlocked(id) else "redeem",id))

func _build_skill_slot(label_text: String, slot_type: String, index: int, current: String, pool: Array) -> void:
	var p := kit.make_panel(kit.COL_PANEL_2)
	unit_detail.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)

	var l := kit.make_label(label_text, 14, kit.COL_TEXT)
	l.custom_minimum_size = Vector2(110, 0)
	hb.add_child(l)

	var items: Array = ["（空）"]
	var ids: Array = [""]
	var sel := 0
	for sk in pool:
		var sid := str(sk.get("id", ""))
		var exclusive:bool=CardScope.exclusive(sk)
		items.append(_rarity_label(sk.get("rarity","common"))+" · "+("专属 · " if exclusive else "")+str(sk.get("name", sid)))
		ids.append(sid)
		if sid == current:
			sel = ids.size() - 1
	var opt := kit.make_option(items, sel, 13)
	opt.name="EquipSlot_"+slot_type
	opt.custom_minimum_size = Vector2(200, 32)
	opt.set_meta("ids", ids)
	var menu:=opt.get_popup()
	menu.set_item_tooltip(0,"此槽位不装配技能。")
	for i in pool.size():
		opt.set_item_icon(i+1,ProgressIcon.texture(ids[i+1]))
		if sel==i+1:
			for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
				opt.add_theme_color_override(state,CardScope.rarity_color(pool[i]))
		var rank:=MetaProgress.Academy.card_rank(MetaProgress,ids[i+1])
		menu.set_item_tooltip(i+1,"%s\n%s" % [pool[i].name,MetaProgress.Academy.skill_description(pool[i],rank)])
	opt.tooltip_text=menu.get_item_tooltip(sel)
	opt.item_selected.connect(func(i):
		var chosen := str(ids[i]) if i < ids.size() else ""
		if not MetaProgress.set_unit_skill(_unit_sel, slot_type, index, chosen):
			opt.select(sel)
			Events.emit_message("该技能尚未解锁，需先在技能库中抽取", kit.COL_WARN))
	hb.add_child(opt)
	Upgrade.mark(opt,Upgrade.skill_slots(_unit_sel)[slot_type])

	var desc := ""
	for sk in pool:
		if str(sk.get("id", "")) == current:
			desc = MetaProgress.Academy.skill_description(sk,MetaProgress.Academy.card_rank(MetaProgress,current))
			break
	var dl := kit.make_label(desc, 11, kit.COL_DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(dl)

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

# ------------------------------------------------------------------ 主循环 / 刷新

func _process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK
		if tasks.visible: tasks.refresh()
		if _page == "pool" and pool_date != MetaProgress.Academy.day(): _refresh_pool()
		MetaProgress.accrue_idle()
		_update_idle_labels()

func _refresh() -> void:
	if is_instance_valid(unit_paint): return
	const Research = preload("res://scripts/expedition/research.gd")
	Research.mark_entry(expedition_tab)
	if expedition_scroll.visible: Research.populate(expedition_tree)
	Upgrade.mark(hero_tab,Upgrade.any_hero())
	var upgrade_names:=Upgrade.pool_upgrade_names()
	pool_tab.tooltip_text="红点：有 %d 张已获得技能未满级，且战略核心足够升级。\n%s%s" % [upgrade_names.size(),"、".join(upgrade_names.slice(0,5)),"等；在培养分类中查看。" if upgrade_names.size()>5 else ""] if not upgrade_names.is_empty() else "技能卡池：抽取、查看效果和培养技能。当前没有可支付的技能升级。"
	var unlock_names:=PackedStringArray()
	for card:Dictionary in MetaProgress.skill_draw_candidates():
		if Upgrade.legend_unlock(str(card.id)):unlock_names.append(str(card.name))
	Upgrade.mark(pool_tab,not upgrade_names.is_empty() or not unlock_names.is_empty())
	if not unlock_names.is_empty():
		var unlock_tip:="红点：有 %d 张未获得传说技能，兑换碎片足够解锁。\n%s%s"%[unlock_names.size(),"、".join(unlock_names.slice(0,5)),"等；在培养分类中查看。" if unlock_names.size()>5 else ""]
		pool_tab.tooltip_text=unlock_tip if upgrade_names.is_empty() else pool_tab.tooltip_text+"\n"+unlock_tip
	var missing_skills:=Upgrade.any_unit_skills()
	Upgrade.mark(tab_units_btn,Upgrade.any_unit_talent() or missing_skills)
	Upgrade.mark(auto_skill_all,missing_skills)
	if _page == "heroes": heroes.refresh()
	if _page == "pool": _refresh_pool()
	if _page=="shop":_refresh_shop()
	credits_label.text = "军需券 %s" % _fmt(MetaProgress.balance("credits"))
	cores_label.text = "战略核心 %s" % _fmt(MetaProgress.balance("cores"))
	diamonds_label.text = "钻石 %s" % _fmt(MetaProgress.balance("diamonds"))
	_update_idle_labels()
	_rebuild_tiers()
	_rebuild_upgrades()
	var b := MetaProgress.stat_bonuses()
	bonus_label.text = "当前全局加成：攻击 ×%.2f · 减伤 ×%.2f · 生命 ×%.2f · 速度 ×%.2f · 建造 ×%.2f · 收益 ×%.2f" % [
		b.attack_bonus, b.defense_bonus, b.hp_bonus, b.speed_bonus, b.build_bonus, b.income_bonus
	]
	if _page == "units":
		_rebuild_unit_list()
		_rebuild_unit_detail()

func _update_idle_labels() -> void:
	var rate := MetaProgress.hourly_rate()
	var pending := MetaProgress.pending_rewards()
	var cap := MetaProgress.cap_hours()
	var hours := MetaProgress.pending_hours()
	var seconds := floori(hours * 3600.0 + 0.000001)
	rate_label.text = "速率：军需券 %.0f/时 · 核心 %.1f/时\n累积上限：%.1f 小时　当前已攒：%02d:%02d:%02d" % [
		rate.credits, rate.cores, cap, floori(seconds / 3600.0), floori(seconds / 60.0) % 60, seconds % 60
	]
	pending_label.text = "军需券 %s" % _fmt(pending.credits)
	pending_cores_label.text = "战略核心 %s" % _fmt(pending.cores)
	cap_bar.value = clampf(hours / max(0.1, cap) * 100.0, 0.0, 100.0)

func _fmt(v: float) -> String:
	if v >= 100000.0:
		return "%.1f万" % (v / 10000.0)
	return str(int(v))

# ------------------------------------------------------------------ 档位

func _rebuild_tiers() -> void:
	_clear(tier_list)
	var next := MetaProgress.next_tier()
	for t in MetaProgress.tiers():
		var tid := str(t.get("id", ""))
		var is_current := MetaProgress.current_tier == tid
		if not is_current and tid != next: continue
		var p := kit.make_panel(kit.COL_PANEL_2, kit.COL_LINE)
		if is_current:
			p.add_theme_stylebox_override("panel", kit.panel_style(Color(0.12, 0.22, 0.3), Color(0.45, 0.9, 1.0), 6, 2, 8))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		p.add_child(hb)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		var title := str(t.get("name", ""))
		if is_current:
			title += "   ★ 当前"
		info.add_child(kit.make_label(title, 15, kit.COL_GOLD if is_current else kit.COL_TEXT))
		var inc: Dictionary = t.get("income_per_hour", {})
		info.add_child(kit.make_label("收益 %d 券/时 · %.0f 核心/时 · 上限 %.0f 时" % [
			int(inc.get("credits", 0)), float(inc.get("cores", 0)), float(t.get("cap_hours", 0))
		], 12, kit.COL_TEXT))
		var sb: Dictionary = t.get("stat_bonus", {})
		info.add_child(kit.make_label("加成 攻×%.2f 减×%.2f 血×%.2f 速×%.2f" % [
			float(sb.get("attack_bonus", 1)), float(sb.get("defense_bonus", 1)),
			float(sb.get("hp_bonus", 1)), float(sb.get("speed_bonus", 1))
		], 12, kit.COL_DIM))
		var desc := kit.make_label(str(t.get("desc", "")), 11, kit.COL_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(250, 0)
		info.add_child(desc)

		var btn := kit.make_button("")
		btn.icon = ProgressIcon.texture(str(t.id))
		btn.custom_minimum_size = Vector2(120, 40)
		if is_current:
			btn.text = "已达最高档" if next.is_empty() else "当前档位"
			btn.disabled = true
		else:
			btn.icon=CostIcon.texture("credits")
			btn.text = "升级 · %d 军需券" % int(MetaProgress.tier_unlock_cost(tid))
			btn.disabled = not MetaProgress.can_unlock_tier(tid)
			btn.pressed.connect(func():
				if MetaProgress.unlock_tier(tid):
					Events.emit_message("已升至 %s" % t.name, kit.COL_OK)
				else:
					Events.emit_message("升级未完成，请检查余额或存档。", kit.COL_WARN))
		hb.add_child(btn)
		tier_list.add_child(p)

# ------------------------------------------------------------------ 升级

func _rebuild_upgrades() -> void:
	for c in upgrade_list.get_children():
		c.queue_free()
	for u in MetaProgress.upgrades():
		var uid := str(u.get("id", ""))
		var lvl := MetaProgress.upgrade_level(uid)
		var maxed := MetaProgress.upgrade_is_maxed(uid)
		var cost := MetaProgress.upgrade_cost(uid)
		var cur_name := MetaProgress.currency_name(MetaProgress.upgrade_currency(uid))

		var p := kit.make_panel(kit.COL_PANEL_2)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		p.add_child(hb)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		info.add_child(kit.make_label("%s   Lv.%d / %d" % [u.get("name", ""), lvl, int(u.get("max_level", 0))], 15, kit.COL_ACCENT_2))
		info.add_child(kit.make_label(str(u.get("desc", "")), 12, kit.COL_TEXT))
		# 效果条
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(280, 10)
		bar.show_percentage = false
		bar.max_value = float(u.get("max_level", 1))
		bar.value = lvl
		bar.add_theme_stylebox_override("background", kit.panel_style(Color(0.06, 0.08, 0.1), Color(0.25, 0.35, 0.45), 3, 1, 0))
		bar.add_theme_stylebox_override("fill", kit.panel_style(Color(0.4, 0.7, 1.0), Color(0.6, 0.9, 1.0), 3, 1, 0))
		info.add_child(bar)

		var btn := kit.make_button("满级" if maxed else "升级 %d %s" % [int(cost), cur_name])
		btn.icon = ProgressIcon.texture(uid) if maxed else CostIcon.texture(MetaProgress.upgrade_currency(uid))
		btn.custom_minimum_size = Vector2(150, 40)
		if maxed:
			btn.disabled = true
		else:
			btn.disabled = not MetaProgress.can_buy_upgrade(uid)
			btn.pressed.connect(func():
				if MetaProgress.buy_upgrade(uid):
					Events.emit_message("%s 升至 Lv.%d" % [u.get("name", ""), MetaProgress.upgrade_level(uid)], kit.COL_OK)
					_refresh())
		hb.add_child(btn)

		upgrade_list.add_child(p)

func _save_bookmarks() -> void:
	if is_instance_valid(unit_list):bookmarks.remember(unit_list.get_parent())
	if is_instance_valid(unit_detail):bookmarks.remember(unit_detail.get_parent())
	if is_instance_valid(heroes):bookmarks.remember(heroes)
	bookmarks.save()

func _exit_tree() -> void:
	# Child ScrollContainers have already left the tree when this callback runs.
	if _page=="units":
		if is_instance_valid(unit_list):bookmarks.remember(unit_list.get_parent(),true)
		if is_instance_valid(unit_detail):bookmarks.remember(unit_detail.get_parent(),true)
	_save_bookmarks()
