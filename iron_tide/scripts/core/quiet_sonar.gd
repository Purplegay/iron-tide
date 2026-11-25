extends Node2D
const ID := "quiet_sonar"
const LAUNCH_SECONDS := 0.55
const ECHO_SECONDS := 1.05
const IMPACT_SECONDS := 1.42
const APPARITION := preload("res://assets/cosmetics/weapons/cthulhu_echo.svg")
const VIOLET := Color("#aa81ff")
const ABYSS := Color("#0b1439")
const DEEP := Color("#12657d")
const AQUA := Color("#45d9d2")
const FOAM := Color("#ddfff7")
var launch := false
var age := 0.0
var axis := Vector2.RIGHT
var preview_span := Vector2.ZERO
var ripple_offset := 0.0
static var lip_indices:=PackedInt32Array()

static func spawn(host:Node,point:Vector2,at_launch:bool,direction:=Vector2.RIGHT,delay:=0.0,sample_span:=Vector2.ZERO) -> void:
	if not is_instance_valid(host):return
	var fx=load("res://scripts/core/quiet_sonar.gd").new()
	fx.launch=at_launch
	fx.axis=Iso.dir(direction).normalized()
	fx.position=point
	fx.age=-delay
	fx.preview_span=Iso.dir(sample_span)
	fx.ripple_offset=fmod(float(fx.get_instance_id()%31)*0.24,TAU)
	host.add_child(fx)

func _process(delta:float) -> void:
	age+=delta
	if age>=(LAUNCH_SECONDS if launch else IMPACT_SECONDS):queue_free()
	else:queue_redraw()

func _draw() -> void:
	if age<0:return
	Iso.begin(self)
	if launch:
		_draw_wake(age/LAUNCH_SECONDS)
		if preview_span!=Vector2.ZERO and age<0.35:
			var travel:=age/0.35
			draw_flight(self,preview_span*travel,axis,age,minf(1.0,preview_span.length()*travel/30.0))
	else:_draw_hit(minf(age/ECHO_SECONDS,1.0))

func _draw_wake(t:float) -> void:
	var fade:=1-smoothstep(0.32,1,t)
	# A pressure gate opens edge-on at the launch tube; the torpedo clears its center.
	var gate:=PackedVector2Array()
	var radius:=3+6*sin(PI*t)
	for i in 25:
		var angle:=TAU*i/24
		gate.append(axis*cos(angle)*radius*0.36+axis.orthogonal()*sin(angle)*radius)
	draw_polyline(gate,Color(VIOLET,fade*0.45),3,true)
	draw_polyline(gate,Color(AQUA,fade),1.2,true)
	for side in [-1,1]:
		for i in 6:
			var along:=3+i*2.8+t*(7+i)
			var across:float=side*(1.6+t*3)+sin(i*2+t*6)*t*1.4
			var p:Vector2=-axis*along+axis.orthogonal()*across+Vector2.UP*t*(3+i)
			var r:=0.7+0.25*(i%3)+t
			draw_arc(p,r,0,TAU,10,Color(AQUA,fade*0.8),1,true)
			draw_circle(p+Vector2(-0.35,-0.45)*r,0.55,Color(FOAM,fade))

# Two out-of-phase pressure strands taper into the torpedo's wake.
static func draw_flight(canvas:CanvasItem,tip:Vector2,forward:Vector2,seconds:float,length_scale:float) -> void:
	if length_scale<=0 or forward.is_zero_approx():return
	var normal:=forward.orthogonal()
	for strand in 2:
		var points:=PackedVector2Array()
		var colors:=PackedColorArray()
		var tint:=AQUA if strand==0 else VIOLET
		for i in 19:
			var u:=float(i)/18
			var offset:=sin(u*TAU*1.4-seconds*11+strand*PI)*(1+3*u)
			points.append(tip+(-forward*(2+29*u)+normal*offset)*length_scale)
			colors.append(Color(tint,(1-u)*0.94))
		canvas.draw_polyline_colors(points,colors,1.8,true)
	canvas.draw_line(tip-forward*5*length_scale,tip,FOAM,1.5,true)

func _draw_lens(t:float) -> void:
	var power:=sin(PI*pow(t,0.72))
	var center:=Vector2.UP*(6+10*power)
	var radius:=15*power
	if radius<0.4:return
	var tilt:=-0.48+t*0.28
	var rim:=PackedVector2Array()
	var inner:=PackedVector2Array()
	for i in 41:
		var a:=TAU*i/40
		rim.append(center+Vector2(cos(a),sin(a)*0.65).rotated(tilt)*radius)
		inner.append(center+Vector2(cos(a),sin(a)*0.48).rotated(tilt)*radius*0.73)
	draw_colored_polygon(rim.slice(0,40),Color(ABYSS,power*0.93))
	draw_polyline(rim,Color(VIOLET,power),2.0,true)
	draw_polyline(inner,Color(AQUA,power*0.8),1.0,true)
	# The scanning arcs cross the lens at two depths and collapse with it.
	for arm in 2:
		var arc:=PackedVector2Array()
		for i in 16:
			var a:=t*4.5+arm*PI+float(i)/15*1.85
			arc.append(center+Vector2(cos(a),sin(a)*0.26).rotated(-0.62)*radius*1.65)
		draw_polyline(arc,Color(AQUA if arm==0 else VIOLET,power*0.3),4,true)
		draw_polyline(arc,Color(FOAM if arm==0 else VIOLET,power),1.3,true)
		draw_circle(arc[-1],1.5,Color(FOAM,power))

