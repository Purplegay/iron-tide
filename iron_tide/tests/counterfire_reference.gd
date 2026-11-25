extends RefCounted
## Local, O(1) reaction to a real hit. Never issues a route or touches player orders.
const RESUME := "ai_counterfire_resume"

static func update(unit) -> bool:
	if not BattleRequest.is_ai_house(unit.side): return false
	if unit._return_timer<=0 and not unit.special.has(RESUME): return false
	var target = unit.special.get("retaliation_target")
	var valid: bool = unit._return_timer>0 and AlliedAbilities.alive(target)
	valid = valid and not unit.is_harvester and not unit.repairing and unit.embarked_in==null and not unit.is_air and unit.logistics.ammo_max==0
	valid = valid and unit.fire_stance!="none" and not unit.special.has("action") and not unit.weapon.is_empty()
	if valid:
		var world = unit._battle_world()
		valid = world!=null and not BattleRequest.friendly(unit.side,target.side) and world.actor_visible_to(unit.side,target) and unit.attack_domain_valid(target)
	if valid:
		var distance: float = CommandoCombat.distance_to(unit,target)
		valid = distance>=unit.min_range and distance<=OpenTopped.command_range(unit,target)
	if valid and unit._burst_left>0 and unit._burst_target!=target: return false
	if not valid:
		if unit.special.has(RESUME):
			var previous: Dictionary = unit.special[RESUME]
			unit.special.erase(RESUME)
			unit.attack_target=previous.target if AlliedAbilities.alive(previous.target) else null
			unit.attack_ordered=previous.ordered and unit.attack_target!=null
		return false
	if not unit.special.has(RESUME):
		unit.special[RESUME]={"target":unit.attack_target,"ordered":unit.attack_ordered}
	unit.attack_target=target
	unit.attack_ordered=false
	return true
