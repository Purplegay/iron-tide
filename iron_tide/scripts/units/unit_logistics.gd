class_name UnitLogistics
extends RefCounted
const AirportDock = preload("res://scripts/buildings/airport_dock.gd")
## Transport and aircraft lifecycle. Movement, damage and production remain on real actors.

const SiegeChopper = preload("res://scripts/units/siege_chopper.gd")

var unit: Unit
var capacity := 0
var size_limit := 0
var passengers: Array = []
var boarding = null
# The carrier position used for the last request can differ from the nearest
# reachable waypoint. This transient cache is rebuilt once on loading a save.
var _boarding_requested_at := Vector2.INF
var _boarding_epoch := -1
var _boarding_replan_left := 0.0
var incoming: Array = []
var unloading := false
var unload_timer := 0.0
var ammo_max := 0
var ammo := 0
var air_state := "flying"
var air_lift := 1.0
var airport_repair_elapsed := 0.0
# Derived airport membership is not serialized; restoring `home` rebuilds it.
var home = null:
	set(value):
		if home != value: airport_repair_elapsed = 0.0
		unregister_home()
		home = value
		register_home()
const HOME_MEMBERS := &"logistics_home_members"
var dock_slot := -1
var reload_elapsed := 0.0
var _home_retry := 0.0
var _waiting_airfield = null
var resume_target = null # Legacy save field; a completed sortie never resumes it.
var carrier_owner = null
var squadron: Array = []
var source: Dictionary = {}

static func home_members(airport) -> Array:
	return airport.get_meta(HOME_MEMBERS, []) if is_instance_valid(airport) else []

func unregister_home() -> void:
	if is_instance_valid(home) and home.has_meta(HOME_MEMBERS):
		var members := home_members(home)
		members.erase(unit)
		if members.is_empty(): home.remove_meta(HOME_MEMBERS)

func register_home() -> void:
	if not is_instance_valid(home) or not is_instance_valid(unit) or not unit.is_inside_tree(): return
	var members := home_members(home)
	if not members.has(unit): members.append(unit)
	home.set_meta(HOME_MEMBERS, members)

func setup(actor) -> void:
	unit = actor
	source = GameData.ra2_source_units.get(unit.unit_id, {}).get("extra", {})
	if unit.unit_id in ["LCRF", "SAPC", "SHAD", "FV", "BFRT", "HTK"]:
		capacity = int(source.get("Passengers", 0))
		size_limit = int(source.get("SizeLimit", 0))
	if unit.unit_id in ["ORCA", "BEAG", "HORNET", "ASW"]:
		ammo_max = int(source.get("Ammo", 1))
		ammo = ammo_max
	ensure_squadron()

func ensure_squadron() -> void:
	if unit.unit_id in ["CARRIER", "DEST"]:
		while squadron.size() < int(source.get("SpawnsNumber", 0)):
			squadron.append({"unit": null, "timer": 0.0})

func assign_producer(producer) -> void:
	if not is_instance_valid(producer):
		return
	if unit.is_air and producer is Building: air_lift = 0.0
	if ammo_max > 0 and producer is Building and choose_home(producer, true):
		unit.position = dock_destination()
		air_state = "parked"
		unit.velocity = Vector2.ZERO

func used_capacity() -> int:
	var total := 0
	passengers = passengers.filter(func(p): return is_instance_valid(p) and p.hp > 0.0)
	for p in passengers:
		total += passenger_size(p)
	return total

func passenger_size(actor) -> int:
	var size = GameData.ra2_source_units.get(actor.unit_id, {}).get("size", 1)
	return maxi(1, int(size) if size != null else 1)

func can_board(actor) -> bool:
	if actor.special.has("expansion_temporary"):return false
	if unit.special.has("furnace_flak_life") or (is_instance_valid(actor) and actor.special.has("furnace_flak_life")): return false
	if capacity <= 0 or actor == unit or not AlliedAbilities.alive(actor) or not AlliedAbilities.alive(unit):
		return false
	var size := passenger_size(actor)
	if unit.unit_id in ["FV", "BFRT"] and not AlliedAbilities.infantry(actor): return false
	return unit.hp > 0.0 and actor.side == unit.side and not actor.is_air and not actor.is_naval \
		and actor.embarked_in == null and size <= size_limit and used_capacity() + size <= capacity

