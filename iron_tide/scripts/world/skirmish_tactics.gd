extends RefCounted
## Independent Godot policy inspired by aimd.ini's task forces, base guards and
## conditional teams. It reads current visible evidence, never grants resources.
const BASE_DEFENSE_RADIUS := 450.0
const MIX := {"E1": 1.0, "GGI": 1.1, "MTNK": 2.2, "FV": 1.3, "SREF": 1.5, "MGTK": 1.5, "TNKD": 1.2, "JUMPJET": 0.9}

# Applied after technology and counters, before comparing eligible products.
const PROCUREMENT := {"GHOST":0.0875, "IVAN":0.0875, "SREF":1.95, "MGTK":1.5, "JUMPJET":1.5, "FV":1.5,
	"APOC":1.95, "HTK":1.5, "TTNK":1.5, "ZEP":1.5}

static func fighter(world, unit, owner := "enemy") -> bool:
	if not is_instance_valid(unit) or unit.side != owner or unit.embarked_in != null: return false
	if not world.actor_alive(unit): return false
	if unit.special.get("expedition_objective","")=="command":return false
	if unit.unit_id == "BFRT" and unit._anim < float(unit.special.get("ai_crew_wait", -1.0)):
		if unit.logistics.used_capacity() < unit.logistics.capacity: return false
	return not unit.special.has("ai_oil_post") and not unit.special.has("field_convoy") \
		and unit.logistics.ammo_max == 0 and not unit.is_naval and unit.unit_id != "SHAD" \
		and unit.special.get("action", "") not in ["tesla_charge", "allied_garrison"] \
		and not unit.special.get("ai_transport_reserved", false) \
		and not unit.is_harvester and unit.deploy_building_id().is_empty() \
		and float(unit._active_weapon().get("damage", 0)) > 0.0

static func visible_opponents(world, owner := "enemy") -> Array:
	return world.units.filter(func(u): return world.actor_alive(u) and BattleRequest.is_house(u.side) and not BattleRequest.friendly(owner,u.side) and world.actor_visible_to(owner,u))

# Land and naval orders share visibility for one synchronous house decision.
static func production_contacts(world, owner: String, contacts: Dictionary) -> Array:
	if not contacts.has("opponents"):
		contacts.opponents = visible_opponents(world, owner)
	return contacts.opponents

# Count spotted hostile airships separately from ordinary air contacts.
static func visible_kirovs(world, owner: String) -> int:
	var count := 0
	for unit in world.units:
		if world.actor_alive(unit) and unit.unit_id == "ZEP" and not BattleRequest.friendly(owner, unit.side) and BattleRequest.is_house(unit.side) and unit.is_air_target() and world.actor_visible_to(owner, unit):
			count += 1
	return count

static func mobile_aa_quota(kirovs: int) -> int:
	return mini(12, 2+2*kirovs) if kirovs>0 else 0

static func emergency_aa_product(world, owner: String, line, kirovs: int, counts: Dictionary, budget: float) -> String:
	if kirovs == 0: return ""
	var product: String = {"GAWEAP":"FV", "NAWEAP":"HTK", "NAHAND":"FLAKT", "GAPILE":"JUMPJET"}.get(line.building_id,"")
	if product.is_empty() or int(counts.get(product,0)) >= mobile_aa_quota(kirovs): return ""
	if not line.can_queue(product) or world.production_price(GameData.get_unit(product),owner) > budget: return ""
	return product

static func air_defense_order(world, owner:String, difficulty:int, owned:Array) -> String:
	var id := "NAFLAK" if world.roster_faction(owner)=="soviet" else "NASAM"
	var count := owned.count(id)
	if not GameData.ra2_prereq_ok(id, owned, world.allied_state, owner): return ""
	var kirovs := visible_kirovs(world,owner)
	if kirovs > 0: return id if count < mini(10, 2+2*kirovs) else ""
	if count>=2 or (difficulty==0 and count>=1): return ""
	if count==0 and owned.has(world.roster_id("GAWEAP",owner)) and owned.has(world.roster_id("GAREFN",owner)): return id
	for u in world.units:
		if world.actor_alive(u) and BattleRequest.is_house(u.side) and not BattleRequest.friendly(owner,u.side) and u.is_air_target() and world.actor_visible_to(owner,u): return id
	return ""

