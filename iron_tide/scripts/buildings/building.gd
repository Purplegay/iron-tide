extends StaticBody2D
class_name Building
## 建筑：指挥中心 / 生产线 / 防御塔 / 敌方巢穴。
## 兼顾建造进度、生产队列、炮塔开火与资金涓流。

var data: Dictionary = {}
var special: Dictionary = {}
var side: String = "ally":
	set(value):
		if side == value: return
		side = value
		if building_id == "CAMACH": special.erase("machine_shop_elapsed")
		if is_instance_valid(battle): battle.invalidate_building_membership()
var faction: String = "allied"
var building_id: String = ""
var display_name: String = ""
const RefineryTraffic = preload("res://scripts/units/refinery_traffic.gd")
var refinery_traffic := RefineryTraffic.new()
const RepairArmAnimation = preload("res://scripts/buildings/repair_arm_animation.gd")

var max_hp: float = 1000.0
var hp: float = 1000.0
var armor: String = "structure"
var ra2_armor: String = ""          # RA2 真实护甲类别（wood/steel/concrete/...）
var radius: float = 30.0
## RA3 式：建在水域上的建筑（绘制浮动平台 + 波纹）
var _on_water: bool = false
## 建筑底盘菱形（begin 空间）——由素材可见底边推得，供选中角标贴合底盘使用
var _sel_poly: PackedVector2Array = PackedVector2Array()
var sight: float = 300.0
var bonuses: Dictionary = { "attack_bonus": 1.0, "defense_bonus": 1.0 }
var is_air: bool = false
var is_hq: bool = false
var is_spawner: bool = false

# 炮塔
var weapon: Dictionary = {}
var attack_range: float = 0.0
var cooldown: float = 1.0
var _cd: float = 0.0
var _gatling_followup_target: Node2D
var _gatling_followup_delay := 0.0
var _think: float = 0.0
var attack_target = null
var _turret_turn_speed := 0.0
var _ground_targeting_allowed := true

# 棱镜支援链（T5，rules.ini [General] PrismSupport*）：棱镜建筑（PrismType=ATESLA）开火时，
# 附近的同族友方棱镜各射一束支援光束助阵，每束按 prism.modifier 提高本次伤害，最多 prism.max 束。
# 支援后该塔自身离线 prism.delay 帧（1/15s/帧＝4s）。支援光束纯表现，不单独造成伤害。
var prism_type: String = ""         # 非空＝这是一座棱镜建筑
var prism_support_weapon: String = ""  # 支援武器 id（Secondary=PrismSupport）
var _prism_offline: float = 0.0      # 支援冷却：>0 表示刚支援过，离线中
var _prism_aim: Vector2 = Vector2.ZERO  # 支援光束瞄准点（带抬高的目标位置）
var _prism_support_range: float = 0.0   # 支援武器像素射程（支援塔须自身在目标此射程内）

# ---- 超级武器（ChronoSphereSpecial / LightningStormSpecial）----------------
var superweapon: Dictionary = {}:
	set(value):
		var old_group := "charge_sites_" + str(superweapon.get("type", ""))
		if is_in_group(old_group): remove_from_group(old_group)
		superweapon = value
		if SupportSystems.shared_charge(self):
			add_to_group("charge_sites_" + sw_type())
var _sw_charge: float = 0.0
var _sw_was_ready: bool = false
var _storm_active: bool = false
var _storm_target: Vector2 = Vector2.ZERO
var _storm_delay: float = 0.0
var _storm_time: float = 0.0
var _storm_hit_timer: float = 0.0
var _storm_scatter_timer: float = 0.0

# 生产
var buildable: Array = []          # 可生产单位 id
var production: Array = []         # 生产队列（unit_id）
var production_paid := 0.0
var progress: float = 0.0
var build_speed: float = 1.0
var trickle: float = 0.0           # 每秒资金

# RA2 电力：power 正=发电/负=耗电（rules.ini Power=）；powered=低电离线（Powered=yes）
var power: int = 0
var powered: bool = false
var _power_warning_visible := false

# 建造进度
var under_construction: bool = false
var build_total: float = 0.0
var build_elapsed: float = 0.0
const COMPLETION_FLASH_SECONDS := 0.72
var _completion_flash_left := 0.0
var _completion_flash_pending := false
# YR rulesmd.ini [GAREFN] FreeUnit=CMIN. Map fixtures have their own opening army.
const CONSTRUCTION_FREE_UNITS := {"GAREFN": "CMIN", "NAREFN": "HARV"}
var _free_unit_retry := 0.0

var battle: Battle
var selected: bool = false
var hovered: bool = false
var repairing: bool = false   # 红警2：K 切换维修（持续回血，消耗资金）
var repair_waiting_funds := false
var _building_repair_elapsed := 0.0
var _hp_ghost: float = 1.0    # 掉血残影（延迟下落的血量比例）
var _hp_flash: float = 0.0    # 受击白闪剩余（1→0）
var _dead: bool = false
var _col: Color = Color(0.4, 0.7, 1.0)
# --- RA2 原图（Step C 阶段2）：非空时 _draw 用 SHP 素材替换程序化建模 ---
var _ra2: Dictionary = {}
var _turret_art := BuildingTurretArt.new()
var _anim_kind_cache: Dictionary = {}
var _ra2_anim: Array = []:
	set(value):
		_ra2_anim = value
		_anim_kind_cache = {}
		for layer: Dictionary in value: _anim_kind_cache[str(layer.get("kind", ""))] = true
		_anim_kind_cache.make_read_only()
var _buildup_art: Dictionary = {}  # (A6) art.ini Buildup 建造序列 SHP（第 0 帧=空基座，末帧=落成）
var _buildup_play: float = -1.0     # >=0 表示正在播放 RA2 BuildupTime（侧栏生产完成后放下建筑的那一下）
# ---- (A4) 维修厂（Service Depot，extra.UnitRepair=yes）----
const REPAIR_STEP := 8.0        # rules.ini RepairStep：每步回血量(HP)
const REPAIR_INTERVAL := 0.96   # rules.ini URepairRate=0.016min ≈ 0.96s/步
const REPAIR_PERCENT := 0.15    # rules.ini RepairPercent：满修费用占单位造价比例
const REPAIR_DIRS := [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]
var _is_repair: bool = false
var _repair_accum: float = 0.0
var _repair_active: bool = false
# 最近一帧的绘制参数（供 hit_test()/art_center() 复用；铁律：判定几何 = 绘制几何）
var _art_frame: int = -1
var _art_source: Dictionary = {}   # 本帧实际绘制的图集（展开序列或成品）
var _art_aframes: Array = []
var _art_sc: float = 1.0
var _art_lift: float = 0.0
var _anim_t: float = 0.0       # 动画累计时间（各层按自己的 Rate 取帧）
var _anim_key: int = -1        # 各层帧号指纹，只有变化才 queue_redraw
var _anim_state: String = "idle"   # RA2 分组动画状态：idle/active/production/special
var _anim_group_t: float = 0.0     # 当前分组相位计时器（状态切换时归零，保证一次性动画从头播）
var _special_until: float = 0.0    # special 状态剩余时长（>0 表示正在播一次性 special 动画）
var _production_anim_t: float = -1.0  # 出兵或放置就绪建筑时触发，独立于常驻动画相位
var _production_anim_duration: float = 0.0
var build_cost: float = 0.0        # RA3：应付建造总额（建造期按帧扣除）
var _pay_stall: bool = false       # RA3：资金不足时暂停建造
var exit_blocked: bool = false
var _exit_anim_left: float = 0.0
var _exit_air: bool = false
var _bunker_fraction := 0.0
const EXIT_DOOR_HOLD := 0.35

## 本建筑可用的动画分组集合（按 bldanim 层的 kind 归纳）。
func _anim_kinds() -> Dictionary:
	return _anim_kind_cache

## 是否具备门动画（战车工厂/船厂/维修厂等）。
func _has_door_anim(ks: Dictionary) -> bool:
	return ks.has("deployinganim") or ks.has("underdooranim") or ks.has("roofdeployinganim") or ks.has("underroofdooranim")

## 触发一次性 special 动画（ATESLA 开火 / GAREFN 卸矿等）。
## dur 为 0 时按 special 层首帧组的 loop 长度与 rate 估算。
## (A4) 是否维修厂（extra.UnitRepair=yes，如 GADEPT）。
func is_repair_depot() -> bool:
	return _is_repair

func is_dead() -> bool:
	return _dead

func is_refinery() -> bool:
	return (data.get("tags", []) as Array).has("refinery")

static func refinery_dock_direction() -> Vector2:
	return art_to_ground(Vector2(1.0, 0.5)).normalized()

func refinery_dock_point(unit_radius: float) -> Vector2:
	return global_position + refinery_dock_offset(footprint_poly(), unit_radius)

static func refinery_dock_offset(poly: PackedVector2Array, unit_radius: float) -> Vector2:
	var center := Vector2.ZERO
	for point in poly:
		center += point
	center /= maxf(1.0, float(poly.size()))
	var outward := refinery_dock_direction()
	var edge := 0.0
	for point in poly:
		edge = maxf(edge, (point - center).dot(outward))
	return center + outward * (edge + unit_radius + 6.0)

## Local working area for a pair of starting miners sharing this dock.
static func refinery_apron(poly: PackedVector2Array, radius: float) -> Rect2:
	var outward := refinery_dock_direction()
	var dock := refinery_dock_offset(poly, radius)
	var stage := dock + outward * Unit.DOCK_STAGE_BACK
	var queue := stage + RefineryTraffic.queue_offset(outward, radius, 1)
	var exit := stage + outward * RefineryTraffic.exit_distance(radius)
	return Rect2(dock, Vector2.ZERO).expand(queue).expand(exit).grow(radius + 4.0)

# ================================================================== 电力（RA2）
## 低电时本阵营建造/生产速度乘数（无低电=1.0）。
func _power_build_factor() -> float:
	if battle != null and battle.has_method("power_build_factor"):
		return float(battle.power_build_factor(side))
	return 1.0

func production_work_rate(uid: String) -> float:
	if GM.no_build_time:
		return GameData.ra2_build_time(GameData.get_unit(uid)) / maxf(0.1, build_speed) / GM.FAST_BUILD_SECONDS
	var factory_factor := 1.0
	if battle != null and not is_refinery():
		factory_factor = battle.factory_speed_factor(side, uid)
	return preload("res://scripts/expedition/research.gd").production(battle,side,uid) * BattleClock.production_scale(GameData.get_unit(uid)) * _power_build_factor() * factory_factor * (battle.ai_unit_build_factor(side) if battle != null else 1.0) * preload("res://scripts/expedition/rules.gd").production_factor(side) * preload("res://scripts/expedition/red_alert.gd").production(battle,side)

func construction_work_rate() -> float:
	if GM.no_build_time: return build_total / GM.FAST_BUILD_SECONDS
	var owner_rate:float=battle.ai_build_factor(side) if battle!=null and BattleRequest.house_teams.has(side) else 1.0
	return BattleClock.production_scale(data) * _power_build_factor() * owner_rate * preload("res://scripts/expedition/red_alert.gd").production(battle,side)

## Presentation invalidation; does not alter power or combat state.
func _refresh_power_warning() -> bool:
	var warning:bool=powered and not _dead and not under_construction and battle!=null and battle.side_power_low(side) and not is_operational()
	var changed:=warning!=_power_warning_visible
	_power_warning_visible=warning
	return warning or changed

## 建筑是否在运转：已落成 且（不需电力 或 供电正常）。Powered=yes 的建筑低电时离线。
func installed_power() -> int:
	return power + int(data.get("extra_power",0)) * special.get("occupants",[]).size() if data.has("extra_power") else power

func is_operational() -> bool:
	if AlliedAbilities.frozen(self): return false
	if _dead or under_construction or _buildup_play >= 0.0:
		return false
	# 尤复 PrismSupportDelay=45 帧（3 秒），支援后不能立即再次供能。
	if _prism_offline > 0.0:
		return false
	if powered and battle != null and battle.side_power_low(side):
		return data.has("charged_weapon") and preload("res://scripts/units/tesla_support.gd").count(self) >= 2
	return true

## (A4) 停机位：在占地外侧、取最靠近来袭方向的那个正交方位（避免斜向卡角）。
func dock_point(from: Vector2 = Vector2.ZERO) -> Vector2:
	if data.get("water_bound", false):
		var approach := depth_anchor().direction_to(from)
		return ProductionExit.water_berth(self, 24.0, Vector2.DOWN if approach.is_zero_approx() else approach, true)
	var dir := from - global_position
	if dir.length() < 0.001:
		dir = Vector2(0.0, 1.0)
	dir = dir.normalized()
	var best_dir := Vector2(0.0, 1.0)
	var best_dot := -2.0
	for d in REPAIR_DIRS:
		var dp: float = dir.dot(d)
		if dp > best_dot:
			best_dot = dp
			best_dir = d
	return global_position + best_dir * (footprint_clearance(best_dir) + 38.0)

## (A4) 维修厂为停机位上的受损载具回血。
## 数值取自 rules.ini：RepairStep=8HP / URepairRate=0.016min(≈0.96s) / RepairPercent=15%。
func _process_repair(delta: float) -> void:
	if delta <= 0.0 or battle == null or battle.paused or battle.ended or get_tree().paused or not is_operational():
		return
	_repair_accum += delta
	var step_ready := _repair_accum >= REPAIR_INTERVAL
	if step_ready:
		_repair_accum = 0.0
	var active := false
	var healed := false
	for u in get_tree().get_nodes_in_group("repair_docked"):
		if not is_instance_valid(u) or not u.repairing or u.repair_depot != self or not u.can_repair_at(self):
			continue
		var mx := float(u.get("max_hp"))
		var h := float(u.get("hp"))
		if mx <= 0.0 or h >= mx:
			continue
		# 必须实际开上平台中心；路上、入口等待均不收费。
		if u.global_position.distance_to(RepairDock.pad(self)) > 6.0:
			continue
		active = true
		if not step_ready:
			continue
		var want: float = minf(REPAIR_STEP, mx - h)
		var ud = u.get("data")
		var unit_cost: float = 0.0
		if typeof(ud) == TYPE_DICTIONARY:
			unit_cost = float((ud as Dictionary).get("cost", 0.0))
		var cost: float = want * unit_cost * REPAIR_PERCENT / mx
		if cost > 0.0 and not battle.spend_side(side, cost):
			continue
		preload("res://scripts/units/soviet_advanced.gd").cleanse(u, true)
		u.heal(want, self)
		healed = true
	if healed:
		play_special()
	if active != _repair_active:
		_repair_active = active
		queue_redraw()

func play_special(dur: float = -1.0) -> void:
	# Repair ticks and building self-repair must not restart/stack the arm poses.
	if building_id in ["GADEPT", "NADEPT", "NAYARD", "CAOUTP"]: return
	var ks := _anim_kinds()
	if not ks.has("specialanim"):
		return
	if dur <= 0.0:
		dur = 0.8
		for lay in _ra2_anim:
			if str(lay.get("kind", "")) == "specialanim":
				var n := int(lay.get("loopEnd", 0)) - int(lay.get("loopStart", 0)) + 1
				dur = maxf(0.1, float(n) * 60.0 / maxf(float(lay.get("rate", 900.0)), 1.0))
				break
	_set_anim_state("special", dur)

func _set_anim_state(s: String, dur: float = 0.0) -> void:
	if _anim_state != s:
		_anim_state = s
		_anim_group_t = 0.0
		_anim_key = -1
	_special_until = dur if dur > 0.0 else 0.0
	queue_redraw()

## 每帧推进状态机：special 到期回落，门动画随生产队列进出。
func _tick_anim_state(delta: float) -> void:
	_exit_anim_left = maxf(0.0, _exit_anim_left - delta)
	if _production_anim_t >= 0.0:
		_production_anim_t += delta
		if _production_anim_t >= _production_anim_duration:
			_production_anim_t = -1.0
			_anim_key = -1
	if _ra2_anim.is_empty():
		return
	_anim_group_t += delta
	if building_id == "NATBNK":
		var occupied := not (special.get("occupants", []) as Array).is_empty()
		_bunker_fraction = move_toward(_bunker_fraction, float(occupied), delta * (220.0 if occupied else 440.0) / 540.0)
	if building_id in ["GADEPT", "NADEPT", "NAYARD", "CAOUTP"]:
		RepairArmAnimation.tick(self)
		return
	var ks := _anim_kinds()
	if is_refinery() and ks.has("specialanim"):
		if unloading_miner() != null:
			_set_anim_state("special")
			return
		if _anim_state == "special":
			_set_anim_state(_base_anim_state(ks))
			return
	if _anim_state == "special":
		_special_until -= delta
		if _special_until <= 0.0:
			_set_anim_state(_base_anim_state(ks))
		return
	var want := _base_anim_state(ks)
	if want != _anim_state:
		_set_anim_state(want)

