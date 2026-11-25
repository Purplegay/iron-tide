extends RefCounted
const Native = preload("res://scripts/world/native_maps.gd")
const Sites = preload("res://scripts/world/civilian_sites.gd")
const Geometry = preload("res://scripts/world/bridge_sections.gd")
const KEY := "bridge_section_health"
const LEGACY_KEY := "bridge_health"
const VERSION_KEY := "bridge_section_version"
const VERSION := 2

static func strength() -> float:
	return float(preload("res://scripts/core/yr_death_rules.gd").data().combat.bridgestrength)

static func spans(world) -> Array:
	if Native.has(world.map_layout()): return Native.data(world.map_layout()).bridge_decks
	var result: Array = world.allied_state.get("repaired_bridges", []).duplicate()
	for hut in world.buildings:
		if is_instance_valid(hut) and hut.special.has("bridge_span") and not result.has(hut.special.bridge_span):
			result.append(hut.special.bridge_span)
	return result

static func overlaps(world, poly: PackedVector2Array, point: Vector2) -> bool:
	if Native.has(world.map_layout()):
		var bounds := Placement.aabb(poly,point)
		var first := Vector2i((bounds.position/Native.CELL).floor())
		var last := Vector2i((bounds.end/Native.CELL).floor())
		var cells: Dictionary = Native.data(world.map_layout()).bridge_base
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				if not cells.has(Vector2i(x,y)): continue
				var origin := Vector2(x,y)*Native.CELL
				var corners := PackedVector2Array([origin,origin+Vector2.RIGHT*Native.CELL,origin+Vector2.ONE*Native.CELL,origin+Vector2.DOWN*Native.CELL])
				if Placement.polys_overlap(poly,point,corners,Vector2.ZERO): return true
		return false
	for span: Rect2 in spans(world):
		var corners := PackedVector2Array([span.position, Vector2(span.end.x,span.position.y), span.end, Vector2(span.position.x,span.end.y)])
		if Placement.polys_overlap(poly,point,corners,Vector2.ZERO): return true
	return false

static func sections(world, span: Rect2) -> Array:
	return Native.data(world.map_layout()).bridge_sections.get(span,[]) if Native.has(world.map_layout()) else Geometry.split(span)

static func section_at(world, point: Vector2) -> Rect2:
	if Native.has(world.map_layout()):
		return Native.data(world.map_layout()).bridge_section_by_cell.get(Vector2i((point/Native.CELL).floor()),Rect2())
	for span: Rect2 in spans(world):
		if not span.has_point(point): continue
		for section: Rect2 in sections(world,span):
			if section.has_point(point): return section
	return Rect2()

static func health(world, section: Rect2) -> float:
	return float(world.allied_state.get(KEY, {}).get(section, strength()))

static func migrate(world) -> void:
	var legacy: Dictionary = world.allied_state.get(LEGACY_KEY,{})
	var old_sections := int(world.allied_state.get(VERSION_KEY,0)) < VERSION
	if legacy.is_empty() and not old_sections: return
	var values: Dictionary = world.allied_state.get(KEY,{})
	for span in legacy:
		if not span is Rect2: continue
		var parts := sections(world,span)
		for section: Rect2 in parts:
			if not values.has(section): values[section] = legacy[span]
		if float(legacy[span]) <= 0.0: retain_center_gap(world,span,values,parts)
	# The first section-based release copied a destroyed legacy span into every
	# section without a version tag. Repair only complete, unversioned spans once.
	if old_sections:
		for span: Rect2 in spans(world):
			var parts := sections(world,span)
			var entirely_broken := not parts.is_empty()
			for section: Rect2 in parts:
				if float(values.get(section,strength())) > 0.0:
					entirely_broken = false
					break
			if entirely_broken: retain_center_gap(world,span,values,parts)
	if not values.is_empty() or world.allied_state.has(KEY): world.allied_state[KEY] = values
	world.allied_state.erase(LEGACY_KEY)
	world.allied_state[VERSION_KEY] = VERSION

static func retain_center_gap(world, span: Rect2, values: Dictionary, parts: Array) -> void:
	if parts.is_empty(): return
	for section: Rect2 in parts: values.erase(section)
	values[parts[parts.size()/2]] = 0.0
	if not Native.has(world.map_layout()):
		if not world.allied_state.has("repaired_bridges"): world.allied_state.repaired_bridges = []
		if not world.allied_state.repaired_bridges.has(span): world.allied_state.repaired_bridges.append(span)

static func hit(world, point: Vector2, damage: float, source = null) -> void:
	if world == null or damage <= 0.0 or world.allied_state.get("expedition_bridge_guard",false): return
	migrate(world)
	if not world.path_service.bridge_at(point).has_area(): return
	var section := section_at(world,point)
	if section.has_area(): damage_section(world,section,damage,source)

