class_name ProductionExit
extends RefCounted
## Measured ports on the shipped SHP canvases, not building-node origins.
## rules.ini ExitCoord distinguishes the barracks and vehicle factory routes;
## these raster anchors adapt those routes to our bottom-anchored Godot sprites.
const PORTS := {
	"GAWEAP": {"size": Vector2(266, 224), "pixel": Vector2(224, 199), "out": Vector2(1, 0.5), "roof": Vector2(155, 145)},
	"GAPILE": {"size": Vector2(250, 148), "pixel": Vector2(137, 130), "out": Vector2(-1, 0.5)},
}
const Airport = preload("res://scripts/buildings/airport_dock.gd")
static var _offsets: Array[Vector2] = []

static func supported(building) -> bool:
	return building.is_refinery() or building.building_id in ["GAYARD", "NAYARD"] or \
		(PORTS.has(building.building_id) and RA2Art.frame_size(building._ra2) == PORTS[building.building_id].size)

static func direction(building) -> Vector2:
	if building.is_refinery(): return building.refinery_dock_direction()
	var vector: Vector2 = PORTS.get(building.building_id, {}).get("out", Vector2(0, 1))
	return building.art_to_ground(vector).normalized()

static func art_point(building, pixel: Vector2) -> Vector2:
	var anchor := RA2Art.anchor(building._ra2, [building._body_damage_frame()])
	var base: Vector2 = -anchor * building.RA2_SPRITE_SCALE + Vector2(0, building.radius * 0.35)
	return building.global_position + building.art_to_ground(base + pixel * building.RA2_SPRITE_SCALE)

static func near_footprint(building, point: Vector2, margin: float) -> bool:
	var local: Vector2 = point - building.global_position
	var poly: PackedVector2Array = building.footprint_poly()
	if Geometry2D.is_point_in_polygon(local, poly): return true
	for i in poly.size():
		if local.distance_to(Geometry2D.get_closest_point_to_segment(local, poly[i], poly[(i + 1) % poly.size()])) < margin: return true
	return false

static func origin(building, data: Dictionary) -> Vector2:
	var radius := maxf(1.0, float(data.get("radius", 8.0)))
	var port: Dictionary = PORTS.get(building.building_id, {})
	if data.get("tags", []).has("air"):
		# Aircraft built by the vehicle factory emerge over its roof hatch.
		if port.has("roof"):
			var art := RA2Art.art(str(data.get("id", "")))
			var facings := int(art.get("facings", 32))
			var frame := posmod(RA2Art.facing_index(direction(building).angle(), facings) + int(art.get("facing_offset", 0)), facings)
			var frames: Array = range(facings * int(art.get("poses", 1)))
			var center := RA2Art.visible_unit_center(Vector2.ZERO, art, radius, frames, frame, 0.0, Unit.RA2_SPRITE_SCALE)
			return art_point(building, port.roof) - center
	var d := direction(building)
	var p: Vector2 = art_point(building, port.pixel) if port.has("pixel") else building.depth_anchor()
	if building.is_refinery(): p = building.refinery_dock_point(radius)
	# PathService currently stamps the producer's AABB into 40-unit cells.
	# Clear that navigation envelope as well as the visible polygon; otherwise
	# an apparently open doorway can still lie inside the producer's blocked cell.
	var navigation: Rect2 = building.footprint_rect().grow(radius + building.battle.path_service.cell + 4.0)
	# Clear only this producer's footprint. Never search through a neighbour or
	# around to the rear when the actual exit is occupied.
	for step in 180:
		if not navigation.has_point(p - building.global_position) and not near_footprint(building, p, radius + 4.0): return p
		p += d * 2.0
	return Vector2.INF

static func point(building, uid: String) -> Vector2:
	var data := GameData.get_unit(uid)
	if Airport.can_produce(building, uid): return Airport.production_point(building, uid)
	var p := origin(building, data)
	if p == Vector2.INF: return p
	var naval: bool = data.get("tags", []).has("naval") or data.get("role", "") == "naval"
	var air: bool = data.get("tags", []).has("air")
	var radius := float(data.get("radius", 8.0))
	var d := direction(building)
	# Prefer the actual port, then nearby positions in its outward half-plane.
	# Bounded, deterministic offsets let crowds clear without rear-side spawns.
	# Docked aircraft retain their exact pad reservation above.
	for offset in offsets():
		var candidate: Vector2 = p + d * offset.x + d.orthogonal() * offset.y
		if building._exit_position_clear(candidate, radius, naval, air): return candidate
	# A water foundation can fit against a coast even when its default exit faces land.
	# Walk out from the dock through contiguous water, stopping at the first clear berth.
	if naval and building.data.get("water_bound", false):
		return water_berth(building, radius, d)
	return Vector2.INF

static func water_berth(building, radius: float, preferred: Vector2, for_repair := false) -> Vector2:
	var center: Vector2 = building.depth_anchor()
	var envelope: Rect2 = building.footprint_rect().grow(radius + building.battle.path_service.cell + 4.0)
	for index in 16:
		var direction := preferred.rotated(ceilf(index / 2.0) * (1 if index % 2 else -1) * TAU / 16.0)
		var probe := center
		for step in 32:
			probe += direction * 10.0
			if not building.battle.in_water_world(probe): break
			if envelope.has_point(probe - building.position): continue
			if for_repair:
				if not building.battle.path_service.is_blocked(probe, true): return probe
			elif building._exit_position_clear(probe, radius, true, false):
				return probe
			break
	return Vector2.INF

static func offsets() -> Array[Vector2]:
	if not _offsets.is_empty(): return _offsets
	var result: Array[Vector2] = [Vector2.ZERO]
	for forward in range(0, 161, 40):
		for lateral in range(-160, 161, 40):
			var offset := Vector2(forward, lateral)
			if offset != Vector2.ZERO and offset.length_squared() <= 160.0 * 160.0: result.append(offset)
	result.sort_custom(func(a: Vector2, b: Vector2):
		if a.length_squared() != b.length_squared(): return a.length_squared() < b.length_squared()
		if a.x != b.x: return a.x > b.x
		return a.y < b.y)
	_offsets = result
	return _offsets

static func assembly(building, unit) -> Vector2:
	var d := direction(building)
	if unit.is_naval and building.data.get("water_bound", false): d = building.depth_anchor().direction_to(unit.position)
	# A default short departure clears the fixed port for the next produced unit.
	# Explicit rallies still win, and this does not affect map/GM spawns.
	for forward in [64.0, 112.0, 160.0]:
		for lateral in [0.0, 40.0, -40.0, 80.0, -80.0]:
			var p: Vector2 = unit.global_position + d * forward + d.orthogonal() * lateral
			if building._exit_position_clear(p, unit.radius, unit.is_naval, unit.is_air): return p
	return Vector2.INF
