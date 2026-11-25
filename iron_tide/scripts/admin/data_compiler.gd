extends Control
class_name DataCompiler
## 可视化数值编译器：在游戏内直接编辑克制矩阵、单位、建筑、波次，并导出 JSON。
## 修改会即时写入内存配置（rebuild_indexes），点「保存到磁盘」写回 res://data/。

@onready var kit = UiKit

var tabs: TabContainer
var _toast: Label
var _toast_t: float = 0.0

# 单位页
var _unit_selector: OptionButton
var _unit_form: VBoxContainer
# 建筑页
var _bld_selector: OptionButton
var _bld_form: VBoxContainer
# 波次页
var _mission_selector: OptionButton
var _wave_form: VBoxContainer
# 克制页
var _matrix_grid: GridContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	# 顶部栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	top.add_child(kit.make_label("数据编译器", 20, kit.COL_ACCENT_2))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_toast = kit.make_label("", 13, kit.COL_OK)
	top.add_child(_toast)
	var save_all := kit.make_button("保存全部到磁盘")
	save_all.pressed.connect(_save_all)
	top.add_child(save_all)
	var reload_btn := kit.make_button("从磁盘重载")
	reload_btn.pressed.connect(_reload_all)
	top.add_child(reload_btn)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(tabs)

	_build_matrix_tab()
	_build_unit_tab()
	_build_building_tab()
	_build_wave_tab()

# ================================================================== 通用工具

func _labeled(text: String, control: Control, width: int = 120) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := kit.make_label(text, 13, kit.COL_DIM)
	l.custom_minimum_size = Vector2(width, 0)
	hb.add_child(l)
	hb.add_child(control)
	return hb

func _find(arr: Array, id: String) -> Dictionary:
	for it in arr:
		if str((it as Dictionary).get("id", "")) == id:
			return it
	return {}

func _set_nested(root: Dictionary, path: Array, value) -> void:
	var cur := root
	for i in range(path.size() - 1):
		var key = path[i]
		if not cur.has(key) or typeof(cur[key]) != TYPE_DICTIONARY:
			cur[key] = {}
		cur = cur[key]
	cur[path[path.size() - 1]] = value

func _toast_msg(text: String, ok: bool = true) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", kit.COL_OK if ok else kit.COL_WARN)
	_toast_t = 3.0
	GameData.rebuild_indexes()

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast != null:
			_toast.text = ""

func _save_all() -> void:
	var ok := true
	for fn in ["combat.json", "units.json", "waves.json", "meta.json", "factions.json", "cards.json"]:
		if GameData.raw_docs.has(fn):
			ok = GameData.save_doc(fn) and ok
	if ok:
		_toast_msg("已写入 res://data/（导出包内只读，请在编辑器里运行）")
	else:
		_toast_msg("写入失败：可能运行在导出包内", false)

func _reload_all() -> void:
	GameData.reload()
	_rebuild_all_tabs()
	_toast_msg("已从磁盘重载全部配置")

func _rebuild_all_tabs() -> void:
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	_build_matrix_tab()
	_build_unit_tab()
	_build_building_tab()
	_build_wave_tab()

# ================================================================== 克制矩阵

