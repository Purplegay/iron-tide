extends RefCounted
## Fixed pins in TNKD.VXL; both emissive banks reuse the armor's depth-clipped 32 directions.
const PLATES:=preload("res://assets/cosmetics/skins/tnkd_casemate.png")
const NEON:=preload("res://assets/cosmetics/skins/tnkd_neon_hd.png")
const GLOW:=preload("res://assets/cosmetics/skins/tnkd_glow.png")
const RED_GLOW:=Color("#ff2244")
const BLUE_GLOW:=Color("#187bff")
const GAS:=preload("res://assets/cosmetics/mounts/future_phase_exhaust.png")
# Different periods and offsets keep the four main tubes out of lockstep.
const BEAT_PERIOD := [1.24,1.47,1.36,1.59]
const BEAT_OFFSET := [0.03,0.48,0.71,0.24]
const SWAP_OFFSET := [0.0,0.55,0.85,0.29]
static func heartbeat(seconds:float,lamp:int) -> float:
	var t:=fposmod(seconds/float(BEAT_PERIOD[lamp])+float(BEAT_OFFSET[lamp]),1.0)
	var first:=smoothstep(0.0,0.09,t)*(1.0-smoothstep(0.09,0.27,t))
	var echo:=smoothstep(0.26,0.34,t)*(1.0-smoothstep(0.34,0.69,t))
	return 0.34+0.66*first+0.44*echo

const LIGHT_COAST_SECONDS := 3.0
var light_time := 0.0
var light_rate := 0.0

func advance_lights(active:bool,delta:float) -> bool:
	var previous:=light_time
	if active:
		light_rate=1.0
		light_time+=delta
	elif light_rate>0:
		var elapsed:=minf(delta,light_rate*LIGHT_COAST_SECONDS)
		var next_rate:=maxf(0.0,light_rate-delta/LIGHT_COAST_SECONDS)
		light_time+=elapsed*(light_rate+next_rate)*0.5
		light_rate=next_rate
		if light_rate==0:return true
	return floori(previous*30)!=floori(light_time*30)

func armor(actor,rect:Rect2,src:Rect2,frame:int,alpha:float) -> void:
	var tile:=Rect2(src.position*2,src.size*2)
	actor.draw_texture_rect_region(PLATES,rect,tile,Color(0.98,1,1,alpha))
	# The static metal and glass sit beneath eight independently lit tubes.
	var pin:Array=actor._weapon_art.origins[frame]
	var panel:=Rect2(rect.position+Vector2(pin[0]-40,pin[1]-38),Vector2(80,56))
	var uv:=Rect2(Vector2(frame%8,frame>>3)*Vector2(640,448),Vector2(640,448))
	actor.draw_texture_rect_region(NEON,panel,uv,Color(0.98,1,1,alpha))
	var glow_uv:=Rect2(Vector2(frame%8,frame>>3)*Vector2(160,112),Vector2(160,112))
	for tube in 8:
		var lamp:=tube%4
		var cannon:=tube>=4
		var local_cycle:=fposmod(light_time+float(SWAP_OFFSET[lamp]),8.0)
		var change:=smoothstep(3.0,4.0,local_cycle)-smoothstep(7.0,8.0,local_cycle)
		var red_first:bool=(lamp%2==0) if cannon else (lamp==0 or lamp==3)
		var tint:=RED_GLOW.lerp(BLUE_GLOW,change if red_first else 1.0-change)
		var intensity:=heartbeat(light_time,lamp) if cannon else 0.72-0.28*cos(TAU*(light_time/5.0+float(BEAT_OFFSET[lamp])))
		tint.a=alpha*intensity
		actor.draw_texture_rect_region(GLOW,panel,glow_uv,tint)
		var filament_uv:=Rect2(glow_uv.position+Vector2.DOWN*glow_uv.size.y*32,glow_uv.size)
		var core:=tint.lightened(0.78)
		core.a=alpha*intensity
		actor.draw_texture_rect_region(GLOW,panel,filament_uv,core)
		glow_uv.position.y+=glow_uv.size.y*4