func _animation_draw_needed() -> bool:
	if _body_visibility != null and not selected and not hovered and not _body_visibility.is_on_screen():
		if not get_viewport_rect().intersects(get_global_transform_with_canvas() * _body_visibility.rect): return false
	var key := 0
	var damaged := _dmg_index() > 0
	for layer: Dictionary in _ra2_anim:
		var kind := str(layer.get("kind", ""))
		if not _layer_visible(kind): continue
		var state: Dictionary = layer._damaged_state if damaged else layer._healthy_state
		key = (key * 31 + kind.hash()) * 31 + _anim_frame_for(layer, state)
	# Include visible layer identity and frame in the complete pose fingerprint.
	if key == _anim_key: return false
	_anim_key = key
	return true

func unloading_miner():
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(49)
	if battle == null or not is_operational():
		return null
	var candidates := get_tree().get_nodes_in_group("ore_harvesters")
	preload("res://scripts/world/battle_call_counters.gd").iterations(49,candidates.size())
	for miner in candidates:
		if battle.actor_alive(miner) and miner.side == side and miner.is_harvester \
				and miner.harvest_state == "unloading" and miner.cargo > 0.0 \
				and miner.home_base == self and miner._dock_locked and miner._dock_home == self \
				and miner.global_position.distance_to(miner._dock_pt) <= miner.DOCK_STOP + 1.0:
			return miner
	return null

func play_production_animation() -> void:
	_production_anim_duration = 0.0
	for lay in _ra2_anim:
		if str(lay.get("kind", "")).begins_with("productionanim"):
			var st := _anim_layer(lay)
			var frames := int(st.loopEnd) - int(st.loopStart) + 1
			_production_anim_duration = maxf(_production_anim_duration, float(frames) * 60.0 / maxf(1.0, float(st.rate)))
	_production_anim_t = 0.0 if _production_anim_duration > 0.0 else -1.0
	_anim_key = -1
	queue_redraw()

## 常驻状态判定：有生产队列且带门动画 → production(门)；否则 active/idle。
func _base_anim_state(ks: Dictionary) -> String:
	if _has_door_anim(ks) and _door_fraction() > 0.0:
		return "production"
	if ks.has("activeanim"):
		return "active"
	if ks.has("idleanim"):
		return "idle"
	return "none"

func _door_open_seconds() -> float:
	var duration := 0.0
	for lay in _ra2_anim:
		var kind := str(lay.get("kind", ""))
		if _is_door_layer(kind) and _door_layer_matches(kind):
			var st := _anim_layer(lay)
			duration = maxf(duration, float(int(st.loopEnd) - int(st.loopStart) + 1) * 60.0 / maxf(1.0, float(st.rate)))
	return maxf(0.01, duration)

func _is_door_layer(kind: String) -> bool:
	return kind.begins_with("deployinganim") or kind.begins_with("underdooranim") \
		or kind.begins_with("roofdeployinganim") or kind.begins_with("underroofdooranim")

func _door_layer_matches(kind: String) -> bool:
	var air := _exit_air
	if _exit_anim_left <= 0.0 and not production.is_empty():
		air = (GameData.get_unit(str(production[0])).get("tags", []) as Array).has("air")
	var roof := kind.begins_with("roofdeployinganim") or kind.begins_with("underroofdooranim")
	return roof == air

func _door_fraction() -> float:
	if _exit_anim_left <= 0.0 and production.is_empty(): return 0.0
	var duration := _door_open_seconds()
	# 出厂后短暂保持开启，再倒放关闭；下一辆接近完成时可以继续开门。
	var amount := clampf(_exit_anim_left / duration, 0.0, 1.0)
	if not production.is_empty() and is_operational():
		var bt := GameData.ra2_build_time(GameData.get_unit(str(production[0]))) / maxf(0.1, build_speed)
		var remaining := maxf(0.0, bt - progress) / maxf(0.01, production_work_rate(str(production[0])))
		amount = maxf(amount, clampf(1.0 - remaining / duration, 0.0, 1.0))
	return amount

## 判断某层在当前状态下是否应绘制（互斥分组）。
func _layer_visible(kind: String) -> bool:
	if kind.begins_with("superanim") and building_id in ["NAIRON", "NAMISL"]:
		# The silo's super layers are complete poses, including the foundation.
		# Keep its current pose visible even when operation is suspended.
		if building_id != "NAMISL" and not is_operational(): return false
		var stage := "superanim"
		var elapsed := sw_recharge() - _sw_charge
		var lead := float(preload("res://scripts/core/yr_death_rules.gd").type_data(building_id).get("chargedanimtime",1)) * 60.0
		if special.has("sw_discharge_age"): stage = "superanimfour"
		elif elapsed <= lead:
			stage = "superanimtwo" if lead-elapsed < sw_anim_seconds("superanimtwo") else "superanimthree"
		return kind == stage
	if building_id == "NATBNK":
		if not (special.get("occupants", []) as Array).is_empty(): return kind in ["specialanim","specialanimtwo"]
		return _bunker_fraction > 0 and kind in ["specialanimthree","specialanimfour"]
	if building_id == "YAPOWR":
		var active := "activeanimtwo" if not special.get("occupants", []).is_empty() else "activeanim"
		return kind == active or kind == "idleanim"
	if data.has("charged_weapon") and not is_operational(): return false
	if building_id == "CAOUTP" and kind == "activeanim": return side != "neutral"
	if building_id in ["GADEPT", "NADEPT", "CAOUTP"] or (building_id == "NAYARD" and kind.begins_with("specialanim")):
		return RepairArmAnimation.visible(self, kind)
	if kind.begins_with("productionanim"):
		return _production_anim_t >= 0.0
	if kind == "idleanim" and _production_anim_t >= 0.0:
		return false
	match _anim_state:
		"special":
			return kind.begins_with("specialanim") or (is_refinery() and kind.begins_with("activeanim"))
		"production":
			# 门动画组：deploying(门体) + underdoor(门洞) + 常驻 active/idle
			if kind.begins_with("deployinganim") or kind.begins_with("underdooranim") \
				or kind.begins_with("roofdeployinganim") or kind.begins_with("underroofdooranim"):
				return _door_layer_matches(kind)
			return kind.begins_with("activeanim") or kind.begins_with("idleanim")
		"active", "idle":
			return kind.begins_with("activeanim") or kind.begins_with("idleanim")
		_:
			return not (kind.begins_with("specialanim") or kind.begins_with("deployinganim") \
				or kind.begins_with("underdooranim") or kind.begins_with("roofdeployinganim") \
				or kind.begins_with("underroofdooranim"))

func setup(p_data: Dictionary, p_side: String, p_pos: Vector2, p_battle, instant: bool = false) -> void:
	data = p_data
	GameData.apply_hollywood_fx(data)
	side = p_side
	faction = str(p_data.get("faction", "allied"))
	building_id = str(p_data.get("id", ""))
	preload("res://scripts/buildings/tesla_pulse.gd").configure(self)
	if building_id=="NAFLAK" and side=="ally" and BattleRequest.extensions_enabled() and BattleRequest.unit_loadout(building_id).passive=="ps_barrage":
		special.flak_card=float(GameData.get_skill("ps_barrage").value)*BattleRequest.card_scale("ps_barrage")
	display_name = str(p_data.get("name", building_id))
	global_position = p_pos
	battle = p_battle
	_on_water = p_battle != null and p_battle.has_method("on_water") and (p_battle.on_water(p_pos) == true)

	max_hp = float(p_data.get("hp", 1000))
	armor = str(p_data.get("armor", "structure"))
	ra2_armor = str(p_data.get("ra2_armor", ""))
	radius = float(p_data.get("radius", 30))
	sight = float(p_data.get("sight", 300))
	trickle = float(p_data.get("trickle", 0.0)) if BattleRequest.extensions_enabled() else 0.0
	power = int(p_data.get("power", 0))
	powered = (p_data.get("powered", false) == true)
	is_hq = (p_data.get("tags", []) as Array).has("hq")
	is_spawner = (p_data.get("tags", []) as Array).has("spawner")

	var w = p_data.get("weapon", null)
	if typeof(w) == TYPE_DICTIONARY and not (w as Dictionary).is_empty():
		weapon = w
		attack_range = float(weapon.get("range", 300))
		cooldown = max(0.05, float(weapon.get("cooldown", 1.0)))

	bonuses.damage_owner_side=side
	if side == "ally":
		var b := BattleRequest.combat_bonuses()
		bonuses["attack_bonus"] = float(b.get("attack_bonus", 1.0))
		CombatMath.begin_growth(bonuses, BattleRequest.growth_attack_cap())
		bonuses["defense_bonus"] = float(b.get("defense_bonus", 1.0))
		max_hp = max_hp * float(b.get("hp_bonus", 1.0))
		build_speed = float(b.get("build_bonus", 1.0))
	elif side == "enemy" or BattleRequest.house_teams.has(side):
		var b := BattleRequest.enemy_logistics(side)
		bonuses["attack_bonus"] = float(b.attack_bonus)
		bonuses["defense_bonus"] = float(b.defense_bonus)
		max_hp *= float(b.hp_bonus)
		# Production uses battle.ai_build_factor once for units and structures.

	preload("res://scripts/world/brutal_three.gd").grant(self)
	# buildable 需为「单位 id 字符串数组」：HUD 与 enqueue 都按 id 使用
	buildable = []
	for _u in GameData.units_from_building(faction, building_id):
		buildable.append(str(_u.get("id", "")))
	preload("res://scripts/rules/joint_ra2_production.gd").sync_catalog(self)
	preload("res://scripts/expedition/rules.gd").sync_training_permits(self)
	apply_mission_production_limits()
	_ra2 = RA2Art.art(building_id)
	if building_id=="NATBNK": _ra2=RA2Art.art("NATBNKBB")
	if p_data.get("hollywood_art",false):
		var tex := load("res://assets/ra2/hollywood/city/"+building_id+".png") as Texture2D
		if tex: _ra2={"kind":"shp","key":building_id,"tex":tex,"rects":[],"count":1,"dmg":1,"cell":[tex.get_width(),tex.get_height()]}
		var states_path := "res://assets/ra2/hollywood/city/states/%s.png" % building_id
		if data.has("garrison_slots") and ResourceLoader.exists(states_path):
			var atlas := load(states_path) as Texture2D
			var width := atlas.get_width() / 3
			var height := atlas.get_height()
			var frames := []
			for index in 3:
				frames.append({"x":index*width,"y":0,"w":width,"h":height})
			_ra2={"kind":"shp","key":building_id,"tex":atlas,"rects":frames,"count":3,"dmg":3,"cell":[width,height],"city_occupancy":true}
	_turret_art.setup(building_id)
	# Only the two ported independent turrets have a shared aim/fire pose.
	# ROT uses the same 15 Hz / 256-step convention as the unit adapter.
	# NASAM omits ROT in local rules: 8 is our explicit adaptation default.
	if building_id in ["GTGCAN", "NASAM", "NALASR", "NAFLAK", "CAOUTP", "YAGGUN", "YAREFN"]:
		var source: Dictionary = GameData.ra2_source_buildings.get(building_id, {})
		var extra: Dictionary = source.get("extra", {})
		_turret_turn_speed = maxf(1.0, float(extra.get("ROT", 8))) * 360.0 / 256.0 * 15.0
		if not _turret_art.gatling.is_empty():
			_turret_turn_speed=float(_turret_art.gatling.rot_units)*360.0/256.0*BattleClock.RULE_TICKS_PER_SECOND
		_ground_targeting_allowed = int(extra.get("LandTargeting", 0)) != 1
	_ra2_anim = RA2Art.building_anims(building_id)
	# Source layers are shared per building type. Their two parameter sets
	# are immutable; only the damage-state choice belongs to this instance.
	for layer:Dictionary in _ra2_anim:
		if not layer.has("_healthy_state"):
			layer._healthy_state=_make_anim_layer(layer,false)
			layer._damaged_state=_make_anim_layer(layer,true) if layer.has("dmg") else layer._healthy_state
	# (A6) 建造序列：art.ini 的 Buildup=<NAME> 指向独立 SHP（已由 ra2pipe art_build.mjs buildup 提取）
	var _bname := "STUDIOMK" if building_id == "NEUTRALSTUDIO" else str(data.get("buildup", "")).to_upper()
	if not _bname.is_empty() and RA2Art.has_art(_bname):
		_buildup_art = RA2Art.art(_bname)
	# (A4) 维修厂判定：运行时数据用 tags 含 "repair"（GADEPT/NADEPT）；兼容 buildings.json 的 extra.UnitRepair
	var _tags = data.get("tags", [])
	if typeof(_tags) == TYPE_ARRAY:
		_is_repair = (_tags as Array).has("repair")
	if not _is_repair:
		var _ex = data.get("extra", {})
		if typeof(_ex) == TYPE_DICTIONARY:
			_is_repair = str((_ex as Dictionary).get("UnitRepair", "")).to_lower() == "yes"
	# RA2 占地判定用的真实底盘多边形（碰撞/占点/寻路共用），必须在 _apply_physics() 之前算好
	_fp_poly = placement_poly(data)
	build_cost = float(p_data.get("cost", 0.0))
	refresh_house_color()
	add_to_group("house_colored")

	# 棱镜建筑：faction.mjs 写入 prism_type（=rules.ini [General] PrismType=）；
	# 主武器开火时触发支援链，见 _prism_support_chain()。
	prism_type = str(p_data.get("prism_type", ""))
	prism_support_weapon = str(p_data.get("prism_support_weapon", ""))
	_prism_support_range = float(p_data.get("prism_support_range", 0.0))
	superweapon = p_data.get("superweapon", {}) if p_data.get("superweapon", null) != null else {}
	if building_id not in ["NATBNK", "YAGRND"]: play_special()
	_sw_charge = 0.0
	_sw_was_ready = false

	# RA2 没有“放下后再施工”：侧栏生产已耗时，放下即建成，只播 BuildupTime 动画。
	# 旧数据 build_time 为空 → 这里回退到 rules.ini BuildSpeed 计算（cost*0.7 分钟/1000）。
	var btime := GameData.ra2_build_time(p_data)
	if instant or (side == "enemy" and BattleRequest.house_teams.is_empty()):
		under_construction = false
		hp = max_hp
		if not _buildup_art.is_empty():
			_buildup_play = 0.0
	else:
		under_construction = true
		build_total = btime / max(0.1, build_speed)
		build_elapsed = 0.0
		hp = max_hp * 0.15

	_apply_physics()
	queue_redraw()

# -------------------------------------------------- RA2 原图（SHP）

const RA2_SPRITE_SCALE := 1.0

## 建造网格边长（与 battle.gd 的 BUILD_GRID 保持一致）：1 格 = 40 世界单位
const BUILD_GRID := 40.0

## Step C 阶段2：用 RA2 建筑 SHP 替换程序化建模（取帧 0，底边中点对齐脚下）。
## (A6) 绘制建造中的 RA2 原版 buildup 序列；返回 false 表示无素材，调用方回退到常规绘制。
func _draw_buildup(r: float) -> bool:
	if _buildup_art.is_empty():
		return false
	var tex: Texture2D = _buildup_art.get("tex")
	if tex == null:
		return false
	var n := int(_buildup_art.get("count", 0))
	if n <= 0:
		return false
	var sc := RA2_SPRITE_SCALE
	var sz := RA2Art.frame_size(_buildup_art)
	var k := 1.0
	if _buildup_play >= 0.0:
		# RA2 renderable: rate = numImages / (60 * General.BuildupTime)
		k = clampf(_buildup_play / maxf(0.01, GameData.ra2_buildup_seconds()), 0.0, 1.0)
	else:
		# 非 RA2 的“边造边付”后备路径：按施工进度推进
		k = clampf(build_elapsed / maxf(0.01, build_total), 0.0, 1.0)
	var fi := clampi(int(floor(k * float(n))), 0, n - 1)
	# 锚点取「落成帧」：完工瞬间与主体贴图同位置，不跳位
	var a := RA2Art.anchor(_buildup_art, [n - 1])
	var base := Vector2(-a.x * sc, r * 0.35 - a.y * sc)
	base += preload("res://scripts/world/construction_transition.gd").deployment_shift(self)
	var dia := RA2Art.base_diamond(_buildup_art, [n - 1])
	if dia.size() == 4:
		var poly := PackedVector2Array()
		for p in dia:
			poly.append(base + p * sc)
		_sel_poly = poly
	else:
		_sel_poly = PackedVector2Array()
	if special.has("mcv_make_radius"):
		var shadow_radius := lerpf(float(special.mcv_make_radius), r, k)
		var ground := base + RA2Art.anchor(_buildup_art, [fi])
		Iso.shadow(self, ground + Vector2(shadow_radius * 0.34, -shadow_radius * 0.15), shadow_radius * 0.85, 0.30)
	else:
		Iso.shadow(self, Vector2(r * 0.34, r * 0.35), r * 0.9, 0.30)
	RA2Art.draw_sprite(self, _buildup_art, Rect2(base, sz * sc), RA2Art.src_rect(_buildup_art, fi))
	_art_frame = fi
	_art_source = _buildup_art
	_art_aframes = [n - 1]
	_art_sc = sc
	_art_lift = 0.0
	return true

