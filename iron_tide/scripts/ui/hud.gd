extends CanvasLayer
class_name BattleHUD
const Hotkeys=preload("res://scripts/ui/battle_hotkeys.gd")
const EffectDetails=preload("res://scripts/ui/battle_effect_details.gd")
## 战斗界面：顶部状态栏、消息日志、选中面板、底部指令甲板（红警2 侧栏）、小地图、GM 快捷入口。

const MiniMapScript := preload("res://scripts/ui/minimap.gd")
const GMConsoleScript := preload("res://scripts/admin/gm_console.gd")
const ANIMATED_ROSTER_LIMIT := 12
const GROUPED_ROSTER_LIMIT := 16
const UnitIconScript := preload("res://scripts/ui/unit_icon.gd")
const UnlockGuidanceScript := preload("res://scripts/ui/unlock_guidance.gd")
const ProductionTooltipScript := preload("res://scripts/ui/production_tooltip.gd")
const ProductionInspectorScript := preload("res://scripts/ui/production_inspector.gd")
var _production_inspector
const UnlockPanelScript := preload("res://scripts/ui/unlock_panel.gd")

var _unlock_panel
var _prod_scroll: ScrollContainer
var _unlock_source := ""
var _unlock_tab := ""
var _unlock_focus := ""
var _unlock_choices: Dictionary = {}

var battle: Battle
var expedition_save_and_leave: Callable
var _live_poll_elapsed := 0.0
var _performance_snapshot := preload("res://scripts/world/performance_snapshot.gd").new()
var kit = UiKit

# 顶部
var fps_label: Label
var funds_label: Label
var wave_label: Label
var kill_label: Label
var timer_label: Label
var mode_label: Label
var power_label: Label
var power_bar: PowerBarControl
var power_plate: VBoxContainer
var power_sub: Label
var speed_btn: Button
var pause_btn: Button
var _load_pause_hint: Label
var _load_resume_press := Vector2.INF
var settings_btn: Button
var save_btn: Button
var save_panel
var settings_panel: PanelContainer
var _deck_orders_button: Button
var _opening_orders_button: Button
var _topbar: PanelContainer
var _minimap_frame: Control
var _enemy_alerts := preload("res://scripts/ui/enemy_superweapon_alerts.gd").new()
var _defeat_notices := preload("res://scripts/ui/house_defeat_notices.gd").new()
const FieldRadio=preload("res://scripts/ui/field_radio.gd")
var field_radio:FieldRadio
var _radio_dock: VBoxContainer
var _log_holder: Control
var _expedition_tabs: HBoxContainer
var _expedition_tab_buttons: Dictionary = {}
var _expedition_tab := "expedition"
const SIDEBAR_WIDTH := 376.0

# 日志
var log_box: VBoxContainer
var log_panel: PanelContainer
var log_btn: Button
var mission_objectives: Label
var _logs: Array = []

# 选中 / 生产
var sel_panel: PanelContainer
var _compact_vitals: PanelContainer
var _unit_vitals: VBoxContainer
var _vitals_home: MarginContainer
var _unit_menu: Control
var unit_menu_toggle: Button
var unit_menu_collapsed := false
var sel_box: VBoxContainer
var _command_box: VBoxContainer
var _unit_command_box: VBoxContainer
var _building_command_box: VBoxContainer
var _unit_command_buttons: Dictionary
var _stance_bar
var sel_strip: PanelContainer
var sel_strip_box: GridContainer
var _strip_scroll: ScrollContainer
var sel_strip_title: Label
var _strip_icons: Array = []
var _strip_grouped := false
# Inactive grouped portraits belong to the HUD for the lifetime of this battle.
var _group_icon_pool: Dictionary = {}
var _group_icon_host := Node.new()
var _strip_unit_count := 0
var _strip_live_elapsed := 0.0
var ability_panel: PanelContainer
var ability_box: GridContainer
var ability_title: Label
var _ability_btns: Array = []
var _reaper_split_btn:Button
# 增益/减益栏（贴在技能栏上方）
var buff_panel: PanelContainer
var expedition_panel: PanelContainer
var tanker_bar: HBoxContainer
var _expedition_scroll: ScrollContainer
var _expedition_body: VBoxContainer
var buff_box: GridContainer
var buff_title: Label
var buff_empty: Label
var _buff_chips: Dictionary = {}
var _buff_sig: String = ""
var prod_panel: PanelContainer
var production_toggle: Button
var production_collapsed := false
var _catalog_body: VBoxContainer
var _roster_body: VBoxContainer
var _sidebar_members: Array = []
var _sidebar_building := 0
const PANEL_PREFERENCES_PATH := "user://hud_panels.cfg"
var prod_box: VBoxContainer
var build_panel: PanelContainer
var build_box: VBoxContainer

# 选中面板的动态部件（只更新数值，不重建控件）
var sel_hp_bar: HpBarControl = null
var sel_hp_label: Label
var sel_shield_label: Label
var sel_stance_label: Label
var economy_status_label: Label = null
var economy_status_bar: ProgressBar = null
const EconomyCycle = preload("res://scripts/world/economy_cycle.gd")
const ConstructionRepack = preload("res://scripts/world/construction_repack.gd")

var sel_cargo_label: Label
var sel_rank_label: Label
var sel_rank_icon: TextureRect
var sel_xp_label: Label
var sel_xp_bar: ProgressBar
var cmd_buttons: Dictionary = {}
const TeslaPulse=preload("res://scripts/buildings/tesla_pulse.gd")
const SkillClock=preload("res://scripts/ui/skill_cooldown_clock.gd")
var _tesla_pulse_btn:Button
var building_action_buttons: Dictionary = {}
var auto_w_controls: HBoxContainer
var formation_buttons: Dictionary = {}
var view_btn: Button
var cmd_hint: PanelContainer
var cmd_hint_label: Label
var _sel_sig: String = ""
var _detail_key: Array = []
var _sw_btn: Button = null
var _sw_src = null
var _sel_warning_style: StyleBoxFlat
var _sel_panel_low: bool = false          # 选中面板是否处于「低血泛红」态
const LOW_HP_TINT: float = 0.34           # 低于此血量比例时整牌泛红告警

var red_alert_panel: Control
var minimap
var gm_console = null
var _speed_index: int = 0
var _display_multiplier := 1.0
const SPEEDS := [1.0, 2.0, 3.0]

## Selection uses live panel bounds, including collapsed/expanded layouts.
func covers_world_pixel(pixel: Vector2) -> bool:
	for panel in [_topbar, _minimap_frame, prod_panel, production_toggle, log_panel, log_btn, _expedition_tabs,
			sel_panel, sel_strip, ability_panel, buff_panel, build_panel,
			unit_menu_toggle, cmd_hint, settings_panel, expedition_panel, tanker_bar, red_alert_panel]:
		if is_instance_valid(panel) and panel.is_visible_in_tree() and panel.get_global_rect().has_point(pixel):
			return true
	return false

func _ready() -> void:
	# 即使战斗被暂停，HUD 仍需响应输入（空格取消暂停、GM 面板等）
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(false)

func _exit_tree() -> void:
	_performance_snapshot.finish()

# Keep the native selection portraits for allied types resident for this battle.
var _roster_portraits := {}
var _pending_portraits: Array[String] = []

func _queue_roster_portrait(unit) -> void:
	if unit.side != "ally": return
	var path := GameData.ra2_cameo_path(unit.unit_id)
	if path.is_empty() or _roster_portraits.has(path): return
	_roster_portraits[path] = null
	_pending_portraits.append(path)

func setup(p_battle) -> void:
	battle = p_battle
	add_child(_group_icon_host)
	for unit in battle.units:
		if is_instance_valid(unit): _queue_roster_portrait(unit)
	Events.unit_spawned.connect(_queue_roster_portrait)
	_build_ui()
	_connect_events()
	_refresh_top()
	_refresh_selection()
	_refresh_build_menu()
	Events.emit_message("操作：左键框选/点选（双击选中同型），Shift 点选切换、框选追加；右键单击移动或集火，按住右键或中键拖图；滚轮缩放，方向键/贴边滚屏。", Color(0.75, 0.82, 0.9))
	Events.emit_message("热键：S 停止 · G 警戒 · X 攻击移动 · T 同型 · P 全选 · H 回基地 · D 倒退攻击 · J 部署 · K 维修 · L 出售 · M/N 上下单位 · F 跟随 · A 攻击 · Y 采集。技能：Q 固有 · W 装配 · E 特殊操作（兼容 Shift 组合）；生产栏使用鼠标操作。", Color(0.7, 0.78, 0.88))
	Events.emit_message("通用：中键单击恢复缩放 / 拖拽平移 · Space 暂停 · Tab 倍速 · Ctrl+G GM 控制台 · Esc 取消/返回 · 数字 选编队 / Ctrl+数字 编组 / Alt+数字 聚焦 · 视角 [ ] 压扁 · ' 菱形/正视 · \\ 镜像。", Color(0.72, 0.8, 0.9))
	_on_command_mode("")
	_on_view_changed(Iso.preset_label())

func _connect_events() -> void:
	Events.funds_changed.connect(func(_a): _refresh_funds())
	Events.power_changed.connect(func(_p, _d, _l): _refresh_top())
	Events.selection_changed.connect(_on_selection_changed)
	Events.production_queue_changed.connect(func(): _refresh_production())
	Events.meta_changed.connect(_refresh_production)
	Events.battle_message.connect(_on_message)
	Events.wave_started.connect(func(_i, _n): _refresh_top())
	Events.gm_notice.connect(func(t): _on_message(t, Color(1.0, 0.8, 0.45)))
	Events.command_mode_changed.connect(_on_command_mode)
	Events.view_changed.connect(_on_view_changed)

# ================================================================== 构建

var _sw_sidebar

func make_support_button() -> Button:
	return _sw_sidebar.make_support_button()

func _build_ui() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_topbar(root)
	_build_log(root)
	_sw_sidebar = preload("res://scripts/ui/superweapon_sidebar.gd").new()
	root.add_child(_sw_sidebar)
	_sw_sidebar.setup(battle)
	_build_cmd_hint(root)
	_unit_menu = Control.new()
	_unit_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_unit_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_unit_menu)
	_build_selection(_unit_menu)
	_build_selection_strip(root)
	_build_ability_bar(root)
	_build_buff_bar(root)
	_build_unit_menu_toggle(root)
	_build_production(root)
	_build_buildmenu(root)
	_build_minimap(root)
	_apply_ra3(root)
	_load_pause_hint = kit.make_label("", 21, Color.WHITE)
	_load_pause_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_pause_hint.add_theme_constant_override("outline_size", 5)
	_load_pause_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(_load_pause_hint)
	_load_pause_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_load_pause_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_load_pause_hint.hide()
	_build_settings(root)
	_topbar.resized.connect(_layout_hud)
	get_viewport().size_changed.connect(_layout_hud)
	_restore_panel_preferences()
	_layout_hud.call_deferred()

func _restore_panel_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(PANEL_PREFERENCES_PATH) != OK: return
	var topbar = config.get_value("panels", "topbar_visible", false)
	_topbar.visible = topbar if topbar is bool else false
	var production = config.get_value("panels", "production_collapsed", false)
	var units = config.get_value("panels", "unit_menu_collapsed", false)
	var details = config.get_value("panels", "production_details_collapsed", false)
	_production_inspector._set_folded(details if details is bool else false)
	set_production_collapsed(production if production is bool else false, false)
	_set_unit_menu_collapsed(units if units is bool else false, false)

func _save_panel_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("panels", "topbar_visible", _topbar.visible)
	config.set_value("panels", "production_collapsed", production_collapsed)
	config.set_value("panels", "unit_menu_collapsed", unit_menu_collapsed)
	config.set_value("panels", "production_details_collapsed", _production_inspector._folded)
	if config.save(PANEL_PREFERENCES_PATH) != OK:
		Events.emit_message("界面收起状态保存失败，下次进入可能无法恢复。", UiKit.COL_WARN)

## ================= 红警3 侧栏布局 + 皮肤（不改变既有面板内部结构） =================
var _skin_root: Control
var _skin_pending: Dictionary = {}

func _faction_accent() -> Color:
	return Ra3Skin.RED if battle != null and battle.roster_faction("ally") == "soviet" else kit.RA_CYAN

func _watch_skin(node: Node) -> void:
	if not (node is BaseButton or node is Label or node is RichTextLabel or node is ProgressBar or node is Panel or node is PanelContainer):
		return
	if not _skin_root.is_ancestor_of(node): return
	var id := node.get_instance_id()
	var changed := _queue_skin.bind(id)
	if not node.theme_changed.is_connected(changed):
		node.theme_changed.connect(changed)
	_queue_skin(id)

func _queue_skin(id: int) -> void:
	if _skin_pending.is_empty():
		_apply_pending_skins.call_deferred()
	_skin_pending[id] = true

func _apply_pending_skins() -> void:
	for id: int in _skin_pending.keys():
		var control := instance_from_id(id) as Control
		if is_instance_valid(control) and not control.is_queued_for_deletion() and _skin_root.is_ancestor_of(control):
			Ra3Skin.upgrade_control(control, _faction_accent(), battle.roster_faction("ally") == "soviet")
		_skin_pending.erase(id)
	# Applying a parent's theme can enqueue descendants during this pass.
	if not _skin_pending.is_empty(): _apply_pending_skins.call_deferred()

func _apply_ra3(root: Control) -> void:
	_skin_root = root
	get_tree().node_added.connect(_watch_skin)
	for node in root.find_children("*", "Control", true, false):
		_watch_skin(node)
	_minimap_frame = minimap.get_parent().get_parent().get_parent()
	_minimap_frame.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap_frame.custom_minimum_size = Vector2.ZERO
	minimap.custom_minimum_size = Vector2(220, 168)
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prod_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	prod_panel.offset_left = -SIDEBAR_WIDTH
	prod_panel.offset_right = -8
	prod_panel.offset_bottom = -8
	sel_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sel_panel.custom_minimum_size = Vector2.ZERO
	for panel in [ability_panel, buff_panel, sel_strip]:
		panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		panel.custom_minimum_size = Vector2.ZERO
	build_panel.hide()
	# BattleScreen calls HUD.setup before Battle.setup establishes the player's country.
	_apply_faction_headers.call_deferred()

func _apply_faction_headers() -> void:
	var soviet := battle.roster_faction("ally") == "soviet"
	_ra2_header(_deck_cap, soviet)
	_ra2_header(_minimap_frame.get_child(0).get_child(0), soviet)

## Original RA2 sidebar caps, decoded with each faction's own SIDEBAR.PAL.
func _ra2_header(label: Label, soviet := false) -> void:
	var cap := StyleBoxTexture.new()
	cap.texture = load("res://assets/ra2/ui/soviet/top-0.png" if soviet else "res://assets/ra2/ui/top-0.png")
	cap.texture_margin_left = 18
	cap.texture_margin_right = 18
	cap.texture_margin_top = 8
	cap.texture_margin_bottom = 8
	cap.content_margin_left = 12
	cap.content_margin_right = 12
	cap.content_margin_top = 6
	cap.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", cap)
	label.add_theme_color_override("font_color", Color(0.95, 0.98, 1))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06))
	label.add_theme_constant_override("outline_size", 4)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _layout_hud() -> void:
	if not is_inside_tree() or _topbar == null or _minimap_frame == null:
		return
	var content_top := _topbar.get_global_rect().end.y + 6.0 if _topbar.visible else 6.0
	fps_label.position = Vector2(12, content_top)
	var view_width := get_viewport().get_visible_rect().size.x
	var sidebar_width := SIDEBAR_WIDTH
	var dock_right := minf(view_width - sidebar_width - 8.0, 8.0 + clampf(view_width * 0.38, 480.0, 580.0))
	_layout_radio_dock()
	minimap.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.20 - 44.0, 100.0, 168.0)
	_minimap_frame.offset_left = -SIDEBAR_WIDTH
	_minimap_frame.offset_right = -8
	_minimap_frame.offset_top = content_top
	_minimap_frame.offset_bottom = content_top + _minimap_frame.get_combined_minimum_size().y
	prod_panel.offset_top = _minimap_frame.offset_bottom + 5.0
	production_toggle.offset_top = prod_panel.offset_top
	production_toggle.offset_bottom = prod_panel.offset_top + 40.0
	production_toggle.offset_left = -SIDEBAR_WIDTH - 32.0
	production_toggle.offset_right = -SIDEBAR_WIDTH
	sel_panel.offset_left = 8
	sel_panel.offset_right = minf(dock_right, 304.0)
	sel_panel.offset_top = -222
	sel_panel.offset_bottom = -8
	ability_panel.offset_left = 8
	ability_panel.offset_right = dock_right
	ability_panel.offset_top = -280
	ability_panel.offset_bottom = -228
	buff_panel.offset_left = 8
	buff_panel.offset_right = sel_panel.offset_right
	buff_panel.offset_top = -326
	buff_panel.offset_bottom = -286
	# The roster now shares the deck's content container.
	if _log_holder != null:
		_log_holder.position.y = content_top + fps_label.size.y + 3.0
	if cmd_hint != null:
		cmd_hint.position = Vector2(486.0, content_top)
		cmd_hint.size.x = maxf(160.0, view_width - sidebar_width - 502.0)
	if settings_panel != null:
		settings_panel.offset_top = content_top
		settings_panel.offset_bottom = minf(get_viewport().get_visible_rect().size.y - 8.0, content_top + 720.0)
	_layout_unit_menu_toggle()
	_layout_selection_strip.call_deferred()
	if is_instance_valid(battle) and is_instance_valid(battle.camera):
		battle.clamp_camera_to_map()

func _build_unit_menu_toggle(root: Control) -> void:
	_compact_vitals = kit.ra_panel(kit.RA_PANEL_2, kit.RA_EDGE, 3, 6)
	_compact_vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_compact_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact_vitals.hide()
	root.add_child(_compact_vitals)
	_compact_vitals.minimum_size_changed.connect(_layout_unit_menu_toggle)
	unit_menu_toggle = kit.make_button("▼ 收起单位菜单")
	unit_menu_toggle.focus_mode = Control.FOCUS_NONE
	unit_menu_toggle.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	unit_menu_toggle.tooltip_text = "收起单位详情与指令，保留 Buff 栏、技能、血条、护盾数值和经验条。"
	root.add_child(unit_menu_toggle)
	unit_menu_toggle.pressed.connect(_toggle_unit_menu)
	unit_menu_toggle.minimum_size_changed.connect(_layout_unit_menu_toggle)
	ability_panel.minimum_size_changed.connect(_layout_unit_menu_toggle)
	buff_panel.minimum_size_changed.connect(_layout_unit_menu_toggle)
	sel_panel.minimum_size_changed.connect(_layout_unit_menu_toggle.call_deferred)
	for panel in [sel_panel, ability_panel, buff_panel]:
		panel.visibility_changed.connect(_layout_unit_menu_toggle)

func _toggle_unit_menu() -> void:
	_set_unit_menu_collapsed(not unit_menu_collapsed)

func _set_unit_menu_collapsed(collapsed: bool, remember := true) -> void:
	unit_menu_collapsed = collapsed
	if is_instance_valid(_unit_vitals):
		_unit_vitals.reparent(_compact_vitals if unit_menu_collapsed else _vitals_home, false)
	_compact_vitals.visible = unit_menu_collapsed and is_instance_valid(_unit_vitals)
	_unit_menu.visible = not unit_menu_collapsed
	unit_menu_toggle.text = "▲ 展开单位菜单" if unit_menu_collapsed else "▼ 收起单位菜单"
	unit_menu_toggle.tooltip_text = "展开单位详情与指令。" if unit_menu_collapsed else "收起单位详情与指令，保留 Buff 栏、技能、血条、护盾数值和经验条。"
	_on_ability_unhover()
	_layout_unit_menu_toggle()
	if remember: _save_panel_preferences()

func _layout_unit_menu_toggle() -> void:
	if unit_menu_toggle == null:
		return
	# Keep the command tiles on screen and reserve readable space for unit details.
	var detail_height := maxf(160.0, sel_panel.get_combined_minimum_size().y + 64.0) if _unit_command_box.visible else 190.0
	sel_panel.offset_top = -8.0 - detail_height
	sel_panel.offset_bottom = -8.0
	var compact_height := maxf(52.0, ability_panel.get_combined_minimum_size().y)
	ability_panel.offset_bottom = -8.0 if unit_menu_collapsed else sel_panel.offset_top - 6.0
	ability_panel.offset_top = ability_panel.offset_bottom - compact_height
	var unit_skills := is_instance_valid(ability_box) and is_instance_valid(battle) and not is_instance_valid(battle.selected_building)
	if is_instance_valid(ability_title): ability_title.visible = not unit_skills
	if is_instance_valid(ability_box): ability_box.columns = 1 if unit_skills and not unit_menu_collapsed else 32
	if is_instance_valid(ability_box):
		var scroll := ability_box.get_parent().get_parent() as ScrollContainer
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if unit_skills else ScrollContainer.SCROLL_MODE_AUTO
	ability_panel.offset_left = 8
	ability_panel.offset_right = minf(get_viewport().get_visible_rect().size.x - SIDEBAR_WIDTH - 8.0, 8.0 + clampf(get_viewport().get_visible_rect().size.x * 0.38, 480.0, 580.0))
	if unit_skills and not unit_menu_collapsed:
		ability_panel.offset_left = sel_panel.offset_right + 4
		ability_panel.offset_right = ability_panel.offset_left + 58
		ability_panel.offset_bottom = -8
		ability_panel.offset_top = -188
	elif unit_skills:
		ability_panel.offset_right = 190
	elif is_instance_valid(ability_box):
		var row := ability_box.get_parent() as HBoxContainer
		var padding := ability_panel.get_theme_stylebox("panel").get_minimum_size().x
		ability_panel.offset_right = minf(ability_panel.offset_right, ability_panel.offset_left + row.get_combined_minimum_size().x + padding)
	buff_panel.offset_bottom=(sel_panel.offset_top if unit_skills and not unit_menu_collapsed else ability_panel.offset_top)-6.0
	buff_panel.offset_top=buff_panel.offset_bottom-maxf(42.0,buff_panel.get_combined_minimum_size().y)
	var top := -8.0
	for panel in [sel_panel, ability_panel, buff_panel]:
		if panel.is_visible_in_tree():
			top = minf(top, panel.offset_top)
	unit_menu_toggle.offset_left = 8.0
	unit_menu_toggle.offset_right = 168.0
	unit_menu_toggle.offset_top = top - 4.0 - maxf(26.0, unit_menu_toggle.get_combined_minimum_size().y)
	unit_menu_toggle.offset_bottom = top - 4.0
	if _compact_vitals.visible:
		var right := buff_panel.offset_right
		var left := unit_menu_toggle.offset_right + 6.0
		var bottom := top - 4.0
		var minimum := _compact_vitals.get_combined_minimum_size()
		if right - left < minimum.x:
			left = unit_menu_toggle.offset_left
			bottom = unit_menu_toggle.offset_top - 4.0
		_compact_vitals.offset_left = left
		_compact_vitals.offset_right = right
		_compact_vitals.offset_top = bottom - minimum.y
		_compact_vitals.offset_bottom = bottom
	_layout_red_alert()

