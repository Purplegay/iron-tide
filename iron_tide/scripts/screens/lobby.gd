extends Control
class_name Lobby
## 关卡选择。列出全部战役，显示简报与推荐，点击进入战斗场景；顶部提供遭遇战入口。

const Preferences = preload("res://scripts/ui/lobby_preferences.gd")

@onready var kit = UiKit

var _map_memory := ConfigFile.new()
const Houses = preload("res://scripts/rules/skirmish_houses.gd")
var _spawn_owner:=0
var _team_rows: Array = []
var _team_grid: GridContainer
var _start_button: Button
var _victory_reward_label: Label
var _color_opt: OptionButton
var _map_opt: OptionButton
var _layout_opt: OptionButton
var _funds_opt: OptionButton
var _enemy_opt: OptionButton
var _diff_opt: OptionButton
var _country_opt: OptionButton
var _mode_opt: OptionButton
var _opening_opt: OptionButton
var _victory_opt: OptionButton
var _fog_check: CheckBox
var _map_preview:Control
var _map_description:Label
var _preferences_status: Label

func _ready() -> void:
	Music.set_context("menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_restore_preferences()
	_refresh_map_preview()
	var controls := _preference_controls()
	for key in controls:
		controls[key].item_selected.connect(_preference_selected.bind(key))
	_color_opt.item_selected.connect(func(_index: int):
		HouseColor.set_player(str(_color_opt.get_item_metadata(_index)))
		_save_preferences()
		_build_team_rows())
	_fog_check.toggled.connect(func(_pressed: bool): _save_preferences())

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.068)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	vb.offset_left = 24
	vb.offset_right = -24
	vb.offset_top = 18
	vb.offset_bottom = -18
	add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	top.add_child(kit.make_label("战 役 选 择", 26, kit.COL_ACCENT_2))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(kit.make_label("扩展模式增益：攻击 ×%.2f · 生命 ×%.2f · 减伤 ×%.2f" % [
		MetaProgress.stat_bonuses().attack_bonus,
		MetaProgress.stat_bonuses().hp_bonus,
		MetaProgress.stat_bonuses().defense_bonus
	], 14, kit.COL_OK))
	var back := kit.make_button("返回主菜单")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	top.add_child(back)

	vb.add_child(kit.divider())
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 18)
	vb.add_child(mode_row)
	_mode_opt = _opt(mode_row, "遭遇战规则", ["红警 2 经典规则", "Iron Tide 扩展"], 0 if BattleRequest.rules_mode == MatchRules.RA2 else 1)
	_opening_opt = _opt(mode_row, "开局方式", ["预建基地", "基地车开局"], 1 if BattleRequest.skirmish_config.get("opening", "") == "mcv" else 0)
	_opening_opt.tooltip_text = "基地车开局：双方仅一辆基地车，无预建建筑和矿车。\n选中基地车按 J 展开；先建电厂、矿场，再由矿场制造矿车。\n因矿车单独付费，初始资金至少 8000。仅 RA2 模式支持。"
	_opening_opt.item_selected.connect(_on_opening_selected)
	mode_row.add_child(kit.make_label("经典规则下，可率领盟军或苏联基础部队作战。局外养成和自定义技能只在扩展模式生效。\n想挑战一波波来袭的敌军，可选择下方的扩展战役。", 13, kit.COL_DIM))
	var rule_row := HBoxContainer.new()
	rule_row.add_theme_constant_override("separation", 18)
	vb.add_child(rule_row)
	_victory_opt = _opt(rule_row, "胜负规则", ["短局 · 基地建筑与基地车", "歼灭 · 全部建筑与单位"], 1 if BattleRequest.skirmish_config.get("victory_condition", "short") == "annihilation" else 0)
	_victory_opt.tooltip_text = "双方同一判定时刻均无存活目标时为平局，不发放养成奖励。战役仍使用各自目标。"
	_fog_check = kit.make_check("战争迷雾", BattleRequest.skirmish_config.get("fog_of_war", true) == true)
	_fog_check.tooltip_text = "未探索区域隐藏；已探索地形保留，失去视野的敌军不可选取或持续锁定。双方遵守相同视野规则；开局仅标明各自最近矿区的地形位置，不揭露敌军。"
	rule_row.add_child(_fog_check)
	_color_opt = HouseColor.color_picker(HouseColor.player_id)
	_layout_opt = _opt(rule_row, "地图（含尤复原图）", preload("res://scripts/world/skirmish_maps.gd").NAMES, 0)
	for i in Preferences.OPTIONS.map_layout.size():
		var map_id:String=Preferences.OPTIONS.map_layout[i]
		_layout_opt.get_popup().set_item_tooltip(i,str(preload("res://scripts/world/skirmish_maps.gd").MAPS.get(map_id,{}).get("desc","")))
	_preferences_status = kit.make_label("设置保存失败，请检查磁盘空间或目录权限", 12, kit.COL_GOLD)
	_preferences_status.hide()
	rule_row.add_child(_preferences_status)
	vb.add_child(_skirmish_panel())
	var roster_panel := kit.make_panel(kit.COL_PANEL, Color(0.32,0.43,0.54))
	var match_row := HBoxContainer.new()
	match_row.add_theme_constant_override("separation",18)
	vb.add_child(match_row)
	match_row.add_child(roster_panel)
	_team_grid = GridContainer.new()
	_team_grid.columns = 6
	_team_grid.add_theme_constant_override("h_separation", 14)
	_team_grid.add_theme_constant_override("v_separation", 3)
	roster_panel.add_child(_team_grid)
	var preview_row:=VBoxContainer.new()
	preview_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_theme_constant_override("separation",18)
	match_row.add_child(preview_row)
	_map_preview=preload("res://scripts/ui/map_preview.gd").new()
	_map_preview.custom_minimum_size=Vector2(300,156)
	_map_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview_row.add_child(_map_preview)
	_map_preview.spawn_clicked.connect(_assign_spawn)
	_map_description=kit.make_label("",15,kit.COL_TEXT)
	_map_description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_map_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preview_row.add_child(_map_description)
	_mode_opt.item_selected.connect(_on_mode_selected)
	_on_mode_selected(_mode_opt.selected)
	vb.add_child(kit.divider())

	var sc := kit.make_scroll()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)

	for m in GameData.missions:
		list.add_child(_mission_card(m))

