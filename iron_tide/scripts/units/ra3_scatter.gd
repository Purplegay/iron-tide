extends RefCounted
## Source OCL chain: Regular -> End or Veteran1 -> Veteran2 -> End.
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_completion_rules.json"))

static func fire(unit, primary, weapon: Dictionary, bonuses: Dictionary) -> void:
	var world = unit._battle_world()
	if world == null: return
	var visited: Array = [primary]
	var first := 1 if unit.veteran_level >= 3 else 0
	var branches := emit(unit, primary, rules.scatter[first], weapon, bonuses, visited)
	if first == 1:
		for branch in branches: emit(unit, branch, rules.scatter[2], weapon, bonuses, visited)

static func emit(unit, source, rule: Dictionary, weapon: Dictionary, bonuses: Dictionary, visited: Array) -> Array:
	var world = unit._battle_world()
	var candidates: Array = []
	var radius := float(rule.range) * Ra3Mirage.WORLD_SCALE
	for target in world.units + world.buildings:
		if not AlliedAbilities.alive(target) or target in visited or BattleRequest.friendly(target.side,unit.side): continue
		if target is Unit and (target.embarked_in != null or target.is_air_target()): continue
		if not world.actor_visible_to(unit.side, target): continue
		if source.position.distance_to(target.position) <= radius: candidates.append(target)
	candidates.sort_custom(func(a, b): return source.position.distance_squared_to(a.position) < source.position.distance_squared_to(b.position))
	var reached: Array = []
	var next := weapon.duplicate(true)
	next.range = radius; next.damage = float(rule.damage); next.damage_delay = float(rule.delay)
	for target in candidates.slice(0, int(rule.count)):
		visited.append(target); reached.append(target)
		var damage: float
		if rule.kind == "CANNON":
			next.ra2_warhead = "RA3_EXPANSION"
			damage = CombatMath.with_offense(cannon_damage(float(rule.damage), target), bonuses)
		else:
			damage = CombatMath.full_damage(next, target.armor, bonuses, null, target.ra2_armor, 0.0, target)
		Ra3WeaponFx.spawn(unit, target, source.art_center(), true, source)
		var packet:=bonuses
		if CombatMath.FinalDamage.active():
			var reference:=cannon_damage(float(rule.damage),target)*float(bonuses.get("veteran_attack",1.0)) if rule.kind=="CANNON" else CombatMath.FinalDamage.weapon_reference(next,target,bonuses)
			packet=CombatMath.FinalDamage.packet(bonuses,reference)
		Ra3Mirage.schedule_hit(unit, target, next, damage, packet)
	return reached

static func cannon_damage(amount: float, target) -> float:
	if target is Unit and (Ra3Mirage.handles(target) or Ra3Expansion.handles(target)):
		return amount * float(rules.cannon_armor[target.unit_id])
	var profiles: Dictionary = Ra3Expansion.rules.target_profiles
	var id: String = target.building_id if target is Building else target.unit_id
	var category := "building" if target is Building else ("naval" if target.is_naval else ("infantry" if AlliedAbilities.infantry(target) else "vehicle"))
	var key: String = profiles.mapping.get(id, profiles.fallback[category])
	var profile: Dictionary = profiles.profiles[key]
	return amount * float(rules.cannon_armor[key]) * float(target.data.hp) / float(profile.hp)