# TNKD's baked DUMMY01 turbine is centred at (-20,0,13.5). Its rear cap
# is another 6.37 units aft, with a 6.85-unit outer metal lip.
const CAP_X := -26.37
const CAP_Z := 13.5
const RING_RADIUS := 5.35
const STEPS := 9
const ROTOR := preload("res://assets/cosmetics/skins/tnkd_rotor.png")
const WINDUP := 1.2
var powered_time := 0.0
var rotor_angle := 0.0
var orbit_angle := 0.0
var thrust := 0.0
var engaging := false
var bend := 0.0
var last_heading := NAN

func tick(actor, delta:float) -> void:
	if delta<=0:return
	var heading:float=actor.hull_angle
	var turn_rate:=0.0 if is_nan(last_heading) else angle_difference(last_heading,heading)/delta
	last_heading=heading
	var speed:=clampf(actor.velocity.length()/maxf(actor.move_speed,1.0),0.0,1.0)
	# Tracked vehicles can turn on the spot with zero linear velocity.
	var demand:=maxf(speed,clampf(absf(turn_rate)*0.5,0,0.85))
	engaging = actor._muzzle > 0.0 or (is_instance_valid(actor.attack_target) and actor._stun_timer <= 0.0
		and actor.embarked_in == null and not AlliedAbilities.frozen(actor) and actor._weapon_target_valid(actor.attack_target))
	if engaging and actor.velocity.is_zero_approx():
		# Aiming turns the fixed gun with the hull; it is not a driving pivot.
		demand = 0.0
		thrust = 0.0
		powered_time = 0.0
	else:
		thrust=move_toward(thrust,demand,delta*(7.0 if demand>thrust else 3.5))
	if demand>0.04:
		powered_time=minf(powered_time+delta,1.9)
	else:
		powered_time=maxf(powered_time-delta*5,0)
	rotor_angle=fposmod(rotor_angle+delta*TAU*3.2*thrust,TAU)
	orbit_angle=fposmod(orbit_angle+delta*TAU/WINDUP*(1.0 if demand>0.04 else thrust),TAU)
	bend=lerpf(bend,clampf(turn_rate*0.28,-1,1),1.0-exp(-delta*7.0))

func flame_visible(actor) -> bool:
	# A shot can start on the tick that crosses into range, before velocity is reset.
	return thrust >= 0.01 and actor._muzzle <= 0.0 and not (engaging and actor.velocity.is_zero_approx())

