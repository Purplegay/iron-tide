extends RefCounted

const SPINE := preload("res://assets/cosmetics/heroes/cyber_spine.svg")
const BOTTLE := preload("res://assets/cosmetics/heroes/soda_tank.svg")
const BLASTER := preload("res://assets/cosmetics/heroes/soda_blaster.svg")
const BODIES := {"TANY":preload("res://assets/cosmetics/skins/tany_outfit.png"),"BORIS":preload("res://assets/cosmetics/skins/boris_outfit.png")}
const TILE := Vector2(100,80)
const NO_SOCKET:Array = []
const SOCKET_FILES := {
	"TANY":"res://assets/cosmetics/skins/tany_rig_sockets.json",
	"BORIS":"res://assets/cosmetics/skins/boris_rig_sockets.json",
}
# Single-facing idle sequences turn independently of the commanded direction.
const IDLE_FACINGS := {
	"TANY":[3,3,3,3,3,3,3,3,3,3,4,4,4,4,4, 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5],
	"BORIS":[3,3,3,4,4,4,4,4,4,4,4,4,4,3,3, 5,5,5,5,5,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5],
}
static var sockets:Dictionary = {}
static var star := PackedVector2Array()

static func draw_star(actor, head:Vector2) -> void:
	if star.is_empty():
		for i in 11:
			star.append(Vector2.UP.rotated(i * TAU / 10.0) * (4.8 if i % 2 == 0 else 2.1))
	var bar:Rect2 = actor.hp_bar_rect()
	var center:=head + Vector2.UP*12.0
	if actor.selected or actor.hp < actor.max_hp or actor._hp_flash > 0 or actor.shield_readout_amount()>0:
		if absf(center.y-bar.get_center().y)<9.0:center.y=bar.position.y-7.0
	var pose:=Transform2D(0.0,center)
	actor.draw_set_transform_matrix(actor.body_draw_transform() * pose)
	actor.draw_polyline(star,Color("#302518"),3.2,true)
	actor.draw_polyline(star,Color("#ffe28b"),1.5,true)
	actor.draw_set_transform_matrix(actor.body_draw_transform())

static func socket(id:String, frame:int) -> Array:
	if not sockets.has(id):
		sockets[id] = JSON.parse_string(FileAccess.get_file_as_string(SOCKET_FILES[id]))
	var frames:Array = sockets[id]
	return frames[frame] if frame >= 0 and frame < frames.size() else []

static func shot_origin(actor, fallback:Vector2) -> Vector2:
	if actor.embarked_in!=null or actor._ra2.is_empty():return fallback
	var facing:=RA2Art.facing_index(actor.hull_angle,8)
	var frame:=RA2Art.seq_frame(actor._seq,actor._fire_sequence(),facing,0)
	var pins:=socket(actor.unit_id,frame)
	if pins.is_empty():return fallback
	var body:=RA2Art.draw_rect(actor._ra2,actor.radius,range(8),actor._visual_lift()).position
	var front:=Vector2.UP.rotated(-facing*TAU/8)
	var gun:=Vector2(front.x*14+front.y*2.4,front.y*9+2.8)
	return actor.global_position+RA2Art.art_dir(body+Vector2(pins[0],pins[1])+gun)

static func draw_body(actor,base:Vector2,frame:int,grade:Color) -> void:
	var cell:=Vector2(frame%16,frame/16)*TILE
	actor.draw_texture_rect_region(BODIES[actor.unit_id],Rect2(base,TILE),Rect2(cell,TILE),grade)

