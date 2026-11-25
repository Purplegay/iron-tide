extends RefCounted
## Source BezierProjectile fields; continuous-flat-world cubic adapter.
const HZ := 15.0
const SCALE := 1.5
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_completion_rules.json"))

static func setup(shot, actor, mount: String, scatter: Vector2) -> void:
	var state: Dictionary = shot.splinters
	var height: float = actor._visual_lift()
	var yaw: float = actor.hull_angle-float(actor.special.get("ra3_aim_"+mount,PI/2.0))
	var pitch: float = float(actor.special.get("ra3_aim_"+mount+"_pitch",0.0))
	var ground: Vector2 = shot.position+RA2Art.art_dir(Vector2(0,height*sqrt(0.75)))
	state.shell_start=Vector3(ground.x,ground.y,height)
	state.shell_tangent=Vector3(cos(yaw)*cos(pitch),sin(yaw)*cos(pitch),-sin(pitch))
	state.shell_end=shot.target_point;state.shell_scatter=scatter
	state.shell_time=0.0;state.shell_frame=0;state.shell_distance=0.0

static func path(state: Dictionary) -> Array[Vector3]:
	var a: Vector3=state.shell_start
	var end: Vector2=state.shell_end
	var d:=Vector3(end.x,end.y,0.0)
	var distance:=a.distance_to(d)
	# Fixed source muzzle tangent, source percent indents and straight cap.
	# Cubic interpolation is a Godot adapter; native segmented solver is unverified.
	var tangent_length:=minf(distance*float(rules.shell.FirstPercentIndent)/100.0,float(rules.shell.FireStraightDistance)*SCALE)
	var b:=a+(state.shell_tangent as Vector3)*tangent_length
	var c:=a.lerp(d,float(rules.shell.SecondPercentIndent)/100.0)
	var result: Array[Vector3]=[]
	for i in 33:result.append(a.bezier_interpolate(b,c,d,float(i)/32.0))
	return result

# Disposable geometry cache: never serialized into the projectile payload.
static func geometry(shot) -> Dictionary:
	var state:Dictionary=shot.splinters
	var shape:=Vector3(float(rules.shell.FirstPercentIndent),float(rules.shell.SecondPercentIndent),float(rules.shell.FireStraightDistance))
	var cached=shot.get_meta("gunship_curve") if shot.has_meta("gunship_curve") else null
	if cached!=null and cached.start==state.shell_start and cached.end==state.shell_end and cached.tangent==state.shell_tangent and cached.shape==shape:return cached
	var curve:=path(state)
	var lengths:=PackedFloat64Array()
	var total:=0.0
	for i in range(1,curve.size()):
		var segment:=curve[i-1].distance_to(curve[i])
		lengths.append(segment);total+=segment
	cached={"start":state.shell_start,"end":state.shell_end,"tangent":state.shell_tangent,"shape":shape,"curve":curve,"lengths":lengths,"length":total}
	shot.set_meta("gunship_curve",cached)
	return cached

static func point_at(geometry:Dictionary,distance:float) -> Vector3:
	var curve:Array[Vector3]=geometry.curve
	var lengths:PackedFloat64Array=geometry.lengths
	for i in lengths.size():
		var length:float=lengths[i]
		if distance<=length:return curve[i].lerp(curve[i+1],clampf(distance/maxf(length,0.00001),0,1))
		distance-=length
	return curve[-1]

static func advance(shot, delta: float) -> bool:
	var state: Dictionary=shot.splinters
	# Old saves contain only a straight segment; seed a continuous path from it.
	if not state.has("shell_start"):
		var start: Vector2=state.start
		state.shell_start=Vector3(start.x,start.y,0)
		var direction: Vector2=start.direction_to(shot.target_point)
		state.shell_tangent=Vector3(direction.x,direction.y,0)
		state.shell_end=shot.target_point;state.shell_scatter=Vector2.ZERO
		state.shell_time=maxf(0.0,float(state.age)-delta);state.shell_frame=floori(float(state.shell_time)*HZ)
		state.shell_distance=float(state.shell_time)*750.0
	state.shell_time=float(state.shell_time)+delta
	var curve:=geometry(shot)
	var speed:=float(rules.mounts.side.weapon.attrs.WeaponSpeed)*SCALE
	while int(state.shell_frame)<floori(float(state.shell_time)*HZ+0.000001):
		state.shell_frame=int(state.shell_frame)+1
		if AlliedAbilities.alive(shot.target) and not shot.target is ForceFirePoint:
			state.shell_end=(state.shell_end as Vector2).move_toward(shot.target.position+(state.shell_scatter as Vector2),float(rules.shell.FlightPathAdjustDistPerSecond)*SCALE/HZ)
			curve=geometry(shot)
		state.shell_distance=float(state.shell_distance)+speed/HZ
		if float(state.shell_distance)>=float(curve.length):
			shot.target_point=state.shell_end;shot.position=shot.target_point
			return true
	var distance:=float(state.shell_distance)+speed/HZ*fposmod(float(state.shell_time)*HZ,1.0)
	var p:=point_at(curve,distance)
	var ahead:=point_at(curve,distance+1.0)
	state.shell_heading=Vector2(ahead.x-p.x,ahead.y-p.y).angle()
	state.shell_pitch=atan2(ahead.z-p.z,Vector2(ahead.x-p.x,ahead.y-p.y).length())
	shot.position=Vector2(p.x,p.y)+RA2Art.art_dir(Vector2(0,-p.z*sqrt(0.75)))
	return false
