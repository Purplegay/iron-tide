extends Node2D
class_name Battle
## 战斗总控：地图生成、资金、单位生成、选择与指令、波次调度、胜负判定、GM 钩子。

signal enemy_superweapon_launched(weapon_name: String)
signal friendly_storm_launched(owner_label: String)
signal computer_defeated(side: String, message: String, color: Color)
signal pointer_gestures_cancelled

const Maps = preload("res://scripts/world/skirmish_maps.gd")
const UnitScript := preload("res://scripts/units/unit.gd")
const BuildingScript := preload("res://scripts/buildings/building.gd")
const ResourceNodeScript := preload("res://scripts/world/resource_node.gd")
const ObstacleScript := preload("res://scripts/world/obstacle.gd")
const NativeMaps = preload("res://scripts/world/native_maps.gd")
const GroundScript := preload("res://scripts/world/ground.gd")
const BUILD_GRID := 40.0        # 红警3式建造网格吸附步长
const BUILD_RADIUS := 620.0     # 距任意我方建筑的最大建造距离
const BUILD_ADJ_RANGE := 80.0   # RA2 Adjacent：新建筑底盘须落在自家底盘该范围内（2 格）
const SELECTION_CLICK_SLOP := 14.0  # 屏幕像素；不随相机缩放或等距投影改变

var pending_pose_redraws: Array[Unit] = []
var radar_ore_revision := 0
var attack_target_outlines := preload("res://scripts/ui/attack_target_outlines.gd").new()
var ore_neighborhood := preload("res://scripts/world/battle_neighborhood.gd").new()
var ai_strategy_budget = preload("res://scripts/world/ai_strategy_budget.gd").new()
var ai_prerequisite_scan := false
var ai_scan_buildings := {}
var ai_scan_zones := {}
var ai_scan_contacts := {}
var ai_scan_prices := {}
var ai_scan_footprints := {}
func clear_ai_decision_cache() -> void:
	ai_scan_buildings.clear()
	ai_scan_zones.clear()
	ai_scan_contacts.clear()
	ai_scan_prices.clear()
	ai_scan_footprints.clear()

# Membership only; eligibility, health and construction state remain live.
var _building_members: Dictionary = {}
var _building_members_dirty := true
var _building_members_count := -1
var _production_witnesses: Dictionary = {}

# These readers borrow the existing valid membership index. They must not
# trigger a rebuild or cache live eligibility/production results.
func _warm_owner_buildings(owner_side: String) -> Array:
	if _building_members_dirty or _building_members_count != buildings.size(): return buildings
	return _building_members.get(owner_side, [])

func invalidate_building_membership() -> void:
	_building_members_dirty = true

func _buildings_for_side(owner_side: String) -> Array:
	if _building_members_dirty or _building_members_count != buildings.size():
		var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(51)
		preload("res://scripts/world/battle_call_counters.gd").iterations(51,buildings.size())
		_building_members.clear()
		_production_witnesses.clear()
		for candidate in buildings:
			if not is_instance_valid(candidate): continue
			var building: Building = candidate
			_building_members.get_or_add(building.side,[]).append(building)
		_building_members_count = buildings.size()
		_building_members_dirty = false
	return _building_members.get(owner_side,[])

var ai_dispatch := preload("res://scripts/world/ai_unit_dispatch.gd").new()
var frame_pacing: Node
var fog = null
var mission: Dictionary = {}
var match_id := ""
const EconomyCycle = preload("res://scripts/world/economy_cycle.gd")
const ConstructionRepack = preload("res://scripts/world/construction_repack.gd")
const AttackRangePreview = preload("res://scripts/world/attack_range_preview.gd")
const BuildRangePreview = preload("res://scripts/world/build_range_preview.gd")
const MovementOrderPreview = preload("res://scripts/world/movement_order_preview.gd")
var build_range_preview = BuildRangePreview.new()
const AttackCooldownIndicator = preload("res://scripts/ui/attack_cooldown_indicator.gd")
const AircraftAmmoIndicator = preload("res://scripts/ui/aircraft_ammo_indicator.gd")
const TransportIndicator = preload("res://scripts/ui/transport_indicator.gd")
const GarrisonIndicator = preload("res://scripts/ui/garrison_indicator.gd")
const VeterancyIndicator = preload("res://scripts/ui/veterancy_indicator.gd")
const HealingIndicator = preload("res://scripts/ui/healing_indicator.gd")
var _move_preview_was_active := false
var _attack_ranges_drawn := false
var _range_nodes: Array[AttackRangePreview] = []
var ore_growth_elapsed := 0.0

var map_size: float = 2400.0
var enemy_faction: String = "swarm"
var skirmish: bool = false                 # 遭遇战模式
var skirmish_enemy_base: String = "allied"
var skirmish_difficulty: int = 1
var house_controllers: Dictionary = {}
var skirmish_ai = null                     # SkirmishAI
var gm_unit_lab := false
var _countries: Dictionary = {}
var production_technology = preload("res://scripts/rules/production_technology.gd").new()
var enemy_base_center: Vector2 = Vector2.ZERO

var funds: float = 4000.0
var enemy_funds: float = 4000.0
var enemy_struct_queue: Array = []
var enemy_struct_ready: Dictionary = {}
var enemy_power: Dictionary = {"produced": 0.0, "drain": 0.0, "low": false}

var units: Array = []
var buildings: Array = []
# Live wall segments keyed by their 40-pixel placement cell. Rebuilt by building lifecycle on load.
var wall_cells: Dictionary = {}
var inspected_drones: Array = [] # Shown in the HUD, excluded from every command recipient list.
var selected_units: Array = []
var _sel_voice_sig := ""                     # 语音：上次已播 select 语音的选择签名
var selected_building = null
var selected_walls: Array = []

var simulation := preload("res://scripts/world/simulation_world.gd").new()
# Existing query consumers share the simulation registry's maintained index.
var neighborhood = simulation.neighborhood
var bridge_traffic := preload("res://scripts/world/bridge_traffic.gd").new()
var camera: Camera2D
var ground: Node2D
var enemy_root: Node2D
var projectiles_root: Node2D
var effects_root: Node2D
var hp_overlay: Node2D                  # 高层级血条/标签层（WORLD_HUD）：恒盖在所有实体之上
var campaign_mark_overlay: Node2D
var move_order_overlay: Node2D

# 波次
var waves: Array = []
var prepared: bool = false
var prepare_time: float = 30.0
var wave_index: int = 0
var wave_timer: float = 0.0
var endless: bool = false
var endless_loop: int = 0
var waves_exhausted: bool = false

# 统计与状态
var kills: int = 0
var waves_cleared: int = 0
var enemy_spawn_count: int = 0
var enemy_initial_scoreable: int = 0
var enemy_losses_for_music: int = 0
var uprising_music_started := false
var triumphal_music_started := false
var _music_check_left := 1.0
var ended: bool = false
var paused: bool = false

# 建造
var armed_build: String = ""

# —— 电力（RA2）——
# 事实源：rules.ini 建筑 Power=（正=发电/负=耗电）+ [General] Min/MaxLowPowerProductionSpeed
# var power_produced/power_drain/power_low 由 _update_power() 每帧重算（建筑变动才发事件）
var power_produced: float = 0.0
var power_drain: float = 0.0
var power_low: bool = false
var _power_sig: String = ""
var _eva_power_low_prev: bool = false

# —— 建筑生产队列（RA3/RA2 侧栏流程：先在侧栏花钱建造→就绪→再选址放置）——
# Aggregate storage for two independent FIFO categories: building / defense.
# Elements: { id, cost, time, elapsed, paid }; use structure_jobs for category views.
var struct_queue: Array = []
var struct_ready: Dictionary = {}       # id -> 已就绪待放置的数量
var struct_ready_order: Array = []       # 就绪建筑的放置顺（先就绪先放）

var spawn_points: Array[Vector2] = []
var drag_start: Vector2 = Vector2.ZERO
var drag_start_screen: Vector2 = Vector2.ZERO
var dragging: bool = false
var _selection_additive: bool = false

# 寻路 / 编队
var path_service: PathService = null
var _fence_routes: PathService
var _fence_epoch := -1
var _has_crushable_fences := false

func movement_service(u) -> PathService:
	if not _has_crushable_fences or not u is Unit or not u.can_roll_fences(): return path_service
	if _fence_routes == null:
		_fence_routes = PathService.new()
		add_child(_fence_routes)
	if _fence_epoch != path_service.epoch:
		_fence_routes.native_map_id = path_service.native_map_id
		_fence_routes.map_size = path_service.map_size
		_fence_routes.cell = path_service.cell
		_fence_routes.cols = path_service.cols
		_fence_routes.rows = path_service.rows
		_fence_routes.time_shift_area = path_service.time_shift_area
		_fence_routes.water_rects = path_service.water_rects
		_fence_routes.bridge_decks = path_service.bridge_decks
		_fence_routes.set_bridge_damage(path_service.bridge_flags, path_service.broken_bridge_decks)
		var solid := _path_blockers().filter(func(b): return not WallArt.crushable_fence(b))
		_fence_routes.rebuild_terrain(solid, allied_state.get("convoy_roads", []))
		_fence_epoch = path_service.epoch
	return _fence_routes

const ReaperSplit = preload("res://scripts/units/ra3_reaper_split.gd")
var split_gunner
var formation_gesture := preload("res://scripts/world/formation_gesture.gd").new()
var formation_mode: String = "line"
var preview_override: Vector2 = Vector2.INF   # 仅测试用：强制建造预览位置

## 镜头跟随目标（红警2：F 跟随选中单位；手动平移解除）
var follow_target = null
## 控制组（红警2 编队）："1".."10" -> Array[Node]
var control_groups: Dictionary = {}
var _group_badges: Dictionary = {}

# 视角
const DEFAULT_VIEW_ZOOM := 1.0
var view_zoom: float = DEFAULT_VIEW_ZOOM

# 交互：悬停高亮 / 指令模式 / 点击反馈
var hover_entity = null
var command_cursor = null
var command_mode: String = ""
## 已武装的超级武器建筑（等待地图点击目标）。
var _armed_superweapon = null
var _chrono_source_point := Vector2.INF
var _order_marks: Array = []
var _last_click_ms: int = 0
var _last_click_unit = null
var last_rally_building = null       # 最近设定集结点的建筑（用于绘制旗帜）
var rally_points: Dictionary = {}    # 建筑 instance_id -> 集结点 Vector2

# 技能瞄准 / 范围显示（红警3 式：带作用范围的技能先瞄准，左键确认施放）
var cast_slot: int = -1              # 已武装等待确认的技能槽（-1 = 未武装）
var hover_ability: int = -1          # HUD 技能按钮悬停槽（仅预览范围，不施放）
var _cast_flashes: Array = []        # 施放后的范围扩散圈（视觉反馈）

# 相机
## 视角平移速度（屏幕像素/秒）。红警2 的平移坐标就是屏幕坐标，故这里按屏幕速度定义。
var cam_speed: float = MetaProgress.SCROLL_BASE
## 贴边滚屏：窗口内的触发带，单位为视口像素。
const EDGE_MARGIN := 9.0
const EDGE_SIDE_MARGIN := 28.0
## 右键「单击 vs 拖拽」判定阈值（对齐红警2 WorldInteraction：7px）
var _click_slop: float = 7.0
## 设置项：按住右键拖拽平移视角（对齐红警2 rightClickScroll）
var right_click_scroll: bool = true
## 设置项：右键单击仍下达移动/集火指令（对齐红警2 rightClickMove）
var right_click_move: bool = true
## 设置项：鼠标贴边自动滚屏
var edge_scroll_enabled: bool = true
## 右键（或中键）拖拽平移的运行时状态
var _rmb_panning: bool = false
var _rmb_moved: bool = false
var _rmb_anchor: Vector2 = Vector2.ZERO
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _window_focused := true
var _edge_from_world := false
var _edge_from_right_panel := false
var edge_panning := false

var hud = null
var _path_refresh_queued := false
var _removed_building_bounds := Rect2()

# ================================================================== 生命周期

var building_art_warmup: Node

func _ready() -> void:
	_build_ghost_layer = Node2D.new()
	_build_ghost_layer.name = "BuildGhostLayer"
	_build_ghost_layer.show_behind_parent = true # 占地边界画在贴图上方。
	_build_ghost_layer.draw.connect(_draw_build_ghosts)
	add_child(_build_ghost_layer)
	if DisplayServer.get_name() != "headless":
		building_art_warmup = preload("res://scripts/buildings/building_art_warmup.gd").new()
		add_child(building_art_warmup)
	command_cursor = preload("res://scripts/ui/battle_cursor.gd").new()
	command_cursor.battle = self
	add_child(command_cursor)
	Events.unit_died.connect(_on_unit_died)
	set_process_unhandled_input(true)
	# Live settings share the menu values; control timing remains wall-clock based.
	_refresh_camera_settings()
	MetaProgress.camera_settings_changed.connect(_refresh_camera_settings)
	get_window().focus_exited.connect(_on_window_focus_exited)
	get_window().focus_entered.connect(_on_window_focus_entered)

func _refresh_camera_settings() -> void:
	edge_scroll_enabled = MetaProgress.edge_scroll
	cam_speed = MetaProgress.scroll_px_per_sec()

func _exit_tree() -> void:
	# A newer scene may already own the hook; never remove another battle's callback.
	if GM.has_battle_tools() and GM._hooks.unit_tools.get_object()==self:GM.unregister_hook("unit_tools")
	if Events.unit_died.is_connected(_on_unit_died):
		Events.unit_died.disconnect(_on_unit_died)
	if get_window().focus_exited.is_connected(_on_window_focus_exited):
		get_window().focus_exited.disconnect(_on_window_focus_exited)
	if get_window().focus_entered.is_connected(_on_window_focus_entered):
		get_window().focus_entered.disconnect(_on_window_focus_entered)

func _on_window_focus_exited() -> void:
	_window_focused = false
	cancel_pointer_gestures()

func _on_window_focus_entered() -> void:
	_window_focused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel_pointer_gestures()

func world_input_enabled() -> bool:
	var first: Dictionary = allied_state.get("allied_first",{})
	if first.get("assault_input_locked",false) or first.get("phase") in [-1,0,3] or (first.get("power_camera_lock",false) and not power_low): return false
	if int(allied_state.get("allied_finale",{}).get("media_stage",0)) != 0: return false
	if allied_state.has("head_brief_stage"): return false
	return not allied_state.get("hollywood",{}).get("briefing",false) and _window_focused and not paused and not ended and not get_tree().paused and preload("res://scripts/ui/battle_hotkeys.gd").modal_count==0

func cancel_pointer_gestures() -> void:
	pointer_gestures_cancelled.emit()
	edge_panning=false
	_edge_from_world=false
	_edge_from_right_panel=false
	formation_gesture.reset()
	if is_instance_valid(move_order_overlay): move_order_overlay.queue_redraw()
	dragging = false
	_rmb_panning = false
	_rmb_moved = false
	_pan_button = MOUSE_BUTTON_NONE
	_last_click_unit = null
	if is_instance_valid(hud) and is_instance_valid(hud.minimap):
		hud.minimap.cancel_drag()
	queue_redraw()

func _on_unit_died(node) -> void:
	if node is Unit and node.unit_id=="SQD" and node.side=="ally" and node.special.get("time_shift_fleet_slot",-1)==21 and node._battle_world()==self and allied_state.has("time_shift") and int(allied_state.time_shift.phase)==0:
		allied_state.time_shift.s01_opening_squid2_lost=true
	invalidate_ai_population()
	if skirmish and not gm_unit_lab and node is Unit and node.unit_id not in SUPPORT_FLIGHTS \
			and BattleRequest.is_ai_house(node.side) and node._battle_world() == self and ai_decisions(node.side).get("mobilized",false):
		update_ai_strength(node.side,ai_living_count(node.side))
	if node is Unit and node.side != "neutral" and not BattleRequest.friendly("ally",node.side):
		if not node.special.get("house_eliminated",false) and not AlliedAbilities.flag(node, "DontScore"):
			kills += 1
			enemy_losses_for_music += 1

	if node is Building and node.side != "neutral" and not BattleRequest.friendly("ally",node.side) and not node.special.get("house_eliminated",false):
		enemy_losses_for_music += 1
	if node is Unit and BattleRequest.is_ai_house(node.side) and node.special.get("ai_mid_engineer", false) and node._battle_world() == self:
		var state := ai_decisions(node.side)
		var losses := int(state.get("oil_engineer_losses",0))+1
		state.oil_engineer_losses = losses
		if losses >= 2: state.oil_retry_left = 60.0
	if node is Building:
		if node.battle == self:
			var bounds := Placement.aabb(footprint_of(node), node.global_position)
			_removed_building_bounds = _removed_building_bounds.merge(bounds) if _removed_building_bounds.has_area() else bounds
		if not _path_refresh_queued:
			_path_refresh_queued = true
			_flush_path_refresh.call_deferred()

func _flush_path_refresh() -> void:
	_path_refresh_queued = false
	var bounds := _removed_building_bounds
	_removed_building_bounds = Rect2()
	if path_service == null or not bounds.has_area():
		_refresh_pathing()
		return
	# Account for foundation stamp padding and grid-cell coverage.
	bounds = bounds.grow(path_service.cell + 2.0)
	var before := path_service.route_snapshot_outside(bounds)
	_refresh_pathing()
	if path_service.route_matches_outside(bounds, before):
		record_route_change(bounds)

# ================================================================== 初始化

func setup(p_mission_id: String, p_hud) -> void:
	match_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if BattleSaves.pending.is_empty():
		if not preload("res://scripts/expedition/rules.gd").active():BattleRequest.freeze_combat_context()
		for id in BattleRequest.combat_context.get("technologies", []):
			production_technology.unlock(str(id), "ally")
	_countries = {
		"ally": GameData.ra2_country_id(str(BattleRequest.skirmish_config.get("country", "美国"))),
		"enemy": GameData.ra2_country_id(str(BattleRequest.skirmish_config.get("enemy_country", "美国")))
	}
	BattleRequest.refresh_houses()
	for i in BattleRequest.skirmish_config.get("houses",[]).size():
		_countries[BattleRequest.Houses.id(i)] = GameData.ra2_country_id(BattleRequest.skirmish_config.houses[i].country)
	mission = GameData.get_mission(p_mission_id)
	if BattleRequest.skirmish:
		mission = GameData.make_skirmish_mission(BattleRequest.skirmish_config)
	if mission.is_empty() and GameData.missions.size() > 0:
		mission = GameData.get_mission("m01")
	var map_theater := str(NativeMaps.data(map_layout()).get("theater", mission.get("theater", "TEMPERATE")))
	RA2Art.set_building_theater(map_theater)
	map_size = float(mission.get("map_size", 2400))
	enemy_faction = str(mission.get("enemy_faction", "swarm"))
	skirmish = (mission.get("skirmish", false) == true)
	if BattleSaves.pending.is_empty() and BattleRequest.extensions_enabled() and production_technology.is_unlocked("production_recipes_2","ally"):
		var orders=BattleRequest.combat_context.get("opening_orders",[])
		if orders is Dictionary:
			orders=preload("res://scripts/rules/opening_order_plans.gd").selected_orders({"opening_orders":orders})
		if not orders.is_empty():allied_state.opening_orders_pending=orders.duplicate()
	skirmish_enemy_base = str(mission.get("skirmish_enemy_base", "allied"))
	skirmish_difficulty = int(mission.get("skirmish_difficulty", 1))
	waves = mission.get("waves", [])
	prepare_time = float(mission.get("prepare_time", 30))
	endless = (mission.get("endless", false) == true)
	hud = p_hud

	var deploy: float = BattleRequest.combat_bonuses().get("deploy_bonus", 0.0)
	funds = float(mission.get("starting_funds", 4000)) * (1.0 + float(deploy))
	enemy_funds = house_starting_funds("enemy") if skirmish else float(mission.get("starting_funds", 4000))

	_build_world()
	preload("res://scripts/world/civilian_sites.gd").populate(self)
	if mission.get("fog_of_war", false) == true:
		fog = preload("res://scripts/world/fog_of_war.gd").new()
		add_child(fog)
		fog.setup(self)
		if skirmish: Events.emit_message("战争迷雾：金色雷达标记为已知矿区；敌军需要侦察。", Color(0.9, 0.8, 0.5))
	gm_unit_lab=BattleRequest.skirmish and BattleRequest.skirmish_config.get("gm_unit_lab",false)==true
	if skirmish and not gm_unit_lab:
		if BattleSaves.pending.is_empty(): MetaProgress.Academy.started(MetaProgress, self)
		_spawn_skirmish_ai()
	_register_gm_hooks()
	if gm_unit_lab:
		for unit in units:
			if is_instance_valid(unit) and unit.side=="enemy":unit.order_stop();unit.fire_stance="none"
		hud.call_deferred("_toggle_gm")
	BattleClock.set_speed(DisplayPreferences.battle_speeds[0])

	Events.funds_changed.emit(funds)
	Events.emit_message("★ %s — %s" % [mission.get("name", ""), mission.get("subtitle", "")], Color(0.7, 0.85, 1.0))
	Events.emit_message(str(mission.get("brief", "")), Color(0.8, 0.85, 0.9))
	if mission.get("id")==TimeShift.ID:
		TimeShift.setup(self)
		return
	if mission.get("id")==AlliedFinale.ID:
		AlliedFinale.setup(self)
		return
	if mission.get("id")==AlliedFirst.ID:
		AlliedFirst.setup(self)
		return
	if mission.get("id") == Hollywood.ID:
		if BattleSaves.pending.is_empty(): Hollywood.setup(self)
		return
	Events.emit_message("准备时间 %d 秒，抓紧建造防线。" % int(ceil(BattleClock.real_seconds(prepare_time))), Color(1.0, 0.85, 0.5))
	if mcv_opening():
		Events.emit_message("基地车开局：按 J 展开建造场 → 电厂 → 矿场 → 选中矿场制造矿车。", Color(0.6, 0.95, 0.7))
	wave_timer = prepare_time
	if mission.get("id")==HeadGames.ID and BattleSaves.pending.is_empty(): HeadGames.start_film(self)

const AlliedFirst = preload("res://scripts/world/allied_first.gd")
const AlliedFinale = preload("res://scripts/world/allied_finale.gd")
const TimeShift = preload("res://scripts/world/time_shift.gd")
const HeadGames = preload("res://scripts/world/head_games.gd")
const Hollywood = preload("res://scripts/world/hollywood_mission.gd")
const CampaignMarks = preload("res://scripts/ui/campaign_objective_marks.gd")

func mcv_opening() -> bool:
	return skirmish and not BattleRequest.extensions_enabled() and mission.get("opening", "") == "mcv"

func _build_world() -> void:
	ground = GroundScript.new()
	if NativeMaps.has(map_layout()):ground.native_id=map_layout()
	ground.set("map_size", map_size)
	ground.z_index = DepthLayers.GROUND   # 最底层：否则会盖住 Battle 自身的框选/建造预览绘制
	add_child(ground)
	ground.setup(map_size)

	effects_root = Node2D.new()
	effects_root.add_to_group("effects_root")
	effects_root.z_index = DepthLayers.FX         # 特效恒在实体之上（RA2 命中/炮口动画画在单位之上）
	add_child(effects_root)

	projectiles_root = Node2D.new()
	projectiles_root.add_to_group("projectiles_root")
	projectiles_root.z_index = DepthLayers.PROJECTILE
	add_child(projectiles_root)

	hp_overlay = Node2D.new()
	hp_overlay.name = "HpOverlay"
	hp_overlay.z_index = DepthLayers.WORLD_HUD            # 血条/标签恒在所有实体（含建筑）之上，低于弹道/特效
	add_child(hp_overlay)
	hp_overlay.draw.connect(_draw_hp_overlay)
	move_order_overlay = Node2D.new()
	move_order_overlay.name = "MoveOrderOverlay"
	move_order_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	move_order_overlay.z_index = DepthLayers.ORDER_PREVIEW
	add_child(move_order_overlay)
	move_order_overlay.draw.connect(func():
		MovementOrderPreview.paint(move_order_overlay, MovementOrderPreview.routes(self))
		ReaperSplit.paint(move_order_overlay,self)
		Unit.YRTalents.paint_reverse(move_order_overlay,self)
		var ab:=_range_preview_ability()
		if ab!=null and ab.id==Unit.Convoy.Cards.PRESS:
			var miner=selected_skill_unit()
			var aim:Vector2=get_global_mouse_position() if cast_slot>=0 else miner.position+Vector2.from_angle(miner.hull_angle)*Unit.Convoy.Cards.PRESS_RANGE
			Unit.Convoy.Cards.draw_press_preview(move_order_overlay,miner,aim,cast_slot>=0))
	if mission.get("id") in [HeadGames.ID, TimeShift.ID, Hollywood.ID, AlliedFirst.ID, AlliedFinale.ID] or mission.get("objectives", {}).has("destroy_hives"):
		var objective_canvas := CanvasLayer.new()
		objective_canvas.name = "CampaignObjectiveCanvas"
		objective_canvas.layer = 1 # Above world and fog, below the HUD and films.
		add_child(objective_canvas)
		var objectives := Node2D.new()
		objectives.name = "Markers"
		objective_canvas.add_child(objectives)
		objectives.draw.connect(func(): CampaignMarks.paint(objectives,self))
		get_viewport().size_changed.connect(objectives.queue_redraw)
		campaign_mark_overlay = objectives

	enemy_root = Node2D.new()
	add_child(enemy_root)

	camera = Camera2D.new()
	camera.process_callback=Camera2D.CAMERA2D_PROCESS_IDLE
	Iso.apply_to(camera, view_zoom)           # 红警2 式 2:1 等距（K=0.5）
	# Use our HUD-aware clamp only. Native viewport limits would clamp again
	# and leave edge tiles behind the sidebar, especially under iso rotation.
	camera.position = player_start()
	camera.enabled = true
	add_child(camera)
	camera.make_current()
	center_on(player_start())

	# Keep the inland lake first so the repair hut bridges it, not the fleet route.
	var coast_x := map_size * 0.5 + 260.0
	if skirmish:
		water_rects = [
			Rect2(map_size * 0.09, map_size * 0.26, map_size * 0.17, map_size * 0.12),
			Rect2(coast_x, map_size * 0.04, map_size - coast_x, map_size * 0.92),
		]
		if map_layout() != "coast":
			var width := 0.14 if map_layout() == "crossings" else 0.32
			water_rects = [Rect2(map_size * (1.0 - width) * 0.5, 0, map_size * width, map_size)]
	if skirmish and Maps.custom(map_layout()):water_rects=Maps.water(map_layout(),map_size)
	if NativeMaps.has(map_layout()):water_rects=NativeMaps.water(map_layout())
	# Step C 阶段2：开局建筑对齐红警2 盟军（建造厂 + 发电厂 + 兵营 + 矿场）
	# 矿场必须开局就有：否则采矿车满仓后无坞可进，表现为“回不动”（T7）。
	var hq_pos := player_start()
	var starting_refinery = null
	if mission.get("id") in [Hollywood.ID,HeadGames.ID,TimeShift.ID,AlliedFinale.ID,AlliedFirst.ID]:
		pass # The airport convoy arrives during the briefing.
	elif mcv_opening():
		hq_pos = snap_build_pos(Vector2(minf(map_size * 0.56, coast_x - 140.0), map_size * 0.84) if map_layout() == "coast" and not BattleRequest.skirmish_config.get("houses",[]).any(func(row):return row.has("spawn")) else hq_pos)
		var mcv = spawn_unit(roster_id("AMCV", "ally"), "ally", hq_pos)
		select_unit(mcv, false)
		_emit_selection()
		center_on(hq_pos)
	else:
		_place_building(roster_id("GACNST", "ally"), "ally", hq_pos, true)
		if NativeMaps.has(map_layout()):
			for row in [["GAPOWR",Vector2(-170,40)],["GAPILE",Vector2(170,30)],["GAREFN",Vector2(-190,190)]]:
				var bid:String=roster_id(row[0],"ally")
				var anchor: Vector2 = hq_pos + row[1]
				var site := Vector2.INF
				if preload("res://scripts/expedition/rules.gd").active():
					var miner_id := roster_id("CMIN", "ally") if row[0] == "GAREFN" else ""
					site = NativeMaps.find_base_site(self, anchor + (row[1] as Vector2).normalized() * 100.0, bid, miner_id)
				if not site.is_finite():
					site = NativeMaps.find_base_site(self, anchor, bid)
				if site.is_finite():
					var created=_place_building(bid,"ally",site,true)
					if row[0]=="GAREFN":starting_refinery=created
		else:
			_place_building(roster_id("GAPOWR", "ally"), "ally", hq_pos + Vector2(-170, 40), true)
			_place_building(roster_id("GAPILE", "ally"), "ally", hq_pos + Vector2(170, 30), true)
			starting_refinery = _place_building(roster_id("GAREFN", "ally"), "ally", hq_pos + Vector2(-190, 190), true)

	var nodes := [
		Vector2(map_size * 0.22, map_size * 0.78),
		Vector2(map_size * 0.78, map_size * 0.78),
		Vector2(map_size * 0.30, map_size * 0.52),
		Vector2(map_size * 0.70, map_size * 0.52),
	]
	if skirmish:
		nodes[1] = Vector2(map_size * 0.36, map_size * 0.66)
		nodes[3] = Vector2(map_size * 0.50, map_size * 0.61)
		if map_layout() != "coast":
			nodes = [Vector2(0.14,0.70)*map_size, Vector2(0.25,0.63)*map_size, Vector2(0.21,0.38)*map_size, Vector2(0.77,0.61)*map_size]
	if skirmish and Maps.custom(map_layout()):nodes=Maps.points(map_layout(),"ore",map_size)
	if NativeMaps.has(map_layout()):nodes=[]
	# (T11) RA2 式「散出来」：每个矿点在地图上铺开成一片散布的小矿格（见 _scatter_ore）。
	for n in nodes:
		if _scatter_ore(n) == 0:
			_spawn_ore_tile(n, ORE_CLUSTER_TOTAL_AMOUNT, ORE_TILE_SEP)   # 兜底：地形太挤也不留空矿

	_apply_country_bonus(hq_pos)

	var both := false
	for w in waves:
		if str(w.get("from", "")) == "both":
			both = true
	if both:
		spawn_points = [Vector2(map_size * 0.2, map_size * 0.12), Vector2(map_size * 0.8, map_size * 0.12)]
	else:
		spawn_points = [Vector2(map_size * 0.5, map_size * 0.12)]
	if skirmish:
		_build_skirmish_enemy_base()
	elif mission.get("id") == HeadGames.ID:
		HeadGames.setup(self)
	elif mission.get("id") not in [Hollywood.ID,TimeShift.ID,AlliedFinale.ID,AlliedFirst.ID]:
		for p in spawn_points:
			_place_building("swarm_hive", "enemy", p, true)
		# RA3 式水域：地图两侧的湖泊（地面单位不可通行，但允许水上建造）
		water_rects = [
			Rect2(map_size * 0.06, map_size * 0.24, map_size * 0.20, map_size * 0.14),
			Rect2(map_size * 0.74, map_size * 0.24, map_size * 0.20, map_size * 0.14),
			# 玩家基地旁的小港：让船坞在建造半径内可落地，海军不成为“有数据无入口”。
			Rect2(map_size * 0.35, map_size * 0.68, map_size * 0.14, map_size * 0.10),
		]

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260930
	for i in range(0 if NativeMaps.has(map_layout()) else (32 if skirmish and Maps.custom(map_layout()) else 14)):
		var pos := Vector2(rng.randf_range(0.08, 0.92) * map_size, rng.randf_range(0.22, 0.66) * map_size)
		if pos.distance_to(hq_pos) < 300.0:
			continue
		if _point_in_water(pos) or (skirmish and preload("res://scripts/world/civilian_sites.gd").reserve_world_crossings(self,pos)):
			continue
		if skirmish and Maps.custom(map_layout()):
			var landmarks:Array=Maps.points(map_layout(),"houses",map_size)+Maps.points(map_layout(),"oil",map_size)+Maps.points(map_layout(),"ore",map_size)+Maps.points(map_layout(),"enemy_ore",map_size)+Maps.points(map_layout(),"gems",map_size)
			if landmarks.any(func(p):return p.distance_to(pos)<180):continue
		var skip := false
		for sp in spawn_points:
			if pos.distance_to(sp) < 260.0:
				skip = true
		if skip:
			continue
		var obs = ObstacleScript.new()
		obs.position = pos
		obs.radius = rng.randf_range(34, 62)
		obs.z_index = DepthLayers.GROUND_OBJ   # 障碍贴地：恒在地面实体之下
		add_child(obs)

	# 寻路服务（必须在障碍与建筑都就位后再建）
	# A contested central gem field; base ore and extension economy stay unchanged.
	if skirmish and Maps.custom(map_layout()):
		for point:Vector2 in Maps.points(map_layout(),"gems",map_size):_scatter_ore(point,4,3,"gems")
	elif skirmish and not NativeMaps.has(map_layout()) and not BattleRequest.extensions_enabled():
		_scatter_ore(Vector2(0.5 if map_layout() == "coast" else 0.28, 0.5) * map_size, 3, 2, "gems")
	if NativeMaps.has(map_layout()):NativeMaps.populate(self)
	path_service = PathService.new()
	path_service.native_map_id=map_layout() if NativeMaps.has(map_layout()) else ""
	# Keep route edges on the same cell boundaries used by native terrain collision.
	path_service.configure(map_size, NativeMaps.CELL if NativeMaps.has(map_layout()) else PathService.CELL)
	path_service.set_water(water_rects)
	# 港口水域可能压在随机矿点上：删掉落水矿，避免采矿车锁定不可达目标。
	for rn in get_tree().get_nodes_in_group("resource_nodes"):
		if is_instance_valid(rn) and path_service.in_water(rn.global_position):
			rn.queue_free()
	add_child(path_service)
	_refresh_pathing()
	if mission.get("id")==HeadGames.ID: HeadGames.arrive(self)
	# Initial miners use the same collision-checked exit as manufactured miners.
	# Fixed offsets next to the HQ can place their bodies inside its footprint.
	for i in range(2):
		if starting_refinery == null or starting_refinery.building_id == "YAREFN":
			break
		var exit_pos: Vector2 = starting_refinery._spawn_point(roster_id("CMIN"))
		if exit_pos != Vector2.INF:
			spawn_unit(roster_id("CMIN", "ally"), "ally", exit_pos, starting_refinery)