func _mission_card(m: Dictionary) -> PanelContainer:
	var p := kit.make_panel(kit.COL_PANEL, Color(0.28, 0.45, 0.65))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	p.add_child(hb)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	left.add_child(kit.make_label("%s" % m.get("name", ""), 20, kit.COL_ACCENT_2))
	left.add_child(kit.make_label(str(m.get("subtitle", "")), 13, kit.COL_GOLD))
	var brief := kit.make_label(str(m.get("brief", "")), 13, kit.COL_TEXT)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(560, 0)
	left.add_child(brief)

	var tags := kit.make_label("初始资金 %d · 准备 %.0fs · 波次 %d%s" % [
		int(m.get("starting_funds", 0)), float(m.get("prepare_time", 0)),
		(m.get("waves", []) as Array).size(),
		"（无尽）" if (m.get("endless", false) == true) else ""
	], 12, kit.COL_DIM)
	left.add_child(tags)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(160, 0)
	hb.add_child(right)
	var start := kit.make_button("扩展战役 · 出击", 17)
	start.custom_minimum_size = Vector2(160, 52)
	var mid := str(m.get("id", ""))
	start.pressed.connect(func(): _start(mid))
	right.add_child(start)
	right.add_child(kit.make_label("敌方：%s" % GameData.get_faction(str(m.get("enemy_faction", ""))).get("name", ""), 12, kit.COL_DIM))
	return p

func _start(mission_id: String) -> void:
	BattleRequest.configure_mission(mission_id, {
		"opponents": 1,
		"difficulty": _diff_opt.selected,
		"enemy_faction": Preferences.OPTIONS.enemy_base.find(Preferences.enemy_base_for(_enemy_opt.get_item_text(_enemy_opt.selected))),
		"country": "美国" if _country_opt == null else _country_opt.get_item_text(_country_opt.selected),
		"rich": _funds_opt.selected == 1,
	})
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

