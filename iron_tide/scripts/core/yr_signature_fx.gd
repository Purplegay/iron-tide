extends Node2D
## Player-authored YR weapon looks. Each event follows its weapon's own timing.
const FRACTURE_ATLAS:=preload("res://assets/cosmetics/weapons/apoc_molten_fracture.png")
const SMOKE := preload("res://assets/ra3/soviet/tank_fx/FXSmoke01.png")
const GLOW := preload("res://assets/cosmetics/weapons/signature_glow.svg")
const EMBER := Color("#ff662d")
const GOLD := Color("#ffe28b")
const ICE := Color("#8ff5ff")
# Small workshop sky charts: branches use indices into each pattern's star list.
const ZODIAC := [
	["白羊座",[Vector2(-44,-11),Vector2(4,-3),Vector2(29,8),Vector2(34,19)],[[0,1,2,3]]],
	["金牛座",[Vector2(-46,-24),Vector2(-17,-2),Vector2(-7,12),Vector2(7,-1),Vector2(41,-20),Vector2(16,19),Vector2(-28,23)],[[0,1,2,3,4],[3,5],[2,6]]],
	["双子座",[Vector2(-29,-24),Vector2(-11,-10),Vector2(4,8),Vector2(20,24),Vector2(-1,-26),Vector2(15,-12),Vector2(26,5),Vector2(42,13),Vector2(-18,17)],[[0,1,2,3],[4,5,6,7],[1,5],[2,8]]],
	["巨蟹座",[Vector2(-28,-25),Vector2(-4,-6),Vector2(3,4),Vector2(-32,24),Vector2(33,22)],[[0,1,2,3],[2,4]]],
	["狮子座",[Vector2(36,-19),Vector2(23,-25),Vector2(10,-14),Vector2(15,-2),Vector2(26,6),Vector2(19,20),Vector2(-39,10),Vector2(-15,-5)],[[0,1,2,3,4,5,6,7,3]]],
	["室女座",[Vector2(-43,-18),Vector2(-18,-9),Vector2(0,2),Vector2(17,14),Vector2(40,23),Vector2(23,-16),Vector2(10,-20),Vector2(-14,19)],[[0,1,2,3,4],[2,6,5],[1,7]]],
	["天秤座",[Vector2(-37,0),Vector2(-4,-23),Vector2(27,-8),Vector2(8,7),Vector2(-23,22),Vector2(40,18)],[[0,1,2,3,0],[0,4],[2,5]]],
	["天蝎座",[Vector2(-35,-23),Vector2(-28,-12),Vector2(-42,-6),Vector2(-17,0),Vector2(-4,16),Vector2(14,23),Vector2(35,16),Vector2(38,1),Vector2(26,-3)],[[0,1,2],[1,3,4,5,6,7,8]]],
	["射手座",[Vector2(-39,2),Vector2(-21,-7),Vector2(-7,-23),Vector2(7,-10),Vector2(27,-13),Vector2(39,1),Vector2(11,7),Vector2(-8,20),Vector2(-23,11)],[[0,1,2,3,1,8,7,6,3,4,5,6],[8,0]]],
	["摩羯座",[Vector2(-42,-15),Vector2(-19,-9),Vector2(10,-2),Vector2(41,-14),Vector2(24,8),Vector2(-4,24),Vector2(-29,9)],[[0,1,2,3,4,5,6,0]]],
	["水瓶座",[Vector2(-42,-5),Vector2(-21,-13),Vector2(-9,-22),Vector2(6,-13),Vector2(-9,-8),Vector2(7,0),Vector2(23,4),Vector2(39,21),Vector2(6,24)],[[0,1,2,3,4,1],[4,5,6,7],[5,8]]],
	["双鱼座",[Vector2(-43,-13),Vector2(-28,-21),Vector2(-19,-10),Vector2(-33,-3),Vector2(-2,8),Vector2(30,21),Vector2(23,-9),Vector2(14,-21),Vector2(28,-25),Vector2(37,-15)],[[0,1,2,3,0],[3,4,5,6,7,8,9,6]]],
]
static var sky_rng:=RandomNumberGenerator.new()
var chart := 0
var event := ""
var age := 0.0
var duration := 0.8
var progress := 0.0
var seconds_left := 0.0
var draw_offset := Vector2.ZERO

