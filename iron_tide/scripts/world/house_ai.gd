extends "res://scripts/world/skirmish_ai.gd"
## Multi-house skirmishes use independent production and construction decisions.
## All persistent AI state is in the battle snapshot's allied_state dictionary.

var _site_candidates: Dictionary = {}
var _decision_elapsed := 0.0
var _decision_wall := 0.0
const LARGE_DECISION_INTERVAL := 0.5
var _decision_phase_set := false
var homes: Dictionary
var swarm: bool:
	get: return enemy_base=="swarm"

func _exit_tree() -> void:
	if is_instance_valid(battle) and battle.ai_strategy_budget != null:
		battle.ai_strategy_budget.forget(house_id)

func objective() -> Vector2:
	var nearest := INF
	var goal := base_center
	for side in homes:
		if BattleRequest.friendly(house_id,side) or not battle.has_surviving_assets(side): continue
		var distance := base_center.distance_squared_to(homes[side])
		if distance < nearest:
			nearest = distance
			goal = homes[side]
	return goal

func unit_produced(unit) -> void:
	_army = ai_state.get_or_add("army",[])
	super.unit_produced(unit)

func _process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(15)
	if battle.ended or battle.paused or get_tree().paused: return
	_decision_elapsed += delta
	_decision_wall += BattleClock.control_delta(delta)
	if not _decision_phase_set and battle.units.size() >= 128:
		var seat := maxi(0,BattleRequest.house_teams.keys().find(house_id)-1)
		_decision_wall += LARGE_DECISION_INTERVAL * float(seat % 5) / 5.0
		_decision_phase_set = true
	# Strategic polling may wait; accumulated simulation time still advances
	# production/attack clocks in full when this house next makes a decision.
	var interval := LARGE_DECISION_INTERVAL if battle.units.size() >= 128 else 1.0 / 15.0
	if _decision_wall < interval: return
	delta = _decision_elapsed
	_decision_elapsed = 0.0
	_decision_wall = fmod(_decision_wall,interval)
	BaseAccess.tick(self,delta)
	# Multiple factories test the same prerequisites during one synchronous decision.
	battle.ai_prerequisite_scan = true
	run_decisions(delta)
	battle.ai_prerequisite_scan = false
	battle.clear_ai_decision_cache()

func run_decisions(delta: float, _nbuild: int = 0) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(16)
	preload("res://scripts/world/air_relief.gd").tick(self,delta)
	var state := ai_state
	_army = state.get_or_add("army",[])
	if state.has("brutal_alarm") and not state.get("attack_dispatch",{}).get("full_sortie",false): state.erase("attack_dispatch")
	elif state.has("attack_dispatch"): dispatch_attacker(state)
	if state.has("subsidy_time"):
		state.ai_subsidy_elapsed = state.subsidy_time
		state.erase("subsidy_time")
	Economy.subsidy(self,delta)
	advance_construction(delta)
	_tick_oil_retry(delta)
	if not swarm:
		Micro.tick(self,delta)
		Economy.relief(self,delta)
	if difficulty == 6: Brutal.tick(self,delta)
	state.think -= delta
	if swarm: state.hive_elapsed=float(state.get("hive_elapsed",0))+delta
	state.attack -= delta
	if state.think > 0:
		if difficulty >= 3 and not swarm:
			_refill_t -= delta
			if _refill_t <= 0:
				_refill_t = 0.25
				if battle.ai_population_full(house_id): return
				for line in battle.buildings:
					if battle.actor_alive(line) and line.side==house_id and not line.is_refinery() and line.is_operational() and not line.buildable.is_empty() and line.production.is_empty() and not line.exit_blocked:
						if line.building_id in ["GAYARD","NAYARD"] and Operations.naval_basin(line).interval > 1: continue
						_try_train(float(state.get("reserve",0)))
						break
		return
	# Keep due houses pending until the next render; do not accumulate heavy
	# two-second strategy passes in one frame after load or a long frame.
	if not battle.ai_strategy_budget.claim(house_id,Engine.get_process_frames()): return
	state.think = 2.0
	state.site_retry=maxf(0.0,float(state.get("site_retry",0))-2.0)
	if not battle.has_surviving_assets(house_id): return
	_army = _army.filter(func(u):return Tactics.fighter(battle,u,house_id))
	state.army = _army
	var buildings: Array = battle.buildings.filter(func(b): return battle.actor_alive(b) and b.side == house_id)
	var units: Array = battle.units.filter(func(u): return battle.actor_alive(u) and u.side == house_id and u.embarked_in == null)
	if swarm:
		_hatch(state,buildings)
	else:
		_manage_base(state,buildings,units)
	battle.update_ai_strength(house_id,battle.ai_living_count(house_id))
	_form_wave(state)