func _build_matrix_tab() -> void:
	var sc := kit.make_scroll()
	sc.name = "克制矩阵"
	tabs.add_child(sc)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	sc.add_child(wrap)

	wrap.add_child(kit.make_label("伤害倍率矩阵：行 = 攻击类型，列 = 护甲类型。倍率 >1 表示克制。", 13, kit.COL_TEXT))

	_matrix_grid = GridContainer.new()
	_matrix_grid.columns = GameData.combat_armor_types.size() + 1
	_matrix_grid.add_theme_constant_override("h_separation", 4)
	_matrix_grid.add_theme_constant_override("v_separation", 4)
	wrap.add_child(_matrix_grid)

	# 表头
	_matrix_grid.add_child(kit.make_label("攻击＼护甲", 13, kit.COL_ACCENT_2))
	for armor in GameData.combat_armor_types:
		var h := kit.make_label(GameData.armor_label(str(armor)), 13, kit.COL_ACCENT)
		h.custom_minimum_size = Vector2(74, 0)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_matrix_grid.add_child(h)

	for at in GameData.combat_attack_types:
		var at_s := str(at)
		var l := kit.make_label(GameData.attack_label(at_s), 13, kit.COL_GOLD)
		l.custom_minimum_size = Vector2(70, 0)
		_matrix_grid.add_child(l)
		for armor in GameData.combat_armor_types:
			var armor_s := str(armor)
			var sp := kit.make_spin(float(GameData.armor_multiplier(at_s, armor_s)), 0.0, 3.0, 0.05)
			sp.custom_minimum_size = Vector2(74, 28)
			sp.value_changed.connect(func(v):
				_write_matrix(at_s, armor_s, v)
				_update_spin_color(sp, v))
			_update_spin_color(sp, sp.value)
			_matrix_grid.add_child(sp)

	wrap.add_child(kit.hsep(6))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	wrap.add_child(tools)
	var norm := kit.make_button("全部重置为 1.0")
	norm.pressed.connect(func():
		for at2 in GameData.combat_attack_types:
			for armor2 in GameData.combat_armor_types:
				_write_matrix(str(at2), str(armor2), 1.0)
		_rebuild_all_tabs()
		_toast_msg("矩阵已重置"))
	tools.add_child(norm)
	tools.add_child(kit.make_label("修改立即生效于所有战斗；记得点右上角保存。", 12, kit.COL_DIM))

func _update_spin_color(sp: SpinBox, v: float) -> void:
	var col := kit.color_for_mult(v)
	if sp.get_line_edit() != null:
		sp.get_line_edit().add_theme_color_override("font_color", col)

func _write_matrix(at: String, armor: String, v: float) -> void:
	var doc: Dictionary = GameData.raw_docs.get("combat.json", {})
	if not doc.has("multipliers"):
		doc["multipliers"] = {}
	if not doc["multipliers"].has(at):
		doc["multipliers"][at] = {}
	doc["multipliers"][at][armor] = snappedf(v, 0.01)
	GameData.rebuild_indexes()

# ================================================================== 单位

func _build_unit_tab() -> void:
	var sc := kit.make_scroll()
	sc.name = "单位数值"
	tabs.add_child(sc)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	sc.add_child(wrap)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	wrap.add_child(head)
	head.add_child(kit.make_label("选择单位：", 14, kit.COL_TEXT))
	_unit_selector = kit.make_option([])
	_unit_selector.custom_minimum_size = Vector2(320, 30)
	head.add_child(_unit_selector)
	var dup := kit.make_button("复制为新单位")
	dup.pressed.connect(_duplicate_unit)
	head.add_child(dup)
	var del := kit.make_button("删除该单位")
	del.pressed.connect(_delete_unit)
	head.add_child(del)

	_unit_form = VBoxContainer.new()
	_unit_form.add_theme_constant_override("separation", 5)
	wrap.add_child(_unit_form)

	# 必须先建好 _unit_form 再填充下拉，否则默认选中回调会写入空引用
	_repopulate_unit_selector()

func _repopulate_unit_selector() -> void:
	_unit_selector.clear()
	for i in range(GameData.units.size()):
		var u: Dictionary = GameData.units[i]
		_unit_selector.add_item("%s（%s）" % [u.get("name", "?"), u.get("id", "?")], i)
	if _unit_selector.get_item_count() > 0:
		_unit_selector.select(0)
		if not _unit_selector.item_selected.is_connected(_on_unit_selected):
			_unit_selector.item_selected.connect(_on_unit_selected)
		_on_unit_selected(0)

func _current_unit() -> Dictionary:
	var idx := _unit_selector.selected
	if idx < 0 or idx >= GameData.units.size():
		return {}
	return GameData.units[idx]

func _on_unit_selected(_idx: int) -> void:
	_build_unit_form(_current_unit())

func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()

