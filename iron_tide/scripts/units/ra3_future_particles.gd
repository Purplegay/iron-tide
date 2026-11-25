extends Node2D
## Neutron impact visuals have their own XML clock, independent of damage radius.
const Draw=preload("res://scripts/units/ra3_future_draw.gd")
const Particle=preload("res://scripts/units/ra3_gunship_impact.gd")
var shot
var viewport: SubViewport
var space: Node3D
var camera: Camera3D
var rows: Array[Dictionary]=[]
var age:=0.0
var budget:=0.0
var draw_size:=120.0
var large_sound:=false

func setup(projectile) -> void:
	shot=projectile
	var composite:=ShaderMaterial.new();composite.shader=preload("res://shaders/ra3_fx_composite.gdshader");material=composite
	age=float(shot.splinters.age)
	large_sound=age>=35.0/30.0 # Restoring an existing node must not replay past sounds.
	viewport=SubViewport.new();viewport.size=Vector2i(384,384);viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	space=Node3D.new();viewport.add_child(space)
	camera=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.position=Vector3(0,200,346.41016);camera.rotation_degrees.x=-30
	var suffix: String="Vet" if shot.splinters.get("heroic",false) else ""
	for id in ["AlliedFutureTankNode"+suffix,"AlliedFutureTankNodeHitLight"+suffix,"AlliedFutureTankNodeHitGlow"+suffix,"AlliedFutureTankHit_XP"+suffix,"AlliedFutureTankHit_Light"+suffix]:
		var data: Dictionary=Draw.data.particles[id.to_lower()]
		for i in int(Particle.range_value(Particle.child(data,"BurstCount"),1)):_add(data)
	if age<1.0/30.0:Ra2Sfx.play("RA3_EXP_ALL_FutureTank_Weapon_NeutronScramblerImpactSmall",shot.target_point)
	_sample()

func _add(data: Dictionary) -> void:
	var row: Dictionary={"data":data,"delay":Particle.range_value(Particle.child(data,"InitialDelay"))/30.0,
		"life":Particle.range_value(Particle.child(data,"Lifetime"))/30.0}
	row.alpha_keys=Particle.sample_alpha_keys(data)
	row.color_scale=Particle.range_value(Particle.child(data,"Colors/ColorScale"),1)
	var native:=str(data.attrs.get("Drawable","")).to_lower()
	var update:=Particle.child(data,"Update/RenderObject" if not native.is_empty() else "Update/Default")
	var node: Node3D
	if not native.is_empty():
		node=Draw.new();space.add_child(node);node.build(native)
		row.size=Particle.xyz(Particle.child(update,"StartSize"),1).abs()
		row.rate=Particle.xyz(Particle.child(update,"SizeRate"));row.rate.z=-row.rate.z
		row.damping=Particle.xyz(Particle.child(update,"SizeDamping"),1).abs()
	else:
		if not Particle.child(data,"Draw/LightSource").is_empty():
			node=OmniLight3D.new();node.omni_range=Particle.range_value(Particle.child(data,"Size"));space.add_child(node)
		else:
			var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE;mesh.mesh=quad;node=mesh
			var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ra3_gpu_particle.gdshader")
			mat.set_shader_parameter("particle_map",load(Draw.ROOT+str(data.attrs.ParticleTexture)+".png"))
			mesh.material_override=mat;space.add_child(mesh)
		row.size=Vector3.ONE*Particle.range_value(Particle.child(data,"Size"),1)
		row.rate=Vector3.ONE*Particle.range_value(Particle.child(update,"SizeRate"))
		row.damping=Vector3.ONE*Particle.range_value(Particle.child(update,"SizeRateDamping"),1)
	row.node=node
	var offset: Dictionary=Particle.child(data,"Volume/Cylinder/Offset").get("attrs",{})
	if offset.is_empty():offset=Particle.child(data,"Volume/Line/StartPoint").get("attrs",{})
	row.origin=Vector3(float(offset.get("x",0)),float(offset.get("z",0)),-float(offset.get("y",0)))
	row.velocity=Particle.xyz(Particle.child(data,"Velocity/Ortho/Position"))
	row.velocity_damping=Particle.range_value(Particle.child(data,"Physics/Default/VelocityDamping"),1)
	row.rotation=Vector3(Particle.range_value(Particle.child(update,"AngleX")),Particle.range_value(Particle.child(update,"AngleZ")),-Particle.range_value(Particle.child(update,"AngleY")))
	row.spin=Vector3(Particle.range_value(Particle.child(update,"AngularRateX")),Particle.range_value(Particle.child(update,"AngularRateZ")),-Particle.range_value(Particle.child(update,"AngularRateY")))
	rows.append(row)