static func committed(world, owner := "enemy") -> float:
	var total := 0.0
	for job in world.allied_state.get("house_ai",{}).get(owner,{}).get("construction_jobs",[]):
		total += maxf(0.0,float(job.cost)-float(job.paid))
	for b in world.buildings:
		if not world.actor_alive(b) or b.side != owner: continue
		if b.under_construction:
			total += b.build_cost * (1.0 - b.build_elapsed / maxf(b.build_total,0.01))
		for i in b.production.size():
			var price: float = world.production_price(GameData.get_unit(b.production[i]), owner)
			if i == 0: price = float(b.special.get("unit_price",price)) - b.production_paid
			total += maxf(0.0, price)
	if owner == "enemy":
		for job in world.enemy_struct_queue:
			total += maxf(0.0, float(job.cost) - float(job.get("paid", 0.0)))
	return total

# Expand only after the normal tech chain. Price both the building and its first
# batch against the owner's treasury, net of orders and replacement miner cash.
static func additional_factory(world, owner: String, difficulty: int, owned: Array, reserve := 0.0) -> String:
	var soviet: bool = world.roster_faction(owner) == "soviet"
	if not owned.has("NATECH" if soviet else "GATECH") or world.side_power_low(owner): return ""
	if not owned.has(world.roster_id("GAREFN",owner)): return ""
	if not world.units.any(func(u): return world.actor_alive(u) and u.side==owner and u.is_harvester): return ""
	var available: float = world.funds_for(owner) - committed(world,owner) - reserve
	var cap := 3 if difficulty>=3 else 2
	var factory: String = world.roster_id("GAWEAP",owner)
	var barracks: String = world.roster_id("GAPILE",owner)
	if not owned.has(factory) or not owned.has(barracks): return ""
	var preferred := ""
	var smallest := cap
	var power: Dictionary = world._side_power(owner)
	for id: String in [factory,barracks]:
		var count := owned.count(id)
		if count==0 or count>=smallest or not GameData.ra2_prereq_ok(id, owned, world.allied_state, owner): continue
		var data := GameData.get_building(id)
		var product := ("HTNK" if soviet else "MTNK") if id==factory else ("E2" if soviet else "E1")
		var batch:float = world.production_price(GameData.get_unit(product),owner) * (count+1)
		var budget := float(data.cost) + batch
		var needs_power:bool = power.produced-power.drain+float(data.get("power",0))<0
		var power_id:String=world.roster_id("GAPOWR",owner)
		if needs_power: budget+=float(GameData.get_building(power_id).cost)
		if available<budget: continue
		var working := 0
		var busy := 0
		for line in world.buildings:
			if not world.actor_alive(line) or line.side!=owner or line.building_id!=id: continue
			if line.is_operational() and not line.production_paused() and not line.exit_blocked:
				working+=1
				if not line.production.is_empty(): busy+=1
		if working!=count or (busy<count and available<budget+float(data.cost)): continue
		preferred = power_id if needs_power else id
		smallest = count
	return preferred

# Test a duplicate factory against the existing type's actual doors. Keep its
# siblings' main exits outside the new navigation footprint as well.
static func expansion_site_ok(world, owner:String, data:Dictionary, point:Vector2) -> bool:
	if not world.build_spot_ok(point,data,true,owner).ok: return false
	if not preload("res://scripts/world/ai_base_access.gd").placement_ok(world,owner,data,point): return false
	if data.id not in ["GAWEAP","NAWEAP","GAPILE","NAHAND"]: return true
	var template = null
	var footprint := Placement.aabb(Building.placement_poly(data),point)
	for line in world.buildings:
		if not world.actor_alive(line) or line.side!=owner: continue
		if line.building_id==data.id: template=line
		if line.building_id not in ["GAWEAP","NAWEAP","GAPILE","NAHAND"]: continue
		if ProductionExit.supported(line):
			var unit_data := GameData.get_unit("BFRT" if line.building_id=="GAWEAP" else "GGI")
			var port := ProductionExit.origin(line,unit_data)
			if footprint.grow(float(unit_data.radius)+PathService.CELL).has_point(port): return false
	if template==null: return true
	var product := GameData.get_unit({"GAWEAP":"BFRT","NAWEAP":"APOC","GAPILE":"GGI","NAHAND":"SHK"}[data.id])
	var radius := float(product.radius)
	if ProductionExit.supported(template):
		var origin:Vector2 = point + (ProductionExit.origin(template,product)-template.global_position)
		var forward := ProductionExit.direction(template)
		return template._exit_position_clear(origin,radius,false,false) and template._exit_position_clear(origin+forward*PathService.CELL,radius,false,false)
	for i in 8:
		var dir:=Vector2.DOWN.rotated(i*TAU/8)
		var exit:Vector2=point+dir*(template.footprint_clearance(dir)+66.0+radius)
		if template._exit_position_clear(exit,radius,false,false) and template._exit_position_clear(exit+dir*PathService.CELL,radius,false,false): return true
	return false

