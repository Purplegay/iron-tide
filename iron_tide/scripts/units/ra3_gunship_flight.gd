extends RefCounted
## Continuous steering adapter for Uprising's GunshipJetAIStateMachine.
## CirclingRadius/Speed are sourced; this is not the unavailable SAGE CPU state machine.
const CENTER := "ra3_flight_center"
const MODE := "ra3_flight_mode"

static func radius(unit) -> float:
	return float(Ra3Expansion.rules.objects.R3HARBINGER.locomotor.CirclingRadius)*1.5

static func circle_speed(unit, flight) -> float:
	var percent: String=Ra3Expansion.rules.objects.R3HARBINGER.locomotor.CirclingSpeed
	return flight.max_speed()*float(percent.trim_suffix("%"))/100.0

static func safe_center(unit, point: Vector2, distance: float) -> Vector2:
	var world=unit._battle_world()
	var edge: float=distance+unit.radius+8.0
	return point.clamp(Vector2.ONE*edge,Vector2.ONE*(world.map_size-edge))

static func tick(unit, flight, delta: float) -> void:
	if unit.logistics.air_lift<0.95:
		unit.velocity=Vector2.ZERO
		return
	var r:=radius(unit)
	var target=unit.attack_target
	var attack: bool=AlliedAbilities.alive(target) and unit.fire_stance!="none" and unit._automatic_target_allowed(target) and unit._weapon_domain_valid(target)
	attack=attack and (unit.attack_ordered or unit.attack_move or not unit.has_move_order or unit._can_pursue_attacker(target,unit.attack_range))
	if attack and unit.hold_position and unit.position.distance_to(target.position)>unit.attack_range:attack=false
	var center: Vector2
	var speed:=circle_speed(unit,flight)
	if attack:
		center=safe_center(unit,target.position,r)
		unit.special[MODE]="attack"
		unit.special[CENTER]=center
		if unit.attack_ordered:unit.has_move_order=false
	else:
		if unit.patrolling and unit.patrol_points.size()==2 and not unit.has_move_order:
			unit.patrol_index=1-unit.patrol_index
			unit.order_move(unit.patrol_points[unit.patrol_index],true)
		if unit.has_move_order:
			center=safe_center(unit,unit.move_target,r)
			unit.special[MODE]="move"
			unit.special[CENTER]=center
			# Fixed-wing arrival means joining the orbit around the requested point.
			# Never brake to a stationary point or snap the aircraft onto the circle.
			if unit.position.distance_to(center)<=r+12.0:
				unit.has_move_order=false;unit.attack_ordered=false
				unit.special[MODE]="idle"
				unit._advance_queue()
			else:speed=flight.max_speed()
		else:
			if not unit.special.has(CENTER):
				unit.special[CENTER]=safe_center(unit,unit.position+Vector2.from_angle(unit.hull_angle).orthogonal()*r,r)
			center=unit.special[CENTER]
			unit.special[MODE]="idle"
	var radial:=center.direction_to(unit.position)
	if radial.is_zero_approx():radial=-Vector2.from_angle(unit.hull_angle).orthogonal()
	var distance: float=unit.position.distance_to(center)
	var desired:=radial.orthogonal()+radial*clampf((r-distance)/(r*0.35),-4.0,4.0)
	unit.hull_angle=rotate_toward(unit.hull_angle,desired.angle(),flight.turn_rate*delta)
	var actual:=move_toward(unit.velocity.length(),speed,flight.acceleration*delta)
	unit.velocity=Vector2.from_angle(unit.hull_angle)*actual
	unit._move_water_safe()
	unit.turret_angle=unit.position.direction_to(target.position).angle() if attack else unit.hull_angle
	unit.aim_dir=Vector2.from_angle(unit.turret_angle)
