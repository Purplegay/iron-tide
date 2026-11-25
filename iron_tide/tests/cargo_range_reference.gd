extends RefCounted
# Frozen pre-change carrier range/domain loop for independent equivalence checks.
static func query_weapon_reusable(unit:Unit) -> bool:
	return OpenTopped.query_weapon_reusable(unit)

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
		if target == null or passenger._weapon_domain_valid(target, false, passenger_gun):
			valid = true
			reach = maxf(reach, float(passenger_gun.get("range", 0.0)))
	if not domain_result.is_empty(): domain_result[0] = valid
	return reach