func exhaust(actor,base:Vector2,frame:int,alpha:float,behind:bool) -> void:
	if actor._dead or actor.embarked_in!=null:return
	if thrust<0.01 and is_zero_approx(rotor_angle):return
	var az:=PI/4-frame*TAU/32
	var aft:=Vector2(sin(az),-0.5*cos(az))
	if (aft.y < -0.0001)!=behind:return
	var lateral:=Vector2(cos(az),0.5*sin(az))
	var vertical:=Vector2.UP*sqrt(0.75)
	var pin:Array=actor._weapon_art.origins[frame]
	var center:=base+Vector2(pin[0],pin[1])-CAP_X*aft+CAP_Z*vertical
	if aft.y>0.01:
		draw_rotor(actor,center,lateral,vertical,alpha)
	if not flame_visible(actor):return
	var afterburn:=smoothstep(WINDUP,1.9,powered_time)
	var phase:=orbit_angle
	var vertices:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	# One leading tongue and two shorter tongues orbit the open hub. A strip's
	# two edges are projected from the same model-space radius as the metal rim.
	for strand in 3:
		var start:=phase+strand*TAU/3
		var reach:=lerpf(3.5,float([13.0,10.5,8.5][strand]),afterburn)
		# At the lip the wide flame foot curls along the rim before lifting off.
		# Its downstream cross-section turns to face the viewer so a tongue
		# never vanishes edge-on as the hull rotates.
		var first:=vertices.size()
		for step in STEPS+1:
			var t:=float(step)/STEPS
			var angle:=start-t*(2.4+0.45*thrust)
			var radial:=lateral*cos(angle)+vertical*sin(angle)
			var radius:=RING_RADIUS*(1.0-0.50*t)
			var width:=(1.9+sin(PI*t)*(2.8+1.8*afterburn))*(1.0-0.85*t)*thrust
			var advance:=t*t*(2.0-t)
			var sweep:=lerpf(10.0,5.0,afterburn)*bend*thrust
			var spine:=center+radial*radius+aft*advance*reach*thrust+lateral*sweep*t*t
			var around:=(lateral*sin(angle)-vertical*cos(angle))*(2.4+0.45*thrust)
			var tangent:=around*radius-radial*RING_RADIUS*0.50+aft*(4*t-3*t*t)*reach*thrust+lateral*sweep*2*t
			var normal:=tangent.orthogonal().normalized()
			vertices.append(spine-normal*width)
			vertices.append(spine+normal*width)
			uv.append(Vector2(t,0.14))
			uv.append(Vector2(t,0.86))
			if step>0:
				var n:=first+step*2
				indices.append_array(PackedInt32Array([n-2,n-1,n,n,n-1,n+1]))
	# The shader reserves this modulation for blue exhaust on any house colour.
	RenderingServer.canvas_item_add_triangle_array(actor.get_canvas_item(),indices,vertices,
			PackedColorArray([Color(0.73,0.98,1,alpha*thrust)]),uv,PackedInt32Array(),PackedFloat32Array(),GAS.get_rid())
	if afterburn>0.001:
		draw_jet(actor,center,aft,lateral,alpha,afterburn)

func draw_rotor(actor,center:Vector2,lateral:Vector2,vertical:Vector2,alpha:float) -> void:
	# Spin only the blade disk inside the stationary housing. Match the
	# bake's cap UVs (tile 0, 1% inset) at zero rotation.
	var vertices:=PackedVector2Array([center])
	var uv:=PackedVector2Array([Vector2(0.49,0.49)])
	var indices:=PackedInt32Array()
	for i in 25:
		var angle:=TAU*i/24.0
		var r:=5.25
		vertices.append(center+r*(lateral*cos(angle)+vertical*sin(angle)))
		uv.append(Vector2(0.49,0.49)+Vector2(cos(angle-rotor_angle),-sin(angle-rotor_angle))*(0.48*r/6.85))
		if i>0:indices.append_array(PackedInt32Array([0,i,i+1]))
	RenderingServer.canvas_item_add_triangle_array(actor.get_canvas_item(),indices,vertices,
			PackedColorArray([Color(0.98,1,1,alpha)]),uv,PackedInt32Array(),PackedFloat32Array(),ROTOR.get_rid())

func draw_jet(actor,center:Vector2,aft:Vector2,lateral:Vector2,alpha:float,afterburn:float) -> void:
	var vertices:=PackedVector2Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var power:=afterburn*thrust
	var length_scale:=(20.0+0.8*sin(orbit_angle*4))*power
	for i in STEPS+1:
		var t:=float(i)/STEPS
		var shift:=lateral*(bend*8+sin(orbit_angle*3-t*5)*0.75)*power
		var spine:=center+aft*length_scale*t+shift*t*t
		var normal:=(aft*length_scale+shift*2*t).orthogonal().normalized()
		var width:=(5.1+11.0*sin(PI*t))*(1.0-0.55*t)*power
		vertices.append(spine-normal*width)
		vertices.append(spine+normal*width)
		uv.append(Vector2(t,0.08))
		uv.append(Vector2(t,0.92))
		if i>0:
			var n:=i*2
			indices.append_array(PackedInt32Array([n-2,n-1,n,n,n-1,n+1]))
	RenderingServer.canvas_item_add_triangle_array(actor.get_canvas_item(),indices,vertices,
			PackedColorArray([Color(0.73,0.98,1,alpha*power)]),uv,PackedInt32Array(),PackedFloat32Array(),GAS.get_rid())
