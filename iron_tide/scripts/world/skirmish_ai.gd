extends Node
## 遭遇战 AI（SkirmishAI）
## 盟军 AI 与玩家共用采矿、资金、工厂和建造队列。虫群保留扩展模式孵化规则。
## 行为：真实生产与经济、按可见敌军补兵、基地留守与集结进攻。
## 胜负由 battle.gd 统一检查存活建筑及可展开基地车。
const Campaign = preload("res://scripts/world/skirmish_campaign.gd")
const BaseAccess = preload("res://scripts/world/ai_base_access.gd")
const Brutal = preload("res://scripts/world/brutal_three.gd")
var brutal_elapsed := 0.0
const Assembly = preload("res://scripts/world/skirmish_assembly.gd")
const Operations = preload("res://scripts/world/skirmish_operations.gd")
const Tactics = preload("res://scripts/world/skirmish_tactics.gd")
const Micro = preload("res://scripts/world/skirmish_micro.gd")
const Economy = preload("res://scripts/world/skirmish_economy.gd")
const Power = preload("res://scripts/world/skirmish_power.gd")
var house_id := "enemy"
var ai_state: Dictionary:
	get: return battle.ai_decisions(house_id)

func objective() -> Vector2:
	return battle._player_target()

var battle: Battle
var difficulty := 1
var enemy_base := "allied"
var tuning: Dictionary = {}
var funds: float:
	get:
		return battle.funds_for(house_id) if is_instance_valid(battle) else 0.0
var base_center: Vector2 = Vector2.ZERO
var rally: Vector2 = Vector2.ZERO
var a_spawned := 0          # 诊断：AI 累计造兵
var a_attacks := 0          # 诊断：AI 进攻波次
var _train_t := 4.0
var _refill_t := 5.0
var _attack_t := 45.0
var _army: Array = []
var _rng := RandomNumberGenerator.new()
var _unit_pool: Array[String] = []
var _miss_sfx := false      # 只提示一次缺语音

func setup(p_battle, p_diff: int, p_enemy_base: String, home := Vector2.INF) -> void:
	battle = p_battle
	difficulty = clampi(p_diff, 0, GameData.DIFFICULTY_NAMES.size() - 1)
	enemy_base = p_enemy_base
	tuning = GameData.skirmish_ai_tuning(difficulty)
	_rng.randomize()
	base_center = home if home.is_finite() else battle.enemy_base_center
	rally = base_center + Vector2(0.0, battle.map_size * 0.075)
	_train_t = 5.0
	_refill_t = 5.0
	_attack_t = float(tuning.get("attack_delay", 55.0))
	_build_unit_pool()

func _build_unit_pool() -> void:
	_unit_pool.clear()
	for id: String in GameData.unit_index:
		var unit := GameData.get_unit(id)
		if unit.get("faction") == enemy_base and not str(unit.get("built_at", "")).is_empty() and GameData.ai_product_allowed(id) and GameData.unit_in_production_catalog(id) and battle.country_block_reason(id, house_id).is_empty():
			_unit_pool.append(id)

func _tick_oil_retry(dt: float) -> void:
	if ai_state.has("oil_retry_left"):
		ai_state.oil_retry_left -= dt
		if ai_state.oil_retry_left <= 0:
			ai_state.erase("oil_retry_left")
			ai_state.erase("oil_engineer_losses")

func _process(dt: float) -> void:
	if battle == null or not is_instance_valid(battle) or battle.ended or battle.paused or get_tree().paused:
		return
	if battle.path_service == null:
		return
	var nbuild := _count_buildings()
	if nbuild <= 0 and not battle.has_base_assets(house_id):
		return
	battle.ai_prerequisite_scan = true
	run_decisions(dt, nbuild)
	battle.ai_prerequisite_scan = false
	battle.clear_ai_decision_cache()

