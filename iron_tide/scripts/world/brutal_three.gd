extends RefCounted
## Difficulty-six bonuses and field orders. Durable match state uses the normal snapshot dictionaries.
const TANKS := ["MTNK","HTNK","SREF","TNKD","MGTK","ROBO","TTNK","APOC","R3MIRAGE","R3FUTURE","R3APOC","R3TESLA"]
const Assembly = preload("res://scripts/world/skirmish_assembly.gd")
const Tactics = preload("res://scripts/world/skirmish_tactics.gd")
const Micro = preload("res://scripts/world/skirmish_micro.gd")

static func grant(actor) -> void:
	if not BattleRequest.is_ai_house(actor.side):
		actor.special.erase("brutal_shield")
		actor.special.erase("brutal_armor")
		return
	if not BattleRequest.brutal_house(actor.side):
		actor.special.erase("brutal_shield")
		actor.special.erase("brutal_armor")
		return
	if actor is Building:
		actor.special.get_or_add("brutal_shield", actor.max_hp * 0.5)
	elif actor.unit_id in TANKS:
		actor.special.brutal_armor = true

static func alert(victim, source) -> void:
	if not BattleRequest.brutal_house(victim.side) or not is_instance_valid(source): return
	var attacker = source.shooter() if source is Projectile else source
	if not is_instance_valid(attacker) or not (attacker is Unit or attacker is Building) or not BattleRequest.is_house(attacker.side) or BattleRequest.friendly(attacker.side,victim.side): return
	var world = victim.battle if victim is Building else victim._battle_world()
	if world == null: return
	var state:Dictionary=world.allied_state
	if not BattleRequest.house_teams.is_empty():
		if not state.get("house_ai",{}).has(victim.side):return
		state=state.house_ai[victim.side]
	elif not is_instance_valid(world.skirmish_ai):return
	var previous: Dictionary = state.get("brutal_alarm", {})
	if previous.get("base", false) and not victim is Building: return
	var point: Vector2 = victim.position
	var spotted: bool = world.actor_visible_to(victim.side, attacker)
	if spotted:
		point = victim.position.move_toward(attacker.position, 300.0)
	elif victim is Building and BattleRequest.house_teams.is_empty():
		point += victim.position.direction_to(world._player_target()) * 200.0
	state.brutal_alarm = {"point":point, "base":victim is Building, "air":spotted and attacker is Unit and attacker.is_air_target(), "life":12.0}

static func wall_id(ai) -> String:
	return "NAWALL" if ai.enemy_base == "soviet" else "GAWALL"

static func wall_site(ai, point: Vector2) -> bool:
	return house_wall_site(ai.battle,ai.house_id,wall_id(ai),point)

static func house_wall_site(world, owner:String, id:String, point:Vector2) -> bool:
	if not preload("res://scripts/world/ai_base_access.gd").placement_ok(world,owner,GameData.get_building(id),point): return false
	if not world.build_spot_ok(point, GameData.get_building(id), true, owner).ok: return false
	for building in world.buildings:
		if not world.actor_alive(building) or building.side != owner or building.is_hq: continue
		if building.buildable.is_empty() and not building.is_refinery(): continue
		var pad: Rect2 = building.footprint_rect()
		pad.position += building.position
		if pad.grow(65.0).has_point(point): return false
	return true

static func opening(ai) -> void:
	if ai.enemy_base != "swarm":house_opening(ai.battle,ai.house_id,wall_id(ai),ai.ai_state)

static func house_opening(world, owner:String, id:String, state:Dictionary) -> void:
	if state.has("brutal_perimeter"): return
	for yard in world.buildings.duplicate():
		if not world.actor_alive(yard) or yard.side != owner or not yard.is_hq: continue
		var origin: Vector2 = world.snap_build_pos(yard.position)
		var half: Vector2 = yard.foundation_half()
		var rx := ceili(half.x / WallArt.CELL) + 1
		var ry := ceili(half.y / WallArt.CELL) + 1
		var count := 0
		# Enclose the yard itself. Production exits, occupied terrain and ore
		# stay open under the same placement checks as a normal wall.
		for x in range(-rx, rx + 1):
			for y in range(-ry, ry + 1):
				if absi(x) < rx and absi(y) < ry: continue
				var point: Vector2 = origin + Vector2(x,y) * WallArt.CELL
				if house_wall_site(world,owner,id,point):
					world._place_building(id, owner, point, true)
					count += 1
		if count > 0: state.brutal_perimeter = count
		return

static func cover_point(ai) -> Vector2:
	var world = ai.battle
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side != ai.house_id or not unit._deployed or not AlliedAbilities.infantry(unit): continue
		var front: Vector2 = unit.position.direction_to(ai.objective())
		if absf(front.x) >= absf(front.y): front = Vector2.RIGHT if front.x >= 0 else Vector2.LEFT
		else: front = Vector2.DOWN if front.y >= 0 else Vector2.UP
		var origin: Vector2 = world.snap_build_pos(unit.position)
		# Flank cover leaves a clear firing lane straight ahead and an exit to the rear.
		for flank in [-1,1]:
			var point: Vector2 = origin + (front + front.orthogonal()*flank)*WallArt.CELL
			if wall_site(ai,point): return point
	return Vector2.INF