func _draw_ra2_sprite(r: float) -> void:
	_turret_art.visible = false
	_art_source = _ra2
	if WallArt.supported(data, _ra2):
		_draw_wall()
		return
	# (A6) 建造中 / 放下后的 BuildupTime：优先播放 RA2 原版 buildup 序列
	# （帧 0=空基座 → 末帧=落成；旧版只在 under_construction 时进这里，而常规流程
	#   instant=true，所以建筑永远是“啪”一下出现，建造动画实际从未播放过。）
	if (under_construction or _buildup_play >= 0.0) and _draw_buildup(r):
		return
	var tex: Texture2D = _ra2.get("tex")
	if tex == null:
		return
	var sz: Vector2 = RA2Art.frame_size(_ra2)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var kind := str(_ra2.get("kind", "shp"))
	var sc := RA2_SPRITE_SCALE
	if BattleRequest.mission_id=="yr_time_shift" and building_id in preload("res://scripts/world/time_shift_events.gd").BRIDGE:
		sc=55.0/(30.0*sqrt(2.0))
	# ---- VXL 建筑（少见）：单帧朝向 ----
	if kind != "shp":
		var vf := RA2Art.facing_index(0.0, int(_ra2.get("facings", 8)))
		var va := RA2Art.anchor(_ra2, [vf])
		RA2Art.draw_sprite(self, _ra2, Rect2(Vector2(-va.x * sc, r * 0.35 - va.y * sc), sz * sc), RA2Art.src_rect(_ra2, vf))
		_art_frame = vf
		_art_aframes = [vf]
		_art_sc = sc
		_art_lift = 0.0
		return
	# ---- (D-3a) 三损伤态：按血量选帧 0/1/2 ----
	var dmg_frames := int(_ra2.get("dmg", 1))
	var di := _body_damage_frame()
	var anchors := body_anchor_frames(di)
	var a := RA2Art.anchor(_ra2, anchors)
	var base := Vector2(-a.x * sc, r * 0.35 - a.y * sc)
	# 选中角标：贴合素材可见底盘的菱形（像素坐标 → begin 空间）
	var dia := base_outline(building_id, _ra2, di)
	if dia.size() >= 3:
		var poly := PackedVector2Array()
		for p in dia:
			poly.append(base + p * sc)
		_sel_poly = poly
	else:
		_sel_poly = PackedVector2Array()
	# ---- 地面投影（RA2 原版影子帧）----
	# 建筑 SHP 的后半段就是影子帧：总帧数 = 2 * dmg，帧 [dmg..2*dmg-1] 与主体帧同画布、同偏移，
	# 黑色半透明（RA2 影子调色板全 0 + opacity 0.5）画在主体之下即可完美对齐。
	# 影子帧只包含「露在建筑外的部分」（RA2 美术优化），所以本体遮挡处无需补。
	var has_shadow := dmg_frames >= 2 and int(_ra2.get("count", 0)) == dmg_frames * 2
	var srect := RA2Art.src_rect(_ra2, di + dmg_frames)
	if building_id not in ["NAMISL", "YAPOWR"]:
		if has_shadow and srect.size.x > 0.0:
			RA2Art.draw_sprite(self, _ra2, Rect2(base, srect.size * sc), srect, Color(0.0, 0.0, 0.0, 0.5))
		else:
			Iso.shadow(self, Vector2(r * 0.34, r * 0.35), r * 0.9, 0.30)
		RA2Art.draw_sprite(self, _ra2, Rect2(base, sz * sc), RA2Art.src_rect(_ra2, di))
	if building_id=="NATBNK" and not special.get("occupants",[]).is_empty():
		_draw_ra2_anim(base,sc,"specialanimtwo")
		HollywoodTurrets.draw_bunker_vehicle(self,false)
		_draw_ra2_anim(base,sc,"specialanim")
		HollywoodTurrets.draw_bunker_vehicle(self,true)
	else:
		_draw_ra2_anim(base,sc)
	if building_id=="NAREFN" and side=="ally" and MetaProgress.cosmetic_style(building_id).get("skin")=="night_shift":
		var miner=unloading_miner()
		var remaining:=float(miner._unload_timer)/maxf(0.01,miner.unload_time) if miner!=null else 0.0
		preload("res://scripts/units/night_shift.gd").ramp(self,base,sc,remaining)
	_turret_art.draw_on(self, base, sz, sc)
	# 记录本帧绘制参数，供 hit_test()/art_center() 复用（铁律：判定几何 = 绘制几何）
	_art_frame = di
	_art_aframes = anchors
	_art_sc = sc
	_art_lift = 0.0

func _draw_wall() -> void:
	var pitch := float(special.get("native_wall_pitch", WallArt.CELL))
	var mask := WallArt.mask_at(global_position, building_id, side, get_tree().get_nodes_in_group("buildings"), pitch)
	_art_frame = WallArt.frame(_ra2, mask, hp / maxf(1.0, max_hp))
	_art_aframes = [0]
	_art_sc = WallArt.SCALE * pitch / WallArt.CELL
	_art_lift = WallArt.lift(_ra2, radius)
	var rect := RA2Art.draw_rect(_ra2, radius, _art_aframes, _art_lift, _art_sc)
	var shadow := int(_ra2.wall_layout.shadow_start) + _art_frame
	RA2Art.draw_sprite(self, _ra2, rect, RA2Art.src_rect(_ra2, shadow), Color(0, 0, 0, 0.5))
	RA2Art.draw_sprite(self, _ra2, rect, RA2Art.src_rect(_ra2, _art_frame))
	_sel_poly = PackedVector2Array()
	for point in footprint_poly():
		_sel_poly.append(Iso.dir(point))

func body_anchor_frames(frame: int) -> Array:
	# Sandbags extend the silhouette; keep the bricks and firing ports in place.
	return [0] if building_id in ["CAHSE01", "CAOILD", "NAMISL"] or _ra2.get("city_occupancy",false) else [frame]

func _body_damage_frame() -> int:
	var count := int(_ra2.get("dmg", 1))
	if count <= 1 or max_hp <= 0.0:
		return 0
	var fraction := hp / max_hp
	if building_id == "CAHSE01" or _ra2.get("city_occupancy",false):
		# The house has one sandbagged frame, followed by rubble; neither is a damage stage.
		if not special.get("occupants", []).is_empty(): return 2
		return 1 if fraction <= 0.66 else 0
	if building_id == "NABNKR": return (2 if not special.get("occupants", []).is_empty() else 0) + (1 if fraction <= 0.5 else 0)
	return _dmg_index()

func _weapon_muzzle() -> Vector2:
	if data.has("hollywood_fx"):
		return global_position + preload("res://scripts/units/hollywood_unit_fx.gd").offset(data.hollywood_fx.primary, _turret_art.angle)
	if data.has("fire_flh"): return preload("res://scripts/units/tesla_support.gd").tip(self)
	if not _ra2.is_empty():
		var a := RA2Art.anchor(_ra2, [_body_damage_frame()])
		var base := Vector2(-a.x * RA2_SPRITE_SCALE, radius * 0.35 - a.y * RA2_SPRITE_SCALE)
		var point := _turret_art.muzzle_point(base, RA2Art.frame_size(_ra2), RA2_SPRITE_SCALE)
		if point.is_finite():
			return global_position + RA2Art.art_dir(point)
	return global_position + global_position.direction_to(attack_target.global_position) * (radius * 0.8)


# -------------------------------------------------- 点击命中判定（WYSIWYG）

## 世界点是否落在本建筑的可见像素上（与 _draw_ra2_sprite 同源）。
func hit_test(world_p: Vector2) -> bool:
	var gun=get_node_or_null("ReaperMount") if building_id=="R3REAPERTURRET" else null
	if gun!=null and gun._ra3_model!=null:return gun.hit_test(world_p)
	var silo_pose := building_id == "NAMISL" and not under_construction and _buildup_play < 0.0
	if (silo_pose or building_id == "CAOILD") and _ra2.get("tex") != null:
		var rect := RA2Art.draw_rect(_ra2, radius, [0], 0, RA2_SPRITE_SCALE)
		var local := Iso.dir(world_p - global_position)
		if not rect.has_point(local): return false
		var pixel := (local - rect.position) / RA2_SPRITE_SCALE
		if Geometry2D.is_point_in_polygon(pixel, base_outline(building_id, _ra2, 0)): return true
		if not silo_pose and _layer_frame_hit(_ra2, _body_damage_frame(), pixel): return true
		for layer in _ra2_anim:
			if not _layer_visible(str(layer.kind)): continue
			var state := _anim_layer(layer)
			var offset := Vector2(float(layer.get("x", 0)), float(layer.get("y", 0)))
			if _layer_frame_hit(RA2Art.art(str(state.image)), _anim_frame_for(layer, state), pixel - offset): return true
		return false
	if _turret_art.hit_test(Iso.dir(world_p - global_position)):
		return true
	if _art_source.get("tex") == null or _art_frame < 0:
		return world_p.distance_to(global_position) <= radius + 10.0
	var origin := global_position + RA2Art.art_dir(preload("res://scripts/world/construction_transition.gd").deployment_shift(self))
	return RA2Art.hits_pixel(world_p, origin, _art_source, radius, _art_aframes, _art_frame, _art_lift, _art_sc)


func _layer_frame_hit(art: Dictionary, frame: int, pixel: Vector2) -> bool:
	if art.is_empty(): return false
	var src := RA2Art.src_rect(art, frame)
	if not Rect2(Vector2.ZERO, src.size).has_point(pixel): return false
	var img := RA2Art.sprite_image(art)
	return img != null and img.get_pixelv(Vector2i(src.position + pixel)).a * 255.0 >= 20.0


## Local isometric drawing bounds of a building engaged at the edge of the fog.
func combat_sight_rect() -> Rect2:
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)
	for vertex in footprint_poly(): rect = rect.expand(Iso.dir(vertex))
	if _art_source.get("tex") != null and _art_frame >= 0:
		var drawn := RA2Art.draw_rect(_art_source, radius, _art_aframes, _art_lift, _art_sc)
		drawn.position += preload("res://scripts/world/construction_transition.gd").deployment_shift(self)
		rect = rect.merge(RA2Art.visible_sprite_rect(_art_source, drawn, RA2Art.src_rect(_art_source, _art_frame)))
		if is_same(_art_source, _buildup_art) or WallArt.is_wall(data): return rect
	if _ra2.get("tex") == null: return rect
	var frame := _body_damage_frame()
	var body := RA2Art.draw_rect(_ra2, radius, body_anchor_frames(frame), 0, RA2_SPRITE_SCALE)
	rect = rect.merge(RA2Art.visible_sprite_rect(_ra2, body, RA2Art.src_rect(_ra2, frame)))
	for layer in _ra2_anim:
		if not _layer_visible(str(layer.kind)): continue
		var state := _anim_layer(layer)
		var art := RA2Art.art(str(state.image))
		if art.get("tex") == null: continue
		var offset := Vector2(layer.get("x", 0), layer.get("y", 0)) * RA2_SPRITE_SCALE
		var dest := Rect2(body.position + offset, RA2Art.frame_size(art) * RA2_SPRITE_SCALE)
		rect = rect.merge(RA2Art.visible_sprite_rect(art, dest, RA2Art.src_rect(art, _anim_frame_for(layer, state))))
	if _turret_art.visible: rect = rect.merge(_turret_art.rect)
	return rect

## 可见像素的世界坐标中心（拖框选择 / 就近判定用，与贴图对齐）
func art_center() -> Vector2:
	var gun=get_node_or_null("ReaperMount") if building_id=="R3REAPERTURRET" else null
	if gun!=null and gun._ra3_model!=null:return gun.art_center()
	if _art_source.get("tex") == null or _art_frame < 0:
		return global_position
	var origin := global_position + RA2Art.art_dir(preload("res://scripts/world/construction_transition.gd").deployment_shift(self))
	return RA2Art.draw_center(origin, _art_source, radius, _art_aframes, _art_lift, _art_sc)


## 阵营涂装（house color）：按当前玩家/敌方色重上材质。由 HouseColor._sync_existing() 调用。
func refresh_house_color() -> void:
	var owner_faction := faction
	if building_id == "CAOILD" and side == "enemy" and battle != null:
		owner_faction = battle.roster_faction(side)
	_col = HouseColor.apply_to(self, side, _faction_hex(owner_faction))
	queue_redraw()


func _faction_hex(fid: String) -> String:
	return "#" + _faction_color(fid).to_html(false)


func _faction_color(fid: String) -> Color:
	var f := GameData.get_faction(fid)
	if f.has("color"):
		return Color(str(f["color"]))
	return Color(0.6, 0.6, 0.6)

const ART_GROUND_K := 2.0      # 本工程 SHP 底盘按标准 2:1 等距绘制（占点换算固定用它，不受视角预设影响）
const FP_ART_SCALE := 0.72     # 扫不到底盘时 foundation 的退回比例（实测美术底盘约为格子的 0.7x）
var _fp_radius := 0.0
var _fp_poly: PackedVector2Array = PackedVector2Array():
	set(points):
		_fp_poly = points
		_fp_radius = 0.0
		for p in points:
			_fp_radius = maxf(_fp_radius, p.length())


## begin/屏幕空间 → 地面空间（Iso.dir 的逆变换）。占点几何全在地面空间里算。
static func art_to_ground(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y * ART_GROUND_K).rotated(Iso.eff_angle())


## Native SHP canvas coordinates. CAOILD_A supplies the right half of the pad.
static func base_outline(id: String, art: Dictionary, frame: int) -> PackedVector2Array:
	if id=="NEUTRALSTUDIO":
		var barracks:=RA2Art.art("GAPILE")
		var outline:=RA2Art.base_diamond(barracks,[0]).duplicate()
		var offset:=RA2Art.anchor(art,[0])-RA2Art.anchor(barracks,[0])
		for i in outline.size():outline[i]+=offset
		return outline
	if id == "CAOILD":
		return PackedVector2Array([Vector2(83, 63), Vector2(137, 90), Vector2(83, 118), Vector2(28, 90)])
	if id == "NAMISL":
		# The static SHP contains only the front lip. Trace the fixed pad on the
		# complete NAMISL_E pose, leaving the opening doors and missile above it.
		return PackedVector2Array([Vector2(98, 108), Vector2(139, 108),
			Vector2(189, 133), Vector2(192, 154), Vector2(139, 181),
			Vector2(98, 181), Vector2(45, 154), Vector2(48, 133)])
	return RA2Art.base_diamond(art, [frame])

## 由建筑数据推出「可见底盘」多边形（地面空间、相对自身原点）。
## 与 _draw_ra2_sprite() 的 base/底盘算法完全一致，所以预览、选中角标、碰撞三者必然贴合。
static func pad_ground_poly(data: Dictionary) -> PackedVector2Array:
	var bid := str(data.get("id", ""))
	if bid.is_empty():
		return PackedVector2Array()
	var ra2 := RA2Art.art(bid)
	if ra2.is_empty():
		return PackedVector2Array()
	if str(ra2.get("kind", "shp")) != "shp":
		return PackedVector2Array()
	var sz: Vector2 = RA2Art.frame_size(ra2)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return PackedVector2Array()
	var r := float(data.get("radius", 30.0))
	var a := RA2Art.anchor(ra2, [0])
	var base := Vector2(-a.x * RA2_SPRITE_SCALE, r * 0.35 - a.y * RA2_SPRITE_SCALE)
	var dia := base_outline(bid, ra2, 0)
	if dia.size() < 3:
		return PackedVector2Array()
	var out := PackedVector2Array()
	for p in dia:
		out.append(art_to_ground(base + p * RA2_SPRITE_SCALE))
	return out


## RA2 foundation（如 "4x3"）换算出的半宽/半高（世界单位）。缺 foundation 时退回半径。
func foundation_half() -> Vector2:
	return foundation_half_for_data(data)

static func foundation_half_for_data(bd: Dictionary) -> Vector2:
	var parts := str(bd.get("foundation", "")).split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		var cells := Vector2(float(parts[0]), float(parts[1]))
		if cells.x > 0.0 and cells.y > 0.0:
			return cells * BUILD_GRID * 0.5
	var r := float(bd.get("radius", 30.0))
	return Vector2(r, r)