static func draw_layer(actor, base:Vector2, pins:Array, frame:int, facing:int, behind:bool, opacity:float) -> void:
	var id:String = actor.unit_id
	var anchor := base + Vector2(pins[0],pins[1])
	var tanya := id == "TANY"
	var bearing := facing
	if frame >= 56 and frame < 56 + IDLE_FACINGS[id].size():
		bearing = IDLE_FACINGS[id][frame-56]
	elif tanya and frame >= 292 and frame < 322:
		bearing = 3 if frame < 307 else 5
	elif actor._seq.has("Paradrop") and frame == int(actor._seq.Paradrop.start):
		bearing = 4
	var front := Vector2.UP.rotated(-bearing * TAU / 8.0)
	var wet := tanya and frame >= 292 and frame < 602
	var prone:bool = actor.is_prone()
	var transform:Transform2D = actor.body_draw_transform()
	var white := Color(1,1,1,opacity)
	var pack_behind := front.y > 0
	if behind == pack_behind:
		var mount := anchor - Vector2(front.x * 4.3,front.y * 2.4)
		var width := lerpf(0.63,1.0,absf(front.y))
		var height := 0.60 if wet else (0.78 if prone else 1.0)
		var rig := Transform2D(Vector2(width,0),Vector2(0,height),mount)
		actor.draw_set_transform_matrix(transform * rig)
		if tanya:
			actor.draw_texture_rect(SPINE,Rect2(-6,-6,12,14),false,white)
			if actor._fire_anim_time >= 0 or actor.special.has("c4_stage"):
				actor.draw_circle(Vector2(0,-0.5),1.4,Color(0.62,1,0.91,opacity))
		else:
			actor.draw_texture_rect(BOTTLE,Rect2(-5,-7.5,10,15),false,white)
	else:
		var chest := anchor + Vector2(front.x*2.2,front.y*1.6)
		actor.draw_set_transform_matrix(transform * Transform2D(0.0,chest))
		var trim := Color("#fe58cd") if tanya else Color("#44c5bc")
		trim.a = opacity
		var strap := Color(0.11,0.17,0.22,opacity)
		var offset := Vector2(2.8*front.y,2.8)
		var spread := 3.8*front.y
		var crest := PackedVector2Array([Vector2(-spread,-2.4),Vector2(0,-1),Vector2(spread,-2.4),Vector2(spread*0.62,0.8),Vector2(0,2.8),Vector2(-spread*0.62,0.8)])
		if tanya and absf(spread)>0.1:
			actor.draw_colored_polygon(crest,Color(0.34,0.23,0.49,opacity))
		actor.draw_line(-offset,offset,strap,2.8,true)
		actor.draw_line(-offset,offset,trim,0.8,true)
		actor.draw_rect(Rect2(-1.4,-1,2.8,2),trim)
	if not tanya and behind == (front.y < -0.1):
		var hand := anchor + Vector2(front.x*3.8+front.y*2.4,2.8+front.y*2)
		var barrel := Vector2(front.x,front.y*0.55+0.08)
		var length_scale:=lerpf(0.56,1.0,absf(front.x))
		var axis:=barrel.normalized()*length_scale
		var up:=Vector2(0,1) if absf(axis.x)>0.34 else Vector2(1,0)
		actor.draw_set_transform_matrix(transform*Transform2D(axis,up,hand))
		actor.draw_texture_rect(BLASTER,Rect2(-4,-4,17.5,9),false,white)
	if not behind:
		var head := base + Vector2(pins[2],pins[3])
		actor.draw_set_transform_matrix(transform * Transform2D(0.0,head))
		if tanya:
			# A luminous wraparound visor reads even at battlefield zoom.
			actor.draw_line(Vector2(-2.8,0),Vector2(2.8,0),Color(0.95,0.18,0.64,opacity),2.1,true)
			if front.y >= -0.1:
				for side in [-1,1]:
					actor.draw_circle(Vector2(front.x+side*1.2*absf(front.y),0),0.95,Color(0.57,1,0.92,opacity))
		else:
			actor.draw_arc(Vector2(0,-0.5),2.7,PI,TAU,9,Color("#fb7756")*white,1.9,true)
			actor.draw_line(Vector2(-2.8,-0.8),Vector2(front.x*3.0+2.4,-0.8),Color("#ffdb86")*white,1.0,true)
			actor.draw_line(Vector2(-3,0),Vector2(3,0),Color("#ffcd57")*white,1.4,true)
			if front.y>=-0.1:
				for side in [-1,1]:
					actor.draw_circle(Vector2(front.x+side*1.6*absf(front.y),0.5),1.5,Color("#193c56")*white)
					actor.draw_circle(Vector2(front.x+side*1.6*absf(front.y)-0.3,0),0.45,Color("#befff1")*white)
	actor.draw_set_transform_matrix(transform)
