extends Node2D

const WARP_SHADER := preload("res://scripts/core/yr_magnetic_wave.gdshader")
const Lepton := Ra2Damage.PX_PER_CELL / 256.0
const Height := preload("res://scripts/units/unit_flight.gd").HEIGHT_PIXEL
const RATE := BattleClock.RULE_TICKS_PER_SECOND
# gamemd WaveClass::Draw_Magnetic (762070): mode 3, ±50 lateral / +50 first-point height.
const HALF_WIDTH := 50.0 * Lepton
const SWEEP_TICKS := 20.0
const INTENSITY_RESET_TICK := 80.0 # 100 counts down to 20; then reset to 64
const INTENSITY_PERIOD := 44.0
const ACTIVE_WAVE := &"yr_magnetic_wave"

var world: Node2D
var shooter: Unit
var victim: Node2D
var reversed: bool
var weapon_range: float
var tick_age := 0.0
var release_tick := -1.0
var first := Vector2.ZERO
var last := Vector2.ZERO
var lateral := Vector2.ZERO
var copy: BackBufferCopy

static func handles(unit, gun: Dictionary) -> bool:
	return unit.unit_id == "TELE" and gun.get("name", "") in ["MagneticBeam", "MagneticBeamE", "MagneShake"]

static func muzzle(unit: Unit) -> Vector2:
	# artmd [TELE] PrimaryFireFLH=85,0,130. The original active wave uses slot zero for both guns.
	return unit.global_position + Vector2.from_angle(unit.turret_angle) * 85.0 * Lepton \
		+ RA2Art.art_dir(Vector2.UP * (unit._visual_lift() + 130.0 * Height))

static func fire(unit: Unit, target: Node2D, reach: float) -> void:
	var battle = unit._battle_world()
	if battle == null or unit.has_meta(ACTIVE_WAVE): return
	var wave := new()
	wave.world = battle
	wave.shooter = unit
	wave.victim = target
	wave.weapon_range = reach
	# Update_Wave reverses the endpoint order for AbstractType::Unit, but not buildings.
	wave.reversed = target is Unit
	battle.effects_root.add_child(wave)
	unit.set_meta(ACTIVE_WAVE, wave)

func _ready() -> void:
	# Visibility uses moving ground endpoints, never the (lifted) sampled pixels.
	add_to_group("per_piece_fog_visibility")
	copy = BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	copy.show_behind_parent = true
	add_child(copy)
	var warp := ShaderMaterial.new()
	warp.shader = WARP_SHADER
	material = warp
	_refresh_axis()
	_refresh_visibility()

func _refresh_axis() -> void:
	var start := muzzle(shooter)
	# Building target location is its targetable body; units use world coords with presentation lift.
	var end := (victim as Building).art_center() if victim is Building else victim.global_position + RA2Art.art_dir(Vector2.UP * (victim as Unit)._visual_lift())
	first = end if reversed else start
	last = start if reversed else end
	first += RA2Art.art_dir(Vector2.UP * 50.0 * Height)
	lateral = (victim.global_position - shooter.global_position).normalized().orthogonal() * HALF_WIDTH

func _refresh_visibility() -> void:
	visible = AlliedAbilities.alive(shooter) and AlliedAbilities.alive(victim) \
		and world.position_visible_to("ally", shooter.global_position) \
		and world.position_visible_to("ally", victim.global_position)
	if not visible: return
	var bounds := Rect2(to_local(first - lateral), Vector2.ZERO)
	bounds = bounds.expand(to_local(first + lateral)).expand(to_local(last - lateral)).expand(to_local(last + lateral))
	copy.rect = bounds.grow(24.0)

func _process(delta: float) -> void:
	if not AlliedAbilities.alive(shooter) or not AlliedAbilities.alive(victim) or shooter.embarked_in != null:
		hide()
		queue_free()
		return
	if not world.paused and not world.ended:
		tick_age += delta * RATE
		var still_linked: bool = shooter.attack_target == victim and (not reversed or victim.special.get("magnet_source") == shooter)
		if release_tick < 0.0 and (not still_linked or shooter.global_position.distance_to(victim.global_position) > weapon_range * 1.1):
			release_tick = tick_age
		if release_tick >= 0.0 and tail() >= head():
			hide()
			queue_free()
			return
	_refresh_axis()
	_refresh_visibility()
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(shooter) and shooter.has_meta(ACTIVE_WAVE) and shooter.get_meta(ACTIVE_WAVE) == self:
		shooter.remove_meta(ACTIVE_WAVE)

func head() -> float:
	return clampf((tick_age if release_tick < 0.0 else release_tick) / SWEEP_TICKS, 0.0, 1.0)

func tail() -> float:
	return clampf((tick_age - release_tick) / SWEEP_TICKS, 0.0, 1.0) if release_tick >= 0.0 else 0.0

func _draw() -> void:
	var end := head()
	var start := tail()
	if end <= start or lateral.is_zero_approx(): return
	var a := first.lerp(last, start)
	var b := first.lerp(last, end)
	# A newly opened/closing sweep can have negligible area, especially
	# with several fixed simulation steps between rendered frames.
	if absf((b-a).cross(lateral)) < 0.01: return
	var points := PackedVector2Array([to_local(a - lateral), to_local(a + lateral), to_local(b + lateral), to_local(b - lateral)])
	# UV carries the projected offset from first, in original-art pixel units.
	var uv := PackedVector2Array()
	for p in points:
		uv.append(Iso.dir(to_global(p) - first) / (Ra2Damage.PX_PER_CELL / (30.0 * sqrt(2.0))))
	var ticks := floorf(tick_age)
	var intensity := 100.0 - ticks if ticks < INTENSITY_RESET_TICK else 64.0 - fposmod(ticks - INTENSITY_RESET_TICK, INTENSITY_PERIOD)
	(material as ShaderMaterial).set_shader_parameter("intensity", intensity)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv)