func request_board(carrier) -> bool:
	if not is_instance_valid(carrier) or not carrier.logistics.can_board(unit):
		return false
	_route_to_carrier(carrier)
	if not carrier.logistics.incoming.has(unit):
		carrier.logistics.incoming.append(unit)
	return true

func _boarding_destination(carrier) -> Vector2:
	# An AI pickup order gives the pilot and all reserved passengers the same
	# fixed rendezvous. A different move order resumes normal carrier tracking.
	if carrier.has_move_order and carrier.move_target == carrier.special.get("ai_pickup",Vector2.INF):
		return carrier.move_target
	return carrier.position

func _route_to_carrier(carrier) -> void:
	var destination := _boarding_destination(carrier)
	unit.order_move(destination)
	boarding = carrier
	_boarding_requested_at = destination
	_boarding_epoch = unit._terrain_epoch()
	_boarding_replan_left = 0.4

func request_unload() -> bool:
	if capacity <= 0 or passengers.is_empty():
		return false
	unit.order_stop()
	unloading = true
	unload_timer = 0.0
	return true

func stop_command(launch := false) -> void:
	boarding = null
	_boarding_requested_at = Vector2.INF
	_boarding_replan_left = 0.0
	unloading = false
	resume_target = null
	if launch and ammo_max > 0 and ammo > 0:
		air_state = "flying"

func can_start_volley() -> bool:
	if unit.special.has("peregrine") and preload("res://scripts/units/peregrine_command.gd").anti_air(unit,unit.attack_target):return air_lift>=.95
	if unit.unit_id == "SCHP":
		return not unit.special.has("siege_progress") and (air_lift <= 0.001 if unit._deployed else air_lift >= 0.95)
	return (not unit.is_air or air_lift >= 0.95) and (ammo_max == 0 or (ammo > 0 and air_state == "flying"))

func consume_volley(_target) -> void:
	if unit.special.has("peregrine") and preload("res://scripts/units/peregrine_command.gd").anti_air(unit,_target):return
	spend_ammo(1,true,_target)

func spend_ammo(count:int,normal:bool,target=null) -> void:
	if ammo_max > 0 and count>0:
		var previous:=ammo
		ammo = maxi(0, ammo-count)
		if unit.special.has("peregrine"):preload("res://scripts/units/peregrine.gd").spent(unit,previous,ammo,normal)
		preload("res://scripts/units/expansion_2_aircraft.gd").ground_ammo_spent(unit,previous,ammo,normal,target)