## 预览、合法性检查和实际碰撞共用；无素材时仍有稳定占地。
static func placement_poly(bd: Dictionary) -> PackedVector2Array:
	if WallArt.is_wall(bd):
		return WallArt.footprint()
	var poly := pad_ground_poly(bd)
	if poly.size() >= 3:
		return poly
	var e := foundation_half_for_data(bd) * FP_ART_SCALE
	return PackedVector2Array([
		Vector2(-e.x, -e.y), Vector2(e.x, -e.y), Vector2(e.x, e.y), Vector2(-e.x, e.y)])


## 唯一事实源：建筑的真实占地多边形（地面空间 / 本节点局部坐标）。
func footprint_poly() -> PackedVector2Array:
	if _fp_poly.size() >= 3:
		return _fp_poly
	return placement_poly(data)


## Ground point on this foundation nearest to the incoming position.
func closest_footprint_point(origin: Vector2) -> Vector2:
	var center := global_position
	var local := origin - center
	var poly: PackedVector2Array = footprint_poly()
	if Geometry2D.is_point_in_polygon(local, poly): return origin
	var best := center
	var best_distance := INF
	for i in poly.size():
		var edge := Geometry2D.get_closest_point_to_segment(local, poly[i], poly[(i + 1) % poly.size()])
		var distance := local.distance_squared_to(edge)
		if distance < best_distance:
			best_distance = distance
			best = center + edge
	return best

## 占地的轴对齐包围盒（局部坐标）
func footprint_rect() -> Rect2:
	return Placement.aabb(footprint_poly())


## 占地外接半径
func footprint_radius() -> float:
	if _fp_poly.size() >= 3: return _fp_radius
	var m := 0.0
	for p in footprint_poly():
		m = maxf(m, p.length())
	return m


## 深度排序锚点（世界坐标）：取占地多边形的形心。
## 建筑节点原点常落在占地前沿附近，直接用原点做深度键会把建筑画得过于靠前、
## 遮住紧贴建筑站立的单位（表现为「兵掉进建筑里」）。用形心可让建筑只在
## 真正位于其后方的单位之上绘制。
var _depth_anchor := Vector2.ZERO
var _depth_anchor_ok := false
func depth_anchor() -> Vector2:
	if not _depth_anchor_ok:
		var poly := footprint_poly()
		var c := Vector2.ZERO
		for p in poly:
			c += p
		if poly.size() > 0:
			c /= float(poly.size())
		_depth_anchor = global_position + c
		_depth_anchor_ok = true
	return _depth_anchor


## 从本地原点沿 dir 射出、穿出占地多边形的距离（原点在占地外时退回外接半径）
func footprint_clearance(dir: Vector2) -> float:
	var poly := footprint_poly()
	if poly.size() < 3:
		return radius + 12.0
	var d := dir.normalized()
	var t := -1.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var den := d.cross(e)
		if absf(den) < 0.0001:
			continue
		var tt := a.cross(e) / den
		if tt <= 0.0:
			continue
		var uu := a.cross(d) / den
		if uu >= -0.001 and uu <= 1.001:
			t = maxf(t, tt)
	if t < 0.0:
		return footprint_radius() + 12.0
	return t


func _apply_physics() -> void:
	# RA2 判定：碰撞体 = 真实占地多边形（SHP 美术底盘四点，扫不到时退回 foundation 矩形），
	# 旧版只有一个小圆，地面单位会直接从建筑身上穿过去。
	var poly := footprint_poly()
	if poly.size() >= 3:
		var cp := CollisionPolygon2D.new()
		cp.polygon = poly
		add_child(cp)
	else:
		var shape := CircleShape2D.new()
		shape.radius = radius
		var cs := CollisionShape2D.new()
		cs.shape = shape
		add_child(cs)
	collision_layer = 2
	collision_mask = 0

## 建筑基底（Footprint 地面中心）：本节点 global_position 即占地网格中心，
## 因此在本地绘制空间里地基中心恒为原点 (0, 0)。
func footprint_center() -> Vector2:
	return Vector2.ZERO

## 基底的半宽/半高（世界单位），由 RA2 的 foundation（如 "4x3"）换算而来；
## 缺少 foundation 时退回碰撞半径（近似为 1 格建筑）。
func footprint_extents() -> Vector2:
	var f_str: String = String(data.get("foundation", ""))
	if not f_str.is_empty() and "x" in f_str:
		var parts := f_str.split("x")
		if parts.size() >= 2:
			var gw := float(parts[0]) * BUILD_GRID * 0.5
			var gh := float(parts[1]) * BUILD_GRID * 0.5
			return Vector2(gw, gh)
	var r := float(data.get("radius", radius))
	return Vector2(r, r)

## RA3 式：水上建筑的浮动平台 + 波纹（替代普通地表阴影）。
func _draw_water_platform(_r: float) -> void:
	var c := footprint_center()
	var e := footprint_extents()
	draw_colored_polygon(Iso.ell(c, e.x * 1.55, e.y * 1.55), Color(0.10, 0.13, 0.16, 0.96))
	draw_colored_polygon(Iso.ell(c, e.x * 1.30, e.y * 1.30), Color(0.20, 0.23, 0.27, 0.96))
	Iso.outline(self, Iso.ell(c, e.x * 1.55, e.y * 1.55), Color(0.35, 0.5, 0.62, 0.75), 2.0)
	for i in 2:
		var rr := 1.75 + float(i) * 0.4
		Iso.outline(self, Iso.ell(c, e.x * rr, e.y * rr), Color(0.6, 0.86, 1.0, 0.2 - float(i) * 0.07), 1.0)

## 基底菱形（2:1 等距）的 4 个角点，本地绘制空间坐标：
## 上(N) / 右(E) / 下(S) / 左(W)，与建造预览网格完全重合。
func footprint_corners() -> PackedVector2Array:
	var e := footprint_extents()
	var hw := e.x
	var hh := e.y
	return PackedVector2Array([
		Iso.dir(Vector2(-hw, -hh)),
		Iso.dir(Vector2(hw, -hh)),
		Iso.dir(Vector2(hw, hh)),
		Iso.dir(Vector2(-hw, hh)),
	])

## 选中角标/地基环使用的四角（优先贴合素材底盘，否则用占地网格）。
func _sel_corners() -> PackedVector2Array:
	if _sel_poly.size() >= 3:
		return _sel_poly
	return footprint_corners()

## RA2 风格选中角标：在角点各画两个 ≤ 1/4 边长的直角臂。
func _draw_selection_brackets(col: Color, w: float) -> void:
	var c := _sel_corners()
	var n := c.size()
	for i in n:
		var p: Vector2 = c[i]
		var q: Vector2 = c[(i + 1) % n]
		var o: Vector2 = c[(i + n - 1) % n]
		draw_line(p, p + (q - p) * 0.25, col, w)
		draw_line(p, p + (o - p) * 0.25, col, w)

var _body_visibility: VisibleOnScreenNotifier2D

func _ready() -> void:
	if battle is Battle and not _ra2.is_empty():
		var reach := maxf(480.0, radius * 6.0)
		_body_visibility = VisibleOnScreenNotifier2D.new()
		_body_visibility.rect = Rect2(-Vector2.ONE * reach, Vector2.ONE * 2.0 * reach)
		_body_visibility.screen_entered.connect(queue_redraw)
		add_child(_body_visibility)
	if battle is Battle and battle.building_art_warmup != null and (_buildup_play >= 0.0 or under_construction):
		battle.building_art_warmup.prepare(self)
	MetaProgress.register_model_display(self)
	var fire := preload("res://scripts/buildings/building_damage_fire.gd").new()
	fire.bind(self)
	add_child(fire)
	var repair_indicator := preload("res://scripts/buildings/building_repair_indicator.gd").new()
	repair_indicator.bind(self)
	add_child(repair_indicator)
	add_to_group("buildings")
	if is_refinery(): add_to_group("ore_refineries")
	BattleRequest.sync_house_groups(self)
	if side in ["ally", "enemy"] or BattleRequest.house_teams.has(side):
		add_to_group("ally_buildings" if side == "ally" else "enemy_buildings")
		add_to_group("allies" if side == "ally" else "enemies")
		add_to_group("enemy_targets" if side == "ally" else "ally_targets")
	_think = randf() * 0.3
	if WallArt.is_wall(data):
		if battle is Battle: battle.wall_cells[WallArt.cell_at(global_position)] = self
		WallArt.refresh_neighbors(self)

func _enter_tree() -> void:
	if battle is Battle:
		battle.invalidate_building_membership()
		battle.simulation.register(self,footprint_radius(),true)
		set_notify_local_transform(true)

func _notification(what:int) -> void:
	if what==NOTIFICATION_LOCAL_TRANSFORM_CHANGED and battle is Battle and is_inside_tree():
		battle.simulation.relocate(self)

func _exit_tree() -> void:
	if battle is Battle:
		battle.invalidate_building_membership()
		set_notify_local_transform(false)
		battle.simulation.remove(self)
	if WallArt.is_wall(data):
		if is_instance_valid(battle) and battle is Battle:
			var cell := WallArt.cell_at(global_position)
			if is_same(battle.wall_cells.get(cell), self): battle.wall_cells.erase(cell)
		remove_from_group("buildings")
		WallArt.refresh_neighbors(self)

## Actual placement only: map fixtures also play buildup, but must not flash.
func notify_construction_placed() -> void:
	if CONSTRUCTION_FREE_UNITS.has(building_id) and not special.has("construction_free_unit"):
		special["construction_free_unit"] = CONSTRUCTION_FREE_UNITS[building_id]
	_completion_flash_pending = true
	if not under_construction and _buildup_play < 0.0:
		_start_completion_flash()

func _start_completion_flash() -> void:
	_completion_flash_pending = false
	_completion_flash_left = COMPLETION_FLASH_SECONDS

func _tick_construction_free_unit(delta: float) -> void:
	var uid := str(special.get("construction_free_unit", ""))
	if uid.is_empty() or not is_operational() or is_queued_for_deletion():
		return
	_free_unit_retry = maxf(0.0, _free_unit_retry - delta)
	if _free_unit_retry > 0.0:
		return
	_free_unit_retry = 0.25
	if battle is Battle and battle.ai_population_full(side): return
	var exit_pos := _spawn_point(uid)
	if exit_pos == Vector2.INF:
		return
	# Persist both pending and consumed state in the existing snapshot dictionary.
	# Clear before spawn signals, so a save/reentrant callback cannot grant it twice.
	special["construction_free_unit"] = ""
	var unit = battle.spawn_unit(uid, side, exit_pos, self)
	if unit == null:
		special["construction_free_unit"] = uid
		return
	if side == "ally":
		Ra2Sfx.play_player_eva(battle, "EVA_UnitReady")

func _tick_completion_flash(delta: float) -> void:
	if _completion_flash_left <= 0.0:
		return
	_completion_flash_left = 0.0 if _dead else maxf(0.0, _completion_flash_left - delta)
	# Two brightness pulses. Keep alpha/fog visibility and shared house materials intact.
	var elapsed := COMPLETION_FLASH_SECONDS - _completion_flash_left
	var pulse := pow(sin(PI * elapsed / (COMPLETION_FLASH_SECONDS * 0.5)), 2.0)
	var brightness := 1.0 + 0.7 * pulse if _completion_flash_left > 0.0 else 1.0
	self_modulate = Color(brightness, brightness, brightness, 1.0)

func _process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(7)
	if special.has("tesla_pulse"):preload("res://scripts/buildings/tesla_pulse.gd").tick(self,delta)
	if special.has("reaper_focus") or special.has("split_focus") or special.has("reaper_heat"): preload("res://scripts/units/ra3_reaper_split.gd").advance_focus(self,delta)
	if special.has("occupants"):preload("res://scripts/units/civilian_orders.gd").tick_building(self)
	if building_id=="YAPSYT": preload("res://scripts/units/head_games_weapons.gd").tower(self,delta)
	if building_id=="GACNST" and special.has(Ra3Clearance.KEY):Ra3Clearance.tick(self, delta)
	if not _dead:
		if special.has("airstrike_mark") or special.has("airstrike_left") or special.has("iron_left") or special.has("ivan_bomb"):
			preload("res://scripts/units/soviet_specials.gd").tick_actor(self, delta)
		AlliedAbilities.tick_actor(self, delta)
	if _dead or AlliedAbilities.frozen(self): return
	if special.has("ore_smoke_puffs") and not battle.paused:
		preload("res://scripts/units/hollywood_unit_fx.gd").advance_smoke(self,delta)
	if special.has("hero_escort_queue"):
		special.hero_escort_retry=float(special.get("hero_escort_retry",0.0))-delta
		if special.hero_escort_retry<=0.0: MetaProgress.Academy.release_escorts(self)
	if building_id == "CAOILD": preload("res://scripts/world/civilian_sites.gd").oil_income(self, delta)
	if building_id == "CAMACH": preload("res://scripts/world/civilian_sites.gd").repair_vehicles(self, delta)
	if building_id == "CATHOSP" and battle.mission.get("id") == "yr_hollywood": battle.Hollywood.hospital_heal(self, delta)
	if special.has("force_shield_left"):
		special.force_shield_left -= delta
		self_modulate = Color(0.7, 0.86 + 0.12 * sin(special.force_shield_left * 6.0), 1.4)
		if special.force_shield_left <= 0:
			special.erase("force_shield_left")
			self_modulate = Color.WHITE
	if _completion_flash_left>0.0:_tick_completion_flash(delta)
	if special.has("campaign_flash_left"):
		var left:=maxf(0.,float(special.campaign_flash_left)-delta)
		var glow:=1.0+0.85*pow(sin(left*PI*2.0),2)
		modulate=Color(glow,glow,1.,1.)
		if left<=0: special.erase("campaign_flash_left")
		else: special.campaign_flash_left=left
	if not _dead and _turret_art.advance_recoil(delta):
		queue_redraw()
	if _buildup_play >= 0.0:
		var make_speed := float(special.get("native_make_speed",1.0))
		# Keep the stored native animation cursor; only placed-building playback accelerates.
		if not special.has("mcv_make_radius"): make_speed *= BattleClock.PLACED_BUILDUP_SCALE
		if GM.no_build_time: make_speed = GameData.ra2_buildup_seconds() / GM.FAST_BUILD_SECONDS
		_buildup_play += delta * make_speed
		if _buildup_play >= GameData.ra2_buildup_seconds():
			_buildup_play = -1.0
			if _completion_flash_pending:
				_start_completion_flash()
		queue_redraw()
	if not superweapon.is_empty() or special.has("sw_discharge_age"):_tick_superweapon(delta)
	# Only a visible outage warning pulses; restoring power redraws once to clear it.
	if _refresh_power_warning():
		queue_redraw()
	# ---- RA2 建筑动画层：状态机推进 + 帧号变化才重绘（每层 Rate 不同，取各层帧号做指纹）
	if not _dead and not _ra2_anim.is_empty():
		_anim_t += delta
		_tick_anim_state(delta)
		# Clocks and gameplay keep advancing offscreen; inspect sprite frames only
		# where their draw list can be consumed. Re-entry already requests a redraw.
		if is_visible_in_tree() and _animation_draw_needed(): queue_redraw()
	if _dead:
		return
	if selected or hovered:
		queue_redraw()
	# 血条表现：白闪快速退散 + 残影追赶；受损时逐帧重绘以驱动脉冲闪烁
	if _hp_flash > 0.0:
		_hp_flash = maxf(0.0, _hp_flash - delta * 5.0)
	var _hpf: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	if _hp_ghost > _hpf:
		_hp_ghost = maxf(_hpf, _hp_ghost - delta * 1.2)
	else:
		_hp_ghost = _hpf
	if _hp_flash > 0.0 or _hp_ghost > _hpf + 0.004 or _hpf < 0.999:
		queue_redraw()
	# 建造进度（RA3：一边建造一边扣钱；资金不足则暂停）
	if under_construction:
		# RA2 低电：建造计时与分帧付款同步乘速度系数（总花费不变，工期变长）
		var pf := construction_work_rate()
		var step := minf(maxf(0.0, delta * pf), maxf(0.0, build_total - build_elapsed))
		var previous_elapsed := build_elapsed
		var pay_ok := true
		if build_cost > 0.0:
			pay_ok = battle.spend_side(side, build_cost / max(0.01, build_total) * step)
		if pay_ok:
			build_elapsed += step
			_pay_stall = false
		elif not _pay_stall:
			_pay_stall = true
			Events.emit_message("资金不足，%s 建造暂停" % display_name, Color(1.0, 0.8, 0.5))
			if side == "ally":
				Ra2Sfx.play_player_eva(battle, "EVA_InsufficientFunds")
		var k := clampf(build_elapsed / max(0.01, build_total), 0.0, 1.0)
		# Only newly completed work adds structural health. Never replace current
		# HP with the progress curve: that erased damage every frame, even stalled.
		var health_added := max_hp * 0.85 * (build_elapsed - previous_elapsed) / maxf(0.01, build_total)
		hp = minf(max_hp, hp + health_added)
		queue_redraw()
		if k >= 1.0:
			under_construction = false
			if special.erase("player_build_order") and side=="ally":preload("res://scripts/world/production_counts.gd").record(battle,"building",building_id)
			_start_completion_flash()
			if WallArt.is_wall(data):
				WallArt.refresh_neighbors(self)
			Events.emit_message("%s 建造完成" % display_name, _col)
			battle.strategic_site_completed(self, true)
			if side == "ally":
				Events.emit_radar_ping(global_position, "ready")   # (B3) 建成闪烁
				Ra2Sfx.play_player_eva(battle, "EVA_ConstructionComplete")
				Ra2Sfx.play_player_eva(battle, "EVA_NewConstructionOptions")
		return

	if not str(special.get("construction_free_unit", "")).is_empty():_tick_construction_free_unit(delta)

	# 资金涓流（RA2：Powered 建筑低电停摆时不再涓流，如矿石精炼器 GAOREP）
	if trickle > 0.0 and is_operational():
		battle.credit_income(side, trickle * delta, true)

	# (A4) 维修厂：为驻停的受损载具回血
	if _is_repair:
		_process_repair(delta)

	if repairing:_process_building_repair(delta)

	if not production.is_empty():_tick_unit_queues(delta)

	if building_id=="R3REAPERTURRET":
		preload("res://scripts/buildings/ra3_reaper_emplacement.gd").tick(self,delta)
		return
	# 炮塔
	if not weapon.is_empty():
		if data.has("charged_weapon"): preload("res://scripts/units/tesla_support.gd").update_weapon(self)
		if _prism_offline > 0.0:
			_prism_offline -= delta
		if _prism_offline > 0.0 or not is_operational():
			special.erase("coil_windup")
			if building_id=="YAGGUN":
				_gatling_followup_target = null
				_tick_gatling(delta,false)
			return
		_think -= delta
		if _think <= 0.0:
			_think = 0.25
			_acquire_target()
		_cd = maxf(0.0, _cd - delta)
		var can_track:=_valid_weapon_target(attack_target)
		if building_id=="YAGGUN":
			_tick_gatling(delta,can_track and _turret_art.aligned(attack_target.global_position-global_position))
		if can_track:
			if _turret_turn_speed > 0.0:
				_turret_art.turn_toward(attack_target.global_position - global_position, delta, _turret_turn_speed)
				queue_redraw()
			if building_id == "YAGGUN" and is_instance_valid(_gatling_followup_target):
				_gatling_followup_delay -= delta
				if attack_target != _gatling_followup_target:
					_gatling_followup_target = null
				elif _gatling_followup_delay <= 0.00001:
					_gatling_followup_target = null
					_fire()
			if _cd <= 0.0:
				if data.has("fire_delay") and not preload("res://scripts/units/tesla_support.gd").ready_to_fire(self,delta): return
				if _fire():
					_cd = preload("res://scripts/buildings/tesla_pulse.gd").reload_duration(self)
					special.card_reload_duration=_cd
					if building_id == "YAGGUN" and int(weapon.get("burst",1)) == 2:
						_gatling_followup_target = attack_target
						_gatling_followup_delay = float(weapon.get("burst_delay",0.1))
		elif building_id == "YAGGUN":
			_gatling_followup_target = null
		elif data.has("fire_delay"):
			special.erase("coil_windup")

