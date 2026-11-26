extends RefCounted
const PROFILE := "res://assets/ra2/american_paradrop.json"
# Keep the release visible long enough to read the drop and landing.
# At the 1500-lepton release height, the local 15-tick clock gives about 8.3 s.
const DESCENT_SPEED_MULTIPLIER := 4.0
static var rules: Dictionary = {}

static func profile() -> Dictionary:
	if rules.is_empty(): rules = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	return rules

static func configure(field) -> void:
	if field.building_id in ["GAAIRC", "AMRADR"] and field.battle.mission.get("id") == "yr_hollywood":
		field.special.american_airfield = false
		if field.sw_type() == "AmerParaDrop":
			field.superweapon = {}
			field._sw_charge = 0.0
			field._sw_was_ready = false
		return
	if field.building_id != "GAAIRC" or field.special.has("american_airfield"): return
	# The shared airport model stands for AMRADR only when built by Americans.
	field.special.american_airfield = field.battle._countries.get(field.side, "") == "Americans" and not field.special.get("has_been_captured", false)
	if field.special.american_airfield: field.superweapon = profile().duplicate(true)

static func valid_zone(world, point: Vector2) -> bool:
	return point.is_finite() and Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point) and not world.in_water_world(point) and not world.path_service.is_blocked(point)

static func _start_drop(world, side: String, point: Vector2, infantry: String, count: int) -> bool:
	if not valid_zone(world, point) or count <= 0: return false
	var dir := 1 if point.x > world.map_size * 0.5 else -1
	var start := Vector2(0 if dir == 1 else world.map_size, point.y)
	var plane = world.spawn_unit(str(profile().plane), side, start)
	if plane == null: return false
	plane.special.para_target = point
	plane.special.para_count = count
	plane.special.para_infantry = infantry
	plane.special.para_left = count
	plane.special.para_dir = dir
	plane.hull_angle = 0.0 if dir == 1 else PI
	plane.logistics.air_lift = 1.0
	return true

static func launch(field, point: Vector2) -> bool:
	var world = field.battle
	var infantry := str(field.superweapon.infantry)
	if field.sw_type() == "ParaDrop" and field.side == "enemy" and world.enemy_faction == "yuri": infantry = "INIT"
	return _start_drop(world, field.side, point, infantry, int(field.superweapon.count))

# Mission scripts use the same aircraft, chute and landing rules as a real
# paradrop, but do not require a constructed superweapon building.
static func launch_story(world, point: Vector2, infantry: String, count: int) -> bool:
	return _start_drop(world, "ally", point, infantry, count)

static func open_ground(world, at: Vector2, except = null) -> Vector2:
	for ring in 4:
		for i in maxi(1, ring * 8):
			var p := at + Vector2.RIGHT.rotated(TAU * i / maxi(1, ring * 8)) * ring * 28
			if not valid_zone(world,p): continue
			if world.units.any(func(u): return u != except and world.actor_alive(u) and not u.is_air and u.embarked_in == null and u.position.distance_to(p) < u.radius + 9): continue
			return p
	return Vector2.INF

static func fly(plane, delta: float) -> void:
	var world = plane._battle_world()
	if world.paused or world.ended or world.get_tree().paused: return
	var spec := profile()
	var dir := int(plane.special.para_dir)
	var goal: Vector2 = plane.special.para_target
	var radius := float(spec.radius_leptons) * 55.0 / 256.0
	var span := minf(radius, 120.0)
	var count := int(plane.special.get("para_count", spec.count))
	var start_x := clampf(goal.x - span, 16, world.map_size - 2 * span - 16)
	var end_x := float(world.map_size) if dir == 1 else 0.0
	plane.position.x = move_toward(plane.position.x,end_x,plane.move_speed*delta)
	if world.actor_visible_to("ally",plane): Ra2Sfx.start_attached_loop(plane,"CargoEngine","para_engine_audio","PDPlaneMoveLoop")
	var engine = plane.get_node_or_null("CargoEngine")
	if engine != null: engine.stream_paused = not world.actor_visible_to("ally",plane)
	while plane.special.para_left > 0:
		var index := count - int(plane.special.para_left)
		var lane := index if dir == 1 else count - 1 - index
		var x := start_x + (lane + 0.5) * 2.0 * span / count
		if (plane.position.x - x) * dir < 0: break
		plane.special.para_left -= 1
		var point := open_ground(world,Vector2(x,goal.y))
		if not point.is_finite(): point = open_ground(world,goal)
		if not point.is_finite(): continue
		var soldier = world.spawn_unit(str(plane.special.get("para_infantry",spec.infantry)),plane.side,point)
		if soldier == null: continue
		soldier.special.para_height = plane._visual_lift()
		soldier.special.para_age = 0.0
		soldier.special.para_collision = [soldier.collision_layer,soldier.collision_mask]
		soldier.collision_layer = 0
		soldier.collision_mask = 0
		soldier.remove_from_group("ground_units")
		soldier.add_to_group("air_units")
	if is_equal_approx(plane.position.x,end_x): AlliedAbilities.consume(plane)
	else: plane.queue_redraw()

static func descend(unit, delta: float) -> void:
	var world = unit._battle_world()
	if world.paused or world.ended or world.get_tree().paused: return
	unit.special.para_age += delta
	var fall_pixels_per_second: float = float(profile().fall_leptons) * BattleClock.RULE_TICKS_PER_SECOND * unit.flight.HEIGHT_PIXEL * DESCENT_SPEED_MULTIPLIER
	unit.special.para_height = move_toward(float(unit.special.para_height), 0.0, fall_pixels_per_second * delta)
	if unit.special.para_height <= 0:
		var landing := open_ground(world,unit.position,unit)
		unit.collision_layer = int(unit.special.para_collision[0])
		unit.collision_mask = int(unit.special.para_collision[1])
		unit.remove_from_group("air_units")
		unit.add_to_group("ground_units")
		for key in ["para_height","para_age","para_collision"]: unit.special.erase(key)
		if not landing.is_finite():
			unit.hp = 0
			unit._die()
			return
		unit.position = landing
	unit.queue_redraw()

static func draw_chute(unit) -> void:
	var spec := profile()
	var art := RA2Art.art(spec.chute)
	if art.is_empty(): return
	var frame := int(float(unit.special.para_age) * float(spec.fps))
	if frame > int(spec.loop_end):
		frame = int(spec.loop_start) + posmod(frame-int(spec.loop_start),int(spec.loop_end)-int(spec.loop_start)+1)
	var size := RA2Art.frame_size(art)
	var attach: Vector2 = Vector2.UP * (float(unit.special.para_height) + unit.radius)
	RA2Art.draw_sprite(unit,art,Rect2(attach-size*0.5,size),RA2Art.src_rect(art,frame))