func tick(delta: float) -> bool:
	if air_state == "flying": airport_repair_elapsed = 0.0
	if unit.special.has("peregrine") and preload("res://scripts/units/peregrine_service.gd").busy(unit):return true
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(27)
	# Ordinary ground actors have no transport/flight work. Read live state so
	# boarding, unloading and a newly created squadron take effect immediately.
	if not unit.is_air and unit.unit_id != "SCHP" and ammo_max == 0 and not unloading and not is_instance_valid(boarding) and squadron.is_empty(): return false
	if not squadron.is_empty():
		tick_squadron(delta)
	if is_instance_valid(boarding):
		var carrier = boarding
		if not carrier.logistics.can_board(unit):
			boarding = null
			unit.order_stop()
			return true
		if unit.position.distance_to(carrier.position) <= unit.radius + carrier.radius + 16.0 and carrier.velocity.length() < 8.0:
			if carrier.is_air:
				if unit._battle_world().in_water_world(carrier.position):
					return false
				if carrier.logistics.air_lift > 0.05:
					return false
			unit.order_stop()
			carrier.logistics.passengers.append(unit)
			unit.set_stowed(carrier)
			carrier._refresh_weapon_derived()
			AlliedAbilities.refresh_ifv_art(carrier)
			carrier._cancel_burst()
			AlliedAbilities.release_control(carrier)
			AlliedAbilities.release_temporal(carrier)
			if carrier.unit_id == "FV":preload("res://scripts/units/convoy_heroes.gd").boarded(carrier)
			if carrier.unit_id == "FV": Ra2Sfx.play("IFVTransform", carrier.global_position)
			boarding = null
			return true
		_boarding_replan_left = maxf(0.0, _boarding_replan_left - delta)
		if _boarding_replan_left <= 0.0:
			var moved := not _boarding_requested_at.is_finite() or _boarding_requested_at.distance_squared_to(_boarding_destination(carrier)) > 24.0 * 24.0
			if moved or (not unit.has_move_order and _boarding_epoch != unit._terrain_epoch()):
				_route_to_carrier(carrier)
	if unloading:
		if unit.is_air:
			if unit._battle_world().in_water_world(unit.position):
				return true
			unit.flight.altitude(0.0, delta)
			if air_lift > 0.05:
				return true
		unload_timer -= delta
		if unload_timer <= 0.0:
			unload_one()
			unload_timer = 0.35 / (Unit.Training.timing_scale(unit) if unit.unit_id in ["SHAD","LCRF","SAPC"] else 1.0)
		unit.queue_redraw()
		return true
	if preload("res://scripts/units/peregrine.gd").active(unit):
		unit.flight.altitude(1.0,delta)
		preload("res://scripts/units/peregrine_service.gd").sync_collision(unit)
		return false
	if ammo_max > 0:
		if air_state == "flying" and is_instance_valid(carrier_owner) and not valid_target(unit.attack_target):
			request_return()
		if air_state == "flying" and unit._burst_left == 0:
			if ammo == 0:
				# Only an explicitly queued route survives automatic rearming.
				var pending: Array = [] if _ai_airfield_plane() else unit.order_queue
				unit.order_queue = []
				if not pending.is_empty() and unit.attack_ordered and AlliedAbilities.alive(unit.attack_target):
					pending.push_front({"target": unit.attack_target, "forced": ForceFire.active(unit, unit.attack_target)})
				request_return()
				unit.order_queue = pending
			elif _ai_airfield_plane() and (not unit.attack_ordered or not valid_target(unit.attack_target)):
				# An interrupted sortie may still have every round. Rejoin the airport
				# cycle even if a legacy save already left the aircraft on open ground.
				request_return()
		if air_state != "flying":
			return tick_return(delta)
	if unit.unit_id == "SCHP":
		return SiegeChopper.tick(unit, delta)
	if unit.is_air:
		if not incoming.is_empty():
			incoming = incoming.filter(func(p): return is_instance_valid(p) and p.hp > 0.0 and p.logistics.boarding == unit)
		var landing := false
		for passenger in incoming:
			if not unit.has_move_order and unit.position.distance_to(passenger.position) <= unit.radius + passenger.radius + 16.0 and unit.velocity.length() < 8.0:
				landing = unit.flight.can_land()
				break
		# A moving aircraft cannot auto-land. Its combat update validates the
		# target separately; skip that duplicate query solely for this decision.
		if not unit.has_move_order:
			var attacking: bool = (unit.attack_ordered or unit.fire_stance != "none") and valid_target(unit.attack_target)
			if not attacking and unit.flight.can_land(): landing = true
		unit.flight.altitude(0.0 if landing else 1.0, delta)
		if unit.special.has("peregrine"):preload("res://scripts/units/peregrine_service.gd").sync_collision(unit)
		if landing:
			unit.velocity = Vector2.ZERO
			unit.queue_redraw()
			return true
		unit.queue_redraw()
	return false

func unload_one() -> void:
	used_capacity()
	if passengers.is_empty():
		unloading = false
		return
	var passenger = passengers[0]
	var world = unit._battle_world()
	for ring in [1.0, 1.6, 2.2]:
		for i in 16:
			var p: Vector2 = unit.position + Vector2.RIGHT.rotated(TAU * i / 16.0) * (unit.radius + passenger.radius + 12.0) * ring
			if not landing_clear(world, p, passenger.radius):
				continue
			passengers.pop_front()
			passenger.position = p
			passenger.set_stowed(null)
			if unit.special.has("convoy"):preload("res://scripts/units/convoy_heroes.gd").unloaded(unit,passenger)
			passenger.order_stop()
			unit._refresh_weapon_derived()
			AlliedAbilities.refresh_ifv_art(unit)
			unit._cancel_burst()
			AlliedAbilities.release_control(unit)
			AlliedAbilities.release_temporal(unit)
			if unit.unit_id == "FV": Ra2Sfx.play("IFVTransform", unit.global_position)
			unloading = not passengers.is_empty()
			return
	# A blocked coast keeps the passenger aboard; never place inside water or a building.

