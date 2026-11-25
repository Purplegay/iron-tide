extends "res://tests/apoc_before_ra3_crash_fx.gd"
## SAGE emitter definitions and textures projected into the battlefield canvas.
const REAPER_ROOT="res://assets/ra3/soviet/reaper_fx/"
const Pose=preload("res://scripts/units/ra3_reaper_pose.gd")

var burst_stride:=1
var pending_delta:=0.0
var particle_bank:Dictionary=Pose.definitions.particles

static func show_event(battle:Battle,point:Vector2,event:String,heading:float=0.0):
	if DisplayServer.get_name()=="headless" or not battle.position_visible_to("ally",point):return null
	if not battle.get_viewport_rect().grow(160).has_point(battle.get_global_transform_with_canvas()*point):
		# Off-camera combat remains audible without constructing any billboards.
		if Pose.definitions.effects.has(event):
			for entry in Particle.child(Pose.definitions.effects[event],"NuggetList").children:
				if entry.tag=="Sound":Ra2Sfx.play("RA3_REAPER_"+str(entry.attrs.Value),point)
		return null
	var active:=battle.get_tree().get_node_count_in_group(&"reaper_particles")
	# Leave room for muzzle flashes, landings and impacts when trails are dense.
	if event=="SovietRocketSmokeTrail" and active>=80:return null
	if active>=128:return null
	var fx=load("res://scripts/units/ra3_reaper_particles.gd").new()
	fx.world=battle;fx.position=point;fx.texture_folder=REAPER_ROOT
	if not event.contains("Land") and battle.projectiles_root.get_child_count()>=6:
		fx.burst_stride=3
	battle.effects_root.add_child(fx);fx.add_to_group("reaper_particles")
	if event=="SovietRocketSmokeTrail":
		fx.burst(event,0.0)
	else:
		var list:Dictionary=Pose.definitions.effects[event]
		for entry in Particle.child(list,"NuggetList").children:
			if entry.tag=="DynamicDecal":preload("res://scripts/units/ra3_reaper_decal.gd").spawn(battle,point,entry.attrs)
			if entry.tag=="Sound":Ra2Sfx.play("RA3_REAPER_"+str(entry.attrs.Value),point)
			if entry.tag!="ParticleSystem":continue
			if entry.attrs.get("OnlyIfOnWater","")=="true" and not battle.in_water_world(point):continue
			var data:Dictionary=Pose.definitions.particles[entry.attrs.Particle]
			var delay:=maxi(1,roundi(Particle.range_value(Particle.child(data,"BurstDelay"),1)))
			for start in range(0,int(data.attrs.get("SystemLifetime",1)),delay):fx.burst(entry.attrs.Particle,start,heading if entry.attrs.get("OrientToObject","")=="true" else 0.0)
	fx._process(0)
	return fx

func burst(id:String,start:float,heading:float=0.0) -> void:
	var data:Dictionary=particle_bank[id]
	var count:=int(Particle.range_value(Particle.child(data,"BurstCount"),1))
	for i in range(0,count,burst_stride):
		emit(data,start)
		var row:Dictionary=rows.back()
		var cylinder:Dictionary=Particle.child(data,"Volume/Cylinder").get("attrs",{})
		if not cylinder.is_empty():
			var disk:=Vector2.from_angle(randf()*TAU)*sqrt(randf())*float(cylinder.get("Radius",0))
			row.origin+=Vector3(disk.x,0,disk.y)
		if data.attrs.get("Shader","")=="ALPHA_TEST":
			row.sprite.material.shader=preload("res://shaders/ra3_damage_particle.gdshader")
		if id.begins_with("Soviet_SickleLand_"):row.gravity=float(Particle.child(data,"Physics/Default").get("attrs",{}).get("Gravity",0.0))
		for key in ["origin","velocity","drift"]:row[key]=row[key].rotated(Vector3.UP,-heading)

func _process(delta:float) -> void:
	if burst_stride>1 and delta>0:
		if world.paused:return
		pending_delta+=delta
		if pending_delta<1.0/30.0:return
		delta=pending_delta
		pending_delta=0.0
	super._process(delta)
	for row in rows:
		if row.get("gravity",0.0)!=0.0:
			var t:=maxf(0,age-float(row.start))
			row.sprite.position.y-=0.5*float(row.gravity)*t*t*sqrt(0.75)*1.5
	z_index=0
