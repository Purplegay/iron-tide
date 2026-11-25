class_name Ra3UnitModel
extends Node
## Original RA3 TruckDraw: one chassis transform, no independent turret.
## The atlas is only the headless fallback.
const ROOT := "res://assets/ra3/mirage/"
const SIZE := Vector2(96, 96)
const OBJECT_SHADER = preload("res://shaders/ra3_object_surface.gdshader")
const ENV_DEFAULT = preload("res://assets/ra3/EVDefault.dds")
const RESOLUTION := Vector2i(384, 384)
static var _meshes: Array[ArrayMesh] = []
static var _parts: Array = []
static var _materials: Dictionary = {}
# Visual crossfade only; concealment, targeting and reveal timers stay in Ra3Mirage.
# SDK gives OpacityTarget=0.5, but not the model transition time.

var disguise_blend := 0.0
var actor: Unit
var viewport: SubViewport
var prop_viewport: SubViewport
var prop_mesh: MeshInstance3D
var _prop_accum := 0.0
var camera: Camera3D
var hull: Node3D
var animation := Ra3BoneAnimation.new()
var _animation_delta := 0.0
var muzzle_local := Vector3.ZERO
var draw_rect := Rect2()
var hull_bounds := AABB()
var _last_pose := Vector3(INF, INF, INF)
var _last_color := Color.TRANSPARENT
var _image: Image
var _image_frame := -1
var _render_requested := false
var _suspended := true
var _treads := 0.0
var _tread_material: ShaderMaterial
var _body_material: ShaderMaterial
var damage_visual
# Layer 1 is the composite, layer 2 the ground shadow, layer 3 the physical hull.
const BODY_MASK_LAYER:=4
var body_mask:SubViewport
var surface_lighting: Node3D
var ground_shadow
var native_extras
var disguise_id := "Tree01"

static func attach(unit: Unit) -> Ra3UnitModel:
	if DisplayServer.get_name() == "headless" or unit.unit_id != Ra3Mirage.ID: return null
	var model := Ra3UnitModel.new()
	model.actor = unit
	unit.add_child(model)
	model._build()
	return model

static func _load_meshes() -> void:
	if not _meshes.is_empty(): return
	_parts = Ra3BoneAnimation.source.meshes
	for part: Dictionary in _parts:
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in range(0, part.vertices.size(), 3):
			vertices.append(Vector3(part.vertices[i], part.vertices[i+1], part.vertices[i+2]))
			normals.append(Vector3(part.normals[i], part.normals[i+1], part.normals[i+2]).normalized())
		for i in range(0, part.uv.size(), 2): uv.append(Vector2(part.uv[i], part.uv[i+1]))
		var indices := PackedInt32Array()
		for i in range(0, part.indices.size(), 3):
			indices.append_array([int(part.indices[i]), int(part.indices[i+2]), int(part.indices[i+1])])
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = preload("res://scripts/units/unit_cosmetics.gd").weapon_mask(part,Ra3BoneAnimation.source.bones)
		arrays[Mesh.ARRAY_INDEX] = indices
		arrays[Mesh.ARRAY_BONES] = PackedInt32Array(part.bones)
		arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array(part.weights)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface := SurfaceTool.new()
		surface.create_from(mesh, 0)
		surface.generate_tangents()
		_meshes.append(surface.commit())

static func setup_object_surface(material: ShaderMaterial, alpha_test: bool) -> void:
	material.shader = OBJECT_SHADER
	material.set_shader_parameter("environment_map", ENV_DEFAULT)
	material.set_shader_parameter("occluded_light", preload("res://scripts/units/ra3_lighting.gd").source.occluded_luminance_scale)
	material.set_shader_parameter("alpha_test", alpha_test)
	var directions := PackedVector3Array()
	var colors := PackedVector3Array()
	var ambient := Vector3.ZERO
	for row: Dictionary in preload("res://scripts/units/ra3_lighting.gd").source.lights:
		var ray: Array = row.LightPos
		directions.append(-Vector3(ray[0], ray[2], -ray[1]).normalized())
		colors.append(Vector3(row.Diffuse[0], row.Diffuse[1], row.Diffuse[2]))
		ambient += Vector3(row.Ambient[0], row.Ambient[1], row.Ambient[2])
	material.set_shader_parameter("ambient_light", ambient)
	material.set_shader_parameter("light_directions", directions)
	material.set_shader_parameter("light_colors", colors)
	material.set_shader_parameter("world_to_map", Basis(Vector3.UP, -Iso.eff_angle()))