func _build_unit_form(u: Dictionary) -> void:
	_clear(_unit_form)
	if u.is_empty():
		_unit_form.add_child(kit.make_label("无单位", 14, kit.COL_WARN))
		return
	var uid := str(u.get("id", ""))

	var idl := kit.make_label("ID：%s    阵营：%s    定位：%s" % [
		uid, GameData.get_faction(str(u.get("faction", ""))).get("short", u.get("faction", "")), u.get("role_name", "")
	], 13, kit.COL_DIM)
	_unit_form.add_child(idl)

	# 名称
	var name_edit := kit.make_line(str(u.get("name", "")), 14)
	name_edit.custom_minimum_size = Vector2(220, 30)
	name_edit.text_changed.connect(func(t):
		u["name"] = t
		_toast_msg("已改名为 " + t))
	_unit_form.add_child(_labeled("名称", name_edit))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	_unit_form.add_child(grid)

	_unit_form.add_child(kit.make_label("基础属性", 15, kit.COL_ACCENT))
	grid.add_child(_field_num(u, ["cost"], "造价", 0, 20000, 10))
	grid.add_child(_field_num(u, ["build_time"], "建造时间(s)", 0.5, 300, 0.5))
	grid.add_child(_field_num(u, ["hp"], "生命", 1, 20000, 10))
	grid.add_child(_field_num(u, ["speed"], "速度", 10, 400, 1))
	grid.add_child(_field_num(u, ["radius"], "碰撞半径", 3, 60, 0.5))
	grid.add_child(_field_num(u, ["sight"], "视野", 40, 800, 10))
	# 护甲
	grid.add_child(_field_armor(u))
	# 归属建筑
	grid.add_child(_field_built_at(u))

	_unit_form.add_child(kit.hsep(4))
	_unit_form.add_child(kit.make_label("武器", 15, kit.COL_ACCENT))
	var wgrid := GridContainer.new()
	wgrid.columns = 2
	wgrid.add_theme_constant_override("h_separation", 24)
	wgrid.add_theme_constant_override("v_separation", 5)
	_unit_form.add_child(wgrid)
	wgrid.add_child(_field_attack_type(u))
	wgrid.add_child(_field_num(u, ["weapon", "damage"], "单发伤害", 0, 2000, 1))
	wgrid.add_child(_field_num(u, ["weapon", "cooldown"], "冷却(s)", 0.05, 10, 0.05))
	wgrid.add_child(_field_num(u, ["weapon", "range"], "射程", 0, 900, 5))
	wgrid.add_child(_field_num(u, ["weapon", "min_range"], "最小射程", 0, 900, 5))
	wgrid.add_child(_field_num(u, ["weapon", "burst"], "连发数", 1, 20, 1))
	wgrid.add_child(_field_num(u, ["weapon", "burst_delay"], "连发间隔", 0.02, 1, 0.02))
	wgrid.add_child(_field_num(u, ["weapon", "aoe"], "溅射半径", 0, 300, 2))
	wgrid.add_child(_field_num(u, ["weapon", "projectile_speed"], "弹速(0=瞬发)", 0, 2000, 10))

	var preview := kit.make_label("", 13, kit.COL_OK)
	preview.name = "dps_preview"
	_unit_form.add_child(preview)
	_update_unit_preview(u)

func _update_unit_preview(u: Dictionary) -> void:
	var p := _unit_form.get_node_or_null("dps_preview")
	if p == null:
		return
	var w: Dictionary = _weapon_of(u)
	if w.is_empty():
		p.text = "无武装（后勤/建筑单位）"
		return
	p.text = "期望 DPS：%.1f   |   %s" % [CombatMath.dps(w), CombatMath.describe_weapon(w)]

## 安全取武器字典：缺失 / null / 非字典一律回退为空字典（采集车等后勤单位 weapon 为 null）
func _weapon_of(u: Dictionary) -> Dictionary:
	var w = u.get("weapon")
	if typeof(w) != TYPE_DICTIONARY:
		return {}
	return w

func _field_num(u: Dictionary, path: Array, label: String, minv: float, maxv: float, step: float) -> HBoxContainer:
	var cur: Variant = u
	for i in range(path.size()):
		var key = path[i]
		if typeof(cur) != TYPE_DICTIONARY:
			return _labeled(label, kit.make_spin(0.0, minv, maxv, step))
		if i == path.size() - 1:
			if typeof(cur.get(key)) == TYPE_NIL:
				cur[key] = 0.0
		else:
			if typeof(cur.get(key)) != TYPE_DICTIONARY:
				cur[key] = {}
		cur = cur[key]
	var sp := kit.make_spin(float(cur), minv, maxv, step)
	sp.value_changed.connect(func(v):
		_set_nested(u, path, snappedf(v, 0.001))
		_update_unit_preview(u)
		_toast_msg("%s = %s" % [label, str(v)]))
	return _labeled(label, sp)