## ---- 遭遇战 ----
func _skirmish_panel() -> PanelContainer:
	var p := kit.make_panel(kit.COL_PANEL, Color(0.85, 0.55, 0.25))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	p.add_child(hb)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	hb.add_child(left)
	left.add_child(kit.make_label("遭 遇 战", 22, kit.COL_GOLD))
	var desc := kit.make_label("选择地图，与 AI 对手一决高下：\n短局可留下炮塔、碉堡和围墙；歼灭战须清除全部建筑与单位。", 13, kit.COL_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(240, 0)
	left.add_child(desc)

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 14)
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(opts)
	_map_opt = _opt(opts, "地图", ["小 2400", "中 3200", "大 4000"], 1)
	_funds_opt = _opt(opts, "初始资金", Preferences.OPTIONS.starting_funds, Preferences.OPTIONS.starting_funds.find(Preferences.DEFAULTS.starting_funds))
	_enemy_opt = _opt(opts, "对手国家", Preferences.OPTIONS.enemy_country, 0)
	_diff_opt = _opt(opts, "新对手的默认难度", GameData.DIFFICULTY_NAMES, 1)
	_diff_opt.set_item_tooltip(4, GameData.skirmish_training_text(4))
	_diff_opt.set_item_tooltip(5, GameData.skirmish_training_text(5) + "。扩展模式：玩家最终命中伤害（含养成、抽卡技能、被动）超过同武器／军衔／护甲基础伤害的 200% 后压缩，趋近 350% 上限。仅新对局生效。")
	_diff_opt.set_item_tooltip(6, GameData.skirmish_training_text(6) + "。扩展模式 150% 起压、上限 225%。收入翻倍，防御塔冷却 ×0.8，坦克最终受伤 ×0.9，建筑带半血护盾。基地设墙，部队分组支援和回防。")
	_country_opt = _opt(opts, "玩家国家", Preferences.OPTIONS.country, 0)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(180, 0)
	hb.add_child(right)
	var b := kit.make_button("开始遭遇战", 17)
	b.custom_minimum_size = Vector2(180, 54)
	b.pressed.connect(_start_skirmish)
	right.add_child(b)
	_start_button = b
	_victory_reward_label = kit.make_label("", 13, kit.COL_GOLD)
	_victory_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_victory_reward_label)
	_enemy_opt.get_parent().hide()
	_country_opt.get_parent().hide()
	return p

func _opt(parent: Control, title: String, items: Array, def_idx: int) -> OptionButton:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	parent.add_child(col)
	col.add_child(kit.make_label(title, 12, kit.COL_DIM))
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 15)
	for it in items:
		ob.add_item(str(it))
	ob.selected = def_idx
	col.add_child(ob)
	return ob

func _load_teams() -> void:
	var stored = _map_memory.get_value(_map_section(),"houses",[])
	_team_rows = stored.duplicate(true) if stored is Array else []
	var capacity := Houses.capacity(Preferences.OPTIONS.map_layout[_layout_opt.selected])
	while _team_rows.size() > capacity: _team_rows.pop_back()
	if _team_rows.size() < 2 or not _team_rows.all(func(r):return r is Dictionary and r.get("team") is int and r.get("country") in Preferences.OPTIONS.enemy_country):
		_team_rows = [{"team":1,"country":"美国"},{"team":2,"country":"美国"}]
	_team_rows[0].country = _country_opt.get_item_text(_country_opt.selected)
	_team_rows[1].country = _enemy_opt.get_item_text(_enemy_opt.selected)
	if _mode_opt.selected == 0:
		for row in _team_rows:
			if row.country == "虫群巢穴": row.country = "美国"
	for i in _team_rows.size():
		var row:Dictionary=_team_rows[i]
		row.seat=int(row.get("seat",i))
		row.spawn=int(row.get("spawn",row.seat))
		if i>0 and not HouseColor.has_color(row.get("color")): row.color="auto"
		if i>0:row.difficulty=clampi(int(row.get("difficulty",_diff_opt.selected)),0,GameData.DIFFICULTY_NAMES.size()-1)
	_spawn_owner=clampi(_spawn_owner,0,_team_rows.size()-1)
	_team_status()

