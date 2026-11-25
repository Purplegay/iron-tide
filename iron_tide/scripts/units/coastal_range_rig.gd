extends RefCounted
## GGI art uses 94x78 SHP cells. Work in that same local canvas and split the
## attachments around the native sprite so the far arm disappears behind the body.
const ARMOR:=Color("#627a7e")
const EDGE:=Color("#d7e0cd")
const JOINT:=Color("#233b46")
const SAFETY:=Color("#ef9856")
const OPTIC:=Color("#95ffda")

const OPTICS:=preload("res://assets/cosmetics/skins/ggi_coastal_optics.png")

static var sockets:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cosmetics/skins/ggi_shoulder_sockets.json"))

# The two idle clips each contain a single authored turn, shared by all eight orders.
# The rifle sweeps from SW towards W in Idle1. Idle2 turns from SE towards S.
const IDLE1_BEARINGS:=[3.0,2.9,2.75,2.5,2.25,2.1,2.0,2.0,2.0,2.0,2.05,2.2,2.4,2.7,3.0]
const IDLE2_BEARINGS:=[5.0,4.9,4.65,4.4,4.2,4.1,4.0,4.0,4.0,4.1,4.2,4.45,4.7,4.9,5.0]

static func _bearing(frame:int,facing:int) -> float:
	if frame>=56 and frame<71:return IDLE1_BEARINGS[frame-56]
	if frame>=71 and frame<86:return IDLE2_BEARINGS[frame-71]
	return float(facing)

static func _ground(direction:Vector2) -> Vector2:
	return direction*Vector2(1.0,0.5)

static func draw_layer(actor,base:Vector2,frame:int,facing:int,behind:bool) -> void:
	var state=actor.yr_finish
	# The sprite frame, rather than the unsnapped world heading, sets the eight bearings.
	var forward:=Vector2.UP.rotated(-_bearing(frame,facing)*TAU/8.0)
	var right:=forward.orthogonal()
	var f:=_ground(forward)
	var s:=_ground(right)
	var foot:=base+Vector2(46,42)
	var open:=smoothstep(0.07,0.88,float(state.fold))
	if frame<0 or frame>=sockets.size() or sockets[frame]==null:return
	var shoulder:Array=sockets[frame]
	# Keep the upper mount on the sampled torso in every pose, including recoil.
	# Only the legs extend to the ground. A fixed deployed socket disconnected
	# the optical heads from the moving operator and crossed the launcher.
	var worn:=base+Vector2(shoulder[0],shoulder[1])+Vector2.DOWN*5.0-f*3.5
	var pack:=worn-f*open*2.0
	var pivot:=pack+Vector2.DOWN*3.7
	# Roll about the lower pin. Project the sideways travel along this SHP facing.
	var lean:float=state.rig_lean
	var roll:=Transform2D(s.x*lean,Vector2.ZERO)
	var shift:=Vector2(0,s.y*lean*5.0)
	var head:=pivot+roll*(pack-pivot)+shift
	if behind and open>0.01:_scan(actor,foot,forward,open,state.phase)
	if behind==(f.y>0.01):
		actor.draw_circle(pivot,1.65,JOINT)
		var body_f:=roll*f
		var body_s:=roll*s
		var up:=roll*Vector2.UP*2.2
		var near_f:=1.0 if f.y>=0 else -1.0
		var near_s:=1.0 if s.y>=0 else -1.0
		_face(actor,head+body_s*2.4*near_s,body_f*1.5,-up,1)
		_face(actor,head+body_f*1.5*near_f,body_s*2.4,-up,1)
		# Sewn webbing and a central latch sit directly on the pack cover.
		var panel:=head+body_f*1.51*near_f
		for strap:float in [-1.45,1.45]:
			var loop:=panel+body_s*strap
			actor.draw_line(loop-up*.76,loop+up*.78,JOINT,.72,true)
			actor.draw_line(loop-body_s*.48,loop+body_s*.48,ARMOR,.64,true)
		_face(actor,head+up,body_s*2.4,body_f*1.5,2)
	var far_sign:float=-1.0 if s.y>=0 else 1.0
	for sign_side:float in [far_sign,-far_sign]:
		var hinge:=head+roll*(s*sign_side*2.8)
		var elbow:=hinge+roll*(s*sign_side*lerpf(0.3,6.0,open)-f*0.9+Vector2.UP*lerpf(1.8,1.0,open))
		var shoe:=foot-f*4.0+s*sign_side*12.0
		var tip:Vector2=elbow.lerp(shoe,smoothstep(0.35,1.0,float(state.fold)))
		if behind!=((-f*lerpf(2.5,8.0,open)+s*sign_side*lerpf(3.6,12.0,open)).y < -0.01):continue
		actor.draw_line(hinge,elbow,JOINT,3.1,true)
		actor.draw_line(hinge+Vector2.UP*0.55,elbow+Vector2.UP*0.55,ARMOR,1.7,true)
		actor.draw_line(elbow,tip,EDGE,1.45,true)
		actor.draw_circle(hinge,1.15,JOINT)
		actor.draw_circle(hinge,.58,ARMOR)
		actor.draw_circle(elbow,1.05,JOINT)
		var warn:bool=state.warning_left>0 and int(state.warning_left*12)%2==0
		var lamp:=SAFETY if state.flash>0 or warn else OPTIC
		actor.draw_circle(elbow,0.42,lamp.darkened(0.30) if open<0.5 else lamp)
		if open>0.7:
			actor.draw_line(tip-f*2.2,tip+f*2.2,JOINT,2.5,true)
			actor.draw_circle(tip,1.05,SAFETY if warn else ARMOR)
	# Each optical head telescopes out of its own side of the folded pack.
	for side_sign:float in [far_sign,-far_sign]:
		var spread:=side_sign*lerpf(1.5,5.2,open)
		if behind!=((-f*lerpf(2.5,8.0,open)+s*spread).y < -0.01):continue
		var shaft:=head+roll*(Vector2.UP*(1.9+open*1.2))
		var socket:=shaft+roll*(s*spread)
		# Twin telescoping posts join each sleeve to the pack on its own depth layer.
		var foot_pin:=head+roll*(s*side_sign*1.7+Vector2.UP*1.5)
		var upper_pin:=shaft+roll*(s*side_sign*1.7)
		actor.draw_line(foot_pin,upper_pin,JOINT,2.3,true)
		actor.draw_line(foot_pin.lerp(upper_pin,.30),upper_pin,EDGE,1.2,true)
		actor.draw_circle(foot_pin,1.25,ARMOR)
		actor.draw_line(shaft,socket,JOINT,2.1,true)
		actor.draw_line(shaft+Vector2.UP*.35,socket+Vector2.UP*.35,EDGE,.65,true)
		_scope(actor,socket,roll*f,roll*s,open,state.flash)
	# Tube vents are on the opposite end to the shot. Split their depth as well.
	if state.flash>0 and actor.is_deployed() and behind==(f.y>0):
		var age:=1.0-float(state.flash)/0.32
		var vent:=foot-f*8.0+Vector2.UP*22.0
		if age<0.42:
			var plume:=vent-f*(4.0+10.0*(1.0-age/0.42))
			var flank:=Vector2(-f.y,f.x).normalized()*1.65
			actor.draw_colored_polygon(PackedVector2Array([vent-flank,plume,vent+flank]),Color(1,0.75,0.36,1-age/0.42))
		for i in 3:
			var p:=clampf(age*1.4-i*0.15,0,1)
			if p<=0 or p>=1:continue
			var center:=vent-f*(2+p*11)+Vector2.UP*(4*p*p)
			var across:=Vector2(-f.y,f.x).normalized()
			var ring:=PackedVector2Array()
			for j in 15:
				var a:=TAU*j/14.0
				ring.append(center+(across*cos(a)+f*sin(a)*0.45)*(0.9+2.4*p))
			actor.draw_polyline(ring,Color(0.78,0.85,0.80,(1-p)*0.77),0.8,true)