func _hatch(state: Dictionary, buildings: Array) -> void:
	if buildings.any(func(b):return b.building_id=="swarm_hive"):
		var elapsed:float=state.hive_elapsed
		battle.credit_income(house_id,elapsed*(float(tuning.get("income",190))+buildings.size()*float(tuning.get("building_income",9))))
		state.hatch_left=float(state.get("hatch_left",0))-elapsed*battle.ai_replenishment_factor(house_id)
		if state.hatch_left<=0:
			if state.has("hatch_rng"): _rng.state=int(state.hatch_rng)
			_try_train()
			state.hatch_left=float(tuning.get("train_interval",6.5))*_rng.randf_range(0.75,1.25)/battle.ai_build_factor(house_id)
			state.hatch_rng=str(_rng.state)
	state.hive_elapsed=0.0

func _manage_base(state: Dictionary, buildings: Array, units: Array) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(17)
	place_ready_construction(buildings)
	if difficulty==6:
		Brutal.house_opening(battle,house_id,Brutal.wall_id(self),state)
	var next := {}
	var defense_reserve := 0.0
	if not battle.owned_building_ids(house_id).has(battle.roster_id("GACNST",house_id)):
		_recover_base()
	else:
		defense_reserve = prepare_air_defense(buildings,difficulty)
		state.erase("planned_site")
		next = next_structure(buildings)
		if not next.is_empty() and funds-Tactics.committed(battle,house_id) >= float(next.cost):
			var point:Vector2 = state.get("planned_site",Vector2.INF)
			state.erase("planned_site")
			if not point.is_finite() or not Tactics.expansion_site_ok(battle,house_id,next,point): point=building_site(next)
			if point.is_finite():
				queue_construction(next,point)
				next = {}
	Economy.replace_miners(self)
	state.reserve = next.get("cost",0) + defense_reserve
	train_army(buildings,units,next,defense_reserve)
	# Three houses on the same six-second clock can all plan rallies and
	# dispatch support on one frame. Stagger the first cycle once per save.
	if battle.frame_pacing != null and battle.frame_pacing.tier >= 2 and not state.get("ops_staggered",false):
		var seat := BattleRequest.house_teams.keys().find(house_id)
		state.ops_left = maxf(2.0,float(state.get("ops_left",0))) + 2.0 * (maxi(0,seat-1) % 3)
		state.ops_staggered = true
	state.ops_left = float(state.get("ops_left",0))-2.0
	if state.ops_left <= 0:
		state.ops_left = 6.0
		Economy.manage(self)
		if enemy_base=="soviet": Operations.staff_soviet_defense(self)
		Operations.tick(self)
		_recruit_idle(6)
		state.defending = _defend_base()
		if state.defending and not state.get("attack_dispatch",{}).get("full_sortie",false):
			state.erase("attack_dispatch")
			state.attack = maxf(state.attack,4.0)

func _form_wave(state: Dictionary) -> void:
	if state.has("attack_dispatch"): return
	state.erase("full_sortie_due")
	var wave: Array = Campaign.wave(self)
	if wave.is_empty(): return
	var goal := Tactics.attack_position(self,wave)
	var direction := base_center.direction_to(goal)
	var slots := Formations.layout(wave.size(),goal,direction,"line",battle._formation_spacing(wave))
	wave.reverse()
	slots.reverse()
	state.attack_dispatch={"units":wave,"slots":slots,"goal":goal,"assembled":true,"full_sortie":true}
	state.attack=float(tuning.get("attack_delay",55.0))
	dispatch_attacker(state)

func ready_for_dispatch(unit) -> bool:
	if not battle.actor_alive(unit) or unit.side != house_id or unit.embarked_in != null: return false
	if unit.has_move_order or is_instance_valid(unit.attack_target) or unit.is_harvester or unit.weapon.is_empty(): return false
	return unit.logistics.ammo_max==0 or (unit.logistics.air_state=="parked" and unit.logistics.ammo==unit.logistics.ammo_max and not is_instance_valid(unit.logistics.carrier_owner))

