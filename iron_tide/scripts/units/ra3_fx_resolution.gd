extends RefCounted
## Cosmetic render budget, not a change to the native effect's world dimensions.
const PIXEL_BUDGET := 8 * 1024 * 1024
const MAX_SIDE := 1536

static func pixel_density(item: CanvasItem) -> float:
	# Include display stretch, camera zoom and the exact compensation used by Iso.begin.
	var upright:=Transform2D(Iso.eff_angle(),Iso.up(),0.0,Vector2.ZERO)
	var screen:=item.get_viewport().get_stretch_transform()*item.get_global_transform_with_canvas()*upright
	return maxf(screen.x.length(),screen.y.length())

static func side(draw_size: float, density: float, simultaneous: int=1, minimum: int=256) -> int:
	var budget_side := floori(sqrt(float(PIXEL_BUDGET) / maxi(1, simultaneous)))
	var limit := mini(MAX_SIDE, budget_side / 128 * 128 if budget_side >= 128 else maxi(1, budget_side))
	if draw_size * density <= minimum: return mini(minimum, limit)
	return clampi(ceili(minf(draw_size*density,float(limit))/128.0)*128,mini(minimum, limit),limit)

static func update(item: CanvasItem, view: SubViewport, world_size: float, minimum: int) -> void:
	if not item.is_inside_tree() or not item.is_visible_in_tree(): return
	var group := &"ra3_weapon_fx_captures"
	if not item.is_in_group(group): item.add_to_group(group)
	var live := item.get_tree().get_node_count_in_group(group)
	var wanted := side(world_size, pixel_density(item), live, minimum)
	# Growing particles retain their allocation until expiry unless other shots need it.
	var pixels := mini(side(INF, 1.0, live, minimum), maxi(view.size.x, wanted))
	if pixels != view.size.x: view.size = Vector2i(pixels, pixels)
