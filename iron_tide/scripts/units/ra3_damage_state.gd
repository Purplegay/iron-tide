extends Node2D
## EA/Upheaval DAMAGED and REALLYDAMAGED. Medium-LOD particle shader adaptation.
const ROOT="res://assets/ra3/expansion/damage/"
const Particle=preload("res://scripts/units/ra3_gunship_impact.gd")
static var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"rules.json"))
var model
var state:=0
var skin_state:=-1
var rows: Array[Dictionary]=[]
var clocks: Dictionary={}
var skins: Array[Dictionary]=[]
var lights: Array[Dictionary]=[]
const SMOKE_SCALE_BY_UNIT := {"R3HARBINGER": 0.08, "R3FUTURE": 0.24}

func setup(renderer) -> void:
	model=renderer
	for mat in model.materials:
		var original: Texture2D=mat.get_shader_parameter("diffuse_map")
		var prefix: String="AUFutureTank" if model.actor.unit_id=="R3FUTURE" else "AUGunship"
		if original!=null and original.resource_path.get_file().get_basename()==prefix:
			skins.append({"material":mat,"original":original,"damaged":load(ROOT+prefix+"_D.png")})
	set_process(false) # Renderer supplies its existing 30 Hz animation clock.

static func smoke_scale_for(unit_id: String) -> float:
	return float(SMOKE_SCALE_BY_UNIT.get(unit_id, 0.24))

static func smoke_position(anchor: Vector2, actor_position: Vector2, particle_offset: Vector3) -> Vector2:
	return Iso.dir(anchor - actor_position) + Vector2(particle_offset.x, particle_offset.z * 0.5 - particle_offset.y * sqrt(0.75)) * 1.5

func smoke_scale() -> float:
	return smoke_scale_for(model.actor.unit_id)

func classify() -> int:
	if model.actor.hp<=0:return 0
	var fraction: float=model.actor.hp/maxf(1,model.actor.max_hp)
	if fraction<=float(rules.thresholds.MaxHealthReallyDamagedPercentage):return 2
	if fraction<=float(rules.thresholds.MaxHealthDamagedPercentage):return 1
	return 0

func suspend() -> void:
	# Cosmetic trails should not reappear at stale positions after offscreen travel.
	if rows.is_empty() and lights.is_empty():return
	for row in rows:row.sprite.queue_free()
	for row in lights:row.node.queue_free()
	rows.clear();lights.clear();clocks.clear()

func tick(delta: float) -> void:
	state=classify()
	if skin_state!=state:
		for skin in skins:skin.material.set_shader_parameter("diffuse_map",skin.damaged if state==2 else skin.original)
		skin_state=state
	rotation=Iso.eff_angle();scale=Iso.up()
	# Damage sockets must use the same current heading and flight lift as the hull.
	if model.actor.unit_id=="R3HARBINGER":model.sync_pose()
	var bones: Array=["B_FENDER01"] if model.actor.unit_id=="R3FUTURE" else ["FXDAMAGE01","FXDAMAGE02"]
	for bone: String in bones:
		for effect in ["Smoke","Fire","FireLight"]:
			var active:=state>=1 if effect=="Smoke" else state==2
			if effect=="FireLight" and model.actor.unit_id!="R3FUTURE":continue
			var key: String=bone+effect
			if not active:clocks.erase(key);continue
			var data: Dictionary=rules.particles["AlliedVehicleDamage"+effect]
			var left:=float(clocks.get(key,0))-delta*30.0
			# Invisible actors never accrue a backlog. Cap catch-up to native max lifetime.
			left=maxf(left,-35.0)
			while left<=0:
				for i in maxi(1,roundi(Particle.range_value(Particle.child(data,"BurstCount"),1))):_emit(data,bone,effect)
				var interval:=maxf(1,Particle.range_value(Particle.child(data,"BurstDelay"),1))
				# 黑烟必须保持在飞机轮廓附近，避免覆盖地面和其他单位；再降频到每 4 帧一团。
				if effect=="Smoke":interval*=4.0
				left+=interval
			clocks[key]=left
	for row in rows.duplicate():
		row.age+=delta*30.0
		if row.age>=row.life:row.sprite.queue_free();rows.erase(row);continue
		var size_: float=maxf(0.01,row.size+row.rate*Particle.integral(row.age,row.damping))
		if row.smoke:size_*=smoke_scale()
		var p: Vector3=row.velocity*row.age+row.offset
		var anchor: Vector2=model.bone_world(row.bone) if model.actor.unit_id=="R3HARBINGER" else row.origin
		row.sprite.position=smoke_position(anchor,model.actor.global_position,p)
		row.sprite.scale=Vector2.ONE*size_*1.5/Vector2(row.sprite.texture.get_size()).x
		var color:=Particle.color_at(row.data,row.age/row.life*100.0)
		color.r*=row.color_scale;color.g*=row.color_scale;color.b*=row.color_scale
		color.a=Particle.sampled_alpha(row.alpha,row.age/row.life*100.0)
		if row.smoke: color.a*=smoothstep(0.0,3.0,row.age)
		row.sprite.modulate=color
		if row.smoke:row.sprite.material.set_shader_parameter("frame",row.age)
	for row in lights.duplicate():
		row.age+=delta*30.0
		if row.age>=row.life:row.node.queue_free();lights.erase(row);continue
		row.node.light_color=Particle.color_at(row.data,row.age/row.life*100)
		row.node.omni_range=row.size+row.rate*Particle.integral(row.age,row.damping)
		row.node.position=model.rig.get_bone_global_pose(row.bone).origin+row.offset