# A single long ground route can cross the map. Dispatch the wave in roster
# order over successive frames; pending members survive save/load with the house.
func dispatch_attacker(state: Dictionary) -> void:
	var wave: Dictionary = state.attack_dispatch
	var pending: Array = wave.units
	while not pending.is_empty():
		var u = pending.pop_back()
		var goal:Vector2 = wave.slots.pop_back() if wave.has("slots") and not wave.slots.is_empty() else wave.goal
		if wave.get("assembled",false):
			if not Tactics.fighter(battle,u,house_id) or u.repairing or u.special.has("ai_deploy_mission") or battle.actor_alive(u.attack_target): continue
			_army.erase(u)
			Micro.release(u)
			if difficulty==6 and u.unit_id not in Brutal.TANKS: goal=goal.move_toward(base_center,80.0)
			Assembly.advance(self,[u],goal)
		else:
			if not ready_for_dispatch(u): continue
			var target=Operations.preferred(self,u,Operations.targets(self))
			if target!=null: Operations.order_attack(u,target)
			elif u.logistics.ammo_max==0: u.ai_order("move",goal,true)
		break
	if pending.is_empty(): state.erase("attack_dispatch")

# Reserve a defensive site independently of the normal tech/construction line.
func prepare_air_defense(buildings:Array, difficulty:int) -> float:
	if construction_pending("defense") or buildings.any(func(b):return b.under_construction and battle.structure_category(b.building_id)=="defense"): return 0.0
	var owned:Array = battle.owned_building_ids(house_id)
	var id := Tactics.air_defense_order(battle,house_id,difficulty,owned)
	if battle.side_power_low(house_id): return 0.0
	if id.is_empty() and owned.has(battle.roster_id("GAWEAP",house_id)) and owned.has(battle.roster_id("GAREFN",house_id)):
		var choices := ["TESLA","NALASR","NABNKR"] if enemy_base=="soviet" else ["ATESLA"]
		for defense in choices:
			if defense not in owned and GameData.ra2_prereq_ok(defense, owned, battle.allied_state, house_id):
				id=defense
				break
	var cover := Vector2.INF
	if id.is_empty() and difficulty==6:
		cover=Brutal.cover_point(self)
		if cover.is_finite(): id=Brutal.wall_id(self)
	if id.is_empty(): return 0.0
	var data := GameData.get_building(id)
	var cost := float(data.cost)
	if battle.funds_for(house_id)-Tactics.committed(battle,house_id)<cost: return cost
	var pos := cover if cover.is_finite() else building_site(data)
	if pos.is_finite():
		queue_construction(data,pos)
	return 0.0

func queue_construction(data: Dictionary, point: Vector2) -> void:
	var jobs: Array = ai_state.get_or_add("construction_jobs",[])
	jobs.append({"id":data.id,"site":point,"cost":data.cost,"time":GameData.ra2_build_time(data),"paid":0.0,"elapsed":0.0})

func construction_pending(category: String) -> bool:
	for job in ai_state.get("construction_jobs",[]):
		if battle.structure_category(job.id)==category: return true
	return false

func advance_construction(delta: float) -> void:
	for job in ai_state.get("construction_jobs",[]):
		if job.get("ready",false): continue
		var ready := {}
		battle._tick_structure_jobs(delta,[job],ready,house_id)
		if ready.has(job.id): job.ready=true

func place_ready_construction(buildings: Array) -> void:
	var jobs: Array = ai_state.get("construction_jobs",[])
	if jobs.is_empty(): return
	# A live build limit denies every ready order of this type. Keep the
	# original fallback cursor for each denial, including interleaved types.
	var blocked_site_counts := {}
	for job in jobs.duplicate():
		if not job.get("ready",false): continue
		if blocked_site_counts.has(job.id):
			var count: int = blocked_site_counts[job.id]
			if count > 0:
				var start := int(ai_state.get("site_cursor", 0)) % count
				ai_state.site_cursor = (start + 32) % count
			continue
		var data := GameData.get_building(job.id)
		var point: Vector2 = job.site
		if not Tactics.expansion_site_ok(battle,house_id,data,point): point=building_site(data, blocked_site_counts)
		if not point.is_finite(): continue
		var site = battle._place_building(job.id,house_id,point,true,true)
		if site!=null:
			buildings.append(site)
			jobs.erase(job)
			blocked_site_counts.clear()

