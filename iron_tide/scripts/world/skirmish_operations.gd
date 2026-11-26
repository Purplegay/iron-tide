extends RefCounted
## Explicit enemy orders use normal unit APIs, visibility and paid production.
const Tactics = preload("res://scripts/world/skirmish_tactics.gd")

static func targets(ai) -> Array:
	var world = ai.battle
	var owner: String = ai.house_id
	if world is Battle and world.ai_prerequisite_scan and world.ai_scan_contacts.has(owner):
		return world.ai_scan_contacts[owner]
	var result := []
	for actors: Array in [world.units, world.buildings]:
		for actor in actors:
			if is_instance_valid(actor) and actor is Building and WallArt.is_wall(actor.data): continue
			if not world.actor_alive(actor) or not BattleRequest.is_house(actor.side) or BattleRequest.friendly(actor.side,owner):
				continue
			if world.actor_visible_to(owner, actor):
				result.append(actor)
	if world is Battle and world.ai_prerequisite_scan:
		world.ai_scan_contacts[owner] = result
	return result

# A planning batch can include repair, boarding and patrol jobs with no need
# for a global enemy list. Build it when the first consumer actually asks.
static func visible_contacts(ai, supplied, batch: Dictionary) -> Array:
	if supplied != null:
		return supplied
	if not batch.has(ai.house_id):
		batch[ai.house_id] = targets(ai)
	return batch[ai.house_id]

static func count(ai, id: String) -> int:
	var n := 0
	for u in ai.battle.units:
		if ai.battle.actor_alive(u) and u.side == ai.house_id and u.unit_id == id: n += 1
	for b in ai.battle.buildings:
		if ai.battle.actor_alive(b) and b.side == ai.house_id: n += b.production.count(id)
	return n

static func enqueue(ai, id: String) -> bool:
	var budget: float = ai.funds - Tactics.committed(ai.battle,ai.house_id)
	if not GameData.ai_product_allowed(id) or budget < float(GameData.get_unit(id).get("cost", INF)): return false
	for b in ai.battle.buildings:
		if ai.battle.actor_alive(b) and b.side == ai.house_id and b.is_operational() and b.production.is_empty() and b.can_queue(id): return b.enqueue(id)
	return false

# The navigable region at the port, measured in map cells. Cached only until
# terrain changes. Units in the doorway do not change the sea's classification.
static func naval_basin(yard) -> Dictionary:
	var nav = yard.battle.path_service
	var cached: Dictionary = yard.get_meta(&"ai_basin", {})
	if cached.get("epoch", -1) == nav.epoch: return cached
	var hull := GameData.get_unit("SUB" if yard.building_id == "NAYARD" else "DEST")
	var point := ProductionExit.origin(yard, hull)
	if not point.is_finite() or nav.is_blocked(point, true):
		point = ProductionExit.water_berth(yard, float(hull.radius), ProductionExit.direction(yard), true)
	var zone: int = nav.zone_at(point,true) if point.is_finite() else 0
	var cells: int = nav.water_zone.count(zone) if zone > 0 else 0
	var map_cells: int = nav.cols * nav.rows
	if not nav.native_map_id.is_empty():
		map_cells = preload("res://scripts/world/native_maps.gd").data(nav.native_map_id).cells.size()
	var fraction := float(cells) / maxi(map_cells, 1)
	var interval := 4 if fraction < 0.05 else (2 if fraction < 0.15 else 1)
	cached = {"epoch":nav.epoch, "zone":zone, "interval":interval}
	yard.set_meta(&"ai_basin", cached)
	return cached

static func limited_navy_turn(ai, yard, basin: Dictionary, opponents: Array, priority: bool) -> bool:
	if basin.interval == 1: return true
	var world = ai.battle
	var nav = world.path_service
	var fleet := 0
	for ship in world.units:
		if world.actor_alive(ship) and ship.side == ai.house_id and ship.is_naval and nav.zone_at(ship.position,true) == basin.zone:
			fleet += 1
	for line in world.buildings:
		if not world.actor_alive(line) or line.side != ai.house_id or line.building_id != yard.building_id or line.production.is_empty(): continue
		if naval_basin(line).zone == basin.zone: fleet += line.production.size()
	var enemies := 0
	for target in opponents:
		if target.is_naval and nav.zone_at(target.position,true) == basin.zone: enemies += 1
	var patrol := 2 if basin.interval == 4 else 4
	if fleet >= maxi(patrol, enemies): return false
	if enemies > fleet: return true
	# Quiet rivers use money left after land production and never buy on credit.
	if priority: return false
	var turn := int(yard.special.get("naval_patrol_turn",0))
	yard.special.naval_patrol_turn = (turn + 1) % int(basin.interval)
	return turn == 0

