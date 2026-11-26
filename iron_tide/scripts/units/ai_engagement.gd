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

## Campaign Area Guard is distinct from sitting on Guard or following a team script.
## Use the local sight radius as a leash; weapon reach still gates actual firing.
static func area_guard(unit: Unit, target, reach: float, delta: float) -> bool:
	if unit.side != "enemy" or unit.hold_position or unit.fire_stance != "free": return false
	if unit.has_move_order or unit.attack_ordered or unit.attack_move or unit.patrolling or not unit.order_queue.is_empty(): return false
	if unit._deployed or unit.repairing or unit.embarked_in != null or unit.is_harvester or unit.is_air or unit.weapon.is_empty(): return false
	if unit.special.has("action") or unit.special.has("finished_attack_route"): return false
	var post: Vector2 = unit.special.campaign_area_guard
	if AlliedAbilities.alive(target):
		var distance := CommandoCombat.distance_to(unit, target)
		if distance <= reach: return false # Normal facing and firing, including minimum range.
		var limit := maxf(unit.sight, reach)
		if visible_enemy(unit, target) and post.distance_squared_to(target.global_position) <= limit * limit and post.distance_squared_to(unit.global_position) <= limit * limit:
			if unit._chase_goal == post: unit._chase_goal = Vector2.INF
			unit._chase_target(unit._attack_approach(target), delta, true)
			unit._face_if_moving()
			unit._move_water_safe()
			return true
	if unit.global_position.distance_squared_to(post) > Unit.ARRIVE_EPS * Unit.ARRIVE_EPS:
		if unit._chase_goal != post: unit._chase_goal = Vector2.INF
		unit._chase_target(post, delta, true)
		unit._face_if_moving()
		unit._move_water_safe()
		return true
	return false

static func busy(unit: Unit) -> bool:
	var target = unit.attack_target
	if not AlliedAbilities.alive(target): return false
	if unit.attack_ordered: return true
	if unit.fire_stance=="none" or not unit._automatic_target_allowed(target): return false
	if not visible_enemy(unit,target): return false
	var reach := OpenTopped.command_range(unit,target)
	var distance := CommandoCombat.distance_to(unit,target)
	return (distance>=unit.min_range and distance<=reach) or unit._can_pursue_attacker(target,reach) or air_pursuit(unit,target)
