extends Node

var checks: Array=[]
var output_dir: String

func field_shader() -> Shader:
	var snapshot:=OS.get_environment("IRON_TIDE_FIELD_BEFORE_SHADER")
	if snapshot.is_empty(): return load("res://shaders/ra3_field_lightning.gdshader")
	var shader:=Shader.new(); shader.code=FileAccess.get_file_as_string(snapshot)
	return shader

func check(ok: bool, label: String, details = null) -> void:
	checks.append({"name":label,"passed":ok,"details":details})
	if not ok: print("FAIL ",label," ",details)

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	DirAccess.make_dir_recursive_absolute(output_dir)
	await exercise()
	var failed:=checks.filter(func(row): return not row.passed).size()
	var file:=FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed},"  ")); file.close()
	print("FIELD_GRADIENT checks=",checks.size()," failed=",failed)
	get_tree().quit(1 if failed else 0)

func exercise() -> void:
	# Independent CPU reference of installed FXLightning VS13536/PS12320.
	# White cloud isolates spatial fading from noise and texture filtering.
	var points:=PackedVector3Array([Vector3(-0.8,0.8,0),Vector3(-0.8,-0.8,0),Vector3(0.8,-0.8,0)])
	var normals:=PackedVector3Array([Vector3(0,0,1),Vector3(sqrt(0.96),0,0.2),Vector3(sqrt(0.96),0,0.2)])
	var colors:=PackedColorArray([Color(0.1,0.2,0.4,1),Color(1,0.8,0.4,0.3),Color(0.7,0.5,0.2,0.8)])
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points; arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2(0,1),Vector2.ONE])
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var viewport:=SubViewport.new(); viewport.size=Vector2i(128,128)
	viewport.own_world_3d=true; viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.0; camera.position=Vector3(0,0,10); viewport.add_child(camera)
	var white:=Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
	var material:=ShaderMaterial.new(); material.shader=field_shader()
	material.set_shader_parameter("cloud",ImageTexture.create_from_image(white))
	material.set_shader_parameter("distortion",ImageTexture.create_from_image(white))
	material.set_shader_parameter("edge_fade",3.0)
	material.set_shader_parameter("hdr_multiplier",2.0)
	var instance:=MeshInstance3D.new(); instance.mesh=mesh; instance.material_override=material
	viewport.add_child(instance)
	var alpha: Array[float]=[]
	for i in 3:
		var ratio:=clampf(absf(normals[i].dot((camera.position-points[i]).normalized()))/3.0,0.0,1.0)
		alpha.append(ratio*ratio*(3.0-2.0*ratio)*colors[i].a)
	for strength in [1.0,0.5,0.1,0.0]:
		material.set_shader_parameter("strength",strength)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var picture:=viewport.get_texture().get_image()
		picture.save_png(output_dir.path_join("gradient-%.1f.png"%strength))
		for pixel in [Vector2i(26,40),Vector2i(40,70),Vector2i(65,95)]:
			var weights:=Vector3((115.2-(pixel.y+0.5))/102.4,0.0,((pixel.x+0.5)-12.8)/102.4)
			weights.y=1.0-weights.x-weights.z
			var tint:=Color(0,0,0,0); var edge:=0.0
			for i in 3:
				tint+=colors[i]*weights[i]; edge+=alpha[i]*weights[i]
			var expected: Vector3=Vector3(tint.r,tint.g,tint.b)*strength*edge*4.0
			var actual_color:=picture.get_pixelv(pixel)
			var actual:=Vector3(actual_color.r,actual_color.g,actual_color.b)
			check(actual.distance_to(expected)<0.014,"separate native interpolants %.1f at %s"%[strength,pixel],{"expected":str(expected),"actual":str(actual)})
	viewport.free()
	await check_shell(material)

func shell_pixel(arrays: Array, pixel: Vector2, camera: Vector3, strength: float) -> Vector3:
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var total:=Vector3.ZERO
	for triangle in range(0,indices.size(),3):
		var positions: Array[Vector2]=[]
		for j in 3:
			var p:=points[indices[triangle+j]]
			positions.append(Vector2(256,256)+Vector2(p.x,p.z*0.5-p.y*sqrt(0.75))*512.0/440.0)
		var ab:=positions[1]-positions[0]; var ac:=positions[2]-positions[0]
		var denominator:=ab.cross(ac)
		if absf(denominator)<0.00001: continue
		var ap:=pixel-positions[0]
		var weights:=Vector3(0,ap.cross(ac)/denominator,ab.cross(ap)/denominator)
		weights.x=1.0-weights.y-weights.z
		if weights.x<0 or weights.y<0 or weights.z<0: continue
		var tint:=Vector3.ZERO; var alpha:=0.0
		for j in 3:
			var i:=indices[triangle+j]
			var ratio:=clampf(absf(normals[i].dot((camera-points[i]).normalized()))/3.0,0.0,1.0)
			alpha+=ratio*ratio*(3.0-2.0*ratio)*colors[i].a*weights[j]
			tint+=Vector3(colors[i].r,colors[i].g,colors[i].b)*strength*weights[j]
		total+=tint*alpha*4.0
	return total.clamp(Vector3.ZERO,Vector3.ONE)

func check_shell(material: ShaderMaterial) -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(512,512)
	viewport.own_world_3d=true; viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=440.0; camera.position=Vector3(0,250,433.0127); camera.rotation_degrees.x=-30.0
	viewport.add_child(camera)
	var shell:=MeshInstance3D.new(); shell.mesh=Ra3MirageFx.mesh_for("excloakingfield")
	shell.material_override=material; viewport.add_child(shell)
	var arrays:=shell.mesh.surface_get_arrays(0)
	var bright_samples:=0
	for strength in [1.0,0.5,0.1,0.0]:
		material.set_shader_parameter("strength",strength)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var picture:=viewport.get_texture().get_image()
		picture.save_png(output_dir.path_join("shell-mask-%.1f.png"%strength))
		var maximum:=0.0
		for y in [124,156,188,220,252,284,316,348]:
			for x in [76,116,156,196,236,276,316,356,396,436]:
				var expected:=shell_pixel(arrays,Vector2(x+0.5,y+0.5),camera.position,strength)
				var color:=picture.get_pixel(x,y)
				maximum=maxf(maximum,Vector3(color.r,color.g,color.b).distance_to(expected))
				if strength==1.0 and expected.length()>0.02: bright_samples+=1
		check(maximum<0.025,"full native shell gradient and additive overlaps %.1f"%strength,maximum)
	check(bright_samples>25,"shell oracle covers lit rings, not only empty exterior",bright_samples)
	material.set_shader_parameter("cloud",load("res://assets/ra3/mirage/presentation/FXCloud03.png"))
	material.set_shader_parameter("distortion",load("res://assets/ra3/mirage/presentation/FXFracTileNRM.png"))
	material.set_shader_parameter("phase",4.0); material.set_shader_parameter("strength",1.0)
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output_dir.path_join("shell-source-textures.png"))
	viewport.free()
