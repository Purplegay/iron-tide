extends Node2D
## Optional workshop look for the Apocalypse primary cannon.
const ID := "blue_arc"
const BLUE := Color("#3778ff")
const CYAN := Color("#83e4ff")
const CORE := Color("#edffff")
const FLARE := preload("res://assets/ra3/expansion/fx/FXLenzflareHDR01.png")
const SMOKE := preload("res://assets/ra3/soviet/tank_fx/FXSmoke01.png")
const FLAME_SECONDS := 0.36
const MUZZLE_LIFE := 0.86
const IMPACT_LIFE := 0.72
const WARP_HOLD := 1.5
const WARP_LIFE := IMPACT_LIFE + WARP_HOLD
const GROUND_RADIUS := 60.0
const WARP_HEIGHT := 44.0
const GROUND_NORMAL := preload("res://assets/ra3/expansion/fx/FXSphereNRM.png")
var ground_copy:BackBufferCopy
var air_copy: BackBufferCopy
var heat_wave: Sprite2D
var ground_wave:Sprite2D
static var flare_material:ShaderMaterial
var phase := 0.0
var muzzle := false
var heading := 0.0
var age := 0.0

static func spawn(host:Node,point:Vector2,at_muzzle:bool,yaw:=0.0,delay:=0.0,ground_offset:=Vector2.ZERO,foundation:=false) -> void:
	var fx=load("res://scripts/core/blue_arc_fx.gd").new()
	if flare_material==null:
		flare_material=ShaderMaterial.new()
		flare_material.shader=preload("res://shaders/blue_arc_fx.gdshader")
	fx.material=flare_material
	fx.phase=fmod(float(fx.get_instance_id()%997)*2.4,TAU)
	fx.position=point
	fx.muzzle=at_muzzle
	fx.heading=yaw
	fx.age=-delay
	if foundation:
		fx.z_as_relative = false
		fx.z_index = DepthLayers.GROUND_OBJ + 3
	else: fx.z_index=2
	host.add_child(fx)
	if not at_muzzle:
		fx._make_ground_wave(ground_offset,host.is_in_group("effects_root"))

static func battle_event(world,point:Vector2,at_muzzle:bool,yaw:=0.0,ground_offset:=Vector2.ZERO,foundation:=false) -> void:
	if DisplayServer.get_name()=="headless" or not world.position_visible_to("ally",point):return
	spawn(world.effects_root,point,at_muzzle,yaw,0.0,ground_offset,foundation)

func _make_ground_wave(offset:Vector2,on_battlefield:bool) -> void:
	# The compatibility renderer may leave partial screen copies black under a
	# transformed canvas. All battlefield swirls sample one copy below the actors.
	var host:=get_parent().get_parent() if on_battlefield else self
	ground_copy = _shared_copy(host,"BlueArcGroundCopy",DepthLayers.GROUND_OBJ+1,on_battlefield)
	if on_battlefield:
		# Capture the finished ground actors before drawing airborne actors or the HUD.
		air_copy = _shared_copy(host,"BlueArcActorCopy",DepthLayers.AIR-2,true)
	ground_wave=Sprite2D.new()
	ground_wave.position=offset
	ground_wave.show_behind_parent=true
	if on_battlefield:
		ground_wave.z_as_relative=false
		ground_wave.z_index=DepthLayers.GROUND_OBJ+2
	ground_wave.texture=GROUND_NORMAL
	var warp:=ShaderMaterial.new()
	warp.shader=preload("res://shaders/blue_arc_ground.gdshader")
	ground_wave.material=warp
	add_child(ground_wave)
	if on_battlefield:
		warp.set_shader_parameter("separate_heat",true)
		heat_wave = Sprite2D.new()
		heat_wave.texture = GROUND_NORMAL
		heat_wave.z_as_relative = false
		heat_wave.z_index = DepthLayers.AIR-1
		var air_material := ShaderMaterial.new()
		air_material.shader = warp.shader
		air_material.set_shader_parameter("air_only",true)
		heat_wave.material = air_material
		ground_wave.add_child(heat_wave)
	ground_wave.hide()
	tree_exiting.connect(_release_ground_wave)

func _shared_copy(host: Node, id: String, depth: int, use_depth: bool) -> BackBufferCopy:
	var copy := host.get_node_or_null(id) as BackBufferCopy
	if copy == null:
		copy = BackBufferCopy.new()
		copy.name = id
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		copy.show_behind_parent = true
		if use_depth:
			copy.z_as_relative = false
			copy.z_index = depth
		host.add_child(copy)
		copy.hide()
	return copy

