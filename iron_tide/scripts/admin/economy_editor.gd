extends Control
class_name EconomyEditor
## 经济调参器：可视化编辑 meta.json 的档位收益、挂机上限、升级价格与战斗结算奖励。

@onready var kit = UiKit

var _toast: Label
var _toast_t: float = 0.0
var _tier_list: VBoxContainer
var _upgrade_list: VBoxContainer
var _settle_box: VBoxContainer
var _idle_box: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	top.add_child(kit.make_label("经济调参器", 20, kit.COL_ACCENT_2))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_toast = kit.make_label("", 13, kit.COL_OK)
	top.add_child(_toast)
	var save_btn := kit.make_button("保存到磁盘")
	save_btn.pressed.connect(_save)
	top.add_child(save_btn)
	var reload_btn := kit.make_button("从磁盘重载")
	reload_btn.pressed.connect(func():
		GameData.reload()
		_rebuild()
		_toast_msg("已重载"))
	top.add_child(reload_btn)

	var sc := kit.make_scroll()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(wrap)

	wrap.add_child(kit.make_label("档位（挂机收益 / 离线累积上限 / 全局属性加成）", 15, kit.COL_ACCENT))
	_tier_list = VBoxContainer.new()
	_tier_list.add_theme_constant_override("separation", 6)
	wrap.add_child(_tier_list)

	wrap.add_child(kit.hsep(6))
	wrap.add_child(kit.make_label("后勤升级项（影响价格与每级效果）", 15, kit.COL_ACCENT))
	_upgrade_list = VBoxContainer.new()
	_upgrade_list.add_theme_constant_override("separation", 6)
	wrap.add_child(_upgrade_list)

	wrap.add_child(kit.hsep(6))
	wrap.add_child(kit.make_label("挂机与战斗结算", 15, kit.COL_ACCENT))
	_idle_box = VBoxContainer.new()
	_idle_box.add_theme_constant_override("separation", 5)
	wrap.add_child(_idle_box)
	_settle_box = VBoxContainer.new()
	_settle_box.add_theme_constant_override("separation", 5)
	wrap.add_child(_settle_box)

	_build_tiers()
	_build_upgrades()
	_build_idle()

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast != null:
			_toast.text = ""

func _toast_msg(t: String) -> void:
	_toast.text = t
	_toast_t = 2.5

func _rebuild() -> void:
	for c in [_tier_list, _upgrade_list, _idle_box, _settle_box]:
		for ch in c.get_children():
			c.remove_child(ch)
			ch.queue_free()
	_build_tiers()
	_build_upgrades()
	_build_idle()

# ------------------------------------------------------------------ 档位

func _build_tiers() -> void:
	for t in GameData.meta_config.get("tiers", []):
		var p := kit.make_panel(kit.COL_PANEL_2)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		p.add_child(vb)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		vb.add_child(head)
		head.add_child(kit.make_label("%s（%s）" % [t.get("name", "?"), t.get("id", "?")], 14, kit.COL_GOLD))

		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 5)
		vb.add_child(grid)
		grid.add_child(_num(t, ["unlock_cost"], "解锁成本", 0, 999999, 100))
		grid.add_child(_num(t, ["income_per_hour", "credits"], "军需券/时", 0, 99999, 10))
		grid.add_child(_num(t, ["income_per_hour", "cores"], "核心/时", 0, 9999, 1))
		grid.add_child(_num(t, ["cap_hours"], "累积上限(时)", 1, 48, 0.5))
		grid.add_child(_num(t, ["stat_bonus", "attack_bonus"], "攻击加成", 1.0, 4.0, 0.01))
		grid.add_child(_num(t, ["stat_bonus", "defense_bonus"], "减伤加成", 1.0, 4.0, 0.01))
		grid.add_child(_num(t, ["stat_bonus", "hp_bonus"], "生命加成", 1.0, 4.0, 0.01))
		grid.add_child(_num(t, ["stat_bonus", "speed_bonus"], "速度加成", 1.0, 3.0, 0.01))

		_tier_list.add_child(p)