func _sample() -> void:
	space.rotation.y=Iso.eff_angle()
	var extent:=40.0
	for row: Dictionary in rows:
		var elapsed:=age-float(row.delay)
		row.node.visible=elapsed>=0.0 and elapsed<float(row.life)
		if not row.node.visible:continue
		var size_: Vector3=row.size
		for axis in 3:size_[axis]=maxf(0.0001,size_[axis]+row.rate[axis]*Particle.integral(elapsed*30.0,row.damping[axis]))
		var alpha:=Particle.sampled_alpha(row.alpha_keys,elapsed/float(row.life)*100.0)
		row.node.position=row.origin+row.velocity*Particle.integral(elapsed*30.0,row.velocity_damping)
		if row.node is OmniLight3D:
			row.node.light_color=Particle.color_at(row.data,elapsed/float(row.life)*100.0)
			row.node.light_energy=float(row.color_scale)
			row.node.omni_range=size_.x
			# This sustained node light belongs to the local effect viewport.
			continue
		row.node.scale=size_
		var parts: Array=[]
		if row.node.has_method("sample"):
			row.node.rotation=row.rotation+row.spin*elapsed*30.0
			row.node.sample(elapsed,0.0,false,alpha);parts=row.node.parts
		else:
			var flat:=str(Particle.child(row.data,"Draw/Gpu").get("attrs",{}).get("Shader",""))=="gpuparticlexy.fx"
			var billboard: Basis=Basis(Vector3.RIGHT,-PI/2.0) if flat else space.global_basis.inverse()*camera.global_basis
			row.node.basis=(billboard*Basis(Vector3.BACK,row.rotation.y+row.spin.y*elapsed*30.0)).scaled(size_)
			var c:=Particle.color_at(row.data,elapsed/float(row.life)*100.0)
			row.node.material_override.set_shader_parameter("particle_color",Vector3(c.r,c.g,c.b)*float(row.color_scale))
			parts=[row.node]
		for part in parts:
			var bounds: AABB=part.mesh.get_aabb()
			for corner in 8:
				var p: Vector3=part.global_transform*bounds.get_endpoint(corner)
				extent=maxf(extent,maxf(absf(p.x),absf(p.z*0.5-p.y*sqrt(0.75))))
	draw_size=extent*3.15;camera.size=draw_size/1.5
	if age>=75.0/30.0:
		visible=false;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;set_process(false)
		return # Six-second damage lifetime must not keep rendering an empty 3D viewport.
	preload("res://scripts/units/ra3_fx_resolution.gd").update(self, viewport, draw_size, 384)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if shot.visible else SubViewport.UPDATE_DISABLED
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(shot):return
	age=float(shot.splinters.age)
	if age>=35.0/30.0 and not large_sound:
		large_sound=true;Ra2Sfx.play("RA3_EXP_ALL_FutureTank_Weapon_NeutronScramblerImpactBig",shot.target_point)
	budget+=delta
	if budget<1.0/30.0:return
	budget=0.0;_sample()

func _draw() -> void:
	if viewport==null:return
	Iso.begin(self);draw_texture_rect(viewport.get_texture(),Rect2(Vector2.ONE*-draw_size/2,Vector2.ONE*draw_size),false)
