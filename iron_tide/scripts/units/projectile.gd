extends Node2D
class_name Projectile
const Visual = preload("res://scripts/units/projectile_visual.gd")
## 通用投射物。直线/抛物线飞向目标所在位置，命中后结算伤害；带 aoe 的做范围伤害。
##
## RA2 迁移（rules.ini [Projectile] 为唯一事实源）：
##   Image=     可见弹体外形（真实 SHP：120MM / DRAGON …）；无 Image 或 Inviso=yes 则不可见
##   Inviso=yes 在目标处结算，无飞行时间（独立于 IsLaser / 光束显示时长）
##   Arcing=yes 抛物线弹道（火炮/大炮）
##   Shadow=yes 飞行时投地面阴影
##   ROT=       追踪转向速率（1/256 圈 / 1/15s）
##   [Warhead] AnimList= 命中动画（脚本 Ra2Fx 播放真实 SHP）

var speed: float = 800.0
var damage: float = 10.0
# 第 8 批：武器 rules 原始 Damage=（未过 Verses）。RA2 的弹头要对【每个】目标各自结算。
var base_damage: float = 10.0
var attack_type: String = "bullet"
var attacker_bonus: Dictionary = {}
var target = null                 # Node2D，可能中途死亡
var target_point: Vector2 = Vector2.ZERO
var aoe: float = 0.0
var owner_side: String = "ally"
var _credit_source: WeakRef
var front_color: Color = Color(1, 0.85, 0.4)
var tail_color: Color = Color(1, 0.5, 0.2)
const DEFAULT_LIFETIME := 3.0
var life: float = DEFAULT_LIFETIME
var _detonated := false
var splinters: Dictionary = {}
var _trail: Array[Vector2] = []

# ---- RA2 [Projectile] 字段 ----
var ra2_warhead: String = ""
var ra2_image: String = ""
var ra2_inviso: bool = false
var ra2_arcing: bool = false
var ra2_shadow: bool = false
var ra2_homing: bool = false        # ROT > 0 的追踪弹
var ra2_rot_deg: float = 0.0        # 追踪转向速率 °/s
var ra2_aa: bool = false
var is_sonic := false
var _sonic_origin := Vector2.ZERO
var _sonic_range := 0.0
var _sonic_damage := 0.0
var _sonic_elapsed := 0.0
var _sonic_tick := 0
var _sonic_source: WeakRef
var _sonic_source_type := ""
var _sonic_affects_allies := true
var _sonic_credit_allowed := false

# Independent Godot adaptation: a straight corridor grows to weapon range
# over 20 pulses at the existing 15 Hz rules clock. These are not EXE geometry.
const SONIC_TICKS := 20
const SONIC_HALF_WIDTH := 14.0

var _heading: Vector2 = Vector2.RIGHT
var _arc_from: Vector2 = Vector2.ZERO
var _arc_to: Vector2 = Vector2.ZERO
var _arc_len: float = 0.0
var _arc_t: float = 0.0
var _arc_dur: float = 0.0
var _arc_h: float = 0.0
var _arc_z: float = 0.0

const ROT_DEG_PER_TICK := 360.0 / 256.0
const ROF_FPS := 15.0

