extends RefCounted
## Cosmetic clocks only. Geometry uses the current frame's body bounds in Iso drawing space.
const GOLD:=Color("#d2a858")
const STEEL:=Color("#293a4a")
const IVORY:=Color("#e3dfc4")
const AMBER:=Color("#ffc861")
var skin:int
var fold:float
var phase:=0.0
var stopped:=0.0
var flash:=0.0
var barrel:=-1
var air_rack:=false
var charge:=0.0
var muzzle:=Vector2.ZERO
var warning_left:=0.0
var rig_lean:=0.0
var rig_speed:=0.0
var rig_heading:=INF
var halo_open:=0.0
var first_star:=0.0
var constellation:=0.0
var sight_check_left:=0.0
var sight_target_id:=0
var target_in_range:=false
const DIPPER:=[Vector2(-0.92,-0.08),Vector2(-0.64,-0.35),Vector2(-0.36,-0.28),Vector2(-0.06,-0.02),Vector2(0.25,0.39),Vector2(0.78,0.16),Vector2(0.68,-0.29)]

func mount_hit() -> void:
	if fold>=0.65:warning_left=0.8

func _init(id:int,deployed:bool) -> void:
	skin=id
	fold=float(deployed)

func fire(index:int,weapon:Dictionary,origin:Vector2) -> void:
	flash=0.32
	barrel=index
	air_rack=skin==9 and weapon.get("ra2_aa",false) and index<0
	muzzle=origin
	if skin==9:
		halo_open=1.0
		if index==0:first_star=0.85
		elif index==1 and first_star>0:
			first_star=0.0
			constellation=1.35
		elif air_rack:
			first_star=0.0
			constellation=0.0

func tick(actor,dt:float,preview_charge:=-1.0) -> void:
	var prev_flash:=flash
	flash=maxf(0,flash-dt)
	var old_phase:=floori(phase*12.0)
	phase=fmod(phase+dt,12.0)
	var changed:=prev_flash>0 or floori(phase*12.0)!=old_phase
	match skin:
		6:
			var before:=stopped
			stopped=move_toward(stopped,1.0 if actor.velocity.length_squared()<1 else 0.0,dt*(0.80 if actor.velocity.length_squared()<1 else 1.9))
			if before!=stopped:actor.material.set_shader_parameter("signature_charge",stopped)
			changed=changed or before!=stopped
		7:
			var before:=fold
			fold=move_toward(fold,float(actor.is_deployed()),dt*3.6)
			_tick_rig(actor,dt)
			warning_left=maxf(0,warning_left-dt) if actor.is_deployed() else 0.0
			changed=changed or before!=fold or warning_left>0
		8:
			var before:=charge
			charge=preview_charge if preview_charge>=0 else (1.0-clampf(actor._cd_timer/maxf(actor.cooldown,0.05),0,1) if is_instance_valid(actor.attack_target) else 0.0)
			if before!=charge or prev_flash>0:
				actor.material.set_shader_parameter("signature_charge",maxf(charge,flash/0.32))
			changed=changed or before!=charge
		9:
			var previous_open:=halo_open
			# A finishing shot keeps its full orbit until its last star fades.
			var afterglow:=maxf(prev_flash,maxf(first_star,constellation))
			sight_check_left-=dt
			var active:bool=actor.velocity.length_squared()>1.0 or afterglow>=dt
			if not active and is_instance_valid(actor.attack_target):
				var target_id:int=actor.attack_target.get_instance_id()
				if target_id!=sight_target_id or sight_check_left<=0.0:
					sight_target_id=target_id
					target_in_range=actor._weapon_target_valid(actor.attack_target)
					sight_check_left=0.12
				active=target_in_range
			if active:
				halo_open=move_toward(halo_open,1.0,dt/0.65)
			else:
				halo_open=move_toward(halo_open,0.0,maxf(0.0,dt-afterglow)/1.2)
			changed=prev_flash>0 or previous_open!=halo_open or (changed and (halo_open>0 or afterglow>0))
			first_star=maxf(0,first_star-dt)
			constellation=maxf(0,constellation-dt)
	if changed:actor.queue_redraw()