## 水域列表（世界坐标矩形）——地面单位不可通行，允许水上建造。
var _slave_clock := 0.0
var water_rects: Array = []

## 遭遇战：在顶部中心搭建敌方基地（盟军镜像或虫群巢穴）+ 敌方矿区。
func _build_skirmish_enemy_base() -> void:
	var spots:=BattleRequest.Houses.starts(map_layout(),map_size)
	var enemy_start:=spots[BattleRequest.house_spawn(1)]
	var cx:=enemy_start.x
	var cy:=enemy_start.y
	if not BattleRequest.house_teams.is_empty():
		enemy_base_center = enemy_start
		allied_state.house_ai = {}
		var rows: Array = BattleRequest.skirmish_config.houses
		for i in range(1,rows.size()):
			var owner := BattleRequest.Houses.id(i)
			var center: Vector2 = spots[BattleRequest.house_spawn(i)]
			allied_state.house_ai[owner] = {"center":center,"think":float(i),"attack":20.0}
			if owner != "enemy": allied_state.house_ai[owner].funds = house_starting_funds(owner)
			if rows[i].country == "虫群巢穴":
				_place_building("swarm_hive",owner,center,true)
			elif mcv_opening():
				var vehicle = spawn_unit(roster_id("AMCV",owner),owner,snap_build_pos(center))
				vehicle.order_stop()
			else:
				_build_house_base(center,owner)
		return
	enemy_base_center = Vector2(cx, cy)
	spawn_points = [enemy_base_center + Vector2(0.0, 150.0)]
	var ore := map_size * 0.10
	var ore_center:Vector2=spots[1]
	var ore_points := [Vector2(ore_center.x - ore * 2.4, ore_center.y + ore * 0.5), Vector2(ore_center.x - ore * 1.6, ore_center.y - ore * 0.8), Vector2(ore_center.x, ore_center.y + ore * 2.6)]
	if map_layout() != "coast": ore_points = [Vector2(.88,.28)*map_size, Vector2(.74,.08)*map_size, Vector2(.78,.41)*map_size]
	if Maps.custom(map_layout()):ore_points=Maps.points(map_layout(),"enemy_ore",map_size)
	if NativeMaps.has(map_layout()):ore_points=[]
	for p in ore_points:
		_add_skirmish_ore(p)
	if skirmish_enemy_base == "swarm":
		_place_building("swarm_hive", "enemy", Vector2(cx, cy), true)
		return
	if mcv_opening():
		var mcv = spawn_unit(roster_id("AMCV", "enemy"), "enemy", snap_build_pos(enemy_base_center))
		mcv.order_stop()
		return
	_build_house_base(Vector2(cx,cy),"enemy")

func _build_house_base(center: Vector2, owner: String) -> void:
	var cx := center.x
	var cy := center.y
	var layout := [
		["GACNST", Vector2(0.0, 0.0)],
		["GAPOWR", Vector2(-170.0, 30.0)],
		["GAPOWR", Vector2(170.0, 30.0)],
		["GAREFN", Vector2(-280.0, 190.0)],
		["GAPILE", Vector2(165.0, 200.0)],
		["GAWEAP", Vector2(0.0, 250.0)],
		["GAPILL", Vector2(-360.0, 330.0)],
		["GAPILL", Vector2(165.0, 370.0)],
	]
	for row in layout:
		var bid := roster_id(row[0], owner)
		var pos: Vector2 = Vector2(cx, cy) + (row[1] as Vector2)
		if map_layout() != "coast": pos.x = cx - row[1].x
		if Maps.custom(map_layout()) and row[0]=="GAREFN":pos=Vector2(cx,cy+440)
		if not NativeMaps.has(map_layout()) and BattleRequest.house_spawn(1)==0:pos.y=2.0*cy-pos.y
		if NativeMaps.has(map_layout()):pos=NativeMaps.find_base_site(self,pos,bid)
		if pos.is_finite() and _skirmish_spot_ok(pos, 78.0):
			_place_building(bid, owner, pos, true)

## (T11) RA2 式矿体：由中心点向外规则抖动铺开成一小片可独立采集的矿格。
## 逻辑仍是多个 ResourceNode，但密集相接、格心均匀错落 → 视觉上连成「一整片散矿」而非孤立圆堆。
## 矿体铺展范围由格数控制；保持单格尺寸和间距，避免把矿石图案一起放大。
const ORE_TILE_SPACING := 46.0   # 相邻矿格中心距（逻辑毛径 ≈ 0.90×46 ≈ 41px）
const ORE_TILE_SEP := 38.0       # 格与格之间的最小圆心距（略小于间距 46，邻格轻微相接成片）
const ORE_TILE_WIDE := 6         # 横（iso 纵向）格数
const ORE_TILE_HIGH := 5         # 纵（iso 横向）格数
const ORE_CLUSTER_MIN_NODES := 3
const ORE_CLUSTER_TOTAL_AMOUNT := 6000.0   # 每处矿点总储量守恒

## 在全图铺开一处矿体：以 center 为中心生成一片矿格。
## 会跳过水域 / 已占建筑底盘 / 障碍 / 地图边缘外的格子（保证可采、可寻路）。
func _scatter_ore(center: Vector2, tiles_wide: int = ORE_TILE_WIDE, tiles_high: int = ORE_TILE_HIGH, resource_kind: String = "ore") -> int:
	var half_x := float(tiles_wide - 1) * 0.5
	var half_y := float(tiles_high - 1) * 0.5
	var spacing := ORE_TILE_SPACING
	var sep := ORE_TILE_SEP
	var margin := spacing * 0.5 + 4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x) * 73856093 + int(center.y) * 19349663 + tiles_wide * 83492791 + tiles_high * 2654435761
	var occupied: Array = []
	for row in range(tiles_high):
		for col in range(tiles_wide):
			var base := Vector2((float(col) - half_x) * spacing, (float(row) - half_y) * spacing)
			var jitter := Vector2(rng.randf_range(-sep, sep), rng.randf_range(-sep, sep)) * 0.18
			var p: Vector2 = center + base + jitter
			if p.x < margin or p.y < margin or p.x > map_size - margin or p.y > map_size - margin:
				continue
			if _point_in_water(p):
				continue
			if _ore_tile_blocked(p, sep):
				continue
			var bad := false
			for o in occupied:
				if p.distance_to(o) < sep:
					bad = true
					break
			if bad:
				continue
			occupied.append(p)
	# for 循环结束：统计可用格位
	var count: int = occupied.size()
	if count < ORE_CLUSTER_MIN_NODES:
		return 0                          # 地形太挤：放弃，由调用方退回单个大矿点
	var each: float = ORE_CLUSTER_TOTAL_AMOUNT / float(count)
	for gp in occupied:
		_spawn_ore_tile(gp, each, sep, resource_kind)
	return count

## 指定位置是否已被建筑 / 障碍占据（避免矿格长进建筑底盘或岩体里）。
func _ore_tile_blocked(p: Vector2, sep: float) -> bool:
	for b in buildings:
		if not is_instance_valid(b):
			continue
		var bp := footprint_of(b)
		if bp.size() >= 3 and Placement.circle_hits_poly(bp, p, sep, b.global_position):
			return true
	for o in get_tree().get_nodes_in_group("obstacles") + get_tree().get_nodes_in_group("native_ore_drills"):
		if is_instance_valid(o) and o.global_position.distance_to(p) < float(o.get("radius")) + sep * 0.85:
			return true
	return false

## 生成一枚小矿格：逻辑小（radius = sep*0.90，单格储量 = 总量/格数），视觉与碰撞同步缩小。
func _spawn_ore_tile(p: Vector2, amount_each: float, sep: float, resource_kind: String = "ore") -> void:
	var rn = ResourceNodeScript.new()
	rn.position = p
	rn.radius = sep * 0.90
	rn.resource_kind = resource_kind
	rn.max_amount = amount_each / GameData.resource_value("ore")
	rn.amount = rn.max_amount
	rn.z_index = DepthLayers.GROUND_OBJ
	add_child(rn)

func _add_skirmish_ore(pos: Vector2) -> void:
	# 同样铺成一片散布矿体；万一地形太挤，退回单个大矿点，避免出现无矿可采的基地。
	if _scatter_ore(pos) == 0:
		_spawn_ore_tile(pos, 6000.0, 30.0)

func _skirmish_spot_ok(pos: Vector2, rad: float) -> bool:
	for off in [Vector2.ZERO, Vector2(rad, 0.0), Vector2(-rad, 0.0), Vector2(0.0, rad), Vector2(0.0, -rad)]:
		if _point_in_water(pos + off):
			return false
	for b in buildings:
		if is_instance_valid(b) and b.global_position.distance_to(pos) < rad + 55.0:
			return false
	return true

func ai_decisions(side: String) -> Dictionary:
	return allied_state.get("house_ai",{}).get(side,allied_state)

func _spawn_skirmish_ai() -> void:
	if not BattleRequest.house_teams.is_empty():
		var homes := {"ally":player_start()}
		for owner in allied_state.house_ai: homes[owner] = allied_state.house_ai[owner].center
		for i in range(1,BattleRequest.skirmish_config.houses.size()):
			var owner := BattleRequest.Houses.id(i)
			var ai = preload("res://scripts/world/house_ai.gd").new()
			ai.house_id = owner
			ai.homes = homes
			var faction := "swarm" if BattleRequest.skirmish_config.houses[i].country=="虫群巢穴" else roster_faction(owner)
			ai.setup(self,BattleRequest.house_difficulty(owner),faction,homes[owner])
			ai.rally = ai.base_center.move_toward(Vector2.ONE * map_size * 0.5, 180.0)
			house_controllers[owner] = ai
			add_child(ai)
			for b in buildings:
				if b.side != owner or not b.is_refinery() or b.building_id == "YAREFN": continue
				var miner_id := roster_id("CMIN",owner)
				var exit: Vector2 = b._spawn_point(miner_id)
				if exit.is_finite(): spawn_unit(miner_id,owner,exit,b)
		_capture_enemy_music_roster()
		return
	var ai = load("res://scripts/world/skirmish_ai.gd").new()
	ai.name = "SkirmishAI"
	add_child(ai)
	ai.setup(self, skirmish_difficulty, skirmish_enemy_base)
	skirmish_ai = ai
	if skirmish_difficulty == 6 and BattleSaves.pending.is_empty(): ai.Brutal.opening(ai)
	for b in buildings:
		if is_instance_valid(b) and b.side == "enemy" and b.is_refinery() and b.building_id != "YAREFN":
			var exit: Vector2 = b._spawn_point(roster_id("CMIN", "enemy"))
			if exit != Vector2.INF:
				spawn_unit(roster_id("CMIN", "enemy"), "enemy", exit, b)
	_capture_enemy_music_roster()

func _capture_enemy_music_roster() -> void:
	enemy_initial_scoreable = 0
	for actor in units + buildings:
		if not is_instance_valid(actor) or actor.side == "neutral" or BattleRequest.friendly("ally", actor.side): continue
		if actor.special.get("house_eliminated", false) or AlliedAbilities.flag(actor, "DontScore"): continue
		enemy_initial_scoreable += 1

func _point_in_water(p: Vector2) -> bool:
	if NativeMaps.has(map_layout()):return (path_service.native_flags(p) if path_service != null else NativeMaps.flags(map_layout(),p))==2
	for r in water_rects:
		if (r as Rect2).has_point(p):
			return true
	return false

## 给定世界点是否在水域内（建筑/建造判定用）。
func on_water(p: Vector2) -> bool:
	return _point_in_water(p)

## 用当前障碍 + 建筑整体重建通行网格
func _refresh_pathing() -> void:
	if path_service == null:
		return
	var blockers := _path_blockers()
	_has_crushable_fences = blockers.any(WallArt.crushable_fence)
	path_service.rebuild_terrain(blockers,allied_state.get("convoy_roads",[]))

func _path_blockers() -> Array:
	var blockers: Array = []
	for o in get_tree().get_nodes_in_group("obstacles") + get_tree().get_nodes_in_group("native_ore_drills"):
		blockers.append(o)
	for b in buildings:
		if is_instance_valid(b) and not b.is_dead() and not b.is_queued_for_deletion():
			blockers.append(b)
	return blockers

func _place_building(bid: String, side: String, pos: Vector2, instant: bool = false, placement_sound: bool = false, force_construction := false):
	if house_defeated(side): return null
	var bd := GameData.get_building(bid)
	if bd.is_empty():
		push_warning("Battle: 未知建筑 " + bid)
		return null
	var parent: Node = self if side == "ally" else enemy_root
	var b = BuildingScript.new()
	b.setup(bd, side, pos, self, instant, force_construction)
	preload("res://scripts/world/american_paradrop.gd").configure(b)
	parent.add_child(b)
	if skirmish and bid == "NAPSIS": b.add_to_group(&"psychic_sensors")
	if placement_sound:
		b.notify_construction_placed()
	b.z_index = DepthLayers.entity_z(b.depth_anchor(), map_size)
	buildings.append(b)
	invalidate_building_membership()
	# A synchronous planner can place a building before its next purchase.
	clear_ai_decision_cache()
	SupportSystems.join_charge(b)
	if path_service != null:
		if WallArt.crushable_fence(b): _has_crushable_fences = true
		path_service.add_blocker(b)
		record_route_change(Placement.aabb(footprint_of(b), b.global_position))
	# RA2 判定：落成后把压在新占地里的单位顶出去
	_push_units_out(b)
	# Only actual placement/deployment emits this one-shot, never map fixtures.
	# Player feedback stays audible at wide zoom; enemy work obeys fog and distance.
	if placement_sound and actor_visible_to("ally", b):
		Ra2Sfx.play("PlaceBuilding", Vector2.INF if side == "ally" else pos)
	if side == "ally" and not instant:
		Ra2Sfx.play_player_eva(self, "EVA_Building", 1000)
	Events.building_placed.emit(b)
	if not b.under_construction:
		strategic_site_completed(b, placement_sound)
	return b

func strategic_site_completed(site: Building, announce: bool) -> void:
	if announce and mission.get("id")==HeadGames.ID: HeadGames.superweapon_built(self,site)
	if not site.broadcasts_superweapon(): return
	if fog != null: fog.rebuild()
	if announce and site.is_allied_ai_storm():
		Ra2Sfx.play_player_eva(self, Ra2Sfx.SUPERWEAPON_DETECTED_VOICES["LightningStorm"], 0)
		Events.emit_message("友方天气控制器已建成", Color("#81dfff"))
		Events.emit_radar_ping(site.position, "friendly_support")
	elif announce and site.side != "neutral" and not BattleRequest.friendly("ally",site.side):
		var voice: String = Ra2Sfx.SUPERWEAPON_DETECTED_VOICES.get(site.sw_type(), "EVA_BeaconDetected")
		Ra2Sfx.play_player_eva(self, voice, 0)
		Events.emit_message("警报：敌方%s已建成，位置已标记" % site.display_name, Color("#ff9270"))
		Events.emit_radar_ping(site.position, "alert")

var allied_state: Dictionary = {}

const AI_UNIT_LIMIT := 64
# These are weapon or support flights, not independently commanded units.
const SUPPORT_FLIGHTS := ["V3ROCKET","DMISL","CMISL","BPLN","SPYP","PDPLANE","ASW","HORNET"]
var _population_frame := -1
var _living_by_house := {}
var _queued_by_house := {}

func invalidate_ai_population() -> void:
	_population_frame = -1

func ai_population_full(side: String, reserve_orders := true) -> bool:
	if not skirmish or gm_unit_lab or not BattleRequest.is_ai_house(side): return false
	if not reserve_orders and units.size() < AI_UNIT_LIMIT: return false
	var living := ai_living_count(side)
	return living + (int(_queued_by_house.get(side,0)) if reserve_orders else 0) >= AI_UNIT_LIMIT

func ai_production_full(side: String, uid: String, producer, reserve_orders := true) -> bool:
	return ai_population_full(side,reserve_orders) and not preload("res://scripts/world/ai_emergency_engineer.gd").permits(self,side,uid,producer,reserve_orders)

func ai_living_count(side: String) -> int:
	var frame := Engine.get_process_frames()
	if frame != _population_frame:
		_population_frame = frame
		_living_by_house.clear()
		_queued_by_house.clear()
		for actor in units:
			if actor_alive(actor) and actor.unit_id not in SUPPORT_FLIGHTS:
				_living_by_house[actor.side] = int(_living_by_house.get(actor.side,0))+1
		for factory in buildings:
			if actor_alive(factory) and not factory.production.is_empty():
				_queued_by_house[factory.side] = int(_queued_by_house.get(factory.side,0))+factory.production.size()
	return int(_living_by_house.get(side,0))

func update_ai_strength(side: String, living: int) -> void:
	var state := ai_decisions(side)
	if living>=32 and not state.get("campaign_started",false): state.campaign_due=true
	if living >= AI_UNIT_LIMIT:
		if not state.get("mobilized",false): state.full_sortie_due = true
		state.mobilized = true
		state.erase("replenishing")
	elif living * 2 <= AI_UNIT_LIMIT and state.erase("mobilized"):
		state.erase("full_sortie_due")
		state.replenishing = true

const REPLENISHMENT_BONUS := [0.0,0.05,0.15,0.30,0.35,0.50,0.55]

func ai_unit_build_factor(owner: String) -> float:
	return ai_build_factor(owner) * ai_replenishment_factor(owner)

func ai_replenishment_factor(owner: String) -> float:
	if skirmish and BattleRequest.is_ai_house(owner) and ai_decisions(owner).get("replenishing", false):
		return 1.0 + float(REPLENISHMENT_BONUS[BattleRequest.house_difficulty(owner)])
	return 1.0

func spawn_unit(uid: String, side: String, pos: Vector2, producer = null, from_queue := false):
	if house_defeated(side): return null
	if uid not in SUPPORT_FLIGHTS and ai_production_full(side,uid,producer,not from_queue): return null
	var ud := GameData.get_unit(uid)
	if uid in MetaProgress.Academy.Stars.IDS and producer==null and mission.get("id")=="yr_hollywood": ud=GameData.hollywood_cast.units[uid]
	if ud.is_empty():
		push_warning("Battle: 未知单位 " + uid)
		return null
	var data := ud.duplicate(true)
	if side == "enemy" and endless and endless_loop > 0:
		var sc: Dictionary = GameData.endless_scaling
		data["_hp_mult"] = pow(float(sc.get("hp_mult_per_loop", 1.18)), endless_loop)
		data["_attack_mult"] = pow(float(sc.get("damage_mult_per_loop", 1.08)), endless_loop)
	var u = UnitScript.new()
	u.setup(data, side, pos)
	if from_queue and side == "ally" and preload("res://scripts/expedition/rules.gd").active():
		u.special[preload("res://scripts/expedition/reinforcement_plan.gd").LOCAL_PRODUCTION] = true
	u._combat_world = self
	var parent: Node = self if side == "ally" else enemy_root
	parent.add_child(u)
	u.z_index = DepthLayers.entity_z(pos, map_size)
	units.append(u)
	invalidate_ai_population()
	preload("res://scripts/world/ai_emergency_engineer.gd").spawned(self,u,producer)
	if skirmish and not gm_unit_lab and units.size() >= 32 and BattleRequest.is_ai_house(side) and uid not in SUPPORT_FLIGHTS:
		update_ai_strength(side,ai_living_count(side))
	if NavalContact.SENSOR_CELLS.has(uid): u.add_to_group(NavalContact.sensor_group(side))
	if side == "enemy" and NavalContact.underwater_type(u): u.visible = actor_visible_to("ally", u)
	if is_instance_valid(producer) and producer is Building and ProductionExit.supported(producer):
		var departure := ProductionExit.direction(producer)
		if u.is_naval and producer.data.get("water_bound", false):
			departure = producer.depth_anchor().direction_to(u.position)
		u.hull_angle = departure.angle()
		u.turret_angle = u.hull_angle
		u.aim_dir = departure
	if uid in ["V3ROCKET", "DMISL", "CMISL", "BPLN", "SPYP", "PDPLANE"]:
		# MissileSpawn belongs to the air target group but cannot receive army orders.
		if u.is_in_group("combatants"): u.remove_from_group("combatants")
		return u
	u.logistics.assign_producer(producer)
	if mission.get("id") == HeadGames.ID and producer is Building and producer.special.has("head_games_wing"):
		HeadGames.assign_wing(u,int(producer.special.head_games_wing))
	if uid in MetaProgress.Academy.Stars.IDS and producer is Building and producer.building_id=="NEUTRALSTUDIO":
		MetaProgress.Academy.Stars.promote(u)
	if uid==Ra3Expansion.FUTURE and is_instance_valid(producer) and producer is Building:
		u.special.ra3_just_built=2.5 # AlliedFutureTank.JustBuiltTime, not generic spawn/restore.
	if is_instance_valid(producer) and producer is Building:
		if allied_state.get("training_" + side + "_" + str(AlliedAbilities.TRAINING_SITES.get(producer.building_id, producer.building_id)), false):
			u.credit_kill(u._vet_need, "enemy" if side == "ally" else "ally")
	if u.is_harvester and is_instance_valid(producer) and buildings.has(producer) \
			and producer.side == side and producer.is_refinery():
		u.home_base = producer
		u.harvest_state = "to_node"
	if side == "enemy" and BattleRequest.house_teams.is_empty():
		enemy_spawn_count += 1
		if is_instance_valid(producer) and buildings.has(producer) and is_instance_valid(skirmish_ai):
			skirmish_ai.unit_produced(u)
		elif not u.is_harvester:
			var goal := _player_target()
			if is_instance_valid(producer) and (producer.special.has("hollywood_wave") or producer.special.has("hollywood_retail_order")): preload("res://scripts/world/hollywood_bases.gd").dispatch(self,u,producer)
			elif skirmish: u.ai_order("move",goal,true)
			else: u.order_move(goal,true)
	elif house_controllers.has(side) and is_instance_valid(producer) and producer.side == side and buildings.has(producer):
		house_controllers[side].unit_produced(u)
	elif is_instance_valid(producer) and producer.side == side and buildings.has(producer):
		if u.is_harvester and producer.is_refinery():
			u.home_base = producer
			u.harvest_state = "to_node"
			Events.unit_spawned.emit(u)
			return u
		# 只有实际生产者能赋予集结命令，地图/技能生成不猜测附近工厂。
		var rally := rally_for(producer)
		if rally != Vector2.INF:
			u.order_move(rally, false)
		elif ProductionExit.supported(producer) and u.logistics.air_state != "parked":
			var assembly := ProductionExit.assembly(producer, u)
			if assembly != Vector2.INF: u.order_move(assembly, false)
	if producer is Building and mission.get("id") == AlliedFinale.ID and side == "enemy":
		AlliedFinale.AI.produced(self,u,producer)
	if from_queue and producer is Building and mission.get("id")==TimeShift.ID and producer.special.has("shift_global_order"):
		preload("res://scripts/world/time_shift_global_ai.gd").produced(self,u,producer)
	if from_queue and producer is Building and mission.get("id")==AlliedFirst.ID and producer.special.has(AlliedFirst.GlobalAI.ORDER):
		AlliedFirst.GlobalAI.produced(self,u,producer)
	if producer is Building and producer.special.has("s07_building_unit"):
		HeadGames.Orders.produced(self,u,producer)
	Events.unit_spawned.emit(u)
	return u

## Sort at the ground contact. Only a unit actually using a facility belongs above its deck.
func _update_depth_order() -> void:
	var axis := Vector2.DOWN.rotated(Iso.eff_angle())
	var center := Vector2.ONE * map_size * 0.5
	var extent := DepthLayers.projection_extent(axis, map_size)
	var overpass = ground.overpass if ground is Ground else null
	var factories:Array[Building]=[]
	for b in buildings:
		if is_instance_valid(b):
			b.z_index = DepthLayers.projected_z(b.depth_anchor(), axis, center, extent)
			if b.building_id=="GAWEAP":factories.append(b)
	for u in units:
		if not is_instance_valid(u): continue
		u.occluded_by_bridge = false
		if u.is_air_target():
			u.z_index = DepthLayers.AIR
			continue
		u.z_index = DepthLayers.projected_z(u.global_position, axis, center, extent)
		if overpass != null and not u.is_air:
			u.occluded_by_bridge = overpass.sort_unit(u)
		if u.is_naval and path_service.near_deck(u.global_position, u.radius + 48.0):
			u.z_index = DepthLayers.WATER + 1 + int(u.z_index / 24)
			if not u.is_amphibious and path_service.in_naval_water(u.position):
				u.occluded_by_bridge = path_service.near_deck(u.position)
		var deck = null
		if u.is_air and u.logistics.air_state in ["parked", "rearming"]:
			deck = u.logistics.home
		elif u.repairing and u.special.get("repair_stage") == "inside":
			deck = u.repair_depot
		elif u.special.has("repair_exit_depot"):
			deck = u.special.repair_exit_depot
		elif u.is_harvester and u.harvest_state == "unloading":
			deck = u.home_base
		if is_instance_valid(deck):
			u.z_index = maxi(u.z_index, deck.z_index + 1)
		elif u.is_air:
			# Non-airport aircraft can emerge through a factory roof hatch.
			for factory in factories:
				if Geometry2D.is_point_in_polygon(u.position-factory.position, factory.footprint_poly()):
					u.z_index = maxi(u.z_index, factory.z_index + 1)

func _player_target() -> Vector2:
	for b in buildings:
		if is_instance_valid(b) and b.is_hq and b.side == "ally" and actor_visible_to("enemy", b):
			return b.global_position
	return player_start()

func map_layout() -> String:
	return str(mission.get("map_layout", "coast"))

func player_start() -> Vector2:
	if mission.get("id")==AlliedFirst.ID and allied_state.get("allied_first",{}).has("assault_base_wp"): return AlliedFirst.wp(int(allied_state.allied_first.assault_base_wp))
	if mission.get("id")==TimeShift.ID:return TimeShift.wp(18)
	if mission.get("id") == HeadGames.ID: return Vector2(HeadGames.FIELD.data.start[0],HeadGames.FIELD.data.start[1])*NativeMaps.CELL
	if mission.get("id") in [Hollywood.ID,AlliedFinale.ID,AlliedFirst.ID]: return NativeMaps.start(map_layout())
	if skirmish:return BattleRequest.Houses.starts(map_layout(),map_size)[BattleRequest.house_spawn(0)]
	return Vector2(0.5 if map_layout() == "coast" else 0.22, 0.80) * map_size

# ================================================================== 资金

func add_funds(amount: float, silent: bool = false) -> void:
	funds += amount
	if not silent:
		Events.funds_changed.emit(funds)

func _deduct_player_funds(amount: float) -> void:
	funds -= amount
	Events.funds_changed.emit(funds)

func spend_funds(cost: float) -> bool:
	if GM.infinite_funds:
		return true
	if funds < cost:
		Events.emit_message("资金不足（需要 %d）" % int(cost), Color(1.0, 0.6, 0.5))
		Ra2Sfx.play_player_eva(self, "EVA_InsufficientFunds", 1500)
		return false
	_deduct_player_funds(cost)
	return true

func current_funds() -> float:
	return funds

const HeadEconomy = preload("res://scripts/world/head_games_economy.gd")

const ShiftEconomy = preload("res://scripts/world/time_shift_global_ai.gd")

func economy_owner(actor) -> String:
	if mission.get("id")==TimeShift.ID:return ShiftEconomy.economy_owner(self,actor)
	if mission.get("id")==AlliedFinale.ID and actor.side=="enemy" and actor.special.get("allied_finale_room")=="Yuri3" and allied_state.has("allied_finale"): return AlliedFinale.Branches.THIRD_ACCOUNT
	return HeadEconomy.owner(self,actor)

func funds_for(owner_side: String) -> float:
	if owner_side.begins_with(ShiftEconomy.ACCOUNT_PREFIX):return float(allied_state.get("s01_ai_accounts",{}).get(owner_side,0.0))
	if owner_side==AlliedFinale.Branches.THIRD_ACCOUNT and allied_state.has("allied_finale"): return float(AlliedFinale.Branches.ensure_account(self).funds)
	var accounts:Dictionary=allied_state.get("s07_accounts",{})
	if accounts.has(owner_side): return float(accounts[owner_side])
	if owner_side=="enemy" and not accounts.is_empty():
		var total:=0.0
		for amount in accounts.values(): total+=float(amount)
		return total
	if owner_side not in ["ally","enemy"] and allied_state.get("house_ai",{}).has(owner_side):
		return float(allied_state.house_ai[owner_side].funds)
	return funds if owner_side == "ally" else enemy_funds

func aircraft_capacity(owner_side: String) -> int:
	var count := 0
	for b in _buildings_for_side(owner_side):
		if is_instance_valid(b) and b.side == owner_side and b.hp > 0.0 and not b.under_construction:
			var raw: Dictionary = GameData.ra2_source_buildings.get(b.building_id, {}).get("extra", {})
			if str(raw.get("UnitReload", "")).to_lower() == "yes" and str(raw.get("Helipad", "")).to_lower() == "yes":
				count += int(raw.get("NumberOfDocks", 0))
	return count

func aircraft_population(owner_side: String) -> int:
	var count := 0
	for u in units:
		if is_instance_valid(u) and u.side == owner_side and u.hp > 0.0 and u.unit_id in ["ORCA", "BEAG"] and not preload("res://scripts/units/peregrine.gd").active(u):
			count += 1
	for b in buildings:
		if is_instance_valid(b) and b.side == owner_side and b.hp > 0.0:
			for uid in b.production:
				if uid in ["ORCA", "BEAG"]:
					count += 1
	return count

# Only earned income is difficulty-scaled. Refunds, relief and transfers use their actual amounts.
func credit_income(owner_side:String, amount:float, silent:=false, ore:=false) -> void:
	var multiplier := 1.0
	if owner_side != "ally" and (is_instance_valid(skirmish_ai) or BattleRequest.house_teams.has(owner_side)):
		var difficulty: int = skirmish_ai.difficulty if is_instance_valid(skirmish_ai) else BattleRequest.house_difficulty(owner_side)
		var level: int = mini(difficulty, 3)
		multiplier = [1.0, 1.0, 2.0, 4.0][level] if ore else [1.0, 1.0, 1.5, 2.0][level]
		if difficulty == 6: multiplier *= 2.0
	credit_side(owner_side, amount * multiplier, silent)
	if ore and owner_side == "ally" and amount > 0 and allied_state.has("expedition_tally"):
		allied_state.expedition_tally.ore += amount

