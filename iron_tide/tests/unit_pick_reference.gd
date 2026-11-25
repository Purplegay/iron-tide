extends Unit
# Frozen pre-round-10 pixel/shape picking reference.
func original_hit_test(world_p: Vector2) -> bool:
	world_p += global_position - presentation_position()
	if embarked_in != null or _dead:
		return false
	if uses_missile_pitch(): world_p = global_position + RA2Art.art_dir(SovietWeapons.DreadFlight.pose(self,_art_lift).affine_inverse() * Iso.dir(world_p-global_position))
	if _rock_t > 0.0:
		world_p = global_position + RA2Art.art_dir(rocking_pose().affine_inverse() * Iso.dir(world_p - global_position))
	if special.has("mcv_repack_left"):
		var repack := preload("res://scripts/world/construction_transition.gd").repack_visual(self)
		if not repack.is_empty():
			return RA2Art.hits_pixel(world_p, global_position + RA2Art.art_dir(repack.shift), repack.art, repack.radius, repack.anchors, repack.frame)
	if special.has("disguise") or unit_id in ["MGTK","R3MIRAGE"]:
		var disguise := AlliedAbilities.disguise_visual(self)
		if not disguise.is_empty(): return RA2Art.hits_pixel(world_p, global_position, disguise.art, radius, disguise.anchors, disguise.frame, 0.0, RA2_SPRITE_SCALE)
	if _ra3_model != null: return _ra3_model.hits(world_p)
	if _ra2.get("tex") == null or _art_frame < 0:
		# 尚无 RA2 美术 or 尚未绘制过一帧 -> 退回逻辑半径兜底
		return world_p.distance_to(global_position) <= radius + 10.0
	var local := Iso.dir(world_p - global_position)
	if is_same(_pick_body_art, _ra2) and not _pick_body_rect.has_point(local) and not _turret_draw_rect.has_point(local): return false
	var turret_image: Image = _ra2_tur.get("img")
	if turret_image != null and _turret_draw_rect.has_point(local):
		var pixel := Vector2i(_turret_draw_source.position + ((local - _turret_draw_rect.position) / _art_sc).floor())
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < turret_image.get_width() and pixel.y < turret_image.get_height():
			if turret_image.get_pixelv(pixel).a * 255.0 >= 20.0:
				return true
	return RA2Art.hits_pixel(world_p, global_position, _ra2, radius, _art_aframes, _art_frame, _art_lift, _art_sc)


## 可见像素的世界坐标中心（拖框选择 / 就近判定用，与贴图对齐）