func setup(p_from: Vector2, p_target, p_weapon: Dictionary, p_damage: float, p_bonus: Dictionary, p_side: String, p_source = null) -> void:
	_credit_source = weakref(p_source) if is_instance_valid(p_source) else null
	global_position = p_from
	target = p_target
	damage = p_damage
	base_damage = float(p_weapon.get("damage", p_damage))
	attack_type = str(p_weapon.get("attack_type", "bullet"))
	aoe = float(p_weapon.get("aoe", 0.0))
	attacker_bonus = p_bonus.duplicate(true)
	if CombatMath.FinalDamage.active() and not attacker_bonus.has("reference_weapon"):attacker_bonus.reference_weapon=p_weapon.duplicate(true)
	attacker_bonus.impact_weapon = p_weapon.get("ra2_weapon_id","")
	owner_side = p_side
	speed = max(60.0, float(p_weapon.get("projectile_speed", 800.0)))
	target_point = p_target.global_position if is_instance_valid(p_target) else p_from
	ra2_warhead = str(p_weapon.get("ra2_warhead", ""))
	# RA2 口径：溅射半径由弹头 CellSpread=（单位＝格）决定，覆盖引擎手写的 aoe
	if ra2_warhead != "":
		var cs: float = GameData.ra2_cell_spread(ra2_warhead)
		if cs > 0.0:
			aoe = cs * 55.0
	set_colors()
	if p_source is Unit and p_source.special.get("expansion_temporary",{}).get("kind")=="twin":front_color=Color(.8,.95,1);tail_color=Color(.3,.7,1)
	# YR BallisticScatter is measured in cells. Adapt the aimed offset to the
	# continuous battlefield before constructing the arc or invisible impact.
	if p_weapon.get("flak_scatter", false):
		var cells := float(preload("res://scripts/core/yr_death_rules.gd").data().combat.ballisticscatter)
		var distance_factor := clampf(p_from.distance_to(target_point) / maxf(1.0, p_weapon.range), 0.0, 1.0)
		var radius := cells * Ra2Damage.PX_PER_CELL * distance_factor
		if p_weapon.ra2_aa: radius *= 2.0
		var scattered := target_point + Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius)
		var world = p_source._battle_world() if is_instance_valid(p_source) and p_source.has_method("_battle_world") else null
		if is_instance_valid(p_source) and p_source is Building: world = p_source.battle
		if world != null and Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).has_point(scattered):
			target_point = scattered
	_apply_ra2_projectile(str(p_weapon.get("ra2_projectile", "")))
	if ra2_homing and p_source is Unit and p_source.unit_id == "SUB":
		_heading = Vector2.from_angle(p_source.hull_angle)
	var projectile_rules: Dictionary = GameData.ra2_projectile(str(p_weapon.get("ra2_projectile", ""))).get("extra", {})
	splinters = {"weapon": str(projectile_rules.get("ShrapnelWeapon", "")), "count": int(projectile_rules.get("ShrapnelCount", 0)), "visited": []}
	if p_source is Unit and p_source.unit_id=="HTNK" and target is Building and str(attacker_bonus.impact_weapon).trim_prefix("YR_SOV_") in ["120mm","120mmE"] and Unit.YRTalents.enabled(p_source,Unit.YRTalents.SPLIT):
		splinters[Unit.YRTalents.SPLIT]=Unit.YRTalents.value(p_source,Unit.YRTalents.SPLIT)*0.01
	if p_source is Unit and p_source.unit_id == "SREF":
		if Unit.Training.scale(p_source) > 1.0:
			splinters.native_prism = Unit.Training.scale(p_source)
			splinters.native_prism_root = base_damage
		if p_source.yr_finish!=null:splinters.corona_glass=true
	var look:=Effects.Looks.current(p_source)
	if p_source is Unit and p_source.special.get("hero_skin",false):
		var commando_look:=Unit.CommandoFx.primary_style(p_source,p_weapon)
		if not commando_look.is_empty():look=commando_look
	if look=="molten_duet":
		if p_weapon.get("name") in ["120mmx","120mmxE"]:
			var barrel:=posmod(int(p_weapon.burst)-int(p_source._burst_left),2)
			splinters.weapon_look="molten_red" if barrel==0 else "molten_gold"
	elif not look.is_empty():splinters.weapon_look=look
	if is_instance_valid(p_target) and p_target is Unit: splinters.impact_air = p_target.is_air_target()
	if p_weapon.get("hero_air_shell", false):
		splinters.hero_air_shell = true
		ra2_aa = true
	splinters.visual_target_lift = Visual.target_lift(self)
	if p_weapon.get("ra2_projectile") == "BlimpBombP" and is_instance_valid(p_source) and p_source is Unit:
		splinters.bomb_drop = true
		var mount: Array = p_source.data.get("bomb_flh",[-50,0,-140])
		var forward := Vector2.from_angle(p_source.hull_angle)
		target_point = p_source.global_position + (forward * float(mount[0]) + forward.orthogonal() * float(mount[1])) * (Ra2Damage.PX_PER_CELL / 256.0)
		var pixel := preload("res://scripts/units/unit_flight.gd").HEIGHT_PIXEL
		var height := maxf(0.0, p_source._visual_lift() / pixel + float(mount[2]))
		_arc_to = target_point
		_arc_from = target_point + RA2Art.art_dir(Vector2.UP * height * pixel)
		global_position = _arc_from
		_heading = forward
		splinters.drop_height = height
		splinters.drop_accel = maxf(1.0,float(projectile_rules.get("Acceleration",1)))
		splinters.drop_speed = maxf(1.0,float(GameData.ra2_weapon(str(p_weapon.ra2_weapon_id)).get("speed",20)))
	if p_weapon.get("flak_scatter", false): splinters.flak_airburst = ra2_aa
	if ForceFire.active(p_source, p_target): splinters["force_fire"] = true
	var raw := GameData.ra2_weapon(str(p_weapon.get("ra2_weapon_id", "")))
	is_sonic = GameData._ra2_flag(raw.get("extra", {}).get("IsSonic"))
	if is_sonic:
		_sonic_origin = p_from
		_heading = p_from.direction_to(target_point)
		if _heading.is_zero_approx():
			_heading = Vector2.RIGHT
		_sonic_range = maxf(0.0, float(p_weapon.get("range", 0.0)))
		_sonic_damage = float(raw.get("ambient_damage", 0.0))
		if attacker_bonus.has("expansion_sonic"):
			_sonic_range=p_from.distance_to(target_point)+110.0
			_sonic_damage=base_damage*float(attacker_bonus.expansion_sonic)
			splinters.expansion_sonic_hits=[]
		_sonic_affects_allies = Ra2Damage._extra(ra2_warhead, "AffectsAllies").to_lower() not in ["no", "false", "0"]
		attacker_bonus = p_bonus.duplicate(true)
		if is_instance_valid(p_source):
			_sonic_source = weakref(p_source)
			_sonic_source_type = str(p_source.get("unit_id"))
			if _sonic_source_type=="DLPH":
				splinters.sonic_mouth_depth=NavalContact.DIVE_DEPTH_PIXELS*NavalContact.dive_fraction(p_source)