func _build_settings(root: Control) -> void:
	settings_panel = kit.ra_panel(kit.RA_PANEL, kit.RA_EDGE, 4, 12)
	settings_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_panel.offset_left = -SIDEBAR_WIDTH
	settings_panel.offset_right = -8
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.z_index = 50
	settings_panel.visible = false
	root.add_child(settings_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := kit.make_label("显示、音乐与开发工具", 16, kit.COL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := kit.make_button("关闭")
	close.pressed.connect(func(): settings_panel.hide())
	heading.add_child(close)
	view_btn = kit.make_button("视角 " + Iso.preset_label(), 13)
	view_btn.tooltip_text = "循环切换投影预设；[ / ] 调整比例，' 切换菱形/正视，\\ 镜像。"
	view_btn.pressed.connect(_cycle_view)
	column.add_child(view_btn)
	column.add_child(preload("res://scripts/ui/camera_controls.gd").new())
	column.add_child(preload("res://scripts/ui/display_controls.gd").new())
	column.add_child(preload("res://scripts/ui/model_display_controls.gd").new())
	column.add_child(preload("res://scripts/ui/music_controls.gd").new())
	Hotkeys.add_button(column,_refresh_hotkey_labels,func():battle.cancel_pointer_gestures())
	var gm_btn := kit.make_button("开发工具 · GM 控制台", 13)
	gm_btn.pressed.connect(func():
		settings_panel.hide()
		_toggle_gm())
	column.add_child(gm_btn)
	var hint := kit.make_label("Ctrl+G 可直接打开开发工具；Esc 关闭本面板。", 12, kit.COL_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	Ra3Skin.upgrade_tree(settings_panel, kit.RA_CYAN)
	settings_panel.minimum_size_changed.connect(_layout_hud)

func _layout_radio_dock() -> void:
	if not is_instance_valid(_radio_dock): return
	var w := get_viewport().get_visible_rect().size.x
	var right := minf(w * 0.79, w - SIDEBAR_WIDTH - 32.0 - 8.0)
	var left := maxf(8.0, w - right)
	if is_instance_valid(red_alert_panel) and red_alert_panel.is_visible_in_tree():
		left = maxf(left, red_alert_panel.get_global_rect().end.x + 8.0)
	_radio_dock.offset_left = minf(left, right - 180.0)
	_radio_dock.offset_right = right - w
	_radio_dock.offset_bottom = -24.0

func show_field_transmission(who:String,message:String,contact_id:String) -> void:
	if not is_instance_valid(field_radio):
		field_radio=FieldRadio.new()
		field_radio.speaker_changed.connect(minimap.show_radio_contact)
		_radio_dock = VBoxContainer.new()
		_radio_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_radio_dock.alignment = BoxContainer.ALIGNMENT_END
		_skin_root.add_child(_radio_dock)
		_radio_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		field_radio.size_flags_vertical = Control.SIZE_SHRINK_END
		_radio_dock.add_child(field_radio)
		_layout_hud()
	field_radio.transmit(who,message,contact_id)
	Events.emit_message("%s：%s"%[who,message],kit.COL_SIDE_MISSION)

func show_skirmish_difficulty() -> void:
	if battle.skirmish:
		var difficulty := clampi(battle.skirmish_difficulty, 0, GameData.DIFFICULTY_NAMES.size() - 1)
		var rows:Array=BattleRequest.skirmish_config.get("houses",[])
		if rows.size()>2:
			var levels:=PackedStringArray()
			var ally_names:=PackedStringArray()
			for i in range(1,rows.size()):
				var level:=BattleRequest.house_difficulty(BattleRequest.Houses.id(i))
				var friendly:=BattleRequest.friendly("ally",BattleRequest.Houses.id(i))
				if friendly:ally_names.append(BattleRequest.Houses.commander_name(rows[i],i))
				levels.append("%s %s · %s · %s"%["友军" if friendly else "敌军",BattleRequest.Houses.commander_label(rows[i],i),rows[i].country,GameData.DIFFICULTY_NAMES[level]])
			mode_label.text+=" · %d 家电脑"%(rows.size()-1)
			if not ally_names.is_empty():mode_label.text+=" · 友军 "+ally_names[0]
			else:mode_label.text+=" · "+BattleRequest.Houses.commander_name(rows[1],1)
			mode_label.tooltip_text+="\n"+"\n".join(levels)
			mode_label.mouse_filter=Control.MOUSE_FILTER_PASS
			return
		var opponent:Dictionary=rows[1] if rows.size()>1 else {"country":BattleRequest.skirmish_config.get("enemy_country","美国")}
		mode_label.text += " · " + BattleRequest.Houses.commander_name(opponent,1) + " · " + str(GameData.DIFFICULTY_NAMES[difficulty])
		if GameData.AI_TRAINING.has(difficulty):
			mode_label.tooltip_text += "\n" + GameData.skirmish_training_text(difficulty)
			mode_label.mouse_filter = Control.MOUSE_FILTER_PASS

func _build_topbar(root: Control) -> void:
	var bar := kit.ra_panel(kit.RA_PANEL_2, kit.RA_EDGE, 0, 10)
	_topbar = bar
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 6
	bar.custom_minimum_size = Vector2(0, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	bar.add_child(hb)

	var status_column := VBoxContainer.new()
	status_column.add_theme_constant_override("separation", 0)
	status_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(status_column)
	fps_label = kit.make_label("FPS --", 15, kit.COL_ACCENT_2)
	fps_label.custom_minimum_size.x = 76.0
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)
	fps_label.add_theme_constant_override("outline_size", 4)
	bar.hide()

	# 左上：作战目标 / 波次（红警3 目标区）
	mode_label = kit.make_label("经典规则" if not BattleRequest.extensions_enabled() else "扩展模式", 13, kit.COL_DIM)
	mode_label.tooltip_text = "红警 2 经典规则下，局外养成和自定义技能不生效。" if not BattleRequest.extensions_enabled() else "Iron Tide 扩展：养成、技能与扩展玩法"
	status_column.add_child(mode_label)
	wave_label = kit.make_label("准备中", 15, kit.COL_ACCENT_2)
	hb.add_child(wave_label)
	timer_label = kit.make_label("--", 15, kit.COL_WARN)
	hb.add_child(timer_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	# 右上：资源 + 击杀（红警3 资源区）
	funds_label = kit.make_label("资金 0", 18, kit.COL_GOLD)
	hb.add_child(funds_label)
	hb.add_child(kit.divider())
	# 电力（RA2）：产电/耗电 + 电力条
	# 电力牌（第 8 批，RA2 信息密度）：耗电 / 供电 / 余量·赤字 一眼看全
	power_plate = VBoxContainer.new()
	power_plate.add_theme_constant_override("separation", 1)
	power_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_label = kit.make_label("⚡ 0 / 0", 15, kit.COL_OK)
	power_label.tooltip_text = "耗电超过供电时，建造和生产都会变慢，需要供电的建筑会停运。"
	power_plate.add_child(power_label)
	power_bar = PowerBarControl.new()
	power_bar.custom_minimum_size = Vector2(152, 14)
	power_plate.add_child(power_bar)
	power_sub = kit.make_label("余量 +0", 12, kit.COL_TEXT)
	power_plate.add_child(power_sub)
	hb.add_child(power_plate)
	hb.add_child(kit.divider())
	kill_label = kit.make_label("击杀 0", 15, kit.COL_TEXT)
	hb.add_child(kill_label)
	hb.add_child(kit.divider())

	_opening_orders_button = kit.make_button("开局订单")
	_opening_orders_button.name = "OpeningOrdersToggle"
	_opening_orders_button.focus_mode = Control.FOCUS_NONE
	_opening_orders_button.hide()
	_opening_orders_button.pressed.connect(_on_opening_plan_pressed)
	hb.add_child(_opening_orders_button)
	if BattleRequest.extensions_enabled():
		var summoning := kit.make_button("百合子")
		summoning.name = "YurikoCommand"
		summoning.tooltip_text = "召唤百合子、使用灵能与分配专属点数"
		var command = preload("res://scripts/ui/yuriko_command.gd").new()
		add_child(command)
		yuriko_command=command
		command.world = battle
		summoning.pressed.connect(command.open)
		hb.add_child(summoning)
	pause_btn = kit.make_button("暂停")
	pause_btn.pressed.connect(_toggle_pause)
	hb.add_child(pause_btn)

	speed_btn = kit.make_button("倍速 ×1")
	speed_btn.pressed.connect(_cycle_speed)
	hb.add_child(speed_btn)
	save_btn = kit.make_button("存档")
	save_btn.tooltip_text = _save_hint()
	save_btn.pressed.connect(_open_saves)
	hb.add_child(save_btn)

	settings_btn = kit.make_button("设置")
	settings_btn.pressed.connect(func(): settings_panel.visible = not settings_panel.visible)
	hb.add_child(settings_btn)

	var leave := kit.make_button("保存并返回" if preload("res://scripts/expedition/rules.gd").active() else "返回大厅")
	leave.pressed.connect(_leave)
	hb.add_child(leave)
	var close_menu := kit.make_button("收起")
	close_menu.pressed.connect(_set_topbar_visible.bind(false))
	hb.add_child(close_menu)

func _on_opening_plan_pressed() -> void:
	if not battle.allied_state.get("opening_orders_pending", []).is_empty():
		battle.allied_state.opening_orders_paused = not battle.allied_state.get("opening_orders_paused", false)
	elif BattleRequest.extensions_enabled() and battle.production_technology.is_unlocked("production_recipes_2", "ally") and BattleRequest.combat_context.get("opening_orders", []).is_empty():
		var book := preload("res://scripts/rules/opening_order_plans.gd").current(MetaProgress.academy)
		var plan: Dictionary = book.plans[book.selected]
		if plan.orders.is_empty():
			Events.emit_message("当前方案没有订单。请在科技树的「预设开局出兵」中添加兵种并保存。", kit.COL_WARN)
			return
		BattleRequest.combat_context.opening_plan_name = plan.name
		BattleRequest.combat_context.opening_orders = plan.orders.duplicate()
		battle.allied_state.opening_orders_pending = plan.orders.duplicate()
		battle.allied_state.opening_orders_paused = false
	_refresh_opening_orders_button()

func _sync_plan_button(button: Button, pending: Array) -> void:
	button.visible = _recipe_button.visible
	if not button.visible: return
	var context := BattleRequest.combat_context
	var plan_name := str(context.get("opening_plan_name", ""))
	var status: String
	button.disabled = pending.is_empty()
	if not pending.is_empty():
		var action := "恢复" if battle.allied_state.get("opening_orders_paused", false) else "暂停"
		status = "%s（待排 %d）" % [action, pending.size()]
	elif not battle.production_technology.is_unlocked("production_recipes_2", "ally"):
		status = "需启用生产配方二级"
	elif context.get("opening_orders", []).is_empty():
		button.text = "载入局外开局方案"
		button.tooltip_text = "将科技树中当前启用的方案加入本局待排订单。"
		button.disabled = false
		return
	else:
		status = "已全部排入队列"
	button.text = ("开局自动生产 " + plan_name).strip_edges() + " · " + status
	button.tooltip_text = button.text

func _refresh_opening_orders_button() -> void:
	var pending: Array = battle.allied_state.get("opening_orders_pending", [])
	if is_instance_valid(_deck_orders_button):
		_sync_plan_button(_deck_orders_button, pending)
	if is_instance_valid(_recipe_window):
		_sync_plan_button(_recipe_window.plan_button, pending)
	_opening_orders_button.visible = not pending.is_empty()
	if pending.is_empty(): return
	var suspended: bool = battle.allied_state.get("opening_orders_paused", false)
	_opening_orders_button.text = ("恢复开局订单" if suspended else "关闭开局订单") + "（%d）" % pending.size()
	_opening_orders_button.tooltip_text = "继续把本局剩余订单排入生产队列。" if suspended else "暂停本局自动下单，已排队的单位继续生产。"

func _set_topbar_visible(shown: bool) -> void:
	if shown: _refresh_opening_orders_button()
	_topbar.visible = shown
	_layout_hud()
	_save_panel_preferences()

func mount_expedition_panel(panel: PanelContainer, scroll: ScrollContainer, body: VBoxContainer) -> void:
	panel.self_modulate.a = 0.56
	# Both pages participate in the same container layout; only the selected page occupies space.
	panel.reparent(_log_holder)
	_expedition_scroll = scroll
	_expedition_body = body
	body.minimum_size_changed.connect(_layout_selection_strip, CONNECT_DEFERRED)
	scroll.item_rect_changed.connect(_layout_selection_strip, CONNECT_DEFERRED)
	panel.item_rect_changed.connect(_layout_selection_strip, CONNECT_DEFERRED)
	_sw_sidebar.visibility_changed.connect(_layout_selection_strip, CONNECT_DEFERRED)
	panel.position = Vector2.ZERO
	log_btn.hide()
	_log_holder.custom_minimum_size.x = 320
	log_panel.custom_minimum_size.x = 320
	for entry in _logs:
		var message: Label = entry.node
		message.custom_minimum_size.x = 290
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expedition_tabs = HBoxContainer.new()
	_log_holder.add_child(_expedition_tabs)
	_log_holder.move_child(_expedition_tabs, log_btn.get_index())
	for key: String in ["expedition", "intel"]:
		var tab := kit.make_button("远征" if key == "expedition" else "情报", 12)
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_expedition_page.bind(key))
		_expedition_tabs.add_child(tab)
		_expedition_tab_buttons[key] = tab
	_select_expedition_page("expedition")

func _select_expedition_page(key: String) -> void:
	_expedition_tab = key
	expedition_panel.visible = key == "expedition"
	log_panel.visible = key == "intel"
	for id: String in _expedition_tab_buttons:
		_expedition_tab_buttons[id].set_pressed_no_signal(id == key)
	_log_holder.size = Vector2.ZERO
	_layout_selection_strip.call_deferred()

func _toggle_log() -> void:
	if is_instance_valid(_expedition_tabs):
		_select_expedition_page("expedition" if _expedition_tab == "intel" else "intel")
		return
	if log_panel != null:
		log_panel.visible = not log_panel.visible
		if log_panel.visible: _refresh_mission_objectives()
		if log_btn != null:
			log_btn.text = "情报 [收起]" if log_panel.visible else "情报 [展开]"

func _build_log(root: Control) -> void:
	var holder := VBoxContainer.new()
	_log_holder = holder
	holder.resized.connect(func(): _layout_selection_strip.call_deferred())
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.offset_left = 14
	holder.offset_top = 62
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(460, 0)
	root.add_child(holder)
	holder.add_child(_defeat_notices)
	_defeat_notices.setup(battle)
	holder.add_child(_enemy_alerts)
	_enemy_alerts.setup(battle)
	log_btn = kit.make_button("情报 [展开]")
	log_btn.custom_minimum_size = Vector2(120, 24)
	log_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	log_btn.tooltip_text = "展开 / 收起 操作提示与战报"
	log_btn.pressed.connect(_toggle_log)
	holder.add_child(log_btn)
	log_panel = kit.make_panel(Color(0.055, 0.085, 0.125, 0.92), kit.RA_EDGE)
	log_panel.self_modulate.a = 0.56
	log_panel.custom_minimum_size = Vector2(460, 0)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.visible = false
	holder.add_child(log_panel)
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 2)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var log_scroll := ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(0, 180)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if BattleRequest.mission_id == "yr_hollywood" and not BattleRequest.skirmish:
		var column := VBoxContainer.new()
		log_panel.add_child(column)
		column.add_child(kit.make_label("本关总目标", 16, kit.COL_GOLD))
		mission_objectives = kit.make_label("", 15, kit.COL_TEXT)
		mission_objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(mission_objectives)
		column.add_child(kit.divider())
		column.add_child(log_scroll)
		log_btn.tooltip_text = "查看本关总目标、进度和战报"
	else:
		log_panel.add_child(log_scroll)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_box)

func _build_cmd_hint(root: Control) -> void:
	cmd_hint = kit.make_panel(Color(0.09, 0.13, 0.18, 0.92), Color(0.45, 0.75, 1.0))
	cmd_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cmd_hint.offset_top = 58
	cmd_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cmd_hint.visible = false
	root.add_child(cmd_hint)
	cmd_hint_label = kit.make_label("", 14, Color(0.75, 0.95, 1.0))
	cmd_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cmd_hint.add_child(cmd_hint_label)

func _build_selection(root: Control) -> void:
	sel_panel = kit.make_panel(kit.RA_PANEL, kit.RA_EDGE)
	sel_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sel_panel.offset_left = 10
	sel_panel.offset_bottom = -10
	sel_panel.offset_top = -382
	sel_panel.custom_minimum_size = Vector2(342, 372)
	sel_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(sel_panel)
	_sel_warning_style = kit.ra_style(kit.RA_PANEL, kit.RA_EDGE, 4, 8, true)
	sel_panel.draw.connect(_draw_selection_warning)
	var sc := kit.make_scroll()
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(1, 1, 1, 0.05)
	sb_bg.set_corner_radius_all(3)
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color(0.32, 0.52, 0.66, 0.5)
	sb_grab.set_corner_radius_all(3)
	var sb_grab_hi := StyleBoxFlat.new()
	sb_grab_hi.bg_color = Color(0.44, 0.68, 0.84, 0.75)
	sb_grab_hi.set_corner_radius_all(3)
	var vbar := sc.get_v_scroll_bar()
	vbar.custom_minimum_size = Vector2(6, 0)
	vbar.add_theme_stylebox_override("scroll", sb_bg)
	vbar.add_theme_stylebox_override("grabber", sb_grab)
	vbar.add_theme_stylebox_override("grabber_highlight", sb_grab_hi)
	vbar.add_theme_stylebox_override("grabber_pressed", sb_grab_hi)
	var dock := VBoxContainer.new()
	sel_panel.add_child(dock)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(sc)
	_command_box = VBoxContainer.new()
	dock.add_child(_command_box)
	_unit_command_box = _command_box
	_stance_bar = preload("res://scripts/ui/combat_stance_bar.gd").new()
	_command_box.add_child(_stance_bar)
	_stance_bar.setup(self)
	_add_command_grid()
	_add_formation_row()
	_unit_command_buttons = cmd_buttons
	_unit_command_box.hide()
	_building_command_box = VBoxContainer.new()
	dock.add_child(_building_command_box)
	sel_box = VBoxContainer.new()
	sel_box.add_theme_constant_override("separation", 4)
	sel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(sel_box)

func _build_production(root: Control) -> void:
	# 底部指令甲板（红警2 侧栏 → 底部）：标题 + 页签 + 可滚动 cameo 网格
	prod_panel = kit.make_panel(kit.COL_PANEL_2)
	prod_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prod_panel.offset_left = 340
	prod_panel.offset_right = -660
	prod_panel.offset_top = -242
	prod_panel.offset_bottom = -10
	prod_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(prod_panel)
	production_toggle = kit.make_button("▶",16)
	production_toggle.name = "ProductionToggle"
	production_toggle.focus_mode = Control.FOCUS_NONE
	production_toggle.tooltip_text = "收起指令甲板（生产继续进行）"
	production_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.add_child(production_toggle)
	production_toggle.pressed.connect(func():set_production_collapsed(not production_collapsed))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	prod_panel.add_child(vb)

	_deck_cap = kit.make_label("", 14, kit.COL_ACCENT_2)
	_deck_cap.custom_minimum_size.y = 34
	vb.add_child(_deck_cap)
	var header_actions := HBoxContainer.new()
	_deck_cap.add_child(header_actions)
	header_actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_actions.offset_left = 28
	header_actions.offset_right = -28
	header_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	header_actions.add_theme_constant_override("separation", 24)
	deck_title = kit.make_label("指令甲板 · 建筑", 14, kit.COL_ACCENT_2)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	vb.add_child(actions)
	deck_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_title.clip_text = true
	actions.add_child(deck_title)
	var action_labels := {"repair": "维修  "+Hotkeys.label("repair"), "repair_all": "一键维修", "sell": "出售  "+Hotkeys.label("sell")}
	for action in action_labels:
		var button: Button = kit.make_button(action_labels[action], 13)
		button.set_script(ProductionTooltipScript)
		if action == "repair":
			button.icon = load("res://assets/ra2/ui/repair.png")
			button.add_theme_constant_override("icon_max_width", 26)
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = action != "repair_all"
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "维修模式：点击受损的己方建筑，再点停止。资金不足暂停，满血结束。右键 / Esc 退出。" if action == "repair" else "出售模式：点击己方建筑，返还一半造价及生产队列已付费用。建造厂也可出售。右键 / Esc 退出。"
		button.pressed.connect(func(): _cmd(action))
		building_action_buttons[action] = button
		if action == "repair_all":
			actions.add_child(button)
		else:
			button.set_meta("ra3_skip", true)
			var fills := {"normal": Color("21354430"), "hover": Color("31546b66"), "pressed": Color("245f7e99"), "hover_pressed": Color("286d90aa"), "disabled": Color("21354418")}
			for slot: String in fills:
				var previous := button.get_theme_stylebox(slot)
				var overlay := StyleBoxFlat.new()
				overlay.bg_color = fills[slot]
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					overlay.set_content_margin(side, previous.get_content_margin(side))
				button.add_theme_stylebox_override(slot, overlay)
			button.add_theme_constant_override("outline_size", 2)
			button.add_theme_color_override("font_outline_color", Color("142431cc"))
			header_actions.add_child(button)
	auto_w_controls=preload("res://scripts/units/auto_w.gd").add_global_control(vb,self)
	deck_tabs = GridContainer.new()
	deck_tabs.columns = 6
	deck_tabs.add_theme_constant_override("h_separation", 4)
	deck_tabs.add_theme_constant_override("v_separation", 4)
	vb.add_child(deck_tabs)
	_add_prod_tabs()

	vb.add_child(kit.divider())
	_roster_body = VBoxContainer.new()
	_roster_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_roster_body)
	sel_strip.reparent(_roster_body, false)
	sel_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_body.hide()
	_catalog_body = VBoxContainer.new()
	_catalog_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_catalog_body)
	vb = _catalog_body

	_recipe_button = kit.make_button("生产配方", 13)
	vb.add_child(_recipe_button)
	_deck_orders_button = kit.make_button("开局自动生产", 13)
	_deck_orders_button.clip_text = true
	_deck_orders_button.hide()
	_deck_orders_button.pressed.connect(func(): _opening_orders_button.pressed.emit())
	vb.add_child(_deck_orders_button)
	_recipe_button.hide()
	_recipe_button.pressed.connect(func(): preload("res://scripts/ui/production_recipes.gd").open(self))
	_unlock_panel = UnlockPanelScript.new()
	vb.add_child(_unlock_panel)
	_unlock_panel.locate_requested.connect(_locate_unlock_building)
	_unlock_panel.return_requested.connect(_return_to_unlock_source)
	_unlock_panel.close_requested.connect(_close_unlock_panel)
	_unlock_panel.description_requested.connect(func(): _show_entity_description(GameData.get_entity(_unlock_source)))
	_unlock_panel.alternative_selected.connect(_choose_unlock_alternative)
	var scroll := ScrollContainer.new()
	_prod_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	prod_box = VBoxContainer.new()
	prod_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prod_box.add_theme_constant_override("separation", 4)
	scroll.add_child(prod_box)
	_production_inspector = ProductionInspectorScript.new()
	vb.add_child(_production_inspector)
	DisplayPreferences.changed.connect(_sync_production_details_visibility)
	_unlock_panel.visibility_changed.connect(_sync_production_details_visibility)
	_sync_production_details_visibility()
	_production_inspector.folded_changed.connect(func(_value: bool): _save_panel_preferences())
	for action in building_action_buttons:
		var action_button: Button = building_action_buttons[action]
		_production_inspector.bind(action_button, action_button.text)
	for tab in deck_tabs_btns.values():
		_production_inspector.bind(tab, tab.text)

func _sync_production_details_visibility() -> void:
	if not is_instance_valid(_production_inspector): return
	if not DisplayPreferences.show_production_details and _production_inspector._source != null:
		_production_inspector.clear()
	_production_inspector.visible = DisplayPreferences.show_production_details and not _unlock_panel.visible

func set_production_collapsed(collapsed: bool, remember := true) -> void:
	var opening_catalog := production_collapsed and not collapsed
	production_collapsed = collapsed
	_catalog_body.visible = not collapsed
	_roster_body.visible = collapsed
	# Fade the plates only; child buttons, portraits and labels stay opaque.
	prod_panel.self_modulate.a = 0.56 if collapsed else 1.0
	sel_strip.self_modulate.a = 0.48
	if collapsed and is_instance_valid(battle) and not battle.armed_build.is_empty():
		battle.armed_build = ""
		battle.queue_redraw()
	for id in deck_tabs_btns:
		deck_tabs_btns[id].set_pressed_no_signal(not collapsed and id == prod_tab)
	deck_title.text = "指令甲板 · 当前选择" if collapsed else "指令甲板 · " + _tab_label(prod_tab)
	production_toggle.text = "◀" if collapsed else "▶"
	production_toggle.tooltip_text = "展开指令甲板" if collapsed else "收起指令甲板（生产继续进行）"
	_layout_hud()
	if opening_catalog: _refresh_production()
	if remember: _save_panel_preferences()

func _build_buildmenu(root: Control) -> void:
	build_panel = kit.make_panel(kit.COL_PANEL_2)
	build_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	build_panel.offset_left = 10
	build_panel.offset_top = -140
	build_panel.visible = false
	build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(build_panel)
	build_box = VBoxContainer.new()
	build_box.add_theme_constant_override("separation", 4)
	build_panel.add_child(build_box)

func _build_minimap(root: Control) -> void:
	var frame := kit.make_panel(kit.COL_PANEL_2)
	frame.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	frame.offset_right = -10
	frame.offset_bottom = -10
	frame.offset_left = -282
	frame.offset_top = -262
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(frame)
	var vb := VBoxContainer.new()
	frame.add_child(vb)
	var title := kit.make_label("战术地图", 13, kit.COL_DIM)
	vb.add_child(title)
	minimap = MiniMapScript.new()
	minimap.custom_minimum_size = Vector2(252, 226)
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var radar_row := HBoxContainer.new()
	radar_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(radar_row)
	power_bar.reparent(radar_row, false)
	power_bar.vertical = true
	power_bar.custom_minimum_size = Vector2(10, 0)
	minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radar_row.add_child(minimap)
	var resources := HBoxContainer.new()
	vb.add_child(resources)
	funds_label.reparent(resources, false)
	funds_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_label.reparent(resources, false)
	power_plate.hide()
	minimap.setup(battle)

# ================= 红警3 式底部选中单位条（选中单位在屏幕最下方的图标排） =================

func _build_selection_strip(root: Control) -> void:
	sel_strip = kit.ra_panel(kit.RA_PANEL_2, kit.RA_EDGE, 4, 6)
	# The sidebar layout anchors this panel above the minimap, growing upward.
	sel_strip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sel_strip.offset_left = -640.0
	sel_strip.offset_right = -8.0
	sel_strip.offset_top = -94.0
	sel_strip.offset_bottom = -8.0
	sel_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	sel_strip.visible = false
	root.add_child(sel_strip)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_strip.add_child(vb)
	sel_strip_title = kit.ra_label("", 12, kit.RA_CYAN)
	sel_strip_title.clip_text = true
	var header := HBoxContainer.new()
	vb.add_child(header)
	header.add_child(sel_strip_title)
	sel_strip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_strip_title.mouse_filter = Control.MOUSE_FILTER_PASS
	var sc := ScrollContainer.new()
	_strip_scroll = sc
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(sc)
	sel_strip_box = GridContainer.new()
	sel_strip_box.columns = 4
	sel_strip_box.add_theme_constant_override("h_separation", 4)
	sel_strip_box.add_theme_constant_override("v_separation", 4)
	sel_strip_box.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(sel_strip_box)
	sel_strip_box.minimum_size_changed.connect(func(): _layout_selection_strip.call_deferred())

func _layout_red_alert() -> void:
	if not is_instance_valid(red_alert_panel): return
	if not red_alert_panel.has_meta("rest_position"):
		red_alert_panel.set_meta("rest_position", Vector2(red_alert_panel.offset_left, red_alert_panel.offset_top))
	var pos: Vector2 = red_alert_panel.get_meta("rest_position")
	if battle.selected_units.is_empty() and battle.inspected_drones.is_empty():
		var button := unit_menu_toggle.get_global_rect()
		pos = Vector2(button.position.x, button.position.y - red_alert_panel.get_parent_control().get_global_rect().end.y - red_alert_panel.size.y)
	elif not unit_menu_collapsed:
		var edge := sel_panel.get_global_rect().end.x
		if ability_panel.is_visible_in_tree(): edge = maxf(edge, ability_panel.get_global_rect().end.x)
		pos = Vector2(edge + 8.0, -8.0 - red_alert_panel.size.y)
	elif _compact_vitals.is_visible_in_tree():
		var parent_bottom := red_alert_panel.get_parent_control().get_global_rect().end.y
		var clear_y := minf(_compact_vitals.get_global_rect().position.y, unit_menu_toggle.global_position.y)
		pos.y = clear_y - parent_bottom - red_alert_panel.size.y - 4.0
	red_alert_panel.position = Vector2(pos.x, red_alert_panel.get_parent_control().size.y + pos.y)
	_layout_radio_dock()

func _layout_selection_strip() -> void:
	if not is_inside_tree() or not is_instance_valid(sel_strip_box) or not is_instance_valid(_topbar): return
	_layout_red_alert()
	var bottom := get_viewport().get_visible_rect().size.y - 228.0
	if is_instance_valid(red_alert_panel) and red_alert_panel.is_visible_in_tree():
		bottom = minf(bottom, red_alert_panel.get_global_rect().position.y - 8.0)
	var gap := 6.0
	if is_instance_valid(_expedition_scroll) and _expedition_scroll.is_visible_in_tree():
		var body_bottom := bottom - expedition_panel.get_theme_stylebox("panel").get_margin(SIDE_BOTTOM)
		var available := maxf(1.0, floorf(body_bottom - _expedition_scroll.global_position.y))
		_expedition_scroll.custom_minimum_size.y = minf(_expedition_body.get_combined_minimum_size().y, available)
	if is_instance_valid(expedition_panel) and expedition_panel.is_visible_in_tree():
		_log_holder.reset_size()
	var left := _log_holder.get_global_rect().end.x + gap
	var right := _minimap_frame.get_global_rect().position.x - gap
	_sw_sidebar.arrange(Vector2(left, fps_label.global_position.y), maxf(1.0, right - left))
	if is_instance_valid(cmd_hint):
		cmd_hint.position.y = _sw_sidebar.get_global_rect().end.y + gap if _sw_sidebar.visible else fps_label.global_position.y
	if not is_instance_valid(_roster_body): return
	if not production_collapsed:
		prod_panel.offset_bottom = -8.0
		return
	var viewport_height := get_viewport().get_visible_rect().size.y
	var chrome := prod_panel.get_combined_minimum_size().y
	var rows := sel_strip_box.get_combined_minimum_size().y if sel_strip.visible else 0.0
	prod_panel.offset_bottom = minf(-8.0, prod_panel.offset_top + chrome + rows - viewport_height)

## 重建底部条（选中内容变化时调用）
func _rebuild_selection_strip() -> void:
	if sel_strip == null or not is_instance_valid(sel_strip):
		return
	var units: Array = []
	if battle != null and not is_instance_valid(battle.selected_building):
		for unit in battle.selected_units + battle.inspected_drones:
			if battle.actor_alive(unit): units.append(unit)
	_strip_unit_count = units.size()
	var mixed := false
	for u in units:
		if u.unit_id != units[0].unit_id:
			mixed = true
			break
	if mixed or units.size() > GROUPED_ROSTER_LIMIT:
		_rebuild_grouped_strip(units)
		return
	if _strip_grouped:
		for entry in _strip_icons:
			_park_group_icon(entry)
		_strip_icons.clear()
		_strip_grouped = false
	# Orders, formation and veterancy can refresh the HUD without changing the roster.
	if not units.is_empty() and units.size() == _strip_icons.size():
		var same := true
		for i in units.size():
			if not is_instance_valid(_strip_icons[i].unit) or units[i] != _strip_icons[i].unit:
				same = false
				break
		if same:
			_refresh_strip_live()
			return
	_strip_live_elapsed = 0.0
	var reusable := {}
	for entry in _strip_icons:
		if is_instance_valid(entry.unit): reusable[entry.unit] = entry
	var wanted := {}
	for unit in units: wanted[unit] = true
	for entry in _strip_icons:
		if not is_instance_valid(entry.unit) or not wanted.has(entry.unit):
			sel_strip_box.remove_child(entry.icon)
			entry.icon.queue_free()
	if _strip_icons.is_empty(): _clear_nodes(sel_strip_box) # A static building portrait.
	_strip_icons.clear()
	sel_strip_title.tooltip_text = ""
	_strip_scroll.scroll_vertical = 0
	_layout_selection_strip.call_deferred()
	if battle == null:
		sel_strip.visible = false
		return
	# 建筑：单格显示
	if is_instance_valid(battle.selected_building):
		var b = battle.selected_building
		sel_strip.visible = true
		sel_strip_title.tooltip_text = EntityDescription.text(b.data)
		sel_strip_title.text = "建筑 · %s    HP %d / %d" % [b.display_name, int(ceil(b.hp)), int(b.max_hp)]
		sel_strip_box.add_child(_make_strip_tile(b.data, null, 1, _faction_color_of(b.faction)))
		return
	if units.is_empty():
		sel_strip.visible = false
		return
	sel_strip.visible = true
	if units.size() == 1:
		sel_strip_title.tooltip_text = EntityDescription.text(units[0].data)
	var animated := units.size() <= ANIMATED_ROSTER_LIMIT
	for u in units:
		if reusable.has(u):
			var entry: Dictionary = reusable[u]
			entry.icon.animate = animated
			entry.icon.set_process(animated)
			if entry.icon.get_index() != _strip_icons.size():
				sel_strip_box.move_child(entry.icon, _strip_icons.size())
			_strip_icons.append(entry)
		else:
			var tile := _make_strip_tile(u.data, u, 1, u._col, animated)
			sel_strip_box.add_child(tile)
			sel_strip_box.move_child(tile, _strip_icons.size() - 1)
	_refresh_strip_live()

