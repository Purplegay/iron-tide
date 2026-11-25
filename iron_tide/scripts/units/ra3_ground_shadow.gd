extends Node2D
## Project original skinned triangles onto a plane; not a SAGE shadow-map solver.
const Lighting = preload("res://scripts/units/ra3_lighting.gd")
const CAPTURE_SCALE := 3.0
var model
var capture: SubViewport
var shadow_camera: Camera3D
var projection: ShaderMaterial
var silhouettes: Array[Dictionary] = []
var rect := Rect2()
var clock := 0.0
var building_clock := 0.0
var nearby: Array = []
var proxies: Array[MeshInstance3D] = []
static var heights: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/shadow_heights.json"))
# Conservative roof volumes for the 2D foundation art, in RA3 model units.
const LEVEL_HEIGHT := 12.0
const MODEL_SCALE := 1.5
const MAX_CASTERS := 4

static func attach(host) -> Node2D:
	var shadow = load("res://scripts/units/ra3_ground_shadow.gd").new()
	shadow.model = host
	host.actor.add_child(shadow)
	shadow.show_behind_parent = true
	shadow.build()
	return shadow

func build() -> void:
	capture = SubViewport.new()
	capture.size = Vector2i(384, 384)
	capture.transparent_bg = true
	# Models are built before the actor enters the tree. Share an explicit world
	# rather than querying Node3D's not-yet-entered or private viewport world.
	model.viewport.own_world_3d = false
	model.viewport.world_3d = World3D.new()
	capture.world_3d = model.viewport.world_3d
	capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	capture.msaa_3d = Viewport.MSAA_2X
	add_child(capture)
	shadow_camera = Camera3D.new()
	shadow_camera.cull_mask = 2
	shadow_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	shadow_camera.size = model.camera.size * CAPTURE_SCALE
	shadow_camera.transform = model.camera.transform
	capture.add_child(shadow_camera)
	# Main camera must not display the white shadow mask or include it in hit tests.
	model.camera.cull_mask = 1
	var sun: DirectionalLight3D = model.surface_lighting.lights[0]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 0.5
	projection = ShaderMaterial.new()
	projection.shader = load("res://shaders/ra3_ground_projection.gdshader")
	for child in model.hull.get_children():
		if not child is MeshInstance3D: continue
		var original := child as MeshInstance3D
		var mat = original.material_override
		if not mat is ShaderMaterial or mat.shader.resource_path not in ["res://shaders/ra3_vehicle.gdshader", "res://shaders/ra3_object_surface.gdshader"]: continue
		var copy := MeshInstance3D.new()
		copy.mesh = original.mesh; copy.skin = original.skin
		copy.layers = 2
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.material_override = projection
		model.hull.add_child(copy)
		copy.skeleton = copy.get_path_to(original.get_node(original.skeleton))
		silhouettes.append({"original": original, "copy": copy})
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/ra3_ground_shadow.gdshader")
	refresh()

func refresh() -> void:
	var actor = model.actor
	var alpha: float = Ra3Mirage.CloakVisual.opacity(actor)
	if actor.unit_id == Ra3Mirage.ID: alpha *= model.body_opacity()
	visible = actor.is_visible_in_tree() and actor.embarked_in == null and alpha > 0.001
	model.surface_lighting.lights[0].shadow_enabled = visible
	if not visible:
		capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_update_building_casters()
	for row: Dictionary in silhouettes:
		row.copy.visible = row.original.visible
		row.copy.transform = row.original.transform
	var ray := Lighting.sun_direction()
	projection.set_shader_parameter("light_ray", ray)
	# Existing visual lift is screen pixels. The mesh-to-screen scale is 1.5,
	# with camera pitch 30deg; ground position must not follow the lifted body.
	var lift: float = actor._visual_lift() if actor.is_air else 0.0
	lift+=float(actor.special.get("walker_height",0.0))
	var height := lift / (1.5 * sqrt(0.75))
	var offset := Vector2(ray.x, ray.z * 0.5) * (-height / ray.y) * 1.5
	var size: Vector2 = model.draw_rect.size * CAPTURE_SCALE
	rect = Rect2(model.draw_rect.position - (size - model.draw_rect.size) * 0.5 + Vector2(0, lift) + offset, size)
	material.set_shader_parameter("softness", 0.8 + minf(height / 35.0, 2.5))
	material.set_shader_parameter("opacity", 0.36 * alpha / (1.0 + height / 180.0))
	capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func _update_building_casters() -> void:
	var actor = model.actor
	var world = actor._battle_world()
	if not is_instance_valid(world): return
	var altitude: float = actor._visual_lift() / (MODEL_SCALE * sqrt(0.75)) if actor.is_air else 0.0
	if building_clock <= 0.0:
		building_clock = 0.2
		nearby.clear()
		for b in world.buildings:
			if not world.actor_alive(b) or b.under_construction or b._buildup_play >= 0.0 or not heights.has(b.building_id): continue
			if not world.actor_visible_to("ally", b): continue
			var limit: float = b.footprint_radius() + heights[b.building_id] * LEVEL_HEIGHT * MODEL_SCALE * 2.0 + 96.0
			if actor.position.distance_squared_to(b.position) <= limit * limit: nearby.append(b)
		nearby.sort_custom(func(a,b): return actor.position.distance_squared_to(a.position) < actor.position.distance_squared_to(b.position))
		if nearby.size() > MAX_CASTERS: nearby.resize(MAX_CASTERS)
	var used := 0
	for b in nearby:
		if not world.actor_alive(b) or not world.actor_visible_to("ally", b): continue
		var height := float(heights[b.building_id]) * LEVEL_HEIGHT
		if altitude > height + 5.0: continue
		if used == proxies.size():
			var proxy := MeshInstance3D.new()
			proxy.mesh = BoxMesh.new()
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			model.camera.get_parent().add_child(proxy)
			proxies.append(proxy)
		var node := proxies[used]
		used += 1
		var footprint: Rect2 = b.footprint_rect()
		var center: Vector2 = (b.position + footprint.get_center() - actor.position).rotated(-Iso.eff_angle()) / MODEL_SCALE
		node.rotation.y = Iso.eff_angle()
		node.scale = Vector3(footprint.size.x / MODEL_SCALE, height, footprint.size.y / MODEL_SCALE)
		node.position = Vector3(center.x, height * 0.5 - altitude, center.y)
		node.show()
	for i in range(used, proxies.size()): proxies[i].hide()

func _process(delta: float) -> void:
	if not is_instance_valid(model) or not is_instance_valid(model.actor):
		queue_free(); return
	building_clock -= delta
	clock += delta
	if not model.actor.get_viewport_rect().grow(250).has_point(model.actor.get_global_transform_with_canvas().origin):
		model.surface_lighting.lights[0].shadow_enabled = false
		capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if clock >= 1.0 / 30.0:
		clock = 0.0
		refresh()

func _draw() -> void:
	if capture == null: return
	Iso.begin(self)
	draw_texture_rect(capture.get_texture(), rect, false)