## 套用 [Projectile] 的真实属性（RA2 是唯一事实源）
func _apply_ra2_projectile(pid: String) -> void:
	if pid == "":
		return
	var p: Dictionary = GameData.ra2_projectile(pid)
	if p.is_empty():
		return
	ra2_image = str(p.get("image", ""))
	ra2_inviso = p.get("inviso") == true
	ra2_arcing = p.get("arcing") == true
	ra2_shadow = p.get("shadow") == true
	ra2_aa = p.get("aa") == true
	var rot := GameData._num(p.get("rot"))
	ra2_rot_deg = rot * ROT_DEG_PER_TICK * ROF_FPS
	ra2_homing = rot > 0.0
	_heading = global_position.direction_to(target_point)
	if _heading.length() < 0.001:
		_heading = Vector2.RIGHT
	if ra2_arcing:
		_arc_from = global_position
		_arc_to = target_point
		_arc_len = _arc_from.distance_to(_arc_to)
		_arc_dur = maxf(0.2, _arc_len / speed)
		_arc_h = clampf(_arc_len * 0.22, 24.0, 170.0)
	elif ra2_homing and Visual.kind(self) == "line":
		# Presentation-only elevation envelope; the existing planar hit path stays authoritative.
		# Reuse serialized curve parameters so an in-flight save keeps the same silhouette.
		_arc_from = global_position
		_arc_to = target_point
		_arc_len = _arc_from.distance_to(_arc_to)
		_arc_h = clampf(_arc_len * 0.16, 12.0, 90.0)

func set_colors() -> void:
	match attack_type:
		"rocket": front_color = Color(1.0, 0.82, 0.35); tail_color = Color(1.0, 0.45, 0.15)
		"shell": front_color = Color(1.0, 0.95, 0.8); tail_color = Color(0.9, 0.7, 0.4)
		"flak": front_color = Color(1.0, 0.9, 0.5); tail_color = Color(0.6, 0.6, 0.7)
		"acid": front_color = Color(0.65, 1.0, 0.35); tail_color = Color(0.3, 0.9, 0.2)
		"tesla": front_color = Color(0.6, 0.85, 1.0); tail_color = Color(0.35, 0.6, 1.0)
		_: front_color = Color(1.0, 0.9, 0.55); tail_color = Color(1.0, 0.6, 0.25)

var _smooth_siege_shell := false
var _previous_arc_z := 0.0

func presentation_lift(blend: float) -> float:
	return lerpf(_previous_arc_z, _arc_z, clampf(blend, 0.0, 1.0)) if _smooth_siege_shell else Visual.lift_at(self, global_position)

func _process(_delta: float) -> void:
	if _smooth_siege_shell and is_physics_interpolated_and_enabled() and _previous_arc_z != _arc_z:
		queue_redraw()

func _configure_siege_presentation() -> void:
	if _smooth_siege_shell: return
	_smooth_siege_shell = ra2_arcing and str(attacker_bonus.get("impact_weapon", "")) in ["YR_SOV_160mm", "YR_SOV_160mmE"]
	set_process(_smooth_siege_shell)
	if _smooth_siege_shell:
		_previous_arc_z = _arc_z
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		reset_physics_interpolation()

func _ready() -> void:
	preload("res://scripts/units/expansion_2_tractor.gd").projectile_created(self)
	if attacker_bonus.has("expansion_torpedo"):preload("res://scripts/units/expansion_2_submarine.gd").initialize(self)
	_configure_siege_presentation()
	# Snapshot restoration assigns flight fields after add_child / ready.
	if attacker_bonus.is_empty(): _configure_siege_presentation.call_deferred()
	if splinters.get("weapon_look","")==Effects.Looks.Sonar.ID and is_instance_valid(shooter()):
		Effects.Looks.Sonar.spawn(Effects._host(),global_position,true,global_position.direction_to(target_point))
	# Original Inviso projectiles snap to their target; hiding a travelling
	# projectile is not equivalent. Keep the same warhead/splash/kill-credit path.
	# Sonic waves own their separate advancing, repeated-damage simulation.
	if ra2_inviso and not is_sonic:
		global_position = target_point
		_explode()