static func _material(treads: bool) -> ShaderMaterial:
	var key := "treads" if treads else "body"
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		setup_object_surface(material, true) # Both retail Mirage mesh materials enable alpha testing.
		var stem := "AUAntiVehicleVehicleTech3" + ("_Treads" if treads else "")
		for pair in [["diffuse_map", ""], ["normal_map", "_NRM"], ["surface_map", "_SPM"]]:
			var texture: Texture2D = load(ROOT + stem + pair[1] + ".png")
			var image := texture.get_image()
			if image.is_compressed(): image.decompress()
			image.generate_mipmaps()
			material.set_shader_parameter(pair[0], ImageTexture.create_from_image(image))
		material.set_shader_parameter("is_tread", treads)
		_materials[key] = material
	return _materials[key].duplicate()

func _build() -> void:
	_load_meshes()
	viewport = SubViewport.new()
	viewport.size = RESOLUTION
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var world := Node3D.new(); viewport.add_child(world)
	hull = Node3D.new(); world.add_child(hull)
	animation.build(hull)
	native_extras=load("res://scripts/units/ra3_mirage_extras.gd").new();hull.add_child(native_extras);native_extras.build(self)
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "rig.json"))
	var point: Array = rig.muzzle.position
	muzzle_local = Vector3(point[0], point[1], point[2])
	_body_material = _material(false)
	_tread_material = _material(true)
	for i in _meshes.size():
		var instance := MeshInstance3D.new()
		instance.mesh = _meshes[i]
		instance.layers |= BODY_MASK_LAYER
		instance.material_override = _tread_material if "TREAD" in str(_parts[i].name) else _body_material
		hull.add_child(instance)
		include_body_mesh(instance)
		instance.skin = animation.skin
		instance.skeleton = instance.get_path_to(animation.skeleton)
	surface_lighting = preload("res://scripts/units/ra3_lighting.gd").install(world)
	camera = Camera3D.new(); world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 64.0
	camera.position = Vector3(0, 58, 86.60254)
	camera.rotation_degrees.x = -30.0
	draw_rect = Rect2(-project(Vector3.ZERO) + Vector2(0, actor.radius * 0.35), SIZE)
	_build_native_disguise()
	ground_shadow = load("res://scripts/units/ra3_ground_shadow.gd").attach(self)
	damage_visual = load("res://scripts/units/ra3_mirage_damage_visual.gd").new()
	actor.add_child(damage_visual)
	damage_visual.setup(self)
	sync_pose(true)

func cosmetic_skeleton() -> Skeleton3D:
	return animation.skeleton

func project(point: Vector3) -> Vector2:
	return SIZE * 0.5 + Vector2(point.x, point.z * 0.5 - (point.y - 8.0) * sqrt(0.75)) * SIZE.y / camera.size

func sync_pose(force := false) -> void:
	if damage_visual != null and damage_visual.sync_skin(): force = true
	var pose := Vector3(actor.hull_angle, 0.0, Iso.eff_angle())
	if force or not pose.is_equal_approx(_last_pose) or _last_color != actor._col:
		hull.rotation.y = pose.z - pose.x
		# Team mask is the source SPM blue channel; metal stays neutral.
		_body_material.set_shader_parameter("house_color", actor._col)
		_tread_material.set_shader_parameter("house_color", actor._col)
		if _last_color != actor._col:
			var top:=hull.get_node_or_null("CosmeticMount/top")
			if top!=null:
				for ornament in top.get_children():
					if ornament.has_method("sync_house_color"):ornament.sync_house_color()
		if force or not is_equal_approx(pose.z, _last_pose.z):
			var to_map := Basis(Vector3.UP, -pose.z)
			_body_material.set_shader_parameter("world_to_map", to_map)
			_tread_material.set_shader_parameter("world_to_map", to_map)
		if prop_mesh != null: prop_mesh.rotation.y=pose.z
		_last_pose = pose
		_last_color = actor._col
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_render_requested = true