static func saving_for_armour(ai, factory_id: String, reserve: float) -> bool:
	var tank := "HTNK" if ai.enemy_base == "soviet" else "MTNK"
	if not ai._unit_pool.has(tank) or ai.funds - committed(ai.battle,ai.house_id) - reserve >= float(GameData.get_unit(tank).cost): return false
	var infantry := 0
	for u in ai.battle.units:
		if not fighter(ai.battle, u, ai.house_id): continue
		if u.data.get("built_at") == factory_id: return false
		if AlliedAbilities.infantry(u): infantry += 1
	if infantry < 3: return false
	for b in ai.battle.buildings:
		if ai.battle.actor_alive(b) and b.side == ai.house_id and b.building_id == factory_id and b.is_operational() and b.production.is_empty() and b.can_queue(tank):
			return true
	return false

static func tech_tier(uid: String) -> int:
	var tier := 1
	for requirement in GameData.ra2_prereq.get(uid, []):
		if requirement in ["TECH", "GATECH", "NATECH", "YATECH"]: return 3
		if requirement in ["RADAR", "GAAIRC", "AMRADR", "NARADR", "GADEPT", "NADEPT"]: tier = 2
	return tier

static func counter_score(data: Dictionary, opponents: Array) -> float:
	var sum := 0.0
	for target in opponents:
		var best := 0.0
		var airborne: bool = target.is_air_target()
		for key in ["weapon", "anti_air_weapon", "deployed_weapon"]:
			var gun: Dictionary = data.get(key, {})
			if gun.is_empty() or (airborne and not CombatMath.can_hit_air(gun)) or (not airborne and not bool(gun.get("ra2_ag", true))): continue
			var damage := CombatMath.full_damage(gun, target.armor, {}, target.bonuses, target.ra2_armor, 0.0, target)
			best = maxf(best, damage * maxi(1, int(gun.get("burst",1))) / maxf(0.1, float(gun.get("cooldown",1.0))) / maxf(1.0,target.max_hp) * 100.0)
		sum += best
	return sum / maxi(1,opponents.size())

static func combat_product(data: Dictionary) -> bool:
	if data.get("role") == "economy": return false
	var raw: Dictionary = GameData.ra2_source_units.get(str(data.id), {}).get("extra", {})
	if not str(raw.get("DeploysInto", "")).is_empty(): return false
	if str(data.id) in ["ENGINEER", "SENGINEER", "YENGINEER", "SPY"]: return false
	for key in ["weapon", "anti_air_weapon", "deployed_weapon"]:
		if float(data.get(key, {}).get("damage", 0)) > 0: return true
	return false

static func production_score(uid: String, data: Dictionary, opponents: Array, count: int, scores: Dictionary = {}) -> float:
	if not scores.has(uid): scores[uid] = counter_score(data, opponents)
	var matchup: float = scores[uid]
	var weight := float(MIX.get(uid, 1.0)) + 0.5 * (tech_tier(uid) - 1)
	if data.get("role") == "air" and count == 0: weight += 2.0
	return (weight + 1.5 * matchup) * float(PROCUREMENT.get(uid, 1.0)) / (1.0 + count * 0.65)

