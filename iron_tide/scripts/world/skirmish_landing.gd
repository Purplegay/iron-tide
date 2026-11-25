extends RefCounted
## Rendezvous ashore, cross navigable water, then use normal passenger unloading.
const Ops = preload("res://scripts/world/skirmish_operations.gd")

static func beach(world, rect: Rect2, goal: Vector2) -> Dictionary:
	var best := {}
	var distance := INF
	for normal in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var vertical: bool = normal.x != 0
		for shift in [0, -160, 160, -320, 320, -480, 480]:
			var coast := Vector2.ZERO
			if vertical:
				coast = Vector2(rect.position.x if normal.x < 0 else rect.end.x, clampf(goal.y + shift, rect.position.y + 80, rect.end.y - 80))
			else:
				coast = Vector2(clampf(goal.x + shift, rect.position.x + 80, rect.end.x - 80), rect.position.y if normal.y < 0 else rect.end.y)
			var land: Vector2 = coast + normal * 110
			var sea: Vector2 = coast - normal * 90
			if not Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).grow(-65).has_point(land): continue
			if world.path_service.is_blocked(land) or world.on_water(land) or not rect.has_point(sea) or world.path_service.is_blocked(sea,true): continue
			var score := goal.distance_squared_to(land)
			if score < distance:
				distance = score
				best = {"land": land, "sea": sea}
	return best

static func approach(ship, point: Vector2) -> bool:
	if ship.position.distance_to(point) <= 48: return true
	if not ship.has_move_order or ship.move_target.distance_to(point) > 45:
		ship.ai_order("move",point, false)
	return false

static func tick(ai, ship, visible: Array) -> void:
	var world = ai.battle
	if not ship.special.has("beach_mission"):
		for rect: Rect2 in world.water_rects:
			if not rect.has_point(ship.position): continue
			var home := beach(world, rect, ai.rally)
			var away := beach(world, rect, ai.objective())
			if home.is_empty() or away.is_empty() or home.land.distance_to(away.land) < 380: continue
			if not world.path_service.same_zone(home.sea, away.sea, true): continue
			ship.special.beach_mission = {"home": home, "away": away, "phase": "load"}
			break
	if not ship.special.has("beach_mission"): return
	var trip: Dictionary = ship.special.beach_mission
	match trip.phase:
		"load":
			var docked := approach(ship, trip.home.land)
			if docked and ship.has_move_order: ship.ai_order("stop")
			var aboard: int = ship.logistics.passengers.size()
			var booked := 0
			var occupied: int = aboard + world.units.filter(func(u): return world.actor_alive(u) and u.side == ai.house_id and u.embarked_in == null and u.special.get("ai_carrier") == ship).size()
			for unit in world.units:
				if not world.actor_alive(unit) or unit.side != ai.house_id or not AlliedAbilities.infantry(unit) or unit.weapon.is_empty(): continue
				if unit.embarked_in != null or unit.repairing: continue
				if unit.special.get("ai_carrier") != ship:
					if occupied >= 2 or unit.special.has("ai_oil_post") or unit.special.has("action") or unit.special.get("ai_transport_reserved", false): continue
					if not world.path_service.same_zone(unit.position, trip.home.land): continue
					if unit.is_deployed() and not unit.set_deployed(false, false): continue
					unit.special.ai_carrier = ship
					unit.special.ai_transport_reserved = true
					occupied += 1
					ai._army.erase(unit)
				booked += 1
				if docked and unit.logistics.boarding != ship:
					if not world.ai_dispatch.defer_job(world,unit,"board",ship): unit.logistics.request_board(ship)
				elif not docked and unit.logistics.boarding == null:
					if approach(unit, trip.home.land) and unit.has_move_order: unit.ai_order("stop")
			if not docked: return
			if aboard >= 2 or (aboard > 0 and booked == 0 and trip.get("waited", false)):
				trip.phase = "embark"
				trip.erase("waited")
				return
			trip.waited = aboard > 0
		"embark":
			if approach(ship, trip.home.sea): trip.phase = "sail"
		"sail":
			if approach(ship, trip.away.sea): trip.phase = "land"
		"land":
			if ship.logistics.passengers.is_empty(): trip.phase = "return_sea"
			elif approach(ship, trip.away.land) and ship.logistics.request_unload():
				trip.phase = "unload"
				trip.erase("last_aboard")
		"unload":
			for unit in world.units:
				if not world.actor_alive(unit) or unit.embarked_in != null or unit.special.get("ai_carrier") != ship: continue
				unit.special.erase("ai_transport_reserved")
				unit.special.erase("ai_carrier")
				var target = Ops.preferred(ai, unit, visible)
				if target != null: Ops.order_attack(unit, target)
				else: unit.ai_order("move",ai.objective(), true)
			var aboard: int = ship.logistics.passengers.size()
			if aboard == 0:
				trip.phase = "return_sea"
			elif aboard == trip.get("last_aboard", -1):
				# If the shore fills up during unloading, try another nearby landing.
				for i in 8:
					var alt: Vector2 = trip.away.land + Vector2.from_angle(TAU * i / 8) * 110
					if ship.logistics.landing_clear(world, alt, ship.radius) and world.path_service.same_zone(alt, trip.away.land):
						trip.away.land = alt
						trip.phase = "land"
						break
			trip.last_aboard = aboard
		"return_sea":
			if approach(ship, trip.away.sea): trip.phase = "return_home"
		"return_home":
			if approach(ship, trip.home.sea): trip.phase = "load"
