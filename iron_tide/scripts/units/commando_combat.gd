class_name CommandoCombat
extends RefCounted
## Independent YR adapter: building C4 is an attack action; Sapper/FakeC4
## are secondary weapons with their own verses, range, damage and reload.
const IDS := ["GHOST", "TANY", "CCOMAND", "PTROOP"]

static func handles(unit: Unit) -> bool:
	return unit.unit_id in IDS

static func versus(w: Dictionary, target) -> float:
	return GameData.ra2_verse(str(w.get("ra2_warhead", "")), str(target.ra2_armor))

static func weapon_for(unit: Unit, target) -> Dictionary:
	if not handles(unit): return {}
	var row := AlliedAbilities.source(unit)
	var elite: bool = unit.veteran_level >= 2
	var primary := AlliedAbilities.weapon(str(row.get("ElitePrimary" if elite else "Primary", row.get("Primary", ""))))
	if not AlliedAbilities.alive(target): return primary
	# NavalTargeting=4 forces the secondary against vessels. A zero primary
	# verse falls back to secondary (Tanya vs vehicles; Chrono Commando vs buildings).
	if versus(primary, target) == 0.0 or (target is Unit and target.is_naval and int(row.get("NavalTargeting", 0)) == 4):
		var secondary := AlliedAbilities.weapon(str(row.get("EliteSecondary" if elite else "Secondary", row.get("Secondary", ""))))
		if not secondary.is_empty() and versus(secondary, target) > 0.0: return secondary
	return primary

static func building_c4(unit: Unit, target) -> bool:
	if not handles(unit) or not AlliedAbilities.flag(unit, "C4") or not target is Building: return false
	if not AlliedAbilities.alive(target) or BattleRequest.friendly(target.side,unit.side) or target.special.has("c4_left") or WallArt.is_wall(target.data): return false
	var row: Dictionary = GameData.allied_capabilities.get("buildings", {}).get(target.building_id,
		GameData.ra2_source_buildings.get(target.building_id, {}).get("extra", {}))
	return GameData._ra2_flag(row.get("CanC4", true)) and not GameData._ra2_flag(row.get("Wall", false))

static func sabotage(unit: Unit, target) -> bool:
	if building_c4(unit, target): return true
	if not handles(unit) or not AlliedAbilities.alive(target): return false
	var w := weapon_for(unit, target)
	var raw := GameData.ra2_weapon(str(w.get("ra2_weapon_id", "")))
	return GameData._ra2_flag(raw.get("extra", {}).get("SabotageCursor", false))

## Nearest point a ground weapon can engage from this side of the target.
static func contact_point(unit: Unit, target) -> Vector2:
	var center: Vector2 = target.global_position
	var origin: Vector2 = unit.global_position
	if target is Building:
		return target.closest_footprint_point(origin)
	if target is Unit and unit.unit_id == "DTRUCK":
		return center.move_toward(origin, target.radius)
	return center

static func distance_to(unit: Unit, target) -> float:
	# Ordinary unit targets need neither foundation projection nor dynamic Node lookup.
	# Keep the DTRUCK contact radius and RefCounted ground-order target on the original path.
	if target is Unit and (unit.is_air or unit.is_naval or unit.unit_id != "DTRUCK"):
		var victim: Unit = target
		var distance := unit.global_position.distance_to(victim.global_position)
		return maxf(0.0, distance) if unit.is_air or unit.is_naval else distance
	if not unit.is_air and not unit.is_naval:
		return unit.global_position.distance_to(contact_point(unit, target))
	var distance: float = unit.global_position.distance_to(target.global_position)
	if target is Building and (handles(unit) or (unit.unit_id in ["IVAN", "CIVAN"] and target.special.has("bridge_span"))):
		distance -= target.footprint_clearance(target.global_position.direction_to(unit.global_position))
	return maxf(0.0, distance)

static func begin_c4(unit: Unit, target) -> bool:
	if preload("res://scripts/units/tanya_talents.gd").locked(unit):return false
	if not building_c4(unit, target) or (unit.fire_stance == "none" and not unit.attack_ordered): return false
	# Normal move orders must never be hijacked by automatic sabotage.
	if unit.has_move_order and not unit.attack_move and not unit.attack_ordered: return false
	if unit.hold_position and unit.global_position.distance_to(AlliedAbilities.approach(unit, target)) > unit.radius + 24.0: return false
	var resume: Vector2 = unit.move_target if unit.has_move_order and unit.attack_move and not unit.attack_ordered else Vector2.INF
	if not AlliedAbilities.use(unit, "allied_c4", target): return false
	if resume.is_finite(): unit.special.c4_resume = resume
	return true

