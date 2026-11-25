extends "res://scripts/units/ra3_crash_fx.gd"
## Retail EP1 effects use frame-based emission. Only drawable mesh nuggets need a 3D capture.
const FOLDER := "res://assets/ra3/yuriko/powers/"
static var bank:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"effects.json"))
var anchor:WeakRef
var attached_offset:=Vector2.ZERO
var marker:=false
static var light_masks:Dictionary={}
var event_name: String
var particle_scale := 1.0
var caster_ref:WeakRef
var link:Line2D
var preview_head:=Vector2.ZERO

static func show_fx(world_:Battle,point:Vector2,event:String,actor=null,offset:=Vector2.ZERO,heading:=Vector2.RIGHT,caster=null,preview_root:Node2D=null):
	if preview_root==null:
		if not is_instance_valid(world_) or not world_.position_visible_to("ally",point):return null
		for ref:String in bank.nuggets.get(event,[]):
			if ref.begins_with("AudioEvent:") or ref.begins_with("Multisound:"):Ra2Sfx.play(ref.get_slice(":",1),point)
		if event!="Lure" and not world_.get_viewport_rect().grow(200).has_point(world_.get_global_transform_with_canvas()*point):return null
	if DisplayServer.get_name()=="headless":return null
	var parent:Node=preview_root if preview_root!=null else world_.effects_root
	var fx=load("res://scripts/units/yuriko_power_fx.gd").new()
	fx.world=world_
	fx.preview=preview_root!=null
	fx.caster_ref=weakref(caster) if is_instance_valid(caster) else null
	fx.position=point+offset
	fx.attached_offset=offset
	fx.anchor=weakref(actor) if is_instance_valid(actor) else null
	fx.texture_folder=FOLDER
	fx.marker=event=="Lure"
	fx.event_name=event
	match event:
		"FX_JapanPsyonicMindInfantry", "FX_JapanPsyonicMind":
			fx.particle_scale = 0.25
		"JapanPsyonic_End", "Lure":
			fx.particle_scale = 0.5
	parent.add_child(fx)
	fx.add_to_group("yuriko_power_fx")
	if fx.marker:
		fx.build_guard_marker()
		fx._process(0)
		return fx
	var names:Array=bank.effects.get(event,[event])
	var meshes:Array=[]
	for id:String in names:
		var data:Dictionary=bank.particles[id]
		if data.attrs.has("Drawable"):
			meshes.append({"tag":"ParticleSystem","attrs":{"Particle":id}})
		else:
			var count:=maxi(1,int(data.attrs.SystemLifetime))
			var spacing:=maxi(1,roundi(Particle.range_value(Particle.child(data,"BurstDelay"),1)))
			for start in range(0,count,spacing):fx.emit_burst(data,start)
	if not meshes.is_empty():
		var shell=Particle.new()
		shell.media_folder=FOLDER
		shell.world=world_
		shell.position=point
		shell.preview=fx.preview
		parent.add_child(shell)
		shell._build(bank,meshes)
		for row in shell.particles:
			if row.data.attrs.Drawable=="FXYURIKOPSYONICBLAST":
				var source_:Dictionary=Particle.cache[FOLDER+"fxyurikopsyonicblast"].source
				var mat:=shell_material(source_)
				row.node.material_override=mat
				row.material=mat
			if row.around_velocity:
				row.velocity=Vector3(heading.x,0,-heading.y)*row.velocity.length()
		shell._sample()
	fx._process(0)
	return fx

static func shell_material(mesh:Dictionary) -> ShaderMaterial:
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://shaders/yuriko_blast.gdshader")
	var c:Dictionary=mesh.material.constants
	for pair in [["Texture_0","fractal"],["Texture_1","displacement"],["TextureFadeOut","falloff"]]:
		mat.set_shader_parameter(pair[1],load(FOLDER+mesh.textures[pair[0]]))
	var tint:Array=c.ColorDiffuseKey1
	var uv:Array=c.DiffuseCoordOffset
	mat.set_shader_parameter("tint",Vector3(tint[0],tint[1],tint[2]))
	mat.set_shader_parameter("uv_scroll",Vector4(uv[0],uv[1],uv[2],uv[3]))
	for pair in [["DisplaceScalar","noise_scale"],["DisplaceAmp","amplitude"],["DisplaceDivergenceAngle","divergence"],["DisplaceSpeed","speed"],["EmissiveHDRMultipler","emissive"]]:
		mat.set_shader_parameter(pair[1],c[pair[0]][0])
	return mat