# Roll of the hinged instrument, in radians. The spring integrates exactly for
# a constant goal so a long frame or accelerated battle cannot launch the pack.
func _tick_rig(actor,dt:float) -> void:
	if dt<=0:return
	if rig_heading!=INF:
		var turn:=angle_difference(rig_heading,actor.hull_angle)
		rig_speed=clampf(rig_speed-4.0*turn,-3.0,3.0)
	rig_heading=actor.hull_angle
	var stride:=0.17*sin(actor._walk_phase*TAU) if actor._moving() else 0.0
	var goal:=lerpf(stride,0.14*sin(phase*PI),smoothstep(0.0,1.0,fold))
	var offset:=rig_lean-goal
	var damp:=exp(-8.0*dt)
	var wave:=sin(10.0*dt)
	var c:=cos(10.0*dt)
	var quadrature:=(rig_speed+8.0*offset)/10.0
	rig_lean=goal+damp*(offset*c+quadrature*wave)
	rig_speed=damp*(rig_speed*c-(8.0*quadrature+10.0*offset)*wave)

func draw_on(actor) -> void:
	if actor._dead or actor.embarked_in!=null or not actor._body_bounds.has_area():return
	var box:Rect2=actor._body_bounds
	var heading:float=actor.turret_angle
	var forward:=Iso.dir(Vector2.from_angle(heading))
	var side:=Iso.dir(Vector2.from_angle(heading).orthogonal())
	var center:=box.get_center()
	var r:float=actor.radius
	match skin:
		6: _glass(actor,forward,side,r)
		9: _dial(actor,center,forward,side,r)

const SOLAR_VEINS:=preload("res://assets/cosmetics/skins/sref_solar_veins.png")

func solar_hull(actor,rect:Rect2,frame:int,alpha:float) -> void:
	var tile:=rect.size*2.0
	var region:=Rect2(Vector2(frame%8,frame>>3)*tile,tile)
	actor.draw_texture_rect_region(SOLAR_VEINS,rect,region,Color(0.98,1,1,alpha))
	var shot_age:=1.0-flash/0.32
	for zone in 3:
		region.position.y+=4*tile.y
		var charged:=smoothstep(0.0,1.0,stopped*3-(2-zone))
		var recoil_wave:=maxf(0.0,1.0-absf(shot_age*4-zone)*1.25) if flash>0 else 0.0
		var strength:=maxf(charged*(0.48+0.10*cos(phase*PI-zone*.55)),recoil_wave)
		if strength>0.01:
			actor.draw_texture_rect_region(SOLAR_VEINS,rect,region,Color(0.98,1,1,alpha*strength))

const SOLAR_CORONA:=preload("res://assets/cosmetics/skins/sref_corona.png")

static var leaf_uv:=PackedVector2Array([Vector2(0.01,0.51),Vector2(0.99,0.51),Vector2(0.99,0.99),Vector2(0.01,0.99)])
const ARC_STEPS:=8

static func _corona_arc(actor,sun:Vector2,radius:float,start:float) -> void:
	var points:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for i in ARC_STEPS+1:
		var u:=float(i)/ARC_STEPS
		var ray:=Vector2.from_angle(start+1.34*u)
		points.append(sun+ray*(radius+0.60))
		points.append(sun+ray*(radius-0.60))
		uv.append(Vector2(u,0.008))
		uv.append(Vector2(u,0.49))
		if i>0:
			var n:=i*2
			indices.append_array(PackedInt32Array([n-2,n-1,n,n,n-1,n+1]))
	RenderingServer.canvas_item_add_triangle_array(actor.get_canvas_item(),indices,points,
			PackedColorArray([Color(0.98,1,1)]),uv,PackedInt32Array(),PackedFloat32Array(),SOLAR_CORONA.get_rid())

