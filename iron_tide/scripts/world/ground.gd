extends Node2D
class_name Ground
## Terrain appearance uses the same world coordinates as placement and navigation.

const TERRAIN := preload("res://shaders/coastal_ground.gdshader")
var native_id := ""
var broken_bridges: Array = []
var bridge_art = preload("res://scripts/world/native_bridge_art.gd").new()
var map_size := 2400.0
var grid_step := 80.0
var show_grid := false
var grid_alpha := 0.045
var _surface := Polygon2D.new()

func _ready() -> void:
	var surface_material := ShaderMaterial.new()
	surface_material.shader = TERRAIN
	for channel in ["grass", "soil", "gravel", "grass_normal", "soil_normal", "gravel_normal"]:
		surface_material.set_shader_parameter(channel, load("res://assets/ra3/terrain/%s.png" % channel))
	_surface.material = surface_material
	if not native_id.is_empty():
		_surface.material=null
		_surface.texture=load("res://assets/maps/yr/%s_terrain.png"%native_id)
		if not preload("res://scripts/world/native_maps.gd").data(native_id).bridges.is_empty():
			bridge_art.prepare(native_id)
	_surface.show_behind_parent = true
	add_child(_surface)
	setup(map_size)

func setup(size: float) -> void:
	map_size = size
	_surface.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size, 0), Vector2(size, size), Vector2(0, size)])
	if _surface.texture!=null:
		var extent:Vector2=_surface.texture.get_size()
		_surface.uv=PackedVector2Array([Vector2.ZERO,Vector2(extent.x,0),extent,Vector2(0,extent.y)])
	queue_redraw()

func set_broken_bridges(broken: Array) -> void:
	broken_bridges = broken.duplicate()
	bridge_art.rebuild(native_id, broken_bridges)
	queue_redraw()

func _draw() -> void:
	for patch: Dictionary in bridge_art.patches:
		draw_texture_rect(patch.texture, patch.rect, false)
	if show_grid:
		var k := 0.0
		while k <= map_size:
			draw_line(Vector2(k, 0), Vector2(k, map_size), Color(0.62, 0.82, 1.0, grid_alpha), 1.0)
			draw_line(Vector2(0, k), Vector2(map_size, k), Color(0.62, 0.82, 1.0, grid_alpha), 1.0)
			k += grid_step
	draw_rect(Rect2(0, 0, map_size, map_size), Color(0.35, 0.62, 0.92, 0.42), false, 4.0)
