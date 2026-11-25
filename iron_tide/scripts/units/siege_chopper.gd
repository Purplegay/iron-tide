extends RefCounted

# artmd SCHPDEPL has eleven visible frames followed by their shadows.
const BODY_FRAMES := 11

static func duration() -> float:
	return BODY_FRAMES * 60.0 / float(GameData.unit_index["SCHP"].deploy_animation.rate)

static func can_begin(unit, deploying: bool) -> bool:
	if unit.special.has("siege_progress"):
		return false
	return not deploying or landing_clear(unit)

static func landing_clear(unit) -> bool:
	var world = unit._battle_world()
	if not unit.logistics.landing_clear(world, unit.position, unit.radius): return false
	for other in world.units:
		if other != unit and AlliedAbilities.alive(other) and other.unit_id == "SCHP" and other._deployed:
			if unit.position.distance_to(other.position) < unit.radius + other.radius: return false
	return true

static func begin(unit, deploying: bool) -> bool:
	if not can_begin(unit, deploying): return false
	unit.special.siege_progress = 0.0 if deploying else 1.0
	return true

static func appearance(unit, id: String) -> void:
	if unit._ra2.get("key") == id: return
	unit._ra2 = RA2Art.art(id)
	unit._ra2_shd = RA2Art.art(id + "_shd") if id != "SCHPDEPL" else {}
	unit._ra2_tur = RA2Art.art("SCHD_tur") if id == "SCHD" else {}
	unit.queue_redraw()

static func sync_collision(unit) -> void:
	var layer := 0
	var mask := 0
	if not unit._dead and unit.embarked_in == null:
		# Folding clears _deployed before liftoff; altitude owns the physical domain.
		layer = 8 if unit.is_air_target() else 1
		mask = 8 if unit.is_air_target() else 7
	if unit.collision_layer != layer: unit.collision_layer = layer
	if unit.collision_mask != mask: unit.collision_mask = mask

static func tick(unit, delta: float) -> bool:
	sync_collision(unit)
	var changing: bool = unit.special.has("siege_progress")
	if unit._deployed and unit.logistics.air_lift > 0.001:
		if not landing_clear(unit):
			unit.special.erase("siege_progress")
			unit.set_deployed(false,false)
			unit.special.erase("siege_progress")
			return true
		unit.flight.altitude(0.0, delta)
		sync_collision(unit)
		return true
	if changing:
		if unit._ra2.get("key") != "SCHPDEPL":
			appearance(unit, "SCHPDEPL")
			var world = unit._battle_world()
			if world != null and world.position_visible_to("ally",unit.position):
				Ra2Sfx.play(GameData.unit_index["SCHP"].deploy_animation.sound,unit.position)
		var end := 1.0 if unit._deployed else 0.0
		var progress := move_toward(float(unit.special.siege_progress), end, delta / duration())
		unit.special.siege_progress = progress
		if is_equal_approx(progress, end):
			unit.special.erase("siege_progress")
			appearance(unit, "SCHD" if unit._deployed else "SCHP")
		unit.queue_redraw()
		return true
	appearance(unit, "SCHD" if unit._deployed else "SCHP")
	if not unit._deployed:
		unit.flight.altitude(1.0, delta)
		sync_collision(unit)
	return false
