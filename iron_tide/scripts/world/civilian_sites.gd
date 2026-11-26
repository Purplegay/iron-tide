extends RefCounted
const Maps=preload("res://scripts/world/skirmish_maps.gd")
const Rules = preload("res://scripts/world/special_rules.gd")

# artmd.ini [CAHSE01] MuzzleFlash0..4 are offsets from the SHP canvas centre.
const HOUSE_PORTS := [[-30,26], [40,34], [24,-4], [-4,30], [10,45]]

static func repair_vehicles(site, delta: float) -> void:
	if site.side == "neutral" or not site.is_operational() or site.battle.paused or site.battle.ended or site.get_tree().paused: return
	var rules := preload("res://scripts/core/yr_death_rules.gd")
	var general: Dictionary = rules.data().general
	var period := float(general.selfhealunitframes) / BattleClock.RULE_TICKS_PER_SECOND
	var elapsed := float(site.special.get("machine_shop_elapsed", 0.0)) + delta
	var pulses := floori(elapsed / period)
	site.special.machine_shop_elapsed = elapsed - pulses * period
	if pulses == 0: return
	for unit in site.battle.units:
		if not site.battle.actor_alive(unit) or unit.side != site.side or unit.hp >= unit.max_hp: continue
		var row: Dictionary = rules.type_data(unit.unit_id)
		var vehicle: bool = row.get("native_category") == "VehicleTypes" if row.has("native_category") else unit.data.get("role") in ["vehicle", "naval"]
		if vehicle and not rules.flag(row, "organic"):
			unit.heal(float(general.selfhealunitamount) * pulses)

static func configure_house(definition: Dictionary) -> void:
	definition.garrison_slots = int(Rules.building("CAHSE01").maxnumberoccupants)
	definition.fire_ports = HOUSE_PORTS
	# OccupyWeapon/EliteOccupyWeapon belong to the soldier, in either type of garrison.
	definition.garrison_weapons = GameData.get_building("NABNKR").garrison_weapons

static func create(world, id: String, point: Vector2):
	var row := Rules.building(id)
	var definition := {"id": id, "name": "可驻军民居" if id == "CAHSE01" else "桥梁维修小屋",
		"faction": "civilian", "hp": float(row.get("strength", 600)), "armor": "structure",
		"ra2_armor": str(row.get("armor", "wood")), "radius": 38.0, "sight": float(row.get("sight", 6)) * 55.0,
		"cost": 0, "power": 0, "tags": ["civilian"], "base_normal": false}
	if id == "CAHSE01": configure_house(definition)
	if id == "CAOILD":
		var oil := preload("res://scripts/core/yr_death_rules.gd").type_data(id)
		definition.merge({"name": "科技钻油井", "hp": float(oil.strength), "ra2_armor": str(oil.armor),
			"sight": float(oil.sight) * 55.0, "foundation": "2x2", "oil_startup": int(oil.producecashstartup),
			"oil_amount": int(oil.producecashamount), "oil_period": float(oil.producecashdelay) / BattleClock.RULE_TICKS_PER_SECOND}, true)
	var b := Building.new()
	b.setup(definition, "neutral", point, world, true)
	world.add_child(b)
	world.buildings.append(b)
	b._buildup_play = -1.0
	b.special.occupants = []
	return b