func _physics_process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(36)
	if delta <= 0.0: return
	if _smooth_siege_shell: _previous_arc_z = _arc_z
	var steps := maxi(1, ceili(delta / (Engine.time_scale / 60.0) - 0.000001))
	var step := delta / steps
	for i in steps:
		if is_queued_for_deletion() or _detonated: break
		if splinters.has("expansion_torpedo") or splinters.has("expansion_fork"):preload("res://scripts/units/expansion_2_submarine.gd").travel(self)
		_advance_projectile(step)

func _advance_projectile(delta: float) -> void:
	if splinters.has("kirov_crash"):
		preload("res://scripts/units/kirov_crash.gd").tick(self, delta)
		return
	if splinters.has("soviet_round"):
		preload("res://scripts/units/ra3_soviet.gd").advance(self,delta)
		queue_redraw()
		return
	if splinters.has("ra3_expansion"):
		Ra3Expansion.tick_shot(self, delta)
		return
	if is_queued_for_deletion():
		return
	if splinters.has("ra3_hit_delay"):
		Ra3Mirage.tick_impact(self,delta)
		return
	if is_sonic:
		_step_sonic(delta)
		queue_redraw()
		return
	if splinters.has("drop_height"):
		# Keep the native tick cursor/trajectory, played at the selected bomb action pace.
		_arc_t += delta * BattleClock.KIROV_BOMB_TICKS_PER_SECOND
		var acceleration: float = splinters.drop_accel
		var cap: float = splinters.drop_speed
		var ticks := floori(_arc_t)
		var ramp := mini(ticks,floori(cap / acceleration))
		var travel := acceleration * ramp * (ramp + 1) * 0.5 + cap * (ticks-ramp) + minf(cap,(ticks+1)*acceleration) * (_arc_t-ticks)
		var height: float = splinters.drop_height
		global_position = _arc_from.lerp(_arc_to,clampf(travel / maxf(0.001,height),0,1))
		if travel >= height: _explode()
		queue_redraw()
		return
	life -= delta
	if life <= 0.0:
		Visual.detach(self)
		queue_free()
		return
	Visual.record(self)
	if splinters.get("bomb_drop", false):
		_arc_t = minf(1.0, _arc_t + delta / _arc_dur)
		global_position = _arc_from.lerp(_arc_to, _arc_t * _arc_t)
		if _arc_t >= 1.0: _explode()
		queue_redraw()
		return
	if ra2_arcing:
		_step_arc(delta)
		queue_redraw()
		return
	if is_instance_valid(target):
		target_point = target.global_position
		if target is Unit: splinters.impact_air = target.is_air_target()
		splinters.visual_target_lift = Visual.target_lift(self)
	if ra2_homing:
		_step_homing(delta)
		queue_redraw()
		return
	var to := target_point - global_position
	var dist := to.length()
	var step := speed * delta
	if dist <= step or dist < 6.0:
		_explode()
		return
	_heading = to.normalized()
	global_position += _heading * step
	queue_redraw()

func _step_sonic(delta: float) -> void:
	_sonic_elapsed += maxf(0.0, delta)
	var due := mini(SONIC_TICKS, int(floorf(_sonic_elapsed * ROF_FPS + 0.00001)))
	# Catch up logical pulses, never collapse them into one large damage event:
	# armor, quantization, death and kill credit still happen for each pulse.
	while _sonic_tick < due:
		_sonic_tick += 1
		var front := _sonic_origin + _heading * _sonic_range * float(_sonic_tick) / SONIC_TICKS
		global_position = front
		_sonic_pulse(front)
	var phase := clampf(_sonic_elapsed * ROF_FPS / SONIC_TICKS, 0.0, 1.0)
	global_position = _sonic_origin + _heading * _sonic_range * phase
	if _sonic_elapsed * ROF_FPS >= SONIC_TICKS + 1:
		queue_free()

