extends RefCounted
## A ground movement order: route first, fire at contacts without chasing them.
const ID := "reverse_attack"
const SPEED := 0.55

static func ready(unit) -> bool:
	return AlliedAbilities.alive(unit) and not unit.is_air and not unit.is_naval and not unit.is_harvester and not unit._deployed and unit.embarked_in == null and unit._stun_timer <= 0 and not AlliedAbilities.frozen(unit) and unit.move_speed > 0 and not AlliedAbilities.infantry_teleporter(unit) and not unit.weapon.is_empty() and unit.power_disabled_reason().is_empty()

static func issue(world, point: Vector2) -> bool:
	if not point.is_finite() or not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point): return false
	var units: Array = []
	for unit in world.selected_units:
		if ready(unit): units.append(unit)
	if units.is_empty(): return false
	var slots: Array = Formations.layout(units.size(),point,world._group_facing(point),world.formation_mode,world._formation_spacing(units))
	var assigned: Dictionary = world._assign_move_slots(units,slots,point)
	var issued := false
	for unit in units:
		var destination: Vector2 = assigned.get(unit,point)
		var path: PackedVector2Array = world.path_for_unit(unit,destination)
		if world.path_service != null and path.size() < 2: continue
		var target = unit.attack_target
		unit.cancel_stance()
		unit.clear_queue()
		unit.order_move(destination,false,null,path)
		if not unit.has_move_order: continue
		unit.special[ID] = true
		unit.fire_stance = "defend"
		unit.attack_target = target if unit._weapon_target_valid(target) else null
		unit._think_timer = 0
		issued = true
	if issued:
		world._add_order_mark(point,"attack_move")
		world._play_group_voice(units,"move")
	return issued

static func tick(unit, delta: float) -> void:
	if not unit.has_move_order or not ready(unit):
		unit.special.erase(ID)
		unit.velocity = Vector2.ZERO
		return
	unit._tick_path_stuck(delta)
	if unit.global_position.distance_to(unit.move_target) <= unit.ARRIVE_EPS or unit._local_traffic.can_settle(unit):
		unit.special.erase(ID)
		unit.has_move_order = false
		unit.velocity = Vector2.ZERO
		unit._advance_queue()
	else:
		unit._move_toward(unit.move_target,delta)
		if unit._weapon_target_valid(unit.attack_target): unit._face(unit.attack_target.global_position)
		else: unit.turret_angle = unit.hull_angle
	unit._move_water_safe()

static func steer(unit, delta: float) -> void:
	if unit.velocity.length_squared() < 0.01: return
	var wanted: float = (-unit.velocity).angle()
	var rate := deg_to_rad(float(unit._mv("rot",0.0)))
	unit._drive_heading = rotate_toward(unit._hull_prev,wanted,rate*delta) if rate > 0 else wanted
	unit.hull_angle = unit._drive_heading
	var error := absf(angle_difference(unit.hull_angle,wanted))
	unit._drive_turning = error >= deg_to_rad(35)
	if unit._drive_turning:
		unit.velocity = Vector2.ZERO
		return
	var turn_speed := smoothstep(cos(deg_to_rad(35)),cos(deg_to_rad(20)),cos(error))
	unit.velocity = -Vector2.from_angle(unit.hull_angle)*minf(unit.velocity.length(),unit.move_speed)*SPEED*turn_speed