func _park_group_icon(entry: Dictionary) -> void:
	var icon: Control = entry.icon
	icon.hide()
	icon.reparent(_group_icon_host, false)
	_group_icon_pool[entry.key] = icon

# Large selections keep one stable tile per unit type. Members remain real
# selected actors; merging the UI never changes their orders or selection flags.
func _rebuild_grouped_strip(units: Array) -> void:
	var groups := {}
	for u in units:
		var identity:=str(u.unit_id)+":"+str(u.special.get("academy_hero",""))
		if not groups.has(identity): groups[identity] = []
		groups[identity].append(u)
	var reusable := {}
	if _strip_grouped:
		for entry in _strip_icons:
			if groups.has(entry.key): reusable[entry.key] = entry
			else:
				_park_group_icon(entry)
	else:
		_clear_nodes(sel_strip_box)
		_strip_scroll.scroll_vertical = 0
	_strip_grouped = true
	_strip_icons.clear()
	sel_strip_title.tooltip_text = ""
	sel_strip.visible = true
	for key: String in groups:
		var members: Array = groups[key]
		var entry: Dictionary
		if reusable.has(key): entry = reusable[key]
		elif _group_icon_pool.has(key):
			var icon: Control = _group_icon_pool[key]
			_group_icon_pool.erase(key)
			icon.reparent(sel_strip_box, false)
			icon.show()
			entry = {"key": key, "icon": icon}
		else:
			var icon = _make_strip_tile(members[0].data, null, members.size(), members[0]._col, false)
			icon.set_hero(str(members[0].special.get("academy_hero","")))
			icon.set_selected(true)
			icon.show_count = true
			icon.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
					_select_strip_group(key, event.button_index == MOUSE_BUTTON_RIGHT))
			sel_strip_box.add_child(icon)
			entry = {"key": key, "icon": icon}
		entry.icon.set_process(false) # Disable after tree entry; Godot enables _process on entry.
		entry.icon.data = members[0].data
		if entry.icon.col != members[0]._col:
			entry.icon.col = members[0]._col
			entry.icon.queue_redraw()
		entry.unit = members[0]
		entry.members = members
		sel_strip_box.move_child(entry.icon, _strip_icons.size())
		_strip_icons.append(entry)
	_refresh_strip_live()
	_layout_selection_strip.call_deferred()

func _select_strip_group(key: String, remove: bool) -> void:
	var keep: Array = []
	for u in battle.selected_units + battle.inspected_drones:
		var identity:=str(u.unit_id)+":"+str(u.special.get("academy_hero",""))
		if battle.actor_alive(u) and ((identity != key) if remove else (identity == key)):
			keep.append(u)
	battle.clear_selection()
	for u in keep: battle.select_unit(u, true)
	battle._emit_selection()

func _faction_color_of(fid: String) -> Color:
	var f := GameData.get_faction(fid)
	if f.has("color"):
		return Color(str(f["color"]))
	return kit.RA_CYAN

## 单个图标格；u 为 null 时表示静态对象（不可点击）
func _make_strip_tile(ud: Dictionary, u, count: int, col: Color, animated := true) -> Control:
	var frac := 1.0
	if u != null and is_instance_valid(u):
		frac = float(u.hp) / maxf(1.0, float(u.max_hp))
	var ic = UnitIconScript.new()
	ic.setup(ud, col, count, frac)
	ic.set_selected(u != null)
	ic.animate = animated
	ic.set_process(animated)
	ic.mouse_filter = Control.MOUSE_FILTER_STOP
	if u != null and is_instance_valid(u):
		ic.set_hero(str(u.special.get("academy_hero","")))
		ic.veteran_rank = u.veteran_level
		_strip_icons.append({ "unit": u, "icon": ic })
		ic.tooltip_text += "\n左键：聚焦该单位；双击：选择同兵种；右键：取消选择该单位"
		ic.gui_input.connect(_on_strip_unit_input.bind(u, ic))
	return ic

func _on_strip_unit_input(event: InputEvent, unit, icon: Control) -> void:
	if not event is InputEventMouseButton or event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:return
	icon.accept_event()
	if not event.pressed or battle == null or not battle.actor_alive(unit):return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		var keep: Array = []
		for selected in battle.selected_units + battle.inspected_drones:
			if selected != unit and battle.actor_alive(selected):keep.append(selected)
		battle.clear_selection()
		for selected in keep:battle.select_unit(selected, true)
		battle._emit_selection()
	elif event.double_click:
		battle.select_all_of_type(unit)
	else:
		battle.focus_unit(unit)

## 底部条血条实时刷新（变化时才重绘）
func _refresh_strip_live() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(34)
	var hp_total := 0.0
	var hp_max := 0.0
	var total := 0
	for e in _strip_icons:
		var ic = e.get("icon")
		if not is_instance_valid(ic): continue
		var members: Array = e.get("members", [e.get("unit")])
		var health := 0.0
		var maximum := 0.0
		var count := 0
		var minimum_rank := 3
		var maximum_rank := 0
		for u in members:
			if not is_instance_valid(u) or u.hp <= 0.0: continue
			health += u.hp
			maximum += u.max_hp
			count += 1
			minimum_rank = mini(minimum_rank, u.veteran_level)
			maximum_rank = maxi(maximum_rank, u.veteran_level)
		hp_total += health
		hp_max += maximum
		total += count
		var changed: bool = ic.count != count or ic.veteran_rank != minimum_rank
		ic.count = count
		ic.veteran_rank = minimum_rank if count > 0 else 0
		var fraction := clampf(health / maxf(1.0, maximum), 0.0, 1.0)
		if absf(fraction - float(ic.hp_frac)) > 0.004:
			ic.hp_frac = fraction
			ic.damaged = fraction < 0.995
			changed = true
		if e.has("members"):
			var hint := "%s ×%d\n总血量 %d%% · %s\n左键：只选当前队伍内该兵种；右键：移出该兵种" % [str(ic.data.get("name", "?")), count, roundi(fraction * 100), "军衔混合，图标显示最低军衔" if minimum_rank != maximum_rank else "相同军衔"]
			if ic.tooltip_text != hint: ic.tooltip_text = hint
		if changed: ic.queue_redraw()
	if not _strip_icons.is_empty():
		var title := "已选部队 %d    总血量 %d%%" % [total, roundi(100.0 * hp_total / maxf(1.0, hp_max))]
		if _strip_grouped: title += " · 按兵种"
		elif is_instance_valid(_strip_icons[0].unit):
			title = "%s ×%d　总血量 %d%%" % [_strip_icons[0].unit.display_name, total, roundi(100.0 * hp_total / maxf(1.0, hp_max))]
		if not battle.inspected_drones.is_empty(): title += " · 寄生中 %d" % battle.inspected_drones.size()
		if sel_strip_title.text != title: sel_strip_title.text = title

# ================================================================== 刷新

var _proc_tick: float = 0.0

func _process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(32)
	_performance_snapshot.sample_frame()
	if not _pending_portraits.is_empty():
		var path: String = _pending_portraits.pop_back()
		if ResourceLoader.exists(path): _roster_portraits[path] = load(path)
	delta = BattleClock.control_delta(delta)
	if not is_equal_approx(_display_multiplier, GM.fast_forward):
		_display_multiplier = GM.fast_forward
		_refresh_selection()
	_tick_prod_hold(delta)
	_live_poll_elapsed += delta
	if _live_poll_elapsed < 0.1: return
	delta = _live_poll_elapsed
	_live_poll_elapsed = 0.0
	if is_instance_valid(fps_label):
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	_refresh_timer()
	_sync_repair_mode()
	_update_ready_tabs(delta)
	# 选中内容变化时立即重建面板（无论由谁触发：鼠标/指令/GM/单位阵亡）
	if battle != null:
		_strip_live_elapsed += delta
		var poll_roster := _strip_unit_count <= ANIMATED_ROSTER_LIMIT or _strip_live_elapsed >= 0.1
		# Direct selection signals stay immediate. Only the fallback poll is throttled.
		if poll_roster:
			var sig := _selection_signature()
			if sig != _sel_sig:
				_sel_sig = sig
				_refresh_selection()
		_refresh_selection_live(poll_roster)
		if poll_roster:
			_strip_live_elapsed = 0.0
			_refresh_strip_live()
			_update_ability_live()
		_update_buff_live()
		_update_sw_live()
		_update_refinery_live()
	_proc_tick += delta
	# 建造/生产进度条需要更平滑：建筑忙碌时提高刷新频率
	var _busy := false
	if battle != null and is_instance_valid(battle.selected_building):
		var _sb = battle.selected_building
		if _sb.under_construction or not (_sb.production as Array).is_empty():
			_busy = true
	var _thr := 0.08 if _busy else 0.45
	if _proc_tick >= _thr:
		_proc_tick = 0.0
		if is_instance_valid(battle):
			_sw_sidebar.refresh()
			_enemy_alerts.refresh()
			_defeat_notices.refresh()
			_layout_selection_strip()
		_refresh_top()
		# 底部甲板常驻：无选中建筑时也刷新；内部有签名守卫，结构未变时只原地刷新（不重建按钮）
		_refresh_production()

func _refresh_funds() -> void:
	if battle == null: return
	var text := "资金 %s" % _fmt(battle.current_funds())
	if GM.infinite_funds: text += "  [GM ∞]"
	if funds_label.text != text: funds_label.text = text

func _refresh_top() -> void:
	if battle == null:
		return
	_refresh_opening_orders_button()
	speed_btn.text = "倍速 ×%s" % str(GM.fast_forward)
	speed_btn.tooltip_text = "逻辑每秒更新 15 次；显示时间为当前倍速下的预计现实秒数。"
	_refresh_funds()
	# 电力（RA2）：标签 + 电力条
	var ps: Dictionary = battle.power_stats()
	var prod := int(ps.get("produced", 0))
	var dr := int(ps.get("drain", 0))
	var low: bool = ps.get("low", false) == true
	if power_label != null:
		power_label.text = "⚡ %d / %d" % [dr, prod]
		var reserve: int = prod - dr
		var cap: int = maxi(maxi(prod, dr), 1)
		var pcol: Color = kit.COL_OK
		if low:
			pcol = kit.COL_WARN
		elif reserve <= 0 or float(reserve) < 0.20 * float(cap):
			pcol = kit.COL_GOLD
		if power_sub != null:
			if reserve >= 0:
				power_sub.text = "余量 +%d" % reserve
			else:
				power_sub.text = "赤字 −%d" % -reserve
			if float(ps.get("hero_bonus",0))>0:power_sub.text+="   英雄供电 +%d"%int(ps.hero_bonus)
			if low:
				power_sub.text += "   电力不足 - 生产减缓"
				power_sub.add_theme_color_override("font_color", kit.COL_WARN)
			else:
				power_sub.add_theme_color_override("font_color", kit.COL_DIM)
		if low:
			pass  # 低电状态改由 power_sub 显示 RA2 原文（电力不足 - 生产减缓）
		power_label.add_theme_color_override("font_color", pcol)
	if power_bar != null:
		power_label.mouse_filter = Control.MOUSE_FILTER_PASS
		power_label.tooltip_text = "耗电 / 供电\n" + power_sub.text
		power_bar.set_power(float(prod), float(dr))
	kill_label.text = "击杀 %d" % battle.kills
	if battle.waves_cleared > 0:
		kill_label.text += "   波次 %d" % battle.waves_cleared

func _refresh_mission_objectives() -> void:
	if mission_objectives == null or battle == null: return
	var state: Dictionary = battle.allied_state.get("hollywood", {})
	var total := preload("res://scripts/world/hollywood_mission.gd").FACTORIES.size()
	var remaining := int(state.get("remaining", total))
	var phase := int(state.get("phase", 1))
	var base_status := "完成第一项目标后继续"
	if phase == 2: base_status = "进行中"
	if phase >= 3: base_status = "已完成"
	mission_objectives.text = "让城里的回收厂全部停运（%d/%d 座）\n清除尤里两处基地的剩余建筑（%s）\n可选：派地面部队探索片场，靠近克林特、阿诺或史泰龙，他们就会加入盟军。" % [total - remaining, total, base_status]

func _refresh_timer() -> void:
	_refresh_mission_objectives()
	if battle == null:
		return
	if battle.ended:
		wave_label.text = "战斗结束"
		timer_label.text = ""
		return
	if battle.allied_state.has("hollywood"):
		var state: Dictionary = battle.allied_state.hollywood
		wave_label.text = "摧毁回收厂（剩余 %d 座）" % state.remaining if state.phase == 1 else "摧毁剩余敌方建筑"
		if state.get("briefing",false): wave_label.text = "战前简报 · 洛杉矶机场"
		if state.phase == 3: wave_label.text = "城区已解放"
		timer_label.text = "已救下 %d 人" % int(state.get("rescued",0))
		return
	if battle.allied_state.has("time_shift"):
		var s:Dictionary=battle.allied_state.time_shift
		wave_label.text="找到并接管苏军基地" if s.phase==4 and not s.get("base_found",false) else battle.TimeShift.OBJECTIVES[int(s.phase)]
		timer_label.text="充能剩余 %d 秒"%ceili(s.timer) if s.phase==3 else ""
		return
	if battle.mission.get("id") == "yr_head_games":
		var state: Dictionary = battle.allied_state
		var freed := int(state.has("head_games_freed_0")) + int(state.has("head_games_freed_1"))
		timer_label.text = ""
		if state.has("head_brief_stage"):
			wave_label.text = "战前简报 · 特兰西瓦尼亚"
		elif state.has("s07_castle_down"):
			wave_label.text = "尤里的城堡已摧毁"
		elif freed == 2:
			wave_label.text = "摧毁尤里的城堡"
		else:
			wave_label.text = "摧毁心灵信标，解放两座基地"
			timer_label.text = "已解放基地 %d / 2" % freed
		return
	if not battle.prepared:
		wave_label.text = "部署阶段"
		timer_label.text = "%.0fs" % ceil(BattleClock.real_seconds(battle.wave_timer))
	elif battle.endless:
		wave_label.text = "无尽模式 · 第 %d 轮" % (battle.endless_loop + 1)
		timer_label.text = "%.0fs" % ceil(BattleClock.real_seconds(battle.wave_timer))
	elif battle.wave_index < battle.waves.size():
		wave_label.text = "下一波：%s" % battle.waves[battle.wave_index].get("name", "")
		timer_label.text = "%.0fs" % ceil(BattleClock.real_seconds(battle.wave_timer))
	else:
		wave_label.text = "清剿残余"
		timer_label.text = ""

func _fmt(v: float) -> String:
	return str(int(v))

func _on_message(text: String, color: Color) -> void:
	var l := kit.make_label(text, 14, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_expedition_tabs):
		l.custom_minimum_size.x = 290
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_box.add_child(l)
	_logs.append({ "node": l, "t": 0.0 })
	if _logs.size() > 8:
		var old = _logs.pop_front()
		if is_instance_valid(old["node"]):
			old["node"].queue_free()

func _clear_nodes(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

# ------------------------------------------------------------------ 选中面板

func _on_selection_changed(payload: Array) -> void:
	var members: Array = battle.selected_units + battle.inspected_drones
	var building_id: int = battle.selected_building.get_instance_id() if is_instance_valid(battle.selected_building) else 0
	if members != _sidebar_members or building_id != _sidebar_building:
		_sidebar_members = members.duplicate()
		_sidebar_building = building_id
		if building_id != 0 or not members.is_empty():
			set_production_collapsed(building_id == 0, false)
			if building_id != 0: _auto_focus_building_tab(battle.selected_building)
	var sig := _selection_signature()
	if sig != _sel_sig:
		_sel_sig = sig
		(sel_box.get_parent() as ScrollContainer).scroll_vertical = 0
	_refresh_selection()
	if not production_collapsed: _refresh_production()

func _selection_signature() -> String:
	if battle == null:
		return ""
	var sig := "f:%s|" % str(battle.formation_mode)
	if is_instance_valid(battle.selected_building):
		return sig + "b:%d|walls:%d" % [battle.selected_building.get_instance_id(), battle.selected_wall_members().size()]
	var ids: Array = []
	for u in battle.selected_units + battle.inspected_drones:
		if is_instance_valid(u):
			ids.append("%d:%d" % [u.get_instance_id(), u.veteran_level])
	return sig + "p:%d|" % battle.inspected_drones.size() + "u:" + ",".join(ids)

func _refresh_selection() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(33)
	if battle == null:
		return
	# 点选有生产功能的建筑 → 自动跳到其对应的生产页（红警2/3：选中建筑即弹出可造列表）
	_rebuild_selection_strip()
	_rebuild_ability_bar()
	_rebuild_buff_bar()
	var detail_key: Array = []
	if not is_instance_valid(battle.selected_building) and not battle.selected_units.is_empty() and battle.inspected_drones.is_empty():
		var unit = battle.selected_units[0]
		if is_instance_valid(unit):
			detail_key = [unit.get_instance_id(), unit.display_name, unit.armor, unit.attack_range, unit.move_speed,
				unit.bonuses.duplicate(), unit._active_weapon().duplicate(), unit_menu_collapsed]
	if not detail_key.is_empty() and detail_key == _detail_key:
		_refresh_selection_live()
		_sync_unit_commands()
		return
	_detail_key = detail_key
	sel_hp_bar = null
	sel_hp_label = null
	sel_shield_label = null
	sel_stance_label = null
	sel_cargo_label = null
	economy_status_label = null
	economy_status_bar = null
	sel_rank_label = null
	sel_rank_icon = null
	sel_xp_label = null
	sel_xp_bar = null
	var unit_commands: bool = not battle.selected_units.is_empty() and not is_instance_valid(battle.selected_building)
	_unit_command_box.visible = unit_commands
	_building_command_box.visible = not unit_commands
	_command_box = _unit_command_box if unit_commands else _building_command_box
	cmd_buttons = _unit_command_buttons if unit_commands else {}
	_unit_vitals = null
	_vitals_home = null
	_compact_vitals.hide()
	_clear_nodes(_compact_vitals)
	var details_scroll := sel_box.get_parent() as ScrollContainer
	details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if is_instance_valid(battle.selected_building) else ScrollContainer.SCROLL_MODE_DISABLED
	_clear_nodes(sel_box)
	_clear_nodes(_building_command_box)
	sel_panel.show()
	if is_instance_valid(battle.selected_building):
		_show_building_info(battle.selected_building)
		return
	var units: Array = []
	for u in battle.selected_units + battle.inspected_drones:
		if is_instance_valid(u):
			units.append(u)
	if units.is_empty():
		sel_panel.hide()
		sel_box.add_child(kit.make_label("未选中单位", 16, kit.COL_DIM))
		sel_box.add_child(kit.make_label("左键点选 / 框选部队（双击选中同型）", 13, kit.COL_DIM))
		sel_box.add_child(kit.make_label("右键移动或集火；左右键同按拖动可调整阵型与朝向", 13, kit.COL_DIM))
		sel_box.add_child(kit.make_label("鼠标移到单位上会高亮其轮廓", 12, kit.COL_DIM))
		return
	var first = units[0]
	_add_unit_info(first)
	if not battle.inspected_drones.is_empty():
		sel_box.add_child(kit.make_label("寄生中 · %d 台恐怖机器人，脱离宿主后可下令" % battle.inspected_drones.size(), 14, kit.COL_GOLD))
		if battle.selected_units.is_empty(): return
	_sync_unit_commands()

func _sync_unit_commands() -> void:
	for mode in formation_buttons:
		formation_buttons[mode].set_pressed_no_signal(mode == battle.formation_mode)
	_on_command_mode(battle.command_mode)


func _show_entity_description(data: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "EntityDescriptionDialog"
	dialog.title = str(data.get("name", "单位说明"))
	dialog.dialog_text = EntityDescription.text(data)
	dialog.dialog_autowrap = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 220))

func _add_description(head: HBoxContainer, data: Dictionary) -> void:
	var title := head.get_child(-1) as Label
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.tooltip_text = EntityDescription.text(data)

func _add_unit_info(first) -> void:
	# 标题行：强调条 + 型号名 + 右侧角色标签
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_box.add_child(head)
	var accent := ColorRect.new()
	accent.color = kit.COL_ACCENT_2
	accent.custom_minimum_size = Vector2(3, 15)
	accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(accent)
	head.add_child(kit.make_label(str(first.display_name), 15, kit.COL_TEXT))
	_add_description(head, first.data)
	var title := head.get_child(-1) as Label
	title.mouse_entered.connect(func():
		if is_instance_valid(first): title.tooltip_text = _unit_hover_details(first))
	title.name = "UnitNameTooltip"
	var head_sp := Control.new()
	head_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(head_sp)
	head.add_child(kit.make_label(_unit_role_tag(first), 11, kit.COL_DIM))
	sel_rank_icon = TextureRect.new()
	sel_rank_icon.custom_minimum_size = Vector2(16, 16)
	sel_rank_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sel_rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	sel_rank_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sel_rank_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sel_rank_icon)
	sel_rank_label = kit.make_label("", 12, kit.COL_GOLD)
	head.add_child(sel_rank_label)

	# Both menu states use the same live bars, including their damage animation.
	_vitals_home = MarginContainer.new()
	_vitals_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_box.add_child(_vitals_home)
	_unit_vitals = VBoxContainer.new()
	_unit_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_vitals.add_theme_constant_override("separation", 1)
	var host: Control = _compact_vitals if unit_menu_collapsed else _vitals_home
	host.add_child(_unit_vitals)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_vitals.add_child(row)
	sel_hp_bar = _make_hp_bar(first.hp, first.max_hp, 15)
	row.add_child(sel_hp_bar)
	sel_hp_label = kit.make_label("%d / %d" % [int(ceil(first.hp)), int(first.max_hp)], 12, kit.COL_TEXT)
	sel_hp_label.custom_minimum_size = Vector2(76, 0)
	sel_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(sel_hp_label)
	sel_shield_label = kit.make_label("", 12, Unit.TankHero.Shield.COLOR)
	sel_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_vitals.add_child(sel_shield_label)
	_refresh_shield_live(first)
	var experience := HBoxContainer.new()
	experience.visible = not first.is_harvester
	experience.add_theme_constant_override("separation", 8)
	experience.tooltip_text = "击毁敌方单位或建筑，按目标造价获得经验。晋升后保留溢出经验；本局军衔不计入局外养成。"
	_unit_vitals.add_child(experience)
	sel_xp_label = kit.make_label("", 12, kit.COL_GOLD)
	experience.add_child(sel_xp_label)
	sel_xp_bar = ProgressBar.new()
	sel_xp_bar.step = 0.0
	sel_xp_bar.show_percentage = false
	sel_xp_bar.custom_minimum_size = Vector2(90, 8)
	sel_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sel_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_xp_bar.set_meta("ra3_skip", true)
	var xp_background := StyleBoxFlat.new()
	xp_background.bg_color = Color(0.06, 0.08, 0.10)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = kit.COL_GOLD
	sel_xp_bar.add_theme_stylebox_override("background", xp_background)
	sel_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	experience.add_child(sel_xp_bar)
	_refresh_veterancy_live(first)
	_compact_vitals.visible = unit_menu_collapsed
	_layout_unit_menu_toggle()

	# 关键数据：一排小卡片
func _unit_hover_details(unit) -> String:
	var lines := PackedStringArray([EntityDescription.text(unit.data), unit.stance_label(), "护甲 %s · 射程 %d · 速度 %d" % [GameData.armor_label(unit.armor), unit.attack_range, unit.move_speed]])
	if unit.is_harvester:
		lines.append(EconomyCycle.miner_status(unit) + " · 货舱 " + _cargo_caption(unit))
		lines.append("预计卸矿 $%d" % roundi(unit.cargo_value() * EconomyCycle.income_factor(battle, unit.side)))
	elif not str(unit.data.get("powered_by", "")).is_empty():
		var reason: String = unit.power_disabled_reason()
		lines.append(reason if not reason.is_empty() else "控制中心在线")
	var weapon: Dictionary = unit._active_weapon()
	lines.append("武器 · 无" if weapon.is_empty() else "武器 · %s · %s" % [weapon.get("name", ""), CombatMath.describe_weapon(weapon)])
	lines.append("攻击加成 ×%.2f · 减伤 ×%.2f" % [unit.bonuses.get("attack_bonus", 1.0), unit.bonuses.get("defense_bonus", 1.0)])
	for key in {"veteran_attack":"老兵火力", "veteran_rof":"老兵射速", "veteran_speed":"老兵机动"}:
		if unit.bonuses.has(key): lines.append("%s ×%.2f" % [key, unit.bonuses[key]])
	return "\n".join(lines)

## 单位角色标签（标题行右侧）
func _unit_role_tag(u) -> String:
	if u != null:
		var d = GameData.get_entity(str(u.unit_id))
		if d is Dictionary:
			var rn := str(d.get("role_name", ""))
			if rn != "":
				return rn
		if u.is_harvester:
			return "后勤"
	return "单位"

## 数据小卡片（上说明 / 下数值），返回数值 Label 供实时刷新
func _stat_card(parent: Control, cap: String, val: String) -> Label:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _chip_style())
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(v)
	v.add_child(kit.make_label(cap, 10, kit.COL_DIM))
	var vl := kit.make_label(val, 13, kit.COL_TEXT)
	vl.clip_text = true
	v.add_child(vl)
	return vl

## 加成小卡片（说明 + 数值）
func _bonus_chip(parent: Control, cap: String, val: String) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _chip_style())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(h)
	h.add_child(kit.make_label(cap, 10, kit.COL_DIM))
	h.add_child(kit.make_label(val, 12, kit.COL_OK))

## 数据卡统一深色描边样式
func _chip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = kit.RA_TILE
	sb.border_color = kit.RA_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 3.0
	return sb

