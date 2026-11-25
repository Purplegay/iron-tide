extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const Defense=preload("res://scripts/units/leizhu_defense.gd")

static func mobile(unit) -> bool:
	if Defense.rank(unit)<3 or unit.embarked_in!=null or unit._stun_timer>0 or unit.repairing or float(unit.special.leizhu.get("shutdown_left",0))>0:return false
	var source=unit.special.get("temporal_by")
	return AlliedAbilities.alive(source) and source is Unit and is_same(source.special.get("temporal_target"),unit) and AlliedAbilities.frozen(unit)

static func move(unit,dt:float) -> bool:
	if not mobile(unit):return false
	unit._drive_heading=NAN;unit._hull_prev=unit.hull_angle;unit._turret_prev=unit.turret_angle
	unit._anim+=dt;unit.decorate_tick(dt)
	if unit.has_move_order:
		var speed:float=unit.move_speed
		unit.move_speed=speed*P.number("hero/TTNK/survival","frozen_speed")
		# Keep native path steering, water/obstacle collision, arrival and queued movement.
		# The frozen branch returns before weapon, ability and ordinary AI updates.
		unit._process_combat(dt)
		unit.move_speed=speed
		unit._limit_turn(dt)
	else:unit.velocity=Vector2.ZERO
	unit.queue_redraw()
	return true