func _glass(actor,f:Vector2,s:Vector2,r:float) -> void:
	var emitter:=Iso.dir(actor._weapon_muzzle()-actor.global_position)
	var base:=emitter+Vector2.DOWN*3.5-f*1.2
	for i in 3:
		var p:=base+s*(i-1)*r*0.19
		var axis:=s*2.1
		if absf(axis.x)<0.8:axis.x=-0.8 if axis.x<0 else 0.8
		var tip:=Vector2.UP*(3.2+float(i==1))
		var points:=PackedVector2Array([p-tip*0.35,p-axis,p+tip,p+axis])
		actor.draw_colored_polygon(points,Color("#4e6473").lerp(Color("#ffe5ac"),clampf(stopped*3-i,0,1)))
		actor.draw_line(p-axis,p+tip,GOLD,0.9,true)
	# The original three open arcs and six hinged leaves share the emitter pivot.
	var sun:=emitter+Vector2.UP*1.7
	var radius:=3.2+stopped*4.7+flash*10
	var sweep:=phase*TAU/4
	for i in 3:
		var angle:=sweep+i*TAU/3
		_corona_arc(actor,sun,radius,angle)
		var ray:=Vector2.from_angle(angle)
		actor.draw_line(sun+ray*(radius+0.6),sun+ray*(radius+1.8+flash*12),Color("#ffe7a5"),0.9,true)
	if stopped>0.01:
		for i in 6:
			var ray:=Vector2.from_angle(sweep+i*TAU/6)
			var tangent:=ray.orthogonal()
			var root:=sun+ray*(radius-0.8)
			var outer:=root+ray*(3.0+3.0*stopped)
			var leaf:=PackedVector2Array([root-tangent*1.8,outer-tangent,outer+tangent*0.7,root+tangent*2.3])
			# U runs from hinge to tip; the lower material strip is the foil.
			var tint:=Color(0.93,0.90,0.83,stopped) if i%2 else Color(0.98,1,1,stopped)
			actor.draw_polygon(leaf,PackedColorArray([tint]),leaf_uv,SOLAR_CORONA)
	actor.draw_circle(sun,1.0,Color("#fff2bc"))
	if flash>0:
		var k:=flash/0.32
		for i in 3:
			var p:=muzzle+f*(1-k)*5+s*(i-1)*(2.1+2.1*(1-k))
			actor.draw_polyline(PackedVector2Array([p-s*1.5,p+Vector2.UP*3,p+s*1.5]),Color(IVORY,k),1,true)

const PIKA_ATLAS:=preload("res://assets/cosmetics/skins/pikachu_voxel.png")
const PIKA_PIVOT:=Vector2(32,42)

# Use the very same 32-frame index and voxel origin as the native body or turret.
static func _pika_origin(actor,base:Vector2,frame:int) -> Vector2:
	var origin:Array=actor._weapon_art.origins[frame]
	return base+Vector2(origin[0],origin[1])

static func _pika_sprite(actor,pivot:Vector2,frame:int,tail:bool,alpha:float) -> void:
	var cell:=Vector2(frame%8,(frame>>3)+(4 if tail else 0))
	actor.draw_texture_rect_region(PIKA_ATLAS,Rect2(pivot-PIKA_PIVOT,Vector2(64,64)),Rect2(cell*128,Vector2(128,128)),Color(0.98,1,1,alpha))

static func _pika_project(az:float,x:float,y:float,z:float) -> Vector2:
	return Vector2(-x*sin(az)+y*cos(az),0.5*(x*cos(az)+y*sin(az))-z*sqrt(0.75))

func pika_tail(actor,base:Vector2,frame:int,front:bool,alpha:float) -> void:
	if actor._dead or actor.embarked_in!=null:return
	var az:=PI/4-frame*TAU/32
	if (cos(az)<0)!=front:return
	_pika_sprite(actor,_pika_origin(actor,base,frame),frame,true,alpha)

