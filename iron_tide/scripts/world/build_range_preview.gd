extends RefCounted
## Shows the grid centers allowed by adjacency, not a promise of clear terrain.
## Placement checks water, obstructions and payment.

## Custom extension-mode yard reach; this is not a native YR Adjacent value.
const EXTENDED_YARD_CELLS := 12.0

var _signature: Array = []
var cells: Dictionary = {}
var edges := PackedVector2Array()
var expansion_cells: Dictionary = {}
var expansion_edges := PackedVector2Array()
var _expansion_signature: Array = []

static func provides_range(data: Dictionary) -> bool:
	if data.get("tags", []).has("civilian"):
		# Ownership is checked by placement_zones; this also covers older saved derricks.
		return data.get("id", "") == "CAOILD"
	var rule: Dictionary = GameData.yr_baseline.get("entities", {}).get(str(data.get("id", "")), {})
	return bool(rule.get("base_normal", data.get("base_normal", not WallArt.is_wall(data))))

static func usable_source(building, side: String) -> bool:
	if not is_instance_valid(building) or building._dead or building.hp <= 0 or building.under_construction or building.is_queued_for_deletion():
		return false
	if not provides_range(building.data): return false
	if building.side == side: return true
	if not BattleRequest.friendly(side, building.side): return false
	var raw: Dictionary = GameData.ra2_source_buildings.get(building.building_id, {}).get("extra", {})
	# Retail rulesmd.ini spells the flag "Eligibile".
	return GameData._ra2_flag(raw.get("EligibileForAllyBuilding", false))

static func adjacency_sources(world, side: String = "ally") -> Array[Rect2]:
	var result: Array[Rect2] = []
	for b in world.buildings:
		if not usable_source(b, side): continue
		result.append(Placement.aabb(world.footprint_of(b), b.global_position))
	return result

static func adjacency_distance(_world, data: Dictionary) -> float:
	var rule: Dictionary = GameData.yr_baseline.get("entities", {}).get(str(data.get("id", "")), {})
	return Ra2Damage.PX_PER_CELL * float(rule.get("adjacent", data.get("adjacent", 2.0)))

## Use the same per-source envelope for placement and the blue/green overlays.
static func source_distance(world, target_data: Dictionary, source_data: Dictionary) -> float:
	var distance := adjacency_distance(world, target_data)
	if BattleRequest.extensions_enabled() and "hq" in source_data.get("tags", []):
		distance = maxf(distance, Ra2Damage.PX_PER_CELL * EXTENDED_YARD_CELLS)
	return distance

static func placement_zones(world, data: Dictionary, side: String = "ally") -> Array:
	var result: Array = []
	for b in world.buildings:
		if not usable_source(b, side): continue
		result.append({"rect": Placement.aabb(world.footprint_of(b), b.global_position),
			"distance": source_distance(world, data, b.data)})
	if BattleRequest.extensions_enabled():
		for vehicle in world.get_tree().get_nodes_in_group("mobile_construction_yards"):
			if vehicle._combat_world != world or vehicle.side != side or not world.actor_alive(vehicle) or vehicle.embarked_in != null:
				continue
			var yard: Dictionary = vehicle.mobile_yard
			result.append({"rect": Placement.aabb(Building.placement_poly(yard), vehicle.global_position),
				"distance": source_distance(world, data, yard)})
	return result

static func allows_placement(world, rect: Rect2, data: Dictionary, side: String = "ally") -> bool:
	return zones_allow(rect, placement_zones(world, data, side))

static func zones_allow(rect: Rect2, zones: Array) -> bool:
	for zone in zones:
		if Placement.aabb_gap(rect, zone.rect) <= float(zone.distance): return true
	return false

static func zone_coverage(world, zones: Array, local: Rect2) -> Dictionary:
	var result := {}
	for zone in zones:
		var sources: Array[Rect2] = [zone.rect]
		result.merge(coverage(world, sources, local, float(zone.distance)))
	return result

static func selected_base(world) -> bool:
	if BattleRequest.extensions_enabled() and world.selected_units.size() == 1:
		var vehicle = world.selected_units[0]
		if world.actor_alive(vehicle) and vehicle.side == "ally" and vehicle.embarked_in == null and not vehicle.mobile_yard.is_empty():
			return true
	var building = world.selected_building
	return is_instance_valid(building) and (building.is_hq or building.building_id == "CAOILD") and building.side == "ally" \
		and building.hp > 0.0 and not building._dead and not building.is_queued_for_deletion() \
		and not building.under_construction