func next_structure(buildings: Array) -> Dictionary:
	# A long tech build must not block recovery after a generator is lost.
	if Power.needed(self): return GameData.get_building(battle.roster_id("GAPOWR",house_id))
	if construction_pending("building") or buildings.any(func(b): return b.under_construction and battle.structure_category(b.building_id)!="defense"): return {}
	var owned: Array = battle.owned_building_ids(house_id)
	var power_id: String = battle.roster_id("GAPOWR",house_id)
	var soviet: bool = battle.roster_faction(house_id)=="soviet"
	var plan := ["GAPOWR","GAREFN","GAPILE","GAWEAP"]
	plan.append_array(["NARADR","NATECH"] if soviet else ["GAAIRC","GATECH"])
	var power: Dictionary = battle._side_power(house_id)
	if power.low: return {} # An existing power order must finish before another is started.
	for entry in plan:
		var id: String = battle.roster_id(entry,house_id)
		if owned.has(id) or not GameData.ra2_prereq_ok(id, owned, battle.allied_state, house_id): continue
		var data := GameData.get_building(id)
		if id!=power_id and power.produced-power.drain+float(data.get("power",0))<0:
			return GameData.get_building(power_id)
		return data
	var miner_id: String = battle.roster_id("CMIN",house_id)
	var reserve: float = battle.production_price(GameData.get_unit(miner_id),house_id)
	var extra := Tactics.additional_factory(battle,house_id, BattleRequest.house_difficulty(house_id), owned, reserve)
	if not extra.is_empty(): return GameData.get_building(extra)
	var yard:String=battle.roster_id("GAYARD",house_id)
	# Failed shoreline/ore scans are expensive on native maps. Other build
	# decisions and interrupted construction stay responsive during the retry.
	if float(ai_state.get("site_retry",0))<=0:
		if yard not in owned and not battle.water_rects.is_empty() and GameData.ra2_prereq_ok(yard, owned, battle.allied_state, house_id):
			var port := Operations.build_spot(self,yard)
			if port.is_finite():
				ai_state.planned_site=port
				return GameData.get_building(yard)
		if Economy.refineries(self).size()<2 and Economy.miners(self,false)>=2 and funds>Tactics.committed(battle,house_id)+Economy.reserve(self):
			for outpost in [false,true]:
				var point:=Economy.placement(self,outpost)
				if point.is_finite():
					ai_state.planned_site=point
					return GameData.get_building(power_id if outpost else battle.roster_id("GAREFN",house_id))
		ai_state.site_retry=20.0
	var candidates := ["NADEPT"] if soviet else []
	if soviet and difficulty>=2: candidates.append_array(["NANRCT","NAINDP","NAIRON","NAMISL"])
	var support := Operations.next_building(self,owned)
	if not support.is_empty(): candidates.append(support)
	for id in candidates:
		if id not in owned and GameData.ra2_prereq_ok(id, owned, battle.allied_state, house_id): return GameData.get_building(Power.before_build(self,id))
	return {}