func _draw_apparition() -> void:
	var rise:=smoothstep(0.28,0.70,age)*(1.0-smoothstep(1.0,IMPACT_SECONDS,age))
	if rise<0.015:return
	var size:=Vector2(65,47)
	var waterline:=Vector2(0,2)
	var crest:=waterline+Vector2(sin(age*5)*1.3,-size.y*rise)
	# Curl the outer tentacles behind the wings, staying inside the impact ripples.
	for side in [-1.0,1.0]:
		var curl:=PackedVector2Array()
		for j in 17:
			var u:=j/16.0
			var a:=u*4.8+0.38*sin(age*7.0+side)
			var reach:=14.0+22*u+sin(a)*6*u
			var lift:=(7.0+13*u+cos(a)*9*u)*rise
			curl.append(waterline+Vector2(side*reach,-lift))
		draw_polyline(curl,Color(ABYSS,rise),3.1,true)
		draw_polyline(curl,Color(AQUA,rise*0.82),1.1,true)
	# Reveal the original proportions above the surface instead of stretching the face.
	var extent:=Vector2(1,rise)
	draw_texture_rect_region(APPARITION,Rect2(crest-Vector2(size.x/2,0),size*extent),
		Rect2(Vector2.ZERO,APPARITION.get_size()*extent),Color(Color.WHITE,smoothstep(0.0,0.36,rise)*0.96))
	var wake:=PackedVector2Array()
	for i in 19:
		var a:=PI*i/18
		wake.append(waterline+Vector2(cos(a)*24,sin(a)*3)*rise)
	draw_polyline(wake,Color(AQUA,0.72*rise),1.4,true)

func _draw_hit(t:float) -> void:
	# Surface pressure flash, then a raised lip of water with a darker cavity.
	var crest:=1-smoothstep(0.17,0.57,t)
	var rise:=smoothstep(0,0.16,t)
	if crest>0:
		if lip_indices.is_empty():
			for i in 40:
				var j:=2*i
				lip_indices.append_array([j,j+2,j+3,j,j+3,j+1])
		var surface:=PackedVector2Array()
		var colors:=PackedColorArray()
		var rim:=PackedVector2Array()
		for i in 41:
			var a:=TAU*i/40
			var dir:=Vector2(cos(a),sin(a)*0.46)
			var height:=pow(maxf(0,sin(7*a+ripple_offset)),3)*(7+11*rise)*crest
			rim.append(dir*(5+14*rise)+Vector2.UP*height)
			surface.append(dir*(4+10*rise)+Vector2.DOWN*2)
			surface.append(rim[i])
			colors.append(Color(DEEP,crest*0.85))
			colors.append(Color(AQUA,crest))
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),lip_indices,surface,colors)
		draw_polyline(rim,Color(FOAM,crest),1.7,true)
		var core:=1-smoothstep(0.06,0.26,t)
		draw_circle(Vector2.ZERO,3+3*core,Color(FOAM,core))
	for ring in 2:
		var phase:=(t-ring*0.12)/(1-ring*0.12)
		if phase<0:continue
		var radius:=4+37*ease(phase,0.52)
		var fade:=(1-smoothstep(0.38,1,phase))*(1-0.25*ring)
		for part in 6:
			var points:=PackedVector2Array()
			for i in 8:
				var a:=TAU*part/6+0.13+0.82*i/7+ring*0.19
				points.append(Vector2(cos(a),sin(a)*0.46)*radius)
			draw_polyline(points,Color(DEEP,0.62*fade),2.8,true)
			draw_polyline(points,Color(AQUA,fade),1.25,true)
	_draw_lens(t)
	_draw_apparition()
	# Streaks turn into individual falling droplets; residual bubbles drift upwards.
	for i in 15:
		var a:=ripple_offset+i*2.39996
		var dir:=Vector2(cos(a),sin(a)*0.46)
		var life:=0.5+0.05*(i%5)
		var p:=t/life
		if p>=1:continue
		var h:=float(13+(i*7)%24)
		var pos:=dir*(3+p*(12+(i*11)%20))+Vector2.UP*h*4*p*(1-p)
		var velocity:=dir*18+Vector2.UP*h*4*(1-2*p)
		var fade:=1-smoothstep(0.65,1,p)
		draw_line(pos-velocity.normalized()*(1+(1-p)*3),pos,Color(AQUA,fade),2.1,true)
		draw_circle(pos,0.95 if i%2 else 1.45,Color(FOAM,fade))
	if t>0.30:
		var p:=(t-0.30)/0.70
		for i in 8:
			var a:=i*2.39996+ripple_offset
			var pos:=Vector2(cos(a)*(7+9*p),sin(a)*4-p*(8+i))
			draw_arc(pos,0.8+p*(1+i%2),0,TAU,10,Color(AQUA,0.8*sin(p*PI)),1,true)