func landing_clear(world, p: Vector2, radius: float) -> bool:
	if world == null or world.path_service == null:
		return false
	for i in 9:
		var sample := p if i == 0 else p + Vector2.RIGHT.rotated(TAU * (i - 1) / 8.0) * radius
		if sample.x < 0.0 or sample.y < 0.0 or sample.x >= world.map_size or sample.y >= world.map_size:
			return false
		if world.path_service.is_blocked(sample) or world.in_water_world(sample):
			return false
	var candidates: Array = world.units
	if world is Battle and world.units.size() >= 96:
		candidates = world.neighborhood.nearby(p, radius + world.neighborhood.max_unit_radius + 3.0)
	for other in candidates:
		if is_instance_valid(other) and other is Unit and other.hp > 0.0 and other.embarked_in == null and not other.is_air:
			if p.distance_squared_to(other.position) < (radius + other.radius + 3.0) ** 2:
				return false
	return true

func choose_home(preferred = null, producer_only := false) -> bool:
	if preload("res://scripts/units/peregrine.gd").active(unit):return false
	_waiting_airfield = null
	if is_instance_valid(carrier_owner) and carrier_owner.hp > 0.0:
		home = carrier_owner
		return true
	var world = unit._battle_world()
	if world == null:
		return false
	var allowed: PackedStringArray = str(source.get("Dock", "GAAIRC,AMRADR")).split(",")
	var candidates: Array = world.buildings.filter(func(b):
		return is_instance_valid(b) and b.hp > 0.0 and b.side == unit.side and not b.under_construction and allowed.has(b.building_id))
	if producer_only: candidates = candidates.filter(func(b): return b == preferred)
	candidates.sort_custom(func(a, b): return unit.position.distance_squared_to(a.position) < unit.position.distance_squared_to(b.position))
	if is_instance_valid(preferred) and candidates.has(preferred):
		candidates.erase(preferred)
		candidates.push_front(preferred)
	for b in candidates:
		var slot := return_slot(b)
		if slot >= 0:
			home = b
			dock_slot = slot
			return true
	if not candidates.is_empty(): _waiting_airfield = candidates[0]
	home = null
	dock_slot = -1
	return false

# Read-only slot lookup shared by hover and explicit right-click return.
func return_slot(airport) -> int:
	if ammo_max <= 0 or is_instance_valid(carrier_owner) or not unit.is_air: return -1
	if not is_instance_valid(airport) or not airport is Building or airport.hp <= 0.0 \
			or airport.is_queued_for_deletion() or airport.side != unit.side or airport.under_construction: return -1
	var allowed: PackedStringArray = str(source.get("Dock", "GAAIRC,AMRADR")).split(",")
	if not allowed.has(airport.building_id): return -1
	var world = unit._battle_world()
	if world == null: return -1
	var docks := int(GameData.ra2_source_buildings.get(airport.building_id, {}).get("extra", {}).get("NumberOfDocks", 0))
	# Keep a plane's own reservation when clicking its current airfield.
	var slots: Array = range(docks)
	if home == airport and dock_slot in slots:
		slots.erase(dock_slot)
		slots.push_front(dock_slot)
	for slot in slots:
		var busy := false
		for other in home_members(airport):
			if is_instance_valid(other) and other != unit and other.hp > 0.0 and not other.is_queued_for_deletion() \
					and other.logistics.home == airport and other.logistics.dock_slot == slot:
				busy = true
				break
		if not busy: return slot
	return -1

func request_return(preferred = null) -> bool:
	if preload("res://scripts/units/peregrine.gd").active(unit):return false
	if ammo_max <= 0:
		return false
	var requested_slot := -1
	if preferred != null:
		requested_slot = return_slot(preferred)
		if requested_slot < 0: return false
	unit.order_stop()
	resume_target = null
	air_state = "returning"
	airport_repair_elapsed = 0.0
	reload_elapsed = 0.0
	if preferred != null:
		home = preferred
		dock_slot = requested_slot
	else:
		choose_home(home)
	return true

func _ai_airfield_plane() -> bool:
	if not BattleRequest.is_ai_house(unit.side) or not GameData._ra2_flag(source.get("AirportBound", false)): return false
	var world = unit._battle_world()
	return is_instance_valid(world) and world.skirmish

