extends RefCounted
## Independent continuous-world adapter for YR Fly / Jumpjet locomotors.
## Parameters: installed rulesmd.ini and YRpp locomotor fields. Curve integration
## and projected pixels are Godot adaptations, not a copy of engine assembly.
const LEPTONS_PER_CELL := 256.0
const WORLD_CELL := 55.0
const HEIGHT_PIXEL := 30.0 / LEPTONS_PER_CELL
const TICKS := 15.0
const DEFAULT_FLIGHT_LEVEL := 1500.0

var unit: Unit
var jumpjet := false
var height := DEFAULT_FLIGHT_LEVEL
var crash_speed := 0.0
var crash_lift := -1.0
var climb := 512.0
var turn_rate := deg_to_rad(63.28125)
var acceleration := 200.0
var horizontal_speed := 0.0
var balloon := false
var landable := true
var no_wobbles := true
var wobble := 0.0
var deviation := 0.0

func setup(actor) -> void:
	unit = actor
	if unit.unit_id == "R3HARBINGER":
		# Uprising AlliedGunshipAircraftLocomotor. Native seconds, independent of YR tick scale.
		jumpjet = true
		balloon = true
		landable = false
		height = 190.0 * 1.5 / HEIGHT_PIXEL
		climb = height # Continuous takeoff adapter; native acceleration is one second.
		horizontal_speed = 120.0 * 1.5
		turn_rate = PI / 2.5
		acceleration = horizontal_speed
		no_wobbles = true
		return
	var row: Dictionary = GameData.ra2_source_units.get(unit.unit_id, {})
	var raw: Dictionary = {}
	for key in row.get("extra", {}): raw[str(key).to_lower()] = row.extra[key]
	jumpjet = str(row.get("locomotor", "")).contains("92612C46") or GameData._ra2_flag(raw.get("jumpjet", false))
	balloon = GameData._ra2_flag(raw.get("balloonhover", false))
	landable = GameData._ra2_flag(raw.get("landable", not balloon))
	# Extension helicopters / winged creatures have no YR source profile.
	# Preserve their authored speed and airborne idle behavior, using hover motion.
	if row.is_empty() and unit.is_air:
		jumpjet = true
		balloon = true
		landable = false
	if jumpjet:
		if unit.unit_id == "JUMPJET" and GameData._ra2_flag(raw.get("crashable", false)):
			crash_speed = float(raw.get("jumpjetcrash", 5.0)) * 2.0 * TICKS * HEIGHT_PIXEL
		height = float(raw.get("jumpjetheight", 500))
		climb = float(raw.get("jumpjetclimb", 5)) * TICKS
		turn_rate = float(raw.get("jumpjetturnrate", 4)) * TAU / 256.0 * TICKS
		horizontal_speed = float(raw.get("jumpjetspeed", 14)) * TICKS * WORLD_CELL / LEPTONS_PER_CELL
		# Accel changes lepton/tick speed each logic tick. Converting to world/s²
		# needs both time factors; one factor stretched the ramp by 15 times.
		acceleration = float(raw.get("jumpjetaccel", 2)) * TICKS * TICKS * WORLD_CELL / LEPTONS_PER_CELL
		no_wobbles = GameData._ra2_flag(raw.get("jumpjetnowobbles", false))
		wobble = float(raw.get("jumpjetwobbles", 0.15))
		deviation = float(raw.get("jumpjetdeviation", 40))
		if row.is_empty():
			horizontal_speed = maxf(1.0, float(unit.data.get("speed", unit.move_speed)))
			acceleration = horizontal_speed * 2.0
			climb = 300.0
			no_wobbles = true
	else:
		height = float(raw.get("flightlevel", DEFAULT_FLIGHT_LEVEL))
		turn_rate = float(raw.get("rot", 3)) * TAU / 256.0 * TICKS
		# Fly uses PitchSpeed for takeoff; this continuous VTOL ramp is an adapter.
		climb = float(raw.get("pitchspeed", 1.0)) * LEPTONS_PER_CELL * 2.0
		acceleration = maxf(1.0, unit.move_speed) * 2.0
	height = maxf(1.0, height)
	climb = maxf(1.0, climb)
	turn_rate = maxf(0.01, turn_rate)
	acceleration = maxf(1.0, acceleration)

