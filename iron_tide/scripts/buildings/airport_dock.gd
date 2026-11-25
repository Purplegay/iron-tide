extends RefCounted
## Original art.ini [GAAIRC] DockingOffset0..3, in leptons.
const OFFSETS := [Vector2(0, -128), Vector2(0, 128), Vector2(256, -128), Vector2(256, 128)]
## Raster calibration for the current 188x162 GAAIRC + GAAIRCBB SHP canvas.
## The four painted centers are (124,110), (94,125), (154,125), (124,140).
const CANVAS_ORIGIN := Vector2(109, 117.5)

static func can_produce(building, uid: String) -> bool:
	var raw: Dictionary = GameData.ra2_source_units.get(uid, {}).get("extra", {})
	return int(raw.get("Ammo", 0)) > 0 and str(raw.get("Dock", "GAAIRC,AMRADR")).split(",").has(building.building_id)

static func destroy_assigned_aircraft(building, temporal_erasure: bool) -> void:
	if not is_instance_valid(building.battle): return
	if int(GameData.ra2_source_buildings.get(building.building_id, {}).get("extra", {}).get("NumberOfDocks", 0)) <= 0: return
	for plane in building.battle.units.duplicate():
		if not building.battle.actor_alive(plane) or plane.side != building.side: continue
		if plane.logistics.home != building or not GameData._ra2_flag(plane.logistics.source.get("AirportBound", false)): continue
		plane.logistics.home = null
		plane.logistics.dock_slot = -1
		plane.hp = 0.0
		plane._die(null, temporal_erasure)

static func free_slot(building) -> int:
	var docks := int(GameData.ra2_source_buildings.get(building.building_id, {}).get("extra", {}).get("NumberOfDocks", 0))
	for slot in docks:
		var busy := false
		for other in building.battle.units:
			if is_instance_valid(other) and other.hp > 0.0 and other.logistics.home == building and other.logistics.dock_slot == slot:
				busy = true
				break
		if not busy: return slot
	return -1

static func production_point(building, uid: String) -> Vector2:
	var slot := free_slot(building)
	if slot < 0: return Vector2.INF
	if not supported(building): return building.position + Vector2((slot % 2) * 44.0 - 22.0, (slot / 2) * 44.0 - 22.0)
	return from_art(building, RA2Art.art(uid), RA2Art.weapon_descriptor(uid).get("origins", []), float(GameData.get_unit(uid).get("radius", 8.0)), Unit.RA2_SPRITE_SCALE, slot)

static func supported(building) -> bool:
	return building.building_id in ["GAAIRC", "AMRADR"] and RA2Art.frame_size(building._ra2) == Vector2(188, 162)

static func destination(building, plane, slot: int) -> Vector2:
	return from_art(building, plane._ra2, plane._weapon_art.get("origins", []), plane.radius, plane.RA2_SPRITE_SCALE, slot)

static func from_art(building, art: Dictionary, origins: Array, radius: float, scale: float, slot: int) -> Vector2:
	var offset: Vector2 = OFFSETS[clampi(slot, 0, OFFSETS.size() - 1)]
	var pixel := CANVAS_ORIGIN + Vector2((offset.x - offset.y) * 30.0, (offset.x + offset.y) * 15.0) / 256.0
	var anchor := RA2Art.anchor(building._ra2, [building._body_damage_frame()])
	var base: Vector2 = Vector2(-anchor.x, -anchor.y) * building.RA2_SPRITE_SCALE + Vector2(0, building.radius * 0.35)
	# The VXL model origin differs from the bottom-of-content unit drawing anchor.
	# Use exported per-facing origins, shared with the actual muzzle projection.
	var ground_offset := Vector2.ZERO
	if not origins.is_empty():
		# Per-facing atlas origins vary by less than one pixel due to raster
		# rounding. Average them so steering never chases a moving docking goal.
		var origin := Vector2.ZERO
		for point in origins: origin += Vector2(point[0], point[1])
		origin /= float(origins.size())
		var rect := RA2Art.draw_rect(art, radius, range(int(art.get("facings", 32))), 0.0, scale)
		ground_offset = rect.position + origin * scale
	return building.position + RA2Art.art_dir(base + pixel * building.RA2_SPRITE_SCALE - ground_offset)