# Render in screen pixels while keeping projection, sockets and world hitboxes in world units.
func update_model_resolution(logical_width: float, on_screen: bool) -> void:
	var pixels := RESOLUTION.x
	if on_screen:
		var density := preload("res://scripts/units/ra3_fx_resolution.gd").pixel_density(actor)
		pixels = clampi(ceili(logical_width * density / 128.0) * 128, RESOLUTION.x, 1024)
	var target_size := Vector2i(pixels, pixels)
	if viewport.size != target_size:
		viewport.size = target_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_image_frame = -1
		_render_requested = true
		if body_mask != null: body_mask.size = target_size
	if prop_viewport != null:
		var prop_size := target_size if on_screen and disguise_blend > 0.0 else Vector2i(192, 192)
		if prop_viewport.size != prop_size:
			prop_viewport.size = prop_size
			prop_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func advance_disguise(delta: float) -> void:
	var chosen: String=preload("res://scripts/units/ra3_mirage_extras.gd").disguise_id(actor)
	if chosen!=disguise_id and prop_mesh!=null:
		disguise_id=chosen
		var part: Dictionary=preload("res://scripts/units/ra3_mirage_extras.gd").data.props[chosen]
		prop_mesh.mesh=preload("res://scripts/units/ra3_mirage_extras.gd").mesh(part)
		prop_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	var previous := disguise_blend
	disguise_blend = move_toward(disguise_blend,1.0 if Ra3Mirage.disguised(actor) else 0.0,maxf(0.0,delta)/float(Ra3WeaponFx.sdk.adapter.model_crossfade_seconds))
	if not is_equal_approx(previous,disguise_blend): actor.queue_redraw()

func disguise_weight() -> float:
	return smoothstep(0.0,1.0,disguise_blend)

func body_opacity() -> float:
	return lerpf(1.0,float(Ra3WeaponFx.sdk.owner_disguise_opacity) if actor.side == "ally" else 0.0,disguise_weight())

func _process(delta: float) -> void:
	if is_instance_valid(actor): advance_disguise(delta)
	if prop_viewport != null:
		prop_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		_prop_accum+=delta
		if is_instance_valid(actor) and actor.is_visible_in_tree() and disguise_blend>0.0 and _prop_accum>=0.1:
			prop_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			_prop_accum=0.0
	if not is_instance_valid(actor) or not actor.is_visible_in_tree() or actor.embarked_in != null:
		update_model_resolution(SIZE.x, false)
		if damage_visual != null: damage_visual.clear_particles()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_suspended = true
		return
	var screen_point := actor.get_global_transform_with_canvas().origin
	if not actor.get_viewport_rect().grow(160).has_point(screen_point):
		update_model_resolution(SIZE.x, false)
		if damage_visual != null: damage_visual.clear_particles()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_suspended = true
		return
	update_model_resolution(SIZE.x, true)
	sync_pose(_suspended)
	_suspended = false
	if not get_tree().paused and not AlliedAbilities.frozen(actor):
		_animation_delta += delta
		if _animation_delta >= 1.0 / 30.0:
			animation.advance(_animation_delta, actor.velocity.length() > 0.1,Ra3Mirage.field_active(actor),actor.selected)
			native_extras.tick(_animation_delta)
			_animation_delta = 0.0
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			_render_requested = true
	if actor.velocity.length() > 0.1 and not get_tree().paused:
		_treads = fmod(_treads + delta * actor.velocity.length() * 0.004, 1.0)
		_tread_material.set_shader_parameter("tread_offset", _treads)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _render_requested:
		actor.queue_redraw()
		_render_requested = false

func release_body_mask() -> void:
	if body_mask!=null:
		body_mask.queue_free()
		body_mask=null

func capture_body_outline(alpha:float) -> void:
	var outline=preload("res://scripts/ui/unit_selection_outline.gd")
	if not outline.eligible(actor) or alpha<=0.01:return
	if body_mask==null:
		body_mask=SubViewport.new()
		body_mask.size=viewport.size
		body_mask.transparent_bg=true
		body_mask.msaa_3d=viewport.msaa_3d
		body_mask.world_3d=viewport.find_world_3d()
		add_child(body_mask)
		var mask_camera:=Camera3D.new()
		mask_camera.projection=camera.projection
		mask_camera.size=camera.size
		mask_camera.transform=camera.transform
		mask_camera.cull_mask=BODY_MASK_LAYER
		body_mask.add_child(mask_camera)
	body_mask.render_target_update_mode=SubViewport.UPDATE_ONCE
	outline.capture(actor,body_mask.get_texture(),draw_rect,Rect2(Vector2.ZERO,body_mask.size),alpha)

