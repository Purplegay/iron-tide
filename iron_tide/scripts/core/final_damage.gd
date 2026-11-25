extends RefCounted
## A per-hit reference travels with the attack. Never compress the shooter's stats.
static func active() -> bool:
	return BattleRequest.extensions_enabled() and (BattleRequest.combat_context.get("mixed_damage_caps",false) or float(BattleRequest.combat_context.get("final_damage_cap",0))>2.0)

static func limit_for(side:String) -> float:
	var profiles:Dictionary=BattleRequest.combat_context.get("house_training",{})
	if profiles.has(side):return {5:3.5,6:2.25}.get(profiles[side].difficulty,0.0)
	return float(BattleRequest.combat_context.get("final_damage_cap",0)) if side=="enemy" or BattleRequest.is_ai_house(side) else 0.0

static func weapon_reference(weapon:Dictionary,target,bonus:Dictionary,distance:float=0.0) -> float:
	if not active() or not is_instance_valid(target) or target is ForceFirePoint:return 0.0
	return CombatMath.full_damage(weapon,target.armor,{"veteran_attack":bonus.get("veteran_attack",1.0)},null,target.ra2_armor,distance,target)

static func packet(bonus:Dictionary,reference:float) -> Dictionary:
	if not active():return bonus
	var result:=bonus.duplicate()
	result.hit_reference_damage=reference
	return result

static func hit_reference(target,bonus:Dictionary,source) -> float:
	if not active() or limit_for(target.side)<=2.0:return 0.0
	if bonus.has("hit_reference_damage"):return float(bonus.hit_reference_damage)
	var weapon:Dictionary=bonus.get("reference_weapon",{})
	if weapon.is_empty() and is_instance_valid(source):
		if source is Unit:weapon=source._active_weapon()
		elif source is Building:weapon=source.weapon
	return weapon_reference(weapon,target,bonus) if not weapon.is_empty() else 0.0

static func apply(damage:float,reference:float,target,bonus:Dictionary,source) -> float:
	if not active() or damage<=0 or reference<=0 or limit_for(target.side)<=2.0 or GM.one_shot_kill:return damage
	var owner:=str(bonus.get("damage_owner_side",""))
	if is_instance_valid(source):
		owner=source.owner_side if source is Projectile else str(source.get("side"))
	if owner!="ally":return damage
	var threshold:=float(BattleRequest.combat_context.get("final_damage_threshold",2.0))
	if BattleRequest.combat_context.has("house_training"):
		threshold=1.5 if BattleRequest.brutal_house(target.side) else 2.0
	return reference*CombatMath.compress_growth(damage/reference,limit_for(target.side),threshold)
