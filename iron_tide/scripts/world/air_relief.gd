extends RefCounted
## Bounded, owner-local aircraft distress calls. Policy values are IronTide AI
## decisions; weapon domains, visibility and command admission remain native.
const ALERTS := "ai_air_distress"
const ASSIGNMENT := "ai_air_relief"
const INTERVAL := 0.75
const LIFE := 6.0
const RADIUS := 800.0
const MAX_ALERTS := 8
const MAX_RESPONDERS := 4

static func alert(victim, attacker) -> void:
	if not (victim.is_air or victim.is_air_target()) or not BattleRequest.is_ai_house(victim.side): return
	var world = victim._battle_world()
	if world == null or not world.skirmish or not world.actor_alive(attacker): return
	if BattleRequest.friendly(victim.side,attacker.side) or not world.actor_visible_to(victim.side,attacker): return
	var calls: Dictionary = world.ai_decisions(victim.side).get_or_add(ALERTS,{})
	if not calls.has(victim) and calls.size() >= MAX_ALERTS: return
	calls[victim] = {"target":attacker,"until":victim._anim+LIFE}

static func assignment(world, unit) -> Dictionary:
	var record: Dictionary = unit.special.get(ASSIGNMENT,{})
	if record.is_empty(): return {}
	var victim = record.get("victim")
	var target = record.get("target")
	if not world.actor_alive(victim) or not world.actor_alive(target) or victim.side!=unit.side \
			or not BattleRequest.is_ai_house(unit.side) or unit._anim>=float(record.until) \
			or BattleRequest.friendly(unit.side,target.side) or not world.actor_visible_to(unit.side,target) \
			or not unit.attack_domain_valid(target):
		unit.special.erase(ASSIGNMENT)
		return {}
	return record

static func blocks_order(world, unit, order: Dictionary) -> bool:
	if order.kind not in ["rally","advance","guard","attack"]: return false
	var record := assignment(world,unit)
	return not record.is_empty() and (order.kind!="attack" or order.get("target")!=record.target)

static func eligible(world, unit, victim, target) -> bool:
	if not world.actor_alive(unit) or unit==victim or unit.side!=victim.side: return false
	if unit.embarked_in!=null or unit.is_harvester or unit.repairing or unit._deployed \
			or unit.special.has("action") or unit.special.has("ai_deploy_mission") \
			or unit.special.has("hero_wreck") or unit.special.get("ai_transport_reserved",false) \
			or not unit.deploy_building_id().is_empty() or unit.unit_id in ["SHAD","DTRUCK"] \
			or is_instance_valid(unit.logistics.carrier_owner) or unit._burst_left>0 \
			or AlliedAbilities.frozen(unit): return false
	if unit.position.distance_squared_to(victim.position)>RADIUS*RADIUS or not unit.attack_domain_valid(target): return false
	if world.actor_alive(unit.attack_target) and unit.attack_target!=target: return false
	if unit.logistics.ammo_max>0 and (unit.logistics.ammo<=0 or unit.logistics.air_state not in ["parked","flying"]): return false
	if unit.logistics.ammo_max>0 and unit.logistics.air_state=="parked" and unit.logistics.ammo<unit.logistics.ammo_max: return false
	# Do not dispatch ground reinforcements across water or disconnected islands.
	# Building centers are blocked cells: test the reachable firing edge instead.
	if not unit.is_air and not unit.is_amphibious and world.path_service!=null:
		var reach := OpenTopped.command_range(unit,target)
		if CommandoCombat.distance_to(unit,target)>reach:
			var point: Vector2 = target.position.move_toward(unit.position,maxf(16.0,reach*0.8))
			if not world.path_service.same_zone(unit.position,point,unit.is_naval): return false
	return true

static func tick(ai, dt: float) -> void:
	var state: Dictionary = ai.ai_state
	var calls: Dictionary = state.get(ALERTS,{})
	if calls.is_empty(): return
	var wait := float(state.get("ai_air_relief_wait",0.0))-dt
	state.ai_air_relief_wait = wait
	if wait>0: return
	state.ai_air_relief_wait = INTERVAL
	var world = ai.battle
	# One bounded roster pass only while a distress call exists.
	var roster: Array = []
	var assigned := 0
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side!=ai.house_id: continue
		if not assignment(world,unit).is_empty(): assigned+=1
		else: roster.append(unit)
	for victim in calls.keys():
		var call: Dictionary = calls[victim]
		var target = call.get("target")
		if not world.actor_alive(victim) or victim.side!=ai.house_id or victim._anim>=float(call.until) \
				or not world.actor_alive(target) or BattleRequest.friendly(ai.house_id,target.side) \
				or not world.actor_visible_to(ai.house_id,target):
			calls.erase(victim)
			continue
		if assigned>=MAX_RESPONDERS: continue
		var candidates: Array = roster.filter(func(unit): return eligible(world,unit,victim,target))
		candidates.sort_custom(func(a,b): return a.position.distance_squared_to(victim.position)<b.position.distance_squared_to(victim.position))
		for unit in candidates:
			unit.special[ASSIGNMENT] = {"victim":victim,"target":target,"until":unit._anim+LIFE}
			world.ai_dispatch.submit(world,unit,{"kind":"attack","target":target,"air_relief":true})
			roster.erase(unit)
			assigned+=1
			if assigned>=MAX_RESPONDERS: break
	if calls.is_empty(): state.erase(ALERTS)