static func cancel_entry(unit) -> void:
	# Cancellation must not strand a soldier inside a solid foundation.
	var target = unit.special.get("target")
	var exit: Vector2 = unit.special.get("c4_exit", Vector2.INF)
	if exit.is_finite() and is_instance_valid(target) and target is Building \
			and unit.position.distance_to(target.position) < target.footprint_clearance(target.position.direction_to(unit.position)) + unit.radius:
		unit.position = exit
	for key in ["c4_stage", "c4_entry", "c4_exit", "c4_stuck"]: unit.special.erase(key)

static func step_inside(unit, target, point: Vector2, delta: float) -> bool:
	var offset: Vector2 = point - unit.global_position
	if offset.length() <= 1.0:
		unit.velocity = Vector2.ZERO
		return true
	var motion := offset.limit_length(unit.move_speed * delta)
	var world = unit._battle_world()
	var next: Vector2 = unit.global_position + motion
	if world == null or next.x < 0 or next.y < 0 or next.x >= world.map_size or next.y >= world.map_size or not unit._domain_ok(next):
		AlliedAbilities.cancel(unit)
		return false
	unit._face(point)
	unit.velocity = motion / maxf(delta, 0.001)
	var before: Vector2 = unit.position
	# Only the sabotaged building is traversable; walls, other buildings and
	# units remain collidable. The exception never persists into a save/cancel.
	if is_instance_valid(target): unit.add_collision_exception_with(target)
	unit.move_with_traffic_exceptions(motion)
	if is_instance_valid(target): unit.remove_collision_exception_with(target)
	unit.special.c4_stuck = float(unit.special.get("c4_stuck", 0.0)) + delta if unit.position.distance_to(before) < 0.1 else 0.0
	if float(unit.special.c4_stuck) >= 3.0: AlliedAbilities.cancel(unit)
	return unit.global_position.distance_to(point) <= 1.0

static func tick_c4(unit, delta: float) -> bool:
	var target = unit.special.get("target")
	var stage: String = unit.special.get("c4_stage", "approach")
	if stage == "exit":
		var exit: Vector2 = unit.special.get("c4_exit", unit.position)
		if step_inside(unit, target, exit, delta):
			var resume: Vector2 = unit.special.get("c4_resume", Vector2.INF)
			AlliedAbilities.cancel(unit)
			unit.velocity = Vector2.ZERO
			unit.has_move_order = false
			if resume.is_finite(): unit.order_move(resume, true)
		return true
	if not AlliedAbilities.can_order(unit, target, "allied_c4"):
		AlliedAbilities.cancel(unit)
		return false
	if stage == "approach":
		var destination := AlliedAbilities.approach(unit, target)
		var distance: float = unit.global_position.distance_to(destination)
		if distance > 4.0:
			# A blocked goal cell resolves to a nearby free cell, not the exact
			# foundation entrance. Finish only this short terminal segment using
			# physical movement; do not steer back to the reached grid waypoint.
			var final_segment: bool = distance <= PathService.CELL * 2.0 \
				and unit._path_pts.size() >= 2 and unit._path_i >= unit._path_pts.size() - 1 \
				and (unit.position.distance_to(unit._path_pts[-1]) <= unit.radius + 24.0 or distance < unit._path_pts[-1].distance_to(destination))
			if final_segment: unit._move_toward(destination, delta, false)
			else: unit._go_to(destination, delta, 4.0)
			unit._face_if_moving()
			unit._move_water_safe()
			return true
		var direction: Vector2 = target.global_position.direction_to(unit.global_position)
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		var edge: float = target.footprint_clearance(direction)
		unit.special.c4_exit = unit.global_position
		unit.special.c4_entry = target.global_position + direction * maxf(0.0, edge - 8.0)
		unit.special.c4_stage = "enter"
		preload("res://scripts/units/expansion_2_infiltration.gd").attacking(unit)
		preload("res://scripts/units/expansion_2_commandos.gd").c4_started(unit)
	if not step_inside(unit, target, unit.special.c4_entry, delta): return true
	if not Geometry2D.is_point_in_polygon(unit.global_position - target.global_position, target.footprint_poly()):
		AlliedAbilities.cancel(unit)
		return false
	# Original rulesmd.ini C4Delay is minutes. Enter the foundation first,
	# arm the building's timer, then leave alive; this is not garrisoning.
	target.special.c4_left = maxf(0.1, float(GameData.allied_capabilities.get("general", {}).get("C4Delay", 0.03)) * 60.0)
	target.special.c4_owner = unit
	target.special.erase("c4_secondary");target.special.erase("c4_side")
	preload("res://scripts/units/temporal_visual.gd").sync(target)
	unit._battle_world().reveal_attack(unit, target)
	Ra2Sfx.play("SealPlaceBomb", unit.global_position)
	unit.special.c4_stage = "exit"
	unit.has_move_order = false
	unit.velocity = Vector2.ZERO
	return true
