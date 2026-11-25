extends Node2D
## Two LaserState origins and native Laser.fx scrolling texture combination.
const Draw=preload("res://scripts/units/ra3_future_draw.gd")
const Particle=preload("res://scripts/units/ra3_gunship_impact.gd")
# Compatibility's 2D canvas has no SAGE HDR exposure/soft-particle pass.
# Bound each emitter's accumulated SDR contribution; keep native XML values.
const GLOW_DISPLAY_GAIN:=0.35
var shot_ref: WeakRef
var world: Battle
var beams: Array[Polygon2D]=[]
var glows: Array[Dictionary]=[]
var emission: Array[float]=[0.0,0.0]
var endpoints: Array[Vector2]=[]
var age:=0.0
var particle_budget:=0.0
var heroic:=false
var flare: Texture2D=load(Draw.ROOT+"FXLenzFlare01.png")

static func spawn(shot) -> void:
	if DisplayServer.get_name()=="headless":return
	shot.set_meta("ra3_beam_started",true)
	var fx=load("res://scripts/units/ra3_future_beam.gd").new()
	fx.shot_ref=weakref(shot);fx.world=shot.get_parent().get_parent();fx.heroic=shot.splinters.get("heroic",false)
	fx.world.add_child(fx);fx.add_to_group("ra3_future_beams");fx.setup()

func setup() -> void:
	var mat:=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=mat
	for i in 2:
		var poly:=Polygon2D.new();add_child(poly)
		poly.texture=load(Draw.ROOT+"FXAlliedFutureLaser.png")
		var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/ra3_future_beam.gdshader")
		shader.set_shader_parameter("first",load(Draw.ROOT+"FXAlliedFutureLaser.png"))
		shader.set_shader_parameter("second",load(Draw.ROOT+"FXAlienLaser.png"))
		shader.set_shader_parameter("second_v",0.8 if i==0 else 1.0)
		shader.set_shader_parameter("emissive",Vector3(9,1.5,1.5) if heroic else Vector3.ONE*4.5)
		poly.material=shader;beams.append(poly)
	_process(0.0)

func _process(delta: float) -> void:
	if world.paused:return
	var shot=shot_ref.get_ref()
	# A live beam follows its damage clock, including suspension/save restore.
	# Only residual particles advance independently once the payload is gone.
	var next_age:=float(shot.splinters.age) if is_instance_valid(shot) else age+delta
	var elapsed:=maxf(0.0,next_age-age)
	age=next_age
	if age>=2.0:queue_free();return
	var active: bool=is_instance_valid(shot) and age<1.0 and not shot.splinters.get("riot_stopped",false) and not shot.splinters.get("riot_suspended",false)
	if active:
		particle_budget+=elapsed
		var emit_end:=particle_budget>=1.0/30.0
		if emit_end:particle_budget=fmod(particle_budget,1.0/30.0)
		var source=shot._credit_source.get_ref()
		if is_instance_valid(source):shot.splinters.muzzles=Ra3Expansion.riot_muzzles(source)
		endpoints=Ra3Expansion.riot_endpoints(shot)
		for i in 2:
			var a:=Iso.dir(shot.splinters.muzzles[i]);var b:=Iso.dir(endpoints[i])
			var normal:=a.direction_to(b).orthogonal()*15.0
			beams[i].rotation=Iso.eff_angle();beams[i].scale=Iso.up()
			beams[i].polygon=PackedVector2Array([a-normal,a+normal,b+normal,b-normal])
			# Polygon2D accepts pixel UVs; CanvasItem shaders receive normalized UVs.
			var texture_size:=beams[i].texture.get_size()
			beams[i].uv=PackedVector2Array([Vector2.ZERO,Vector2(texture_size.x,0),texture_size,Vector2(0,texture_size.y)])
			beams[i].material.set_shader_parameter("age",age)
			emission[i]-=elapsed
			if emission[i]<=0:
				_emit(shot.splinters.muzzles[i],"AlliedFutureStartGlow"+("Vet" if heroic else ""),i)
				emission[i]=randf_range(1,5)/30.0
			if emit_end:_emit(endpoints[i],"AlliedFutureGlow"+("Vet" if heroic else ""),i+2)
	for beam in beams:beam.visible=active
	glows=glows.filter(func(g):return age-float(g.born)<float(g.life))
	visible=endpoints.is_empty() or world.position_visible_to("ally",endpoints[0])
	z_index=DepthLayers.entity_z(endpoints[0],world.map_size)+2 if not endpoints.is_empty() else 0
	queue_redraw()

func _emit(point: Vector2, id: String, emitter: int) -> void:
	var data: Dictionary=Draw.data.particles[id.to_lower()]
	var color_: Dictionary=Particle.child(Particle.child(data,"Colors").children[0],"Color").attrs
	var scale_: float=Particle.range_value(Particle.child(data,"Colors/ColorScale"),1)
	var update:=Particle.child(data,"Update/Default")
	glows.append({"point":point,"emitter":emitter,"born":age,"life":Particle.range_value(Particle.child(data,"Lifetime"))/30.0,
		"size":Particle.range_value(Particle.child(data,"Size")),"rate":Particle.range_value(Particle.child(update,"SizeRate")),
		"damping":Particle.range_value(Particle.child(update,"SizeRateDamping"),1),"color":Color(float(color_.r)*scale_,float(color_.g)*scale_,float(color_.b)*scale_)})

func glow_counts() -> PackedInt32Array:
	var counts:=PackedInt32Array([0,0,0,0])
	for g: Dictionary in glows:counts[int(g.emitter)]+=1
	return counts

func glow_tint(g: Dictionary, counts: PackedInt32Array) -> Color:
	var native: Color=g.color
	# Hue-preserving HDR compression, then normalize the emitter's overlap.
	# This is a Godot SDR adapter, not a claimed reconstruction of SAGE exposure.
	var peak:=maxf(native.r,maxf(native.g,native.b))
	var tint:=native*(GLOW_DISPLAY_GAIN/(1.0+peak)/maxi(1,counts[int(g.emitter)]))
	tint.a=clampf(1.0-(age-float(g.born))/float(g.life),0,1)
	return tint

func _draw() -> void:
	Iso.begin(self)
	var counts:=glow_counts()
	for g: Dictionary in glows:
		var t:=age-float(g.born)
		# CommonParticle.VertexCorners span -0.5..0.5: Size is full width.
		var size_: float=(g.size+g.rate*Particle.integral(t*30,g.damping))*1.5
		var tint:=glow_tint(g,counts)
		draw_texture_rect(flare,Rect2(Iso.dir(g.point)-Vector2.ONE*size_/2,Vector2.ONE*size_),false,tint)
