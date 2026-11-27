extends RefCounted
## Player presentation only. Keys are the last observed world positions, not actor IDs.
## This deliberately survives the removal and replacement of an unobserved actor.

class Silhouette extends Node2D:
	var pose: Array = []
	var radius := 0.0
	var tint := Color.WHITE
	var _textures: Dictionary = {}

	func _draw() -> void:
		Iso.begin(self)
		if pose.is_empty():
			var base := Vector2(0, radius * 0.35)
			Iso.box(self, base, radius * 1.5, radius * 1.5, radius * 0.85, tint.darkened(0.35), tint.lightened(0.2))
		for layer: Array in pose:
			var path: String = layer[0]
			if not _textures.has(path):
				_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
			var texture: Texture2D = _textures.get(path)
			if texture != null: draw_texture_rect_region(texture, layer[1], layer[2], layer[3])

var records: Dictionary = {}
var shown: Dictionary = {}
var _nodes: Dictionary = {}
var _view := Vector2.INF

func observe(building: Building) -> void:
	var point := building.global_position
	var paint := 0
	var skin := 0
	var hollywood := false
	var shader := building.material as ShaderMaterial
	if shader != null:
		paint = int(shader.get_shader_parameter("paint_mode"))
		skin = int(shader.get_shader_parameter("unit_skin"))
		hollywood = bool(shader.get_shader_parameter("hollywood_paint"))
	var radar := Color(0.65, 0.65, 0.6) if building.side == "neutral" else Color(1.0, 0.45, 0.4)
	if (not BattleRequest.skirmish and BattleRequest.mission_id == "yr_time_shift") or HouseColor.allied_first() or HouseColor.head_games() or HouseColor.hollywood_enemy(building.side):
		radar = building._col
	records[point] = {"pose": building.fog_pose(), "radius": building.radius, "color": building._col,
		"radar": radar, "paint": paint, "skin": skin, "hollywood": hollywood, "depth": building.z_index}

func forget(point: Vector2) -> void:
	records.erase(point)
	_hide(point)

func _hide(point: Vector2) -> void:
	shown.erase(point)
	if _nodes.has(point):
		_nodes[point].hide()
		_nodes[point].queue_free()
		_nodes.erase(point)

func restore(data: Dictionary) -> void:
	for point: Vector2 in _nodes.keys(): _hide(point)
	records = data.duplicate(true)

func publish(fog, observed: Dictionary) -> void:
	for point: Vector2 in records.keys():
		if observed.has(point):
			_hide(point)
		elif fog.is_visible_at("ally", point):
			forget(point)
		elif fog.is_explored_at("ally", point):
			if not _nodes.has(point): _show(fog, point, records[point])
		else:
			forget(point)
	sync_view()

func _show(fog, point: Vector2, row: Dictionary) -> void:
	var node := Silhouette.new()
	node.pose = row.pose
	node.radius = row.radius
	node.tint = row.color
	node.material = HouseColor.material_for(row.color, row.paint, row.skin, row.hollywood)
	node.z_as_relative = false
	node.z_index = row.depth
	fog.add_child(node)
	node.global_position = point
	_nodes[point] = node
	shown[point] = row

func sync_view() -> void:
	var view := Vector2(Iso.eff_angle(), Iso.K)
	if _view == view: return
	_view = view
	for node in _nodes.values(): node.queue_redraw()

## Saves contain only numeric values, colors and allowlisted texture paths.
static func valid(data) -> bool:
	if not data is Dictionary or data.size() > 20000: return false
	for point in data:
		var row = data[point]
		if not point is Vector2 or not point.is_finite() or not row is Dictionary: return false
		if not row.get("radius") is float or not is_finite(row.radius) or row.radius <= 0.0 or row.radius > 2000.0: return false
		if not valid_color(row.get("color")) or not valid_color(row.get("radar")) or not row.get("hollywood") is bool: return false
		if not row.get("depth") is int or row.depth < -4096 or row.depth > 4096: return false
		if not row.get("paint") is int or row.paint < 0 or row.paint >= HouseColor.PaintMode.size(): return false
		if not row.get("skin") is int or row.skin < 0 or row.skin > 32: return false
		if not row.get("pose") is Array or row.pose.size() > 64: return false
		for layer in row.pose:
			if not layer is Array or layer.size() != 4 or not layer[0] is String: return false
			var path: String = layer[0]
			if (not path.begins_with("res://assets/ra2/") and not path.begins_with("res://assets/maps/") and not path.begins_with("res://assets/ra3/")) or ".." in path or "\\" in path or not path.ends_with(".png"): return false
			if not layer[1] is Rect2 or not layer[1].is_finite() or not layer[2] is Rect2 or not layer[2].is_finite() or not valid_color(layer[3]): return false
	return true

static func valid_color(color) -> bool:
	return color is Color and Vector4(color.r, color.g, color.b, color.a).is_finite()