static func production(ai, factory_id := "", reserve := 0.0, line = null, kirovs := 0, batch: Dictionary = {}) -> Dictionary:
	var world = ai.battle
	var available := maxf(0.0, ai.funds - committed(world,ai.house_id) - reserve)
	# One synchronous shopping pass can visit the same line twice. Visibility
	# and matchup scores are stable during the pass; the caller advances counts
	# only after a successful enqueue. Funds and queue eligibility are read live.
	if batch.is_empty():
		batch.opponents = visible_opponents(world,ai.house_id)
		batch.scores = {}
		var initial := {}
		for u in world.units:
			if world.actor_alive(u) and u.side == ai.house_id:
				initial[u.unit_id] = int(initial.get(u.unit_id, 0)) + 1
		for b in world.buildings:
			if not world.actor_alive(b) or b.side != ai.house_id: continue
			for uid in b.production: initial[uid] = int(initial.get(uid, 0)) + 1
		batch.counts = initial
	var counts: Dictionary = batch.counts
	if line != null:
		var urgent := emergency_aa_product(world,ai.house_id,line,kirovs,counts,available)
		if urgent in ai._unit_pool: return {"uid":urgent, "producer":line}
		if counts.has("BFRT") and line.building_id == "GAPILE" and "E1" in ai._unit_pool and line.can_queue("E1") and available >= world.production_price(GameData.get_unit("E1"), ai.house_id):
			if preload("res://scripts/world/skirmish_fortress_crew.gd").needs_riflemen(world, ai.house_id):
				return {"uid":"E1", "producer":line}
	var best := {}
	var best_score := -INF
	var preferred:String=ai.ai_state.get("preferred_recruit","")
	var products: Array = line.buildable if line != null else ai._unit_pool
	for uid: String in products:
		if not ai._unit_pool.has(uid): continue
		var data := GameData.get_unit(uid)
		# Harvesters and MCVs have dedicated procurement orders and caps.
		if not combat_product(data): continue
		if world.production_price(data, ai.house_id) > available: continue
		var producer = null
		for b in ([line] if line != null else world.buildings):
			if not world.actor_alive(b) or b.side != ai.house_id: continue
			if not factory_id.is_empty() and b.building_id != factory_id: continue
			if not b.is_operational() or not b.can_queue(uid): continue
			if b.production.size() < 2 and (producer == null or b.production.size() < producer.production.size()): producer = b
		if producer == null: continue
		var score := production_score(uid, data, batch.opponents, int(counts.get(uid, 0)), batch.scores)
		if uid==preferred:score*=1.25
		score /= 1.0 + producer.production.size() * 0.5
		if score > best_score:
			best_score = score
			best = {"uid": uid, "producer": producer}
	return best

## Check the actual blast origin against current ownership, including remote bases.
static func unsafe_demo_site(world, side: String, point: Vector2) -> bool:
	var warhead := str(preload("res://scripts/core/yr_death_rules.gd").data().weapons.DEMOBOMB.warhead)
	for b in world.buildings:
		if not world.actor_alive(b) or not BattleRequest.friendly(b.side,side): continue
		var distance: float = point.distance_to(b.global_position)
		if distance <= BASE_DEFENSE_RADIUS: return true
		var clearance: float = b.footprint_clearance(b.global_position.direction_to(point))
		if Ra2Damage.in_spread(distance - clearance, warhead): return true
	return false

static func base_threat(ai):
	var best = null
	var opponents := visible_opponents(ai.battle,ai.house_id)
	if opponents.is_empty(): return null
	var positions := PackedVector2Array()
	for building in ai.battle.buildings:
		if ai.battle.actor_alive(building) and building.side == ai.house_id:
			positions.append(building.global_position)
	var nearest := BASE_DEFENSE_RADIUS * BASE_DEFENSE_RADIUS
	for opponent in opponents:
		var origin: Vector2 = opponent.global_position
		for point in positions:
			var distance := origin.distance_squared_to(point)
			if distance < nearest:
				nearest = distance
				best = opponent
	return best

static func attack_position(ai, army: Array) -> Vector2:
	var objective_state:Dictionary=ai.battle.allied_state.get("expedition_task",{})
	if objective_state.has("counter_point") and not BattleRequest.friendly("ally",ai.house_id):
		return objective_state.counter_point
	var best := -INF
	# This fallback is the known opposing starting region, not hidden actor data.
	var result: Vector2 = ai.objective()
	var center: Vector2 = ai.rally
	if not army.is_empty():
		center=Vector2.ZERO
		for unit in army: center+=unit.global_position
		center/=army.size()
	var fighters: Array = army.filter(func(u): return fighter(ai.battle,u,ai.house_id))
	for target in ai.battle.units + ai.battle.buildings:
		if is_instance_valid(target) and target is Building and WallArt.is_wall(target.data): continue
		if not ai.battle.actor_alive(target) or not BattleRequest.is_house(target.side) or BattleRequest.friendly(ai.house_id,target.side) or not ai.battle.actor_visible_to(ai.house_id, target): continue
		var priority := 30.0
		if target is Building:
			priority = 90.0
			if target.is_refinery(): priority = 120.0
			elif target.building_id == "GAWEAP": priority = 130.0
			elif target.building_id in ["GAWEAT", "GACSPH", "NAMISL", "NAIRON"]: priority = 180.0
		elif target.is_harvester: priority = 110.0
		priority += 15.0 * (1.0 - target.hp / maxf(1.0, target.max_hp))
		var distance: float = center.distance_to(target.global_position)
		priority -= distance / 30.0
		if target is Building and distance<=12.0*Ra2Damage.PX_PER_CELL: priority+=100.0
		if priority > best:
			# Scores cannot improve after this point. Resolve expensive weapon,
			# disguise and visibility eligibility only for a potential new winner.
			if not fighters.any(func(u): return u.attack_domain_valid(target)): continue
			best = priority
			result = target.global_position
	return result