# Keep a paid ocean line running. Quiet enclosed waters get a limited patrol.
static func train_navy(ai, reserve:float, priority := false, contacts: Dictionary = {}) -> void:
	var world=ai.battle
	var yard_id:String=world.roster_id("GAYARD",ai.house_id)
	for yard in world.buildings:
		if not world.actor_alive(yard) or yard.side != ai.house_id or yard.building_id != yard_id or not yard.is_operational(): continue
		if yard.production.size() >= mini(2, yard.queue_capacity()) or yard.production_paused() or yard.exit_blocked: continue
		var budget: float = ai.funds - Tactics.committed(world,ai.house_id) - reserve
		if budget <= 0.0: return
		var basin := naval_basin(yard)
		if basin.zone == 0: continue
		var next_ship := ""
		var ferry: String = {"soviet":"SAPC", "yuri":"YHVR"}.get(ai.enemy_base,"LCRF")
		if world.map_layout() in ["strait","island_cross"] and count(ai,ferry) == 0 and yard.can_queue(ferry) and budget >= world.production_price(GameData.get_unit(ferry),ai.house_id):
			if yard.enqueue(ferry): continue
		var opponents := Tactics.production_contacts(world,ai.house_id,contacts)
		if not limited_navy_turn(ai, yard, basin, opponents, priority): continue
		var least_represented := INF
		var cheapest := ""
		var lowest_price := INF
		for id: String in yard.buildable:
			if not yard.can_queue(id): continue
			var price: float = world.production_price(GameData.get_unit(id), ai.house_id)
			if price < lowest_price:
				cheapest = id
				lowest_price = price
			if price > budget: continue
			var data := GameData.get_unit(id)
			var weight := 1.0 + 0.4 * (Tactics.tech_tier(id) - 1) + minf(2.0,Tactics.counter_score(data, opponents) / 10.0)
			if data.get("weapon", {}).is_empty() and data.get("transport_capacity",0) > 0: weight *= 0.35
			if id in ["SUB", "DEST"]: weight += 1.5
			var score := (float(count(ai,id)) + 0.7) / weight
			if score < least_represented:
				next_ship = id
				least_represented = score
		# Only an idle yard on its own purchasing turn can commit future income.
		# A second hull and all purchases while saving for a miner need full funding.
		if next_ship.is_empty() and priority and reserve <= 0.0 and yard.production.is_empty():
			next_ship = cheapest
		if not next_ship.is_empty(): yard.enqueue(next_ship)

# Fill one nearby defense post per decision, leaving the rest of the field army available.
static func staff_soviet_defense(ai) -> void:
	var world = ai.battle
	for building in world.buildings:
		if not world.actor_alive(building) or building.side != ai.house_id or building.under_construction: continue
		var coil: bool = building.data.has("charged_weapon")
		if not coil and not building.data.has("garrison_slots"): continue
		var action := "tesla_charge" if coil else "allied_garrison"
		var wanted: int = (3 if world.side_power_low(ai.house_id) else 1) if coil else mini(2, int(building.data.garrison_slots))
		var assigned: int = building.special.get("occupants", []).size()
		var nearest = null
		var distance := 650.0
		for u in world.units:
			if not world.actor_alive(u) or u.side != ai.house_id or u.embarked_in != null: continue
			if u.special.get("action") == action and u.special.get("target") == building:
				assigned += 1
				continue
			if u.special.has("action") or u.special.has("ai_oil_post") or u.repairing or u.attack_ordered or is_instance_valid(u.attack_target): continue
			if not AlliedAbilities.can_order(u,building,action): continue
			var d: float = u.position.distance_to(building.position)
			if d < distance:
				distance = d
				nearest = u
		if assigned < wanted and nearest != null:
			if world.ai_dispatch.defer_job(world,nearest,"interaction",{"action":action,"target":building}): return
			if AlliedAbilities.use(nearest,action,building):
				ai._army.erase(nearest)
				return