func _sonic_pulse(front: Vector2) -> void:
	if _sonic_damage == 0.0 or _sonic_range <= 0.0:
		return
	var seen := {}
	var source = _sonic_source.get_ref() if _sonic_source != null else null
	for group in ["ally_targets", "enemy_targets"]:
		var contacts:=get_tree().get_nodes_in_group(group)
		var grippers:Array=[]
		for host in contacts:
			if host is Unit and AlliedAbilities.alive(host.special.get("squid")):grippers.append(host.special.squid)
		# Resolve the attached body before a hit on its host can eject it.
		if not grippers.is_empty():contacts.assign(grippers+contacts)
		for t in contacts:
			if not is_instance_valid(t) or t.is_queued_for_deletion() or not t.has_method("receive_hit"):
				continue
			if seen.has(t.get_instance_id()):
				continue
			seen[t.get_instance_id()] = true
			if t == source or t.get("hp") == null or float(t.get("hp")) <= 0.0 or (t.get("embarked_in") != null and NavalContact.grip_host(t)==null):
				continue
			if t.has_method("is_air_target") and t.is_air_target():
				continue
			if not t.has_method("is_air_target") and t.get("is_air") == true:
				continue
			if BattleRequest.friendly(str(t.get("side")),owner_side):
				if not _sonic_affects_allies:
					continue
				if not _sonic_source_type.is_empty() and str(t.get("unit_id")) == _sonic_source_type:
					var extra: Dictionary = GameData.ra2_source_units.get(_sonic_source_type, {}).get("extra", {})
					if GameData._ra2_flag(extra.get("TypeImmune")):
						continue
			if attacker_bonus.has("expansion_sonic"):
				if BattleRequest.friendly(str(t.get("side")),owner_side) or splinters.expansion_sonic_hits.has(t):continue
				if source is Unit and not source._weapon_domain_valid(t):continue
			var offset: Vector2 = t.global_position - _sonic_origin
			if offset.dot(_heading) < 0.0:
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(t.global_position, _sonic_origin, front)
			var edge_distance := maxf(0.0, t.global_position.distance_to(nearest) - _radius_of(t))
			if edge_distance > SONIC_HALF_WIDTH + 0.001:
				continue
			var per := Ra2Damage.target_damage(_sonic_damage, ra2_warhead, t, 0.0)
			per = CombatMath.with_offense(per, attacker_bonus)
			if per != 0.0:
				if attacker_bonus.has("expansion_sonic"):splinters.expansion_sonic_hits.append(t)
				_sonic_credit_allowed = not BattleRequest.friendly(str(t.get("side")),owner_side)
				t.receive_hit(per, attack_type, hit_modifiers(t), self, ra2_warhead)
				_sonic_credit_allowed = false

func shooter():
	return _credit_source.get_ref() if _credit_source != null else null

func hit_modifiers(victim,distance:float=0.0,scale:float=1.0) -> Dictionary:
	if not CombatMath.FinalDamage.active():return attacker_bonus
	var reference:float
	if is_sonic:
		reference=Ra2Damage.target_damage(_sonic_damage,ra2_warhead,victim,0.0)*float(attacker_bonus.get("veteran_attack",1.0))
	else:
		var native:Dictionary=attacker_bonus.get("reference_weapon",{"damage":base_damage,"ra2_warhead":ra2_warhead,"attack_type":attack_type})
		reference=CombatMath.FinalDamage.weapon_reference(native,victim,attacker_bonus,distance)*scale
	return CombatMath.FinalDamage.packet(attacker_bonus,reference)

# Keep the projectile as impact origin while forwarding experience to its shooter.
func credit_kill(value: float, defeated_side: String = "") -> void:
	if BattleRequest.friendly(defeated_side,owner_side) or (is_sonic and not _sonic_credit_allowed) or _credit_source == null:
		return
	var source = shooter()
	if is_instance_valid(source) and source.has_method("credit_kill") and source.get("hp") != null and float(source.get("hp")) > 0.0:
		source.credit_kill(value, defeated_side)

## Arcing=yes：抛物线弹道（RA2 火炮/大炮的抛射）
func _step_arc(delta: float) -> void:
	_arc_t += delta / _arc_dur
	var t := clampf(_arc_t, 0.0, 1.0)
	var end_height := 0.0
	if splinters.get("hero_air_shell", false):
		if AlliedAbilities.alive(target) and target.is_air_target():
			_arc_to = target.global_position
			target_point = _arc_to
			splinters.visual_target_lift = target._visual_lift()
		end_height = float(splinters.visual_target_lift)
	global_position = _arc_from.lerp(_arc_to, t)
	_arc_z = sin(PI * t) * _arc_h + t * end_height
	if _arc_t >= 1.0:
		_explode()

## ROT>0：有限转向速率的追踪（RA2 导弹/防空弹）
func _step_homing(delta: float) -> void:
	if is_instance_valid(target) and target is Unit and Unit.PoolCards.intercept(self,target):return
	var want := global_position.direction_to(target_point)
	if want.length() > 0.001:
		var max_turn := deg_to_rad(ra2_rot_deg) * delta
		var cur := _heading.angle()
		_heading = Vector2.RIGHT.rotated(cur + clampf(angle_difference(cur, want.angle()), -max_turn, max_turn))
	var step := speed * delta
	var contact := step
	if is_instance_valid(target) and target is Unit and target.special.has("peregrine"):
		if preload("res://scripts/units/peregrine_defense.gd").deflect(self,global_position+_heading*step):return
	if ra2_image == "SUBT" and is_instance_valid(target) and target is Unit: contact = maxf(step, target.radius)
	if global_position.distance_to(target_point) <= contact:
		_explode()
		return
	global_position += _heading * step