func _field_armor(u: Dictionary) -> HBoxContainer:
	var items: Array = []
	for a in GameData.combat_armor_types:
		items.append(GameData.armor_label(str(a)))
	var cur_idx := GameData.combat_armor_types.find(str(u.get("armor", "unarmored")))
	var opt := kit.make_option(items, max(0, cur_idx))
	opt.item_selected.connect(func(i):
		u["armor"] = str(GameData.combat_armor_types[i])
		_toast_msg("护甲 = " + GameData.armor_label(str(u["armor"]))))
	return _labeled("护甲类型", opt)

func _field_attack_type(u: Dictionary) -> HBoxContainer:
	var items: Array = []
	for a in GameData.combat_attack_types:
		items.append(GameData.attack_label(str(a)))
	var w := _weapon_of(u)
	var cur_idx := GameData.combat_attack_types.find(str(w.get("attack_type", "bullet")))
	var opt := kit.make_option(items, max(0, cur_idx))
	opt.item_selected.connect(func(i):
		if not u.has("weapon") or typeof(u["weapon"]) != TYPE_DICTIONARY:
			u["weapon"] = {}
		u["weapon"]["attack_type"] = str(GameData.combat_attack_types[i])
		_update_unit_preview(u)
		_toast_msg("攻击类型 = " + GameData.attack_label(str(u["weapon"]["attack_type"]))))
	return _labeled("攻击类型", opt)

func _field_built_at(u: Dictionary) -> HBoxContainer:
	var ids: Array = []
	for b in GameData.buildings:
		if str(b.get("faction", "")) == str(u.get("faction", "")):
			ids.append(str(b.get("id", "")))
	if ids.is_empty():
		ids = ["GACNST"]
	var cur_idx := ids.find(str(u.get("built_at", "")))
	var opt := kit.make_option(ids, max(0, cur_idx))
	opt.item_selected.connect(func(i):
		u["built_at"] = str(ids[i])
		_toast_msg("生产建筑 = " + str(ids[i])))
	return _labeled("生产建筑", opt)

func _duplicate_unit() -> void:
	var u := _current_unit()
	if u.is_empty():
		return
	var copy := u.duplicate(true)
	copy["id"] = str(u.get("id", "unit")) + "_copy"
	copy["name"] = str(u.get("name", "")) + " 改"
	var doc: Dictionary = GameData.raw_docs.get("units.json", {})
	if not doc.has("units"):
		doc["units"] = []
	doc["units"].append(copy)
	GameData.rebuild_indexes()
	_repopulate_unit_selector()
	_toast_msg("已复制为 " + str(copy["id"]))

func _delete_unit() -> void:
	var u := _current_unit()
	if u.is_empty():
		return
	var doc: Dictionary = GameData.raw_docs.get("units.json", {})
	var arr: Array = doc.get("units", [])
	var idx := arr.find(u)
	if idx >= 0:
		arr.remove_at(idx)
	GameData.rebuild_indexes()
	_repopulate_unit_selector()
	_toast_msg("已删除单位（记得保存）", false)

# ================================================================== 建筑

func _build_building_tab() -> void:
	var sc := kit.make_scroll()
	sc.name = "建筑数值"
	tabs.add_child(sc)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	sc.add_child(wrap)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	wrap.add_child(head)
	head.add_child(kit.make_label("选择建筑：", 14, kit.COL_TEXT))
	_bld_selector = kit.make_option([])
	_bld_selector.custom_minimum_size = Vector2(320, 30)
	head.add_child(_bld_selector)

	_bld_form = VBoxContainer.new()
	_bld_form.add_theme_constant_override("separation", 5)
	wrap.add_child(_bld_form)

	_repopulate_building_selector()

func _repopulate_building_selector() -> void:
	_bld_selector.clear()
	for i in range(GameData.buildings.size()):
		var b: Dictionary = GameData.buildings[i]
		_bld_selector.add_item("%s（%s）" % [b.get("name", "?"), b.get("id", "?")], i)
	if _bld_selector.get_item_count() > 0:
		_bld_selector.select(0)
		if not _bld_selector.item_selected.is_connected(_on_building_selected):
			_bld_selector.item_selected.connect(_on_building_selected)
		_on_building_selected(0)