static func next_building(ai, owned: Array) -> String:
	if ai.difficulty == 0: return ""
	var wanted := []
	if ai.enemy_base == "allied" and ai.battle.units.any(func(u): return ai.battle.actor_alive(u) and u.side == ai.house_id and not u.is_air and not AlliedAbilities.infantry(u) and u.hp < u.max_hp * 0.6): wanted.append("GADEPT")
	if ai.enemy_base == "allied" and ai.difficulty >= 2: wanted.append_array(["GAWEAT", "GACSPH"])
	for id in wanted:
		if not owned.has(id) and GameData.ra2_prereq_ok(id, owned, ai.battle.allied_state, ai.house_id) and ai.funds - Tactics.committed(ai.battle,ai.house_id) >= float(GameData.get_building(id).get("cost", INF)): return id
	return ""

static func has_build_spot(ai, id: String) -> bool:
	return build_spot(ai, id).is_finite()

static func build_spot(ai, id: String) -> Vector2:
	var data: Dictionary = GameData.get_building(id)
	var coastal: bool = data.get("water_bound", false)
	var front: Vector2 = ai.objective() if coastal else Vector2.ZERO
	for anchor in ai.battle.buildings:
		if not ai.battle.actor_alive(anchor) or anchor.side != ai.house_id or anchor.under_construction: continue
		for distance in [150.0, 220.0, 300.0, 380.0]:
			for direction in 16:
				var point: Vector2 = ai.battle.snap_build_pos(anchor.position + Vector2.RIGHT.rotated(TAU * direction / 16.0) * distance)
				if coastal:
					if not ai.battle.on_water(point): continue
					var far_shore := water_point(ai.battle, point, front)
					if not far_shore.is_finite() or far_shore.distance_to(front) > ai.battle.map_size * 0.25: continue
				if Tactics.expansion_site_ok(ai.battle,ai.house_id,data,point): return point
	# Sparse radial probes can miss the gap left by a destroyed factory.
	if not coastal:
		var region = preload("res://scripts/world/build_range_preview.gd")
		var cells: Dictionary = region.zone_coverage(ai.battle, region.placement_zones(ai.battle, data, ai.house_id), Placement.aabb(Building.placement_poly(data)))
		for cell: Vector2i in cells:
			var point: Vector2 = Vector2(cell) * ai.battle.BUILD_GRID
			if Tactics.expansion_site_ok(ai.battle,ai.house_id,data,point): return point
	return Vector2.INF

# Project onto real water with hull clearance, in the ship's own connected component.
static func water_point(world, origin: Vector2, goal: Vector2, max_range := INF) -> Vector2:
	var best := Vector2.INF
	var distance := INF
	for rect: Rect2 in world.water_rects:
		var water := rect.grow(-PathService.CELL)
		if not water.has_area(): continue
		var aim := goal.clamp(water.position, water.end)
		# Every acceptable point lies inside this rectangle or on its edge.
		var lower_bound := aim.distance_squared_to(goal)
		if lower_bound >= distance or lower_bound > max_range * max_range:
			continue
		var point: Vector2 = world.path_service.nearest_reachable(aim, origin, true, 4)
		if not water.has_point(point) and point != aim: continue
		if not world.on_water(point) or not world.path_service.same_zone(origin, point, true): continue
		var d := point.distance_squared_to(goal)
		if d <= max_range * max_range and d < distance:
			distance = d
			best = point
	return best

static func naval_orders(ai, ship, visible: Array) -> void:
	visible=ai.Campaign.defensive_contacts(ai,ship,visible)
	if ship.fire_stance == "none" or naval_counterfire(ai, ship): return
	if ship.unit_id=="DLPH":
		visible=visible.duplicate()
		for host in ai.battle.units:
			if ai.battle.actor_alive(host) and host.side==ship.side and AlliedAbilities.alive(host.special.get("squid")):
				visible.append(host.special.squid)
	var target = preferred(ai, ship, visible)
	if target != null:
		var in_range: bool = ship.position.distance_to(target.position) <= OpenTopped.command_range(ship, target)
		var can_chase: bool = target is Unit and ai.battle.on_water(target.position) and ai.battle.path_service.same_zone(ship.position, target.position, true)
		if in_range or can_chase or ship.unit_id == "DRED":
			order_attack(ship,target)
		else:
			var coast := water_point(ai.battle,ship.position,target.position)
			if coast.is_finite() and (not ship.has_move_order or ship.move_target.distance_to(coast) > PathService.CELL):
				ship.ai_order("move",coast,false)
		return
	if ai.ai_state.get("campaign_started",false) and ship.special.get(ai.Campaign.ROLE)=="guard": return
	if ship.has_move_order: return
	var leg := int(ship.special.get("ai_sea_leg",0))
	var front: Vector2 = ai.objective()
	var goal: Vector2 = front if leg == 0 else front.lerp(ai.base_center,0.45)
	var point := water_point(ai.battle,ship.position,goal)
	if point.is_finite():
		ship.special.ai_sea_leg = 1 - leg
		if ship.position.distance_to(point) > PathService.CELL: ship.ai_order("move",point,false)