func house_starting_funds(owner_side:String) -> float:
	var level:=BattleRequest.house_difficulty(owner_side)
	return funds*[1.0,2.0,3.0,6.0][mini(level,3)]*(1.0+float(BattleRequest.enemy_logistics(owner_side).deploy_bonus))

func ai_build_factor(owner_side: String) -> float:
	if owner_side != "ally" and (is_instance_valid(skirmish_ai) or BattleRequest.house_teams.has(owner_side)):
		var difficulty: int = skirmish_ai.difficulty if is_instance_valid(skirmish_ai) else BattleRequest.house_difficulty(owner_side)
		return [1.0, 1.0, 1.25, 1.5][mini(difficulty, 3)] * float(BattleRequest.enemy_logistics(owner_side).build_bonus)
	return 1.0

func credit_side(owner_side: String, amount: float, silent := false) -> void:
	if amount <= 0.0:
		return
	if owner_side==AlliedFinale.Branches.THIRD_ACCOUNT and allied_state.has("allied_finale"):
		AlliedFinale.Branches.ensure_account(self).funds += amount
	elif owner_side.begins_with(ShiftEconomy.ACCOUNT_PREFIX):
		var rooms:Dictionary=allied_state.get("s01_ai_accounts",{})
		if rooms.has(owner_side):rooms[owner_side]+=amount
	elif owner_side == "ally":
		add_funds(amount, silent)
	elif allied_state.get("s07_accounts",{}).has(owner_side):
		allied_state.s07_accounts[owner_side] += amount
	elif owner_side=="enemy" and allied_state.has("s07_accounts"):
		allied_state.s07_accounts[HeadEconomy.account(-1)] += amount
	elif owner_side not in ["ally","enemy"] and allied_state.get("house_ai",{}).has(owner_side):
		allied_state.house_ai[owner_side].funds += amount
	else:
		enemy_funds += amount

## Theft transfers existing balances, independent of free-purchase debug flags.
## Commit both sides before emitting the single player-HUD notification.
func transfer_spy_funds(victim: String, thief: String, percent: float, at: Vector2) -> float:
	if allied_state.has("s07_accounts") or victim.begins_with(ShiftEconomy.ACCOUNT_PREFIX) or thief.begins_with(ShiftEconomy.ACCOUNT_PREFIX):
		if victim==thief or not is_finite(percent): return 0.0
		var stolen:=transfer_drain_funds(victim,thief,funds_for(victim)*clampf(percent,0.0,1.0))
		var gain:=thief=="ally"
		if stolen>0.0:
			var tint:=Color(0.5,1,0.75) if gain else Color(1,0.5,0.4)
			Events.emit_message(("间谍渗透成功：窃取敌方资金 +%s" if gain else "敌方间谍渗透矿场：我方损失资金 -%s")%stolen,tint)
			Effects.spawn_text(at,("+%s" if gain else "-%s")%stolen,tint)
		elif gain: Events.emit_message("间谍已进入矿场，但该敌军基地没有可窃取的资金。")
		return stolen
	if not BattleRequest.house_teams.is_empty():
		if not BattleRequest.house_teams.has(victim) or not BattleRequest.house_teams.has(thief) or BattleRequest.friendly(victim,thief) or not is_finite(percent): return 0.0
		var stolen := funds_for(victim)*clampf(percent,0.0,1.0)
		if spend_side(victim,stolen): credit_side(thief,stolen)
		return stolen
	if victim == thief or victim not in ["ally", "enemy"] or thief not in ["ally", "enemy"] or not is_finite(percent):
		return 0.0
	var ally_before := funds
	var enemy_before := enemy_funds
	var amount := maxf(0.0, funds_for(victim)) * clampf(percent, 0.0, 1.0)
	if thief == "ally":
		enemy_funds -= amount
		funds += amount
	else:
		funds -= amount
		enemy_funds += amount
	var receipt := {"thief": thief, "victim": victim, "amount": amount,
		"ally_before": ally_before, "ally_after": funds, "enemy_before": enemy_before, "enemy_after": enemy_funds}
	allied_state["last_spy_transfer"] = receipt
	print("[SpyTransfer] ", JSON.stringify(receipt))
	if amount > 0.0: Events.funds_changed.emit(funds)
	var message := "间谍渗透成功：窃取敌方资金 +%s" % amount if thief == "ally" else "敌方间谍渗透矿场：我方损失资金 -%s" % amount
	if amount <= 0.0: message = "间谍已进入矿场，但敌方没有可窃取资金。" if thief == "ally" else "敌方间谍已进入矿场，我方没有资金损失。"
	Events.emit_message(message, Color(0.5, 1, 0.75) if thief == "ally" else Color(1, 0.5, 0.4))
	Effects.spawn_text(at, ("+%s" if thief == "ally" else "-%s") % amount, Color(0.5, 1, 0.75) if thief == "ally" else Color(1, 0.5, 0.4))
	return amount

## DiskDrain moves existing funds rather than purchasing anything.
func transfer_drain_funds(victim: String, thief: String, limit: float) -> float:
	var accounts:Dictionary=allied_state.get("s01_ai_accounts",{}) if victim.begins_with(ShiftEconomy.ACCOUNT_PREFIX) or thief.begins_with(ShiftEconomy.ACCOUNT_PREFIX) else allied_state.get("s07_accounts",{})
	if not accounts.is_empty():
		if not ((victim=="ally" and accounts.has(thief)) or (thief=="ally" and accounts.has(victim))): return 0.0
		var moved:=minf(limit,funds_for(victim))
		if moved<=0 or not spend_side(victim,moved): return 0.0
		credit_side(thief,moved,true)
		return moved
	var houses: Dictionary = allied_state.get("house_ai", {})
	if BattleRequest.friendly(victim, thief): return 0.0
	if victim not in ["ally", "enemy"] and not houses.has(victim): return 0.0
	if thief not in ["ally", "enemy"] and not houses.has(thief): return 0.0
	var amount := minf(limit, funds_for(victim))
	if amount <= 0.0: return 0.0
	if victim == "ally":
		funds -= amount
	elif victim == "enemy":
		enemy_funds -= amount
	else:
		houses[victim].funds -= amount
	credit_side(thief, amount, true)
	if victim == "ally" or thief == "ally": Events.funds_changed.emit(funds)
	return amount

func spend_side(owner_side: String, amount: float) -> bool:
	if owner_side.begins_with(ShiftEconomy.ACCOUNT_PREFIX):
		var rooms:Dictionary=allied_state.get("s01_ai_accounts",{})
		if not rooms.has(owner_side) or amount<0.0 or float(rooms[owner_side])+0.000001<amount:return false
		rooms[owner_side]=maxf(0.0,float(rooms[owner_side])-amount)
		return true
	if owner_side==AlliedFinale.Branches.THIRD_ACCOUNT and allied_state.has("allied_finale"):
		var bank := AlliedFinale.Branches.ensure_account(self)
		if amount<0.0 or bank.funds+0.000001<amount: return false
		bank.funds=maxf(0.0,bank.funds-amount)
		return true
	if owner_side == "ally":
		return try_spend(amount)
	if owner_side=="enemy" and allied_state.has("s07_accounts"): owner_side=HeadEconomy.account(-1)
	var accounts:Dictionary=allied_state.get("s07_accounts",{})
	if accounts.has(owner_side):
		if amount<0.0 or float(accounts[owner_side])+0.000001<amount: return false
		accounts[owner_side]=maxf(0.0,float(accounts[owner_side])-amount)
		return true
	if owner_side not in ["ally","enemy"] and allied_state.get("house_ai",{}).has(owner_side):
		if amount < 0 or funds_for(owner_side) < amount: return false
		allied_state.house_ai[owner_side].funds -= amount
		return true
	if amount < 0.0 or enemy_funds + 0.000001 < amount:
		return false
	enemy_funds = maxf(0.0, enemy_funds - amount)
	return true

# RA3：静默尝试扣款（供建造/生产分帧扣费用；不足则不扣、不刷屏）
func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if GM.infinite_funds:
		return true
	if funds < amount:
		return false
	_deduct_player_funds(amount)
	return true

# ================================================================== 电力（RA2）
# 事实源：rules.ini 建筑 Power= + [General]
#   MinLowPowerProductionSpeed=.5 / MaxLowPowerProductionSpeed=.8 / LowPowerPenaltyModifier=1
# 规则（照搬 ts-ra2 PowerTrait / ProductionTrait）：
#   · 发电量 = Σ ceil(Power × 当前血量%)（受损电站出力下降；未落成不计）
#   · 耗电量 = Σ |Power|（未落成不计）
#   · produced < drain → 低电：全阵营建造/生产变慢（1.0→0.8→0.5）
#   · 建筑 Powered=yes 低电时离线（ATESLA/GTGCAN/GAGAP/GAOREP/GASPYSAT）
const POWER_MIN_LOW_SPEED := 0.5      # MinLowPowerProductionSpeed
const POWER_MAX_LOW_SPEED := 0.8      # MaxLowPowerProductionSpeed
const POWER_PENALTY_MODIFIER := 1.0   # LowPowerPenaltyModifier

func _update_power() -> void:
	# Sum every owner in one traversal. Keep the player's historical dead-site
	# handling separate from AI grids and keep per-owner building order intact.
	var grids := {"enemy": {"produced": 0.0, "drain": 0.0, "low": false}}
	for owner in allied_state.get("house_ai", {}):
		grids[owner] = {"produced": 0.0, "drain": 0.0, "low": false}
	var prod := 0.0
	var drain := 0.0
	for entry in buildings:
		if not is_instance_valid(entry): continue
		var b:Building=entry
		if b.under_construction: continue
		var p := b.installed_power()
		var produced := ceilf(p * clampf(b.hp / maxf(1.0, b.max_hp), 0.0, 1.0)) if p > 0.0 else 0.0
		var consumed: float = -p if p < 0.0 else 0.0
		if b.side == "ally":
			prod += produced
			drain += consumed
		if b.hp > 0.0 and grids.has(b.side):
			var grid: Dictionary = grids[b.side]
			grid.produced += produced
			grid.drain += consumed
	if allied_state.has("allied_first"): prod+=float(allied_state.allied_first.get("auxiliary_power",0))
	grids.ally={"produced":prod,"drain":drain}
	preload("res://scripts/units/leizhu_station.gd").update(self,grids)
	prod=float(grids.ally.produced);grids.erase("ally")
	for grid: Dictionary in grids.values():
		grid.low = grid.produced < grid.drain - 0.001
	enemy_power = grids.enemy
	for owner in allied_state.get("house_ai", {}):
		if owner != "enemy": allied_state.house_ai[owner].power = grids[owner]
	if GM.infinite_power:
		prod = maxf(prod, drain)
	power_produced = prod
	power_drain = drain
	power_low = prod < drain - 0.001
	var blackout := side_power_blackout("ally")
	var effective_prod := 0.0 if blackout else prod
	var effective_low := power_low or blackout
	var sig := "%d|%d|%d|%d|%d" % [int(effective_prod), int(drain), int(effective_low), int(allied_state.get("leizhu_power",{}).get("ally",0)), int(blackout)]
	if sig != _power_sig:
		_power_sig = sig
		Events.power_changed.emit(effective_prod, power_drain, effective_low)
	if effective_low and not _eva_power_low_prev:
		Ra2Sfx.play_player_eva(self, "EVA_LowPower", 5000)
	_eva_power_low_prev = effective_low

## 低电时全阵营建造/生产速度乘数（RA2 ProductionTrait.computeLowPowerBuildSpeedModifier）。
func _side_power(owner_side: String) -> Dictionary:
	var produced := 0.0
	var drain := 0.0
	for b in _warm_owner_buildings(owner_side):
		if not is_instance_valid(b) or b.side != owner_side or b.hp <= 0.0 or b.under_construction:
			continue
		if b.power > 0.0:
			produced += ceilf(b.installed_power() * clampf(b.hp / maxf(1.0, b.max_hp), 0.0, 1.0))
		else:
			drain -= b.power
	if owner_side=="ally" and allied_state.has("allied_first"): produced+=float(allied_state.allied_first.get("auxiliary_power",0))
	produced+=preload("res://scripts/units/leizhu_station.gd").amount(self,owner_side,produced,drain)
	return {"produced": produced, "drain": drain, "low": produced < drain - 0.001}

func side_power_blackout(owner_side: String) -> bool:
	return float(allied_state.get("blackout_" + owner_side, 0.0)) > 0.0

func side_power_low(owner_side: String) -> bool:
	if side_power_blackout(owner_side): return true
	if owner_side not in ["ally","enemy"]: return allied_state.get("house_ai",{}).get(owner_side,{}).get("power",{}).get("low",false)
	return power_low if owner_side == "ally" else bool(enemy_power.low)

func power_build_factor(owner_side: String = "ally") -> float:
	if side_power_blackout(owner_side): return POWER_MIN_LOW_SPEED
	var low := side_power_low(owner_side)
	var grid: Dictionary = allied_state.get("house_ai",{}).get(owner_side,{}).get("power",enemy_power)
	var produced: float = power_produced if owner_side == "ally" else float(grid.produced)
	var drain: float = power_drain if owner_side == "ally" else float(grid.drain)
	if not low or drain <= 0.0:
		return 1.0
	var ratio := 1.0 - minf(1.0, produced / drain)
	var penalty := 0.3 * POWER_PENALTY_MODIFIER * ratio / 0.15
	return clampf(1.0 - penalty, POWER_MIN_LOW_SPEED, POWER_MAX_LOW_SPEED)

func power_stats() -> Dictionary:
	var blackout := side_power_blackout("ally")
	return {"produced": 0.0 if blackout else power_produced, "drain": power_drain,
		"low": power_low or blackout, "blackout": blackout,
		"hero_bonus": 0.0 if blackout else float(allied_state.get("leizhu_power", {}).get("ally", 0))}

# ================================================================== 主循环

func _flush_pose_redraws() -> void:
	for unit in pending_pose_redraws:
		if is_instance_valid(unit) and unit._combat_world == self and unit._pose_redraw_pending:
			unit._pose_redraw_pending = false
			unit.queue_redraw()
	pending_pose_redraws.clear()

var _opening_order_poll := 0.0

var yuriko_support:Unit

func _process(delta: float) -> void:
	if is_instance_valid(yuriko_support):preload("res://scripts/units/yuriko.gd").tick_deployment(self,delta)
	if allied_state.has("opening_orders_pending") and not allied_state.get("opening_orders_paused", false) and not paused and not ended and not get_tree().paused:
		_opening_order_poll -= delta
		if _opening_order_poll <= 0:
			_opening_order_poll = 1.0
			preload("res://scripts/rules/opening_order_plans.gd").submit(self)
	_flush_pose_redraws()
	if allied_state.get("area_repair", 0) != 0 and not paused and not ended and not get_tree().paused:
		_repair_poll -= delta
		if _repair_poll <= 0.0:
			_repair_poll = 0.5
			_tick_area_repair()
	if not ended and not paused and Music.context == "battle":
		_music_check_left -= delta
		if _music_check_left <= 0.0:
			var score_elapsed := 1.0 - _music_check_left
			_music_check_left = 1.0
			preload("res://scripts/world/battle_music_director.gd").tick(self, score_elapsed)
	attack_target_outlines.tick(self,delta)
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(10)
	ai_dispatch.pump(self)
	if not inspected_drones.is_empty(): _refresh_inspected_drones()
	if not selected_walls.is_empty():
		var retained := selected_wall_members()
		if retained.size() != selected_walls.size():
			for wall in selected_walls:
				if is_instance_valid(wall) and not retained.has(wall): wall.set_selected(false)
			selected_walls = retained
			if not selected_walls.has(selected_building):
				selected_building = selected_walls[0] if not selected_walls.is_empty() else null
			_emit_selection()
	if command_mode==ReaperSplit.ID and (not is_instance_valid(split_gunner) or not ReaperSplit.engaged(split_gunner)):arm_command("")
	formation_gesture.refresh(self)
	_update_camera(BattleClock.control_delta(delta))
	_update_order_marks(delta)
	_update_cast_flashes(delta)
	_ensure_visual_layers()
	if _attack_ranges_drawn or not build_range_preview.cells.is_empty() or not selected_units.is_empty() or is_instance_valid(selected_building) or dragging or armed_build != "" or command_mode != "" or cast_slot >= 0 or hover_ability >= 0 or not _order_marks.is_empty() or not _cast_flashes.is_empty():
		queue_redraw()
	if move_order_overlay != null:
		var active := not selected_units.is_empty() or command_mode == ReaperSplit.ID or command_mode == Unit.YRTalents.REVERSE or cast_slot >= 0 or hover_ability >= 0
		if active or _move_preview_was_active: move_order_overlay.queue_redraw()
		_move_preview_was_active = active
	if campaign_mark_overlay != null:
		campaign_mark_overlay.queue_redraw()
	if ended:
		return
	units = units.filter(func(u): return is_instance_valid(u))
	buildings = buildings.filter(func(b): return is_instance_valid(b))
	_update_depth_order()
	if hp_overlay != null:
		hp_overlay.queue_redraw()
	if allied_state.has("convoy_slugs"):preload("res://scripts/units/convoy_cards.gd").slugs_tick(self,delta)
	if allied_state.has("convoy_roads"):preload("res://scripts/units/convoy_cards.gd").roads_tick(self,delta)
	preload("res://scripts/units/soviet_specials.gd").tick_world(self, delta)
	Unit.TankHero.tick_world(self,delta)
	if allied_state.has("hero_reinforcements"):preload("res://scripts/rules/hero_reinforcements.gd").tick(self,delta)
	if allied_state.has("leizhu_reinforcements"):preload("res://scripts/rules/leizhu_reinforcements.gd").tick(self,delta)
	preload("res://scripts/units/expansion_cards.gd").world_tick(self,delta)
	preload("res://scripts/units/boris_fire_control.gd").world_tick(self,delta)
	if allied_state.has("peregrine_hunters"):preload("res://scripts/units/peregrine_cards.gd").world_tick(self,delta)
	if allied_state.has("peregrine_submunitions"):preload("res://scripts/units/peregrine_command.gd").world_tick(self,delta)
	LightningStorm.tick(self, delta)
	preload("res://scripts/core/yr_death_combat.gd").tick(self)
	_tick_structure_queue(delta)
	EconomyCycle.tick(self, delta)
	for side in ["ally", "enemy"]:
		var key: String = "blackout_" + side
		if allied_state.has(key): allied_state[key] = maxf(0.0, float(allied_state[key]) - delta)
	_update_power()
	if skirmish and not paused and ("YuriCountry" in _countries.values()):
		_slave_clock += delta
		if _slave_clock >= 0.5:
			preload("res://scripts/world/slave_mining.gd").tick(self,_slave_clock)
			_slave_clock = 0
	if mission.get("id")==TimeShift.ID:
		TimeShift.tick(self,delta)
	elif mission.get("id")==AlliedFinale.ID:
		AlliedFinale.tick(self,delta)
	elif mission.get("id")==AlliedFirst.ID:
		AlliedFirst.tick(self,delta)
	elif allied_state.has("hollywood"):
		if not paused: Hollywood.tick(self,delta)
	else:
		if mission.get("id") == HeadGames.ID and not paused:
			if allied_state.has("head_brief_stage"): HeadGames.briefing(self)
			HeadGames.attackers(self,delta)
			HeadGames.field_events(self,delta)
		if mission.get("id")!=HeadGames.ID: _update_waves(delta)
		_check_end()

## 窗口内的边缘带；越过原生窗口后的滚动由 edge_pointer_direction 单独处理。
func edge_pan_dir(mouse: Vector2, vp: Vector2) -> Vector2:
	if not Rect2(Vector2.ZERO, vp).has_point(mouse):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mouse.x < EDGE_SIDE_MARGIN:
		dir.x -= 1.0
	elif mouse.x >= vp.x - EDGE_SIDE_MARGIN:
		dir.x += 1.0
	if mouse.y < EDGE_MARGIN:
		dir.y -= 1.0
	elif mouse.y >= vp.y - EDGE_MARGIN:
		dir.y += 1.0
	return dir

## 屏幕位移 -> 相机世界位移。红警2 的平移坐标就是屏幕坐标，此处保持一致：
## 先按各轴缩放反算世界位移，再按相机旋转（等距 45°）转回世界系，得到真正的屏幕轴平移。
func screen_pan_to_world(screen_delta: Vector2) -> Vector2:
	var z := camera.zoom
	var sx: float = screen_delta.x / maxf(0.001, z.x)
	var sy: float = screen_delta.y / maxf(0.001, z.y)
	return Vector2(sx, sy).rotated(camera.rotation)

## Screen area available beside the command deck; always use its live layout.
func camera_play_rect() -> Rect2:
	var rect := get_viewport_rect()
	if is_instance_valid(hud) and is_instance_valid(hud.prod_panel) and hud.prod_panel.is_visible_in_tree():
		var panel: Rect2 = hud.prod_panel.get_global_rect()
		if panel.size.x > 0.0 and panel.position.x > rect.position.x and panel.position.x < rect.end.x:
			rect.size.x = maxf(1.0, panel.position.x - rect.position.x)
	return rect

func camera_focus_offset() -> Vector2:
	return screen_pan_to_world(camera_play_rect().get_center() - get_viewport_rect().get_center())

func camera_edge_pan_dir(mouse: Vector2) -> Vector2:
	var dir := edge_pan_dir(mouse, get_viewport_rect().size)
	if is_instance_valid(hud) and is_instance_valid(hud._topbar) and hud._topbar.is_visible_in_tree():
		var top: float = hud._topbar.get_global_rect().end.y
		var play := camera_play_rect()
		if Rect2(Vector2(play.position.x, top), Vector2(play.size.x, EDGE_SIDE_MARGIN)).has_point(mouse) and get_viewport_rect().has_point(mouse):
			dir.y = -1.0
	if is_instance_valid(hud) and is_instance_valid(hud.prod_panel) and hud.prod_panel.is_visible_in_tree():
		var panel:Rect2=hud.prod_panel.get_global_rect()
		# Only the exposed strip alongside the actual deck acts as a right edge.
		if Rect2(panel.position-Vector2(EDGE_SIDE_MARGIN,0),Vector2(EDGE_SIDE_MARGIN,panel.size.y)).has_point(mouse) and get_viewport_rect().has_point(mouse):
			dir.x=1.0
	return dir

var _camera_limit_key:=Vector4.INF
var _camera_limit_size:=Vector2.ZERO
var _camera_limit_polygon:=PackedVector2Array()
var _camera_limit_center:=Vector2.ZERO

# Translating the camera cannot change the intersection of the projected map
# and the playable viewport. Zoom, rotation, map and HUD size can.
func _refresh_camera_limits(play_size:Vector2) -> void:
	var key:=Vector4(map_size,camera.rotation,camera.zoom.x,camera.zoom.y)
	if key==_camera_limit_key and play_size==_camera_limit_size:return
	_camera_limit_key=key
	_camera_limit_size=play_size
	var polygon := PackedVector2Array()
	for point in [Vector2.ZERO, Vector2(map_size, 0), Vector2.ONE * map_size, Vector2(0, map_size)]:
		polygon.append(point.rotated(-camera.rotation) * camera.zoom)
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	var half := play_size * 0.5
	var margin := Vector2.ONE * 64.0
	var low := bounds.position + half - margin
	var high := bounds.end - half + margin
	# When the entire map fits, center it on that axis instead of reversing limits.
	for axis in 2:
		if low[axis] > high[axis]:
			low[axis] = bounds.get_center()[axis] - 0.001
			high[axis] = bounds.get_center()[axis] + 0.001
	var box := PackedVector2Array([low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)])
	var intersections := Geometry2D.intersect_polygons(polygon, box)
	_camera_limit_polygon=intersections[0] if not intersections.is_empty() else PackedVector2Array()
	_camera_limit_center=bounds.get_center()

func clamp_camera_to_map() -> void:
	if not is_instance_valid(camera):return
	var play:=camera_play_rect()
	_refresh_camera_limits(play.size)
	var offset:=screen_pan_to_world(play.get_center()-get_viewport_rect().get_center())
	var focus:=(camera.position+offset).rotated(-camera.rotation)*camera.zoom
	var allowed:=_camera_limit_polygon
	if allowed.is_empty():
		focus=_camera_limit_center
	elif not Geometry2D.is_point_in_polygon(focus,allowed):
		var nearest := allowed[0]
		var distance := INF
		for i in allowed.size():
			var point := Geometry2D.get_closest_point_to_segment(focus, allowed[i], allowed[(i + 1) % allowed.size()])
			var candidate := focus.distance_squared_to(point)
			if candidate < distance:
				distance = candidate
				nearest = point
		focus = nearest
	camera.position = screen_pan_to_world(focus) - offset

## 按屏幕位移平移视角并钳制到地图内。
func pan_screen(screen_delta: Vector2) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	follow_target = null   # 手动平移解除镜头跟随
	camera.position += screen_pan_to_world(screen_delta)
	clamp_camera_to_map()
	camera.force_update_scroll()

# Windows stops delivering client mouse-motion events outside the window.
# The production deck may also lead into the right window edge, without scrolling over its controls.
func edge_pointer_direction(mouse:Vector2, outside:Vector2, over_ui:bool) -> Vector2:
	if not world_input_enabled():
		_edge_from_world=false
		_edge_from_right_panel=false
		return Vector2.ZERO
	if outside!=Vector2.ZERO:
		return outside if _edge_from_world or (_edge_from_right_panel and outside.x>0.0) else Vector2.ZERO
	_edge_from_world=not over_ui and get_viewport_rect().has_point(mouse)
	_edge_from_right_panel=over_ui and get_viewport_rect().has_point(mouse) and _pointer_on_production_panel(mouse)
	return camera_edge_pan_dir(mouse) if _edge_from_world else Vector2.ZERO

func _pointer_on_production_panel(mouse: Vector2) -> bool:
	if not is_instance_valid(hud) or not is_instance_valid(hud.prod_panel) or not hud.prod_panel.is_visible_in_tree(): return false
	var control := get_viewport().gui_get_hovered_control()
	return control != null and hud.prod_panel.get_global_rect().has_point(mouse) \
		and (control == hud.prod_panel or hud.prod_panel.is_ancestor_of(control))

static func outside_window_direction(pixel:Vector2i, window_size:Vector2i) -> Vector2:
	return Vector2(-1 if pixel.x<0 else (1 if pixel.x>=window_size.x else 0),
		-1 if pixel.y<0 else (1 if pixel.y>=window_size.y else 0))

func _update_camera(delta: float) -> void:
	edge_panning=false
	if camera == null or not is_instance_valid(camera):
		return
	if not world_input_enabled():
		_edge_from_world=false
		_edge_from_right_panel=false
		return
	var dir := Vector2.ZERO
	var focus := get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit):
		if Input.is_action_pressed("ui_left"):
			dir.x -= 1.0
		if Input.is_action_pressed("ui_right"):
			dir.x += 1.0
		if Input.is_action_pressed("ui_up"):
			dir.y -= 1.0
		if Input.is_action_pressed("ui_down"):
			dir.y += 1.0
	# 贴边滚屏（拖拽平移进行中不触发；无头模式下鼠标恒为 (0,0)，跳过以免相机漂移）
	if edge_scroll_enabled and not formation_gesture.held and not _rmb_panning and DisplayServer.get_name() != "headless":
		var outside:=Vector2.ZERO
		var window:=get_window()
		if get_viewport()==window and window.mode in [Window.MODE_WINDOWED,Window.MODE_MAXIMIZED] and not window.is_embedded():
			var id:=window.get_window_id()
			outside=outside_window_direction(DisplayServer.mouse_get_position()-DisplayServer.window_get_position(id),DisplayServer.window_get_size(id))
		var edge:=edge_pointer_direction(get_viewport().get_mouse_position(),outside,_pointer_over_ui())
		edge_panning=edge!=Vector2.ZERO
		dir+=edge
	else:
		_edge_from_world=false
		_edge_from_right_panel=false
	if dir != Vector2.ZERO:
		var pan_delta:=minf(delta,0.2) if edge_panning else delta
		pan_screen(dir.normalized() * cam_speed * pan_delta)
	elif is_instance_valid(follow_target):
		# Follow the rendered pose, not the next 15 Hz physics position. Mixing
		# the two makes the camera jump ahead while the unit interpolates behind.
		var point: Vector2 = follow_target.presentation_position() if follow_target is Unit else follow_target.global_position
		camera.position = point - camera_focus_offset()
		clamp_camera_to_map()
		camera.force_update_scroll()

## 缩放。采用现代 RTS（红警3 / SC2）的「鼠标锚点缩放」：
## 缩放后光标下的地图点保持不动，不再像旧实现那样整屏往中心漂。
## 说明：相机 zoom = (z, z*Iso.K)，两轴同比缩放、且均匀缩放与旋转可交换，
## 所以只需要按同一比例 ratio 缩放画布变换的基向量即可精确求解。
func zoom_camera(factor: float) -> void:
	if camera == null:
		return
	var z: float = clampf(camera.zoom.x * factor, 0.45, 3.2)
	if absf(z - camera.zoom.x) < 0.0001:
		return
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var sp: Vector2 = get_viewport().get_mouse_position()
	var ctr: Vector2 = ct * camera.get_screen_center_position()   # 屏幕中心
	var ratio: float = z / camera.zoom.x
	var w_before: Vector2 = ct.affine_inverse() * sp
	var w_after: Vector2 = ct.affine_inverse() * ((sp - ctr) / ratio + ctr)
	camera.zoom = Iso.cam_zoom(z)
	camera.position += w_before - w_after
	clamp_camera_to_map()

## Middle click restores launch scale around the current usable-world center.
func reset_camera_zoom() -> void:
	if not is_instance_valid(camera): return
	var focus := camera.position + camera_focus_offset()
	view_zoom = DEFAULT_VIEW_ZOOM
	camera.zoom = Iso.cam_zoom(view_zoom)
	camera.position = focus - camera_focus_offset()
	clamp_camera_to_map()
	camera.reset_smoothing()
	camera.force_update_scroll()

func center_on(p: Vector2) -> void:
	if camera != null:
		follow_target = null
		camera.position = p - camera_focus_offset()
		clamp_camera_to_map()

# ================================================================== 输入

func _unhandled_input(event: InputEvent) -> void:
	if not world_input_enabled():
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if dragging:
			queue_redraw()

## 右键「单击」语义：取消放置 -> 取消指令模式 -> 下达移动/集火指令（对齐红警2 WorldInteraction）。
func _handle_right_click(event: InputEventMouseButton) -> void:
	if cast_slot >= 0:
		cancel_cast()
		return
	if armed_build != "":
		armed_build = ""
		Events.emit_message("已取消放置", Color(0.8, 0.8, 0.8))
		return
	if command_mode != "":
		arm_command("")
		return
	_issue_order(get_global_mouse_position(), event.shift_pressed, event.ctrl_pressed)