static func spawn(host:Node,point:Vector2,kind:String,delay:=0.0,offset:=Vector2.ZERO) -> void:
	if not is_instance_valid(host):return
	var fx=load("res://scripts/core/yr_signature_fx.gd").new()
	fx.event=kind
	fx.position=point
	fx.age=-delay
	fx.draw_offset=offset
	match kind:
		"meteor_smoke":
			fx.duration=0.58
			fx.z_as_relative=false
			fx.z_index=DepthLayers.AIR-1
		"chrono_seam":fx.duration=1.65
		"meteor_dust":
			fx.duration=1.54
			fx.chart=sky_rng.randi_range(0,ZODIAC.size()-1)
		"molten_gold":fx.duration=1.12
		"chrono_sample":
			fx.duration=2.7
			var ink:=ShaderMaterial.new()
			ink.shader=preload("res://shaders/house_remap.gdshader")
			ink.set_shader_parameter("fracture_ink",true)
			fx.material=ink
		"meteor_sample":
			fx.duration=2.34
			fx.chart=sky_rng.randi_range(0,ZODIAC.size()-1)
	host.add_child(fx)

func _process(delta:float) -> void:
	age+=delta
	if age>=duration:queue_free()
	else:queue_redraw()

func _draw() -> void:
	if age<0:return
	Iso.begin(self)
	var t:=clampf(age/duration,0,1)
	match event:
		"molten_red","molten_gold":
			_fracture(minf(age/0.8,1),event=="molten_gold")
			if event=="molten_gold":_mushroom_cloud(t)
		"chrono_live":_clock(Vector2.ZERO,progress,seconds_left,1.0)
		"meteor_smoke":
			var size:=Vector2.ONE*(9+17*t)
			draw_texture_rect(SMOKE,Rect2(draw_offset+Vector2.UP*4*t-size/2,size),false,Color(0.88,0.88,0.91,0.82*(1-t)))
		"meteor_dust":_meteor_impact(t)
		"chrono_seam":_seam(t)
		"chrono_sample":_chrono_sample(t)
		"meteor_sample":_meteor_sample()

func _fracture(t:float,golden:bool) -> void:
	if t>=1.0:return
	var frame:=roundi(t*24.0)+(25 if golden else 0)
	var cell:=Vector2(216,128)
	var src:=Rect2(Vector2(frame%10,frame/10)*cell,cell)
	draw_texture_rect_region(FRACTURE_ATLAS,Rect2(-cell*0.25,cell*0.5),src)

func _mushroom_cloud(t:float) -> void:
	if t<0.10:return
	var cloud:=RA2Art.fx("MININUKE")
	if cloud.is_empty():return
	var frame:=mini(int(cloud.count)-1,int((t-0.10)/0.90*int(cloud.count)))
	var size:Vector2=cloud.cell*0.27
	draw_texture_rect_region(cloud.tex,Rect2(Vector2(-size.x*0.5,-size.y*0.78),size),RA2Art.fx_rect(cloud,frame))