func _emit(data: Dictionary, bone: String, effect: String) -> void:
	var update:=Particle.child(data,"Update/Default")
	var offset: Dictionary=Particle.child(data,"Volume/Cylinder/Offset").get("attrs",{})
	var row: Dictionary={"data":data,"age":0.0,"life":Particle.range_value(Particle.child(data,"Lifetime")),
		"size":Particle.range_value(Particle.child(data,"Size")),"rate":Particle.range_value(Particle.child(update,"SizeRate")),
		"damping":Particle.range_value(Particle.child(update,"SizeRateDamping"),1),
		"offset":Vector3(float(offset.get("x",0)),float(offset.get("z",0)),-float(offset.get("y",0)))}
	if effect=="FireLight":
		var index:=-1
		for i in model.source.bones.size():
			if str(model.source.bones[i].name).to_upper()==bone:index=i;break
		if index<0:return
		var light:=OmniLight3D.new();light.light_energy=Particle.range_value(Particle.child(data,"Colors/ColorScale"),1)
		model.hull.add_child(light);row.node=light;row.bone=index
		# Volume cylinder: radius 30, length 5, offset z15; attach to moving bone.
		var volume: Dictionary=Particle.child(data,"Volume/Cylinder").get("attrs",{})
		var direction:=randf()*TAU;var radius:=sqrt(randf())*float(volume.get("Radius",0))
		row.offset+=Vector3(cos(direction)*radius,randf_range(-.5,.5)*float(volume.get("Length",0)),sin(direction)*radius)
		lights.append(row);return
	var sprite:=Sprite2D.new();sprite.texture=load(ROOT+str(data.attrs.ParticleTexture)+".png")
	var mat:=ShaderMaterial.new();row.smoke=effect=="Smoke"
	mat.shader=preload("res://shaders/ra3_damage_particle.gdshader") if row.smoke else preload("res://shaders/ra3_damage_fire.gdshader")
	if row.smoke:mat.set_shader_parameter("columns",6.0);mat.set_shader_parameter("frames",36.0)
	sprite.material=mat;sprite.rotation=Particle.range_value(Particle.child(update,"AngleZ"));add_child(sprite)
	row.sprite=sprite;row.bone=bone;row.origin=model.bone_world(bone)
	row.alpha=Particle.sample_alpha_keys(data)
	row.color_scale=Particle.range_value(Particle.child(data,"Colors/ColorScale"),1)
	if row.smoke:row.color_scale*=0.38
	row.velocity=Particle.xyz(Particle.child(data,"Velocity/Ortho/Position"))
	var drift: Dictionary=Particle.child(data,"Physics/Default/DriftVelocity").get("attrs",{})
	row.velocity+=Vector3(float(drift.get("x",0)),float(drift.get("z",0)),-float(drift.get("y",0)))
	if effect=="Fire":
		var speed:=Particle.range_value(Particle.child(data,"Velocity/Outward/Speed"))
		var angle:=randf()*TAU
		row.velocity+=Vector3(cos(angle),0,sin(angle))*speed
	rows.append(row)