func run_decisions(dt: float, nbuild: int = 0) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(19)
	preload("res://scripts/world/air_relief.gd").tick(self,dt)
	BaseAccess.tick(self,dt)
	if difficulty == 6: Brutal.tick(self, dt)
	Economy.subsidy(self,dt)
	_tick_oil_retry(dt)
	if enemy_base == "swarm":
		battle.credit_income(house_id, (float(tuning.get("income", 190.0)) + float(nbuild) * float(tuning.get("building_income", 9.0))) * dt)
	else:
		Micro.tick(self, dt)
		Economy.relief(self, dt)
	_army = _army.filter(func(u): return Tactics.fighter(battle, u, house_id))
	_train_t -= dt * (battle.ai_replenishment_factor(house_id) if enemy_base == "swarm" else 1.0)
	if _train_t <= 0.0:
		battle.update_ai_strength(house_id,battle.ai_living_count(house_id))
		_train_t = float(tuning.get("train_interval", 6.5)) * _rng.randf_range(0.75, 1.25)
		if enemy_base == "swarm":
			_train_t /= battle.ai_build_factor(house_id)
		else:
			_replace_miners()
			_try_build()
			Economy.manage(self)
			if enemy_base == "soviet": Operations.staff_soviet_defense(self)
			_recruit_idle()
			_defend_base()
			Operations.tick(self)
		_try_train()
	_refill_idle_lines(dt)
	_attack_t -= dt
	if ai_state.get("full_sortie_due",false) or ai_state.get("campaign_due",false) or (not ai_state.get("campaign_started",false) and battle.ai_living_count(house_id)>=Campaign.START_COUNT): _attack_t = 0.0
	if _attack_t <= 0.0:
		var full: bool = ai_state.erase("full_sortie_due") or battle.ai_population_full(house_id,false)
		if full or ai_state.get("campaign_started",false) or battle.ai_living_count(house_id)>=Campaign.START_COUNT:
			_launch_attack(full)
		else: _attack_t = 1.0

# Fast procurement only when a line actually ran dry. Keep construction, tech,
# deployment and strategic attacks on their existing cadence.
func _refill_idle_lines(dt: float) -> void:
	if difficulty < 3 or enemy_base == "swarm": return
	_refill_t -= dt
	if _refill_t > 0.0: return
	_refill_t = 0.25
	for producer in battle.buildings:
		if not battle.actor_alive(producer) or producer.side != house_id or producer.is_refinery() or producer.buildable.is_empty(): continue
		if producer.production.is_empty() and not producer.exit_blocked and producer.is_operational():
			if producer.building_id in ["GAYARD","NAYARD"] and Operations.naval_basin(producer).interval > 1: continue
			_try_train()
			return

func _count_buildings() -> int:
	var n := 0
	for b in battle.buildings:
		if is_instance_valid(b) and str(b.side) == house_id:
			n += 1
	return n