func _meteor_impact(t:float) -> void:
	if t<0.52:_dust(t/0.52)
	if t<0.09:return
	var points:Array=ZODIAC[chart][1]
	var fade:=1-smoothstep(0.77,1,t)
	var link:=smoothstep(0.42,0.60,t)*fade
	if link>0:
		for chain:Array in ZODIAC[chart][2]:
			for j in range(1,chain.size()):
				var a:Vector2=points[chain[j-1]]
				var b:Vector2=points[chain[j]]
				draw_line(a,a.lerp(b,smoothstep(0.42,0.60,t)),Color(ICE,link*0.74),1.15,true)
	for i in points.size():
		var p:=clampf((t-0.09-0.018*(i%4))/0.36,0,1)
		if p<=0:continue
		var end:Vector2=points[i]
		var side:=end.normalized().orthogonal()*(3 if i%2 else -3)
		var head:=end*ease(p,0.68)+side*sin(PI*p)
		var back:=maxf(0,p-0.26*(1-smoothstep(0.70,1,p)))
		var tail:=end*ease(back,0.68)+side*sin(PI*back)
		if head.distance_squared_to(tail)>0.04:
			var wing:=tail.direction_to(head).orthogonal()*1.65
			draw_colored_polygon(PackedVector2Array([head+wing,tail,head-wing]),Color(EMBER,fade))
			draw_line(tail,head,GOLD,1.0,true)
		var flare:=Vector2.ONE*(10+3*(i%3))
		draw_texture_rect(GLOW,Rect2(head-flare/2,flare),false,Color(GOLD,0.85*fade))
		draw_circle(head,1.1 if i%3 else 1.6,Color(Color.WHITE,fade))
		if i%3==0:
			draw_line(head+Vector2.UP*3,head+Vector2.DOWN*3,Color(GOLD,fade),1)
	if link>0:
		var name_text:String=ZODIAC[chart][0]
		draw_string_outline(ThemeDB.fallback_font,Vector2(-29,38),name_text,HORIZONTAL_ALIGNMENT_CENTER,58,11,3,Color(Color("#141c32"),link))
		draw_string(ThemeDB.fallback_font,Vector2(-29,38),name_text,HORIZONTAL_ALIGNMENT_CENTER,58,11,Color(ICE,link))

func _dust(t:float) -> void:
	var spread:=ease(t,0.45)
	var fade:=1-smoothstep(0.33,1,t)
	var footprint:=Vector2(93,37)*(0.25+spread)
	draw_texture_rect(GLOW,Rect2(-footprint/2,footprint),false,Color(EMBER,0.9*fade))
	for i in 20:
		var dir:=Vector2.from_angle(TAU*i/20+0.12)
		var point:=dir*Vector2(1,0.43)*(5+40*spread)
		var loft:=sin(t*PI)*(3+(i*13)%9)
		point.y-=loft
		var size:=Vector2(19+t*17,12+t*12)*(0.8+0.10*(i%5))
		draw_texture_rect(SMOKE,Rect2(point-size/2,size),false,Color(1.0,0.83,0.68,fade*0.96))
		var spark:=point-Vector2(0,sin(t*PI)*(8+i%4*2))
		draw_line(spark,spark-dir*3,Color(GOLD,fade*(1-t)),1.35,true)
	var flash:=1-smoothstep(0.05,0.38,t)
	draw_circle(Vector2.ZERO,4+8*flash,Color(EMBER,flash*0.85))

static func missile_heat(canvas:CanvasItem,nose:Vector2,dir:Vector2,heat:float,seconds:float) -> void:
	if heat<0.025 or dir.is_zero_approx():return
	var normal:=dir.orthogonal()
	var size:=Vector2.ONE*(23+2*sin(seconds*23))*heat
	canvas.draw_texture_rect(GLOW,Rect2(nose-size/2,size),false,Color(EMBER,heat))
	for side in [-1.0,1.0]:
		var edge:Vector2=normal*side
		var tail:=nose-dir*(19+3*sin(seconds*19+side))*heat
		canvas.draw_colored_polygon(PackedVector2Array([nose+dir*2,nose-dir*5+edge*6*heat,tail+edge*2*heat]),Color(EMBER,0.78*heat))
		canvas.draw_line(nose+dir*2,nose-dir*6+edge*4*heat,Color(GOLD,heat),1.9,true)

static func ghosts(canvas:CanvasItem,tex:Texture2D,dest:Rect2,src:Rect2,progress:float) -> void:
	var spread:=(4+7*sin(PI*progress))*(1-smoothstep(0.65,0.98,progress))
	for i in [-1,1]:
		var shifted:=Rect2(dest.position+Vector2(i*spread,-i*spread*0.26),dest.size)
		canvas.draw_texture_rect_region(tex,shifted,src,Color(0.45 if i==-1 else 0.82,0.96,1,0.76*(1-progress)))

