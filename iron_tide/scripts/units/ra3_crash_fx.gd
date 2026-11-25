extends Node2D
## Original FX_AlliedBomberDie, flat-world billboard adapter (not SAGE HDR).
const ROOT="res://assets/ra3/expansion/crash/"
const Particle=preload("res://scripts/units/ra3_gunship_impact.gd")
static var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"effects.json"))
# Cache parsed color curves and texture references per imported effect.
static var color_curves:Dictionary={}
static var texture_cache:Dictionary={}
var texture_folder:=ROOT
var world:Battle
var rows:Array[Dictionary]=[]
var age:=0.0
var preview:=false
var share_material_updates := false

static func spawn(battle:Battle,point:Vector2):
	if DisplayServer.get_name()=="headless" or not battle.position_visible_to("ally",point):return null
	var live=battle.get_tree().get_nodes_in_group("ra3_crash_fx").filter(func(n):return battle.is_ancestor_of(n))
	if live.size()>=16:live[0].queue_free()
	var fx=load("res://scripts/units/ra3_crash_fx.gd").new()
	fx.world=battle;fx.position=point;battle.add_child(fx);fx.add_to_group("ra3_crash_fx")
	fx.build();return fx

func build() -> void:
	for entry:Dictionary in Particle.child(source.effect,"NuggetList").children:
		var data:Dictionary=source.particles[entry.attrs.Particle]
		var duration:=int(data.attrs.get("SystemLifetime",1))
		var delay:=maxi(1,int(Particle.range_value(Particle.child(data,"BurstDelay"),1)))
		for start in range(0,duration,delay):
			for i in int(Particle.range_value(Particle.child(data,"BurstCount"),1)):emit(data,float(start))
	_process(0)

func emit(data:Dictionary,start:float,shared_material:ShaderMaterial=null) -> void:
	var update:=Particle.child(data,"Update/Default")
	var draw:Dictionary=Particle.child(data,"Draw/Gpu").get("attrs",{})
	var light:bool=not Particle.child(data,"Draw/LightSource").is_empty()
	# LightSource illuminates lit canvas surfaces; never draw it as a giant flare.
	var sprite=PointLight2D.new() if light else Sprite2D.new()
	var texture_key:=texture_folder+str(data.attrs.ParticleTexture)
	if not texture_cache.has(texture_key):
		texture_cache[texture_key]=Particle.particle_texture(texture_folder,str(data.attrs.ParticleTexture))
	sprite.texture=texture_cache[texture_key]
	var curve_key:=texture_folder+str(data.attrs.id)
	if not color_curves.has(curve_key):
		var colors:=PackedColorArray()
		var offsets:=PackedFloat32Array()
		for key in Particle.child(data,"Colors").get("children",[]):
			if key.tag!="Color":continue
			var value:Dictionary=Particle.child(key,"Color").attrs
			colors.append(Color(float(value.r),float(value.g),float(value.b)))
			offsets.append(float(key.attrs.RelativeAge)*0.01)
		var curve:=Gradient.new()
		if colors.is_empty():colors.append(Color.WHITE);offsets.append(0.0)
		curve.offsets=offsets;curve.colors=colors
		color_curves[curve_key]=curve
	var material:=shared_material
	if material==null:
		material=ShaderMaterial.new()
		material.shader=preload("res://shaders/ra3_damage_particle.gdshader") if data.attrs.get("Shader","")=="ALPHA" else preload("res://shaders/ra3_crash_particle.gdshader")
		material.set_shader_parameter("columns",float(draw.get("FramesPerRow",1)))
		material.set_shader_parameter("frames",float(draw.get("TotalFrames",1)))
	if not light:sprite.material=material
	add_child(sprite)
	var box:Dictionary=Particle.child(data,"Volume/Box/HalfSize").get("attrs",{})
	var origin:=Vector3(randf_range(-1,1)*float(box.get("x",0)),randf_range(-1,1)*float(box.get("z",0)),randf_range(-1,1)*float(box.get("y",0)))
	var drift:Dictionary=Particle.child(data,"Physics/Default/DriftVelocity").get("attrs",{})
	rows.append({"curve":color_curves[curve_key],"sprite":sprite,"light":light,"data":data,"start":start,"life":Particle.range_value(Particle.child(data,"Lifetime")),
		"size":Particle.range_value(Particle.child(data,"Size")),"rate":Particle.range_value(Particle.child(update,"SizeRate")),
		"damping":Particle.range_value(Particle.child(update,"SizeRateDamping"),1),"origin":origin,
		"velocity":Particle.xyz(Particle.child(data,"Velocity/Ortho/Position")),"drag":Particle.range_value(Particle.child(data,"Physics/Default/VelocityDamping"),1),
		"drift":Vector3(float(drift.get("x",0)),float(drift.get("z",0)),-float(drift.get("y",0))),
		"angle":Particle.range_value(Particle.child(update,"AngleZ")),"spin":Particle.range_value(Particle.child(update,"AngularRateZ")),
		"alpha":Particle.sample_alpha_keys(data),"color_scale":Particle.range_value(Particle.child(data,"Colors/ColorScale"),1),"speed":float(draw.get("SpeedMultiplier",1))})

func _process(delta:float) -> void:
	if not preview and world.paused and delta>0:return
	age+=delta*30.0
	if not preview:
		rotation=Iso.eff_angle()
		scale=Iso.up()
		visible=world.position_visible_to("ally",position)
		z_index=DepthLayers.entity_z(position,world.map_size)+1
	var updated_materials:Dictionary={}
	for row in rows.duplicate():
		var t:float=age-row.start
		if t>=row.life:row.sprite.queue_free();rows.erase(row);continue
		row.sprite.visible=t>=0
		if t<0:continue
		var size_:float=maxf(0.01,row.size+row.rate*Particle.integral(t,row.damping))
		var p:Vector3=row.origin+row.velocity*Particle.integral(t,row.drag)+row.drift*t
		row.sprite.position=Vector2(p.x,p.z*.5-p.y*sqrt(.75))*1.5
		if row.light:row.sprite.texture_scale=size_*1.5/float(row.sprite.texture.get_width())
		else:row.sprite.scale=Vector2.ONE*size_*1.5/float(row.sprite.texture.get_width())
		row.sprite.rotation=row.angle+row.spin*t
		var color:Color=row.curve.sample(t/row.life)
		if row.light:
			row.sprite.color=color;row.sprite.energy=row.color_scale;continue
		color.r*=row.color_scale;color.g*=row.color_scale;color.b*=row.color_scale
		color.a=Particle.sampled_alpha(row.alpha,t/row.life*100.0)
		if not preview and str(row.data.attrs.get("ParticleTexture","")).to_lower() == "fxlenzflarehdr01":
			PostLayer.bright_flash(world, row.sprite, row.sprite.global_position, size_ * 1.5, color.get_luminance() * color.a * 2.7363)
		row.sprite.modulate=color
		var material:ShaderMaterial=row.sprite.material
		if not share_material_updates or not updated_materials.has(material):
			material.set_shader_parameter("frame",t*row.speed)
			if share_material_updates:updated_materials[material]=true
	if rows.is_empty():queue_free()
