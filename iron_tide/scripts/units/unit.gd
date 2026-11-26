extends CharacterBody2D

class_name Unit
const Convoy=preload("res://scripts/units/convoy_heroes.gd")
const P=preload("res://scripts/rules/progression_parameters.gd")
const Furnace = preload("res://scripts/units/furnace_legend.gd")
const DomainCards=preload("res://scripts/units/domain_cards.gd")
const YRTalents=preload("res://scripts/units/yr_unit_talents.gd")
const Training = preload("res://scripts/rules/skill_training.gd")
const ReaperSplit = preload("res://scripts/units/ra3_reaper_split.gd")
const SovietSpecials = preload("res://scripts/units/soviet_specials.gd")
const TankHero = preload("res://scripts/units/tank_hero.gd")
const SovietWeapons = preload("res://scripts/units/soviet_advanced.gd")
## 通用作战单位。数据来自 GameData，加成来自 MetaProgress。
## 行为：待机 / 移动 / 攻击 / 采集。寻敌与决策做了节流以支撑上百单位。
## 建模：全部程序化绘制（多边形 + 明暗分层 + 面板缝线 + 阵营涂装），带行进/开火动画。

const CasemateFrame = preload("res://scripts/units/tnkd_exoframe.gd")
const ReverseAttack = preload("res://scripts/units/reverse_attack.gd")
const VehicleSteering = preload("res://scripts/units/vehicle_steering.gd")
const TacticalTargeting = preload("res://scripts/core/tactical_targeting.gd")
var _body_visibility: VisibleOnScreenNotifier2D
var _air_cull_lift := 0.0
const CULLABLE_NATIVE_AIR := ["ORCA","BEAG","HORNET","ASW","ZEP","JUMPJET","SHAD","SCHP"]
var _combat_world: Battle
var motion_pose := preload("res://scripts/units/unit_motion_pose.gd").new()
var _local_traffic := preload("res://scripts/units/local_traffic.gd").new()

var _scan_grant_until := -1
const MISSILE_CARRIERS := ["V3","DRED"]
const DEPLOYING_INFANTRY := ["E1","GGI"]
const FACTION_TICK_PASSIVES := ["ps_phase","ps_limiter","ps_contact"]
const TARGET_REFRESH := 0.32
const FoundationTransit = preload("res://scripts/expedition/foundation_transit.gd")
const ARRIVE_EPS := 10.0
const FLOW_HANDOFF := 46.0   # 距目标这么近时改用直行微调（流场只负责长途导航）

var data: Dictionary = {}
var side: String = "ally":
	set(value):
		if side == value: return
		if is_in_group(NavalContact.sensor_group(side)):
			remove_from_group(NavalContact.sensor_group(side))
			add_to_group(NavalContact.sensor_group(value))
		side = value
var faction: String = "allied"
enum WeaponTargetRule { STANDARD, GRINDER, SQUID, BOMB, INFEST, COMMANDO }
var _weapon_target_rule := WeaponTargetRule.STANDARD
var unit_id: String = "":
	set(value):
		unit_id = value
		match value:
			"R3APOC": _weapon_target_rule = WeaponTargetRule.GRINDER
			"SQD": _weapon_target_rule = WeaponTargetRule.SQUID
			"IVAN", "CIVAN": _weapon_target_rule = WeaponTargetRule.BOMB
			"DRON": _weapon_target_rule = WeaponTargetRule.INFEST
			_: _weapon_target_rule = WeaponTargetRule.COMMANDO if value in CommandoCombat.IDS else WeaponTargetRule.STANDARD
var mobile_yard: Dictionary = {}
var display_name: String = ""

# --- 基础属性（已含局外加成）---
var base_hp: float = 100.0
var max_hp: float = 100.0
var hp: float = 100.0
var armor: String = "unarmored"
var move_speed: float = 100.0
# ---- RA2 移动规则运行时（faction.mjs 产出的 data["move"]）----
var _mv_cache: Dictionary = {}       # move 字段缓存（data 不变化）
var _hull_prev: float = 0.0          # 本帧开始时的车体朝向（用于 ROT 限速）
var _turret_prev: float = 0.0        # 本帧开始时的炮塔朝向
var _spd_cur: float = 0.0            # Accelerates=yes 时的当前速度
var _crush_cd: float = 0.0
var _crush_death: bool = false            # 本次死亡是否由碾压造成（决定 DieSound vs CrushSound）
var base_speed: float = 100.0
var radius: float = 8.0
var sight: float = 300.0
var is_air: bool = false
## 海军的移动域标记：只用「水面网格」寻路，且不允许登岸。
var occluded_by_bridge := false # Presentation state rebuilt by the battle depth pass.
var is_naval: bool = false
var is_amphibious := false
var powered_unit := preload("res://scripts/units/powered_unit.gd").new()
var hover_motion := preload("res://scripts/units/unit_hover.gd").new()
var embarked_in = null
var logistics := preload("res://scripts/units/unit_logistics.gd").new()
var flight := preload("res://scripts/units/unit_flight.gd").new()
var crushable: bool = false              # RA2 Crushable=（可被碾压）；由 move 规则填充
var is_harvester: bool = false

# --- RA2 原图（Step C 阶段2）：非空时 _draw 用 SHP/VXL 素材替换程序化建模 ---
# Shared render resources are rebound only when an appearance is assigned.
# Gameplay transforms, tint and animation clocks remain live draw inputs.
var _voxel_hull: VoxelRenderer.Atlas
var _voxel_turret: VoxelRenderer.Atlas
var _voxel_shadow: VoxelRenderer.Atlas
var _ra2: Dictionary = {}:
	set(value):
		_ra2 = value
		_voxel_hull = VoxelRenderer.atlas(value) if VoxelRenderer.TYPES.has(unit_id) else null
var _ra2_tur: Dictionary = {}:
	set(value):
		_ra2_tur = value
		_voxel_turret = VoxelRenderer.atlas(value) if VoxelRenderer.TYPES.has(unit_id) else null
var _ra2_shd: Dictionary = {}:
	set(value):
		_ra2_shd = value
		_voxel_shadow = VoxelRenderer.atlas(value) if VoxelRenderer.TYPES.has(unit_id) else null
var _weapon_art: Dictionary = {}
var _turret_draw_rect := Rect2()
var _turret_draw_source := Rect2()
# 最近一帧的绘制参数（供 hit_test()/art_center() 复用；铁律：判定几何 = 绘制几何）
var shield_sprite: Sprite2D
var _body_bounds := Rect2() # Visible body in local drawing coordinates, excluding ground shadow.
const DamageParticles = preload("res://scripts/units/vehicle_damage_particles.gd")
var _has_damage_particles := false
var _art_frame: int = -1
var _pick_body_rect := Rect2()
var _pick_body_art: Dictionary
var _drew_moving_pose := false
var _pose_redraw_pending := false
var _passage_tick := -1
var _passage_epoch := -1
var _passage_grid_revision := -1
var _passage_service_id := 0
var _passage_from := Vector2.INF
var _passage_goal := Vector2.INF
var _passage_radius := 0.0
var _passage_points := PackedVector2Array()
var _art_aframes: Array = []
var _art_sc: float = 1.0
const TankFinish=preload("res://scripts/units/tank_finish.gd")
var tank_finish:TankFinish
const CoastalRig=preload("res://scripts/units/coastal_range_rig.gd")
const YRFinish=preload("res://scripts/units/yr_signature_finish.gd")
const TankHeroSkin=preload("res://scripts/units/tank_hero_skin.gd")
var casemate_thruster:CasemateFrame
var yr_finish:YRFinish
var night_skin:RefCounted
var hero_art:RefCounted
var peregrine_fx:RefCounted
var _art_lift: float = 0.0
var _shadow_draw_rect := Rect2()
# Canvas draw commands retain a RID, not the ImageTexture resource. Keep the
# displayed shadow alive even when another unit evicts it from the shared cache.
var _shadow_draw_texture: Texture2D
var _seq: Dictionary = {}           # (D-2) 步兵帧序（art.ini [<image>Sequence] 导出）
var _dying := 0.0                   # (D-2) 阵亡动画剩余时间
const InfantryIdle = preload("res://scripts/units/infantry_idle.gd")
var idle_pose: InfantryIdle
var _fire_anim_time := -1.0

# --- 武器 ---
var weapon: Dictionary = {}
var attack_range: float = 0.0
var min_range: float = 0.0
var cooldown: float = 1.0
var can_hit_air: bool = false
var _cd_timer: float = 0.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _burst_target = null
var aim_dir: Vector2 = Vector2.RIGHT
var turret_angle: float = 0.0

# --- 加成 ---
var bonuses: Dictionary = { "attack_bonus": 1.0, "defense_bonus": 1.0 }

# --- 采集 ---
var cargo: float = 0.0
var cargo_gems: float = 0.0
var cargo_cap: float = 0.0
var harvest_rate: float = 0.0
var unload_time: float = 1.0
var chrono_return_elapsed := 0.0
var chrono_return_blocked := false
const EconomyCycle = preload("res://scripts/world/economy_cycle.gd")

var harvest_state: String = "to_node"   # to_node / harvesting / to_base / unloading
var _naval_idle_fps := 0.0
var _squid_swim_fps := 0.0
const AUTO_HARVEST_IDLE_SECONDS := 10.0
var auto_harvest_enabled := true
var auto_harvest_idle := 0.0
var _harvest_fx := HarvesterIntakeFx.new()
var resource_node = null
var home_base = null
var _home_tick: float = 0.0   # 精炼厂重选计时（红警2：自动就近卸矿）

# --- 指令 ---
var move_target: Vector2 = Vector2.ZERO
var has_move_order: bool = false
var attack_move: bool = false
var attack_target = null
var _chase_goal := Vector2.INF
var _chase_retry_interval := 0.35
var _chase_repath_left := 0.0
var _drive_heading := NAN
var _drive_turning := false
var attack_ordered: bool = false   # 玩家右键显式指定的集火目标（区别于自动索敌）
var selected: bool = false
var _think_timer: float = 0.0
var _cargo_command_target = null # Transient order edge, deliberately not saved.
var path_field = null        # 流场引用（由 Battle 指派，矿车/维修等局部寻路用）
var order_queue: Array = []  # 路径点队列（Shift 队列指令）

# --- RA2 ZoneMap + A* 路径（由 Battle 按单位下发；每个单位有独立编队终点）---
var _path_pts: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _path_epoch: int = -1
var _blocked_move_goal := Vector2.INF
const YRBlockage = preload("res://scripts/units/yr_blockage_policy.gd")
var _yr_blockage := YRBlockage.new()
var _nav_stuck_t: float = 0.0
var _nav_stuck_best: float = INF
var _nav_stuck_waypoint: Vector2 = Vector2.INF
var _dodge_t: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO

# --- 维修厂进驻（A4）---
var repair_depot = null             # 目标维修厂（Building，UnitRepair=yes）
var repairing: bool = false         # 是否正处于进驻维修状态
var _repair_dock: Vector2 = Vector2.ZERO  # 停机位世界坐标（下单时确定，避免抖动）

# --- 姿态 / 交互 ---
var hovered: bool = false           # 鼠标悬停（世界内高亮反馈）
var hold_position: bool = false     # 警戒：不追击，只打射程内目标
var patrol_points: Array = []       # 巡逻两点（A=起点 B=折返点）
var patrol_index: int = 1
var patrolling: bool = false
var excluded_from_army_selection := false:
	set(value):
		excluded_from_army_selection = value
		world_status_due = 0
		queue_redraw()
var fire_stance: String = "free"    # defend 自动防卫 / free 自由开火 / return 仅反击 / none 停火
var _return_timer: float = 0.0      # 「仅反击」姿态下的被击计时

# --- 表现层动画状态 ---
var yuriko_model
var _ra3_model: Ra3UnitModel
var hull_angle: float = 0.0         # 车体朝向（移动时对齐速度，炮塔独立转向）
var group_idle_redraw := false
var _anim: float = 0.0              # 全局动画时钟
var _track_phase: float = 0.0       # 履带滚动相位
const WALK_STRIDE := 60.0          # 走路一个步循环覆盖的地面距离（像素，≈ 1 等距地块）
var _walk_phase: float = 0.0        # 步兵走路相位 0..1（按实际位移推进，脚下不打滑）
var _muzzle: float = 0.0            # 炮口火光剩余时间
var _recoil: float = 0.0            # 后坐位移 0..1
var _seed: int = 0                  # 每单位固定的涂装/细节随机种子
var _hp_ghost: float = 1.0          # 掉血残影（延迟下落的血量比例）
var _hp_flash: float = 0.0          # 受击白闪剩余（1→0）

var _col: Color = Color(0.35, 0.65, 1.0)
var _dead: bool = false
var ra2_armor: String = ""          # RA2 真实护甲类别（none/flak/plate/light/medium/heavy/wood/steel/concrete/special_1/2）

# --- 技能（Q 固有、W 装配、被动、E 特殊操作）---
var skills: Array = []               # Ability 对象列表（主动技能，最多 4）
var passive: Dictionary = {}         # 被动技能定义（最多 1）
var skill_power: float = 1.0         # 技能强度倍率（局外「技能强化」）
var _base_atk: float = 1.0           # 含局外 + 被动的攻击倍率（技能 buff 的基准值）
var _base_def: float = 1.0
var _base_speed: float = 100.0
var _hero_heal_interval := 0.0
var _regen_frac: float = 0.0         # 被动回血：每秒恢复最大生命的比例
var _stun_timer: float = 0.0         # 瘫痪剩余时间
var _has_active_skills: bool = false
var _hover_locomotor := false
var _samples_tracks := false

# --- 老兵 / 精英（RA2 VeteranLevel）---
# data.veteran = { veteran:{ABILITY:true}, elite:{...}, elite_weapon:{...} }
# 击杀按「击杀价值 = 目标 cost」累积；达自身 cost × VeteranRatio 升 1 级，再一倍升 2 级（Elite）。
var veteran_level: int = 0           # 0 新兵 / 1 老兵 / 2 精英
var _vet_kills: float = 0.0          # 已累积击杀价值
var _vet_need: float = 0.0           # 升到下一级所需的击杀价值
var _vet_cfg: Dictionary = {}        # 该单位的 veteran 定义（可为空）
var _vet_elite_weapon: Dictionary = {}  # Elite 主武器（可为空）
var _ra2_weapon_override: Dictionary = {}  # 精英武器生效期间的实际武器（覆盖 weapon）
var _base_max_hp: float = 100.0      # 未叠老兵 STRONGER 前的生命上限
var _vet_self_heal: float = 0.0      # SELF_HEAL 每秒回血比例
var _vet_value: float = 0.0          # 自身价值（= cost，用于升级阈值/击杀给分）

# --- 增益 / 减益（buff）栏 ---
# 每种 buff 一种颜色环绕（用户口径）：攻击红 / 防御绿 / 闪避紫 / 命中黄 / 暴击红+蓝 /
# 速度青蓝 / 冷却青 / 回血绿。kind 与技能 effect 的 "<kind>_buff" 一一对应。
const BUFF_KINDS := {
	"electric_slow": {"name":"脉冲减速","short":"减速","col":Color.SKY_BLUE,"unit":"%","debuff":true},
	"leizhu_slow_20": {"name":"三极电庭","short":"电庭","col":Color.SKY_BLUE,"unit":"%","debuff":true},
	"leizhu_slow_25": {"name":"三极电庭","short":"电庭","col":Color.SKY_BLUE,"unit":"%","debuff":true},
	"leizhu_slow_30": {"name":"三极电庭","short":"电庭","col":Color.SKY_BLUE,"unit":"%","debuff":true},
	"leizhu_slow_35": {"name":"三极电庭","short":"电庭","col":Color.SKY_BLUE,"unit":"%","debuff":true},
	"attack":   { "name": "攻击强化", "short": "攻击", "col": Color(1.00, 0.32, 0.26), "col2": Color(0, 0, 0, 0), "unit": "%" },
	"defense":  { "name": "防御强化", "short": "防御", "col": Color(0.36, 0.96, 0.46), "col2": Color(0, 0, 0, 0), "unit": "%" },
	"dodge":    { "name": "闪避提升", "short": "闪避", "col": Color(0.72, 0.42, 1.00), "col2": Color(0, 0, 0, 0), "unit": "%" },
	"accuracy": { "name": "命中提升", "short": "命中", "col": Color(1.00, 0.86, 0.30), "col2": Color(0, 0, 0, 0), "unit": "%" },
	"crit":     { "name": "暴击强化", "short": "暴击", "col": Color(1.00, 0.30, 0.32), "col2": Color(0.36, 0.56, 1.00), "unit": "%" },
	"speed":    { "name": "速度提升", "short": "速度", "col": Color(0.28, 0.84, 1.00), "col2": Color(0, 0, 0, 0), "unit": "%" },
	"cooldown": { "name": "冷却缩减", "short": "冷却", "col": Color(0.24, 1.00, 0.92), "col2": Color(0, 0, 0, 0), "unit": "cd" },
	"regen":    { "name": "生命恢复", "short": "回血", "col": Color(0.44, 1.00, 0.52), "col2": Color(0, 0, 0, 0), "unit": "regen" },
	"tesla_emp": { "name": "电磁瘫痪", "short": "瘫痪", "col": Color(0.58,0.79,1.0), "unit": "s", "debuff": true },
	"stun":     { "name": "瘫痪",     "short": "瘫痪", "col": Color(0.80, 0.55, 1.00), "col2": Color(0, 0, 0, 0), "unit": "stun", "debuff": true },
	"freeze":   { "name": "冻结",     "short": "冻结", "col": Color(0.40, 0.85, 1.00), "col2": Color(0, 0, 0, 0), "unit": "freeze", "debuff": true },
}
var buffs: Array = []                # [{kind,name,left,dur,value,col,col2,debuff}]

func _enter_tree() -> void:
	logistics.register_home()
	if _combat_world==null:
		var world:=_battle_world()
		if world is Battle: _combat_world=world
	if _combat_world is Battle:
		_combat_world.simulation.register(self,radius,false)
		set_notify_local_transform(true)

func _notification(what:int) -> void:
	if (what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED) and is_inside_tree():
		reset_physics_interpolation()
		queue_redraw()
	if what == NOTIFICATION_RESET_PHYSICS_INTERPOLATION:
		motion_pose.capture(self)
	if what==NOTIFICATION_LOCAL_TRANSFORM_CHANGED and _combat_world is Battle and is_inside_tree():
		_combat_world.simulation.relocate(self)
		if is_physics_interpolated_and_enabled(): motion_pose.moved(self)

func _exit_tree() -> void:
	_pose_redraw_pending = false
	_passage_tick = -1
	logistics.unregister_home()
	if _combat_world is Battle:
		set_notify_local_transform(false)
		_combat_world.simulation.remove(self)
		_combat_world = null

func setup(p_data: Dictionary, p_side: String, p_pos: Vector2) -> void:
	buffs.clear()
	data = p_data
	GameData.apply_hollywood_fx(data)
	side = p_side
	fire_stance = "defend" if side == "ally" else "free"
	faction = str(p_data.get("faction", "allied"))
	unit_id = str(p_data.get("id", ""))
	var yard_id := deploy_building_id()
	if not yard_id.is_empty():
		var yard := GameData.get_building(yard_id)
		if "hq" in yard.get("tags", []):
			mobile_yard = yard
			add_to_group("mobile_construction_yards")
	_naval_idle_fps = 0.0
	if unit_id in ["DLPH", "SQD"]:
		var extra: Dictionary = GameData.ra2_source_units.get(unit_id, {}).get("extra", {})
		var ticks := float(extra.get("IdleRate", 8 if unit_id == "DLPH" else 4))
		_naval_idle_fps = BattleClock.RULE_TICKS_PER_SECOND / maxf(1.0, ticks)
		if unit_id == "SQD":_squid_swim_fps = BattleClock.RULE_TICKS_PER_SECOND / maxf(1.0,float(extra.get("WalkRate",2)))
	if unit_id in ["SUB","DLPH"]: special.dive_remaining = NavalContact.dive_delay()
	display_name = str(p_data.get("name", unit_id))
	global_position = p_pos

	base_hp = float(p_data.get("hp", 100))
	armor = str(p_data.get("armor", "unarmored"))
	ra2_armor = str(p_data.get("ra2_armor", ""))
	base_speed = float(p_data.get("speed", 100))
	radius = float(p_data.get("radius", 8))
	sight = float(p_data.get("sight", 300))
	is_air = (p_data.get("tags", []) as Array).has("air")
	is_naval = (p_data.get("tags", []) as Array).has("naval") or str(p_data.get("role", "")) == "naval"
	_has_damage_particles = DamageParticles.configured(self)
	is_amphibious = str(p_data.get("movement_zone", "")).to_lower() == "amphibious"
	if AlliedAbilities.source(self).get("SpeedType", "") == "Amphibious": is_amphibious = true
	is_harvester = str(p_data.get("role", "")) == "economy"
	_hover_locomotor = not is_air and str(p_data.get("move",{}).get("speed_type","")).to_lower()=="hover"
	_samples_tracks = unit_id in VehicleTracks.TRACKED

	if unit_id=="SLAV": cargo_cap=float(data.storage)
	var hv: Dictionary = p_data.get("harvester", {})
	if not hv.is_empty():
		cargo_cap = float(hv.get("cargo_cap", 200))
		harvest_rate = float(hv.get("income_per_sec", 6.0))
		unload_time = EconomyCycle.unload_seconds()
		if not BattleRequest.native_ore_map().is_empty():
			cargo_cap = float(GameData.ra2_economy.storage.get(unit_id, cargo_cap))
			harvest_rate = 1.0
		elif not BattleRequest.extensions_enabled():
			cargo_cap = float(GameData.ra2_economy.get("storage", {}).get(unit_id, cargo_cap))
			harvest_rate = float(GameData.ra2_economy.get("adapter", {}).get("harvest_units_per_second", 0.88))

	var w = p_data.get("weapon", null)
	if typeof(w) == TYPE_DICTIONARY and not (w as Dictionary).is_empty():
		weapon = w
		attack_range = float(weapon.get("range", 200))
		min_range = float(weapon.get("min_range", 0))
		cooldown = max(0.05, float(weapon.get("cooldown", 1.0)))
		can_hit_air = CombatMath.can_hit_air(weapon)

	# 局外加成
	bonuses = { "attack_bonus": 1.0, "defense_bonus": 1.0 }
	bonuses.damage_owner_side=side
	if side == "ally":
		var b := BattleRequest.combat_bonuses()
		bonuses["attack_bonus"] = float(b.get("attack_bonus", 1.0))
		bonuses["defense_bonus"] = float(b.get("defense_bonus", 1.0))
		max_hp = base_hp * float(b.get("hp_bonus", 1.0))
		move_speed = base_speed * float(b.get("speed_bonus", 1.0))
	else:
		var hp_m := float(data.get("_hp_mult", 1.0))
		var atk_m := float(data.get("_attack_mult", 1.0))
		var b := BattleRequest.enemy_logistics(side) if side == "enemy" or BattleRequest.house_teams.has(side) else MatchRules.neutral_bonuses()
		max_hp = base_hp * hp_m * float(b.hp_bonus)
		move_speed = base_speed * float(b.speed_bonus)
		bonuses["attack_bonus"] = atk_m * float(b.attack_bonus)
		bonuses["defense_bonus"] = float(b.defense_bonus)

	# 逐单位改造（局外·该单位专属）+ 技能装配
	_init_skills()
	PoolCards.fleet_setup(self)
	_init_native_skills()
	preload("res://scripts/expedition/rules.gd").spawn_stats(self)
	_base_atk = float(bonuses.get("attack_bonus", 1.0))
	_base_def = float(bonuses.get("defense_bonus", 1.0))
	_base_speed = move_speed
	_base_max_hp = max_hp
	preload("res://scripts/world/brutal_three.gd").grant(self)
	hp = max_hp

	_ra2 = RA2Art.art(unit_id)
	logistics.setup(self)
	flight.setup(self)
	UnitSkillLayout.ensure(self)

	_ra2_shd = RA2Art.art(unit_id + "_shd")
	if not _ra2.is_empty():
		_seq = RA2Art.seq(unit_id)
		if _seq.has("Idle1") or _seq.has("Idle2"):
			idle_pose = InfantryIdle.new(get_instance_id())
		var _tr := str(_ra2.get("turret", ""))
		if _tr != "":
			_ra2_tur = RA2Art.art(_tr)
			if not _ra2_tur.has("img") and _ra2_tur.get("tex") != null:
				var image: Image = _ra2_tur.tex.get_image()
				if image != null:
					if image.is_compressed():
						image.decompress()
					_ra2_tur["img"] = image
	_weapon_art = RA2Art.weapon_descriptor(unit_id)
	_deploy_frame = int(p_data.get("deploy_frame", -1))
	_deploy_atk = float(p_data.get("deploy_attack_mult", 1.5))
	_deploy_def = float(p_data.get("deploy_defense_mult", 1.0))
	# 老兵 / 精英：装配该单位的 veteran 定义（无则不启用等级系统）
	_vet_cfg = p_data.get("veteran", {})
	_vet_elite_weapon = p_data.get("elite_weapon", {})
	ensure_source_veterancy()
	veteran_level = 0
	_vet_kills = 0.0
	_vet_self_heal = 0.0
	if p_data.get("self_healing",false):
		_hero_heal_interval = float(GameData.ra2_general.repair.rate_minutes) * 60.0
	elif unit_id in ["BORIS","TANY"]:
		var row := preload("res://scripts/core/yr_death_rules.gd").type_data(unit_id)
		if GameData._ra2_flag(row.get("selfhealing",false)):
			_hero_heal_interval = float(GameData.ra2_general.repair.rate_minutes) * 60.0
	_vet_value = maxf(1.0, float(p_data.get("cost", 100)))
	if data.has("soviet_ra3"): _vet_value=float(data.soviet_ra3.experience_award[0])
	if Ra3Expansion.handles(self): _vet_value = float(Ra3Expansion.rules.objects[unit_id].experience_award[0])
	var _vr := GameData.ra2_veteran_rules()
	_vet_need = Ra3Expansion.rank_requirement(self) if unit_id=="R3TESLA" else _vet_value * float(_vr.get("ratio", 3.0))
	_col = HouseColor.apply_to(self, side, _faction_hex(faction))
	add_to_group("house_colored")
	_seed = abs(hash(unit_id)) % 997
	hull_angle = 0.0
	if unit_id == "YURIKO":
		yuriko_model = preload("res://scripts/units/yuriko_model.gd").new()
		add_child(yuriko_model)
	_ra3_model = Ra3UnitModel.attach(self)
	if _ra3_model == null:
		_ra3_model = preload("res://scripts/units/ra3_expansion_model.gd").create(self)
	if _ra3_model != null and side=="ally":
		preload("res://scripts/units/unit_cosmetics.gd").install(_ra3_model,MetaProgress.cosmetic_style(unit_id))
	Ra3MirageFx.attach(self)
	_apply_physics()
	_refresh_weapon_derived()
	# 等距深度排序：z_index 由 Battle._update_depth_order() 每帧写入（深度键 = y − x），
	# 见 DepthLayers。此处不再写死层级，以免与建筑互相穿插。
	queue_redraw()

## 装配 W 主动和被动；兵种机制强化独立消费，旧对局保留旧卡牌倍率。
func _init_skills() -> void:
	skills.clear()
	passive = {}
	skill_power = 1.0
	_regen_frac = 0.0
	# AI difficulty training also applies in RA2; it does not unlock extension skills.
	if BattleRequest.is_ai_house(side):
		var training := BattleRequest.enemy_unit_upgrades(side)
		bonuses["attack_bonus"] *= float(training.attack_bonus)
		bonuses["defense_bonus"] *= float(training.defense_bonus)
		skill_power = float(training.skill_bonus)
	if not BattleRequest.extensions_enabled():
		_has_active_skills = false
		return
	var loadout: Dictionary = {}
	if side == "ally":
		var ub := BattleRequest.unit_bonus(unit_id)
		bonuses["attack_bonus"] = float(bonuses.get("attack_bonus", 1.0)) * float(ub.get("attack_bonus", 1.0))
		CombatMath.begin_growth(bonuses, BattleRequest.growth_attack_cap())
		bonuses["defense_bonus"] = float(bonuses.get("defense_bonus", 1.0)) * float(ub.get("defense_bonus", 1.0))
		skill_power = float(ub.get("skill_bonus", 1.0))
		# 只装载已解锁的技能（未抽取到的抽取技能即使装在存档里也不生效）
		loadout = BattleRequest.unit_loadout(unit_id)
	else:
		var ab = data.get("abilities", {})
		if typeof(ab) == TYPE_DICTIONARY:
			loadout = ab
	_load_equipped_skills(loadout)

func _load_equipped_skills(loadout:Dictionary) -> void:
	skills.clear()
	passive={}
	_regen_frac=0.0
	loadout = UnitSkillLayout.normalize(unit_id, loadout, special.has("academy_hero"))
	var act: Array = loadout.get("active", [])
	for sid in act:
		var s := str(sid)
		if s == "":
			continue
		var sd := GameData.get_skill(s)
		if sd.is_empty():
			continue
		var ability := Ability.new()
		var rank:int=BattleRequest.combat_context.get("card_ranks",{}).get(s,0) if side=="ally" else 0
		ability.setup(sd,rank)
		if side == "ally":
			if ability.effect_has("stun"): ability.duration *= BattleRequest.card_scale(s)
			else: ability.value *= BattleRequest.card_scale(s)
		skills.append(ability)
	var pid := str(loadout.get("passive", ""))
	if pid != "":
		var pd := GameData.get_skill(pid)
		if not pd.is_empty():
			passive = pd.duplicate()
			if side == "ally": passive.value = float(pd.get("value", 0.0)) * BattleRequest.card_scale(pid)
	_apply_passive()
	_has_active_skills = not skills.is_empty()

func equip_hero_cards() -> void:
	if side!="ally" or not BattleRequest.extensions_enabled():return
	# Promotion happens after ordinary setup. Remove only its card modifier,
	# retaining global growth, base-unit training and their cached baselines.
	var old_attack:=float(bonuses.attack_bonus)
	var old_defense:=float(bonuses.defense_bonus)
	var old_speed:=move_speed
	_apply_passive(true)
	_load_equipped_skills(BattleRequest.hero_loadout(unit_id))
	_base_atk*=float(bonuses.attack_bonus)/maxf(old_attack,0.0001)
	_base_def*=float(bonuses.defense_bonus)/maxf(old_defense,0.0001)
	_base_speed*=move_speed/maxf(old_speed,0.0001)
	_init_native_skills()
	UnitSkillLayout.ensure(self)

## 单位固有指令始终可用，不依赖扩展模式的抽卡/装配。
var special: Dictionary = {}

func _init_native_skills() -> void:
	if unit_id == "YURIKO":
		var burst := Ability.new()
		burst.setup({"id":"yuriko_burst","name":"灵能爆发","effect":"yuriko_burst","target":"self","radius":187.5,"cooldown":30,"desc":"0.4 秒后对周围造成 500 伤害，地面载具和建筑瘫痪 4 秒。"})
		skills.assign([burst])
		_has_active_skills = true
		return
	AlliedAbilities.install(self)
	ensure_auto_harvest_skill()
	if unit_id != "GGI":
		return
	var native: Array[Ability] = []
	for definition in [
		{"id": "ggi_deploy", "name": "部署导弹", "effect": "native_deploy",
			"desc": "部署后不能移动，使用反装甲/防空导弹，近距离存在盲区；再次点击收起。与 J 和鼠标部署同步。"},
		{"id": "ggi_guard", "name": "固守", "effect": "native_guard",
			"desc": "停止移动并自由开火，只攻击射程内目标，不追击。再次点击解除；不改变部署状态，也不增加攻防数值。"}
	]:
		var ability := Ability.new()
		ability.setup(definition)
		native.append(ability)
	skills = native + skills
	_has_active_skills = true

func is_native_ability(i: int) -> bool:
	var ab := ability_at(i)
	return ab != null and (ab.id.begins_with("allied_") or (unit_id == "GGI" and ab.id in ["ggi_deploy", "ggi_guard"]) or (is_harvester and ab.id == "miner_auto_harvest"))

func is_ordinary_harvester() -> bool:
	return is_harvester and special.get("academy_hero") != "HARV"

func ensure_auto_harvest_skill() -> void:
	if not is_harvester: return
	for ab in skills:
		if ab.id == "miner_auto_harvest": return
	var ability := Ability.new()
	ability.setup({"id": "miner_auto_harvest", "name": "自动采矿", "effect": "native_auto_harvest",
		"desc": "开启后空闲 10 秒自动寻找可达矿点，包括未探索区域；有货先返场。移动、维修、卸货、固守时不接管。关闭仅停止空闲接管，不打断当前采矿；可手动指定矿点，按 S 停止。"})
	skills.push_front(ability)
	_has_active_skills = true

## 被动技能：一次性永久计入基准值
const PoolCards = preload("res://scripts/units/expedition_pool_cards.gd")

func _apply_passive(remove:=false) -> void:
	if passive.is_empty():
		return
	var eff := str(passive.get("effect", ""))
	var v := float(passive.get("value", 0.0)) * Training.card_scale(self)
	var factor:=1.0/(1.0+v) if remove else 1.0+v
	match eff:
		"ps_flank_cover":
			if remove and is_in_group(PoolCards.GROUP): remove_from_group(PoolCards.GROUP)
			elif not remove and not is_in_group(PoolCards.GROUP): add_to_group(PoolCards.GROUP)
		"ps_swimming":
			is_amphibious = not remove
		"passive_armor":
			bonuses["defense_bonus"] = float(bonuses.get("defense_bonus", 1.0)) * factor
		"passive_damage":
			bonuses["attack_bonus"] = float(bonuses.get("attack_bonus", 1.0)) * factor
		"passive_speed":
			move_speed *= factor
		"passive_sight":
			sight *= factor
		"passive_harvest":
			harvest_rate *= factor
		"passive_regen":
			_regen_frac = 0.0 if remove else v

# ---------------------------------------------------------------- 老兵 / 精英（RA2 VeteranLevel）
## The spawned Hornet and scoped fortress pack omitted their rank profiles.
## Fill only these missing definitions from the imported local YR rules; this
## also repairs older snapshots without changing their rank/XP or save format.
func ensure_source_veterancy() -> bool:
	if unit_id not in ["HORNET", "BFRT"]: return false
	var row: Dictionary = GameData.ra2_source_units.get(unit_id, {})
	var extra: Dictionary = row.get("extra", {})
	var changed := false
	if _vet_cfg.is_empty():
		var profile := {}
		for pair in [["veteran", "VeteranAbilities"], ["elite", "EliteAbilities"]]:
			var abilities := {}
			for value in str(extra.get(pair[1], "")).split(",", false):
				abilities[value.strip_edges().to_upper()] = true
			if not abilities.is_empty(): profile[pair[0]] = abilities
		if not profile.is_empty():
			_vet_cfg = profile
			changed = true
	var elite_id := str(row.get("elite_primary", "") if row.get("elite_primary") != null else "")
	if _vet_elite_weapon.is_empty() and not elite_id.is_empty() and not GameData.ra2_weapon(elite_id).is_empty():
		_vet_elite_weapon = AlliedAbilities.weapon(elite_id)
		changed = true
	return changed

func can_gain_veterancy() -> bool:
	if (Ra3Expansion.handles(self) or data.has("soviet_ra3")): return true
	var extra: Dictionary = GameData.ra2_source_units.get(unit_id, {}).get("extra", {})
	return not _vet_cfg.is_empty() and (not extra.has("Trainable") or GameData._ra2_flag(extra.Trainable))

## UI reads the same remaining experience and threshold that promotion consumes.
func veterancy_status() -> Dictionary:
	if (Ra3Expansion.handles(self) or data.has("soviet_ra3")): return Ra3Expansion.rank_status(self)
	if Ra3Mirage.handles(self): return Ra3Mirage.rank_status(self)
	var enabled := can_gain_veterancy()
	var cap := int(GameData.ra2_veteran_rules().get("cap", 2))
	var maxed := enabled and veteran_level >= cap
	var required := maxf(1.0, _vet_need)
	return {"enabled": enabled, "rank": veteran_level, "level": veteran_level + 1,
		"name": ["新兵", "老兵", "精英"][clampi(veteran_level, 0, 2)], "maxed": maxed,
		"current": clampf(_vet_kills, 0.0, required) if not maxed else 0.0,
		"required": required if enabled and not maxed else 0.0,
		"progress": 1.0 if maxed else (clampf(_vet_kills / required, 0.0, 1.0) if enabled else 0.0)}

## Hostile destruction grants target cost once; projectiles relay the victim side.
func credit_kill(value: float, defeated_side: String = "") -> void:
	var original_value:=value
	if side=="ally":value*=1.0+preload("res://scripts/expedition/rules.gd").value("veterans")
	if special.has("expansion_temporary"):return
	if (Ra3Expansion.handles(self) or data.has("soviet_ra3")):
		Ra3Expansion.credit_kill(self,value,defeated_side)
		return
	if Ra3Mirage.handles(self):
		Ra3Mirage.credit_kill(self,value,defeated_side)
		return
	var vr := GameData.ra2_veteran_rules()
	var cap := int(vr.get("cap", 2))
	if _dead or hp <= 0.0 or is_queued_for_deletion() or defeated_side == side or not can_gain_veterancy() or veteran_level >= cap:
		return
	if embarked_in is Unit and embarked_in.special.get("academy_hero")=="FV" and int(embarked_in.special.hero_survival_rank)>=1:
		embarked_in.credit_kill(original_value,defeated_side)
	_vet_kills += maxf(0.0, value)
	while veteran_level < cap and _vet_kills >= _vet_need:
		_vet_kills -= _vet_need
		_grant_veteran(veteran_level + 1, true)
		# 下一级所需价值再累加一次基础阈值（RA2 每级按 VeteranRatio × 自身价值）
		_vet_need = _vet_value * float(vr.get("ratio", 3.0)) * float(veteran_level)

## 授予（或直接设定）等级并重新结算加成；announce=true 时播放 EVA 提示。
func _grant_veteran(level: int, announce: bool) -> void:
	var cap := 3 if Ra3Mirage.handles(self) or (Ra3Expansion.handles(self) or data.has("soviet_ra3")) else int(GameData.ra2_veteran_rules().get("cap", 2))
	level = clampi(level, 0, cap)
	if level == veteran_level:
		return
	veteran_level = level
	_refresh_veteran_bonuses(announce)

## 依据当前等级与 veteran 定义，把倍率写入 bonuses / move_speed / max_hp，并切换精英武器。
func _refresh_veteran_bonuses(announce: bool) -> void:
	if (Ra3Expansion.handles(self) or data.has("soviet_ra3")):
		Ra3Expansion.apply_veterancy(self,announce)
		return
	if Ra3Mirage.handles(self):
		Ra3Mirage.apply_veterancy(self,announce)
		return
	var vr := GameData.ra2_veteran_rules()
	_clear_veteran_bonuses()
	if veteran_level <= 0:
		if not _dead:
			_ra2_weapon_override = {}
			_refresh_weapon_derived()
		return
	var kit: Dictionary = _vet_cfg.get("veteran", {}).duplicate(true)
	if veteran_level >= 2:
		kit.merge(_vet_cfg.get("elite", {}), true)
	if kit.get("FIREPOWER", false):
		bonuses["veteran_attack"] = float(vr.get("combat", 1.1))
	if kit.get("ROF", false):
		bonuses["veteran_rof"] = float(vr.get("rof", 0.6))
	if kit.get("FASTER", false):
		bonuses["veteran_speed"] = float(vr.get("speed", 1.2))
	if kit.get("STRONGER", false):
		# VeteranArmor is a received-damage divisor, not extra Strength/HP.
		bonuses["veteran_defense"] = float(vr.get("armor", 1.5))
	# SELF_HEAL：非战斗时缓慢自愈
	_vet_self_heal = 0.002 if kit.get("SELF_HEAL", false) else 0.0
	# Elite 专属武器替换
	if veteran_level >= 2 and not _vet_elite_weapon.is_empty():
		_ra2_weapon_override = _vet_elite_weapon.duplicate(true)
	else:
		_ra2_weapon_override = {}
	if not _dead:
		_refresh_weapon_derived()
	# Promotion changes combat stats, not body geometry or transport collision state.
	# Reinitializing physics here adds shapes and re-enables hidden passengers.
	queue_redraw()
	if announce:
		# RA2 无 EVA 升级播报；用单位的「special」语音作为升级反馈（先自方，敌我皆可）
		if Ra2Sfx.has_voice(data, "special"):
			Ra2Sfx.play_voice(data, "special", global_position)
		preload("res://scripts/ui/veterancy_indicator.gd").promote(self)

func _clear_veteran_bonuses() -> void:
	bonuses.erase("veteran_attack")
	bonuses.erase("veteran_rof")
	bonuses.erase("veteran_speed")
	bonuses.erase("veteran_defense")
	if not _dead and max_hp != _base_max_hp:
		var frac := hp / maxf(1.0, max_hp)
		max_hp = _base_max_hp
		hp = clampf(_base_max_hp * frac, 1.0, _base_max_hp)

## 精英武器生效时，刷新由武器派生的字段（射程/冷却/对空）。
func _refresh_weapon_derived() -> void:
	var w := _active_weapon()
	attack_range = float(w.get("range", attack_range))
	min_range = float(w.get("min_range", min_range))
	cooldown = max(0.05, float(w.get("cooldown", cooldown)))
	can_hit_air = CombatMath.can_hit_air(w)

## 当前实际使用的武器：精英武器优先，否则基础武器。
func _active_weapon() -> Dictionary:
	return _weapon_for_target(attack_target)

func deployed_weapon() -> Dictionary:
	var base: Dictionary = data.get("deployed_weapon", {})
	var result: Dictionary = data.get("elite_deployed_weapon", base) if veteran_level >= 2 else base
	if unit_id == "SCHP" and Training.siege_extra(self) > 0.0:
		result = result.duplicate()
		result.range = float(result.range) + Training.siege_extra(self) * Ra2Damage.PX_PER_CELL
	return result

func _weapon_for_target(target) -> Dictionary:
	# Vision and HUD queries can run after the victim is freed, before retargeting.
	if not is_instance_valid(target):
		target = null
	if special.has("hero_wreck"):return {}
	if special.has("convoy_projection"):return special.convoy_projection
	var current:=_loadout_weapon_for_target(target)
	if special.has("peregrine") and preload("res://scripts/units/peregrine_command.gd").anti_air(self,target):
		return preload("res://scripts/units/peregrine_command.gd").weapon(self,current)
	if unit_id=="E1" and special.get("academy_hero")=="E1" and not current.is_empty():
		if preload("res://scripts/units/expansion_rules.gd").rank(self,"ap_watch_posts")>=2:
			for ability in skills:
				if ability.id=="ap_watch_posts":
					current=current.duplicate()
					current.ra2_aa=true
					break
	if special.has("academy_hero") and MetaProgress.Academy.legacy_bonuses(self) and not current.is_empty():
		current=current.duplicate()
		current.range=float(current.get("range",0))+P.number("mechanic/hero_common","range_cells")*Ra2Damage.PX_PER_CELL
		if TankHero.rank(self, true) >= 5:
			current.ra2_aa = true
			if is_instance_valid(target) and target is Unit and target.is_air_target():
				current.damage = float(current.damage) * TankHero.AIR_DAMAGE_SCALE
				current.hero_air_shell = true
	if _deployed and float(special.get("hero_range_aura",0))>0 and not current.is_empty():
		current=current.duplicate()
		current.range=float(current.get("range",0))+float(special.hero_range_aura)
	return current

func _effective_native_weapon(target = null) -> Dictionary:
	if embarked_in is Building: return preload("res://scripts/units/civilian_orders.gd").weapon(self)
	if unit_id == "TELE" and target is Building: return data.secondary_weapon
	if unit_id == "DISK" and target is Building and (target.power>0 or target.is_refinery()): return data.secondary_weapon
	if unit_id == "BRUTE" and target is Unit and not target.data.get("tags", []).has("infantry"):
		return data.secondary_weapon
	if CommandoCombat.handles(self): return CommandoCombat.weapon_for(self, target)
	if unit_id == "FV" and not logistics.passengers.is_empty():
		var passenger = logistics.passengers[0]
		if AlliedAbilities.alive(passenger):
			var mode := int(AlliedAbilities.source(passenger).get("IFVMode", 0))
			var key := ("EliteWeapon" if veteran_level >= 2 else "Weapon") + str(mode + 1)
			return AlliedAbilities.weapon(str(AlliedAbilities.source(self).get(key, "HoverMissile")))
	if unit_id in ["CLEG", "PTROOP"]:
		return AlliedAbilities.weapon(str(AlliedAbilities.source(self).get("ElitePrimary" if veteran_level >= 2 else "Primary", "")))
	if unit_id == "MGTK" and veteran_level >= 2:
		return AlliedAbilities.weapon("MirageGunE")
	return {}


# Only these native types have an alternate resolver. Runtime state (rank,
# cargo, target and deployment) is still evaluated inside that resolver.
const NATIVE_WEAPON_RESOLVERS := {"GHOST": true, "TANY": true, "CCOMAND": true,
	"PTROOP": true, "FV": true, "CLEG": true, "MGTK": true, "BRUTE": true, "TELE": true, "DISK": true}

func _loadout_weapon_for_target(target) -> Dictionary:
	if unit_id == "BSUB" and is_instance_valid(target) and not (target is Unit and target.is_naval) and not (target is Building and target.data.get("water_bound",false)):
		return data.shore_weapon
	if unit_id in ["YTNK","STLN","DNOA"] and not embarked_in is Building:
		var gun := HollywoodInfantry.choose(self,target)
		return OpenTopped.weapon(self,gun) if embarked_in is Unit else gun
	if unit_id == "BORIS" and is_instance_valid(target) and target is Building: return data.special_weapon
	if unit_id == "SQD" and is_instance_valid(target) and target is Unit and SovietSpecials.organic(target):
		return data.get("elite_special_weapon", data.special_weapon) if veteran_level >= 2 else data.special_weapon
	if embarked_in is Building or NATIVE_WEAPON_RESOLVERS.has(unit_id):
		var native := _effective_native_weapon(target)
		if not native.is_empty(): return OpenTopped.weapon(self, native) if embarked_in is Unit else native
	if data.has("anti_air_weapon") and is_instance_valid(target) and target is Unit and target.is_air_target():
		var aa:Dictionary=data.elite_anti_air_weapon if veteran_level >= 2 else data.anti_air_weapon
		return OpenTopped.weapon(self, aa) if embarked_in is Unit else aa
	if _deployed and data.has("deployed_weapon"):
		var deployed:=deployed_weapon()
		return OpenTopped.weapon(self, deployed) if embarked_in is Unit else deployed
	var base:=_ra2_weapon_override if not _ra2_weapon_override.is_empty() else weapon
	return OpenTopped.weapon(self, base) if embarked_in is Unit else base

const StudioTalents = preload("res://scripts/rules/hollywood_heroes.gd")
const HollywoodInfantry = preload("res://scripts/units/hollywood_infantry.gd")
const HollywoodFx = preload("res://scripts/units/hollywood_unit_fx.gd")

func _fire_sequence() -> String:
	if special.has("prone_left"): return "FireProne"
	if unit_id == "DESO" and _deployed and special.get("rad_unpack", false): return "Deploy"
	if is_air_target() and _seq.has("FireFly"): return "FireFly"
	if _swimming() and _seq.has("WetAttack"): return "WetAttack"
	return "DeployedFire" if _deployed and _seq.has("DeployedFire") else "FireUp"

func _swimming() -> bool:
	if not is_amphibious or not AlliedAbilities.infantry(self): return false
	var world := _battle_world()
	return world != null and world.in_water_world(global_position)


func cosmetic_outfit() -> Dictionary:
	if special.has("academy_hero"): return {}
	return MetaProgress.cosmetic_style(unit_id)

func refresh_house_color() -> void:
	_col = HouseColor.apply_to(self, side, _faction_hex(faction))
	# Workshop inspection pauses child processing. Refresh both hull and IFF
	# sleeve immediately, including unowned try-on models.
	if unit_id=="R3MIRAGE" and _ra3_model!=null:_ra3_model.sync_pose()
	if unit_id=="SQD" and is_instance_valid(embarked_in): embarked_in.queue_redraw()
	queue_redraw()


func _faction_hex(fid: String) -> String:
	return "#" + _faction_color(fid).to_html(false)


func _faction_color(fid: String) -> Color:
	var f := GameData.get_faction(fid)
	if f.has("color"):
		return Color(str(f["color"]))
	return Color(0.6, 0.6, 0.6)

func _apply_physics() -> void:
	# 俯视 RTS：必须用浮动运动模式，否则 GROUNDED 语义会让单位贴着碰撞体「卡住」而非滑动绕行。
	motion_mode = MOTION_MODE_FLOATING
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	if is_air:
		collision_layer = 8
		collision_mask = 8
	else:
		collision_layer = 1
		collision_mask = 1 | 2 | 4   # 地面单位 / 建筑 / 障碍


var _siege_rotor: Node

func _ready() -> void:
	if unit_id == "SCHP":
		_siege_rotor = load("res://scripts/units/siege_rotor_animation.gd").new(self)
		add_child(_siege_rotor)
	if _combat_world != null: physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	reset_physics_interpolation()
	# A moving sprite would otherwise regenerate its draw list even across the map.
	# Leave unsupported models, missiles and workshop previews on their own draw path.
	if _combat_world != null and (not is_air or unit_id in CULLABLE_NATIVE_AIR) and not _ra2.is_empty() and _ra3_model == null:
		_body_visibility = VisibleOnScreenNotifier2D.new()
		# Include flight height, wobble and the existing generous sprite/effect pad.
		# 0.35 bounds every supported isometric preset; unusual projections fall back.
		_air_cull_lift = maxf(0.0,flight.height+absf(flight.deviation))*flight.HEIGHT_PIXEL+3.0 if is_air else 0.0
		var reach := 360.0+_air_cull_lift/0.35
		_body_visibility.rect = Rect2(-Vector2.ONE*reach,Vector2.ONE*reach*2.0)
		_body_visibility.screen_entered.connect(queue_redraw)
		add_child(_body_visibility)
	if is_harvester:
		add_to_group("ore_harvesters")
	if unit_id == Ra3Mirage.ID: add_to_group(Ra3Mirage.SOURCE_GROUP)
	if unit_id=="YURIKO":
		yuriko_model.hover_fx.attach_distortion(self)
		# The native model is rendered into a screen-resolution texture.
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		MetaProgress.register_model_display(self)
	add_to_group("combatants")
	BattleRequest.sync_unit_target_groups(self)
	add_to_group("air_units" if is_air else "ground_units")
	_think_timer = randf() * TARGET_REFRESH

# ------------------------------------------------------------------ 主循环

var _fire_clock_snapshot: Dictionary = {}

# Physics may advance several times before the next displayed pose.
func _request_pose_redraw() -> void:
	if _pose_redraw_pending: return
	if _combat_world == null or not Engine.is_in_physics_frame() or not _combat_world.is_processing() or not _combat_world.can_process():
		queue_redraw()
		return
	_pose_redraw_pending = true
	_combat_world.pending_pose_redraws.append(self)

func _physics_process(delta: float) -> void:
	if yuriko_model != null: yuriko_model.sync_actor(self,delta)
	if special.has("psi_crush"):preload("res://scripts/units/yuriko.gd").crush_pose(self,delta)
	if special.has("psi_holder") or special.has("psi_flight") or special.has("psi_air_pull") or special.has("psi_burst_push"):
		if preload("res://scripts/units/yuriko.gd").carried_tick(self,delta): return
	if unit_id == "YURIKO": preload("res://scripts/units/yuriko.gd").tick(self,delta)
	var sonar_rate := 1.0
	if special.has("sonar_reload_lock"):
		sonar_rate=PoolCards.clock_rate(self,delta)
		if unit_id in ["CARRIER","DEST"]:set_meta("sonar_hangar_rate",sonar_rate)
	elif has_meta("sonar_hangar_rate"):remove_meta("sonar_hangar_rate")
	if special.has("return_window"):
		special.return_window-=delta
		if special.return_window<=0:special.erase("return_window")
	if special.has("reverse_cd"):
		special.reverse_cd-=delta
		if special.reverse_cd<=0.000001:special.erase("reverse_cd")
	if special.has("plate_cooldown"):
		special.plate_cooldown-=delta
		if special.plate_cooldown<=0:special.erase("plate_cooldown")
	if special.has(FoundationTransit.ANCHOR) and not has_move_order:FoundationTransit.settle(self)
	if special.has("leizhu_control"):preload("res://scripts/units/leizhu_command.gd").control_tick(self,delta)
	if special.has("leizhu_electrode"):
		preload("res://scripts/units/leizhu_cards.gd").electrode_tick(self,delta)
		return
	if special.has("boris_radio_shield"):preload("res://scripts/units/boris_radio.gd").shield_tick(self,delta)
	if special.has("boris_command"):preload("res://scripts/units/boris_command.gd").tick(self,delta)
	if special.has("tanya_flash_left"):preload("res://scripts/units/expansion_rules.gd").timer(special,"tanya_flash_left",delta)
	if special.has("tanya_breach_charge"):
		preload("res://scripts/units/tanya_breach.gd").charge_tick(self,delta)
		return
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(0)
	motion_pose.capture(self)
	if (data.has("soviet_ra3") or unit_id == Ra3Expansion.HARBINGER) and delta > Engine.time_scale / 60.0 + 0.000001:
		_fire_clock_snapshot = preload("res://scripts/units/weapon_step_clock.gd").capture(self)
	elif not _fire_clock_snapshot.is_empty():
		_fire_clock_snapshot = {}
	if preload("res://scripts/units/progression_expansion.gd").tick(self,delta):return
	if special.has(Furnace.STANCE) or special.has(Furnace.GUARD) or passive.get("id")==Furnace.PASSIVE:
		Furnace.tick(self,delta)
	if passive.get("id")=="ps_rally_guard": PoolCards.rally(self,delta)
	if special.has("fleet_talent"):PoolCards.fleet_tick(self,delta)
	if special.has(DomainCards.STATE) or passive.get("id") in DomainCards.PASSIVE:DomainCards.tick(self,delta)
	if side == "ally" or special.has("auto_w_hit_left"):
		preload("res://scripts/units/auto_w.gd").tick(self,delta)
	if special.has("convoy"):Convoy.tick(self,delta)
	if special.has("convoy_projection") and float(special.convoy_projection.damage)<0:Convoy.Cards.repair_projection(self,delta)
	if unit_id == "SHK": preload("res://scripts/units/tesla_reserve.gd").tick(self, delta)
	if not _dead and (special.has("electric_chain") or special.has("crew_coordination")): preload("res://scripts/units/electric_cards.gd").tick(self,delta)
	if not _dead and special.has("academy_hero") and TankHero.tick(self,delta):return
	if special.has("commando_hero_v2"):preload("res://scripts/units/expansion_2_commandos.gd").tick(self,delta)
	if special.has("peregrine"):preload("res://scripts/units/peregrine.gd").tick(self,delta)
	if special.has("leizhu"):preload("res://scripts/units/leizhu.gd").tick(self,delta)
	if special.has("leizhu_court_order"):preload("res://scripts/units/leizhu_court_order.gd").tick(self)
	if special.has(YRTalents.BOOK):
		var book:Dictionary=special[YRTalents.BOOK]
		book.left-=delta
		if book.left<=0 or not AlliedAbilities.alive(book.target) or (AlliedAbilities.alive(attack_target) and not is_same(attack_target,book.target)): special.erase(YRTalents.BOOK)
	if not _dead and special.has("reverse_heal_left"):YRTalents.tick_reverse_heal(self,delta)
	if special.has(YRTalents.REVERSE) and not YRTalents.reverse_allowed(self):YRTalents.end_reverse(self)
	if not _dead and (passive.get("id") in FACTION_TICK_PASSIVES or special.has("decoy_origin") or special.has("echo_bonus_left") or special.has("echo_left") or special.has("buoy_left") or special.has("twin_left") or special.has("slope_left") or special.has("plate_flash")):
		FactionCards.tick(self,delta)
	if tank_finish!=null:tank_finish.tick(self,delta)
	if yr_finish!=null:yr_finish.tick(self,delta)
	if night_skin!=null:night_skin.tick(self,delta)
	if hero_art!=null:hero_art.tick(self,delta)
	if peregrine_fx!=null:peregrine_fx.tick(self,delta)
	if special.get("hero_skin",false) and TankHeroSkin.enabled(self) and (velocity.length_squared()>1 or is_instance_valid(attack_target) or selected):_request_pose_redraw()
	if casemate_thruster!=null:
		casemate_thruster.tick(self,delta)
		if casemate_thruster.advance_lights(selected or casemate_thruster.engaging,delta):_request_pose_redraw()
	if unit_id == "BORIS" and (special.has("airstrike_wing") or float(special.get("airstrike_cd",0.0)) > 0.0):
		SovietSpecials.advance_sortie_reload(self,delta)
	if special.has("reaper_focus") or special.has("split_focus") or special.has("reaper_heat"): ReaperSplit.advance_focus(self,delta)
	# A cached moving pose needs one more draw even if this tick stops or exits early.
	if _drew_moving_pose:
		_drew_moving_pose = false
		if not _pose_redraw_pending and not preload("res://scripts/units/grizzly_visual_refresh.gd").eligible(self):_request_pose_redraw()
	if not _dead and (special.has("ivan_bomb") or special.has("iron_left") or special.has("airstrike_left")):
		SovietSpecials.tick_actor(self, delta)
	if special.has("rolling_crush") and (_dead or embarked_in!=null or _stun_timer>0 or repairing or AlliedAbilities.frozen(self) or special.get("gm_stationary",false)):
		special.erase("rolling_crush")
	if idle_pose != null: idle_pose.tick(self, delta)
	if not _dead and unit_id in MISSILE_CARRIERS and special.has("missile_racks"):
		SovietWeapons.tick_racks(self, delta * sonar_rate)
	if is_naval and not _dead and NavalContact.underwater_type(self):
		NavalContact.tick(self, delta)
		var world := _battle_world()
		if world != null: visible = world.actor_visible_to("ally", self)
	if not _dead and special.has("parasite") and AlliedAbilities.alive(special.parasite):
		SovietWeapons.burrow_tick(self, delta)
	if _hero_heal_interval > 0.0 and not _dead: _tick_hero_self_heal(delta)
	# GM targets suppress orders/combat, never flight or the death cleanup clock.
	if special.get("gm_stationary",false) and not _dead:
		_rock_update(delta)
		_tick_gm_target(delta)
		return
	if not _dead and special.has("para_target"):
		preload("res://scripts/world/american_paradrop.gd").fly(self,delta)
		return
	if not _dead and special.has("para_height"):
		preload("res://scripts/world/american_paradrop.gd").descend(self,delta)
		return
	if not _dead and special.has("spy_exit"):
		SovietSpecials.fly_scout(self,delta)
		return
	if not _dead and special.has("strike_run"):
		SovietSpecials.fly_mig(self, delta)
		return
	if not _dead and unit_id in ["V3ROCKET", "DMISL", "CMISL"]:
		SovietWeapons.fly(self, delta)
		return
	if not _dead and data.has("self_repair") and hp < max_hp and not AlliedAbilities.frozen(self):
		var timer := float(special.get("self_repair_timer", 0.0)) + delta
		var interval := float(data.self_repair.interval)
		if timer >= interval: heal(float(data.self_repair.step) * floorf(timer / interval))
		special.self_repair_timer = fmod(timer, interval)
	if _samples_tracks: VehicleTracks.sample(self, delta)
	if has_meta(preload("res://scripts/ui/veterancy_indicator.gd").PROMOTION):
		preload("res://scripts/ui/veterancy_indicator.gd").tick(self, delta)
	if has_meta(preload("res://scripts/ui/healing_indicator.gd").PULSE):
		preload("res://scripts/ui/healing_indicator.gd").tick(self, delta)
	if _harvest_fx.remaining>0: _harvest_fx.tick(self, delta)
	_rock_update(delta)
	if _dead:
		if _dying > 0.0:
			_dying = maxf(0.0, _dying - delta)
			_anim += delta
			if unit_id=="DNOA": HollywoodInfantry.sequence_sound(self,special.get("death_sequence","Die1"),int(_anim*13))
			if flight.crash_lift >= 0.0: flight.update_air_death()
			_request_pose_redraw()
			if _dying <= 0.0:
				queue_free()
		return
	if embarked_in != null:
		auto_harvest_idle = 0.0
		if embarked_in is Building:
			preload("res://scripts/units/civilian_orders.gd").tick(self, delta)
			return
		if (unit_id == "DRON" and embarked_in.special.get("parasite") == self) or (unit_id == "SQD" and embarked_in.special.get("squid") == self): return
		if embarked_in is Unit and embarked_in.unit_id in ["LCRF", "SAPC"]:
			global_position = embarked_in.global_position
		OpenTopped.tick(self, delta)
		return
	AlliedAbilities.tick_actor(self, delta)
	if special.has("chaos_seconds") or special.has("magnet_seconds") or special.has("mind_links"):
		preload("res://scripts/units/head_games_weapons.gd").tick(self,delta)
	if data.has("soviet_ra3"):
		preload("res://scripts/units/ra3_soviet.gd").tick(self,delta)
		if is_queued_for_deletion() or special.has("walker_jump"):return
	if _dead: return
	if special.has("leizhu") and preload("res://scripts/units/leizhu_safety.gd").stopped(self):
		velocity=Vector2.ZERO;_request_pose_redraw();return
	if AlliedAbilities.frozen(self):
		AlliedAbilities.release_temporal(self)
		if special.has("leizhu") and preload("res://scripts/units/leizhu_insulation.gd").move(self,delta):return
		velocity = Vector2.ZERO
		_request_pose_redraw()
		return
	if special.has("studio"):StudioTalents.tick(self,delta)
	if special.has("controller") and int((_anim+delta)*5)!=int(_anim*5): _request_pose_redraw()
	if (special.has("prone_left") or special.has("psi_reload") or special.has("psi_elapsed") or special.has("cheer_elapsed")) and HollywoodInfantry.tick(self,delta): return
	if unit_id=="SLAV" and _fire_anim_time>=0: HollywoodInfantry.sequence_sound(self,"FireUp",int(_fire_anim_time*16))
	if unit_id=="DNOA":
		var clip:String = "Walk" if _moving() else (idle_pose.clip if idle_pose!=null else "")
		var phase:int = int(_walk_phase*int(_seq.Walk.per)) if clip=="Walk" else (int(idle_pose.elapsed*idle_pose.FPS) if idle_pose!=null else 0)
		HollywoodInfantry.sequence_sound(self,clip,phase)
	if unit_id=="SLAV" and special.get("shoveling",false): _request_pose_redraw()
	if special.has("ra3_impulse"): preload("res://scripts/units/ra3_meta_impact.gd").tick(self, delta)
	if special.has("mcv_repack_left") or special.has("mcv_resume_path"):
		if preload("res://scripts/world/construction_transition.gd").tick(self, delta): return
	if special.has("mcv_deploy_at") and preload("res://scripts/world/construction_transition.gd").arrive(self): return
	if special.has("temporal_target") and AlliedAbilities.channel(self, delta):
		# The channel returns before the ordinary reload tick. Passengers already
		# tick in OpenTopped before reaching their separate channel entry.
		if unit_id == "CLEG": _cd_timer = maxf(0.0, _cd_timer - delta)
		return
	if special.has("pounce") and preload("res://scripts/units/dog_pounce.gd").tick(self, delta): return
	var powered_off := data.has("powered_by") and powered_unit.tick(self, delta)
	if _hover_locomotor: hover_motion.tick(self, delta, powered_off)
	if powered_off:
		return
	_drive_heading = NAN
	_hull_prev = hull_angle
	_turret_prev = turret_angle
	crushable = data.get("deployed_crushable", _mv("crushable", false)) == true if _deployed else _mv("crushable", false) == true
	if unit_id == "SQD" and _seq.has("Walk"):
		# Keep a continuous tentacle cycle when switching between IdleRate and WalkRate.
		var frames:=int(_seq.Walk.per)
		var prior:=int(_walk_phase*frames)
		var rate:=_squid_swim_fps if _moving() else _naval_idle_fps
		_walk_phase=fposmod(_walk_phase+delta*rate/frames,1.0)
		if prior!=int(_walk_phase*frames):_request_pose_redraw()
	elif _naval_idle_fps > 0.0 and int((_anim + delta) * _naval_idle_fps) != int(_anim * _naval_idle_fps):
		_request_pose_redraw()
	if casemate_thruster!=null and casemate_thruster.thrust>0.0:_request_pose_redraw()
	_anim += delta
	# Spread decorative redraws across three physics ticks for a stationary large selection.
	var refresh_idle_art := not group_idle_redraw or (Engine.get_physics_frames() + get_instance_id()) % 3 == 0
	if _has_damage_particles and refresh_idle_art and DamageParticles.stage(self) > 0: _request_pose_redraw()
	if _stun_timer > 0.0:
		auto_harvest_idle = 0.0
		_stun_timer = maxf(0.0, _stun_timer - delta)
		velocity = velocity.move_toward(Vector2.ZERO, maxf(60.0, move_speed) * 8.0 * delta)
		_tick_buffs(delta)
		decorate_tick(delta)
		_move_water_safe()
		_request_pose_redraw()
		return
	if special.has("peregrine") and preload("res://scripts/units/peregrine_service.gd").busy(self):
		_tick_skills(delta);_cd_timer=maxf(0,_cd_timer-delta);_tick_buffs(delta)
		velocity=Vector2.ZERO;_request_pose_redraw();return
	_local_traffic.tick_congestion(self, delta)
	if _regen_frac > 0.0 and hp < max_hp:
		heal(_regen_frac * max_hp * delta)
	# 老兵 SELF_HEAL（RA2 精英自愈）：非交战时缓慢回血
	if _hero_heal_interval <= 0.0 and _vet_self_heal > 0.0 and hp < max_hp and attack_target == null:
		heal(_vet_self_heal * max_hp * delta)
	_tick_skills(delta)
	var fire_clock_before := _cd_timer
	var fire_target_before = attack_target
	var fire_clock_rate := P.number("hero/tank/survival","frozen_fire") if special.has("academy_hero") and TankHero.cold(self) else 1.0
	fire_clock_rate *= sonar_rate
	if special.get("academy_hero")=="HARV":fire_clock_rate*=Convoy.Cards.rate(self)
	if unit_id != Ra3Expansion.HARBINGER and not special.has("missile_racks"): _cd_timer -= delta * fire_clock_rate
	if special.has("squid"):
		SovietSpecials.squeeze(self, delta)
		return
	if unit_id == "DESO" and _deployed:
		SovietSpecials.Growth.tick(self,delta)
		decorate_tick(delta)
		if _cd_timer <= 0.0:
			special.rad_unpack = not special.has("rad_deployed_fired")
			_fire_anim_time = 0.0
			_cd_timer = SovietSpecials.drop_radiation(self)
			_request_pose_redraw()
		return
	if unit_id in MISSILE_CARRIERS and not special.has("missile_racks"): SovietWeapons.sync_rack(self)
	_think_timer -= delta
	decorate_tick(delta)
	if special.has("convoy") and special.convoy.has("press"):
		velocity=Vector2.ZERO
		_request_pose_redraw()
		return
	if special.has("peregrine_hunt_order"):
		logistics.tick(delta)
		preload("res://scripts/units/peregrine_hunt_order.gd").tick(self,delta)
		_request_pose_redraw()
		return
	if _think_timer <= 0.0 or ((attack_ordered or (side != "ally" and attack_target != null and _think_timer > TARGET_REFRESH)) and not AlliedAbilities.alive(attack_target)):
		_refresh_target()
		_think_timer = _target_refresh_interval()
	if unit_id=="YTNK": HollywoodInfantry.gatling(self,delta)
	if unit_id == "BORIS" or CommandoCombat.handles(self) or data.has("anti_air_weapon") or special.has("peregrine"): _refresh_weapon_derived()

	if special.has("ra3_riot_point"):
		velocity = Vector2.ZERO
		_limit_turn(delta)
		_request_pose_redraw()
		return
	if logistics.tick(delta):
		_limit_turn(delta)
		_request_pose_redraw()
		return
	if special.has("action") and AlliedAbilities.tick_action(self, delta):
		_request_pose_redraw()
		return
	if special.has("repair_exit_point") and RepairDock.tick_exit(self, delta):
		return
	if repairing:
		_process_repair(delta)     # (A4) 进驻维修厂优先：开到停机位→停车待修→满血自动驶离
		auto_harvest_idle = 0.0
	elif is_harvester and not (special.get("academy_hero")=="HARV" and (attack_ordered or patrolling or (_weapon_target_valid(attack_target) and not has_move_order and not special.get("convoy_delivery",false)))):
		_process_harvester(delta)
		if not weapon.is_empty() and _weapon_target_valid(attack_target):
			_face(attack_target.global_position)
	else:
		if special.has(ReverseAttack.ID): ReverseAttack.tick(self,delta)
		elif special.has(YRTalents.REVERSE):YRTalents.reverse_tick(self,delta)
		else:_process_combat(delta)

	# Turn on arrival, through the same ROT limiter as driving and aiming.
	if special.has("formation_heading") and not has_move_order:
		var heading: float = special.formation_heading
		if is_instance_valid(attack_target) or global_position.distance_to(move_target) > ARRIVE_EPS + 1.0:
			special.erase("formation_heading")
		else:
			hull_angle = heading
			turret_angle = heading
			aim_dir = Vector2.from_angle(heading)
			_request_pose_redraw()
			if absf(angle_difference(_hull_prev,heading)) < 0.001 and absf(angle_difference(_turret_prev,heading)) < 0.001:
				special.erase("formation_heading")
	# RA2 移动规则：ROT 限速转向（缺省即时） + Crusher 碾压
	_limit_turn(delta)
	if unit_id=="R3REAPER":preload("res://scripts/units/ra3_soviet.gd").align_reaper(self,delta)
	# 发射读取限速后的真实炮塔朝向；新连发本帧不再额外扣一次间隔。
	if _weapon_uses_hull():
		turret_angle = hull_angle
		aim_dir = Vector2.RIGHT.rotated(hull_angle)
	elif _mv("turret", false) == true:
		aim_dir = Vector2.RIGHT.rotated(turret_angle)
	if repairing or (is_harvester and weapon.is_empty()):
		_cancel_burst()
	else:
		_advance_firing(delta, fire_clock_before, fire_target_before, fire_clock_rate)
	_crush_tick(delta)

	# 表现层动画重绘：选中/悬停/行进/开火/血条残影与白闪时逐帧刷新
	var moving := velocity.length() > 4.0
	var hpf: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var turning := hull_angle != _hull_prev or turret_angle != _turret_prev
	if (selected and (refresh_idle_art or turning or is_air)) or hovered or moving or _muzzle > 0.0 or _recoil > 0.02 \
			or _hp_flash > 0.0 or _hp_ghost > hpf + 0.004:
		if not _pose_redraw_pending and preload("res://scripts/units/grizzly_visual_refresh.gd").refresh(self):_request_pose_redraw()

## 动画计时（履带滚动、炮口衰减、后坐复位、反击计时）
func decorate_tick(delta: float) -> void:
	var speed := velocity.length()
	if _fire_anim_time >= 0.0:
		_fire_anim_time += delta
		if _fire_anim_time >= float(_seq.get(_fire_sequence(), {}).get("per", 0)) / 16.0:
			_fire_anim_time = -1.0
		_request_pose_redraw()
	if speed > 4.0:
		_track_phase = fmod(_track_phase + delta * (speed / maxf(20.0, radius * 3.0)), 1.0)
	if unit_id != "SQD":
		if speed > 4.0:
			_walk_phase = fmod(_walk_phase + delta * clampf(speed / WALK_STRIDE, 0.0, 4.0), 1.0)
		else:
			_walk_phase = float(_seed % 977) / 977.0
	if _muzzle > 0.0:
		_muzzle = maxf(0.0, _muzzle - delta)
	_recoil = maxf(0.0, _recoil - delta * 3.6)
	_return_timer = maxf(0.0, _return_timer - delta)
	# 血条表现：白闪快速退散，残影缓慢追赶当前血量
	if _hp_flash > 0.0:
		_hp_flash = maxf(0.0, _hp_flash - delta * 5.0)
	var hpf: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	if _hp_ghost > hpf:
		_hp_ghost = maxf(hpf, _hp_ghost - delta * 1.4)
	else:
		_hp_ghost = hpf

func _process_combat(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(1)
	if special.has(preload("res://scripts/units/ai_engagement.gd").RESUME): preload("res://scripts/units/ai_engagement.gd").resume_route(self)
	if (_return_timer > 0.0 or special.has(preload("res://scripts/units/ai_counterfire.gd").RESUME)) and preload("res://scripts/units/ai_counterfire.gd").update(self):
		_face(attack_target.global_position)
		velocity=Vector2.ZERO
		return
	if is_air and not (unit_id == "SCHP" and _deployed):
		flight.process_combat(delta)
		return
	var target = attack_target
	# Empty ground orders have no pursuit, shot or waypoint to resolve.
	# Still yield to traffic, and retain special naval and crusher contact rules.
	if not is_instance_valid(target) and not has_move_order and not attack_ordered and not patrolling:
		if special.has("campaign_area_guard") and preload("res://scripts/units/ai_engagement.gd").area_guard(self, null, 0.0, delta): return
		if _deployed:
			velocity = Vector2.ZERO
		else:
			_idle_move(delta)
			if not velocity.is_zero_approx() or is_naval or is_harvester or unit_id == "R3APOC":
				_move_water_safe()
		return
	# A stationary GI only needs a new tracking decision when its aim changes.
	# Firing and reacquisition still validate the target independently.
	if _deployed and unit_id in DEPLOYING_INFANTRY:
		has_move_order = false
		velocity = Vector2.ZERO
		if is_instance_valid(target) and (attack_ordered or fire_stance != "none"):
			var bearing := global_position.direction_to(target.global_position)
			var angle := bearing.angle()
			if not bearing.is_equal_approx(aim_dir) or not is_equal_approx(angle, turret_angle) or not is_equal_approx(angle, hull_angle):
				if _automatic_target_allowed(target) and attack_domain_valid(target):
					_face(target.global_position)
		return
	var has_target := is_instance_valid(target) and (attack_ordered or fire_stance != "none") and _automatic_target_allowed(target)
	var reach := 0.0
	if has_target:
		if AlliedAbilities.flag(self, "OpenTopped"):
			# command_range already validates every usable passenger weapon.
			# Do not run cargo_can_attack over the same passengers first.
			reach = OpenTopped.command_range(self, target)
			has_target = reach > 0.0
		else:
			var live_weapon := _weapon_for_target(target)
			has_target = _weapon_domain_valid(target, false, live_weapon)
			if has_target:
				# Ordinary weapons already expose their live range on the unit.
				# Naval contact and dual-weapon selection still resolve per target.
				if unit_id == "DRED" or unit_id == "DEST" or data.has("anti_air_weapon"):
					reach = OpenTopped.command_range(self, target, live_weapon, [], false)
				else:
					reach = attack_range
				if special.has("studio"):reach+=StudioTalents.range_bonus(self,target)
	var dist := CommandoCombat.distance_to(self, target) if has_target else 0.0
	var in_range := has_target and dist <= reach and dist >= min_range
	if has_target and (in_range or attack_ordered or attack_move or fire_stance == "free") and CommandoCombat.begin_c4(self, target):
		AlliedAbilities.tick_action(self, delta)
		return
	if has_target and dist > reach and _can_pursue_attacker(target, reach):
		preload("res://scripts/units/ai_engagement.gd").begin_ground_pursuit(self)
		_chase_target(_attack_approach(target), delta, true)
		_face_if_moving()
		_move_water_safe()
		return
	if special.has("campaign_area_guard") and preload("res://scripts/units/ai_engagement.gd").area_guard(self, target if has_target else null, reach, delta):
		return
	if AlliedAbilities.infantry_teleporter(self) and not hold_position and (attack_ordered or attack_move or fire_stance == "free"):
		if has_target and attack_ordered and not in_range:
			var direction: Vector2 = target.global_position.direction_to(global_position)
			var destination: Vector2 = target.global_position + direction * maxf(min_range + 15.0, attack_range * 0.8)
			if target is Building: destination += direction * (target.footprint_clearance(direction) + radius)
			if AlliedAbilities.teleport(self, destination):
				attack_target = target
				attack_ordered = true
			return
		if has_move_order and not in_range:
			AlliedAbilities.teleport(self, move_target)
			return
	# Deployment is stationary even for explicit attacks: no chase, patrol,
	# separation or residual velocity. Firing remains in the normal weapon path.
	if _deployed:
		has_move_order = false
		velocity = Vector2.ZERO
		if has_target:
			_face(target.global_position)
		return

	# 1) 玩家显式集火（右键指定目标）：追击目标，进入射程后停下开火
	if has_target and attack_ordered and not hold_position:
		if in_range:
			has_move_order = false
			_face(target.global_position)
			velocity = Vector2.ZERO
		elif unit_id == "DRED":
			var goal := _chase_goal
			if not goal.is_finite() or not has_move_order or goal.distance_to(target.position) < min_range or goal.distance_to(target.position) > (OpenTopped.command_range(self,target) if special.has("studio") or AlliedAbilities.flag(self, "OpenTopped") else reach):
				goal = SovietWeapons.DreadFlight.firing_position(self,target)
			if goal.is_finite(): _chase_target(goal,delta)
			else: velocity = Vector2.ZERO
			_face_if_moving()
		elif dist < min_range:
			_move_away(target.global_position, delta)
			_face_if_moving()
		else:
			_chase_target(_attack_approach(target), delta)
			_face_if_moving()
		_move_water_safe()
		return

	# 2) 攻击移动：途中遇敌则停下交战（保留目的地，清场后继续前进）
	if has_target and not in_range and not hold_position and (attack_ordered or attack_move or fire_stance == "free") and CommandoCombat.sabotage(self, target) and (not has_move_order or attack_move):
		if has_move_order and attack_move: special.commando_resume = move_target
		_chase_target(target.global_position, delta)
		attack_ordered = true
		_face_if_moving()
		_move_water_safe()
		return
	if has_move_order and attack_move and in_range and not hold_position:
		_face(target.global_position)
		velocity = Vector2.ZERO
		_move_water_safe()
		return

	# 巡逻：抵达当前点后折返（巡逻是长距离往返，同样走流场）
	if patrolling and patrol_points.size() == 2 and not has_move_order:
		patrol_index = 1 - patrol_index
		var np: Vector2 = patrol_points[patrol_index]
		order_move(np, true, _field_for(np))

	# 3) 普通移动：边走边打 —— 自动索敌不再打断/取消移动（修复「攻击中不能移动」）
	if has_move_order:
		var blockage := _ordinary_move_blockage(delta)
		if blockage == YRBlockage.Action.WAIT and not _local_traffic.passing(self):
			velocity = Vector2.ZERO
			return
		if blockage == YRBlockage.Action.CLEAR:
			_tick_path_stuck(delta)
		elif blockage == YRBlockage.Action.DETOUR:
			_recover_stalled_path(_current_move_waypoint(), false)
		var settle := blockage == YRBlockage.Action.FINISH or (blockage == YRBlockage.Action.CLEAR and _local_traffic.can_settle(self))
		var correct_layer := _at_order_layer()
		if correct_layer and (global_position.distance_to(move_target) <= ARRIVE_EPS or settle):
			_yr_blockage.clear()
			if settle:
				move_target = global_position
			has_move_order = false
			attack_ordered = false
			velocity = Vector2.ZERO
			_advance_queue()
		else:
			var full_speed:=move_speed
			if special.get("academy_hero")=="TANY":move_speed*=preload("res://scripts/units/tanya_operations.gd").move_factor(self)
			_move_toward(move_target, delta)
			move_speed=full_speed
			if in_range:
				_face_while_firing(target.global_position)
			else:
				_face_if_moving()
		_move_water_safe()
		return

	# 4) 待机：射程内有目标则站定开火，否则原地警戒
	if has_target:
		_face(target.global_position)
		if in_range:
			velocity = Vector2.ZERO
		else:
			_idle_move(delta)
	else:
		_idle_move(delta)
	_move_water_safe()

func _finish_ground_waypoint() -> void:
	if not order_queue.is_empty() and is_instance_valid(attack_target) and attack_target is ForceFirePoint:
		_finish_target_order()

func _finish_target_order() -> void:
	var planned: bool = special.has("planned_attack") or not order_queue.is_empty()
	var pending := order_queue
	order_queue = []
	order_stop(false)
	order_queue = pending
	if not pending.is_empty():
		if logistics.ammo_max == 0 or logistics.ammo > 0:
			_advance_queue()
		# Empty aircraft resume the pending tail on their next full reload.
	elif planned:
		special.finished_attack_route = true
	if logistics.ammo_max > 0 and logistics.air_state == "flying" and order_queue.is_empty() \
			and not has_move_order and not attack_ordered and GameData._ra2_flag(logistics.source.get("AirportBound", false)):
		logistics.request_return()

func _advance_queue() -> void:
	var skipped_attack := false
	while not order_queue.is_empty():
		var next = order_queue.pop_front()
		if next is Vector2 or (next is Dictionary and next.has("position")):
			var point: Vector2 = next if next is Vector2 else next.position
			if next is Dictionary and next.has("deck"):
				special.erase("hollywood_deck_goal")
				special.erase("hollywood_street_goal")
				if next.deck: special.hollywood_deck_goal = point
				elif special.has("hollywood_on_deck"): special.hollywood_street_goal = point
				var route := _path_for(point)
				if route.size()<2: continue
				order_move(point,next.get("attack_move",false),null,route)
				if has_move_order: return
				continue
			order_move(point, next is Dictionary and next.get("attack_move", false), _field_for(point))
			if has_move_order: return
			continue
		if not next is Dictionary: continue
		var target = next.get("target")
		if next.has("interaction"):
			if not AlliedAbilities.alive(target): continue
			if next.interaction == "allied_engineer" and target.side != next.target_side: continue
			if _start_interaction(next.interaction, target): return
			continue
		var forced: bool = next.get("forced", false)
		if not AlliedAbilities.alive(target) or (not forced and target.side == side) or not attack_domain_valid(target):
			skipped_attack = true
			continue
		if forced and not ForceFire.reason(_battle_world(), self, target).is_empty():
			skipped_attack = true
			continue
		start_target_order(target, forced, true)
		return
	if skipped_attack: special.finished_attack_route = true

## Building entry and boarding are terminal destinations. Store the action so a
## lost door, occupied dock or captured building never turns into an attack.
func order_interaction(action: String, target, append: bool) -> bool:
	if not AlliedAbilities.alive(target): return false
	if append and (has_move_order or attack_ordered or not order_queue.is_empty()):
		order_queue.append({"interaction": action, "target": target, "target_side": target.side})
		return true
	return _start_interaction(action, target)

func _start_interaction(action: String, target) -> bool:
	if not AlliedAbilities.alive(target) or embarked_in != null or _stun_timer > 0.0 or AlliedAbilities.frozen(self): return false
	var accepted: bool
	match action:
		"airfield": accepted = logistics.request_return(target)
		"refinery": accepted = order_return_to_refinery(target)
		"depot": accepted = order_repair(target)
		"board": accepted = target.side == side and logistics.request_board(target)
		_: accepted = AlliedAbilities.use(self, action, target)
	if accepted: clear_queue()
	return accepted

func order_target(target, forced: bool, append: bool, offset := Vector2.ZERO) -> void:
	if not append and special.has("psi_elapsed"): HollywoodInfantry.start_folding(self)
	if append and (has_move_order or attack_ordered or not order_queue.is_empty()):
		order_queue.append({"target": target, "forced": forced})
		return
	if not append: clear_queue()
	start_target_order(target, forced, append, offset)

func start_target_order(target, forced: bool, planned: bool, offset := Vector2.ZERO) -> void:
	if special.has("peregrine"):
		if special.has("hero_wreck"):return
		preload("res://scripts/units/peregrine_service.gd").leave(self)
	# Stop and deploy paths clear the active order. Keep the pending tail separate.
	var pending := order_queue
	order_queue = []
	cancel_stance()
	if forced or is_deployed():
		order_stop(false)
		logistics.stop_command(true)
	elif unit_id == "SREF":
		var approach := _attack_approach(target, offset)
		order_move(approach, true, null, _prism_attack_path(target, approach))
		_chase_goal = approach
		_schedule_chase_retry()
	else:
		var approach := _attack_approach(target, offset)
		order_move(approach, true)
		if has_move_order and _path_pts.size() >= 2:
			_chase_goal = approach
			_schedule_chase_retry()
	order_queue = pending
	if special.has(YRTalents.BOOK) and not is_same(special[YRTalents.BOOK].target,target): special.erase(YRTalents.BOOK)
	attack_target = target
	attack_ordered = true
	if special.has("studio"):StudioTalents.mark(self,target)
	attack_move = false
	if forced: special[ForceFire.KEY] = target
	if planned or forced: special.planned_attack = true

func _idle_move(delta: float) -> void:
	if unit_id == "DNOA" and special.has("rexy_guard_origin"):
		var post:Vector2 = special.rexy_guard_origin
		var destination := post
		if AlliedAbilities.alive(attack_target) and not BattleRequest.friendly(side,attack_target.side) and _automatic_target_allowed(attack_target) and _weapon_domain_valid(attack_target):
			destination = _attack_approach(attack_target)
		if global_position.distance_to(destination) > ARRIVE_EPS:
			_chase_target(destination, delta, true)
			_face_if_moving()
			return
	if (not hold_position or _local_traffic.mobile_ai_guard(self)) and not _deployed and _local_traffic.tick_idle(self, delta):
		return
	# No movement order means no ambient separation velocity. Moving units
	# still steer around peers; stopped units do not drift after arrival/S.
	velocity = Vector2.ZERO
	_drive_turning = false

func _attack_approach(target, offset := Vector2.ZERO) -> Vector2:
	if is_air or is_naval or target is ForceFirePoint or AlliedAbilities.infantry_teleporter(self):
		return target.global_position + offset
	var point := CommandoCombat.contact_point(self, target)
	# Aim for this side of the target. Stop at range during the chase.
	var stand_off := minf(attack_range * 0.65, PathService.CELL * 1.5)
	return point.move_toward(global_position, stand_off)

func _prism_attack_path(target, fallback: Vector2) -> PackedVector2Array:
	# The far side of a crowded bridge can be unreachable even when there is
	# a clear firing position on this side. Keep the normal route for detours.
	var contact := CommandoCombat.contact_point(self, target)
	var firing_point := contact.move_toward(global_position, maxf(0.0, attack_range - ARRIVE_EPS * 2.0))
	var path := _path_for(firing_point)
	if path.size() >= 2:
		var end := path[path.size() - 1]
		var edge: Vector2 = target.closest_footprint_point(end) if target is Building else target.global_position
		if end.distance_to(edge) <= attack_range - ARRIVE_EPS:
			return path
	return _path_for(fallback)

func _schedule_chase_retry(replanned := false) -> void:
	var world := _battle_world()
	_chase_retry_interval = 0.35
	if world is Battle and world.frame_pacing != null:
		var pacing = world.frame_pacing
		if replanned: pacing.chase_replans += 1
		var tier: int = 0 if side == "ally" else pacing.tier
		_chase_retry_interval = pacing.CHASE_SECONDS[tier]
		# Spread simultaneous squad retries across ticks without using combat RNG.
		if tier > 0:
			_chase_retry_interval += float(get_instance_id() % 17) * 0.006
	_chase_repath_left = _chase_retry_interval

func _chase_target(target_pos: Vector2, delta: float, retaliation := false) -> void:
	_chase_repath_left -= delta
	var prism_order := unit_id == "SREF" and attack_ordered and not (attack_target is ForceFirePoint)
	var needs_route := not _chase_goal.is_finite() or (not retaliation and not has_move_order)
	if not needs_route and _chase_repath_left <= 0.0:
		var distance_moved := _chase_goal.distance_squared_to(target_pos)
		var changed_cell := Vector2i((_chase_goal / PathService.CELL).floor()) != Vector2i((target_pos / PathService.CELL).floor())
		var reached_endpoint := global_position.distance_squared_to(move_target) <= ARRIVE_EPS * ARRIVE_EPS
		needs_route = (changed_cell and distance_moved > PathService.CELL * PathService.CELL) or (reached_endpoint and distance_moved > 1.0)
	if needs_route:
		if ai_path_allowed():
			has_move_order = not retaliation
			move_target = target_pos
			set_agent_path(_prism_attack_path(attack_target, target_pos) if prism_order else _path_for(target_pos))
			_chase_goal = target_pos
			_schedule_chase_retry(true)
		elif _path_pts.size() < 2 or not _chase_goal.is_finite():
			velocity = Vector2.ZERO
			return
		# Otherwise continue along the known route while waiting for a planning slot.
	# The last walkable cell can stop just outside contact range at a large foundation.
	if not is_naval and _path_pts.size() >= 2 and _path_i >= _path_pts.size() - 1 and global_position.distance_to(target_pos) <= 2.0 * PathService.CELL:
		if global_position.distance_to(move_target) <= ARRIVE_EPS or global_position.distance_to(target_pos) < move_target.distance_to(target_pos):
			_move_toward(target_pos, delta, false)
			return
	_tick_path_stuck(delta, retaliation, true)
	if _path_pts.size() < 2 or global_position.distance_to(move_target) <= ARRIVE_EPS:
		velocity = Vector2.ZERO
		return
	_move_toward(move_target, delta)

## 朝目标位置靠近。use_field=true 时优先走流场（长途绕障），临近目标再直行
func _move_toward(p: Vector2, delta: float, use_field: bool = true) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(3)
	var dir := _steer_dir(p, use_field)
	if use_field and not special.has("bridge_traffic_route"): dir = _local_traffic.bridge_direction(self,dir)
	velocity = dir * _ramped_speed(delta)
	apply_separation(delta)
	_avoid_obstacles(delta)
	_align_drive_velocity(delta)

## move 字段读取（带缓存）：data["move"][key]，缺则返回 def
func _mv(key: String, def):
	if _mv_cache.has(key):
		return _mv_cache[key]
	var v = def
	if data is Dictionary:
		var m = data.get("move", null)
		if m is Dictionary and m.has(key):
			v = m[key]
		elif key=="rot" and unit_id in ["LTNK","YTNK"] and m is Dictionary:
			v=float(m.rot_units)*360.0/256.0*BattleClock.RULE_TICKS_PER_SECOND
	_mv_cache[key] = v
	return v

## RA2 Accelerates=：仅 =yes 才做起停斜坡（AccelerationFactor= 秒内到最高速）。
## 缺省 no（盟军白名单内无单位开启），此时恒等于 move_speed，与迁移前完全一致。
func _ramped_speed(delta: float) -> float:
	var top:=move_speed*Ra3Expansion.damaged_speed_factor(self) if Ra3Expansion.handles(self) else move_speed
	if data.has("soviet_ra3") and hp/max_hp<=0.5:top*=float(data.soviet_ra3.max_speed_damaged)
	if Ra3Mirage.handles(self): top *= Ra3Mirage.damaged_speed_factor(self)
	if special.has("prone_left"): top*=0.5
	var t := float(_mv("accel_time", 0.0))
	if t <= 0.0:
		_spd_cur = top
		return top
	_spd_cur = move_toward(_spd_cur, top, top / t * delta)
	return _spd_cur

## Independent continuous-world driving adapter. Ground vehicles turn before
## translation on sharp changes, then steer along the hull at the imported ROT.
## Naval hulls share this constraint; turning only their sprite made them strafe.
## Harvesters retain their dedicated approach/reverse docking controller.
func _align_drive_velocity(delta: float) -> void:
	if special.has(ReverseAttack.ID):
		ReverseAttack.steer(self,delta)
		return
	if is_air or is_harvester or (not is_naval and str(data.get("role", "")) != "vehicle"):
		return
	var rate := deg_to_rad(float(_mv("rot", 0.0)))
	if rate <= 0.0 or velocity.length_squared() < 0.01:
		_drive_turning = false
		return
	var wanted := velocity.angle()
	_drive_heading = rotate_toward(_hull_prev, wanted, rate * delta)
	hull_angle = _drive_heading
	if not is_instance_valid(attack_target):
		turret_angle = wanted
	var error := absf(angle_difference(_drive_heading, wanted))
	# Clear ground can support a rolling bend; tight formations and arrivals
	# retain the tested 35-degree envelope. Never widen crowded turns globally.
	var pivot_angle := VehicleSteering.pivot_angle(self, wanted, error)
	_drive_turning = error >= deg_to_rad(pivot_angle)
	if _drive_turning:
		velocity = Vector2.ZERO
		return
	var turn_speed := smoothstep(cos(deg_to_rad(pivot_angle)), cos(deg_to_rad(20.0)), cos(error))
	velocity = Vector2.from_angle(_drive_heading) * minf(velocity.length(), move_speed) * turn_speed

## RA2 ROT：车体/炮塔各有转向速率上限（1/256 圈 / 1/15s）；ROT 缺省 = 瞬时转向。
## 在每帧末尾对“本帧被写死的朝向”做一次限速，不侵入各处的朝向赋值。
func _limit_turn(delta: float) -> void:
	if is_air:
		# The grounded SCHD turret uses vehicle ROT; the airborne nose uses flight steering.
		if unit_id == "SCHP" and _deployed:
			turret_angle = rotate_toward(_turret_prev,turret_angle,deg_to_rad(float(_mv("rot",0.0))) * delta)
		return
	# With both desired angles unchanged, ROT cannot change either result.
	if hull_angle == _hull_prev and turret_angle == _turret_prev and (not is_finite(_drive_heading) or _drive_heading == _hull_prev):
		preload("res://scripts/world/battle_call_counters.gd").iterations(70,1)
		return
	var rr := float(_mv("rot", 0.0))
	if rr <= 0.0:
		return
	var mx := deg_to_rad(rr) * delta
	var desired_hull := _drive_heading if is_finite(_drive_heading) else hull_angle
	hull_angle = _hull_prev + clampf(angle_difference(_hull_prev, desired_hull), -mx, mx)
	turret_angle = _turret_prev + clampf(angle_difference(_turret_prev, turret_angle), -mx, mx)

## RA2 碾压：Crusher=yes 的单位开过去直接碾死可被碾压的敌方步兵（含矿车 AutoCrush）。
func _crush_tick(delta: float) -> void:
	_crush_cd = maxf(0.0, _crush_cd - delta)
	if _crush_cd > 0.0 or velocity.length() < 18.0:
		return
	if unit_id=="R3APOC" or not (_mv("crusher", false) == true):
		return
	_crush_cd = 0.15
	# 注意："allies"/"enemies" 是【自己这一侧】的组名（见 apply_separation）；要碾压的是敌方，
	# 所以 ally 侧要扫 "enemies"。
	var group := BattleRequest.foes_group(side)
	var world:=_battle_world()
	var local_search:bool=world is Battle and world.units.size()>=96
	var contacts:Array=world.neighborhood.nearby(global_position,radius+world.neighborhood.max_unit_radius+4.0) if local_search else get_tree().get_nodes_in_group(group)
	for e in contacts:
		if not is_instance_valid(e) or e == self or (local_search and not e.is_in_group(group)):
			continue
		if e.get("crushable") != true or e.get("is_air") == true:
			continue
		var hpv = e.get("hp")
		if hpv == null or float(hpv) <= 0.0:
			continue
		var reach: float = radius + float(e.get("radius")) + 4.0
		if global_position.distance_to(e.global_position) <= reach and e.has_method("receive_hit"):
			e.receive_hit(99999.0, "crush", {})

## 综合 A* 路径、流场与直行，求出本帧的行进方向
func _at_order_layer() -> bool:
	if special.get("hollywood_deck_goal", Vector2.INF) == move_target:
		return special.has("hollywood_on_deck")
	if special.get("hollywood_street_goal", Vector2.INF) == move_target:
		return not special.has("hollywood_on_deck")
	return true

func _steer_dir(p: Vector2, use_field: bool = true) -> Vector2:
	if use_field and special.has("ai_route_goal"):
		if not ai_path_allowed(): return Vector2.ZERO
		var goal: Vector2 = special.ai_route_goal
		special.erase("ai_route_goal")
		if has_move_order and goal.is_equal_approx(move_target): set_agent_path(_path_for(goal))
	if _deployed or (use_field and _blocked_move_goal == p):
		return Vector2.ZERO
	var off := p - global_position
	var d := off.length()
	if d <= 0.1 and (not has_move_order or _at_order_layer()):
		return Vector2.ZERO
	if use_field and _path_pts.size() >= 2:
		# Wait for a refresh before following a route through changed terrain.
		var current_epoch := _terrain_epoch()
		if _path_epoch != current_epoch:
			var world := _navigation_world()
			if world is Battle and world.remaining_route_unchanged(self, current_epoch):
				_path_epoch = current_epoch
			else:
				if not ai_path_allowed(): return Vector2.ZERO
				if side != "ally" and world != null and world.path_service != null and not world.path_service.take_route_refresh():
					return Vector2.ZERO
				_repath_now()
		if _blocked_move_goal == p: return Vector2.ZERO
		var pdir := _path_dir()
		# Stay at the reachable end of a partial route and keep the order alive.
		if has_move_order and not attack_ordered and not _path_pts.is_empty() and _path_i == _path_pts.size()-1:
			var last := _path_pts[_path_i]
			if not last.is_equal_approx(p) and global_position.distance_to(last) <= ARRIVE_EPS:
				return Vector2.ZERO
		if pdir != Vector2.ZERO:
			if _dodge_t > 0.0:
				return (pdir * 0.45 + _dodge_dir * 0.9).normalized()
			return pdir
	# A harvest goal already has a smoothed A* route. Only build its map-wide
	# fallback if that route cannot supply a direction outside the handoff radius.
	if use_field and d > FLOW_HANDOFF and path_field == null and _flow_goal.is_finite():
		if not ai_path_allowed(): return Vector2.ZERO
		path_field = _field_for(_flow_goal)
	if use_field and path_field != null and d > FLOW_HANDOFF:
		var fdir: Vector2 = path_field.direction_at(global_position)
		if fdir.length() > 0.05:
			return fdir
	return off / d

## 沿着 A* 折线前进：跳过已到达的拐点，只朝当前路点走。
func _path_dir() -> Vector2:
	var n := _path_pts.size()
	if n < 2:
		return Vector2.ZERO
	if _path_i < 1:
		_path_i = 1
	var waypoint_radius:=2.0 if special.has("bridge_traffic_route") else 18.0
	while _path_i < n - 1 and global_position.distance_to(_path_pts[_path_i]) <= waypoint_radius:
		_path_i += 1
	var wp := _path_pts[_path_i]
	var off := wp - global_position
	if off.length() <= 0.5:
		return Vector2.ZERO
	return off.normalized()

## 无进展检测：被友军/建筑卡住时重算路径并向侧面闪避（RA2 的阻塞绕行）。
func _current_move_waypoint() -> Vector2:
	return _path_pts[clampi(_path_i, 1, _path_pts.size()-1)] if _path_pts.size() >= 2 else move_target

func _ordinary_move_blockage(delta: float) -> int:
	# Special locomotors and explicit attack orders retain their own recovery.
	if not has_move_order or is_air or is_naval or is_harvester or is_amphibious or _deployed or repairing or hold_position or patrolling or attack_move or attack_ordered or _drive_turning or unit_id == "R3APOC" or special.has("rolling_crush") or special.has(FoundationTransit.ANCHOR) or special.has("ai_route_goal"):
		_yr_blockage.clear()
		return YRBlockage.Action.CLEAR
	if global_position.distance_squared_to(move_target) <= ARRIVE_EPS * ARRIVE_EPS and _at_order_layer():
		_yr_blockage.clear()
		return YRBlockage.Action.CLEAR
	var traffic: Dictionary = special.get(_local_traffic.CONGESTION, {})
	# Keep the long clock while the existing congestion escape still overlaps a hull.
	var blocked: bool = not traffic.is_empty() and (not traffic.get("passing", false) or float(traffic.get("clear_seconds", 0.0)) <= 0.0)
	if blocked:
		_dodge_t = 0.0
		_nav_stuck_t = 0.0
		_nav_stuck_best = INF
		_nav_stuck_waypoint = Vector2.INF
	var action := _yr_blockage.tick(Engine.get_physics_frames(), delta, move_target, blocked, true, global_position.distance_to(move_target) if blocked else INF)
	if action == YRBlockage.Action.FINISH and (not _at_order_layer() or not _domain_ok(global_position) or not _local_traffic.can_settle(self, YRBlockage.CLOSE_DISTANCE)):
		return YRBlockage.Action.RETRY
	return action

func _tick_path_stuck(delta: float, retaliation := false, chasing := false) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(5)
	if (not has_move_order and not retaliation) or _deployed or special.has("rolling_crush"):
		_nav_stuck_t = 0.0
		_nav_stuck_best = INF
		_nav_stuck_waypoint = Vector2.INF
		return
	if _drive_turning:
		# Turning is progress; keep the avoidance heading until travel can start.
		_nav_stuck_t = 0.0
		return
	_dodge_t = maxf(0.0, _dodge_t - delta)
	# 绕障可能暂时远离终点；按当前路点的进展判断，避免每 0.9 秒打断正常绕行。
	var waypoint := _current_move_waypoint()
	if waypoint != _nav_stuck_waypoint:
		_nav_stuck_waypoint = waypoint
		_nav_stuck_best = INF
		_nav_stuck_t = 0.0
	var d := global_position.distance_to(waypoint)
	if d < _nav_stuck_best - 8.0:
		_nav_stuck_best = d
		_nav_stuck_t = 0.0
		return
	_nav_stuck_t += delta
	var retry_after := 0.55 + _chase_retry_interval if chasing else 0.9
	if _nav_stuck_t < retry_after:
		return
	_recover_stalled_path(waypoint, chasing)

func _recover_stalled_path(waypoint: Vector2, chasing: bool) -> void:
	var admitted := ai_path_allowed()
	var world := _navigation_world()
	if side != "ally" and world is Battle and is_instance_valid(world.frame_pacing) and not world.frame_pacing.allow_stuck_retry(get_instance_id(), admitted):
		return
	if not admitted:
		return
	_nav_stuck_t = 0.0
	_nav_stuck_best = INF
	_yr_blockage.clear()
	if chasing: _schedule_chase_retry(true)
	_blocked_move_goal = Vector2.INF
	if preload("res://scripts/units/base_escape.gd").try_route(self):return
	var on_bridge: bool = world != null and world.path_service != null and world.path_service.near_deck(global_position,radius+40.0)
	# Bridge lanes can be blocked by parked hulls too. A terrain-checked route
	# around them is safe; only the unguided sideways dodge stays disabled below.
	if world != null and not is_air and not waypoint.is_equal_approx(global_position):
		var blockers := _local_traffic.stalled_blockers(self, waypoint)
		if on_bridge:blockers=preload("res://scripts/units/bridge_traffic_route.gd").obstructions(self,blockers)
		if not blockers.is_empty():
			var detour: PackedVector2Array = world.path_for_unit(self, move_target, null, blockers)
			if on_bridge and (detour.size()<3 or not detour[-1].is_equal_approx(move_target)):
				detour=preload("res://scripts/units/bridge_traffic_route.gd").find(self,move_target,blockers)
			if detour.size() > 2 and detour[-1].is_equal_approx(move_target):
				set_agent_path(detour)
				if on_bridge:special["bridge_traffic_route"]=true
				return
			# When the grid cannot resolve a tight crowd, keep collision-checked
			# local yielding active. Stopping here would also freeze adjacent movers.
	_repath_now()
	if on_bridge:
		preload("res://scripts/world/bridge_traffic.gd").record(self,"stuck_repath")
		# A sideways emergency dodge points into water and makes the following
		# tanks pivot repeatedly. Retain the bridge route while local traffic yields.
		_dodge_t = 0.0
		return
	var to_goal := (waypoint - global_position)
	if to_goal.length() > 1.0:
		var perp := Vector2(-to_goal.y, to_goal.x).normalized()
		if _seed % 2 == 1:
			perp = -perp
		_dodge_dir = perp
		_dodge_t = 0.55

func _navigation_world() -> Battle:
	if _combat_world != null: return _combat_world
	# Enemy units live below enemy_root; both houses use the same terrain owner.
	var par := get_parent()
	while par != null:
		if par is Battle:
			return par
		par = par.get_parent()
	return null

func _terrain_epoch() -> int:
	var par := _navigation_world()
	if par != null and par.has_method("path_epoch"):
		return int(par.path_epoch())
	return _path_epoch

func ai_path_allowed() -> bool:
	if not BattleRequest.is_ai_house(side): return true
	var world := _battle_world()
	return not world is Battle or world.ai_dispatch.allow(world,self)

func ai_order(kind: String, point := Vector2.ZERO, attack := false) -> void:
	var world := _battle_world()
	if world is Battle: world.ai_dispatch.submit(world,self,{"kind":kind,"point":point,"attack":attack})

# Keep one exact geometric passage result per unit. Traffic is always live.
func ground_passage(service: PathService, goal: Vector2, stationary: Array) -> PackedVector2Array:
	var clearance := radius + 1.0
	if not stationary.is_empty():
		return service.passages.route(service, global_position, goal, clearance, stationary)
	var tick := Engine.get_physics_frames()
	var service_id := service.get_instance_id()
	var revision := service.passage_revision()
	if _passage_tick == tick and _passage_grid_revision == revision and _passage_epoch == service.epoch and _passage_service_id == service_id and _passage_from == global_position and _passage_goal == goal and _passage_radius == clearance:
		return _passage_points.duplicate()
	var points: PackedVector2Array = service.passages.route(service, global_position, goal, clearance, stationary)
	_passage_tick = tick
	_passage_grid_revision = revision
	_passage_epoch = service.epoch
	_passage_service_id = service_id
	_passage_from = global_position
	_passage_goal = goal
	_passage_radius = clearance
	_passage_points = points.duplicate()
	return points

func _path_for(p: Vector2) -> PackedVector2Array:
	var par := _navigation_world()
	if par != null and par.has_method("path_for_unit"):
		return par.path_for_unit(self, p)
	return PackedVector2Array()

func _repath_now() -> void:
	special.erase("bridge_traffic_route")
	_blocked_move_goal = Vector2.INF
	var keep_destination := has_move_order and not attack_ordered
	var pts: PackedVector2Array
	if unit_id == "SREF" and attack_ordered and AlliedAbilities.alive(attack_target) and not (attack_target is ForceFirePoint):
		pts = _prism_attack_path(attack_target, _attack_approach(attack_target))
	else:
		pts = _path_for(move_target)
	if pts.size() >= 2:
		_path_pts = pts
		_path_i = 1
		_path_epoch = _terrain_epoch()
		if not keep_destination:
			move_target = pts[-1]
	else:
		if keep_destination: _blocked_move_goal = move_target
		_path_pts = PackedVector2Array()
		_path_i = 0
		_path_epoch = _terrain_epoch()

func set_agent_path(pts: PackedVector2Array) -> void:
	_yr_blockage.clear()
	special.erase("bridge_traffic_route")
	_blocked_move_goal = Vector2.INF
	_path_pts = pts
	_path_i = 1 if pts.size() >= 2 else 0
	_path_epoch = _terrain_epoch()
	if pts.size() >= 2:
		move_target = pts[pts.size() - 1]
	_nav_stuck_t = 0.0
	_nav_stuck_best = INF
	_nav_stuck_waypoint = Vector2.INF
	_dodge_t = 0.0

func _move_away(from: Vector2, delta: float) -> void:
	var dir := (global_position - from).normalized()
	velocity = dir * move_speed * 0.9
	apply_separation(delta)

## 单位之间的分离力，避免堆叠
func apply_separation(delta: float) -> void:
	_local_traffic.apply(self, delta)

## 简单的圆形障碍绕行
func _avoid_obstacles(_delta: float) -> void:
	if is_air or is_naval:
		return
	for obs in get_tree().get_nodes_in_group("obstacles"):
		if not is_instance_valid(obs):
			continue
		var off: Vector2 = obs.global_position - global_position
		var dist := off.length()
		var r: float = float(obs.get("radius")) + radius + 34.0
		if dist > 0.01 and dist < r:
			var perp := Vector2(-off.y, off.x).normalized()
			if perp.dot(velocity) < 0.0:
				perp = -perp
			velocity += perp * move_speed * 0.8 * (1.0 - dist / r)

## 约束 #3 门禁：入库倒车段（_dock_phase==1 / unloading / _back_in）必须保持 _dock_out 倒车姿态。
## 前进朝向更新（把 hull_angle 对齐行进方向）只在矿车 to_node / to_base(_dock_phase==0) 生效；
## 其余姿态一律短路跳过，否则会污染倒车姿态与倒车灯（见倒车灯绘制）。供未来矿车漂移修复使用。
func _harvest_heading_free() -> bool:
	if not is_harvester:
		return true
	if _back_in:
		return false
	if harvest_state == "unloading":
		return false
	if harvest_state == "to_base" and _dock_phase == 1:
		return false
	return true

## 移动时朝行进方向，静止时保持瞄准
func _face_if_moving() -> void:
	if not _harvest_heading_free():
		return
	if velocity.length() > 12.0:
		var direction := velocity.normalized()
		var angle := direction.angle()
		var changed := aim_dir != direction or turret_angle != angle or hull_angle != angle
		aim_dir = direction
		turret_angle = angle
		hull_angle = angle
		# Translation updates the CanvasItem transform. An unchanged rigid pose
		# keeps its draw list; animated/status/custom bodies retain live redraws.
		if not _pose_redraw_pending and (changed or not preload("res://scripts/units/grizzly_visual_refresh.gd").rigid_vehicle(self)):
			_request_pose_redraw()

# Commit the final hull and aim together. Overwriting a stable firing angle
# with the travel angle first would invalidate the draw list on every step.
func _face_while_firing(point: Vector2) -> void:
	var offset := point - global_position
	if offset.length() <= 0.01:
		_face_if_moving()
		return
	if not _harvest_heading_free() or velocity.length() <= 12.0:
		_face(point)
		return
	var direction := offset.normalized()
	var angle := direction.angle()
	var hull := angle if (not has_move_order or attack_move) and _weapon_uses_hull() else velocity.normalized().angle()
	var changed := hull_angle != hull or aim_dir != direction or turret_angle != angle
	hull_angle = hull
	aim_dir = direction
	turret_angle = angle
	if changed or not preload("res://scripts/units/grizzly_visual_refresh.gd").rigid_vehicle(self):
		queue_redraw()

func _face(p: Vector2) -> void:
	var d := (p - global_position)
	if d.length() > 0.01:
		var direction := d.normalized()
		var angle := direction.angle()
		var changed := aim_dir != direction or turret_angle != angle
		aim_dir = direction
		turret_angle = angle
		if _weapon_uses_hull() and (not has_move_order or attack_move):
			changed = changed or hull_angle != angle
			hull_angle = turret_angle
		# A stationary aim does not invalidate the draw list. Movement, turn
		# interpolation, muzzle/status effects and selection refresh separately.
		if changed: _request_pose_redraw()

# ------------------------------------------------------------------ 寻敌

# Only autonomous target selection is less frequent in large battles. Keep
# explicit attacks, retaliation, player decisions and all firing clocks intact.
# A dead target during the extra interval triggers the scan above immediately;
# inside the original interval its wait is no longer than the former policy.
func _target_refresh_interval() -> float:
	if side == "ally" or attack_ordered or _return_timer > 0.0: return TARGET_REFRESH
	if not is_instance_valid(attack_target) and (has_move_order or attack_move): return TARGET_REFRESH
	var world := _battle_world()
	if world == null or world.units.size() < 128: return TARGET_REFRESH
	preload("res://scripts/world/battle_call_counters.gd").iterations(87,1)
	return TARGET_REFRESH * 2.0

## Default defense acquires mobile enemies only. Explicit orders and the existing
## free/return/none stances retain their own policies; a firing building can be answered.
func _automatic_target_allowed(target) -> bool:
	if unit_id == "DNOA" and special.has("rexy_guard_origin") and is_instance_valid(target):
		var post:Vector2 = special.rexy_guard_origin
		if post.distance_to(target.global_position) > sight: return false
	if is_instance_valid(target) and target is Unit and target.side == "neutral": return ForceFire.active(self,target)
	if special.has("expansion_temporary"):
		var linked=preload("res://scripts/units/expansion_heroes.gd").owner_target(self)
		if linked!=null:return is_same(target,linked) and not BattleRequest.friendly(side,linked.side)
	if is_instance_valid(target) and target is Building and not preload("res://scripts/units/ai_wall_clearance.gd").allowed(self,target): return false
	if attack_ordered or attack_move or fire_stance != "defend": return true
	if not is_instance_valid(target): return false
	var retaliating: bool = _return_timer > 0.0 and target == special.get("retaliation_target")
	if target is Building: return retaliating
	if not target is Unit: return false
	var raw: Dictionary = GameData.ra2_source_units.get(unit_id, {}).get("extra", {})
	return retaliating or GameData._ra2_flag(raw.get("CanPassiveAquire", true))

## A hit can pull an idle defender two cells past weapon reach. Native GuardRange
## is a scan radius; use a larger explicit value without extending the weapon.
func _can_pursue_attacker(target, reach: float) -> bool:
	if _return_timer <= 0.0 or not is_instance_valid(target) or not is_same(target, special.get("retaliation_target")): return false
	var ai := BattleRequest.is_ai_house(side)
	if attack_ordered or hold_position or _deployed or repairing or is_harvester: return false
	if (patrolling or attack_move or has_move_order) and not ai: return false
	if fire_stance == "none" or embarked_in != null or special.has("finished_attack_route"): return false
	if not order_queue.is_empty():
		if not ai: return false
		for waypoint in order_queue:
			if not waypoint is Vector2 and not (waypoint is Dictionary and waypoint.has("position")): return false
	if special.has("action") or special.has("ai_deploy_mission"): return false
	if logistics.ammo_max > 0 or unit_id in ["V3", "CARRIER"] or AlliedAbilities.infantry_teleporter(self): return false
	var native := preload("res://scripts/core/yr_death_rules.gd").type_data(unit_id)
	var limit := maxf(reach + 2.0 * Ra2Damage.PX_PER_CELL, float(native.get("guardrange", 0.0)) * Ra2Damage.PX_PER_CELL)
	if ai:
		limit = maxf(maxf(limit,sight),float(special.get("retaliation_contact_range",0.0)))
		if not preload("res://scripts/units/ai_engagement.gd").visible_enemy(self,target): return false
	if not special.has("retaliation_origin"): special.retaliation_origin = global_position
	var origin: Vector2 = special.retaliation_origin
	var point: Vector2 = target.closest_footprint_point(origin) if target is Building and not is_air and not is_naval else target.global_position
	return origin.distance_to(point) <= limit and origin.distance_to(global_position) <= limit

func _refresh_target() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(2)
	if (_return_timer > 0.0 or special.has(preload("res://scripts/units/ai_counterfire.gd").RESUME)) and preload("res://scripts/units/ai_counterfire.gd").update(self): return
	if preload("res://scripts/units/ai_wall_clearance.gd").update(self): return
	if not str(special.get("action", "")).is_empty(): return
	if special.has("expansion_temporary") and preload("res://scripts/units/expansion_heroes.gd").follow_owner_target(self):return
	if special.has("commando_resume") and (not AlliedAbilities.alive(attack_target) or not _weapon_domain_valid(attack_target)):
		var resume: Vector2 = special.commando_resume
		order_move(resume, true)
	if (logistics.ammo_max > 0 or unit_id in ["CARRIER","V3"]) and not attack_ordered:
		attack_target = null
		return
	if weapon.is_empty() or (fire_stance == "none" and not attack_ordered):
		attack_target = null
		attack_ordered = false
		return
	# 玩家显式指定的目标：只要仍然有效就保持锁定（允许跨距离追击）
	if attack_ordered:
		var ot = attack_target
		if AlliedAbilities.alive(ot) and ((ot.side != side and not (ot is Unit and ot.side == "neutral")) or ForceFire.active(self, ot)) and attack_domain_valid(ot):
			return
		attack_ordered = false
		if not attack_move:
			# Target lost/dead: finish the explicit order instead of following its
			# old destination and silently turning the order into attack-move.
			_finish_target_order()
			return
	var route_complete := special.has("finished_attack_route")
	if route_complete and (_return_timer <= 0.0 or not is_instance_valid(special.get("retaliation_target"))):
		attack_target = null
		return
	if fire_stance == "return" and not attack_ordered and not attack_move and _return_timer <= 0.0:
		attack_target = null
		return
	if _burst_left > 0 and _weapon_target_valid(_burst_target):
		attack_target = _burst_target
		return
	# A real hit is a single known contact, not another global target search.
	if _return_timer>0 and BattleRequest.is_ai_house(side):
		var attacker = special.get("retaliation_target")
		if _can_pursue_attacker(attacker,attack_range) and _automatic_target_allowed(attacker):
			attack_target=attacker
			return
	if side == "ally" and _return_timer > 0.0 and fire_stance in ["defend", "return"]:
		var attacker = special.get("retaliation_target")
		if AlliedAbilities.alive(attacker) and not BattleRequest.friendly(side, attacker.side) and _weapon_target_valid(attacker):
			attack_target = attacker
			return
	# A wounded bystander inside the neutron sphere must not steal an active Flux focus.
	if unit_id==Ra3Expansion.FUTURE and special.has("phase_target") and is_same(attack_target,special.phase_target):
		var can_keep_focus:=fire_stance!="return" or attack_move or is_same(attack_target,special.get("retaliation_target"))
		if can_keep_focus and _weapon_target_valid(attack_target): return
	var best = null
	var best_score := -INF
	var group := BattleRequest.foes_group(side)
	var cover_world := _battle_world()
	if cover_world is Battle and _scan_grant_until < Engine.get_physics_frames() and not cover_world.ai_dispatch.allow_scan(cover_world,self):
		return
	_scan_grant_until = -1
	var check_cover: bool = cover_world is Battle and not cover_world.wall_cells.is_empty()
	# For a fixed-range weapon all candidate units share the same search distance.
	# Preserve per-target ranges for passengers, dedicated AA and naval weapons.
	var cargo_range := not logistics.passengers.is_empty() and AlliedAbilities.flag(self, "OpenTopped")
	var fixed_range := unit_id not in ["BSUB", "DRED", "DEST","YTNK"] and not data.has("anti_air_weapon") and not cargo_range and not special.has("peregrine")
	var outer_range := INF
	if unit_id == "BSUB":
		outer_range = float(data.shore_weapon.range)
	elif unit_id=="YTNK":
		outer_range = maxf(HollywoodInfantry.gun_at_stage(self,false).range,HollywoodInfantry.gun_at_stage(self,true).range)
	elif cargo_range and unit_id=="BFRT":
		outer_range = OpenTopped.search_bound(self)
	elif fixed_range or (unit_id=="DRED" and not cargo_range and not data.has("anti_air_weapon")):
		outer_range = attack_range
	elif data.has("anti_air_weapon") and not cargo_range and unit_id not in ["DRED","DEST","SQD","BORIS"] and not CommandoCombat.handles(self):
		# Ordinary dual-weapon units select by target domain. Use the longer reach
		# only for rejection; candidate scoring still uses the actual weapon.
		var aa: Dictionary = data.elite_anti_air_weapon if veteran_level >= 2 else data.anti_air_weapon
		aa = OpenTopped.weapon(self,aa)
		var bonus := 0.0
		if special.has("academy_hero") and MetaProgress.Academy.legacy_bonuses(self): bonus += P.number("mechanic/hero_common","range_cells")*Ra2Damage.PX_PER_CELL
		if _deployed: bonus += maxf(0.0,float(special.get("hero_range_aura",0)))
		outer_range = maxf(float(_weapon_for_target(null).get("range",attack_range)),float(aa.get("range",0))+bonus)
	var search_limit := attack_range if hold_position or (fire_stance in ["defend","return"] and not attack_move) else maxf(sight,attack_range)
	var outer_limit := maxf(search_limit,outer_range)
	var outer_squared := outer_limit * outer_limit
	var retaliator = special.get("retaliation_target") if _return_timer > 0.0 else null
	var origin := global_position
	# Reuse the result slot, never target validity, across candidates. The range
	# query already visits every live passenger and checks the carrier weapon.
	var cargo_domain := [false] if cargo_range else []
	var cargo_weapons := {"enabled":true} if cargo_range else {}
	var local_search:bool=cover_world is Battle and cover_world.units.size()>=96 and outer_limit<cover_world.map_size and unit_id not in ["DLPH","DRED"]
	var contacts:Array
	if route_complete:
		# Stay at the final waypoint and answer only the actual shooter.
		contacts = [retaliator]
	elif local_search:
		var grid = cover_world.neighborhood
		var unit_padding: float = grid.max_unit_radius if unit_id == "DTRUCK" else 0.0
		if is_instance_valid(retaliator):
			contacts = grid.nearby(origin, outer_limit + maxf(grid.max_footprint, unit_padding))
			if not contacts.has(retaliator): contacts.append(retaliator)
		else:
			contacts = grid.target_contacts(origin, outer_limit + unit_padding, outer_limit + grid.max_footprint)
	else:
		contacts=get_tree().get_nodes_in_group(group)
	if unit_id=="DLPH" and not route_complete:
		for host in get_tree().get_nodes_in_group("allies" if side=="ally" else "enemies"):
			if host is Unit and AlliedAbilities.alive(host.special.get("squid")):contacts.append(host.special.squid)
	preload("res://scripts/world/battle_call_counters.gd").iterations(2,contacts.size())
	# Resolve once only for weapons whose selection is independent of candidates.
	# This cache lives for this synchronous query, never across updates.
	var share_weapon := fixed_range and (embarked_in == null or OpenTopped.query_weapon_reusable(self)) and unit_id not in ["BORIS","SQD","STLN","DNOA"] and not NATIVE_WEAPON_RESOLVERS.has(unit_id) and not special.has("academy_hero")
	var shared_weapon: Dictionary = {}
	var reject_air := false
	for e in contacts:
		if not is_instance_valid(e) or ((local_search or route_complete) and not e.is_in_group(group)): continue
		if is_finite(outer_limit) and not is_same(e,retaliator):
			var distance_sq := origin.distance_squared_to(e.global_position)
			if distance_sq > outer_squared:
				var padding := 0.0
				if e is Building:
					padding = e.footprint_radius()
					# Dreadnought missiles extend their reach against large foundations.
					# Keep this conservative rejection bound and the original group order.
					if unit_id=="DRED":
						var half_size:Vector2=e.foundation_half()/Building.BUILD_GRID
						if minf(half_size.x,half_size.y)>=1.0:padding+=ceilf(minf(half_size.x,half_size.y))*Ra2Damage.PX_PER_CELL
				elif e is Unit and unit_id == "DTRUCK": padding = e.radius
				if distance_sq > (outer_limit + padding) * (outer_limit + padding): continue
		if e.is_queued_for_deletion() or e.get("hp") == null or float(e.hp) <= 0.0: continue
		if e is Unit and e.embarked_in!=null and not (unit_id=="DLPH" and NavalContact.grip_host(e)!=null):
			continue
		if not _automatic_target_allowed(e): continue
		if fire_stance == "return" and not attack_move and e != special.get("retaliation_target"): continue
		# The resolved weapon is target-independent here. Read flight state live.
		if reject_air and e is Unit and e.is_air_target(): continue
		var d := CommandoCombat.distance_to(self, e)
		var candidate_weapon: Dictionary = {} if fixed_range else _weapon_for_target(e)
		var reach := attack_range if fixed_range else OpenTopped.command_range(self, e, candidate_weapon, cargo_domain, null, cargo_weapons)
		var search_range := reach if hold_position or (fire_stance in ["defend", "return"] and not attack_move) else maxf(sight, reach)
		if d < min_range or (d > search_range and not _can_pursue_attacker(e, reach)):
			continue
		if candidate_weapon.is_empty():
			if share_weapon and not shared_weapon.is_empty():
				candidate_weapon = shared_weapon
				preload("res://scripts/world/battle_call_counters.gd").iterations(69,1)
			else:
				candidate_weapon = _weapon_for_target(e)
				if share_weapon:
					shared_weapon = candidate_weapon
					reject_air = _scan_rejects_air(shared_weapon)
		var eligible: bool = cargo_domain[0] if cargo_range else _weapon_domain_valid(e, false, candidate_weapon)
		if not eligible:
			continue
		var building_c4 := CommandoCombat.building_c4(self, e)
		if check_cover and not building_c4 and WallArt.shot_blocked(cover_world, self, e, candidate_weapon): continue
		var score := 4.0 - d / maxf(1.0, sight) if building_c4 else TacticalTargeting.score(self, e, candidate_weapon, attack_target)
		if score > best_score or (local_search and score==best_score and is_instance_valid(best) and best.is_greater_than(e)):
			best_score = score
			best = e
	attack_target = best
	if best == null and data.has("charge_weapon") and not has_move_order and not attack_ordered and not attack_move:
		var coil = preload("res://scripts/units/tesla_support.gd").nearby(self)
		if coil != null: AlliedAbilities.use(self, "tesla_charge", coil)

# ------------------------------------------------------------------ 开火

func _cancel_burst() -> void:
	special.erase("tesla_charge_up")
	special.erase("tesla_clip_target")
	_burst_left = 0
	_burst_target = null

func attack_domain_valid(target) -> bool:
	return _weapon_domain_valid(target) or OpenTopped.cargo_can_attack(self, target)

const EMPTY_WEAPON_QUERY: Dictionary = {}

# A synchronous weapon check reads concealment twice. For an ordinary target,
# prove once that neither reader has a concealment effect to resolve.
func _ordinary_weapon_visibility() -> bool:
	if unit_id == "MGTK" or unit_id == Ra3Mirage.ID: return false
	if special.has("contact_reporters") or special.has("echo_cloaked") or special.has("disguise"): return false
	if special.has(preload("res://scripts/units/expansion_2_infiltration.gd").KEY) or special.has(preload("res://scripts/units/tanya_talents.gd").KEY): return false
	if float(special.get("progression_v1", EMPTY_WEAPON_QUERY).get("dive_cloak", 0)) > 0.0:
		return false
	return not is_inside_tree() or not get_tree().has_group(Ra3Mirage.SOURCE_GROUP)

# Only called after the existing scan has proved it can share the resolved weapon.
func _scan_rejects_air(resolved_weapon: Dictionary) -> bool:
	return not resolved_weapon.is_empty() and _weapon_target_rule == WeaponTargetRule.STANDARD \
		and embarked_in == null and logistics.passengers.is_empty() and not CombatMath.can_hit_air(resolved_weapon)

func _weapon_domain_valid(target, check_cover := false, resolved_weapon: Dictionary = {}) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(47)
	if not is_instance_valid(target): return false
	if target is Building and (target.is_protected_mission_plant() or float(target.special.get("force_shield_left", 0.0)) > 0.0): return false
	if not BattleRequest.house_teams.is_empty() and target.side != side and BattleRequest.friendly(side,target.side) and not ForceFire.active(self,target): return false
	if _weapon_target_rule != WeaponTargetRule.STANDARD:
		match _weapon_target_rule:
			WeaponTargetRule.GRINDER:
				if special.get("soviet_mode", false) and not (target is Building or (target is Unit and target.ground_contact_eligible() and not AlliedAbilities.infantry(target))): return false
			WeaponTargetRule.SQUID:
				if not SovietSpecials.squid_target(target): return false
			WeaponTargetRule.BOMB:
				if not SovietSpecials.accepts_bomb(self, target): return false
			WeaponTargetRule.INFEST:
				if not SovietWeapons.can_infest(target): return false
	if not NavalContact.weapon_allows(self, target): return false
	# Callers that already resolved the live weapon can share it within this
	# decision. Never retain it across ticks, target changes or passenger changes.
	var active := resolved_weapon if not resolved_weapon.is_empty() else _weapon_for_target(target)
	if unit_id in ["STLN","DNOA"] and GameData.ra2_verse(str(active.get("ra2_warhead","")),Ra2Damage.armor_of(target))==0: return false
	var c4 := _weapon_target_rule == WeaponTargetRule.COMMANDO and CommandoCombat.building_c4(self, target)
	if not c4:
		var air: bool
		if target is Unit:
			var victim: Unit = target
			air = victim.is_air_target()
		else:
			air = target.is_air_target() if target.has_method("is_air_target") else target.get("is_air") == true
		if air:
			if not CombatMath.can_hit_air(active): return false
		else:
			if GameData.projectile_blocks_ground(str(active.get("ra2_projectile", ""))): return false
			if GameData.unit_blocks_land_targeting(unit_id) and target.get("is_naval") != true and not (target is Building and target.data.get("water_bound", false)):
				return false
	var ordinary_visibility: bool = not c4 and target is Unit and target._ordinary_weapon_visibility()
	if not c4 and not AlliedAbilities.valid_weapon_target(self, target, active, ordinary_visibility): return false
	var world := _battle_world()
	if world != null and not target is ForceFirePoint and not world.actor_visible_to(side,target,self,ordinary_visibility) and not (unit_id=="DLPH" and NavalContact.visible_grip(world,side,target)):
		return false
	if c4: return not AlliedAbilities.frozen(self) and not AlliedAbilities.frozen(target)
	if check_cover and world is Battle and not world.wall_cells.is_empty() and WallArt.shot_blocked(world, self, target, active): return false
	if _weapon_target_rule == WeaponTargetRule.COMMANDO and CommandoCombat.versus(active, target) <= 0.0: return false
	if target is Unit:
		var victim: Unit = target
		if victim.ignores_warhead(str(active.get("ra2_warhead", ""))): return false
	elif target is Building:
		var structure: Building = target
		if structure.ignores_warhead(str(active.get("ra2_warhead", ""))): return false
	elif target.has_method("ignores_warhead") and target.ignores_warhead(str(active.get("ra2_warhead", ""))):
		return false
	return true

func _weapon_target_valid(target, resolved_weapon: Dictionary = {}) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(48)
	if (special.has("tanya_flash_left") or special.get("academy_hero")=="TANY") and not preload("res://scripts/units/tanya_operations.gd").target_allowed(self,target):return false
	if not preload("res://scripts/units/progression_expansion.gd").target_allowed(self,target):return false
	if special.has("hero_wreck"):return false
	if not power_disabled_reason().is_empty():
		return false
	if weapon.is_empty() or (fire_stance == "none" and not attack_ordered) or repairing or _dead:
		return false
	if fire_stance == "return" and not attack_ordered and not attack_move and _return_timer <= 0.0:
		return false
	if not is_instance_valid(target) or target.is_queued_for_deletion() or float(target.get("hp")) <= 0.0:
		return false
	if target is Unit and target.embarked_in!=null and not (unit_id=="DLPH" and NavalContact.grip_host(target)!=null):
		return false
	var distance := CommandoCombat.distance_to(self, target)
	var target_dependent := unit_id in ["YTNK","BSUB"] or data.has("anti_air_weapon") or data.has("special_weapon") or special.has("peregrine")
	if target_dependent and resolved_weapon.is_empty(): resolved_weapon = _weapon_for_target(target)
	var reach := float(resolved_weapon.get("range",0.0)) if target_dependent else attack_range
	if unit_id == "DRED": reach = OpenTopped.command_range(self,target)
	if special.has("studio"):reach+=StudioTalents.range_bonus(self,target)
	if distance > reach or distance < float(resolved_weapon.get("min_range",min_range)): return false
	if (target.get("side") == side and not ForceFire.active(self, target)) or not _automatic_target_allowed(target) or not _weapon_domain_valid(target, true, resolved_weapon):
		return false
	return not CommandoCombat.building_c4(self, target) # Contact action, never fire the primary at it.

func _weapon_uses_hull() -> bool:
	# This receiver is already a Unit. Keep live deploy/mode/weapon checks.
	if unit_id == Ra3Mirage.ID: return true
	match unit_id:
		"R3APOC":
			if special.get("soviet_mode", false): return true
		"R3HARBINGER", "ZEP": return false
		"SCHP":
			if _deployed: return false
		"DLPH", "SUB": return true
	if is_air: return true
	return data.get("ra2", false) == true and not weapon.is_empty() \
		and not is_naval and not is_harvester and _mv("turret", false) != true

func _weapon_aligned(target) -> bool:
	# Directly above its target a bomber has no meaningful planar firing bearing.
	if unit_id == "HORNET" and logistics.air_lift >= 0.95 and CommandoCombat.distance_to(self, target) <= radius:
		return true
	if unit_id == "DTRUCK": return true # Proximity fuse has no firing arc.
	if unit_id==Ra3Expansion.HARBINGER:return preload("res://scripts/units/ra3_gunship_aim.gd").ready(self,target)
	var uses_hull := _weapon_uses_hull()
	if _mv("turret", false) != true and not uses_hull:
		return true
	var direction: Vector2 = target.global_position - global_position
	var heading := hull_angle if uses_hull else turret_angle
	var tolerance := Ra3Mirage.aim_tolerance(self) if Ra3Mirage.handles(self) else deg_to_rad(2.0)
	if unit_id == "SUB": return NavalContact.torpedo_aligned(self, target)
	if data.has("soviet_ra3"):tolerance=deg_to_rad(1.0 if unit_id=="R3APOC" and special.get("soviet_mode",false) else float(data.soviet_ra3.aim_degrees))
	return not direction.is_zero_approx() and absf(angle_difference(heading, direction.angle())) <= tolerance

func _sprite_facing(art: Dictionary, heading: float) -> int:
	var count := int(art.get("facings", 8))
	if unit_id in ["DLPH","SQD"]:
		var screen_dir := Iso.dir(Vector2.RIGHT.rotated(heading))
		return posmod(roundi((screen_dir.angle() + PI / 2.0) / TAU * 8.0), 8)
	return posmod(RA2Art.facing_index(heading, count) + int(art.get("facing_offset", 0)), count)

func bridge_contact_offset() -> Vector2:
	if not special.has("hollywood_on_deck"): return Vector2.ZERO
	return preload("res://scripts/world/hollywood_overpass.gd").RISE * float(special.get("hollywood_deck_fraction", 1.0))

func _visual_lift() -> float:
	if special.has("psi_air_pull"): return float(special.psi_air_pull.height)
	if special.has("para_height"): return float(special.para_height)
	if unit_id in ["V3ROCKET", "DMISL", "CMISL"]: return logistics.air_lift
	if special.has("hollywood_on_deck"):
		return -Iso.dir(bridge_contact_offset()).y + hover_motion.lift
	return flight.visual_lift() if is_air else hover_motion.lift

func _disc_center() -> Vector2:
	return art_center() if _art_frame >= 0 else Effects.hit_position(self)

func _weapon_muzzle(barrel_index := -1) -> Vector2:
	if _ra3_model != null: return _ra3_model.muzzle()
	if OpenTopped.active(self): return OpenTopped.muzzle(self)
	if embarked_in is Building and embarked_in.data.has("fire_ports"):
		var seat: int = embarked_in.special.get("occupants", []).find(self)
		var ports: Array = embarked_in.data.fire_ports
		if seat >= 0 and seat < ports.size():
			var port: Array = ports[seat]
			# MuzzleFlashN is measured from the original SHP canvas centre, even before its first draw.
			var center := RA2Art.draw_center(embarked_in.global_position, embarked_in._ra2, embarked_in.radius, embarked_in.body_anchor_frames(embarked_in._body_damage_frame()))
			return center + RA2Art.art_dir(Vector2(port[0],port[1]) * Building.RA2_SPRITE_SCALE)
	if unit_id == "SCHP":
		if night_skin!=null:return night_skin.muzzle(self)
		var mount: Array = GameData.unit_index["SCHP"].ground_flh if _deployed else GameData.unit_index["SCHP"].air_flh
		var forward := Vector2.from_angle(turret_angle if _deployed else hull_angle)
		var offset := (forward*float(mount[0])+forward.orthogonal()*float(mount[1])) * (Ra2Damage.PX_PER_CELL/256.0)
		return global_position + offset + RA2Art.art_dir(Vector2.UP*(_visual_lift()+float(mount[2])*flight.HEIGHT_PIXEL))
	if hero_art!=null and embarked_in==null:return hero_art.muzzle(self)
	if data.has("hollywood_fx") and _weapon_art.get("muzzles",[]).is_empty() and embarked_in==null: return HollywoodFx.muzzle(self)
	if unit_id == "DLPH" and not _ra2.is_empty() and _seq.has("FireUp"):
		return _dolphin_muzzle()
	var fallback := global_position + aim_dir * (radius + 4.0) + RA2Art.art_dir(Vector2(0.0, -_visual_lift()))
	var points: Array = _weapon_art.get("muzzles", [])
	var barrels: Array = _weapon_art.get("barrel_muzzles", [])
	if barrel_index >= 0 and barrel_index < barrels.size(): points = barrels[barrel_index]
	if points.is_empty() or _ra2.is_empty():
		return fallback
	var art := _ra2 if _ra2_tur.is_empty() else _ra2_tur
	var heading := hull_angle if _ra2_tur.is_empty() else turret_angle
	var frame := _sprite_facing(art, heading)
	if unit_id in ["LTNK","YTNK"]: frame=HollywoodTurrets.frame(self)
	if frame >= points.size():
		return fallback
	var lift := _visual_lift() + preload("res://scripts/units/dog_pounce.gd").lift(self)
	var base := RA2Art.draw_rect(_ra2, radius, range(int(_ra2.get("facings", 8))), lift, RA2_SPRITE_SCALE).position
	var point: Array = points[frame]
	if embarked_in is Building and embarked_in.building_id=="NATBNK":
		return embarked_in.global_position+RA2Art.art_dir(HollywoodTurrets.bunker_rect(embarked_in,self).position+Vector2(point[0],point[1])*RA2_SPRITE_SCALE)
	var offset := base + Vector2(float(point[0]), float(point[1])) * RA2_SPRITE_SCALE
	# Single-barrel vehicles rock with their sprites too; barrel_index only
	# chooses a weapon socket and must not decide whether body pose applies.
	if _rock_t > 0.0: offset = rocking_pose() * offset
	return global_position + RA2Art.art_dir(offset)

func _dolphin_muzzle() -> Vector2:
	var facing := _sprite_facing(_ra2, hull_angle)
	var guard: Dictionary = _seq.Guard
	var frames: Array = range(int(guard.start), int(guard.start) + 8)
	var rect := RA2Art.draw_rect(_ra2, radius, frames, 0.0, RA2_SPRITE_SCALE)
	# Cache the mouth tip of each firing pose directly from the source silhouette.
	# The sprite atlas and standing anchor are the same ones used by drawing/picking.
	var mouths: Dictionary = _ra2.get("mouths", {})
	if not mouths.has(facing):
		var source := RA2Art.src_rect(_ra2, RA2Art.seq_frame(_seq, "FireUp", facing, 0))
		var img: Image = RA2Art.sprite_image(_ra2)
		var forward := Vector2.RIGHT.rotated(-PI / 2.0 + float(facing) * TAU / 8.0)
		var best := -INF
		var sum := Vector2.ZERO
		var count := 0
		for y in int(source.size.y):
			for x in int(source.size.x):
				if img.get_pixelv(Vector2i(source.position) + Vector2i(x, y)).a < 0.5:
					continue
				var point := Vector2(x + 0.5, y + 0.5)
				var front := point.dot(forward)
				if front > best + 0.01:
					best = front
					sum = point
					count = 1
				elif absf(front - best) < 0.01:
					sum += point
					count += 1
		mouths[facing] = sum / maxf(1.0, float(count))
		_ra2["mouths"] = mouths
	return global_position + RA2Art.art_dir(rect.position + (mouths[facing] as Vector2) * RA2_SPRITE_SCALE)

# Only firing clocks need short steps at 15 Hz, at each selected speed. Never repeat movement,
# target acquisition, avoidance or skill scans, and never bank idle firing time.
func _advance_firing(delta: float, previous_cd: float, previous_target, cooldown_rate: float = 1.0) -> void:
	# Independent mounts and unfinished bursts still advance after losing their target.
	if _burst_left <= 0 and not is_instance_valid(attack_target) and not data.has("soviet_ra3") and unit_id != Ra3Expansion.HARBINGER:
		return
	var mount_clock := not _fire_clock_snapshot.is_empty()
	var event_step := Engine.time_scale / 60.0
	var split: bool = delta > event_step + 0.000001 and previous_target == attack_target and is_instance_valid(attack_target)
	if not split:
		if _burst_left > 0: _update_burst(delta)
		elif _try_fire_ready() and _burst_left == 0: _finish_ground_waypoint()
		return
	var ordinary_clock := not mount_clock and unit_id != Ra3Expansion.HARBINGER and not special.has("missile_racks")
	var rate := cooldown_rate
	if ordinary_clock: _cd_timer = previous_cd
	if mount_clock: preload("res://scripts/units/weapon_step_clock.gd").restore(self, _fire_clock_snapshot)
	var remaining := delta
	var steps := maxi(1, ceili(delta / event_step - 0.000001))
	var step := delta / steps
	var burst_checked := false
	var burst_weapon: Dictionary = {}
	for i in steps:
		remaining -= step
		if ordinary_clock: _cd_timer -= step * rate
		if mount_clock: preload("res://scripts/units/weapon_step_clock.gd").advance(self, step)
		if _burst_left > 0:
			# Between shots these substeps only advance clocks: target, weapon,
			# position and visibility cannot change. Revalidate after every shot,
			# which can kill/control a target or change the shooter's loadout.
			if not burst_checked or mount_clock:
				burst_weapon = _active_weapon()
				if attack_target != _burst_target or not _weapon_target_valid(attack_target, burst_weapon):
					_cancel_burst()
					continue
				burst_checked = true
			if _advance_valid_burst(step, burst_weapon): burst_checked = false
		elif ordinary_clock and _cd_timer > 0.0 and not (unit_id == "BORIS" and attack_target is Building):
			continue
		elif _try_fire_ready():
			burst_checked = false
			if _burst_left == 0: _finish_ground_waypoint()
		elif _cd_timer <= 0.0 and not mount_clock:
			# Aim/target/logistics cannot improve inside these firing-only steps.
			if ordinary_clock: _cd_timer -= remaining * rate
			break

func _update_burst(delta: float) -> void:
	var weapon := _active_weapon()
	if _burst_left <= 0:
		return
	var t = attack_target
	if t != _burst_target or not _weapon_target_valid(t, weapon):
		_cancel_burst()
		return
	_advance_valid_burst(delta, weapon)

func _advance_valid_burst(delta: float, weapon: Dictionary) -> bool:
	_burst_timer = maxf(0.0, _burst_timer - delta * (P.number("hero/tank/survival","frozen_fire") if TankHero.cold(self) else 1.0))
	if _burst_timer > 0.0 or not _weapon_aligned(attack_target):
		return false
	_fire_shot(attack_target)
	_burst_left -= 1
	if _burst_left == 0:
		_burst_target = null
	_burst_timer = float(weapon.get("burst_delay", 0.1))
	if _burst_left == 0: _finish_ground_waypoint()
	return true

func _try_fire_ready() -> bool:
	if unit_id=="SAPC" and special.has("fleet_talent") and int(special.get("fleet_ammo",0))<=0:return false
	if special.has("leizhu") and preload("res://scripts/units/leizhu_safety.gd").stopped(self):return false
	if _dead or hp <= 0.0 or _stun_timer > 0.0: return false
	if special.has("peregrine") and preload("res://scripts/units/peregrine_defense.gd").silent(self):return false
	if special.has("boris_command") and preload("res://scripts/units/boris_command.gd").suppressed(self):return false
	if special.has("commando_hero_v2") and special.commando_hero_v2.has("corridor_call"):return false
	if (special.has("tanya_flash_left") or special.get("academy_hero")=="TANY") and preload("res://scripts/units/tanya_talents.gd").silenced(self):return false
	if data.has("soviet_ra3"):return preload("res://scripts/units/ra3_soviet.gd").fire(self)
	if unit_id == Ra3Expansion.HARBINGER:
		return preload("res://scripts/units/ra3_gunship_mounts.gd").try_fire(self)
	if not is_instance_valid(attack_target) or unit_id == "CARRIER" or (unit_id == "DEST" and NavalContact.underwater_type(attack_target)) or not logistics.can_start_volley():
		return false
	var t = attack_target
	var designating := unit_id == "BORIS" and is_instance_valid(t) and t is Building
	preload("res://scripts/units/expansion_2_armor.gd").prepare_wait(self,t)
	var reload_left := float(special.get("airstrike_cd", 0.0)) if designating else _cd_timer
	if (fire_stance == "none" and not attack_ordered) or _burst_left > 0 or reload_left > 0.0:
		return false
	var weapon := _active_weapon()
	if weapon.is_empty(): return false
	if designating and (special.has("airstrike_wing") or t.special.has("airstrike_mark") or t.special.has("airstrike_left")): return false
	if not _weapon_target_valid(t, weapon) or not _weapon_aligned(t):
		return false
	if unit_id == "DTRUCK" and side == "enemy" and preload("res://scripts/world/skirmish_tactics.gd").unsafe_demo_site(_battle_world(), side, global_position):
		return false
	if not preload("res://scripts/units/ra3_future_state.gd").prepare(self,t):return false
	logistics.consume_volley(t)
	_burst_left = max(1, int(weapon.get("burst", 1)))
	if unit_id in MISSILE_CARRIERS:
		_burst_left = mini(_burst_left, SovietWeapons.ready_racks(self))
		if _burst_left == 0: return false
	if unit_id=="SAPC" and special.has("fleet_talent"):
		_burst_left=maxi(1,int(special.get("fleet_ammo",1)))
		special.fleet_ammo=0
	if special.erase("extra_volley"):
		_burst_left *= 2
	_burst_target = t
	_burst_timer = 0.0
	# 冷却缩减 buff（青）：按比例压低武器装填时间；再叠老兵 ROF（RA2 VetROF）
	var interval := float(weapon.cooldown) if unit_id in ["BORIS","YURIKO"] or special.has("peregrine") else cooldown
	var reload := CombatMath.veteran_cooldown(interval, bonuses) * (1.0 - clampf(buff_value("cooldown"), 0.0, 0.85)) * YRTalents.cooldown_multiplier(self)
	if unit_id in ["DOG", "SOV_DOG"]: reload /= Training.timing_scale(self)
	if special.has(Furnace.GUARD): reload /= float(special[Furnace.GUARD].rate)
	reload=preload("res://scripts/units/progression_expansion.gd").modify_reload(self,reload)
	if special.has("studio"):reload*=StudioTalents.reload_factor(self,t)
	if weapon.get("peregrine_aa",false):reload=1.0
	if buff_value("west_shift") > 0: reload *= 0.5
	if designating:
		SovietSpecials.set_airstrike_reload(self, reload)
		preload("res://scripts/units/boris_radio.gd").started(self)
	else: _cd_timer = reload
	if UnitSkillLayout.find(self,"ap_focus_fire")>=0 or passive.get("id")==DomainCards.ANCHOR:special.focus_reload_duration=reload
	if unit_id == "APOC":
		# Both domain slots share this reload. Preserve its denominator across retargeting and saves.
		special.shared_reload_duration = _cd_timer
	if special.get("academy_hero")=="TANY":preload("res://scripts/units/tanya_operations.gd").volley(self,t,weapon)
	_fire_shot(t,true)
	_burst_left -= 1
	if _burst_left == 0:
		_burst_target = null
	_burst_timer = float(weapon.get("burst_delay", 0.1))
	return true

## RA2 炮口火光：武器 Anim= 指定的真实动画 SHP（8 项按炮塔朝向取，1 项恒用）。
## 位置用真实炮口（aim_dir * (radius+4)）；Bright=yes 用叠加混合（RA2 的发光闪光）。
func _spawn_muzzle_fx(at: Vector2, wid: String) -> void:
	if wid == "":
		return
	# Add a compact afterglow at the same rifle or garrison muzzle as the stock flash.
	if special.get("hero_skin", false) and unit_id in ["E1", "E2"]:
		var glow := Color("#c4e8f4") if unit_id == "E1" else Color("#ffc281")
		Effects.spawn_flash(at, 8.0, glow)
	if TankHeroSkin.enabled(self):Effects.spawn_flash(at,12.0,TankHeroSkin.COLORS[0 if unit_id=="MTNK" else 1])
	if OpenTopped.active(self):
		var port_anim := str(GameData.ra2_weapon(wid).get("extra", {}).get("OpenToppedAnim", ""))
		if not port_anim.is_empty():
			Ra2Fx.play(Effects._host(), at, port_anim)
			return
	if embarked_in is Building and embarked_in.data.has("fire_ports"):
		var extra: Dictionary = GameData.ra2_weapon(wid).get("extra", {})
		var window_anim := str(extra.get("OccupantAnim", ""))
		if not window_anim.is_empty():
			var flash = Ra2Fx.play(embarked_in.battle.effects_root, at, window_anim)
			if flash != null and flash.anim.translucent: flash.tint.a = 0.5
			return
	var names: Array = GameData.ra2_muzzle_anims(wid)
	if names.is_empty():
		return
	var img := Ra2Fx.pick_directional(names, Iso.dir(aim_dir))
	if img == "":
		return
	Ra2Fx.play_transient(Effects._host(), at, img, 1.0, GameData.ra2_muzzle_bright(wid))

## 弹着表现（第 8 批）：AnimList= 按【伤害】选档 + Sparky 火花 + Bright 闪光 + 地面灼痕
func _spawn_impact_anim(at: Vector2, dmg: float = 0.0, ground_hit := true) -> void:
	var wid := str(_active_weapon().get("ra2_warhead", ""))
	if wid == "":
		return
	var host:=Effects._host()
	if not Effects.Looks.impact(host,at,Effects.Looks.current(self)) and not Ra2Fx.play_impact(host, wid, dmg, at):
		Effects.spawn_impact(at, Color(1.0, 0.85, 0.5), 8.0 + minf(dmg, 200.0) * 0.06)
	if ground_hit: Ra2Fx.spawn_scorch(Effects._host(), wid, dmg, at)

func _disc_trace(stage: String, target, weapon_id := "") -> void:
	var trace := get_tree().get_first_node_in_group("battle_crash_trace")
	if trace == null: return
	var target_id := "point"
	if target is Unit: target_id = target.unit_id
	elif target is Building: target_id = target.building_id
	trace.mark("disc." + stage, {"shooter": get_instance_id(), "side": side, "target": target_id, "weapon": weapon_id})

func _fire_shot(target,first_in_volley:=false) -> void:
	if unit_id == "DISK": _disc_trace("fire.begin", target)
	if special.has("peregrine") and preload("res://scripts/units/peregrine_defense.gd").silent(self):return
	if special.has("commando_hero_v2") and special.commando_hero_v2.has("corridor_call"):return
	if (special.has("tanya_flash_left") or special.get("academy_hero")=="TANY") and preload("res://scripts/units/tanya_talents.gd").silenced(self):return
	if special.has("boris_command") and preload("res://scripts/units/boris_command.gd").suppressed(self):return
	if special.get("academy_hero")=="TANY":preload("res://scripts/units/tanya_talents.gd").attacking(self)
	if Ra3Mirage.field_active(self): return
	if special.has("ra3_riot_point"): return
	if not is_instance_valid(target):
		return
	target=preload("res://scripts/units/expansion_2_armor.gd").split_target(self,target)
	if special.get("academy_hero")=="E2" and side=="ally" and BattleRequest.combat_context.get("furnace_contract",false):
		var world := _battle_world()
		if world != null: world.allied_state.furnace_attacked=true
	# Actual normal shots (including force-fire) interrupt hero shield recovery.
	TankHero.Shield.interrupt_recovery(self)
	if Ra3Expansion.handles(self):
		_muzzle = 0.09
		special.reveal = 2.0
		Ra3Expansion.shoot(self, target)
		if first_in_volley:preload("res://scripts/units/expansion_2_overload.gd").fired(self)
		return
	if unit_id in ["SUB", "SQD"]:
		NavalContact.surface(self)
	var world := _battle_world()
	if world != null:
		world.reveal_attack(embarked_in if OpenTopped.active(self) or embarked_in is Building else self, target)
	var weapon := _active_weapon()   # 精英武器优先（RA2 ElitePrimary）
	if unit_id == "DISK": _disc_trace("weapon", target, str(weapon.get("name", "")))
	var reference_weapon:=weapon.duplicate(true) if CombatMath.FinalDamage.active() else {}
	if unit_id == "SHK":
		# Consume on actual firing, including a dodge or force-fire; never mutate shared weapons.
		weapon = weapon.duplicate()
		weapon.damage = float(weapon.damage) * preload("res://scripts/units/expansion_2_infantry.gd").discharge(self,preload("res://scripts/units/tesla_reserve.gd").discharge(self))
		weapon.damage *= preload("res://scripts/units/electric_cards.gd").primary_multiplier(self,target)
	preload("res://scripts/units/expansion_2_ground.gd").before_reveal(self)
	_muzzle = 0.09
	special.reveal = 2.0
	if _seq.has(_fire_sequence()):
		_fire_anim_time = 0.0
	_recoil = 1.0
	queue_redraw()
	# 命中判定：自身命中加成抵消目标闪避（紫）
	preload("res://scripts/units/expansion_2_air.gd").firing(self)
	preload("res://scripts/units/expansion_2_naval_fire.gd").firing(self,target)
	preload("res://scripts/units/expansion_2_submarine.gd").firing(self)
	preload("res://scripts/units/expansion_2_infiltration.gd").attacking(self)
	preload("res://scripts/units/expansion_2_aircraft.gd").firing(self)
	if first_in_volley:preload("res://scripts/units/expansion_2_overload.gd").fired(self)
	var hit_chance: float = clampf(1.0 + buff_value("accuracy") - _target_evade(target), 0.05, 1.0)
	if hit_chance < 0.999 and randf() > hit_chance:
		if special.has("studio"):
			special.studio.erase("duel")
			special.studio.erase("fort")
		if special.erase("echo_cloaked"):
			special.erase("echo_bonus")
			special.erase("echo_bonus_left")
		Effects.spawn_text(Effects.hit_position(target) + Vector2(0, -radius - 20), "闪避", Color(0.80, 0.72, 1.0))
		return
	# 注意：Object.get() 只接受 1 个参数（旧代码 target.get("ra2_armor", "") 是错的，
	# 会在实机开火时报 Invalid call 并让 RA2 Verses 通路静默失效，退回引擎护甲）
	if unit_id == "YURIKO":
		preload("res://scripts/units/yuriko.gd").crush(self,target)
		return
	if unit_id == "BSUB" and weapon.name == "CruiseLauncher":
		NavalContact.surface(self)
		var missile = world.spawn_unit("CMISL", side, position)
		if missile != null:
			missile.special.flight = {"origin":position, "aim":target.position, "source":self, "elapsed":0.0,
				"windup":1.33, "altitude":165, "duration":maxf(0.1,position.distance_to(target.position)/330),
				"damage":250 if veteran_level >= 2 else 200, "warhead":"YR_CMISLWH", "bonus":bonuses.duplicate(true)}
		return
	if SovietSpecials.shoot(self, target, weapon): return
	if unit_id in MISSILE_CARRIERS:
		SovietWeapons.launch(self, target)
		return
	var t_ra2 = target.get("ra2_armor")
	var shot_bonus := bonuses.duplicate(true)
	if special.has("studio"):StudioTalents.shot(self,target,shot_bonus)
	if special.has("convoy"):Convoy.fired(self,target,shot_bonus,first_in_volley)
	logistics.apply_carrier_attack(shot_bonus)
	preload("res://scripts/units/progression_expansion.gd").shot(self,target,shot_bonus)
	if not reference_weapon.is_empty():shot_bonus.reference_weapon=reference_weapon
	shot_bonus.impact_weapon = weapon.get("ra2_weapon_id","")
	# 暴击 buff（红+蓝）：概率性增伤
	var crit_ch: float = clampf(buff_value("crit"), 0.0, 0.95)
	if crit_ch > 0.0 and randf() < crit_ch:
		shot_bonus["attack_bonus"] = float(shot_bonus.get("attack_bonus", 1.0)) * 1.6
		Effects.spawn_text(Effects.hit_position(target) + Vector2(0, -radius - 24), "暴击", Color(1.0, 0.55, 0.35))
	var dmg := CombatMath.full_damage(weapon, str(target.get("armor")), shot_bonus, null, "" if t_ra2 == null else str(t_ra2), 0.0, target)
	var pspd := float(weapon.get("projectile_speed", 0.0))
	var barrel_index := -1
	if unit_id == "APOC" and weapon.name in ["120mmx", "120mmxE"]:
		barrel_index = posmod(int(weapon.burst) - _burst_left, 2)
	var muzzle := _weapon_muzzle(barrel_index)
	if weapon.get("peregrine_aa",false):Effects.spawn_beam(muzzle,Effects.hit_position(target),Color(.95,.85,.55),"laser",1.0,.05)
	if yr_finish!=null:yr_finish.fire(barrel_index,weapon,Iso.dir(muzzle-global_position))
	var commando_look:=CommandoFx.primary_style(self,weapon) if special.get("hero_skin",false) else ""
	if not commando_look.is_empty():
		CommandoFx.spawn(Effects._host(),commando_look,CommandoSkin.shot_origin(self,muzzle),Effects.hit_position(target))
	elif not Ra3Mirage.handles(self): _spawn_muzzle_fx(muzzle, str(weapon.get("ra2_weapon_id", "")))
	# RA2 开火音效：weapon Report= → sound.ini → wav（与炮口火光同步）
	if unit_id == "YTNK" and str(weapon.get("report", "")).begins_with("GattlingGunAttackLoop"):
		preload("res://scripts/core/gatling_audio.gd").shot(self,weapon,_cd_timer)
	elif not Ra3Mirage.handles(self):
		if unit_id == "DISK": _disc_trace("audio.begin", target)
		Ra2Sfx.play_weapon(weapon, muzzle)
		if unit_id == "DISK": _disc_trace("audio.end", target)
	if Ra3Mirage.handles(self):
		Ra3Mirage.shoot(self, target, weapon, dmg, shot_bonus)
		return
	if AlliedAbilities.special_shot(self, target, weapon): return
	# 表现层：光束/激光/电弧武器（原版无 Anim=，靠 IsLaser/IsRadBeam/IsElectricBolt 渲染）
	# → 程序化光束，见 GameData.ra2_beam_spec（数据驱动，覆盖全部 27 把）
	var beam := GameData.ra2_beam_spec(str(weapon.get("ra2_weapon_id", "")))
	var beam_drawn := false
	if unit_id == "DISK" and weapon.get("name", "") in ["DiskLaser", "DiskLaserE"]:
		_disc_trace("laser.begin", target)
		var endpoint: Vector2 = target.art_center() if target.has_method("art_center") else Effects.hit_position(target)
		Effects.spawn_beam(_disc_center(), endpoint, Color("ff454c"), "laser", 2.5, 0.24, "", null, false, false, true, global_position, target.global_position)
		_disc_trace("laser.created", target)
		beam_drawn = true
	elif not beam.is_empty():
		var bcol: Color = beam.get("color", Color(1, 1, 1))
		if (beam.get("house", false) == true):
			bcol = HouseColor.color_for_side(side, "")
		Effects.spawn_beam(muzzle, Effects.hit_position(target), bcol, str(beam.get("kind", "laser")),
			float(beam.get("thickness", 2.5)), float(beam.get("duration", 0.12)), Effects.Looks.current(self,true),null,false,yr_finish!=null and unit_id=="TTNK")
		beam_drawn = true
	if pspd <= 0.0 and target is ForceFirePoint:
		ForceFire.instant_ground(self, target, weapon, dmg, shot_bonus, _pick_projectile_parent())
		return
	if pspd <= 0.0:
		# 瞬发（电弧 / 近战）
		var at := str(weapon.get("attack_type", "melee"))
		if at == "tesla" and not beam_drawn:
			Effects.spawn_beam(muzzle, Effects.hit_position(target), Color(0.6, 0.9, 1.0), "tesla", 2.2, 0.09)
		elif not beam_drawn and commando_look.is_empty():
			Effects.spawn_impact(Effects.hit_position(target), Color(0.9, 0.85, 0.7), 8.0)
		# 瞬发武器（电弧/近战/光束）同样按弹头 AnimList= 播放真实命中动画（第 8 批：按伤害选档）
		if unit_id == "DISK": _disc_trace("impact.begin", target)
		if commando_look.is_empty(): _spawn_impact_anim(Effects.hit_position(target), dmg, Effects.hit_position(target).is_equal_approx(target.global_position))
		else: Effects.Looks.impact(Effects._host(), Effects.hit_position(target), commando_look)
		if target.has_method("receive_hit"):
			if unit_id == "DISK": _disc_trace("impact.end", target)
			preload("res://scripts/world/bridge_damage.gd").instant_target(self,target,CombatMath.with_offense(float(weapon.get("damage",0.0)),shot_bonus),str(weapon.get("ra2_warhead","")))
			if unit_id == "DISK": _disc_trace("damage.begin", target)
			target.receive_hit(dmg, at, shot_bonus, self, str(weapon.get("ra2_warhead", "")))
			if unit_id == "DISK": _disc_trace("damage.end", null)
			if shot_bonus.get("leizhu_primary",false):
				preload("res://scripts/units/leizhu_station.gd").finish(self,shot_bonus)
				preload("res://scripts/units/leizhu_cards.gd").finish(self)
			if unit_id == "SHK": preload("res://scripts/units/electric_cards.gd").chain_hit(self,target)
	else:
		if unit_id == "DISK": _disc_trace("projectile.begin", target)
		var p := Projectile.new()
		p.setup(muzzle, target, weapon, dmg, shot_bonus, side, self)
		_pick_projectile_parent().add_child(p)
		if unit_id == "DISK": _disc_trace("projectile.created", target)

## 目标闪避值（供命中判定调用）
func _target_evade(t) -> float:
	if is_instance_valid(t) and t.has_method("buff_value"):
		return float(t.buff_value("dodge"))
	return 0.0

func _pick_projectile_parent() -> Node:
	var tree := get_tree()
	var holder := tree.get_first_node_in_group("projectiles_root")
	return holder if holder != null else get_parent()

# ------------------------------------------------------------------ 采集

func _process_harvester(delta: float) -> void:
	if delta <= 0.0:
		return
	EconomyCycle.normalize_unload(self)
	if special.has("ore_bale_wait"):
		special.ore_bale_wait = maxf(0, float(special.ore_bale_wait) - delta)
	# Player movement temporarily overrides automatic collection.
	if has_move_order:
		auto_harvest_idle = 0.0
		chrono_return_elapsed = 0.0
		chrono_return_blocked = false
		_tick_path_stuck(delta)
		if _go_to(move_target, delta, ARRIVE_EPS):
			has_move_order = false
			_clear_field()
			_advance_queue()
		else:
			_face_harvest_travel()
		_move_water_safe()
		return
	# Vacate the entrance even when the last ore field has been exhausted.
	if _harvest_exit != Vector2.INF:
		auto_harvest_idle = 0.0
		_leave_refinery(delta)
		return
	# 卡死黑名单倒计时（不可达/卡住的矿点暂时跳过，避免反复去撞）
	for k in _ore_block.keys():
		_ore_block[k] = float(_ore_block[k]) - delta
		if float(_ore_block[k]) <= 0.0:
			_ore_block.erase(k)

	if special.get("academy_hero")=="HARV" and Convoy.idle_miner(self,delta):return
	if _wait_for_auto_harvest(delta):
		return
	# (A5) 矿点会采空并缓慢再生：空/近空的矿点直接跳过，改投最近的可采矿点
	if harvest_state in ["to_node", "harvesting"] and (not is_instance_valid(resource_node) or not _node_ok(resource_node) or _ore_block.has(resource_node)):
		if not BattleRequest.native_ore_map().is_empty() and not is_instance_valid(resource_node) and cargo <= 0:
			var retry := float(special.get("ore_search_wait", 0)) - delta
			if retry > 0:
				special.ore_search_wait = retry
				return
			if not ai_path_allowed(): return
			special.ore_search_wait = 1.0
		elif not ai_path_allowed(): return
		resource_node = _ore_target()
		if harvest_state == "harvesting":
			harvest_state = "to_node"
	# 红警2：采矿车只在「矿石精炼厂」(tag=refinery) 卸矿；每 1.5s 重选最近精炼厂（能自动认到新建成的矿厂）
	_home_tick -= delta
	var blocked_home := false
	if _home_tick <= 0.0 and _dock_locked:
		_home_tick = 1.5
		blocked_home = harvest_state == "to_base" and is_instance_valid(home_base) and not EconomyCycle.refinery_accessible(self, home_base)
	if not is_instance_valid(home_base) or home_base.side != side or home_base.hp <= 0.0 or not home_base.is_operational() \
			or blocked_home or (_home_tick <= 0.0 and not _dock_locked):
		if not ai_path_allowed(): return
		var previous_home = home_base
		home_base = _pick_home_base()
		_home_tick = 1.5
		if previous_home != home_base:
			if harvest_state == "unloading":
				harvest_state = "to_base"
				_unload_work = 0.0
			_unlock_dock()
			_clear_field()
			_stuck_reset()
	# Returning a load must not depend on another mine still having ore.
	if resource_node == null and cargo > 0.0 and harvest_state in ["to_node", "harvesting"]:
		harvest_state = "to_base"
	if special.get("academy_hero")=="HARV" and not special.get("convoy_delivery",false) and harvest_state in ["to_base","unloading"]:
		_suspend_harvest();return
	if (resource_node == null and harvest_state in ["to_node", "harvesting"]) \
			or (home_base == null and harvest_state in ["to_base", "unloading"]):
		if harvest_state == "unloading":
			harvest_state = "to_base"
		_unlock_dock()
		_clear_field()
		velocity = Vector2.ZERO
		_move_water_safe()
		return

	match harvest_state:
		"to_node":
			# 停止距离与到达阈值统一（过去 60 > 52，矿车停在阈值外永远进不了 harvesting）
			var nod_r: float = 0.0
			if resource_node != null and is_instance_valid(resource_node):
				nod_r = float(resource_node.radius)
			var previous_node = resource_node
			var tn: Vector2 = resource_node.global_position
			if not _steer_field_to(tn): return
			_track_stuck(delta, tn, true)
			if resource_node != previous_node: return
			var stop_distance := 24.0 if resource_node.native_variant >= 0 else nod_r + 26.0
			if _go_to(tn, delta, stop_distance):
				_stuck_reset()
				harvest_state = "harvesting"
			else:
				_face_harvest_travel()
		"harvesting":
			_clear_field()
			velocity = Vector2.ZERO
			# Harvesting aims the chassis, independently of weapon/turret logic.
			# Test the actual heading before requesting a turn; _limit_turn applies
			# the imported ROT later in this physics tick.
			var aligned := _harvest_facing_ready()
			var toward_ore: Vector2 = resource_node.global_position - global_position
			if not toward_ore.is_zero_approx() and resource_node.native_variant < 0:
				hull_angle = toward_ore.angle()
				turret_angle = hull_angle
				aim_dir = toward_ore.normalized()
			queue_redraw()
			if not aligned:
				_harvest_fx.remaining = 0.0
			if resource_node.native_variant >= 0:
				_collect_native_bale(delta, aligned)
				_move_water_safe()
				return
			var units_per_bale := _map_units_per_cargo_unit()
			var space := maxf(0.0, cargo_cap - cargo) * units_per_bale
			var drawn := minf(maxf(0.0, harvest_rate * delta * (2.0 if special.has("convoy_double_hold") else 1.0)), space) if aligned else 0.0
			if resource_node != null and is_instance_valid(resource_node) and resource_node.has_method("extract"):
				drawn = resource_node.extract(drawn)
				if resource_node.resource_kind == "gems":
					cargo_gems += drawn / units_per_bale
				_harvest_fx.extracted(self, resource_node, drawn)
			_collect_cargo(drawn / units_per_bale)
			if drawn>0 and special.has("convoy_miner_hit"):Convoy.collected(self)
			if cargo >= cargo_cap:
				harvest_state = "to_base"
			elif not _node_ok(resource_node, 0.05):
				# (A5) 矿点采空：立即换最近的非空矿点；附近全空则先把已有货送回
				var nxt = _ore_target(0.05)
				if nxt != null and nxt != resource_node:
					resource_node = nxt
					harvest_state = "to_node"
				elif cargo > 0.0:
					harvest_state = "to_base"
		"to_base":
			if not _dock_locked or _dock_home != home_base:
				_lock_dock()
			if _dock_phase == 0 and _dock_occupied():
				_dock_wait += delta
				chrono_return_elapsed = 0.0
				chrono_return_blocked = unit_id == "CMIN"
				# Remote chrono miners wait where they are. Nearby/ordinary miners
				# wait beside the entrance, leaving the outbound lane clear.
				if unit_id != "CMIN" or global_position.distance_to(_dock_stage()) < 150.0:
					var waiting_point: Vector2 = home_base.refinery_traffic.waiting_point(home_base, self)
					if not _steer_field_to(waiting_point): return
					if not _go_to(waiting_point, delta, ARRIVE_EPS): _face_harvest_travel()
				else:
					velocity = Vector2.ZERO
					_clear_field()
				_move_water_safe()
				return
			if EconomyCycle.chrono_return(self, delta):
				return
			if _dock_phase == 0:
				if not _steer_field_to(_dock_stage()): return
				if _go_to(_dock_stage(), delta, 16.0):
					_stuck_reset()
					velocity = Vector2.ZERO
					hull_angle = _dock_out.angle()
					# Turn while parked. Only the final short approach is reversing.
					if not _dock_occupied() and absf(angle_difference(_hull_prev, hull_angle)) < 0.12:
						_dock_phase = 1
						_dock_wait = 0.0
						_back_in = true
						_clear_field()
				else:
					_face_harvest_travel()
					if not _drive_turning:
						_track_stuck(delta, _dock_stage(), false)
			else:
				_dock_wait += delta
				hull_angle = _dock_out.angle()
				if _dock_occupied():
					_stuck_reset()
					_clear_field()
					velocity = Vector2.ZERO
				else:
					_clear_field()
					_reverse_to(_dock_pt, delta)
					if _dock_pt.distance_to(global_position) <= DOCK_STOP:
						_stuck_reset()
						velocity = Vector2.ZERO
						harvest_state = "unloading"
						_unload_timer = unload_time
						_unload_work = 0.0
					else:
						_track_stuck(delta, _dock_pt, false)
		"unloading":
			_clear_field()
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 6.0 * delta)
			if _dock_locked:
				hull_angle = _dock_out.angle()   # 卸矿时保持倒车姿态（尾部对着矿厂）
			_unload_timer -= delta
			if _unload_timer <= 0.000001:
				_unload_timer = 0.0
				_unload_cargo(cargo)
			if cargo <= 0.000001:
				cargo = 0.0
				cargo_gems = 0.0
				_unlock_dock()
				special.erase("convoy_delivery")
				_harvest_exit = global_position # Pending until a reachable exit has been reserved.
				_exit_check_left = 0.0
				_back_in = false
				harvest_state = "to_node"
	_move_water_safe()

# Transient: revalidate old saves and periodically retry if traffic changes.
var _exit_check_left := 0.0
var _exit_progress_at := Vector2.INF

func _leave_refinery(delta: float) -> void:
	if not is_instance_valid(home_base) or home_base.hp <= 0.0 or home_base.side != side:
		_harvest_exit = Vector2.INF
		_clear_field()
		return
	_exit_check_left -= delta
	if _exit_check_left <= 0.0:
		if not ai_path_allowed():
			velocity = Vector2.ZERO
			return
		var stalled := global_position.distance_to(_exit_progress_at) < 4.0 and global_position.distance_to(_harvest_exit) > ARRIVE_EPS
		_exit_progress_at = global_position
		_exit_check_left = 1.0
		var needs_route := _path_pts.size() < 2 or not _path_pts[-1].is_equal_approx(_harvest_exit) or _path_epoch != _terrain_epoch()
		if needs_route or stalled or not EconomyCycle.miner_landing_clear(_battle_world(), _harvest_exit, radius + 4.0, self):
			var route: PackedVector2Array = home_base.refinery_traffic.exit_route(home_base,self,_harvest_exit if stalled else Vector2.INF)
			_clear_field()
			if not route.is_empty():
				_harvest_exit = route[-1]
				_flow_goal = _harvest_exit
				set_agent_path(route)
	if _path_pts.is_empty():
		velocity = Vector2.ZERO
		return
	if _go_to(_harvest_exit, delta, ARRIVE_EPS):
		_harvest_exit = Vector2.INF
		_exit_progress_at = Vector2.INF
		_clear_field()
	else:
		_face_harvest_travel()
	_move_water_safe()

var _unload_timer: float = 0.0
var _unload_work: float = 0.0
var _last_water_pos: Vector2 = Vector2.INF
var _flow_goal: Vector2 = Vector2.INF   # 当前寻路流场对应的目标点（避免每帧重算）
var _stuck_t: float = 0.0               # 顶墙卡滞累计时长
var _stuck_waypoint := Vector2.INF
var _stuck_best: float = INF            # 本次行程距目标最近距离
var _stuck_n: int = 0                   # 连续卡滞次数
var _ore_block: Dictionary = {}         # 矿点 -> 解禁剩余秒（卡死过的矿点暂避）

## Manual orders enter idle; an active collection/delivery cycle keeps its own state machine.
func _collect_native_bale(delta: float, aligned: bool) -> void:
	if not aligned:
		harvest_state = "to_node"
		return
	if float(special.get("ore_bale_wait", 0)) > 0.000001:
		_harvest_fx.extracted(self, resource_node, delta)
		return
	special.ore_bale_wait = 1.0 / maxf(harvest_rate, 0.01)
	var stages_before: float = resource_node.amount
	var bale:=minf(2.0,minf(cargo_cap-cargo,maxf(0,stages_before-1))) if special.has("convoy_double_hold") else 1.0
	if special.has("convoy_double_hold") and cargo>=cargo_cap:return
	resource_node.extract(bale if bale>0 else 1.0)
	if stages_before > 1:
		_collect_cargo(bale)
		if resource_node.resource_kind == "gems": cargo_gems += bale
		if bale>0 and special.has("convoy_miner_hit"):Convoy.collected(self)
		_harvest_fx.extracted(self, resource_node, 1)
	if cargo >= cargo_cap:
		harvest_state = "to_base"
	elif resource_node.is_empty():
		var next = _native_ore_target(true)
		_claim_ore(next)
		resource_node = next
		harvest_state = "to_base" if next == null and cargo > 0 else "to_node"

func _collect_cargo(amount: float) -> void:
	var previous := cargo
	cargo = minf(cargo_cap, cargo + amount)
	if side=="ally" and special.get("academy_hero")=="HARV":
		var threshold:float=special.convoy.base_hold*.25
		if previous<threshold and cargo>=threshold:
			Effects.spawn_text(art_center(),"热锭备妥",Color.GOLD)
			Events.emit_message("老秤 · 矿量达到原仓的 1/4，W 可打出热锭。",Color.GOLD)

func _suspend_harvest() -> void:
	special.erase("convoy_delivery")
	if not is_harvester: return
	harvest_state = "idle"
	auto_harvest_idle = 0.0
	_claim_release()
	resource_node = null
	_unlock_dock()
	_clear_field()
	_harvest_exit = Vector2.INF
	chrono_return_elapsed = 0.0
	chrono_return_blocked = false

func _wait_for_auto_harvest(delta: float) -> bool:
	if hold_position or patrolling:
		auto_harvest_idle = 0.0
		velocity = Vector2.ZERO
		return true
	if harvest_state not in ["idle", ""]:
		auto_harvest_idle = 0.0
		return false
	velocity = Vector2.ZERO
	if not auto_harvest_enabled:
		auto_harvest_idle = 0.0
		return true
	auto_harvest_idle += delta
	if auto_harvest_idle < AUTO_HARVEST_IDLE_SECONDS or not ai_path_allowed(): return true
	auto_harvest_idle = 0.0
	home_base = _pick_home_base()
	if not is_instance_valid(home_base): return true
	if cargo > 0.0:
		harvest_state = "to_base"
		return false
	var node = _ore_target()
	if not is_instance_valid(node): return true
	order_harvest(node)
	return false

func _harvest_facing_ready() -> bool:
	if not is_instance_valid(resource_node):
		return false
	if resource_node.native_variant >= 0:
		return Vector2i((global_position / 55.0).floor()) == Vector2i((resource_node.position / 55.0).floor())
	var direction: Vector2 = resource_node.global_position - global_position
	# Ore is traversable: a miner directly over the resource keeps its heading.
	return direction.is_zero_approx() or absf(angle_difference(hull_angle, direction.angle())) <= deg_to_rad(2.0)

func _face_harvest_travel() -> void:
	_face_if_moving()
	# Do not travel backwards while the limited-speed hull turn catches up.
	var turn := absf(angle_difference(_hull_prev, hull_angle))
	if turn > PI / 3.0:
		velocity = Vector2.ZERO

## 自动采矿每次换目的地都重建路径，避免沿用玩家之前下达的移动路线。
func _steer_field_to(p: Vector2) -> bool:
	var current_epoch := _terrain_epoch()
	var same_goal := _flow_goal.is_finite() and _flow_goal.distance_squared_to(p) <= 400.0
	if same_goal and _path_epoch != current_epoch and _path_pts.size() >= 2 and _combat_world is Battle:
		if _combat_world.remaining_route_unchanged(self, current_epoch):
			_path_epoch = current_epoch
	if not same_goal or _path_epoch != current_epoch:
		if not ai_path_allowed():
			velocity = Vector2.ZERO
			return false
		move_target = p
		set_agent_path(_path_for(p))
		path_field = null
		_flow_goal = p
	return true

func _clear_field() -> void:
	path_field = null
	_flow_goal = Vector2.INF
	_path_pts.clear()
	_path_i = 0

func _stuck_reset() -> void:
	_stuck_waypoint = Vector2.INF
	_stuck_t = 0.0
	_stuck_best = INF
	_stuck_n = 0

# --- (M6) 卸矿泊位：冻结 + 倒车入库 ---------------------------------------

var _dock_pt: Vector2 = Vector2.INF          # 冻结的卸矿泊位（世界坐标）
var _dock_out: Vector2 = Vector2(0.0, 1.0)   # 泊位外法线（远离矿厂方向）
var _dock_home: Node = null                  # 泊位所属矿厂
var _dock_locked: bool = false               # 泊位是否已冻结
var _dock_phase: int = 0                     # 0=驶向待泊位 1=倒车入库
var _dock_wait: float = 0.0                  # 泊位被占用的等待时长
var _back_in: bool = false                   # 倒车姿态（绘制用）
var _harvest_exit := Vector2.INF
var _ore_claim: Node = null                  # (M6) 已认领的矿点

const DOCK_STAGE_BACK := 46.0                # 待泊位在泊位外侧的退让距离
const DOCK_STOP := 4.0                       # 停到卸矿口附近后才能开始卸载
const DOCK_REVERSE_SPEED := 0.55             # 倒车速度系数（低于前进，观感与原版一致）

## 矿场前方固定卸矿口，位置不随矿车来向变化。
func _lock_dock() -> void:
	if is_instance_valid(_dock_home):
		_dock_home.refinery_traffic.release(_dock_home, self)
	chrono_return_elapsed = 0.0
	chrono_return_blocked = false
	_dock_locked = false
	_dock_phase = 0
	_dock_wait = 0.0
	_back_in = false
	_dock_home = home_base
	if not is_instance_valid(home_base):
		_dock_pt = Vector2.INF
		return
	_dock_out = home_base.refinery_dock_direction()
	_dock_pt = home_base.refinery_dock_point(radius)
	_dock_locked = true
	home_base.refinery_traffic.join(home_base, self)

func _unlock_dock() -> void:
	_harvest_exit = Vector2.INF
	if is_instance_valid(_dock_home):
		_dock_home.refinery_traffic.release(_dock_home, self)
	chrono_return_elapsed = 0.0
	chrono_return_blocked = false
	_dock_locked = false
	_dock_phase = 0
	_dock_wait = 0.0
	_dock_home = null
	_dock_pt = Vector2.INF
	_back_in = false

## 待泊位：泊位再往外退 DOCK_STAGE_BACK。矿车先到这里把车身摆正，再倒车入库。
func _dock_stage() -> Vector2:
	if _dock_pt == Vector2.INF:
		return global_position
	return _dock_pt + _dock_out * DOCK_STAGE_BACK

## 泊位是否被同阵营其它矿车占用（正在卸矿且贴在泊位上）。
func _dock_occupied() -> bool:
	if _dock_pt == Vector2.INF:
		return false
	if is_instance_valid(_dock_home) and not _dock_home.refinery_traffic.can_enter(_dock_home, self):
		return true
	for u in get_tree().get_nodes_in_group("ore_harvesters"):
		if u == self or not is_instance_valid(u):
			continue
		if not ("harvest_state" in u) or u.side != side:
			continue
		if u._dock_home == _dock_home and (u._dock_phase == 1 or u.harvest_state == "unloading"):
			return true
	return false

## 倒车入库：位移朝泊位、车头保持朝外。
func _reverse_to(p: Vector2, delta: float) -> void:
	var dir: Vector2 = p - global_position
	if dir.length() < 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 6.0 * delta)
		return
	velocity = dir.normalized() * minf(move_speed * DOCK_REVERSE_SPEED, dir.length() / maxf(0.001, delta))
	hull_angle = _dock_out.angle()

## 无进展时重新寻路；连续受阻则重选目标。不要直接改坐标穿过碰撞体。
func _track_stuck(delta: float, travel: Vector2, is_to_node: bool) -> void:
	# The shortest legal route can initially lead away from the mine or dock.
	var waypoint := travel
	if _path_pts.size() >= 2:
		waypoint = _path_pts[clampi(_path_i,1,_path_pts.size()-1)]
	var d := global_position.distance_to(waypoint)
	if not waypoint.is_equal_approx(_stuck_waypoint):
		_stuck_waypoint = waypoint
		_stuck_best = d
		_stuck_t = 0.0
		return
	if d < _stuck_best - 6.0:
		_stuck_best = d
		_stuck_t = 0.0
		_stuck_n = 0
		return
	_stuck_t += delta
	if _stuck_t < 1.2:
		return
	_stuck_t = 0.0
	_stuck_n += 1
	# Miners can meet parked armour or another loaded truck on a narrow leg.
	# Use the same local traffic exclusions as an explicit move order before
	# abandoning good ore. Keep the final reverse into the berth straight.
	if _stuck_n < 3 and (is_to_node or _dock_phase == 0):
		var blockers := _local_traffic.stalled_blockers(self,waypoint)
		if not blockers.is_empty() and ai_path_allowed():
			var world := _navigation_world()
			if world != null:
				var detour: PackedVector2Array = world.path_for_unit(self,travel,null,blockers)
				if detour.size()>2 and detour[-1].is_equal_approx(travel):
					set_agent_path(detour)
					_flow_goal = travel
					_stuck_waypoint = detour[1]
					_stuck_best = global_position.distance_to(_stuck_waypoint)
					return
	_clear_field()
	_stuck_best = d
	if _stuck_n >= 3:
		_stuck_n = 0
		if is_to_node and resource_node != null and is_instance_valid(resource_node):
			_ore_block[resource_node] = 20.0
			resource_node = _ore_target()
		else:
			home_base = null
			_unlock_dock()
			velocity = Vector2.ZERO

## 最近可采矿点：优先偏离临时黑名单（卡死过的矿点）；全在黑名单时退回普通就近选择，避免僵住。
## (M6) 再优先「未被同阵营其它矿车认领」的矿点：多台矿车自动分流，不再全部扎堆同一堆矿。
func _native_ore_target(near_only: bool):
	var world := _battle_world()
	if world == null: return null
	var settings: Dictionary = preload("res://scripts/world/native_ore.gd").rules(world.map_layout())
	var scan_tiles := int(settings.near_scan if near_only else settings.far_scan)
	var origin := Vector2i((global_position / 55.0).floor())
	var nearby: Array = world.ore_neighborhood.nearby(global_position, (scan_tiles + 1) * 55.0) if world is Battle else get_tree().get_nodes_in_group("resource_nodes")
	var chosen = _pick_reachable_ore(nearby, world, origin, scan_tiles, near_only, true)
	if chosen != null or near_only:
		return chosen
	return _pick_reachable_ore(get_tree().get_nodes_in_group("resource_nodes"), world, origin, scan_tiles, false, false)

func _pick_reachable_ore(nodes: Array, world: Node, origin: Vector2i, scan_tiles: int, near_only: bool, inside: bool):
	var ranked := []
	var best = null
	var best_score := INF
	for node in nodes:
		if node.get_parent() != world or node.is_empty() or _ore_block.has(node):
			continue
		var offset := Vector2i((node.position / 55.0).floor()) - origin
		var ring := maxi(absi(offset.x), absi(offset.y))
		if (ring <= scan_tiles) != inside:
			continue
		var score := global_position.distance_squared_to(node.position)
		if near_only and ring <= 1:
			score = -1000000.0 if ring == 0 else -10000.0 * node.amount + score / 100
		if node.claim_held_by(self):
			score += 55.0 * 55.0 * 40
		ranked.append([score, node])
		if score < best_score or (score == best_score and node.get_index() < best.get_index()):
			best = node
			best_score = score
	if best == null or _ore_reachable(best):
		return best
	# Only sort when the first choice is blocked. Sibling order breaks equal
	# scores just as the original scene-order scan did.
	ranked.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1].get_index() < b[1].get_index())
	for candidate in ranked:
		if candidate[1] != best and _ore_reachable(candidate[1]):
			return candidate[1]
	return null

func _ore_target(min_frac: float = 0.02):
	if not BattleRequest.native_ore_map().is_empty():
		var native_target = _native_ore_target(false)
		_claim_ore(native_target)
		return native_target
	var best = null
	var bd := INF
	var free_best = null
	var free_bd := INF
	var world := _battle_world()
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if world != null and not world.is_ancestor_of(n):
			continue
		if not is_instance_valid(n) or not _node_ok(n, min_frac):
			continue
		if _ore_block.has(n):
			continue
		var d: float = global_position.distance_squared_to(n.global_position)
		var available: bool = n.has_method("claim_held_by") and not n.claim_held_by(self)
		if d >= bd and (not available or d >= free_bd): continue
		if not _ore_reachable(n): continue
		if d < bd:
			bd = d
			best = n
		if available and d < free_bd:
			free_bd = d
			free_best = n
	var pick = free_best if free_best != null else best
	if pick == null:
		return _nearest_ore_node(min_frac)
	_claim_ore(pick)
	return pick

## (M6) 矿点认领：释放旧认领、登记新认领。
func _claim_ore(n) -> void:
	if _ore_claim != null and is_instance_valid(_ore_claim) and _ore_claim != n:
		if _ore_claim.has_method("claim_release"):
			_ore_claim.claim_release(self)
	_ore_claim = n
	if n != null and is_instance_valid(n) and n.has_method("claim_by"):
		n.claim_by(self)

## (M6) 释放矿点认领（改道 / 手动指令 / 脱离采集时调用）。
func _claim_release() -> void:
	if _ore_claim != null and is_instance_valid(_ore_claim) and _ore_claim.has_method("claim_release"):
		_ore_claim.claim_release(self)
	_ore_claim = null

# HARV stores native bales even in older saves. In extension mode the map
# counts credit-sized resource units; each of the 40 bales holds 25 of them.
func _map_units_per_cargo_unit() -> float:
	return 25.0 if unit_id == "HARV" and BattleRequest.extensions_enabled() and BattleRequest.native_ore_map().is_empty() else 1.0

func cargo_value() -> float:
	var gems := clampf(cargo_gems, 0.0, cargo)
	var value := (cargo - gems) * GameData.resource_value("ore") + gems * GameData.resource_value("gems")
	return value * _map_units_per_cargo_unit()

func _unload_cargo(amount: float) -> void:
	var quantity := clampf(amount, 0.0, cargo)
	if quantity <= 0.0:
		return
	var share := quantity / cargo
	var credits := cargo_value() * share
	if side == "ally" and BattleRequest.extensions_enabled():
		credits *= float(BattleRequest.combat_bonuses().get("ore_delivery_bonus", 1.0))
	var base_credits := credits
	var world := _battle_world()
	if world != null:
		credits *= EconomyCycle.income_factor(world, side)
	cargo_gems = maxf(0.0, cargo_gems * (1.0 - share))
	cargo = maxf(0.0, cargo - quantity)
	if special.get("convoy_delivery",false) and side=="ally" and Convoy.Cards.C.eligible(world,"HARV"):
		var quest:=Convoy.Cards.C.progress(world,"HARV")
		if quest.get("haul_targets",{}).size()>=2:
			quest.delivered_amount=float(quest.get("delivered_amount",0))+quantity
			if quest.delivered_amount>=.25*float(special.convoy.base_hold):quest.delivered=true
	_deposit(credits, credits - base_credits)

func _deposit(amount: float, purifier_bonus: float = 0.0) -> void:
	var world := _battle_world()
	if world != null:
		world.credit_income(side, amount, false, true)
	if side == "ally":
		var caption := "+" + String.num(amount, 2)
		if purifier_bonus > 0.0: caption += "（精炼 +%s）" % String.num(purifier_bonus, 2)
		Effects.spawn_text(global_position + Vector2(0, -radius - 10), caption, Color(0.6, 0.95, 0.6))

func _battle_world() -> Battle:
	if _combat_world != null: return _combat_world
	var node := get_parent()
	while node != null:
		if node is Battle:
			return node
		node = node.get_parent()
	return null

## 返回 true 表示已到达（距离 ≤ stop）。
## 调用方据此切状态，避免「停止距离 > 到达阈值」导致矿车停在阈值外空转（曾经 60 vs 52）。
func _go_to(p: Vector2, delta: float, stop: float) -> bool:
	if global_position.distance_to(p) <= stop:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
		return true
	_move_toward(p, delta)
	return false

## (A5) 矿点是否仍可采：amount 高于 max_amount*min_frac 视为可用。
func _node_ok(n, min_frac: float = 0.02) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var amt = n.get("amount")
	if amt == null:
		return true
	if n.native_variant >= 0 or not BattleRequest.extensions_enabled():
		return float(amt) > 0.000001
	var mx: float = maxf(1.0, float(n.get("max_amount")))
	return float(amt) > mx * min_frac

## (A5) 最近的可采矿点（跳过采空/近空矿点）；找不到返回 null。
func _ore_reachable(node) -> bool:
	var world := _battle_world()
	if world == null:
		return true
	# The resource center can be blocked while its harvesting rim remains reachable.
	var reach: float = 24.0 if node.native_variant >= 0 else node.radius + 26.0
	var nearest: Vector2 = world.path_service.nearest_reachable(node.global_position, global_position, false, ceili(reach / world.path_service.cell) + 1)
	return nearest.distance_to(node.global_position) <= reach

func _nearest_ore_node(min_frac: float = 0.02):
	var best = null
	var bd := INF
	var world := _battle_world()
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if world != null and not world.is_ancestor_of(n):
			continue
		if not _node_ok(n, min_frac):
			continue
		var d: float = global_position.distance_squared_to(n.global_position)
		if d < bd and _ore_reachable(n):
			bd = d
			best = n
	if best != null:
		_claim_ore(best)
	return best

func _nearest_in_group(g: String):
	var best = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(g):
		if not is_instance_valid(n):
			continue
		if g == "ally_buildings" and str(n.get("side")) != side:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < bd:
			bd = d
			best = n
	return best

## 红警2：采矿车只就近「矿石精炼厂」(tag=refinery) 卸矿；
## 没有可用矿场时保留货物等待，不把总部或敌方建筑当作卸矿点。
func _pick_home_base():
	var best = null
	var bd := INF
	for refinery in get_tree().get_nodes_in_group("ore_refineries"):
		if refinery.side != side or refinery.hp <= 0.0 or not refinery.is_operational():
			continue
		var distance := global_position.distance_squared_to(refinery.global_position)
		if distance < bd and EconomyCycle.refinery_accessible(self, refinery):
			bd = distance
			best = refinery
	return best

# ------------------------------------------------------------------ 受伤 / 死亡

func ignores_warhead(warhead_id: String) -> bool:
	if data.get("immune_to_psionics", false) != true and data.get("immune_to_radiation", false) != true: return false
	var flags: Dictionary = GameData.warhead_combat_rule(warhead_id)
	# PsychicDamage is distinct from mind control in the original rules.
	return (data.get("immune_to_psionics", false) == true and flags.get("mind_control", false)) \
		or (data.get("immune_to_radiation", false) == true and flags.get("radiation", false))

func receive_hit(damage: float, attack_type: String = "bullet", attacker_bonus: Dictionary = {}, source = null, warhead_id: String = "", blast_center := Vector2.INF, blast_damage := -1.0) -> void:
	if damage > 0 and is_instance_valid(_combat_world) and _combat_world.allied_state.has("yuriko_field") and preload("res://scripts/units/yuriko.gd").protected(_combat_world,self,source,attack_type): return
	if damage > 0 and special.has("rescue_shield"): return
	if damage>0 and preload("res://scripts/units/expansion_2_drone.gd").invulnerable(self):return
	if special.get("progression_v1",{}).has("succession"):return
	var hit_reference:=CombatMath.FinalDamage.hit_reference(self,attacker_bonus,source)
	# Delayed damage can outlive its source. Keep resolving the hit without kill credit.
	if not is_instance_valid(source): source=null
	if damage>0 and not _dead and hp>0 and embarked_in==null:TankHero.Shield.interrupt_recovery(self)
	if attack_type=="crush" and MetaProgress.Academy.crush_immune(self): return
	if special.has("iron_left"):
		SovietSpecials.deflect_hit(self, damage)
		return
	if AlliedAbilities.alive(special.get("temporal_by")) and TankHero.rank(self,true)<4: return
	if damage>0 and NavalContact.grip_host(self)!=null and source is Projectile and source.is_sonic:
		SovietSpecials.release_squid(embarked_in, true)
	if special.has("squid") and (attack_type == "sonic" or (is_instance_valid(source) and source is Projectile and source.is_sonic)): SovietSpecials.release_squid(self, true)
	if damage > 0.0: special.reveal = 2.0
	if _dead or hp <= 0.0 or embarked_in != null:
		return
	if ignores_warhead(warhead_id):
		return
	if side == "ally" and GM.god_mode:
		Effects.spawn_text(Effects.hit_position(self) + Vector2(0, -radius - 12), "免疫", Color(0.7, 0.9, 1.0))
		return
	if side == "enemy" and GM.one_shot_kill:
		damage = 99999.0
	if attack_type == "crush":
		_crush_death = true
	var prev_frac: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	# 第 8 批：RA2 量化（正 floor / 负 ceil），并触发 [Warhead] Rocker=yes 的受击摇晃
	var reporter=null
	if damage>0:
		var gun=source.shooter() if source is Projectile else source
		reporter=FactionCards.contact_owner(gun,self)
		if reporter!=null and FactionCards.contact_matches(reporter,self):
			damage*=1.0+float(reporter.passive.value)
		damage=FactionCards.impact(gun,self,damage,source,attacker_bonus)
		damage=preload("res://scripts/units/electric_cards.gd").crew_damage(gun,self,damage,attacker_bonus)
	damage=preload("res://scripts/units/progression_expansion.gd").impact(self,source,damage,attacker_bonus)
	damage=preload("res://scripts/expedition/rules.gd").impact(self,source,damage,attack_type)
	var offense_damage:=damage
	if damage>0 and (special.has("slope_left") or passive.get("id")=="ps_limiter"): damage=FactionCards.defend(self,damage,source,blast_center)
	if special.has(DomainCards.STATE):damage=DomainCards.defend(self,damage)
	damage=Training.defend(self,damage,source)
	if special.has("commando_hero_v2"):damage=preload("res://scripts/units/expansion_2_commandos.gd").defend(self,damage,attack_type,attacker_bonus,source)
	if damage > 0 and unit_id == "MGTK" and special.get("progression_v2", {}).has("mirage_guard"):
		damage=preload("res://scripts/units/expansion_2_ground.gd").defend(self,damage,attack_type,attacker_bonus,source)
	if damage > 0 and unit_id == "APOC":
		damage=preload("res://scripts/units/expansion_2_armor.gd").defend(self,damage,attacker_bonus,source)
	var water_packet:Dictionary={}
	damage=preload("res://scripts/units/expansion_2_naval.gd").defend(self,damage,attack_type,attacker_bonus,source,water_packet)
	damage=preload("res://scripts/expedition/rules.gd").defend(self,damage)
	var defended := CombatMath.with_defense(damage, bonuses)
	defended=CombatMath.FinalDamage.apply(defended,hit_reference*defended/offense_damage if offense_damage>0 else 0.0,self,attacker_bonus,source)
	# Cross-game PRISM ratios retain fractions; Yuri warheads keep their rounding.
	var final_dmg := defended if warhead_id in ["RA3_PRISM", "RA3_EXPANSION"] else Ra2Damage.quantize(defended)
	var water_saved:=preload("res://scripts/units/water_relay.gd").reduction(water_packet,defended,warhead_id) if not water_packet.is_empty() else 0.0
	# Parasite infantry culling is not an ordinary 30-damage bite. Keep immunity
	# and god-mode checks above, and award the kill through the normal death path.
	if warhead_id in ["ParasiteDog", "YR_CAP_ParasiteDog", "YR_SOV_ParasiteDog", "YR_SOV_Parasite"] and AlliedAbilities.infantry(self) and final_dmg > 0:
		final_dmg = maxf(final_dmg, hp)
	if warhead_id == "YR_SOV_ParasitePlus" and final_dmg > 0 and special.has("squid") and is_instance_valid(source) and source == special.squid and SovietSpecials.culls_ship(self, source):
		final_dmg = maxf(final_dmg, hp)
	final_dmg=TankHero.defend(self,final_dmg,warhead_id,attack_type,source)
	if final_dmg>=hp and special.has("academy_hero"):
		final_dmg=MetaProgress.Academy.survival_damage(self,final_dmg,warhead_id,str(attacker_bonus.get("impact_weapon","")))
	if final_dmg != 0.0 and Ra2Damage.is_rocker(warhead_id):
		if is_instance_valid(source) and source == special.get("parasite") and warhead_id == "YR_SOV_Parasite":
			if final_dmg > 0.0 and hp > final_dmg and TankHero.rank(self,true)<1:
				rock_sideways(-1.0 if randf() < 0.5 else 1.0)
				Effects.spawn_sparks(art_center(), 8, Color.WHITE)
		else:
			_start_rock(damage, source, blast_center, blast_damage)
	if (Ra3Mirage.handles(self) or Ra3Expansion.handles(self)) and final_dmg > 0.0: special.ra3_under_fire = 3.0
	if damage > 0.0 and is_instance_valid(source):
		# Damage and kill credit still use the impact source. Counterfire needs the live launcher.
		var attacker = source.shooter() if source is Projectile else source
		if is_instance_valid(attacker) and (attacker is Unit or attacker is Building) and not BattleRequest.friendly(attacker.side,side) and AlliedAbilities.alive(attacker):
			if final_dmg > 0: preload("res://scripts/world/air_relief.gd").alert(self,attacker)
			var native := preload("res://scripts/core/yr_death_rules.gd").type_data(unit_id)
			if final_dmg > 0 and GameData._ra2_flag(native.get("canretaliate", true)):
				if _return_timer <= 0.0 or not special.has("retaliation_origin"):
					special.retaliation_origin = global_position
				if side == "ally" and (_return_timer <= 0.0 or not is_same(attacker, special.get("retaliation_target"))):
					_think_timer = 0.0
				if BattleRequest.is_ai_house(side) and (_return_timer <= 0.0 or not is_same(attacker,special.get("retaliation_target"))):
					# The shot identifies this contact beyond passive scan range. Repeated
					# hits from the same shooter do not drag the pursuit boundary forward.
					var origin:Vector2 = special.retaliation_origin
					var point:Vector2 = attacker.closest_footprint_point(origin) if attacker is Building and not is_air and not is_naval else attacker.global_position
					special.retaliation_contact_range = origin.distance_to(point)
					_think_timer = 0.0
				_return_timer = maxf(_return_timer, 6.0)
				special.retaliation_target = attacker
	if final_dmg > 0:
		if reporter!=null: FactionCards.record_contact(reporter,self)
		MetaProgress.Academy.hit(self, source)
	if special.has("squid") and final_dmg > 0 and not is_same(source,special.squid):
		SovietSpecials.external_grip_hit(self,final_dmg)
	var shield_before:=TankHero.Shield.amount(self)
	if final_dmg > 0 and BattleRequest.is_ai_house(side) and special.get("brutal_armor", false):
		final_dmg *= 0.9;water_saved *= 0.9
	if water_saved>0:preload("res://scripts/units/water_relay.gd").record(self,water_packet,water_saved)
	if final_dmg > 0 and BattleRequest.brutal_house(side): preload("res://scripts/world/brutal_three.gd").alert(self, source)
	final_dmg=preload("res://scripts/units/leizhu_safety.gd").divert(self,final_dmg,attack_type,attacker_bonus,source)
	var leizhu_shield_input:=final_dmg
	final_dmg=preload("res://scripts/expedition/rules.gd").absorb(self,final_dmg)
	final_dmg=TankHero.Shield.absorb(self,final_dmg)
	var shield_absorbed:=TankHero.Shield.record_hit(self,shield_before,final_dmg,source,warhead_id)
	if shield_absorbed>0:preload("res://scripts/units/progression_expansion.gd").contact(self,source)
	preload("res://scripts/units/auto_w.gd").record_hit(self,final_dmg,source)
	if final_dmg>0 and BattleRequest.combat_context.get("furnace_contract",false):
		MetaProgress.Academy.contract_damage(_battle_world(),self,source,final_dmg)
	final_dmg=preload("res://scripts/units/expansion_heroes.gd").absorb(self,final_dmg)
	final_dmg=preload("res://scripts/units/progression_expansion_2.gd").absorb(self,final_dmg)
	if special.has("boris_radio_shield"):final_dmg=preload("res://scripts/units/boris_radio.gd").absorb(self,final_dmg)
	if special.has("peregrine"):
		preload("res://scripts/units/peregrine_service.gd").damaged(self,source,final_dmg)
		final_dmg=preload("res://scripts/units/peregrine_cards.gd").absorb(self,final_dmg)
		final_dmg=preload("res://scripts/units/peregrine_service.gd").absorb(self,final_dmg)
	if special.has("commando_hero_v2"):final_dmg=preload("res://scripts/units/expansion_2_commandos.gd").absorb(self,final_dmg)
	if special.has("leizhu"):
		final_dmg=preload("res://scripts/units/leizhu_command.gd").absorb(self,final_dmg)
		final_dmg=preload("res://scripts/units/leizhu.gd").absorb(self,final_dmg)
		final_dmg=preload("res://scripts/units/leizhu_defense.gd").absorb(self,final_dmg)
		final_dmg=preload("res://scripts/units/leizhu_safety.gd").absorb(self,final_dmg)
	var leizhu_absorbed:=maxf(0,leizhu_shield_input-final_dmg)
	if attacker_bonus.get("leizhu_primary",false):preload("res://scripts/units/leizhu_command.gd").steal(self,source,attacker_bonus,maxf(0,leizhu_shield_input-final_dmg))
	if special.get("academy_hero")=="TANY":final_dmg=preload("res://scripts/units/tanya_talents.gd").before_damage(self,final_dmg,attack_type,attacker_bonus,source,warhead_id)
	if special.get("academy_hero")=="BORIS":
		final_dmg=preload("res://scripts/units/boris_radio.gd").before_damage(self,final_dmg,attack_type,attacker_bonus)
	preload("res://scripts/units/progression_expansion.gd").damaged(self,source,final_dmg,attacker_bonus)
	if special.has("peregrine"):final_dmg=preload("res://scripts/units/peregrine_service.gd").before_damage(self,final_dmg,attack_type,attacker_bonus,source)
	if special.has("leizhu"):final_dmg=preload("res://scripts/units/leizhu_safety.gd").before_damage(self,final_dmg,attack_type,attacker_bonus)
	var direct_hit: bool = blast_center == Vector2.INF and is_instance_valid(source) and attack_type not in ["erase","crush","execute"] and not attacker_bonus.get("force_execute",false)
	if direct_hit and source is Projectile:direct_hit=is_same(source.target,self)
	if special.has("rally_block") and final_dmg>0 and direct_hit:
		special.erase("rally_block")
		final_dmg=0.0
	if passive.get("id") == "ps_emergency_plate" and final_dmg > 0 and hp - final_dmg <= max_hp * 0.5 and not special.has("plate_cooldown"):
		final_dmg *= 0.80 - 0.05 * _equipped_card_rank("ps_emergency_plate")
		special.plate_cooldown = 25.0
	if final_dmg > 0 and direct_hit:
		final_dmg = PoolCards.divert(self, final_dmg, source)
	if special.has("convoy"):final_dmg=Convoy.absorb(self,final_dmg,source)
	if buff_value("convoy_invulnerable")>0:final_dmg=0
	if final_dmg>0:Convoy.damaged(self,source,final_dmg,attacker_bonus)
	var leizhu_health_before:=hp
	if special.has("convoy_rescue_shield") and buff_value("convoy_rescue")>0:
		var used:=minf(final_dmg,special.convoy_rescue_shield)
		special.convoy_rescue_shield-=used;final_dmg-=used
	if unit_id=="ARND" and special.has("studio"):final_dmg=StudioTalents.absorb(self,final_dmg)
	hp -= final_dmg
	if final_dmg>0 and attacker_bonus.has("studio_target"):StudioTalents.impact(source,self,attacker_bonus)
	if unit_id=="INIT" and final_dmg>0 and hp>0 and embarked_in==null: HollywoodInfantry.suppress(self)
	if unit_id=="YURIKO":preload("res://scripts/units/yuriko_audio.gd").hurt(self,final_dmg,attack_type)
	if final_dmg>0 and leizhu_health_before>max_hp*.2 and hp>0 and hp<=max_hp*.2 and is_instance_valid(source):Convoy.Talents.rescue(self,leizhu_health_before)
	if special.has("leizhu"):preload("res://scripts/units/leizhu_defense.gd").injured(self,source,attack_type,attacker_bonus,leizhu_absorbed,maxf(0,leizhu_health_before-maxf(0,hp)))
	if special.has("commando_hero_v2"):preload("res://scripts/units/expansion_2_commandos.gd").injured(self,source,final_dmg)
	preload("res://scripts/units/expansion_heroes.gd").injured(self)
	preload("res://scripts/units/expansion_talents.gd").injured(self,source,final_dmg+shield_absorbed)
	if tank_finish!=null and final_dmg>0 and attack_type=="shell":tank_finish.shell_hit()
	if yr_finish!=null and unit_id=="GGI" and _deployed and final_dmg>0:yr_finish.mount_hit()
	if unit_id in ["SUB","DLPH"] and hp > 0.0 and final_dmg > 0.0:
		NavalContact.surface(self)
		var world := _battle_world()
		if world != null: visible = world.actor_visible_to("ally", self)
	if warhead_id == "RA3_PRISM" and absf(hp) < 0.000001: hp = 0.0
	if side == "ally":
		Events.emit_radar_ping(global_position, "attack")   # (B3) 雷达受袭闪烁
		if is_ordinary_harvester():
			Ra2Sfx.play_player_eva(_battle_world(), "EVA_OreMinerUnderAttack", 6000)
	var col := Color(1.0, 0.45, 0.35)
	if shield_absorbed>0:
		var shield_world := _battle_world()
		if shield_world != null and shield_world.actor_visible_to("ally",self):
			Effects.spawn_text(Effects.hit_position(self)+Vector2(0,-radius-12),TankHero.Shield.hit_caption(shield_absorbed,final_dmg,side),TankHero.Shield.COLOR if final_dmg<=0 else col)
	if hp <= 0.0:
		hp = 0.0
		var warhead: Dictionary = GameData.ra2_warheads.get(warhead_id.to_lower(), {})
		special.death_kind = int(GameData._num(warhead.get("inf_death"), 1.0))
		special.yr_causes_death_weapon = GameData.warhead_combat_rule(warhead_id).get("causes_death_weapon", false)
		preload("res://scripts/rules/commando_contracts.gd").prepare_death(self,source,attacker_bonus)
		if special.get("academy_hero")=="BORIS":preload("res://scripts/units/boris_radio.gd").health_hit(self,source,final_dmg)
		_die(source)
		special.erase("commando_kill_hit")
		return
	# A fully absorbed hit must not flash the health bar as if HP were lost.
	if shield_absorbed<=0 or final_dmg>0:
		_hp_ghost = maxf(_hp_ghost, prev_frac)
		_hp_flash = 1.0
	if shield_absorbed<=0:
		Effects.spawn_text(Effects.hit_position(self) + Vector2(randf_range(-6, 6), -radius - 12), str(int(final_dmg)), col)
	queue_redraw()

# SelfHealing and elite SELF_HEAL grant the same trait. Keep its partial step in the battle save.
func _tick_hero_self_heal(delta: float) -> void:
	if hp >= max_hp:
		special.erase("hero_heal_elapsed")
		return
	if delta <= 0.0 or hp <= 0.0 or embarked_in != null or AlliedAbilities.frozen(self): return
	var world := _battle_world()
	if world != null and (world.paused or world.ended or get_tree().paused): return
	var elapsed := float(special.get("hero_heal_elapsed",0.0)) + delta
	var steps := floori((elapsed + 0.000001) / _hero_heal_interval)
	special.hero_heal_elapsed = maxf(0.0,elapsed - steps * _hero_heal_interval)
	if steps > 0:
		heal(float(steps))
		if hp >= max_hp: special.erase("hero_heal_elapsed")

func can_receive_healing() -> bool:
	return not special.get("progression_v1", {}).has("succession") and not special.has("hero_wreck") and special.get("expansion_temporary", {}).get("kind") not in ["post", "reserve"]

func heal(amount: float, healer = null, skill_heal:=false) -> void:
	if not can_receive_healing():return
	var previous_hp := hp
	hp = min(max_hp, hp + amount)
	if unit_id=="YURIKO" and previous_hp<max_hp*.9999 and hp>=max_hp*.9999 and is_instance_valid(healer) and healer!=self:Ra2Sfx.play_voice(data,"healed",global_position,5000)
	if skill_heal:preload("res://scripts/rules/expansion_contracts.gd").healed(self,hp-previous_hp)
	if hp>previous_hp and healer is Unit and healer.special.get("academy_hero")=="FV" and AlliedAbilities.is_repair_ifv(healer):Convoy.Cards.work(healer,self,true,{})
	if hp > previous_hp and is_instance_valid(healer) and healer != self and special.has("squid"):
		SovietSpecials.release_squid(self, true)
	preload("res://scripts/ui/healing_indicator.gd").gained(self, previous_hp)
	queue_redraw()

func _tick_gm_target(delta: float) -> void:
	if not is_air:
		if _stun_timer > 0.0:
			_stun_timer=maxf(0,_stun_timer-delta)
			_tick_buffs(delta)
		elif DamageParticles.stage(self) == 0:
			return
		_anim += delta
		queue_redraw()
		return
	if embarked_in != null: return
	# AI/old saves may retain orders; targets only perform their native idle flight.
	attack_target = null; attack_ordered = false; attack_move = false
	has_move_order = false; patrolling = false; fire_stance = "none"
	if AlliedAbilities.frozen(self): return
	_stun_timer = maxf(0.0, _stun_timer - delta)
	if _stun_timer > 0.0: return
	_anim += delta
	flight.altitude(1.0, delta)
	flight.process_combat(delta)
	queue_redraw()

func _die(killer = null, temporal_erasure := false) -> void:
	if unit_id=="SMIN" and not _dead: preload("res://scripts/world/slave_mining.gd").release(self,killer)
	if _dead:
		return
	if preload("res://scripts/units/progression_expansion.gd").before_death(self,killer):return
	if unit_id == "YURIKO":
		for guard in special.get("psi_guards",[]):
			if AlliedAbilities.alive(guard) and guard.special.has("psi_original_side"): preload("res://scripts/units/yuriko.gd").release_guard(guard)
	if special.get("academy_hero")=="BORIS":preload("res://scripts/units/boris_radio.gd").dying(self,temporal_erasure)
	var eliminated:bool=special.get("house_eliminated",false)
	if eliminated:
		temporal_erasure=true
		special.erase("hero_wreck")
		Effects.spawn_impact(global_position,Color(1.0,0.55,0.15),radius*2.2)
	elif TankHero.begin_wreck(self):return
	if special.has("contact_target"): FactionCards.clear_contact(self)
	if special.has("contact_reporters"):
		for owner in special.contact_reporters.duplicate():
			if is_instance_valid(owner) and is_same(owner.special.get("contact_target"),self): FactionCards.clear_contact(owner)
	var world := _battle_world()
	if world != null and world.fog != null: world.fog.hold_unit_sight(self)
	var fall_from := _visual_lift() if not temporal_erasure and flight.crash_speed > 0.0 and embarked_in == null else 0.0
	var hull_crash := false
	if unit_id in ["ZEP", "DISK"] and not temporal_erasure and embarked_in == null:
		hull_crash = preload("res://scripts/units/kirov_crash.gd").begin(self)
	_dead = true
	if shield_sprite != null: shield_sprite.hide()
	if special.has("combo_slot") and world!=null: preload("res://scripts/world/head_games_combine.gd").casualty(world,special.combo_slot)
	if special.has("virus_shooter"):
		preload("res://scripts/units/head_games_weapons.gd").virus_death(self,killer)
	if unit_id=="YURIKO" and not temporal_erasure and is_instance_valid(world):preload("res://scripts/units/yuriko_power_fx.gd").show_fx(world,position,"FX_JapanYurikoDeath")
	if special.has("peregrine"):special.peregrine.erase("rearm_shield")
	if unit_id in ["V3ROCKET","DMISL"]: SovietWeapons.vacate_rack(self)
	SovietSpecials.remove_bomb(self,not temporal_erasure)
	if special.has("squid"): SovietSpecials.host_sinking(self, killer)
	if AlliedAbilities.alive(special.get("parasite")):
		if killer == special.parasite:
			SovietWeapons.release_drone(self)
		else:
			SovietWeapons.cleanse(self)
	preload("res://scripts/ui/unit_selection_outline.gd").clear(self)
	AlliedAbilities.release_control(self)
	AlliedAbilities.release_temporal(self)
	if is_instance_valid(embarked_in):
		global_position = embarked_in.global_position
	embarked_in = null
	logistics.destroyed()
	# 老兵：击杀者按被击杀单位的价值获得经验（RA2 击杀升级）
	if not eliminated or unit_id == "YURIKO":
		preload("res://scripts/world/battle_music_director.gd").death(world, self, killer)
	if not eliminated:
		preload("res://scripts/rules/field_commission.gd").defeated(world, self, killer)
		MetaProgress.Academy.defeated(world, self, killer)
		preload("res://scripts/expedition/rules.gd").defeated(world,self,killer)
	if is_instance_valid(killer) and killer != self and killer.has_method("credit_kill") and not AlliedAbilities.flag(self,"DontScore"):
		killer.credit_kill(_vet_value if _vet_value > 0.0 else maxf(1.0, float(data.get("cost", 100))), side)
	# 语音：CrushSound（被碾压）或 DieSound（rules.ini → voice.die / voice.crush）
	var vkind := "crush" if _crush_death else "die"
	if unit_id=="YURIKO":
		preload("res://scripts/units/yuriko_audio.gd").sync(self)
		vkind=special.get("psi_death_voice",vkind)
	if not temporal_erasure and Ra2Sfx.has_voice(data, vkind):
		Ra2Sfx.play_voice(data, vkind, global_position, 260)
	if not temporal_erasure and not hull_crash:
		preload("res://scripts/core/yr_death_combat.gd").destroyed(self)
		if unit_id == Ra3Expansion.HARBINGER and _visual_lift() > 0.01: preload("res://scripts/units/ra3_gunship_crash.gd").begin(self)
		else: Ra3Wreck.spawn(self)
		if unit_id == Ra3Expansion.HARBINGER:
			preload("res://scripts/units/ra3_crash_fx.gd").spawn(_battle_world(),global_position+RA2Art.art_dir(Vector2(0,-_visual_lift()*sqrt(0.75))))
		elif not AlliedAbilities.infantry(self) and not preload("res://scripts/core/yr_death_fx.gd").destroyed(self):
			Effects.spawn_impact(global_position, _col, radius * 2.2)
	var source_flags: Dictionary = GameData.ra2_source_units.get(unit_id, {}).get("extra", {})
	if side == "ally" and unit_id != "HORNET" and not is_harvester and not special.has(Furnace.GUARD) and str(source_flags.get("MissileSpawn", "")).to_lower() != "yes":
		Ra2Sfx.play_player_eva(_battle_world(), "EVA_UnitLost", 2000)
	Events.unit_died.emit(self)
	if cargo > 0.0:
		cargo = 0.0
	cargo_gems = 0.0
	remove_from_group("combatants")
	remove_from_group("ground_units")
	remove_from_group("air_units")
	remove_from_group("allies")
	remove_from_group("enemies")
	remove_from_group("ally_targets")
	remove_from_group("enemy_targets")
	velocity = Vector2.ZERO
	# Complete source sequence from frame zero; death never loops or collides.
	collision_layer = 0
	collision_mask = 0
	if yuriko_model != null and not temporal_erasure:
		yuriko_model.sync_actor(self,0)
		_dying = yuriko_model.duration(yuriko_model.action)
		set_physics_process(true)
		queue_redraw()
		return
	if flight.begin_air_death(fall_from):
		set_physics_process(true)
		queue_redraw()
		return
	var death_kind := int(special.get("death_kind", 1))
	var effect := preload("res://scripts/core/yr_death_rules.gd").infantry_effect(death_kind)
	if not temporal_erasure and AlliedAbilities.infantry(self) and not effect.is_empty():
		if preload("res://scripts/core/yr_death_fx.gd").play(_battle_world(), global_position, effect) != null:
			queue_free()
			return
	if not temporal_erasure and _seq.has("Die1"):
		var sequence := "Die2" if death_kind == 2 and _seq.has("Die2") else "Die1"
		if _swimming() and _seq.has("Wet" + sequence): sequence = "Wet" + sequence
		special.death_sequence = sequence
		_anim = 0.0
		_dying = maxf(1.0, float(_seq[sequence].per)) / 13.0
		# Death animation continues through the registered simulation component.
		set_physics_process(true)
		queue_redraw()
	else:
		queue_free()

# ------------------------------------------------------------------ 指令

func order_move(p: Vector2, p_attack_move: bool = false, p_field = null, p_path: PackedVector2Array = PackedVector2Array(), report_deployment := true) -> void:
	_yr_blockage.clear()
	if unit_id == "DNOA": special.erase("rexy_guard_origin")
	if special.has("psi_elapsed"): HollywoodInfantry.start_folding(self)
	if special.has("leizhu") and preload("res://scripts/units/leizhu_safety.gd").stopped(self):return
	if special.has("peregrine"):
		if special.has("hero_wreck"):return
		preload("res://scripts/units/peregrine_service.gd").leave(self)
	preload("res://scripts/units/expansion_2_drone.gd").cancel_leap(self)
	special.erase(preload("res://scripts/units/ai_engagement.gd").RESUME)
	preload("res://scripts/units/ai_wall_clearance.gd").cancel(self)
	special.erase("ai_counterfire_resume")
	special.erase("ai_formation_batch")
	if special.has("ai_dispatch_pending"):
		var world := _battle_world()
		if world is Battle: world.ai_dispatch.cancel_order(world,self)
	special.erase("ai_route_goal")
	_blocked_move_goal = Vector2.INF
	special.erase(ReverseAttack.ID)
	YRTalents.end_reverse(self)
	special.erase("formation_heading")
	special.erase("mcv_deploy_at")
	if AlliedAbilities.frozen(self) and not (special.has("leizhu") and preload("res://scripts/units/leizhu_insulation.gd").mobile(self)): return
	if AlliedAbilities.infantry_teleporter(self) and not p_attack_move and embarked_in == null:
		if not AlliedAbilities.teleport(self, p) and side == "ally": Events.emit_message("传送落点被占用或不适合步兵", Color(1, 0.7, 0.4))
		return
	AlliedAbilities.cancel(self)
	if _reject_powered_command():
		return
	_harvest_exit = Vector2.INF
	_local_traffic.reset()
	_chase_goal = Vector2.INF
	_chase_repath_left = 0.0
	_drive_turning = false
	special.erase(VehicleSteering.REVERSAL)
	if NavalContact.grip_host(self)!=null:SovietSpecials.release_squid(embarked_in)
	if embarked_in != null:
		return
	logistics.stop_command(true)
	if _deployed:
		if not report_deployment: return
		var stance_hint := "火炮已部署，按 E 收炮后可移动" if unit_id == "SCHP" else "已部署导弹，需先收起" if unit_id == "GGI" else "已卧倒据守，需先起身"
		Events.emit_message("%s %s（再次点击自身 / 命令栏部署 J）" % [display_name, stance_hint], Color(1.0, 0.85, 0.6))
		# 语音：VoiceFeedback（RA2 对无法执行的命令播"无法服从"）
		if Ra2Sfx.has_voice(data, "feedback"):
			Ra2Sfx.play_voice(data, "feedback", global_position, 400)
		return
	if repairing:
		_end_repair(false)
	if unit_id == "R3REAPER":
		ReaperSplit.clear(self)
		if not p_attack_move:special.erase("reaper_focus")
	if FoundationTransit.enabled(self):
		var transit_world:=_navigation_world()
		if transit_world!=null and transit_world.path_service!=null:
			var safe:=FoundationTransit.destination(self,transit_world,p)
			if safe!=p:
				p=safe;p_path=PackedVector2Array();p_field=null
	move_target = p
	_suspend_harvest()
	has_move_order = true
	attack_move = p_attack_move
	attack_ordered = false
	attack_target = null
	_cancel_burst()
	if is_air:
		p_field = null
	path_field = p_field
	# 未显式给路径时自动按 ZoneMap+A* 求一次（集合点/巡逻/队列入队都走同一套）
	if preload("res://scripts/world/construction_transition.gd").active(self):
		p_path = PackedVector2Array()
		path_field = null
	elif p_path.is_empty() and p_field == null:
		if ai_path_allowed(): p_path = _path_for(p)
		else: special.ai_route_goal = p
	if p_path.size() >= 2:
		set_agent_path(p_path)
	else:
		_path_pts = PackedVector2Array()
		_path_i = 0
		_nav_stuck_t = 0.0
		_nav_stuck_best = INF
		_nav_stuck_waypoint = Vector2.INF
		_dodge_t = 0.0
	if not is_harvester: harvest_state = "to_node"
	preload("res://scripts/units/ai_wall_clearance.gd").remember(self,p)
	_claim_release()      # (M6) 手动改道：放弃矿点认领与已冻结泊位
	_unlock_dock()

## (A4) 派往维修厂：RA2 维修厂（GADEPT）语义——受损载具开上停机位，由维修厂按 RepairStep 回血，满血自动驶离。
func can_repair_at(depot) -> bool:
	if special.has("hero_wreck"):return false
	return not _dead and hp > 0.0 and hp < max_hp and not is_queued_for_deletion() \
		and not is_air and str(data.get("role", "")) != "infantry" \
		and embarked_in == null and _stun_timer <= 0.0 and not AlliedAbilities.frozen(self) \
		and powered_unit.reason(self).is_empty() and is_instance_valid(depot) \
		and depot.has_method("is_repair_depot") and depot.is_repair_depot() and is_naval == bool(depot.data.get("water_bound", false)) \
		and depot.side == side and depot.is_operational()

func order_repair(depot) -> bool:
	if not can_repair_at(depot):
		return false
	if _reject_powered_command():
		return false
	var entry: Vector2 = preload("res://scripts/buildings/repair_access.gd").nearest(self, depot)
	if not entry.is_finite(): return false
	# Reuse ordinary command replacement: clear old A*, boarding, skills and stance.
	cancel_stance()
	order_queue.clear()
	order_move(entry)
	repair_depot = depot
	repairing = true
	# 中断并清空其它指令
	attack_target = null
	attack_ordered = false
	hold_position = false
	patrolling = false
	order_queue.clear()
	if is_harvester:
		harvest_state = ""
		resource_node = null
		_claim_release()      # (M6)
		_unlock_dock()
	add_to_group("repair_docked")
	RepairDock.invalidate(depot.battle)
	special.repair_entry = entry
	set_meta("repair_access_epoch", depot.battle.path_service.epoch)
	special.repair_stage = "inside" if global_position.distance_to(RepairDock.pad(depot)) <= 6.0 else "approach"
	if special.get("repair_exit_depot") == depot:
		special.erase("repair_exit_depot")
		special.erase("repair_exit_point")
	_repair_dock = RepairDock.pad(depot)
	has_move_order = true
	attack_move = false
	return true

## (A4) 维修状态每物理帧：开到停机位→停车待修；满血→自动驶离。
func _process_repair(delta: float) -> void:
	if repair_depot == null or not is_instance_valid(repair_depot) \
			or repair_depot.is_dead() or repair_depot.under_construction or repair_depot.side != side:
		_end_repair(false)
		return
	if hp >= max_hp:
		_end_repair(true)
		return
	if not repair_depot.is_operational():
		velocity = Vector2.ZERO
		return
	RepairDock.tick(self, delta)

## (A4) 结束维修。eject=true 时驶离停机位，让位给下一辆。
func _end_repair(eject: bool = true) -> void:
	var was: bool = repairing
	repairing = false
	remove_from_group("repair_docked")
	var dep = repair_depot
	RepairDock.leave(self, dep)
	repair_depot = null
	has_move_order = false
	velocity = Vector2.ZERO
	_clear_field()
	if eject and was and is_instance_valid(dep):
		var exit_point: Vector2 = special.get("repair_exit_point", dep.dock_point(global_position))
		var direction: Vector2 = dep.position.direction_to(exit_point)
		# Continue beyond the doorway, on the opposite side of the waiting lane.
		var away := exit_point + direction * (radius * 3.0 + 64.0) - direction.orthogonal() * (radius * 2.0 + 20.0)
		order_move(away, false, null)

## 追加路径点（Shift 队列指令）。没有当前移动指令时，直接作为首个指令。
func queue_waypoint(p: Vector2, p_field = null, p_attack_move := false) -> void:
	if _reject_powered_command():
		return
	if not has_move_order and not attack_ordered and order_queue.is_empty():
		order_move(p, p_attack_move, p_field if p_field != null else _field_for(p))
		return
	if unit_id == "R3REAPER": ReaperSplit.clear(self)
	order_queue.append({"position": p, "attack_move": true} if p_attack_move else p)

func clear_queue() -> void:
	order_queue.clear()

func order_stop(reset_fire_stance := true) -> void:
	_yr_blockage.clear()
	if unit_id == "DNOA": special.erase("rexy_guard_origin")
	if special.has("psi_order"): special.erase("psi_order")
	if special.has(FoundationTransit.ANCHOR):FoundationTransit.settle(self)
	preload("res://scripts/units/expansion_2_drone.gd").cancel_leap(self)
	special.erase(preload("res://scripts/units/ai_engagement.gd").RESUME)
	preload("res://scripts/units/ai_wall_clearance.gd").cancel(self)
	special.erase("ai_counterfire_resume")
	if special.has("ai_dispatch_pending"):
		var world := _battle_world()
		if world is Battle: world.ai_dispatch.cancel_order(world,self)
	special.erase("ai_route_goal")
	_blocked_move_goal = Vector2.INF
	special.erase(ReverseAttack.ID)
	YRTalents.end_reverse(self)
	if NavalContact.grip_host(self)!=null:SovietSpecials.release_squid(embarked_in)
	special.erase("reaper_focus")
	if unit_id == "R3REAPER": ReaperSplit.clear(self)
	special.erase("formation_heading")
	special.erase("mcv_deploy_at")
	special.erase("rolling_crush")
	special.erase(VehicleSteering.REVERSAL)
	if reset_fire_stance and side == "ally": fire_stance = "defend"
	special.erase("retaliation_target")
	special.erase("retaliation_origin")
	special.erase("retaliation_contact_range")
	_chase_goal = Vector2.INF
	_return_timer = 0.0
	AlliedAbilities.cancel(self)
	_cancel_burst()
	_suspend_harvest()
	_local_traffic.reset()
	logistics.stop_command()
	if repairing:
		_end_repair(false)
	has_move_order = false
	attack_move = false
	attack_target = null
	attack_ordered = false
	patrolling = false
	hold_position = false
	patrol_points = []
	order_queue.clear()
	if unit_id!="R3HARBINGER":velocity = Vector2.ZERO
	else:
		# Stop cancels the mission; a fixed-wing gunship keeps flying locally.
		special.erase("ra3_flight_center")
		special.erase("ra3_flight_mode")

## 警戒：原地固守，只打射程内的目标
func order_guard() -> void:
	if unit_id == "DNOA": special.erase("rexy_guard_origin")
	if special.has(FoundationTransit.ANCHOR):FoundationTransit.settle(self)
	special.erase(preload("res://scripts/units/ai_engagement.gd").RESUME)
	special.erase(ReverseAttack.ID)
	if NavalContact.grip_host(self)!=null:SovietSpecials.release_squid(embarked_in)
	special.erase("reaper_focus")
	if unit_id == "R3REAPER": ReaperSplit.clear(self)
	special.erase("formation_heading")
	special.erase("mcv_deploy_at")
	fire_stance = "free"
	_cancel_burst()
	attack_target = null
	AlliedAbilities.cancel(self)
	_suspend_harvest()
	_local_traffic.reset()
	logistics.stop_command()
	if repairing:
		_end_repair(false)
	hold_position = true
	patrolling = false
	patrol_points = []
	has_move_order = false
	attack_move = false
	attack_ordered = false
	order_queue.clear()
	velocity = Vector2.ZERO

## 巡逻：在「当前位置」与 p 之间往返
func order_patrol(p: Vector2) -> void:
	if _reject_powered_command():
		return
	order_queue.clear()
	patrol_points = [global_position, p]
	patrol_index = 1
	patrolling = true
	hold_position = false
	order_move(p, true, _field_for(p))

## 玩家下达新指令时清除姿态
func cancel_stance() -> void:
	patrolling = false
	hold_position = false
	patrol_points = []

func order_return_to_refinery(refinery) -> bool:
	if not is_harvester or embarked_in != null or _dead or AlliedAbilities.frozen(self) or _stun_timer > 0.0:
		return false
	if not is_instance_valid(refinery) or refinery.side != side or not refinery.is_refinery() or not refinery.is_operational():
		return false
	if home_base == refinery and ((_dock_locked and harvest_state in ["to_base", "unloading"]) or _harvest_exit.is_finite()):
		return true
	if not EconomyCycle.refinery_accessible(self, refinery): return false
	order_stop(false)
	if special.get("academy_hero")=="HARV":special.convoy_delivery=true
	home_base = refinery
	_home_tick = 1.5
	harvest_state = "to_base"
	_stuck_reset()
	_lock_dock()
	return true

## 采集：指派一个矿点（采集车用）
func order_harvest(node) -> void:
	special.erase("formation_heading")
	if not is_harvester or node == null:
		return
	if special.has("convoy"):
		special.erase("convoy_press_order")
		special.convoy.erase("press")
	resource_node = node
	auto_harvest_idle = 0.0
	cancel_stance()
	_harvest_exit = Vector2.INF
	harvest_state = "to_node"
	has_move_order = false
	attack_ordered = false
	order_queue.clear()
	_unlock_dock()
	_clear_field()
	_stuck_reset()
	_claim_ore(node)

# --- 开火姿态 ---
func set_fire_stance(s: String) -> void:
	if unit_id == "DNOA": special.erase("rexy_guard_origin")
	special.erase("finished_attack_route")
	fire_stance = s
	if s == "none":
		attack_target = null
		attack_ordered = false
		_cancel_burst()

func cycle_fire_stance() -> void:
	match fire_stance:
		"defend":
			set_fire_stance("free")
		"free":
			set_fire_stance("return")
		"return":
			set_fire_stance("none")
		_:
			set_fire_stance("defend")

func fire_stance_label() -> String:
	match fire_stance:
		"defend":
			return "自动防卫"
		"free":
			return "自由开火"
		"return":
			return "仅反击"
		"none":
			return "停火"
	return fire_stance

func set_selected(v: bool) -> void:
	if selected == v: return
	selected = v
	if not v:
		group_idle_redraw = false
		preload("res://scripts/ui/unit_selection_outline.gd").clear(self)
	queue_redraw()

func set_hovered(v: bool) -> void:
	if hovered == v:
		return
	hovered = v
	queue_redraw()

func stance_label() -> String:
	var disabled := power_disabled_reason()
	if not disabled.is_empty():
		return disabled
	var supply_status: String = logistics.status()
	if supply_status != "":
		return supply_status
	if _deployed:
		if unit_id == "SCHP": return "火炮部署"
		return "部署导弹" if unit_id == "GGI" else "卧倒据守"
	if patrolling:
		return "巡逻"
	if hold_position:
		return "警戒"
	if attack_move:
		return "攻击移动"
	if has_move_order:
		return "移动中"
	return "待命"

## 向 Battle 索取目标点的流场（引擎侧做缓存）
func _field_for(p: Vector2):
	if is_air or is_amphibious:
		return null
	var par := _navigation_world()
	if par != null and par.has_method("field_for_pos"):
		return par.field_for_pos(p, is_naval)
	return null

# ==================================================================
#  绘制 —— 程序化建模（多边形 + 明暗分层 + 面板缝线 + 涂装 + 动画）
# ==================================================================

func presentation_position() -> Vector2:
	return motion_pose.point(self, motion_pose.fraction(self))

func _draw() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(6)
	if _body_visibility != null and not _body_visibility.is_on_screen() and not selected and not hovered and (not is_air or (Iso.K >= 0.35 and _visual_lift() <= _air_cull_lift)):
		# Also handle the first frame after spawn, camera pan or fog reveal,
		# before the renderer sends screen_entered.
		if not get_viewport_rect().intersects(get_global_transform_with_canvas() * _body_visibility.rect):
			# These markers may still be visible far from their owner.
			if not special.has("controlled") and not special.has("airstrike_mark") and not special.has("buoy_left") and not special.has("echo_left") and not special.has("para_height"):
				return
	# Drawing runs synchronously on the main thread. Only the render call sees
	# interpolated bearings; restore the authoritative angles before returning.
	var logical_hull := hull_angle
	var logical_turret := turret_angle
	var blend := motion_pose.fraction(self)
	hull_angle = motion_pose.hull(self, blend)
	turret_angle = motion_pose.turret(self, blend)
	_draw_pose()
	hull_angle = logical_hull
	turret_angle = logical_turret

func _draw_pose() -> void:
	if special.has("leizhu_electrode"):
		preload("res://scripts/units/leizhu_cards.gd").draw_electrode(self)
		return
	if special.has("tanya_breach_charge"):
		preload("res://scripts/units/tanya_breach.gd").draw(self)
		return
	preload("res://scripts/world/battle_call_counters.gd").iterations(6,1)
	_body_bounds = Rect2()
	_drew_moving_pose = velocity.length_squared() > 16.0
	if preload("res://scripts/units/bomb_nest_visual.gd").handles(self):
		preload("res://scripts/units/bomb_nest_visual.gd").draw(self)
		return
	RA2Art.begin_detail_draw(self)
	Iso.begin(self)
	if special.has("psi_burst_push"):
		var push:Dictionary=special.psi_burst_push
		draw_set_transform_matrix(body_draw_transform().translated_local(Vector2.UP*float(push.height)*sin(PI*float(push.age)/.45)))
	elif special.has("psi_crush") and not special.has("psi_holder") and not special.has("psi_flight"):
		draw_set_transform_matrix(body_draw_transform().translated_local(Vector2.UP*float(special.psi_crush.height)))
	if special.has("psi_holder") or special.has("psi_flight"):
		var lift:=preload("res://scripts/units/yuriko.gd").lift_height(self)
		draw_set_transform_matrix(Transform2D(Iso.eff_angle(),Vector2(1,Iso.inv_k()),0,Vector2.ZERO).translated_local(Vector2.UP*lift))
	var r := radius
	_draw_buffs(r)
	_harvest_fx.draw_on(self, true)
	if tank_finish!=null:tank_finish.draw_on(self,true)
	if _rock_t > 0.0: draw_set_transform_matrix(body_draw_transform())
	if peregrine_fx!=null:peregrine_fx.draw_under(self)
	preload("res://scripts/ui/unit_selection_outline.gd").begin(self)
	if special.has("mcv_repack_left") and preload("res://scripts/world/construction_transition.gd").draw_repack(self):
		pass
	elif unit_id == "YURIKO":
		preload("res://scripts/units/yuriko.gd").draw(self)
	elif _ra3_model != null:
		_ra3_model.draw_on()
		_body_bounds = _ra3_model.projected_body_bounds()
	elif (special.has("disguise") or unit_id == "MGTK" or unit_id == Ra3Mirage.ID) and AlliedAbilities.draw_disguise(self):
		pass
	elif night_skin!=null and not _dead and _dying<=0:
		night_skin.draw_on(self)
	elif hero_art!=null and not _dead and _dying<=0:
		hero_art.draw_on(self)
	elif not _ra2.is_empty():
		_draw_ra2_sprite(r)
	else:
		_draw_procedural_body(r)
	preload("res://scripts/ui/unit_selection_outline.gd").end(self)
	if peregrine_fx!=null:peregrine_fx.draw_over(self)
	if not _dead and special.has("para_height"): preload("res://scripts/world/american_paradrop.gd").draw_chute(self)
	if _rock_t > 0.0: Iso.begin(self)
	_harvest_fx.draw_on(self, false)
	if tank_finish!=null:tank_finish.draw_on(self,false)
	if yr_finish!=null:yr_finish.draw_on(self)
	AlliedAbilities.draw_status(self)
	preload("res://scripts/units/expansion_visual.gd").draw(self)
	if special.has("peregrine"):preload("res://scripts/units/peregrine_cards.gd").draw(self)
	if special.has("leizhu"):preload("res://scripts/units/leizhu.gd").draw(self)
	elif special.has("leizhu_control"):preload("res://scripts/units/leizhu_command.gd").draw(self)
	if special.has("progression_v2"):preload("res://scripts/units/progression_expansion_2.gd").draw(self)
	if _stun_timer>0 and has_buff("tesla_emp"):
		_draw_emp_arcs()
	if unit_id == Ra3Mirage.ID: Ra3Mirage.draw_field(self)
	if not _dead and special.has("contact_reporters"): FactionCards.draw_contact(self)
	if special.has("plate_flash") or special.has("echo_left") or special.has("buoy_left"): FactionCards.draw(self)
	if special.has(DomainCards.STATE):DomainCards.draw(self)

	# 低血冒烟
	if _has_damage_particles:
		DamageParticles.draw(self)
	elif not is_naval and hp < max_hp * 0.42 and not _dead and not ((Ra3Expansion.handles(self) or Ra3Mirage.handles(self) or unit_id in ["R3TESLA","R3APOC"]) and _ra3_model!=null):
		_draw_smoke(r, hp / maxf(1.0, max_hp))

	if is_harvester and cargo_cap > 0.0 and not (special.get("academy_hero","")=="HARV" and has_method("cosmetic_preview_travel")):
		var fcov: float = clampf(cargo / maxf(1.0, cargo_cap), 0.0, 1.0)
		var bw: float = r * 1.8
		var by: float = -r * 2.2
		if unit_id=="HARV" and side=="ally" and cosmetic_outfit().get("skin")=="night_shift" and _body_bounds.has_area():
			by=minf(by,_body_bounds.position.y-9.0)
		draw_rect(Rect2(-bw * 0.5, by, bw, 5.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-bw * 0.5 + 1.0, by + 1.0, (bw - 2.0) * fcov, 3.0), Color(1.0, 0.6, 0.22))

	var contact := bridge_contact_offset()
	if contact != Vector2.ZERO:
		draw_set_transform(contact, Iso.eff_angle(), Iso.up())
	_draw_selection(r)
	if excluded_from_army_selection and side == "ally" and not _dead and embarked_in == null:
		var foot := _ground_center(r) + Vector2(0, r * 0.7 + 7.0)
		draw_circle(foot, 6.0, Color("21232b"))
		draw_arc(foot, 5.0, 0, TAU, 20, Color("ffcc67"), 1.8, true)
		draw_line(foot - Vector2(2.8, 0), foot + Vector2(2.8, 0), Color("ffcc67"), 2.0)

	_draw_reverse_tag(r)
	if contact != Vector2.ZERO: Iso.begin(self)

## Shared local drawing rectangle for the world bar and its attached indicators.
func hp_bar_rect() -> Rect2:
	if yuriko_model!=null:
		var head:Vector2=yuriko_model.head_offset()
		return Rect2(head.x-12.0,head.y-21.0,24.0,5.0)
	var width := maxf(22.0, radius * 2.2)
	var anchor: Vector2
	if _body_bounds.has_area():
		anchor = Vector2(_body_bounds.get_center().x, _body_bounds.position.y - 10.0)
	else:
		anchor = Vector2(0.0, -radius * 2.7 - _visual_lift())
	return Rect2(anchor - Vector2(width * 0.5, 0.0), Vector2(width, 5.0))

func draw_body_sprite(art: Dictionary, target: Rect2, source: Rect2, tint := Color.WHITE, waterline := INF) -> void:
	RA2Art.draw_sprite(self, art, target, source, tint,waterline)
	var bounds := RA2Art.visible_sprite_rect(art, target, source)
	if not bounds.has_area(): return
	if uses_missile_pitch():
		bounds = SovietWeapons.DreadFlight.pose(self, _visual_lift()) * bounds
	elif _rock_t > 0.0:
		bounds = rocking_pose() * bounds
	_body_bounds = _body_bounds.merge(bounds) if _body_bounds.has_area() else bounds

## 血条改由 battle.hp_overlay 在高层级（DepthLayers.WORLD_HUD）统一绘制，
## 恒盖在所有实体（含建筑）之上。
## origin 为 begin 空间坐标（调用方传 Iso.dir(世界坐标)），ci 为其所属 CanvasItem。
func shield_readout_amount() -> float:
	return preload("res://scripts/ui/shield_readout.gd").amount(self)

func draw_hp_bar(ci: CanvasItem, origin: Vector2, show_values := false) -> void:
	var shield := shield_readout_amount()
	preload("res://scripts/units/unit_shield_visual.gd").sync(self, shield)
	if not (show_values or hp < max_hp or selected or _hp_flash > 0.0 or shield>0):
		return
	var rect := hp_bar_rect()
	rect.position += origin
	var pct: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	HpBar.draw_bar(ci, rect, pct, HpBar.world_fill(side, pct), 0, _hp_ghost, _hp_flash, 0.0, HpBar.rim_for(side))
	TankHero.Shield.draw_bar(self,ci,rect)
	preload("res://scripts/units/water_relay.gd").draw_bar(self,ci,rect)
	if show_values: HpBar.draw_readout(ci,rect,side,hp,max_hp,shield)

# -------------------------------------------------- RA2 原图（SHP/VXL）

const FactionCards = preload("res://scripts/units/faction_cards.gd")
const CommandoFx = preload("res://scripts/units/commando_shot_fx.gd")
const CommandoSkin = preload("res://scripts/units/commando_skin.gd")
const HeroArmor = preload("res://scripts/units/hero_armor.gd")
const RA2_SPRITE_SCALE := 1.0

# ---- 形态切换（RA2「美国大兵」式：部署/卧倒）----
var _deployed: bool = false:
	set(value):
		_deployed=value
		if value and not is_in_group(&"deployed_route_blockers"): add_to_group(&"deployed_route_blockers")
		elif not value and is_in_group(&"deployed_route_blockers"): remove_from_group(&"deployed_route_blockers")

# ---- 第 8 批：受击摇晃（[Warhead] Rocker=yes；RA2 Vehicle.applyRocking）----
var _rock_t: float = 0.0
var _rock_amp: float = 0.0
var _rock_dir: Vector2 = Vector2.RIGHT
var rock_events: int = 0


## 第 8 批：RA2 的 Prone 状态 = 本工程的「部署据守」（弹头 ProneDamage= 据此生效）
func is_prone() -> bool:
	return special.has("prone_left") or special.has(Furnace.STANCE) or (_deployed and data.get("deployed_prone", true) == true)


func uses_missile_pitch() -> bool:
	return unit_id == "DMISL" or (unit_id == "V3ROCKET" and special.get("flight", {}).has("phase"))

func rocking_pose() -> Transform2D:
	if _rock_t <= 0.0 or _rock_amp <= 0.0: return Transform2D.IDENTITY
	var progress := 1.0 - _rock_t / (Ra2Damage.rocking_seconds() * _rock_amp)
	return Ra2Damage.rocking_xform(_rock_dir, Ra2Damage.rocking_tilt(progress, _rock_amp), radius)

func body_draw_transform() -> Transform2D:
	return Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO) * rocking_pose()

## A parasite inside the hull rolls the vehicle sideways at full strength.
func rock_sideways(side_sign: float) -> void:
	_rock_dir = Vector2.from_angle(hull_angle).orthogonal() * side_sign
	_rock_amp = 1.0
	_rock_t = Ra2Damage.rocking_seconds()
	rock_events += 1
	queue_redraw()

func _start_rock(dmg: float, source, blast_center: Vector2, blast_damage: float) -> void:
	if is_air or AlliedAbilities.infantry(self) or embarked_in != null or _rock_t > 0.0:
		return
	var direction := Vector2.ZERO
	if source is Projectile:
		direction = global_position - source.target_point
		if direction.is_zero_approx(): direction = source._heading
		blast_damage = source.base_damage
	elif blast_center.is_finite():
		direction = global_position - blast_center
	if direction.is_zero_approx() and is_instance_valid(source) and source is Node2D:
		direction = global_position - source.global_position
	if direction.is_zero_approx(): direction = Vector2.from_angle(hull_angle)
	var weight := float(data.get("move", {}).get("weight", 0.0))
	_rock_amp = Ra2Damage.rocking_intensity(blast_damage if blast_damage >= 0.0 else dmg) * clampf(1.0 - weight / 5.0, 0.0, 1.0)
	if _rock_amp <= 0.0: return
	_rock_dir = direction.normalized()
	_rock_t = Ra2Damage.rocking_seconds() * _rock_amp
	rock_events += 1
	queue_redraw()


func _rock_update(delta: float) -> void:
	if _rock_t <= 0.0:
		return
	_rock_t = maxf(0.0, _rock_t - delta)
	if _rock_t <= 0.0:
		_rock_amp = 0.0
	queue_redraw()
var _deploy_frame: int = -1     # SHP 部署姿态首帧（按朝向 +index）；-1 = 不支持
var _deploy_atk: float = 1.5    # 部署时攻击倍率
var _deploy_def: float = 1.0    # 部署时防御倍率

func _moving() -> bool:
	return velocity.length() > 8.0

## (M6) 倒车入库标识：车尾两盏琥珀倒车灯 + 「倒车」小字。
## 只在一段倒车入库（_back_in）时出现，可直接在有头截图里验证「矿车倒车入库」。
func _draw_reverse_tag(r: float) -> void:
	if not _back_in or _dead:
		return
	var fwd: Vector2 = Iso.dir(Vector2.RIGHT.rotated(hull_angle))
	var back: Vector2 = -fwd
	var side_v := Vector2(-back.y, back.x)
	var lamp := Color(1.0, 0.74, 0.28, 0.95)
	for sgn in [-1.0, 1.0]:
		draw_circle(back * (r * 1.1) + side_v * (r * 0.5 * sgn), 3.0, lamp)


## Step C 阶段2：用 RA2 原图替换程序化建模。底边中点对齐脚下原点。
## (D-2) 步兵行进/开火/阵亡 用 art.ini 帧序；(D-4) 载具有独立炮塔 sheet 时按 turret_angle 叠加。
var _anchor_span_key := Vector4i(-1, -1, -1, -1)
var _anchor_span_frames: Array = []

func _anchor_frames(start: int, count: int, extra_start: int = 0, extra_count: int = 0) -> Array:
	var key := Vector4i(start, count, extra_start, extra_count)
	if key != _anchor_span_key:
		_anchor_span_frames = range(start, start + count)
		if extra_count > 0: _anchor_span_frames.append_array(range(extra_start, extra_start + extra_count))
		_anchor_span_frames.make_read_only()
		_anchor_span_key = key
	return _anchor_span_frames

const VoxelRenderer = preload("res://scripts/units/voxel_renderer.gd")
const HollywoodTurrets = preload("res://scripts/units/hollywood_turret_pose.gd")

func draw_prepared_voxel(prepared, rect: Rect2, frame: int, grade: Color) -> void:
	VoxelRenderer.submit(self,prepared,rect,frame,grade)

func _draw_ra2_sprite(r: float) -> void:
	if _voxel_hull != null and VoxelRenderer.draw(self,r): return
	_draw_ra2_sprite_uncached(r)

func _draw_ra2_sprite_uncached(r: float) -> void:
	var tex: Texture2D = _ra2.get("tex")
	if tex == null:
		return
	var sz: Vector2 = RA2Art.frame_size(_ra2)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var kind := str(_ra2.get("kind", "vxl"))
	var rects: Array = _ra2.get("rects", [])
	var facings := RA2Art.INFANTRY_FACINGS if kind == "shp" else int(_ra2.get("facings", 8))
	var fidx := _sprite_facing(_ra2, hull_angle) if kind == "vxl" or unit_id in ["DLPH","SQD"] else RA2Art.facing_index(hull_angle, facings)
	var frame := fidx
	var anchor_start := 0
	var anchor_count := facings
	var extra_start := 0
	var extra_count := 0
	if _seq.has("Guard"):
		frame = RA2Art.seq_frame(_seq, "Guard", fidx, 0)
		var guard: Dictionary = _seq.Guard
		anchor_start = int(guard.start)
		anchor_count = int(guard.per) * int(guard.facings)
	if kind == "vxl" and int(_ra2.get("poses", 1)) > 1:
		var poses := int(_ra2.poses)
		anchor_start = 0
		anchor_count = facings * poses
		if logistics.air_lift > 0.1:
			var pose: int = _siege_rotor.phase(_ra2) if _siege_rotor != null else posmod(int(_anim * float(_ra2.get("fps", 20.0))), poses)
			frame += pose * facings
	elif _dying <= 0.0 and unit_id == "DESO" and _deployed:
		# DesoSequence has one shared deployed pose, independent of facing.
		frame = RA2Art.seq_frame(_seq, _fire_sequence(), fidx, int(_fire_anim_time * 16.0)) if _fire_anim_time >= 0 else _deploy_frame
		anchor_start = _deploy_frame
		anchor_count = 1
	elif unit_id=="GGI" and yr_finish!=null and _dying<=0.0 and yr_finish.fold>0 and yr_finish.fold<1 and _fire_anim_time<0:
		var transition:="Down" if _deployed else "Up"
		var fraction:float=yr_finish.fold if _deployed else 1.0-yr_finish.fold
		frame=RA2Art.seq_frame(_seq,transition,fidx,mini(1,int(fraction*2)))
	elif _dying <= 0.0 and _deployed and _deploy_frame >= 0 and kind == "shp" and _deploy_frame + facings <= rects.size():
		frame = _deploy_frame + fidx
		anchor_start = _deploy_frame
		anchor_count = facings
		if _seq.has("DeployedFire"):
			var firing: Dictionary = _seq.DeployedFire
			# One shared anchor prevents the body jumping between idle and gunfire.
			extra_start = int(firing.start)
			extra_count = int(firing.per) * facings
			if _fire_anim_time >= 0.0:
				frame = RA2Art.seq_frame(_seq, "DeployedFire", fidx, int(_fire_anim_time * 16.0))
	elif not _seq.is_empty():
		var nm := ""
		var fps := 14.0
		if _dying > 0.0:
			nm = str(special.get("death_sequence", "Die1"))
			fps = flight.TICKS if flight.crash_lift >= 0.0 else 13.0
		elif special.has("psi_elapsed") or special.has("prone_left") or special.has("cheer_elapsed") or (unit_id=="SLAV" and (special.get("shoveling",false) or cargo>0) and (_moving() or special.get("shoveling",false))):
			nm = HollywoodInfantry.pose(self)
		elif special.has(Furnace.STANCE) and _seq.has("Crawl"):
			nm = "FireProne" if _fire_anim_time >= 0 and _seq.has("FireProne") else "Crawl"
		elif special.has("para_height"):
			nm = "Paradrop"
		elif unit_id == "BORIS" and is_instance_valid(attack_target) and attack_target is Building and attack_target.special.get("airstrike_mark", {}).get("spotter") == self and not attack_target.special.airstrike_mark.get("boris_independent",false):
			nm = "SecondaryFire" # Original eight-direction laser-designator pose.
		elif _fire_anim_time >= 0.0 or _muzzle > 0.0:
			nm = _fire_sequence()
			fps = 16.0
		elif is_air_target() and _seq.has("Fly"):
			# RocketeerSequence has distinct airborne poses; never use Walk aloft.
			nm = "Fly" if _moving() or not _seq.has("Hover") else "Hover"
		elif _moving():
			nm = "Walk"
			fps = 14.0
		if nm.is_empty() and unit_id in ["DLPH","SQD"]:
			nm = "Walk" # Naval SHP uses the swimming cycle even at rest.
		if _swimming():
			if _dying > 0.0: nm = str(special.get("death_sequence", nm))
			elif nm == "Walk": nm = "Swim" if _seq.has("Swim") else nm
			elif nm.is_empty(): nm = "Tread" if _seq.has("Tread") else "Guard"
		if nm != "":
			var t := int(_anim * fps + 0.00001)
			if _dying > 0.0 and _seq.has(nm): t = mini(t, int(_seq[nm].per) - 1)
			if _fire_anim_time >= 0.0 and nm == _fire_sequence():
				t = int(_fire_anim_time * fps + 0.00001)
			if nm == "Walk":
				var wseg: Dictionary = _seq[nm]
				var wper := int(wseg.get("per", 6))
				if unit_id == "DLPH" and not _moving():
					t = int(_anim * _naval_idle_fps)
				else:
					t = int(_walk_phase * float(wper))
			if special.has(Furnace.STANCE) and nm=="Crawl": t=int(_walk_phase * int(_seq.Crawl.per)) if _moving() else 0
			if _dying<=0 and (special.has("psi_elapsed") or special.has("prone_left") or nm in ["Cheer","Carry","Shovel"]): t = HollywoodInfantry.frame(self,nm)
			var f2 := RA2Art.seq_frame(_seq, nm, fidx, t)
			if f2 >= 0 and f2 < rects.size():
				frame = f2
		if nm in ["", "Tread", "Guard"] and idle_pose != null and idle_pose.appearance == unit_id and idle_pose.frame >= 0:
			frame = idle_pose.frame
	if unit_id == "SCHP" and _ra2.get("key") == "SCHPDEPL":
		var count := maxi(1, rects.size() / 2)
		anchor_start = 0
		anchor_count = count
		extra_count = 0
		frame = clampi(int(float(special.get("siege_progress", 0.0)) * count), 0, count - 1)
	var aframes := _anchor_frames(anchor_start, anchor_count, extra_start, extra_count)
	var src := RA2Art.src_rect(_ra2, frame)
	var sc := RA2_SPRITE_SCALE
	var dive := NavalContact.dive_fraction(self)
	var lift := _visual_lift()
	if unit_id in ["SUB","DLPH"]: lift -= NavalContact.DIVE_DEPTH_PIXELS * dive
	var a := RA2Art.span_anchor(_ra2, _anchor_span_key)
	var base := Vector2(-a.x * sc, r * 0.35 - a.y * sc - lift)
	# (b) 单位贴图自动提亮：抵消体素着色下限 0.42 与偏暗素材（CMIN 等）。可逆。
	var grade: Color = RA2Art.sprite_grade(_ra2)
	if peregrine_fx!=null and special.has("hero_wreck"):grade=grade.darkened(.35)
	if special.get("hero_skin", false) and unit_id in ["E1","E2"]:
		grade *= Color(0.68, 0.93, 1.15) if unit_id == "E1" else Color(1.18, 0.79, 0.60)
	var cloak_alpha := Ra3Mirage.CloakVisual.opacity(self)
	if unit_id in ["SQD", "SUB", "DLPH"]:
		grade *= Color.WHITE.lerp(Color(0.53, 0.76, 0.88), dive)
	grade.a *= cloak_alpha * (1.0 - 0.5 * dive)
	if powered_unit.offline:
		grade = grade.darkened(0.45)
	# 地面投影：优先用管线烘出的 RA2 体素阴影（<id>_shd.png，VXL 沿光向压平、与主体同 base/cell，
	# 见 ra2pipe/vxl_lib.mjs 的 shadow 模式；方向与建筑 SHP 影子帧一致 = 屏幕右侧）。
	# 没有影子图（步兵 SHP、程序化单位）时退回等距椭圆。
	var shd_tex: Texture2D = _ra2_shd.get("tex")
	var joint_shadow: Texture2D
	if bool(_ra2.get("split_shadow", false)) and not _ra2_tur.is_empty():
		var turret_shadow := RA2Art.art(str(_ra2_tur.get("key", "")) + "_shd")
		if not turret_shadow.is_empty():
			var shadow_frame:=HollywoodTurrets.frame(self) if unit_id=="YTNK" else _sprite_facing(turret_shadow, turret_angle)
			joint_shadow = RA2Art.unit_shadow_texture(_ra2_shd, turret_shadow, frame, shadow_frame)
	if _rock_t > 0.0: Iso.begin(self)
	var ground_offset := Iso.dir(bridge_contact_offset())
	_shadow_draw_texture = joint_shadow
	_shadow_draw_rect = Rect2()
	var dolphin_waterline:=INF
	var water_center:=Vector2.ZERO
	if unit_id=="DLPH":
		water_center=base+sz*sc*0.5+Vector2.DOWN*(4.0-NavalContact.DIVE_DEPTH_PIXELS*dive)
		dolphin_waterline=water_center.y-18.0*dive
		NavalContact.draw_dolphin_wake(self,water_center,dive,false)
	elif dive >= 1.0 or unit_id == "SQD" or uses_missile_pitch():
		pass # Submerged hulls and NoShadow missiles omit the surface shadow.
	elif unit_id=="SCHP" and _ra2.get("key")=="SCHPDEPL":
		_shadow_draw_rect=Rect2(base+Vector2.DOWN*lift+ground_offset,sz*sc)
		draw_texture_rect_region(_ra2.tex,_shadow_draw_rect,RA2Art.src_rect(_ra2,frame+aframes.size()),Color(0,0,0,0.5*cloak_alpha))
	elif shd_tex != null:
		var ssz: Vector2 = RA2Art.frame_size(_ra2_shd)
		if ssz.x > 0.0:
			_shadow_draw_rect = Rect2(base + Vector2(0.0, lift) + ground_offset, ssz * sc)
			if joint_shadow != null:
				draw_texture_rect(joint_shadow, _shadow_draw_rect, false, Color(0.0, 0.0, 0.0, 0.5 * cloak_alpha * (1.0 - dive)))
			else:
				draw_texture_rect_region(shd_tex, _shadow_draw_rect, RA2Art.src_rect(_ra2_shd, frame), Color(0.0, 0.0, 0.0, 0.5 * cloak_alpha * (1.0 - dive)))
	else:
		Iso.shadow(self, ground_offset + Vector2(r * 0.34, r * 0.4), r * 0.85, 0.34 * cloak_alpha * (1.0 - dive))
	if _rock_t > 0.0: draw_set_transform_matrix(body_draw_transform())
	if uses_missile_pitch():
		draw_set_transform_matrix(Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO) * SovietWeapons.DreadFlight.pose(self,lift))
	var armored: bool = not special.has(Furnace.STANCE) and special.get("hero_skin", false) and unit_id in ["E1","E2"] and _dying <= 0.0
	var armor_anchor := Vector2.ZERO
	var armor_bearing:=float(fidx)
	if armored:
		armor_bearing=HeroArmor.pose_bearing(self,frame,fidx)
		armor_anchor = HeroArmor.head(self,frame,src,Rect2(base,sz*sc))
		HeroArmor.draw_layer(self,armor_anchor,armor_bearing,true,grade.a)
	var commando_socket:Array = CommandoSkin.NO_SOCKET
	if unit_id in ["TANY","BORIS"] and special.get("academy_hero") == unit_id:
		commando_socket = CommandoSkin.socket(unit_id, frame)
	var commando_outfit:bool = not commando_socket.is_empty() and special.get("hero_skin",false)
	var commando_alive:=not _dead and _dying<=0
	if commando_outfit and commando_alive: CommandoSkin.draw_layer(self, base, commando_socket, frame, fidx, true, grade.a)
	var coastal:=unit_id=="GGI" and yr_finish!=null and _dying<=0.0 and not _dead and not special.has("para_height")
	if coastal:CoastalRig.draw_layer(self,base,frame,fidx,true)
	if unit_id=="TTNK" and yr_finish!=null:yr_finish.pika_tail(self,base,fidx,false,grade.a)
	if casemate_thruster!=null:casemate_thruster.exhaust(self,base,fidx,grade.a,true)
	if commando_outfit:
		CommandoSkin.draw_body(self, base, frame, grade)
		_body_bounds=RA2Art.visible_sprite_rect(_ra2,Rect2(base,sz*sc),src)
		if _rock_t>0:_body_bounds=rocking_pose()*_body_bounds
		if commando_alive:CommandoSkin.draw_layer(self, base, commando_socket, frame, fidx, false, grade.a)
	else:
		draw_body_sprite(_ra2, Rect2(base, sz * sc), src, grade,dolphin_waterline)
	if commando_alive and not commando_socket.is_empty(): CommandoSkin.draw_star(self, base + Vector2(commando_socket[2],commando_socket[3]))
	if special.has(Furnace.STANCE) and not _dead: Furnace.draw_armor(self,frame,Rect2(base,sz*sc),grade.a)
	if special.get("hero_skin", false): TankHeroSkin.draw_layer(self,base,fidx,false,grade.a)
	if unit_id=="SREF" and yr_finish!=null:yr_finish.solar_hull(self,Rect2(base,sz*sc),fidx,grade.a)
	if casemate_thruster!=null:
		casemate_thruster.armor(self,Rect2(base,sz*sc),src,fidx,grade.a)
		casemate_thruster.exhaust(self,base,fidx,grade.a,false)
	if unit_id=="TTNK" and yr_finish!=null:yr_finish.pika_tail(self,base,fidx,true,grade.a)
	if unit_id=="DLPH":NavalContact.draw_dolphin_wake(self,water_center,dive,true)
	if uses_missile_pitch():
		Iso.begin(self)
		SovietWeapons.DreadFlight.draw_exhaust(self)
	# 独立炮塔：与车体同画布对齐，按 turret_angle 单独取帧叠加
	_turret_draw_rect = Rect2()
	if not _ra2_tur.is_empty():
		var ttex: Texture2D = _ra2_tur.get("tex")
		if ttex != null:
			var tsz: Vector2 = RA2Art.frame_size(_ra2_tur)
			if tsz.x > 0.0 and tsz.y > 0.0:
				var tfi := _sprite_facing(_ra2_tur, turret_angle)
				if unit_id=="YTNK": tfi=HollywoodTurrets.frame(self)
				var draw_offset: Array = _ra2_tur.get("draw_offset", [0, 0])
				_turret_draw_rect = Rect2(base + Vector2(draw_offset[0], draw_offset[1]) * sc, tsz * sc)
				_turret_draw_source = RA2Art.src_rect(_ra2_tur, tfi)
				var turret_grade := RA2Art.sprite_grade(_ra2_tur)
				turret_grade.a *= cloak_alpha * (1.0 - 0.5 * dive)
				if powered_unit.offline:
					turret_grade = turret_grade.darkened(0.45)
				draw_body_sprite(_ra2_tur, _turret_draw_rect, _turret_draw_source, turret_grade)
				if special.get("hero_skin", false): TankHeroSkin.draw_layer(self,base,tfi,true,turret_grade.a)
				if unit_id=="TTNK" and yr_finish!=null:yr_finish.pika_head(self,base,tfi,turret_grade.a)
	# 记录本帧绘制参数，供 hit_test()/art_center() 复用（铁律：判定几何 = 绘制几何）
	if armored:
		HeroArmor.draw_layer(self,armor_anchor,armor_bearing,false,grade.a)
	if coastal:CoastalRig.draw_layer(self,base,frame,fidx,false)
	if unit_id=="HARV" and side=="ally" and cosmetic_outfit().get("skin")=="night_shift":
		preload("res://scripts/units/night_shift.gd").truck(self,base,fidx,facings,sc)
	_pick_body_art = _ra2
	_pick_body_rect = Rect2(base, sz * sc)
	_art_frame = frame
	_art_aframes = aframes
	_art_sc = sc
	_art_lift = lift


# -------------------------------------------------- 点击命中判定（WYSIWYG）

## 世界点是否落在本单位的可见像素上。与 _draw_ra2_sprite 同源：
## 用绘制时缓存的 frame/aframes/sc/lift 反算「绘制空间」坐标后采样贴图 alpha。
func hit_test(world_p: Vector2) -> bool:
	var scope = preload("res://scripts/world/battle_call_counters.gd").enter(56)
	if embarked_in != null or _dead:
		return false
	if yuriko_model != null: return _body_bounds.grow(3).has_point(Iso.dir(world_p-presentation_position())) or world_p.distance_to(presentation_position())<=radius
	if night_skin!=null:return night_skin.hits(self,world_p)
	if hero_art!=null:return hero_art.hits(self,world_p)
	# Before a native sprite has a drawn pose, the existing hit rule is a circle.
	# Its interpolated centre lies between the previous and current positions.
	# Reject distant pointers before querying interpolation or building art poses.
	# The extra pixel keeps inclusive circle endpoints inside Rect2's open edge.
	if _art_frame < 0 and _ra3_model == null and _rock_t <= 0.0 and not special.has("mcv_repack_left") \
			and unit_id != "SPY" and unit_id != "MGTK" and unit_id != Ra3Mirage.ID and unit_id != "DMISL" and unit_id != "V3ROCKET":
		var bounds := Rect2(global_position,Vector2.ZERO).expand(motion_pose.previous_position).grow(radius+11.0)
		if not bounds.has_point(world_p):
			preload("res://scripts/world/battle_call_counters.gd").iterations(56,1)
			return false
	world_p += global_position - presentation_position()
	if uses_missile_pitch(): world_p = global_position + RA2Art.art_dir(SovietWeapons.DreadFlight.pose(self,_art_lift).affine_inverse() * Iso.dir(world_p-global_position))
	if _rock_t > 0.0:
		world_p = global_position + RA2Art.art_dir(rocking_pose().affine_inverse() * Iso.dir(world_p - global_position))
	if special.has("mcv_repack_left"):
		var repack := preload("res://scripts/world/construction_transition.gd").repack_visual(self)
		if not repack.is_empty():
			return RA2Art.hits_pixel(world_p, global_position + RA2Art.art_dir(repack.shift), repack.art, repack.radius, repack.anchors, repack.frame)
	if special.has("disguise") or unit_id in ["MGTK","R3MIRAGE"]:
		var disguise := AlliedAbilities.disguise_visual(self)
		if not disguise.is_empty():
			# Own Mirage tanks remain selectable at their feet beneath the tree canopy.
			if side == "ally" and unit_id in ["MGTK", "R3MIRAGE"] and world_p.distance_squared_to(global_position) <= (radius + 10.0) * (radius + 10.0):
				return true
			return RA2Art.hits_pixel(world_p, global_position, disguise.art, radius, disguise.anchors, disguise.frame, 0.0, RA2_SPRITE_SCALE)
	if _ra3_model != null: return _ra3_model.hits(world_p)
	if _ra2.get("tex") == null or _art_frame < 0:
		# 尚无 RA2 美术 or 尚未绘制过一帧 -> 退回逻辑半径兜底
		return world_p.distance_to(global_position) <= radius + 10.0
	var local := Iso.dir(world_p - global_position)
	if is_same(_pick_body_art, _ra2) and not _pick_body_rect.has_point(local) and not _turret_draw_rect.has_point(local): return false
	var turret_image: Image = _ra2_tur.get("img")
	if turret_image != null and _turret_draw_rect.has_point(local):
		var pixel := Vector2i(_turret_draw_source.position + ((local - _turret_draw_rect.position) / _art_sc).floor())
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < turret_image.get_width() and pixel.y < turret_image.get_height():
			if turret_image.get_pixelv(pixel).a * 255.0 >= 20.0:
				return true
	return RA2Art.hits_pixel(world_p, global_position, _ra2, radius, _art_aframes, _art_frame, _art_lift, _art_sc)


## 可见像素的世界坐标中心（拖框选择 / 就近判定用，与贴图对齐）
func art_center() -> Vector2:
	var center := _rest_art_center()
	if uses_missile_pitch(): return global_position + RA2Art.art_dir(SovietWeapons.DreadFlight.pose(self,_art_lift) * Iso.dir(center-global_position))
	if _rock_t <= 0.0: return center
	return global_position + RA2Art.art_dir(rocking_pose() * Iso.dir(center - global_position))

func _rest_art_center() -> Vector2:
	if yuriko_model != null: return global_position+RA2Art.art_dir(Vector2(0,-15))
	if night_skin!=null and not _dead:return night_skin.center(self)
	if hero_art!=null and not _dead:return hero_art.center(self)
	if special.has("mcv_repack_left"):
		var repack := preload("res://scripts/world/construction_transition.gd").repack_visual(self)
		if not repack.is_empty():
			return RA2Art.draw_center(global_position + RA2Art.art_dir(repack.shift), repack.art, repack.radius, repack.anchors)
	if special.has("disguise") or unit_id == "MGTK" or unit_id == Ra3Mirage.ID:
		var disguise := AlliedAbilities.disguise_visual(self)
		if not disguise.is_empty(): return RA2Art.draw_center(global_position, disguise.art, radius, disguise.anchors, 0.0, RA2_SPRITE_SCALE)
	if _ra3_model != null: return _ra3_model.center()
	if _ra2.get("tex") == null or _art_frame < 0:
		return global_position
	if _ra2.get("kind", "") == "vxl":
		return RA2Art.visible_unit_center(global_position, _ra2, radius, _art_aframes, _art_frame, _art_lift, _art_sc)
	return RA2Art.draw_center(global_position, _ra2, radius, _art_aframes, _art_lift, _art_sc)


# -------------------------------------------------- 载具 / 坦克 / 火炮

func _draw_ground_shadow(offset: Vector2, size: float, opacity: float) -> void:
	if _rock_t > 0.0: Iso.begin(self)
	Iso.shadow(self, offset, size, opacity)
	if _rock_t > 0.0: draw_set_transform_matrix(body_draw_transform())

func _draw_procedural_body(r:float) -> void:
	var body_col := _col
	if side == "enemy":
		body_col = body_col.darkened(0.06)
	var dark := body_col.darkened(0.46)
	var mid := body_col.darkened(0.2)
	var light := body_col.lightened(0.24)
	var hi := body_col.lightened(0.48)
	var glass := Color(0.52, 0.78, 0.95)
	var ammo := Color(1.0, 0.6, 0.22)
	var role := str(data.get("role", "vehicle"))
	var tgs: Array = data.get("tags", [])
	var has_weapon := not weapon.is_empty()

	if is_air:
		_draw_air(r, body_col, dark, mid, light, hi, glass, ammo, has_weapon, role)
	elif role == "infantry" or tgs.has("infantry"):
		_draw_infantry(r, body_col, dark, mid, light, hi, dark, has_weapon)
	elif tgs.has("beast") or tgs.has("swarm"):
		_draw_beast(r, body_col, dark, mid, light, hi, ammo, has_weapon)
	elif role == "mech" or role == "mecha":
		_draw_mech(r, body_col, dark, mid, light, hi, glass, ammo, has_weapon)
	elif is_harvester:
		_draw_harvester(r, body_col, dark, mid, light, hi, glass, ammo)
	else:
		_draw_vehicle(r, body_col, dark, mid, light, hi, glass, ammo, has_weapon, role)

func _draw_vehicle(r: float, body: Color, dark: Color, mid: Color, light: Color, hi: Color,
		glass: Color, ammo: Color, has_weapon: bool, role: String) -> void:
	var heavy := role == "artillery"
	_draw_ground_shadow(Vector2(r * 0.34, r * 0.4), r * 0.85, 0.34)
	var hull := Vector2.RIGHT.rotated(hull_angle)
	var hull_r := Vector2(-hull.y, hull.x)
	var flash := _muzzle > 0.0
	var recoil := _recoil * r * 0.28

	# --- 履带（两条，带滚动纹路）---
	var tw := r * 0.44
	var tl := r * 2.1
	for sgn: float in [-1.0, 1.0]:
		var c := hull_r * (r * 0.72 * sgn) + hull * 0.02
		_draw_track(c, hull, tl, tw, r * 0.34, dark.darkened(0.15), mid.darkened(0.1))

	# --- 车体 ---
	var hull_top := _oriented_box(Vector2(0, r * 0.06), hull, r * 1.9, r * 1.36, r * 0.6, mid, light)
	# 车体侧面板缝
	_draw_box_seams(Vector2(0, r * 0.06), hull, r * 1.9, r * 1.36, r * 0.6, dark)
	# 前部首上装甲（斜面高光梯形）—— 四个角都必须走 Iso.dir，
	# 否则把世界向量直接加到已投影的点上，方向/长度都不对。
	var fr_a := Iso.dir(hull * (r * 1.02) + hull_r * (r * 0.5))
	var fr_b := Iso.dir(hull * (r * 1.02) - hull_r * (r * 0.5))
	var fr_c := Iso.dir(hull * (r * 1.02) - hull_r * (r * 0.28)) + Vector2(0, -r * 0.16)
	var fr_d := Iso.dir(hull * (r * 1.02) + hull_r * (r * 0.28)) + Vector2(0, -r * 0.16)
	draw_colored_polygon(PackedVector2Array([fr_a, fr_b, fr_c, fr_d]), hi)
	# 后部引擎格栅
	var bk := Iso.dir(-hull * (r * 0.98)) + Vector2(0, -r * 0.3)
	for i in range(4):
		var yy := bk.y - r * 0.34 + float(i) * r * 0.14
		draw_line(Vector2(bk.x - r * 0.5, yy), Vector2(bk.x + r * 0.5, yy), dark, 1.4, true)
	# 侧裙板高光条
	for sgn: float in [-1.0, 1.0]:
		var a := Iso.dir(hull * (r * 0.85) + hull_r * (r * 0.68 * sgn)) + Vector2(0, -r * 0.16)
		var b := Iso.dir(-hull * (r * 0.85) + hull_r * (r * 0.68 * sgn)) + Vector2(0, -r * 0.16)
		draw_line(a, b, light, 1.6, true)

	# --- 炮塔（独立朝向 + 后坐）---
	var tf := Vector2.RIGHT.rotated(turret_angle)
	var tdir := _sdir(tf)
	var t_base := hull_top + Vector2(0, -r * 0.14) - tdir * recoil
	var t_top := _oriented_box(t_base, tf, r * (1.15 if heavy else 0.94), r * 0.8, r * 0.46, body, hi)
	draw_circle(t_top + Vector2(0, r * 0.02), r * 0.12, dark)      # 舱盖
	draw_line(t_top + Vector2(0, r * 0.02), t_top + Vector2(0, r * 0.02) - Vector2(0, r * 1.15), dark.darkened(0.2), 1.4, true)
	draw_circle(t_top + Vector2(0, r * 0.02) - Vector2(0, r * 1.2), r * 0.05, Color(0.95, 0.32, 0.28))  # 天线灯

	if has_weapon:
		var blen := r * (2.3 if heavy else 1.72)
		var bthick := maxf(2.6, r * (0.24 if heavy else 0.17))
		var root := t_top + tdir * (r * 0.24)
		var muzzle := root + tdir * (blen - r * 0.24)
		draw_line(root, muzzle, dark, bthick + 1.8, true)
		draw_line(root + Vector2(0, -bthick * 0.18), muzzle + Vector2(0, -bthick * 0.18), mid, bthick * 0.7, true)
		if heavy:
			draw_line(muzzle - tdir * r * 0.3, muzzle - tdir * r * 0.12, dark.darkened(0.2), bthick + 3.0, true)
			draw_line(muzzle - tdir * r * 0.06, muzzle + tdir * r * 0.05, dark.darkened(0.2), bthick + 2.2, true)
		if flash:
			_draw_muzzle_flash(muzzle, tdir, r * (1.0 if heavy else 0.72), ammo)
	var tdir2 := tdir
	# 同轴机枪
	draw_line(t_top + hull_r * (r * 0.26) * 0.0 + tdir2 * (r * 0.1), t_top + tdir2 * (r * 0.75) + Vector2(0, r * 0.1), dark, 1.6, true)
	# 车灯
	var lp := Iso.dir(hull * (r * 0.98) + hull_r * (r * 0.45)) + Vector2(0, -r * 0.24)
	draw_circle(lp, maxf(1.4, r * 0.09), Color(1.0, 0.95, 0.7, 0.9))
	# 阵营涂装条
	draw_line(Iso.dir(hull * (r * 0.9) + hull_r * (r * 0.2)) + Vector2(0, -r * 0.05),
		Iso.dir(-hull * (r * 0.9) + hull_r * (r * 0.2)) + Vector2(0, -r * 0.05),
		Color(ammo.r, ammo.g, ammo.b, 0.55), 1.5, true)

	# --- 细节：前顶棱线高光（增强车体立体感）---
	draw_line(Iso.dir(hull * (r * 0.96) + hull_r * (r * 0.64)) + Vector2(0, -r * 0.62),
		Iso.dir(hull * (r * 0.96) - hull_r * (r * 0.64)) + Vector2(0, -r * 0.62), hi, 1.3, true)
	# 另一侧车灯
	var lp2 := Iso.dir(hull * (r * 0.98) - hull_r * (r * 0.45)) + Vector2(0, -r * 0.24)
	draw_circle(lp2, maxf(1.4, r * 0.09), Color(1.0, 0.95, 0.7, 0.9))
	# 尾部排气管 + 热光
	var ex := Iso.dir(-hull * (r * 0.88) - hull_r * (r * 0.42)) + Vector2(0, -r * 0.3)
	draw_circle(ex, maxf(1.6, r * 0.1), dark.darkened(0.35))
	draw_circle(ex + Vector2(0, -r * 0.06), maxf(1.0, r * 0.05), Color(1.0, 0.45, 0.2, 0.5))
	# 炮塔尾舱（红警3 式储物舱）
	_oriented_box(t_base - tdir * (r * 0.66) + Vector2(0, -r * 0.1), tf, r * 0.4, r * 0.66, r * 0.2,
		dark.darkened(0.05), mid.darkened(0.05))
	# 车体置物箱 + 备用履带块
	_oriented_box(Iso.dir(-hull * (r * 0.46) + hull_r * (r * 0.52)) + Vector2(0, -r * 0.66),
		hull, r * 0.34, r * 0.3, r * 0.16, mid, dark)
	draw_line(Iso.dir(hull * (r * 0.86) + hull_r * (r * 0.42)) + Vector2(0, -r * 0.62),
		Iso.dir(hull * (r * 0.86) + hull_r * (r * 0.2)) + Vector2(0, -r * 0.62), dark, 1.2, true)

# -------------------------------------------------- 步兵

func _draw_infantry(r: float, _body: Color, dark: Color, mid: Color, light: Color, hi: Color,
		_unused: Color, has_weapon: bool) -> void:
	# 步兵：屏幕对齐的躯干/头盔 + 世界朝向的腿与武器
	Iso.shadow(self, Vector2(r * 0.34, r * 0.55), r * 0.5, 0.32)
	var fwd := _sdir(Vector2.RIGHT.rotated(hull_angle))
	var rg := Vector2(-fwd.y, fwd.x)
	var walk := 0.0
	if velocity.length() > 12.0:
		walk = sin(_anim * 9.0) * r * 0.26
	var bob := 0.0
	if velocity.length() > 12.0:
		bob = absf(sin(_anim * 9.0)) * r * 0.09

	# 腿
	for s: float in [-1.0, 1.0]:
		var hip := Vector2(0, r * 0.1)
		var knee := hip + rg * (r * 0.15 * s) + Vector2(0, r * 0.34) + fwd * (walk * s)
		var ft := knee + rg * (r * 0.07 * s) + Vector2(0, r * 0.3) + fwd * (walk * s * 0.7)
		draw_line(Iso.dir(hip), Iso.dir(knee), dark, maxf(2.2, r * 0.22), true)
		draw_line(Iso.dir(knee), Iso.dir(ft), mid, maxf(2.0, r * 0.19), true)
		draw_line(Iso.dir(ft) - rg * (r * 0.1), Iso.dir(ft) + fwd * (r * 0.14), dark.darkened(0.2), maxf(2.2, r * 0.16), true)

	# 躯干
	var torso := Iso.extrude(self, Vector2(0, r * 0.05), r * 0.34, r * 0.72 - bob, mid, light, 12)
	# 战术背心（分色块）
	draw_colored_polygon(PackedVector2Array([
		torso + Vector2(-r * 0.3, r * 0.12), torso + Vector2(r * 0.3, r * 0.12),
		torso + Vector2(r * 0.26, -r * 0.34), torso + Vector2(-r * 0.26, -r * 0.34)]), dark)
	# 背包
	draw_colored_polygon(PackedVector2Array([
		Iso.dir(-fwd * (r * 0.3)) + Vector2(-r * 0.22, r * 0.18),
		Iso.dir(-fwd * (r * 0.3)) + Vector2(r * 0.22, r * 0.18),
		Iso.dir(-fwd * (r * 0.3)) + Vector2(r * 0.18, -r * 0.2),
		Iso.dir(-fwd * (r * 0.3)) + Vector2(-r * 0.18, -r * 0.2)]), mid.darkened(0.15))
	# 头盔
	draw_circle(torso + Vector2(0, -r * 0.28), r * 0.27, dark)
	draw_circle(torso + Vector2(0, -r * 0.31), r * 0.21, light)
	draw_arc(torso + Vector2(0, -r * 0.28), r * 0.27, PI, TAU, 10, hi, 1.2)

	# 武器
	if has_weapon:
		var wd := _sdir(Vector2.RIGHT.rotated(turret_angle))
		var hand := torso + wd * (r * 0.2) + Vector2(0, r * 0.06)
		var muzzle := hand + wd * (r * 0.95)
		draw_line(hand - wd * (r * 0.2), muzzle, dark, maxf(2.0, r * 0.15), true)
		draw_line(hand + Vector2(0, r * 0.14), hand + wd * (r * 0.3) + Vector2(0, r * 0.1), mid, maxf(1.6, r * 0.12), true)
		# 瞄准镜 / 弹匣
		draw_circle(hand + wd * (r * 0.25) + Vector2(0, -r * 0.12), maxf(1.2, r * 0.07), dark.darkened(0.2))
		if _muzzle > 0.0:
			_draw_muzzle_flash(muzzle, wd, r * 0.55, ammo_or_light())

func ammo_or_light() -> Color:
	return Color(1.0, 0.72, 0.3)

# -------------------------------------------------- 空中单位

func _draw_air(r: float, body: Color, dark: Color, mid: Color, light: Color, hi: Color,
		glass: Color, ammo: Color, has_weapon: bool, _role: String) -> void:
	# 地面分离阴影
	draw_colored_polygon(Iso.ell(Vector2(0, r * 2.1), r * 1.1, r * 1.1, 20), Color(0, 0, 0, 0.15))
	var hover := Vector2(0, -_visual_lift())
	var fwd := _sdir(Vector2.RIGHT.rotated(hull_angle))
	var rg := Vector2(-fwd.y, fwd.x)

	# 机身
	var fus := hover + fwd * (r * 0.2)
	draw_colored_polygon(PackedVector2Array([
		fus + fwd * (r * 1.25), fus + rg * (r * 0.3),
		fus - fwd * (r * 1.15), fus - rg * (r * 0.34)]), mid)
	draw_colored_polygon(PackedVector2Array([
		fus + fwd * (r * 1.2), fus + rg * (r * 0.12),
		fus - fwd * (r * 1.1), fus - rg * (r * 0.12)]), hi)
	# 座舱玻璃
	draw_colored_polygon(PackedVector2Array([
		fus + fwd * (r * 0.72) + rg * (r * 0.16), fus + fwd * (r * 0.72) - rg * (r * 0.16),
		fus + fwd * (r * 0.2) - rg * (r * 0.14), fus + fwd * (r * 0.2) + rg * (r * 0.14)]), glass)
	# 尾梁 + 尾翼
	var tail := fus - fwd * (r * 1.5)
	draw_line(fus - fwd * (r * 1.0), tail, dark, maxf(2.0, r * 0.16), true)
	draw_line(tail, tail - rg * (r * 0.42) - fwd * (r * 0.12), dark, maxf(1.8, r * 0.14), true)
	# 短翼
	var wing := fus + fwd * (r * 0.05)
	draw_colored_polygon(PackedVector2Array([
		wing + rg * (r * 1.05) - fwd * (r * 0.22), wing + rg * (r * 1.05) + fwd * (r * 0.34),
		wing + rg * (r * 0.2) + fwd * (r * 0.4), wing + rg * (r * 0.2) - fwd * (r * 0.22)]), body.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		wing - rg * (r * 1.05) - fwd * (r * 0.22), wing - rg * (r * 1.05) + fwd * (r * 0.34),
		wing - rg * (r * 0.2) + fwd * (r * 0.4), wing - rg * (r * 0.2) - fwd * (r * 0.22)]), body.darkened(0.1))
	# 挂载导弹
	if has_weapon:
		for s: float in [-1.0, 1.0]:
			var mp := wing + rg * (r * 0.62 * s)
			draw_line(mp - fwd * (r * 0.2), mp + fwd * (r * 0.5), dark, maxf(1.8, r * 0.12), true)
			draw_colored_polygon(PackedVector2Array([
				mp + fwd * (r * 0.62), mp + fwd * (r * 0.5) + rg * (r * 0.07),
				mp + fwd * (r * 0.5) - rg * (r * 0.07)]), ammo)
	# 主旋翼（旋转）+ 尾桨
	var rot := _anim * 22.0
	var rlen := r * 1.9
	for i in range(3):
		var a := rot + float(i) * TAU / 3.0
		var rd := Vector2(cos(a), sin(a) * 0.5)
		draw_line(fus + Vector2(0, -r * 0.34), fus + Vector2(0, -r * 0.34) + rd * rlen, Color(1, 1, 1, 0.22), 2.0, true)
	draw_circle(fus + Vector2(0, -r * 0.34), r * 0.14, dark)
	# 引擎喷口
	var ex := fus - fwd * (r * 1.15)
	draw_circle(ex - rg * (r * 0.34), r * 0.12, dark)
	draw_circle(ex + rg * (r * 0.34), r * 0.12, dark)
	var glow := 0.6 + 0.4 * sin(_anim * 14.0)
	draw_circle(ex - rg * (r * 0.34), r * 0.09, Color(1.0, 0.7, 0.3, glow))
	draw_circle(ex + rg * (r * 0.34), r * 0.09, Color(1.0, 0.7, 0.3, glow))

# -------------------------------------------------- 机甲

func _draw_mech(r: float, body: Color, dark: Color, mid: Color, light: Color, _hi: Color,
		glass: Color, ammo: Color, has_weapon: bool) -> void:
	_draw_ground_shadow(Vector2(r * 0.34, r * 0.62), r * 0.8, 0.3)
	var walk := 0.0
	if velocity.length() > 12.0:
		walk = sin(_anim * 7.0) * r * 0.2
	var fwd := _sdir(Vector2.RIGHT.rotated(hull_angle))
	var rg := Vector2(-fwd.y, fwd.x)
	# 双腿
	for s: float in [-1.0, 1.0]:
		var hip := Vector2(r * 0.42 * s, r * 0.05)
		var knee := hip + Vector2(r * 0.2 * s, r * 0.4) + fwd * (walk * s)
		var ankle := knee + Vector2(r * 0.08 * s, r * 0.36) + fwd * (walk * s * 0.6)
		draw_line(Iso.dir(hip), Iso.dir(knee), mid, maxf(3.0, r * 0.26), true)
		draw_line(Iso.dir(knee), Iso.dir(ankle), dark, maxf(2.6, r * 0.22), true)
		draw_circle(Iso.dir(knee), maxf(2.0, r * 0.16), dark.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([
			Iso.dir(ankle) + rg * (r * 0.2), Iso.dir(ankle) + fwd * (r * 0.3),
			Iso.dir(ankle) - fwd * (r * 0.22), Iso.dir(ankle) - rg * (r * 0.2)]), dark.darkened(0.15))
	# 躯干
	var torso := Iso.extrude(self, Vector2(0, r * 0.02), r * 0.44, r * 1.05, body, light, 10)
	# 肩甲
	for s: float in [-1.0, 1.0]:
		var sh := torso + Vector2(r * 0.5 * s, r * 0.2)
		draw_colored_polygon(PackedVector2Array([
			sh + Vector2(-r * 0.24 * s, r * 0.16), sh + Vector2(r * 0.26 * s, r * 0.16),
			sh + Vector2(r * 0.3 * s, -r * 0.24), sh + Vector2(-r * 0.18 * s, -r * 0.28)]), mid)
	# 胸口反应堆 / 座舱
	draw_circle(torso + Vector2(0, r * 0.05), r * 0.16, glass)
	draw_circle(torso + Vector2(0, r * 0.05), r * 0.16, Color(0.7, 0.95, 1.0, 0.5 * (0.6 + 0.4 * sin(_anim * 5.0))))
	draw_circle(torso + Vector2(0, -r * 0.34), r * 0.1, dark)
	# 头部 + 传感器
	draw_circle(torso + Vector2(0, -r * 0.52), r * 0.19, mid)
	draw_line(torso + Vector2(-r * 0.12, -r * 0.56), torso + Vector2(r * 0.12, -r * 0.56), Color(1.0, 0.4, 0.35), 2.0, true)
	draw_line(torso + Vector2(0, -r * 0.68), torso + Vector2(0, -r * 1.15), dark.darkened(0.2), 1.4, true)
	# 臂炮
	if has_weapon:
		var wd := _sdir(Vector2.RIGHT.rotated(turret_angle))
		var recoil := _recoil * r * 0.2
		var root := torso + Vector2(r * 0.56, r * 0.05) - wd * recoil
		var muzzle := root + wd * (r * 1.5)
		draw_line(root, muzzle, dark, maxf(3.0, r * 0.26), true)
		draw_line(root + Vector2(0, -r * 0.1), muzzle + Vector2(0, -r * 0.1), mid, maxf(2.0, r * 0.16), true)
		if _muzzle > 0.0:
			_draw_muzzle_flash(muzzle, wd, r * 0.8, ammo)
	# 阵营涂装
	draw_line(torso + Vector2(-r * 0.4, r * 0.34), torso + Vector2(r * 0.4, r * 0.34), Color(ammo.r, ammo.g, ammo.b, 0.5), 1.6, true)

# -------------------------------------------------- 兽群 / 生物

func _draw_beast(r: float, body: Color, dark: Color, mid: Color, light: Color, hi: Color,
		ammo: Color, has_weapon: bool) -> void:
	_draw_ground_shadow(Vector2(r * 0.34, r * 0.45), r * 0.9, 0.32)
	var fwd := _sdir(Vector2.RIGHT.rotated(hull_angle))
	var rg := Vector2(-fwd.y, fwd.x)
	var crawl := _anim * 8.0

	# 腿（三对，交替）
	for i in range(3):
		for s: float in [-1.0, 1.0]:
			var base := Vector2(-fwd.x * (r * 0.5 - float(i) * r * 0.5), -fwd.y * (r * 0.5 - float(i) * r * 0.5))
			var ph := sin(crawl + float(i) * 2.0 + (0.0 if s > 0.0 else PI))
			var knee := base + rg * (r * 0.55 * s) + fwd * (ph * r * 0.16) + Vector2(0, r * 0.25)
			var ft := knee + rg * (r * 0.45 * s) + Vector2(0, r * 0.42) + fwd * (ph * r * 0.12)
			var p0 := Iso.dir(base)
			draw_line(p0, Iso.dir(knee), dark, maxf(2.4, r * 0.16), true)
			draw_line(Iso.dir(knee), Iso.dir(ft), dark.darkened(0.1), maxf(2.0, r * 0.13), true)
	# 甲壳身体（分段）
	var bt := Iso.extrude(self, Vector2(0, r * 0.05), r * 1.0, r * 0.5, mid, light, 16)
	for i in range(3):
		var yy := bt.y + r * 0.1 - float(i) * r * 0.16
		var w := r * (0.9 - float(i) * 0.16)
		draw_arc(Vector2(0, yy), w, PI, TAU, 14, dark.darkened(0.1), 1.6)
	# 背刺
	for i in range(4):
		var sxp := -r * 0.45 + float(i) * r * 0.3
		draw_colored_polygon(PackedVector2Array([
			Vector2(sxp - r * 0.08, bt.y), Vector2(sxp + r * 0.08, bt.y),
			Vector2(sxp, bt.y - r * 0.5 - float(i % 2) * r * 0.2)]), hi)
	# 头 + 下颚
	var head := bt + fwd * (r * 0.85) + Vector2(0, -r * 0.12)
	draw_circle(head, r * 0.42, body.darkened(0.05))
	for s: float in [-1.0, 1.0]:
		draw_line(head + rg * (r * 0.18 * s), head + rg * (r * 0.18 * s) + fwd * (r * 0.5) + rg * (r * 0.1 * s), dark, maxf(2.0, r * 0.12), true)
	# 眼睛
	draw_circle(head + rg * (r * 0.16) - fwd * (r * 0.1), maxf(1.4, r * 0.1), ammo)
	draw_circle(head - rg * (r * 0.16) - fwd * (r * 0.1), maxf(1.4, r * 0.1), ammo)
	# 尾
	var tail := bt - fwd * (r * 1.1)
	draw_line(bt - fwd * (r * 0.6), tail, dark, maxf(2.4, r * 0.18), true)
	if has_weapon and _muzzle > 0.0:
		_draw_muzzle_flash(head + fwd * (r * 0.5), fwd, r * 0.6, ammo)

# -------------------------------------------------- 采集车

func _draw_harvester(r: float, body: Color, dark: Color, mid: Color, light: Color, _hi: Color,
		glass: Color, ammo: Color) -> void:
	_draw_ground_shadow(Vector2(r * 0.34, r * 0.4), r * 0.85, 0.32)
	var hull := Vector2.RIGHT.rotated(hull_angle)
	var hull_r := Vector2(-hull.y, hull.x)
	# 轮/履带
	for sgn: float in [-1.0, 1.0]:
		_draw_track(hull_r * (r * 0.72 * sgn) + hull * 0.02, hull, r * 1.9, r * 0.4, r * 0.3, dark.darkened(0.12), mid.darkened(0.08))
	# 底盘
	var chas := _oriented_box(Vector2(0, r * 0.05), hull, r * 1.7, r * 1.3, r * 0.52, mid, light)
	# 料斗（后部）+ 矿石填充
	var hopper := chas - Iso.dir(hull) * 0.0 + Iso.dir(-hull * (r * 0.35))
	draw_colored_polygon(PackedVector2Array([
		hopper + Vector2(-r * 0.5, r * 0.05), hopper + Vector2(r * 0.34, r * 0.05),
		hopper + Vector2(r * 0.28, -r * 0.5), hopper + Vector2(-r * 0.46, -r * 0.5)]), dark)
	var fill: float = clampf(cargo / maxf(1.0, cargo_cap), 0.0, 1.0)
	if fill > 0.01:
		var fh := r * 0.55 * fill
		draw_colored_polygon(PackedVector2Array([
			hopper + Vector2(-r * 0.44, r * 0.02), hopper + Vector2(r * 0.3, r * 0.02),
			hopper + Vector2(r * 0.3, r * 0.02 - fh), hopper + Vector2(-r * 0.44, r * 0.02 - fh)]), ammo)
		draw_colored_polygon(PackedVector2Array([
			hopper + Vector2(-r * 0.44, r * 0.02 - fh), hopper + Vector2(r * 0.3, r * 0.02 - fh),
			hopper + Vector2(r * 0.24, r * 0.02 - fh - r * 0.06), hopper + Vector2(-r * 0.4, r * 0.02 - fh - r * 0.06)]), ammo.lightened(0.25))
	# 驾驶舱（前部）+ 玻璃
	var cab := chas + Iso.dir(hull * (r * 0.6)) + Vector2(0, -r * 0.42)
	draw_colored_polygon(PackedVector2Array([
		cab + Vector2(-r * 0.34, r * 0.2), cab + Vector2(r * 0.3, r * 0.2),
		cab + Vector2(r * 0.24, -r * 0.34), cab + Vector2(-r * 0.28, -r * 0.34)]), body)
	draw_colored_polygon(PackedVector2Array([
		cab + Vector2(-r * 0.24, r * 0.06), cab + Vector2(r * 0.24, r * 0.06),
		cab + Vector2(r * 0.18, -r * 0.26), cab + Vector2(-r * 0.18, -r * 0.26)]), glass)
	draw_line(cab + Vector2(0, r * 0.06), cab + Vector2(0, -r * 0.26), dark, 1.2, true)
	# 前部钻头
	var drill := chas + Iso.dir(hull * (r * 1.0)) + Vector2(0, -r * 0.1)
	draw_line(drill - Iso.dir(hull) * (r * 0.1), drill + Iso.dir(hull) * (r * 0.45), dark.darkened(0.15), maxf(2.4, r * 0.2), true)
	draw_colored_polygon(PackedVector2Array([
		drill + Iso.dir(hull) * (r * 0.45) + hull_r * (r * 0.1),
		drill + Iso.dir(hull) * (r * 0.45) - hull_r * (r * 0.1),
		drill + Iso.dir(hull) * (r * 0.62)]), Color(0.8, 0.82, 0.86))
	# 警示条纹
	var wp := chas + Iso.dir(-hull * (r * 0.2)) + Vector2(0, r * 0.2)
	for i in range(3):
		draw_line(Vector2(wp.x - r * 0.4 + float(i) * r * 0.3, wp.y), Vector2(wp.x - r * 0.28 + float(i) * r * 0.3, wp.y - r * 0.16), ammo, 2.0, true)

# -------------------------------------------------- 公共绘制辅助

## 世界朝向映射到屏幕方向（纵向乘 K，与地面一致）
func _screen_dir() -> Vector2:
	return _sdir(Vector2.RIGHT.rotated(turret_angle))

func _sdir(world_dir: Vector2) -> Vector2:
	var sd: Vector2 = Iso.dir(world_dir)
	if sd.length() < 0.001:
		return Vector2(0, -1)
	return sd.normalized()

## 以世界坐标定义、朝 fwd_world 的立方形箱体；返回顶面中心（屏幕坐标）
func _oriented_box(c: Vector2, fwd_world: Vector2, length: float, width: float, h: float,
		body: Color, top: Color) -> Vector2:
	var f := fwd_world.normalized()
	if f.length() < 0.001:
		f = Vector2.RIGHT
	var rg := Vector2(-f.y, f.x)
	var hl := length * 0.5
	var hw := width * 0.5
	var base := PackedVector2Array([
		Iso.dir(c + f * hl - rg * hw),   # 前右
		Iso.dir(c + f * hl + rg * hw),   # 前左
		Iso.dir(c - f * hl + rg * hw),   # 后左
		Iso.dir(c - f * hl - rg * hw)])  # 后右
	var up := Vector2(0, -h)
	var shades: Array[float] = [0.10, 0.30, 0.20, 0.34]
	for i in range(4):
		var a := base[i]
		var b := base[(i + 1) % 4]
		draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), body.darkened(shades[i]))
	var cap := PackedVector2Array([base[0] + up, base[1] + up, base[2] + up, base[3] + up])
	draw_colored_polygon(cap, top)
	Iso.outline(self, [cap[0], cap[1], cap[2], cap[3]], body.darkened(0.5), 1.0)
	return Iso.dir(c) + up

## 车体面板缝线
func _draw_box_seams(c: Vector2, fwd_world: Vector2, length: float, width: float, h: float, seam: Color) -> void:
	var f := fwd_world.normalized()
	var rg := Vector2(-f.y, f.x)
	for s: float in [-1.0, 1.0]:
		var a := Iso.dir(c + f * (length * 0.5) + rg * (width * 0.5 * s)) + Vector2(0, -h)
		var b := Iso.dir(c - f * (length * 0.5) + rg * (width * 0.5 * s)) + Vector2(0, -h)
		draw_line(a, b, seam, 1.0, true)

## 履带：低矮箱体 + 滚动纹路
func _draw_track(c: Vector2, fwd_world: Vector2, length: float, width: float, h: float, dark: Color, edge: Color) -> void:
	var top := _oriented_box(c, fwd_world, length, width, h, dark, edge)
	var f := fwd_world.normalized()
	var rg := Vector2(-f.y, f.x)
	var n := 8
	var phase := fmod(_track_phase, 1.0)
	for i in range(n):
		var t := (float(i) + phase) / float(n)
		var p := c + f * ((t - 0.5) * length)
		var a := p + rg * (width * 0.42)
		var b := p - rg * (width * 0.42)
		draw_line(Iso.dir(a) + Vector2(0, -h - 0.2), Iso.dir(b) + Vector2(0, -h - 0.2),
			dark.lightened(0.18), maxf(1.0, width * 0.07), true)
	draw_circle(Iso.dir(c) + Vector2(0, -h * 0.5), maxf(1.2, width * 0.14), edge)

## 炮口火光
func _draw_muzzle_flash(muzzle: Vector2, dir: Vector2, size: float, col: Color) -> void:
	var k: float = clampf(_muzzle / 0.09, 0.0, 1.0)
	var rg := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		muzzle + dir * (size * 1.3), muzzle + rg * (size * 0.55 * k), muzzle - dir * (size * 0.1), muzzle - rg * (size * 0.55 * k)]),
		Color(1.0, 0.92, 0.62, 0.85 * k))
	draw_circle(muzzle + dir * (size * 0.2), size * 0.5 * k, Color(1.0, 0.75, 0.35, 0.9 * k))
	draw_circle(muzzle, size * 0.32 * k, Color(1.0, 1.0, 0.9, 0.95 * k))
	if col.a > 0.0:
		pass

## 低血冒烟
func _draw_smoke(r: float, hp_frac: float) -> void:
	var sev: float = clampf((0.42 - hp_frac) / 0.42, 0.0, 1.0)
	var top := -r * (2.3 if is_air else 1.6)
	for i in range(3):
		var ph := fmod(_anim * 0.8 + float(i) * 0.33, 1.0)
		var yy := top - ph * r * 1.8
		var xx := sin((_anim + float(i)) * 2.0) * r * 0.3
		var rad: float = r * (0.16 + ph * 0.45) * (0.6 + sev)
		# Restart each puff invisibly so the loop never appears to teleport.
		var birth_fade := smoothstep(0.0, 0.14, ph)
		var al: float = birth_fade * (1.0 - ph) * 0.32 * (0.4 + sev)
		draw_circle(Vector2(xx, yy), rad, Color(0.32, 0.32, 0.34, al))

## 选中 / 悬停标识：地面菱形描边 + 屏幕对齐四角括号（红警2 观感）
## 闪避 buff 的「烟幕环绕」：紫灰色雾团绕单位缓慢旋绕，并带轻微升腾的雾气。
func _draw_buff_smoke(base_c: Vector2, rr: float, col: Color, seed_i: int) -> void:
	var smoke_col := Color(col.r * 0.62 + 0.30, col.g * 0.62 + 0.30, col.b * 0.62 + 0.30)
	for m in range(9):
		var a3: float = _anim * 0.65 + TAU * float(m) / 9.0 + float(seed_i) * 0.7
		var wob: float = 0.5 + 0.5 * sin(_anim * 1.25 + float(m) * 2.1)
		var rad: float = rr * (0.70 + 0.36 * wob)
		var cp := base_c + Iso.dir(Vector2(cos(a3) * rad, sin(a3) * rad))
		draw_circle(cp, 4.0 + 3.4 * wob, Color(smoke_col.r, smoke_col.g, smoke_col.b, 0.10 + 0.14 * wob))
	for m in range(3):
		var ph: float = fmod(_anim * 0.45 + float(m) / 3.0 + float(seed_i) * 0.2, 1.0)
		var yy: float = base_c.y - ph * rr * 1.7
		var xx: float = sin((_anim + float(m)) * 1.7 + float(seed_i)) * rr * 0.6
		var r2: float = rr * (0.24 + 0.36 * ph)
		var birth_fade := smoothstep(0.0, 0.14, ph)
		draw_circle(Vector2(xx, yy), r2, Color(smoke_col.r, smoke_col.g, smoke_col.b, birth_fade * (1.0 - ph) * 0.22))

## 增益/减益光环：每种 buff 一圈彩色椭圆环（用户口径配色，势力无关）。
## 绘制在单位本体之下（_draw 顶部调用）。双色 buff（暴击）画红+蓝两圈；
## 回血叠上升十字，瘫痪叠环上旋转警示点。
## Target-side EMP feedback, drawn over the model and outside its selection mask.
func _draw_emp_arcs() -> void:
	if _dead or embarked_in!=null:return
	var center:=Iso.dir(art_center()-global_position)
	var phase:=floorf(_anim*14.0)+float(_seed%71)
	for strand in 2:
		var points:=PackedVector2Array()
		for i in 7:
			var progress:=float(i)/6.0
			var wave:=sin(phase*1.7+strand*4.1+i*2.3)
			var height:=(strand-0.5)*0.42+wave*0.28
			points.append(center+Vector2((progress-0.5)*1.65,height)*radius)
		draw_polyline(points,Color(0.30,0.52,1.0,0.84),2.6,true)
		draw_polyline(points,Color(0.84,0.95,1.0),1.1,true)

func _draw_buffs(r: float) -> void:
	if buffs.is_empty():
		return
	var base_c := Vector2(0.0, r * 0.5)
	var idx := 0
	for b in buffs:
		if float(b.get("left",0))<=0:continue
		var kind := str(b.get("kind", ""))
		if kind=="tesla_emp":continue # The electric arcs are drawn above the vehicle.
		var col: Color = b.get("col", Color.WHITE)
		var col2: Color = b.get("col2", Color(0, 0, 0, 0))
		var rr: float = r * (1.50 + 0.42 * float(idx))
		var pulse: float = 0.5 + 0.5 * sin(_anim * 3.0 + float(idx) * 1.3)
		if kind == "dodge":
			# 闪避：淡紫环 + 烟幕环绕
			Iso.outline(self, Iso.ell(base_c, rr, rr), Color(col.r, col.g, col.b, 0.18 + 0.18 * pulse), 2.0)
			_draw_buff_smoke(base_c, rr, col, idx)
		else:
			Iso.outline(self, Iso.ell(base_c, rr, rr), Color(col.r, col.g, col.b, 0.30 + 0.36 * pulse), 2.5)
			if col2.a > 0.0:
				Iso.outline(self, Iso.ell(base_c, rr * 1.18, rr * 1.18), Color(col2.r, col2.g, col2.b, 0.30 + 0.36 * pulse), 2.5)
			var ang: float = _anim * 1.6 + float(idx) * 1.9
			var p := base_c + Iso.dir(Vector2(cos(ang) * rr, sin(ang) * rr))
			draw_circle(p, 2.6, Color(col.r, col.g, col.b, 0.55 + 0.35 * pulse))
		if kind == "regen":
			for j in range(2):
				var ph: float = fmod(_anim * 0.55 + float(j) * 0.5, 1.0)
				var py: float = base_c.y - ph * r * 2.2
				var px: float = sin((_anim + float(j)) * 2.1) * r * 0.6
				var ca: float = (1.0 - ph) * 0.7
				draw_line(Vector2(px - 3.0, py), Vector2(px + 3.0, py), Color(col.r, col.g, col.b, ca), 1.6)
				draw_line(Vector2(px, py - 3.0), Vector2(px, py + 3.0), Color(col.r, col.g, col.b, ca), 1.6)
		elif kind == "stun":
			for j in range(3):
				var a2: float = _anim * 2.2 + TAU * float(j) / 3.0
				var q := base_c + Iso.dir(Vector2(cos(a2) * rr * 0.82, sin(a2) * rr * 0.82))
				draw_circle(q, 2.0, Color(col.r, col.g, col.b, 0.9))
		idx += 1

## 选择环 / 落地环的贴地中心：始终落在单位与地面接触的位置（对齐阴影与素材脚底）
func _ground_center(r: float) -> Vector2:
	if is_air:
		# 空中单位：环贴在地面投影（有 RA2 素材时与阴影一致，否则用程序化阴影高度）
		return Vector2(0, r * 0.4 if not _ra2.is_empty() else r * 2.1)
	if not _ra2.is_empty():
		return Vector2(0, r * 0.4)
	match str(data.get("role", "vehicle")):
		"infantry":
			return Vector2(0, r * 0.55)
		"mech":
			return Vector2(0, r * 0.62)
		"beast":
			return Vector2(0, r * 0.45)
		"harvester":
			return Vector2(0, r * 0.4)
		_:
			return Vector2(0, r * 0.4)

func _draw_selection(r: float) -> void:
	if not (selected or hovered):
		return
	var gc := _ground_center(r)
	if not selected:
		Iso.outline(self, Iso.ell(gc, r * 1.3, r * 1.3), Color(0.7, 0.95, 0.75, 0.45), 1.0)
		return
	var t := float(Time.get_ticks_msec() % 1000) / 1000.0
	var pulse: float = 0.7 + 0.3 * sin(t * TAU)
	var ring_color:=Color(0.55,1.0,0.65,0.95)
	if yuriko_model!=null: ring_color=preload("res://scripts/units/yuriko.gd").COLORS[yuriko_model.outfit]
	Iso.outline(self, Iso.ell(gc, r * 1.35, r * 1.35), ring_color, 2.0)
	var col := Color(ring_color,pulse) if yuriko_model!=null else Color(0.45,1.0,.6,pulse)
	var bw: float = maxf(13.0, r * 1.7)
	var top: float = -r * (3.9 if is_air else 3.0)
	var bot: float = r * 1.0
	var arm: float = maxf(4.0, r * 0.5)
	draw_line(Vector2(-bw, top), Vector2(-bw + arm, top), col, 2.0)
	draw_line(Vector2(-bw, top), Vector2(-bw, top + arm), col, 2.0)
	draw_line(Vector2(bw, top), Vector2(bw - arm, top), col, 2.0)
	draw_line(Vector2(bw, top), Vector2(bw, top + arm), col, 2.0)
	draw_line(Vector2(-bw, bot), Vector2(-bw + arm, bot), col, 2.0)
	draw_line(Vector2(-bw, bot), Vector2(-bw, bot - arm), col, 2.0)
	draw_line(Vector2(bw, bot), Vector2(bw - arm, bot), col, 2.0)
	draw_line(Vector2(bw, bot), Vector2(bw, bot - arm), col, 2.0)
	# Selected stance markers: guard square, patrol dot, aggressive chevron.
	if hold_position:
		draw_rect(Rect2(-3.0, bot + 3.0, 6.0, 6.0), Color(0.6, 0.85, 1.0, 0.9))
	elif patrolling and patrol_points.size() == 2:
		draw_circle(Vector2(0, bot + 6.0), 3.5, Color(1.0, 0.85, 0.4, 0.9))
	elif fire_stance == "none":
		draw_line(Vector2(-4.0, bot + 6.0), Vector2(4.0, bot + 6.0), Color(0.95, 0.45, 0.45, 0.9), 2.0)
	if fire_stance == "free" and not hold_position:
		# A patrol can retain aggressive mode; keep its dot visible beside the arrow.
		var marker_x := 10.0 if patrolling and patrol_points.size() == 2 else 0.0
		var attack_col := Color(1.0, 0.65, 0.25, 0.95)
		draw_line(Vector2(marker_x - 4.0, bot + 9.0), Vector2(marker_x, bot + 3.0), attack_col, 2.0)
		draw_line(Vector2(marker_x, bot + 3.0), Vector2(marker_x + 4.0, bot + 9.0), attack_col, 2.0)

# ------------------------------------------------------------------ 技能（红警3 式）

## 每帧推进技能冷却与限时增益（buff 也在这里结算，无主动技能的单位同样需要）
func _tick_skills(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(4)
	# Timers only update their remaining durations. Publish all stat changes once below.
	_tick_buffs(delta, false)
	if _has_active_skills:
		for ab in skills:
			ab.tick(delta)
	_recompute_bonuses()

## 汇总限时 buff，重算攻/防/速（单一数据源：技能 buff 已在 _cast_ability 落地为 buff，避免重复计入）
func _recompute_bonuses() -> void:
	_recompute_base_bonuses()
	if unit_id == "E2":
		bonuses.attack_bonus*=preload("res://scripts/units/expansion_2_infantry.gd").attack(self)
	move_speed*=preload("res://scripts/units/progression_expansion.gd").speed(self)
	if special.has("commando_hero_v2") and special.commando_hero_v2.has("rhythm_left"):move_speed*=1.25
	if special.has("peregrine"):
		move_speed+=_base_speed*preload("res://scripts/units/peregrine.gd").speed_bonus(self)*(1.0-clampf(buff_value("electric_slow"),0.0,0.8))
	if unit_id == "ORCA" or unit_id == "BEAG":
		move_speed+=_base_speed*preload("res://scripts/units/peregrine_command.gd").speed_bonus(self)*(1.0-clampf(buff_value("electric_slow"),0.0,0.8))
	if side == "ally":
		move_speed*=preload("res://scripts/expedition/rules.gd").speed_factor(self)
	if special.has(Furnace.STANCE):
		bonuses.attack_bonus *= float(GameData.get_skill(Furnace.ACTIVE).attack_by_rank[special[Furnace.STANCE].rank])
		move_speed = _base_speed * float(GameData.get_skill(Furnace.ACTIVE).speed_by_rank[special[Furnace.STANCE].rank])

func _recompute_base_bonuses() -> void:
	# Most actors have no temporary effects. Apply the same base/deployment values
	# directly, retaining live training and speed-floor changes during battle.
	if buffs.is_empty() and not special.has("slope_speed"):
		bonuses.attack_bonus = _base_atk * (_deploy_atk if _deployed else 1.0)
		var armor := _deploy_def if _deployed else 1.0
		if _deployed and unit_id in DEPLOYING_INFANTRY: armor *= Training.scale(self)
		bonuses.defense_bonus = _base_def * armor
		move_speed = TankHero.speed(self,_base_speed)
		return
	# One pass, same per-kind multiplication order. Do not cache across ticks:
	# effects can expire, be dispelled or change during another actor's attack.
	var attack := 1.0
	var defense := 1.0
	var speed := 1.0
	var slow := 0.0
	var court_slow := 0.0
	for buff in buffs:
		var value := float(buff.get("value",0.0))
		match str(buff.get("kind","")):
			"attack", "red_alert_attack": attack *= 1.0 + value
			"defense": defense *= 1.0 + value
			"speed": speed *= 1.0 + value
			"electric_slow": slow += value
			"leizhu_slow_20","leizhu_slow_25","leizhu_slow_30","leizhu_slow_35": court_slow=maxf(court_slow,value)
	bonuses["attack_bonus"] = _base_atk * attack * (_deploy_atk if _deployed else 1.0)
	bonuses["defense_bonus"] = _base_def * defense * (_deploy_def * (Training.scale(self) if unit_id in DEPLOYING_INFANTRY else 1.0) if _deployed else 1.0)
	move_speed = _base_speed * speed * (0.0 if _deployed else 1.0)
	if special.has("slope_speed"): move_speed *= 1.0 + float(special.slope_speed)
	move_speed *= 1.0 - clampf(maxf(slow,court_slow),0.0,0.8)
	move_speed=TankHero.speed(self,move_speed)

# ------------------------------------------------------------------ 增益 / 减益（buff）

## 施加 / 刷新一个 buff。同 kind 取「更长的剩余时间 + 更高的数值」。
func add_buff(p_kind: String, p_dur: float, p_value: float, p_name: String = "") -> void:
	if _dead or p_kind == "" or p_dur <= 0.0:
		return
	var spec: Dictionary = BUFF_KINDS.get(p_kind, {})
	var label := p_name if p_name != "" else str(spec.get("name", p_kind))
	for b in buffs:
		if str(b.get("kind", "")) == p_kind:
			b["left"] = maxf(float(b.get("left", 0.0)), p_dur)
			b["dur"] = maxf(float(b.get("dur", p_dur)), p_dur)
			b["value"] = maxf(float(b.get("value", 0.0)), p_value)
			if p_kind!="tesla_emp":_recompute_bonuses()
			queue_redraw()
			return
	buffs.append({
		"kind": p_kind, "name": label, "left": p_dur, "dur": p_dur, "value": p_value,
		"col": spec.get("col", Color.WHITE), "col2": spec.get("col2", Color(0, 0, 0, 0)),
		"debuff": (spec.get("debuff", false) == true),
	})
	if p_kind!="tesla_emp":_recompute_bonuses()
	queue_redraw()

func has_buff(kind: String) -> bool:
	for b in buffs:
		if str(b.get("kind", "")) == kind:
			return true
	return false

## 某 kind 的数值之和（用于闪避/命中/暴击/冷却/回血等概率或比率型效果）
func buff_value(kind: String) -> float:
	var v := DomainCards.passive_bonus(self,DomainCards.ANCHOR) if kind=="cooldown" and passive.get("id")==DomainCards.ANCHOR else 0.0
	for b in buffs:
		if str(b.get("kind", "")) == kind:
			v += float(b.get("value", 0.0))
	if kind=="cooldown":
		var haste:=buff_value("red_alert_haste")
		if haste>0.0:v=1.0-(1.0-v)/(1.0+haste)
	return v

## 某 kind 的乘算倍率 ∏(1+value)（用于攻/防/速）
func buff_mult_scalar(kind: String) -> float:
	var m := 1.0
	for b in buffs:
		if str(b.get("kind", "")) == kind:
			m *= 1.0 + float(b.get("value", 0.0))
	return m

func clear_buff(kind: String) -> void:
	for i in range(buffs.size() - 1, -1, -1):
		if str(buffs[i].get("kind", "")) == kind:
			buffs.remove_at(i)
	_recompute_bonuses()
	queue_redraw()

## 倒计时推进 + 回血结算；过期移除
func _tick_buffs(delta: float, refresh_bonuses := true) -> void:
	if buffs.is_empty():
		return
	var changed := false
	for i in range(buffs.size() - 1, -1, -1):
		var b: Dictionary = buffs[i]
		var kind := str(b.get("kind", ""))
		if kind == "regen" and hp < max_hp:
			heal(float(b.get("value", 0.0)) * max_hp * delta)
		b["left"] = float(b.get("left", 0.0)) - delta
		if float(b["left"]) <= 0.0:
			buffs.remove_at(i)
			changed = changed or kind!="tesla_emp"
	if changed and refresh_bonuses:
		_recompute_bonuses()
	if changed or preload("res://scripts/units/grizzly_visual_refresh.gd").refresh(self):queue_redraw()

## 供 HUD 直接渲染的条目（文案在单位侧生成，UI 保持哑）
# Presentation only: never store the full tooltip rows or serialize these fields.
var world_status_icons:Array=[]
var world_status_due: int = -1
var world_status_phase: int = -1

func buff_entries() -> Array:
	if _dead or hp<=0 or embarked_in!=null:return []
	var out: Array = preload("res://scripts/units/expansion_visual.gd").entries(self)
	if excluded_from_army_selection and side == "ally":
		out.push_front({"id":"army_exclusion", "kind":"army_exclusion", "icon":"army_exclusion", "name":"已从全选中排除", "text":"全选作战单位时会跳过此单位。再次点击「排除」即可恢复。", "col":Color("ffcc67")})
	if special.has("tanya_flash_left"):out.append(preload("res://scripts/units/expansion_visual.gd").row("闪光脱离 · 停止开火",special.tanya_flash_left,true,"hourglass"))
	if special.has("boris_command") or special.get("academy_hero")=="BORIS":out.append_array(preload("res://scripts/units/boris_command.gd").entries(self))
	if special.has("boris_radio_shield") or special.get("academy_hero")=="BORIS":out.append_array(preload("res://scripts/units/boris_radio.gd").entries(self))
	if special.has("peregrine"):out.append_array(preload("res://scripts/units/peregrine.gd").entries(self))
	if special.has("leizhu"):out.append_array(preload("res://scripts/units/leizhu.gd").entries(self))
	if special.has("leizhu") or special.has("leizhu_control"):out.append_array(preload("res://scripts/units/leizhu_command.gd").entries(self))
	if unit_id in ["ORCA","BEAG"]:out.append_array(preload("res://scripts/units/peregrine_command.gd").entries(self))
	out.append_array(preload("res://scripts/units/progression_expansion_2.gd").entries(self))
	if special.has("commando_hero_v2"):out.append_array(preload("res://scripts/units/expansion_2_commandos.gd").entries(self))
	for b in buffs:
		if float(b.get("left",0))<=0:continue
		var kind := str(b.get("kind", ""))
		var val := float(b.get("value", 0.0))
		var nm := str(b.get("name", ""))
		var spec: Dictionary = BUFF_KINDS.get(kind, {})
		var sh := str(spec.get("short", nm))
		var txt := nm
		match kind:
			"cooldown":
				txt = "冷却-%d%%" % int(round(val * 100.0))
			"regen":
				txt = "回血%.1f%%/s" % (val * 100.0)
			"stun", "tesla_emp":
				txt = nm
			_:
				txt = "%s+%d%%" % [sh, int(round(val * 100.0))]
		out.append({
			"kind": kind, "text": txt, "name": nm,
			"left": maxf(0.0, float(b.get("left", 0.0))),
			"dur": maxf(0.01, float(b.get("dur", 1.0))),
			"col": b.get("col", Color.WHITE), "col2": b.get("col2", Color(0, 0, 0, 0)),
			"debuff": (b.get("debuff", false) == true),
		})
	preload("res://scripts/ui/unit_status.gd").append_native(self,out)
	preload("res://scripts/expedition/rules.gd").append_status(self,out)
	return preload("res://scripts/ui/unit_status.gd").normalize(out,true)

## 汇总当前所有「处于激活状态」技能对某项属性的倍率
func _ability_mult(token: String) -> float:
	var m := 1.0
	for ab in skills:
		if ab.is_active() and ab.effect_has(token):
			m *= 1.0 + ab.value * Training.card_scale(self)
	return m

func ability_count() -> int:
	return skills.size()

func ability_at(i: int) -> Ability:
	if i < 0 or i >= skills.size():
		return null
	return skills[i]

func ability_ready(i: int) -> bool:
	if special.has("leizhu") and preload("res://scripts/units/leizhu_safety.gd").stopped(self):return false
	if special.get("academy_hero")=="TANY" and preload("res://scripts/units/tanya_talents.gd").locked(self):return false
	if special.has("hero_wreck"):return false
	var ab: Ability = ability_at(i)
	if ab!=null and ab.id=="yuriko_burst":return preload("res://scripts/units/yuriko.gd").ready(self,"burst")
	if ab!=null and ab.id=="drone_auto_hunt":return preload("res://scripts/units/expansion_2_drone.gd").enabled(self)
	if ab!=null and GameData.get_skill(ab.id).get("expansion",false):return preload("res://scripts/units/progression_expansion.gd").ready(self,ab)
	if ab!=null and ab.id==Furnace.ACTIVE:return Furnace.can_switch(self)
	if ab!=null and ab.id in DomainCards.ACTIVE:return ab.ready() and DomainCards.ready(self,ab.id)
	if ab!=null and ab.id==ReaperSplit.ID:return ReaperSplit.engaged(self)
	if ab!=null and ab.id.begins_with("allied_soviet_"):return preload("res://scripts/units/ra3_soviet.gd").ability(self).ready
	if ab!=null and ab.id in [Ra3Expansion.BEAM,Ra3Expansion.TOGGLE]:return Ra3Expansion.info(self).ready
	if ab != null and ab.id == Ra3Mirage.SKILL: return Ra3Mirage.info(self).ready
	if ab != null and ab.id=="ap_twin":
		return ab.ready() and not special.get("soviet_mode",false) and not special.has("twin_pending") and not special.has("twin_left")
	if is_native_ability(i):
		return not _dead and hp > 0.0 and not is_queued_for_deletion() and embarked_in == null and _stun_timer <= 0.0 and not repairing and not AlliedAbilities.frozen(self)
	return ab != null and ab.ready()

func ability_info(i: int) -> Dictionary:
	var ab: Ability = ability_at(i)
	if ab == null:
		return {}
	if ab.id=="yuriko_burst":
		var left := float(special.get("psi_cd_burst",0))
		var total:=preload("res://scripts/units/yuriko.gd").cooldown_duration(self,"burst")
		return {"id":ab.id,"name":ab.display_name,"desc":ab.desc,"ready":ability_ready(i),"cd_left":left,"cooldown":total,"cd_frac":left/total,"active":false}
	if ab.id==Convoy.Cards.PRESS and special.has("convoy"):
		var info:=preload("res://scripts/units/progression_expansion.gd").info(self,ab)
		var cost:float=.25*special.convoy.base_hold
		info.name+=" · 热锭" if cargo>=cost else " · 冷锭"
		info.desc+="\n矿量 %d%% · 可发热锭 %d 枚 · %s"%[roundi(cargo*100/maxf(1,special.convoy.base_hold)),floori(cargo/maxf(.01,cost)),("每发消耗原仓 25%" if cargo>=cost else "距热锭还差 %s 矿"%String.num(cost-cargo,1))]
		return info
	if ab.id=="drone_auto_hunt":return preload("res://scripts/units/expansion_2_drone.gd").info(self)
	if GameData.get_skill(ab.id).get("expansion",false):return preload("res://scripts/units/progression_expansion.gd").info(self,ab)
	if ab.id.begins_with("allied_"): return AlliedAbilities.info(self, ab)
	if ab.id==Furnace.ACTIVE:
		return {"id":ab.id,"name":"起身" if special.has(Furnace.STANCE) else "卧倒","ready":ability_ready(i),"desc":GameData.get_skill(ab.id).desc,"cooldown":ab.cooldown,"cd_left":ab.cd_left,"cd_frac":ab.cd_frac(),"active":special.has(Furnace.STANCE),"toggle":true}
	if ab.id=="ap_slope":
		var rank:int=BattleRequest.combat_context.get("card_ranks",{}).get(ab.id,0)
		return {"id":ab.id,"name":ab.display_name,"desc":GameData.get_skill(ab.id).desc+"\n本级正面减伤 %s%%，起步加速 %d%%。" % [String.num(ab.value*100,1),roundi(FactionCards.slope_speed(rank)*100)],
			"ready":ability_ready(i),"cd_left":ab.cd_left,"cooldown":ab.cooldown,"cd_frac":ab.cd_frac(),"active":special.has("slope_left")}
	if ab.id=="ap_twin":
		var rank:=clampi(int(BattleRequest.combat_context.get("card_ranks",{}).get(ab.id,0)),0,3)
		var pending:=special.has("twin_pending")
		return {"id":ab.id,"name":ab.display_name+(" · 待开炮" if pending else ""),"desc":GameData.get_skill(ab.id).desc+"\n本级 "+FactionCards.twin_summary(rank)+"，右炮增伤 %s%%。" % String.num(ab.value*100,1),
			"ready":ability_ready(i),"cd_left":ab.cd_left,"cooldown":ab.cooldown,"cd_frac":ab.cd_frac(),"active":pending or special.has("twin_left")}
	if is_native_ability(i):
		if ab.id == "miner_auto_harvest":
			return {"id": ab.id, "name": "自动采矿：" + ("开" if auto_harvest_enabled else "关"),
				"desc": ab.desc, "ready": ability_ready(i), "cd_left": 0.0, "cooldown": 0.0,
				"cd_frac": 0.0, "active": auto_harvest_enabled, "toggle": true, "glyph": "harvest"}
		var deployment := ab.id == "ggi_deploy"
		var enabled := _deployed if deployment else hold_position
		return {"id": ab.id, "name": ("收起导弹" if enabled else "部署导弹") if deployment else ("解除固守" if enabled else "固守"),
			"desc": ab.desc, "ready": ability_ready(i), "cd_left": 0.0, "cooldown": 0.0,
			"cd_frac": 0.0, "active": enabled, "toggle": true, "glyph": "deploy" if deployment else "guard"}
	return {
		"id": ab.id, "name": ab.display_name, "desc": ab.desc,
		"ready": ab.ready(), "cd_left": ab.cd_left, "cooldown": ab.cooldown,
		"cd_frac": ab.cd_frac(), "active": ab.is_active()
	}

func passive_name() -> String:
	return str(passive.get("name", ""))

func passive_desc() -> String:
	if passive.is_empty(): return ""
	var definition:=GameData.get_skill(passive.id)
	var value:=float(passive.get("value",0))
	if not definition.has("allowed_units"): value*=Training.card_scale(self)
	var text := MetaProgress.Academy.skill_description(definition,_equipped_card_rank(passive.id),value)
	var progress := preload("res://scripts/rules/field_commission.gd").progress_text(self)
	return text + ("\n" + progress if not progress.is_empty() else "")

func _equipped_card_rank(id:String) -> int:
	return int(BattleRequest.combat_context.get("card_ranks",{}).get(id,0)) if side=="ally" else 0

func equipped_active_description(ab:Ability) -> String:
	var definition:=GameData.get_skill(ab.id)
	var power:=1.0 if definition.has("allowed_units") else Training.card_scale(self)
	var duration:=ab.duration*power if ab.effect_has("stun") else ab.duration
	return MetaProgress.Academy.skill_description(definition,_equipped_card_rank(ab.id),ab.value*power,duration,ab.cooldown)

func has_skill_bar() -> bool:
	return not _dead and hp > 0.0 and (embarked_in == null or preload("res://scripts/units/expansion_2_drone.gd").enabled(self))

## 释放第 i 个主动技能；成功返回 true
func use_ability(i: int, point := Vector2.INF) -> bool:
	if special.has("leizhu") and preload("res://scripts/units/leizhu_safety.gd").stopped(self):return false
	if special.has("hero_wreck"):return false
	if _reject_powered_command():
		return false
	var ab: Ability = ability_at(i)
	if ab == null or not ability_ready(i):
		return false
	if ab.id=="yuriko_burst":return preload("res://scripts/units/yuriko.gd").burst(self)
	if ab.id==Convoy.Cards.CREW:return Convoy.Cards.picker(self,ab)
	if ab.id==Convoy.Cards.PRESS:return Convoy.Cards.cast_press(self,ab,point)
	if ab.id in PoolCards.ACTIVES: return PoolCards.cast(self, ab, point)
	if ab.id=="drone_auto_hunt":return preload("res://scripts/units/expansion_2_drone.gd").toggle(self)
	if GameData.get_skill(ab.id).get("expansion",false):return preload("res://scripts/units/progression_expansion.gd").cast(self,ab,point)
	if ab.id==Furnace.ACTIVE: return Furnace.cast(self,ab)
	if ab.id==ReaperSplit.ID:
		ReaperSplit.arm(_battle_world(),self)
		return true
	if ab.id.begins_with("allied_"): return AlliedAbilities.use(self, ab.id)
	if is_native_ability(i):
		if ab.id == "miner_auto_harvest":
			auto_harvest_enabled = not auto_harvest_enabled
			auto_harvest_idle = 0.0
			return true
		if ab.id == "ggi_deploy":
			return deploy()
		if hold_position:
			order_stop()
		else:
			order_guard()
			fire_stance = "free"
			_cancel_burst()
			attack_target = null
			_refresh_target()
		queue_redraw()
		return true
	if ab.id in ["ap_decoy","ap_twin","ap_buoy","ap_slope"]:
		if not AlliedAbilities.alive(self) or embarked_in!=null or _stun_timer>0 or repairing or AlliedAbilities.frozen(self) or not FactionCards.cast(self,ab,point): return false
	if ab.id in ["ap_tesla_chain","ap_shock_pulse"] and not preload("res://scripts/units/electric_cards.gd").cast(self,ab): return false
	if ab.id in DomainCards.ACTIVE and not DomainCards.cast(self,ab):return false
	if unit_id == "R3REAPER": ReaperSplit.clear(self)
	ab.trigger_cooldown(maxf(0.6, Training.card_scale(self)))
	_cast_ability(ab)
	queue_redraw() # Active effects are shown by the shared status markers.
	queue_redraw()
	return true

func power_disabled_reason() -> String:
	return powered_unit.reason(self)

func command_voice_kind(kind: String) -> String:
	if not power_disabled_reason().is_empty():
		return "select_deactivated" if kind == "select" else ""
	if unit_id=="YURIKO":
		if kind=="select" and special.has("psi_hurt_voice_left"):return "select_under_fire"
		if kind=="select" and is_instance_valid(attack_target):return "select_battle"
		if kind=="move" and attack_move:return "move_attack"
	if unit_id == "BORIS" and kind == "attack" and is_instance_valid(attack_target) and attack_target is Building:
		return "secondary_attack"
	if Ra3Mirage.handles(self): return Ra3Mirage.voice_kind(self, kind)
	if Ra3Expansion.handles(self):return Ra3Expansion.voice_kind(self,kind)
	return kind

func _reject_powered_command() -> bool:
	var reason := power_disabled_reason()
	if reason.is_empty():
		return false
	if side == "ally":
		Events.emit_message(display_name + " · " + reason, Color(1.0, 0.8, 0.5))
		Ra2Sfx.play_voice(data, "select_deactivated", global_position, 500)
	return true

func _cast_ability(ab: Ability) -> void:
	for token in ab.effects():
		match token:
			"heal":
				_heal_around(ab.radius, ab.value * Training.card_scale(self))
			"stun":
				_stun_around(ab.radius, ab.duration * Training.card_scale(self))
			"deploy":
				_toggle_deploy()
			_:
				# 任意 "<kind>_buff" → 化为可查看/可环绕的 buff（自身或范围内友军）
				if token.ends_with("_buff"):
					var kind := token.substr(0, token.length() - 5)
					_grant_buff(kind, ab.duration, ab.value * Training.card_scale(self), ab.radius)

## 形态切换（RA2 美国大兵式）：部署/卧倒。再点一次起身。
func _toggle_deploy() -> void:
	deploy()

## 是否具备部署（卧倒）能力：
##   · rules.ini `Deployer=yes`（RA2 事实源，build.mjs/faction.mjs → data.deployer）
##   · 或 art.ini 序列里有卧倒姿态帧（`Deployed=` → _deploy_frame）
##   · 或技能栏里有 deploy 效果的主技能（ap_deploy）
func deploy_building_id() -> String:
	var raw: Dictionary = GameData.ra2_source_units.get(unit_id, {}).get("extra", {})
	var bid := str(data.get("deploys_into",raw.get("DeploysInto", "")))
	return bid if not bid.is_empty() and not GameData.get_building(bid).is_empty() else ""

func can_deploy() -> bool:
	if special.has("peregrine"):return preload("res://scripts/units/peregrine_defense.gd").rank(self)>=4 and not special.has("hero_wreck")
	if not deploy_building_id().is_empty():
		return true
	if logistics.capacity > 0 or logistics.ammo_max > 0:
		return true
	if (data.get("deployer", false) == true) or _deploy_frame >= 0:
		return true
	return _deploy_skill_index() >= 0

## 主技能里的部署槽位（技能栏第一个 deploy 效果技能），没有则 -1。
func _deploy_skill_index() -> int:
	for i in skills.size():
		var ab: Ability = skills[i]
		if ab != null and ab.effect_has("deploy"):
			return i
	return -1

func is_deployed() -> bool:
	return _deployed or special.has("psi_elapsed")

## 「单点释放主技能」：一次点击/一个热键切到卧倒（再点一次起身）。
## 命令栏「部署 (J)」、技能栏主技能、快捷键 J 全部汇到这里，
## 不再有第二条失效通道（旧版 battle.deploy_selected() 调 u.deploy()，而 Unit 没这个方法 → 点 D 永远无反应）。
func deploy() -> bool:
	if _dead or hp <= 0.0 or is_queued_for_deletion() or embarked_in != null:
		return false
	if unit_id=="YURI": return HollywoodInfantry.begin_pulse(self)
	if special.has("peregrine"):return preload("res://scripts/units/peregrine_service.gd").toggle(self)
	if not deploy_building_id().is_empty():
		var world := _battle_world()
		return world != null and world.deploy_construction_vehicle(self)
	if logistics.capacity > 0:
		return logistics.request_unload()
	if logistics.ammo_max > 0:
		return logistics.request_return()
	if not can_deploy():
		return false
	return set_deployed(not _deployed)

## 设置卧倒状态（幂等）：姿态帧、语音、战斗加成、静止一步到位。
func set_deployed(want: bool, notify_player := true) -> bool:
	if special.has("para_height"): return false
	if _deployed == want:
		return false
	if unit_id == "SCHP" and not logistics.SiegeChopper.begin(self, want):
		return false
	_deployed = want
	if unit_id=="SCHP" and not want:special.get("progression_v2",{}).erase("tractor_arm")
	if unit_id == "DESO":
		if not want:SovietSpecials.end_sampling(self)
		special.erase("rad_deployed_fired")
		_cd_timer = 0.0
	var navigation = _navigation_world()
	if navigation is Battle: navigation.notify_deployment_changed(self)
	elif navigation != null: navigation.notify_deployment_changed()
	crushable = data.get("deployed_crushable", _mv("crushable", false)) == true if _deployed else _mv("crushable", false) == true
	_local_traffic.reset()
	_cancel_burst()
	_fire_anim_time = -1.0
	_muzzle = 0.0
	_refresh_weapon_derived()
	# 语音：DeploySound / UndeploySound（rules.ini → voice.deploy / voice.undeploy）
	var vkind := "deploy" if _deployed else "undeploy"
	var world := _battle_world()
	var audible: bool = notify_player or (world != null and world.position_visible_to("ally", global_position))
	if audible and Ra2Sfx.has_voice(data, vkind):
		Ra2Sfx.play_voice(data, vkind, global_position, 100)
	# D 键与技能栏主技能共享同一状态；两者互不阻塞（D 是姿态指令，不占技能冷却）
	if _deployed:
		has_move_order = false
		velocity = Vector2.ZERO
	_recompute_bonuses()
	if notify_player and unit_id == "SCHP":
		Events.emit_message("武装直升机正在部署火炮" if want else "武装直升机正在收炮起飞", Color.SKY_BLUE)
	elif notify_player and _deployed:
		var stance := "部署导弹（反装甲/防空 · 近距盲区 · 无法移动）" if unit_id == "GGI" else "卧倒据守（火力↑ · 无法移动）"
		Events.emit_message("%s %s" % [display_name, stance], Color(0.62, 1.0, 0.72))
	elif notify_player:
		Events.emit_message("%s 起身" % display_name, Color(0.85, 0.92, 1.0))
	queue_redraw()
	return true

## 授予 buff：radius > 0 时为范围光环（对友军生效），否则仅自身
func _grant_buff(kind: String, dur: float, value: float, p_radius: float) -> void:
	if p_radius > 0.0:
		var group: String = "allies" if side == "ally" else "enemies"
		for n in get_tree().get_nodes_in_group(group):
			if is_instance_valid(n) and n.has_method("add_buff"):
				if global_position.distance_to(n.global_position) <= p_radius:
					n.add_buff(kind, dur, value)
	else:
		add_buff(kind, dur, value)

func _heal_around(r: float, frac: float) -> void:
	if r <= 0.0:
		heal(max_hp * frac,self,true)
		return
	var group: String = "allies" if side == "ally" else "enemies"
	for n in get_tree().get_nodes_in_group(group):
		if is_instance_valid(n) and n.has_method("heal"):
			if global_position.distance_to(n.global_position) <= r:
				n.heal(float(n.max_hp) * frac, self,true)

func _stun_around(r: float, dur: float) -> void:
	var group: String = BattleRequest.foes_group(side)
	for n in get_tree().get_nodes_in_group(group):
		if is_instance_valid(n) and n.has_method("stun"):
			if global_position.distance_to(n.global_position) <= r:
				n.stun(dur)

func stun(seconds: float, status: String="stun") -> void:
	if _dead:
		return
	if special.has("peregrine") and preload("res://scripts/units/peregrine_defense.gd").resist(self,seconds,status):return
	if special.get("academy_hero")=="BORIS":seconds=preload("res://scripts/units/boris_radio.gd").control_duration(self,seconds)
	_stun_timer = maxf(_stun_timer, seconds)
	add_buff(status, seconds, 0.0)
	queue_redraw()


var _shore_escape := Vector2.INF
var _shore_retry := 0.0

# A slide against traffic can push a ground unit a few pixels beyond the
# shoreline. Old saves can already start there. Walk only to a nearby bank
# through clear space; do not use this to cross a waterway.
func _recover_at_shore(dt: float) -> void:
	_shore_retry -= dt
	if _shore_escape.is_finite() and (global_position.distance_to(_shore_escape)>radius+18.0 or not _domain_ok(_shore_escape)):
		_shore_escape=Vector2.INF
	if not _shore_escape.is_finite() and _shore_retry <= 0.0:
		var world := _navigation_world()
		_shore_retry = 0.5
		for distance in range(6,ceili(radius)+19,6):
			for i in 16:
				var motion := Vector2.from_angle(TAU*i/16.0)*distance
				var landing := global_position + motion
				if world.path_service.is_blocked(landing, false, false, unit_id == "R3APOC"): continue
				if _domain_ok(landing) and move_with_traffic_exceptions(motion, true) == null:
					_shore_escape=global_position+motion
					break
			if _shore_escape.is_finite(): break
	velocity = Vector2.ZERO
	if not _shore_escape.is_finite(): return
	var step := global_position.direction_to(_shore_escape)*minf(move_speed*dt,global_position.distance_to(_shore_escape))
	var collision := move_with_traffic_exceptions(step)
	var recovered := _domain_ok(global_position)
	if collision != null or recovered or global_position.is_equal_approx(_shore_escape):
		_shore_escape=Vector2.INF
		_shore_retry=0.0
		_clear_field()
		if recovered and has_move_order:
			if ai_path_allowed(): _repath_now()
			else: special.ai_route_goal = move_target

## 移动域安全层：海军只在水面走、陆军不进水；同时处理岸边滑移。
## 所有原有 move_and_slide() 调用都改走这里，避免逐处遗漏。
func _move_water_safe() -> void:
	if special.has(FoundationTransit.ANCHOR) and not has_move_order:FoundationTransit.settle(self)
	# Also cover non-combat movement callers, e.g. stun/repair/logistics.
	if _deployed:
		velocity = Vector2.ZERO
		return
	# These stationary actors have neither shore recovery nor contact work.
	# Keep harvesters, moving orders, naval recovery and Apocalypse contacts live.
	if velocity.is_zero_approx() and not is_naval and unit_id != "R3APOC" and (is_air or (not is_harvester and not has_move_order)):
		return
	var dt := get_physics_process_delta_time()
	if dt <= 0.0:
		dt = 1.0 / 60.0
	var step := velocity * dt
	if not is_air and not is_naval and not step.is_zero_approx():
		var road_world=_navigation_world()
		if road_world!=null and road_world.allied_state.has("convoy_roads") and Convoy.Cards.blocks_step(road_world,global_position,global_position+step):
			velocity=Vector2.ZERO;return
	var can_recover := not is_naval and (is_harvester or has_move_order)
	if not is_air and (can_recover or not velocity.is_zero_approx()) and not _domain_ok(global_position + step):
		if can_recover and not _domain_ok(global_position):
			_recover_at_shore(dt)
			return
		if _domain_ok(global_position + Vector2(step.x, 0.0)):
			velocity = Vector2(step.x, 0.0) / dt
		elif _domain_ok(global_position + Vector2(0.0, step.y)):
			velocity = Vector2(0.0, step.y) / dt
		else:
			velocity = Vector2.ZERO
	# A stationary body must not be pushed by collision recovery alone.
	if special.get("academy_hero")=="HARV" and Convoy.crush(self,velocity*dt,dt):return
	if unit_id=="R3APOC" and preload("res://scripts/units/ra3_apocalypse_crush.gd").contact(self,velocity*dt,dt):return
	if not velocity.is_zero_approx():
		if unit_id!="R3APOC":OpenTopped.crush_contact(self)
		_slide_across_bridge_layers(dt)
	if is_naval:
		if _domain_ok(global_position):
			_last_water_pos = global_position
		elif _last_water_pos != Vector2.INF:
			global_position = _last_water_pos

# Player and allied AI units share space; the existing friendly infantry rule also applies. Boats can pass
# beneath a bridge deck. Exceptions apply only during this move, so ownership
# changes take effect immediately and other commands keep their own exceptions.
func can_roll_fences() -> bool:
	return not is_air and not is_naval and unit_id != "R3APOC" and _mv("crusher", false) == true

func _slide_across_bridge_layers(dt: float) -> void:
	var temporary := _traffic_collision_exceptions(velocity * dt, true)
	var before := position
	move_and_slide()
	if get_slide_collision_count() > 0 and can_roll_fences():
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			var fence := hit.get_collider()
			if is_instance_valid(fence) and WallArt.crushable_fence(fence) and not fence.is_dead():
				fence.receive_hit(999999.0, "crush", {}, self)
	_record_overpass_move(before)
	for other in temporary: remove_collision_exception_with(other)
	if special.has(FoundationTransit.ANCHOR) and FoundationTransit.parkable(self,_navigation_world(),position,0):special.erase(FoundationTransit.ANCHOR)

func move_with_traffic_exceptions(motion: Vector2, test_only := false) -> KinematicCollision2D:
	var temporary := _traffic_collision_exceptions(motion)
	var before := position
	var collision := move_and_collide(motion, test_only)
	if not test_only: _record_overpass_move(before)
	for other in temporary: remove_collision_exception_with(other)
	return collision

func _record_overpass_move(before: Vector2) -> void:
	if is_air or is_naval: return
	var world := _navigation_world()
	if world != null and world.ground is Ground and world.ground.overpass != null:
		world.ground.overpass.record_move(self, before)

func _traffic_collision_exceptions(motion: Vector2, sliding := false) -> Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(53)
	var world := _navigation_world()
	var travel := motion.length()
	var temporary: Array = []
	if world == null or world.path_service == null:
		return temporary
	var existing: Array = []
	var existing_loaded := false
	var drone_exit := unit_id=="DRON" and special.has("progression_v2")
	var expedition_transit:=FoundationTransit.enabled(self) and has_move_order and not _deployed
	var base_escape := special.has(preload("res://scripts/units/base_escape.gd").KEY)
	if drone_exit or base_escape or expedition_transit:
		existing = get_collision_exceptions()
		existing_loaded = true
	if drone_exit:
		var old_host=preload("res://scripts/units/expansion_2_drone.gd").exit_host(self,motion,existing)
		if old_host!=null:temporary.append(old_host)
	if expedition_transit:
		temporary.append_array(FoundationTransit.buildings(self,motion,existing))
	if base_escape and not expedition_transit:
		temporary.append_array(preload("res://scripts/units/base_escape.gd").buildings(self,motion,existing))
	# For a floating body without platform motion, the first native sweep covers
	# its whole step. With no hit or overlap, no unit exception can change the
	# slide. Foundation and host-exit handling above still runs for its side effects.
	if sliding and Engine.is_in_physics_frame() and motion_mode == MOTION_MODE_FLOATING and platform_wall_layers == 0:
		if not test_move(global_transform, motion, null, safe_margin, true):
			return temporary
	var contacts:Array=world.neighborhood.nearby(global_position,radius+world.neighborhood.max_unit_radius+travel+4.0,true) if world is Battle and world.units.size()>=96 else world.units
	# Candidate snapshots can outlive a destroyed actor. In Godot, even `is`
	# throws on a freed instance; validate first or movement below is skipped.
	preload("res://scripts/world/battle_call_counters.gd").iterations(53,contacts.size())
	var origin := global_position
	for candidate in contacts:
		if not is_instance_valid(candidate) or not candidate is Unit: continue
		var other: Unit = candidate
		if other == self or other.is_air != is_air or other.embarked_in != null: continue
		var reach: float = radius + other.radius + travel + 4.0
		if origin.distance_squared_to(other.global_position) > reach * reach: continue
		if not world.actor_alive(other): continue
		var pass_friendly: bool = _local_traffic.friendly_unit_pair(self,other)
		var upper = other if is_naval else self
		var pass_bridge: bool = other.is_naval != is_naval and world.path_service.near_deck(upper.global_position, upper.radius)
		var separate_decks := special.has("hollywood_on_deck") != other.special.has("hollywood_on_deck")
		if pass_friendly or pass_bridge or separate_decks:
			if not existing_loaded:
				existing = get_collision_exceptions()
				existing_loaded = true
			if not existing.has(other):
				add_collision_exception_with(other)
				temporary.append(other)
	return temporary

func _domain_ok(p: Vector2) -> bool:
	if is_air:
		return true
	var par := _navigation_world()
	if par == null or par.path_service == null:
		return true
	if par.path_service.native_map_id == "yr_sov01":
		var terrain := par.path_service.native_flags(p)
		if is_amphibious: return (terrain & 3) != 0
		return (terrain & (2 if is_naval else 1)) != 0
	if is_amphibious: return true
	return par.path_service.in_naval_water(p) if is_naval else not par.in_water_world(p)

## Low-flying targets may be vulnerable to ground fire before a physical grapple can reach them.
func ground_contact_eligible() -> bool:
	if embarked_in != null or special.has("para_height"): return false
	if not is_air: return true
	return unit_id in ["SCHP", "SHAD"] and logistics.air_lift <= 0.001

func is_air_target() -> bool:
	if special.has("para_height"): return true
	return is_air and logistics.air_lift > 0.1

func set_stowed(carrier) -> void:
	if carrier!=null:preload("res://scripts/units/expansion_2_infiltration.gd").stowed(self)
	_cargo_command_target = null
	_think_timer = 0.0
	AlliedAbilities.release_temporal(self)
	_cancel_burst()
	attack_target = null
	attack_ordered = false
	if carrier != null:
		AlliedAbilities.cancel(self)
		AlliedAbilities.release_control(self)
	if carrier is Unit and carrier.unit_id == "BFRT" and special.get("ai_carrier") == carrier:
		special.erase("ai_transport_reserved")
		special.erase("ai_carrier")
	embarked_in = carrier
	reset_physics_interpolation()
	BattleRequest.sync_unit_target_groups(self,carrier == null)
	_refresh_weapon_derived()
	visible = carrier == null
	velocity = Vector2.ZERO
	var groups := ["combatants", "air_units" if is_air else "ground_units"]
	if carrier != null:
		collision_layer = 0
		collision_mask = 0
		var attached_squid:bool=NavalContact.grip_host(self)!=null
		if not attached_squid:selected=false
		for group in groups:
			remove_from_group(group)
		var world := _battle_world()
		if world != null and not attached_squid:
			world.selected_units.erase(self)
			world._emit_selection()
	else:
		collision_layer = 8 if is_air else 1
		collision_mask = 8 if is_air else 7
		for group in groups:
			add_to_group(group)
	queue_redraw()
