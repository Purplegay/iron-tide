extends RefCounted
## Separate hull/turret bakes in their own original VXL model coordinates.
const HULL := [preload("res://assets/cosmetics/skins/mtnk_hero_hull.png"),preload("res://assets/cosmetics/skins/htnk_hero_hull.png")]
const TURRET := [preload("res://assets/cosmetics/skins/mtnk_hero_turret.png"),preload("res://assets/cosmetics/skins/htnk_hero_turret.png")]
const HULL_LIGHT := [preload("res://assets/cosmetics/skins/mtnk_hero_hull_glow.png"),preload("res://assets/cosmetics/skins/htnk_hero_hull_glow.png")]
const TURRET_LIGHT := [preload("res://assets/cosmetics/skins/mtnk_hero_turret_glow.png"),preload("res://assets/cosmetics/skins/htnk_hero_turret_glow.png")]
static var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cosmetics/skins/tank_hero_armor.json"))
const COLORS := [Color("#8df3ff"),Color("#ff764d")]

static func enabled(actor) -> bool:
	return actor.unit_id in ["MTNK","HTNK"] and actor.special.get("hero_skin",false) and actor._dying<=0 and not actor.special.has("hero_wreck")

static func draw_layer(actor,base:Vector2,frame:int,turret:bool,alpha:float) -> void:
	if not enabled(actor):return
	var index:=0 if actor.unit_id=="MTNK" else 1
	var anchor:Array=data.units[actor.unit_id].anchor
	var rect:=Rect2(base+Vector2(anchor[0]-48,anchor[1]-42)*actor.RA2_SPRITE_SCALE,Vector2(96,64)*actor.RA2_SPRITE_SCALE)
	var tile:=Rect2(Vector2(frame%8,frame>>3)*Vector2(384,256),Vector2(384,256))
	actor.draw_texture_rect_region(TURRET[index] if turret else HULL[index],rect,tile,Color(0.98,1,1,alpha))
	var clock:=float(Time.get_ticks_msec())/1000.0
	var active:bool=actor.velocity.length_squared()>1 or is_instance_valid(actor.attack_target) or actor.selected
	var intensity:float=(0.48+0.30*sin(clock*3.0+float(index))) if active else 0.20
	var tint:Color=COLORS[index]
	tint.a=alpha*intensity
	actor.draw_texture_rect_region(TURRET_LIGHT[index] if turret else HULL_LIGHT[index],rect,tile,tint)
