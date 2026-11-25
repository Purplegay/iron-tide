extends RefCounted
## AI contact policy. Passive target acquisition alone does not occupy a unit.
const RESUME := "ai_pursuit_resume"

static func begin_ground_pursuit(unit: Unit) -> void:
	if BattleRequest.is_ai_house(unit.side) and unit.has_move_order and not unit.special.has(RESUME):
		unit.special[RESUME]={"goal":unit.move_target,"advance":unit.attack_move}

static func resume_route(unit: Unit) -> void:
	if not unit.special.has(RESUME): return
	var target = unit.special.get("retaliation_target")
	if unit._can_pursue_attacker(target,unit.attack_range): return
	var saved:Dictionary=unit.special[RESUME]
	unit.special.erase(RESUME)
	unit.order_move(saved.goal,saved.advance)

static func visible_enemy(unit: Unit, target) -> bool:
	if not AlliedAbilities.alive(target) or BattleRequest.friendly(unit.side,target.side): return false
	var world := unit._battle_world()
	return world!=null and world.actor_visible_to(unit.side,target) and unit.attack_domain_valid(target)

static func air_pursuit(unit: Unit, target) -> bool:
	if not unit.is_air or unit.logistics.ammo_max>0 or not BattleRequest.is_ai_house(unit.side): return false
	if unit.hold_position or unit.repairing or unit.embarked_in!=null or unit.special.has("action"): return false
	if unit.fire_stance!="free" and not unit.attack_move: return false
	if unit.has_move_order and not unit.attack_move: return false
	if not unit.order_queue.is_empty() or unit.special.has("finished_attack_route"): return false
	if not AlliedAbilities.alive(target) or unit.position.distance_to(target.position)>maxf(unit.sight,unit.attack_range): return false
	return unit._automatic_target_allowed(target) and visible_enemy(unit,target)

static func busy(unit: Unit) -> bool:
	var target = unit.attack_target
	if not AlliedAbilities.alive(target): return false
	if unit.attack_ordered: return true
	if unit.fire_stance=="none" or not unit._automatic_target_allowed(target): return false
	if not visible_enemy(unit,target): return false
	var reach := OpenTopped.command_range(unit,target)
	var distance := CommandoCombat.distance_to(unit,target)
	return (distance>=unit.min_range and distance<=reach) or unit._can_pursue_attacker(target,reach) or air_pursuit(unit,target)
