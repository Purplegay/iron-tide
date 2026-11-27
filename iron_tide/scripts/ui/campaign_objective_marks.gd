extends RefCounted
## Both views project the same public positions. No mark grants vision or accepts attack orders.

const GOLD := Color("ffda59")
const CASTLE_TITLE := "摧毁尤里的城堡"

static func entry(position: Vector2, title: String, actor = null, color := GOLD) -> Dictionary:
	return {"position": position, "title": title, "actor": actor, "color": color, "status": "active"}

static func eligible(world) -> bool:
	return not world.skirmish and not world.endless and not world.gm_unit_lab and not preload("res://scripts/expedition/rules.gd").active()

static func marks(world, radar: bool) -> Array:
	if world.ended or not eligible(world): return []
	if world.allied_state.has("time_shift"): return world.TimeShift.radar_marks(world)
	if world.allied_state.has("hollywood"): return world.Hollywood.markers(world, radar)
	if world.allied_state.has("allied_first"): return world.AlliedFirst.marks(world, radar)
	if world.allied_state.has("allied_finale"): return world.AlliedFinale.marks(world, radar)
	if world.mission.get("id") == world.HeadGames.ID: return head_games(world)
	var result: Array = []
	if world.mission.get("objectives", {}).has("destroy_hives"):
		for b in world.buildings:
			if world.actor_alive(b) and b.side == "enemy" and b.is_spawner:
				result.append(entry(b.position, "摧毁孵化巢", b))
	return result

static func head_games(world) -> Array:
	var s: Dictionary = world.allied_state
	if s.has("s07_castle_down"): return []
	var briefing := int(s.get("head_brief_stage", -1))
	if briefing == 0: return []
	var castle_only := briefing == 1 or (briefing < 0 and s.has("head_games_freed_0") and s.has("head_games_freed_1"))
	var result: Array = []
	for b in world.buildings:
		if not world.actor_alive(b) or b.side != "enemy": continue
		if castle_only:
			if b.building_id == world.HeadGames.CASTLE: return [entry(b.position, CASTLE_TITLE, b)]
			continue
		if not b.special.has("head_games_beacon"): continue
		var wing := int(b.special.head_games_beacon)
		if s.has("head_games_freed_%d" % wing) or (briefing > 1 and wing != 3 - briefing): continue
		result.append(entry(b.position, "摧毁苏军心灵信标" if wing == 0 else "摧毁盟军心灵信标", b))
	return result

static func screen_point(layer: Node2D, world, mark: Dictionary) -> Vector2:
	var point: Vector2 = mark.position
	var actor = mark.get("actor")
	var target_visible: bool = world.actor_alive(actor) and world.actor_visible_to("ally", actor)
	var projection: Transform2D = world.get_canvas_transform()
	if target_visible and actor is Building:
		var bounds: Rect2 = actor.combat_sight_rect()
		if bounds.has_area():
			point = actor.global_position + RA2Art.art_dir(Vector2(bounds.get_center().x,bounds.position.y))
			var roof := projection * point
			if mark.get("keep_over_building",false):
				# Keep a build instruction visible when the roof is cropped at high zoom.
				var foot: Vector2 = projection * actor.global_position
				var viewport := layer.get_viewport_rect()
				if viewport.has_point(foot):
					return Vector2(clampf(roof.x, viewport.position.x+14, viewport.end.x-14), maxf(roof.y-18,viewport.position.y+78))
				return roof - Vector2(0,18)
			return roof - Vector2(0,float(mark.get("roof_gap",48.0)))
	if target_visible: point = actor.art_center()
	return projection * point - Vector2(0, 30 if target_visible else 14)

static func paint(layer: Node2D, world) -> void:
	var public_marks := marks(world, false)
	if public_marks.is_empty(): return
	var clip := layer.get_viewport_rect().grow(12)
	var mouse := layer.get_viewport().get_mouse_position()
	var font := ThemeDB.fallback_font
	layer.draw_set_transform_matrix(layer.get_global_transform_with_canvas().affine_inverse())
	for mark: Dictionary in public_marks:
		var p := screen_point(layer, world, mark)
		if not clip.has_point(p): continue
		var color: Color = mark.color
		var diamond := PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0), p + Vector2(0, -9)])
		layer.draw_colored_polygon(diamond.slice(0, 4), Color("141820"))
		layer.draw_polyline(diamond, color, 2.5, true)
		layer.draw_circle(p, 2.5, color)
		if mark.get("keep_over_building",false) or public_marks.size() <= 3 or p.distance_squared_to(mouse) < 32.0 * 32.0:
			var text: String = mark.title
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var caption := p + Vector2(-width * 0.5, -17)
			layer.draw_rect(Rect2(caption + Vector2(-5, -15), Vector2(width + 10, 19)), Color(0.04, 0.06, 0.08, 0.93))
			layer.draw_string(font, caption, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	layer.draw_set_transform_matrix(Transform2D.IDENTITY)
