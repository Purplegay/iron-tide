extends Node2D
class_name WaterLayer
## Each shore is anchored to the playable water rectangle. Rebuild on bridge
## repairs and save restoration. Wave movement is entirely in the material.

const WATER := preload("res://shaders/coastal_water.gdshader")
const BEACH_WIDTH := 34.0

var rects: Array = []:
	set(value):
		rects = value
		if is_node_ready():
			_rebuild()

func _ready() -> void:
	z_index = DepthLayers.WATER
	_rebuild()

func _rebuild() -> void:
	for old in get_children():
		remove_child(old)
		old.queue_free()
	if get_parent().has_method("map_layout") and preload("res://scripts/world/native_maps.gd").has(get_parent().map_layout()):return
	for bounds: Rect2 in rects:
		if not bounds.has_area():
			continue
		var surface := Polygon2D.new()
		var mat := ShaderMaterial.new()
		mat.shader = WATER
		mat.set_shader_parameter("half_size", bounds.size * 0.5)
		mat.set_shader_parameter("sand", load("res://assets/ra3/terrain/sand.png"))
		surface.material = mat
		surface.position = bounds.get_center()
		var extent := bounds.size * 0.5 + Vector2.ONE * BEACH_WIDTH
		surface.polygon = PackedVector2Array([-extent, Vector2(extent.x, -extent.y), extent, Vector2(-extent.x, extent.y)])
		add_child(surface)
