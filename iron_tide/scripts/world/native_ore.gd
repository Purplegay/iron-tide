extends RefCounted
## Native maps store an overlay frame (0..11), not credits. A depleted overlay
## disappears after its last, non-paying frame (GatherOreTask / TiberiumTrait).
const CELL := 55.0
const STAGES := 12
const Maps = preload("res://scripts/world/native_maps.gd")

static func rules(id: String) -> Dictionary:
	var row: Dictionary = Maps.data(id)
	return row.ore_rules

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point / CELL).floor())

static func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL

static func spawn(world, cell: Vector2i, kind: String, stages: int) -> Node:
	var node = load("res://scripts/world/resource_node.gd").new()
	node.position = center(cell)
	node.resource_kind = kind
	node.max_amount = STAGES
	node.amount = stages
	node.radius = CELL * 0.45
	node.z_index = DepthLayers.GROUND_OBJ
	world.add_child(node)
	return node

static func load_art(node, id: String) -> void:
	var settings := rules(id)
	var cell := cell_at(node.position)
	node.native_variant = settings.variants.get(cell, posmod(cell.x * 31 + cell.y * 57, 12))
	var stem := "gem" if node.resource_kind == "gems" else "tib"
	node._ore_texture = load("res://assets/ra2/resources/native/%s_%s.png" % [stem, settings.theater])

static func install_drills(world) -> void:
	if world.has_node("NativeOreDrills"): return
	var layer := Node2D.new()
	layer.name = "NativeOreDrills"
	world.add_child(layer)
	var settings := rules(world.map_layout())
	for drill: Array in settings.drills:
		var rig := preload("res://scripts/world/native_ore_drill.gd").new()
		rig.position = center(Vector2i(drill[0], drill[1]))
		rig.atlas = load("res://assets/ra2/resources/native/tibtre_%s.png" % settings.theater)
		rig.variant = int(str(drill[2]).right(2)) - 1
		layer.add_child(rig)

static func tick(world, delta: float) -> void:
	var settings := rules(world.map_layout())
	var state: Dictionary = world.allied_state
	world.ore_growth_elapsed += delta
	var drill_elapsed := float(state.get("ore_drill_elapsed", 0)) + delta
	state.ore_drill_elapsed = drill_elapsed
	var cycle: float = settings.growth_seconds
	var drill_cycle: float = settings.drill_seconds
	if world.ore_growth_elapsed < cycle and drill_elapsed < drill_cycle: return
	var cells := {}
	for node in world.get_tree().get_nodes_in_group("resource_nodes"):
		if node.get_parent() == world: cells[cell_at(node.position)] = node
	var rng := RandomNumberGenerator.new()
	rng.seed = world.match_id.hash()
	if state.has("ore_random_state"): rng.state = state.ore_random_state
	while world.ore_growth_elapsed >= cycle:
		world.ore_growth_elapsed -= cycle
		for cell: Vector2i in cells.keys():
			var node = cells[cell]
			if node.resource_kind != "ore" or node.is_empty(): continue
			var was_full: bool = node.amount >= STAGES
			if not was_full and settings.grows and rng.randf() < float(settings.growth_chance):
				node.amount += 1
				node.queue_redraw()
			if was_full and settings.spreads and rng.randf() < float(settings.spread_chance):
				seed_near(world, cells, cell, 1, 1, false, rng)
	while drill_elapsed >= drill_cycle:
		drill_elapsed -= drill_cycle
		for index in settings.drills.size():
			var drill: Array = settings.drills[index]
			if seed_near(world, cells, Vector2i(drill[0], drill[1]), 2, 4, true, rng):
				var layer = world.get_node_or_null("NativeOreDrills")
				if layer: layer.get_child(index).start()
	state.ore_drill_elapsed = drill_elapsed
	state.ore_random_state = rng.state

static func seed_near(world, cells: Dictionary, origin: Vector2i, rings: int, initial: int, enrich: bool, rng: RandomNumberGenerator) -> bool:
	var layout: String = world.map_layout()
	var terrain: Dictionary = Maps.data(layout)
	for ring in range(1, rings + 1):
		var candidates: Array[Vector2i] = []
		var existing = null
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring: continue
				var cell := origin + Vector2i(x, y)
				var node = cells.get(cell)
				if node and not node.is_empty():
					if enrich and node.resource_kind == "ore" and node.amount < STAGES: existing = node
					continue
				if not terrain.ore_ground.has(cell) or world._ore_tile_blocked(center(cell), CELL * .35): continue
				candidates.append(cell)
		if not candidates.is_empty():
			var cell: Vector2i = candidates[rng.randi_range(0, candidates.size()-1)]
			var node = cells.get(cell)
			if node:
				node.resource_kind = "ore"
				load_art(node, layout)
				node.amount = initial
				node.depleted = false
				node.queue_redraw()
			else:
				cells[cell] = spawn(world, cell, "ore", initial)
			return true
		if existing:
			existing.amount += 1
			existing.queue_redraw()
			return true
	return false
