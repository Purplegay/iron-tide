extends Node2D
## A world-anchored visual token. The owner's talent state remains authoritative.
const META:=&"ground_capacitor_token"
var owner_ref:WeakRef
var seconds:=0

static func sync(unit) -> void:
	var state:Dictionary=unit.special.get("progression_v1",{}).get("capacitor",{})
	var ref:WeakRef=unit.get_meta(META) if unit.has_meta(META) else null
	var token=ref.get_ref() if ref!=null else null
	if state.is_empty() or not AlliedAbilities.alive(unit):
		if is_instance_valid(token):token.queue_free()
		unit.remove_meta(META)
		return
	if not is_instance_valid(token) or token.is_queued_for_deletion():
		var world=unit._battle_world()
		if world==null or not is_instance_valid(world.effects_root):return
		token=load("res://scripts/units/ground_capacitor_token.gd").new()
		token.owner_ref=weakref(unit)
		world.effects_root.add_child(token)
		token.add_to_group("ground_capacitor_token")
		unit.set_meta(META,weakref(token))
	token.global_position=state.point
	token.refresh(state)

func refresh(state:Dictionary) -> void:
	var unit=owner_ref.get_ref()
	var world=unit._battle_world() if is_instance_valid(unit) else null
	visible=world!=null and world.position_visible_to("ally",global_position)
	var remaining:=maxi(0,ceili(float(state.get("left",0))))
	if remaining!=seconds:seconds=remaining;queue_redraw()

func _process(_delta:float) -> void:
	var unit=owner_ref.get_ref()
	if not AlliedAbilities.alive(unit):queue_free();return
	var state:Dictionary=unit.special.get("progression_v1",{}).get("capacitor",{})
	if state.is_empty():queue_free();return
	refresh(state)

func _draw() -> void:
	Iso.begin(self)
	# Solid base, copper terminals and a lightning core distinguish it from a shield.
	var base:=PackedVector2Array([Vector2(-13,0),Vector2(-7,-5),Vector2(7,-5),Vector2(13,0),Vector2(7,6),Vector2(-7,6)])
	draw_colored_polygon(base,Color("#14232d"))
	base.append(base[0]);draw_polyline(base,Color("#d6b56b"),1.5,true)
	for x in [-6,6]:
		draw_rect(Rect2(x-3,-15,6,15),Color("#243b48"))
		draw_rect(Rect2(x-3,-15,6,3),Color("#f4ce7d"))
		for y in [-10,-6]:draw_line(Vector2(x-3,y),Vector2(x+3,y),Color("#ae874b"),1.5)
	draw_polyline(PackedVector2Array([Vector2(2,-13),Vector2(-3,-7),Vector2(3,-7),Vector2(-2,0)]),Color("#8deaff"),2.5,true)
	var font:=ThemeDB.fallback_font
	var label:="接地电容 %ds"%seconds
	var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	var at:=Vector2(-width*.5,-21)
	draw_style_box(label_box(),Rect2(at+Vector2(-4,-13),Vector2(width+8,17)))
	draw_string_outline(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color("#071018"))
	draw_string(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#e7d5a8"))

func label_box() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=Color(0.025,0.06,0.08,0.85)
	box.set_corner_radius_all(3)
	return box