const Parallel = preload("res://scripts/buildings/parallel_production.gd")
const HollywoodTurrets = preload("res://scripts/units/hollywood_turret_pose.gd")

func _tick_gatling(delta:float,engaged:bool) -> void:
	var rules:=_turret_art.gatling
	var charge:float=special.get("gattling_charge",0.0)
	if not engaged and charge<=0 and _turret_art.spin_pose==0: return
	var rate:float=rules.rate_up if engaged else -float(rules.rate_down)
	charge=clampf(charge+delta*BattleClock.RULE_TICKS_PER_SECOND*rate,0,float(rules.stages.back()))
	special.gattling_charge=charge
	_turret_art.spin_pose=HollywoodTurrets.spin(self,delta,charge,rules.stages)
	queue_redraw()

func _tick_unit_queues(delta: float) -> void:
	if production.is_empty() or not is_operational(): return
	Parallel.prepare(self)
	var heads: Array = [str(production[0])]
	if Parallel.enabled(self):
		for uid in production:
			if Parallel.lane(str(uid)) != Parallel.lane(str(heads[0])):
				heads.append(str(uid))
				break
	for uid: String in heads:
		if not (battle is Battle and battle.ai_production_full(side,uid,self,false)): _tick_unit_queue(delta,uid)

func _tick_unit_queue(delta: float, uid: String) -> void:
	var index := production.find(uid)
	if index < 0 or not unit_prereqs_ok(uid): return
	var state := Parallel.state(self,uid)
	if state.paused: return
	var ud := GameData.get_unit(uid)
	if uid in ["ORCA", "BEAG"] and battle.aircraft_population(side) > battle.aircraft_capacity(side): return
	var bt: float = GameData.ra2_build_time(ud) / max(0.1, build_speed)
	var step := minf(maxf(0.0, delta * production_work_rate(uid)), maxf(0.0, bt - float(state.progress)))
	if not state.has("price"):
		state.price = float(ud.cost) if float(state.paid) > 0.0 else battle.production_price(ud, side)
	var ucost: float = state.price
	var need := minf(ucost / maxf(0.01, bt) * step, maxf(0.0, ucost - float(state.paid)))
	var pay := minf(need, maxf(0.0, battle.funds_for(side)))
	if side == "ally" and GM.infinite_funds: pay = need
	if pay > 0.0 and not battle.spend_side(side, pay): pay = 0.0
	state.paid += pay
	if need > 0.0: step *= pay / need
	state.progress += step
	var completed := false
	if float(state.progress) >= bt - 0.000001 and float(state.paid) >= ucost - 0.0001:
		var exit_pos := _spawn_point(uid)
		state.blocked = exit_pos == Vector2.INF
		if not state.blocked:
			_exit_air = (ud.get("tags", []) as Array).has("air")
			production.remove_at(index)
			state = Parallel.empty_state()
			Parallel.store(self,uid,state)
			var produced=battle.spawn_unit(uid, side, exit_pos, self, true)
			if battle.skirmish and data.tags.has("barracks"):
				preload("res://scripts/world/yuri_support.gd").clone_infantry(battle,self,produced)
			preload("res://scripts/rules/hero_reinforcements.gd").produced(battle,self,produced)
			if side == "ally" and produced != null and preload("res://scripts/expedition/research.gd").rank(BattleRequest.combat_context.get("expedition",{}),"factory")>0:
				battle.allied_state.get_or_add("research_built",{})[GameData.unit_production_category(ud)]=true
			if side == "ally" and produced != null:
				preload("res://scripts/world/production_counts.gd").record(battle, "unit", uid)
				MetaProgress.Academy.built(MetaProgress, battle, uid, produced, self)
			play_production_animation()
			_exit_anim_left = EXIT_DOOR_HOLD + _door_open_seconds()
			if side == "ally":
				if uid == Ra3Mirage.ID: Ra2Sfx.play_voice(ud, "created", Vector2.INF, 300)
				else: Ra2Sfx.play_player_eva(battle, "EVA_UnitReady")
			completed = true
	Parallel.store(self,uid,state)
	if completed and side == "ally": Events.production_queue_changed.emit()
	if not _ra2_anim.is_empty() and _anim_state != "special":
		var next_anim := _base_anim_state(_anim_kinds())
		if next_anim != _anim_state: _set_anim_state(next_anim)
	queue_redraw()

func production_head(uid := "") -> int:
	return Parallel.head(self,uid)

func production_for_category(category: String) -> String:
	return Parallel.category_head(self,category)

func queue_elapsed(uid := "") -> float:
	return float(Parallel.state(self,uid).progress)

func total_production_paid() -> float:
	return Parallel.total_paid(self)

func queue_exit_blocked(uid := "") -> bool:
	return bool(Parallel.state(self,uid).blocked)

func _spawn_point(uid: String = "") -> Vector2:
	if ProductionExit.supported(self) or preload("res://scripts/buildings/airport_dock.gd").can_produce(self, uid):
		return ProductionExit.point(self, uid)
	var ud := GameData.get_unit(uid)
	var naval: bool = str(ud.get("role", "")) == "naval" or (ud.get("tags", []) as Array).has("naval")
	var air: bool = (ud.get("tags", []) as Array).has("air")
	var unit_radius := maxf(1.0, float(ud.get("radius", 8.0)))
	# Unmapped legacy buildings retain their old fallback until their art ports are calibrated.
	# 不因随机数改变出口；无合法位置时保留队首等待，舰船绝不退回陆地。
	for extra in [26.0, 66.0, 106.0]:
		for i in range(24):
			var d := Vector2.DOWN.rotated(TAU * float(i) / 24.0)
			var p: Vector2 = global_position + d * (footprint_clearance(d) + float(extra) + unit_radius)
			if _exit_position_clear(p, unit_radius, naval, air):
				return p
	return Vector2.INF

func _exit_position_clear(p: Vector2, unit_radius: float, naval: bool, air: bool) -> bool:
	if battle == null:
		return false
	# 中心与外圈都检查，防止中心在岸边/地图内而身体跨入阻挡。
	for i in range(9):
		var sample := p if i == 0 else p + Vector2.RIGHT.rotated(TAU * float(i - 1) / 8.0) * unit_radius
		if sample.x < 0.0 or sample.y < 0.0 or sample.x >= battle.map_size or sample.y >= battle.map_size:
			return false
		if not air and (battle.path_service == null or battle.path_service.is_blocked(sample, naval)):
			return false
		if naval and not battle.in_water_world(sample):
			return false
	var candidates: Array = battle.units
	if battle is Battle and battle.units.size() >= 96:
		candidates = battle.neighborhood.nearby(p, unit_radius + battle.neighborhood.max_unit_radius + 2.0)
	for u in candidates:
		if not is_instance_valid(u) or not u is Unit or u.is_queued_for_deletion() or u.hp <= 0.0 or u.embarked_in != null or u.is_air != air:
			continue
		if p.distance_squared_to(u.global_position) < pow(unit_radius + u.radius + 2.0, 2):
			return false
	return true

# ------------------------------------------------------------------ 生产

## 生产队列上限（对齐红警2 侧栏：9 个）
const MAX_QUEUE: int = 9

func apply_mission_production_limits() -> void:
	if not GameData.mission_production_tech().is_empty():
		buildable = buildable.filter(func(id): return GameData.mission_tech_block_reason(id).is_empty())

func queue_capacity() -> int:
	if is_refinery():
		if battle != null and battle.production_technology.is_unlocked(battle.production_technology.MINER_QUEUE, side):
			return battle.production_technology.MINER_CAPACITY
		return 1
	return battle.production_technology.unit_capacity(side) if battle!=null else MAX_QUEUE

func can_queue(uid: String) -> bool:
	if battle is Battle and battle.ai_production_full(side,uid,self): return false
	if side == "enemy" and battle != null and is_instance_valid(battle.skirmish_ai) and not GameData.ai_product_allowed(uid): return false
	if battle != null and not battle.hero_limit_reason(uid, side).is_empty(): return false
	if uid in ["ORCA", "BEAG"] and battle != null:
		if battle.aircraft_population(side) >= battle.aircraft_capacity(side):
			return false
	return buildable.has(uid) and unit_prereqs_ok(uid)

func unit_prereqs_ok(uid: String) -> bool:
	# Orders from older saves may predate the limit. Never count the queue itself here.
	if battle != null and not battle.hero_limit_reason(uid, side, false).is_empty(): return false
	if not GameData.unit_production_block_reason(uid, battle.allied_state if battle != null else {}, side).is_empty():
		return false
	if preload("res://scripts/expedition/rules.gd").licensed_production(uid, side):
		return battle != null and buildable.has(uid)
	if not production_tech_block_reason(uid).is_empty():
		return false
	if battle != null and not battle.country_block_reason(uid, side).is_empty():
		return false
	if is_refinery() and uid == CONSTRUCTION_FREE_UNITS.get(building_id):
		return battle != null
	if battle is Battle: return battle.production_prereqs_ok(uid, side)
	return battle != null and GameData.ra2_prereq_ok(uid, battle.owned_building_ids(side), battle.allied_state, side)

func production_tech_block_reason(uid: String) -> String:
	if preload("res://scripts/expedition/rules.gd").licensed_production(uid, side): return ""
	var clearance := Ra3Clearance.block_reason(self, uid)
	if not clearance.is_empty(): return clearance
	return battle.production_technology.block_reason(building_id, uid, side) if battle != null else ""

func queue_block_reason(uid: String) -> String:
	if battle is Battle and battle.ai_production_full(side,uid,self): return "本家电脑单位已达 %d 上限（含在训）" % Battle.AI_UNIT_LIMIT
	if side == "enemy" and battle != null and is_instance_valid(battle.skirmish_ai) and not GameData.ai_product_allowed(uid): return "遭遇战 AI 禁止生产 RA3 单位"
	if battle != null:
		var limit: String = battle.hero_limit_reason(uid, side)
		if not limit.is_empty(): return limit
	if _dead:
		return "生产建筑已被摧毁"
	if under_construction:
		return "%s 施工中" % display_name
	var roster_reason := GameData.unit_production_block_reason(uid, battle.allied_state if battle != null else {}, side)
	if not roster_reason.is_empty():
		return roster_reason
	if not buildable.has(uid):
		return "%s 无法生产该单位" % display_name
	var technology_reason := production_tech_block_reason(uid)
	if not technology_reason.is_empty():
		return technology_reason
	if battle != null:
		var country_reason: String = battle.country_block_reason(uid, side)
		if not country_reason.is_empty():
			return country_reason
	if not unit_prereqs_ok(uid):
		if battle == null:
			return "这座建筑暂时无法生产"
		return "缺少前置：" + GameData.ra2_missing_prereq_names(uid, battle.owned_building_ids(side), battle.allied_state, side)
	if uid in ["ORCA", "BEAG"] and battle != null:
		if battle.aircraft_population(side) >= battle.aircraft_capacity(side):
			return "停机位已满（含在产战机），需增加空指部"
	if is_refinery() and not is_operational():
		return "缺电停工" if powered and battle != null and battle.power_low else "矿场等待展开"
	if Parallel.count(self,uid) >= queue_capacity():
		return "生产队列已满（上限 %d）" % queue_capacity()
	return ""

func order_recipe(orders: Array) -> String:
	if battle == null or side != "ally" or not BattleRequest.extensions_enabled() or not battle.production_technology.is_unlocked("production_recipes", side):
		return "需要研究生产配方"
	if battle.paused or battle.ended or get_tree().paused: return "请在对局进行时下单"
	if is_refinery() or orders.is_empty(): return "请选择单位生产工厂和配方"
	var accepted := 0
	var skipped := 0
	var first_reason := ""
	var first_unit := ""
	for item in orders:
		var uid := str(item)
		var reason := queue_block_reason(uid)
		if not reason.is_empty():
			skipped += 1
			if first_reason.is_empty():
				first_reason = str(GameData.get_unit(uid).get("name", uid)) + " · " + reason
			continue
		if accepted == 0:
			Parallel.prepare(self)
			first_unit = uid
		production.append(uid)
		accepted += 1
	if accepted > 0:
		battle.invalidate_ai_population()
		_announce_production(first_unit, 1000)
		Events.production_queue_changed.emit()
		queue_redraw()
	if skipped > 0:
		return "已排入 %d 项，跳过 %d 项。%s" % [accepted, skipped, first_reason]
	return ""

func enqueue(uid: String) -> bool:
	return enqueue_many(uid, 1) == 1

func _announce_production(uid: String, gap_ms: int) -> void:
	var unit_data := GameData.get_unit(uid)
	var training: bool = data.get("tags", []).has("barracks") or unit_data.get("role") == "infantry" or unit_data.get("tags", []).has("infantry")
	Ra2Sfx.play_player_eva(battle, "EVA_Training" if training else "EVA_Building", gap_ms)

## 批量入队（Shift 点击 / 长按一次排 5 个）：返回实际入队数量，费用随生产进度扣除。
func enqueue_many(uid: String, n: int) -> int:
	var got: int = 0
	for _i in range(maxi(0, n)):
		if not queue_block_reason(uid).is_empty():
			break
		if got == 0:
			Parallel.prepare(self)
		production.append(uid)
		if battle is Battle: battle.invalidate_ai_population()
		got += 1
	if got > 0:
		if side == "ally":
			_announce_production(uid, 1000)
			Events.production_queue_changed.emit()
		queue_redraw()
	return got