func _current_building() -> Dictionary:
	var idx := _bld_selector.selected
	if idx < 0 or idx >= GameData.buildings.size():
		return {}
	return GameData.buildings[idx]

func _on_building_selected(_idx: int) -> void:
	_clear(_bld_form)
	var b := _current_building()
	if b.is_empty():
		_bld_form.add_child(kit.make_label("无建筑", 14, kit.COL_WARN))
		return
	var name_edit := kit.make_line(str(b.get("name", "")), 14)
	name_edit.text_changed.connect(func(t):
		b["name"] = t
		_toast_msg("建筑更名为 " + t))
	_bld_form.add_child(_labeled("名称", name_edit))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	_bld_form.add_child(grid)
	grid.add_child(_field_num(b, ["cost"], "造价", 0, 40000, 10))
	grid.add_child(_field_num(b, ["build_time"], "建造时间(s)", 0, 300, 1))
	grid.add_child(_field_num(b, ["hp"], "生命", 100, 40000, 50))
	grid.add_child(_field_num(b, ["radius"], "半径", 10, 80, 1))
	grid.add_child(_field_num(b, ["sight"], "视野", 40, 800, 10))
	grid.add_child(_field_num(b, ["trickle"], "资金/秒", 0, 60, 0.5))

	_bld_form.add_child(kit.hsep(4))
	_bld_form.add_child(kit.make_label("防御武器（可留空伤害为 0）", 15, kit.COL_ACCENT))
	var wgrid := GridContainer.new()
	wgrid.columns = 2
	wgrid.add_theme_constant_override("h_separation", 24)
	wgrid.add_theme_constant_override("v_separation", 5)
	_bld_form.add_child(wgrid)
	if not b.has("weapon") or typeof(b["weapon"]) != TYPE_DICTIONARY:
		b["weapon"] = {}
	wgrid.add_child(_field_num(b, ["weapon", "damage"], "单发伤害", 0, 2000, 1))
	wgrid.add_child(_field_num(b, ["weapon", "cooldown"], "冷却(s)", 0.05, 10, 0.05))
	wgrid.add_child(_field_num(b, ["weapon", "range"], "射程", 0, 900, 5))
	wgrid.add_child(_field_num(b, ["weapon", "burst"], "连发数", 1, 20, 1))
	wgrid.add_child(_field_num(b, ["weapon", "aoe"], "溅射半径", 0, 300, 2))
	wgrid.add_child(_field_attack_type(b))

	_bld_form.add_child(kit.hsep(4))
	_bld_form.add_child(kit.make_label("可生产单位（逗号分隔 id）", 13, kit.COL_ACCENT))
	var builds_edit := kit.make_line(",".join(PackedStringArray(b.get("builds", []))), 13)
	builds_edit.custom_minimum_size = Vector2(420, 30)
	builds_edit.text_changed.connect(func(t):
		var ids: Array = []
		for part in t.split(",", false):
			var s: String = part.strip_edges()
			if s != "":
				ids.append(s)
		b["builds"] = ids
		_toast_msg("生产列表已更新"))
	_bld_form.add_child(builds_edit)

# ================================================================== 波次

func _build_wave_tab() -> void:
	var sc := kit.make_scroll()
	sc.name = "关卡波次"
	tabs.add_child(sc)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	sc.add_child(wrap)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	wrap.add_child(head)
	head.add_child(kit.make_label("选择关卡：", 14, kit.COL_TEXT))
	_mission_selector = kit.make_option([])
	_mission_selector.custom_minimum_size = Vector2(320, 30)
	head.add_child(_mission_selector)

	_wave_form = VBoxContainer.new()
	_wave_form.add_theme_constant_override("separation", 6)
	wrap.add_child(_wave_form)

	_repopulate_mission_selector()

func _repopulate_mission_selector() -> void:
	_mission_selector.clear()
	for i in range(GameData.missions.size()):
		var m: Dictionary = GameData.missions[i]
		_mission_selector.add_item("%s（%s）" % [m.get("name", "?"), m.get("id", "?")], i)
	if _mission_selector.get_item_count() > 0:
		_mission_selector.select(0)
		if not _mission_selector.item_selected.is_connected(_on_mission_selected):
			_mission_selector.item_selected.connect(_on_mission_selected)
		_on_mission_selected(0)

