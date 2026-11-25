extends "res://tests/ra3_future_presentation_regression.gd"

const Particle=preload("res://scripts/units/ra3_gunship_impact.gd")

func texture(color: Color) -> ImageTexture:
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(color)
	return ImageTexture.create_from_image(image)

func close_color(actual: Color, expected: Vector3) -> bool:
	return Vector3(actual.r,actual.g,actual.b).distance_to(expected)<0.018

func spatial_sample(shader: String, kind: int, opacity: float) -> Color:
	var view:=SubViewport.new();view.size=Vector2i(64,64);view.transparent_bg=true;view.own_world_3d=true;add_child(view)
	var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE;mesh.mesh=quad;view.add_child(mesh)
	var camera:=Camera3D.new();camera.position.z=2;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;view.add_child(camera)
	var mat:=ShaderMaterial.new();mat.shader=load(shader);mesh.material_override=mat
	mat.set_shader_parameter("kind",kind);mat.set_shader_parameter("opacity",opacity)
	mat.set_shader_parameter("tint",Vector3(0.6,0.4,0.2));mat.set_shader_parameter("emissive",0.5)
	mat.set_shader_parameter("diffuse_map",texture(Color(0.5,0.5,0.5,1)))
	mat.set_shader_parameter("mask_map",texture(Color.WHITE));mat.set_shader_parameter("edge_fade",0.0)
	mat.set_shader_parameter("particle_map",texture(Color(0.5,0.5,0.5,1)))
	mat.set_shader_parameter("particle_color",Vector3(0.6,0.4,0.2))
	var result: Image=await capture(view,"oracle-"+shader.get_file()+"-"+str(kind)+"-"+str(opacity))
	var pixel:=result.get_pixel(32,32);view.free();return pixel

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	# Independent literal equations from the EA shaders, with constant textures.
	var texel:=128.0/255.0
	for opacity in [0.8,0.4,0.1]:
		var expected: Vector3=Vector3(0.6,0.4,0.2)*pow(texel,2.2)*float(opacity)
		var shield:=await spatial_sample("res://shaders/ra3_future_shield.gdshader",0,opacity)
		check(close_color(shield,expected),"FXShield opacity multiplies RGB once at "+str(opacity),{"actual":str(shield),"expected":str(expected)})
		var lightning:=await spatial_sample("res://shaders/ra3_gunship_fx.gdshader",0,opacity)
		check(close_color(lightning,expected),"FXLightning native ONE+ONE energy at "+str(opacity),{"actual":str(lightning),"expected":str(expected)})
	var proton:=await spatial_sample("res://shaders/ra3_gunship_fx.gdshader",1,0.25)
	check(close_color(proton,Vector3(0.6,0.4,0.2)*pow(texel,2.2)),"proton opacity selects erosion mask rather than fading whole RGB")
	var gpu:=await spatial_sample("res://shaders/ra3_gpu_particle.gdshader",0,1.0)
	check(close_color(gpu,Vector3(pow(texel*0.6,2.2),pow(texel*0.4,2.2),pow(texel*0.2,2.2))),"GpuParticle applies ColorScale before GammaToLinear, without double emission")
	await composite_check()
	await refraction_check()
	var data: Dictionary=preload("res://scripts/units/ra3_future_draw.gd").data.particles.alliedfuturetanknode
	var values: Array=[]
	for i in 20:values.append(Particle.sample_alpha_keys(data)[1].value)
	check(values.all(func(v):return v>=0.5 and v<=1.0) and values.max()-values.min()>0.1,"native per-particle alpha range is sampled once, not always its minimum")
	var fade: Dictionary=preload("res://scripts/units/ra3_future_draw.gd").data.particles.alliedfuturetankhit_xp
	var keys:=Particle.sample_alpha_keys(fade)
	check(is_equal_approx(Particle.sampled_alpha(keys,0),0.5) and is_equal_approx(Particle.sampled_alpha(keys,50),0.25) and is_zero_approx(Particle.sampled_alpha(keys,100)),"expanded sphere preserves source 0.5 to zero linear opacity curve")

func composite_check() -> void:
	var view:=SubViewport.new();view.size=Vector2i(64,64);view.world_2d=World2D.new();add_child(view)
	var background:=Sprite2D.new();background.texture=texture(Color(0.2,0.3,0.4,1));background.scale=Vector2.ONE*32;background.position=Vector2(32,32);view.add_child(background)
	var sprite:=Sprite2D.new();sprite.scale=Vector2.ONE*16;sprite.position=Vector2(32,32);view.add_child(sprite)
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ra3_fx_composite.gdshader");sprite.material=mat
	for alpha in [0.0,0.25,1.0]:
		sprite.texture=texture(Color(0,0,0,alpha))
		var clear: Image=await capture(view,"black-coverage-"+str(alpha))
		check(close_color(clear.get_pixel(32,32),Vector3(0.2,0.3,0.4)),"black particle quad never darkens background at alpha "+str(alpha))
		sprite.texture=texture(Color(0.1,0.1,0.1,alpha))
		var lit: Image=await capture(view,"emission-coverage-"+str(alpha))
		check(close_color(lit.get_pixel(32,32),Vector3(0.3,0.4,0.5)),"precomputed emission is not attenuated twice at alpha "+str(alpha))
	view.free()

func refraction_check() -> void:
	var view:=SubViewport.new();view.size=Vector2i(128,128);view.world_2d=World2D.new();add_child(view)
	var image:=Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:image.set_pixel(x,y,Color(x/127.0,y/127.0,0.2,1))
	var background:=Sprite2D.new();background.texture=ImageTexture.create_from_image(image);background.centered=false;view.add_child(background)
	var copy:=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;view.add_child(copy)
	var sprite:=Sprite2D.new();sprite.texture=texture(Color(0.6,0.5,1,1));sprite.scale=Vector2.ONE*32;sprite.position=Vector2(64,64);view.add_child(sprite)
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ra3_gunship_distortion.gdshader");sprite.material=mat
	var normal:=Vector3(153/255.0*2-1,128/255.0*2-1,1).normalized()
	for opacity in [1.0,0.5,0.0]:
		mat.set_shader_parameter("opacity",opacity)
		var picture: Image=await capture(view,"refraction-"+str(opacity))
		var expected:=Vector3((64+normal.x*opacity*0.08*128)/127.0,(64+normal.y*opacity*0.08*128)/127.0,0.2)
		check(close_color(picture.get_pixel(64,64),expected),"native normalized normal and 0.08 UV offset, single coverage at "+str(opacity),{"actual":str(picture.get_pixel(64,64)),"expected":str(expected)})
	view.free()