func draw_on() -> void:
	sync_pose(_suspended)
	_suspended = false
	var cloak_alpha := Ra3Mirage.CloakVisual.opacity(actor)
	capture_body_outline(body_opacity() * cloak_alpha)
	if actor.has_meta("time_fracture"):
		preload("res://scripts/core/yr_signature_fx.gd").ghosts(actor,viewport.get_texture(),draw_rect,Rect2(Vector2.ZERO,viewport.size),actor.get_meta("time_fracture"))
	actor.draw_texture_rect(viewport.get_texture(), draw_rect, false,Color(1,1,1,body_opacity() * cloak_alpha))
	if disguise_blend > 0.0 and prop_viewport != null:
		preload("res://scripts/ui/unit_selection_outline.gd").capture(actor, prop_viewport.get_texture(), draw_rect, Rect2(Vector2.ZERO, prop_viewport.size), disguise_weight() * cloak_alpha)
		actor.draw_texture_rect(prop_viewport.get_texture(),draw_rect,false,Color(1,1,1,disguise_weight() * cloak_alpha))

func muzzle() -> Vector2:
	sync_pose()
	var point := hull.transform * animation.muzzle()
	return actor.global_position + RA2Art.art_dir(draw_rect.position + project(point))

func include_body_mesh(instance: MeshInstance3D) -> void:
	var box: AABB = instance.transform * instance.get_aabb()
	hull_bounds = hull_bounds.merge(box) if hull_bounds.size != Vector3.ZERO else box

func projected_body_bounds() -> Rect2:
	var bounds := Rect2(draw_rect.position + project(hull.transform * hull_bounds.get_endpoint(0)), Vector2.ZERO)
	for i in range(1, 8):
		bounds = bounds.expand(draw_rect.position + project(hull.transform * hull_bounds.get_endpoint(i)))
	if prop_mesh != null and prop_mesh.mesh != null and disguise_blend > 0.0:
		var prop_box := prop_mesh.get_aabb()
		for i in 8:
			bounds = bounds.expand(draw_rect.position + project(prop_mesh.global_transform * prop_box.get_endpoint(i)))
	return bounds.intersection(draw_rect)

func center() -> Vector2:
	return actor.global_position + RA2Art.art_dir(draw_rect.position + project(Vector3(0, 8, 0)))

func hits(world_point: Vector2) -> bool:
	var local := Iso.dir(world_point - actor.global_position)
	if not draw_rect.has_point(local): return false
	# Read back only for an actual pointer hit candidate, never per render frame.
	if _image_frame != Engine.get_process_frames():
		_image = viewport.get_texture().get_image()
		_image_frame = Engine.get_process_frames()
	if _image == null or _image.is_empty(): return world_point.distance_to(actor.global_position) < actor.radius
	var pixel := Vector2i((local - draw_rect.position) / SIZE * Vector2(_image.get_size()))
	return _image.get_pixelv(pixel).a > 0.15

func _build_native_disguise() -> void:
	prop_viewport=SubViewport.new(); prop_viewport.size=Vector2i(192,192)
	prop_viewport.transparent_bg=true; prop_viewport.own_world_3d=true
	prop_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; add_child(prop_viewport)
	prop_mesh=MeshInstance3D.new(); prop_mesh.mesh=Ra3MirageFx.mesh_for("disguise_tree")
	var material := ShaderMaterial.new(); material.shader=load("res://shaders/ra3_disguise_tree.gdshader")
	material.set_shader_parameter("diffuse_map",load("res://assets/ra3/mirage/uprising/AP_MirageDisguises01.png"))
	prop_mesh.material_override=material; prop_viewport.add_child(prop_mesh)
	var prop_camera := Camera3D.new(); prop_camera.projection=camera.projection; prop_camera.size=camera.size
	prop_camera.transform=camera.transform; prop_viewport.add_child(prop_camera)
	var prop_world := Node3D.new(); prop_viewport.add_child(prop_world)
	preload("res://scripts/units/ra3_lighting.gd").install(prop_world)