## 按住右键（或中键）拖拽平移视角——对齐红警2 rightClickScroll + CameraPanHandler。
## 用 _input 而非 _unhandled_input：拖拽经过 HUD 时仍能持续收到鼠标移动，不会中途断掉。
## GUI 命中的控件（含子节点和面板留白）拥有鼠标；IGNORE 装饰不参与命中。
## _input 早于 GUI 派发，此处只让位，不消费 GUI 自己需要的事件。
func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func _begin_pan(button: InputEventMouseButton) -> void:
	dragging = false
	_last_click_unit = null
	_rmb_panning = true
	_rmb_moved = false
	_rmb_anchor = button.position
	_pan_button = button.button_index
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not world_input_enabled():
		return
	if formation_gesture.handle(self,event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if _rmb_panning and mb.button_index != _pan_button:
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and dragging:
			# Ownership follows the press: a world box may end over the minimap/HUD.
			# Consume its release before GUI dispatch so it cannot move the minimap.
			var release_box := Rect2(drag_start_screen, mb.position - drag_start_screen).abs()
			var box_selection := release_box.size.length() >= SELECTION_CLICK_SLOP
			dragging = false
			if box_selection or not _pointer_over_ui():
				_apply_selection(drag_start, _selection_additive, release_box)
			else:
				_last_click_unit = null
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				if _pointer_over_ui():
					return
				_begin_pan(mb)
			else:
				if not _rmb_panning:
					return
				var clicked := not _rmb_moved and mb.position.distance_to(_rmb_anchor) <= _click_slop
				_rmb_panning = false
				_rmb_moved = false
				_pan_button = MOUSE_BUTTON_NONE
				if clicked and not _pointer_over_ui(): reset_camera_zoom()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if _pointer_over_ui():
					return
				if cast_slot >= 0 and not right_click_scroll:
					cancel_cast()
					get_viewport().set_input_as_handled()
					return
				if right_click_scroll or (not selected_units.is_empty() and command_mode.is_empty() and armed_build.is_empty()):
					_begin_pan(mb)
				else:
					_handle_right_click(mb)
			elif _rmb_panning:
				var moved := _rmb_moved or mb.position.distance_to(_rmb_anchor) > _click_slop
				_rmb_panning = false
				_rmb_moved = false
				_pan_button = MOUSE_BUTTON_NONE
				if not moved and (right_click_move or not right_click_scroll) and not _pointer_over_ui():
					_handle_right_click(mb)
			else:
				return
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _rmb_panning:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & (1 << (_pan_button - 1))) == 0:
			cancel_pointer_gestures()
			get_viewport().set_input_as_handled()
			return
		if not _rmb_moved and mm.position.distance_to(_rmb_anchor) > _click_slop:
			_rmb_moved = true
		if _rmb_moved and (right_click_scroll or _pan_button == MOUSE_BUTTON_MIDDLE):
			# 抓取地图：鼠标右/下移 -> 视角左/上移
			pan_screen(-mm.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		queue_redraw()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if _pointer_over_ui():
		return
	var world := get_global_mouse_position()
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if cast_slot >= 0:
			confirm_cast(get_canvas_transform().affine_inverse()*event.position)
			return
		if armed_build != "":
			_try_place_building(world)
			return
		if command_mode != "":
			_issue_command_at(world, event.shift_pressed)
			return
		if event.ctrl_pressed:
			ForceFire.issue(self, world, event.shift_pressed)
			return
		drag_start = world
		drag_start_screen = get_viewport().get_mouse_position()
		_selection_additive = event.shift_pressed
		dragging = true
		queue_redraw()
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_camera(1.12)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_camera(0.89)

# ================================================================== 选择

func _drag_screen_rect() -> Rect2:
	var cur := get_viewport().get_mouse_position()
	return Rect2(drag_start_screen, cur - drag_start_screen).abs()


func _apply_selection(a: Vector2, additive: bool, sbox: Rect2) -> void:
	var single := sbox.size.length() < SELECTION_CLICK_SLOP
	# A plain click on the sole selected stance unit / occupied IFV deploys it.
	# Test before clearing selection; box/Shift selection and rapid type-selection stay gestures.
	var deploy_target = pointer_deploy_target(a) if single and not additive else null
	if deploy_target != null:
		deploy_target.deploy()
		_last_click_unit = deploy_target
		_last_click_ms = Time.get_ticks_msec()
		_emit_selection()
		return
	var picked = pick_for_selection(a) if single else null
	if single and picked==null and allied_state.has("hollywood") and Hollywood.RetailSequences.resident_click(self,allied_state.hollywood,a):return
	if single and not additive and can_click_evacuate(picked):
		deploy_selected()
		return
	var reconcile_box := not single and not additive and not is_instance_valid(selected_building) and selected_walls.is_empty() and inspected_drones.is_empty() and command_mode.is_empty()
	if not additive and not reconcile_box:
		clear_selection()
	if single:
		if picked is Unit:
			# 双击同型只选当前画面里可见的单位。
			var now := Time.get_ticks_msec()
			if additive:
				_last_click_unit = null
				if inspected_drones.has(picked):
					inspected_drones.erase(picked)
				elif selected_units.has(picked):
					selected_units.erase(picked)
					picked.set_selected(false)
				else:
					select_unit(picked, true)
			elif is_instance_valid(_last_click_unit) and _last_click_unit == picked and now - _last_click_ms < 350 and picked.embarked_in == null:
				select_all_of_type(picked, true)
				_last_click_unit = null
			else:
				select_unit(picked, false)
				_last_click_unit = picked
				_last_click_ms = now
		elif picked != null:
			select_building(picked)
			_last_click_unit = null
		else:
			health_inspection_target = _pick_at(a, false)
			_last_click_unit = null
	else:
		_last_click_unit = null
		# Lao Cheng counts as a combat selection; boxes containing only ordinary miners still work.
		# Filter before select_unit so rejected/dead/passenger units cannot suppress miners.
		var candidates: Array = []
		var has_non_ordinary_miner := false
		var projection := get_viewport().get_canvas_transform()
		for u in units:
			if not actor_alive(u) or u.side != "ally" or u.unit_id in ["V3ROCKET", "DMISL", "CMISL", "BPLN", "SPYP", "PDPLANE"]:
				continue
			var anchor = inspection_host(u) if u.embarked_in != null else u
			if anchor != null and sbox.has_point(projection * anchor.art_center()):
				candidates.append(u)
				has_non_ordinary_miner = has_non_ordinary_miner or not u.is_ordinary_harvester()
		if has_non_ordinary_miner:
			candidates = candidates.filter(func(unit): return not unit.is_ordinary_harvester())
		if reconcile_box:
			if candidates == selected_units:
				return
			var retained := {}
			for unit in candidates: retained[unit] = true
			for unit in selected_units:
				if is_instance_valid(unit) and (not retained.has(unit) or (unit.embarked_in != null and NavalContact.grip_host(unit) == null)): unit.set_selected(false)
			selected_units.clear()
		for u in candidates:
			select_unit(u, true)
	_emit_selection()

func can_click_evacuate(picked) -> bool:
	if not is_instance_valid(picked) or picked != selected_building or not selected_units.is_empty():
		return false
	if picked.side != "ally" or not actor_alive(picked) or not world_input_enabled() \
			or cast_slot >= 0 or not armed_build.is_empty() or not command_mode.is_empty():
		return false
	return picked.special.get("occupants", []).any(func(u): return actor_alive(u) and u.embarked_in == picked)

## Shared by the hover cursor and click release: selected stance infantry or occupied IFV.
func pointer_deploy_target(p: Vector2):
	var candidate = pointer_deploy_candidate()
	return candidate if candidate != null and _pick_at(p) == candidate else null

func pointer_deploy_candidate():
	if not world_input_enabled() or cast_slot >= 0 or not armed_build.is_empty() or not command_mode.is_empty():
		return null
	if selected_units.size() != 1 or is_instance_valid(selected_building):
		return null
	var unit = selected_units[0]
	if not is_instance_valid(unit) or unit.side != "ally" or not actor_alive(unit) \
			or unit.embarked_in != null or unit._stun_timer > 0.0 or unit.repairing:
		return null
	var unload_ifv: bool = unit.unit_id in ["FV", "BFRT"] and unit.logistics.capacity > 0 \
			and unit.logistics.passengers.any(func(passenger): return actor_alive(passenger))
	var mcv: bool = not unit.deploy_building_id().is_empty()
	if not mcv and not unload_ifv and (not unit.data.get("deployer", false) or not unit.can_deploy() \
			or not unit.deploy_building_id().is_empty() or unit.logistics.capacity > 0 or unit.logistics.ammo_max > 0):
		return null
	# A rapid second selection click still selects the same type, without a stance change.
	if is_instance_valid(_last_click_unit) and _last_click_unit == unit and Time.get_ticks_msec() - _last_click_ms < 350:
		return null
	return unit

func inspection_host(drone):
	if not actor_alive(drone) or drone.side != "ally":return null
	if drone.unit_id=="SQD":return NavalContact.grip_host(drone)
	if drone.unit_id!="DRON":return null
	var host = drone.embarked_in
	if not actor_alive(host) or host.special.get("parasite") != drone or not actor_visible_to("ally",host): return null
	return host

func pick_for_selection(point: Vector2):
	var friendly = _pick_at(point)
	if friendly != null: return friendly
	return inspected_target_on(_pick_enemy_at(point))

func inspected_target_on(host):
	if host is Unit:
		for key in ["parasite","squid"]:
			var attached=host.special.get(key)
			if inspection_host(attached)==host:return attached
	return null

func _refresh_inspected_drones() -> void:
	var changed := false
	for i in range(inspected_drones.size()-1, -1, -1):
		var drone = inspected_drones[i]
		if inspection_host(drone) != null: continue
		inspected_drones.remove_at(i)
		if actor_alive(drone) and drone.side == "ally" and drone.embarked_in == null:
			select_unit(drone,true)
		changed = true
	if changed: _emit_selection()

func _pick_at(p: Vector2, ally_only: bool = true):
	var best = null
	var bd := INF
	for u in units:
		if not is_instance_valid(u):
			continue
		if ally_only and (u.side != "ally" or u.unit_id == "PDPLANE"):
			continue
		# WYSIWYG：命中判定 = 可见像素（与绘制同源）；就近用「可见像素中心」
		if not u.hit_test(p) or not actor_visible_to("ally", u):
			continue
		var d: float = p.distance_to(u.art_center())
		if d < bd:
			bd = d
			best = u
	if best != null:
		return best
	var bbest = null
	var bbd := INF
	for bld in buildings:
		if not is_instance_valid(bld):
			continue
		if ally_only and bld.side != "ally":
			continue
		if not bld.hit_test(p) or not actor_visible_to("ally", bld):
			continue
		var d2: float = p.distance_to(bld.art_center())
		if d2 < bbd:
			bbd = d2
			bbest = bld
	return bbest

## 拾取敌方目标（单位优先，其次建筑；同样按可见像素命中）
func _pick_enemy_at(p: Vector2):
	if selected_units.any(func(u):return actor_alive(u) and u.unit_id=="DLPH"):
		var friendly=_pick_at(p)
		if friendly is Unit:
			var squid=friendly.special.get("squid")
			if actor_alive(squid) and squid.side!="ally" and NavalContact.grip_host(squid)==friendly:return squid
	var best = null
	var bd := INF
	for u in get_tree().get_nodes_in_group(BattleRequest.foes_group("ally")):
		if not is_instance_valid(u):
			continue
		var u_hit: bool = u.hit_test(p) if u.has_method("hit_test") else (p.distance_to(u.global_position) < float(u.get("radius")) + 16.0)
		if not u_hit or not actor_visible_to("ally", u):
			continue
		var uc: Vector2 = u.art_center() if u.has_method("art_center") else u.global_position
		var d: float = p.distance_to(uc)
		if d < bd:
			bd = d
			best = u
	if best != null:
		return best
	for bld in buildings:
		if actor_alive(bld) and (bld.side != "neutral" or bld.is_explosive_barrel() or bld.special.get("allied_first_overlay",false)) and not BattleRequest.friendly(bld.side,"ally") and actor_visible_to("ally", bld) and bld.hit_test(p):
			return bld
	return null

## 拾取分组内的节点（如 resource_nodes 矿点）
func _pick_node_at(p: Vector2, group: String):
	var best = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(n) or not position_visible_to("ally", n.global_position):
			continue
		var d: float = p.distance_to(n.global_position)
		if d < float(n.get("radius")) + 26.0 and d < bd:
			bd = d
			best = n
	return best

func clear_selection() -> void:
	health_inspection_target = null
	if command_mode == "mcv_site": arm_command("")
	queue_redraw()
	for u in selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	selected_units.clear()
	inspected_drones.clear()
	for wall in selected_walls:
		if is_instance_valid(wall): wall.set_selected(false)
	selected_walls.clear()
	if is_instance_valid(selected_building):
		selected_building.set_selected(false)
	selected_building = null

func select_unit(u, additive: bool) -> void:
	if is_instance_valid(u) and (u.special.get("expedition_mission_unit",false) or u.special.has("psi_original_side")): return
	if not actor_alive(u) or (u.embarked_in != null and inspection_host(u) == null) or u.unit_id in ["V3ROCKET", "DMISL", "CMISL", "BPLN", "SPYP", "PDPLANE"]:
		return
	if not additive:
		clear_selection()
	elif is_instance_valid(selected_building) or not selected_walls.is_empty():
		clear_selection()
	if u.embarked_in != null and NavalContact.grip_host(u)==null:
		if not inspected_drones.has(u): inspected_drones.append(u)
		return
	if not selected_units.has(u):
		selected_units.append(u)
		u.set_selected(true)

func select_building(b) -> void:
	clear_selection()
	selected_building = b
	if is_instance_valid(b):
		selected_walls = WallArt.connected_component(b, buildings)
		if selected_walls.is_empty():
			b.set_selected(true)
		else:
			for wall in selected_walls: wall.set_selected(true)

func selected_wall_members() -> Array:
	return selected_walls.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion() and not b.is_dead() and b.hp > 0.0 and b.side == "ally")

func unit_in_visible_play_area(unit) -> bool:
	if not actor_alive(unit) or unit.embarked_in != null or not unit.is_visible_in_tree():
		return false
	var pixel: Vector2 = get_viewport().get_canvas_transform() * unit.art_center()
	if not get_viewport_rect().has_point(pixel):
		return false
	return not is_instance_valid(hud) or not hud.covers_world_pixel(pixel)

func select_all_of_type(proto, visible_only: bool = false, skip_box_carrier: bool = false) -> void:
	clear_selection()
	for u in units:
		if is_instance_valid(u) and u.side == "ally" and u.unit_id == proto.unit_id:
			if skip_box_carrier and u.special.has("field_box"):
				continue
			if visible_only and not unit_in_visible_play_area(u):
				continue
			select_unit(u, true)
	_emit_selection()

## 释放当前选中单位的第 slot 个技能（HUD 技能栏 / 快捷键调用），返回成功数量
func use_ability_selected(slot: int) -> int:
	var n := 0
	var source = selected_skill_unit()
	var shown: Ability = source.ability_at(slot) if source != null else null
	if shown == null:
		return 0
	if shown.id=="drone_auto_hunt":
		var drones:Array=(selected_units+inspected_drones).filter(func(u):return actor_alive(u) and u.side=="ally" and UnitSkillLayout.find(u,"drone_auto_hunt")>=0 and u.ability_ready(UnitSkillLayout.find(u,"drone_auto_hunt")))
		var turn_on:bool=not drones.any(func(u):return preload("res://scripts/units/expansion_2_drone.gd").automatic(u))
		for drone in drones:
			if preload("res://scripts/units/expansion_2_drone.gd").automatic(drone)!=turn_on and drone.use_ability(UnitSkillLayout.find(drone,"drone_auto_hunt")):n+=1
		return n
	if shown.id in ["allied_deploy", "ggi_deploy"] or (source.unit_id == "SCHP" and shown.id == "allied_special"):
		var group := selected_deploy_group(source.unit_id == "SCHP")
		# Mixed groups finish deployment before a later command folds everyone.
		var deploy: bool = group.any(func(u): return not u.is_deployed())
		for u in group:
			if u.is_deployed() != deploy and u.use_ability(UnitSkillLayout.index(u, 2)):
				n += 1
		return n
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("use_ability"):
			# Saved arrays may have different ordering; cast the displayed identity only.
			var actual := UnitSkillLayout.find(u, shown.id)
			if actual >= 0 and actual in [UnitSkillLayout.index(u, 0), UnitSkillLayout.index(u, 1), UnitSkillLayout.index(u, 2)] and u.use_ability(actual):
				n += 1
	return n

func infantry_deploy_group() -> Array:
	return selected_deploy_group()

## Infantry and siege choppers each share a desired state within their own group.
func selected_deploy_group(choppers := false) -> Array:
	var group: Array = []
	for u in selected_units:
		if not is_instance_valid(u) or u.is_queued_for_deletion() or u._dead or u.hp <= 0.0 or u.side != "ally" or u.embarked_in != null:
			continue
		var ability: Ability = u.ability_at(UnitSkillLayout.index(u, 2))
		var matches: bool = u.unit_id == "SCHP" if choppers else ability != null and ability.id in ["allied_deploy", "ggi_deploy"]
		if matches and ability != null and not group.has(u):
			group.append(u)
	return group

## 选中单位里第一个带技能栏的单位（供 HUD 技能栏展示），无则返回 null
func selected_skill_unit():
	for u in selected_units + inspected_drones:
		if is_instance_valid(u) and u.has_method("has_skill_bar") and u.has_skill_bar():
			return u
	return null

func _emit_selection() -> void:
	if command_mode==Unit.YRTalents.REVERSE:arm_command("")
	if command_mode==ReaperSplit.ID and split_gunner!=ReaperSplit.selected(self):arm_command("")
	selected_units = selected_units.filter(func(u): return is_instance_valid(u) and u.hp > 0.0 and (u.embarked_in == null or NavalContact.grip_host(u)!=null))
	if selected_units.is_empty() and command_mode != "" and command_mode not in ["repair", "sell", "superweapon", ReaperSplit.ID]:
		command_mode = ""
		Events.command_mode_changed.emit("")
	if selected_units.is_empty():
		cast_slot = -1
		hover_ability = -1
	var payload: Array = []
	if not selected_walls.is_empty():
		payload.append_array(selected_wall_members())
	elif is_instance_valid(selected_building):
		payload.append(selected_building)
	var large_group := selected_units.size() > AttackRangePreview.INDIVIDUAL_LIMIT
	for u in selected_units:
		u.group_idle_redraw = large_group
		payload.append(u)
	payload.append_array(inspected_drones)
	Events.selection_changed.emit(payload)
	_maybe_select_voice()

# ================================================================== 单位语音（RA2）
# rules.ini 的 Voice* → data/ra2_allied.json 的 <entry>.voice → [sound.ini]
# 一次选择/一条命令只播一条语音（RA2 亦如此：框选 20 个不会叠 20 条）——
# 从"有该语音的单位"里随机取一个作代表，与 RA2 的随机响应一致。
func _voice_rep(arr: Array, kind: String):
	var pool: Array = []
	for u in arr:
		if not is_instance_valid(u) or not u.has_method("order_move"):
			continue
		var effective_kind: String = u.command_voice_kind(kind)
		if not effective_kind.is_empty() and Ra2Sfx.has_voice(u.data, effective_kind):
			# Let the designated spotter acknowledge a mixed group's airstrike order.
			if kind == "attack" and effective_kind == "secondary_attack": return u
			pool.append(u)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _play_group_voice(arr: Array, kind: String, throttle_ms: int = 180) -> bool:
	var rep = _voice_rep(arr, kind)
	if rep == null:
		return false
	return Ra2Sfx.play_voice(rep.data, rep.command_voice_kind(kind), rep.global_position, throttle_ms)

## 选择变化时才播 select 语音（签名去重：拖框/重复点击不会每帧重播）
func _maybe_select_voice() -> void:
	# Inspection can acknowledge selection without making the parasite commandable.
	var speakers := selected_units + inspected_drones
	var sig := "inspect:" if not inspected_drones.is_empty() else ""
	for u in speakers:
		if is_instance_valid(u):
			sig += str(u.get_instance_id()) + ","
	if sig == _sel_voice_sig:
		return
	_sel_voice_sig = sig
	if not speakers.is_empty():
		_play_group_voice(speakers, "select", 200)

## (A4) 命中指定阵营的建筑（供右键维修厂判定）
func _pick_building_at(p: Vector2, want_side := "ally"):
	var best = null
	var bd := INF
	for bld in buildings:
		if not is_instance_valid(bld):
			continue
		if want_side != "" and bld.side != want_side:
			continue
		if not bld.hit_test(p) or not actor_visible_to("ally", bld):
			continue
		var d: float = p.distance_to(bld.art_center())
		if d < bd:
			bd = d
			best = bld
	return best

## Transparent pixels between the animated factory layers still belong to the
## building foundation for support orders.
func support_order_target(point: Vector2, use_foundation := true):
	return support_target_from_pick(point, _pick_at(point), use_foundation)

func support_target_from_pick(point: Vector2, picked, use_foundation := true, empty_pixels := false):
	if picked == null and not empty_pixels: picked = _pick_building_at(point, "")
	if not use_foundation or picked is Building: return picked
	if picked != null and not selected_units.has(picked): return picked
	if not selected_units.any(func(u): return actor_alive(u) and AlliedAbilities.infantry(u)): return picked
	for building in buildings:
		if not actor_alive(building) or not actor_visible_to("ally", building): continue
		if not Geometry2D.is_point_in_polygon(point - building.global_position, building.footprint_poly()): continue
		for actor in selected_units:
			if picked != null and picked != actor: continue
			if actor_alive(actor) and not AlliedAbilities.default_order(actor, building).is_empty(): return building
	return picked

## (A4) 维修指令：右键点中己方维修厂时，把受损载具派去修理（满血的不去）。
func repair_facility_at(p: Vector2):
	return repair_facility_from_pick(p, _pick_building_at(p, "ally"))

func repair_facility_from_pick(p: Vector2, picked):
	if picked != null: return picked if picked.is_repair_depot() else null
	# The open water between a yard's piers belongs to the berth.
	if not selected_units.any(func(u): return actor_alive(u) and u.is_naval): return null
	for yard in buildings:
		if actor_alive(yard) and yard.side == "ally" and yard.data.get("water_bound", false) and yard.is_repair_depot():
			if Geometry2D.is_point_in_polygon(p - yard.position, yard.footprint_poly()): return yard
	return null

func _try_repair_at(p: Vector2, append := false) -> bool:
	var depot = repair_facility_at(p)
	if depot == null:
		return false
	if not depot.is_operational():
		Events.emit_message("维修厂尚未就绪，暂不能维修", Color(1.0, 0.8, 0.5))
		return true
	var assigned := false
	for u in selected_units:
		if not is_instance_valid(u):
			continue
		if u.can_repair_at(depot): assigned = u.order_interaction("depot", depot, append) or assigned
	if assigned:
		_add_order_mark(depot.global_position, "repair")
		Events.emit_message("维修：进驻 %s" % depot.display_name, Color(0.6, 0.95, 1.0))
	else:
		Events.emit_message("造船厂只接收可行动的受损己方舰艇" if depot.data.get("water_bound", false) else "维修厂只接收可行动的受损己方地面载具", Color(1.0, 0.8, 0.5))
	return true

## Shared by the pointer and right-click dispatch; hovering never issues an order.
func boarding_order_status(carrier) -> Dictionary:
	if not carrier is Unit or not actor_alive(carrier) or carrier.side != "ally" \
			or carrier.embarked_in != null or carrier.logistics.capacity <= 0 or not actor_visible_to("ally", carrier):
		return {}
	var candidates: Array = []
	var has_selection := false
	for unit in selected_units:
		if not actor_alive(unit) or unit == carrier or unit.embarked_in != null:
			continue
		has_selection = true
		if carrier.logistics.can_board(unit): candidates.append(unit)
	if not has_selection: return {}
	var reason := ""
	if candidates.is_empty():
		reason = "载具已满员" if carrier.logistics.used_capacity() >= carrier.logistics.capacity else "所选单位无法进入该载具"
	return {"passengers": candidates, "reason": reason}

## The same read-only airfield eligibility drives pointer and command dispatch.
func airfield_order_status(airport) -> Dictionary:
	if not airport is Building or not actor_alive(airport) or airport.side != "ally" \
			or not actor_visible_to("ally", airport): return {}
	var docks := int(GameData.ra2_source_buildings.get(airport.building_id, {}).get("extra", {}).get("NumberOfDocks", 0))
	if docks <= 0: return {}
	var planes: Array = []
	var available: Array = []
	for unit in selected_units:
		if not actor_alive(unit) or unit.embarked_in != null or not unit.is_air \
				or unit.logistics.ammo_max <= 0 or is_instance_valid(unit.logistics.carrier_owner): continue
		planes.append(unit)
		if unit.logistics.return_slot(airport) >= 0: available.append(unit)
	if planes.is_empty(): return {}
	return {"planes": planes, "available": available,
		"reason": "机场尚未建成" if airport.under_construction else "机场泊位已满或不支持所选飞机"}

## 右键下达默认指令。p_queue=Shift 追加为路径点；Ctrl 攻击移动
func has_selected_attack_building() -> bool:
	return selected_units.is_empty() and actor_alive(selected_building) and selected_building.side == "ally" and selected_building.supports_attack_order()

func peregrine_air_order(target) -> bool:
	if not target is Unit or not target.is_air_target(): return false
	for unit in selected_units:
		if actor_alive(unit) and unit.special.has("peregrine") and preload("res://scripts/units/peregrine_command.gd").anti_air(unit, target):
			return true
	return false

func hero_miner_attack_order(target) -> bool:
	if target == null: return false
	for unit in selected_units:
		if actor_alive(unit) and unit.special.get("academy_hero") == "HARV" and unit.embarked_in == null and unit.attack_domain_valid(target):
			return true
	return false

func _issue_order(p: Vector2, p_queue: bool = false, p_attack_move: bool = false) -> void:
	if p_attack_move:
		_command_move(p, p_queue, true)
		return
	if has_selected_attack_building():
		force_attack(_pick_enemy_at(p))
		return
	if selected_units.is_empty():
		# 未选单位：若选中的是建筑，右键设定集结点
		if is_instance_valid(selected_building):
			if p.distance_to(selected_building.global_position) <= selected_building.radius or selected_building.hit_test(p):
				_clear_rally(selected_building)
			else:
				_set_rally(selected_building, p)
		return
	var target = _pick_enemy_at(p)
	if peregrine_air_order(target):
		force_attack(target, p_queue)
		return
	var airport = _pick_building_at(p, "ally")
	if _try_refinery_return(airport, p_queue): return
	var landing := airfield_order_status(airport)
	if not landing.is_empty():
		var returned := 0
		for plane in landing.available:
			if plane.order_interaction("airfield", airport, p_queue): returned += 1
		if returned > 0: _add_order_mark(airport.position, "move")
		if returned < landing.planes.size(): Events.emit_message(landing.reason, Color(1.0, 0.8, 0.5))
		return
	var carrier = _pick_at(p)
	var special_target = support_target_from_pick(p, carrier)
	var special_ordered := false
	var mark := "repair"
	for actor in selected_units:
		if not actor_alive(actor): continue
		var action := AlliedAbilities.default_order(actor, special_target)
		if not action.is_empty() and actor.order_interaction(action, special_target, p_queue):
			special_ordered = true
			if action == "ivan_bridge": mark = "attack"
	if special_ordered:
		_add_order_mark(p, mark)
		return
	var boarding := boarding_order_status(carrier)
	if not boarding.is_empty():
		var loaded := false
		for u in boarding.passengers:
			loaded = u.order_interaction("board", carrier, p_queue) or loaded
		if loaded:
			_add_order_mark(carrier.position, "move")
		elif not str(boarding.reason).is_empty():
			Events.emit_message(boarding.reason, Color(1.0, 0.8, 0.5))
		return
	if hero_miner_attack_order(target):
		force_attack(target, p_queue)
		return
	# 采集车：右键矿点指派采集
	if _try_harvest_at(p):
		return
	# (A4) 右键己方维修厂：受损载具进驻修理
	if _try_repair_at(p, p_queue):
		return
	if target != null:
		force_attack(target, p_queue)
		return
	_command_move(p, p_queue)

## 移动：RA2 式编队槽位 + 每单位独立 A* 路径（不再全队共用一张流场）。
## 共享流场会让所有单位挤在同一条梯度线上，到终点再各自散开，观感就是“一坨”。
## Radar orders target terrain, not sprite hitboxes (which may overlap a different tile).
func radar_ground_order(p: Vector2, queued: bool, attack_move: bool) -> bool:
	if not right_click_move or cast_slot >= 0 or not armed_build.is_empty() or not command_mode.is_empty():
		return false
	if selected_units.any(func(u): return actor_alive(u) and u.side == "ally"):
		_command_move(p, queued, attack_move)
		return true
	if actor_alive(selected_building) and selected_building.side == "ally" and not selected_building.buildable.is_empty():
		_set_rally(selected_building, p)
		return true
	return false

func _command_move(p: Vector2, p_queue: bool = false, p_attack_move: bool = false) -> void:
	if selected_units.is_empty():
		return
	var units: Array = []
	for u in selected_units:
		if is_instance_valid(u):
			units.append(u)
	if units.is_empty():
		return
	var facing := _group_facing(p)
	var spacing := _formation_spacing(units)
	var slots: Array = Formations.layout(units.size(), p, facing, formation_mode, spacing)
	var assigned := _assign_move_slots(units, slots, p)
	_issue_move_slots(units, assigned, p, p_queue, p_attack_move)

func _issue_move_slots(units: Array, assigned: Dictionary, p: Vector2, p_queue: bool, p_attack_move: bool, final_heading := INF) -> void:
	var reported_stances := {}
	var deployed := self.units.filter(func(other): return actor_alive(other) and other._deployed and not other.is_air and not other.is_naval and other.embarked_in == null)
	for u in units:
		var slot: Vector2 = assigned.get(u, p)
		# A deployed GI rejects an immediate move in order_move; keep its feedback
		# and queue semantics without computing or retrying an unusable path.
		var stationary: bool = not p_queue and u._deployed and u.unit_id in ["GGI", "E1"]
		var deck_goal := Vector2.INF
		if ground is Ground and ground.overpass != null and not u.is_air and not u.is_naval:
			var center_hit: Vector2 = ground.overpass.pick_deck(p)
			if center_hit.is_finite():
				deck_goal = ground.overpass.pick_deck(slot)
				if not deck_goal.is_finite(): deck_goal = center_hit
				slot = deck_goal
			if p_queue and (u.has_move_order or u.attack_ordered or not u.order_queue.is_empty()):
				u.order_queue.append({"position":slot,"attack_move":p_attack_move,"deck":deck_goal.is_finite()})
				continue
			u.special.erase("hollywood_street_goal")
			u.special.erase("hollywood_deck_goal")
			if deck_goal.is_finite(): u.special.hollywood_deck_goal = slot
			elif u.special.has("hollywood_on_deck"): u.special.hollywood_street_goal = slot
		var pts := PackedVector2Array() if stationary else path_for_unit(u, slot, deployed)
		if not stationary and pts.size()<2 and (deck_goal.is_finite() or u.special.has("hollywood_on_deck")):
			u.order_stop(false)
			continue
		if pts.size() >= 2:
			# 终点可能被吸附到岸边/障碍旁，以路径末点为准
			slot = pts[pts.size() - 1]
		elif path_service != null and not stationary:
			# 完全不可达：原地待命，避免顶着墙无限推
			var wm: bool = u.get("is_naval") == true
			var routes := movement_service(u)
			var snapped := routes.nearest_reachable(slot, u.global_position, wm, 20, u.is_amphibious, u.unit_id=="R3APOC")
			if snapped.distance_to(u.global_position) > 8.0:
				pts = routes.find_path(u.global_position, snapped, wm, 6000, u.is_amphibious, [], u.unit_id=="R3APOC")
				slot = snapped
			else:
				slot = u.global_position
		if p_queue and not deck_goal.is_finite() and not u.special.has("hollywood_on_deck"):
			u.queue_waypoint(slot, null, p_attack_move)
		else:
			u.cancel_stance()
			u.clear_queue()
			var report_stance := not reported_stances.has(u.unit_id)
			u.order_move(slot, p_attack_move, null, pts, report_stance)
			if u._deployed and report_stance and u.embarked_in == null and not AlliedAbilities.frozen(u):
				reported_stances[u.unit_id] = true
			if is_finite(final_heading):
				if u.has_move_order:
					u.special.formation_heading = final_heading
				elif AlliedAbilities.infantry_teleporter(u) and u.position.is_equal_approx(slot):
					u.move_target = slot
					u.special.formation_heading = final_heading
	if p_queue:
		_add_order_mark(p, "queue")
	else:
		_add_order_mark(p, "attack_move" if p_attack_move else "move")
	_play_group_voice(selected_units, "move")

var _deployed_path_epoch := 0

const ROUTE_HISTORY := 32
var _route_changes := {}
var remote_route_reuses := 0

func record_route_change(bounds: Rect2) -> void:
	_route_changes[path_epoch()] = bounds
	if _route_changes.size() > ROUTE_HISTORY:
		_route_changes.erase(_route_changes.keys()[0])

func notify_deployment_changed(blocker: Unit = null) -> void:
	_deployed_path_epoch += 1
	if is_instance_valid(blocker):
		record_route_change(Rect2(blocker.global_position, Vector2.ZERO).grow(blocker.radius))

func remaining_route_unchanged(unit: Unit, current_epoch: int) -> bool:
	# Missing history means a full terrain refresh, a restored save or a very old path.
	var count := current_epoch - unit._path_epoch
	if count <= 0 or count > ROUTE_HISTORY or unit._path_pts[-1] != unit.move_target:
		return false
	for version in range(unit._path_epoch + 1, current_epoch + 1):
		if not _route_changes.has(version):
			return false
		var changed: Rect2 = _route_changes[version]
		# Include site raster padding, transient blocker padding and both hulls' clearance.
		changed = changed.grow(2.0 * path_service.cell + unit.radius + 8.0)
		var start := unit.global_position
		for index in range(clampi(unit._path_i, 1, unit._path_pts.size()-1), unit._path_pts.size()):
			var finish := unit._path_pts[index]
			if Rect2(start, Vector2.ZERO).expand(finish).intersects(changed, true):
				var leg := finish - start
				var normal := Vector2(-leg.y, leg.x)
				var extent := 0.5 * changed.size.dot(normal.abs())
				if absf((changed.get_center() - start).dot(normal)) <= extent:
					return false
			start = finish
	remote_route_reuses += 1
	return true

