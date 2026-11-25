class_name Ra3Wreck
extends Node2D
## Native COL geometry; SDK lifetime/sink parameters, cosmetic Godot motion.
const ROOT := "res://assets/ra3/mirage/native/"
const MAX_WRECKS := 24
const GRAVITY := 24.0 # Cosmetic Godot units/s², not a recovered SAGE constant.
const GROUND_DRAG := 4.0 # Cosmetic exponential damping, not native ContactTag friction.
static var dynamics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra3/wreck_dynamics.json")).profiles
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "wreck.json"))
static var meshes: Array[ArrayMesh] = []
static var expansion_meshes: Dictionary = {}
var model_source: Dictionary = source
var model_meshes: Array = []
var expansion_folder := ""
var dynamics_key := "mirage"
var death_age := 4.5
var motion_rng := RandomNumberGenerator.new()
var world
var viewport: SubViewport
var root: Node3D
var camera: Camera3D
var falling_ref: WeakRef
var falling_offset := Vector2.ZERO
var age := 0.0
var heading_angle := 0.0
var parts: Array[Dictionary] = []
var rect := Rect2(-64, -89, 128, 128)

static func spawn(unit) -> Ra3Wreck:
	if (unit.unit_id != Ra3Mirage.ID and not Ra3Expansion.handles(unit) and not unit.data.has("soviet_ra3")) or DisplayServer.get_name() == "headless": return null
	var battle = unit._battle_world()
	if battle == null: return null
	return spawn_from(battle,unit.unit_id,unit.global_position,unit.hull_angle,unit.velocity)

static func spawn_from(battle, unit_id: String, point: Vector2, heading: float, velocity: Vector2, falling = null) -> Ra3Wreck:
	if DisplayServer.get_name()=="headless":return null
	var live: Array[Node] = battle.get_tree().get_nodes_in_group("ra3_wrecks").filter(func(n): return not n.is_queued_for_deletion() and battle.is_ancestor_of(n))
	if live.size() >= MAX_WRECKS: live[0].queue_free()
	var wreck := Ra3Wreck.new()
	wreck.model_meshes = meshes
	if unit_id in [Ra3Expansion.FUTURE,Ra3Expansion.HARBINGER] or unit_id=="R3REAPERTURRET" or GameData.get_unit(unit_id).has("soviet_ra3"):
		wreck.dynamics_key = "future" if unit_id == "R3FUTURE" else "harbinger"
		wreck.expansion_folder = "res://assets/ra3/expansion/" + ("future/" if unit_id == "R3FUTURE" else "harbinger/")
		if unit_id=="R3REAPERTURRET" or GameData.get_unit(unit_id).has("soviet_ra3"):wreck.expansion_folder="res://assets/ra3/soviet/"+unit_id+"/"
		wreck.model_source = JSON.parse_string(FileAccess.get_file_as_string(wreck.expansion_folder + "wreck.json"))
		if not expansion_meshes.has(unit_id): expansion_meshes[unit_id] = []
		wreck.model_meshes = expansion_meshes[unit_id]
	wreck.world = battle
	wreck.position = point
	if falling != null:wreck.falling_ref=weakref(falling)
	# Keep ownership local to the battle; never add a combatant/obstacle.
	battle.add_child(wreck)
	wreck.add_to_group("ra3_wrecks")
	wreck._build(heading, velocity)
	return wreck

static func clear(battle: Node) -> void:
	for node in battle.get_tree().get_nodes_in_group("ra3_wrecks"):
		if battle.is_ancestor_of(node): node.free()
	for node in battle.get_tree().get_nodes_in_group("ra3_audio_timers"):
		if battle.is_ancestor_of(node): node.free()