func production_paused(uid := "") -> bool:
	return production_head(uid) >= 0 and bool(Parallel.state(self,uid).paused)

func resume_production(uid: String) -> bool:
	var head := production_head(uid)
	if head < 0 or str(production[head]) != uid or not production_paused(uid): return false
	var state := Parallel.state(self,uid)
	state.paused = false
	Parallel.store(self,uid,state)
	if side == "ally":
		_announce_production(uid, 0)
		Events.production_queue_changed.emit()
	return true

## Right-click active type: hold first, then cancel one matching order from the tail.
## Waiting types can be removed directly, without affecting the active work.
func production_right_click(uid: String, index: int = -1) -> bool:
	if production.is_empty(): return false
	if index >= production.size(): return false
	var head := production_head(uid)
	var active := head >= 0 and str(production[head]) == uid and (index < 0 or index == head)
	if active and not production_paused(uid):
		var state := Parallel.state(self,uid)
		state.paused = true
		Parallel.store(self,uid,state)
		if side == "ally":
			Events.production_queue_changed.emit()
			Ra2Sfx.play_player_eva(battle, "EVA_OnHold", 500)
			Events.emit_message("生产已暂停：左键继续，右键取消", Color(1.0, 0.8, 0.5))
		return true
	if index >= 0: return cancel_at(index)
	for i in range(production.size() - 1, -1, -1):
		if str(production[i]) == uid: return cancel_at(i)
	return false

func cancel_queue() -> void:
	if production.is_empty():
		return
	cancel_at(production.size()-1)

## 取消队列中指定下标的单位（红警2：右键队列项取消该单位），并全额退款。
## 取消的若是“正在生产”的那一个（下标 0），进度归零。
func cancel_at(idx: int) -> bool:
	if idx < 0 or idx >= production.size():
		return false
	var uid: String = str(production[idx])
	var state := Parallel.state(self,uid)
	var active := idx == Parallel.stored_head(self,uid)
	production.remove_at(idx)
	if battle is Battle: battle.invalidate_ai_population()
	if battle is Battle: preload("res://scripts/world/ai_emergency_engineer.gd").cancelled(battle,self,uid)
	if active:
		battle.credit_side(side, float(state.paid))
		Parallel.store(self,uid,Parallel.empty_state())
	else: Parallel.sync(self)
	if side == "ally": Events.production_queue_changed.emit()
	queue_redraw()
	if side == "ally":
		Ra2Sfx.play_player_eva(battle, "EVA_Canceled", 500)
	return true

func queue_progress(uid := "") -> float:
	var head := production_head(uid)
	if head < 0:
		return 0.0
	uid = str(production[head])
	var ud := GameData.get_unit(uid)
	var bt: float = GameData.ra2_build_time(ud) / max(0.1, build_speed)
	return clampf(queue_elapsed(uid) / max(0.01, bt), 0.0, 1.0)

# ------------------------------------------------------------------ 炮塔

func supports_attack_order() -> bool:
	return not weapon.is_empty() or building_id == "R3REAPERTURRET" or data.has("garrison_weapons") or data.has("charged_weapon")

func attack_order_reason(target) -> String:
	if data.has("garrison_weapons"):
		return preload("res://scripts/units/civilian_orders.gd").order_block_reason(self, target)
	if building_id == "R3REAPERTURRET":
		return "" if preload("res://scripts/buildings/ra3_reaper_emplacement.gd").accepts_order(self, target) else "请选择射程内可攻击的敌人"
	if not data.has("charged_weapon"):
		if not battle.actor_alive(target) or target.side in [side,"neutral"]: return "请选择敌方目标"
		return ForceFire.reason(battle,self,target)
	if not is_operational(): return "磁暴线圈尚未就绪或供电不足"
	if not battle.actor_alive(target) or target.side == side or target.side == "neutral": return "请选择敌方目标"
	if target is Unit and target.is_air_target(): return "磁暴线圈只能攻击地面目标"
	preload("res://scripts/units/tesla_support.gd").update_weapon(self)
	if not _valid_weapon_target(target): return "请选择射程内可见且可攻击的敌方目标"
	return ""

func _acquire_target() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(8)
	if ForceFire.active(self, attack_target):
		if _valid_weapon_target(attack_target): return
		ForceFire.clear(self)
	var order_key := "coil_ordered_target" if data.has("charged_weapon") else "defense_ordered_target"
	if special.has(order_key):
		if is_instance_valid(attack_target) and special[order_key] == attack_target and attack_target.side != side and attack_target.side != "neutral" and _valid_weapon_target(attack_target):
			return
		special.erase(order_key)
	var current = attack_target
	attack_target = null
	var best := -INF
	var group := BattleRequest.foes_group(side)
	var local_search:bool=battle is Battle and battle.units.size()>=96
	var search_range := float(data.guns[1].range) if building_id == "YAGGUN" else attack_range
	var contacts:Array=battle.neighborhood.nearby(global_position,search_range) if local_search else get_tree().get_nodes_in_group(group)
	for e in contacts:
		if (local_search and not e.is_in_group(group)) or not _valid_weapon_target(e):
			continue
		var score := preload("res://scripts/core/tactical_targeting.gd").score(self, e, weapon, current)
		if score > best or (local_search and score==best and is_instance_valid(attack_target) and attack_target.is_greater_than(e)):
			best = score
			attack_target = e

func _valid_weapon_target(target, force_order: bool = false) -> bool:
	if BattleRequest.is_ai_house(side) and is_instance_valid(target) and target is Building and WallArt.is_wall(target.data): return false
	if not is_instance_valid(target) or target.is_queued_for_deletion() or float(target.get("hp")) <= 0.0:
		return false
	if target is Building and (target.is_protected_mission_plant() or float(target.special.get("force_shield_left", 0.0)) > 0.0): return false
	var distance_sq := global_position.distance_squared_to(target.global_position)
	var minimum := maxf(0.0,float(weapon.get("min_range",0.0)))
	var reach := attack_range
	if building_id == "YAGGUN": reach = float(data.guns[1 if target is Unit and target.is_air_target() else 0].range)
	if distance_sq > reach * reach or distance_sq < minimum * minimum: return false
	if AlliedAbilities.alive(target.special.get("temporal_by")): return false
	if NavalContact.underwater_type(target): return false
	if target is Unit and AlliedAbilities.concealed(target, side): return false
	if battle != null and not target is ForceFirePoint and not battle.actor_visible_to(side, target,self):
		return false
	if (BattleRequest.friendly(str(target.get("side")),side) or (target is Unit and target.side == "neutral")) and not force_order and not ForceFire.active(self, target):
		return false
	if target.has_method("set_stowed") and target.embarked_in != null:
		return false
	var air: bool = target.is_air_target() if target.has_method("is_air_target") else target.get("is_air") == true
	if (air and building_id != "YAGGUN" and not CombatMath.can_hit_air(weapon)) or (not air and not _ground_targeting_allowed):
		return false
	var shot_weapon := _gatling_weapon(air) if building_id == "YAGGUN" else weapon
	return not WallArt.shot_blocked(battle, self, target, shot_weapon)

func _gatling_weapon(air: bool) -> Dictionary:
	var charge := float(special.get("gattling_charge", 0.0))
	var stage := HollywoodTurrets.stage(charge, _turret_art.gatling.stages)
	return data.guns[stage * 2 + int(air)]

func _fire() -> bool:
	# RA2：Powered 防御建筑（磁暴线圈/光棱塔）低电时离线、不再开火
	if not is_operational() or not _valid_weapon_target(attack_target):
		return false
	if _turret_turn_speed > 0.0 and not _turret_art.aligned(attack_target.global_position - global_position):
		return false
	if battle != null:
		battle.reveal_attack(self, attack_target)
	if building_id == "YAGGUN":
		var air := attack_target is Unit and (attack_target as Unit).is_air_target()
		weapon = _gatling_weapon(air)
		cooldown = float(weapon.cooldown)
	var t_ra2 = attack_target.get("ra2_armor")
	var shot_bonus := bonuses.duplicate(true)
	if CombatMath.FinalDamage.active():shot_bonus.reference_weapon=weapon.duplicate(true)
	# 棱镜支援链（T5）：棱镜建筑开火前先拉取友方棱镜助阵，每束 ×prism.modifier 伤害。
	if not prism_type.is_empty():
		shot_bonus["attack_bonus"] = float(shot_bonus.get("attack_bonus", 1.0)) * _prism_support_chain(attack_target)
	var dmg := CombatMath.full_damage(weapon, str(attack_target.get("armor")), shot_bonus, null, "" if t_ra2 == null else str(t_ra2), 0.0, attack_target)
	var muzzle := _weapon_muzzle()
	_spawn_muzzle_fx(muzzle, attack_target.global_position - global_position)
	# RA2 开火音效：weapon Report= → sound.ini → wav
	if building_id == "YAGGUN":
		preload("res://scripts/core/gatling_audio.gd").shot(self,weapon,cooldown)
	else:
		Ra2Sfx.play_weapon(weapon, muzzle)
	var pspd := float(weapon.get("projectile_speed", 0.0))
	# 表现层：激光/光束/电弧武器（原版无 Anim=，靠 IsLaser/IsRadBeam/IsElectricBolt 渲染）
	# → 程序化光束，见 GameData.ra2_beam_spec。棱镜塔（PrismShot）此前无任何激光表现，此处补齐。
	var beam := GameData.ra2_beam_spec(str(weapon.get("ra2_weapon_id", "")))
	if not beam.is_empty():
		var bcol: Color = beam.get("color", _col)
		if (beam.get("house", false) == true):
			bcol = _col
		var end: Vector2 = attack_target.art_center() if beam.kind == "yr_bolt" and attack_target.has_method("art_center") else Effects.hit_position(attack_target)
		Effects.spawn_beam(muzzle, end, bcol, str(beam.get("kind", "laser")),
			float(beam.get("thickness", 2.5)), float(beam.get("duration", 0.12)), Effects.Looks.current(self,true))
	if pspd <= 0.0 and attack_target is ForceFirePoint:
		ForceFire.instant_ground(self, attack_target, weapon, dmg, shot_bonus, battle.projectiles_root if battle != null else self)
	elif pspd <= 0.0:
		var contact := Effects.hit_position(attack_target)
		if beam.is_empty():
			Effects.spawn_beam(muzzle, contact, _col.lightened(0.3))
		_spawn_impact_anim(contact, dmg, Effects.hit_lift(attack_target) <= 0.01)
		if attack_target.has_method("receive_hit"):
			preload("res://scripts/world/bridge_damage.gd").instant_target(self,attack_target,CombatMath.with_offense(float(weapon.get("damage",0.0)),shot_bonus),str(weapon.get("ra2_warhead","")))
			attack_target.receive_hit(dmg, str(weapon.get("attack_type", "bullet")), shot_bonus, self, str(weapon.get("ra2_warhead", "")))
	else:
		var p := Projectile.new()
		p.setup(muzzle, attack_target, weapon, dmg, shot_bonus, side, self)
		var holder := get_tree().get_first_node_in_group("projectiles_root")
		(holder if holder != null else battle).add_child(p)
	_turret_art.start_recoil()
	queue_redraw()
	if not data.has("fire_delay"): play_special()
	preload("res://scripts/units/expansion_2_overload.gd").fired(self)
	return true

## 棱镜支援链（T5）：rules.ini [General] PrismType/PrismSupportModifier/PrismSupportMax/
## PrismSupportDelay/Duration/Height。开火的棱镜（PrismType= 建筑）向周围【同族友方棱镜】求援，
## 每座空闲友方棱镜向主攻塔供能，本次伤害乘以 (1 + 支援数 × modifier)，最多 max 束；
## 支援方随及离线 delay 帧（1/15s/帧）。返回最终伤害倍率（无支援＝1.0）。
## 与 RA2 差异：原版支援光束为 InvisibleHigh 弹道，本作将其作为纯表现（不单独造成伤害），
## 伤害统一挂在主光束上，避免同帧多次 receive_hit。
func _prism_support_chain(target) -> float:
	if not is_instance_valid(target): return 1.0
	var modifier := SupportSystems.general("PrismSupportModifier", 1.5)
	var limit := int(SupportSystems.general("PrismSupportMax", 8))
	var delay := SupportSystems.general("PrismSupportDelay", 45) / 15.0
	var duration := SupportSystems.general("PrismSupportDuration", 15) / 15.0
	var aim := global_position + RA2Art.art_dir(Vector2(0, -SupportSystems.general("PrismSupportHeight", 420) * 30.0 / 256.0))
	var candidates: Array = []
	for b in battle.buildings:
		if not is_instance_valid(b) or b == self or b.side != side or b.prism_type != prism_type: continue
		if not b.is_operational() or b._cd > 0.0: continue
		if b.position.distance_to(position) <= b._prism_support_range: candidates.append(b)
	candidates.sort_custom(func(a, b): return a.position.distance_squared_to(position) < b.position.distance_squared_to(position))
	var count := mini(limit, candidates.size())
	for i in count:
		var supporter = candidates[i]
		supporter._prism_offline = delay
		supporter._prism_aim = aim
		supporter.play_special(duration)
		battle.reveal_attack(supporter, target)
		var origin: Vector2 = supporter.position + RA2Art.art_dir(Vector2(0, -SupportSystems.general("PrismSupportHeight", 420) * 30.0 / 256.0))
		Effects.spawn_beam(origin, aim, _col, "laser", 2.0, duration)
	return 1.0 + modifier * count

func _spawn_muzzle_fx(at: Vector2, dir_world: Vector2) -> void:
	var wid := str(weapon.get("ra2_weapon_id", ""))
	if wid == "":
		return
	var names: Array = GameData.ra2_muzzle_anims(wid)
	if names.is_empty():
		return
	var img := Ra2Fx.pick_directional(names, Iso.dir(dir_world))
	if img == "":
		return
	Ra2Fx.play(Effects._host(), at, img, 1.0, GameData.ra2_muzzle_bright(wid))

## 瞬发开火（无弹道）时按弹头 AnimList= 播放真实命中动画
## 弹着表现（第 8 批）：AnimList= 按【伤害】选档 + Sparky 火花 + Bright 闪光 + 地面灼痕
func _spawn_impact_anim(at: Vector2, dmg: float = 0.0, ground := true) -> void:
	var wid := str(weapon.get("ra2_warhead", ""))
	if wid == "":
		return
	if not Ra2Fx.play_impact(Effects._host(), wid, dmg, at):
		Effects.spawn_impact(at, Color(1.0, 0.85, 0.5), 8.0 + minf(dmg, 200.0) * 0.06)
	if ground: Ra2Fx.spawn_scorch(Effects._host(), wid, dmg, at)

# ------------------------------------------------------------------ 受伤 / 死亡

func ignores_warhead(id: String) -> bool:
	return WallArt.is_wall(data) and not WallArt.can_damage(id, ra2_armor)

func is_protected_mission_plant() -> bool:
	if building_id not in preload("res://scripts/world/time_shift.gd").POWER_PLANTS: return false
	if not is_instance_valid(battle) or battle.mission.get("id")!="yr_time_shift": return false
	return int(battle.allied_state.get("time_shift",{}).get("phase",0)) in [0,1]