## Recent incoming fire takes precedence over patrols and strategic target scoring.
static func naval_counterfire(ai, ship) -> bool:
	if ship._return_timer <= 0.0 or ship.fire_stance == "none" or ship.weapon.is_empty() or ship.repairing or ship.embarked_in != null:
		return false
	if ship._stun_timer > 0.0 or ship.special.has("repair_exit_point") or AlliedAbilities.frozen(ship):
		return false
	var attacker = ship.special.get("retaliation_target")
	if not ai.battle.actor_alive(attacker) or attacker.side == ship.side or not ship.attack_domain_valid(attacker):
		return false
	var reach := OpenTopped.command_range(ship, attacker)
	var distance := CommandoCombat.distance_to(ship, attacker)
	if distance < ship.min_range: return false
	if distance <= reach:
		if ship.hold_position:
			ship.attack_target = attacker
			return true
		# The destroyer's gun can reload longer than the six-second hit memory.
		# Keep a newly assigned response through its next firing opportunity.
		if not ship.attack_ordered or not is_same(ship.attack_target, attacker):
			ship._return_timer = maxf(ship._return_timer, ship._cd_timer + 0.75)
		order_attack(ship, attacker)
		return true
	if ship.hold_position or distance > reach + 2.0 * Ra2Damage.PX_PER_CELL: return false
	# Search firing positions in the hull's water component instead of plotting
	# a course to the soldier's land tile. Reuse an approach that still works.
	if ship.has_move_order and not ship.attack_ordered and not ship.attack_move and ai.battle.path_service.same_zone(ship.position, ship.move_target, true):
		var remaining: float = ship.move_target.distance_to(attacker.position)
		if remaining >= ship.min_range and remaining <= reach - Unit.ARRIVE_EPS: return true
	var water := preload("res://scripts/units/dread_missile.gd").firing_position(ship, attacker)
	if not water.is_finite(): return false
	ship.ai_order("move",water, false)
	return true

static func order_attack(unit, target) -> void:
	if unit.attack_target == target and unit.attack_ordered and not unit.special.has("ai_dispatch_pending"): return
	var world = unit._battle_world()
	if world != null: world.ai_dispatch.submit(world,unit,{"kind":"attack","target":target})

static func preferred(ai, unit, visible: Array):
	var best = null
	var score := -INF
	for target in visible:
		if not is_instance_valid(target): continue
		if target is Building and WallArt.is_wall(target.data): continue
		var distance: float = unit.position.distance_to(target.position)
		var value: float = 60.0 + (1.0 - target.hp / maxf(1.0, target.max_hp)) * 30.0
		if unit.is_naval and target is Unit and target.is_naval: value += 40.0
		if target is Building: value += 40.0 if target.is_refinery() or not target.superweapon.is_empty() else 15.0
		elif target.is_harvester: value += 30.0
		value -= distance / 60.0
		if target is Building and distance<=maxf(unit.attack_range,unit.sight): value+=60.0
		if value <= score or not unit.attack_domain_valid(target):
			continue
		if unit.is_naval:
			if unit.weapon.is_empty():
				continue
			var reach := OpenTopped.command_range(unit, target)
			if distance > reach:
				var firing_point := preload("res://scripts/units/dread_missile.gd").firing_position(unit,target) if unit.unit_id == "DRED" else water_point(ai.battle, unit.position, target.position, reach)
				if not firing_point.is_finite() or firing_point.distance_to(target.position) > reach:
					continue
		score = value
		best = target
	return best