func _try_train(construction_reserve := 0.0) -> void:
	if battle.ai_population_full(house_id): return
	if enemy_base != "swarm" and battle.mcv_opening() and not _has_miner():
		return
	if _unit_pool.is_empty():
		return
	if enemy_base != "swarm":
		var reserve: float = Economy.reserve(self) + maxf(construction_reserve,Power.reserve(self))
		if funds - Tactics.committed(battle,house_id) <= reserve: return
		# The yard gets first call every third purchasing decision and can use spare funds on the others.
		var naval_turn:=int(ai_state.get("ai_naval_turn",0))
		ai_state.ai_naval_turn=(naval_turn+1)%3
		var kirovs := Tactics.visible_kirovs(battle,house_id)
		if naval_turn==0 and kirovs==0:Operations.train_navy(self,reserve,true)
		var factory_id: String = battle.roster_id("GAWEAP",house_id)
		var tech := "APOC" if enemy_base == "soviet" else "SREF"
		var main := "HTNK" if enemy_base == "soviet" else "MTNK"
		var tech_factory = null
		var escort_count := 3 if difficulty == 0 else 1
		var need_aa_vehicle := kirovs>0 and Operations.count(self,"HTK" if enemy_base=="soviet" else "FV") < Tactics.mobile_aa_quota(kirovs)
		if not need_aa_vehicle and _unit_pool.has(tech) and Operations.count(self,main) >= escort_count and Operations.count(self,tech) == 0:
			for producer in battle.buildings:
				if battle.actor_alive(producer) and producer.side==house_id and producer.building_id==factory_id and producer.is_operational() and producer.production.is_empty() and producer.can_queue(tech):
					tech_factory = producer
					break
		if tech_factory != null:
			if funds - Tactics.committed(battle,house_id) - reserve >= battle.production_price(GameData.get_unit(tech),house_id):
				tech_factory.enqueue(tech)
			else: tech_factory = null
		# Each available production line can place an order, including an airfield with no enemy contact.
		var yard_id: String = battle.roster_id("GAYARD", house_id)
		var lines: Array = battle.buildings.filter(func(b):return battle.actor_alive(b) and b.side==house_id and b.is_operational() and not b.buildable.is_empty())
		if kirovs > 0:
			var aa_lines := [factory_id,battle.roster_id("GAPILE",house_id)]
			lines.sort_custom(func(a,b): return a.building_id in aa_lines and b.building_id not in aa_lines)
		else:
			lines.sort_custom(func(a,b): return a.building_id == "GAAIRC" and b.building_id != "GAAIRC")
		# Cheap troops can finish before the next strategic decision. Fill the
		# existing two-order buffer, giving every line its first turn before a second.
		var procurement := {}
		for refill in (2 if difficulty >= 3 else 1):
			for producer in lines:
				if producer == tech_factory or producer.is_refinery() or producer.building_id == yard_id: continue
				if producer.production_paused() or producer.exit_blocked or producer.production.size() >= mini(2, producer.queue_capacity()): continue
				if kirovs==0 and producer.building_id == battle.roster_id("GAPILE", house_id) and Tactics.saving_for_armour(self, factory_id, reserve): continue
				var pick := Tactics.production(self, producer.building_id, reserve, producer, kirovs, procurement)
				if not pick.is_empty() and producer.enqueue(pick.uid):
					procurement.counts[pick.uid] = int(procurement.counts.get(pick.uid, 0)) + 1
		if naval_turn!=0 or kirovs>0:Operations.train_navy(self,reserve)
		return
	var uid := ""
	var best := -INF
	var opponents := Tactics.visible_opponents(battle,house_id)
	for candidate in _unit_pool:
		var data := GameData.get_unit(candidate)
		if float(data.cost) > funds: continue
		var score := (float(Tactics.tech_tier(candidate)) + Tactics.counter_score(data,opponents) + _rng.randf()) / (1.0 + Operations.count(self,candidate))
		if score > best:
			uid = candidate
			best = score
	if uid.is_empty(): return
	var cost := float(GameData.get_unit(uid).cost)
	if not battle.spend_side(house_id, cost):
		return
	var pos := rally + Vector2(_rng.randf_range(-80.0, 80.0), _rng.randf_range(-80.0, 80.0))
	var u = battle.spawn_unit(uid, house_id, pos)
	if u == null:
		battle.credit_side(house_id, cost)
		return
	Assembly.assemble(self, u)
	_army.append(u)
	a_spawned += 1

func unit_produced(u) -> void:
	Campaign.reinforcement(self,u)
	if u.is_harvester:
		return
	if u.is_naval or u.logistics.ammo_max > 0:
		u.ai_order("stop")
		if u.is_naval and not u.weapon.is_empty(): Operations.naval_orders(self, u, Operations.targets(self))
		a_spawned += 1
		return
	if not u.deploy_building_id().is_empty():
		u.ai_order("stop")
		return
	Assembly.assemble(self, u)
	_army.append(u)
	a_spawned += 1

