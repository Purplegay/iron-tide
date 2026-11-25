extends Node2D
## Native FXList + particle ranges; the visual adapter samples at 30 Hz.
## Uses one shared viewport per explosion, not one viewport per particle.
const ROOT := "res://assets/ra3/expansion/fx/"
const MATERIAL := preload("res://scripts/units/ra3_gunship_material.gd")
const RESOLUTION := preload("res://scripts/units/ra3_fx_resolution.gd")
static var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"gunship_effects.json"))
static var cache: Dictionary={}
var media_folder:=ROOT
var world: Battle
var viewport: SubViewport
var space: Node3D
var camera: Camera3D
var particles: Array[Dictionary]=[]
var age:=0.0
var preview:=false
var duration:=0.0
var budget:=0.0
var effect_id: String
var distortion: Sprite2D
var draw_size:=480.0

static func spawn(battle: Battle, point: Vector2, heroic: bool):
	if DisplayServer.get_name()=="headless":return null
	if not battle.position_visible_to("ally",point):return null
	var live:=battle.get_tree().get_nodes_in_group("ra3_gunship_impacts").filter(func(n):return battle.is_ancestor_of(n))
	if live.size()>=16:live[0].free()
	var effect=load("res://scripts/units/ra3_gunship_impact.gd").new()
	effect.world=battle;effect.position=point
	effect.effect_id="FX_AlliedGunshipProtonHitVet" if heroic else "FX_AlliedGunshipProtonHit"
	battle.add_child(effect);effect.add_to_group("ra3_gunship_impacts")
	effect._build()
	return effect

static func child(node: Dictionary, path: String) -> Dictionary:
	var result:=node
	for tag in path.split("/"):
		var found: Dictionary={}
		for item: Dictionary in result.get("children",[]):
			if item.tag==tag:found=item;break
		result=found
	return result

static func range_value(node: Dictionary, default: float=0.0) -> float:
	var a: Dictionary=node.get("attrs",{})
	var low:=float(a.get("Low",default));var high:=float(a.get("High",default))
	# Uprising 1.1 ClientRandomVariable (0x633640): High <= Low returns High.
	# ProtonSW intentionally contains .75 -> .1. lerp/sorting inflates its rings.
	return high if high<=low else lerpf(low,high,randf())

static func xyz(node: Dictionary, default: float=0.0) -> Vector3:
	return Vector3(range_value(child(node,"x"),default),range_value(child(node,"z"),default),-range_value(child(node,"y"),default))

func _build(bank:Dictionary=definitions,entries:Array=[]) -> void:
	var composite:=ShaderMaterial.new();composite.shader=preload("res://shaders/ra3_fx_composite.gdshader");material=composite
	viewport=SubViewport.new();viewport.size=Vector2i(384,384);viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	space=Node3D.new();viewport.add_child(space)
	camera=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=320.0;camera.position=Vector3(0,200,346.41016);camera.rotation_degrees.x=-30
	if entries.is_empty():entries=child(bank.effects[effect_id],"NuggetList").children
	for entry: Dictionary in entries:
		if entry.tag=="Sound":Ra2Sfx.play("RA3_EXP_"+str(entry.attrs.Value),position)
		if entry.tag!="ParticleSystem" or entry.attrs.get("OnlyIfOnWater","")=="true":continue
		var data: Dictionary=bank.particles[entry.attrs.Particle]
		var bursts:=int(data.attrs.get("SystemLifetime",1))
		var delay:=maxi(1,int(range_value(child(data,"BurstDelay"),1)))
		for frame in range(0,bursts,delay):
			for i in int(range_value(child(data,"BurstCount"),1)):_particle(data,frame/30.0)
	_sample()

static func particle_texture(folder: String, id: String) -> Texture2D:
	if id.to_lower() == "fxlenzflarehdr01":
		return preload("res://assets/ra3/FXLenzflareHDR01.dds")
	return load(folder + id + ".png")