static func tick(ai) -> void:
	var world = ai.battle
	if world.paused or world.ended or world.get_tree().paused or ai.enemy_base == "swarm": return
	# Restore crossings lost in combat first. Initially unfinished bridges must
	# not take the engineer just purchased for the opening oil capture.
	preload("res://scripts/world/ai_bridge_repair.gd").tick(ai,true)
	claim_oil(ai)
	preload("res://scripts/world/ai_bridge_repair.gd").tick(ai)
	var visible := targets(ai)
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side != ai.house_id or unit.embarked_in != null: continue
		if not (unit.special.get("ai_transport_reserved",false) or unit.hp < unit.max_hp*0.3 or unit.is_naval or unit.logistics.ammo_max>0 or unit.unit_id in ["SPY","SHAD","LCRF","SAPC","GHOST","BFRT"]): continue
		if not world.ai_dispatch.defer_job(world,unit,"operations",true): unit_decision(ai,unit,visible)
	for b in world.buildings:
		if not world.actor_alive(b) or b.side != ai.house_id: continue
		if b.hp < b.max_hp * 0.65 and not b.repairing and ai.funds - Tactics.committed(world,ai.house_id) > 300: b.set_repairing(true)
		if b.sw_ready(): preload("res://scripts/world/skirmish_support.gd").consider(ai, b, visible)
		if b.sw_type().to_lower() == "ironcurtain" and b.sw_ready():
			for unit in world.units:
				if world.actor_alive(unit) and unit.side == b.side and unit.unit_id in ["APOC","HTNK","DRED"] and world.actor_alive(unit.attack_target):
					b.fire_superweapon(unit.position)
					break
		if b.sw_type().to_lower() in ["lightningstorm","multimissile"] and b.sw_ready():
			var best = null
			var score := 0.0
			for target in visible:
				var value := 0.0
				for other in visible:
					if target.position.distance_to(other.position) < 275: value += float(other.data.get("cost", 100))
				for own in world.units + world.buildings:
					if world.actor_alive(own) and BattleRequest.friendly(own.side,ai.house_id) and target.position.distance_to(own.position) < 330: value -= float(own.data.get("cost", 100)) * 2
				if value > score: score = value; best = target
			if best != null and score >= 600: b.fire_superweapon(best.position)

static func claim_oil(ai) -> void:
	var world = ai.battle
	var oil = preload("res://scripts/world/skirmish_oil.gd")
	var point: Vector2 = oil.midfield(world)
	var mid = null
	var sites := []
	var remembered: Array = ai.ai_state.get("ai_neutral_oil", []).filter(func(p): return not world.position_visible_to(ai.house_id, p))
	var revisit := remembered.duplicate()
	revisit.erase(point) # Scouts reconfirm midfield before an engineer sets out.
	for b in world.buildings:
		if not world.actor_alive(b) or b.building_id != "CAOILD" or not world.actor_visible_to(ai.house_id, b): continue
		if b.position == point: mid = b
		if b.side == "neutral" and not remembered.has(b.position): remembered.append(b.position)
		if b.side == "neutral" or (b == mid and BattleRequest.is_house(b.side) and not BattleRequest.friendly(b.side,ai.house_id)): sites.append(b)
	ai.ai_state.ai_neutral_oil = remembered
	var threats: Array = oil.defenders(ai, point) if point.is_finite() else []
	if point.is_finite(): oil.manage(ai, point, mid, threats, sites.is_empty())
	var suspended: bool = float(ai.ai_state.get("oil_retry_left", 0)) > 0
	if suspended: sites.erase(mid)
	var engineer_id := "SENGINEER" if ai.enemy_base == "soviet" else "ENGINEER"
	for unit in world.units:
		if world.actor_alive(unit) and unit.side == ai.house_id and unit.special.get("action") == "allied_engineer":
			if mid != null and unit.special.get("target") == mid and (suspended or not threats.is_empty()):
				unit.ai_order("move",ai.rally, false)
				continue
			sites.erase(unit.special.get("target"))
	if sites.is_empty() and revisit.is_empty(): return
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side != ai.house_id or unit.unit_id != engineer_id or unit.embarked_in != null: continue
		if unit.special.get("ai_bridge_repair_worker",false): continue
		if unit.special.has("action"): continue
		if world.allied_state.get("ai_dispatch_waiting",{}).get(unit,{}).get("jobs",{}).has("interaction"): continue
		if sites.is_empty():
			unit.special.erase("ai_mid_engineer")
			oil.move_near(unit, revisit[0], false)
			return
		var nearest = sites[0]
		for site in sites:
			if unit.position.distance_squared_to(site.position) < unit.position.distance_squared_to(nearest.position): nearest = site
		unit.special.erase("ai_mid_engineer")
		if nearest == mid:
			unit.special.ai_mid_engineer = true
			if not threats.is_empty():
				oil.move_near(unit, ai.rally, false)
				return
		if world.ai_dispatch.defer_job(world,unit,"interaction",{"action":"allied_engineer","target":nearest}): return
		if AlliedAbilities.use(unit, "allied_engineer", nearest): ai._army.erase(unit)
		return
	# Do not buy an engineer for stale fog memories or a contested midfield oil.
	# Existing engineers may scout remembered sites; new ones need a visible job.
	if not sites.any(func(site):return site!=mid or (not suspended and threats.is_empty())): return
	if count(ai, engineer_id) > 0: return
	var reserve: float = preload("res://scripts/world/skirmish_economy.gd").reserve(ai)
	if ai.funds - Tactics.committed(world,ai.house_id) - reserve < world.production_price(GameData.get_unit(engineer_id), ai.house_id): return
	for producer in world.buildings:
		if world.actor_alive(producer) and producer.side == ai.house_id and producer.is_operational() and producer.can_queue(engineer_id):
			if not producer.production_paused() and producer.enqueue(engineer_id): return