func _assign_spawn(index:int) -> void:
	var current:Dictionary=_team_rows[_spawn_owner]
	for row:Dictionary in _team_rows:
		if row.spawn==index:
			row.spawn=current.spawn
			break
	current.spawn=index
	_team_changed()
	_build_team_rows()

func _team_status() -> void:
	_start_button.disabled = not Houses.valid(_team_rows,Preferences.OPTIONS.map_layout[_layout_opt.selected],_mode_opt.selected == 0)
	_start_button.text = "请设置对手" if _start_button.disabled else "开始遭遇战"
	_start_button.tooltip_text = "将至少一名对手分到与你不同的结盟组。" if _start_button.disabled else ""
	var adjustment := {}
	if not _start_button.disabled and _mode_opt.selected == 1:
		adjustment = Houses.victory_reward(_team_rows, _diff_opt.selected)
	_victory_reward_label.visible = not adjustment.is_empty()
	if _victory_reward_label.visible:
		_victory_reward_label.text = "胜利收益 %d%%" % adjustment.percent
		_victory_reward_label.tooltip_text = Houses.reward_description(adjustment)
		_victory_reward_label.mouse_filter = Control.MOUSE_FILTER_PASS

func _team_changed() -> void:
	_team_status()
	_map_memory.set_value(_map_section(),"houses",_team_rows.duplicate(true))
	_save_preferences()

func _build_team_rows() -> void:
	for child in _team_grid.get_children():
		_team_grid.remove_child(child)
		if child != _color_opt: child.queue_free()
	for title in ["参战方","国家","颜色","结盟组","AI 难度","地图选位"]:
		_team_grid.add_child(kit.make_label(title, 14, kit.COL_GOLD))
	var capacity := Houses.capacity(Preferences.OPTIONS.map_layout[_layout_opt.selected])
	var color_ids := HouseColor.roster_color_ids(_team_rows)
	for seat in capacity:
		var i := -1
		for n in _team_rows.size():
			if int(_team_rows[n].get("seat",n)) == seat: i = n
		var active := i >= 0
		var slot := OptionButton.new()
		_team_grid.add_child(slot)
		slot.custom_minimum_size.x = 150
		if seat == 0:
			slot.add_item("玩家")
			slot.disabled = true
		else:
			slot.add_item(Houses.commander_label(_team_rows[i],i) if active else "电脑 %d" % seat)
			slot.add_item("关闭")
			slot.select(0 if active else 1)
			slot.disabled = seat == 1
			slot.item_selected.connect(func(choice):
				if choice == 0 and not active:
					var point:=seat
					for alternative in capacity:
						if not _team_rows.any(func(row):return row.spawn==point):break
						point=alternative
					_team_rows.append({"team":2,"country":"苏俄","seat":seat,"spawn":point,"difficulty":_diff_opt.selected,"color":"auto"})
				elif choice == 1 and active:
					_team_rows.remove_at(i)
					if _spawn_owner==i:_spawn_owner=0
					elif _spawn_owner>i:_spawn_owner-=1
				_team_changed()
				_build_team_rows())
		if active:
			var chip := GradientTexture2D.new()
			chip.width = 18
			chip.height = 14
			chip.gradient = Gradient.new()
			var tint := Color(HouseColor.hex_of(color_ids[i]))
			chip.gradient.colors = PackedColorArray([tint,tint])
			slot.set_item_icon(0,chip)
		var country := OptionButton.new()
		_team_grid.add_child(country)
		country.custom_minimum_size.x = 150
		var color := _color_opt if seat == 0 else HouseColor.color_picker(str(_team_rows[i].get("color","auto")) if active else HouseColor.player_id, true)
		color.name = "HouseColorSeat%d" % seat
		color.custom_minimum_size.x = 122
		color.disabled = not active
		color.tooltip_text = "自动区分会避开其他阵营；指定颜色不会被自动改色。" if seat>0 else "选择玩家阵营颜色。"
		_team_grid.add_child(color)
		if active and i>0:
			color.item_selected.connect(func(index):
				_team_rows[i].color = color.get_item_metadata(index)
				_team_changed()
				_build_team_rows())
		var team := OptionButton.new()
		_team_grid.add_child(team)
		team.custom_minimum_size.x = 100
		var diff:=OptionButton.new()
		_team_grid.add_child(diff)
		if active and i>0:
			for level in GameData.DIFFICULTY_NAMES.size():
				diff.add_item(GameData.DIFFICULTY_NAMES[level])
				diff.set_item_tooltip(level,_diff_opt.get_item_tooltip(level))
			diff.select(_team_rows[i].difficulty)
			diff.item_selected.connect(func(level): _team_rows[i].difficulty=level; _team_changed())
		else:
			diff.add_item("—")
			diff.disabled=true
		var pos:=OptionButton.new()
		if active:
			for point in capacity: pos.add_item("%d 号" % (point+1))
			pos.select(_team_rows[i].spawn)
		else:
			pos.add_item("—")
		pos.disabled=not active
		pos.tooltip_text="直接选择出生点；已占用的位置会与该参战方互换。"
		pos.item_selected.connect(func(index): _spawn_owner=i; _assign_spawn(index))
		_team_grid.add_child(pos)
		if not active:
			country.disabled = true
			team.disabled = true
			continue
		var countries: Array = Preferences.OPTIONS.country if i == 0 or _mode_opt.selected == 0 else Preferences.OPTIONS.enemy_country
		for name_ in countries: country.add_item(name_)
		country.select(countries.find(_team_rows[i].country))
		country.item_selected.connect(func(idx):
			_team_rows[i].country = countries[idx]
			if i == 0: _country_opt.select(idx)
			if i == 1: _enemy_opt.select(idx)
			_team_changed()
			_build_team_rows())
		for n in capacity: team.add_item("%s 组" % String.chr(65+n))
		team.select(_team_rows[i].team-1)
		team.item_selected.connect(func(idx):
			_team_rows[i].team = idx+1
			_team_changed())

	_map_preview.set_roster(_team_rows,_spawn_owner)