static func populate(world) -> void:
	if not world.skirmish or not BattleSaves.pending.is_empty(): return
	if preload("res://scripts/world/native_maps.gd").has(world.map_layout()):return
	if Maps.custom(world.map_layout()):
		populate_authored(world)
		return
	for factor in [Vector2(0.37, 0.46), Vector2(0.44, 0.54)]:
		var point: Vector2 = Vector2.ONE * world.map_size * factor
		var clear: bool = not world.in_water_world(point)
		for b in world.buildings:
			if b.position.distance_to(point) < b.radius + 160: clear = false
		for obstacle in world.get_tree().get_nodes_in_group("obstacles"):
			if obstacle.position.distance_to(point) < obstacle.radius + 100: clear = false
		if clear: create(world, "CAHSE01", point)
	# Both crossings span the inland lake. The fleet route remains open.
	var lake: Rect2 = world.water_rects[0]
	for intact in [false, true]:
		if world.map_layout() == "strait": break
		var span := crossing_span(lake, intact)
		create_crossing(world, span, intact)
	var anchors := [Vector2(0.39, 0.16), Vector2(0.39, 0.80), Vector2(0.30, 0.46)]
	if world.map_layout() != "coast": anchors = [Vector2(0.86,0.18), Vector2(0.13,0.84), Vector2(0.38,0.56) if world.map_layout() == "crossings" else Vector2(0.29,0.46)]
	for i in anchors.size():
		var site = place_oil(world, anchors[i] * world.map_size)
		if site != null and i == 2: world.allied_state.oil_mid_point = site.position
	world._refresh_pathing()
	ensure_visual(world)

static func reserve_world_crossings(world,point:Vector2) -> bool:
	if preload("res://scripts/world/native_maps.gd").has(world.map_layout()):return false
	if Maps.custom(world.map_layout()):return Maps.reserve(world,point)
	return world.map_layout()!="strait" and not world.water_rects.is_empty() and reserve_crossings(world.water_rects[0],point)

static func populate_authored(world) -> void:
	for entry:Dictionary in Maps.bridges(world.map_layout(),world.map_size):
		create_crossing(world, entry.span, entry.intact)
	for point:Vector2 in Maps.points(world.map_layout(),"houses",world.map_size):
		if world._skirmish_spot_ok(point,85) and not reserve_world_crossings(world,point):create(world,"CAHSE01",point)
	var anchors:=Maps.points(world.map_layout(),"oil",world.map_size)
	for i in anchors.size():
		var site=place_oil(world,anchors[i])
		if site!=null and i==2:world.allied_state.oil_mid_point=site.position
	world._refresh_pathing()
	ensure_visual(world)

static func place_oil(world, anchor: Vector2):
	for ring in range(8):
		for step in maxi(1, ring * 8):
			var point: Vector2 = world.snap_build_pos(anchor + Vector2.RIGHT.rotated(TAU * step / maxi(1, ring * 8)) * ring * 64.0)
			if not Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).grow(-100).has_point(point): continue
			if not world._skirmish_spot_ok(point, 100) or reserve_world_crossings(world,point): continue
			if world.get_tree().get_nodes_in_group("obstacles").any(func(o): return o.position.distance_to(point) < o.radius + 90): continue
			if world.get_tree().get_nodes_in_group("resource_nodes").any(func(o): return not o.is_queued_for_deletion() and o.position.distance_to(point) < 85): continue
			if world.units.any(func(u): return world.actor_alive(u) and u.position.distance_to(point) < 100): continue
			return create(world, "CAOILD", point)
	return null

static func oil_income(site, delta: float) -> void:
	if site.side == "neutral" or site.battle.paused or site.battle.ended or site.get_tree().paused: return
	var elapsed := float(site.special.get("oil_elapsed", 0.0)) + delta
	var period := float(site.data.oil_period)
	var payments := floori((elapsed + 1e-9) / period)
	site.special.oil_elapsed = maxf(0.0, elapsed - payments * period)
	if payments > 0: site.battle.credit_income(site.side, payments * int(site.data.oil_amount), true)

static func crossing_span(lake: Rect2, intact: bool) -> Rect2:
	var width := minf(120.0, lake.size.y * 0.34)
	var y := lake.position.y + lake.size.y * (0.78 if intact else 0.22)
	if lake.position.y == 0: y = lake.size.y * (0.60 if intact else 0.40)
	return Rect2(lake.position.x - 20, y - width * 0.5, lake.size.x + 40, width)

static func create_crossing(world, span: Rect2, intact: bool) -> void:
	var hut
	for east in [false, true]:
		hut = create(world, "CABHUT", hut_point(span, east))
		hut.special.bridge_span = span
		hut.special.bridge_repaired = false
	if intact: repair(hut)