static func spy(ai, unit, visible: Array) -> void:
	if unit.special.get("action", "") == "allied_infiltrate": return
	var chosen = null
	var priority := -1.0
	for target in visible:
		if not AlliedAbilities.can_order(unit, target, "allied_infiltrate"): continue
		var score := 20.0
		if target.is_refinery(): score = 80.0
		elif target.building_id in ["GATECH","NATECH"]:
			var stolen := "stolen_%s_%s" % [ai.house_id,"RequiresStolenAlliedTech" if target.building_id == "GATECH" else "RequiresStolenSovietTech"]
			score = 90.0 if not ai.battle.allied_state.get(stolen, false) else 0.0
		elif not target.superweapon.is_empty(): score = 50.0 + target.sw_progress() * 60.0
		if score > priority: priority = score; chosen = target
	if chosen == null: return
	if not unit.special.has("disguise"):
		for target in visible:
			if AlliedAbilities.can_order(unit, target, "allied_disguise"):
				AlliedAbilities.use(unit, "allied_disguise", target); break
	AlliedAbilities.use(unit, "allied_infiltrate", chosen)

static func meet_passengers(world, carrier) -> void:
	# Fly to reserved troops instead of sending them on a long march across the map.
	var nearest = null
	var best := INF
	for passenger in carrier.logistics.incoming:
		if not world.actor_alive(passenger) or passenger.logistics.boarding != carrier: continue
		var distance: float = passenger.position.distance_to(carrier.position)
		if distance <= passenger.radius + carrier.radius + 16.0 and carrier.flight.can_land(): return
		if distance < best:
			best = distance
			nearest = passenger
	if nearest == null: return
	# Local passengers keep walking to an already reachable landing site.
	if best < 8.0 * 55 and carrier.flight.can_land(): return
	var center: Vector2 = nearest.position
	if best < 8.0 * 55 and nearest.position.distance_to(nearest.move_target) <= 16.0:
		center = nearest.move_target
	for ring in range(4):
		for i in maxi(1,8*ring):
			var point := center + Vector2.RIGHT.rotated(TAU*i/maxi(1,8*ring))*ring*36.0
			if carrier.flight.can_land_at(point):
				carrier.special.ai_pickup = point
				carrier.ai_order("move",point)
				return