func path_epoch() -> int:
	return (path_service.epoch if path_service != null else 0) + _deployed_path_epoch

func path_for_unit(u, p: Vector2, candidates = null, traffic_blockers: Array = []) -> PackedVector2Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(14)
	if not is_instance_valid(u):
		return PackedVector2Array()
	if u.get("is_air") == true:
		var target := Vector2(clampf(p.x, 0.0, map_size), clampf(p.y, 0.0, map_size))
		return PackedVector2Array([u.global_position, target])
	if path_service == null:
		return PackedVector2Array()
	var routes := movement_service(u)
	var wm: bool = u.get("is_naval") == true
	var stationary: Array = traffic_blockers.duplicate() if not traffic_blockers.is_empty() else []
	if not wm:
		for other in (get_tree().get_nodes_in_group(&"deployed_route_blockers") if candidates == null else candidates):
			if not actor_alive(other) or other == u or other.side != u.side or (candidates==null and other._battle_world()!=self) or not other._deployed or other.embarked_in != null or other.is_air or other.is_naval:
				continue
			if u._local_traffic.friendly_unit_pair(u,other): continue
			stationary.append({"position": other.global_position, "radius": u.radius + other.radius + 8.0})
	if not wm and ground is Ground and ground.overpass != null:
		var elevated: bool = u.special.get("hollywood_deck_goal",Vector2.INF) == p
		if elevated or u.special.has("hollywood_on_deck"):
			return ground.overpass.layered_route(u,p,elevated,routes,stationary)
	if traffic_blockers.is_empty() and u is Unit:
		stationary.append_array(u._local_traffic.campaign_neutral_blockers(u, self, p))
	var transit=preload("res://scripts/expedition/foundation_transit.gd")
	# Foundation collision exceptions exist only for explicit movement orders.
	# Automatic mining/docking must keep routing around solid allied buildings.
	if transit.enabled(u) and u.has_move_order and not u._deployed and transit.crosses(u,self,p,stationary):return PackedVector2Array([u.position,p])
	if uses_ground_passages(u):
		var passage: PackedVector2Array = u.ground_passage(routes, p, stationary) if u is Unit else routes.passages.route(routes, u.global_position, p, u.radius + 1.0, stationary)
		if not passage.is_empty(): return passage
	var army_route := units.size()>=96 and BattleRequest.is_ai_house(u.side)
	return routes.find_path(u.global_position, p, wm, 6000, u.is_amphibious, stationary, u.unit_id=="R3APOC",army_route)

func uses_ground_passages(u) -> bool:
	return not u.is_air and not u.is_naval and (u.is_harvester or u.data.get("role", "") in ["vehicle", "infantry"] or u.data.get("tags", []).has("infantry"))

## 编队间距按单位体积计算：战舰/大型车辆不再按步兵的 34px 挤成一团。
func _formation_spacing(units: Array) -> float:
	var max_r := 10.0
	for u in units:
		if is_instance_valid(u):
			max_r = maxf(max_r, float(u.get("radius")))
	# 相邻单位可能各提前 ARRIVE_EPS 停下；为车身、分离距离和两侧到达容差留足空间。
	var arrival_spacing := max_r * 2.0 + UnitScript.ARRIVE_EPS * 2.0 + 4.0
	return maxf(max_r * 2.6, arrival_spacing)

## 槽位分配：按距离贪心匹配，避免单位斜穿友军去抢对面的位置。
func _assign_move_slots(units: Array, slots: Array, center: Vector2, defer_routes := false) -> Dictionary:
	var res: Dictionary = {}
	if slots.is_empty():
		for u in units:
			res[u] = center
		return res
	var pool := PackedInt32Array()
	pool.resize(slots.size())
	for i in slots.size(): pool[i] = i
	var order: Array = units.duplicate()
	order.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	var used: Array[Vector2] = []
	var spacing := _formation_spacing(units)
	var origin := Vector2.ZERO
	for actor in units:
		origin += actor.global_position
	origin /= maxf(1.0, units.size())
	var forward := (center - origin).normalized()
	var marching := origin.distance_to(center) > spacing * sqrt(float(units.size()))
	var depth_by_slot := PackedFloat64Array()
	var row_margin := spacing * 0.25
	if marching:
		depth_by_slot.resize(slots.size())
		for i in slots.size():
			var point: Vector2 = slots[i]
			depth_by_slot[i] = (point - center).dot(forward)
	# Terrain is unchanged during this synchronous command. Reuse slot checks
	# only within this call and within an identical movement domain.
	var blocked_by_domain:Dictionary={}
	for u in order:
		var wm: bool = u.get("is_naval") == true
		var air: bool = u.get("is_air") == true
		var routes := movement_service(u)
		var domain:= (8 if routes != path_service else 0) | int(wm) | (int(u.is_amphibious)<<1) | (int(u.unit_id=="R3APOC")<<2)
		var blocked: Array = []
		if not air and path_service != null:
			if not blocked_by_domain.has(domain):
				blocked.resize(slots.size())
				blocked_by_domain[domain] = blocked
			else:
				blocked = blocked_by_domain[domain]
		var position:Vector2=u.global_position
		var best := -1
		var best_d := INF
		var best_depth := -INF
		for i in range(pool.size()):
			var slot_index := pool[i]
			var s: Vector2 = slots[slot_index]
			if not blocked.is_empty():
				if blocked[slot_index] == null: blocked[slot_index] = routes.is_blocked(s,wm,u.is_amphibious,u.unit_id=="R3APOC")
				if blocked[slot_index]: continue
			# Keep the original row/tie order. A slot behind the current row
			# cannot win on distance, regardless of the unit's position.
			var depth := 0.0
			var advances_row := false
			if marching:
				depth = depth_by_slot[slot_index]
				advances_row = depth > best_depth + row_margin
				if not advances_row and not absf(depth - best_depth) <= row_margin: continue
			var d := position.distance_squared_to(s)
			if advances_row or d < best_d:
				best_d = d
				best_depth = depth
				best = i
		if best < 0:
			best = 0
		var slot: Vector2 = slots[pool[best]]
		pool.remove_at(best)
		if not defer_routes and not air and path_service != null:
			slot = resolve_move_slot(u,slot,used,spacing)
			used.append(slot)
		res[u] = slot
	return res

func resolve_move_slot(u, slot: Vector2, used: Array[Vector2], spacing: float) -> Vector2:
	var routes := movement_service(u)
	var wm: bool = u.is_naval
	var transit=preload("res://scripts/expedition/foundation_transit.gd")
	if transit.enabled(u):
		slot=transit.destination(u,self,slot)
		if _move_slot_clear(slot,used,spacing) and transit.crosses(u,self,slot,[]):return slot
	var reachable := routes.nearest_reachable(slot, u.global_position, wm, 6, u.is_amphibious, u.unit_id=="R3APOC")
	if reachable != slot and (not uses_ground_passages(u) or routes.passages.route(routes, u.global_position, slot, u.radius+1.0, []).is_empty()):
		slot = reachable
	# Snapping around an obstacle must retain body/arrival spacing, not
	# merely place centers in different 16px cells.
	var snapped := slot
	for nudge in range(48):
		if _move_slot_clear(slot, used, spacing):
			break
		var ang := float(nudge + 1) * 2.399963
		var cand := snapped + Vector2(cos(ang), sin(ang)) * spacing * float(1 + nudge / 8)
		cand = routes.nearest_reachable(cand, u.global_position, wm, 6, u.is_amphibious, u.unit_id=="R3APOC")
		if not routes.is_blocked(cand, wm, u.is_amphibious) and _move_slot_clear(cand, used, spacing):
			slot = cand
	return slot

func _move_slot_clear(slot: Vector2, used: Array[Vector2], spacing: float) -> bool:
	for other in used:
		if slot.distance_to(other) < spacing - 0.1:
			return false
	return true

## 采集指令：把选中的采集车派往 p 附近的矿点
func refinery_return_miners(building) -> Array:
	if not is_instance_valid(building) or building.side != "ally" or not building.is_refinery(): return []
	return selected_units.filter(func(u): return actor_alive(u) and u.side == "ally" and u.is_harvester and u.embarked_in == null)

func _try_refinery_return(building, append := false) -> bool:
	var miners := refinery_return_miners(building)
	if miners.is_empty(): return false
	if not building.is_operational():
		Events.emit_message("这座矿场尚不能接收矿车")
		return true
	var returning: Array = []
	for miner in miners:
		if miner.order_interaction("refinery", building, append): returning.append(miner)
	if not returning.is_empty():
		_add_order_mark(building.global_position, "harvest")
		_play_group_voice(returning, "move")
	if returning.size() < miners.size():
		Events.emit_message("%d 辆矿车暂时无法返回该矿场" % (miners.size() - returning.size()))
	return true

func _try_harvest_at(p: Vector2) -> bool:
	if not selected_units.any(func(u): return is_instance_valid(u) and u.is_harvester): return false
	var node = _pick_node_at(p, "resource_nodes")
	if node == null:
		return false
	var assigned := false
	var harvesters: Array = []
	for u in selected_units:
		if is_instance_valid(u) and (u.get("is_harvester") == true):
			u.order_harvest(node)
			assigned = true
			harvesters.append(u)
	if assigned:
		_add_order_mark(p, "harvest")
		Events.emit_message("采集：%s" % str(node.get("display_name")), Color(0.95, 0.8, 0.35))
		_play_group_voice(harvesters, "harvest")
	return assigned

## 设定建筑集结点：出厂的部队会自动前往
func _set_rally(b, p: Vector2) -> void:
	if not is_instance_valid(b) or b.side != "ally" or b.buildable.is_empty():
		return
	rally_points[b.get_instance_id()] = p
	last_rally_building = b
	var cleanup := _clear_rally.bind(b)
	if not b.tree_exiting.is_connected(cleanup):
		b.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)
	_add_order_mark(p, "rally")
	Events.emit_message("集结点已设定", Color(0.7, 0.95, 1.0))
	queue_redraw()
	if is_instance_valid(hp_overlay):
		hp_overlay.queue_redraw()

func _clear_rally(b) -> void:
	if not is_instance_valid(b):
		return
	rally_points.erase(b.get_instance_id())
	if last_rally_building == b:
		last_rally_building = null
	queue_redraw()
	if is_instance_valid(hp_overlay):
		hp_overlay.queue_redraw()

## 供 spawn_unit 查询建筑集结点
func rally_for(building) -> Vector2:
	if building == null or not is_instance_valid(building):
		return Vector2.INF
	if rally_points.has(building.get_instance_id()):
		return rally_points[building.get_instance_id()]
	return Vector2.INF

## 强制集火（攻击指令）
func force_attack(target, append := false) -> void:
	if has_selected_attack_building():
		if not is_instance_valid(target): return
		var reason: String = selected_building.attack_order_reason(target)
		if not reason.is_empty():
			Events.emit_message(reason, Color(1.0, 0.8, 0.5))
			return
		if selected_building.building_id == "R3REAPERTURRET":
			preload("res://scripts/buildings/ra3_reaper_emplacement.gd").order(selected_building, target)
		else:
			ForceFire.clear(selected_building)
			if selected_building.data.has("charged_weapon"):
				if selected_building.attack_target != target: selected_building.special.erase("coil_windup")
				selected_building.special.coil_ordered_target = target
			elif not selected_building.data.has("garrison_weapons"):
				selected_building.special.defense_ordered_target = target
			selected_building.attack_target = target
			if target is Building and target.is_explosive_barrel(): selected_building.special[ForceFire.KEY] = target
		_add_order_mark(target.global_position, "attack")
		return
	if not is_instance_valid(target) or selected_units.is_empty() or not (actor_visible_to("ally",target) or NavalContact.visible_grip(self,"ally",target)):
		return
	var dest: Vector2 = target.global_position
	var attackers: Array = []
	var n := selected_units.size()
	for i in range(n):
		var u = selected_units[i]
		if not is_instance_valid(u):
			continue
		if NavalContact.grip_host(target)!=null and u.unit_id!="DLPH":continue
		# Spies copy infantry through the same explicit target order as combat units.
		if u.unit_id == "SPY":
			AlliedAbilities.use(u, "allied_disguise", target)
			continue
		attackers.append(u)
		var ring := Vector2.ZERO
		if n > 1:
			var ang := TAU * float(i) / float(n)
			var rad := 22.0 + 12.0 * float(i / 8)
			ring = Vector2(cos(ang), sin(ang)) * rad
		u.order_target(target, target is Building and (target.is_explosive_barrel() or target.special.get("allied_first_overlay",false)), append, ring)
	if not attackers.is_empty():
		_add_order_mark(dest, "attack")
		Events.emit_message("集火：%s" % str(target.get("display_name")), Color(1.0, 0.72, 0.45))
		_play_group_voice(attackers, "attack")

## 供 HUD 底部选中条点击：单选某单位并聚焦镜头
func focus_unit(u) -> void:
	if not is_instance_valid(u):
		return
	select_unit(u, false)
	center_on(u.global_position)
	_emit_selection()

func select_same_type_now() -> void:
	for u in selected_units:
		if is_instance_valid(u):
			select_all_of_type(u, false, true)
			return

## 上下循环选中己方单位（红警2：M 上一个 / N 下一个）
func select_cycle(dir: int) -> void:
	var pool: Array = []
	for u in get_tree().get_nodes_in_group("combatants"):
		if is_instance_valid(u) and u.side == "ally":
			pool.append(u)
	if pool.is_empty():
		return
	pool.sort_custom(func(a, b) -> bool: return a.get_instance_id() < b.get_instance_id())
	var cur = selected_units[0] if selected_units.size() > 0 else null
	var idx := pool.find(cur)
	var nxt = pool[(idx + dir + pool.size()) % pool.size()]
	clear_selection()
	select_unit(nxt, false)
	center_on(nxt.global_position)
	_emit_selection()

## 镜头对准基地（红警2：H 回到主基地）
func center_on_base() -> void:
	for b in get_tree().get_nodes_in_group("ally_buildings"):
		if is_instance_valid(b) and b.is_hq:
			center_on(b.global_position)
			Events.emit_message("镜头回到基地", Color(0.7, 0.9, 1.0))
			return
	for b in get_tree().get_nodes_in_group("ally_buildings"):
		if is_instance_valid(b):
			center_on(b.global_position)
			return
	Events.emit_message("暂无己方建筑", Color(1.0, 0.8, 0.5))

## 跟随选中单位（红警2：F 跟随，再按一次取消）
func follow_selected() -> void:
	if selected_units.is_empty() or not is_instance_valid(selected_units[0]):
		follow_target = null
		Events.emit_message("未选中可跟随单位", Color(1.0, 0.8, 0.5))
		return
	var u = selected_units[0]
	if follow_target == u:
		follow_target = null
		Events.emit_message("已取消跟随", Color(0.8, 0.85, 0.9))
	else:
		follow_target = u
		Events.emit_message("跟随：%s" % str(u.display_name), Color(0.7, 0.95, 0.9))

## 部署（红警2：D）——单位无部署能力时给出提示
func deploy_selected() -> void:
	if is_instance_valid(selected_building):
		if selected_building.side != "ally":
			return
		if preload("res://scripts/units/civilian_orders.gd").slots(selected_building) > 0:
			preload("res://scripts/units/civilian_orders.gd").evacuate(selected_building, false, true)
			return
		ConstructionRepack.execute(self, selected_building)
		return
	var ok := 0
	var eligible := 0
	var choppers := selected_deploy_group(true)
	var deploy_choppers: bool = choppers.any(func(u): return not u.is_deployed())
	for u in selected_units.duplicate():
		if not is_instance_valid(u):
			continue
		if u.unit_id == "SCHP":
			if choppers.has(u):
				eligible += 1
				if u.is_deployed() != deploy_choppers and u.use_ability(UnitSkillLayout.index(u, 2)):
					ok += 1
			continue
		if not u.has_method("deploy"):
			continue
		if u.has_method("can_deploy") and not u.can_deploy():
			continue
		eligible += 1
		if u.deploy():
			ok += 1
	if eligible == 0:
		Events.emit_message("当前单位无部署能力（红警2：D 部署步兵/基地车）", Color(1.0, 0.85, 0.55))

## 基地车转换不经过死亡或付款路径；校验成功后才消耗原单位。
func construction_deploy_check(unit, position: Vector2 = Vector2.INF) -> Dictionary:
	if ended or not is_instance_valid(unit) or not units.has(unit) or unit._dead or unit.hp <= 0.0 \
			or unit.is_queued_for_deletion() or unit.embarked_in != null:
		return {"ok": false, "reason": "基地车当前无法展开"}
	if preload("res://scripts/world/construction_transition.gd").active(unit):
		return {"ok": false, "reason": "等待基地车收起完成"}
	var bid: String = unit.deploy_building_id()
	if bid.is_empty():
		return {"ok": false, "reason": "该单位不能展开为建筑"}
	var pos := snap_build_pos(unit.global_position if position == Vector2.INF else position)
	var data := GameData.get_building(bid)
	var result := build_spot_ok(pos, data, true, unit.side, unit)
	# 不能让狭窄水域从地基中间穿过，即使四个角均在陆地上。
	if result.ok and not data.get("water_bound", false):
		var poly := Building.placement_poly(data)
		for water in water_rects:
			var r: Rect2 = water
			var water_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
				r.end, Vector2(r.position.x, r.end.y)])
			if Placement.polys_overlap(poly, pos, water_poly, Vector2.ZERO):
				result = {"ok": false, "reason": "不能建在水面"}
				break
	result["position"] = pos
	result["building"] = bid
	return result

func selected_mcv():
	if selected_units.size() != 1: return null
	var unit = selected_units[0]
	if not actor_alive(unit) or unit.side != "ally" or unit.deploy_building_id().is_empty(): return null
	return unit

func mcv_site(p: Vector2) -> Dictionary:
	var unit = selected_mcv()
	var result := construction_deploy_check(unit,p)
	if result.ok and not path_service.same_zone(unit.position, result.position):
		result.ok = false
		result.reason = "基地车无法到达该位置"
	return result

func deploy_construction_vehicle(unit) -> bool:
	var status := construction_deploy_check(unit)
	if not status.ok:
		if is_instance_valid(unit) and unit.side == "ally":
			Events.emit_message("无法展开基地车：" + str(status.reason), Color(1.0, 0.7, 0.5))
		return false
	var fraction: float = clampf(unit.hp / unit.max_hp, 0.0, 1.0)
	var was_selected := selected_units.has(unit)
	# Placement clears its footprint by pushing units, including this consumed MCV.
	# Capture the visible start before that collision housekeeping moves it.
	var vehicle_origin: Vector2 = unit.global_position
	var building = _place_building(status.building, unit.side, status.position, true, true)
	if building == null:
		return false
	building.hp = building.max_hp * fraction
	if unit.side == "ally":
		var growth_defense: float = preload("res://scripts/expedition/growth.gd").actor_factor(unit, "def")
		building.bonuses["defense_bonus"] = float(building.bonuses.get("defense_bonus", 1.0)) * growth_defense
	if unit.special.has(Ra3Clearance.KEY):
		building.special[Ra3Clearance.KEY] = unit.special[Ra3Clearance.KEY].duplicate(true)
	if mission.get("id")==TimeShift.ID and unit.special.has("shift_global_house"):
		building.special.time_shift_native_house=unit.special.shift_global_house
	preload("res://scripts/world/construction_transition.gd").deploying(building, unit, vehicle_origin)
	unit._dead = true
	unit.set_process(false)
	unit.set_physics_process(false)
	for group in unit.get_groups():
		unit.remove_from_group(group)
	units.erase(unit)
	selected_units.erase(unit)
	for key in control_groups:
		control_groups[key].erase(unit)
	if follow_target == unit:
		follow_target = null
	if hover_entity == unit:
		hover_entity = null
	unit.queue_free()
	if was_selected:
		if selected_units.is_empty():
			select_building(building)
		_emit_selection()
	_update_power()
	if building.side == "ally":
		Events.emit_message("矿场已展开，矿工开始采矿。" if building.building_id=="YAREFN" else "基地车已展开为建造厂，可以恢复建筑生产。", Color(0.6, 0.95, 0.7))
	return true

## 维修选中建筑（红警2：K 切换维修）
func toggle_repair_selected() -> void:
	apply_building_action("repair", selected_building)

## 出售选中建筑（红警2：L 出售，返还一半造价）
func sell_selected_building() -> void:
	if selected_walls.is_empty():
		apply_building_action("sell", selected_building)
	else:
		for wall in selected_wall_members():
			apply_building_action("sell", wall)

## Cursor and execution share eligibility rules; no selection is required.
func building_action_reason(action: String, b) -> String:
	if action not in ["repair", "sell"]:
		return "未知建筑操作"
	if not is_instance_valid(b) or not b is Building or b.is_queued_for_deletion() or b.is_dead() or b.hp <= 0.0:
		return "请点击己方建筑"
	if b.side != "ally":
		return "只能操作己方建筑"
	if b.building_id == "CAOILD" and action == "sell": return "科技钻油井不可出售"
	if b.building_id != "CAOILD" and b.data.get("tags", []).has("civilian"):
		return "民用建筑不可出售；受损后撤出驻军，由工程师修复"
	if b.under_construction:
		return "建筑尚未完成"
	var extra: Dictionary = GameData.ra2_source_buildings.get(b.building_id, {}).get("extra", {})
	if action == "repair":
		if str(extra.get("Repairable", "true")).to_lower() in ["false", "no", "0"]:
			return "该建筑不能维修"
		if not b.repairing and b.hp >= b.max_hp:
			return "建筑已满血，无需维修"
	else:
		if b.is_hq and not GameData._ra2_flag(extra.get("ConstructionYard",false)):
			return "该基地不可出售"
		if b.data.get("unsellable",false) or str(extra.get("Unsellable", "false")).to_lower() in ["true", "yes", "1"]:
			return "该建筑不能出售"
	return ""

func can_repair_all() -> bool:
	return BattleRequest.extensions_enabled() and production_technology.is_unlocked("repair_all", "ally")

var _repair_poll := 0.0

func _tick_area_repair() -> void:
	var automatic: bool = allied_state.get("area_repair", 0) == 2
	var pending := false
	var started := false
	for b in buildings:
		if not actor_alive(b) or b.side != "ally": continue
		if automatic and not b.repairing and b.hp < b.max_hp and building_action_reason("repair", b).is_empty():
			b.set_repairing(true)
			b.special.area_repair = true
			started = true
		if b.repairing and b.special.has("area_repair"): pending = true
	if started:
		Ra2Sfx.play_player_eva(self, "EVA_Repairing", 3000)
	if not automatic and not pending: allied_state.erase("area_repair")

func repair_all_buildings() -> void:
	if paused or ended or get_tree().paused or not can_repair_all(): return
	if command_mode in ["repair", "sell"]: arm_command("")
	var upgraded := production_technology.is_unlocked("repair_auto", "ally")
	var mode := int(allied_state.get("area_repair", 0))
	if upgraded and mode == 2:
		DisplayPreferences.set_automatic_building_repair(false)
		allied_state.erase("area_repair")
		for b in buildings:
			if actor_alive(b) and b.side == "ally" and b.special.has("area_repair"): b.set_repairing(false)
		return
	if upgraded and mode == 1:
		DisplayPreferences.set_automatic_building_repair(true)
		allied_state.area_repair = 2
		_tick_area_repair()
		return
	var started := 0
	var ongoing := 0
	for b in buildings:
		if not building_action_reason("repair", b).is_empty(): continue
		if b.repairing:
			ongoing += 1
			continue
		b.set_repairing(true)
		if upgraded: b.special.area_repair = true
		started += 1
	if upgraded:
		allied_state.area_repair = 1 if started > 0 else 2
		DisplayPreferences.set_automatic_building_repair(started == 0)
		if started == 0: return
	if started > 0:
		Ra2Sfx.play_player_eva(self, "EVA_Repairing", 500)
		Events.emit_message("已开始维修 %d 座建筑" % started)
	elif ongoing > 0:
		Events.emit_message("已有 %d 座建筑正在维修" % ongoing)
	else:
		Events.emit_message("当前没有需要维修的己方建筑")

func apply_building_action(action: String, b) -> bool:
	if paused or ended or get_tree().paused:
		return false
	var reason := building_action_reason(action, b)
	if not reason.is_empty():
		Events.emit_message(reason, Color(1.0, 0.8, 0.5))
		return false
	if action == "repair":
		b.set_repairing(not b.repairing)
		if b.repairing:
			Ra2Sfx.play_player_eva(self, "EVA_Repairing", 500)
		Events.emit_message("%s：%s" % [b.display_name, "开始维修，再次点击可停止" if b.repairing else "停止维修"])
		return true
	var refund: float = float(GameData.ra2_refund(int(b.data.get("cost", 0)))) + b.total_production_paid()
	# Selling is not destruction: no kill credit, death sound or explosion.
	b.retire_sold()
	buildings.erase(b)
	selected_walls.erase(b)
	rally_points.erase(b.get_instance_id())
	if selected_building == b:
		var remaining := selected_wall_members()
		selected_building = remaining[0] if not remaining.is_empty() else null
	if hover_entity == b:
		hover_entity = null
	_refresh_pathing()
	_update_power()
	credit_side("ally", refund)
	_emit_selection()
	Events.emit_message("已出售 %s，返还 %d（含队列已付费用）" % [b.display_name, int(refund)], Color(0.95, 0.85, 0.6))
	Ra2Sfx.play_player_eva(self, "EVA_StructureSold", 500)
	return true

# —— 控制组（红警2 编队）——
func _control_group_alive(actor) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.side != "ally":
		return false
	if actor is Building:
		return not actor.is_dead()
	return actor is Unit and not actor._dead and actor.hp > 0.0

func _control_group_members(gid: int) -> Array:
	var key := str(gid)
	var retained: Array = []
	var available: Array = []
	for actor in control_groups.get(key, []):
		if not _control_group_alive(actor) or retained.has(actor):
			continue
		retained.append(actor)
		# Boarding temporarily hides a unit; unloading restores its original group.
		if actor is Building or actor.embarked_in == null:
			available.append(actor)
	if control_groups.has(key):
		var removed := retained.size() != (control_groups[key] as Array).size()
		control_groups[key] = retained
		if removed: refresh_control_group_badges()
	return available

# Only group edits and save restoration rebuild the reverse index. Selection
# and hover can then draw a badge without searching every group each frame.
func refresh_control_group_badges() -> void:
	_group_badges.clear()
	for gid in range(1,11):
		var digit := str(gid % 10)
		for actor in control_groups.get(str(gid), []):
			if not _control_group_alive(actor): continue
			var id: int = actor.get_instance_id()
			var label: String = _group_badges.get(id,"")
			if not digit in label: _group_badges[id] = label + digit
	if is_instance_valid(hp_overlay): hp_overlay.queue_redraw()

func control_group_badge(actor) -> String:
	if not _control_group_alive(actor) or not (actor.selected or actor.hovered): return ""
	if actor is Unit and actor.embarked_in != null: return ""
	return _group_badges.get(actor.get_instance_id(),"")

func _paint_control_group(actor, projection: Transform2D, zoom: float) -> void:
	var digits := control_group_badge(actor)
	if digits.is_empty(): return
	var bar: Rect2 = actor.hp_bar_rect()
	# Below the left edge, clear of the rank to the left and reload circles to the right.
	var pos: Vector2 = (projection * actor.global_position + Vector2(bar.position.x,bar.end.y)*zoom + Vector2(0,2)).round()
	var rect := Rect2(pos,Vector2(10,13))
	var tint := HouseColor.player_color()
	hp_overlay.draw_set_transform_matrix(hp_overlay.get_global_transform_with_canvas().affine_inverse())
	for digit in digits:
		hp_overlay.draw_rect(rect,Color.BLACK)
		hp_overlay.draw_rect(rect.grow(-0.5),tint,false,1)
		hp_overlay.draw_string(ThemeDB.fallback_font,rect.position+Vector2(1,11),digit,HORIZONTAL_ALIGNMENT_CENTER,8,12,tint)
		rect.position.x += 11
	Iso.begin(hp_overlay)

func assign_control_group(gid: int) -> void:
	var arr: Array = []
	for u in selected_units:
		if _control_group_alive(u) and u.embarked_in == null and not arr.has(u):
			arr.append(u)
	if not selected_walls.is_empty():
		arr.append_array(selected_wall_members())
	elif selected_building is Building and _control_group_alive(selected_building):
		arr.append(selected_building)
	if arr.is_empty():
		Events.emit_message("没有可编组的单位", Color(1.0, 0.8, 0.5))
		return
	control_groups[str(gid)] = arr
	refresh_control_group_badges()
	Events.emit_message("编队 %d 已记录（%d）" % [gid, arr.size()], Color(0.7, 0.95, 1.0))

func select_control_group(gid: int) -> void:
	var arr := _control_group_members(gid)
	if arr.is_empty():
		return
	clear_selection()
	for x in arr:
		if x is Unit:
			select_unit(x,true)
		elif x is Building:
			selected_building = x
			if WallArt.is_wall(x.data): selected_walls.append(x)
			x.set_selected(true)
	_emit_selection()

func center_control_group(gid: int) -> void:
	var c := Vector2.ZERO
	var members := _control_group_members(gid)
	for x in members:
		c += x.global_position
	if not members.is_empty():
		center_on(c / float(members.size()))

## 全选己方作战单位
func toggle_army_exclusion() -> void:
	if not world_input_enabled(): return
	var targets := selected_units.filter(func(u): return actor_alive(u) and u.side == "ally")
	if targets.is_empty(): return
	var exclude := targets.any(func(u): return not u.excluded_from_army_selection)
	for u in targets:
		u.excluded_from_army_selection = exclude
	var message := "已从全选中排除 %d 个单位" if exclude else "已取消 %d 个单位的排除标记"
	Events.emit_message(message % targets.size())

func select_excluded_units() -> void:
	if not world_input_enabled(): return
	var found := false
	for u in units:
		if not actor_alive(u) or u.side != "ally" or not u.excluded_from_army_selection: continue
		if u.embarked_in != null and NavalContact.grip_host(u) == null: continue
		select_unit(u, found)
		found = found or selected_units.has(u)
	if found:
		_emit_selection()
		center_on_selection()
		Events.emit_message("已选中排除全选的单位（%d）" % selected_units.size())
	else:
		Events.emit_message("当前没有可选中的已排除单位")

func select_all_combat() -> void:
	clear_selection()
	for u in units:
		if not actor_alive(u) or u.side != "ally" or u.excluded_from_army_selection or u.special.has("field_box") or not u.is_in_group("combatants") or u.is_ordinary_harvester():
			continue
		if u.embarked_in != null and NavalContact.grip_host(u) == null:
			continue
		if is_instance_valid(u.logistics.carrier_owner) or u.weapon.is_empty() or AlliedAbilities.is_repair_ifv(u):
			continue
		select_unit(u, true)
	_emit_selection()
	Events.emit_message("已全选部队（%d）" % selected_units.size(), Color(0.7, 0.95, 1.0))

## V toggles aggressive targeting; mixed selections enter it together.
func aggressive_selected() -> void:
	set_fire_stance_selected("defend" if selected_fire_stance() == "free" else "free")

func selected_fire_stance() -> String:
	var state := ""
	for unit in selected_units:
		if not actor_alive(unit) or unit.side != "ally" or unit.embarked_in != null: continue
		var current: String = "guard" if unit.hold_position and unit.fire_stance == "free" else unit.fire_stance
		if not state.is_empty() and current != state: return "mixed"
		state = current
	return state

func set_fire_stance_selected(stance: String) -> void:
	if not world_input_enabled():return
	if stance not in ["free", "defend", "return", "none"]: return
	var count:=0
	for unit in selected_units:
		if not actor_alive(unit) or unit.side!="ally" or unit.embarked_in!=null:continue
		unit.hold_position=false
		unit.set_fire_stance(stance)
		# Drop auto-acquired focus/bursts so leaving aggressive mode takes effect now.
		# Explicit movement and target orders retain their existing authority.
		if not unit.attack_ordered:
			unit.attack_target = null
			unit._cancel_burst()
		unit._refresh_target()
		count+=1
	if count>0:
		var labels := {"free":"主动进攻", "defend":"自动防卫", "return":"仅反击", "none":"停火"}
		Events.emit_message("作战姿态：%s（%d）" % [labels[stance],count],Color(1,.85,.5))
		_emit_selection()