func emit_burst(data:Dictionary,start:float) -> void:
	var count:=int(Particle.range_value(Particle.child(data,"BurstCount"),1))
	for i in count:
		emit(data,start)
		var row:Dictionary=rows.back()
		if row.light:row.sprite.texture=light_mask(float(Particle.child(data,"Draw/LightSource").attrs.MaximumIntensityRadiusRatio))
		var volume:Dictionary=Particle.child(data,"Volume").children[0]
		var radius:=float(volume.attrs.get("Radius",0))
		var dir:=Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized()
		if volume.tag=="Sphere":row.origin=dir*radius*pow(randf(),1.0/3.0)
		elif volume.tag=="Line":
			row.origin=coord(Particle.child(volume,"StartPoint")).lerp(coord(Particle.child(volume,"EndPoint")),randf())
		elif volume.tag=="Cylinder":
			var disk:=Vector2.from_angle(randf()*TAU)*sqrt(randf())*radius
			row.origin=coord(Particle.child(volume,"Offset"))+Vector3(disk.x,0,disk.y)
		if not Particle.child(data,"Velocity/Outward").is_empty():
			row.velocity=dir*Particle.range_value(Particle.child(data,"Velocity/Outward/Speed"))
		var render:=Particle.child(data,"Update/RenderObject")
		if not render.is_empty():
			row.size=Particle.range_value(Particle.child(render,"StartSize/x"))
			row.rate=Particle.range_value(Particle.child(render,"SizeRate/x"))
			row.damping=Particle.range_value(Particle.child(render,"SizeDamping/x"),1)
		# Keep the entire plume around the target, including moving sparks and light falloff.
		row.size *= particle_scale
		row.rate *= particle_scale
		row.origin *= particle_scale
		row.velocity *= particle_scale
		row.drift *= particle_scale
		var gpu:Dictionary=Particle.child(data,"Draw/Gpu").get("attrs",{})
		var shader_name:String=str(gpu.get("Shader","")).to_lower()
		var multiply:=int(data.attrs.get("BlendMode",1))==5
		if shader_name=="gpuparticledistort.fx" or multiply:
			row.sprite.material.shader=preload("res://shaders/yuriko_multiply.gdshader") if multiply else preload("res://shaders/yuriko_distort.gdshader")
			if int(data.attrs.BlendMode)==3:row.sprite.material.shader=preload("res://shaders/yuriko_alpha.gdshader")
			row.sprite.material.set_shader_parameter("columns",float(gpu.get("FramesPerRow",1)))
			row.sprite.material.set_shader_parameter("frames",float(gpu.get("TotalFrames",1)))
			row.sprite.material.set_shader_parameter("animation_speed",row.speed)
			if gpu.has("DetailTexture"):
				var values:Array=gpu.MiscValues
				row.sprite.material.set_shader_parameter("misc",Vector4(values[0],values[1],values[2],values[3]))
				row.sprite.material.set_shader_parameter("seed_offset",randf())
				row.sprite.material.set_shader_parameter("detail_noise",load(FOLDER+gpu.DetailTexture+".png"))
		var trail:=Particle.child(data,"Draw/Trail")
		if not trail.is_empty():row.trail_life=float(trail.attrs.TrailLife)
		if shader_name=="gpuparticledistortion.fx":
			var copy:=BackBufferCopy.new()
			copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
			add_child(copy)
			move_child(copy,row.sprite.get_index())
			row.sprite.material.shader=preload("res://shaders/ra3_gunship_distortion.gdshader")
			row.distortion=true