func update(world) -> void:
	if (world.armed_build.is_empty() and not selected_base(world)) or world.ended:
		_signature.clear()
		cells.clear()
		edges.clear()
		clear_expansion()
		return
	# Base selection uses the first power plant foundation as its reference.
	# Picking a building switches to that type's exact footprint and Adjacent.
	var data: Dictionary = GameData.get_building(world.roster_id("GAPOWR") if world.armed_build.is_empty() else world.armed_build)
	var local := Rect2() if data.is_empty() else Placement.aabb(Building.placement_poly(data))
	var zones := placement_zones(world, data)
	var distance := source_distance(world, data, data)
	var signature: Array = [local, zones, distance, world.map_size]
	if signature != _signature:
		_signature = signature
		cells = zone_coverage(world, zones, local)
		edges = boundary(cells, world.BUILD_GRID)
		_expansion_signature.clear()
	update_expansion(world, data, local, distance)

func clear_expansion() -> void:
	expansion_cells.clear()
	expansion_edges.clear()
	_expansion_signature.clear()

func update_expansion(world, data: Dictionary, local: Rect2, distance: float) -> void:
	if world.armed_build.is_empty() or data.is_empty() or not provides_range(data):
		clear_expansion()
		return
	var position: Vector2 = world.snap_build_pos(world.preview_override if world.preview_override != Vector2.INF else world.get_global_mouse_position())
	# Recheck live blockers even when the cursor stays in the same grid cell.
	var allowed: bool = world.build_spot_ok(position, data, int(world.struct_ready.get(world.armed_build, 0)) > 0).ok
	if not allowed:
		clear_expansion()
		return
	var signature: Array = [position, local, distance]
	if signature == _expansion_signature: return
	_expansion_signature = signature
	# Predict the exact same placement envelope after this foundation completes.
	# Terrain and occupancy still apply; this does not grant territory.
	var future_source: Array[Rect2] = [Rect2(local.position + position, local.size)]
	expansion_cells = coverage(world, future_source, local, distance)
	for cell in cells: expansion_cells.erase(cell)
	expansion_edges = boundary(expansion_cells, world.BUILD_GRID)

static func coverage(world, sources: Array[Rect2], local: Rect2, distance: float) -> Dictionary:
	var result: Dictionary = {}
	var grid: float = world.BUILD_GRID
	for source in sources:
		# AABB gap <= distance, solved for the proposed building's grid center.
		var low: Vector2 = (source.position - Vector2.ONE * distance - local.end).max(-local.position)
		var high: Vector2 = (source.end + Vector2.ONE * distance - local.position).min(Vector2.ONE * world.map_size - local.end)
		for x in range(int(ceil(low.x / grid)), int(floor(high.x / grid)) + 1):
			for y in range(int(ceil(low.y / grid)), int(floor(high.y / grid)) + 1):
				result[Vector2i(x, y)] = true
	return result

static func boundary(region: Dictionary, grid: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var half := grid * 0.5
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for cell in region:
		var center := Vector2(cell) * grid
		for i in 4:
			if not region.has(cell + directions[i]):
				result.append(center + corners[i])
				result.append(center + corners[(i + 1) % 4])
	return result

func paint(world: Node2D) -> void:
	update(world)
	if cells.is_empty(): return
	paint_region(world, cells, edges, Color(0.16, 0.80, 1.0, 0.09), Color(0.30, 0.88, 1.0, 0.95))
	paint_region(world, expansion_cells, expansion_edges, Color(0.35, 1.0, 0.30, 0.18), Color(0.55, 1.0, 0.35, 1.0))

func paint_region(world: Node2D, region: Dictionary, outline: PackedVector2Array, fill: Color, stroke: Color) -> void:
	if region.is_empty(): return
	var grid: float = world.BUILD_GRID
	for cell in region:
		world.draw_rect(Rect2(Vector2(cell) * grid - Vector2.ONE * grid * 0.5, Vector2.ONE * grid), fill)
	# Screen-sized edges remain legible when zoomed out without thickening at 4x.
	var transform := world.get_global_transform_with_canvas()
	var projected := PackedVector2Array()
	for point in outline: projected.append(transform * point)
	world.draw_set_transform_matrix(transform.affine_inverse())
	world.draw_multiline(projected, Color(0.01, 0.12, 0.18, 0.8), 4.5, true)
	world.draw_multiline(projected, stroke, 2.0, true)
	world.draw_set_transform_matrix(Transform2D.IDENTITY)