func _particle(data: Dictionary, start: float) -> void:
	var life:=range_value(child(data,"Lifetime"),30)/30.0
	var drawable:=str(data.attrs.get("Drawable","")).to_lower()
	var update:=child(data,"Update/RenderObject" if not drawable.is_empty() else "Update/Default")
	var row: Dictionary={"data":data,"start":start,"life":life,"node":null,"material":null}
	row.alpha_keys=sample_alpha_keys(data)
	if not drawable.is_empty():
		var key:=media_folder+drawable
		if not cache.has(key):
			var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(key+".json"))
			cache[key]={"source":native,"mesh":MATERIAL.make_mesh(native)}
		var native: Dictionary=cache[key].source
		var mesh:=MeshInstance3D.new();mesh.mesh=cache[key].mesh
		var mat:=MATERIAL.create(native.material,native.textures,media_folder)
		mat.set_shader_parameter("source_origin",Vector3(position.x/1.5,position.y/1.5,0))
		mesh.material_override=mat;space.add_child(mesh);row.node=mesh;row.material=mat
		row.size=xyz(child(update,"StartSize"),1).abs()
		row.rate=xyz(child(update,"SizeRate"));row.rate.z=-row.rate.z
		row.damping=xyz(child(update,"SizeDamping"),1).abs()
	else:
		var texture: Texture2D=particle_texture(media_folder, str(data.attrs.ParticleTexture))
		if str(data.attrs.id).ends_with("Dist"):
			# Refraction reads the scene before this explosion is composited. An
			# explicit copy prevents other screen-reading effects reusing a stale frame.
			var layer:=Node2D.new();layer.show_behind_parent=true;add_child(layer)
			var copy:=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;layer.add_child(copy)
			distortion=Sprite2D.new();distortion.texture=texture;layer.add_child(distortion)
			var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ra3_gunship_distortion.gdshader")
			distortion.material=mat;row.node=distortion;row.material=mat
		else:
			var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE
			mesh.mesh=quad;space.add_child(mesh);mesh.rotation_degrees.x=-30
			var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ra3_gpu_particle.gdshader")
			mat.set_shader_parameter("particle_map",texture);mesh.material_override=mat
			row.node=mesh;row.material=mat
		row.size=Vector3.ONE*range_value(child(data,"Size"),1)
		row.rate=Vector3.ONE*range_value(child(update,"SizeRate"))
		row.damping=Vector3.ONE*range_value(child(update,"SizeRateDamping"),1)
	var offset: Dictionary=child(data,"Volume/Cylinder/Offset").get("attrs",{})
	var radius:=float(child(data,"Volume/Cylinder").get("attrs",{}).get("Radius",0))
	var disk:=Vector2.from_angle(randf()*TAU)*sqrt(randf())*radius
	row.origin=Vector3(float(offset.get("x",0))+disk.x,float(offset.get("z",0)),-float(offset.get("y",0))+disk.y)
	row.velocity=xyz(child(data,"Velocity/Ortho/Position"))
	row.drag=range_value(child(data,"Physics/Default/VelocityDamping"),1)
	row.rotation=Vector3(range_value(child(update,"AngleX")),range_value(child(update,"AngleZ")),-range_value(child(update,"AngleY")))
	row.spin=Vector3(range_value(child(update,"AngularRateX")),range_value(child(update,"AngularRateZ")),-range_value(child(update,"AngularRateY")))
	row.spin_drag=range_value(child(update,"AngularDamping"),1)
	row.color_scale=range_value(child(data,"Colors/ColorScale"),1)
	row.around_velocity=update.get("attrs",{}).get("Rotation","")=="ROTATE_AROUND_VELOCITY"
	particles.append(row);duration=maxf(duration,start+life)

static func integral(frames: float, damping: float) -> float:
	return frames if is_equal_approx(damping,1.0) else (1.0-pow(damping,frames))/(1.0-damping)

static func alpha_at(data: Dictionary, relative: float) -> float:
	var keys: Array=child(data,"Alphas").get("children",[])
	if keys.is_empty():return 1.0
	var previous: Dictionary=keys[0].attrs
	for key: Dictionary in keys:
		var next: Dictionary=key.attrs
		var a:=float(previous.RelativeAge);var b:=float(next.RelativeAge)
		if relative<=b:
			return lerpf(float(previous.get("Low",1)),float(next.get("Low",1)),clampf((relative-a)/maxf(0.001,b-a),0,1))
		previous=next
	return float(previous.get("Low",1))

static func sample_alpha_keys(data: Dictionary) -> Array:
	var keys: Array=[]
	for key: Dictionary in child(data,"Alphas").get("children",[]):
		keys.append({"time":float(key.attrs.RelativeAge),"value":range_value(key,1)})
	return keys

static func sampled_alpha(keys: Array, relative: float) -> float:
	if keys.is_empty():return 1.0
	var previous: Dictionary=keys[0]
	for next: Dictionary in keys:
		if relative<=float(next.time):return lerpf(previous.value,next.value,clampf((relative-previous.time)/maxf(0.001,next.time-previous.time),0,1))
		previous=next
	return float(previous.value)

static func color_at(data: Dictionary, relative: float) -> Color:
	var keys: Array=child(data,"Colors").get("children",[]).filter(func(k):return k.tag=="Color")
	if keys.is_empty():return Color.WHITE
	var previous: Dictionary=keys[0]
	for next: Dictionary in keys:
		if relative<=float(next.attrs.RelativeAge):
			var a: Dictionary=child(previous,"Color").attrs;var b: Dictionary=child(next,"Color").attrs
			return Color(float(a.r),float(a.g),float(a.b)).lerp(Color(float(b.r),float(b.g),float(b.b)),clampf((relative-float(previous.attrs.RelativeAge))/maxf(0.001,float(next.attrs.RelativeAge)-float(previous.attrs.RelativeAge)),0,1))
		previous=next
	var c: Dictionary=child(previous,"Color").attrs
	return Color(float(c.r),float(c.g),float(c.b))

