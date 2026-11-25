extends RefCounted
## Uprising BezierProjectile: zero launch speed, distance += old speed, then +5/frame.
## CPU evidence and the remaining terrain/contact adapters: RA3_NEUTRON_FLIGHT.md.
const HZ:=15.0
const SCALE:=1.5
const ACCELERATION:=5.0*SCALE
const TRACK_STEP:=20.0/HZ*SCALE
const SEGMENTS:=32

static func setup(shot, actor) -> void:
	var state: Dictionary=shot.splinters
	var height:=0.0
	if actor._ra3_model!=null:
		var model=actor._ra3_model
		var name: String="FX_LASER0"+str(int(actor.special.get("ra3_barrel",0))%2+1)
		for i in model.source.bones.size():
			if str(model.source.bones[i].name).to_upper()==name:
				height=model.rig.get_bone_global_pose(i).origin.y*SCALE-actor.radius*0.35/sqrt(0.75)
				break
	state.neutron_stage="flight"
	state.flight_time=0.0;state.flight_frame=0;state.flight_distance=0.0;state.flight_speed=0.0
	state.flight_height=height
	state.flight_start=shot.position+RA2Art.art_dir(Vector2(0,height*sqrt(0.75)))
	state.flight_end=shot.target_point
	state.flight_heading=(shot.target_point-state.flight_start).angle()

static func curve(state: Dictionary) -> Array[Vector3]:
	var start: Vector2=state.flight_start
	var end: Vector2=state.flight_end
	var a:=Vector3(start.x,start.y,float(state.flight_height))
	var d:=Vector3(end.x,end.y,0.0)
	var height:=maxf(a.z,d.z)
	var b:=a.lerp(d,0.33);b.z=height+5.0*SCALE*minf(1.0,a.distance_to(d)/(300.0*SCALE))
	var c:=a.lerp(d,0.66);c.z=height
	var path: Array[Vector3]=[]
	for i in SEGMENTS+1:path.append(a.bezier_interpolate(b,c,d,float(i)/SEGMENTS))
	return path

static func length_of(path: Array[Vector3]) -> float:
	var length:=0.0
	for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
	return length

static func at_distance(path: Array[Vector3], distance: float) -> Vector3:
	for i in range(1,path.size()):
		var length:=path[i-1].distance_to(path[i])
		if distance<=length:return path[i-1].lerp(path[i],clampf(distance/maxf(length,0.00001),0,1))
		distance-=length
	return path[-1]

static func advance(shot, delta: float) -> float:
	var state: Dictionary=shot.splinters
	state.flight_time=float(state.flight_time)+delta
	var path:=curve(state)
	while int(state.flight_frame)<floori(float(state.flight_time)*HZ+0.000001):
		state.flight_frame=int(state.flight_frame)+1
		if AlliedAbilities.alive(shot.target) and not shot.target is ForceFirePoint:
			state.flight_end=(state.flight_end as Vector2).move_toward(shot.target.position,TRACK_STEP)
			path=curve(state)
		state.flight_distance=float(state.flight_distance)+float(state.flight_speed)
		state.flight_speed=minf(999999.0/HZ*SCALE,float(state.flight_speed)+ACCELERATION)
		if float(state.flight_distance)+0.000001>=length_of(path):
			shot.target_point=state.flight_end;shot.position=shot.target_point
			state.neutron_stage="node";state.age=0.0
			return maxf(0.0,float(state.flight_time)-float(state.flight_frame)/HZ)
	# Render interpolation between native steps; damage remains on the arrival tick.
	var distance:=float(state.flight_distance)+float(state.flight_speed)*fposmod(float(state.flight_time)*HZ,1.0)
	var point:=at_distance(path,distance)
	var ahead:=at_distance(path,distance+1.0)
	if point.distance_to(ahead)>0.0001:
		state.flight_heading=Vector2(ahead.x-point.x,ahead.y-point.y).angle()
		state.flight_pitch=atan2(ahead.z-point.z,Vector2(ahead.x-point.x,ahead.y-point.y).length())
	shot.position=Vector2(point.x,point.y)+RA2Art.art_dir(Vector2(0,-point.z*sqrt(0.75)))
	return -1.0