func _update_ground_wave() -> void:
	var buildup := smoothstep(IMPACT_LIFE*0.29, IMPACT_LIFE*0.54, age)
	var release := smoothstep(IMPACT_LIFE*0.68 + WARP_HOLD, WARP_LIFE, age)
	var strength := buildup * (1.0-release)
	var active:=strength>0.001
	if ground_wave.visible!=active:
		ground_wave.visible=active
		_count_active_waves(1 if active else -1)
	if not active:return
	var radius:=GROUND_RADIUS*lerpf(1.0,0.46,smoothstep(IMPACT_LIFE*0.50 + WARP_HOLD, WARP_LIFE, age))
	var rise := WARP_HEIGHT / GROUND_RADIUS * buildup * (1.0-release)
	var half_height := Iso.K + rise*0.5
	ground_wave.rotation = Iso.eff_angle()
	ground_wave.scale = Vector2(2*radius/GROUND_NORMAL.get_width(), 2*radius*half_height*Iso.inv_k()/GROUND_NORMAL.get_height())
	# Expand the sprite upwards while leaving its ground contact at its node origin.
	ground_wave.offset.y = -GROUND_NORMAL.get_height()*rise/(4.0*half_height)
	ground_wave.material.set_shader_parameter("squash", Iso.K)
	ground_wave.material.set_shader_parameter("rise", rise)
	ground_wave.material.set_shader_parameter("flame", buildup*(1.0-smoothstep(0.6,WARP_LIFE,age)))
	ground_wave.material.set_shader_parameter("strength",strength)
	ground_wave.material.set_shader_parameter("swirl_angle", age * 2.4)
	if heat_wave != null:
		heat_wave.offset = ground_wave.offset
		heat_wave.material.set_shader_parameter("squash",Iso.K)
		heat_wave.material.set_shader_parameter("rise",rise)
		heat_wave.material.set_shader_parameter("strength",strength)
		heat_wave.material.set_shader_parameter("swirl_angle",age*2.4)

func _count_active_waves(change:int) -> void:
	var count:=int(ground_copy.get_meta("active_waves",0))+change
	ground_copy.set_meta("active_waves",count)
	ground_copy.visible=count>0
	if is_instance_valid(air_copy): air_copy.visible=count>0

func _release_ground_wave() -> void:
	if is_instance_valid(ground_copy) and is_instance_valid(ground_wave) and ground_wave.visible:
		_count_active_waves(-1)

func _process(delta:float) -> void:
	age+=delta
	if age>=(MUZZLE_LIFE if muzzle else WARP_LIFE):queue_free()
	else:
		if ground_copy!=null:_update_ground_wave()
		if muzzle or age - delta < IMPACT_LIFE: queue_redraw()

func _draw() -> void:
	if age<0:return
	Iso.begin(self)
	if muzzle:
		_draw_muzzle()
	elif age < IMPACT_LIFE:
		_draw_impact(clampf(age/IMPACT_LIFE,0,1))

func _glow(at:Vector2,size:Vector2,color:Color) -> void:
	draw_texture_rect(FLARE,Rect2(at-size/2,size),false,color)

