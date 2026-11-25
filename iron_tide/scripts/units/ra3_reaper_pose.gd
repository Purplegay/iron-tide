extends RefCounted
## Resolve the official bored/selected transition scripts before sampling the rig.
const SOURCE="res://assets/ra3/soviet/reaper_fx/source.json"
static var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
# Angles are relative to the hull. Limit both the firing test and the visible barrel to the XML sector.
static func natural_heading(mount:Dictionary) -> float:
	# XML yaw is counterclockwise; positive map bearings rotate toward model +Z.
	return -deg_to_rad(float(mount.angle))

static func barrel_heading(mount:Dictionary, bearing:float) -> float:
	var natural := natural_heading(mount)
	var offset := angle_difference(natural,bearing)
	return natural + clampf(offset,-deg_to_rad(float(mount.anticlockwise)),deg_to_rad(float(mount.clockwise)))

static func in_range(round_data:Dictionary, distance:float, extra_range:=0.0) -> bool:
	return distance >= float(round_data.min_range)*1.5 and distance <= float(round_data.max_range)*1.5+extra_range

var rng:=RandomNumberGenerator.new()
var state:=""
var clip:=""
var age:=0.0
var speed:=1.0
var blend_time:=0.0
var blend_age:=0.0
var previous:Array[Transform3D]=[]

# Save the animation-only pose so a clip transition never blends in the previous frame's aim.
var clip_poses:Dictionary={}
var offsets:Dictionary={}

func aim_grenades(model,step:float) -> void:
	var unit=model.actor
	for i in definitions.grenade_mounts.size():
		var mount:Dictionary=definitions.grenade_mounts[i]
		var bone:int=model.rig.find_bone(mount.turret)
		var natural:=natural_heading(mount)
		var current:=float(offsets.get(bone,0.0))
		var desired:=0.0
		var target=unit.attack_target
		var other=unit.special.get("split_enemy")
		if AlliedAbilities.alive(target) and AlliedAbilities.alive(other) and is_same(unit.special.get("split_primary"),target) and unit.special.get("split_side_index",-1)==i:
			if preload("res://scripts/units/ra3_reaper_split.gd").covers(unit,other,mount):target=other
		elif AlliedAbilities.alive(target) and target is Unit and target.is_air_target():
			var cache:Dictionary=unit.get_meta(&"reaper_aa_cover",{})
			if is_same(cache.get("primary"),target):target=cache.targets[i]
		if AlliedAbilities.alive(target) and not (target is Unit and target.is_air_target()):
			var bearing:float=unit.global_position.angle_to_point(target.global_position)-unit.hull_angle
			var limited:=barrel_heading(mount,bearing)
			if absf(angle_difference(limited,bearing))<=0.000001:
				desired=limited-natural
			elif not mount.recenter_outside:
				desired=current
		current=move_toward(current,desired,deg_to_rad(float(mount.turn_rate))*step)
		offsets[bone]=current
		var pose:Transform3D=model.rig.get_bone_pose(bone)
		clip_poses[bone]=pose
		var heading:=natural+current
		if i>0:
			# Slide the side socket along the curved shell as its barrel swings forward.
			# Model-space only. The child muzzle follows the same animated socket.
			var forward:=maxf(0.0,cos(heading))
			var clearance:=Vector3(3.5,0.0,2.5*signf(sin(natural)))
			model.rig.set_bone_pose_position(bone,pose.origin+clearance*forward)
		model.rig.set_bone_pose_rotation(bone,Quaternion(Vector3.UP,-heading)*pose.basis.get_rotation_quaternion())

func _init() -> void:
	rng.randomize()

func _enter(model, next:String) -> void:
	state=next
	age=0.0
	var choices:Array=definitions.selection.get(next,[])
	var rule:Dictionary={}
	if not choices.is_empty():
		var total:=0
		for choice in choices:total+=int(choice.weight)
		var draw:=rng.randi_range(1,total)
		for choice in choices:
			draw-=int(choice.weight)
			if draw<=0:
				rule=choice
				break
	clip=str(rule.get("clip",next))
	speed=rng.randf_range(rule.get("speed_min",1.0),rule.get("speed_max",1.0))
	if next=="JMPA":speed=2.0
	blend_age=0.0
	blend_time=float(rule.get("blend",0.0))/30.0
	previous.clear()
	if blend_time>0 and not model.clip_name.is_empty():
		for i in model.rig.get_bone_count():previous.append(clip_poses.get(i,model.rig.get_bone_pose(i)))

func advance(model,dt:float) -> float:
	var unit=model.actor
	var desired:="STATE_SelectedPose" if unit.selected else "STATE_bored"
	if AlliedAbilities.alive(unit.attack_target):desired="AIDA"
	if unit.velocity.length()>1.0:desired="WLKA"
	var jump:Dictionary=unit.special.get("walker_jump",{})
	var pack_end:=preload("res://scripts/units/ra3_reaper_leap.gd").takeoff_seconds(jump)
	var clip_start:float=pack_end-(float(model.clips.JMPA.frames)-1)/(2.0*float(model.clips.JMPA.fps))
	if not jump.is_empty():
		if jump.age>=pack_end:desired="JMPB"
		elif jump.age+0.000001>=clip_start:desired="JMPA"
		else:desired="AIDA"
	if unit.special.get("walker_deployed",false):desired="AIDB"
	var last:float=0.0
	if model.clips.has(clip):last=(float(model.clips[clip].frames)-1.0)/float(model.clips[clip].fps)
	var busy:bool=(state=="TRANS_IdleToSelected" and desired=="STATE_SelectedPose") or (state=="TRANS_SelectedToIdle" and desired=="STATE_bored")
	age+=dt*speed
	blend_age+=dt
	if desired!=state and not (busy and age<last):
		if desired=="STATE_SelectedPose" and state in ["STATE_bored","TRANS_SelectedToIdle"]:_enter(model,"TRANS_IdleToSelected")
		elif desired=="STATE_bored" and state in ["STATE_SelectedPose","TRANS_IdleToSelected"]:_enter(model,"TRANS_SelectedToIdle")
		else:_enter(model,desired)
	elif state in ["STATE_bored","STATE_SelectedPose"] and age>=last:_enter(model,state)
	var data:Dictionary=model.clips[clip]
	var frame:=age*float(data.fps)
	if state=="JMPA":return clampf((jump.age-clip_start)*2*float(data.fps),0,float(data.frames)-1)
	if state=="JMPB":return fposmod((jump.age-pack_end)*float(data.fps),float(data.frames))
	if state=="AIDB":return minf(float(unit.special.get("walker_landing_age",10))*float(data.fps),float(data.frames)-1)
	if state in ["AIDA","JMPB","WLKA"]:return fposmod(frame,float(data.frames))
	return minf(frame,float(data.frames)-1)

func blend(model) -> void:
	if previous.is_empty():return
	var weight:=clampf(blend_age/blend_time,0,1)
	if weight>=1:
		previous.clear()
		return
	for i in previous.size():
		model.rig.set_bone_pose(i,previous[i].interpolate_with(model.rig.get_bone_pose(i),weight))