func _current_mission() -> Dictionary:
	var idx := _mission_selector.selected
	if idx < 0 or idx >= GameData.missions.size():
		return {}
	return GameData.missions[idx]

func _on_mission_selected(_idx: int) -> void:
	_clear(_wave_form)
	var m := _current_mission()
	if m.is_empty():
		_wave_form.add_child(kit.make_label("无关卡", 14, kit.COL_WARN))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	_wave_form.add_child(grid)
	grid.add_child(_field_num(m, ["starting_funds"], "初始资金", 0, 99999, 100))
	grid.add_child(_field_num(m, ["prepare_time"], "准备时间(s)", 0, 300, 5))
	grid.add_child(_field_num(m, ["map_size"], "地图尺寸", 1200, 5000, 100))

	var brief_edit := kit.make_line(str(m.get("brief", "")), 13)
	brief_edit.custom_minimum_size = Vector2(560, 30)
	brief_edit.text_changed.connect(func(t):
		m["brief"] = t
		_toast_msg("简报已更新"))
	_wave_form.add_child(_labeled("关卡简报", brief_edit, 80))

	_wave_form.add_child(kit.divider())
	_wave_form.add_child(kit.make_label("波次列表（spawns 格式：单位id:数量，用逗号分隔）", 14, kit.COL_ACCENT))

	var waves: Array = m.get("waves", [])
	if not m.has("waves"):
		m["waves"] = waves
	for i in range(waves.size()):
		_wave_form.add_child(_wave_row(waves, i))

	var add_wave := kit.make_button("＋ 新增波次")
	add_wave.pressed.connect(func():
		waves.append({ "name": "新波次", "delay": 25, "spawns": [ { "unit": "swarm_drone", "count": 4 } ] })
		_on_mission_selected(_mission_selector.selected))
	_wave_form.add_child(add_wave)

func _wave_row(waves: Array, i: int) -> PanelContainer:
	var w: Dictionary = waves[i]
	var p := kit.make_panel(kit.COL_PANEL_2)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vb.add_child(head)
	head.add_child(kit.make_label("第 %d 波" % (i + 1), 14, kit.COL_GOLD))
	var name_edit := kit.make_line(str(w.get("name", "")), 13)
	name_edit.custom_minimum_size = Vector2(160, 28)
	name_edit.text_changed.connect(func(t):
		w["name"] = t)
	head.add_child(name_edit)
	head.add_child(kit.make_label("倒计时(s)", 12, kit.COL_DIM))
	var delay_sp := kit.make_spin(float(w.get("delay", 25)), 1, 600, 1)
	delay_sp.custom_minimum_size = Vector2(76, 28)
	delay_sp.value_changed.connect(func(v): w["delay"] = v)
	head.add_child(delay_sp)
	var from_both := str(w.get("from", "")) == "both"
	var both_chk := kit.make_check("两路出兵", from_both)
	both_chk.toggled.connect(func(on):
		if on:
			w["from"] = "both"
		else:
			w.erase("from"))
	head.add_child(both_chk)
	var del := kit.make_button("删除")
	del.pressed.connect(func():
		waves.remove_at(i)
		_on_mission_selected(_mission_selector.selected))
	head.add_child(del)

	var spawns_edit := kit.make_line(_spawns_to_text(w.get("spawns", [])), 13)
	spawns_edit.custom_minimum_size = Vector2(560, 30)
	spawns_edit.text_changed.connect(func(t):
		w["spawns"] = _text_to_spawns(t)
		_toast_msg("波次 %d 组成已更新" % (i + 1)))
	vb.add_child(_labeled("组成", spawns_edit, 50))

	return p

func _spawns_to_text(spawns: Array) -> String:
	var parts: Array = []
	for s in spawns:
		parts.append("%s:%d" % [s.get("unit", ""), int(s.get("count", 1))])
	return ", ".join(PackedStringArray(parts))

func _text_to_spawns(text: String) -> Array:
	var out: Array = []
	for part in text.split(",", false):
		var seg := part.strip_edges()
		if seg == "":
			continue
		var kv := seg.split(":")
		var uid := str(kv[0]).strip_edges()
		var cnt := 1
		if kv.size() > 1:
			cnt = int(str(kv[1]).strip_edges())
		if uid != "":
			out.append({ "unit": uid, "count": cnt })
	return out