static func light_mask(ratio:float) -> Texture2D:
	if not light_masks.has(ratio):
		var gradient:=Gradient.new()
		gradient.offsets=PackedFloat32Array([0,ratio,1])
		gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE,Color.BLACK])
		var mask:=GradientTexture2D.new()
		mask.width=128
		mask.height=128
		mask.fill=GradientTexture2D.FILL_RADIAL
		mask.fill_from=Vector2(.5,.5)
		mask.fill_to=Vector2(1,.5)
		mask.gradient=gradient
		light_masks[ratio]=mask
	return light_masks[ratio]

static func coord(value:Dictionary) -> Vector3:
	var a:Dictionary=value.get("attrs",{})
	return Vector3(float(a.get("x",0)),float(a.get("z",0)),-float(a.get("y",0)))

func build_guard_marker() -> void:
	link = Line2D.new()
	link.width = 1.5
	link.antialiased = true
	link.default_color = Color(0.69, 0.64, 1.0, 0.68)
	add_child(link)

func _draw() -> void:
	if marker:
		draw_arc(Vector2(0, -4), 11.0, 0, TAU, 48, Color(0.72, 0.62, 1.0, 0.85), 1.8, true)

static func body_point(actor) -> Vector2:
	var center:Vector2=actor.art_center()
	if actor is Unit:
		var height:=float(actor.special.get("psi_crush",{}).get("height",0))
		if actor.special.has("psi_holder") or actor.special.has("psi_flight"):
			height=preload("res://scripts/units/yuriko.gd").lift_height(actor)
		center+=RA2Art.art_dir(Vector2.UP*height)
	return center

func _process(delta:float) -> void:
	if not preview and world.paused:return
	if anchor!=null:
		var actor=anchor.get_ref()
		if is_instance_valid(actor):
			if marker or event_name in ["JapanPsyonic_End","FX_JapanPsyonicMind","FX_JapanPsyonicMindInfantry"]:position=body_point(actor)
			elif event_name=="JapanPsyonic_Start":position=actor.position+RA2Art.art_dir(actor.yuriko_model.head_offset())
			else:position=actor.position+attached_offset
		if marker and (not AlliedAbilities.alive(actor) or not actor.special.has("psi_original_side")):
			queue_free()
			return
	if marker:
		if not preview:
			rotation = Iso.eff_angle()
			scale = Iso.up()
			z_index = DepthLayers.entity_z(position, world.map_size) + 1
		if preview:
			link.points=PackedVector2Array([preview_head-position,Vector2.UP*9])
		else:
			var caster=caster_ref.get_ref() if caster_ref!=null else null
			var guard=anchor.get_ref() if anchor!=null else null
			visible=AlliedAbilities.alive(guard) and guard.embarked_in==null and world.actor_visible_to("ally",guard)
			link.visible=visible and AlliedAbilities.alive(caster) and caster.embarked_in==null and world.actor_visible_to("ally",caster)
			if link.visible:
				var top:float=guard._body_bounds.position.y
				var head:Vector2=guard.global_position+RA2Art.art_dir(Vector2(0,top if top<-4 else -guard.radius*1.5))
				link.points=PackedVector2Array([to_local(caster.global_position+RA2Art.art_dir(caster.yuriko_model.head_offset())),to_local(head)])
		return
	super._process(delta)
	for row in rows:
		if row.has("trail_life") and row.sprite.visible:
			var t:float=age-row.start
			var before:=maxf(0,t-row.trail_life)
			var path:Vector3=row.velocity*(Particle.integral(t,row.drag)-Particle.integral(before,row.drag))+row.drift*(t-before)
			var span:=Vector2(path.x,path.z*.5-path.y*sqrt(.75))*1.5
			row.sprite.position-=span*.5
			row.sprite.rotation=span.angle()
			row.sprite.scale.x+=span.length()/float(row.sprite.texture.get_width())
		if row.get("distortion",false):
			row.sprite.material.set_shader_parameter("opacity",row.sprite.modulate.a)
			row.sprite.material.set_shader_parameter("angle",row.sprite.rotation)
