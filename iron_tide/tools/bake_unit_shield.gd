extends SceneTree
## Run in a minimal GL Compatibility project with IRON_SHIELD_ROOT pointing at the game.
func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var base := OS.get_environment("IRON_SHIELD_ROOT")
	var folder := base.path_join("assets/ra3/yuriko")
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	assert(gltf.append_from_file(folder.path_join("classic/JapanYurikoTech1.glb"),state)==OK)
	var body := gltf.generate_scene(state)
	var shell := MeshInstance3D.new()
	shell.mesh = body.find_child("YurikoShield",true,false).mesh
	body.free()
	var vp := SubViewport.new()
	vp.size = Vector2i(160,160)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	vp.add_child(shell)
	var camera := Camera3D.new()
	vp.add_child(camera)
	var box := shell.get_aabb()
	var center := box.get_center()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = box.size.length()*0.82
	camera.position = center + Vector3(0,0.5,0.866)*box.size.length()*2
	camera.look_at(center)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	camera.environment = env
	var source:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("FXYURIKOSHIELD.json")))
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string(base.path_join("shaders/yuriko_blast.gdshader"))
	mat.shader = shader
	for pair in [["fractal","Texture_0"],["displacement","Texture_1"],["falloff","TextureFadeOut"]]:
		var image := Image.load_from_file(folder.path_join("powers").path_join(source.textures[pair[1]]))
		mat.set_shader_parameter(pair[0],ImageTexture.create_from_image(image))
	var c:Dictionary = source.material.constants
	var tint:Array = c.ColorDiffuseKey1
	var scroll:Array = c.DiffuseCoordOffset
	mat.set_shader_parameter("tint",Vector3(tint[0],tint[1],tint[2]))
	mat.set_shader_parameter("uv_scroll",Vector4(scroll[0],scroll[1],scroll[2],scroll[3]))
	for pair in [["noise_scale","DisplaceScalar"],["amplitude","DisplaceAmp"],["divergence","DisplaceDivergenceAngle"],["speed","DisplaceSpeed"],["emissive","EmissiveHDRMultipler"]]:
		mat.set_shader_parameter(pair[0],c[pair[1]][0])
	mat.set_shader_parameter("opacity",1.15)
	shell.material_override = mat
	var atlas := Image.create_empty(160*8,160*4,false,Image.FORMAT_RGBA8)
	for frame in 32:
		mat.set_shader_parameter("age",frame/12.0)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y in 160:
			for x in 160:
				var p := image.get_pixel(x,y)
				var alpha := maxf(p.r,maxf(p.g,p.b))
				image.set_pixel(x,y,Color(p.r/alpha,p.g/alpha,p.b/alpha,alpha) if alpha>0 else Color.TRANSPARENT)
		atlas.blit_rect(image,Rect2i(0,0,160,160),Vector2i(frame%8,frame/8)*160)
	print("SHIELD ",atlas.get_used_rect())
	assert(atlas.get_used_rect().has_area())
	quit(atlas.save_png(folder.path_join("unit_shield_atlas.png")))