# ------------------------------------------------------------------ 升级项

func _build_upgrades() -> void:
	for u in GameData.meta_config.get("upgrades", []):
		var p := kit.make_panel(kit.COL_PANEL_2)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		p.add_child(vb)
		vb.add_child(kit.make_label("%s — %s" % [u.get("name", "?"), u.get("desc", "")], 14, kit.COL_GOLD))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 5)
		vb.add_child(grid)
		grid.add_child(_num(u, ["max_level"], "最大等级", 1, 200, 1))
		grid.add_child(_num(u, ["cost_base"], "基础价格", 1, 99999, 10))
		grid.add_child(_num(u, ["cost_growth"], "价格增长系数", 1.0, 3.0, 0.01))
		grid.add_child(_num(u, ["effect_per_level"], "每级效果", 0.0, 5.0, 0.01))
		_upgrade_list.add_child(p)

# ------------------------------------------------------------------ 挂机 / 结算

func _build_idle() -> void:
	var idle: Dictionary = GameData.meta_config.get("idle", {})
	if not GameData.meta_config.has("idle"):
		GameData.meta_config["idle"] = idle
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_idle_box.add_child(row)
	row.add_child(_num(idle, ["tick_seconds"], "结算间隔(s)", 1, 600, 1))
	row.add_child(_num(idle, ["offline_cap_hours"], "离线上限(时)", 1, 72, 1))

	if not idle.has("settlement"):
		idle["settlement"] = {}
	var settle: Dictionary = idle["settlement"]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 5)
	_settle_box.add_child(grid)
	grid.add_child(_num(settle, ["win_credits"], "胜利军需券", 0, 99999, 50))
	grid.add_child(_num(settle, ["win_cores"], "胜利核心", 0, 9999, 1))
	grid.add_child(_num(settle, ["lose_credits"], "失败军需券", 0, 99999, 50))
	grid.add_child(_num(settle, ["lose_cores"], "失败核心", 0, 9999, 1))
	grid.add_child(_num(settle, ["per_kill_credits"], "每击杀军需券", 0, 100, 1))
	grid.add_child(_num(settle, ["wave_credits"], "每波军需券", 0, 9999, 10))
	grid.add_child(_num(settle, ["wave_cores"], "每波核心", 0, 999, 1))

func _num(root: Dictionary, path: Array, label: String, minv: float, maxv: float, step: float) -> HBoxContainer:
	var cur: Variant = root
	for i in range(path.size()):
		var key = path[i]
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(key):
			if i < path.size() - 1:
				(cur as Dictionary)[key] = {}
			else:
				(cur as Dictionary)[key] = 0.0
		cur = (cur as Dictionary)[key]
	var sp: SpinBox = kit.make_spin(float(cur), minv, maxv, step)
	sp.value_changed.connect(func(v):
		_set_nested(root, path, snappedf(v, 0.001))
		GameData.rebuild_indexes()
		_toast_msg("%s 已更新" % label))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := kit.make_label(label, 12, kit.COL_DIM)
	l.custom_minimum_size = Vector2(110, 0)
	hb.add_child(l)
	hb.add_child(sp)
	return hb

func _set_nested(root: Dictionary, path: Array, value) -> void:
	var cur: Variant = root
	for i in range(path.size() - 1):
		var key = path[i]
		if not (cur as Dictionary).has(key) or typeof((cur as Dictionary)[key]) != TYPE_DICTIONARY:
			(cur as Dictionary)[key] = {}
		cur = (cur as Dictionary)[key]
	(cur as Dictionary)[path[path.size() - 1]] = value

func _save() -> void:
	var ok: bool = GameData.save_doc("meta.json")
	if ok:
		_toast_msg("已写入 res://data/meta.json")
	else:
		_toast_msg("写入失败（导出包只读）")