func tick_return(delta: float) -> bool:
	if not is_instance_valid(home) or home.hp <= 0.0 or home.side != unit.side:
		airport_repair_elapsed = 0.0
		reload_elapsed = 0.0
		air_state = "returning"
		_home_retry -= delta
		if _home_retry <= 0.0 or not _ai_airfield_plane():
			_home_retry = 1.0
			choose_home()
		if not is_instance_valid(home) or home.hp <= 0 or home.side != unit.side:
			if _ai_airfield_plane():
				unit.flight.altitude(1.0, delta)
				if is_instance_valid(_waiting_airfield) and _waiting_airfield.hp > 0.0 and _waiting_airfield.side == unit.side:
					var angle := float(unit.get_instance_id() % 16) * TAU / 16.0
					var offset := Vector2.from_angle(angle) * 120.0
					unit.flight.travel(_waiting_airfield.position + offset, delta, 24.0)
					return true
			unit.velocity = Vector2.ZERO
			return true
	_home_retry = 0.0
	var destination := dock_destination()
	if home is Building and air_state in ["parked", "rearming"] and air_lift <= 0.05:
		# Re-seat legacy parked saves and keep the model on its pad after a health/
		# camera change. A new movement/attack order already switches to flying.
		unit.position = destination
		air_lift = 0.0
	# Once the approach reaches the assigned berth, descend in the moving
	# deck's frame. A moving hull must not restart the climb on every tick.
	var on_deck: bool = is_instance_valid(carrier_owner) and home == carrier_owner
	if on_deck and (air_state == "deck_landing" or unit.position.distance_to(destination) <= maxf(16.0, carrier_owner.radius + unit.radius)):
		air_state = "deck_landing"
		unit.velocity = Vector2.ZERO
		unit.position = unit.position.move_toward(destination, unit.flight.max_speed() * delta)
		unit.flight.altitude(0.0, delta)
		if air_lift <= 0.05 and unit.position.distance_to(destination) <= 2.0:
			unit.position = destination
			air_lift = 0.0
			carrier_owner.logistics.recover(unit)
		return true
	if unit.position.distance_to(destination) > 8.0:
		air_state = "returning"
		unit.flight.altitude(1.0, delta)
		# Our 2D collision layer cannot represent height: parked neighbors must
		# not block an overhead approach to another reserved pad. Keep ordinary
		# airborne traffic collision, and remove only exceptions added here.
		var below: Array = []
		if home is Building and air_lift >= 0.95:
			for other in home_members(home):
				if is_instance_valid(other) and other != unit and other.is_air \
						and other.logistics.home == home and other.logistics.air_lift <= 0.1 \
						and not unit.get_collision_exceptions().has(other):
					unit.add_collision_exception_with(other)
					below.append(other)
		unit.flight.travel(destination, delta, 8.0)
		for other in below:
			if is_instance_valid(other): unit.remove_collision_exception_with(other)
		return true
	unit.velocity = Vector2.ZERO
	# Final touchdown removes the navigation tolerance instead of parking up to
	# eight world units off-center. Airborne approach still uses real flight.
	unit.position = destination
	unit.flight.altitude(0.0, delta)
	if air_lift > 0.05:
		return true
	air_lift = 0.0
	tick_airport_repair(delta)
	if ammo >= ammo_max:
		park_after_sortie()
		return true
	air_state = "rearming"
	if not home.is_operational() or unit._battle_world().side_power_low(unit.side):
		return true
	reload_elapsed += delta
	var reload_seconds := maxf(0.01, float(GameData.ra2_general.get("aircraft", {}).get("reload_minutes", 0.3)) * 60.0)
	if ammo < ammo_max and reload_elapsed >= reload_seconds:
		var previous:=ammo
		ammo += 1
		reload_elapsed = 0.0
		preload("res://scripts/units/expansion_2_aircraft.gd").refill_complete(unit,previous,ammo,ammo_max)
	if ammo >= ammo_max:
		park_after_sortie()
	return true