static func request_cover(ai, owned: Array) -> void:
	var world = ai.battle
	if ai.enemy_base == "swarm" or not world.structure_jobs("defense",ai.house_id).is_empty() or world.structure_ready_count("defense",ai.house_id) > 0: return
	var id := wall_id(ai)
	if not GameData.ra2_prereq_ok(id, owned, world.allied_state, ai.house_id) or not ai._can_fund_structure(id, false): return
	if cover_point(ai).is_finite(): world.request_structure(id, ai.house_id)

static func advance(ai, troops: Array, point: Vector2) -> void:
	if troops.is_empty(): return
	var front: Array = []
	var support: Array = []
	var origin := Vector2.ZERO
	for unit in troops:
		origin += unit.position
		if unit.unit_id in TANKS: front.append(unit)
		else: support.append(unit)
	var direction := point.direction_to(origin / troops.size())
	Assembly.advance(ai, front, point)
	var rear := point
	if not front.is_empty() and not support.is_empty():
		for angle: float in [0.0, 0.65, -0.65, 1.3, -1.3, PI]:
			var candidate := point + direction.rotated(angle)*80.0
			if ai.battle.path_service.same_zone(support[0].position, candidate):
				rear = candidate
				break
	Assembly.advance(ai, support, rear)

static func tick(ai, dt: float) -> void:
	ai.brutal_elapsed += dt
	if ai.brutal_elapsed < 2.0: return
	var elapsed: float = ai.brutal_elapsed
	ai.brutal_elapsed = 0.0
	var world = ai.battle
	opening(ai)
	var alarm: Dictionary = ai.ai_state.get("brutal_alarm", {})
	var responders: Array = []
	for unit in world.units:
		if not Tactics.fighter(world,unit,ai.house_id) or unit.repairing or unit.special.has("action") or unit.unit_id == "DTRUCK": continue
		if unit._deployed or unit.special.has("ai_deploy_mission"): continue
		var campaign_attack: bool = ai.ai_state.get("campaign_started",false) and unit.special.get("ai_campaign_role")=="attack"
		if not alarm.is_empty() and not unit.special.has("hero_wreck") and not campaign_attack:
			responders.append(unit)
		if unit.has_move_order and (not world.actor_alive(unit.attack_target) or not unit._weapon_target_valid(unit.attack_target)):
			var previous: Vector2 = unit.special.get("brutal_watch_pos",unit.position)
			var unchanged: bool = unit.position.distance_to(previous) < 6.0 and unit.move_target.distance_to(unit.position) > 80.0
			unit.special.brutal_stall = float(unit.special.get("brutal_stall",0.0)) + elapsed if unchanged else 0.0
			if unit.special.brutal_stall >= 6.0:
				var goal: Vector2 = unit.move_target
				var side_step: Vector2 = unit.position.direction_to(goal).orthogonal() * (100.0 if int(unit.special.get("brutal_retry",0)) % 2 == 0 else -100.0)
				world.ai_dispatch.submit(world,unit,{"kind":"detour","offset":side_step,"attack":unit.attack_move,"goal":goal})
				unit.special.brutal_retry = int(unit.special.get("brutal_retry",0))+1
				unit.special.brutal_stall = 0.0
		else:
			unit.special.erase("brutal_stall")
		var idle: bool = not unit.has_move_order and not unit.attack_ordered and not world.actor_alive(unit.attack_target)
		if idle and campaign_attack:
			ai.ai_state.campaign_due=true
			unit.special.erase("brutal_idle")
			unit.special.brutal_watch_pos=unit.position
			continue
		if idle and alarm.is_empty() and not Assembly.ready(unit, ai.rally):
			unit.special.brutal_idle = float(unit.special.get("brutal_idle", 0.0)) + elapsed
			if unit.special.brutal_idle >= 8.0:
				unit.cancel_stance()
				Assembly.assemble(ai, unit)
				if not ai._army.has(unit): ai._army.append(unit)
				unit.special.erase("brutal_idle")
		else:
			unit.special.erase("brutal_idle")
		unit.special.brutal_watch_pos = unit.position
	if alarm.is_empty(): return
	alarm.life -= elapsed
	if alarm.life <= 0:
		ai.ai_state.erase("brutal_alarm")
		return
	var point: Vector2 = alarm.point
	var air_raid: bool = alarm.get("air", false)
	responders.sort_custom(func(a,b):
		if air_raid:
			var a_aa: bool = air_defender(a)
			var b_aa: bool = air_defender(b)
			if a_aa != b_aa: return a_aa
		return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
	var group: Array = []
	var committed := 0
	for unit in responders:
		var assigned: Vector2 = unit.special.get("brutal_relief_at", Vector2.INF)
		if assigned.distance_to(point) < 160.0 and (unit.position.distance_to(point) < 180.0 or unit.has_move_order and unit.move_target.distance_to(point) < 180.0):
			committed += 1
	for unit in responders:
		if group.size() + committed >= 6: break
		if unit.position.distance_to(point) < 160 or world.actor_alive(unit.attack_target) and unit.position.distance_to(point) < 400: continue
		if unit.has_move_order and unit.move_target.distance_to(point) < 170: continue
		if not unit.is_air:
			var access: Vector2 = world.path_service.nearest_reachable(point,unit.position,false,6,unit.is_amphibious)
			if access.distance_to(point) > 180: continue
		unit.special.brutal_relief_at = point
		ai._army.erase(unit)
		group.append(unit)
	advance(ai,group,point)

static func air_defender(unit) -> bool:
	return unit.unit_id == "GGI" or unit.data.has("anti_air_weapon") or CombatMath.can_hit_air(unit._active_weapon())