func receive_hit(damage: float, attack_type: String = "bullet", attacker_bonus: Dictionary = {}, source = null, warhead_id: String = "") -> void:
	if is_instance_valid(battle) and battle.mission.get("id")=="yr_time_shift" and battle.allied_state.has("time_shift") and is_instance_valid(source) and source.get("side")=="ally":
		if building_id.begins_with("CATIME"):battle.TimeShift.Story.once(battle,"Mis_xS1_ZofiaSaveTimeMach")
		if building_id.begins_with("GAPOWR") and building_id.length()==7:battle.TimeShift.Story.once(battle,"Mis_xS1_ZofiaDoNotKillPower")
	if damage > 0 and is_protected_mission_plant(): return
	if damage > 0 and is_instance_valid(battle) and battle.allied_state.has("yuriko_field") and preload("res://scripts/units/yuriko.gd").protected(battle,self,source,attack_type): return
	if building_id=="CABHUT" and is_instance_valid(battle) and battle.allied_state.get("expedition_bridge_guard",false):return
	if damage > 0.0 and ignores_warhead(warhead_id): return
	var hit_reference:=CombatMath.FinalDamage.hit_reference(self,attacker_bonus,source)
	if building_id == "CABHUT": return # rulesmd: Immune=yes; charges destroy the span.
	if special.has("iron_left"):
		preload("res://scripts/units/soviet_specials.gd").deflect_hit(self, damage)
		return
	if float(special.get("force_shield_left", 0)) > 0 or AlliedAbilities.alive(special.get("temporal_by")): return
	# warhead_id：projectile/单位即时武器等 5 参调用点传入；此前缺此形参会报
	# "Invalid call ... Expected 4 argument(s)"，导致建筑免疫这些伤害（烟测 441 次/100s）。
	if _dead or hp <= 0.0:
		return
	if side == "ally" and GM.god_mode:
		return
	if side == "enemy" and GM.one_shot_kill:
		damage = 999999.0
	var prev_frac: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	# 第 8 批：RA2 量化（正 floor / 负 ceil）
	if damage>0:
		var gun=source.shooter() if source is Projectile else source
		damage=Unit.FactionCards.impact(gun,self,damage,source,attacker_bonus)
		damage=preload("res://scripts/units/electric_cards.gd").crew_damage(gun,self,damage,attacker_bonus)
	damage=preload("res://scripts/units/progression_expansion.gd").impact(self,source,damage,attacker_bonus)
	damage=preload("res://scripts/expedition/rules.gd").impact(self,source,damage,attack_type)
	var defended := CombatMath.with_defense(damage, bonuses)/(1.0+float(special.get("card_armor",0)))
	defended=CombatMath.FinalDamage.apply(defended,hit_reference*defended/damage if damage>0 else 0.0,self,attacker_bonus,source)
	# Cross-game PRISM ratios retain fractions; Yuri warheads keep their rounding.
	var final_dmg := defended if warhead_id in ["RA3_PRISM", "RA3_EXPANSION"] else Ra2Damage.quantize(defended)
	if damage > 0.0 and WallArt.is_wall(data) and WallArt.destroys_wall(warhead_id): final_dmg = hp
	if final_dmg > 0:
		MetaProgress.Academy.hit(self, source)
		if battle != null and battle.fog != null and is_instance_valid(source):
			var shooter = source.shooter() if source is Projectile else source
			if is_instance_valid(shooter) and (shooter is Unit or shooter is Building):
				battle.fog.reveal_building_hit(shooter.side, self)
	if final_dmg > 0 and BattleRequest.is_ai_house(side):
		preload("res://scripts/world/brutal_three.gd").alert(self, source)
		var absorbed := minf(final_dmg, float(special.get("brutal_shield", 0.0)))
		if absorbed > 0:
			special.brutal_shield -= absorbed
			if attacker_bonus.get("leizhu_primary",false):preload("res://scripts/units/leizhu_command.gd").steal(self,source,attacker_bonus,absorbed)
			final_dmg -= absorbed
			if battle != null and battle.actor_visible_to("ally",self):
				var caption := Unit.TankHero.Shield.hit_caption(absorbed,minf(hp,final_dmg),side)
				Effects.spawn_text(global_position,caption,Unit.TankHero.Shield.COLOR,Vector2(0, hp_bar_rect().position.y-24))
	if final_dmg>0 and BattleRequest.combat_context.get("furnace_contract",false):
		MetaProgress.Academy.contract_damage(battle,self,source,final_dmg)
	preload("res://scripts/units/progression_expansion.gd").damaged(self,source,final_dmg,attacker_bonus)
	if final_dmg>0:preload("res://scripts/units/convoy_heroes.gd").damaged(self,source,final_dmg,attacker_bonus)
	if attacker_bonus.get("studio_grenade",false):final_dmg*=Unit.StudioTalents.grenade_multiplier(source,self,attacker_bonus)
	hp -= final_dmg
	if final_dmg>0 and attacker_bonus.has("studio_target"):Unit.StudioTalents.impact(source,self,attacker_bonus)
	if warhead_id == "RA3_PRISM" and absf(hp) < 0.000001: hp = 0.0
	if side == "ally":
		Events.emit_radar_ping(global_position, "attack")   # (B3) 雷达受袭闪烁
		if building_id != "R3REAPERTURRET":
			Ra2Sfx.play_player_eva(battle, "EVA_OurBaseIsUnderAttack", 8000)
	if hp <= 0.0:
		hp = 0.0
		special.yr_causes_death_weapon = GameData.warhead_combat_rule(warhead_id).get("causes_death_weapon", false)
		preload("res://scripts/rules/commando_contracts.gd").prepare_death(self,source,attacker_bonus)
		_die(source)
		special.erase("commando_kill_hit")
		return
	_hp_ghost = maxf(_hp_ghost, prev_frac)   # 掉血残影停在旧血量
	_hp_flash = 1.0                          # 受击白闪
	queue_redraw()

func set_repairing(active: bool) -> void:
	special.erase("area_repair")
	repairing = active
	repair_waiting_funds = false
	_building_repair_elapsed = 0.0
	queue_redraw()

func _process_building_repair(delta: float) -> void:
	if not repairing or _dead or under_construction or delta <= 0.0 or battle == null or battle.paused or battle.ended or get_tree().paused:
		return
	if hp >= max_hp:
		set_repairing(false)
		return
	var rules: Dictionary = GameData.ra2_general.get("repair", {})
	var interval := maxf(0.01, float(rules.get("rate_minutes", 0.016)) * 60.0)
	var step := maxf(0.01, float(rules.get("step", 8.0)))
	var per_hp := maxf(0.0, float(data.get("cost", 0))) / maxf(1.0, max_hp) * maxf(0.0, float(rules.get("percent", 0.15)))
	_building_repair_elapsed += delta
	while repairing and _building_repair_elapsed + 0.000001 >= interval:
		_building_repair_elapsed = maxf(0.0, _building_repair_elapsed - interval)
		var heal := minf(step, max_hp - hp)
		var charge := heal * per_hp
		# Capturable oil derricks have no purchase price. Charge the minimum repair tick.
		if building_id == "CAOILD": charge = maxf(1.0, charge)
		if not battle.spend_side(side, charge):
			if not repair_waiting_funds and side == "ally":
				Events.emit_message("%s 维修暂停：资金不足，到账后继续" % display_name, Color(1.0, 0.8, 0.5))
				Ra2Sfx.play_player_eva(battle, "EVA_InsufficientFunds")
			repair_waiting_funds = true
			_building_repair_elapsed = 0.0
			queue_redraw()
			return
		repair_waiting_funds = false
		hp = minf(max_hp, hp + heal)
		play_special()
		queue_redraw()
		battle._update_power()
		if hp >= max_hp:
			set_repairing(false)

func retire_sold() -> void:
	if _dead: return
	if special.has("occupants"): preload("res://scripts/units/civilian_orders.gd").evacuate(self, true)
	preload("res://scripts/buildings/building_sale_fx.gd").play(self)
	_dead = true
	preload("res://scripts/ui/unit_selection_outline.gd").clear(self)
	if battle is Battle: battle.invalidate_ai_population()
	preload("res://scripts/buildings/building_crew.gd").eject(self)
	set_repairing(false)
	production.clear()
	special.erase(Parallel.KEY)
	production_paid = 0.0
	special.erase("unit_price")
	progress = 0.0
	remove_from_group("buildings")
	if WallArt.is_wall(data):
		WallArt.refresh_neighbors(self)
	hide()
	queue_free()

func _die(killer = null, temporal_erasure := false) -> void:
	if not _dead and is_instance_valid(battle) and battle.mission.get("id")=="yr_head_games":
		if side=="enemy" and building_id in ["NACNST","GACNST","YACNST"]:
			battle.allied_state["s07_no_yard_%d"%int(special.get("head_games_wing",-1))]=true
		if building_id in ["CATRAN01","CATRAN02"]:
			battle.allied_state["s07_dark_"+building_id]=true
			var lamp=battle.get_node_or_null("TransylvaniaLights/"+building_id)
			if lamp:lamp.hide()
	if not _dead and special.has("head_grinder") and is_instance_valid(battle):
		preload("res://scripts/world/head_games.gd").grinder_lost(battle,special.head_grinder)
	if _dead:
		return
	if building_id=="YAREFN": preload("res://scripts/world/slave_mining.gd").release(self,killer)
	var eliminated:bool=special.get("house_eliminated",false)
	if eliminated:
		temporal_erasure=true
		Effects.spawn_impact(global_position,Color(1.0,0.55,0.15),radius*2.4)
	_dead = true
	preload("res://scripts/ui/unit_selection_outline.gd").clear(self)
	preload("res://scripts/units/soviet_specials.gd").remove_bomb(self,not temporal_erasure)
	preload("res://scripts/buildings/airport_dock.gd").destroy_assigned_aircraft(self, temporal_erasure)
	if building_id=="R3REAPERTURRET" and not temporal_erasure:
		Ra3Wreck.spawn_from(battle,building_id,global_position,float(special.get("walker_heading",0)),Vector2.ZERO)
	if special.has("occupants"):
		preload("res://scripts/units/civilian_orders.gd").evacuate(self, true)
	if not eliminated:
		preload("res://scripts/world/battle_music_director.gd").death(battle, self, killer)
		preload("res://scripts/rules/field_commission.gd").defeated(battle, self, killer)
		MetaProgress.Academy.defeated(battle, self, killer)
	if is_instance_valid(killer) and killer != self and killer.has_method("credit_kill"):
		killer.credit_kill(maxf(0.0, float(data.get("cost", 0))), side)
	if WallArt.is_wall(data):
		WallArt.refresh_neighbors(self)
	# 语音：DieSound（rules.ini → voice.die，如 GAPOWR=PowerPlantDie）
	if not temporal_erasure and Ra2Sfx.has_voice(data, "die"):
		Ra2Sfx.play_voice(data, "die", global_position, 200)
	if not temporal_erasure:
		preload("res://scripts/core/yr_death_combat.gd").destroyed(self)
		preload("res://scripts/buildings/building_crew.gd").eject(self)
		if not preload("res://scripts/core/yr_death_fx.gd").destroyed(self):
			Effects.spawn_impact(global_position, _col, radius * 2.4)
		preload("res://scripts/buildings/building_rubble.gd").leave(self)
	Events.unit_died.emit(self)
	remove_from_group("buildings")
	queue_free()

# ------------------------------------------------------------------ 绘制

func set_selected(v: bool) -> void:
	selected = v
	if building_id=="R3REAPERTURRET" and has_node("ReaperMount"):$ReaperMount.set_selected(v)
	queue_redraw()

func set_hovered(v: bool) -> void:
	if hovered == v:
		return
	hovered = v
	if building_id=="R3REAPERTURRET" and has_node("ReaperMount"):$ReaperMount.set_hovered(v)
	queue_redraw()

func _draw() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(9)
	if building_id=="R3REAPERTURRET":return
	if _body_visibility != null and not selected and not hovered and not _body_visibility.is_on_screen():
		if not get_viewport_rect().intersects(get_global_transform_with_canvas() * _body_visibility.rect):
			return
	RA2Art.begin_detail_draw(self)
	Iso.begin(self)
	SupportSystems.draw_gap(self)
	if building_id=="NAPSIS" and side=="ally":
		for pair in special.get("psychic_orders",[]): draw_line(to_local(pair[0]),to_local(pair[1]),Color(0.85,0.36,1.0,0.65),2.0)
	# Original shipyard SHP already contains its docks and waterline. The old
	# procedural platform belongs only to buildings without source artwork.
	if _on_water and _ra2.is_empty():
		_draw_water_platform(radius)
	var r := radius
	var body_col := _col
	if side == "enemy":
		body_col = body_col.darkened(0.05)
	var light := body_col.lightened(0.28)
	var dark := body_col.darkened(0.5)
	var def_gun := not weapon.is_empty()
	var tgs: Array = data.get("tags", [])

	if not _ra2.is_empty():
		preload("res://scripts/ui/unit_selection_outline.gd").begin(self)
		_draw_ra2_sprite(r)
		preload("res://scripts/ui/unit_selection_outline.gd").end(self)
	else:
		# 地基
		draw_colored_polygon(Iso.ell(Vector2(0, r * 0.5), r * 1.18, r * 1.18), Color(0.16, 0.17, 0.2, 0.9))

		var wall_h := r * (0.85 if is_hq else 0.65)
		if def_gun:
			# 防御塔：底盘 + 塔身 + 炮塔
			var b0 := Iso.extrude(self, Vector2(0, r * 0.35), r * 0.8, wall_h * 0.7, body_col.darkened(0.1), light, 12)
			var b1 := Iso.extrude(self, b0, r * 0.5, wall_h * 0.8, body_col, light, 12)
			var ang := 0.0
			if is_instance_valid(attack_target):
				ang = (attack_target.global_position - global_position).angle()
			var sd: Vector2 = Iso.dir(Vector2(cos(ang), sin(ang)))
			if sd.length() > 0.01:
				sd = sd.normalized()
			draw_circle(b1, r * 0.34, light)
			draw_line(b1, b1 + sd * r * 1.3, dark, maxf(3.0, r * 0.2), true)
		elif is_hq:
			# 指挥中心：大方基 → 主楼 → 穹顶 + 天线
			var h0 := Iso.box(self, Vector2(0, r * 0.45), r * 2.0, r * 2.0, r * 0.7, body_col, light)
			var h1 := Iso.box(self, h0 + Vector2(0, -r * 0.35), r * 1.35, r * 1.35, r * 0.85, body_col.darkened(0.06), light)
			draw_colored_polygon(Iso.ell(h1 - Vector2(0, r * 0.05), r * 0.55, r * 0.55), light)
			draw_line(h1, h1 - Vector2(0, r * 1.25), dark, 2.0, true)
			draw_circle(h1 - Vector2(0, r * 1.3), r * 0.12, Color(1.0, 0.6, 0.25))
		elif is_spawner:
			# 虫巢：锥形主峰 + 环绕小球
			var s0 := Iso.extrude(self, Vector2(0, r * 0.4), r * 1.15, wall_h, body_col.darkened(0.08), light, 14)
			for i in range(5):
				var a := TAU * float(i) / 5.0
				draw_circle(s0 + Vector2(cos(a) * r * 0.9, sin(a) * r * 0.4), r * 0.16, dark)
			draw_circle(s0 - Vector2(0, r * 0.15), r * 0.3, Color(1.0, 0.55, 0.2))
		elif tgs.has("production"):
			# 生产建筑：宽厂房 + 屋顶锯齿 + 卷帘门
			var p0 := Iso.box(self, Vector2(0, r * 0.4), r * 2.1, r * 1.75, wall_h, body_col, light)
			for k in range(3):
				var sz := (float(k) - 1.0) * r * 0.5
				draw_colored_polygon(PackedVector2Array([
					Vector2(sz - r * 0.28, p0.y - r * 0.12), Vector2(sz, p0.y - r * 0.42),
					Vector2(sz + r * 0.28, p0.y - r * 0.12), Vector2(sz, p0.y + r * 0.1)]),
					light.darkened(0.1))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 0.55, r * 0.55), Vector2(r * 0.55, r * 0.55),
				Vector2(r * 0.55, r * 0.55 - wall_h * 0.62), Vector2(-r * 0.55, r * 0.55 - wall_h * 0.62)]),
				dark)
		else:
			var g0 := Iso.box(self, Vector2(0, r * 0.4), r * 1.9, r * 1.9, wall_h, body_col, light)
			draw_colored_polygon(Iso.ell(g0, r * 0.42, r * 0.42), light.darkened(0.05))

		# ---- 贴图细节：屋顶网格 + 顶沿高光 + 可见墙面窗格 + 阵营涂装条 ----
		if not def_gun and not is_hq and not is_spawner:
			var fw := r * (2.1 if tgs.has("production") else 1.9)
			var fd := r * (1.75 if tgs.has("production") else 1.9)
			var fc := Vector2(0, r * 0.42)
			var c0 := Iso.dir(fc + Vector2(-fw * 0.5, -fd * 0.5))
			var c1 := Iso.dir(fc + Vector2(fw * 0.5, -fd * 0.5))
			var c2 := Iso.dir(fc + Vector2(fw * 0.5, fd * 0.5))
			var c3 := Iso.dir(fc + Vector2(-fw * 0.5, fd * 0.5))
			var up := Vector2(0, -wall_h)
			for i in range(1, 3):
				var f := float(i) / 3.0
				draw_line(c0.lerp(c1, f) + up, c3.lerp(c2, f) + up, dark.lightened(0.4), 1.0, true)
				draw_line(c0.lerp(c3, f) + up, c1.lerp(c2, f) + up, dark.lightened(0.4), 1.0, true)
			draw_line(c1 + up, c2 + up, light, 1.6, true)
			draw_line(c2 + up, c3 + up, light, 1.6, true)
			var ammo := Color(1.0, 0.72, 0.3) if side == "ally" else Color(1.0, 0.42, 0.35)
			for face in [[c1, c2], [c2, c3]]:
				var fa: Vector2 = face[0]
				var fb: Vector2 = face[1]
				for k in range(3):
					var t := 0.25 + float(k) * 0.25
					draw_circle(fa.lerp(fb, t) + up * 0.6, maxf(1.2, r * 0.075), Color(0.55, 0.85, 1.0, 0.8))
				draw_line(fa + up * 0.12, fb + up * 0.12, Color(ammo.r, ammo.g, ammo.b, 0.55), 2.0, true)


	if special.has("ore_smoke_puffs"): preload("res://scripts/units/hollywood_unit_fx.gd").draw_smoke(self)
	AlliedAbilities.draw_status(self)

	# 低电离线（RA2）：Powered 建筑无电时压暗 + 「无电」角标（呼吸闪烁）
	if powered and not _dead and not under_construction and battle != null and battle.side_power_low(side) and not is_operational():
		var bpulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec() % 1200) / 1200.0 * TAU)
		var bfont := ThemeDB.fallback_font
		if bfont != null:
			var btxt := "无电"
			var btw := bfont.get_string_size(btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var bby := -r * 2.2
			var bbox := Rect2(-btw * 0.5 - 5.0, bby - 14.0, btw + 10.0, 17.0)
			draw_rect(bbox, Color(0.5, 0.06, 0.06, 0.35 + 0.3 * bpulse))
			draw_rect(bbox, Color(1.0, 0.35, 0.3, 0.55 + 0.35 * bpulse), false, 1.5)
			draw_string(bfont, Vector2(-btw * 0.5, bby - 1.0), btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.8, 0.75 + 0.25 * bpulse))

	# 建造中
	if under_construction:
		var k := clampf(build_elapsed / max(0.01, build_total), 0.0, 1.0)
		var by := -r * 2.4
		draw_rect(Rect2(-r, by, r * 2, 7), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-r + 1, by + 1, (r * 2 - 2) * k, 5), Color(0.95, 0.75, 0.3))
	# 生产进度
	if not production.is_empty():
		var k2 := queue_progress()
		# 贴图底边在 r*0.35（见 _draw_ra2_sprite 的锚点），进度条紧贴其下方即可，
		# 之前用 r*1.35 会飘到建筑下方约 1 个半径的空地上（显着“偏”）。
		var py := r * 0.35 + 5.0
		draw_rect(Rect2(-r, py, r * 2, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-r + 1, py + 1, (r * 2 - 2) * k2, 4), Color(0.5, 0.9, 1.0))
	# 选中 / 悬停（贴地）：按 foundation 尺寸的基底菱形 + RA2 风格四角角标
	if selected:
		var t := float(Time.get_ticks_msec() % 1000) / 1000.0
		var pulse: float = 0.7 + 0.3 * sin(t * TAU)
		# 底盘轮廓（贴合水泥坪台/素材底盘）
		Iso.outline(self, _sel_corners(), Color(0.45, 1.0, 0.6, 0.20 + 0.10 * pulse), 1.0)
		# RA2 原版风格：四角角标
		_draw_selection_brackets(Color(0.55, 1.0, 0.65, 0.95), 2.0)
	elif hovered:
		_draw_selection_brackets(Color(0.7, 0.95, 0.75, 0.45), 1.0)