## 红警2 式指令栏
# —— 红警3 式命令/技能图标：矢量自绘（RA3 命令卡为方形图标块，取代文字按钮）——
class CmdGlyph extends Control:
	var gid := "move"
	var col := Color(0.82, 0.94, 1.0)

	func _init(p_gid: String = "move", p_size: int = 22, p_col: Color = Color(0.82, 0.94, 1.0)) -> void:
		gid = p_gid
		col = p_col
		custom_minimum_size = Vector2(p_size, p_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("ra3_skip", true)

	func _draw() -> void:
		var w: float = maxf(size.x, size.y)
		var c := Vector2(size.x, size.y) * 0.5
		var lw: float = maxf(2.0, w * 0.12)
		match gid:
			"move":
				_arrow(c, w * 0.60, lw)
			"attack_move":
				_arrow(c - Vector2(0.0, w * 0.05), w * 0.46, lw)
				_cross(Vector2(c.x + w * 0.27, c.y - w * 0.27), w * 0.10, lw)
			"attack", "aggressive":
				_cross(c, w * 0.24, lw)
			"reverse_attack":
				_chev(c - Vector2(w * 0.18, 0), w * 0.7, lw, true)
				_cross(c + Vector2(w * 0.22, 0), w * 0.13, lw * 0.7)
			"stop":
				_octagon(c, w * 0.27, lw)
			"guard", "armor":
				_shield(c, w, lw)
			"patrol":
				_loop(c, w, lw)
			"harvest", "repair":
				_bolt(c, w, lw)
			"exclude":
				var tint := Color("ffcc67") if (get_parent() as Button).button_pressed else col
				draw_arc(c, w * 0.37, 0, TAU, 24, tint, lw, true)
				draw_line(c - Vector2(w * 0.19, 0), c + Vector2(w * 0.19, 0), tint, lw)
			"stance", "same":
				_dots(c, w)
			"selectall":
				_flag(c, w, lw)
			"center", "centerbase", "excluded":
				_eye(c, w, lw)
			"follow":
				_step(c, w, lw)
			"prev":
				_chev(c, w, lw, true)
			"next":
				_chev(c, w, lw, false)
			"sell":
				_coin(c, w, lw)
			"deploy":
				_deploy(c, w, lw)
			"smoke":
				_smoke(c, w, lw)
			"boost":
				_boost(c, w, lw)
			"shell":
				_shell(c, w, lw)
			"radar":
				_radar(c, w, lw)
			"heal":
				_heal(c, w, lw)
			"mine":
				_mine(c, w, lw)
			_:
				draw_arc(c, w * 0.26, 0.0, TAU, 18, col, lw, true)

	func _arrow(c: Vector2, s: float, lw: float) -> void:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.55, s * 0.45), c + Vector2(-s * 0.55, -s * 0.30), c + Vector2(s * 0.55, s * 0.07)]), col)
		draw_line(c + Vector2(s * 0.55, s * 0.07), c + Vector2(s * 0.55, s * 0.52), col, lw, true)

	func _cross(c: Vector2, r: float, lw: float) -> void:
		draw_arc(c, r, 0.0, TAU, 20, col, lw * 0.9, true)
		draw_line(c + Vector2(-r * 1.55, 0), c + Vector2(r * 1.55, 0), col, lw * 0.9, true)
		draw_line(c + Vector2(0, -r * 1.55), c + Vector2(0, r * 1.55), col, lw * 0.9, true)

	func _octagon(c: Vector2, r: float, lw: float) -> void:
		var pts := PackedVector2Array()
		for i in range(9):
			var a: float = TAU * float(i % 8) / 8.0 + PI / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, col, lw, true)

	func _shield(c: Vector2, w: float, lw: float) -> void:
		var s: float = w * 0.30
		draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.9), c + Vector2(s, -s * 0.9), c + Vector2(s, s * 0.15), c + Vector2(0, s * 1.05), c + Vector2(-s, s * 0.15), c + Vector2(-s, -s * 0.9)]), col, lw, true)

	func _loop(c: Vector2, w: float, lw: float) -> void:
		var r: float = w * 0.24
		draw_arc(c, r, 0.7, TAU + 0.35, 22, col, lw, true)
		var tip: Vector2 = c + Vector2(cos(0.7), sin(0.7)) * r
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-3.4, -1.2), tip + Vector2(3.4, -1.2), tip + Vector2(0.0, 4.6)]), col)

	func _bolt(c: Vector2, w: float, lw: float) -> void:
		var s: float = w * 0.30
		draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, lw * 1.2, true)
		draw_line(c + Vector2(-s, -s * 0.6), c + Vector2(-s, s), col, lw, true)
		draw_line(c + Vector2(s, -s), c + Vector2(s, s * 0.6), col, lw, true)

	func _dots(c: Vector2, w: float) -> void:
		for i in range(3):
			draw_circle(c + Vector2((float(i) - 1.0) * w * 0.27, 0.0), maxf(1.8, w * 0.085), col)

	func _flag(c: Vector2, w: float, lw: float) -> void:
		draw_line(c + Vector2(-w * 0.22, -w * 0.36), c + Vector2(-w * 0.22, w * 0.38), col, lw, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.22, -w * 0.36), c + Vector2(w * 0.32, -w * 0.16), c + Vector2(-w * 0.22, w * 0.06)]), col)

	func _eye(c: Vector2, w: float, lw: float) -> void:
		var r: float = w * 0.29
		draw_arc(c, r, 0.0, TAU, 20, col, lw * 0.9, true)
		draw_circle(c, maxf(2.2, w * 0.11), col)

	func _step(c: Vector2, w: float, lw: float) -> void:
		_arrow(c - Vector2(0.0, w * 0.06), w * 0.50, lw)
		draw_arc(c + Vector2(0.0, w * 0.33), w * 0.20, PI, TAU, 12, col, lw * 0.8, true)

	func _chev(c: Vector2, w: float, lw: float, left: bool) -> void:
		var d: float = -1.0 if left else 1.0
		var s: float = w * 0.26
		draw_polyline(PackedVector2Array([c + Vector2(s * d, -s), c + Vector2(-s * d, 0.0), c + Vector2(s * d, s)]), col, lw, true)

	func _coin(c: Vector2, w: float, lw: float) -> void:
		var r: float = w * 0.28
		draw_arc(c, r, 0.0, TAU, 20, col, lw * 0.9, true)
		draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), col, lw, true)
		draw_line(c + Vector2(-r * 0.4, -r * 0.28), c + Vector2(r * 0.4, -r * 0.28), col, lw * 0.8, true)
		draw_line(c + Vector2(-r * 0.4, r * 0.28), c + Vector2(r * 0.4, r * 0.28), col, lw * 0.8, true)

	func _deploy(c: Vector2, w: float, lw: float) -> void:
		var s: float = w * 0.30
		draw_polyline(PackedVector2Array([c + Vector2(-s, s * 0.35), c + Vector2(0.0, -s * 0.55), c + Vector2(s, s * 0.35)]), col, lw, true)
		draw_line(c + Vector2(-s * 1.15, s * 0.95), c + Vector2(s * 1.15, s * 0.95), col, lw, true)

	func _smoke(c: Vector2, w: float, lw: float) -> void:
		for i in range(3):
			draw_arc(c + Vector2((float(i) - 1.0) * w * 0.19, 0.0), w * 0.14, 0.0, TAU, 12, col, lw * 0.85, true)

	func _boost(c: Vector2, w: float, lw: float) -> void:
		draw_polyline(PackedVector2Array([c + Vector2(-w * 0.26, w * 0.08), c + Vector2(0.0, -w * 0.32), c + Vector2(w * 0.26, w * 0.08)]), col, lw, true)
		draw_polyline(PackedVector2Array([c + Vector2(-w * 0.26, w * 0.36), c + Vector2(0.0, -w * 0.04), c + Vector2(w * 0.26, w * 0.36)]), col, lw, true)

	func _shell(c: Vector2, w: float, lw: float) -> void:
		draw_arc(c, w * 0.15, 0.0, TAU, 14, col, lw * 0.9, true)
		for i in range(8):
			var a: float = TAU * float(i) / 8.0
			draw_line(c + Vector2(cos(a), sin(a)) * w * 0.23, c + Vector2(cos(a), sin(a)) * w * 0.42, col, lw * 0.8, true)

	func _radar(c: Vector2, w: float, lw: float) -> void:
		var o := c + Vector2(0.0, w * 0.22)
		draw_arc(o, w * 0.36, PI, TAU, 16, col, lw, true)
		draw_line(o, o + Vector2(w * 0.24, -w * 0.30), col, lw * 0.8, true)

	func _heal(c: Vector2, w: float, lw: float) -> void:
		draw_line(c + Vector2(0, -w * 0.32), c + Vector2(0, w * 0.32), col, lw, true)
		draw_line(c + Vector2(-w * 0.32, 0), c + Vector2(w * 0.32, 0), col, lw, true)

	func _mine(c: Vector2, w: float, lw: float) -> void:
		draw_arc(c, w * 0.17, 0.0, TAU, 14, col, lw * 0.9, true)
		for i in range(6):
			var a: float = TAU * float(i) / 6.0
			draw_line(c + Vector2(cos(a), sin(a)) * w * 0.19, c + Vector2(cos(a), sin(a)) * w * 0.38, col, lw * 0.8, true)

func _cmd_hotkey(id: String) -> String:
	return Hotkeys.label(id)

func _save_hint() -> String:
	return "%s 快速存档，%s 打开读档，%s 保存当前性能快照" % [Hotkeys.label("save"), Hotkeys.label("load"), Hotkeys.label("snapshot")]

func _refresh_hotkey_labels() -> void:
	save_btn.tooltip_text = _save_hint()
	for id in _unit_command_buttons:
		var button=_unit_command_buttons[id]
		if not is_instance_valid(button):continue
		if button.has_meta("hotkey_label"):
			var label=button.get_meta("hotkey_label")
			if is_instance_valid(label):label.text=_cmd_hotkey(id)
		button.tooltip_text=Hotkeys.hint(button.get_meta("base_tooltip",button.tooltip_text))
	for id in ["repair","sell"]:
		building_action_buttons[id].text=("维修  " if id=="repair" else "出售  ")+Hotkeys.label(id)
	_rebuild_ability_bar()

func _ability_glyph(nm: String) -> String:
	if nm.contains("烟") or nm.contains("雾"):
		return "smoke"
	if nm.contains("超载") or nm.contains("引擎") or nm.contains("加速") or nm.contains("推进") or nm.contains("机动"):
		return "boost"
	if nm.contains("装甲") or nm.contains("护甲") or nm.contains("护盾"):
		return "armor"
	if nm.contains("雷达") or nm.contains("侦") or nm.contains("探"):
		return "radar"
	if nm.contains("修复") or nm.contains("回复") or nm.contains("治疗") or nm.contains("维修"):
		return "heal"
	if nm.contains("雷"):
		return "mine"
	if nm.contains("部署") or nm.contains("卧倒") or nm.contains("形态"):
		return "deploy"
	return "shell"

func _add_command_grid() -> void:
	var heading := HBoxContainer.new()
	_command_box.add_child(heading)
	var label := kit.make_label("单位指令", 11, kit.COL_DIM)
	heading.add_child(label)
	var more := kit.make_button("更多 ▸", 11)
	more.toggle_mode = true
	more.focus_mode = Control.FOCUS_NONE
	heading.add_child(more)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	_command_box.add_child(grid)
	_add_cmd(grid, "移动", "move", "红警2：右键径直移动；此处点击后左键点地面实行编队移动")
	_add_cmd(grid, "攻击 (A)", "attack", "点击敌人集火。Ctrl＋左键强攻单位或地面，Shift 追加移动点或攻击目标，S 停止。")
	_add_cmd(grid, "停止 (S)", "stop", "立即停止移动与攻击")
	_add_cmd(grid, "倒退攻击 (D)", "reverse_attack", "点击后选择后退位置，边退边开火；右键或 Esc 取消选点。")
	_add_cmd(grid, "巡逻", "patrol", "点击折返点：在当前位置与折返点间往返")
	_add_cmd(grid, "攻击移动 (X)", "attack_move", "点地面前进，途中遇敌交战。也可直接按 Ctrl＋右键，按住 Shift 可追加。")
	_add_cmd(grid, "采集 (Y)", "harvest", "采集车：左键点矿点指派采集")
	_add_cmd(grid, "同型 (T)", "same", "选中场上全部同型号单位")
	_add_cmd(grid, "排除全选 (F4)", "exclude", "让选中单位跳过 F2 和 P。选中已排除的单位再点一次即可恢复。混选时全部排除。")
	_add_cmd(grid, "找回 (F3)", "excluded", "选中全图可操控的已排除单位，并将镜头移到它们的中心。")
	_add_cmd(grid, "全选部队 (F2)", "selectall", "F2 或 P 选中全图己方作战单位，可继续下达移动或攻击指令")
	_add_cmd(grid, "镜头 (C)", "center", "镜头对准当前选中的单位")
	_add_cmd(grid, "回基地 (H)", "centerbase", "镜头回到主基地")
	_add_cmd(grid, "跟随 (F)", "follow", "镜头跟随选中单位（再按取消）")
	_add_cmd(grid, "上一个 (M)", "prev", "循环选中上一个己方单位")
	_add_cmd(grid, "下一个 (N)", "next", "循环选中下一个己方单位")
	_add_cmd(grid, "维修 (K)", "repair", "进入维修模式，点击己方建筑；再次点击停止维修")
	_add_cmd(grid, "出售 (L)", "sell", "进入出售模式，点击己方建筑；返还一半造价及队列已付费用")
	_add_cmd(grid, "部署 (J)", "deploy", "部署具备部署能力的单位")
	var auxiliary := ["same", "selectall", "exclude", "excluded", "center", "centerbase", "follow", "prev", "next", "repair", "sell"]
	for id in auxiliary: cmd_buttons[id].hide()
	more.toggled.connect(func(expanded: bool):
		more.text = "收起 ▴" if expanded else "更多 ▸"
		for id in auxiliary: cmd_buttons[id].visible = expanded
		_layout_unit_menu_toggle.call_deferred())

func _add_cmd(grid: GridContainer, text: String, id: String, tip: String) -> void:
	# Readable command tiles: distinct glyph, permanent short name and hotkey.
	var btn: Button = kit.ra_icon_tile(32)
	btn.custom_minimum_size.y = 37
	btn.set_meta("ra3_skip", true)
	btn.tooltip_text = "%s\n%s" % [text, tip]
	btn.set_meta("base_tooltip",btn.tooltip_text)
	btn.tooltip_text=Hotkeys.hint(btn.tooltip_text)
	btn.focus_mode = Control.FOCUS_NONE
	if id in ["move", "attack", "patrol", "attack_move", "harvest", "reverse_attack", "repair", "sell", "follow", "deploy", "exclude"]:
		btn.toggle_mode = true
		btn.button_pressed = (battle.command_mode == id)
	if id in ["guard", "repair"]:
		if id == "guard": btn.toggle_mode = true
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ra2/ui/%s.png" % id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(5, 1)
		icon.size = Vector2(21, 20)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
	else:
		var gl: Control = CmdGlyph.new(id, 18)
		gl.position = Vector2(6, 2)
		btn.add_child(gl)
	var captions := {"exclude":"排除", "reverse_attack":"倒退", "selectall":"全选", "center":"聚焦", "centerbase":"基地", "attack_move":"攻移"}
	var caption := kit.make_label(captions.get(id, text.get_slice(" (", 0)), 10)
	caption.name = "CommandCaption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, 20)
	caption.size = Vector2(32, 16)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(caption)
	var hk := _cmd_hotkey(id)
	if not hk.is_empty():
		var hl: Label = kit.ra_label(hk, 8, kit.RA_CYAN_DIM)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl.position = Vector2(22, 0)
		btn.add_child(hl)
		btn.set_meta("hotkey_label",hl)
	cmd_buttons[id] = btn
	btn.pressed.connect(func(): _cmd(id))
	grid.add_child(btn)

func _cmd(id: String) -> void:
	if battle == null:
		return
	if id in preload("res://scripts/ui/combat_stance_bar.gd").IDS and not battle.world_input_enabled():
		_on_command_mode(battle.command_mode)
		return
	# —— 控制组（红警2：数字选中 / Ctrl+数字编组 / Alt+数字聚焦）——
	if id.begins_with("group_sel:"):
		battle.select_control_group(int(id.get_slice(":", 1)))
		return
	if id.begins_with("group_set:"):
		battle.assign_control_group(int(id.get_slice(":", 1)))
		return
	if id.begins_with("group_focus:"):
		battle.center_control_group(int(id.get_slice(":", 1)))
		return
	match id:
		"move":
			battle.arm_command("move")
		"attack":
			battle.arm_command("attack")
		"patrol":
			battle.arm_command("patrol")
		"attack_move":
			battle.arm_command("attack_move")
		"reverse_attack":
			if battle.world_input_enabled(): battle.arm_command(Unit.ReverseAttack.ID)
		"harvest":
			battle.arm_command("harvest")
		"stop":
			battle.stop_selected()
		"guard":
			battle.guard_selected()
		"stance":
			battle.cycle_fire_stance_selected()
		"aggressive":
			battle.aggressive_selected()
		"defend", "return_fire", "hold_fire":
			battle.set_fire_stance_selected(preload("res://scripts/ui/combat_stance_bar.gd").STATES[id])
		"exclude":
			battle.toggle_army_exclusion()
		"excluded":
			battle.select_excluded_units()
		"selectall":
			battle.select_all_combat()
		"center":
			battle.center_on_selection()
		"same":
			battle.select_same_type_now()
		"follow":
			battle.follow_selected()
		"centerbase":
			battle.center_on_base()
		"prev":
			battle.select_cycle(-1)
		"next":
			battle.select_cycle(1)
		"deploy":
			battle.deploy_selected()
		"repair_all":
			battle.repair_all_buildings()
			_sync_repair_mode()
		"repair":
			battle.arm_command("repair")
		"sell":
			battle.arm_command("sell")
	_on_command_mode(str(battle.command_mode))

func _add_formation_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_command_box.add_child(row)
	row.add_child(kit.make_label("阵型", 13, kit.COL_DIM))
	var names := { "line": "线列", "wedge": "楔形", "column": "纵队" }
	for mode in ["line", "wedge", "column"]:
		var b: Button = kit.make_button(str(names[mode]), 13)
		b.toggle_mode = true
		b.button_pressed = (str(battle.formation_mode) == mode)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Ctrl+F 循环切换阵型"
		b.pressed.connect(func():
			battle.set_formation(mode)
			_refresh_selection())
		formation_buttons[mode] = b
		row.add_child(b)