static func damage_section(world, section: Rect2, damage: float, source = null) -> void:
	if world.allied_state.get("expedition_bridge_guard",false) or damage <= 0.0 or health(world,section) <= 0.0: return
	if not world.allied_state.has(KEY): world.allied_state[KEY] = {}
	var remaining := maxf(0.0, health(world,section) - damage)
	world.allied_state[KEY][section] = remaining
	if remaining > 0.0: return
	for hut in world.buildings:
		if is_instance_valid(hut) and hut.special.has("bridge_span") and hut.special.bridge_span.encloses(section):
			hut.special.bridge_repaired = false
	restore(world)
	collapse_units(world,section,source)
	Effects.spawn_impact(section.get_center(),Color(0.7,0.5,0.3),30.0)

static func collapse_units(world, span: Rect2, source = null) -> void:
	for unit in world.units.duplicate():
		if not world.actor_alive(unit) or unit.embarked_in != null or unit.is_air_target() or not span.has_point(unit.position): continue
		if not unit._domain_ok(unit.position): unit._die(source)

static func reset_health(world, span: Rect2) -> void:
	migrate(world)
	for section: Rect2 in sections(world,span): world.allied_state.get(KEY, {}).erase(section)

static func restore(world) -> void:
	migrate(world)
	var overrides := {}
	var broken: Array = []
	var native := Native.has(world.map_layout())
	if native: Native.bind_bridge_huts(world)
	var decks: Array = Native.data(world.map_layout()).bridge_decks if native else world.allied_state.get("repaired_bridges",[])
	for span: Rect2 in decks:
		for section: Rect2 in sections(world,span):
			if health(world,section) <= 0.0: broken.append(section)
	# Both bank huts reflect the same span; the second engineer must not be spent
	# after the first has already restored the crossing.
	for hut in world.buildings:
		if not world.actor_alive(hut) or not hut.special.has("bridge_span"): continue
		var span: Rect2 = hut.special.bridge_span
		var intact: bool = decks.has(span)
		for section: Rect2 in sections(world,span):
			if health(world,section) <= 0.0: intact = false; break
		hut.special.bridge_repaired = intact
	if native:
		var row: Dictionary = Native.data(world.map_layout())
		for cell in row.bridge_section_by_cell:
			if health(world,row.bridge_section_by_cell[cell]) <= 0.0:
				overrides[cell] = int(row.bridge_base[cell])
	world.path_service.set_bridge_damage(overrides,broken)
	if not native: world.path_service.set_water(world.water_rects,decks)
	world._refresh_pathing()
	Sites.ensure_visual(world)
	for child in world.get_children():
		if child is Ground:
			child.set_broken_bridges(broken)

static func blast(world, point: Vector2, damage: float, warhead := "", radius := 0.0, source = null) -> void:
	if world == null or world.path_service == null or damage <= 0.0 or world.allied_state.get("expedition_bridge_guard",false): return
	migrate(world)
	var native_radius := Ra2Damage.cells(warhead)*Ra2Damage.PX_PER_CELL
	var reach := native_radius if native_radius > 0.0 else maxf(0.0,radius)
	if reach <= 0.0:
		hit(world,point,damage,source)
		return
	var native := Native.has(world.map_layout())
	var decks: Array = Native.data(world.map_layout()).bridge_decks if native else world.path_service.bridge_decks.duplicate()
	for span: Rect2 in decks:
		if point.distance_to(point.clamp(span.position,span.end)) > reach: continue
		for section: Rect2 in sections(world,span):
			if health(world,section) <= 0.0: continue
			var distance := point.distance_to(point.clamp(section.position,section.end))
			if distance > reach: continue
			# One impact per covered section, regardless of its width or actor count.
			var falloff := Ra2Damage.distance_factor(distance,warhead) if native_radius > 0.0 else clampf(1.0-distance/(reach+1.0)*0.5,0.5,1.0)
			damage_section(world,section,damage*falloff,source)

static func instant_target(source, target, damage: float, warhead: String) -> void:
	if not is_instance_valid(target) or target is ForceFirePoint or (target is Unit and target.is_air_target()): return
	var world = source._battle_world() if source is Unit else source.battle
	blast(world,target.global_position,damage,warhead,0.0,source)

static func projectile_hit(projectile, damage: float) -> void:
	var ground_only: bool = projectile.splinters.get("bomb_drop",false) or (is_instance_valid(projectile.target) and projectile.target is ForceFirePoint)
	if not ground_only:
		if projectile.splinters.get("hero_air_shell",false): return
		var air: bool = projectile.splinters.get("impact_air",false)
		if projectile.splinters.has("flak_airburst"): air = projectile.splinters.flak_airburst
		elif AlliedAbilities.alive(projectile.target) and projectile.target is Unit: air = projectile.target.is_air_target()
		if air: return
	var world = projectile.get_parent()
	while world != null and not world is Battle: world = world.get_parent()
	blast(world,projectile.target_point,damage,projectile.ra2_warhead,projectile.aoe,projectile)