func _recruit_idle(max_orders := -1) -> void:
	for u in battle.units:
		if not Tactics.fighter(battle, u, house_id) or u.repairing or u.special.has("action") or preload("res://scripts/units/ai_engagement.gd").busy(u): continue
		if u.special.has("ai_deploy_mission"): continue
		# Aircraft with ammunition keep their explicit sortie/rearm contract.
		if u.logistics.ammo_max > 0: continue
		if u.special.get(Campaign.ROLE)=="attack":
			if not u.has_move_order:
				if not _army.has(u): _army.append(u)
				ai_state.campaign_due=true
			continue
		var reassign: bool = _army.has(u) and Assembly.needs_new_slot(self, u)
		if not reassign and (u.has_move_order or (_army.has(u) and Assembly.ready(u, rally))): continue
		if not _army.has(u): _army.append(u)
		Micro.release(u)
		u.cancel_stance()
		Assembly.assemble(self, u)
		if max_orders > 0:
			max_orders -= 1
			if max_orders == 0: break

func _defend_base() -> bool:
	if difficulty == 6 and ai_state.has("brutal_alarm"): return true
	var threat = Tactics.base_threat(self)
	if threat == null: return false
	var responders: Array = []
	var dispatched := false
	for u in _army:
		if not Tactics.fighter(battle, u, house_id) or u.unit_id == "DTRUCK" or not u.attack_domain_valid(threat) or u.special.has("ai_deploy_mission"): continue
		if ai_state.get("campaign_started",false) and u.special.get(Campaign.ROLE)!="guard": continue
		dispatched = true
		var previous: Vector2 = u.special.get("ai_defense_goal", Vector2.INF)
		if not u.attack_move or previous.distance_to(threat.position) > 100.0:
			u.special.ai_defense_goal = threat.position
			responders.append(u)
	Assembly.advance(self, responders, threat.position)
	return dispatched

func _replace_miners() -> void:
	Economy.replace_miners(self)

## 基地车优先用于重建，不编入攻击队。仅使用真实工厂和现有生产资格。
func _recover_base() -> void:
	for unit in battle.units:
		if not is_instance_valid(unit) or unit.side != house_id or unit.hp <= 0.0 or unit._dead \
				or unit.is_queued_for_deletion() or unit.deploy_building_id().is_empty():
			continue
		if unit.embarked_in != null:
			return
		if battle.ai_dispatch.defer_job(battle,unit,"recover",true): return
		if battle.construction_deploy_check(unit).ok:
			battle.deploy_construction_vehicle(unit)
			return
		# 已下达有效展开位置的移动命令时继续行驶，避免每次决策改道。
		if unit.has_move_order and battle.construction_deploy_check(unit, unit.move_target).ok:
			return
		for distance in [160.0, 240.0, 320.0, 480.0, 640.0]:
			for direction in 16:
				var pos: Vector2 = battle.snap_build_pos(unit.global_position + Vector2.RIGHT.rotated(TAU * direction / 16.0) * distance)
				if not battle.construction_deploy_check(unit, pos).ok:
					continue
				var path: PackedVector2Array = battle.path_service.find_path(unit.global_position, pos)
				if path.is_empty() or path[path.size() - 1].distance_to(pos) > 40.0:
					continue
				unit.ai_order("move",pos, false)
				return
		return
	for factory in battle.buildings:
		if not is_instance_valid(factory) or factory.side != house_id or factory.is_dead():
			continue
		if factory.production.has(battle.roster_id("AMCV", house_id)):
			return
	for factory in battle.buildings:
		if is_instance_valid(factory) and factory.side == house_id and factory.is_operational() \
				and factory.production.is_empty() and factory.can_queue(battle.roster_id("AMCV", house_id)):
			factory.enqueue(battle.roster_id("AMCV", house_id))
			return