## 循环切换选中单位的开火姿态（自动防卫 / 自由开火 / 仅反击 / 停火）
func cycle_fire_stance_selected() -> void:
	if selected_units.is_empty():
		return
	var label := ""
	var mode := ""
	for u in selected_units:
		if is_instance_valid(u):
			u.cycle_fire_stance()
			label = u.fire_stance_label()
			mode = u.fire_stance
	var col := Color(1.0, 0.85, 0.5) if mode == "free" else Color(0.72, 0.82, 0.95)
	Events.emit_message("开火姿态：%s" % label, col)
	_emit_selection()

## 镜头对准选中单位
func center_on_selection() -> void:
	var c := Vector2.ZERO
	var n := 0
	for u in selected_units:
		if is_instance_valid(u):
			c += u.global_position
			n += 1
	if n == 0 and is_instance_valid(selected_building):
		c = selected_building.global_position
		n = 1
	if n == 0:
		return
	center_on(c / float(n))

## 选中单位的几何中心到目标点的方向（阵型朝向）
func _group_facing(p: Vector2) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for u in selected_units:
		if is_instance_valid(u):
			c += u.global_position
			n += 1
	if n == 0:
		return Vector2.UP
	var dir: Vector2 = p - c / float(n)
	if dir.length() < 1.0:
		return Vector2.UP
	return dir.normalized()

func cycle_formation() -> void:
	var modes: Array = Formations.MODES
	var i := modes.find(formation_mode)
	formation_mode = modes[(i + 1) % modes.size()]
	Events.emit_message("编队阵型：%s" % Formations.label(formation_mode), Color(0.7, 0.95, 0.8))

func set_formation(mode: String) -> void:
	if Formations.MODES.has(mode):
		formation_mode = mode
		Events.emit_message("编队阵型：%s" % Formations.label(mode), Color(0.7, 0.95, 0.8))

# ================================================================== 指令模式 / 姿态 / 视角

func arm_command(mode: String) -> void:
	split_gunner=null
	if mode == "":
		_armed_superweapon = null
		_chrono_source_point = Vector2.INF
	if mode == "attack" and has_selected_attack_building() and selected_building.data.has("garrison_weapons") and not preload("res://scripts/units/civilian_orders.gd").has_gunner(selected_building):
		Events.emit_message("需要可开火的驻军，先让步兵进驻", Color(1.0, 0.8, 0.5))
		return
	if mode != "" and mode not in ["repair", "sell"] and selected_units.is_empty() and not (mode in ["attack",ReaperSplit.ID] and has_selected_attack_building()):
		Events.emit_message("先选中作战单位，再按 M/A/P 下令", Color(1.0, 0.8, 0.5))
		return
	if mode != "" and command_mode == mode:
		command_mode = ""
	else:
		command_mode = mode
	if command_mode != "":
		if armed_build != "":
			armed_build = ""
		cast_slot = -1
		hover_ability = -1
		_armed_superweapon = null
		cancel_pointer_gestures()
		Events.emit_message("指令模式：%s（左键点击目标 / Esc 取消）" % _mode_label(mode), Color(0.7, 0.95, 1.0))
	Events.command_mode_changed.emit(command_mode)
	queue_redraw()

## 建筑面板点击：武装超级武器，等待地图目标点。
func owns_superweapon(b) -> bool:
	return actor_alive(b) and b.side == "ally" and not b.superweapon.is_empty()

func arm_superweapon(b) -> void:
	if not owns_superweapon(b) or ended or paused or get_tree().paused:
		return
	if not b.sw_ready():
		Events.emit_message("%s 尚在充能（%d%%）" % [b.sw_label(), int(b.sw_progress() * 100.0)], Color(1.0, 0.8, 0.5))
		return
	_armed_superweapon = b
	cancel_pointer_gestures()
	hover_ability = -1
	_chrono_source_point = Vector2.INF
	command_mode = "superweapon"
	armed_build = ""
	cast_slot = -1
	var instruction := "先选区域再选落点：敌我均受影响，普通步兵及危险落点会致死（Esc 取消）" if b.sw_type().to_lower() == "chronosphere" else "选择 %s 的目标位置（左键确认 / Esc 取消）" % b.sw_label()
	if b.sw_type() == "SpyPlane": instruction = "点击一处侦察区域，可指定未探索地带；飞机将自动飞越拍照（Esc 取消）。"
	if b.sw_type() in ["AmerParaDrop","ParaDrop"]: instruction = "点击陆地投放 %d 名美国大兵（Esc 取消）。" % int(b.superweapon.count)
	if b.sw_type() == "LightningStorm": instruction = "移动鼠标选择落雷区域，左键确认施放；区域内随机落雷，敌我均受影响（Esc 取消）。"
	Events.emit_message(instruction, Color(0.75, 0.9, 1.0))
	Events.command_mode_changed.emit(command_mode)
	queue_redraw()

func _mode_label(mode: String) -> String:
	if mode==Unit.ReverseAttack.ID:return "倒退攻击"
	if mode==Unit.YRTalents.REVERSE:return "掩护倒车"
	if mode==ReaperSplit.ID:return ReaperSplit.LABEL
	match mode:
		"mcv_site": return "基地车展开选址"
		"repair":
			return "维修建筑"
		"sell":
			return "出售建筑"
		"move":
			return "移动"
		"attack":
			return "攻击"
		"patrol":
			return "巡逻"
		"attack_move":
			return "攻击移动"
		"harvest":
			return "采集"
		"superweapon":
			return "超级武器"
	return "取消"

func _issue_command_at(p: Vector2, p_queue: bool = false) -> void:
	var mode := command_mode
	if mode == Unit.ReverseAttack.ID:
		if Unit.ReverseAttack.issue(self,p): arm_command("")
		else: Events.emit_message("请选择可通行的地面和可移动的地面作战单位",Color.ORANGE)
		return
	if mode==Unit.YRTalents.REVERSE:
		var issued:=false
		for unit in selected_units:
			if Unit.YRTalents.start_reverse(unit,p): issued=true
		if issued:arm_command("")
		else: Events.emit_message("请选择可直线倒车到达的畅通地面，最多 3 格",Color.ORANGE)
		return
	if mode==ReaperSplit.ID:
		ReaperSplit.confirm(self,p)
		return
	if mode == "mcv_site":
		var result := mcv_site(p)
		if not result.ok:
			Events.emit_message(result.reason)
			return
		var unit = selected_mcv()
		arm_command("")
		unit.order_move(result.position)
		unit.special.mcv_deploy_at = result.position
		return
	if mode in ["repair", "sell"]:
		apply_building_action(mode, _pick_building_at(p, ""))
		return
	var sw_src = _armed_superweapon
	if mode == "superweapon":
		if not owns_superweapon(sw_src) or not sw_src.sw_ready():
			arm_command("")
			return
		if sw_src.sw_type().to_lower() == "chronosphere" and not _chrono_source_point.is_finite():
			if SupportSystems.chrono_units(self, p, sw_src.side).is_empty():
				Events.emit_message("该区域没有可见、可受超时空影响的单位", Color(1, 0.8, 0.5))
				return
			_chrono_source_point = p
			Events.command_mode_changed.emit(command_mode)
			Ra2Fx.play(effects_root, p, "CHRONOAR")
			Events.emit_message("已选中传送区域，请点击目的地（Esc 取消）", Color(0.75, 0.9, 1))
			return
		if sw_src.fire_superweapon(p):
			arm_command("")
		else:
			Events.emit_message("目标不可用、尚未探索或武器未就绪；请重新选点", Color(1, 0.8, 0.5))
		return
	if not (p_queue and mode == "attack"): arm_command("")
	match mode:
		"move":
			_command_move(p, p_queue)
		"attack_move":
			_command_move(p, p_queue, true)
		"harvest":
			if not _try_refinery_return(_pick_building_at(p, "ally")) and not _try_harvest_at(p):
				Events.emit_message("请选择矿点或己方矿场", Color(1.0, 0.8, 0.5))
		"attack":
			var t = _pick_enemy_at(p)
			if t == null:
				ForceFire.issue(self, p, p_queue)
			else:
				force_attack(t, p_queue)
		"patrol":
			var offs := Vector2.ZERO
			for u in selected_units:
				if is_instance_valid(u):
					u.cancel_stance()
					u.order_patrol(p + offs)
					offs += Vector2(26.0, -18.0)
			_add_order_mark(p, "patrol")

func stop_selected() -> void:
	if actor_alive(selected_building):
		ForceFire.clear(selected_building)
		selected_building.attack_target = null
		if has_selected_attack_building():
			ReaperSplit.clear(selected_building)
			selected_building.special.erase("reaper_focus")
			selected_building.special.erase("reaper_ordered_target")
			selected_building.special.erase("coil_ordered_target")
			selected_building.special.erase("defense_ordered_target")
			selected_building.special.erase("coil_windup")
			if command_mode in ["attack",ReaperSplit.ID]:arm_command("")
	var n := 0
	for u in selected_units:
		if is_instance_valid(u):
			u.order_stop()
			n += 1
	if n > 0:
		arm_command("")
		Events.emit_message("部队停止（%d）" % n, Color(0.85, 0.9, 1.0))

## -1: no eligible selection; 0: off; 1: mixed; 2: all guarding.
func guard_selection_state() -> int:
	var count := 0
	var guarding := 0
	for u in selected_units:
		if not actor_alive(u) or u.side != "ally": continue
		count += 1
		if u.hold_position and u.fire_stance == "free": guarding += 1
	if count == 0: return -1
	if guarding == count: return 2
	return 1 if guarding > 0 else 0

func guard_selected() -> void:
	var disable := guard_selection_state() == 2
	var count := 0
	for u in selected_units:
		if not actor_alive(u) or u.side != "ally": continue
		if disable:
			u.order_stop()
		else:
			u.order_guard()
		count += 1
	if count > 0:
		arm_command("")
		var state := "已关闭，恢复自动防卫" if disable else "已开启，原地固守"
		Events.emit_message("部队警戒：%s（%d）" % [state, count], Color(0.6, 0.9, 1.0))

func _emit_view() -> void:
	Events.view_changed.emit(Iso.preset_label())
	Events.emit_message("视角：%s" % Iso.preset_label(), Color(0.7, 0.9, 1.0))

func set_view_preset(i: int) -> void:
	Iso.set_preset(i)
	if camera != null:
		view_zoom = camera.zoom.x
		Iso.apply_to(camera, view_zoom)
		clamp_camera_to_map()
	_emit_view()

func cycle_view_preset() -> void:
	Iso.next_preset()
	if camera != null:
		view_zoom = camera.zoom.x
		Iso.apply_to(camera, view_zoom)
		clamp_camera_to_map()
	_emit_view()

func set_view_k(v: float) -> void:
	Iso.set_k(v)
	if camera != null:
		view_zoom = camera.zoom.x
		Iso.apply_to(camera, view_zoom)
		clamp_camera_to_map()
	_emit_view()

func toggle_view_mirror() -> void:
	Iso.toggle_mirror()
	if camera != null:
		view_zoom = camera.zoom.x
		Iso.apply_to(camera, view_zoom)
		clamp_camera_to_map()
	_emit_view()

## 切换「等距 45° 菱形」/「轴向对齐俯视」
func toggle_view_yaw() -> void:
	Iso.toggle_yaw()
	if camera != null:
		view_zoom = camera.zoom.x
		Iso.apply_to(camera, view_zoom)
		clamp_camera_to_map()
	_emit_view()

## 混合编队返回 null，由 Unit 自己按移动域取流场；纯海军使用水面流场。
func group_field_for(units_arr: Array, p: Vector2):
	var naval := 0
	var other := 0
	for u in units_arr:
		if not is_instance_valid(u):
			continue
		if (u.get("is_naval") == true):
			naval += 1
		else:
			other += 1
	if naval > 0 and other == 0:
		return field_for_pos(p, true)
	if naval > 0:
		return null
	return field_for_pos(p, false)

## Iron Tide 扩展模式的国家开局赠送，不属于 RA2 国家规则。
func _apply_country_bonus(hq: Vector2) -> void:
	if not BattleRequest.skirmish or not BattleRequest.extensions_enabled():
		return
	var country := str(BattleRequest.skirmish_config.get("country", "美国"))
	match country:
		"美国":
			for i in range(2):
				spawn_unit("E1", "ally", hq + Vector2(90 + i * 34, -10))
		"韩国":
			spawn_unit("BEAG", "ally", hq + Vector2(120, -60))
		"法国":
			_place_building("GTGCAN", "ally", hq + Vector2(240, 120), true)
		"德国":
			spawn_unit("TNKD", "ally", hq + Vector2(120, 60))
		"英国":
			spawn_unit("SNIPE", "ally", hq + Vector2(80, -50))

## 供 Unit 巡逻/海军移动时取流场
func field_for_pos(p: Vector2, water_mode: bool = false):
	if path_service == null:
		return null
	return path_service.field_for(p, water_mode)

## 单位移动域查询：is_naval 用。水域判断与寻路网格同源，避免视觉岸边与碰撞不一致。
func in_water_world(p: Vector2) -> bool:
	return path_service != null and path_service.in_water(p)

# ================================================================== 悬停 / 点击反馈

func _set_hover(hit) -> void:
	if hit == hover_entity:
		return
	if is_instance_valid(hover_entity) and hover_entity.has_method("set_hovered"):
		hover_entity.set_hovered(false)
	hover_entity = hit
	if is_instance_valid(hover_entity) and hover_entity.has_method("set_hovered"):
		hover_entity.set_hovered(true)

func _update_cursor() -> void:
	if is_instance_valid(command_cursor):
		command_cursor.refresh(0.0)

func _cursor_on_ore(mp: Vector2 = Vector2.INF) -> bool:
	if mp == Vector2.INF:
		mp = get_global_mouse_position()
	if not position_visible_to("ally", mp): return false
	if command_mode != "harvest" and not selected_units.any(func(u): return is_instance_valid(u) and u.is_harvester):
		return false
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(n):
			continue
		if not n.is_empty() and n.global_position.distance_to(mp) <= 34.0:
			return true
	return command_mode == "harvest"

func _add_order_mark(p: Vector2, kind: String) -> void:
	_order_marks.append({ "pos": p, "kind": kind, "t": 0.75 })
	queue_redraw()

func _update_order_marks(delta: float) -> void:
	if _order_marks.is_empty():
		return
	for m in _order_marks:
		m["t"] = float(m["t"]) - delta
	_order_marks = _order_marks.filter(func(m): return float(m["t"]) > 0.0)

func _draw_order_marks() -> void:
	for m in _order_marks:
		var t: float = clampf(float(m["t"]) / 0.75, 0.0, 1.0)
		var kind := str(m["kind"])
		var col := Color(0.5, 1.0, 0.62, t)
		if kind == "attack":
			col = Color(1.0, 0.5, 0.4, t)
		elif kind == "patrol":
			col = Color(1.0, 0.85, 0.4, t)
		var pos: Vector2 = m["pos"]
		var rr := 18.0 + (1.0 - t) * 26.0
		Iso.outline(self, Iso.ground_circle(pos, rr), col, 2.0)
		if kind == "patrol":
			Iso.outline(self, Iso.ell(pos, rr * 0.55, rr * 0.55), col, 2.0)