# Orthographic bounds of all eight corners, using the same linear projection.
static func projected_extent(pose:Transform3D,bounds:AABB) -> float:
	var center:=pose*bounds.get_center()
	var half:=bounds.size*0.5
	var basis:=pose.basis
	var k:=sqrt(0.75)
	var x:=absf(center.x)+absf(basis.x.x)*half.x+absf(basis.y.x)*half.y+absf(basis.z.x)*half.z
	var y:=absf(center.z*0.5-center.y*k)+absf(basis.x.z*0.5-basis.x.y*k)*half.x+absf(basis.y.z*0.5-basis.y.y*k)*half.y+absf(basis.z.z*0.5-basis.z.y*k)*half.z
	return maxf(x,y)

func _sample() -> void:
	space.rotation.y=Iso.eff_angle()
	var extent:=48.0
	for row: Dictionary in particles:
		var elapsed:=age-float(row.start)
		row.node.visible=elapsed>=0 and elapsed<float(row.life)
		if not row.node.visible:continue
		var frames:=elapsed*30.0
		var size_: Vector3=row.size
		for axis in 3:size_[axis]=maxf(0.0001,size_[axis]+row.rate[axis]*integral(frames,row.damping[axis]))
		var opacity:=sampled_alpha(row.alpha_keys,elapsed/float(row.life)*100.0)
		var point: Vector3=row.origin+row.velocity*integral(frames,float(row.drag))
		if row.node is Sprite2D:
			row.node.position=Vector2(point.x,-point.z)*1.5+RA2Art.art_dir(Vector2(0,-point.y*sqrt(0.75)*1.5))
			row.node.rotation=Iso.eff_angle()
			row.node.scale=Iso.up()*size_.x*1.5/float(row.node.texture.get_width())
			row.material.set_shader_parameter("opacity",opacity)
			row.material.set_shader_parameter("angle",row.rotation.y+row.spin.y*integral(frames,float(row.spin_drag)))
		else:
			row.node.position=point;row.node.scale=size_
			if not str(row.data.attrs.get("Drawable","")).is_empty():
				row.node.rotation=row.rotation+row.spin*integral(frames,float(row.spin_drag))
				if row.around_velocity and (row.velocity as Vector3).length_squared()>0.0001:
					# SAGE's drawable forward axis is X; the expanding shockwave must
					# face its upward velocity, not stand vertically in the battlefield.
					row.node.basis=Basis(Quaternion(Vector3.RIGHT,(row.velocity as Vector3).normalized()))*Basis.from_euler(row.node.rotation)
					row.node.scale=size_
				row.material.set_shader_parameter("age",elapsed);row.material.set_shader_parameter("opacity",opacity)
			else:
				var c:=color_at(row.data,elapsed/float(row.life)*100.0)
				if not preview and str(row.data.attrs.get("ParticleTexture","")).to_lower() == "fxlenzflarehdr01":
					var point_on_screen := Vector2(point.x, -point.z) * 1.5 + RA2Art.art_dir(Vector2(0, -point.y * sqrt(0.75) * 1.5))
					PostLayer.bright_flash(world, self, global_position + point_on_screen, size_.x * 1.5, c.get_luminance() * float(row.color_scale) * 2.7363)
				row.material.set_shader_parameter("particle_color",Vector3(c.r,c.g,c.b)*float(row.color_scale))
				var angle: float=row.rotation.y+row.spin.y*integral(frames,float(row.spin_drag))
				row.node.basis=(space.global_basis.inverse()*camera.global_basis*Basis(Vector3.BACK,angle)).scaled(size_)
			# Fit the actual expanding mesh bounds. A fixed projectile viewport clips
			# the original shockwave long before its native lifetime is over.
			var bounds: AABB=row.node.mesh.get_aabb()
			extent=maxf(extent,projected_extent(row.node.global_transform,bounds))
	draw_size=extent*2.1*1.5
	camera.size=draw_size/1.5
	RESOLUTION.update(self, viewport, draw_size, 256)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED
	queue_redraw()

func _process(delta: float) -> void:
	if not preview and is_instance_valid(world) and world.paused:return
	age+=delta
	if age>=duration:queue_free();return
	visible=preview or (is_instance_valid(world) and world.position_visible_to("ally",global_position))
	budget+=delta
	if budget<1.0/30.0:return
	budget=0.0
	if not preview:z_index=DepthLayers.entity_z(global_position,world.map_size)+1
	_sample()

func _draw() -> void:
	if viewport==null:return
	if not preview:Iso.begin(self)
	draw_texture_rect(viewport.get_texture(),Rect2(Vector2.ONE*-draw_size*0.5,Vector2.ONE*draw_size),false)