func pika_head(actor,base:Vector2,frame:int,alpha:float) -> void:
	if actor._dead or actor.embarked_in!=null:return
	var pivot:=_pika_origin(actor,base,frame)
	_pika_sprite(actor,pivot,frame,false,alpha)
	var az:=PI/4-frame*TAU/32
	var glow:=clampf(maxf(charge,flash/0.32),0,1)
	if glow>0:
		for flank:float in [-1.0,1.0]:
			var face:=0.72*cos(az)+flank*0.68*sin(az)
			if face<=0.12:continue
			var cheek:=pivot+_pika_project(az,8.8,flank*7.55,13.4)
			actor.draw_texture_rect(STAR_GLOW,Rect2(cheek-Vector2.ONE*3.4,Vector2.ONE*6.8),false,Color(1,0.18,0.05,alpha*glow*face*0.7))
	if flash>0 or charge>0.72 or fmod(phase,1.5)<0.12:
		var left:=pivot+_pika_project(az,-5.3,-11.5,33.1)
		var right:=pivot+_pika_project(az,-5.3,11.5,33.1)
		var arc:=PackedVector2Array([left,left.lerp(right,0.30)+Vector2.UP*(2.6+sin(phase*31)),left.lerp(right,0.58)+Vector2.UP*0.8,left.lerp(right,0.76)+Vector2.UP*3.0,right])
		actor.draw_polyline(arc,Color(1,0.78,0.13,alpha*0.38),1.65,true)
		actor.draw_polyline(arc,Color(1,1,0.81,alpha),0.9,true)

func _dial(actor,c:Vector2,f:Vector2,s:Vector2,r:float) -> void:
	var base:=c+Vector2.DOWN*r*0.10
	_polar_halo(actor,actor._body_bounds,r)
	var ticks:=PackedVector2Array()
	for i in 12:
		var a:=TAU*i/12
		var ray:=(f*cos(a)+s*sin(a))*r*0.51
		ticks.append(base+ray*0.81)
		ticks.append(base+ray)
	actor.draw_multiline(ticks,Color("#24445a"),1.25,true)
	for i in 2:
		var root:=base+s*(1 if i==1 else -1)*r*0.23+f*r*0.25
		var recoil:=flash/0.32 if i==barrel else 0.0
		var slide:=root-f*recoil*3.5
		actor.draw_line(slide,slide+f*4.0,GOLD,2.1,true)
		if recoil>0:
			var tip:=muzzle+f*2
			actor.draw_line(tip-s*3*recoil,tip+s*3*recoil,Color(0.62,0.94,1.0,recoil),1.5,true)
	for i in 3:
		var lit:=air_rack and flash>0 and (0.32-flash)>=0.045*i
		var p:=base-s*r*0.64+f*(i-1)*2.3
		actor.draw_mesh(_dial_lamp(),null,Transform2D(0.0,p),Color("#ffae46") if lit else STEEL)

const STAR_GLOW:=preload("res://assets/cosmetics/weapons/signature_glow.svg")
const CHART_STAR:=preload("res://assets/cosmetics/skins/apoc_chart_star.svg")
const ORBIT_ATLAS:=preload("res://assets/cosmetics/skins/apoc_polar_orbit.png")
const HALO_WIDTH:=1.95
const HALO_LIFT:=2.05