func tick_airport_repair(delta:float) -> void:
	var world=unit._battle_world()
	if delta<=0 or world==null or world.paused or world.ended or unit.get_tree().paused:return
	if not AlliedAbilities.alive(unit) or unit.special.has("peregrine") or unit.special.has("hero_wreck"):return
	if not home is Building or not AlliedAbilities.alive(home) or home.side!=unit.side or not home.is_operational() or world.side_power_low(unit.side):return
	if air_lift>0.001 or dock_slot<0 or return_slot(home)!=dock_slot or unit.position.distance_to(dock_destination())>2:return
	if unit.hp>=unit.max_hp:
		airport_repair_elapsed=0.0;return
	var rules:Dictionary=GameData.ra2_general.get("repair",{})
	var interval:=maxf(.01,float(rules.get("rate_minutes",.016))*60.0)
	var step:=maxf(0,float(rules.get("step",8)))
	airport_repair_elapsed+=delta
	var ticks:=floori((airport_repair_elapsed+.000001)/interval)
	if ticks<=0:return
	airport_repair_elapsed=maxf(0,airport_repair_elapsed-ticks*interval)
	unit.heal(step*ticks,home)
	if unit.hp>=unit.max_hp:airport_repair_elapsed=0.0

func park_after_sortie() -> void:
	# Only player waypoints may launch another sortie, including after loading a save.
	var pending: Array = unit.order_queue
	if not pending.is_empty() and _ai_airfield_plane(): pending = []
	unit.order_queue = []
	if air_state != "parked" or unit.has_move_order or unit.attack_ordered:
		unit.order_stop()
	resume_target = null
	reload_elapsed = 0.0
	air_state = "parked"
	unit.order_queue = pending
	if not pending.is_empty(): unit._advance_queue()

func dock_destination() -> Vector2:
	if not is_instance_valid(home): return unit.position
	var destination: Vector2 = home.position
	if is_instance_valid(carrier_owner) and home == carrier_owner:
		for index in carrier_owner.logistics.squadron.size():
			if is_same(carrier_owner.logistics.squadron[index].unit, unit):
				return carrier_owner.logistics.deck_position(index)
	if home is Building:
		if AirportDock.supported(home):
			return AirportDock.destination(home, unit, dock_slot)
		destination += Vector2((dock_slot % 2) * 44.0 - 22.0, (dock_slot / 2) * 44.0 - 22.0)
	return destination

func valid_target(target) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.hp > 0.0 \
		and (not BattleRequest.friendly(target.side,unit.side) or ForceFire.active(unit, target)) and unit._weapon_domain_valid(target) and not (target is Unit and target.embarked_in != null)

func deck_position(index: int) -> Vector2:
	var offset := (index - (squadron.size() - 1) * 0.5) * 22.0
	return unit.position + Vector2(0, offset).rotated(unit.hull_angle)

func apply_carrier_attack(shot_bonus: Dictionary) -> void:
	if unit.unit_id not in ["HORNET", "ASW"] or not AlliedAbilities.alive(carrier_owner): return
	if carrier_owner.side != unit.side: return
	# Replace the aircraft's independent growth with its ship's live attack.
	# Preserve aircraft buffs without multiplying shared global growth twice.
	var aircraft_buff := float(shot_bonus.get("attack_bonus", 1.0)) / maxf(unit._base_atk, 0.0001)
	shot_bonus.attack_bonus = float(carrier_owner.bonuses.get("attack_bonus", 1.0)) * aircraft_buff

