extends RefCounted
## Own selected orders only: intention lines, not a disclosure of hidden navigation cells.
const MOVE := Color(0.65, 0.81, 0.25, 0.9)
const ATTACK_MOVE := Color(1.0, 0.65, 0.25, 0.9)

static func routes(world) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world.ended: return result
	for unit in world.selected_units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit._dead or unit.hp <= 0.0:
			continue
		if unit.side != "ally" or unit.embarked_in != null:
			continue
		var points := PackedVector2Array([unit.global_position])
		if unit.attack_ordered:
			if unit.order_queue.is_empty() or not AlliedAbilities.alive(unit.attack_target): continue
			if not unit.attack_target is ForceFirePoint and not world.actor_visible_to("ally", unit.attack_target): continue
			points.append(unit.attack_target.global_position)
		elif unit.has_move_order: points.append(unit.move_target)
		else: continue
		for order in unit.order_queue:
			if order is Vector2: points.append(order)
			elif order is Dictionary:
				if order.has("position"): points.append(order.position)
				else:
					var target = order.get("target")
					if AlliedAbilities.alive(target) and (target is ForceFirePoint or world.actor_visible_to("ally", target)):
						points.append(target.global_position)
		result.append({"points": points, "attack_move": unit.attack_move or unit.attack_ordered})
	return result

# Seven screen pixels of ink and seven of space. One textured quad represents
# the entire segment regardless of its length or the number of dashes.
static var _dash_tiles: Dictionary = {}
static func _dash_tile(color: Color) -> Texture2D:
	if not _dash_tiles.has(color):
		var image := Image.create_empty(14, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			var edge := Color(0.02, 0.04, 0.01, color.a * (0.4 if y in [0,3] else 0.8))
			if y in [1,2]: edge = edge.blend(Color(color, color.a * 0.75))
			image.fill_rect(Rect2i(0, y, 7, 1), edge)
		_dash_tiles[color] = ImageTexture.create_from_image(image)
	return _dash_tiles[color]

static func paint(canvas: Node2D, items: Array[Dictionary]) -> void:
	if items.is_empty(): return
	var projection := canvas.get_global_transform_with_canvas() * canvas.global_transform.affine_inverse()
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	for item in items:
		var color := ATTACK_MOVE if bool(item.attack_move) else MOVE
		if items.size() > 8: color.a *= 0.65
		var points: PackedVector2Array = item.points
		for i in range(1, points.size()):
			var from := projection * points[i - 1]
			var to := projection * points[i]
			if from.distance_squared_to(to) < 1.0: continue
			var normal := from.direction_to(to).orthogonal() * 2.0
			var uv_end := from.distance_to(to) / 14.0
			canvas.draw_primitive(PackedVector2Array([from-normal,to-normal,to+normal,from+normal]),
				PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO,Vector2(uv_end,0),Vector2(uv_end,1),Vector2.DOWN]), _dash_tile(color))
			var diamond := PackedVector2Array([to + Vector2(0, -5), to + Vector2(5, 0), to + Vector2(0, 5), to + Vector2(-5, 0), to + Vector2(0, -5)])
			canvas.draw_polyline(diamond, Color(0.02, 0.04, 0.01, color.a * 0.8), 3.0, true)
			canvas.draw_polyline(diamond, color, 1.5, true)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
