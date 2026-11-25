extends Node2D
## Visual-only child: inherits building visibility/depth, but not house remap.
## Original SHP canvas centers and artmd DamageFireOffset positions stay aligned.
static var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra2/building_damage_fire.json"))
var building
var offsets: Array = []
var elapsed := 0.0

func bind(actor) -> void:
	building = actor
	name = "DamageFire"
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offsets = config.buildings.get(actor.building_id, {}).get("offsets", [])
	visible = false
	# Stable staggering without consuming gameplay RNG or adding saved state.
	elapsed = fposmod(actor.position.x * 0.013 + actor.position.y * 0.017, 7.0)

func active_count() -> int:
	if not is_instance_valid(building) or building._dead or building.hp <= 0.0 or building.max_hp <= 0.0:
		return 0
	if building.under_construction or building._buildup_play >= 0.0 or building._ra2.is_empty() or AlliedAbilities.frozen(building):
		return 0
	var fraction: float = building.hp / building.max_hp
	if fraction > float(config.yellow): return 0
	# Density is an independent presentation policy, not a claim of YR RNG parity.
	return offsets.size() if fraction <= float(config.red) else ceili(offsets.size() * 0.5)

func advance(delta: float) -> void:
	visible = active_count() > 0
	if not visible: return
	var world = building.battle
	if world == null or (not world.paused and not world.ended and not get_tree().paused):
		elapsed = fposmod(elapsed + maxf(0.0, delta), 3600.0)
	queue_redraw()

func _process(delta: float) -> void:
	advance(delta)

func fire_position(index: int) -> Vector2:
	var art: Dictionary = building._ra2
	var scale_factor: float = building.RA2_SPRITE_SCALE
	var anchor := RA2Art.anchor(art, [building._body_damage_frame()])
	var base := Vector2(-anchor.x * scale_factor, building.radius * 0.35 - anchor.y * scale_factor)
	var offset: Array = offsets[index]
	return base + (RA2Art.frame_size(art) * 0.5 + Vector2(float(offset[0]), float(offset[1]))) * scale_factor

func _draw() -> void:
	Iso.begin(self)
	for index in active_count():
		var types: Array = config.types
		var anim := RA2Art.fx(str(types[index % types.size()]))
		if anim.is_empty(): continue
		var frame := int(floor(elapsed * float(anim.fps) + index * 11)) % maxi(1, int(anim.count))
		var size: Vector2 = anim.cell * building.RA2_SPRITE_SCALE
		draw_texture_rect_region(anim.tex, Rect2(fire_position(index) - size * 0.5, size), RA2Art.fx_rect(anim, frame))