func _polar_halo(actor,box:Rect2,r:float) -> void:
	if halo_open<=0 and first_star<=0 and constellation<=0:return
	var radius:=r*HALO_WIDTH
	var center:=Vector2(box.get_center().x,box.position.y-r*HALO_LIFT+sin(phase*TAU/3)*1.2)
	var strength:=minf(1.0,constellation*2.2)
	var time:=1.35-constellation
	var emitter:=Vector2(center.x,box.position.y+box.size.y*0.24)
	if halo_open>0:
		var open:=smoothstep(0.0,1.0,halo_open)
		_orbit(actor,emitter.lerp(center,open),radius*lerpf(0.08,1.0,open),open,strength)
	# Stars retain their full chart and height even when the orbit retracts.
	var oval:=Vector2(radius,radius*0.40)
	var ring_center:=center+Vector2.DOWN*2
	# A pair of faint moving light sheets ties the projected chart to its emitter.
	if strength>0:
		for flank:float in [-1.0,1.0]:
			var lip:=ring_center+Vector2(flank*radius*0.68,oval.y*0.62)
			var root:=emitter+Vector2(flank*2,0)
			var sheet_pose:=Transform2D(Vector2(3.2,0),lip-root,root)
			actor.draw_mesh(_polar_sheet(),null,sheet_pose,Color(1,1,1,strength))
			for j in 3:
				var t:=fposmod(time*0.78+j/3.0+(0.11 if flank>0 else 0.0),1.0)
				var speck:=emitter.lerp(lip,t)
				actor.draw_line(speck,speck+Vector2.UP*(0.5+t),Color(0.63,0.92,1.0,strength*sin(PI*t)*0.64),0.68,true)
	if first_star<=0 and constellation<=0:return
	var points:=PackedVector2Array()
	var alpha:=strength if constellation>0 else minf(1,first_star*3)
	for i in DIPPER.size():
		if i>0 and (constellation<=0 or time<float(i)*0.045):break
		points.append(center+Vector2(DIPPER[i])*Vector2(radius*0.93,radius*0.83))
	if points.size()>1:
		var path:=points.duplicate()
		if points.size()==DIPPER.size():path.append(points[3])
		actor.draw_polyline(path,Color(0.24,0.65,1.0,alpha*0.20),2.6,true)
		actor.draw_polyline(path,Color(0.65,0.91,1.0,alpha*0.90),0.85,true)
	for i in points.size():
		var ray:=3.7 if i==0 or i==6 else 2.4
		ray*=0.9+0.1*cos(phase*TAU+i)
		var shine:=Color("#ffe7ad") if i==0 else Color("#9aeaff")
		var extent:=Vector2.ONE*ray*4.0
		actor.draw_texture_rect(CHART_STAR,Rect2(points[i]-extent/2,extent),false,Color(shine,alpha))

func _orbit(actor,center:Vector2,radius:float,opacity:float,strength:float) -> void:
	var mist:=Vector2(radius*2.18,radius*0.98)
	actor.draw_texture_rect(STAR_GLOW,Rect2(center-mist/2,mist),false,Color(0.13,0.39,0.88,opacity*(0.21+0.32*strength)))
	var frame:=posmod(roundi(phase*12.0),72)
	var cell:=Vector2(160,72)
	var src:=Rect2(Vector2(frame%12,frame/12)*cell,cell)
	var size:=cell*radius/(2.0*18.0*HALO_WIDTH)
	var dest:=Rect2(center+Vector2.DOWN*2.0-size*0.5,size)
	# Mark these as effect pixels so the vehicle's metal finish does not recolor them.
	var tint:=Color(0.997,1,1,opacity)
	actor.draw_texture_rect_region(ORBIT_ATLAS,dest,src,tint)
	if strength>0:
		src.position.y+=6*cell.y
		tint.a*=strength
		actor.draw_texture_rect_region(ORBIT_ATLAS,dest,src,tint)

# All three tiny lamps share their unchanged 64-segment disk. Rebuilding circles
# on every animated redraw otherwise recreates and uploads this geometry.
static var _dial_lamp_mesh:ArrayMesh
static func _dial_lamp() -> ArrayMesh:
	if _dial_lamp_mesh!=null:return _dial_lamp_mesh
	var vertices:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for i in 65:
		vertices.append(Vector2.from_angle(TAU*i/64.0)*1.05)
	vertices.append(Vector2.ZERO)
	for i in 64:
		indices.append_array(PackedInt32Array([65,i,i+1]))
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_INDEX]=indices
	_dial_lamp_mesh=ArrayMesh.new()
	_dial_lamp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _dial_lamp_mesh

# Stretch one shared gradient triangle between the emitter and chart lip.
static var _polar_sheet_mesh:ArrayMesh
static func _polar_sheet() -> ArrayMesh:
	if _polar_sheet_mesh!=null:return _polar_sheet_mesh
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector2Array([Vector2.ZERO,Vector2(-1,1),Vector2(1,1)])
	arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(0.27,0.78,1,0),Color(0.24,0.64,1,0.10),Color(0.52,0.91,1,0.025)])
	_polar_sheet_mesh=ArrayMesh.new()
	_polar_sheet_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _polar_sheet_mesh