func _build(heading: float, velocity: Vector2) -> void:
	# Cosmetic randomness must not advance the combat/global RNG.
	motion_rng.randomize()
	var profile: Dictionary = model_source.get("profile",dynamics[dynamics_key])
	death_age = motion_rng.randf_range(float(profile.min_lifetime), float(profile.max_lifetime))
	viewport = SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var space := Node3D.new()
	viewport.add_child(space)
	root = Node3D.new()
	space.add_child(root)
	heading_angle = heading
	root.rotation.y = Iso.eff_angle() - heading
	camera = Camera3D.new()
	space.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 170.666667
	camera.position = Vector3(0, 58, 86.60254)
	camera.rotation_degrees.x = -30
	# Same pixel/world scale and ground anchor as the living 96px model.
	# Larger capture area for random trajectories, unchanged pixel/world scale.
	rect.size = Vector2(256, 256)
	rect.position = -Vector2(128, 128 + 8 * sqrt(0.75) * 1.5) + Vector2(0, 19 * 0.35)
	preload("res://scripts/units/ra3_lighting.gd").install(space)
	var bodies: Dictionary = {}
	for i in model_source.pieces.size():
		var piece: Dictionary = model_source.pieces[i]
		if model_meshes.size() <= i: model_meshes.append(make_mesh(piece))
		if not bodies.has(piece.name):
			var body := Node3D.new()
			body.position = Ra3BoneAnimation.vector(piece.center)
			root.add_child(body)
			bodies[piece.name] = body
			var inherited := root.basis.inverse() * Vector3(velocity.x, 0, -velocity.y) * 0.05
			var motion := sample_motion(profile, piece, inherited, motion_rng)
			motion.node = body
			motion.bounds = model_meshes[i].get_aabb()
			parts.append(motion)
		else:
			for part: Dictionary in parts:
				if part.node == bodies[piece.name]:
					part.bounds = part.bounds.merge(model_meshes[i].get_aabb())
		var mesh := MeshInstance3D.new()
		mesh.mesh = model_meshes[i]
		var material := Ra3UnitModel._material(bool(piece.treads))
		if not piece.treads: material.set_shader_parameter("diffuse_map", load(ROOT + "burnt.png"))
		if piece.has("material"):
			material.set_shader_parameter("diffuse_map",load(expansion_folder+(str(piece.material.get("DiffuseTexture",piece.material.get("Texture_0","burnt.png"))) if piece.treads else "burnt.png")))
			for channel in ["NormalMap","SpecMap"]:
				if piece.material.has(channel):material.set_shader_parameter("normal_map" if channel=="NormalMap" else "surface_map",load(expansion_folder+str(piece.material[channel])))
		elif not expansion_folder.is_empty():
			var stem := "AUTreads" if piece.treads else ("AUFutureTank" if "future" in expansion_folder else "AUGunship")
			material.set_shader_parameter("diffuse_map", load(expansion_folder + (stem + ".png" if piece.treads else "burnt.png")))
			material.set_shader_parameter("normal_map", load(expansion_folder + stem + "_NRM.png"))
			material.set_shader_parameter("surface_map", load(expansion_folder + stem + "_SPM.png"))
		material.set_shader_parameter("house_color", Color("32363b"))
		mesh.material_override = material
		bodies[piece.name].add_child(mesh)
	_process(0)

static func random_direction(rng: RandomNumberGenerator) -> Vector3:
	var y := rng.randf_range(-1.0, 1.0)
	var angle := rng.randf_range(0.0, TAU)
	var radius := sqrt(maxf(0.0, 1.0 - y * y))
	return Vector3(radius * cos(angle), y, radius * sin(angle))

static func sample_motion(profile: Dictionary, piece: Dictionary, inherited: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var body: Dictionary = profile.bodies[String(piece.name).to_upper()]
	var start := Ra3BoneAnimation.vector(piece.center)
	var radial_offset := Vector3(start.x, 0, start.z)
	# SDK: outward Explodiness + independent random FlingPerturbation per bone,
	# and random angular momentum from Spinniness. Conversion below is a bounded
	# Godot cosmetic adapter, not SAGE's impulse/inertia or OCL velocity solver.
	var weight := clampf(800.0 / float(body.mass), 0.5, 1.0)
	# Preserve model-scale radial separation. The old normalized direction plus
	# attenuations moved 30-unit pieces only 3-7 units: still assembled.
	# This positional expansion is an explicit Godot adapter, not recovered CPU.
	var perturb := random_direction(rng) * float(profile.fling_perturbation)
	var fling := radial_offset * float(profile.explodiness) * 0.5 + perturb
	fling.y = 9.0 + absf(perturb.y)
	var velocity := Vector3(fling.x * weight, fling.y, fling.z * weight) + inherited
	var spin := random_direction(rng) * float(body.spinniness) * weight * 0.2
	var flight := (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * GRAVITY * maxf(0.0, start.y - 0.2))) / GRAVITY
	return {"name":piece.name, "start":start, "velocity":velocity, "spin":spin, "flight_time":flight}

