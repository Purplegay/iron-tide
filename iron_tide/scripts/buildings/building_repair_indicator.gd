extends Node2D
## Derived presentation only. HP, repair charges and saved state belong to Building.
const ROOT := "res://assets/ra2/ui/repair_animation/"
static var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source.json"))
static var textures: Array[Texture2D] = []
const FRAME_SECONDS := 0.16
var building
var elapsed := 0.0

func bind(actor) -> void:
	building = actor
	name = "RepairIndicator"
	z_as_relative = false
	z_index = DepthLayers.WORLD_HUD + 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	if textures.is_empty():
		for row in metadata.frames: textures.append(load(ROOT + row.file))

func active() -> bool:
	return AlliedAbilities.alive(building) and building.side == "ally" and building.repairing \
		and building.hp < building.max_hp and not building.under_construction \
		and building._buildup_play < 0.0 and not AlliedAbilities.frozen(building)

func advance(delta: float) -> void:
	visible = active()
	if not visible:
		elapsed = 0.0
		return
	var world = building.battle
	if not building.repair_waiting_funds and world != null and not world.paused and not world.ended and not get_tree().paused:
		elapsed = fposmod(elapsed + maxf(0.0, delta), FRAME_SECONDS * textures.size())
	queue_redraw()

func _process(delta: float) -> void:
	advance(delta)

func frame_index() -> int:
	return int(elapsed / FRAME_SECONDS) % textures.size()

func screen_origin() -> Vector2:
	# Project the exact same upright point used by Building.draw_hp_bar.
	var overlay: Node2D = building.battle.hp_overlay
	var upright := Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO)
	var hp_anchor := Iso.dir(building.global_position) + Vector2(0, -building.radius * 2.9)
	var point := overlay.get_global_transform_with_canvas() * (upright * hp_anchor)
	return (point + Vector2(-20.0, -40.0)).round()

func _draw() -> void:
	if not active(): return
	var frame := frame_index()
	var offset: Array = metadata.frames[frame].offset
	var at := screen_origin()
	draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())
	draw_texture(textures[frame], at + Vector2(float(offset[0]) - 12.0, float(offset[1]) - 7.0))
	if building.repair_waiting_funds:
		draw_string(ThemeDB.fallback_font, at + Vector2(43, 22), "等待资金", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.82, 0.3))
	draw_set_transform_matrix(Transform2D.IDENTITY)
