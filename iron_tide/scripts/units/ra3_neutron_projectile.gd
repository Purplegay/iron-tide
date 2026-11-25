extends Node2D
## Actual FXFutureProjectile02 / _Vet, before the separate impact-node FX.
const Draw=preload("res://scripts/units/ra3_future_draw.gd")
const Particle=preload("res://scripts/units/ra3_gunship_impact.gd")
var shot
var viewport: SubViewport
var camera: Camera3D
var space: Node3D
var model: Node3D
var light: OmniLight3D
var budget:=0.0
var draw_size:=120.0
var model_id:=""

func setup(projectile) -> void:
	shot=projectile
	var composite:=ShaderMaterial.new();composite.shader=preload("res://shaders/ra3_fx_composite.gdshader");material=composite
	viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	space=Node3D.new();viewport.add_child(space)
	camera=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.position=Vector3(0,200,346.41016);camera.rotation_degrees.x=-30
	model_id="fxfutureprojectile02_vet" if shot.splinters.get("heroic",false) else "fxfutureprojectile02"
	model=Draw.new();space.add_child(model);model.build(model_id)
	# The heroic Draw explicitly replaces the normal Draw, including its light.
	if not shot.splinters.get("heroic",false):
		light=OmniLight3D.new();space.add_child(light)
		var data: Dictionary=Draw.data.particles.alliedfuturetankprojlight
		light.omni_range=Particle.range_value(Particle.child(data,"Size"))
		light.light_energy=Particle.range_value(Particle.child(data,"Colors/ColorScale"),1)
	_sample()

func _sample() -> void:
	var age:=float(shot.splinters.flight_time)
	space.rotation.y=Iso.eff_angle()
	# Normal XML ORIENT_TO_FLIGHT_PATH; heroic replacement has schema-default flags.
	model.rotation=Vector3.ZERO
	if not shot.splinters.get("heroic",false):
		model.rotation.y=-float(shot.splinters.flight_heading)
		model.rotation.z=float(shot.splinters.get("flight_pitch",0.0))
	model.sample(age)
	if light!=null:
		var data: Dictionary=Draw.data.particles.alliedfuturetankprojlight
		var life:=Particle.range_value(Particle.child(data,"Lifetime"))/30.0
		light.visible=age<life;light.light_color=Particle.color_at(data,age/life*100.0)
		light.position.y=20.0+age*30.0
	var extent:=20.0
	for part in model.parts:
		var bounds: AABB=part.mesh.get_aabb()
		for corner in 8:
			var p: Vector3=part.global_transform*bounds.get_endpoint(corner)
			extent=maxf(extent,maxf(absf(p.x),absf(p.z*0.5-p.y*sqrt(0.75))))
	draw_size=extent*3.15;camera.size=draw_size/1.5
	preload("res://scripts/units/ra3_fx_resolution.gd").update(self, viewport, draw_size, 256)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if shot.visible else SubViewport.UPDATE_DISABLED
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(shot):return
	budget+=delta
	if budget<1.0/30.0:return
	budget=0.0;_sample()

func _draw() -> void:
	if viewport==null:return
	Iso.begin(self);draw_texture_rect(viewport.get_texture(),Rect2(Vector2.ONE*-draw_size/2,Vector2.ONE*draw_size),false)
