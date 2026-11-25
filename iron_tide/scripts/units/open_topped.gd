class_name OpenTopped
extends RefCounted
## Independent adapter for YR OpenTopped. Passengers retain their own weapon,
## reload, veterancy and target; the carrier is never replaced with an IFV weapon.

static func active(unit: Unit) -> bool:
	return unit.embarked_in is Unit and AlliedAbilities.alive(unit.embarked_in) and AlliedAbilities.flag(unit.embarked_in, "OpenTopped")

static func weapon(unit: Unit, base: Dictionary) -> Dictionary:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(75)
	if not active(unit) or base.is_empty(): return base
	# Deployer infantry fire their deployed weapon from an open transport.
	var result: Dictionary = base
	if unit.unit_id in ["E1", "GGI"]:
		result = unit.deployed_weapon()
	# Only scalar range/damage are adjusted; immutable nested weapon metadata
	# need not be recursively copied on every target/range query.
	result = result.duplicate()
	var rules: Dictionary = unit.embarked_in.data.open_topped
	result.range = float(result.get("range", 0.0)) + float(rules.range_bonus)
	result.damage = float(result.get("damage", 0.0)) * float(rules.damage_multiplier)
	return result

static func tick(unit: Unit, delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(28)
	if not active(unit): return
	var carrier: Unit = unit.embarked_in
	unit.global_position = carrier.global_position
	var previous_cd: float = unit._cd_timer
	var previous_target = unit.attack_target
	unit._cd_timer -= delta
	unit._think_timer -= delta
	unit._stun_timer = maxf(0.0, unit._stun_timer - delta)
	unit._tick_buffs(delta)
	AlliedAbilities.tick_actor(unit, delta)
	if not AlliedAbilities.alive(unit): return
	if carrier.side != unit.side or carrier.fire_stance == "none" or carrier._stun_timer > 0.0 \
			or (carrier.fire_stance == "return" and not carrier.attack_ordered and not carrier.attack_move and carrier._return_timer <= 0.0) \
			or unit._stun_timer > 0.0 or AlliedAbilities.frozen(carrier) or AlliedAbilities.frozen(unit):
		unit._cancel_burst()
		AlliedAbilities.release_temporal(unit)
		return
	# Embarked weapons inherit the carrier's command, not the passenger's idle stance.
	unit.fire_stance = carrier.fire_stance
	unit.attack_move = carrier.attack_move
	unit.attack_ordered = carrier.attack_ordered
	unit._return_timer = carrier._return_timer
	unit.special.retaliation_target = carrier.special.get("retaliation_target")
	unit._refresh_weapon_derived()
	if AlliedAbilities.channel(unit, delta): return
	# A passenger unable to hit the carrier's target keeps a different target.
	# That is not a fresh order every physics tick. Retry on the normal scan
	# cadence, but react immediately when the carrier receives a new target.
	var ordered_target = carrier.attack_target if carrier.attack_ordered else null
	var commanded: bool = AlliedAbilities.alive(ordered_target) and not is_same(unit._cargo_command_target,ordered_target)
	unit._cargo_command_target=ordered_target
	if unit._think_timer <= 0.0 or commanded or (is_instance_valid(unit.attack_target) and not unit._weapon_target_valid(unit.attack_target)):
		unit._think_timer = unit.TARGET_REFRESH
		unit.attack_ordered = carrier.attack_ordered
		if carrier.attack_ordered and unit._weapon_target_valid(carrier.attack_target):
			unit.attack_target = carrier.attack_target
		else:
			var hold: bool = unit.hold_position
			unit.hold_position = true # No chasing while embarked; choose an in-range target.
			unit._refresh_target()
			unit.hold_position = hold
	if AlliedAbilities.alive(unit.attack_target):
		unit.aim_dir = unit.global_position.direction_to(unit.attack_target.global_position)
		unit.hull_angle = unit.aim_dir.angle()
		unit.turret_angle = unit.hull_angle
	unit._advance_firing(delta, previous_cd, previous_target)

static func muzzle(unit: Unit) -> Vector2:
	var carrier: Unit = unit.embarked_in
	var seat: int = maxi(0, carrier.logistics.passengers.find(unit))
	# Separate roof ports; world-space offsets are projected by the existing effects renderer.
	var along := float(seat / 2) * 9.0 - 9.0
	var across := -11.0 if seat % 2 == 0 else 11.0
	return carrier.global_position + Vector2(along, across).rotated(carrier.hull_angle) \
		+ RA2Art.art_dir(Vector2(0.0, -24.0))

# Only ordinary GI/GGI cargo has the same weapon for every candidate. Keep
# heroes and alternate domain/type resolvers on the live per-target path.
static func query_weapon_reusable(unit: Unit) -> bool:
	return unit.unit_id in ["E1", "GGI"] and unit.embarked_in is Unit and not unit.special.has("academy_hero") \
		and not unit.data.has("anti_air_weapon") and not unit.data.has("special_weapon")

static func command_range(carrier: Unit, target = null, resolved_weapon: Dictionary = {}, domain_result: Array = [], open_topped = null, query_weapons: Dictionary = {}) -> float:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(74)
	if carrier.unit_id == "DEST" and NavalContact.underwater_type(target):
		# Range=-2: aircraft on patrol can use an allied sensor contact beyond
		# the mothership's own sonar. Normal domain/visibility and stance checks still apply.
		if carrier.attack_ordered and target == carrier.attack_target:return INF
		if NavalContact.submerged(target):return INF # Domain validation requires detection.
		var world=carrier._battle_world()
		if world!=null and NavalContact.detected(world,carrier.side,target):return INF
		return NavalContact.sensor_range(carrier)
	var gun := resolved_weapon
	if gun.is_empty() and carrier.data.has("anti_air_weapon"): gun = carrier._weapon_for_target(target)
	var reach: float = gun.get("range", carrier.attack_range) if carrier.data.has("anti_air_weapon") else carrier.attack_range
	if carrier.unit_id == "DRED" and is_instance_valid(target) and target is Building:
		var half_size: Vector2 = target.foundation_half() / Building.BUILD_GRID
		if minf(half_size.x,half_size.y) >= 1.0:
			reach += ceilf(minf(half_size.x,half_size.y)) * Ra2Damage.PX_PER_CELL
	# A caller may supply the result of the same synchronous eligibility branch.
	# Never retain it across updates: capability/state changes remain live.
	if not (AlliedAbilities.flag(carrier, "OpenTopped") if open_topped == null else open_topped): return reach
	# The optional result belongs to this synchronous query only. A zero-range
	# valid weapon is distinct from having no eligible weapon at all.
	var valid := target == null or carrier._weapon_domain_valid(target, false, gun)
	if not valid: reach = 0.0
	for passenger in carrier.logistics.passengers:
		if not AlliedAbilities.alive(passenger) or passenger.side != carrier.side: continue
		preload("res://scripts/world/battle_call_counters.gd").iterations(74,1)
		var passenger_gun: Dictionary
		# The dictionary belongs to this one synchronous target scan. Membership,
		# domain, cover and visibility are still checked for every target.
		var reuse: bool = query_weapons.get("enabled",false) and query_weapon_reusable(passenger)
		var key: int = passenger.get_instance_id()
		if reuse and query_weapons.has(key):
			passenger_gun = query_weapons[key]
			preload("res://scripts/world/battle_call_counters.gd").iterations(73,1)
		else:
			passenger_gun = passenger._weapon_for_target(target)
			if reuse: query_weapons[key] = passenger_gun
		var passenger_reach:float=float(passenger_gun.get("range",0.0))
		# Once one weapon is eligible, a shorter/equal range cannot change either
		# output. This is local to this target query, with no cross-unit cache.
		if valid and passenger_reach<=reach:
			if target!=null:preload("res://scripts/world/battle_call_counters.gd").iterations(80,1)
			continue
		if target == null or passenger._weapon_domain_valid(target, false, passenger_gun):
			valid = true
			reach = maxf(reach, passenger_reach)
	if not domain_result.is_empty(): domain_result[0] = valid
	return reach

## Conservative broad-phase bound. Domain, cover, live range and scoring still
## run per candidate. Infantry with a target-dependent weapon keep the full scan.
static func search_bound(carrier: Unit) -> float:
	var reach:float = carrier.attack_range
	for passenger in carrier.logistics.passengers:
		if not AlliedAbilities.alive(passenger) or passenger.side != carrier.side: continue
		if not AlliedAbilities.infantry(passenger) or passenger.unit_id=="BORIS" or CommandoCombat.handles(passenger):
			return INF
		var gun:Dictionary = passenger._weapon_for_target(null)
		reach = maxf(reach,float(gun.get("range",0.0)))
		if passenger.data.has("anti_air_weapon"):
			var aa:Dictionary=passenger.data.elite_anti_air_weapon if passenger.veteran_level>=2 else passenger.data.anti_air_weapon
			aa=weapon(passenger,aa)
			var hero_bonus:=Ra2Damage.PX_PER_CELL if passenger.special.has("academy_hero") else 0.0
			reach=maxf(reach,float(aa.get("range",0.0))+hero_bonus)
	return reach

static func cargo_can_attack(carrier: Unit, target) -> bool:
	if carrier.logistics.passengers.is_empty() or not AlliedAbilities.flag(carrier, "OpenTopped"): return false
	for passenger in carrier.logistics.passengers:
		if AlliedAbilities.alive(passenger) and passenger.side == carrier.side and passenger._weapon_domain_valid(target): return true
	return false

static func can_crush(carrier: Unit, other, heavy := false) -> bool:
	return (heavy or AlliedAbilities.flag(carrier, "OmniCrusher")) and other is Unit \
		and AlliedAbilities.alive(other) and not BattleRequest.friendly(other.side,carrier.side) and other.embarked_in == null \
		and not other.is_air and not other.is_naval and not AlliedAbilities.flag(other, "OmniCrushResistant")

static func crush_contact(carrier: Unit, heavy := false) -> void:
	if (not heavy and not AlliedAbilities.flag(carrier, "OmniCrusher")) or carrier.velocity.length() < 18.0: return
	var group := BattleRequest.foes_group(carrier.side)
	var world = carrier._battle_world()
	var local_search:bool=world is Battle and world.units.size()>=96
	var actors:Array=world.neighborhood.nearby(carrier.global_position,carrier.radius+world.neighborhood.max_unit_radius+4.0) if local_search else carrier.get_tree().get_nodes_in_group(group)
	for other in actors:
		if not is_instance_valid(other) or not other is Unit or (local_search and not other.is_in_group(group)): continue
		var offset: Vector2 = other.global_position - carrier.global_position
		var reach: float = carrier.radius + other.radius + 4.0
		if offset.length_squared() <= reach * reach and offset.dot(carrier.velocity) > 0.0 and can_crush(carrier, other, heavy):
			other.receive_hit(99999.0, "crush", {}, carrier)
