extends Node2D
## Base-game FX inherited by Upheaval: bullet flash/video spark and veteran ricochet.
const Particle=preload("res://scripts/units/ra3_gunship_impact.gd")
const ROOT="res://assets/ra3/expansion/fx/"
static var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"gunship_weapons.json"))
var world: Battle
var age:=0.0
var direction:=Vector2.RIGHT
var rows: Array[Dictionary]=[]
var duration:=0.0

static func spawn(battle: Battle, point: Vector2, incoming: Vector2, heroic: bool=false):
	if DisplayServer.get_name()=="headless" or not battle.position_visible_to("ally",point):return null
	var live:=battle.get_tree().get_nodes_in_group("ra3_gunship_bullet_hits").filter(func(n):return battle.is_ancestor_of(n))
	if live.size()>=64:live[0].free()
	var result=load("res://scripts/units/ra3_gunship_bullet_hit.gd").new()
	result.world=battle;result.position=point;result.direction=incoming.normalized()
	battle.add_child(result);result.add_to_group("ra3_gunship_bullet_hits")
	result._build(heroic)
	return result

func _build(heroic: bool) -> void:
	var names: Array[String]=["BulletHitAlliesSpark","BulletHitAlliesFlash"]
	if heroic:names.append("CritHitS")
	for name_ in names:
		var data: Dictionary=rules.particles[name_]
		for i in int(Particle.range_value(Particle.child(data,"BurstCount"),1)):
			var update:=Particle.child(data,"Update/Default")
			var row: Dictionary={"data":data,"start":Particle.range_value(Particle.child(data,"InitialDelay")),
				"life":Particle.range_value(Particle.child(data,"Lifetime")),"trail":data.attrs.Type=="TRAIL",
				"size":Particle.range_value(Particle.child(data,"Size")),"rate":Particle.range_value(Particle.child(update,"SizeRate")),
				"damping":Particle.range_value(Particle.child(update,"SizeRateDamping"),1),
				"drag":Particle.range_value(Particle.child(data,"Physics/Default/VelocityDamping"),1),
				"velocity":Particle.xyz(Particle.child(data,"Velocity/Ortho/Position")),
				"color_scale":Particle.range_value(Particle.child(data,"Colors/ColorScale"),1)}
			row.texture=load(ROOT+str(data.attrs.ParticleTexture)+".png")
			row.origin=Vector3.ZERO
			var radius:=float(Particle.child(data,"Volume/Cylinder").get("attrs",{}).get("Radius",0))
			var disk:=Vector2.from_angle(randf()*TAU)*sqrt(randf())*radius
			row.origin=Vector3(disk.x,0,disk.y)
			if row.trail:
				row.trail_life=float(Particle.child(data,"Draw/Trail").attrs.TrailLife)
			else:
				var sprite:=Sprite2D.new();sprite.texture=row.texture;add_child(sprite)
				var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ra3_bullet_particle.gdshader")
				var draw: Dictionary=Particle.child(data,"Draw/Gpu").attrs
				row.columns=float(draw.get("FramesPerRow",1));row.speed=float(draw.get("SpeedMultiplier",1))
				mat.set_shader_parameter("columns",row.columns);mat.set_shader_parameter("frames",float(draw.get("TotalFrames",1)))
				sprite.material=mat;sprite.rotation=Particle.range_value(Particle.child(update,"AngleZ"));row.sprite=sprite
			rows.append(row);duration=maxf(duration,(float(row.start)+float(row.life))/30.0)
	var additive:=CanvasItemMaterial.new();additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=additive
	_sample()

func _point(row: Dictionary, frames: float) -> Vector2:
	var p: Vector3=row.origin+row.velocity*Particle.integral(maxf(0,frames),row.drag)
	p=Basis(Vector3.UP,-direction.angle()+Iso.eff_angle())*p
	return Vector2(p.x,p.z*0.5-p.y*sqrt(0.75))*1.5

func _sample() -> void:
	for row in rows:
		var elapsed:=age*30.0-float(row.start)
		row.active=elapsed>=0 and elapsed<float(row.life)
		if row.trail:continue
		row.sprite.visible=row.active
		if not row.active:continue
		var size_: float=maxf(0.001,row.size+row.rate*Particle.integral(elapsed,row.damping))*1.5
		row.sprite.position=_point(row,elapsed)
		# The shader selects an atlas cell; the Sprite's quad still spans the full texture.
		row.sprite.scale=Vector2.ONE*size_/float(row.texture.get_width())
		var color:=Particle.color_at(row.data,elapsed/float(row.life)*100)*float(row.color_scale)
		row.sprite.modulate=Color(color.r,color.g,color.b,1)
		row.sprite.material.set_shader_parameter("frame",elapsed*row.speed)
	rotation=Iso.eff_angle();scale=Iso.up()
	queue_redraw()

func _process(delta: float) -> void:
	if world.paused:return
	age+=delta
	if age>=duration:queue_free();return
	visible=world.position_visible_to("ally",global_position)
	z_index=DepthLayers.entity_z(global_position,world.map_size)+2
	_sample()

func _draw() -> void:
	for row in rows:
		if not row.trail or not row.active:continue
		var elapsed:=age*30.0-float(row.start)
		var a:=_point(row,maxf(0,elapsed-float(row.trail_life)));var b:=_point(row,elapsed)
		var side:=a.direction_to(b).orthogonal()*float(row.size)*1.5*0.5
		var color:=Particle.color_at(row.data,elapsed/float(row.life)*100)
		draw_polygon(PackedVector2Array([a-side,b-side,b+side,a+side]),PackedColorArray([color,color,color,color]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),row.texture)
