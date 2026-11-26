extends RefCounted
## One atlas quad at the actor's depth, updated by the existing visible-health pass.
const ATLAS := preload("res://assets/ra3/yuriko/unit_shield_atlas.png")
static var additive: CanvasItemMaterial

static func sync(unit, amount: float) -> void:
	var sprite: Sprite2D = unit.shield_sprite
	var native_shell: bool = unit.yuriko_model != null and unit.special.has("psi_shield")
	var active: bool = not native_shell and not unit._dead and not unit.special.has("hero_wreck") and (amount > 0 or unit.special.has("rescue_shield"))
	if not active:
		if sprite != null: sprite.hide()
		return
	if sprite == null:
		if additive == null:
			additive = CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite = Sprite2D.new()
		sprite.texture = ATLAS
		sprite.hframes = 8
		sprite.vframes = 4
		sprite.material = additive
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		unit.add_child(sprite)
		unit.shield_sprite = sprite
	var bounds: Rect2 = unit._body_bounds
	if not bounds.has_area():
		var extent := Vector2.ONE * float(unit.radius)
		var center := Iso.dir(unit.art_center() - unit.global_position)
		bounds = Rect2(center - extent, extent * 2)
	var shell_size := bounds.size * 1.2 + Vector2(8,8)
	# The baked 160px tile has 114px of visible shell across its diameter.
	var basis := Transform2D(Iso.eff_angle(), Iso.up(), 0, Vector2.ZERO)
	sprite.transform = basis.translated_local(bounds.get_center()).scaled_local(shell_size / 114.0)
	sprite.frame = int(Time.get_ticks_msec() * 0.012) % 32
	sprite.show()
