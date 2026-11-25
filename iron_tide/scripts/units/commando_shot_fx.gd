extends Node2D

const LASER := "tanya_neon_laser"
const SODA := "boris_soda_bubbles"

var style:String
var offset:Vector2
var burst:bool
var age:=0.0
var lifetime:float

static func primary_style(actor, weapon:Dictionary) -> String:
	if not actor.special.get("hero_skin",false) or actor.special.get("academy_hero")!=actor.unit_id:return ""
	var id:=str(weapon.get("ra2_weapon_id","")).trim_prefix("YR_CAP_").trim_prefix("YR_SOV_")
	if actor.unit_id=="TANY" and id in ["DoublePistols","DoublePistolsE"]:return LASER
	if actor.unit_id=="BORIS" and id in ["AKM","AKME"]:return SODA
	return ""

static func spawn(host:Node, look:String, origin:Vector2, end:Vector2, impact:=false) -> void:
	if not is_instance_valid(host):return
	var fx=new()
	fx.style=look
	fx.burst=impact
	fx.position=origin
	fx.offset=end-origin
	fx.lifetime=(0.24 if impact else 0.14) if look==LASER else (0.34 if impact else 0.26)
	fx.z_index=2
	host.add_child(fx)

func _process(delta:float) -> void:
	age+=delta
	if age>=lifetime:queue_free()
	else:queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	var t:=clampf(age/lifetime,0,1)
	var end:=Iso.dir(offset)
	var fade:=1.0-t
	if style==LASER:
		var pink:=Color(1,0.1,0.6,fade)
		var cyan:=Color(0.22,1,0.98,fade)
		if not burst:
			var rim:=end.normalized().orthogonal()*(1.6+1.4*t)
			draw_line(Vector2.ZERO,end,Color(0.85,0.06,0.66,0.35*fade),7.5*fade+1,true)
			draw_line(rim,end+rim*0.2,pink,2.0,true)
			draw_line(-rim,end,cyan,2.0,true)
			draw_line(Vector2.ZERO,end,Color(1,1,1,fade),1.1,true)
			draw_circle(Vector2.ZERO,3.5*fade,cyan)
		else:
			for i in 6:
				var axis:=Vector2.from_angle(0.32+i*TAU/6)
				var radius:=(11.0 if i%2 else 17.0)*(0.45+t)
				draw_line(axis*(radius*t),axis*radius,pink if i%2 else cyan,1.7*fade+0.4,true)
			draw_circle(Vector2.ZERO,4.2*fade,Color(1,0.94,1,fade))
		return
	if burst:
		for i in 8:
			var drift:=Vector2.from_angle(i*TAU/8+0.23)*(3.0+t*(9.0+i%3*4))
			bubble(drift+Vector2.UP*8*t*t,1.6+(i%3)*0.85,fade)
	else:
		var side:=end.normalized().orthogonal()
		var count:=clampi(ceili(end.length()/13.0),4,16)
		for i in count:
			var step:=clampf((float(i)+0.5)/count+t*0.60-0.11,0,1)
			if step<=0 or step>=1:continue
			var wave:=sin(i*2.4+t*4)*minf(4.5,end.length()*0.05)
			bubble(end*step+side*wave+Vector2.UP*t*t*5,1.65+fposmod(i*1.31,2.6),fade)

func bubble(at:Vector2, size:float, fade:float) -> void:
	draw_circle(at,size,Color(0.29,0.93,0.89,0.24*fade))
	draw_arc(at,size,0,TAU,14,Color(0.43,1,0.96,0.9*fade),1.1,true)
	draw_arc(at,size,0.2,1.8,7,Color(1,0.65,0.56,fade),0.9,true)
	draw_circle(at+Vector2(-0.33,-0.43)*size,maxf(0.55,size*0.24),Color(1,1,0.96,fade))
