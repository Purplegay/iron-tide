extends Node2D
## Visual-only reverse buildup. The sold actor retires immediately as before.

var art: Dictionary = {}
var frame := 0
var radius := 0.0
var seconds_per_frame := 0.0
var elapsed := 0.0
var start_frame := 0
var world

static func play(building) -> Node2D:
	var source: Dictionary = building._buildup_art
	var count := int(source.get("count", 0))
	if count <= 0 or source.get("tex") == null or not building.is_inside_tree():
		return null # Walls and assets without a make sequence have no reverse frames.
	var fx = load("res://scripts/buildings/building_sale_fx.gd").new()
	fx.art = source
	fx.radius = building.radius
	fx.seconds_per_frame = maxf(0.01, GameData.ra2_buildup_seconds()) / count
	fx.start_frame = count - 1
	if building._buildup_play >= 0.0:
		fx.start_frame = clampi(int(building._buildup_play / fx.seconds_per_frame), 0, count - 1)
	fx.frame = fx.start_frame
	fx.world = building.battle
	fx.material = building.material
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.z_as_relative = false
	fx.z_index = building.z_index
	building.get_parent().add_child(fx)
	fx.global_position = building.global_position
	fx.visible = building.visible
	fx.add_to_group("building_sale_visuals")
	return fx

func _process(delta: float) -> void:
	if is_instance_valid(world) and (world.paused or world.ended): return
	elapsed += delta
	frame = start_frame - int(floor(elapsed / seconds_per_frame))
	if frame < 0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if frame < 0: return
	Iso.begin(self)
	var count := int(art.get("count", 0))
	var anchor := RA2Art.anchor(art, [count - 1])
	var base := Vector2(-anchor.x, radius * 0.35 - anchor.y)
	Iso.shadow(self, Vector2(radius * 0.34, radius * 0.35), radius * 0.9, 0.30)
	draw_texture_rect_region(art.tex, Rect2(base, RA2Art.frame_size(art)), RA2Art.src_rect(art, frame))