## Death is already credited. Only the SHP and its separation from the ground advance here.
func begin_air_death(lift: float) -> bool:
	if lift <= 0.0 or crash_speed <= 0.0:
		return false
	for sequence in ["AirDeathStart", "AirDeathFalling", "AirDeathFinish"]:
		if int(unit._seq.get(sequence, {}).get("per", 0)) <= 0: return false
	crash_lift = lift
	unit._anim = 0.0
	unit.special.death_sequence = "AirDeathStart"
	unit._dying = lift / crash_speed + float(unit._seq.AirDeathFinish.per) / TICKS
	return true

func update_air_death() -> void:
	var finish_time := float(unit._seq.AirDeathFinish.per) / TICKS
	crash_lift = maxf(0.0, unit._dying - finish_time) * crash_speed
	if crash_lift <= 0.0:
		unit.special.death_sequence = "AirDeathFinish"
		unit._anim = finish_time - unit._dying
	elif unit._anim >= float(unit._seq.AirDeathStart.per) / TICKS:
		unit.special.death_sequence = "AirDeathFalling"

func visual_lift() -> float:
	if crash_lift >= 0.0: return crash_lift
	var offset := 0.0
	if jumpjet and not no_wobbles and unit.logistics.air_lift >= 0.99:
		offset = sin(unit._anim * wobble * TICKS * TAU + float(unit._seed % 97)) * deviation
	var lift := maxf(0.0, height * unit.logistics.air_lift + offset) * HEIGHT_PIXEL
	if unit.unit_id == "JUMPJET":
		# Requested visual jetpack sway, independent of YR JumpjetNoWobbles and
		# locomotor height. Share this offset with picking, muzzle and HP anchors.
		var moving := clampf(unit.velocity.length() / maxf(1.0, max_speed()), 0.0, 1.0)
		var amplitude := lerpf(2.5, 0.8, moving)
		var airborne := smoothstep(0.65, 1.0, unit.logistics.air_lift)
		var phase := TAU * float(posmod(unit._seed, 997)) / 997.0
		lift += sin(unit._anim * TAU / 2.4 + phase) * amplitude * airborne
	if unit.night_skin!=null:lift+=unit.night_skin.hover_lift(unit)
	return lift

func altitude(target: float, delta: float) -> void:
	unit.logistics.air_lift = move_toward(unit.logistics.air_lift, target, climb / height * delta * (Unit.Training.scale(unit) if unit.unit_id == "SHAD" else 1.0))
	unit.queue_redraw()

func max_speed() -> float:
	if not jumpjet: return unit.move_speed * preload("res://scripts/units/electric_cards.gd").return_speed(unit)
	# Keep veterancy / extension buffs while consuming JumpjetSpeed, not Speed.
	var base := maxf(1.0, float(unit.data.get("speed", unit.move_speed)))
	return horizontal_speed * unit.move_speed / base

func face(destination: Vector2, delta: float) -> void:
	var direction: Vector2 = destination - unit.position
	if direction.is_zero_approx(): return
	unit.hull_angle = rotate_toward(unit.hull_angle, direction.angle(), turn_rate * delta)
	unit.turret_angle = unit.hull_angle
	unit.aim_dir = Vector2.from_angle(unit.hull_angle)