func _draw_command_cursor() -> void:
	if command_mode == "superweapon" and is_instance_valid(_armed_superweapon) and _armed_superweapon.sw_type() in ["IronCurtain","MultiMissile","SpyPlane","AmerParaDrop","ParaDrop","LightningStorm","ChronoSphere"]: return
	if command_mode in ["repair", "sell"]:
		return # Original wrench/sell cursor is rendered by battle_cursor.
	var pos := get_global_mouse_position()
	var col := Color(0.5, 1.0, 0.62, 0.95)
	var label := _mode_label(command_mode)
	if command_mode == "attack":
		col = Color(1.0, 0.45, 0.4, 0.98)
		label = "攻击"
	elif command_mode == "patrol":
		col = Color(1.0, 0.85, 0.4, 0.95)
		label = "巡逻"
	elif command_mode == "attack_move":
		col = Color(1.0, 0.62, 0.35, 0.98)
		label = "攻击移动"
	elif command_mode == "harvest":
		col = Color(0.95, 0.8, 0.35, 0.98)
		label = "采集"
	var rr := 26.0
	Iso.outline(self, Iso.ground_circle(pos, rr), col, 2.0)
	draw_line(pos + Vector2(-rr * 0.6, 0.0), pos + Vector2(rr * 0.6, 0.0), col, 1.5)
	draw_line(pos + Vector2(0.0, -rr * 0.6), pos + Vector2(0.0, rr * 0.6), col, 1.5)
	if command_mode == "attack":
		var t = _pick_enemy_at(pos)
		if t != null:
			var tr := float(t.get("radius")) + 8.0
			Iso.outline(self, Iso.ell(t.global_position, tr, tr), Color(1.0, 0.3, 0.3, 0.9), 3.0)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, pos + Vector2(-14.0, rr + 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

# ================================================================== 建造

func set_build_mode(bid: String) -> void:
	if not campaign_yard_block_reason(bid).is_empty() or not GameData.building_production_block_reason(bid).is_empty():
		return
	armed_build = bid
	cast_slot = -1
	hover_ability = -1
	if command_mode != "":
		command_mode = ""
		Events.command_mode_changed.emit("")
	var bd := GameData.get_building(bid)
	Events.emit_message("放置模式：%s（右键取消）" % bd.get("name", bid), Color(1.0, 0.85, 0.5))

# ================================================================ 建筑生产队列（RA3/RA2 侧栏流程）

## 已拥有建筑 id 集合（用于前置条件判定）。
const YURI_EQUIVALENT := {"GACNST":"YACNST", "GAPOWR":"YAPOWR", "GAREFN":"YAREFN", "GAPILE":"YABRCK", "GAWEAP":"YAWEAP", "GAAIRC":"NAPSIS", "GATECH":"YATECH", "GAYARD":"YAYARD", "GAPILL":"YAGGUN", "GADEPT":"YAGRND", "AMCV":"PCV", "CMIN":"SMIN", "MTNK":"LTNK", "E1":"INIT"}
const SOVIET_EQUIVALENT := {
	"GACNST":"NACNST", "GAPOWR":"NAPOWR", "GAREFN":"NAREFN", "GAPILE":"NAHAND",
	"GAWEAP":"NAWEAP", "GAYARD":"NAYARD", "GADEPT":"NADEPT", "GAPILL":"NALASR", "AMCV":"SMCV", "CMIN":"HARV"
}

func roster_faction(owner_side: String = "ally") -> String:
	if owner_side == "ally" and mission.get("id") in [HeadGames.ID,TimeShift.ID]: return "soviet"
	if skirmish and _countries.get(owner_side) == "YuriCountry": return "yuri"
	return "soviet" if skirmish and _countries.get(owner_side) in ["Russians", "Confederation", "Arabs", "Africans"] else "allied"

func roster_id(allied_id: String, owner_side: String = "ally") -> String:
	if roster_faction(owner_side) == "yuri":
		return str(YURI_EQUIVALENT.get(allied_id,allied_id))
	return str(SOVIET_EQUIVALENT.get(allied_id, allied_id)) if roster_faction(owner_side) == "soviet" else allied_id

func s07_secret_product(id:String) -> bool:
	return not skirmish and mission.get("id")==HeadGames.ID and id=="GTGCAN"

func country_block_reason(id: String, owner_side: String = "ally") -> String:
	if s07_secret_product(id) and owner_side=="ally":
		return "" if "CASLAB" in owned_building_ids(owner_side) else "需占领秘密实验室"
	if GameData.hollywood_production_unit(id): return ""
	const ExpeditionRules = preload("res://scripts/expedition/rules.gd")
	if owner_side == "ally" and GameData.unit_index.has(id) and ExpeditionRules.active():
		if id in ExpeditionRules.context().get("licenses", []):
			return ""
	var product: Dictionary = GameData.unit_index.get(id, GameData.building_index.get(id, {}))
	var foreign_producer := false
	var faction: String = product.get("faction", "")
	if faction in ["allied", "soviet", "yuri"] and faction != roster_faction(owner_side) and GameData.is_ra2(id):
		var factory: String = product.get("built_at", "")
		if GameData.is_building(id): factory = {"soviet":"NACNST", "yuri":"YACNST", "allied":"GACNST"}[faction]
		foreign_producer = factory in owned_building_ids(owner_side)
	return GameData.ra2_country_block_reason(id, str(_countries.get(owner_side, "Americans")), foreign_producer)

func owns_production_yard(bid: String, owner_side: String) -> bool:
	if bid=="NEUTRALSTUDIO" or s07_secret_product(bid):
		var yards:=owned_building_ids(owner_side)
		return "GACNST" in yards or "NACNST" in yards or "YACNST" in yards
	var faction: String = GameData.building_index.get(bid, {}).get("faction", roster_faction(owner_side))
	return {"soviet":"NACNST","yuri":"YACNST","allied":"GACNST"}.get(faction) in owned_building_ids(owner_side)

func uses_split_campaign_deck() -> bool:
	return not skirmish and mission.get("id") == AlliedFinale.ID

func campaign_deck_factions() -> Array[String]:
	var result: Array[String] = []
	var owned := owned_building_ids()
	if "NACNST" in owned: result.append("soviet")
	if "GACNST" in owned: result.append("allied")
	return result

func campaign_yard_block_reason(bid: String, owner_side := "ally") -> String:
	if s07_secret_product(bid) and owner_side=="ally":
		if not owns_production_yard(bid,owner_side):return "缺少建造场"
		return country_block_reason(bid,owner_side)
	if owner_side != "ally" or not uses_split_campaign_deck() or not GameData.is_ra2(bid): return ""
	if owns_production_yard(bid, owner_side): return ""
	return "缺少对应阵营的建造场"

func has_construction_roster(faction: String, owner_side: String = "ally") -> bool:
	if not uses_split_campaign_deck() and faction == roster_faction(owner_side): return true
	return {"allied":"GACNST", "soviet":"NACNST", "yuri":"YACNST"}.get(faction) in owned_building_ids(owner_side)

func owned_building_ids(owner_side: String = "ally") -> Array:
	if ai_prerequisite_scan and ai_scan_buildings.has(owner_side):
		return ai_scan_buildings[owner_side]
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(52)
	var candidates := _buildings_for_side(owner_side)
	preload("res://scripts/world/battle_call_counters.gd").iterations(52,candidates.size())
	var out: Array = []
	for candidate in candidates:
		if not is_instance_valid(candidate): continue
		var b: Building = candidate
		if b.side != owner_side or b.hp <= 0.0 or b.is_dead() or b.is_queued_for_deletion() or b.under_construction:
			continue
		var id = b.get("building_id")
		if id != null:
			out.append(str(id))
	if ai_prerequisite_scan:
		ai_scan_buildings[owner_side] = out
	return out

# Boolean production gate reads live actors; no cross-frame prerequisite cache.
func production_prereqs_ok(id: String, owner_side: String) -> bool:
	if ai_prerequisite_scan:
		return GameData.ra2_prereq_ok(id, owned_building_ids(owner_side), allied_state, owner_side)
	if not GameData.ra2_prereq.has(id): return true
	var candidates := _buildings_for_side(owner_side)
	var witnesses: Dictionary = _production_witnesses.get_or_add(owner_side, {})
	for pre in GameData.production_prerequisites(id, allied_state, owner_side):
		var token := str(pre).strip_edges().to_upper()
		if token.is_empty(): continue
		# This is a live witness, not a cached prerequisite answer.
		var witness = witnesses.get(token)
		if is_instance_valid(witness) and _live_production_witness(witness, owner_side, token): continue
		witnesses.erase(token)
		var found := false
		for candidate in candidates:
			if not is_instance_valid(candidate): continue
			var building: Building = candidate
			# Reject irrelevant types before reading the remaining live actor state.
			if not GameData.supplies_prerequisite(building.building_id, token): continue
			if building.side != owner_side or building.hp <= 0.0 or building.is_dead() or building.is_queued_for_deletion() or building.under_construction: continue
			witnesses[token] = building
			found = true
			break
		if not found: return false
	return true

func _live_production_witness(building: Building, owner_side: String, token: String) -> bool:
	return building.side == owner_side and building.hp > 0.0 and not building.is_dead() \
		and not building.is_queued_for_deletion() and not building.under_construction \
		and GameData.supplies_prerequisite(building.building_id, token)

func structure_category(bid: String) -> String:
	return GameData.building_production_category(bid)

## Only the mixed campaign splits the player's construction lanes by faction.
func structure_lane_faction(bid: String, owner_side: String = "ally") -> String:
	if owner_side != "ally" or not uses_split_campaign_deck(): return ""
	var faction := str(GameData.building_index.get(bid, {}).get("faction", ""))
	return faction if faction in ["soviet", "allied"] else roster_faction(owner_side)

func _matches_structure_lane(bid: String, category: String, faction: String, owner_side: String) -> bool:
	return (category.is_empty() or structure_category(bid) == category) and (faction.is_empty() or structure_lane_faction(bid, owner_side) == faction)

## Lane views retain job dictionaries; mutate membership via request/cancel.
func structure_jobs(category: String = "", owner_side: String = "ally", faction: String = "") -> Array:
	var jobs: Array = struct_queue if owner_side == "ally" else enemy_struct_queue
	if category.is_empty() and faction.is_empty():
		return jobs
	return jobs.filter(func(job): return _matches_structure_lane(str(job.id), category, faction, owner_side))

func structure_reservations_enabled(owner_side: String = "ally") -> bool:
	return production_technology.is_unlocked("structure_queue", owner_side)

func structure_ready_count(category: String, owner_side: String = "ally", faction: String = "") -> int:
	var ready: Dictionary = struct_ready if owner_side == "ally" else enemy_struct_ready
	var count := 0
	for id in ready:
		if _matches_structure_lane(str(id), category, faction, owner_side):
			count += int(ready[id])
	return count

func hero_limit_reason(id: String, owner_side: String, include_training := true) -> String:
	if id not in GameData.UNIQUE_HERO_TYPES: return ""
	for unit in units:
		if actor_alive(unit) and unit.side == owner_side and unit.unit_id == id:
			if id not in MetaProgress.Academy.Stars.IDS and owner_side == "ally" and unit.special.get(preload("res://scripts/expedition/reinforcement_plan.gd").MEMBER, false) and preload("res://scripts/expedition/rules.gd").active():
				continue
			return "%s已在战场上" % GameData.get_unit(id).name
	if include_training:
		for producer in buildings:
			if actor_alive(producer) and producer.side == owner_side and producer.production.has(id):
				return "%s已在训练中" % GameData.get_unit(id).name
	return ""

func single_structure(id: String) -> bool:
	var definition: Dictionary = GameData.building_index.get(id, {})
	if definition.is_empty(): return false
	var defined_limit = definition.get("buildlimit")
	if defined_limit != null: return int(defined_limit) == 1
	return int(preload("res://scripts/core/yr_death_rules.gd").type_data(id).get("buildlimit",-1)) == 1

func limit_reason(id: String, owner_side: String, placing_paid := false) -> String:
	if not single_structure(id): return hero_limit_reason(id, owner_side)
	for b in buildings:
		if not actor_alive(b) or b.side != owner_side: continue
		if b.building_id == id: return "该建筑最多一座"
	if placing_paid: return ""
	var ready: Dictionary = struct_ready if owner_side == "ally" else enemy_struct_ready
	if int(ready.get(id,0)) > 0: return "该建筑已就绪，请先放置"
	var jobs: Array = struct_queue if owner_side == "ally" else enemy_struct_queue
	for job in jobs:
		if job.id == id: return "该建筑已在生产中"
	return ""

func production_price(item: Dictionary, owner_side: String) -> float:
	var price := float(item.get("cost", 0)) * preload("res://scripts/expedition/rules.gd").price_factor(str(item.get("id","")),owner_side)
	if GameData.ra2_source_units.get(item.get("id", ""), {}).get("kind") != "vehicle": return price
	if ai_prerequisite_scan and ai_scan_prices.has(owner_side):
		var factor: float = ai_scan_prices[owner_side]
		return price if factor < 0.0 else floorf(price * factor)
	for b in _warm_owner_buildings(owner_side):
		if is_instance_valid(b) and b.side == owner_side and b.data.has("vehicle_cost_factor") and b.is_operational():
			var factor := float(b.data.vehicle_cost_factor)
			if ai_prerequisite_scan: ai_scan_prices[owner_side] = factor
			return floorf(price * factor)
	if ai_prerequisite_scan: ai_scan_prices[owner_side] = -1.0
	return price

func structure_queue_block_reason(bid: String, owner_side: String = "ally") -> String:
	var limit := limit_reason(bid, owner_side)
	if not limit.is_empty(): return limit
	var category := structure_category(bid)
	var faction := structure_lane_faction(bid, owner_side)
	var jobs := structure_jobs(category, owner_side, faction)
	var ready := structure_ready_count(category, owner_side, faction)
	if not structure_reservations_enabled(owner_side):
		if ready > 0:
			return "请先放置或取消已就绪建筑；预约后续建造需要科技：建筑预约"
		if not jobs.is_empty():
			return "当前类别正在建造；预约后续建造需要科技：建筑预约"
	var capacity: int = production_technology.structure_capacity(owner_side)
	if jobs.size() + ready >= capacity:
		return "建造队列已满（含就绪，上限 %d）；可在局外科技升级" % capacity
	return ""

## 已就绪进入选址；预约必须经过同一科技/容量门禁。
func request_structure(bid: String, owner_side: String = "ally") -> void:
	if house_defeated(owner_side): return
	if not campaign_yard_block_reason(bid, owner_side).is_empty() or not GameData.building_production_block_reason(bid).is_empty(): return
	if owner_side == "ally" and int(struct_ready.get(bid, 0)) == 0 and resume_structure(bid): return
	var bd := GameData.get_building(bid)
	if bd.is_empty():
		return
	if bid=="NEUTRALSTUDIO" and not owns_production_yard(bid,owner_side):return
	if bid!="NEUTRALSTUDIO" and skirmish and bd.get("ra2", false) and not has_construction_roster(bd.faction, owner_side): return
	var country_reason := country_block_reason(bid, owner_side)
	if not country_reason.is_empty():
		if owner_side == "ally":
			Events.emit_message("无法建造 %s：%s" % [bd.get("name", bid), country_reason], Color(1.0, 0.6, 0.5))
		return
	if owner_side != "ally":
		if not structure_queue_block_reason(bid, owner_side).is_empty() or not GameData.ra2_prereq_ok(bid, owned_building_ids(owner_side), allied_state, owner_side):
			return
		if not owns_production_yard(bid, owner_side):
			return
		for job in enemy_struct_queue:
			if str(job.id) == bid:
				return
		enemy_struct_queue.append({"id": bid, "cost": float(bd.get("cost", 0)),
			"time": GameData.ra2_build_time(bd), "elapsed": 0.0, "paid": 0.0})
		return
	# 已就绪：直接进入放置模式
	if int(struct_ready.get(bid, 0)) > 0:
		set_build_mode(bid)
		return
	if not s07_secret_product(bid) and not GameData.ra2_prereq_ok(bid, owned_building_ids()):
		Events.emit_message("无法建造 %s：缺少前置：%s" % [bd.get("name", bid),
			GameData.ra2_missing_prereq_names(bid, owned_building_ids())], Color(1.0, 0.6, 0.5))
		return
	var queue_reason := structure_queue_block_reason(bid)
	if not queue_reason.is_empty():
		Events.emit_message(queue_reason, Color(1.0, 0.6, 0.5))
		return
	struct_queue.append({
		"id": bid,
		"cost": float(bd.get("cost", 0)),
		"time": GameData.ra2_build_time(bd),
		"elapsed": 0.0,
		"paid": 0.0,
	})
	Events.emit_message("开始建造 %s（$%d）" % [bd.get("name", bid), int(bd.get("cost", 0))], Color(0.7, 0.9, 1.0))
	Ra2Sfx.play_player_eva(self, "EVA_Building", 1000)

func structure_is_paused(bid: String) -> bool:
	var job := current_structure_job(structure_category(bid), structure_lane_faction(bid))
	return not job.is_empty() and str(job.id) == bid and bool(job.get("paused", false))

func resume_structure(bid: String) -> bool:
	if not structure_is_paused(bid): return false
	current_structure_job(structure_category(bid), structure_lane_faction(bid)).erase("paused")
	Ra2Sfx.play_player_eva(self, "EVA_Building", 0)
	return true

func structure_right_click(bid: String) -> void:
	var job := current_structure_job(structure_category(bid), structure_lane_faction(bid))
	if not job.is_empty() and str(job.id) == bid and not bool(job.get("paused", false)):
		job["paused"] = true
		Ra2Sfx.play_player_eva(self, "EVA_OnHold", 500)
		Events.emit_message("建造已暂停：左键继续，右键取消", Color(1.0, 0.8, 0.5))
		return
	cancel_structure(bid)

## 取消建造 / 收回就绪建筑（返还已投入资金或全额）。
func cancel_structure(bid: String) -> void:
	# 同类订单从队尾取消，保留已经投入资金的当前工程。
	for i in range(struct_queue.size() - 1, -1, -1):
		if str(struct_queue[i].get("id", "")) == bid:
			add_funds(float(struct_queue[i].get("paid", 0.0)))
			struct_queue.remove_at(i)
			Events.emit_message("已取消建造（返还资金）", Color(1.0, 0.8, 0.5))
			Ra2Sfx.play_player_eva(self, "EVA_Canceled", 500)
			return
	if int(struct_ready.get(bid, 0)) > 0:
		struct_ready[bid] = int(struct_ready[bid]) - 1
		if int(struct_ready[bid]) <= 0:
			struct_ready.erase(bid)
			struct_ready_order.erase(bid)
			if armed_build == bid:
				armed_build = ""
				queue_redraw()
				if hp_overlay != null:
					hp_overlay.queue_redraw()
		add_funds(float(GameData.get_building(bid).get("cost", 0)))
		Events.emit_message("已收回就绪建筑（返还资金）", Color(1.0, 0.8, 0.5))
		Ra2Sfx.play_player_eva(self, "EVA_Canceled", 500)

## 队列推进：分期付款建造，完成后进入就绪队列。
func _tick_structure_queue(delta: float) -> void:
	var split := uses_split_campaign_deck()
	if split and (not struct_queue.is_empty() or not struct_ready.is_empty()):
		var invalid := {}
		for job in struct_queue:
			if not campaign_yard_block_reason(str(job.id)).is_empty(): invalid[str(job.id)] = true
		for id in struct_ready:
			if not campaign_yard_block_reason(str(id)).is_empty(): invalid[str(id)] = true
		for id in invalid:
			while struct_queue.any(func(job): return job.id == id) or int(struct_ready.get(id,0)) > 0:
				cancel_structure(id)
	for category in ["building", "defense"]:
		if split:
			for faction in ["soviet", "allied"]:
				_tick_structure_jobs(delta, struct_queue, struct_ready, "ally", category, faction)
		else:
			_tick_structure_jobs(delta, struct_queue, struct_ready, "ally", category)
		_tick_structure_jobs(delta, enemy_struct_queue, enemy_struct_ready, "enemy", category)

func factory_speed_factor(owner_side: String, uid: String = "") -> float:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(58)
	if BattleRequest.extensions_enabled():
		return 1.0
	var count := 0
	for candidate in _buildings_for_side(owner_side):
		preload("res://scripts/world/battle_call_counters.gd").iterations(58, 1)
		if not actor_alive(candidate): continue
		var factory: Building = candidate
		if factory.side != owner_side or not factory.is_operational():
			continue
		if (uid.is_empty() and factory.is_hq) or (not uid.is_empty() and not factory.is_refinery() and factory.buildable.has(uid)):
			count += 1
	var data := GameData.get_building(roster_id("GACNST", owner_side)) if uid.is_empty() else GameData.get_unit(uid)
	return GameData.ra2_build_time(data) / GameData.ra2_build_time(data, maxi(1, count))

func structure_work_rate(owner_side: String = "ally", building_id: String = "") -> float:
	if GM.no_build_time: return GameData.ra2_build_time(GameData.get_building(building_id)) / GM.FAST_BUILD_SECONDS
	return BattleClock.production_scale(GameData.get_building(building_id)) * power_build_factor(owner_side) * factory_speed_factor(owner_side) * ai_build_factor(owner_side) * preload("res://scripts/expedition/red_alert.gd").production(self,owner_side)

func structure_production_block_reason(bid: String, owner_side: String = "ally") -> String:
	var mission_reason := GameData.building_production_block_reason(bid)
	if not mission_reason.is_empty(): return mission_reason
	if not owns_production_yard(bid, owner_side):
		return "缺少生产建筑：建造厂"
	var country_reason := country_block_reason(bid, owner_side)
	if not country_reason.is_empty(): return country_reason
	if s07_secret_product(bid) and owner_side=="ally": return ""
	var owned := owned_building_ids(owner_side)
	if not GameData.ra2_prereq_ok(bid, owned, allied_state, owner_side):
		return "缺少前置：" + GameData.ra2_missing_prereq_names(bid, owned, allied_state, owner_side)
	return ""

func _tick_structure_jobs(delta: float, jobs: Array, ready: Dictionary, owner_side: String, category: String = "", faction: String = "") -> void:
	if house_defeated(owner_side): return
	if jobs.is_empty():
		return
	var job_index := 0
	if not category.is_empty() or not faction.is_empty():
		job_index = -1
		for i in jobs.size():
			if _matches_structure_lane(str(jobs[i].id), category, faction, owner_side):
				job_index = i
				break
		if job_index < 0:
			return
	var it: Dictionary = jobs[job_index]
	if bool(it.get("paused", false)) or not structure_production_block_reason(str(it.id), owner_side).is_empty(): return
	# Preserve old saved queues, but an unplaced building occupies the lane
	# until this technology is granted. Never discard paid work on migration.
	if not category.is_empty() and not structure_reservations_enabled(owner_side) and structure_ready_count(category, owner_side, faction) > 0:
		return
	var t := maxf(0.01, float(it.get("time", 10.0)))
	var cost := maxf(0.0, float(it.get("cost", 0.0)))
	# RA2 低电：建造变慢（付款与计时同步缩放，总花费不变、工期拉长）
	var pf := structure_work_rate(owner_side, str(it.id))
	var step := minf(maxf(0.0, delta * pf), maxf(0.0, t - float(it.get("elapsed", 0.0))))
	var need := minf(cost / t * step, maxf(0.0, cost - float(it.get("paid", 0.0))))
	var pay := need
	if not (owner_side == "ally" and GM.infinite_funds) and funds_for(owner_side) < need:
		pay = maxf(0.0, funds_for(owner_side))
	if pay > 0.0 and not spend_side(owner_side, pay):
		pay = 0.0
	it["paid"] = float(it.get("paid", 0.0)) + pay
	it["elapsed"] = float(it.get("elapsed", 0.0)) + (step if need <= 0.0 else step * (pay / need))
	if float(it.get("elapsed", 0.0)) >= t - 0.0001 and float(it.get("paid", 0.0)) >= cost - 0.0001:
		var bid := str(it.get("id", ""))
		ready[bid] = int(ready.get(bid, 0)) + 1
		jobs.remove_at(job_index)
		if owner_side != "ally":
			return
		if not struct_ready_order.has(bid):
			struct_ready_order.append(bid)
		Events.emit_message("%s 就绪，点击图标选址" % GameData.get_building(bid).get("name", bid), Color(0.6, 1.0, 0.7))
		Ra2Sfx.play_player_eva(self, "EVA_ConstructionComplete")

## 当前正在建造的队列项（供 HUD 显示进度），无则返回空字典。
func current_structure_job(category: String = "", faction: String = "") -> Dictionary:
	var jobs := structure_jobs(category, "ally", faction)
	if jobs.is_empty():
		return {}
	return jobs[0]

# A yard delivers a structure when its checked footprint is placed. Extra wall
# segments, map fixtures and an MCV unfolding do not represent new deliveries.
func deliver_ready_structure(id: String, side: String, point: Vector2):
	if not campaign_yard_block_reason(id, side).is_empty() or not GameData.mission_tech_block_reason(id).is_empty(): return null
	var ready: Dictionary = struct_ready if side == "ally" else enemy_struct_ready
	if int(ready.get(id, 0)) <= 0 or GameData.get_building(id).is_empty(): return null
	if not limit_reason(id,side,true).is_empty(): return null
	ready[id] = int(ready[id]) - 1
	if ready[id] == 0:
		ready.erase(id)
		if side == "ally": struct_ready_order.erase(id)
	var placed = _place_building(id, side, point, true, true)
	if side=="ally" and placed!=null:preload("res://scripts/world/production_counts.gd").record(self,"building",id)
	for yard in buildings:
		if actor_alive(yard) and yard.side == side and yard.is_hq and yard.is_operational():
			yard.play_production_animation()
			break
	return placed

func _try_place_building(pos: Vector2) -> void:
	if not campaign_yard_block_reason(armed_build).is_empty() or not GameData.mission_tech_block_reason(armed_build).is_empty():
		armed_build = ""
		return
	var bd: Dictionary = GameData.get_building(armed_build)
	if bd.is_empty():
		armed_build = ""
		return
	var snapped := snap_build_pos(pos)
	var ready := int(struct_ready.get(armed_build, 0)) > 0
	var chk := build_spot_ok(snapped, bd, ready)
	if not chk["ok"]:
		Events.emit_message(str(chk["reason"]), Color(1.0, 0.6, 0.5))
		return
	if ready:
		# RA3：已付费就绪 → 直接成型放置
		var placed = deliver_ready_structure(armed_build, "ally", snapped)
		if placed == null: return
		var segments := WallArt.bridge(self, placed)
		if segments > 0: Events.emit_message("自动连接 %d 段围墙，已逐段扣费" % segments, Color(0.6, 0.9, 1))
		Events.emit_message("已部署 %s" % bd.get("name", ""), Color(0.6, 0.9, 1.0))
	else:
		var placed=_place_building(armed_build, "ally", snapped, false, true)
		if placed!=null:placed.special.player_build_order=true
		Events.emit_message("开始建造 %s" % bd.get("name", ""), Color(0.6, 0.9, 1.0))
	armed_build = ""

func _player_hq():
	for b in buildings:
		if is_instance_valid(b) and not b.is_dead() and not b.is_queued_for_deletion() and b.hp > 0.0 and b.is_hq and b.side == "ally":
			return b
	return null

# ================================================================== 波次

func _update_waves(delta: float) -> void:
	if paused or gm_unit_lab:
		return
	wave_timer -= delta
	Events.wave_countdown.emit(max(0.0, wave_timer))
	if wave_timer > 0.0:
		return
	if not prepared:
		prepared = true
		Events.emit_message("尤里军团开始进攻！" if mission.get("id") == HeadGames.ID else "⚠ 虫潮来袭！", Color(1.0, 0.5, 0.4))
		_spawn_wave(0)
		wave_index = 1
		_schedule_next()
		return
	if waves_exhausted:
		if endless:
			_endless_cycle()
		return
	_spawn_wave(wave_index)
	wave_index += 1
	_schedule_next()

func _schedule_next() -> void:
	if wave_index >= waves.size():
		if endless:
			waves_exhausted = true
			wave_timer = float(GameData.endless_scaling.get("loop_seconds", 90))
			Events.emit_message("循环加压中…", Color(1.0, 0.7, 0.5))
		else:
			waves_exhausted = true
			wave_timer = 99999.0
			Events.emit_message("敌军增援已到齐。摧毁两座信标和城堡。" if mission.get("id") == HeadGames.ID else "全部波次已投放，清除残余敌人即可获胜。", Color(0.7, 0.9, 1.0))
		return
	wave_timer = float(waves[wave_index].get("delay", 25))

func _spawn_wave(index: int) -> void:
	if index < 0 or index >= waves.size():
		return
	var w: Dictionary = waves[index]
	waves_cleared += 1
	Events.wave_started.emit(index + 1, str(w.get("name", "波次")))
	Events.emit_message("▶ 第 %d 波：%s" % [index + 1, w.get("name", "")], Color(1.0, 0.75, 0.45))
	var from_both := str(w.get("from", "")) == "both"
	var spawns: Array = w.get("spawns", [])
	for s in spawns:
		var uid := str(s.get("unit", ""))
		var count := int(s.get("count", 1))
		for i in range(count):
			var sp: Vector2 = spawn_points[0]
			if from_both and spawn_points.size() > 1:
				sp = spawn_points[i % spawn_points.size()]
			var jitter := Vector2(randf_range(-70, 70), randf_range(-70, 70))
			spawn_unit(uid, "enemy", sp + jitter)

func _endless_cycle() -> void:
	endless_loop += 1
	var sc: Dictionary = GameData.endless_scaling
	var add := int(sc.get("count_add_per_loop", 2))
	Events.emit_message("♻ 第 %d 轮加压（+%d 数量 / 血量 ×%.2f）" % [
		endless_loop + 1, add, pow(float(sc.get("hp_mult_per_loop", 1.18)), endless_loop)
	], Color(1.0, 0.55, 0.45))
	for w in waves:
		var spawns: Array = (w as Dictionary).get("spawns", [])
		for s in spawns:
			var uid := str(s.get("unit", ""))
			var count := int(s.get("count", 1)) + add * endless_loop
			for i in range(count):
				var sp: Vector2 = spawn_points[i % spawn_points.size()]
				spawn_unit(uid, "enemy", sp + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	wave_timer = float(sc.get("loop_seconds", 90))

# ================================================================== 胜负

func _check_end() -> void:
	if ended or gm_unit_lab:
		return
	if preload("res://scripts/expedition/rules.gd").active():
		if allied_state.has("expedition_task") and not has_base_assets("ally"):end_battle(false)
		return
	if skirmish:
		var survivors:Dictionary=preload("res://scripts/world/house_elimination.gd").update(self)
		var ally_alive:bool=survivors.get("ally",false)
		var enemy_alive:bool=survivors.get("enemy",false)
		if not BattleRequest.house_teams.is_empty():
			ally_alive = false
			enemy_alive = false
			for side: String in BattleRequest.house_teams:
				if not survivors.get(side,false): continue
				if BattleRequest.friendly("ally",side): ally_alive = true
				else: enemy_alive = true
		if not ally_alive and not enemy_alive:
			end_battle(false, true)
		elif not ally_alive:
			end_battle(false)
		elif not enemy_alive:
			end_battle(true)
		return
	if mission.get("id")==HeadGames.ID:
		if not HeadGames.check_player_loss(self):HeadGames.objectives(self)
		return
	if mission.get("id")==TimeShift.ID:return
	if _player_hq() == null:
		end_battle(false)
		return
	if endless:
		return
	var objectives: Dictionary = mission.get("objectives", {})
	if objectives.has("destroy_hives"):
		var hives := 0
		for b in buildings:
			if is_instance_valid(b) and b.side == "enemy" and b.is_spawner:
				hives += 1
		if hives == 0:
			end_battle(true)
		return
	if waves_exhausted:
		var foes := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				foes += 1
		if foes == 0:
			end_battle(true)

func actor_alive(actor) -> bool:
	if not is_instance_valid(actor): return false
	if actor is Unit:
		var unit: Unit = actor
		return not unit.is_queued_for_deletion() and unit.hp > 0.0 and not unit._dead
	if actor is Building:
		var building: Building = actor
		return not building.is_queued_for_deletion() and building.hp > 0.0 and not building._dead
	return not actor.is_queued_for_deletion() and actor.hp > 0.0 and not actor._dead

func actor_visible_to(observer: String, actor, viewer = null, ordinary_visibility := false, known_underwater_type = null) -> bool:
	if not is_instance_valid(actor):
		return false
	if actor is Unit and actor.embarked_in != null:
		return false
	if BattleRequest.friendly(actor.side,observer):return true
	if not ordinary_visibility:
		if observer == "ally" and actor.special.has("reed_watch"): return true
		if actor.special.has("contact_reporters") and Unit.FactionCards.contact_exposes(actor,observer):return true
		if actor is Unit and preload("res://scripts/units/expansion_2_infiltration.gd").hidden(actor) and preload("res://scripts/units/tanya_operations.gd").concealed(actor,observer):return false
		if actor is Unit and preload("res://scripts/units/tanya_talents.gd").hidden(actor) and preload("res://scripts/units/tanya_operations.gd").concealed(actor,observer):return false
		if actor.special.has("echo_cloaked") and not preload("res://scripts/units/tanya_operations.gd").detects(self,observer,actor):return false
		if float(actor.special.get("progression_v1",{}).get("dive_cloak",0))>0 and not preload("res://scripts/units/tanya_operations.gd").detects(self,observer,actor):return false
	if viewer is Unit:
		var scout=viewer if viewer.unit_id=="DEST" else viewer.logistics.carrier_owner
		if AlliedAbilities.alive(scout):
			var track:Dictionary=scout.special.get("progression_v1",{}).get("tracking",{})
			if track.get("left",0)>0 and is_same(track.get("target"),actor):return true
	var submerged: bool = NavalContact.submerged(actor) if known_underwater_type == null else (known_underwater_type and not actor.special.has("dive_remaining"))
	if submerged and get_tree().has_group(Unit.FactionCards.BUOYS) and Unit.FactionCards.sees_buoy(self,observer,actor,viewer):return true
	if fog != null and not fog.is_visible_at(observer,actor.global_position):return false
	if submerged and not NavalContact.detected(self,observer,actor):return false
	return ordinary_visibility or not Ra3Mirage.field_conceals(actor,observer) or preload("res://scripts/units/tanya_operations.gd").detects(self,observer,actor)

func reveal_attack(attacker, target) -> void:
	preload("res://scripts/world/battle_music_director.gd").exchange(self, attacker, target)
	if skirmish: ai_dispatch.record_exchange(attacker, target)
	if fog != null:
		fog.reveal_attack(attacker, target)

func position_visible_to(observer: String, p: Vector2) -> bool:
	return fog == null or fog.is_visible_at(observer, p)

func position_explored_by(observer: String, p: Vector2) -> bool:
	return fog == null or fog.is_explored_at(observer, p)

func has_surviving_assets(owner_side: String) -> bool:
	if house_defeated(owner_side): return false
	if mission.get("victory_condition", "short") != "annihilation":
		return has_base_assets(owner_side)
	for actor in units + buildings:
		if actor_alive(actor) and actor.side == owner_side and not (actor is Unit and actor.unit_id in ["V3ROCKET","DMISL","CMISL","BPLN","SPYP","PDPLANE"]):
			return true
	return false

func house_defeated(owner_side: String) -> bool:
	return skirmish and not gm_unit_lab and allied_state.get("defeated_houses",{}).has(owner_side)

func has_base_assets(owner_side: String) -> bool:
	for b in _warm_owner_buildings(owner_side):
		if not actor_alive(b) or b.side != owner_side: continue
		var tags: Array = b.data.get("tags", [])
		if not tags.has("civilian") and not tags.has("defense"):
			return true
	for u in units:
		if is_instance_valid(u) and u.side == owner_side and u.hp > 0.0 and not u._dead \
				and not u.is_queued_for_deletion() and not u.deploy_building_id().is_empty():
			return true
	return false

func end_battle(win: bool, draw: bool = false, gm_forced := false) -> void:
	if gm_unit_lab:
		Events.emit_message("单位测试场不进行胜负结算；请使用返回大厅退出。",Color(1,.8,.4))
		return
	if ended:
		return
	var expedition_result:=preload("res://scripts/expedition/rules.gd").active()
	if expedition_result:
		if not Expedition.settle(self,win and not draw):
			Events.emit_message(Expedition.error,Color.TOMATO)
			return
	var result := {
		"match_id": match_id,
		"win": win and not draw,
		"draw": draw,
		"outcome": "draw" if draw else ("win" if win else "loss"),
		"victory_condition": mission.get("victory_condition", "short"),
		"kills": kills,
		"waves": waves_cleared,
		"endless": endless,
		"loop": endless_loop,
		"mission": mission.get("id", "")
	}
	var eligible_win:=win and not draw and skirmish and not gm_forced
	result["rules_mode"] = BattleRequest.rules_mode
	result["gm_forced"] = gm_forced
	if BattleRequest.extensions_enabled() and not draw:
		if skirmish and win:
			var config := BattleRequest.skirmish_config
			result["alliance_reward"] = BattleRequest.Houses.victory_reward(config.get("houses", []), int(config.get("difficulty", 1)))
	if expedition_result:
		# Expedition owns its separate run-file commit above; retain that existing path.
		var appearance_rewards:=preload("res://scripts/world/production_counts.gd").settle(self,eligible_win)
		if eligible_win:appearance_rewards.append_array(MetaProgress.award_victory_skins(BattleRequest.victory_difficulty()))
		result.cosmetic_rewards=appearance_rewards
		result.rewards=MetaProgress.apply_battle_result(result) if BattleRequest.extensions_enabled() and not draw else {}
	elif not preload("res://scripts/rules/battle_rewards.gd").commit(self,result,eligible_win):
		Events.emit_message("结算存档失败，本局尚未结算；请恢复存储可写后重试。",Color.TOMATO)
		return
	ended = true
	if expedition_result and win and not draw:
		preload("res://scripts/world/house_elimination.gd").eliminate_hostiles(self)
	Music.finish_battle(win and not draw)
	BattleClock.leave_battle()
	for hook in ["add_funds", "deposit_funds", "kill_all_enemies", "skip_wave", "spawn_units", "force_end", "unlock_structure_queue", "unit_tools"]:
		GM.unregister_hook(hook)
	Events.battle_ended.emit(result)

# ================================================================== GM 钩子

func _register_gm_hooks() -> void:
	GM.register_hook("unit_tools",func(request):return preload("res://scripts/admin/gm_unit_tools.gd").run(self,request))
	GM.register_hook("add_funds", func(amount): add_funds(float(amount), true))
	GM.register_hook("deposit_funds", func(amount): add_funds(float(amount), false))
	GM.register_hook("kill_all_enemies", Callable(self, "_gm_kill_all"))
	GM.register_hook("skip_wave", Callable(self, "_gm_skip_wave"))
	GM.register_hook("spawn_units", Callable(self, "_gm_spawn_units"))
	GM.register_hook("force_end", Callable(self, "_gm_force_end"))
	GM.register_hook("unlock_structure_queue", func(): return production_technology.unlock("structure_queue", "ally"))

func _gm_kill_all() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("receive_hit"):
			e.receive_hit(999999.0, "tesla", {})
			n += 1
	Events.emit_message("GM 清场：%d 个敌方目标被抹除" % n, Color(1.0, 0.5, 0.5))
	return n

func _gm_skip_wave() -> void:
	wave_timer = 0.05
	Events.emit_message("GM：跳过当前倒计时", Color(1.0, 0.8, 0.4))

func _gm_spawn_units(uid: String, count: int, side: String) -> void:
	for i in range(int(count)):
		var pos := get_global_mouse_position() + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		if side == "enemy":
			pos = spawn_points[0] + Vector2(randf_range(-90, 90), randf_range(-90, 90))
		spawn_unit(uid, side, pos)
	Events.emit_message("GM：生成 %d 个 %s" % [int(count), uid], Color(1.0, 0.8, 0.4))

func _gm_force_end(win: bool) -> void:
	end_battle((win == true),false,true)

# ================================================================== 绘制

func _draw() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(11)
	RA2Art.begin_detail_draw(self)
	_draw_water()
	if allied_state.has("convoy_deployed"):preload("res://scripts/units/convoy_cards.gd").draw_world(self)
	preload("res://scripts/units/boris_fire_control.gd").draw_world(self)
	if allied_state.has("peregrine_hunters"):preload("res://scripts/units/peregrine_cards.gd").draw_world(self)
	if allied_state.has("peregrine_submunitions"):preload("res://scripts/units/peregrine_command.gd").draw_world(self)
	build_range_preview.paint(self)
	var attack_ranges := AttackRangePreview.ranges(self)
	_attack_ranges_drawn = not attack_ranges.is_empty()
	var basis := get_canvas_transform()
	basis.origin = Vector2.ZERO
	for i in attack_ranges.size():
		if i == _range_nodes.size():
			var ring := AttackRangePreview.new()
			ring.show_behind_parent = true
			add_child(ring)
			_range_nodes.append(ring)
		_range_nodes[i].show()
		_range_nodes[i].sync(attack_ranges[i], attack_ranges.size() > 1, basis)
	for i in range(attack_ranges.size(), _range_nodes.size()):
		_range_nodes[i].hide()
	_draw_order_marks()
	_draw_cast_flashes()
	if cast_slot >= 0 or hover_ability >= 0:
		_draw_ability_range()
	var had_build_ghosts := not _build_ghosts.is_empty()
	_build_ghosts.clear()
	if command_mode == "mcv_site" and selected_mcv() != null:
		var unit = selected_mcv()
		var site := snap_build_pos(get_global_mouse_position())
		_draw_build_preview(GameData.get_building(unit.deploy_building_id()), mcv_site(site))
	elif command_mode != "":
		_draw_command_cursor()
	if dragging:
		# 框选框按屏幕空间绘制：等距相机下若用世界坐标会变成斜菱形，
		# 这里用逆 canvas 变换把绘制切到屏幕像素空间，保证是正矩形（对齐红警2）。
		draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())
		var box := _drag_screen_rect()
		draw_rect(box, Color(0.45, 1.0, 0.6, 0.12))
		draw_rect(box, Color(0.45, 1.0, 0.6, 0.8), false, 2.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if armed_build != "":
		_draw_build_preview()
	if had_build_ghosts or not _build_ghosts.is_empty():
		_build_ghost_layer.queue_redraw()

## RA3 式水域渲染（世界坐标矩形 → 相机自动投影为等距菱形湖面）。
var _water_layer: WaterLayer = null
var _post_layer: PostLayer = null

func _draw_water() -> void:
	# 水体改由 WaterLayer 子节点绘制（分层 / 岸线泡沫 / 动态波纹）。
	# 逻辑水域 water_rects 不变，本函数只负责挂载表现层（幂等）。
	_ensure_visual_layers()

## 战场视觉层挂载（幂等）：水面层 + 后期调色层。都不参与判定。
func _ensure_visual_layers() -> void:
	if _water_layer == null:
		_water_layer = WaterLayer.new()
		_water_layer.name = "WaterLayer"
		_water_layer.rects = water_rects
		add_child(_water_layer)
	if _post_layer == null:
		_post_layer = PostLayer.new()
		_post_layer.name = "PostLayer"
		add_child(_post_layer)

## 高层级血条 overlay：每帧重绘，把所有单位/建筑血条画到 WORLD_HUD 层，
## 使其恒盖在建筑之上（不被前方建筑遮挡）。
## 关键：相机带 45° 等距旋转，须与实体一样先 Iso.begin 抵消，血条才会直立。
## 但 overlay 节点变换是 T(0)（实体是 T(p)），不能把世界坐标直接当作绘制坐标，
## 否则被映射到 S(z,z)·p 而飞离实体；须用 Iso.dir(p)（与 begin 互逆）作原点。
func _draw_superweapon_footprint() -> void:
	if command_mode != "superweapon" or not owns_superweapon(_armed_superweapon) or not _armed_superweapon.sw_ready(): return
	if not world_input_enabled() or _pointer_over_ui() or not get_viewport_rect().has_point(get_viewport().get_mouse_position()): return
	var type: String = _armed_superweapon.sw_type()
	if type.to_lower() == "chronosphere":
		preload("res://scripts/ui/chrono_target_preview.gd").draw(hp_overlay,self,get_global_mouse_position())
		return
	if type == "LightningStorm":
		preload("res://scripts/ui/storm_target_preview.gd").draw(hp_overlay,self,get_global_mouse_position())
		return
	var radius := preload("res://scripts/units/soviet_specials.gd").target_radius(type)
	if radius <= 0.0: return
	var point := get_global_mouse_position()
	if not preload("res://scripts/units/soviet_specials.gd").can_aim_at(_armed_superweapon,point): return
	var color := Color("#f64e50") if type == "IronCurtain" else Color("#ffb435")
	var boundary := Iso.ell(Iso.dir(point), radius, radius, 96)
	hp_overlay.draw_colored_polygon(boundary, Color(color,0.09))
	Iso.outline(hp_overlay,boundary,Color(0.06,0.05,0.04,0.75),4.0)
	Iso.outline(hp_overlay,boundary,color,2.0)

var show_all_health := false
var health_inspection_target = null
var _health_batch: MultiMeshInstance2D
var _ring_batch: MultiMeshInstance2D

func _draw_hp_overlay() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(12)
	if hp_overlay == null:
		return
	if _health_batch == null:
		_health_batch = preload("res://scripts/ui/world_health_bars.gd").new()
		hp_overlay.add_child(_health_batch)
	if _ring_batch == null:
		_ring_batch = preload("res://scripts/ui/world_cooldown_rings.gd").new()
		hp_overlay.add_child(_ring_batch)
	_ring_batch.begin(hp_overlay)
	AttackCooldownIndicator.world_batch = _ring_batch
	_health_batch.begin()
	HpBar.world_batch = _health_batch
	Iso.begin(hp_overlay)
	if get_tree().has_group(&"psychic_sensors"):
		preload("res://scripts/world/yuri_support.gd").draw_orders(self,hp_overlay)
	if allied_state.has("hollywood"): Hollywood.draw_supplies(self)
	if allied_state.has("head_grinder_crates"): HeadGames.draw_grinder_crates(self)
	if allied_state.has("allied_finale"): AlliedFinale.draw_cash_crates(self)
	_draw_superweapon_footprint()
	preload("res://scripts/units/soviet_specials.gd").draw_missiles(hp_overlay, self)
	const Psychic = preload("res://scripts/world/yuri_support.gd")
	var beacons := Psychic.active_beacons(self)
	var screen := get_viewport_rect().grow(64) # Includes rank, healing and multi-weapon rings.
	var projection := get_viewport().get_canvas_transform()
	var zoom := camera.zoom.x if is_instance_valid(camera) else 1.0
	for candidate in units:
		if not actor_alive(candidate): continue
		var u: Unit = candidate
		if u.special.has("controller") or u.special.has("dominator_source") or (not beacons.is_empty() and u.special.has("head_games_wing")):
			Psychic.draw_control(self, hp_overlay, u, beacons)
		# Bookmarks are drawn on the target even when their owner is offscreen.
		if u.special.has(Unit.YRTalents.BOOK) and actor_visible_to("ally", u):
			Unit.YRTalents.paint_bookmark(hp_overlay,self,u)
		if not (u.selected or u.hovered) or (not u.is_air and u.logistics.capacity == 0):
			var bar: Rect2 = u.hp_bar_rect()
			var bounds := Rect2(projection * u.global_position + bar.position * zoom, bar.size * zoom)
			if not screen.intersects(bounds): continue
		if not actor_visible_to("ally", u): continue
		var display_origin := Iso.dir(u.presentation_position())
		if u.occluded_by_bridge and u.is_visible_in_tree() and not u.is_air_target():
			# Retail BEHIND uses frames 1..17 of the 18-frame SHP.
			var frame := 1 + floori(Engine.get_physics_frames() * (15.0 * 200.0 / 256.0) / Engine.physics_ticks_per_second) % 17
			var size := Vector2(55,43)
			var source := Rect2(Vector2(frame%6,frame/6)*size,size)
			hp_overlay.draw_texture_rect_region(preload("res://assets/maps/yr/behind.png"),Rect2(display_origin-size*0.5,size),source)
		u.draw_hp_bar(hp_overlay, display_origin, show_all_health or is_same(health_inspection_target,u) or (u.selected and selected_units.size()==1))
		preload("res://scripts/ui/unit_status.gd").draw_world(u,hp_overlay,display_origin)
		AttackCooldownIndicator.paint(u, hp_overlay)
		if u.is_air: AircraftAmmoIndicator.paint(u, hp_overlay)
		if u.logistics.capacity > 0: TransportIndicator.paint(u, hp_overlay)
		if u.veteran_level > 0: VeterancyIndicator.paint(u, hp_overlay)
		if u.has_meta(HealingIndicator.PULSE): HealingIndicator.paint(u, hp_overlay)
		if u.selected or u.hovered: _paint_control_group(u,projection,zoom)
	for candidate in buildings:
		if not actor_alive(candidate): continue
		var b: Building = candidate
		if b.special.has("controller") or b.special.has("dominator_source") or (not beacons.is_empty() and b.special.has("head_games_wing")):
			Psychic.draw_control(self, hp_overlay, b, beacons)
		var bar: Rect2 = b.hp_bar_rect()
		var bounds := Rect2(projection * b.global_position + bar.position * zoom, bar.size * zoom)
		var on_screen := screen.intersects(bounds)
		if not on_screen and not (b.selected or b.hovered): continue
		if not actor_visible_to("ally", b): continue
		if on_screen:
			b.draw_hp_bar(hp_overlay, Iso.dir(b.global_position), show_all_health or is_same(health_inspection_target,b) or is_same(selected_building,b))
			if b.building_id=="R3REAPERTURRET":
				var mount=b.get_node_or_null("ReaperMount")
				if is_instance_valid(mount):preload("res://scripts/ui/unit_status.gd").draw_world(mount,hp_overlay,Iso.dir(b.global_position))
			if b.selected or b.hovered: _paint_control_group(b,projection,zoom)
		AttackCooldownIndicator.paint(b, hp_overlay)
		if b.selected or b.hovered: GarrisonIndicator.paint(b, hp_overlay, projection)
	HpBar.world_batch = null
	_health_batch.finish()
	_ring_batch.finish()
	AttackCooldownIndicator.world_batch = null
	for unit in selected_units:
		var held=NavalContact.grip_host(unit)
		if held!=null:
			var ring:=Iso.ell(Iso.dir(held.global_position),held.radius+4,held.radius+4)
			ring.append(ring[0])
			hp_overlay.draw_polyline(ring,Color.AQUAMARINE,2.0,true)
	for drone in inspected_drones:
		var host = inspection_host(drone)
		if host == null: continue
		var ring := Iso.ell(Iso.dir(host.global_position), host.radius+4, host.radius+4)
		ring.append(ring[0])
		hp_overlay.draw_polyline(ring,Color.AQUAMARINE,2.0,true)
	_draw_rally_flags()
	if command_mode == "mcv_site" and selected_mcv() != null:
		var site := snap_build_pos(get_global_mouse_position())
		var check_site := mcv_site(site)
		var yard := GameData.get_building(selected_mcv().deploy_building_id())
		_draw_build_caption(site, Building.placement_poly(yard), "基地车 · " + ("可在此展开" if check_site.ok else str(check_site.reason)), Color.AQUAMARINE if check_site.ok else Color.SALMON)
	if armed_build != "":
		var bd := GameData.get_building(armed_build)
		if not bd.is_empty():
			var pos := snap_build_pos(preview_override if preview_override != Vector2.INF else get_global_mouse_position())
			var chk := build_spot_ok(pos, bd, int(struct_ready.get(armed_build, 0)) > 0)
			var col := Color(0.45, 1.0, 0.6) if chk.ok else Color(1.0, 0.42, 0.4)
			var caption := "%s · %s" % [bd.get("name", armed_build), "可放置" if chk.ok else chk.reason]
			if not RA2Art.has_art(str(bd.get("id", armed_build))):
				caption += "（简易预览）"
			caption += " · 青：当前范围"
			if chk.ok and BuildRangePreview.provides_range(bd):
				caption += " · 绿：落成后新增（按当前占地）"
			elif not BuildRangePreview.provides_range(bd): caption += " · 不扩展建造范围"
			if WallArt.is_wall(bd) and int(struct_ready.get(armed_build, 0)) > 0:
				var plan := WallArt.plan(self, armed_build, "ally", pos)
				caption += " · 共 %d 段 / 补齐费用 %d" % [1 + plan.points.size(), plan.cost]
				if not plan.reason.is_empty(): caption += " · " + str(plan.reason)
			_draw_build_caption(pos, Building.placement_poly(bd), caption, col)

## 路径点队列：单位 → 后续点 的连线 + 小菱形
## 是否任一选中单位存在路径点队列（决定是否持续重绘）
## 集结点旗帜
func _draw_rally_flags() -> void:
	var b = selected_building
	var rally := rally_for(b)
	if rally == Vector2.INF:
		return
	# WORLD_HUD 层以屏幕像素绘制，旗帜直立且不随缩放变小。
	var canvas := hp_overlay.get_global_transform_with_canvas()
	var p := canvas * rally
	var col := Color(0.55, 0.95, 1.0, 0.9)
	hp_overlay.draw_set_transform_matrix(canvas.affine_inverse())
	hp_overlay.draw_line(canvas * b.global_position, p, Color(col, 0.35), 1.0)
	hp_overlay.draw_line(p, p + Vector2(0, -28), col, 2.0)
	hp_overlay.draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -28), p + Vector2(18, -22), p + Vector2(0, -15)]), col)
	hp_overlay.draw_arc(p, 7.0, 0.0, TAU, 24, col, 1.5)
	hp_overlay.draw_set_transform_matrix(Transform2D.IDENTITY)

