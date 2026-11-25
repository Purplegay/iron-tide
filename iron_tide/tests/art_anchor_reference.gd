extends RefCounted
static func anchor(m: Dictionary, frames: Array) -> Vector2:
	var fixed: Array = m.get("fixed_anchor", [])
	if fixed.size() == 2: return Vector2(float(fixed[0]), float(fixed[1]))
	if m.is_empty():
		return Vector2.ZERO
	var tex: Texture2D = m.get("tex")
	if tex == null: return Vector2.ZERO
	var poses: Dictionary = m.get_or_add("pose_anchors", {})
	if poses.has(frames): return poses[frames]
	if m.has("foot_bounds"):
		var baked := RA2Art._geometry_anchor(m, frames)
		if baked.is_finite():
			poses[frames.duplicate()] = baked
			return baked
	var img := RA2Art.sprite_image(m)
	var res := Vector2.ZERO
	if img != null:
		var left := 2147483647
		var right := -1
		var bottom := -1
		var atlas := Rect2i(Vector2i.ZERO, img.get_size())
		for frame in frames:
			var src := Rect2i(RA2Art.src_rect(m, int(frame)))
			var clipped := src.intersection(atlas)
			if not clipped.has_area(): continue
			var bounds := img.get_region(clipped).get_used_rect()
			if not bounds.has_area(): continue
			bounds.position += clipped.position - src.position
			# Only pixels outside the existing three extrema can move the foot anchor.
			for x in range(bounds.position.x, mini(left, bounds.end.x)):
				for y in range(bounds.position.y, bounds.end.y):
					if img.get_pixel(src.position.x + x, src.position.y + y).a > 0.06:
						left = x
						break
				if left == x: break
			for x in range(bounds.end.x - 1, maxi(right, bounds.position.x - 1), -1):
				for y in range(bounds.position.y, bounds.end.y):
					if img.get_pixel(src.position.x + x, src.position.y + y).a > 0.06:
						right = x
						break
				if right == x: break
			for y in range(bounds.end.y - 1, maxi(bottom, bounds.position.y - 1), -1):
				for x in range(bounds.position.x, bounds.end.x):
					if img.get_pixel(src.position.x + x, src.position.y + y).a > 0.06:
						bottom = y
						break
				if bottom == y: break
		if right >= 0: res = Vector2((left + right + 1) * 0.5, bottom + 1)
	poses[frames.duplicate()] = res
	return res
