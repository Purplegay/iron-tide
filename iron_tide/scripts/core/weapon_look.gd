extends Node2D
## Optional workshop visuals. Projectiles retain their launch-time appearance in splinters.
const Signature = preload("res://scripts/core/yr_signature_fx.gd")
const Sonar = preload("res://scripts/core/quiet_sonar.gd")
const BlueArc = preload("res://scripts/core/blue_arc_fx.gd")
const CHOICES = preload("res://scripts/rules/cosmetic_catalog.gd").WEAPON_FX
const NAMES = preload("res://scripts/rules/cosmetic_catalog.gd").WEAPON_NAMES
const LOVE_INTRO_SECONDS := 1.1
const HEART_FINALE_SECONDS := 0.70
const BIG_HEART = preload("res://assets/cosmetics/weapons/love_heart.svg")
const LOVE_LINES := ["LOVE","&","PEACE"]
const HEART := [Vector2(0,-1),Vector2(2,-3),Vector2(4,-3),Vector2(5,-1),Vector2(5,1),Vector2(0,6),Vector2(-5,1),Vector2(-5,-1),Vector2(-4,-3),Vector2(-2,-3)]
const SPECTRUM = preload("res://assets/cosmetics/weapons/spectrum.svg")
const BLAST = preload("res://assets/cosmetics/weapons/pixel_blast.svg")
const POINTER = preload("res://assets/cosmetics/weapons/cyber_hit.svg")
var style := ""
var age := 0.0

static func current(source, next_shot := false) -> String:
	if not is_instance_valid(source) or not (source is Unit or source is Building) or source.side!="ally":return ""
	var id:String
	if source is Unit:
		var host=source.embarked_in
		id=host.building_id if host is Building and host.building_id=="NABNKR" else source.unit_id
	elif source is Building:id=source.building_id
	else:return ""
	if not CHOICES.has(id):return ""
	var outfit: Dictionary = source.cosmetic_outfit() if source is Unit and id == source.unit_id else MetaProgress.cosmetic_style(id)
	var chosen:String=outfit.get("weapon_fx","stock")
	if chosen!=CHOICES[id]:return ""
	if chosen=="duplex":
		var count:=int(source.special.get("prism_palette_shot",0))
		if next_shot:
			count+=1
			source.special.prism_palette_shot=count
		return "prism_red" if count%2==0 else "prism_blue"
	return chosen

static func impact(host:Node,at:Vector2,look:String) -> bool:
	const CommandoFx=preload("res://scripts/units/commando_shot_fx.gd")
	if look in [CommandoFx.LASER,CommandoFx.SODA]:
		CommandoFx.spawn(host,look,at,at,true)
		return true
	if look in ["molten_red","molten_gold"]:
		Signature.spawn(host,at,look)
		return true
	if look==Sonar.ID:
		Sonar.spawn(host,at,false)
		return true
	if look not in ["pixel_blast","cyber_hit","love_peace"] or not is_instance_valid(host):return false
	var hit=load("res://scripts/core/weapon_look.gd").new()
	hit.style=look
	hit.position=at
	if look=="love_peace":hit.z_index=2
	hit.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	host.add_child(hit)
	return true

func _process(delta:float) -> void:
	age+=delta
	if age>=(LOVE_INTRO_SECONDS+HEART_FINALE_SECONDS if style=="love_peace" else 0.32):queue_free()
	else:queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	if style=="love_peace":
		_draw_love_peace()
		return
	var t:=clampf(age/0.32,0,1)
	var fade:=1.0-smoothstep(0.62,1.0,t)
	var blast:=style=="pixel_blast"
	var radius:=lerpf(4,23,t)
	for i in (8 if blast else 4):
		var p:=(Vector2.from_angle(TAU*i/(8 if blast else 4)+0.39)*radius).round()
		draw_rect(Rect2(p-Vector2.ONE,Vector2.ONE*(3 if blast else 2)),Color(Color("#ffb542") if blast else Color("#35e9ea"),fade))
	var tex:Texture2D=BLAST if blast else POINTER
	var size:=tex.get_size()*lerpf(0.43,0.73,smoothstep(0,0.42,t))
	var offset:=Vector2.UP*(5*t) if blast else Vector2(-3,2)*(1-t)
	draw_texture_rect(tex,Rect2(offset-size*0.5,size),false,Color(Color.WHITE,fade))
	if not blast:
		draw_string(ThemeDB.fallback_font,Vector2(10,-9-3*t),"HIT",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(Color("#61fff1"),fade))

func _draw_love_peace() -> void:
	if age>=LOVE_INTRO_SECONDS:
		var t:=clampf((age-LOVE_INTRO_SECONDS)/HEART_FINALE_SECONDS,0,1)
		var pop:=smoothstep(0,0.26,t)
		var beat:=sin(smoothstep(0.20,0.64,t)*PI)
		var size:=BIG_HEART.get_size()*(0.35+pop*0.9+beat*0.18)
		var center:=Vector2.UP*(3+pop*4+beat*4+t*6)
		var alpha:=smoothstep(0,0.10,t)*(1-smoothstep(0.66,1,t))
		draw_texture_rect(BIG_HEART,Rect2(center-size/2,size),false,Color(Color.WHITE,alpha))
		return
	var t:=clampf(age/LOVE_INTRO_SECONDS,0,1)
	var fade:=1.0-smoothstep(0.68,1.0,t)
	for i in 8:
		var dir:=Vector2.from_angle(TAU*i/8.0+0.18)
		var reach:=lerpf(7,42,ease(t,0.38))
		var at:=dir*reach*Vector2(1.18,0.68)+Vector2.UP*7*t
		var size_factor:=lerpf(0.5,1.0,smoothstep(0,0.17,t))*(0.75 if i%2 else 1.0)
		var points:=PackedVector2Array()
		for point:Vector2 in HEART:points.append(at+point.rotated(dir.x*0.27)*size_factor)
		var tint:=Color("#ff729d") if i%2 else Color("#ffc5dc")
		draw_colored_polygon(points,Color(tint,fade))
	for i in LOVE_LINES.size():
		if age<i*0.075:break
		var settle:=smoothstep(0,0.14,age-i*0.075)
		var pos:=Vector2(-36,-9+i*13+(1-settle)*4-t*5)
		var font_size:=12 if i==1 else 16
		var ink:=Color("#ffadc9") if i==1 else Color("#fff1f4")
		draw_string_outline(ThemeDB.fallback_font,pos,LOVE_LINES[i],HORIZONTAL_ALIGNMENT_CENTER,72,font_size,4,Color(Color("#791e43"),fade))
		draw_string(ThemeDB.fallback_font,pos,LOVE_LINES[i],HORIZONTAL_ALIGNMENT_CENTER,72,font_size,Color(ink,fade))
