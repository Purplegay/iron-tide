extends Unit
func original_rest_art_center() -> Vector2:
	var repack := preload("res://scripts/world/construction_transition.gd").repack_visual(self)
	if not repack.is_empty():
		return RA2Art.draw_center(global_position + RA2Art.art_dir(repack.shift), repack.art, repack.radius, repack.anchors)
	var disguise := AlliedAbilities.disguise_visual(self)
	if not disguise.is_empty(): return RA2Art.draw_center(global_position, disguise.art, radius, disguise.anchors, 0.0, RA2_SPRITE_SCALE)
	if _ra3_model != null: return _ra3_model.center()
	if _ra2.get("tex") == null or _art_frame < 0:
		return global_position
	if _ra2.get("kind", "") == "vxl":
		return RA2Art.visible_unit_center(global_position, _ra2, radius, _art_aframes, _art_frame, _art_lift, _art_sc)
	return RA2Art.draw_center(global_position, _ra2, radius, _art_aframes, _art_lift, _art_sc)

