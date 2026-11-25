extends Node2D
## A single cosmetic beam event: refracted edges collapse into a short-lived facet burst.
const GLOW := preload("res://assets/cosmetics/weapons/signature_glow.svg")
const STRIP := preload("res://assets/cosmetics/weapons/prism.svg")
const BLUE := Color("#367bff")
const RED := Color("#ff3559")
const CYAN := Color("#7aeeff")
const ROSE := Color("#ffad95")
const AFTERGLOW := 0.23

static func draw_beam(beam:Node2D,start:Vector2,end:Vector2,blue:bool,branch:bool,width:float,seconds:float,beam_life:float) -> void:
	var delta:=end-start
	var reach:=delta.length()
	if reach<0.01:return
	var t:=clampf(seconds/beam_life,0,1)
	var fade:=1-smoothstep(0.28,1,t)
	var tint:=BLUE if blue else RED
	var edge:=CYAN if blue else ROSE
	var w:=clampf(width,1.8,3.6)*(0.70 if branch else 1.0)
	beam.draw_set_transform(start,delta.angle(),Vector2.ONE)
	if fade>0:
		beam.draw_texture_rect(STRIP,Rect2(0,-w*1.95,reach,w*3.9),false,Color(tint,fade*0.72))
		beam.draw_line(Vector2.ZERO,Vector2.RIGHT*reach,Color(Color.WHITE,fade),w*0.58,true)
		# Two triangular paths meet at each end like light crossing a cut gemstone.
		for side in [-1.0,1.0]:
			var prism:=PackedVector2Array([Vector2.ZERO,Vector2(0.26*reach,side*w*1.65*fade),Vector2(0.74*reach,side*w*0.54*fade),Vector2(reach,0)])
			beam.draw_polyline(prism,Color(edge,fade*0.91),1.05,true)
		var pulse:=Vector2.RIGHT*lerpf(0.12,0.94,smoothstep(0,0.77,t))*reach
		beam.draw_texture_rect(GLOW,Rect2(pulse-Vector2(13,4)*w*0.58,Vector2(26,8)*w*0.58),false,Color(edge,fade))
		if not branch:
			beam.draw_texture_rect(GLOW,Rect2(-9,-9,18,18),false,Color(edge,fade))
	var p:=clampf(seconds/(beam_life+AFTERGLOW),0,1)
	var residual:=1-smoothstep(0.27,1,p)
	var size:=(16.0 if branch else 26.0)*(1+0.42*p)
	var hit:=Vector2.RIGHT*reach
	beam.draw_texture_rect(GLOW,Rect2(hit-Vector2.ONE*size/2,Vector2.ONE*size),false,Color(tint,residual))
	for i in (4 if branch else 6):
		var ray:=Vector2.from_angle(TAU*i/(4 if branch else 6)+0.4)
		var center:=hit+ray*(1+size*0.61*ease(p,0.6))
		var tip:=ray*(3.7 if branch else 5.0)*(1-0.65*p)
		var flank:=tip.orthogonal()*0.34
		beam.draw_colored_polygon(PackedVector2Array([center+tip,center+flank,center-tip,center-flank]),Color(edge,residual))
		beam.draw_line(center-tip,center+flank,Color(Color.WHITE,residual),0.85,true)