static func hut_point(span: Rect2, east: bool) -> Vector2:
	return Vector2(span.end.x + 85 if east else span.position.x - 85, span.get_center().y + span.size.y * 0.55)

static func reserve_crossings(lake: Rect2, point: Vector2) -> bool:
	for intact in [false, true]:
		var span := crossing_span(lake, intact)
		if span.grow(65).has_point(point): return true
		for east in [false, true]:
			if point.distance_to(hut_point(span, east)) < 115: return true
	return false

static func repair(hut) -> void:
	var world = hut.battle
	if bool(hut.special.get("bridge_repaired", false)) or not hut.special.has("bridge_span"): return
	var span: Rect2 = hut.special.bridge_span
	hut.special.bridge_repaired = true
	load("res://scripts/world/bridge_damage.gd").reset_health(world,span)
	if not world.allied_state.has("repaired_bridges"): world.allied_state.repaired_bridges = []
	if not world.allied_state.repaired_bridges.has(span): world.allied_state.repaired_bridges.append(span)
	refresh_crossings(world)
	hut.queue_redraw()

static func break_bridge(hut) -> void:
	if hut.battle.allied_state.get("expedition_bridge_guard",false):return
	if not hut.special.get("bridge_repaired", false): return
	if preload("res://scripts/world/native_maps.gd").has(hut.battle.map_layout()):
		var damage = load("res://scripts/world/bridge_damage.gd")
		var parts: Array = damage.sections(hut.battle,hut.special.bridge_span)
		if not parts.is_empty(): damage.hit(hut.battle,parts[parts.size()/2].get_center(),damage.strength())
		return
	hut.special.bridge_repaired = false
	hut.battle.allied_state.get("repaired_bridges", []).erase(hut.special.bridge_span)
	refresh_crossings(hut.battle)
	load("res://scripts/world/bridge_damage.gd").collapse_units(hut.battle,hut.special.bridge_span)
	hut.queue_redraw()

static func refresh_crossings(world) -> void:
	load("res://scripts/world/bridge_damage.gd").restore(world)

static func restore_crossings(world) -> void:
	# Pre-layer saves cut a strip out of the lake. Reconstruct the water even
	# when only the surviving deck span (and no repair hut) was saved.
	for span: Rect2 in world.allied_state.get("repaired_bridges", []):
		if world.water_rects.any(func(r: Rect2): return r.has_point(span.get_center())): continue
		var strips: Array = []
		for hut in world.buildings:
			if hut.special.get("bridge_span") == span:
				strips.assign(hut.special.get("bridge_water", []))
				break
		if strips.is_empty():
			for shore: Rect2 in world.water_rects:
				if is_equal_approx(shore.end.y, span.position.y) or is_equal_approx(shore.position.y, span.end.y):
					var cut := Rect2(shore.position.x, span.position.y, shore.size.x, span.size.y).intersection(span)
					if cut.has_area() and not strips.has(cut): strips.append(cut)
		for cut: Rect2 in strips:
			var merged := cut
			var slot: int = world.water_rects.size()
			for index in range(world.water_rects.size()-1, -1, -1):
				var shore: Rect2 = world.water_rects[index]
				if not is_equal_approx(shore.position.x, cut.position.x) or not is_equal_approx(shore.size.x, cut.size.x): continue
				if is_equal_approx(shore.end.y, merged.position.y) or is_equal_approx(shore.position.y, merged.end.y):
					merged = merged.merge(shore)
					world.water_rects.remove_at(index)
					slot = index
			world.water_rects.insert(slot, merged)
	refresh_crossings(world)

static func ensure_visual(world) -> void:
	preload("res://scripts/buildings/building_rubble.gd").restore(world)
	if world.get_node_or_null("CivilianSiteVisual") != null: return
	var visual = load("res://scripts/world/civilian_site_visual.gd").new()
	visual.name = "CivilianSiteVisual"
	visual.world = world
	visual.z_index = DepthLayers.BRIDGE_DECK
	world.add_child(visual)
