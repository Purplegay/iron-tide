extends RefCounted
## Independent local target policy. Callers retain visibility/domain/order authority.
## Scores are preferences, not damage changes or predictions of guaranteed kills.

static func score(shooter, target, weapon: Dictionary, current) -> float:
	var distance: float = shooter.global_position.distance_to(target.global_position)
	if distance < float(weapon.get("min_range", 0.0)):
		return -INF
	var armor = target.get("ra2_armor")
	var damage := CombatMath.full_damage(weapon, str(target.get("armor")), shooter.bonuses,
		target.get("bonuses"), "" if armor == null else str(armor), 0.0, target)
	if damage <= 0.0:
		return -INF
	var effectiveness := clampf(damage / maxf(1.0, float(weapon.get("damage", 0.0))), 0.0, 4.0)
	var volley := damage * maxi(1, int(weapon.get("burst", 1)))
	var volleys := maxf(1.0, ceil(float(target.hp) / maxf(0.01, volley)))
	var wounded := 1.0 - clampf(float(target.hp) / maxf(1.0, float(target.max_hp)), 0.0, 1.0)
	var result := 2.0 * sqrt(effectiveness) + 4.0 / volleys + 0.6 * wounded
	result -= 0.5 * distance / maxf(1.0, float(shooter.attack_range))
	# A shootable target always beats a target which would need pursuit.
	if distance > shooter.attack_range:
		result -= 16.0
	if shooter is Unit and BattleRequest.is_ai_house(shooter.side) and target is Building and distance<=shooter.attack_range:
		result+=2.0
	if target == current:
		result += 0.5
	return result
