extends RefCounted
## Per-house offensive roles persist in ordinary snapshot dictionaries.
const START_COUNT := 32
const HOME_GUARD := 10
const ROLE := "ai_campaign_role"

static func eligible(ai, unit) -> bool:
	if ai.Tactics.fighter(ai.battle,unit,ai.house_id): return true
	return ai.battle.actor_alive(unit) and unit.side==ai.house_id and unit.embarked_in==null and not unit.is_harvester and unit.unit_id not in ["SHAD","LCRF","SAPC"] and (unit.is_naval or unit.logistics.ammo_max>0) and not unit.weapon.is_empty()

static func defensive_contacts(ai, unit, contacts: Array) -> Array:
	if not ai.ai_state.get("campaign_started",false): return contacts
	reinforcement(ai,unit)
	if unit.special.get(ROLE)!="guard": return contacts
	return contacts.filter(func(target):return target.position.distance_to(ai.base_center)<=ai.Tactics.BASE_DEFENSE_RADIUS or CommandoCombat.distance_to(unit,target)<=OpenTopped.command_range(unit,target))

static func guards(ai) -> int:
	var count := 0
	for unit in ai.battle.units:
		if eligible(ai,unit) and unit.special.get(ROLE)=="guard": count+=1
	return count

static func reinforcement(ai, unit) -> void:
	var state: Dictionary = ai.ai_state
	if not state.get("campaign_started",false) or not eligible(ai,unit) or unit.special.has(ROLE): return
	if guards(ai)<HOME_GUARD:
		unit.special[ROLE]="guard"
		return
	unit.special[ROLE]="attack"
	state.campaign_due=true

static func wave(ai) -> Array:
	var state: Dictionary = ai.ai_state
	if not state.get("campaign_started",false):
		if ai.battle.ai_living_count(ai.house_id)<START_COUNT: return []
		var fighters: Array = ai.battle.units.filter(func(u):return eligible(ai,u))
		if fighters.size()<=HOME_GUARD: return []
		fighters.sort_custom(func(a,b):
			var land_a: bool=ai.Tactics.fighter(ai.battle,a,ai.house_id)
			var land_b: bool=ai.Tactics.fighter(ai.battle,b,ai.house_id)
			if land_a!=land_b:return land_a
			return a.position.distance_squared_to(ai.base_center)<b.position.distance_squared_to(ai.base_center))
		for i in fighters.size():
			var unit = fighters[i]
			unit.special[ROLE]="guard" if i<HOME_GUARD else "attack"
			if i<HOME_GUARD and ai.Tactics.fighter(ai.battle,unit,ai.house_id) and not AlliedAbilities.alive(unit.attack_target):
				if not ai._army.has(unit): ai._army.append(unit)
				ai.Micro.release(unit)
				ai.Assembly.assemble(ai,unit)
		state.campaign_started=true
	else:
		# Old saves and recovered transports may introduce unassigned fighters.
		for unit in ai.battle.units: reinforcement(ai,unit)
		rebalance(ai)
	var ready: Array = ai.wave_candidates(true)
	var result := []
	for unit in ready:
		if unit.special.get(ROLE)=="attack": result.append(unit)
		elif not unit.hold_position and not unit.has_move_order and not is_instance_valid(unit.attack_target) and not unit.special.has("ai_defense_goal") \
				and not unit.special.has("ai_dispatch_pending") and not ai.Assembly.needs_new_slot(ai,unit):
			unit.ai_order("guard")
	state.erase("campaign_due")
	return result

static func rebalance(ai) -> void:
	# Attrition must not leave permanently increasing reserves while the attack dies out.
	if not ai.ai_state.get("campaign_started",false): return
	# Field skirmishes must not freeze all surplus home guards indefinitely.
	# Legacy alarms without the base flag retain their conservative behavior.
	var alarm: Dictionary = ai.ai_state.get("brutal_alarm", {})
	if not alarm.is_empty():
		if alarm.get("base",true): return
		var point: Vector2 = alarm.get("point",ai.base_center)
		if point.distance_squared_to(ai.base_center)<=ai.Tactics.BASE_DEFENSE_RADIUS*ai.Tactics.BASE_DEFENSE_RADIUS: return
	var reserve:=0
	var idle:Array=[]
	for unit in ai.battle.units:
		if not eligible(ai,unit): continue
		if unit.special.get(ROLE)!="guard": continue
		reserve+=1
		if unit.repairing or unit.special.has("action") or unit.special.has("ai_deploy_mission") or AlliedAbilities.frozen(unit): continue
		if ai.battle.actor_alive(unit.attack_target) or unit.special.has("ai_defense_goal"): continue
		if unit.has_move_order or unit.special.has("ai_dispatch_pending"): continue
		if unit.special.has("brutal_relief_at") and not alarm.is_empty():
			var assigned: Vector2 = unit.special.brutal_relief_at
			var point: Vector2 = alarm.get("point",assigned)
			if assigned.distance_squared_to(point)<160.0*160.0 and unit.position.distance_squared_to(point)<180.0*180.0: continue
		idle.append(unit)
	var surplus:=reserve-HOME_GUARD
	if surplus<=0: return
	idle.sort_custom(func(a,b):return a.position.distance_squared_to(ai.base_center)>b.position.distance_squared_to(ai.base_center))
	for i in mini(surplus,idle.size()):
		idle[i].special.erase("brutal_relief_at")
		idle[i].special[ROLE]="attack"
		ai.ai_state.campaign_due=true