## RA3-style visible territory, using the actual RA2 adjacency/grid rules.
func _draw_build_preview(bd: Dictionary = {}, site: Dictionary = {}) -> void:
	if bd.is_empty(): bd = GameData.get_building(armed_build)
	if bd.is_empty():
		return
	var pos := snap_build_pos(preview_override if preview_override != Vector2.INF else get_global_mouse_position())
	var chk := build_spot_ok(pos, bd, int(struct_ready.get(armed_build, 0)) > 0) if site.is_empty() else site
	var ok: bool = chk["ok"]
	var col := Color(0.45, 1.0, 0.6) if ok else Color(1.0, 0.42, 0.4)

	if ok and WallArt.is_wall(bd) and int(struct_ready.get(armed_build, 0)) > 0:
		WallArt.paint_plan(self, armed_build, pos)

	# 占地 = 建筑真实底盘多边形（与选中角标、碰撞体完全同一份几何，所见即所得）
	var fpoly := Building.placement_poly(bd)
	_fill_world_poly(fpoly, pos, Color(col.r, col.g, col.b, 0.22))
	# 建筑贴图单独走房色材质，放置边界仍用本层的绿/红提示。
	if not WallArt.is_wall(bd) or int(struct_ready.get(armed_build, 0)) <= 0 or not ok:
		_queue_build_ghost(bd, pos, ok)
	_draw_world_poly(fpoly, pos, col, 2.5)
	# 四角标（按真实底盘包围盒）
	var frect := Placement.aabb(fpoly, pos)
	var cl := minf(minf(frect.size.x, frect.size.y) * 0.35, 22.0)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner := frect.get_center() + Vector2(c.x * frect.size.x * 0.5, c.y * frect.size.y * 0.5)
		draw_line(corner, corner + Vector2(-c.x * cl, 0.0), col, 3.0)
		draw_line(corner, corner + Vector2(0.0, -c.y * cl), col, 3.0)
	# 准心
	draw_line(pos - Vector2(9, 0), pos + Vector2(9, 0), col, 1.5)
	draw_line(pos - Vector2(0, 9), pos + Vector2(0, 9), col, 1.5)

## 提示保持屏幕字号与水平方向，不随等距投影旋转或压扁。
func _draw_build_caption(pos: Vector2, poly: PackedVector2Array, text: String, col: Color) -> void:
	var canvas := hp_overlay.get_global_transform_with_canvas()
	var screen_poly := PackedVector2Array()
	for p in poly:
		screen_poly.append(canvas * (p + pos))
	var bounds := Placement.aabb(screen_poly)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var box_size := Vector2(text_size.x + 20.0, 30.0)
	var view_size := get_viewport_rect().size
	var at := Vector2(bounds.get_center().x - box_size.x * 0.5, bounds.end.y + 10.0)
	at.x = clampf(at.x, 8.0, maxf(8.0, view_size.x - box_size.x - 8.0))
	at.y = clampf(at.y, 8.0, maxf(8.0, view_size.y - box_size.y - 8.0))
	hp_overlay.draw_set_transform_matrix(canvas.affine_inverse())
	hp_overlay.draw_style_box(UiKit.panel_style(Color(0.035, 0.05, 0.07, 0.94), col.darkened(0.45), 4), Rect2(at, box_size))
	hp_overlay.draw_string(font, at + Vector2(10.0, 21.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	hp_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 建筑占地半尺寸（世界像素）。
## 优先用 RA2 原生 foundation（如 "5x3" = 5 格×3 格）换算，每格 = BUILD_GRID；
## 无 foundation 时回退碰撞半径 radius。
func foundation_half(bd: Dictionary) -> Vector2:
	return Building.foundation_half_for_data(bd)

## 建筑贴图和炮塔独立于放置反馈着色；透明度不改变房色阶的 RGB。
var _build_ghost_layer: Node2D
var _build_ghosts: Array[Dictionary] = []
var _build_ghost_turrets: Dictionary = {}

func _queue_build_ghost(bd: Dictionary, pos: Vector2, ok: bool, planned_mask: int = -1) -> void:
	_build_ghosts.append({"data": bd, "pos": pos, "ok": ok, "mask": planned_mask})

func _draw_build_ghosts() -> void:
	RA2Art.begin_detail_draw(_build_ghost_layer)
	if _build_ghosts.is_empty():
		return
	# 普通放置和基地车选址互斥；连墙预览的所有段也使用同一建筑 ID。
	var bd: Dictionary = _build_ghosts[0].data
	var faction := str(bd.get("faction", "allied"))
	var house := HouseColor.player_building_preview_color(faction)
	_build_ghost_layer.material = HouseColor.material_for(house)
	for ghost in _build_ghosts:
		_draw_build_ghost(ghost.data, ghost.pos, ghost.ok, ghost.mask)
	_build_ghost_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_build_ghost(bd: Dictionary, pos: Vector2, ok: bool, planned_mask: int) -> void:
	var img := str(bd.get("id", armed_build))
	var art: Dictionary = RA2Art.art(img)
	var tex: Texture2D = art.get("tex")
	if tex == null:
		return
	var rr := float(bd.get("radius", 30.0))
	var sz: Vector2 = RA2Art.frame_size(art)
	var anc: Vector2 = RA2Art.anchor(art, [0])
	var base := Vector2(-anc.x, rr * 0.35 - anc.y)
	var tint := Color(1.0, 1.0, 1.0, 0.55 if ok else 0.42)
	_build_ghost_layer.draw_set_transform(pos, Iso.eff_angle(), Iso.up())
	if WallArt.supported(bd, art):
		var mask := planned_mask if planned_mask >= 0 else WallArt.mask_at(pos, img, "ally", get_tree().get_nodes_in_group("buildings"))
		var rect := RA2Art.draw_rect(art, rr, [0], WallArt.lift(art, rr), WallArt.SCALE)
		RA2Art.draw_sprite(_build_ghost_layer, art, rect, RA2Art.src_rect(art, WallArt.frame(art, mask, 1.0)), tint)
		return
	RA2Art.draw_sprite(_build_ghost_layer, art, Rect2(base, sz), RA2Art.src_rect(art, 0), tint)
	if not _build_ghost_turrets.has(img):
		var turret := BuildingTurretArt.new()
		turret.setup(img)
		_build_ghost_turrets[img] = turret
	_build_ghost_turrets[img].draw_on(_build_ghost_layer, base, sz, 1.0, tint)

## 两个轴对齐矩形（占地盒）是否重叠。
func _rect_overlap(a: Vector2, ah: Vector2, b: Vector2, bh: Vector2) -> bool:
	return absf(a.x - b.x) < (ah.x + bh.x) and absf(a.y - b.y) < (ah.y + bh.y)

## 世界（地面）空间凸多边形填充
func _fill_world_poly(poly: PackedVector2Array, off: Vector2, col: Color) -> void:
	if poly.size() < 3:
		return
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(p + off)
	draw_colored_polygon(pts, col)

## 世界（地面）空间闭合多边形描边
func _draw_world_poly(poly: PackedVector2Array, off: Vector2, col: Color, w: float) -> void:
	for i in poly.size():
		draw_line(off + poly[i], off + poly[(i + 1) % poly.size()], col, w)

## 半宽半高 → 矩形多边形
func _rect_poly(half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])

## 任一物体的占地多边形（建筑用真实底盘；其它用半径方盒）
func footprint_of(b: Node) -> PackedVector2Array:
	if b == null or not is_instance_valid(b):
		return PackedVector2Array()
	if b.has_method("footprint_poly"):
		return b.footprint_poly()
	var r := float(b.get("radius"))
	return _rect_poly(Vector2(r, r))

## 建筑落成后，把压在新占地里的地面单位顶出去（RA2 里等同于单位被顶开，避免卡在墙里）
func _push_units_out(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	var poly := footprint_of(b)
	if poly.size() < 3:
		return
	var c: Vector2 = b.global_position
	for u in get_tree().get_nodes_in_group("ground_units"):
		if not is_instance_valid(u):
			continue
		var lp: Vector2 = u.global_position - c
		var edge: Vector2 = Placement.push_out_dir(poly, lp, c, Vector2.ZERO)
		if edge != Vector2.ZERO:
			var away: Vector2 = Vector2(u.global_position) - c
			away = away.normalized()
			if away == Vector2.ZERO:
				away = Vector2.DOWN
			u.global_position = edge + away * (float(u.get("radius")) + 6.0)
			u.velocity = Vector2.ZERO

## 取建筑对应的数据（用于占地换算）。
func _building_data(b: Node) -> Dictionary:
	if "data" in b and b.data is Dictionary:
		return b.data
	return {}

## 世界坐标吸附到建造网格（RA3 式对齐）
func snap_build_pos(p: Vector2) -> Vector2:
	return Vector2(roundf(p.x / BUILD_GRID) * BUILD_GRID, roundf(p.y / BUILD_GRID) * BUILD_GRID)

## 建造合法性（RA2 判定）：
##   ① 占地多边形必须完整落在地图内；
##   ② 不得与任何建筑 / 障碍 / 矿点 / 地面单位重叠；
##   ③ 水陆不可骑跨（要么整块陆地，要么整块水面做浮动平台）；
##   ④ 基地连通：必须与我方已有建筑的底盘接壤（RA2 Adjacent 范围）。
## 返回 {"ok": bool, "reason": String}
func build_spot_ok(pos: Vector2, bd: Dictionary, ignore_funds: bool = false, owner_side: String = "ally", deploying_unit = null, authored_node := false) -> Dictionary:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(13)
	var poly: PackedVector2Array
	if ai_prerequisite_scan:
		# Geometry extraction reads the art anchor and foundation. Reuse it for
		# all candidates of the same definition in this synchronous decision.
		var key: String = str(bd.get("id",""))
		var cached: Dictionary = ai_scan_footprints.get(key,{})
		if not cached.is_empty() and cached.data == bd:
			poly = cached.poly
		else:
			poly = Building.placement_poly(bd)
			ai_scan_footprints[key] = {"data":bd.duplicate(true),"poly":poly}
	else:
		poly = Building.placement_poly(bd)
	var rect := Placement.aabb(poly, pos)
	var center := rect.get_center()
	var reach := rect.size.length() * 0.5
	var indexed := units.size() >= 96
	var limit := limit_reason(str(bd.get("id","")),owner_side,ignore_funds)
	if not limit.is_empty(): return {"ok":false,"reason":limit}
	var reason := ""

	# ① 地图边界
	if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > map_size or rect.end.y > map_size:
		reason = "超出地图边界"

	if reason == "" and preload("res://scripts/world/bridge_damage.gd").overlaps(self,poly,pos):
		reason = "桥面禁止建造或展开基地车"

	if reason=="" and NativeMaps.has(map_layout()) and not NativeMaps.clear_rect(map_layout(),rect,bd.get("water_bound",false)):
		reason="原版地图边界、悬崖或水陆地形不可建"

	# ② 与建筑重叠（RA2：地基格不可占用）
	if reason == "":
		for b in (neighborhood.nearby(center, reach + neighborhood.max_footprint) if indexed else buildings):
			if not is_instance_valid(b) or not b is Building or b.is_dead() or b.is_queued_for_deletion():
				continue
			var bp := footprint_of(b)
			if bp.size() >= 3 and Placement.polys_overlap(poly, pos, bp, b.global_position):
				reason = "与建筑重叠"
				break

	# ② 与阻挡地形重叠
	if reason == "":
		for o in get_tree().get_nodes_in_group("obstacles") + get_tree().get_nodes_in_group("native_ore_drills"):
			if is_instance_valid(o) and Placement.circle_hits_rect(rect, o.global_position, float(o.get("radius"))) and Placement.circle_hits_poly(poly, o.global_position, float(o.get("radius")), pos):
				reason = "地形不可建"
				break

	# ② 与资源点重叠
	if reason == "":
		for nd in (ore_neighborhood.nearby(center, reach + ore_neighborhood.max_unit_radius) if indexed else get_tree().get_nodes_in_group("resource_nodes")):
			if is_instance_valid(nd) and not (nd.native_variant >= 0 and nd.is_empty()) and Placement.circle_hits_rect(rect, nd.global_position, float(nd.get("radius"))) and Placement.circle_hits_poly(poly, nd.global_position, float(nd.get("radius")), pos):
				reason = "与矿点重叠"
				break

	# ② 与地面单位重叠（否则单位会被新建建筑卡死）
	if reason == "":
		for u in (neighborhood.nearby(center, reach + neighborhood.max_unit_radius) if indexed else get_tree().get_nodes_in_group("ground_units")):
			if is_instance_valid(u) and u is Unit and not u.is_air and u != deploying_unit and not u._dead and not u.is_queued_for_deletion() and Placement.circle_hits_rect(rect, u.global_position, float(u.get("radius"))) and Placement.circle_hits_poly(poly, u.global_position, float(u.get("radius")), pos):
				reason = "与单位重叠"
				break

	# ③ 水陆一致：船坞（water_bound）必须完全在水面，其余建筑不许占水面。
	if reason == "" and path_service != null:
		var wet := 0
		var dry := 0
		for p in poly:
			if path_service.in_water(p + pos):
				wet += 1
			else:
				dry += 1
		if (bd.get("water_bound", false) == true):
			if dry > 0:
				reason = "船坞必须建在水面"
		elif wet > 0:
			reason = "不能建在水面"

	# ④ BaseNormal 来源：原版 Adjacent；扩展模式建造场至少提供 12 格范围。
	# 与范围绘制共用源建筑规则，地形和占用由上方检查。
	if reason == "" and deploying_unit == null and not authored_node:
		var zones: Array
		if ai_prerequisite_scan:
			var by_type: Dictionary = ai_scan_zones.get_or_add(owner_side, {})
			if not by_type.has(bd.id):
				by_type[bd.id] = BuildRangePreview.placement_zones(self, bd, owner_side)
			zones = by_type[bd.id]
		else:
			zones = BuildRangePreview.placement_zones(self, bd, owner_side)
		if not BuildRangePreview.zones_allow(rect, zones):
			reason = "超出建造范围，请靠近己方建筑或盟友建造场"

	if reason == "" and not ignore_funds and funds_for(owner_side) <= 0.0:
		reason = "资金不足"
	return {"ok": reason == "", "reason": reason}

func register_kill() -> void:
	kills += 1

func _scoreable_alive_count(side: String, friendly_group := false) -> int:
	var count := 0
	for actor in units:
		if not is_instance_valid(actor) or actor._dead or actor.is_queued_for_deletion() or actor.hp <= 0.0: continue
		if actor.side == "neutral" or actor.unit_id in SUPPORT_FLIGHTS: continue
		var same_side: bool = BattleRequest.friendly("ally", actor.side) if friendly_group else (not BattleRequest.friendly("ally", actor.side) if side == "enemy" else actor.side == side)
		if not same_side: continue
		if actor.special.get("house_eliminated", false) or AlliedAbilities.flag(actor, "DontScore"): continue
		count += 1
	return count


# ================================================================== 技能瞄准 / 范围显示
# 红警3 式：带作用范围的技能（radius > 0）点击后先进入「瞄准态」，在施法者周围实时
# 显示作用范围与受影响单位，左键确认 / 右键或 Esc 取消；无范围的自身增益保持即时施放。

## 技能目标配色：友军 绿 / 敌军 红 / 其它 青
func _ability_color(target: String) -> Color:
	match target:
		"enemies":
			return Color(1.0, 0.46, 0.40)
		"allies":
			return Color(0.46, 1.0, 0.62)
	return Color(0.62, 0.92, 1.0)

## HUD 技能按钮悬停：仅预览作用范围（不施放）
func preview_ability(slot: int) -> void:
	if cast_slot >= 0:
		return
	hover_ability = slot
	queue_redraw()

## 清除悬停预览
func clear_ability_preview() -> void:
	if hover_ability >= 0:
		hover_ability = -1
		queue_redraw()

## 请求释放技能（HUD 技能按钮 / Q/W/E 调用，兼容 Shift 组合）。
## >0：即时施放成功数量；-1：进入瞄准态；0：不可用（未选 / 冷却中 / 无此技能）。
func request_ability(slot: int) -> int:
	var u = selected_skill_unit()
	if u == null or not is_instance_valid(u):
		return 0
	var ab: Ability = u.ability_at(slot)
	if ab != null and ab.id == "allied_special" and not u.deploy_building_id().is_empty():
		if selected_mcv() == null or not u.ability_ready(slot): return 0
		arm_command("mcv_site")
		return 1
	if ab == null:
		return 0
	# A disabled lead chopper must not block the rest; each member checks readiness.
	if not u.ability_ready(slot) and not (u.unit_id == "SCHP" and ab.id == "allied_special"):
		return 0
	if ab.radius <= 0.0 and ab.id not in Unit.PoolCards.POINT_CARDS:
		# 自身增益：即时施放（不打断操作节奏）
		var n := use_ability_selected(slot)
		if n > 0:
			_add_cast_flash(u.global_position, _ability_radius(ab), _ability_color(ab.target))
		return n
	# 有作用范围：进入瞄准态（再次点同一槽 = 取消）
	if cast_slot == slot:
		cancel_cast()
		return -1
	cast_slot = slot
	hover_ability = -1
	if command_mode != "":
		command_mode = ""
		Events.command_mode_changed.emit("")
	armed_build = ""
	Events.emit_message("施放瞄准：%s（左键确认 / 右键取消）" % ab.display_name, _ability_color(ab.target))
	queue_redraw()
	return -1

## 确认施放（左键）
func confirm_cast(click_point := Vector2.INF) -> void:
	if cast_slot < 0:
		return
	var slot := cast_slot
	cast_slot = -1
	var primary = selected_skill_unit()
	if is_instance_valid(primary) and primary.ability_at(slot)!=null and primary.ability_at(slot).id==Unit.Convoy.Cards.PRESS:
		if not click_point.is_finite():click_point=get_global_mouse_position()
		if not primary.use_ability(slot,click_point):
			Events.emit_message("老秤：请选择能接近的可见敌方地面车辆或建筑。",Color.SALMON)
		queue_redraw()
		return
	if is_instance_valid(primary) and primary.ability_at(slot) != null and primary.ability_at(slot).id in Unit.PoolCards.POINT_CARDS:
		var id: String = primary.ability_at(slot).id
		var count := 0
		for actor in selected_units:
			if actor_alive(actor) and actor.side == "ally" and actor.use_ability(UnitSkillLayout.find(actor, id), get_global_mouse_position()): count += 1
		if count == 0: Events.emit_message("目标无效、超出范围或技能仍在冷却")
		return
	if is_instance_valid(primary) and primary.ability_at(slot)!=null and primary.ability_at(slot).id=="ap_leizhu_court":
		var point:=get_global_mouse_position()
		var used:=0
		for actor in selected_units:
			if actor_alive(actor) and actor.side=="ally" and preload("res://scripts/units/leizhu_court_order.gd").request(actor,point):used+=1
		if used<=0:Events.emit_message("请选择可见陆地，中心和三根电极落点均须可放置；距离较远时会自动驶近施放",Color(1,.7,.4))
		queue_redraw()
		return
	if is_instance_valid(primary) and primary.ability_at(slot)!=null and primary.ability_at(slot).id=="ap_peregrine_hunt":
		var used:=preload("res://scripts/units/peregrine_hunt_order.gd").selected(self,get_global_mouse_position())
		if used<=0:Events.emit_message("请选择可见敌地面单位或建筑，并确保至少有2发弹药",Color(1,.7,.4))
		queue_redraw()
		return
	if is_instance_valid(primary) and primary.ability_at(slot)!=null and primary.ability_at(slot).id=="ap_overload_seal":
		var used:=preload("res://scripts/units/expansion_2_overload.gd").cast_selected(self,get_global_mouse_position())
		if used<=0:Events.emit_message("请选择5格内可见敌战斗载具或武装建筑；已有封条不能叠加",Color(1,.7,.4))
		queue_redraw()
		return
	if is_instance_valid(primary) and primary.ability_at(slot)!=null and primary.ability_at(slot).id=="ap_buoy":
		var point:=get_global_mouse_position()
		var used:=0
		for ship in selected_units:
			if actor_alive(ship) and ship.use_ability(UnitSkillLayout.find(ship,"ap_buoy"),point):used+=1
		if used==0:Events.emit_message("请选择驱逐舰 660 范围内的水面",Color(1,0.7,0.4))
		else:_add_cast_flash(point,Unit.FactionCards.BUOY_RADIUS,_ability_color("water"))
		queue_redraw()
		return
	if is_instance_valid(primary) and primary.ability_at(slot) != null and primary.ability_at(slot).id.begins_with("allied_"):
		var id: String = primary.ability_at(slot).id
		var point := get_global_mouse_position()
		var target = support_order_target(point, id in ["allied_engineer", "allied_infiltrate"])
		var count := 0
		for actor in selected_units.duplicate():
			if actor_alive(actor) and UnitSkillLayout.find(actor, id) >= 0:
				if AlliedAbilities.use(actor, id, target, point): count += 1
		if count == 0: Events.emit_message("该目标不符合技能条件，未执行指令", Color(1, 0.7, 0.4))
		else: _add_order_mark(point, "attack")
		queue_redraw()
		return
	var flash_col := Color(0.62, 0.92, 1.0)
	var flash_rad := 70.0
	var marks: Array = []
	for u in selected_units:
		if not is_instance_valid(u) or not u.has_method("ability_at"):
			continue
		var ab: Ability = u.ability_at(UnitSkillLayout.find(u, primary.ability_at(slot).id)) if primary != null and primary.ability_at(slot) != null else null
		if ab == null or not ab.ready():
			continue
		flash_col = _ability_color(ab.target)
		flash_rad = _ability_radius(ab)
		if ab.id!="ap_shock_pulse":marks.append(u.global_position)
	var n := use_ability_selected(slot)
	if n <= 0:
		Events.emit_message("技能不可用或仍在冷却", Color(0.62, 0.68, 0.76))
	else:
		for p in marks:
			_add_cast_flash(p, flash_rad, flash_col)
	queue_redraw()

## 取消瞄准（右键 / Esc）
func cancel_cast() -> void:
	if cast_slot < 0:
		return
	cast_slot = -1
	Events.emit_message("已取消施放", Color(0.8, 0.8, 0.8))
	queue_redraw()

## 显示半径：范围技能用自身 radius；无范围技能给一个可读的默认圈
func _ability_radius(ab: Ability) -> float:
	return ab.radius if ab.radius > 0.0 else 70.0

## 当前要展示范围的技能（瞄准态优先，其次悬停预览）
func _range_preview_ability() -> Ability:
	var slot := cast_slot if cast_slot >= 0 else hover_ability
	if slot < 0:
		return null
	var u = selected_skill_unit()
	if u == null or not is_instance_valid(u):
		return null
	return u.ability_at(slot)

## 落在作用范围内的单位（供高亮）
func _ability_affected(center: Vector2, radius: float, target: String) -> Array:
	var out: Array = []
	var group: String = "enemies" if target == "enemies" else "allies"
	for e in get_tree().get_nodes_in_group(group):
		if is_instance_valid(e) and center.distance_to(e.global_position) <= radius:
			out.append(e)
	return out

## 绘制技能作用范围（等距地面圆 + 受影响单位高亮 + 施法者标记 + 鼠标准心）
func _draw_ability_range() -> void:
	var pulse=preload("res://scripts/buildings/tesla_pulse.gd")
	if hover_ability==1 and pulse.available(selected_building):
		var ab:Ability=pulse.ability(selected_building)
		if ab.radius<=0:return
		var ring:=Iso.ground_circle(selected_building.global_position,ab.radius)
		draw_colored_polygon(ring,Color(0.62,0.92,1,0.07))
		Iso.outline(self,ring,Color(0.62,0.92,1,0.5),1.5)
		return
	var ab: Ability = _range_preview_ability()
	if ab == null or ab.id==Unit.Convoy.Cards.PRESS:
		return
	var u = selected_skill_unit()
	if u == null or not is_instance_valid(u):
		return
	var aiming: bool = cast_slot >= 0
	if ab.id=="ap_leizhu_court":
		preload("res://scripts/units/leizhu_cards.gd").draw_preview(self,u,get_global_mouse_position() if aiming else u.position+Vector2.from_angle(u.hull_angle)*2*55)
		return
	if ab.id=="ap_boris_corridor":
		preload("res://scripts/units/boris_fire_control.gd").draw_preview(self,u,get_global_mouse_position() if aiming else u.position+Vector2.from_angle(u.hull_angle)*2*55)
		return
	var col: Color = _ability_color(ab.target)
	var rad: float = ab.radius
	if rad <= 0.0:
		rad = 34.0
	var c: Vector2 = get_global_mouse_position() if aiming and ab.id=="ap_buoy" else u.global_position
	draw_colored_polygon(Iso.ground_circle(c, rad), Color(col.r, col.g, col.b, 0.13 if aiming else 0.07))
	Iso.outline(self, Iso.ground_circle(c, rad), Color(col.r, col.g, col.b, 0.95 if aiming else 0.5), 2.5 if aiming else 1.5)
	if aiming:
		Iso.outline(self, Iso.ground_circle(c, rad * 0.66), Color(col.r, col.g, col.b, 0.4), 1.5)
	for e in _ability_affected(c, rad, ab.target):
		var er: float = float(e.get("radius")) + 6.0
		Iso.outline(self, Iso.ground_circle(e.global_position, er), Color(col.r, col.g, col.b, 0.9), 2.0)
	Iso.outline(self, Iso.ground_circle(c, 12.0), Color(col.r, col.g, col.b, 0.95), 2.0)
	if aiming:
		# 提示文字 + 鼠标准心改用屏幕空间绘制，避免被等距相机旋转/压扁
		var xf := get_global_transform_with_canvas()
		var sp: Vector2 = xf * get_local_mouse_position()
		var csp: Vector2 = xf * to_local(c)
		draw_set_transform_matrix(xf.affine_inverse())
		draw_line(sp + Vector2(-11.0, 0.0), sp + Vector2(11.0, 0.0), col, 2.0)
		draw_line(sp + Vector2(0.0, -11.0), sp + Vector2(0.0, 11.0), col, 2.0)
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(font, csp + Vector2(-rad, -rad - 30.0), "%s（%.0f）" % [ab.display_name, rad], HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 14, col)
			draw_string(font, sp + Vector2(-14.0, 34.0), "左键施放  ·  右键取消", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.r, col.g, col.b, 0.85))
		draw_set_transform_matrix(Transform2D.IDENTITY)

## 施放瞬间的范围扩散圈
func _add_cast_flash(pos: Vector2, radius: float, col: Color) -> void:
	_cast_flashes.append({ "pos": pos, "r": maxf(28.0, radius), "col": col, "t": 0.6, "life": 0.6 })
	queue_redraw()

func _update_cast_flashes(delta: float) -> void:
	if _cast_flashes.is_empty():
		return
	for f in _cast_flashes:
		f["t"] = float(f["t"]) - delta
	_cast_flashes = _cast_flashes.filter(func(f): return float(f["t"]) > 0.0)

func _draw_cast_flashes() -> void:
	for f in _cast_flashes:
		var life: float = maxf(0.001, float(f["life"]))
		var k: float = 1.0 - clampf(float(f["t"]) / life, 0.0, 1.0)
		var base: float = float(f["r"])
		var col: Color = f["col"]
		var pos: Vector2 = f["pos"]
		var rr: float = lerpf(base * 0.4, base * 1.15, k)
		Iso.outline(self, Iso.ground_circle(pos, rr), Color(col.r, col.g, col.b, (1.0 - k) * 0.9), 3.0)
		if k < 0.55:
			var rr2: float = lerpf(base * 0.15, base * 0.9, k / 0.55)
			draw_colored_polygon(Iso.ground_circle(pos, rr2), Color(col.r, col.g, col.b, (0.55 - k) * 0.45))
		Iso.outline(self, Iso.ground_circle(pos, base), Color(col.r, col.g, col.b, (1.0 - k) * 0.4), 2.0)