func travel(destination: Vector2, delta: float, arrival := 5.0) -> bool:
	var offset: Vector2 = destination - unit.position
	var distance := offset.length()
	if distance <= arrival:
		unit.velocity = Vector2.ZERO
		return true
	face(destination, delta)
	# Take off vertically first. No ground-level sliding across buildings.
	if unit.logistics.air_lift < 0.95:
		unit.velocity = Vector2.ZERO
		return false
	var top := max_speed()
	var angle := absf(angle_difference(unit.hull_angle, offset.angle()))
	# Bounded steering changes the actual velocity, not only the displayed nose.
	# Slow down before tight turns / arrival so the turn radius cannot trap a
	# destination inside an endless orbit.
	var desired := minf(top, sqrt(2.0 * acceleration * maxf(0.0, distance - arrival)))
	# Radius matters while turning, not while flying directly toward the goal.
	# The braking-distance cap above still handles the straight-line arrival.
	if angle > deg_to_rad(20.0):
		desired = minf(desired, maxf(top * 0.12, distance * turn_rate * 0.65))
	desired *= maxf(0.0 if jumpjet else 0.15, cos(angle))
	var speed := move_toward(unit.velocity.length(), desired, acceleration * delta)
	speed = minf(speed, distance / maxf(delta, 0.001))
	unit.velocity = Vector2.from_angle(unit.hull_angle) * speed
	unit._move_water_safe()
	return false

func can_land() -> bool:
	return can_land_at(unit.position)

func can_land_at(center: Vector2) -> bool:
	if not landable or balloon: return false
	var world = unit._battle_world()
	if world == null or world.path_service == null: return false
	# A transport may descend beside waiting infantry, but never onto terrain
	# blockers or water. Passenger placement keeps its stricter occupancy test.
	for i in 9:
		var point: Vector2 = center if i == 0 else center + Vector2.from_angle(TAU * (i - 1) / 8.0) * unit.radius
		if point.x < 0.0 or point.y < 0.0 or point.x >= world.map_size or point.y >= world.map_size:
			return false
		if world.in_water_world(point) or world.path_service.is_blocked(point): return false
	return true

func process_combat(delta: float) -> void:
	if unit.unit_id=="R3HARBINGER":
		preload("res://scripts/units/ra3_gunship_flight.gd").tick(unit,self,delta)
		return
	var target = unit.attack_target
	var valid: bool = AlliedAbilities.alive(target) and (unit.attack_ordered or unit.fire_stance != "none") and unit._automatic_target_allowed(target) and unit._weapon_domain_valid(target)
	var in_range: bool = valid and unit.position.distance_to(target.position) <= unit.attack_range and unit.position.distance_to(target.position) >= unit.min_range
	var pursuing: bool = valid and (unit._can_pursue_attacker(target,unit.attack_range) or preload("res://scripts/units/ai_engagement.gd").air_pursuit(unit,target))
	if valid and (unit.attack_ordered or unit.attack_move or not unit.has_move_order or pursuing):
		if unit.unit_id=="ZEP" and (in_range or unit.attack_ordered or pursuing) and not unit.hold_position and unit.position.distance_to(target.position)>8.0:
			travel(target.position,delta)
			return
		if in_range:
			face(target.position, delta)
			unit.velocity = unit.velocity.move_toward(Vector2.ZERO, acceleration * delta)
			unit._move_water_safe()
			if unit.attack_ordered: unit.has_move_order = false
			return
		if not unit.hold_position and (unit.attack_ordered or pursuing):
			var away: Vector2 = target.position.direction_to(unit.position)
			var approach: Vector2 = target.position + away * maxf(unit.min_range + 12.0, unit.attack_range * 0.75)
			travel(approach, delta)
			return
	if unit.patrolling and unit.patrol_points.size() == 2 and not unit.has_move_order:
		unit.patrol_index = 1 - unit.patrol_index
		unit.order_move(unit.patrol_points[unit.patrol_index], true)
	if unit.has_move_order:
		if travel(unit.move_target, delta):
			unit.has_move_order = false
			unit.attack_ordered = false
			unit._advance_queue()
	else:
		unit.velocity = unit.velocity.move_toward(Vector2.ZERO, acceleration * delta)
		unit._move_water_safe()