## 第 8 批：按 ts-ra2 Warhead.detonate() 结算。
## · CellSpread(格) 半径内【每个】目标各自过 Verses(护甲) → ProneDamage → PercentAtMax 线性衰减
## · 衰减用武器原始 Damage=，不再是「原目标算好的一份伤害」照抄给所有人
## · 命中动画 AnimList= 按【伤害】选档（floor(damage/25)），并落地面灼痕
func _explode() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(64)
	if _detonated or is_queued_for_deletion():
		return
	_detonated = true
	# Capture before receive_hit can kill/remove the target. Never move the
	# authoritative planar impact point merely to align the displayed explosion.
	var impact_lift := Visual.target_lift(self)
	splinters.visual_target_lift = impact_lift
	var impact_position := target_point + RA2Art.art_dir(Vector2(0, -impact_lift))
	Visual.detach(self)
	var cs: float = Ra2Damage.cells(ra2_warhead) if ra2_warhead != "" else 0.0
	var off := attacker_bonus if attacker_bonus is Dictionary else {}
	preload("res://scripts/world/bridge_damage.gd").projectile_hit(self,CombatMath.with_offense(base_damage,off))
	if splinters.has(Unit.YRTalents.SPLIT):Unit.YRTalents.split_hit(self)
	if cs > 0.0:
		# Actors register by the side allowed to attack them: allies are enemy_targets.
		for t in ForceFire.impact_candidates(self):
			if not is_instance_valid(t) or not t.has_method("receive_hit"):
				continue
			var d: float = t.global_position.distance_to(target_point)
			if splinters.has("drop_height") and t is Building:
				d = maxf(0.0,d-t.footprint_clearance(t.global_position.direction_to(target_point)))
			d/=maxf(1.0,float(splinters.get("spread_scale",1.0)))
			if not Ra2Damage.in_spread(d, ra2_warhead):
				continue
			var per := Ra2Damage.target_damage(base_damage, ra2_warhead, t, d)
			per = CombatMath.with_offense(per, off)
			if per == 0.0:
				continue
			t.receive_hit(per, attack_type, hit_modifiers(t,d), self, ra2_warhead)
	elif aoe > 0.5:
		# 非 RA2 弹头：保留原有经验衰减
		for t2 in ForceFire.impact_candidates(self):
			if not is_instance_valid(t2) or not t2.has_method("receive_hit"):
				continue
			var d2: float = t2.global_position.distance_to(target_point)
			if d2 <= aoe + _radius_of(t2):
				var falloff := clampf(1.0 - d2 / (aoe + 1.0) * 0.5, 0.5, 1.0)
				t2.receive_hit(damage * falloff, attack_type, hit_modifiers(t2,0.0,falloff), self, ra2_warhead)
	elif is_instance_valid(target) and target is ForceFirePoint:
		# A precise ground shot can hit a unit standing on the coordinate without
		# silently retargeting it; actors that move away are not chased by the shot.
		for actor in ForceFire.impact_candidates(self):
			if actor.global_position.distance_to(target_point) > maxf(1.0, _radius_of(actor)): continue
			var per_ground := CombatMath.with_offense(Ra2Damage.target_damage(base_damage, ra2_warhead, actor, 0.0), off)
			actor.receive_hit(per_ground, attack_type, hit_modifiers(actor), self, ra2_warhead)
	else:
		if is_instance_valid(target) and target.has_method("receive_hit"):
			var per3 := base_damage
			if ra2_warhead != "":
				per3 = Ra2Damage.target_damage(base_damage, ra2_warhead, target, 0.0)
			per3 = CombatMath.with_offense(per3, off)
			target.receive_hit(per3, attack_type, hit_modifiers(target), self, ra2_warhead)
			var source = _credit_source.get_ref() if _credit_source != null else null
			if is_instance_valid(source) and source is Unit and source.unit_id == "SHK":
				preload("res://scripts/units/electric_cards.gd").chain_hit(source, target)
	preload("res://scripts/units/expansion_2_soviet.gd").finish_projectile(self)
	preload("res://scripts/units/expansion_2_armor.gd").finish_projectile(self)
	if attacker_bonus.get("leizhu_primary",false):
		preload("res://scripts/units/leizhu_station.gd").finish(shooter(),attacker_bonus)
		preload("res://scripts/units/leizhu_cards.gd").finish(shooter())
	if splinters.has("expansion_torpedo"):preload("res://scripts/units/expansion_2_submarine.gd").finish(self)
	if splinters.has("expansion_calibration"):preload("res://scripts/units/expansion_2_calibration.gd").finish(self)
	if splinters.has("burning_create"):preload("res://scripts/units/expansion_2_aircraft.gd").finish(self)
	if splinters.has("expansion_tractor"):preload("res://scripts/units/expansion_2_tractor.gd").projectile_landed(self)
	if splinters.has("peregrine_split_pending"):preload("res://scripts/units/peregrine_command.gd").finish(self)
	# 命中特效：AnimList= 按伤害选档；没有素材才回退程序化爆炸
	var hit: bool = _spawn_ra2_impact(base_damage, impact_position)
	if not hit:
		Effects.spawn_impact(impact_position, front_color, max(aoe, 10.0))
	if impact_lift <= 0.01:
		Ra2Fx.spawn_scorch(Effects._host(), ra2_warhead, base_damage, target_point)
	_spawn_splinters()
	queue_free()