func _try_build() -> void:
	var owned: Array = battle.owned_building_ids(house_id)
	if not owned.has(battle.roster_id("GACNST", house_id)):
		_recover_base()
		return
	# A blocked site in one category must not hold the other queue hostage.
	for id in battle.enemy_struct_ready.keys():
		if battle.single_structure(id) and not battle.limit_reason(id, house_id, true).is_empty():
			# Refund paid duplicates from old saves or a newly captured facility.
			var copies := int(battle.enemy_struct_ready[id])
			battle.enemy_struct_ready.erase(id)
			battle.credit_side(house_id, copies * float(GameData.get_building(id).cost), true)
			continue
		var point := Vector2.INF
		if difficulty == 6 and WallArt.is_wall(GameData.get_building(id)):
			point = Brutal.cover_point(self)
			if not point.is_finite():
				var copies: int = battle.enemy_struct_ready[id]
				battle.enemy_struct_ready.erase(id)
				battle.credit_side(house_id, copies * float(GameData.get_building(id).cost), true)
				continue
		else:
			point = Economy.placement(self) if id == battle.roster_id("GAREFN",house_id) else Operations.build_spot(self,str(id))
			if id == battle.roster_id("GAPOWR",house_id) and ai_state.has("ai_ore_outpost"):
				var site: Vector2 = ai_state.ai_ore_outpost
				if Tactics.expansion_site_ok(battle,house_id,GameData.get_building(id),site): point = site
				if point.is_finite(): ai_state.erase("ai_ore_outpost")
			if not point.is_finite() and id == battle.roster_id("GAREFN",house_id):
				point = Operations.build_spot(self,str(id))
		if point.is_finite(): battle.deliver_ready_structure(str(id),house_id,point)
	owned = battle.owned_building_ids(house_id)
	if not battle.side_power_low(house_id):
		_try_defense(owned)
	if difficulty == 6: Brutal.request_cover(self, owned)
	if not battle.structure_jobs("building",house_id).is_empty() or battle.structure_ready_count("building",house_id) > 0: return
	if Power.needed(self):
		battle.request_structure(battle.roster_id("GAPOWR",house_id),house_id)
		return
	var factory: String = battle.roster_id("GAWEAP",house_id)
	if battle.mcv_opening() and owned.has(battle.roster_id("GAREFN",house_id)) and not _has_miner():
		var miner_id: String = battle.roster_id("CMIN",house_id)
		if owned.has(factory) or Economy.refineries(self).any(func(b): return b.can_queue(miner_id) or b.special.get("construction_free_unit","") == miner_id):
			return # Protect the first miner, unless rebuilding its factory is the only recovery path.
	if not owned.has(factory) and GameData.ra2_prereq_ok(factory, owned, battle.allied_state, house_id):
		battle.request_structure(Power.before_build(self,factory), house_id)
		return
	var wanted := ""
	var radar := "NARADR" if enemy_base == "soviet" else "GAAIRC"
	var lab := "NATECH" if enemy_base == "soviet" else "GATECH"
	var yard: String = battle.roster_id("GAYARD",house_id)
	if wanted.is_empty() and owned.has(battle.roster_id("GAWEAP",house_id)):
		# Leave the coastal opening enough time to launch its first patrol ship.
		if not owned.has(yard) and GameData.ra2_prereq_ok(yard, owned, battle.allied_state, house_id) and Operations.has_build_spot(self,yard):
			wanted = yard
		for tech in [radar, lab]:
			if wanted.is_empty() and not owned.has(tech) and GameData.ra2_prereq_ok(tech, owned, battle.allied_state, house_id):
				wanted = tech
				break
	if wanted.is_empty() and Economy.expand(self): return
	if wanted.is_empty():
		var extra := Tactics.additional_factory(battle,house_id,difficulty,owned,Economy.reserve(self))
		if not extra.is_empty() and Operations.has_build_spot(self,extra): wanted=extra
	if wanted == "":
		var sequence := ["GAPOWR", "GAREFN", "GAPILE", "GAWEAP", "GAYARD"]
		sequence.append_array(["NARADR", "GADEPT", "NATECH"] if enemy_base == "soviet" else ["GAAIRC", "GATECH"])
		if difficulty >= 2 and enemy_base == "soviet":
			sequence.append_array(["NANRCT", "NAINDP", "NAIRON", "NAMISL"])
		for entry in sequence:
			var id: String = battle.roster_id(entry, house_id)
			if not owned.has(id) and GameData.ra2_prereq_ok(id, owned, battle.allied_state, house_id):
				if entry == "GAYARD" and not Operations.has_build_spot(self,id): continue
				wanted = id
				break
	if wanted != "":
		wanted=Power.before_build(self,wanted)
		if wanted not in [battle.roster_id("GAPOWR", house_id), battle.roster_id("GAREFN", house_id)] and not _can_fund_structure(wanted, wanted in [radar,lab]): return
		battle.request_structure(wanted, house_id)
	else:
		wanted = Operations.next_building(self, owned)
		if wanted != "": battle.request_structure(Power.before_build(self,wanted), house_id)

