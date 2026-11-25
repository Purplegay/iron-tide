extends Control
## Read-only sidebar clock. Progress comes from the queue, never a visual timer.
var frac: float = -1.0
var badge: int = 0
var phase: String = "idle"
var faction_id: String = "allied"
var icon: Control = null
var _badge_label: Label

static func color_for(faction: String) -> Color:
	# UI accents, not player/house colors. Yuri is reserved for its future roster.
	match faction.to_lower():
		"allied": return Color("57a8ff")
		"soviet": return Color("ff5b4a")
		"yuri", "thirdside": return Color("b97aff")
		"empire": return Color("ffd24a")
		"swarm": return Color("a56bff")
	return Color("57a8ff")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.add_theme_font_size_override("font_size",12)
	_badge_label.add_theme_color_override("font_color",Color.WHITE)
	_badge_label.add_theme_color_override("font_outline_color",Color.BLACK)
	_badge_label.add_theme_constant_override("outline_size",4)
	_badge_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_badge_label)
	_badge_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge_label.offset_left=-38; _badge_label.offset_right=-4
	_badge_label.offset_top=1; _badge_label.offset_bottom=18
	_sync_badge()

func set_state(f: float, n: int, state: String = "producing") -> void:
	var value := -1.0 if f < 0.0 else clampf(f,0.0,1.0)
	var next_phase := "idle" if value < 0.0 else state
	if is_equal_approx(frac,value) and badge == n and phase == next_phase: return
	frac=value; badge=maxi(0,n); phase=next_phase
	_sync_badge()
	queue_redraw()

func _sync_badge() -> void:
	if not is_instance_valid(_badge_label): return
	_badge_label.visible=badge>1
	_badge_label.text="x%d" % badge if badge>1 else ""

func clock_rect() -> Rect2:
	if is_instance_valid(icon):
		var at := get_global_transform().affine_inverse() * icon.global_position
		return Rect2(at,icon.size).grow(-2.0)
	return Rect2(Vector2.ZERO,size).grow(-2.0)

## Unbuilt sector: noon at 0%, clockwise reveal, no mask at 100%.
## Intersect rays with the rectangular cameo so no paint reaches name/price.
static func remaining_sector(rect: Rect2, progress: float) -> PackedVector2Array:
	if progress <= 0.0 or progress >= 1.0: return PackedVector2Array()
	var center := rect.get_center()
	var half := rect.size*0.5
	var direction := Vector2.from_angle(-PI*0.5+TAU*progress)
	var distance := minf(half.x/maxf(absf(direction.x),0.00001),half.y/maxf(absf(direction.y),0.00001))
	var points := PackedVector2Array([center,center+direction*distance])
	for corner in [Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y),rect.position]:
		var at: Vector2=corner-center
		var corner_progress := fposmod(at.angle()+PI*0.5,TAU)/TAU
		if corner_progress > progress+0.00001: points.append(corner)
	points.append(Vector2(center.x,rect.position.y))
	return points

func _draw() -> void:
	if frac < 0.0: return
	var rect := clock_rect()
	if rect.size.x<8.0 or rect.size.y<8.0: return
	var center := rect.get_center()
	var radius := minf(rect.size.x,rect.size.y)*0.5-2.0
	var accent := color_for(faction_id)
	if is_instance_valid(icon):
		if frac <= 0.0: draw_rect(rect,Color(0,0,0,0.58))
		elif frac < 1.0:
			var polygon := remaining_sector(rect,frac)
			if polygon.size()>2: draw_colored_polygon(polygon,Color(0,0,0,0.58))
	else: draw_circle(center,radius+2.0,Color(0.025,0.035,0.05,0.9))
	draw_arc(center,radius,-PI*0.5,PI*1.5,64,Color(0,0,0,0.75),4.0,true)
	draw_arc(center,radius,-PI*0.5,PI*1.5,64,Color(accent,0.24),2.0,true)
	if frac > 0.0:
		draw_arc(center,radius,-PI*0.5,-PI*0.5+TAU*frac,64,accent,2.0,true)
	if phase == "paused":
		for x in [-3.0,2.0]: draw_rect(Rect2(center+Vector2(x,-5),Vector2(2,10)),Color.WHITE)
	elif phase == "blocked":
		draw_circle(center,5.0,Color.BLACK)
		draw_line(center+Vector2(0,-3),center+Vector2(0,1),Color("ffd24a"),2.0,true)
		draw_circle(center+Vector2(0,3),1.0,Color("ffd24a"))
	elif phase == "waiting":
		for x in [-4.0,0.0,4.0]: draw_circle(center+Vector2(x,0),1.0,Color.WHITE)
	elif phase == "ready":
		draw_polyline(PackedVector2Array([center+Vector2(-5,0),center+Vector2(-1,4),center+Vector2(6,-5)]),Color.BLACK,5.0,true)
		draw_polyline(PackedVector2Array([center+Vector2(-5,0),center+Vector2(-1,4),center+Vector2(6,-5)]),accent,2.0,true)