func _start_skirmish() -> void:
	_load_teams()
	if _start_button.disabled: return
	var maps := [2400, 3200, 4000]
	var funds: Array = Preferences.OPTIONS.starting_funds
	BattleRequest.configure_skirmish(MatchRules.RA2 if _mode_opt.selected == 0 else MatchRules.EXTENDED, {
		"houses": _team_rows.duplicate(true),
		"map_size": maps[_map_opt.selected],
		"map_layout": Preferences.OPTIONS.map_layout[_layout_opt.selected],
		"starting_funds": funds[_funds_opt.selected],
		"enemy_country": Preferences.OPTIONS.enemy_country[_enemy_opt.selected],
		"enemy_base": Preferences.enemy_base_for(_enemy_opt.get_item_text(_enemy_opt.selected)),
		"difficulty": _diff_opt.selected,
		"country": _country_opt.get_item_text(_country_opt.selected),
		"opening": "mcv" if _opening_opt.selected == 1 else "prebuilt",
		"victory_condition": "annihilation" if _victory_opt.selected == 1 else "short",
		"fog_of_war": _fog_check.button_pressed,
	})
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_mode_selected(index: int) -> void:
	var ra2 := index == 0
	_enemy_opt.set_item_disabled(Preferences.OPTIONS.enemy_country.find("虫群巢穴"), ra2)
	_opening_opt.set_item_disabled(1, not ra2)
	if not ra2:
		_opening_opt.select(0)
	_on_opening_selected(_opening_opt.selected)
	if ra2 and _enemy_opt.get_item_text(_enemy_opt.selected) == "虫群巢穴":
		_enemy_opt.select(0)

func _on_opening_selected(index: int) -> void:
	if _funds_opt == null:
		return
	_funds_opt.set_item_disabled(0, index == 1)
	_funds_opt.tooltip_text = "基地车开局最低 8000，需支付电厂、矿场及矿车费用" if index == 1 else ""
	if index == 1 and _funds_opt.selected == 0:
		_funds_opt.select(1)

## Lobby preferences are independent of battle snapshots and permanent progression.
func _preference_controls() -> Dictionary:
	return {"rules_mode": _mode_opt, "opening": _opening_opt,
		"victory_condition": _victory_opt, "map_size": _map_opt, "map_layout": _layout_opt,
		"starting_funds": _funds_opt, "enemy_country": _enemy_opt,
		"difficulty": _diff_opt, "country": _country_opt}

