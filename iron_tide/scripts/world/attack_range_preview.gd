extends Node2D
## Presentation only: the same center-to-center distances used by weapon checks.
## Ground circles receive the camera projection once; strokes stay screen-sized.
const SEGMENTS := 128
const INDIVIDUAL_LIMIT := 12
const READY := Color(0.32, 0.88, 1.0, 0.80)
const INACTIVE := Color(0.65, 0.69, 0.73, 0.62)
const DEPLOY := Color(1.0, 0.84, 0.30, 0.95)
const BLIND := Color(1.0, 0.65, 0.27, 0.85)

static func ranges(world) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world.ended or world.armed_build != "" or world.cast_slot >= 0 or world.hover_ability >= 0:
		return result
	var actors: Array = world.selected_units.duplicate()
	if is_instance_valid(world.selected_building):
		actors.append(world.selected_building)
	var summarized := actors.size() > INDIVIDUAL_LIMIT
	var represented := {}
	for actor in actors:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.hp <= 0.0 or actor.side != "ally":
			continue
		var radius: float = actor.attack_range
		var minimum := 0.0
		var active := true
		if actor is Unit:
			if actor.embarked_in != null or actor.is_ordinary_harvester() or actor._active_weapon().is_empty():
				continue
			if actor.unit_id == "DRED": radius = OpenTopped.command_range(actor,actor.attack_target)
			minimum = actor.min_range
			active = actor.fire_stance != "none" and not actor.repairing
		elif actor is Building:
			active = actor.is_operational()
			if actor.data.has("garrison_weapons"):
				var garrison = preload("res://scripts/units/civilian_orders.gd")
				radius = garrison.bunker_range(actor)
				active = active and garrison.has_gunner(actor)
			elif actor.weapon.is_empty():
				continue
			else:
				minimum = float(actor.weapon.get("min_range", 0.0))
		else:
			continue
		if radius <= 0.0:
			continue
		if summarized and actor is Unit:
			# Keep an actual shooter's center for each distinct weapon reach and stance.
			var key := [actor.unit_id, radius, minimum, active]
			if represented.has(key): continue
			represented[key] = true
		result.append({"center": actor.global_position + (actor.bridge_contact_offset() if actor is Unit else Vector2.ZERO), "radius": radius,
			"minimum": maxf(0.0, minimum), "active": active})
	# Use the displayed cursor so UI, modifiers and double-click suppression all agree.
	if world.selected_units.size() == 1 and world.command_mode.is_empty() and is_instance_valid(world.command_cursor) and world.command_cursor.state in ["deploy", "deploy_infantry"]:
		var unit = world.selected_units[0]
		if AlliedAbilities.alive(unit) and not unit.is_deployed():
			var weapon: Dictionary = unit.deployed_weapon()
			if float(weapon.get("range", 0.0)) > 0.0:
				result.append({"center": unit.global_position + unit.bridge_contact_offset(), "radius": weapon.range, "minimum": weapon.get("min_range", 0.0), "active": true, "deploy_preview": true})
	return result

static func dashed_ring(canvas: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(0, SEGMENTS, 4):
		canvas.draw_polyline(PackedVector2Array([points[i], points[i + 1], points[i + 2]]), color, width, true)

static func circle(center: Vector2, radius: float, transform: Transform2D) -> PackedVector2Array:
	var ring := Transform2D(transform.x * radius, transform.y * radius, transform * center)
	var points := ring * Iso.unit_circle(SEGMENTS)
	points.append(points[0])
	return points

# The ring follows its owner as a canvas item. Moving the camera or the unit
# changes only its transform; the 128-segment strokes stay in the render list.
var _radius := 0.0
var _minimum := 0.0
var _active := true
var _deploy := false
var _multiple := false
var _basis := Transform2D.IDENTITY

func sync(item: Dictionary, multiple: bool, basis: Transform2D) -> void:
	global_position = item.center
	var deploy: bool = item.get("deploy_preview", false)
	if _radius == item.radius and _minimum == item.minimum and _active == item.active and _deploy == deploy and _multiple == multiple and _basis.is_equal_approx(basis):
		return
	_radius = item.radius
	_minimum = item.minimum
	_active = item.active
	_deploy = deploy
	_multiple = multiple
	_basis = basis
	queue_redraw()

func _draw() -> void:
	draw_set_transform_matrix(_basis.affine_inverse())
	var outer := circle(Vector2.ZERO, _radius, _basis)
	var color := READY if _active else INACTIVE
	if _deploy:
		dashed_ring(self, outer, DEPLOY, 2.5)
	else:
		if _multiple: color.a *= 0.65
		draw_polyline(outer, Color(0.015, 0.035, 0.045, color.a * 0.55), 3.5, true)
		draw_polyline(outer, color, 1.5, true)
	if _minimum > 0.0:
		dashed_ring(self, circle(Vector2.ZERO, _minimum, _basis), BLIND if _deploy or _active else INACTIVE, 1.5)