## 血条改由 battle.hp_overlay 在高层级（DepthLayers.WORLD_HUD）统一绘制，
## 恒盖在所有实体（含建筑）之上。
## origin 为 begin 空间坐标（调用方传 Iso.dir(世界坐标)），ci 为其所属 CanvasItem。
func hp_bar_rect() -> Rect2:
	var width := maxf(50.0,radius*2.4)
	return Rect2(-width*0.5,-radius*2.9,width,6.0)

func draw_hp_bar(ci: CanvasItem, origin: Vector2, show_values := false) -> void:
	var shield := float(special.get("brutal_shield", 0.0))
	if _dead or not (show_values or hp < max_hp or _hp_flash > 0.0 or shield > 0):
		return
	var rect := hp_bar_rect()
	rect.position += origin
	if shield > 0:
		var bar := Rect2(rect.position+Vector2(0,-5),Vector2(rect.size.x,3))
		HpBar.draw_bar(ci,bar,shield / (max_hp * 0.5),Color.SKY_BLUE)
	if show_values: HpBar.draw_readout(ci,rect,side,hp,max_hp,shield)
	var pct := clampf(hp / max(1.0, max_hp), 0.0, 1.0)
	var alert_k: float = clampf(1.0 - pct, 0.0, 1.0)
	HpBar.draw_bar(ci, rect, pct, HpBar.world_fill(side, pct), 0, _hp_ghost, _hp_flash, alert_k, HpBar.rim_for(side))

# ------------------------------------------------------------------ RA2 建筑动画层
# RA2 的建筑动效不在主体 SHP 里：art.ini 用 ActiveAnim/ActiveAnimTwo..Four/IdleAnim 指向独立的动画 SHP。
# 动画 SHP 与主体 SHP 同画布（cell 一致），所以复用主体的 base 偏移直接叠在主体之上即可像素级对齐。
# Shadow=yes 的动画 SHP：总帧数 = 2 x 可见帧数，后一半是同一动作的黑影（光向偏移已烘在像素里），画在可见帧之下。
# ------------------------------------------------------------------

## RA2 的 Rate 单位是「Rate/60 = 帧/秒」，缺省 900 → 15fps。
func _anim_frame(rate: float, loop_start: int, loop_end: int) -> int:
	var n := loop_end - loop_start + 1
	if n <= 1:
		return loop_start
	var spf := 60.0 / maxf(rate, 1.0)
	return loop_start + int(fmod(_anim_t / spf, float(n)))

## 依据当前状态选取的计时器取帧（special 组用 _anim_group_t，一次性从 0 起播）。
func _anim_frame_for(lay: Dictionary, st: Dictionary) -> int:
	if building_id == "NATBNK": return roundi(lerpf(st.loopStart, st.loopEnd, _bunker_fraction))
	if (building_id == "CAOUTP" and str(lay.kind) != "activeanim") or building_id in ["GADEPT", "NADEPT"] or (building_id == "NAYARD" and str(lay.kind).begins_with("specialanim")):
		return RepairArmAnimation.frame(self, st)
	var rate := float(st["rate"])
	if building_id == "NEUTRALSTUDIO" and not production.is_empty() and not production_paused(str(production[0])) and is_operational():
		rate *= 2.0
	var ls := int(st["loopStart"])
	if not str(data.get("powers_unit", "")).is_empty() and not is_operational():
		return ls
	var le := int(st["loopEnd"])
	var n := le - ls + 1
	if n <= 1:
		return ls
	var spf := 60.0 / maxf(rate, 1.0)
	var kind := str(lay.get("kind", ""))
	if kind == "superanimfour" and special.has("sw_discharge_age"):
		return ls + mini(n-1,int(float(special.sw_discharge_age)/spf))
	if kind == "superanimtwo" and building_id in ["NAMISL","NAIRON"]:
		var lead := float(preload("res://scripts/core/yr_death_rules.gd").type_data(building_id).get("chargedanimtime",1)) * 60.0
		return ls + clampi(int((lead-sw_recharge()+_sw_charge)/spf),0,n-1)
	if kind.begins_with("productionanim"):
		return ls + mini(n - 1, int(maxf(0.0, _production_anim_t) / spf))
	if _is_door_layer(kind):
		return ls + mini(n - 1, int(_door_fraction() * float(n)))
	var one_shot := kind.begins_with("specialanim") or kind.begins_with("deployinganim") \
		or kind.begins_with("underdooranim") or kind.begins_with("roofdeployinganim") \
		or kind.begins_with("underroofdooranim")
	if one_shot:
		# 一次性：按分组计时器从头播，播完停在末帧
		return ls + mini(n - 1, int(_anim_group_t / spf))
	return ls + int(fmod(_anim_t / spf, float(n)))

## Render damage stage shared by the building body and its animation layers.
func _dmg_index() -> int:
	var df := int(_ra2.get("dmg", 1))
	if df > 1 and max_hp > 0.0:
		var frac := hp / max_hp
		# These sheets have a damaged body followed by an alternate red-remap frame.
		if building_id in ["GAWEAP", "NAWEAP", "NAREFN", "YAPOWR"]: return 1 if frac <= 0.5 else 0
		return mini(df - 1, 0 if frac > 0.66 else (1 if frac > 0.33 else 2))
	return 0

## 取某一层当前生效的参数（受损时换成该层的 dmg 变体）。
func _anim_layer(lay: Dictionary) -> Dictionary:
	return lay._damaged_state if _dmg_index()>0 else lay._healthy_state

static func _make_anim_layer(lay: Dictionary, damaged:bool) -> Dictionary:
	var st := {
		"image": str(lay.get("image", "")),
		"loopStart": int(lay.get("loopStart", 0)),
		"loopEnd": int(lay.get("loopEnd", 0)),
		"rate": float(lay.get("rate", 900.0)),
		"shadow": (lay.get("shadow", false) == true),
		"frames": int(lay.get("frames", 0)),
	}
	if damaged and lay.has("dmg"):
		var d: Dictionary = lay["dmg"]
		for k in ["image", "loopStart", "loopEnd", "rate", "shadow", "frames"]:
			if d.has(k):
				st[k] = d[k]
		st["rate"] = float(st["rate"])
		st["frames"] = int(st["frames"])
		st["shadow"] = (st["shadow"] == true)
	if int(st["loopEnd"]) < int(st["loopStart"]):
		st["loopEnd"] = st["loopStart"]
	return st

func _draw_ra2_anim(base: Vector2, sc: float, only_kind: String = "") -> void:
	if _ra2_anim.is_empty():
		return
	for lay in _ra2_anim:
		if not only_kind.is_empty() and lay.kind!=only_kind: continue
		if not _layer_visible(str(lay.get("kind", ""))):
			continue
		var est := _anim_layer(lay)
		var art := RA2Art.art(str(est["image"]))
		var tex: Texture2D = art.get("tex")
		if tex == null:
			continue
		var ofs := base + Vector2(float(lay.get("x", 0.0)), float(lay.get("y", 0.0))) * sc
		var v := _anim_frame_for(lay, est)
		var total := int(art.get("count", 0))
		var half := int(est["frames"])
		if (est["shadow"] == true) and half > 0 and v + half < total:
			var sr := RA2Art.src_rect(art, v + half)
			if sr.size.x > 0.0:
				RA2Art.draw_sprite(self, art, Rect2(ofs, sr.size * sc), sr, Color(0.0, 0.0, 0.0, 0.5))
		RA2Art.draw_sprite(self, art, Rect2(ofs, RA2Art.frame_size(art) * sc), RA2Art.src_rect(art, v))

# ======================= 超级武器 =======================

func sw_recharge() -> float:
	return maxf(1.0, float(superweapon.get("recharge_seconds", 420.0)))

func sw_ready() -> bool:
	if superweapon.is_empty() or _dead or under_construction or not _superweapon_powered(): return false
	var source = SupportSystems.charge_controller(self)
	return source != null and source._sw_charge >= source.sw_recharge()

func _superweapon_powered() -> bool:
	if sw_type() == "ParaDrop" and side == "neutral": return false
	return is_operational() and (sw_type() != "ForceShield" or not battle.side_power_low(side))

func sw_progress() -> float:
	return clampf(_sw_charge / sw_recharge(), 0.0, 1.0)

func sw_label() -> String:
	var t := str(superweapon.get("ui_name", ""))
	if t == "" and sw_type() == "SpyPlane": return "侦察机"
	if t == "":
		t = str(superweapon.get("name", "超级武器"))
	return t

func sw_type() -> String:
	return str(superweapon.get("type", ""))

## Only these four YR superweapons broadcast their site and countdown.
## Other support powers share the charging machinery but use normal scouting.
func broadcasts_superweapon() -> bool:
	return sw_type() in ["MultiMissile", "IronCurtain", "ChronoSphere", "LightningStorm"]

func is_allied_ai_storm() -> bool:
	return sw_type() == "LightningStorm" and BattleRequest.is_ai_house(side) and BattleRequest.friendly("ally", side)

func sw_anim_seconds(kind: String) -> float:
	for layer in _ra2_anim:
		if layer.kind == kind:
			var st := _anim_layer(layer)
			return (int(st.loopEnd)-int(st.loopStart)+1) * 60.0 / maxf(1.0,float(st.rate))
	return 0.0

func _tick_superweapon(delta: float) -> void:
	if special.has("sw_discharge_age"):
		special.sw_discharge_age += delta
		if special.sw_discharge_age >= sw_anim_seconds("superanimfour"): special.erase("sw_discharge_age")
		queue_redraw()
	if superweapon.is_empty() or _dead or under_construction:
		return
	if SupportSystems.charge_controller(self) != self: return
	# 充电：断电（低电）时暂停，和 RA2 一致；已发射的天气风暴不受断电影响。
	if _superweapon_powered() and not LightningStorm.active_for(battle, self):
		_sw_charge = minf(sw_recharge(), _sw_charge + delta)
	var rdy := _superweapon_powered() and _sw_charge >= sw_recharge()
	if rdy and not _sw_was_ready:
		_sw_was_ready = true
		if side == "ally":
			Ra2Sfx.play_support_ready(battle, sw_type())
		queue_redraw()
	SupportSystems.sync_charge(self)

func _play_storm_bolt(at: Vector2) -> void:
	SupportSystems.storm_bolt(self, at)

func _storm_damage(at: Vector2, _legacy_radius: float) -> void:
	SupportSystems.storm_damage(self, at)

func _fire_chrono(target: Vector2, origin := Vector2.INF) -> bool:
	return SupportSystems.chrono_move(self, target, origin)

func fire_superweapon(target: Vector2, chrono_origin := Vector2.INF) -> bool:
	if not sw_ready():
		return false
	var typ := sw_type().to_lower()
	var ok := false
	if typ in ["psychicdominator", "geneticconverter", "psychicreveal"]:
		ok = preload("res://scripts/world/yuri_support.gd").launch(self,target)
	elif typ in ["ironcurtain", "multimissile", "spyplane"]:
		ok = preload("res://scripts/units/soviet_specials.gd").superweapon(self, target)
	elif typ in ["amerparadrop", "paradrop"]:
		ok = preload("res://scripts/world/american_paradrop.gd").launch(self, target)
	elif typ == "forceshield":
		for b in battle.buildings:
			if battle.actor_alive(b) and b.side == side and not b.under_construction and b.position.distance_to(target) <= float(superweapon.radius):
				b.special.force_shield_left = float(superweapon.duration)
				ok = true
		if ok:
			var key := "blackout_" + side
			battle.allied_state[key] = maxf(float(battle.allied_state.get(key, 0)), float(superweapon.blackout))
	elif typ == "chronosphere":
		ok = _fire_chrono(target, chrono_origin)
	elif typ == "lightningstorm":
		ok = LightningStorm.start(self, target)
	if not ok:
		return false
	if broadcasts_superweapon():
		preload("res://scripts/world/battle_music_director.gd").superweapon_used(battle, side)
	if battle.fog != null: battle.fog.reveal_superweapon(self, target)
	# Spawn launch ignition after opening its fog window so hidden silos still show it.
	if typ == "multimissile" and battle.position_visible_to("ally", global_position):
		var ignition = Ra2Fx.play(battle.effects_root, global_position, "NUKETO")
		if ignition != null: ignition.draw_offset = preload("res://scripts/units/soviet_specials.gd").SILO_OFFSET
	if building_id in ["NAMISL","NAIRON"]: special.sw_discharge_age = 0.0
	_sw_charge = 0.0
	_sw_was_ready = false
	SupportSystems.sync_charge(self)
	if typ == "amerparadrop":
		if side == "ally": Events.emit_message("空降运输机已出发")
	if typ == "lightningstorm" and (side == "ally" or is_allied_ai_storm()):
		var owner_label := "我方" if side == "ally" else "友方"
		battle.friendly_storm_launched.emit(owner_label)
		Ra2Sfx.play_player_eva(battle, Ra2Sfx.SUPERWEAPON_ALERT_VOICES["LightningStorm"], 0)
		Events.emit_message(owner_label + "已发动闪电风暴", Color("#81dfff"))
		Events.emit_radar_ping(target, "friendly_support")
	elif broadcasts_superweapon() and not BattleRequest.friendly("ally", side):
		var label := sw_label()
		battle.enemy_superweapon_launched.emit(label)
		Ra2Sfx.play_enemy_superweapon_alert(battle, sw_type())
		Events.emit_message("警告：敌方已发动%s！" % label, Color(1.0, 0.48, 0.24))
		Events.emit_radar_ping(target, "alert")
		if not global_position.is_equal_approx(target): Events.emit_radar_ping(global_position, "alert")
	queue_redraw()
	return true