func train_army(buildings: Array, units: Array, next: Dictionary, defense_reserve := 0.0) -> void:
	if battle.ai_population_full(house_id): return
	var counts := {}
	var refinery: String = battle.roster_id("GAREFN",house_id)
	var miner: String = battle.roster_id("CMIN",house_id)
	for u in units: counts[u.unit_id] = int(counts.get(u.unit_id,0))+1
	for b in buildings:
		for uid in b.production:
			counts[uid] = int(counts.get(uid,0))+1
	var refinery_count := buildings.filter(func(b):return b.building_id==refinery and not b.under_construction).size()
	var contacts := {}
	var kirovs := Tactics.visible_kirovs(battle, house_id)
	var yard:String=battle.roster_id("GAYARD",house_id)
	var naval_turn:int=ai_state.get("naval_turn",0)
	ai_state.naval_turn=(naval_turn+1)%3
	var power_reserve:float=Power.reserve(self)
	var reserve := maxf(Economy.reserve(self),maxf(float(next.get("cost",0))+defense_reserve,power_reserve))
	if naval_turn==0 and kirovs==0: Operations.train_navy(self,reserve,true,contacts)
	var available: float = funds-Tactics.committed(battle,house_id)
	var matchups := {}
	for b in buildings:
		if b.building_id==yard or not b.is_operational() or not b.production.is_empty() or b.production_paused() or b.exit_blocked or b.buildable.is_empty(): continue
		var uid := Tactics.emergency_aa_product(battle,house_id,b,kirovs,counts,available-maxf(defense_reserve,power_reserve))
		if b.building_id==battle.roster_id("GAWEAP",house_id) and int(counts.get(miner,0))<2*refinery_count and b.can_queue(miner) and (uid.is_empty() or int(counts.get(miner,0))==0):
			uid=miner
		elif uid.is_empty():
			# Keep cash for the next prerequisite even while waiting for a clear site.
			var budget := available - maxf(float(next.get("cost",0)) + defense_reserve,power_reserve)
			if budget<=0: continue
			var opponents := Tactics.production_contacts(battle,house_id,contacts)
			uid=choose_combat_unit(b,budget,counts,opponents,matchups)
		if uid.is_empty(): continue
		var price: float = battle.production_price(GameData.get_unit(uid),house_id)
		if price<=available-power_reserve and b.enqueue(uid):
			available-=price
			counts[uid]=int(counts.get(uid,0))+1

	if naval_turn!=0 or kirovs>0: Operations.train_navy(self,reserve,false,contacts)

func choose_combat_unit(line, budget: float, counts: Dictionary, opponents: Array, matchups: Dictionary = {}) -> String:
	var best := ""
	var best_score := -INF
	var flagship := "APOC" if battle.roster_faction(house_id)=="soviet" else "SREF"
	for uid: String in line.buildable:
		if not GameData.ai_product_allowed(uid) or not GameData.unit_in_production_catalog(uid): continue
		var data := GameData.get_unit(uid)
		if not Tactics.combat_product(data): continue
		if battle.production_price(data,house_id)>budget or not line.can_queue(uid): continue
		var count := int(counts.get(uid,0))
		if uid==flagship and count==0: return uid
		var score := Tactics.production_score(uid, data, opponents, count, matchups)
		if score>best_score:
			best_score=score
			best=uid
	return best

func building_site(data: Dictionary, blocked_site_counts: Variant = null) -> Vector2:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(18)
	if data.get("water_bound",false): return Operations.build_spot(self,data.id)
	# The paid build limit applies to every point in this synchronous search.
	var limit_reached: bool = not battle.limit_reason(data.id, house_id, true).is_empty()
	if not limit_reached:
		for ring in range(1,7):
			for i in 12:
				var offset := Vector2.RIGHT.rotated(TAU*i/12.0)*ring*75.0
				var point: Vector2 = battle.snap_build_pos(base_center+offset)
				if Tactics.expansion_site_ok(battle,house_id,data,point): return point
	# Packed bases can have legal cells between radial samples or beside a later building.
	var region = preload("res://scripts/world/build_range_preview.gd")
	var zones: Array = region.placement_zones(battle,data,house_id)
	var local := Placement.aabb(Building.placement_poly(data))
	var entry: Dictionary = _site_candidates.get(data.id,{})
	if entry.get("zones")!=zones or entry.get("local")!=local or entry.get("size")!=battle.map_size:
		entry={"zones":zones,"local":local,"size":battle.map_size,
			"sites":region.zone_coverage(battle,zones,local).keys()}
		if _site_candidates.size()>=16: _site_candidates.clear()
		_site_candidates[data.id]=entry
	# Cache only potential grid centers. Live fog, units, terrain, exits and
	# building collisions must still pass expansion_site_ok on every attempt.
	var sites: Array = entry.sites
	if limit_reached and blocked_site_counts != null:
		blocked_site_counts[data.id] = sites.size()
	if not sites.is_empty():
		var state: Dictionary = battle.allied_state.house_ai[house_id]
		var start := int(state.get("site_cursor",0)) % sites.size()
		if not limit_reached:
			for offset in mini(32,sites.size()):
				var point: Vector2 = Vector2(sites[(start+offset)%sites.size()])*battle.BUILD_GRID
				if Tactics.expansion_site_ok(battle,house_id,data,point): return point
		state.site_cursor=(start+32)%sites.size()
	return Vector2.INF