func _can_fund_structure(id: String, installments: bool) -> bool:
	var available := funds - Tactics.committed(battle,house_id)
	var reserve: float = Economy.reserve(self)
	if installments and reserve == 0.0: return available > 0.0
	return available >= reserve + float(GameData.get_building(id).cost)

func _try_defense(owned: Array) -> void:
	if not battle.structure_jobs("defense",house_id).is_empty() or battle.structure_ready_count("defense",house_id) > 0: return
	var soviet := enemy_base == "soviet"
	var aa := "NAFLAK" if soviet else "NASAM"
	var priority: Array = []
	var air_order := Tactics.air_defense_order(battle,house_id,difficulty,owned)
	if not air_order.is_empty(): priority.append(air_order)
	if owned.has(battle.roster_id("GAREFN",house_id)) and owned.has(battle.roster_id("GAWEAP",house_id)):
		priority.append("TESLA" if soviet else "ATESLA")
		if soviet: priority.append_array(["NALASR","NABNKR"])
	for id in priority:
		if id != aa and owned.has(id): continue
		if GameData.ra2_prereq_ok(id, owned, battle.allied_state, house_id) and _can_fund_structure(id,true) and Operations.has_build_spot(self,id):
			battle.request_structure(id,house_id)
			return

func _has_miner() -> bool:
	for unit in battle.units:
		if is_instance_valid(unit) and unit.side == house_id and unit.is_harvester and unit.hp > 0.0 and not unit._dead:
			return true
	return false

func wave_candidates(full: bool) -> Array:
	var source: Array = battle.units if full else _army
	var ready := []
	for unit in source:
		if not Tactics.fighter(battle,unit,house_id) or unit.repairing or unit.special.has("ai_deploy_mission"): continue
		if full:
			if preload("res://scripts/world/ai_blocked_route.gd").waiting(battle,unit):continue
			if preload("res://scripts/units/ai_engagement.gd").busy(unit) or unit.special.has("action"): continue
			if ai_state.has("brutal_alarm") and unit.special.has("brutal_relief_at"): continue
			if unit.has_move_order and unit.attack_move and not unit.special.has("ai_defense_goal"): continue
		elif enemy_base != "swarm" and not Assembly.ready(unit,rally): continue
		ready.append(unit)
	return ready

func _launch_attack(full := false) -> void:
	_army = _army.filter(func(u): return Tactics.fighter(battle,u,house_id))
	var attackers: Array = Campaign.wave(self)
	if attackers.is_empty():
		_attack_t=2.0
		return
	var tgt: Vector2 = objective() if enemy_base=="swarm" else Tactics.attack_position(self,attackers)
	for u in attackers:
		Micro.release(u)
		u.special.erase("ai_defense_goal")
		_army.erase(u)
	if difficulty == 6: Brutal.advance(self, attackers, tgt)
	else: Assembly.advance(self, attackers, tgt)
	var n := attackers.size()
	_attack_t = float(tuning.get("attack_delay", 55.0)) * _rng.randf_range(0.85, 1.15)
	if n > 0 and battle.fog == null:
		Events.emit_message("敌军发起进攻（%d 台）" % n, Color(1.0, 0.55, 0.42))
	a_attacks += 1

func stats() -> Dictionary:
	return {"spawned": a_spawned, "attacks": a_attacks, "pool": _unit_pool.size(), "funds": int(funds)}