func _spawn_splinters() -> void:
	var id: String = splinters.get("weapon", "")
	if id.is_empty() or int(splinters.get("count", 0)) <= 0: return
	var w := AlliedAbilities.weapon(id.trim_prefix("YR_CAP_"))
	if w.is_empty(): return
	var visited: Array = splinters.get("visited", [])
	if is_instance_valid(target): visited.append(target)
	var candidates: Array = []
	var source = _credit_source.get_ref() if _credit_source != null else null
	var world = source._battle_world() if is_instance_valid(source) and source is Unit else null
	for actor in get_tree().get_nodes_in_group(BattleRequest.foes_group(owner_side) if not BattleRequest.house_teams.is_empty() else ("ally_targets" if owner_side == "ally" else "enemy_targets")):
		if not AlliedAbilities.alive(actor) or visited.has(actor) or actor.get("is_air") == true or actor.get("embarked_in") != null: continue
		if world != null and not world.actor_visible_to(owner_side, actor): continue
		if actor.global_position.distance_to(target_point) <= float(w.range) and Ra2Damage.target_damage(float(w.damage), str(w.ra2_warhead), actor, 0.0) > 0.0: candidates.append(actor)
	candidates.sort_custom(func(a, b): return a.global_position.distance_squared_to(target_point) < b.global_position.distance_squared_to(target_point))
	var emitted := 0
	for actor in candidates:
		if emitted >= int(splinters.count): break
		# Inviso children recurse immediately and can consume a later sibling.
		if visited.has(actor) or not AlliedAbilities.alive(actor): continue
		visited.append(actor)
		emitted += 1
		var child := Projectile.new()
		var child_damage := float(w.damage)
		if splinters.has("native_prism"):
			child_damage = minf(float(splinters.native_prism_root), child_damage * float(splinters.native_prism))
		var child_weapon: Dictionary = w.duplicate(true)
		child_weapon.damage = child_damage
		var child_bonus:=attacker_bonus.duplicate(true)
		if child_bonus.has("expansion_prism_multiplier"):
			child_bonus.attack_bonus/=float(child_bonus.expansion_prism_multiplier)
			child_bonus.erase("expansion_prism_multiplier")
		child_bonus.expansion_scatter=true
		if CombatMath.FinalDamage.active():
			child_bonus=child_bonus.duplicate(true)
			child_bonus.erase("hit_reference_damage")
			child_bonus.reference_weapon=w.duplicate(true)
		child.setup(target_point, actor, child_weapon, child_damage, child_bonus, owner_side, source)
		if splinters.has("native_prism"):
			child.splinters.native_prism = splinters.native_prism
			child.splinters.native_prism_root = splinters.native_prism_root
		child.splinters.visited = visited
		if splinters.get("corona_glass",false):child.splinters.corona_glass=true
		if splinters.has("weapon_look"):child.splinters.weapon_look = splinters.weapon_look
		var beam := GameData.ra2_beam_spec(str(w.get("ra2_weapon_id", "")))
		if not beam.is_empty():
			var color: Color = HouseColor.color_for_side(owner_side, "") if beam.get("house", false) else beam.color
			Effects.spawn_beam(target_point, actor.global_position, color, str(beam.kind), float(beam.thickness), float(beam.duration), splinters.get("weapon_look",""),null,true,splinters.get("corona_glass",false))
		get_parent().add_child(child)

## 弹着表现（第 8 批）：AnimList= 按伤害选档 + Sparky 火花 + Bright 闪光
func _spawn_ra2_impact(dmg: float, at: Vector2) -> bool:
	if ra2_warhead == "":
		return false
	var host:=Effects._host()
	return Effects.Looks.impact(host,at,splinters.get("weapon_look","")) or Ra2Fx.play_impact(host, ra2_warhead, dmg, at)

func _radius_of(n: Node) -> float:
	var r = n.get("radius")
	if r == null:
		return 10.0
	return float(r)