func _restore_preferences() -> void:
	var values := Preferences.read()
	var controls := _preference_controls()
	for key in controls:
		controls[key].select(Preferences.OPTIONS[key].find(values[key]))
	_fog_check.set_pressed_no_signal(values.fog_of_war)
	_on_mode_selected(_mode_opt.selected)
	_map_memory.load(Preferences.PATH)
	_restore_map_choice(true)
	_remember_map_choice() # Seed legacy global choices before the player switches maps.

func _map_section() -> String:
	return "map_%s_%d" % [Preferences.OPTIONS.map_layout[_layout_opt.selected], Preferences.OPTIONS.map_size[_map_opt.selected]]

func _remember_map_choice() -> void:
	var section := _map_section()
	var country := _country_opt.get_item_text(_country_opt.selected)
	_map_memory.set_value(section, "country", country)
	_map_memory.set_value(section, "color_" + country, _color_opt.get_item_metadata(_color_opt.selected))

func _restore_map_choice(restore_country: bool) -> void:
	var section := _map_section()
	if restore_country and _map_memory.has_section_key(section, "country"):
		var index: int = Preferences.OPTIONS.country.find(_map_memory.get_value(section, "country"))
		if index >= 0: _country_opt.select(index)
	var key := "color_" + _country_opt.get_item_text(_country_opt.selected)
	if not _map_memory.has_section_key(section, key): return
	var saved: Variant = _map_memory.get_value(section, key)
	if typeof(saved) != TYPE_STRING: return
	for i in _color_opt.item_count:
		if saved == _color_opt.get_item_metadata(i):
			_color_opt.select(i)
			if HouseColor.player_id != saved: HouseColor.set_player(saved)
			return

func _preference_selected(_index: int, key: String) -> void:
	if key in ["map_layout", "map_size", "country"]:
		_restore_map_choice(key != "country")
	_save_preferences()
	_refresh_map_preview()

func _selection_preferences() -> Dictionary:
	var values := {"fog_of_war": _fog_check.button_pressed}
	var controls := _preference_controls()
	for key in controls:
		values[key] = Preferences.OPTIONS[key][controls[key].selected]
	values["enemy_base"] = Preferences.enemy_base_for(str(values.enemy_country))
	return values

func _save_preferences() -> void:
	_remember_map_choice()
	_preferences_status.visible = Preferences.write(_selection_preferences(), _map_memory) != OK

func _refresh_map_preview() -> void:
	_load_teams()
	var id:String=Preferences.OPTIONS.map_layout[_layout_opt.selected]
	var native=preload("res://scripts/world/native_maps.gd")
	_map_preview.show_map(id,float(Preferences.OPTIONS.map_size[_map_opt.selected]))
	_build_team_rows()
	_map_opt.disabled=native.has(id)
	_map_opt.get_parent().visible=not native.has(id)
	_map_opt.tooltip_text="这张地图大小固定。" if native.has(id) else "自制地图尺寸"
	if native.has(id):
		var row:Dictionary=native.data(id)
		_map_description.text="%s · 尤复原版地图导入\n%s · 保留原图尺寸 · 原图 %d 个出生点，最多支持 %d 家参战\n直接在「地图选位」下拉框选择出生点；已占用的位置会互换。\n适配限制：地势暂为平面，部分中立物件和桥梁破坏尚未完整支持。"%[row.title,{"TEMPERATE":"温带","SNOW":"雪地","URBAN":"都市"}.get(row.theater,row.theater),row.starts.size(),row.starts.size()]
	else:
		var maps=preload("res://scripts/world/skirmish_maps.gd")
		_map_description.text="%s · Iron Tide 自制布局\n%s\n直接在「地图选位」下拉框选择出生点。金点为矿区，白点为油井。\n切换后点击「开始遭遇战」生成新地图；读取存档仍保留存档中的旧地图。"%[maps.NAMES[maps.IDS.find(id)],maps.MAPS.get(id,{}).get("desc","海岸与水道的基础布局。")]