func tick_squadron(delta: float) -> void:
	var world = unit._battle_world()
	if world == null:
		return
	for index in range(squadron.size()-1,-1,-1):
		var slot: Dictionary = squadron[index]
		if slot.has("reserve_left"):
			slot.reserve_left-=delta
			if slot.reserve_left<=0:
				var retiring=slot.unit
				if not AlliedAbilities.alive(retiring) or retiring.embarked_in==unit or retiring.logistics.ammo<=0:
					squadron.remove_at(index)
					if AlliedAbilities.alive(retiring):
						world.units.erase(retiring)
						world.selected_units.erase(retiring)
						retiring.queue_free()
				continue
		var aircraft = slot.unit
		if typeof(aircraft) != TYPE_NIL and (not is_instance_valid(aircraft) or aircraft.hp <= 0.0):
			slot.unit = null
			slot.timer = float(source.get("SpawnRegenRate", 600)) / 15.0
			aircraft = null
		slot.timer = maxf(0.0, float(slot.timer) - delta * float(unit.get_meta("sonar_hangar_rate",1.0)))
		# Already airborne aircraft cannot launch again; still advance their berth
		# timer and detect death above, but do not revalidate the ship's target.
		if aircraft != null and aircraft.embarked_in != unit: continue
		var target = unit.attack_target
		if slot.timer > 0.0 or (unit.fire_stance == "none" and not unit.attack_ordered) or not valid_target(target):
			continue
		if unit.unit_id == "DEST" and not NavalContact.underwater_type(target):
			continue
		if (target is Unit and target.is_air_target()) or (unit.unit_id == "CARRIER" and unit.position.distance_to(target.position) > unit.attack_range):
			continue
		var launch := deck_position(index)
		if aircraft == null:
			aircraft = world.spawn_unit(str(source.Spawns), unit.side, launch, unit)
			if aircraft == null:
				continue
			slot.unit = aircraft
			aircraft.logistics.carrier_owner = unit
		aircraft.position = launch
		aircraft.set_stowed(null)
		preload("res://scripts/units/expansion_rules.gd").state(aircraft).erase("afterburn_used")
		aircraft.logistics.ammo = aircraft.logistics.ammo_max
		aircraft.logistics.home = unit
		aircraft.logistics.air_state = "flying"
		aircraft.logistics.air_lift = 0.0
		aircraft.hull_angle = unit.hull_angle
		aircraft.order_move(target.position, true)
		aircraft.attack_target = target
		aircraft.attack_ordered = true
		if aircraft.unit_id == "ASW": Ra2Sfx.play("OspreyTakeOff", launch)
		if ForceFire.active(unit, target): aircraft.special[ForceFire.KEY] = target
	sync_deck_art()

func sync_deck_art() -> void:
	if unit.unit_id != "DEST" or squadron.is_empty(): return
	var berth: Dictionary = squadron[0]
	var empty: bool = berth.unit.embarked_in != unit if is_instance_valid(berth.unit) else berth.timer > 0.0
	var id := "DESTWO" if empty else "DEST"
	var hull := RA2Art.art(id)
	if hull.is_empty() or unit._ra2.get("tex") == hull.tex: return
	unit._ra2 = hull
	unit._ra2_shd = RA2Art.art(id + "_shd")
	unit.queue_redraw()

func recover(aircraft) -> void:
	for slot in squadron:
		if slot.unit == aircraft:
			aircraft.set_stowed(unit)
			slot.timer = float(source.get("SpawnReloadRate", 150)) / 15.0
			preload("res://scripts/units/expansion_cards.gd").recover(unit,aircraft)
			if aircraft.unit_id == "ASW":
				Ra2Sfx.play("OspreyLanding", unit.position)
				sync_deck_art()
			return

func destroyed() -> void:
	if is_instance_valid(carrier_owner):
		for berth in carrier_owner.logistics.squadron:
			if berth.unit == unit:
				berth.unit = null
				berth.timer = float(carrier_owner.logistics.source.SpawnRegenRate) / 15.0
				carrier_owner.logistics.sync_deck_art()
				break
	for passenger in passengers.duplicate():
		if is_instance_valid(passenger) and passenger.hp > 0.0:
			passenger.hp = 0.0
			passenger._die()
	passengers.clear()
	for slot in squadron:
		if is_instance_valid(slot.unit) and slot.unit.hp > 0.0:
			slot.unit.hp = 0.0
			slot.unit._die()
	squadron.clear()

func status() -> String:
	if preload("res://scripts/units/peregrine.gd").active(unit):
		return "弹药 %d / %d · 空中自动补弹 · 不占机场位"%[ammo,ammo_max]
	if capacity > 0:
		if unit.unit_id == "FV" and not passengers.is_empty():
			return "%s · %s" % [passengers[0].display_name, "维修模式" if AlliedAbilities.is_repair_ifv(unit) else "D 卸载"]
		return "乘员 %d / %d · %s" % [used_capacity(), capacity, "卸载中" if unloading else "右键载具装载 · D 卸载"]
	if ammo_max > 0:
		var names := {"flying": "飞行", "returning": "返航", "deck_landing": "降落甲板", "rearming": "补弹", "parked": "停靠"}
		return "弹药 %d / %d · %s" % [ammo, ammo_max, names.get(air_state, air_state)]
	if not squadron.is_empty():
		var active := 0
		for slot in squadron:
			if is_instance_valid(slot.unit) and slot.unit.hp > 0.0:
				active += 1
		return "舰载机 %d / %d" % [active, squadron.size()]
	return ""