# The decals are sampled on projected solid faces. In profile the viewer sees
# the radiator, head-on the lens, and from behind the sealed ivory end cap.
static func _face(actor,center:Vector2,x:Vector2,y:Vector2,tile:int) -> void:
	if absf(x.cross(y))<0.05:return
	var uv:=Vector2(tile%2,tile>>1)*0.5+Vector2.ONE*0.008
	var span:=0.484
	actor.draw_polygon(PackedVector2Array([center-x-y,center+x-y,center+x+y,center-x+y]),
			PackedColorArray([Color(0.78,0.81,0.80)]),PackedVector2Array([uv,uv+Vector2.RIGHT*span,uv+Vector2.ONE*span,uv+Vector2.DOWN*span]),OPTICS)

static func _scope(actor,socket:Vector2,f:Vector2,s:Vector2,open:float,flash:float) -> void:
	var depth:=1.15+open*1.35
	var width:=1.15+open*0.4
	var up:=Vector2.UP*(1.0+open*0.4)
	var body:=socket+f*(open*1.7)
	var near_side:=1.0 if s.y>=0 else -1.0
	_face(actor,body+s*width*near_side,f*depth,-up,2)
	_face(actor,body+up,s*width,f*depth,1)
	# Machined rim at the front of the barrel, extending beyond the cooling fins.
	var muzzle:=body+f*depth
	actor.draw_line(muzzle-s*width+up,muzzle+s*width+up,EDGE,.65,true)
	if f.y<0:
		_face(actor,body-f*depth,s*width,-up,2)
	else:
		var lens:=body+f*depth
		_face(actor,lens,s*width,-up,0)
		if open>0.6 and f.y>0.05:
			var glow:=0.40+0.25*open
			actor.draw_circle(lens-up*0.15,0.52,Color(0.62,1.0,0.82,glow))
	if flash>0:
		var k:=flash/0.32
		actor.draw_line(body+up-f,body+up+f,Color(1,.64,.21,k),0.65,true)

static func _scan(actor,foot:Vector2,heading:Vector2,open:float,phase:float) -> void:
	var start:=foot+_ground(heading)*2.5
	var radius:=open*24.0
	var sweep:=lerpf(-0.60,0.60,0.5+0.5*sin(phase*PI))
	# A short rotating wedge and two range echoes sit on the ground in front of the launcher.
	var beam:=PackedVector2Array([start])
	for i in 6:beam.append(start+_ground(heading.rotated(sweep-i*0.032))*radius)
	actor.draw_colored_polygon(beam,Color(0.24,0.94,0.79,0.18*open))
	actor.draw_line(start,start+_ground(heading.rotated(sweep))*radius,Color(0.46,1,0.85,0.82*open),0.75,true)
	for echo in 2:
		var t:=fposmod(phase*0.65+echo*0.5,1.0)
		var arc:=PackedVector2Array()
		for i in 19:arc.append(start+_ground(heading.rotated(-0.73+i*1.46/18))*radius*(0.38+t*0.62))
		actor.draw_polyline(arc,Color(0.35,0.89,0.79,0.58*open*sin(t*PI)),0.7,true)
	for i in 5:
		var direction:=_ground(heading.rotated((i-2)*0.35))
		actor.draw_line(start+direction*(radius-1.8),start+direction*radius,Color(0.80,0.96,0.79,open*0.71),0.7,true)