static func transport(ai, carrier, visible: Array) -> void:
	var phase: String = carrier.special.get("ai_transport_phase", "load")
	if phase == "load":
		var troops: Array = ai.battle.units.filter(func(u): return ai.battle.actor_alive(u) and u.side == ai.house_id and u.unit_id == "GHOST" and u.embarked_in == null and u.logistics.boarding == null)
		for unit in troops.slice(0, maxi(0, 2 - carrier.logistics.passengers.size() - carrier.logistics.incoming.size())):
			unit.cancel_stance()
			if ai.battle.ai_dispatch.defer_job(ai.battle,unit,"board",carrier) or unit.logistics.request_board(carrier):
				unit.special.ai_transport_reserved = true
				unit.special.ai_carrier = carrier
				ai._army.erase(unit)
		if carrier.logistics.passengers.size() < 2:
			if not carrier.has_move_order:
				meet_passengers(ai.battle,carrier)
			return
		carrier.special.erase("ai_pickup")
		var target = preferred(ai, carrier.logistics.passengers[0], visible.filter(func(t): return t is Building))
		if target == null: return
		for distance in [180.0, 260.0, 360.0]:
			for i in 16:
				var point: Vector2 = target.position + Vector2.from_angle(TAU * i / 16) * distance
				if not carrier.logistics.landing_clear(ai.battle, point, 50): continue
				carrier.special.ai_transport_phase = "fly"
				carrier.special.ai_drop = point
				carrier.ai_order("move",point, false)
				return
	elif phase == "fly":
		if carrier.position.distance_to(carrier.special.ai_drop) < 30:
			carrier.logistics.request_unload()
			carrier.special.ai_transport_phase = "unload"
	elif phase == "unload" and carrier.logistics.passengers.is_empty():
		carrier.special.ai_transport_phase = "return"
		carrier.ai_order("move",ai.rally, false)
		for u in ai.battle.units:
			if ai.battle.actor_alive(u) and u.side == ai.house_id and u.embarked_in == null and u.special.get("ai_carrier") == carrier:
				u.special.erase("ai_transport_reserved")
				u.special.erase("ai_carrier")
	elif phase == "return" and carrier.position.distance_to(ai.rally) < 80:
		carrier.ai_order("stop")
		carrier.special.ai_transport_phase = "load"

static func unit_decision(ai,unit,visible, batch: Dictionary = {}) -> void:
	if unit.embarked_in != null: return
	var world = ai.battle
	var carrier = unit.special.get("ai_carrier")
	if unit.special.get("ai_transport_reserved", false) and (not world.actor_alive(carrier) or carrier.side != unit.side):
		unit.special.erase("ai_transport_reserved")
		unit.special.erase("ai_carrier")
	if unit.unit_id == "E1" and world.actor_alive(carrier) and carrier.unit_id == "BFRT" and unit.special.get("ai_transport_reserved",false):
		var pending: Dictionary = world.allied_state.get("ai_dispatch_waiting",{}).get(unit,{})
		if unit.side == carrier.side and (unit.logistics.boarding == carrier or pending.get("jobs",{}).get("board") == carrier):
			return
		unit.special.erase("ai_transport_reserved")
		unit.special.erase("ai_carrier")
	if unit.repairing or unit.special.has("repair_exit_point"): return
	if not unit.is_harvester and unit.hp < unit.max_hp * 0.3:
		var repairing := false
		for depot in world.buildings:
			if unit.can_repair_at(depot) and unit.order_repair(depot): repairing = true; break
		if repairing: ai._army.erase(unit); return
	if unit.unit_id == "SPY":
		spy(ai, unit, visible_contacts(ai, visible, batch))
	elif unit.unit_id == "BFRT":
		preload("res://scripts/world/skirmish_fortress_crew.gd").load_nearby(ai, unit)
	elif unit.unit_id == "SHAD":
		transport(ai, unit, visible_contacts(ai, visible, batch))
	elif unit.unit_id in ["LCRF", "SAPC", "YHVR"]:
		preload("res://scripts/world/skirmish_landing.gd").tick(ai, unit, visible_contacts(ai, visible, batch))
	elif unit.is_naval:
		if not unit.weapon.is_empty(): naval_orders(ai,unit,visible_contacts(ai, visible, batch))
	elif unit.logistics.ammo_max > 0:
		if unit.logistics.air_state != "parked" or unit.logistics.ammo < unit.logistics.ammo_max: return
		# A fresh AI decision is required for each sortie; player planes are untouched.
		var target = preferred(ai, unit, ai.Campaign.defensive_contacts(ai,unit,visible_contacts(ai, visible, batch)))
		if target != null: order_attack(unit, target)
	elif unit.unit_id == "GHOST" and unit.logistics.boarding == null and not unit.special.get("ai_transport_reserved", false):
		var target = preferred(ai, unit, ai.Campaign.defensive_contacts(ai,unit,visible_contacts(ai, visible, batch)).filter(func(t): return t is Building))
		if target != null: order_attack(unit, target)