# gamemd WaveClass::Draw_NonMagnetic (761640) and Update_Wave (762AF0).
# Each advancing edge interpolates three points between the muzzle and target.
func _draw_sonic_wave() -> void:
	var endpoint := target_point
	if is_instance_valid(target):
		endpoint = target.global_position
	var travel := endpoint - _sonic_origin
	if travel.is_zero_approx():
		return
	var lepton := Ra2Damage.PX_PER_CELL / 256.0
	var forward := travel.normalized()
	var flank := Iso.dir(forward.orthogonal() * (100.0 * lepton))
	var inset := Iso.dir(forward * minf(30.0 * lepton, travel.length() * 0.5))
	var depth := float(splinters.get("sonic_mouth_depth", 0.0))
	var mouth := Iso.dir(_sonic_origin - global_position) + Vector2.DOWN * depth
	var tip := Iso.dir(endpoint - global_position) + Vector2.UP * (50.0 * 30.0 / 256.0)
	var span := tip - mouth
	var tick := floori(_sonic_elapsed * ROF_FPS + 0.00001)
	var head := clampf(float(tick + 1) / SONIC_TICKS, 0.0, 1.0)
	var tail := clampf(float(tick - 1) / SONIC_TICKS, 0.0, 1.0)
	if head <= tail:
		return
	if material == null:
		var wave_material := ShaderMaterial.new()
		wave_material.shader = preload("res://shaders/yr_sonic_wave.gdshader")
		material = wave_material
	var octant := roundf((span + flank - inset).angle() / (PI / 4.0))
	var sample_dir := Vector2.from_angle(octant * PI / 4.0).round()
	material.set_shader_parameter("sample_dir", sample_dir)
	material.set_shader_parameter("intensity", 100 - tick)
	# UV is the native 60x30 battlefield pixel offset relative to the muzzle.
	var native_scale := (30.0 * sqrt(2.0)) / Ra2Damage.PX_PER_CELL
	for side in [-1.0, 1.0]:
		var near_edge: Vector2 = inset + flank * side
		var far_edge: Vector2 = span - inset + flank * side
		var offsets := PackedVector2Array([span * tail, span * head,
			near_edge.lerp(far_edge, head), near_edge.lerp(far_edge, tail)])
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for offset in offsets:
			points.append(mouth + offset)
			uvs.append(offset * native_scale)
		draw_primitive(points, PackedColorArray([Color.WHITE]), uvs)

func _draw() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(37)
	if splinters.has("kirov_crash"):
		preload("res://scripts/units/kirov_crash.gd").draw(self)
		return
	if splinters.has("soviet_round"):return # Reaper owns its container. The native Apocalypse shell has an empty Model.
	if splinters.has("ra3_expansion"):
		Ra3Expansion.draw_shot(self)
		return
	if splinters.has("ra3_hit_delay"): return
	Iso.begin(self)
	if is_sonic:
		_draw_sonic_wave()
		return
	# 地面阴影（Arcing/Shadow=yes 且已升空）
	var blend := Engine.get_physics_interpolation_fraction() if is_physics_interpolated_and_enabled() else 1.0
	var lift := -presentation_lift(blend)
	if ra2_shadow and _arc_z > 1.0:
		draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.28))
	# 可见弹体：真实 SHP 优先，其次程序化光点
	# Trails must render before the SHP branch returns, including homing missiles.
	Visual.draw_trail(self)
	if splinters.get("weapon_look","")==Effects.Looks.Sonar.ID:
		var elapsed:=maxf(0,DEFAULT_LIFETIME-life)
		var direction:=Iso.dir(_heading)
		Effects.Looks.Sonar.draw_flight(self,Vector2.ZERO,direction.normalized(),elapsed,minf(speed*elapsed*direction.length()/30,1))
	if splinters.get("bomb_drop", false) or ra2_image == "SUBT":
		var model := RA2Art.art("SUBT" if ra2_image == "SUBT" else "ZBOMB")
		if not model.is_empty():
			var size := RA2Art.frame_size(model)
			var count := int(model.facings)
			var frame := RA2Art.facing_index(_heading.angle(), count)
			if ra2_image == "SUBT": frame = posmod(frame + int(model.get("facing_offset", 0)), count)
			RA2Art.draw_sprite(self, model, Rect2(-size * 0.5, size), RA2Art.src_rect(model, frame), Color.WHITE)
			return
	if not ra2_inviso and ra2_image != "":
		var m: Dictionary = RA2Art.fx(ra2_image)
		if not m.is_empty():
			var cell: Vector2 = m.get("cell", Vector2.ZERO)
			var tex: Texture2D = m.get("tex")
			var src: Rect2 = RA2Art.fx_rect(m, Visual.sprite_frame(self, int(m.get("count", 1))))
			if tex != null:
				draw_texture_rect_region(tex, Rect2(Vector2(0.0, lift) - cell * 0.5, cell), src)
				return
	if ra2_inviso:
		return
	draw_circle(Vector2(0.0, lift), 3.2, front_color)
