extends SceneTree
var output := ""
var source := ""

func _initialize() -> void:
	call_deferred("render_atlas")

func render_atlas() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: --script render_fallback.gd -- <converted-source-directory> <output-directory>")
		quit(2); return
	source = args[0]; output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var model := Node3D.new()
	viewport.add_child(model)
	var parts: Array = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("geometry.json")))
	var nodes: Array = []
	for part: Dictionary in parts:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in range(0, part.vertices.size(), 3):
			vertices.append(Vector3(part.vertices[i], part.vertices[i+1], part.vertices[i+2]))
			normals.append(Vector3(part.normals[i], part.normals[i+1], part.normals[i+2]).normalized())
		for i in range(0, part.uv.size(), 2): uv.append(Vector2(part.uv[i], part.uv[i+1]))
		var indices := PackedInt32Array()
		for i in range(0, part.indices.size(), 3): indices.append_array([int(part.indices[i]),int(part.indices[i+2]),int(part.indices[i+1])])
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(source.path_join("AUAntiVehicleVehicleTech3" + ("_Treads" if "TREAD" in str(part.name) else "") + ".png")))
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.7
		mesh.surface_set_material(0, mat)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		model.add_child(node)
		nodes.append(node)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0,0,0,0)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	light.light_energy = 1.1
	viewport.add_child(light)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 64
	camera.position = Vector3(0,50,86.60254)
	camera.look_at(Vector3.ZERO)
	# Shift ground origin to pixel (48,60), keeping body/turret identical anchors.
	camera.position += camera.global_basis.y * 8.0
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("rig.json")))
	var point: Array = rig.muzzle.position
	var muzzle_local := Vector3(point[0], point[1], point[2])
	var muzzles: Array = []
	for turret in [false]:
		for i in nodes.size(): nodes[i].visible = bool(parts[i].turret) == turret
		var atlas := Image.create(32*98+2,98,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for facing in 32:
			# RA2Art's facing convention: screen (sin(az), -0.5*cos(az)).
			var az := PI/4.0 - facing*TAU/32.0
			model.rotation.y = PI/2.0-az
			for frame in 2: await process_frame
			await RenderingServer.frame_post_draw
			var img := viewport.get_texture().get_image()
			atlas.blit_rect(img,Rect2i(0,0,96,96),Vector2i(2+facing*98,2))
			if not turret:
				var muzzle := camera.unproject_position(model.transform * muzzle_local)
				muzzles.append([muzzle.x,muzzle.y])
		assert(atlas.save_png(output.path_join("R3MIRAGE_tur.png" if turret else "R3MIRAGE.png")) == OK)
	var file := FileAccess.open(output.path_join("unitweapon_R3MIRAGE.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"muzzles":muzzles,"source":"RA3 FX weapon bone; atlas camera projection"}))
	print("MIRAGE_ATLAS_OK whole vehicle 32 facings, original FX_Weapon projected muzzle")
	quit()