func _draw_muzzle() -> void:
	var axis:=Iso.dir(Vector2.from_angle(heading)).normalized()
	var side:=axis.orthogonal()
	# Smoke follows the jet, expanding and drifting upward after each barrel fires.
	for i in 8:
		var t:=(age-0.015*i)/(MUZZLE_LIFE-0.015*i)
		if t<=0 or t>=1:continue
		var curl:=sin(phase+i*1.6+t*4)
		var center:=axis*(5+i*4.6+t*(10+i))+side*curl*(1+5*t)+Vector2.UP*18*t*t
		var diameter:=10+24*t+3*absf(curl)
		var alpha:=smoothstep(0,0.12,t)*(1-smoothstep(0.37,1,t))
		var ash:=Color("#506680").lerp(Color("#b2c5d1"),t)
		draw_texture_rect(SMOKE,Rect2(center-Vector2.ONE*diameter/2,Vector2.ONE*diameter),false,Color(ash,alpha*0.78))
	if age>=FLAME_SECONDS:return
	var t:=clampf(age/FLAME_SECONDS,0,1)
	var flare:=1-smoothstep(0.23,0.94,t)
	if flare>0:
		var reach:=lerpf(24,61,smoothstep(0,0.25,t))*(1-0.30*smoothstep(0.50,0.94,t))
		var width:=10*flare
		var waist:=axis*reach*0.34
		_glow(waist,Vector2(80,55),Color(BLUE,0.88*flare))
		# A broad blue envelope forks around the white-hot central jet.
		for sign_y in [-1,1]:
			var edge:Vector2=side*sign_y
			var flicker:=sin(phase+sign_y+t*20)
			var tongue:=PackedVector2Array([Vector2.ZERO,waist+edge*width,
				axis*reach*0.72+edge*width*0.86,axis*reach*(0.87+flicker*0.06)+edge*width*0.66,
				axis*reach*0.64+edge*width*0.33,axis*reach,waist-edge*width*0.30])
			draw_colored_polygon(tongue,Color(BLUE,flare))
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO,waist+side*width*0.56,axis*reach,waist-side*width*0.56]),Color(CYAN,flare))
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO,waist+side*width*0.25,axis*reach*0.82,waist-side*width*0.25]),Color(CORE,flare))
	var fade:=1-smoothstep(0.45,1,t)
	for i in 15:
		var spread:=sin(i*2.4+phase)
		var ray:=axis.rotated(spread*0.82)
		var speed:=18.0+float((i*13)%26)
		var pos:=ray*(2.0+speed*t)+side*spread*5*t*t
		var tint:=CYAN if i%3 else BLUE
		draw_line((pos-ray*(2+4*(1-t))).round(),pos.round(),Color(tint,fade),2 if i%3==0 else 1)
		if i%3==0:draw_rect(Rect2(pos.round(),Vector2(2,2)),Color(CORE,fade))

func _draw_impact(t:float) -> void:
	var fade:=1-smoothstep(0.52,1,t)
	var flash:=1-smoothstep(0.04,0.55,t)
	var expansion:=smoothstep(0,0.28,t)
	var radius:float=lerpf(6,29,expansion)*(1-smoothstep(0.37,0.94,t))
	_glow(Vector2.ZERO,Vector2(82,68)*(0.5+0.5*expansion),Color(BLUE,0.9*fade))
	_glow(Vector2.ZERO,Vector2(52,40)*(1+0.3*t),Color(CYAN,flash))
	# A low expanding shock front breaks apart while the brighter arcs curl back in.
	var wave:=1-smoothstep(0.18,0.72,t)
	if wave>0:
		for arc in 5:
			var ring:=PackedVector2Array()
			for j in 10:
				var angle:=arc*TAU/5+float(j)*0.116+phase
				ring.append(Vector2.from_angle(angle)*Vector2(1,0.60)*(5+35*ease(t,0.5)))
			draw_polyline(ring,Color(CYAN,wave*0.75),1.5,true)
	for arm in 3:
		var path:=PackedVector2Array()
		for step in 13:
			var f:=step/12.0
			var angle:=phase+arm*TAU/3+t*5.6-f*1.85
			var kink:=1.0 if step%2==0 else 0.75+0.08*sin(phase+arm+t*27)
			var point:=Vector2.from_angle(angle)*radius*(1-f*0.76)*kink
			path.append((point/1.5).round()*1.5)
		draw_polyline(path,Color(BLUE,fade),4)
		draw_polyline(path,Color(CYAN,fade),1.5)
		draw_line(path[3],path[3]*1.24+Vector2(2,-3),Color(CORE,fade),1.5)
	# Low, fast streaks give way to slower tumbling, gravity-driven blue embers.
	for i in 20:
		var angle:=phase+i*2.39996
		var v:=Vector2(cos(angle),sin(angle)*0.62-0.35)*(22+(i*13)%34)
		var pos:=(v*t+Vector2.DOWN*16*t*t).round()
		var opacity:=1-smoothstep(0.45+0.02*(i%7),1,t)
		draw_line(pos-v.normalized()*4*(1-t),pos,Color(BLUE,opacity),2)
		draw_rect(Rect2(pos,Vector2.ONE*(2 if i%3 else 3)),Color(CYAN if i%2 else CORE,opacity))
	if flash>0:
		draw_line(Vector2(-6,0)*flash,Vector2(6,0)*flash,Color(CORE,flash),2)
		draw_line(Vector2(0,-9)*flash,Vector2(0,9)*flash,Color(CORE,flash),2)