static func make_mesh(row: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in range(0, row.vertices.size(), 3):
		vertices.append(Vector3(row.vertices[i], row.vertices[i+1], row.vertices[i+2]))
		normals.append(Vector3(row.normals[i], row.normals[i+1], row.normals[i+2]).normalized())
	for i in range(0, row.uv.size(), 2): uv.append(Vector2(row.uv[i], row.uv[i+1]))
	var indices := PackedInt32Array()
	for i in range(0, row.indices.size(), 3): indices.append_array([int(row.indices[i]), int(row.indices[i+2]), int(row.indices[i+1])])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_tangents()
	return surface.commit()

func opacity() -> float:
	return 1.0 - clampf((age - float(model_source.draw_delay)) / float(model_source.fade_seconds), 0, 1)

func _process(delta: float) -> void:
	if falling_ref != null:
		var shot=falling_ref.get_ref()
		if is_instance_valid(shot): position=shot.position
		if is_instance_valid(shot) and not shot.is_queued_for_deletion():
			position=shot.position
			var state: Dictionary=shot.splinters
			var altitude: float=preload("res://scripts/units/ra3_gunship_crash.gd").altitude(state)
			falling_offset=Vector2(0,-altitude*sqrt(0.75))
			root.rotation=Vector3(deg_to_rad(state.spin.x)*float(state.age),Iso.eff_angle()-heading_angle,deg_to_rad(state.spin.y)*float(state.age))
			for part in parts:part.node.position=part.start;part.node.rotation=Vector3.ZERO
			visible=world.position_visible_to("ally",position)
			z_index=DepthLayers.entity_z(position,world.map_size)+1
			viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED
			queue_redraw();return
		falling_ref=null;falling_offset=Vector2.ZERO;age=0.0;root.rotation=Vector3.ZERO
	age += delta
	root.rotation.y = Iso.eff_angle() - heading_angle
	if age >= float(model_source.draw_delay) + float(model_source.fade_seconds):
		queue_free()
		return
	visible = is_instance_valid(world) and world.position_visible_to("ally", global_position)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED
	var half_size := 128.0
	for part: Dictionary in parts:
		var body: Node3D = part.node
		var t := minf(age, float(part.flight_time))
		var grounded_time := maxf(0.0, age-float(part.flight_time))
		var motion_time := t+(1.0-exp(-GROUND_DRAG*grounded_time))/GROUND_DRAG
		body.rotation = part.spin * motion_time
		body.position = part.start + part.velocity * motion_time
		body.position.y = part.start.y + part.velocity.y*t - 0.5*GRAVITY*t*t
		# Conservative rotated mesh bounds keep settled pieces above ground.
		var rotated_bounds: AABB = Transform3D(body.basis, Vector3.ZERO) * part.bounds
		body.position.y = maxf(0.2 - rotated_bounds.position.y, body.position.y)
		body.position.y -= maxf(0, age - death_age - float(model_source.sink_delay)) * float(model_source.sink_rate)
		# Fit the dispersed geometry without changing its pixel/world scale or
		# silently clipping parts that have left the original vehicle rectangle.
		for corner in 8:
			var p: Vector3 = root.transform * (body.transform * part.bounds.get_endpoint(corner))
			half_size=maxf(half_size,maxf(absf(p.x*1.5),absf((p.z*0.5-(p.y-8.0)*sqrt(0.75))*1.5))+12.0)
	rect.size=Vector2.ONE*ceilf(half_size*2.0)
	rect.position=-rect.size*0.5-Vector2(0,8*sqrt(0.75)*1.5)+Vector2(0,19*0.35)
	camera.size=rect.size.y/1.5
	var capture_size:=clampi(ceili(rect.size.y*2.0/128.0)*128,768,1536)
	# Grow in coarse steps and never shrink during this wreck's short lifetime.
	if capture_size>viewport.size.y:viewport.size=Vector2i(capture_size,capture_size)
	z_index = DepthLayers.entity_z(global_position, world.map_size)
	queue_redraw()

func _draw() -> void:
	if viewport == null: return
	Iso.begin(self)
	draw_texture_rect(viewport.get_texture(), Rect2(rect.position+falling_offset,rect.size), false, Color(1,1,1,opacity()))