static func time_beam(canvas:CanvasItem,a:Vector2,b:Vector2,t:float) -> void:
	if a.is_equal_approx(b):return
	var side:=(b-a).normalized().orthogonal()
	canvas.draw_line(a,b,Color(0.18,0.64,1.0,0.19*(1-t)),5.2,true)
	for i in 3:
		var f:=fmod(t*0.65+i/3.0,1.0)
		var shard:=a.lerp(b,f)
		var along:=(b-a).normalized()
		canvas.draw_colored_polygon(PackedVector2Array([shard+side*2.3,shard+along*3.8,shard-side*2.3,shard-along*3.8]),Color(ICE,0.83*(1-t)))
	for strand in [-1.0,1.0]:
		var points:=PackedVector2Array()
		for j in 17:
			var f:=j/16.0
			points.append(a.lerp(b,f)+side*sin(f*TAU*2+t*TAU)*sin(f*PI)*3.6*strand)
		canvas.draw_polyline(points,Color(ICE,(1-t)*0.78),1.4,true)
	canvas.draw_line(a,b,Color(Color.WHITE,1-t),1.1,true)

func _clock(at:Vector2,done:float,remaining:float,alpha:float) -> void:
	var radius:=9.0 if remaining>=0 else 15.0
	draw_circle(at,radius,Color(Color("#172d45"),alpha*0.91))
	draw_arc(at,radius,0,TAU,40,Color(ICE,alpha),1.3,true)
	for i in 12:
		var dir:=Vector2.from_angle(i*TAU/12)
		draw_line(at+dir*(radius-2.1),at+dir*(radius-0.6),Color(GOLD,alpha),1,true)
	var hand:=Vector2.UP.rotated(done*TAU)
	draw_line(at,at+hand*(radius-2.8),Color(Color.WHITE,alpha),1.45,true)
	draw_line(at,at+Vector2.UP.rotated(done*PI/2-0.7)*radius*0.46,Color(GOLD,alpha),1.55,true)
	if remaining>=0:
		var label:="%.1fs"%(ceilf(remaining*10)/10.0)
		var pos:=at+Vector2(radius+3,4)
		draw_string_outline(ThemeDB.fallback_font,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,Color("#112130"))
		draw_string(ThemeDB.fallback_font,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(ICE,alpha))

func _seam(t:float) -> void:
	_clock(Vector2.ZERO,1.0,-1.0,1-smoothstep(0.52,1,t))
	t=minf(1,t*4)

	var fade:=1-smoothstep(0.25,1,t)
	var halo:=Vector2(14,52)*fade
	draw_texture_rect(GLOW,Rect2(-halo/2,halo),false,Color(ICE,fade))
	draw_line(Vector2.UP*(18+4*t),Vector2.DOWN*14*(1-t),Color(ICE,fade),1.45,true)
	for i in 6:
		var p:=Vector2.from_angle(i*TAU/6)*t*13
		draw_circle(p,1,Color(Color.WHITE,fade))

func _chrono_sample(t:float) -> void:
	var art:=RA2Art.art("MTNK")
	if art.is_empty():return
	var src:=RA2Art.src_rect(art,3)
	var rect:=Rect2(-src.size*0.40,src.size*0.80)
	if t<0.6:
		var p:=t/0.6
		ghosts(self,art.tex,rect,src,p)
		draw_texture_rect_region(art.tex,rect,src,Color(0.75,0.96,1,1-p))
		time_beam(self,Vector2(-80,10),Vector2.ZERO,fmod(age*4,1))
		_clock(Vector2(0,-23),p,(1-p)*duration*0.6,1.0)
	else:_seam((t-0.6)/0.4)

func _meteor_sample() -> void:
	if age>=0.80:
		_meteor_impact((age-0.80)/1.54)
		return
	var u:=age/0.80
	var point:=Vector2(-80*(1-u),-24*sin(PI*u))
	var dir:=Vector2(80,-24*PI*cos(PI*u)).normalized()
	for i in 5:
		var prev:=maxf(0,u-i*0.045)
		var pos:=Vector2(-80*(1-prev),-24*sin(PI*prev))
		var size:=Vector2.ONE*(7+i*1.7)
		draw_texture_rect(SMOKE,Rect2(pos-size/2,size),false,Color(0.82,0.83,0.85,0.62-i*0.08))
	draw_line(point-dir*8,point,Color.LIGHT_GRAY,3.4,true)
	missile_heat(self,point,dir,smoothstep(0.5,0.8,u),age)