func _style(bg: Color, border: Color, bw: int = 1, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	return sb

func _make_hp_bar(cur: float, mx: float, height: int = 16) -> HpBarControl:
	# 红警3 风格血条控件（凹槽 + 描边 + 分段 + 高光），取代 ProgressBar
	var pb := HpBarControl.new()
	pb.custom_minimum_size = Vector2(120, height)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.set_hp(cur, mx)
	return pb

## 只更新数值，不重建控件（避免按钮在点击瞬间被重建）
## 超级武器按钮实时充能显示；击杀/切换建筑后自动失效。
func _update_sw_live() -> void:
	if not is_instance_valid(_sw_btn):
		return
	if not is_instance_valid(_sw_src):
		_sw_btn = null
		_sw_src = null
		return
	if _sw_src.superweapon.is_empty():
		return
	if _sw_src.sw_ready():
		_sw_btn.text = "%s · 就绪" % _sw_src.sw_label()
	else:
		_sw_btn.text = "%s · %d%%" % [_sw_src.sw_label(), int(_sw_src.sw_progress() * 100.0)]
	_sw_btn.disabled = not _sw_src.sw_ready()

func _refresh_shield_live(unit) -> void:
	if not is_instance_valid(sel_shield_label):return
	var shield:Dictionary=preload("res://scripts/ui/shield_readout.gd").summary(unit)
	sel_shield_label.visible = shield.visible
	if not sel_shield_label.visible:return
	sel_shield_label.text = shield.text
	sel_shield_label.tooltip_text = shield.details

func _refresh_veterancy_live(unit) -> void:
	if not is_instance_valid(sel_xp_label):
		return
	var status: Dictionary = unit.veterancy_status()
	if is_instance_valid(sel_rank_icon):
		sel_rank_icon.texture = HpBar.rank_texture(status.rank, unit.data)
		sel_rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if HpBar.uses_ra3_ranks(unit.data) else TextureRect.STRETCH_KEEP_CENTERED
		sel_rank_icon.visible = status.enabled and status.rank > 0
	sel_rank_label.text = "Lv.%d · %s" % [status.level, status.name] if status.enabled else "不可晋升"
	sel_xp_bar.visible = status.enabled
	sel_xp_bar.value = float(status.progress) * 100.0
	if not status.enabled:
		sel_xp_label.text = "该单位不获得作战经验"
	elif status.maxed:
		sel_xp_label.text = "%s · 已达最高军衔" % status.name
	else:
		var next := "老兵" if int(status.rank) == 0 else "精英"
		if HpBar.uses_ra3_ranks(unit.data) and int(status.rank) == 2: next = "英雄"
		sel_xp_label.text = "经验 %d / %d · 距%s %d" % [int(status.current), int(status.required), next, int(ceil(float(status.required) - float(status.current)))]

func _refresh_selection_live(refresh_commands := true) -> void:
	if battle == null:
		return
	var first = null
	for u in battle.selected_units + battle.inspected_drones:
		if is_instance_valid(u):
			first = u
			break
	if first == null:
		var b = battle.selected_building
		if is_instance_valid(b):
			_refresh_shield_live(b)
			var status := sel_box.get_node_or_null("DefenseStatus") as Label
			if status != null: status.text = _defense_status(b)
			_refresh_deploy_cmd()
			_refresh_economy_status(b)
			_update_sel_panel_tint(float(b.hp) / maxf(1.0, float(b.max_hp)))
			if sel_hp_bar != null and is_instance_valid(sel_hp_bar):
				sel_hp_bar.set_hp(b.hp, b.max_hp)
			if sel_hp_label != null and is_instance_valid(sel_hp_label):
				sel_hp_label.text = "%d / %d" % [int(ceil(b.hp)), int(b.max_hp)]
		else:
			_update_sel_panel_tint(1.0)
		return
	_update_sel_panel_tint(float(first.hp) / maxf(1.0, float(first.max_hp)))
	_refresh_veterancy_live(first)
	_refresh_shield_live(first)
	_refresh_economy_status(first)
	if sel_hp_bar != null and is_instance_valid(sel_hp_bar):
		sel_hp_bar.set_hp(first.hp, first.max_hp)
	if sel_hp_label != null and is_instance_valid(sel_hp_label):
		sel_hp_label.text = "%d / %d" % [int(ceil(first.hp)), int(first.max_hp)]
	if sel_stance_label != null and is_instance_valid(sel_stance_label):
		sel_stance_label.text = first.stance_label()
		var reserve := preload("res://scripts/units/tesla_reserve.gd").caption(first)
		if not reserve.is_empty(): sel_stance_label.text += " · " + reserve
	if sel_cargo_label != null and is_instance_valid(sel_cargo_label) and first.is_harvester:
		sel_cargo_label.text = _cargo_caption(first)
	if refresh_commands: _refresh_deploy_cmd()

## 低血整牌泛红：选中单位/建筑血量过低时，把选中面板底色染红并脉冲（信息栏告警）
func _update_sel_panel_tint(frac: float) -> void:
	var low := frac < LOW_HP_TINT
	if not low and not _sel_panel_low:
		return
	_sel_panel_low = low
	if low:
		var k := clampf((LOW_HP_TINT - frac) / LOW_HP_TINT, 0.0, 1.0)
		var bg: Color = kit.RA_PANEL.lerp(Color(0.30, 0.045, 0.055), 0.28 + 0.42 * k)
		bg.a = 0.95
		_sel_warning_style.bg_color = bg
	sel_panel.queue_redraw()

func _draw_selection_warning() -> void:
	if _sel_panel_low:
		# Paint below the controls without notifying them of a theme or layout change.
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
		_sel_warning_style.border_color = Color(1.0, 0.42, 0.34).lerp(Color(1.0, 0.70, 0.55), pulse * 0.7)
		sel_panel.draw_style_box(_sel_warning_style, Rect2(Vector2.ZERO, sel_panel.size))

func _on_command_mode(mode: String) -> void:
	for action in building_action_buttons:
		if building_action_buttons[action].toggle_mode:
			building_action_buttons[action].set_pressed_no_signal(action == mode)
	if cmd_hint != null and is_instance_valid(cmd_hint):
		cmd_hint.visible = mode != ""
		if cmd_hint_label != null and is_instance_valid(cmd_hint_label):
			match mode:
				"superweapon":
					var source = battle._armed_superweapon
					var instruction := "点击地图指定目标"
					if is_instance_valid(source) and source.sw_type().to_lower()=="chronosphere":
						instruction = "选择传送目的地；紫色框表示落点区域" if battle._chrono_source_point.is_finite() else "选择要传送的单位区域；蓝色框覆盖 3×3 格"
					if is_instance_valid(battle._armed_superweapon) and battle._armed_superweapon.sw_type()=="LightningStorm": instruction="移动鼠标选择落雷区域，左键确认"
					cmd_hint_label.text = "战略支援：%s，右键或 Esc 取消" % instruction
				"mcv_site": cmd_hint_label.text = "展开基地：左键选择绿色地基，右键或 Esc 取消"
				"repair":
					cmd_hint_label.text = "维修：点击己方建筑开始 / 停止（Esc / 右键退出）"
				"sell":
					cmd_hint_label.text = "出售：点击己方建筑返还资金（Esc / 右键退出）"
				"move":
					cmd_hint_label.text = "移动指令：左键点地面下达（Esc / 右键取消）"
				"reverse_attack":
					cmd_hint_label.text = "倒退攻击：左键选择后退位置，途中继续开火（Esc / 右键取消）"
				"attack":
					cmd_hint_label.text = "攻击指令：左键点敌方目标强制集火（Esc / 右键取消）"
				"patrol":
					cmd_hint_label.text = "巡逻指令：左键点折返点，两点往返（Esc / 右键取消）"
				"attack_move":
					cmd_hint_label.text = "攻击移动：左键选目的地，途中遇敌交战（Esc / 右键取消）"
				"harvest":
					cmd_hint_label.text = "采集：左键选择矿点（Esc / 右键取消）"
				_:
					cmd_hint_label.text = ""
	for key in cmd_buttons.keys():
		if key in preload("res://scripts/ui/combat_stance_bar.gd").IDS: continue
		var b = cmd_buttons[key]
		if is_instance_valid(b):
			if key == "exclude":
				var targets: Array = battle.selected_units.filter(func(u): return battle.actor_alive(u) and u.side == "ally")
				b.set_pressed_no_signal(not targets.is_empty() and targets.all(func(u): return u.excluded_from_army_selection))
				b.get_child(0).queue_redraw()
				continue
			b.set_pressed_no_signal(str(key) == mode)
			if key == "follow": b.set_pressed_no_signal(is_instance_valid(battle.follow_target) and battle.selected_units.has(battle.follow_target))
	_refresh_deploy_cmd()
	if is_instance_valid(_stance_bar): _stance_bar.refresh()

## (M6) 「部署/卧倒」按钮状态：已卧倒时点亮为琥珀色，tooltip 变成「起身」。
## 「单点释放主技能」：单击即切换，不必先选技能再点地面。
func _refresh_deploy_cmd() -> void:
	var btn: Button = cmd_buttons.get("deploy")
	if btn == null or not is_instance_valid(btn):
		return
	if is_instance_valid(battle.selected_building):
		var status := ConstructionRepack.check(battle, battle.selected_building)
		btn.disabled = not status.ok
		btn.tooltip_text = "收起矿场 (J)\n保留生命比例和现有矿工" if battle.selected_building.building_id=="YAREFN" else "收起基地车 (J)\n保留生命比例与已付建造进度，不另收费"
		if not status.ok:
			btn.tooltip_text += "\n不可用：" + str(status.reason)
		btn.tooltip_text=Hotkeys.hint(btn.tooltip_text)
		return
	var ok := false
	var dep := false
	var logistics_hint := ""
	for u in battle.selected_units:
		if not is_instance_valid(u) or not u.has_method("can_deploy"):
			continue
		if not u.can_deploy():
			continue
		ok = true
		if not u.deploy_building_id().is_empty():
			var status: Dictionary = battle.construction_deploy_check(u)
			logistics_hint = "展开奴隶矿场 (J)\n在矿区附近部署，最多容纳五名矿工" if u.unit_id=="SMIN" else "展开建造厂 (J)\n原地展开，不另扣资金；保留当前生命比例"
			if not status.ok:
				logistics_hint += "\n当前无法展开：" + str(status.reason)
		elif u.unit_id=="YURI":
			logistics_hint = "心灵波 (J)\n杀伤周围三格内的敌方步兵"
		elif u.special.has("peregrine"):
			var maintained:bool=u.special.peregrine.has("maintenance")
			logistics_hint="起飞 (J)\n结束维护并清除维护盾；空中自补继续" if maintained else "下降维护 (J)\n需在同方有效机场 3 格内合法空地；不占机场位，维护时停火，3 秒未受敌伤后回血"
			dep=maintained
		elif u.logistics.capacity > 0:
			logistics_hint = "卸载乘员 (J)\n在陆地或可通行岸边卸载；没有空位时乘员留在载具内"
		elif u.logistics.ammo_max > 0:
			logistics_hint = "返回机场 (J)\n返航停靠补弹；停机位或机场不可用时等待"
		elif u.unit_id == "GGI":
			logistics_hint = "收起导弹 (J)\n恢复机枪和移动" if u.is_deployed() else "部署导弹 (J)\n固定反装甲/防空，近距有盲区；部署时不可被普通坦克碾压"
		if u.has_method("is_deployed") and u.is_deployed():
			dep = true
	btn.disabled = not ok
	btn.set_pressed_no_signal(dep)
	var caption = btn.get_node_or_null("CommandCaption")
	if caption != null: caption.text = "收起" if dep else "部署"
	if caption!=null and logistics_hint.begins_with("起飞"):caption.text="起飞"
	elif caption!=null and logistics_hint.begins_with("下降维护"):caption.text="维护"
	if logistics_hint != "":
		btn.tooltip_text = logistics_hint
	elif not ok:
		btn.tooltip_text = "部署 (J)\n选中美国大兵等可部署单位后可用"
	elif dep:
		btn.tooltip_text = "起身 (J)\n单击让已卧倒的单位起身"
	else:
		btn.tooltip_text = "部署 (J)\n单击卧倒据守：火力↑ · 不能移动（再点一次起身）"
	btn.tooltip_text=Hotkeys.hint(btn.tooltip_text)
	for c in btn.get_children():
		if c is CmdGlyph:
			c.modulate = Color(1.0, 0.78, 0.35) if dep else Color(1, 1, 1)

func _cycle_view() -> void:
	if battle != null and battle.has_method("cycle_view_preset"):
		battle.cycle_view_preset()

func _on_view_changed(label: String) -> void:
	if view_btn != null and is_instance_valid(view_btn):
		view_btn.text = "视角 " + label

func _defense_status(b) -> String:
	if b.data.has("extra_power"): return "供电人员 %d / %d · 满血供电 %d" % [b.special.get("occupants",[]).size(),b.data.garrison_slots,b.installed_power()]
	if b.data.has("charged_weapon"):
		var n := preload("res://scripts/units/tesla_support.gd").count(b)
		var low: bool = battle.side_power_low(b.side)
		var state := "强化射击" if n >= (3 if low else 1) else ("等待供电" if low and n < 2 else "基础射击")
		return "充能步兵 %d · %s" % [n, state]
	if b.data.has("garrison_weapons"):
		var garrison = preload("res://scripts/units/civilian_orders.gd")
		return "驻军 %d / %d · 对地射程 %.1f 格%s" % [b.special.get("occupants", []).size(), garrison.slots(b),
			garrison.bunker_range(b) / Ra2Damage.PX_PER_CELL, "" if garrison.has_gunner(b) else " · 暂无火力"]
	return "驻军 %d / %d · 动员兵或美国大兵右键进入 · 低血量自动撤出" % [b.special.get("occupants", []).size(),preload("res://scripts/units/civilian_orders.gd").slots(b)]

func _show_building_info(b) -> void:
	if b.side == "ally" and b.supports_attack_order():
		var grid:=GridContainer.new()
		grid.columns=2
		_command_box.add_child(grid)
		_add_cmd(grid,"攻击 (A)","attack","选择射程内的敌人，或 Ctrl＋左键强攻单位或地面")
		_add_cmd(grid,"停止 (S)","stop","取消当前集火目标")
	var capacity := preload("res://scripts/units/civilian_orders.gd").slots(b)
	if capacity > 0 or b.data.has("charged_weapon"):
		var status: Label = kit.make_label(_defense_status(b), 13, kit.COL_DIM)
		status.name = "DefenseStatus"
		sel_box.add_child(status)
	if capacity > 0:
		if b.side == "ally":
			var leave := kit.make_button("撤出全部驻军  J", 14)
			leave.pressed.connect(func(): preload("res://scripts/units/civilian_orders.gd").evacuate(b, false, true))
			_command_box.add_child(leave)
	if b.building_id == "CABHUT":
		sel_box.add_child(kit.make_label("桥面可通行，伊文右键维修屋可装弹炸桥" if b.special.get("bridge_repaired", false) else "工程师右键进入，修复关联桥梁", 13, kit.COL_DIM))
	if b.side == "ally" and (b.is_hq or b.data.get("tags", []).has("purifier") or b.building_id == "GAROBO"):
		_add_economy_status()
		_refresh_economy_status(b)
	if b.side == "ally" and str(b.building_id) in ["GACNST", "NACNST","YAREFN"]:
		var repack: Button = kit.make_button("收起矿场  J" if b.building_id=="YAREFN" else "收起基地车  J", 14)
		repack.custom_minimum_size.y = 48
		var icon := GameData.ra2_cameo_path(ConstructionRepack.vehicle_type(b))
		if ResourceLoader.exists(icon):
			repack.icon = load(icon)
			repack.expand_icon = true
			repack.add_theme_constant_override("icon_max_width", 48)
		repack.pressed.connect(func(): battle.deploy_selected())
		_command_box.add_child(repack)
		cmd_buttons["deploy"] = repack
		_refresh_deploy_cmd()
		if b.building_id == "GACNST":
			var clearance_panel = preload("res://scripts/ui/ra3_clearance_panel.gd").new()
			_command_box.add_child(clearance_panel)
			clearance_panel.setup(b)
	var head := HBoxContainer.new()
	sel_box.add_child(head)
	head.add_child(kit.make_label(b.display_name, 16, kit.COL_ACCENT_2))
	_add_description(head, b.data)
	var wall_count: int = battle.selected_wall_members().size()
	if wall_count > 1:
		sel_box.add_child(kit.make_label("已选围墙：%d 段 · 血量显示当前点击段" % wall_count, 13, kit.COL_OK))
		var sell_walls: Button = kit.make_button("出售所选围墙（%d 段）" % wall_count, 14)
		sell_walls.name = "SellSelectedWalls"
		sell_walls.pressed.connect(battle.sell_selected_building)
		_command_box.add_child(sell_walls)
	sel_box.add_child(kit.make_label("阵营：%s" % GameData.get_faction(b.faction).get("name", b.faction), 13, kit.COL_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	sel_box.add_child(row)
	sel_hp_bar = _make_hp_bar(b.hp, b.max_hp, 16)
	row.add_child(sel_hp_bar)
	sel_hp_label = kit.make_label("%d / %d" % [int(ceil(b.hp)), int(b.max_hp)], 12, kit.COL_TEXT)
	row.add_child(sel_hp_label)
	sel_shield_label = kit.make_label("",12,Unit.TankHero.Shield.COLOR)
	sel_box.add_child(sel_shield_label)
	_refresh_shield_live(b)
	sel_box.add_child(kit.make_label("护甲 %s" % GameData.armor_label(b.armor), 13, kit.COL_TEXT))
	if b.under_construction:
		sel_box.add_child(kit.make_label("建造中", 13, kit.COL_WARN))
		sel_box.add_child(_make_build_bar(b.build_elapsed / max(0.01, b.build_total), "%d%%" % int(clampf(b.build_elapsed / max(0.01, b.build_total), 0.0, 1.0) * 100), kit.COL_WARN))
	if not (b.weapon as Dictionary).is_empty():
		sel_box.add_child(kit.make_label("防御武器：%s" % b.weapon.get("name", ""), 13, kit.COL_TEXT))
		sel_box.add_child(kit.make_label(CombatMath.describe_weapon(b.weapon), 12, kit.COL_DIM))
	if b.special.has("flak_card") and b.special.flak_card>0:
		var card:=GameData.get_skill("ps_barrage")
		var rank:int=BattleRequest.combat_context.get("card_ranks",{}).get(card.id,0)
		var label:=kit.make_label(card.name+"　"+MetaProgress.Academy.skill_description(card,rank,b.special.flak_card),12,kit.COL_DIM)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		sel_box.add_child(label)
	if not b.superweapon.is_empty() and not b.under_construction:
		sel_box.add_child(kit.divider())
		var swb: Button = kit.make_button(b.sw_label())
		swb.disabled = not b.sw_ready()
		swb.pressed.connect(func():
			if is_instance_valid(b):
				battle.arm_superweapon(b)
		)
		_command_box.add_child(swb)
		_sw_btn = swb
		_sw_src = b
	if b.is_refinery() and b.side == "ally":
		sel_box.add_child(kit.divider())
		var hint := kit.make_label("科技：矿场矿车制造。每座矿场同时制造一辆，出厂后自动采矿。", 12, kit.COL_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sel_box.add_child(hint)
		_update_refinery_live()
	elif not (b.buildable as Array).is_empty() and not b.under_construction:
		sel_box.add_child(kit.divider())
		var _t: String = _tab_for_building(b)
		var _tn: String = _tab_label(_t) if _t != "" else "生产"
		var production_hint := kit.make_label("在「指令甲板 · %s」点击单位开始生产。" % _tn, 12, kit.COL_OK)
		production_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sel_box.add_child(production_hint)
		var rally_hint := kit.make_label("右键地面设置集结点；右键本建筑清除。", 12, kit.COL_DIM)
		rally_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sel_box.add_child(rally_hint)
	elif b.is_hq:
		sel_box.add_child(kit.make_label("点击右侧建筑页签，生产并放置新建筑", 12, kit.COL_DIM))
	# 选中建筑时立即刷新生产面板（此前只能等 _process 的 0.45s 轮询，面板会明显迟滞）
	_refresh_production()

func _build_refinery_ability(b) -> void:
	ability_panel.show()
	ability_title.text = "%s　技能" % b.display_name
	_refinery_src = b
	_refinery_btn = kit.make_button("", 11)
	_refinery_btn.custom_minimum_size.y = 38
	_refinery_btn.focus_mode = Control.FOCUS_NONE
	_refinery_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_refinery_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Keep the portrait independent of Button's multiline text/icon fitting.
	# expand_icon can shrink the icon to zero beside a two-line caption.
	var content := HBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6.0
	content.offset_right = -6.0
	content.offset_top = 3.0
	content.offset_bottom = -3.0
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refinery_btn.add_child(content)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(40, 30)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var miner_id: String = Building.CONSTRUCTION_FREE_UNITS.get(b.building_id, "CMIN")
	var miner_icon := GameData.ra2_cameo_path(miner_id)
	if not miner_icon.is_empty() and ResourceLoader.exists(miner_icon):
		portrait.texture = load(miner_icon) as Texture2D
	content.add_child(portrait)
	var caption := kit.make_label("", 11)
	caption.name = "Caption"
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	_refinery_btn.pressed.connect(func():
		if is_instance_valid(b):
			if not b.resume_production(miner_id): b.enqueue(miner_id)
			_update_refinery_live()
	)
	_refinery_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and is_instance_valid(b):
			_refinery_btn.accept_event()
			b.production_right_click(miner_id)
			_update_refinery_live())
	ability_box.add_child(_refinery_btn)
	_refinery_cancel = kit.make_button("暂停制造", 11)
	_refinery_cancel.focus_mode = Control.FOCUS_NONE
	_refinery_cancel.pressed.connect(func():
		if is_instance_valid(b):
			b.production_right_click(miner_id)
			_update_refinery_live()
	)
	ability_box.add_child(_refinery_cancel)
	_update_refinery_live()

var _refinery_btn: Button
var _refinery_cancel: Button
var _refinery_src

func _update_refinery_live() -> void:
	if not is_instance_valid(_refinery_btn) or not is_instance_valid(_refinery_src):
		return
	var b = _refinery_src
	var miner_id: String = Building.CONSTRUCTION_FREE_UNITS.get(b.building_id, "CMIN")
	var busy: bool = not b.production.is_empty()
	var unit_data := GameData.get_unit(miner_id)
	var cost := int(battle.production_price(unit_data, b.side))
	var seconds := production_seconds(unit_data, b)
	var reason: String = b.queue_block_reason(miner_id)
	_refinery_btn.disabled = not reason.is_empty() and not b.production_paused()
	var status := _queue_caption(b) if busy else "$%d · %.1f秒 · 点击制造" % [cost, seconds]
	if not reason.is_empty() and not busy:
		status = reason
	var caption := _refinery_btn.get_node("Content/Caption") as Label
	if b.queue_capacity() > 1:
		status += " · 队列 %d/%d" % [b.production.size(), b.queue_capacity()]
	caption.text = "制造采矿车\n" + status
	_refinery_btn.custom_minimum_size = (_refinery_btn.get_node("Content") as Control).get_combined_minimum_size() + Vector2(12, 6)
	var tech_state := "调试已解锁" if GM.unlock_production_tech else ("已解锁" if b.production_tech_block_reason(miner_id).is_empty() else "未解锁")
	_refinery_btn.tooltip_text = caption.text + "\n科技：矿场矿车制造（%s）\n每座矿场同时制造一辆，出厂后自动采矿。\n沿生产进度扣费；缺钱暂停；出口受阻时等待，清空后出车。\n生产中右键暂停；已暂停时左键继续、右键取消。" % tech_state
	if is_instance_valid(_refinery_cancel):
		_refinery_cancel.visible = busy
		_refinery_cancel.text = "取消制造" if b.production_paused() else "暂停制造"
		_refinery_cancel.tooltip_text = "取消最后一辆，退还该订单已付费用" if b.production_paused() else "暂停并保留生产进度；再次点击取消制造"

# ------------------------------------------------------------------ 生产面板

var _recipe_window: Window
var _recipe_button: Button
var prod_tab: String = "building"
var _factories = preload("res://scripts/ui/production_factories.gd").new(self)
var _last_group_digit := 0
var _last_group_tap_ms := 0

# —— 底部指令甲板（红警2 侧栏 → 底部）容器引用 ——
var deck_tabs: GridContainer = null
var deck_tabs_btns: Dictionary = {}   # tab_id -> Button
var _deck_faction := ""
var _deck_cap: Label
var deck_title: Label = null
var _ready_tab_phase := 0.0

## 鼠标生产页签：建筑 / 防御 / 步兵 / 载具 / 空军 / 海军
## 红警3 把飞机、舰船从「载具」里拆成独立页签，这里照做。
## D7=B：**无内容的页签自动隐藏**（如本工程暂无海军设施 → 海军页签不显示）。
func _add_prod_tabs() -> void:
	if deck_tabs == null:
		return
	_deck_faction = battle.roster_faction()
	deck_tabs_btns.clear()
	var defs: Array = [["building", "建筑"], ["defense", "防御"], ["infantry", "步兵"], ["vehicle", "载具"], ["air", "空军"], ["naval", "海军"]]
	var shown: Array[String] = []
	for d in defs:
		if _tab_available(str(d[0])):
			shown.append(str(d[0]))
	# 若当前页签被隐藏，回落到「建筑」
	if not shown.has(prod_tab):
		prod_tab = "building" if shown.has("building") else (shown[0] if not shown.is_empty() else "building")
	for d in defs:
		var id: String = str(d[0])
		if not shown.has(id):
			continue
		var tb: Button = kit.ra_button(11, 24)
		tb.set_script(ProductionTooltipScript)
		tb.text = str(d[1])
		tb.tooltip_text = str(d[1]) + "生产目录"
		if is_instance_valid(_production_inspector):
			_production_inspector.bind(tb, tb.text)
		tb.custom_minimum_size = Vector2(54, 24)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.button_pressed = not production_collapsed and prod_tab == id
		tb.pressed.connect(func() -> void:
			if not production_collapsed and prod_tab == id:
				set_production_collapsed(true, false)
			else:
				select_prod_tab(id))
		tb.draw.connect(func() -> void: _draw_ready_tab(tb, id))
		deck_tabs.add_child(tb)
		deck_tabs_btns[id] = tb
	_update_ready_tabs(0.0)

## Keep the actual tab button and its input intact; draw above the RA3 skin.
## Selected tabs also blink until every ready item is placed or cancelled.
func _update_ready_tabs(delta: float) -> void:
	if battle == null: return
	var any_ready := false
	for id in ["building", "defense"]:
		var button: Button = deck_tabs_btns.get(id)
		if not is_instance_valid(button): continue
		var count: int = battle.structure_ready_count(id) if not battle.ended else 0
		any_ready = any_ready or count > 0
		button.tooltip_text = "%s：%d 项建造就绪，点击页签后选择图标放置" % [_tab_label(id), count] if count > 0 else _tab_label(id)
		button.queue_redraw()
	_ready_tab_phase = fmod(_ready_tab_phase + maxf(0.0, delta), 1.0) if any_ready else 0.0

func _draw_ready_tab(button: Button, id: String) -> void:
	if battle == null or battle.ended or battle.structure_ready_count(id) <= 0: return
	var pulse := 0.5 + 0.5 * cos(TAU * _ready_tab_phase)
	var rect := Rect2(Vector2(1, 1), button.size - Vector2(2, 2))
	var cut := 5.0
	var points := PackedVector2Array([
		rect.position + Vector2(cut, 0), Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(0, cut), rect.end - Vector2(cut, 0),
		Vector2(rect.position.x, rect.end.y), rect.position + Vector2(0, cut)])
	button.draw_colored_polygon(points, Color(1.0, 0.72, 0.12, 0.03 + 0.38 * pulse))
	points.append(points[0])
	button.draw_polyline(points, Color(1.0, 0.82, 0.22, 0.12 + 0.88 * pulse), 2.0, true)

## 该页签是否有可生产内容（D7=B 无内容则隐藏）。建筑/防御恒有。
func _tab_available(id: String) -> bool:
	if id == "building" or id == "defense":
		return true
	for bd in _construction_choices():
		if bd.faction == "soviet" and not bd.get("ra2", false): continue
		for uid in (bd.get("builds", []) as Array):
			var ud := GameData.get_unit(str(uid))
			if ud.is_empty():
				continue
			var c := _unit_cat(ud)
			if c == id or (id == "vehicle" and c == "support"):
				return true
	return false

## 鼠标或解锁引导切换生产页签。
func select_prod_tab(id: String) -> void:
	if not deck_tabs_btns.has(id):
		return
	_unlock_focus = ""
	prod_tab = id
	if production_collapsed: set_production_collapsed(false, false)
	for k in deck_tabs_btns.keys():
		var btn: Button = deck_tabs_btns[k]
		if is_instance_valid(btn):
			btn.button_pressed = (k == id)
	_prod_sig = ""
	if deck_title != null:
		deck_title.text = "指令甲板 · %s" % _tab_label(id)
	_refresh_production()

func _tab_label(id: String) -> String:
	match id:
		"building": return "建筑"
		"defense": return "防御"
		"infantry": return "步兵"
		"vehicle": return "载具"
		"air": return "空军"
		"naval": return "海军"
	return "指令"

## 依据建筑可生产单位的分类，推断应展示的甲板页签（步兵 / 载具 / 空军 / 海军；无 → ""）
## 红警3 风格：飞机、舰船各自独立页签，不再混在载具里。
func _tab_for_building(b) -> String:
	var has_inf := false
	var has_veh := false
	var has_air := false
	var has_nav := false
	for uid in (b.buildable as Array):
		var ud := GameData.get_unit(str(uid))
		if ud.is_empty():
			continue
		var c := _unit_cat(ud)
		if c == "infantry":
			has_inf = true
		elif c == "naval":
			has_nav = true
		elif c == "air":
			has_air = true
		elif c == "vehicle" or c == "support":
			has_veh = true
	# 单一类别 → 直接落到该页
	if has_inf and not (has_veh or has_air or has_nav):
		return "infantry"
	if has_veh and not (has_inf or has_air or has_nav):
		return "vehicle"
	if has_air and not (has_inf or has_veh or has_nav):
		return "air"
	if has_nav and not (has_inf or has_veh or has_air):
		return "naval"
	if has_inf:
		return "infantry"
	if has_veh:
		return "vehicle"
	if has_air:
		return "air"
	if has_nav:
		return "naval"
	return ""

## 点选有生产功能的建筑时，自动跳到对应生产页（不改动用户随后的手动切页）
func _auto_focus_building_tab(b) -> void:
	if not is_instance_valid(b):
		return
	if b.is_refinery():
		return
	if b.side != "ally" or b.under_construction:
		return
	if b.is_hq:
		select_prod_tab("building")
		return
	if (b.buildable as Array).is_empty():
		return
	var t := _tab_for_building(b)
	if t != "":
		_factories.remember(b, t)
	if t != "" and t != prod_tab:
		select_prod_tab(t)

## 建筑目录（按页签过滤：建筑=非防御，防御=防御）。
## RA3 风格：不可建造项不隐藏，保留在网格中置灰（可用性见 _build_state）。
func _construction_choices() -> Array:
	var native: String = battle.roster_faction()
	var choices := GameData.buildings_for_faction(native)
	for foreign in ["allied","soviet","yuri"]:
		if foreign == native or not battle.has_construction_roster(foreign): continue
		if foreign == "yuri" and not battle.skirmish: continue
		for building in GameData.buildings_for_faction(foreign):
			if GameData.is_ra2(str(building.id)) and building.id!="NEUTRALSTUDIO": choices.append(building)
	return choices

func _building_catalog() -> Array:
	var ra2: Array = []
	var eng: Array = []
	for bd in _construction_choices():
		if bd.faction == "soviet" and not bd.get("ra2", false): continue
		var tags: Array = bd.get("tags", [])
		if int(bd.get("cost", 0)) <= 0 or tags.has("hq"):
			continue
		if not GameData.building_production_block_reason(str(bd.get("id", ""))).is_empty():
			continue
		var is_def: bool = battle.structure_category(str(bd.get("id", ""))) == "defense"
		if not ((prod_tab == "defense" and is_def) or (prod_tab == "building" and not is_def)):
			continue
		var id := str(bd.get("id", ""))
		if GameData.is_ra2(id):
			ra2.append(id)
		else:
			eng.append(id)
	return GameData.catalog_sorted(ra2, prod_tab) + eng if BattleRequest.extensions_enabled() else GameData.catalog_sorted(ra2, prod_tab)

## 某建筑当前是否可建造（RA3 侧栏置灰口径）：{ ok: bool, reason: String }
func _build_state(bid: String) -> Dictionary:
	if bid==MetaProgress.Academy.Stars.STUDIO:
		var studio_reason:String=battle.structure_production_block_reason(bid)
		return {"ok":studio_reason.is_empty(),"reason":studio_reason}
	var disabled_reason := GameData.building_production_block_reason(bid)
	if not disabled_reason.is_empty():
		return {"ok": false, "reason": disabled_reason}
	var paid := int(battle.struct_ready.get(bid,0)) > 0
	var limit: String = battle.limit_reason(bid, "ally", paid)
	if not limit.is_empty(): return {"ok": false, "reason": limit}
	var country_reason: String = battle.country_block_reason(bid)
	if not country_reason.is_empty():
		return { "ok": false, "reason": country_reason }
	if GameData.is_ra2(bid):
		var owned := _owned_building_ids()
		if GameData.ra2_prereq_ok(bid, owned):
			return { "ok": true, "reason": "" }
		return { "ok": false, "reason": "缺少前置：" + _prereq_names(bid, owned) }
	if GameData.ra2_loaded:
		return { "ok": false, "reason": "当前阵容无法建造" }
	return { "ok": true, "reason": "" }

## 把未满足的前置令牌翻成中文名（用于置灰提示）
func _prereq_names(bid: String, owned: Array) -> String:
	return GameData.ra2_missing_prereq_names(bid, owned)

func _entity_name(id: String) -> String:
	return str((GameData.get_entity(id) as Dictionary).get("name", id))

## 生产甲板目录：列出本阵营全部单位（RA2 在前、引擎自带在后）。
## RA3 风格：不因缺少生产建筑而隐藏，只是置灰（可用性见 _unit_state）。
func _unit_catalog() -> Array:
	if preload("res://scripts/expedition/rules.gd").active():
		var available: Array = []
		var factory = _factories.current()
		if not is_instance_valid(factory):
			return available
		for uid: String in factory.buildable:
			if _cat_match(GameData.get_unit(uid)) and GameData.unit_production_block_reason(uid, battle.allied_state, factory.side).is_empty():
				available.append(uid)
		return GameData.catalog_sorted(available, "unit")
	var native: String = battle.roster_faction()
	var catalog := GameData.faction_unit_catalog(native)
	if not BattleRequest.skirmish:
		catalog = catalog.filter(func(id: String): return not id.begins_with("R3") and id != "YURIKO")
	var extra: Array = []
	for b in battle.buildings:
		if not battle.actor_alive(b) or b.side != "ally" or b.under_construction or b.is_refinery(): continue
		if b.faction == native and b.building_id not in ["GAPILE", "NAHAND"]: continue
		for id in b.buildable:
			if catalog.has(id) or extra.has(id) or not (GameData.is_ra2(id) or GameData.hollywood_production_unit(id)) or str(id).begins_with("R3"): continue
			if id in GameData.STOLEN_INFANTRY and not GameData.unit_production_block_reason(id, battle.allied_state).is_empty(): continue
			extra.append(id)
	if not extra.is_empty(): catalog = GameData.catalog_sorted(catalog + extra, "unit")
	if not GameData.mission_production_tech().is_empty():
		var owned := _owned_building_ids()
		catalog = catalog.filter(func(id): return GameData.mission_product_block_reason(str(id), owned).is_empty())
	return catalog

## 某单位当前是否可生产：{ ok: bool, reason: String }
func _unit_state(uid: String) -> Dictionary:
	var roster_reason := GameData.unit_production_block_reason(uid, battle.allied_state)
	if not roster_reason.is_empty():
		return { "ok": false, "reason": roster_reason }
	var country_reason: String = battle.country_block_reason(uid)
	if not country_reason.is_empty():
		return { "ok": false, "reason": country_reason }
	if GameData.is_ra2(uid) or GameData.hollywood_production_unit(uid):
		var p = _producer_for(uid)
		if p != null:
			var reason: String = p.queue_block_reason(uid)
			return { "ok": reason.is_empty(), "reason": reason }
		var at := str(GameData.get_unit(uid).get("built_at", ""))
		return { "ok": false, "reason": "需要：" + _entity_name(at) }
	if GameData.ra2_loaded:
		return { "ok": false, "reason": "当前阵容无法生产" }
	return { "ok": true, "reason": "" }

## 当前“活跃生产建筑”：优先选中建筑（若它在施工/有队列），否则我方第一座忙碌的，最后回退。
func _active_producer():
	if prod_tab not in ["building", "defense"]:
		return _factories.current()
	var b = battle.selected_building
	if is_instance_valid(b) and b.side == "ally" and (b.under_construction or not (b.production as Array).is_empty()):
		return b
	for node in get_tree().get_nodes_in_group("ally_buildings"):
		if is_instance_valid(node) and (node.under_construction or not (node.production as Array).is_empty()):
			return node
	if is_instance_valid(b) and b.side == "ally":
		return b
	var hs := get_tree().get_nodes_in_group("ally_buildings")
	if hs.size() > 0:
		return hs[0]
	return null

## 为某单位寻找能生产它的建筑（红警2 式自动路由，无需先选中建筑）
func _producer_for(uid: String):
	if prod_tab not in ["building", "defense"] and _cat_match(GameData.get_unit(uid)):
		# Factory tabs own normal production; refinery manufacture is a separate technology action.
		var active = _factories.current()
		if is_instance_valid(active) and active.buildable.has(uid):
			return active
	var b = battle.selected_building
	if is_instance_valid(b) and b.side == "ally" and not b.is_refinery() and not b.is_dead() and not b.under_construction and (b.buildable as Array).has(uid):
		return b
	for node in get_tree().get_nodes_in_group("ally_buildings"):
		if is_instance_valid(node) and not node.is_refinery() and not node.is_dead() and not node.under_construction and (node.buildable as Array).has(uid):
			return node
	# 仍在施工的唯一生产建筑也应给出具体原因，而不是声称没有该建筑。
	for node in get_tree().get_nodes_in_group("ally_buildings"):
		if is_instance_valid(node) and not node.is_refinery() and not node.is_dead() and (node.buildable as Array).has(uid):
			return node
	return null

func _unit_cat(ud: Dictionary) -> String:
	return GameData.unit_production_category(ud)

func _cat_match(ud: Dictionary) -> bool:
	if ud.is_empty():
		return false
	var c := _unit_cat(ud)
	match prod_tab:
		"infantry":
			return c == "infantry"
		"vehicle":
			return c == "vehicle" or c == "support"
		"air":
			return c == "air"
		"naval":
			return c == "naval"
		_:
			return false

# —— 生产面板持久缓存：避免周期性整体重建导致按钮在“按下/抬起”之间被销毁而丢失点击 ——
var _prod_sig: String = ""
var _prod_buttons: Dictionary = {}   # uid -> Button
var _prod_wipes: Dictionary = {}     # uid -> CameoWipe（红警2 式卡片建造进度擦除 + 队列角标）
var _prod_bars: Dictionary = {}      # "build" / "queue" -> [production clock, Label]
var _prod_locked: Dictionary = {}     # uid -> 置灰原因（RA3 风格：不可建造而非隐藏）
var _prod_status_labels: Dictionary = {} # uid -> 卡片第二行，原地更新状态
var _structure_status: Label = null
var _queue_host: VBoxContainer = null   # 页脚：队列图标网格宿主（原地刷新）
var _queue_shape_sig: String = ""
# 长按连造：按住生产按钮超过 HOLD_TIME 一次性排 HOLD_BATCH 个（等同 Shift+点击）
const HOLD_TIME: float = 0.45
const HOLD_BATCH: int = 5
var _hold_uid: String = ""
var _hold_t: float = 0.0
var _hold_fired: bool = false

## 尤复式建造/生产时钟 + 状态说明；与卡片读取同一实际进度。
func _make_build_bar(frac: float, caption: String, _fill_col: Color = kit.RA_CYAN, kind: String = "") -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	var clock := CameoWipe.new()
	clock.custom_minimum_size=Vector2(34,34)
	clock.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var producer = _active_producer()
	clock.faction_id = str(producer.faction) if is_instance_valid(producer) else "allied"
	clock.set_state(frac,0)
	box.add_child(clock)
	var cap := kit.ra_label(caption,12,kit.COL_DIM)
	cap.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_child(cap)
	if kind != "": _prod_bars[kind]=[clock,cap]
	return box


func _prod_signature() -> String:
	var parts: Array = [str(prod_tab), _factories.signature(), str(GM.no_build_time)]
	if prod_tab == "building" or prod_tab == "defense":
		for bid in _building_catalog():
			parts.append(str(bid) + ("+" if (_build_state(str(bid)).get("ok", true) == true) else "-"))
		# 建筑就绪 / 当前建造项变化时重绘侧栏（不计进度百分比，避免逐帧重建）
		if battle.get("struct_ready") != null:
			for rid in battle.struct_ready_order:
				parts.append("R:" + str(rid) + ":" + str(int(battle.struct_ready.get(rid, 0))))
		var sjob: Dictionary = battle.current_structure_job(prod_tab) if battle.has_method("current_structure_job") else {}
		parts.append("J:" + str(sjob.get("id", "")))
	else:
		for uid in _unit_catalog():
			if _cat_match(GameData.get_unit(str(uid))):
				parts.append(str(uid))
	var p = _active_producer()
	parts.append(str(p.get_instance_id()) if is_instance_valid(p) else "-")
	if is_instance_valid(p):
		parts.append("c" if p.under_construction else "n")
	# 注意：队列内容不计入签名 —— 队列变化走 _update_queue_host() 原地重建图标条，
	# 避免每排一个兵就整体重建、销毁“按下中”的按钮（连续建造丢点击）。
	return "|".join(PackedStringArray(parts))

func _catalog_block_reason(uid: String) -> String:
	if prod_tab in ["building", "defense"] and battle.structure_is_paused(uid): return ""
	var current = _factories.current() if prod_tab not in ["building", "defense"] else null
	if is_instance_valid(current) and current.production_paused(uid) and current.production_head(uid) >= 0 and str(current.production[current.production_head(uid)]) == uid: return ""
	var state := _build_state(uid) if prod_tab in ["building", "defense"] else _unit_state(uid)
	if not bool(state.get("ok", true)):
		return str(state.get("reason", "当前不可生产"))
	if prod_tab in ["building", "defense"] and int(battle.struct_ready.get(uid,0)) == 0:
		var queue_reason: String = battle.structure_queue_block_reason(uid)
		if not queue_reason.is_empty():
			return queue_reason
	return ""

func _production_payment_hint(uid: String) -> String:
	var cost: float = battle.production_price(GameData.get_entity(uid), "ally")
	var funds: float = battle.current_funds()
	if not GM.infinite_funds and funds < cost:
		return "可下单，随进度扣费；资金耗尽时等待，到账自动继续。总价 %d，现有 %d，尚差 %d。" % [int(cost), int(funds), int(ceil(cost - funds))]
	return ""

func _explain_disabled_cameo(uid: String) -> void:
	var reason := _catalog_block_reason(uid)
	if not reason.is_empty():
		_show_unlock_panel(uid)
		Events.emit_message("%s：%s" % [_entity_name(uid), _with_unlock_hint(uid, reason)], kit.COL_WARN)

func _show_unlock_panel(uid: String) -> void:
	if prod_tab in ["building", "defense"] and not battle.structure_queue_block_reason(uid).is_empty() and bool(_build_state(uid).get("ok", true)):
		return
	var guide: Dictionary = _unlock_guide(uid)
	if str(guide.get("summary", "")).is_empty():
		return
	if not _unlock_source.is_empty():
		var original: Dictionary = _unlock_guide(_unlock_source)
		for step in original.get("steps", []):
			if str(step.id) == uid:
				_unlock_panel.present(_entity_name(_unlock_source), original)
				return
	if _unlock_source != uid:
		_unlock_choices.clear()
	_unlock_source = uid
	_unlock_tab = prod_tab
	_unlock_panel.present(_entity_name(uid), guide)

func _close_unlock_panel() -> void:
	_unlock_source = ""
	_unlock_focus = ""
	_unlock_choices.clear()
	_unlock_panel.hide()
	_update_production_live()

func _unlock_guide(uid: String) -> Dictionary:
	return UnlockGuidanceScript.new(battle, _unlock_choices if uid == _unlock_source else {}).describe(uid)

func _choose_unlock_alternative(token: String, id: String) -> void:
	if _unlock_source.is_empty():
		return
	var guide := _unlock_guide(_unlock_source)
	for group in guide.get("alternatives", []):
		if str(group.token) != token:
			continue
		for option in group.options:
			if str(option.id) == id and bool(option.can_choose):
				_unlock_choices[token] = id
				_unlock_focus = ""
				_update_production_live()
				return

func _locate_unlock_building(bid: String) -> void:
	var data := GameData.get_building(bid)
	if data.is_empty() or data.get("tags", []).has("hq") or float(data.get("cost", 0)) <= 0:
		return
	_locate_unlock_cameo(bid, battle.structure_category(bid))

func _return_to_unlock_source() -> void:
	if not _unlock_source.is_empty():
		_locate_unlock_cameo(_unlock_source, _unlock_tab)

func _locate_unlock_cameo(id: String, tab: String) -> void:
	select_prod_tab(tab)
	if not _prod_buttons.has(id):
		return
	_unlock_focus = id
	_update_production_live()
	_scroll_to_unlock_cameo(id)

func _scroll_to_unlock_cameo(id: String) -> void:
	# Wait for the changed tab and route panel to finish container layout.
	for i in 2:
		await get_tree().process_frame
	if _unlock_focus == id and is_instance_valid(_prod_buttons.get(id)):
		_prod_scroll.ensure_control_visible(_prod_buttons[id])

func _with_unlock_hint(uid: String, reason: String) -> String:
	if prod_tab in ["building", "defense"] and reason == battle.structure_queue_block_reason(uid):
		return reason
	var guide: Dictionary = _unlock_guide(uid)
	var summary := str(guide.get("summary", ""))
	return reason + ("；" + summary if not summary.is_empty() else "")

func _update_production_live() -> void:
	_factories.update()
	var guidance = UnlockGuidanceScript.new(battle)
	for uid in _prod_buttons.keys():
		var btn: Button = _prod_buttons[uid]
		if is_instance_valid(btn):
			var cue:float = battle.allied_state.get("hollywood",{}).get("cameo_left",0.0) if uid=="BFRT" else 0.0
			btn.guide_highlight = str(uid) == _unlock_focus or (cue>0 and fmod(cue,0.5)<0.3)
			var data := GameData.get_entity(str(uid))
			var cost: float = battle.production_price(data, "ally")
			var label: Label = _prod_status_labels.get(uid)
			var state := ""
			var color: Color = kit.COL_GOLD
			var ready_n := int(battle.struct_ready.get(str(uid), 0))
			var queue_index := -1
			var jobs: Array = battle.structure_jobs(prod_tab)
			for i in jobs.size():
				if str(jobs[i].id) == str(uid):
					queue_index = i
					break
			if ready_n > 0:
				btn.disabled = false
				state = ("选址中" if battle.armed_build == str(uid) else "就绪") + " ×%d" % ready_n
				color = kit.COL_OK
			elif queue_index >= 0:
				btn.disabled = not _catalog_block_reason(str(uid)).is_empty()
				if queue_index == 0:
					var job: Dictionary = battle.current_structure_job(prod_tab)
					state = "%s %d%%" % ["已暂停" if bool(job.get("paused", false)) else _production_status("建造中", cost, null, str(job.id)), int(100.0 * float(job.elapsed) / maxf(0.01, float(job.time)))]
				else:
					state = "排队第 %d 项" % (queue_index + 1)
				color = kit.COL_WARN
			else:
				state = _catalog_block_reason(str(uid))
				btn.disabled = not state.is_empty()
				if btn.disabled:
					color = kit.COL_WARN
				elif prod_tab not in ["building", "defense"]:
					var producer = _factories.current()
					if is_instance_valid(producer) and producer.production_paused(str(uid)) and producer.production_head(str(uid)) >= 0 and str(producer.production[producer.production_head(str(uid))]) == str(uid):
						state = "已暂停 %d%% · 左键继续" % int(producer.queue_progress(str(uid)) * 100.0)
						color = kit.COL_WARN
					else:
						producer = _producer_for(str(uid))
					if state.is_empty() and is_instance_valid(producer) and producer != _factories.current():
						state = "由%s生产" % producer.display_name
						color = kit.RA_CYAN
			btn.get_child(0).modulate = Color.WHITE
			btn.get_child(0).get_child(0).modulate = Color(0.55, 0.55, 0.60, 1.0) if btn.disabled else Color.WHITE
			if is_instance_valid(label):
				label.set_meta("idle_caption", "%s · %.1fs" % [_fmt(cost), production_seconds(data)])
				label.text = state if state != "" else str(label.get_meta("idle_caption"))
				if str(uid) in MetaProgress.Academy.Stars.IDS:
					var trainer = _producer_for(str(uid))
					var seconds := production_seconds(data, trainer)
					var timing := "%.1f秒" % seconds
					if is_instance_valid(trainer) and not trainer.production.is_empty() and trainer.production[0] == uid:
						timing = "剩%.1f秒" % (seconds * (1.0 - trainer.queue_progress(str(uid))))
						state = _production_status("训练中", cost, trainer)
					elif is_instance_valid(trainer) and trainer.production.has(uid):
						state = "等待训练"
					label.text = "$%d · %s" % [int(cost), timing]
					if not state.is_empty(): label.text += "\n" + state.trim_prefix(str(data.get("name", "")))
				label.add_theme_color_override("font_color", color)
			var detail := str(btn.get_meta("base_tooltip", ""))
			detail += "\n预计 %.1fs（当前倍速，资金充足时）" % production_seconds(data)
			if not btn.disabled and state.begins_with("由"):
				detail += "\n点击后切换到该生产建筑，并加入其独立队列。"
			btn.tooltip_text = detail + ("\n[" + state + "]" if state != "" else "")
			if ready_n > 0:
				var cancel_hint := "右键处理同类排队（生产中先暂停，再次取消）" if queue_index >= 0 else "右键收回并退款"
				btn.tooltip_text = "%s\n[%s] 左键选址；%s" % [data.get("name", uid), state, cancel_hint]
			elif queue_index >= 0:
				var blocked := _catalog_block_reason(str(uid))
				var order_hint := "左键追加一项；" if battle.structure_reservations_enabled() else ""
				btn.tooltip_text = "%s\n[%s] %s生产中右键暂停；暂停后左键继续、右键取消；等待项右键直接取消。" % [data.get("name", uid), state, order_hint]
				if not blocked.is_empty():
					btn.tooltip_text += "\n无法追加：" + blocked
			if ready_n > 0 or queue_index >= 0:
				btn.tooltip_text += "\n" + EntityDescription.text(data)
			else:
				var guide: Dictionary = _unlock_guide(str(uid)) if str(uid) == _unlock_source else guidance.describe(str(uid))
				if not str(guide.detail).is_empty():
					btn.tooltip_text = "%s\n%s\n\n%s" % [_entity_name(str(uid)), guide.detail, btn.tooltip_text]
			if data.has("garrison_slots"):
				btn.tooltip_text = "驻军容量：%d 人\n%s" % [int(data.garrison_slots), btn.tooltip_text]
			if ready_n == 0 and not btn.disabled:
				var payment_hint := _production_payment_hint(str(uid))
				if not payment_hint.is_empty(): btn.tooltip_text += "\n" + payment_hint
	if not _unlock_source.is_empty() and is_instance_valid(_unlock_panel):
		_unlock_panel.present(_entity_name(_unlock_source), _unlock_guide(_unlock_source))
	_update_structure_status()
	_update_queue_host()
	_update_cameo_wipes()
	if is_instance_valid(_production_inspector) and _production_inspector.visible:
		_production_inspector.refresh()
	var p = _active_producer()
	if not is_instance_valid(p):
		return
	if _prod_bars.has("build"):
		var arr: Array = _prod_bars["build"]
		var bp: Control = arr[0]
		var bl: Label = arr[1]
		var f: float = clampf(p.build_elapsed / max(0.01, p.build_total), 0.0, 1.0)
		if is_instance_valid(bp):
			bp.set_state(f,0,_clock_phase("施工中",0.0))
		if is_instance_valid(bl):
			bl.text = "施工进度 %d%% · 剩 %ds" % [int(f * 100.0), int(ceil(BattleClock.real_seconds(maxf(0.0, p.build_total - p.build_elapsed) / maxf(0.01, p.construction_work_rate()))))]
	if _prod_bars.has("queue"):
		var arr2: Array = _prod_bars["queue"]
		var qp: Control = arr2[0]
		var ql: Label = arr2[1]
		var qf: float = clampf(p.queue_progress(_queue_uid(p)), 0.0, 1.0)
		if is_instance_valid(qp):
			var data := GameData.get_unit(_queue_uid(p)) if not _queue_uid(p).is_empty() else {}
			qp.set_state(qf,0,_clock_phase("生产中",float(data.get("cost",0)),p))
		if is_instance_valid(ql):
			ql.text = _queue_caption(p)

func _production_status(normal: String, cost: float, producer = null, structure_id := "") -> String:
	if get_tree().paused:
		return "已暂停"
	if not structure_id.is_empty():
		var reason: String = battle.structure_production_block_reason(structure_id)
		if not reason.is_empty(): return reason
	if is_instance_valid(producer) and producer.production_paused(_queue_uid(producer)): return "已暂停"
	if is_instance_valid(producer) and not producer.is_operational():
		if producer.under_construction or producer._buildup_play >= 0.0:
			return "等待展开"
		return "缺电停工" if producer.powered and battle.power_low else "暂时停工"
	if is_instance_valid(producer) and not _queue_uid(producer).is_empty():
		var uid := _queue_uid(producer)
		var roster_reason := GameData.unit_production_block_reason(uid, battle.allied_state, producer.side)
		if not roster_reason.is_empty():
			return roster_reason
		var tech_reason: String = producer.production_tech_block_reason(uid)
		if not tech_reason.is_empty():
			return tech_reason
		var country_reason: String = battle.country_block_reason(uid, producer.side)
		if not country_reason.is_empty():
			return country_reason
		if not producer.unit_prereqs_ok(uid):
			return "缺少前置：" + GameData.ra2_missing_prereq_names(uid, battle.owned_building_ids(producer.side), battle.allied_state, producer.side)
		if uid in ["ORCA", "BEAG"] and battle.aircraft_population(producer.side) > battle.aircraft_capacity(producer.side):
			return "停机位不足，等待空指部"
	if is_instance_valid(producer) and producer.queue_exit_blocked(_queue_uid(producer)):
		return "出口受阻"
	if cost > 0.0 and battle.funds <= 0.0:
		return "资金不足"
	if battle.power_build_factor() < 1.0:
		return "缺电减速"
	return normal

func _update_structure_status() -> void:
	if not is_instance_valid(_structure_status):
		return
	var job: Dictionary = battle.current_structure_job(prod_tab)
	var ready_n := 0
	for id in battle.struct_ready:
		if battle.structure_category(str(id)) == prod_tab:
			ready_n += int(battle.struct_ready[id])
	_structure_status.visible = true
	var line := "%s就绪 %d · 点击对应图标选址" % [_tab_label(prod_tab), ready_n] if ready_n > 0 else "空闲 · 点击图标开始建造"
	if not job.is_empty():
		var state := _production_status("建造中", float(job.cost), null, str(job.id))
		if bool(job.get("paused", false)): state = "已暂停"
		if ready_n > 0 and not battle.structure_reservations_enabled():
			state = "等待放置已就绪建筑"
		line = "%s · %s · %d%%" % [_entity_name(str(job.id)), state, int(100.0 * float(job.elapsed) / maxf(0.01, float(job.time)))]
		if state in ["建造中", "缺电减速"]:
			line += " · 剩 %ds" % int(ceil(BattleClock.real_seconds(maxf(0.0, float(job.time) - float(job.elapsed)) / maxf(0.01, battle.structure_work_rate("ally", str(job.id))))))
		line += "\n等待 %d 项 · 就绪 %d" % [maxi(0, battle.structure_jobs(prod_tab).size() - 1), ready_n]
	_structure_status.text = "%s独立队列 · 可与%s同时建造\n" % [_tab_label(prod_tab), "建筑" if prod_tab == "defense" else "防御"] + line
	_structure_status.text += ("\n建筑预约：已解锁（含就绪上限 %d；局外可升级）" % battle.production_technology.structure_capacity("ally")) if battle.structure_reservations_enabled() else "\n建筑预约：未解锁 · 当前类别仅建造一项，放置后继续"


## 红警2 式建造进度擦除：建筑 = 正在施工的那张卡；单位 = 队列头那张卡（+ 队列数量角标）。
func _clock_phase(normal: String, cost: float, producer = null, structure_id := "") -> String:
	var status := _production_status(normal,cost,producer,structure_id)
	if get_tree().paused or battle.paused or status == "已暂停": return "paused"
	return "producing" if status in [normal,"缺电减速"] else "blocked"

func _update_cameo_wipes() -> void:
	var states: Dictionary = {}
	if prod_tab in ["building","defense"]:
		var jobs: Array = battle.structure_jobs(prod_tab)
		for i in jobs.size():
			var job: Dictionary = jobs[i]
			var id := str(job.id)
			if not states.has(id):
				var phase := "waiting"
				var progress := 0.0
				if i == 0:
					phase = "paused" if bool(job.get("paused",false)) else _clock_phase("建造中",float(job.cost),null,id)
					progress=clampf(float(job.elapsed)/maxf(0.001,float(job.time)),0.0,1.0)
					if not battle.structure_reservations_enabled():
						for ready_id in battle.struct_ready:
							if int(battle.struct_ready[ready_id])>0 and battle.structure_category(str(ready_id))==prod_tab: phase="blocked"
				states[id]=[progress,0,phase]
			states[id][1]+=1
		for id in battle.struct_ready:
			if not states.has(str(id)) and int(battle.struct_ready[id])>0:
				states[str(id)]=[1.0,int(battle.struct_ready[id]),"ready"]
	else:
		var producer = _active_producer()
		if is_instance_valid(producer) and not producer.under_construction:
			var runs: Array = _queue_runs(producer)
			for i in runs.size():
				var id := str(runs[i].uid)
				if not states.has(id):
					var cost := float(GameData.get_unit(id).get("cost",0))
					states[id]=[producer.queue_progress(id) if i==0 else 0.0,0,_clock_phase("生产中",cost,producer) if i==0 else "waiting"]
				states[id][1]+=int(runs[i].n)
	for id in _prod_wipes:
		var wipe = _prod_wipes[id]
		if not is_instance_valid(wipe): continue
		var state: Array = states.get(str(id),[-1.0,0,"idle"])
		wipe.set_state(float(state[0]),int(state[1]),str(state[2]))

func _sync_repair_mode() -> void:
	if battle == null or not building_action_buttons.has("repair_all"): return
	var button: Button = building_action_buttons.repair_all
	if battle.can_repair_all() and battle.production_technology.is_unlocked("repair_auto", "ally"):
		var mode := int(battle.allied_state.get("area_repair", 0))
		button.text = ["维修待命", "本轮抢修", "自动抢修"][mode]
		button.tooltip_text = ["点击维修当前受损建筑。全满血时直接开启自动抢修。", "本轮修完后待命。点击切换自动抢修。", "持续维修新受损建筑。点击停止自动抢修，手动维修继续。"][mode]
	else: button.text = "一键维修"

func refresh_repair_all() -> void:
	var auto_available := preload("res://scripts/units/auto_w.gd").available(battle)
	auto_w_controls.show()
	for child in auto_w_controls.get_children():
		if child is Button:
			child.disabled = not auto_available
			if not child.has_meta("available_hint"): child.set_meta("available_hint", child.tooltip_text)
			child.tooltip_text = str(child.get_meta("available_hint")) if auto_available else ("经典模式不启用 Auto W。" if not BattleRequest.extensions_enabled() else "需要局外科技：Auto W。研究后在新对局生效。")
			if not auto_available: child.set_pressed_no_signal(false)
	if auto_available:
		preload("res://scripts/units/auto_w.gd").refresh_global_selection(auto_w_controls, battle)
	var repair_all: Button = building_action_buttons.repair_all
	repair_all.show()
	repair_all.disabled = not battle.can_repair_all()
	repair_all.tooltip_text = "经典模式不启用一键维修。" if not BattleRequest.extensions_enabled() else "需要局外科技：一键维修（主菜单 → 科技树）。研究后在新对局生效。" if repair_all.disabled else "立即开始维修所有受损且可维修的己方建筑。按实际修复量扣费，缺钱时等待到账。"

	_sync_repair_mode()

func _refresh_production() -> void:
	if battle == null or prod_box == null:
		return
	_recipe_button.visible = prod_tab in ["infantry", "vehicle", "air", "naval"] and BattleRequest.extensions_enabled() and battle.production_technology.is_unlocked("production_recipes", "ally")
	_sync_plan_button(_deck_orders_button, battle.allied_state.get("opening_orders_pending", []))
	if deck_tabs != null and _deck_faction != battle.roster_faction():
		_clear_nodes(deck_tabs)
		_add_prod_tabs()
	if is_instance_valid(_recipe_window) and not _recipe_window.is_queued_for_deletion():
		_recipe_window.sync_from_deck()
	_update_ready_tabs(0.0)
	# 只在“面板构成”变化时整体重建；否则原地刷新。
	# 此前 _process 在生产中每 0.08s 重建一次按钮，会把“按下中”的按钮销毁 → 连续建造丢点击。
	var sig := _prod_signature()
	if sig == _prod_sig and prod_box.get_child_count() > 0:
		_update_production_live()
		return
	_prod_sig = sig
	if is_instance_valid(_production_inspector): _production_inspector.clear()
	# 重建会移除原按钮，旧按住手势不能转移到新页或另一座工厂。
	_hold_uid = ""
	_hold_fired = false
	_prod_buttons.clear()
	_prod_bars.clear()
	_prod_locked.clear()
	_prod_status_labels.clear()
	_structure_status = null
	_prod_wipes.clear()
	_clear_nodes(prod_box)
	_factories.build(prod_box)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	prod_box.add_child(grid)

	if prod_tab == "building" or prod_tab == "defense":
		# —— 建筑 / 防御 页：RA3/RA2 流程（侧栏花钱建造 → 就绪 → 点击图标选址）——
		var cat := _building_catalog()
		if cat.is_empty():
			prod_box.add_child(kit.make_label("暂无可建造项目", 13, kit.COL_DIM))
		var job: Dictionary = battle.current_structure_job(prod_tab) if battle.has_method("current_structure_job") else {}
		for bid in cat:
			var sid := str(bid)
			var bd := GameData.get_building(sid)
			var bcost := float(bd.get("cost", 0))
			var st := _build_state(sid)
			var ok: bool = st.get("ok", true) == true
			var ready_n := int(battle.struct_ready.get(sid, 0)) if battle.get("struct_ready") != null else 0
			var building_this := (not job.is_empty()) and str(job.get("id", "")) == sid
			var btn: Button = _make_cameo(bd, bcost, _prod_buttons.size(), ok or ready_n > 0)
			if ready_n > 0:
				btn.tooltip_text = "%s\n[已就绪] 左键选址放置，右键取消" % str(bd.get("name", sid))
				btn.modulate = Color(0.75, 1.0, 0.8)
			elif building_this:
				var pct := int(clampf(float(job.get("elapsed", 0.0)) / maxf(0.01, float(job.get("time", 1.0))), 0.0, 1.0) * 100.0)
				var instruction := "已暂停，左键继续、右键取消" if battle.structure_is_paused(sid) else "建造中，右键暂停"
				btn.tooltip_text = "%s\n%d%% · %s" % [str(bd.get("name", sid)), pct, instruction]
				btn.modulate = Color(0.65, 0.85, 1.0)
				btn.disabled = not _catalog_block_reason(sid).is_empty()
			else:
				btn.tooltip_text = "%s\n造价 %d" % [EntityDescription.text(bd), int(bcost)]
				if ok:
					btn.disabled = not _catalog_block_reason(sid).is_empty()
				else:
					_prod_locked[sid] = str(st.get("reason", ""))
			if ready_n > 0 or building_this:
				btn.tooltip_text += "\n" + EntityDescription.text(bd)
			btn.pressed.connect(func() -> void: _start_build(sid))
			btn.gui_input.connect(func(ev) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and btn.disabled:
					_explain_disabled_cameo(sid)
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					_cancel_build(sid))
			grid.add_child(btn)
			_prod_buttons[sid] = btn
			btn.set_meta("base_tooltip", btn.tooltip_text)
	else:
		# —— 步兵 / 载具 / 空军 / 海军 页：可生产单位（红警2 式自动路由到对应建筑）——
		var ucat: Array = []
		for uid in _unit_catalog():
			if _cat_match(GameData.get_unit(str(uid))):
				ucat.append(str(uid))
		if ucat.is_empty():
			var hint := "暂无可生产单位（需先建成兵营 / 工厂）"
			match prod_tab:
				"air":
					hint = "苏联飞行器由战车工厂生产" if battle.roster_faction() == "soviet" else "战机由空指部生产"
				"naval":
					hint = "舰艇由造船厂生产，船厂需建在水面"
					if not GameData.mission_tech_block_reason(battle.roster_id("GAYARD", "ally")).is_empty():
						hint = "本关科技限制了造船厂建造"
			if preload("res://scripts/expedition/rules.gd").active() and is_instance_valid(_factories.current()):
				hint = "当前工厂暂无可生产兵种"
			prod_box.add_child(kit.make_label(hint, 13, kit.COL_DIM))
		for uid in ucat:
			var ud := GameData.get_unit(str(uid))
			var cost: float = battle.production_price(ud, "ally")
			var ust := _unit_state(str(uid))
			var uok: bool = bool(ust.get("ok", true))
			var ubtn: Button = _make_cameo(ud, cost, _prod_buttons.size(), uok)
			if not uok:
				_prod_locked[str(uid)] = str(ust.get("reason", ""))
			ubtn.tooltip_text = "%s\n克制：%s\n造价 %d" % [
				EntityDescription.text(ud), CombatMath.describe_weapon(ud.get("weapon", {})), int(cost)
			]
			ubtn.tooltip_text += "\n单击：生产 1 个；Shift+单击 / 长按：生产 5 个。\n生产中右键暂停；暂停后左键继续、右键取消 1 个同类订单。\n等待项右键直接取消；下方队列图标同样适用。取消只退还已扣资金。"
			ubtn.pressed.connect(func() -> void:
				if _hold_fired:
					_hold_fired = false
					return
				_queue(str(uid), HOLD_BATCH if Input.is_key_pressed(KEY_SHIFT) else 1))
			ubtn.button_down.connect(func() -> void: _begin_prod_hold(str(uid)))
			ubtn.button_up.connect(func() -> void: _end_prod_hold(str(uid)))
			ubtn.gui_input.connect(func(ev) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and ubtn.disabled:
					_explain_disabled_cameo(str(uid))
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					ubtn.accept_event()
					_cancel_unit(str(uid)))
			grid.add_child(ubtn)
			_prod_buttons[str(uid)] = ubtn
			ubtn.set_meta("base_tooltip", ubtn.tooltip_text)

	# 页脚：活跃生产建筑的施工 / 队列（常驻容器，队列变化时原地重建图标条）
	prod_box.add_child(kit.divider())
	if prod_tab in ["building", "defense"]:
		_structure_status = kit.make_label("", 12, kit.COL_WARN)
		_structure_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prod_box.add_child(_structure_status)
	_queue_host = VBoxContainer.new()
	_queue_host.add_theme_constant_override("separation", 3)
	prod_box.add_child(_queue_host)
	_queue_shape_sig = ""
	_update_queue_host()
	_update_production_live()

func _start_build(bid: String) -> void:
	if battle == null:
		return
	# 已付费的就绪建筑可直接选址；追加订单检查解锁与容量，费用随进度扣除。
	if int(battle.struct_ready.get(bid, 0)) == 0:
		var reason := _catalog_block_reason(bid)
		if not reason.is_empty():
			_show_unlock_panel(bid)
			Events.emit_message("%s：%s" % [_entity_name(bid), _with_unlock_hint(bid, reason)], kit.COL_WARN)
			return
	# RA3 式流程：已在侧栏花钱建造→就绪→点击图标选址放置
	if battle.has_method("request_structure"):
		battle.request_structure(bid)
		_refresh_build_menu()
		_refresh_production()
	elif battle.has_method("set_build_mode"):
		battle.set_build_mode(bid)

func _cancel_build(bid: String) -> void:
	if battle != null and battle.has_method("cancel_structure"):
		battle.structure_right_click(bid)
		_refresh_build_menu()
		_refresh_production()

func _cancel_unit(uid: String) -> void:
	# Cancellation belongs to the displayed factory, even when production is
	# blocked by money, prerequisites or queue capacity. Never reroute it.
	var p = _factories.current()
	if not is_instance_valid(p):
		return
	p.production_right_click(uid)
	_refresh_production()
	_refresh_top()

func _queue(uid: String, n: int = 1) -> void:
	var current = _factories.current()
	if is_instance_valid(current) and current.resume_production(uid):
		return
	var p = _producer_for(uid)
	if p == null:
		_show_unlock_panel(uid)
		Events.emit_message("%s：%s" % [_entity_name(uid), _with_unlock_hint(uid, _unit_state(uid).get("reason", "缺少生产建筑"))], kit.COL_WARN)
		return
	var blocked: String = p.queue_block_reason(uid)
	if not blocked.is_empty():
		_show_unlock_panel(uid)
		Events.emit_message("%s：%s" % [_entity_name(uid), _with_unlock_hint(uid, blocked)], kit.COL_WARN)
		_refresh_production()
		return
	if prod_tab not in ["building", "defense"] and _cat_match(GameData.get_unit(uid)) and p != _factories.current():
		_factories.remember(p, prod_tab)
		_unlock_focus = ""
		Events.emit_message("已切换至%s %d · 生产%s" % [p.display_name, _factories.number_for(p), _entity_name(uid)], kit.RA_CYAN)
	var got: int = p.enqueue_many(uid, n)
	if got < n:
		var reason: String = p.queue_block_reason(uid)
		if reason.is_empty():
			reason = "生产状态已变化，请重试"
		var partial := "已加入 %d/%d 个；" % [got, n] if got > 0 else ""
		Events.emit_message("%s：%s%s" % [_entity_name(uid), partial, reason], kit.COL_WARN)
	# Accepted orders already refreshed the selected factory through the queue signal.
	if got == 0:
		_refresh_production()
	_refresh_top()

## —— 长按连造（Shift 点击 / 长按一次排 5 个）——
func _begin_prod_hold(uid: String) -> void:
	_hold_uid = uid
	_hold_t = 0.0
	_hold_fired = false

func _end_prod_hold(uid: String) -> void:
	if _hold_uid == uid:
		_hold_uid = ""

func _tick_prod_hold(delta: float) -> void:
	if _hold_uid == "" or _hold_fired:
		return
	_hold_t += delta
	if _hold_t >= HOLD_TIME:
		_hold_fired = true
		var uid := _hold_uid
		_hold_uid = ""
		_queue(uid, HOLD_BATCH)

## —— 页脚队列：图标网格（对齐红警2 SidebarCard：图标 + 数量角标）——
func _queue_shape() -> String:
	var p = _active_producer()
	if not is_instance_valid(p):
		return "none"
	if p.under_construction:
		return "build:%d" % p.get_instance_id()
	var s: String = "q:%d:%s" % [p.get_instance_id(),prod_tab]
	for x in (p.production as Array):
		s += "|" + str(x)
	return s

func _update_queue_host() -> void:
	if _queue_host == null or not is_instance_valid(_queue_host):
		return
	_queue_host.visible = prod_tab not in ["building", "defense"]
	if not _queue_host.visible:
		return
	var shape := _queue_shape()
	if shape == _queue_shape_sig:
		return
	_queue_shape_sig = shape
	_prod_bars.erase("build")
	_prod_bars.erase("queue")
	_clear_nodes(_queue_host)
	_build_queue_host(_active_producer())

func _build_queue_host(p) -> void:
	if _queue_host == null or not is_instance_valid(_queue_host):
		return
	if not is_instance_valid(p):
		_queue_host.add_child(kit.make_label("未选中生产建筑 · 点建筑或直接点上方项目自动路由", 12, kit.COL_DIM))
		return
	if p.under_construction:
		_queue_host.add_child(kit.make_label("%s · 施工中" % p.display_name, 13, kit.COL_WARN))
		var f: float = clampf(p.build_elapsed / max(0.01, p.build_total), 0.0, 1.0)
		_queue_host.add_child(_make_build_bar(f, "施工进度 %d%%" % int(f * 100.0), kit.COL_WARN, "build"))
		return
	if _queue_uid(p).is_empty():
		_queue_host.add_child(kit.make_label("%s · 空闲（点上方项目开始生产）" % p.display_name, 12, kit.COL_DIM))
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(kit.make_label("队列 %d / %d" % [_queue_count(p), p.queue_capacity()], 12, kit.COL_OK))
	head.add_child(kit.make_label("右键暂停／取消", 11, kit.COL_DIM))
	_queue_host.add_child(head)
	var strip := HBoxContainer.new()
	strip.name = "queue_strip"
	strip.add_theme_constant_override("separation", 4)
	var runs:=_queue_runs(p)
	if runs.size()>9:
		var scroll:=ScrollContainer.new()
		scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size.y=64
		_queue_host.add_child(scroll)
		scroll.add_child(strip)
	else:
		_queue_host.add_child(strip)
	for run in runs:
		strip.add_child(_make_queue_tile(p, str(run["uid"]), int(run["n"]), int(run["start"])))
	_queue_host.add_child(_make_build_bar(p.queue_progress(_queue_uid(p)), _queue_caption(p), kit.RA_CYAN, "queue"))

## Estimate actual elapsed seconds using the same rates as the production consumer.
func production_seconds(data: Dictionary, producer = null) -> float:
	var duration := GameData.ra2_build_time(data)
	var id := str(data.get("id", ""))
	if GameData.is_building(id):
		duration /= maxf(0.01, battle.structure_work_rate("ally", id))
	else:
		if not is_instance_valid(producer): producer = _producer_for(id)
		if is_instance_valid(producer):
			duration /= maxf(0.1, producer.build_speed)
			duration /= maxf(0.01, producer.production_work_rate(id))
		else:
			duration = GM.FAST_BUILD_SECONDS if GM.no_build_time else duration / BattleClock.production_scale(data)
	return BattleClock.real_seconds(duration)

func _cargo_caption(miner) -> String:
	return "%.1f / %d · $%d" % [miner.cargo, int(miner.cargo_cap), int(round(miner.cargo_value()))]

func _queue_uid(p) -> String:
	return p.production_for_category(prod_tab) if is_instance_valid(p) else ""

func _queue_count(p) -> int:
	var count := 0
	for run in _queue_runs(p): count += int(run.n)
	return count

func _queue_caption(p) -> String:
	if not is_instance_valid(p) or _queue_uid(p).is_empty():
		return ""
	var data := GameData.get_unit(_queue_uid(p))
	var state := _production_status("生产中", float(data.get("cost", 0)), p)
	var text := "%s %s · %d%%" % [state, data.get("name", _queue_uid(p)), int(clampf(p.queue_progress(_queue_uid(p)), 0.0, 1.0) * 100.0)]
	if state in ["生产中", "缺电减速"]:
		var duration := GameData.ra2_build_time(data) / maxf(0.1, p.build_speed)
		var remaining := maxf(0.0, duration - p.queue_elapsed(_queue_uid(p))) / maxf(0.01, p.production_work_rate(_queue_uid(p)))
		text += " · 剩 %ds" % int(ceil(BattleClock.real_seconds(remaining)))
		if not p.is_refinery() and battle.factory_speed_factor(p.side, _queue_uid(p)) > 1.0:
			text += " · 多厂加速"
	return text

## 把队列拆成「连续同型」的段（红警2 侧栏按同类合并并显示数量）
func _queue_runs(p) -> Array:
	var runs: Array = []
	if not is_instance_valid(p):
		return runs
	for i in range((p.production as Array).size()):
		var uid := str(p.production[i])
		if p.Parallel.enabled(p) and not _cat_match(GameData.get_unit(uid)): continue
		if not runs.is_empty() and str(runs[runs.size() - 1]["uid"]) == uid and int(runs[-1].start) + int(runs[-1].n) == i:
			runs[runs.size() - 1]["n"] = int(runs[runs.size() - 1]["n"]) + 1
		else:
			runs.append({ "uid": uid, "n": 1, "start": i })
	return runs

## 队首右键先暂停，左键继续；暂停后或等待项右键取消一个。
func _make_queue_tile(p, uid: String, n: int, start: int) -> Control:
	var ud := GameData.get_unit(uid)
	var wrap: Control = kit.ra_panel(kit.RA_TILE, kit.RA_EDGE, 3, 3)
	wrap.custom_minimum_size = Vector2(46, 46)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_to_group("rmb_cancel")
	wrap.tooltip_text = "%s ×%d\n生产中：右键暂停；已暂停：左键继续、右键取消 1 个。\n等待项：右键取消。" % [str(ud.get("name", uid)), n]
	if is_instance_valid(_production_inspector):
		_production_inspector.bind_hint(wrap, "%s ×%d" % [str(ud.get("name", uid)), n], wrap.tooltip_text, ud)
	var ic = UnitIconScript.new()
	var fcol := str(ud.get("faction", "allied"))
	if fcol.is_empty() and is_instance_valid(p):
		fcol = str(p.faction)
	ic.setup(ud, _faction_color_of(fcol), n, 1.0, true)
	ic.animate = false
	ic.custom_minimum_size = Vector2(40, 40)
	wrap.add_child(ic)
	var idx: int = start + n - 1
	wrap.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				wrap.accept_event()
				if is_instance_valid(p):
					p.production_right_click(uid, start if start == p.production_head(uid) and not p.production_paused(uid) else idx)
					_refresh_production()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				wrap.accept_event()
				if is_instance_valid(p) and start == p.production_head(uid) and p.resume_production(uid):
					_refresh_production())
	return wrap

# ------------------------------------------------------------------ 建造菜单

func _refresh_build_menu() -> void:
	_clear_nodes(build_box)
	build_box.add_child(kit.make_label("建造菜单（点击后在战场放置）", 15, kit.COL_ACCENT_2))
	# Step C 阶段2：引擎自创建筑已删除，建造菜单直接取用建筑目录（RA2 建筑在内，hq 类自然过滤）
	var list := _building_catalog()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	build_box.add_child(grid)
	for bid in list:
		var bd := GameData.get_building(bid)
		var cost := float(bd.get("cost", 0))
		var btn: Button = kit.ra_button(13, 48)
		btn.text = "%s\n%s" % [str(bd.get("name", bid)), _fmt(cost)]
		btn.custom_minimum_size = Vector2(158, 50)
		btn.tooltip_text = EntityDescription.text(bd)
		btn.pressed.connect(func():
			if battle.has_method("request_structure"):
				battle.request_structure(bid)
			else:
				battle.set_build_mode(bid)
			build_panel.visible = false)
		btn.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_build(bid))
		grid.add_child(btn)
	var hint := kit.make_label("在己方建筑或盟友建造场附近放置，避开单位、矿点和障碍；红色提示禁止原因。右键取消。", 12, kit.COL_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_box.add_child(hint)

# ------------------------------------------------------------------ 控制

# 单位与战场热键；生产栏不绑定键盘。
#   H 回基地  D 倒退攻击 · J 部署  K 维修  L 出售  M/N 上/下一个单位  F 跟随  A 攻击  Y 采集
#   数字 选中编队 / Ctrl+数字 编组 / Alt+数字 聚焦   Esc 选项/取消  Space 暂停  Tab 倍速
# Independent Yuri-style clockwise cameo clock; ignores all mouse input.
const CameoWipe = preload("res://scripts/ui/production_clock.gd")

func _make_cameo(d: Dictionary, cost: float, _idx: int, avail: bool = true) -> Button:
	var btn: Button = kit.ra_button(13, 70)
	btn.set_script(ProductionTooltipScript)
	btn.text = ""
	btn.custom_minimum_size = Vector2(140, 70)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = false
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5.0
	row.offset_right = -5.0
	row.offset_top = 3.0
	row.offset_bottom = -3.0
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	var ic = UnitIconScript.new()
	ic.setup(d, _faction_color_of(str(d.get("faction", "allied"))), 1, 1.0, true)
	ic.show_status = false
	ic.animate = false
	ic.custom_minimum_size = Vector2(46, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var caption := str(d.get("name", "?"))
	if d.has("garrison_slots"): caption += " · %d人" % int(d.garrison_slots)
	var nm := kit.make_label(caption, 12, kit.RA_TEXT)
	nm.clip_text = true
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.custom_minimum_size = Vector2(80, 28)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var _bt: float = production_seconds(d)
	var cs := kit.make_label(_fmt(cost) if _bt <= 0.0 else "%s · %.1fs" % [_fmt(cost), _bt], 11, kit.COL_GOLD)
	cs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cs.clip_text = true
	cs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cs.max_lines_visible = 2
	cs.custom_minimum_size = Vector2(80, 26)
	cs.set_meta("idle_caption", cs.text)
	_prod_status_labels[str(d.get("id", ""))] = cs
	if is_instance_valid(_production_inspector):
		btn.set_meta("inspector_status", cs)
		_production_inspector.bind(btn, str(d.get("name", d.get("id", ""))), d)
	col.add_child(cs)
	# 红警2 侧栏卡片的「建造进度擦除」+ 队列数量角标，随队列状态实时刷新
	var wipe := CameoWipe.new()
	wipe.name = "CameoWipe"
	wipe.icon = ic
	wipe.faction_id = str(d.get("faction", "allied"))
	btn.add_child(wipe)
	wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prod_wipes[str(d.get("id", ""))] = wipe
	if not avail:
		# 不可建造时仅压暗图标，保留名称与具体原因的文字对比度。
		btn.disabled = true
		ic.modulate = Color(0.55, 0.55, 0.60, 1.0)
	return btn

func _owned_building_ids() -> Array:
	return battle.owned_building_ids()

func _ra2_gate(ids: Array) -> Array:
	if not GameData.ra2_loaded:
		return ids
	var owned := _owned_building_ids()
	var keep: Array = []
	for id in ids:
		var s := str(id)
		if not GameData.is_ra2(s):
			# RA2 阵营启用后，引擎自带盟军单位不再出现在甲板
			if str((GameData.get_unit(s) as Dictionary).get("faction", "")) == battle.roster_faction():
				continue
			keep.append(id)
			continue
		if GameData.ra2_prereq_ok(s, owned):
			keep.append(id)
	return keep

func _input(event: InputEvent) -> void:
	if _load_resume_press.is_finite() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_load_resume_press = Vector2.INF
	if Hotkeys.modal_count>0:return
	if is_instance_valid(save_panel) and save_panel.root.visible: return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		_last_group_digit = 0
		return
	var kc: int = event.keycode
	var ctrl: bool = event.ctrl_pressed
	var shift: bool = event.shift_pressed
	var alt: bool = event.alt_pressed
	if kc == KEY_SPACE and shift and not ctrl and not alt and not event.meta_pressed:
		if is_instance_valid(battle):
			battle.show_all_health = not battle.show_all_health
			battle.hp_overlay.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	var gid := _group_digit(kc)
	if gid == 0 or ctrl or alt or shift:
		_last_group_digit = 0
	# —— 控制组（红警2 对齐：Ctrl+数字编组 / Alt+数字聚焦 / 连按两下数字居中）——
	if gid > 0 and not shift:
		if ctrl:
			_cmd("group_set:%d" % gid)
		elif alt:
			_cmd("group_focus:%d" % gid)
		else:
			var now := Time.get_ticks_msec()
			var double_tap := _last_group_digit == gid and now - _last_group_tap_ms <= 400
			_last_group_digit = 0 if double_tap else gid
			_last_group_tap_ms = now
			_cmd("group_sel:%d" % gid)
			if double_tap:
				_cmd("group_focus:%d" % gid)
		return
	if not (ctrl or shift or alt or event.meta_pressed) and is_instance_valid(yuriko_bar) and yuriko_bar.visible and battle.world_input_enabled() and yuriko_bar.hotkey(kc):
		get_viewport().set_input_as_handled()
		return
	var translated:=Hotkeys.translate(event)
	if translated==null:return
	kc=translated.keycode
	match kc:
		KEY_F8:
			if is_instance_valid(battle):
				var result := _performance_snapshot.capture(battle)
				Events.emit_message(result.message, kit.COL_OK if result.ok else kit.COL_WARN)
			get_viewport().set_input_as_handled()
		KEY_F5:
			if battle != null:
				var result: Dictionary = BattleSaves.save_slot(battle, "quick")
				Events.emit_message(result.message, kit.COL_OK if result.ok else kit.COL_WARN)
			get_viewport().set_input_as_handled()
		KEY_F9:
			_open_saves()
			get_viewport().set_input_as_handled()
		KEY_PERIOD:
			if not shift and is_instance_valid(minimap) and minimap.jump_to_radar_event():
				get_viewport().set_input_as_handled()
		KEY_SPACE:
			_toggle_pause()
		KEY_TAB:
			_cycle_speed()
		KEY_G:
			if ctrl:
				_toggle_gm()
			else:
				_cmd("guard")
		KEY_F:
			if ctrl:
				if battle != null and battle.has_method("cycle_formation"):
					battle.cycle_formation()
			else:
				_cmd("follow")
		# 技能直接按键释放，Shift 组合兼容旧习惯；不再切生产页签。
		KEY_Q, KEY_W, KEY_E:
			if not ctrl and not alt and not event.meta_pressed:
				_cast_ability([KEY_Q, KEY_W, KEY_E].find(kc))
				get_viewport().set_input_as_handled()
		# 红警2 指令热键
		KEY_S:
			_cmd("stop")
		KEY_X:
			_cmd("attack_move")
		KEY_V:
			_cmd("aggressive")
			get_viewport().set_input_as_handled()
		KEY_T:
			_cmd("same")
		KEY_F4:
			if not ctrl and not shift and not alt and battle != null and battle.world_input_enabled():
				_cmd("exclude")
				get_viewport().set_input_as_handled()
		KEY_F3:
			if not ctrl and not shift and not alt and battle != null and battle.world_input_enabled():
				_cmd("excluded")
				get_viewport().set_input_as_handled()
		KEY_F2:
			if not ctrl and not shift and not alt and battle != null and battle.world_input_enabled():
				_cmd("selectall")
				get_viewport().set_input_as_handled()
		KEY_P:
			_cmd("selectall")
		KEY_H:
			_cmd("centerbase")
		KEY_D:
			_cmd("reverse_attack")
		KEY_J:
			_cmd("deploy")
		KEY_K:
			_cmd("repair")
		KEY_L:
			_cmd("sell")
		KEY_M:
			_cmd("prev")
		KEY_N:
			_cmd("next")
		KEY_A:
			_cmd("attack")
		KEY_Y:
			_cmd("harvest")
		KEY_C:
			_cmd("center")
		KEY_MINUS:
			if battle != null:
				battle.set_view_k(Iso.K - 0.02)
		KEY_EQUAL:
			if battle != null:
				battle.set_view_k(Iso.K + 0.02)
		KEY_BACKSLASH:
			if battle != null:
				battle.toggle_view_mirror()
		KEY_APOSTROPHE:
			if battle != null:
				battle.toggle_view_yaw()
		KEY_ESCAPE:
			if not armed_escape():
				_set_topbar_visible(not _topbar.visible)
			get_viewport().set_input_as_handled()

# 数字键 1-9,0 → 编队号 1-10（0 归为 10）
func _group_digit(kc: int) -> int:
	if kc >= KEY_1 and kc <= KEY_9:
		return kc - KEY_0
	if kc == KEY_0:
		return 10
	return 0

func armed_escape() -> bool:
	if is_instance_valid(battle) and battle.formation_gesture.held:
		battle.cancel_pointer_gestures()
		get_viewport().set_input_as_handled()
		return true
	if settings_panel != null and settings_panel.visible:
		settings_panel.hide()
		return true
	if battle != null and is_instance_valid(battle) and battle.cast_slot >= 0:
		battle.cancel_cast()
		return true
	if build_panel.visible:
		build_panel.visible = false
		return true
	if gm_console != null and is_instance_valid(gm_console) and gm_console.visible:
		gm_console.visible = false
		return true
	if battle != null and battle.command_mode != "":
		battle.arm_command("")
		return true
	if battle != null and battle.armed_build != "":
		battle.armed_build = ""
		return true
	return false

func pause_after_load() -> void:
	battle.cancel_pointer_gestures()
	battle.paused = true
	get_tree().paused = true
	pause_btn.text = "继续"
	_load_resume_press = Vector2.INF
	var key := Hotkeys.label("pause")
	_load_pause_hint.text = "已暂停 · 点击战场空白处或按%s继续" % ("空格" if key == "Space" else " " + key + " ")
	_load_pause_hint.show()
	set_process_unhandled_input(true)
	Events.emit_message(_load_pause_hint.text, kit.COL_WARN)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT): return
	if not is_instance_valid(_load_pause_hint) or not _load_pause_hint.visible: return
	if not get_tree().paused or not battle.paused or battle.ended or Hotkeys.modal_count > 0: return
	if is_instance_valid(save_panel) and save_panel.root.visible: return
	if covers_world_pixel(event.position) or get_viewport().gui_get_hovered_control() != null: return
	var point: Vector2 = battle.get_canvas_transform().affine_inverse() * event.position
	if battle._pick_at(point, false) != null or battle._pick_node_at(point, "resource_nodes") != null: return
	if event.pressed:
		_load_resume_press = event.position
	elif _load_resume_press.distance_to(event.position) < battle.SELECTION_CLICK_SLOP:
		_toggle_pause()
	get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if battle == null or battle.ended:
		return
	var p := not get_tree().paused
	battle.cancel_pointer_gestures()
	get_tree().paused = p
	battle.paused = p
	_load_pause_hint.hide()
	_load_resume_press = Vector2.INF
	set_process_unhandled_input(false)
	pause_btn.text = "继续" if p else "暂停"
	Events.emit_message("已暂停" if p else "继续", kit.COL_WARN)

func _open_saves() -> void:
	if not is_instance_valid(save_panel):
		save_panel = preload("res://scripts/ui/save_panel.gd").new()
		save_panel.battle = battle
		add_child(save_panel)
	save_panel.open()

func _cycle_speed() -> void:
	_speed_index = (SPEEDS.find(GM.fast_forward) + 1) % SPEEDS.size()
	var s: float = SPEEDS[_speed_index]
	BattleClock.set_speed(s)
	speed_btn.text = "倍速 ×%d" % int(s)

func _toggle_gm() -> void:
	if gm_console == null or not is_instance_valid(gm_console):
		gm_console = GMConsoleScript.new()
		gm_console.battle_hud = self
		add_child(gm_console)
		gm_console.visible = false
	gm_console.visible = not gm_console.visible
	if gm_console.visible:
		gm_console.refresh()

func _leave() -> void:
	if preload("res://scripts/expedition/rules.gd").active() and battle != null and not battle.ended:
		if expedition_save_and_leave.is_valid():
			expedition_save_and_leave.call()
		else:
			Events.emit_message("无法保存远征，仍停留在战场", Color.TOMATO)
		return
	if battle != null and not battle.ended:
		battle.end_battle(false)
	get_tree().paused = false
	BattleClock.leave_battle()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn" if BattleRequest.skirmish else "res://scenes/campaign_command.tscn")

# ================================================================== 单位技能栏（红警3 式）
# 固定 Q 固有主动、W 装配主动、被动、E 特殊操作；空槽不挪位。

var yuriko_command
var yuriko_bar

func _build_ability_bar(root: Control) -> void:
	if yuriko_command!=null:
		yuriko_bar=preload("res://scripts/ui/yuriko_bar.gd").new()
		yuriko_bar.command=yuriko_command
		yuriko_command.strip=yuriko_bar
		root.add_child(yuriko_bar)
	ability_panel = kit.ra_panel(kit.RA_PANEL_2, kit.RA_EDGE, 4, 6)
	# 技能栏堆叠在右下角「单位显示」的正上方（同一右下载荷区）
	ability_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ability_panel.offset_left = -640.0
	ability_panel.offset_right = -8.0
	ability_panel.offset_top = -150.0
	ability_panel.offset_bottom = -98.0
	ability_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ability_panel.visible = false
	root.add_child(ability_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	ability_panel.add_child(scroll)
	scroll.add_child(hb)
	ability_title = kit.ra_label("", 12, kit.RA_CYAN)
	hb.add_child(ability_title)
	ability_box = GridContainer.new()
	ability_box.columns = 32
	ability_box.add_theme_constant_override("h_separation", 3)
	ability_box.add_theme_constant_override("v_separation", 3)
	ability_box.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(ability_box)
	hb.minimum_size_changed.connect(_layout_unit_menu_toggle.call_deferred)

func _rebuild_ability_bar() -> void:
	if is_instance_valid(yuriko_bar):yuriko_bar.hide()
	if ability_box == null or not is_instance_valid(ability_box):
		return
	_clear_nodes(ability_box)
	_ability_btns.clear()
	_reaper_split_btn=null
	_tesla_pulse_btn=null
	_refinery_btn = null
	_refinery_cancel = null
	_refinery_src = null
	if ability_panel == null or not is_instance_valid(ability_panel):
		return
	if battle == null or not battle.has_method("selected_skill_unit"):
		ability_panel.visible = false
		return
	var building = battle.selected_building
	if is_instance_valid(building):
		if TeslaPulse.available(building):
			ability_panel.show()
			ability_title.text=building.display_name+"　技能"
			_tesla_pulse_btn=kit.make_button(TeslaPulse.ability(building).display_name+"  "+Hotkeys.label("skill_w"),13)
			_tesla_pulse_btn.name="TeslaPulseW"
			_tesla_pulse_btn.icon=preload("res://scripts/ui/progression_icon.gd").texture(TeslaPulse.card_id(building))
			_tesla_pulse_btn.pressed.connect(func():_cast_ability(1))
			_tesla_pulse_btn.mouse_entered.connect(func():battle.preview_ability(1))
			_tesla_pulse_btn.mouse_exited.connect(battle.clear_ability_preview)
			ability_box.add_child(_tesla_pulse_btn)
			preload("res://scripts/units/auto_w.gd").add_control(ability_box,building,_tesla_pulse_btn,self)
			SkillClock.attach(_tesla_pulse_btn,true)
			_update_ability_live()
		elif building.building_id=="R3REAPERTURRET" and battle.ReaperSplit.unlocked(battle.ReaperSplit.selected(battle)):
			ability_panel.show()
			ability_title.text=building.display_name+"　技能"
			var split_btn:=kit.make_button("分区射击  "+Hotkeys.label("skill_w"),13)
			_reaper_split_btn=split_btn
			split_btn.disabled=not battle.ReaperSplit.engaged(battle.ReaperSplit.selected(battle))
			split_btn.tooltip_text=battle.ReaperSplit.HINT
			split_btn.pressed.connect(func(): _cast_ability(1))
			ability_box.add_child(split_btn)
			preload("res://scripts/units/auto_w.gd").add_control(ability_box,battle.ReaperSplit.selected(battle),split_btn,self)
		elif building.side == "ally" and not building.is_dead() and not ConstructionRepack.vehicle_type(building).is_empty():
			ability_panel.show()
			ability_title.text = "%s　技能" % building.display_name
			var fold := kit.make_button(("收起矿场  " if building.building_id=="YAREFN" else "收起基地车  ")+Hotkeys.label("skill_e"),13)
			fold.name = "RepackSkill"
			var path := GameData.ra2_cameo_path(ConstructionRepack.vehicle_type(building))
			if ResourceLoader.exists(path): fold.icon=load(path)
			fold.expand_icon = true
			fold.custom_minimum_size = Vector2(165,38)
			fold.pressed.connect(func(): _cast_ability(2))
			ability_box.add_child(fold)
		elif building.side == "ally" and not building.is_dead() and building.is_refinery():
			_build_refinery_ability(building)
		if building.side == "ally" and not building.is_dead() and not building.under_construction and preload("res://scripts/units/civilian_orders.gd").slots(building) > 0:
			ability_panel.show()
			var occupants: Array = building.special.get("occupants", [])
			var capacity := preload("res://scripts/units/civilian_orders.gd").slots(building)
			var hint := "选中步兵，右键进驻" if occupants.is_empty() else "点击头像撤出"
			ability_title.text = "驻军 %d / %d　%s" % [occupants.size(), capacity, hint]
			if building.data.has("extra_power"):
				ability_title.text = "%s　%s" % [_defense_status(building), "右键派步兵进入" if occupants.is_empty() else "点击头像撤出"]
			if building.building_id == "NABNKR" and BattleRequest.extensions_enabled():
				var tier:int=building.battle.production_technology.bunker_level(building.side)
				ability_title.text += ("　射程天赋 Lv.%d" % (tier-1) if tier>0 else "　射程天赋未启用") if BattleRequest.combat_context.get("bunker_talent_version",0)>=1 else "　旧局射程科技 %d/3" % tier
			for unit in occupants:
				if not is_instance_valid(unit) or unit.embarked_in != building: continue
				var seat: Button = kit.ra_icon_tile(42)
				seat.name = "Occupant%d" % unit.get_instance_id()
				seat.tooltip_text = "%s · %d / %d 生命 · 点击单独撤出" % [unit.display_name, ceili(unit.hp), ceili(unit.max_hp)]
				var portrait := GameData.ra2_cameo_path(unit.unit_id)
				if ResourceLoader.exists(portrait):
					seat.icon = load(portrait)
					seat.expand_icon = true
				else: seat.text = unit.display_name
				seat.pressed.connect(preload("res://scripts/units/civilian_orders.gd").withdraw.bind(building, unit))
				ability_box.add_child(seat)
		elif ability_box.get_child_count()==0:
			ability_panel.hide()
		if building.side=="ally" and not building.is_dead() and float(building.special.get("card_armor",0))>0:
			ability_panel.show()
			if ability_box.get_child_count()==0:ability_title.text=building.display_name+"　技能"
			var armor_chip:=kit.make_button("复合装甲板",11)
			armor_chip.name="BuildingCardPassive"
			armor_chip.icon=preload("res://scripts/ui/progression_icon.gd").texture("ps_armor_plating")
			armor_chip.tooltip_text=MetaProgress.Academy.skill_description(GameData.get_skill("ps_armor_plating"),int(building.special.get("card_armor_rank",0)),float(building.special.card_armor))
			ability_box.add_child(armor_chip)
		if building.side=="ally" and not building.is_dead():
			ability_panel.show()
			var details:=kit.make_button("被动／天赋",11)
			details.name="EffectDetails"
			details.pressed.connect(EffectDetails.open.bind(self,building))
			ability_box.add_child(details)
		return
	var u = battle.selected_skill_unit()
	if u == null or not is_instance_valid(u):
		ability_panel.visible = false
		return
	ability_panel.visible = true
	if u.unit_id=="YURIKO" and is_instance_valid(yuriko_bar):
		ability_panel.hide()
		yuriko_bar.bind(u)
		return
	ability_title.text = "%s　技能" % str(u.display_name)
	var keys := [Hotkeys.label("skill_q"), Hotkeys.label("skill_w"), Hotkeys.label("skill_e")]
	var n := 3
	for i in range(n):
		if i == 2: _add_passive_slot(u)
		var info: Dictionary = UnitSkillLayout.info(u, i)
		var aname := str(info.get("name", ""))
		var key: String = str(keys[i]) if i < keys.size() else str(i + 1)
		# 红警3 式：图标块 + 热键角标 + 冷却数字覆盖层，右侧跟随技能名
		var btn: Button = kit.ra_icon_tile(38)
		btn.focus_mode = Control.FOCUS_NONE
		var equipped:Ability=u.ability_at(UnitSkillLayout.index(u,i))
		if i==1 and equipped!=null and equipped.id==str(info.get("id","")) and GameData.is_gacha_skill(equipped.id):
			btn.tooltip_text="%s  [%s]\n%s" % [aname,key,u.equipped_active_description(equipped)]
		else:
			btn.tooltip_text = "%s  [%s]\n%s\n冷却 %ss" % [aname, key, str(info.get("desc", "")), Ability.cooldown_text(BattleClock.real_seconds(float(info.get("cooldown", 0.0))))]
		btn.set_meta("base", aname)
		btn.set_meta("key", key)
		var skill_icon := str(info.get("icon", ""))
		var card_id:=str(info.get("id",""))
		var card_icon:=not GameData.get_skill(card_id).is_empty()
		if card_icon or (not skill_icon.is_empty() and ResourceLoader.exists(skill_icon)):
			var picture := TextureRect.new()
			picture.texture = preload("res://scripts/ui/progression_icon.gd").texture(card_id) if card_icon else load(skill_icon)
			if card_id==Unit.Furnace.ACTIVE:preload("res://scripts/ui/furnace_contract_panel.gd").shine(picture)
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.position = Vector2(2, 2); picture.size = Vector2(34, 34)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(picture); btn.set_meta("skill_texture", picture)
		else:
			var gl: Control = CmdGlyph.new(str(info.get("glyph", _ability_glyph(aname))), 20)
			gl.position = Vector2(9, 7)
			btn.add_child(gl)
		SkillClock.attach(btn)
		if info.has("active_frame"):
			var active_frame:=preload("res://scripts/ui/active_skill_frame.gd").new()
			active_frame.name="ActiveSkillFrame"
			btn.add_child(active_frame)
		var kl: Label = kit.ra_label(key, 9, kit.RA_CYAN_DIM)
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kl.position = Vector2(28, 24)
		btn.add_child(kl)
		var cd: Label = kit.ra_label("", 10, kit.RA_GOLD)
		cd.add_theme_constant_override("outline_size",3)
		cd.add_theme_color_override("font_outline_color",Color(0.02,0.025,0.04))
		cd.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cd)
		btn.set_meta("cd", cd)
		btn.pressed.connect(_on_ability_btn.bind(i))
		btn.mouse_entered.connect(_on_ability_hover.bind(i))
		btn.mouse_exited.connect(_on_ability_unhover)
		_ability_btns.append(btn)
		ability_box.add_child(btn)
		var nl: Label = kit.ra_label(aname, 11, kit.RA_TEXT)
		nl.mouse_filter = Control.MOUSE_FILTER_STOP
		nl.tooltip_text = btn.tooltip_text
		# 红警3 式「整块技能可点」：技能名文字原先吞掉点击却不派发，导致点名字没反应。
		nl.gui_input.connect(_on_ability_name_input.bind(i))
		nl.mouse_entered.connect(_on_ability_hover.bind(i))
		nl.mouse_exited.connect(_on_ability_unhover)
		btn.set_meta("name_label", nl)
		nl.hide()
		btn.add_child(nl)
		if i==1:preload("res://scripts/units/auto_w.gd").add_control(ability_box,u,btn,self)
	_update_ability_live()

func _add_passive_slot(unit) -> void:
	var title: String = unit.passive_name()
	var talents := PackedStringArray()
	var options := MetaProgress.talent_options(unit.unit_id)
	for key: String in options:
		if BattleRequest.has_unit_talent(unit.unit_id, key, unit.side):
			var rank := MetaProgress.talent_rank(unit.unit_id, key, BattleRequest.combat_context.get("unit_talents", {}))
			talents.append("%s %d/3" % [options[key].name, rank])
	var caption := "被动／天赋　" + (title if not title.is_empty() else "查看")
	if not talents.is_empty(): caption += "\n" + talents[0] + (" 等" if talents.size() > 1 else "")
	var chip := kit.ra_icon_tile(38)
	if not unit.passive.is_empty():
		chip.icon = preload("res://scripts/ui/progression_icon.gd").texture(unit.passive.id)
		chip.expand_icon = true
	else:
		chip.text = "◇"
	chip.name="EffectDetails"
	chip.pressed.connect(EffectDetails.open.bind(self,unit))
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = caption
	chip.mouse_entered.connect(func():
		if is_instance_valid(unit): chip.tooltip_text = EffectDetails.describe(unit))
	ability_box.add_child(chip)

func _on_ability_btn(slot: int) -> void:
	_cast_ability(slot)

func _on_ability_name_input(ev: InputEvent, slot: int) -> void:
	# 技能名的 Label 与图标块同一施放入口，避免「单击技能名无效」。
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if slot >= 0 and slot < _ability_btns.size() and is_instance_valid(_ability_btns[slot]) and _ability_btns[slot].disabled:
			return
		_on_ability_btn(slot)

func _cast_ability(slot: int) -> void:
	if battle == null:
		return
	if slot==1 and TeslaPulse.available(battle.selected_building):
		if not TeslaPulse.use(battle.selected_building):Events.emit_message("技能不可用：检查冷却、供电或建造状态",kit.COL_DIM)
		_update_ability_live()
		return
	if slot==2:
		var selected=battle.selected_skill_unit()
		if Unit.YRTalents.reverse_ready(selected):
			battle.arm_command(Unit.YRTalents.REVERSE)
			return
	if slot==1:
		var gun=battle.ReaperSplit.selected(battle)
		if battle.ReaperSplit.unlocked(gun):
			battle.ReaperSplit.arm(battle,gun)
			return
	if slot == 2 and is_instance_valid(battle.selected_building) and battle.selected_building.side == "ally" and battle.selected_building.is_hq:
		ConstructionRepack.execute(battle, battle.selected_building)
		return
	var unit = battle.selected_skill_unit()
	if unit == null: return
	slot = UnitSkillLayout.index(unit, slot)
	if slot < 0: return
	if battle.has_method("request_ability"):
		# 带作用范围的技能：先进入瞄准态显示范围（左键确认）；无范围：即时施放
		var r: int = battle.request_ability(slot)
		if r == 0:
			Events.emit_message("技能不可用或仍在冷却", kit.COL_DIM)
			return
		_update_ability_live()
		return
	if not battle.has_method("use_ability_selected"):
		return
	var n: int = battle.use_ability_selected(slot)
	if n <= 0:
		Events.emit_message("技能不可用或仍在冷却", kit.COL_DIM)
		return
	_update_ability_live()

func _update_ability_live() -> void:
	if ability_panel == null or not is_instance_valid(ability_panel) or not ability_panel.visible:
		return
	if is_instance_valid(_tesla_pulse_btn):
		var b=battle.selected_building
		if not TeslaPulse.available(b):_rebuild_ability_bar();return
		var ab:=TeslaPulse.ability(b)
		_tesla_pulse_btn.disabled=not TeslaPulse.ready(b)
		_tesla_pulse_btn.get_node("CooldownClock").update_timer(ab.cd_left,ab.cooldown)
		_tesla_pulse_btn.text=ab.display_name+"  "+Hotkeys.label("skill_w")+(" · %.1fs" % ab.cd_left if ab.cd_left>0 else "")
		_tesla_pulse_btn.tooltip_text=MetaProgress.Academy.skill_description(GameData.get_skill(ab.id),int(b.special[TeslaPulse.STATE].rank),ab.value)+"\n需防御建筑正常运转。"
		return
	if is_instance_valid(_reaper_split_btn):
		_reaper_split_btn.disabled=not battle.ReaperSplit.engaged(battle.ReaperSplit.selected(battle))
		return
	if battle == null or _ability_btns.is_empty():
		return
	var u = battle.selected_skill_unit() if battle.has_method("selected_skill_unit") else null
	if u == null or not is_instance_valid(u):
		return
	for i in range(_ability_btns.size()):
		var btn = _ability_btns[i]
		if not is_instance_valid(btn):
			continue
		var cd = btn.get_meta("cd", null)
		var nl = btn.get_meta("name_label", null)
		var actual := UnitSkillLayout.index(u, i)
		var info: Dictionary = UnitSkillLayout.info(u, i)
		var total:=float(info.get("cooldown",0.0))
		var active_frame=btn.get_node_or_null("ActiveSkillFrame")
		if active_frame!=null:
			active_frame.set_active(bool(info.get("active_frame",false)),bool(info.get("ready",false)))
			btn.tooltip_text="%s  [%s]\n%s"%[info.get("name",""),btn.get_meta("key",""),info.get("desc","")]
			if is_instance_valid(nl):nl.text=str(info.get("name",""));nl.tooltip_text=btn.tooltip_text
		# Equipped cards shorten their real recharge through the existing training rule.
		var furnace: bool = info.get("id","") == Unit.Furnace.ACTIVE
		if actual>=0 and not furnace and not str(info.get("id","")).begins_with("allied_"):
			total/=maxf(0.6,Unit.Training.card_scale(u))
		btn.get_node("CooldownClock").update_timer(float(info.get("cd_left",0.0)),total)
		var deploy_group_ready := false
		if i == 2 and (str(info.get("id", "")) in ["allied_deploy", "ggi_deploy"] or (u.unit_id == "SCHP" and info.get("id") == "allied_special")):
			var choppers: bool = u.unit_id == "SCHP"
			var group: Array = battle.selected_deploy_group(choppers)
			if group.size() > 1:
				info = info.duplicate()
				var all_deployed: bool = group.all(func(member): return member.is_deployed())
				info["name"] = ("全部收炮起飞" if choppers else "全部起立") if all_deployed else "全部部署"
				info["active"] = all_deployed
				info["desc"] = "选中步兵只要有人未部署，就统一部署；全部已部署才统一起立。不同兵种使用各自的部署姿态，受控制限制的单位暂时无法执行。"
				if choppers:
					info["desc"] = "选中直升机只要有未部署的，就统一部署；全部已部署才统一收炮起飞。降落受阻或正在切换的直升机暂时无法执行。"
					deploy_group_ready = group.any(func(member): return member.is_deployed() == all_deployed and member.ability_ready(UnitSkillLayout.index(member, 2)))
		var picture = btn.get_meta("skill_texture") if btn.has_meta("skill_texture") else null
		var icon_path := str(info.get("icon", ""))
		if is_instance_valid(picture) and not icon_path.is_empty() and (picture.texture == null or picture.texture.resource_path != icon_path):
			if ResourceLoader.exists(icon_path): picture.texture = load(icon_path)
		var toggle := bool(info.get("toggle", false))
		var active := toggle and bool(info.get("active", false))
		if toggle:
			var cooldown := float(info.get("cooldown", 0.0))
			var cooldown_text := "冷却 %.1fs" % BattleClock.real_seconds(cooldown) if cooldown > 0.0 else "无冷却"
			btn.tooltip_text = "%s  [%s]\n%s\n切换开关 · %s%s" % [str(info.get("name", "")), str(btn.get_meta("key", "")), str(info.get("desc", "")), cooldown_text, " · 已开启" if active else ""]
			if furnace:
				btn.tooltip_text = "金鳞战垒  [%s]\n%s\n护盾%s" % [btn.get_meta("key", ""), info.desc, cooldown_text]
			if nl != null and is_instance_valid(nl):
				nl.text = str(info.get("name", ""))
				if furnace:
					var remaining := ceili(BattleClock.real_seconds(float(info.cd_left)))
					nl.text += " · 盾 %ds" % remaining if remaining > 0 else " · 盾就绪"
				nl.tooltip_text = btn.tooltip_text
		if deploy_group_ready or (actual >= 0 and u.ability_ready(actual)) or (info.get("id") in [battle.ReaperSplit.ID,Unit.YRTalents.REVERSE] and info.ready):
			btn.disabled = false
			btn.modulate = Color(0.65, 1.0, 0.75, 1) if active else Color.WHITE
			if nl != null and is_instance_valid(nl):
				nl.modulate = Color(1, 1, 1, 1)
			if cd != null and is_instance_valid(cd):
				cd.text = "✓" if active else ""
		else:
			btn.disabled = true
			btn.modulate = Color(0.72, 0.78, 0.86, 1)
			if nl != null and is_instance_valid(nl):
				nl.modulate = Color(0.62, 0.66, 0.74, 1)
			if cd != null and is_instance_valid(cd):
				cd.text = "—" if (toggle and float(info.get("cd_left", 0.0)) <= 0.0) or (actual < 0 and float(info.get("cd_left",0.0)) <= 0.0) else "%ds" % int(ceil(BattleClock.real_seconds(float(info.get("cd_left", 0.0)))))

# ================================================================== 增益/减益栏（buff 栏）
# 贴在技能栏正上方：列出当前选中单位的限时增益/减益（色块 + 名称数值 + 倒计时）。
# 配色口径：攻击红 / 防御绿 / 闪避紫 / 命中黄 / 暴击红+蓝 / 速度青蓝 / 冷却青 / 回血绿 / 瘫痪紫。

func _build_buff_bar(root: Control) -> void:
	buff_panel = kit.ra_panel(kit.RA_PANEL, kit.RA_EDGE, 4, 5)
	buff_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buff_panel.offset_left = -640.0
	buff_panel.offset_right = -8.0
	buff_panel.offset_top = -196.0
	buff_panel.offset_bottom = -152.0
	buff_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	buff_panel.z_index = 12
	buff_panel.visible = false
	root.add_child(buff_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	buff_panel.add_child(hb)
	buff_title = kit.ra_label("Buff / 状态", 11, kit.RA_CYAN)
	hb.add_child(buff_title)
	buff_empty = kit.ra_label("暂无生效中的增益或减益", 11, kit.COL_DIM)
	buff_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(buff_empty)
	buff_box = GridContainer.new()
	buff_box.columns = 7
	buff_box.add_theme_constant_override("h_separation", 2)
	buff_box.add_theme_constant_override("v_separation", 2)
	buff_box.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(buff_box)

func _buff_unit():
	if battle == null:return null
	if is_instance_valid(battle.selected_building):
		var building=battle.selected_building
		if building.building_id=="R3REAPERTURRET" and battle.actor_visible_to("ally",building):
			return building.get_node_or_null("ReaperMount")
		return null
	for u in battle.selected_units:
		if AlliedAbilities.alive(u) and battle.actor_visible_to("ally",u):
			return u
	return null

func _buff_signature(ents: Array) -> String:
	var parts: Array = []
	for e in ents:
		parts.append(str(e.get("id", e.get("kind", ""))))
	return ",".join(parts)

func _rebuild_buff_bar() -> void:
	if buff_box == null or not is_instance_valid(buff_box):
		return
	_clear_nodes(buff_box)
	_buff_chips.clear()
	if buff_panel == null or not is_instance_valid(buff_panel):
		return
	var u = _buff_unit()
	if u == null or not u.has_method("buff_entries"):
		buff_panel.visible = false
		_buff_sig = ""
		return
	var ents: Array = u.buff_entries()
	_buff_sig = _buff_signature(ents)
	buff_panel.visible = true
	buff_empty.visible = ents.is_empty()
	_fill_buff_grid(ents)
	_fit_buff_panel()

func _fill_buff_grid(ents: Array) -> void:
	var capacity := buff_box.columns * 2
	var count := ents.size() if ents.size() <= capacity else capacity - 1
	for i in count:
		var e: Dictionary = ents[i]
		var chip := _make_buff_chip(e)
		buff_box.add_child(chip)
		_buff_chips[str(e.id)] = chip
	if count < ents.size():
		var more := kit.ra_label("…", 17, kit.COL_TEXT)
		more.name = "StatusOverflow"
		more.custom_minimum_size = Vector2(28,28)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more.mouse_filter = Control.MOUSE_FILTER_STOP
		buff_box.add_child(more)
		_update_overflow_hint(more, ents, count)

func _update_overflow_hint(more: Label, ents: Array, start: int) -> void:
	var lines := PackedStringArray(["其余 %d 个状态" % (ents.size()-start)])
	for i in range(start,ents.size()):
		var tip := preload("res://scripts/ui/unit_status.gd").tooltip(ents[i])
		lines.append(tip.replace("\n", " · "))
	var hint := "\n".join(lines)
	if more.tooltip_text != hint: more.tooltip_text = hint

## 让面板按内容自适应宽度（右对齐在技能栏上方），避免 buff 多时被裁切
func _fit_buff_panel() -> void:
	if not is_instance_valid(buff_panel):return
	_layout_unit_menu_toggle()

func _make_buff_chip(e: Dictionary) -> Control:
	var chip:=preload("res://scripts/ui/status_chip.gd").new()
	chip.name="Status_"+str(e.id).validate_node_name()
	chip.update_entry(e)
	return chip

func _update_buff_live() -> void:
	if buff_panel == null or not is_instance_valid(buff_panel):
		return
	if battle == null:
		return
	var u = _buff_unit()
	if u == null or not u.has_method("buff_entries"):
		if buff_panel.visible:
			_rebuild_buff_bar()
		return
	var ents: Array = u.buff_entries()
	if not buff_panel.visible or _buff_signature(ents) != _buff_sig:
		_rebuild_buff_bar()
		return
	if not buff_panel.visible:
		return
	for e in ents:
		var chip = _buff_chips.get(str(e.id))
		if chip == null or not is_instance_valid(chip):
			continue
		chip.update_entry(e)
	var more := buff_box.get_node_or_null("StatusOverflow") as Label
	if more != null: _update_overflow_hint(more, ents, buff_box.columns * 2 - 1)
	_fit_buff_panel()


# ---- 技能范围预览（悬停技能按钮时在世界里显示作用范围） ----
func _on_ability_hover(slot: int) -> void:
	if battle != null and is_instance_valid(battle) and battle.has_method("preview_ability"):
		var unit = battle.selected_skill_unit()
		if unit != null: battle.preview_ability(UnitSkillLayout.index(unit, slot))

func _on_ability_unhover() -> void:
	if battle != null and is_instance_valid(battle) and battle.has_method("clear_ability_preview"):
		battle.clear_ability_preview()

## RA3-style contextual status strip: current activity, progress and actionable reason.
## Reuses the project's RA2 cameos and skin; no extra production hotkeys.
func _add_economy_status() -> void:
	economy_status_label = kit.make_label("", 12, kit.COL_ACCENT_2)
	economy_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	economy_status_label.custom_minimum_size.x = 260
	sel_box.add_child(economy_status_label)
	economy_status_bar = ProgressBar.new()
	economy_status_bar.custom_minimum_size = Vector2(0, 5)
	economy_status_bar.show_percentage = false
	economy_status_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	economy_status_bar.add_theme_stylebox_override("background", kit.ra_style(kit.RA_PANEL, kit.RA_EDGE, 0, 0))
	economy_status_bar.add_theme_stylebox_override("fill", kit.ra_style(kit.RA_CYAN, kit.RA_CYAN, 0, 0))
	sel_box.add_child(economy_status_bar)

func _refresh_economy_status(entity) -> void:
	if not is_instance_valid(economy_status_label) or not is_instance_valid(entity):
		return
	if entity is Unit and not str(entity.data.get("powered_by", "")).is_empty():
		var reason: String = entity.power_disabled_reason()
		economy_status_label.text = reason if not reason.is_empty() else "机器人在线 · 控制中心运转正常"
		economy_status_label.modulate = kit.COL_WARN if not reason.is_empty() else Color.WHITE
		economy_status_label.tooltip_text = "断电或失去己方控制中心后停止移动和攻击；恢复后继续原指令。"
		economy_status_label.show()
		economy_status_bar.hide()
	elif entity is Unit and entity.is_harvester:
		var factor := EconomyCycle.income_factor(battle, entity.side)
		economy_status_label.text = EconomyCycle.miner_status(entity) + " · 货舱 " + _cargo_caption(entity)
		if factor > 1.0:
			economy_status_label.text += " · 精炼 +%d%%" % roundi((factor - 1.0) * 100.0)
		economy_status_label.tooltip_text = "基础货值 $%d · 当前卸矿预计 $%d\n按实际卸货时生效的精炼器加成结算" % [roundi(entity.cargo_value()), roundi(entity.cargo_value() * factor)]
		economy_status_bar.value = entity.cargo / maxf(1.0, entity.cargo_cap) * 100.0
	elif entity is Building:
		economy_status_bar.visible = false
		if entity.building_id == "GAROBO":
			var active: bool = entity.is_operational()
			economy_status_label.text = "机器人控制中心 · " + ("在线" if active else ("展开中" if entity.under_construction or entity._buildup_play >= 0.0 else "缺电停机"))
			economy_status_label.tooltip_text = "耗电 100；至少一座己方控制中心运转即可控制所有己方机器人坦克。"
			economy_status_label.modulate = Color.WHITE if active else kit.COL_WARN
			economy_status_label.show()
		elif entity.data.get("tags", []).has("purifier"):
			var active: bool = entity.is_operational()
			var reason := "运行中" if active else ("建造/展开中" if entity.under_construction or entity._buildup_play >= 0.0 else "停机：缺电或受干扰")
			economy_status_label.text = "精炼器 · " + reason + "\n本方卸矿总加成 +%d%%" % roundi((EconomyCycle.income_factor(battle, entity.side) - 1.0) * 100.0)
			economy_status_label.modulate = Color.WHITE if active else kit.COL_WARN
		else:
			var state := ConstructionRepack.check(battle, entity)
			economy_status_label.text = "基地管理 · 建筑 / 防御独立建造\n" + ("可收起迁移 · 保留已付进度" if state.ok else str(state.reason))
