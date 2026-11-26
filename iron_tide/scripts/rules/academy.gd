extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Permanent progression is written through MetaProgress's atomic profile replacement.
const LEGACY_HEROES := {"E1":"守望者", "E2":"炉火", "MTNK":"北辰", "HTNK":"铁脊"}
const HEROES := {"E1":"守望者", "E2":"炉火", "MTNK":"北辰", "HTNK":"铁脊", "TANY":"谭雅", "BORIS":"鲍里斯", "ORCA":"游隼", "TTNK":"雷铸", "FV":"引片", "HARV":"老秤", "CLNT":"克林特", "ARND":"阿诺", "STLN":"史泰龙"}
const Stars = preload("res://scripts/rules/hollywood_heroes.gd")
const Commandos = preload("res://scripts/units/expansion_2_commandos.gd")
const HERO_REQUIREMENT := 50
const ContractPool=preload("res://scripts/rules/hero_contract_pool.gd")
static var ESCORT_RANKS:Array:
	get:return [Array(range(P.count("hero/infantry/escort","elite_0"))).map(func(_i):return 2)+Array(range(P.count("hero/infantry/escort","veteran_0"))).map(func(_i):return 1),Array(range(P.count("hero/infantry/escort","elite_1"))).map(func(_i):return 2)+Array(range(P.count("hero/infantry/escort","veteran_1"))).map(func(_i):return 1),Array(range(P.count("hero/infantry/escort","elite_2"))).map(func(_i):return 2)+Array(range(P.count("hero/infantry/escort","veteran_2"))).map(func(_i):return 1),Array(range(P.count("hero/infantry/escort","elite_3"))).map(func(_i):return 2)+Array(range(P.count("hero/infantry/escort","veteran_3"))).map(func(_i):return 1)]

const SURVIVAL_STAGES_DEFAULT = [
	"犬扑、海豹冲锋枪和谭雅双枪的致命一击最多扣除 1/4 最大生命",
	"恐怖机器人扑击和狙击枪的致命一击最多扣除 1/3 最大生命",
	"免疫碾压",
	"生化、辐射武器的致命一击最多扣除 1/2 最大生命",
	"自爆武器的致命一击最多扣除 2/3 最大生命",
	"超时空擦除英雄所需的持续冻结时间翻倍",
]
static var SURVIVAL_STAGES:Array:
	get:return P.traits("hero/infantry/survival",SURVIVAL_STAGES_DEFAULT)

static func hero_requirement(id:String) -> int:
	if id in Stars.IDS or id in ["FV","HARV"]:return 1
	if id in ["ORCA","TTNK"]:return 5
	if id in Commandos.IDS:return 5
	return 20 if id in ["MTNK","HTNK"] else HERO_REQUIREMENT

static func legacy_bonuses(unit) -> bool:
	return unit.special.get("academy_hero","") in LEGACY_HEROES

static func hero_build_count(meta,id:String) -> int:
	return int(meta.academy.get("hero_builds",{}).get(id,0))

const PEREGRINE_PRODUCTS := ["SHAD", "ORCA", "BEAG"]

static func aircraft_product(unit) -> bool:
	return is_instance_valid(unit) and unit is Unit and unit.is_air and unit.unit_id in PEREGRINE_PRODUCTS and not Commandos.R.temporary(unit)

static func reinforcement_unlocked(id:String,side:String) -> bool:
	# Freeze player eligibility at match start; AI does not use the player's profile.
	return side!="ally" or bool(BattleRequest.combat_context.get("reinforcement_hero_unlocked",{}).get(id,false))

static func crush_immune(target) -> bool:
	if target.special.get("academy_hero")=="TANY":return preload("res://scripts/units/tanya_talents.gd").rank(target,true)>=3
	if Unit.TankHero.active(target):return Unit.TankHero.rank(target,true)>=3
	return survival_rank(target)>=2

static func survival_rank(target) -> int:
	if target.special.get("academy_hero","") not in ["E1","E2"]: return -1
	return clampi(int(target.special.get("hero_survival_rank",0)),0,SURVIVAL_STAGES.size()-1)

static func survival_damage(target, damage:float, warhead:String, weapon:String) -> float:
	var rank:=survival_rank(target)
	if rank < 0 or damage < target.hp: return damage
	var fraction:float
	match warhead.trim_prefix("YR_SOV_").trim_prefix("YR_CAP_"):
		"ParasiteDog": fraction=P.number("hero/infantry/survival","dog_cap")
		"Parasite": fraction=P.number("hero/infantry/survival","sniper_cap") if rank>=1 else 1.0
		"Gas","RadBeamWarhead","RadEruptionWarhead","RadSite": fraction=P.number("hero/infantry/survival","toxic_cap") if rank>=3 else 1.0
		"TerrorBombWH","CRTerrorBombWH","DemobombWH": fraction=P.number("hero/infantry/survival","bomb_cap") if rank>=4 else 1.0
		_:
			match weapon.trim_prefix("YR_SOV_").trim_prefix("YR_CAP_"):
				"MP5","MP5E","ChronoMP5","ChronoMP5E","CRMP5","DoublePistols","DoublePistolsE": fraction=P.number("hero/infantry/survival","dog_cap")
				"Virusgun","VirusgunE": fraction=P.number("hero/infantry/survival","toxic_cap") if rank>=3 else 1.0
				"AWP","AWPE","CRAWP","Sniper": fraction=P.number("hero/infantry/survival","sniper_cap") if rank>=1 else 1.0
				_: return damage
	if fraction>=1.0: return damage
	return minf(damage,target.max_hp*fraction)

static func escort_description(rank:int) -> String:
	var ranks:Array=ESCORT_RANKS[rank]
	var elite:=ranks.count(2)
	var veteran:=ranks.size()-elite
	var groups:=PackedStringArray()
	if veteran: groups.append("%d 名一星老兵" % veteran)
	if elite: groups.append("%d 名二星精英" % elite)
	return "＋".join(groups)

const EXCHANGE := {"epic":50, "legend":200}
const DUPLICATES := {"common":1, "rare":2, "epic":5, "legend":12}

static func hero_talent_cost(action:String, rank:int,hero_id:="") -> int:
	var cap:int=ESCORT_RANKS.size()-1 if action=="escort" else SURVIVAL_STAGES.size()-1 if action=="survival" else 0
	if hero_id in ["TANY","BORIS","ORCA","FV","HARV"] and action in ["escort","survival"]:cap=5
	if hero_id=="ORCA" and action=="survival":cap=preload("res://scripts/units/peregrine_defense.gd").OPEN_RANK
	if hero_id=="TTNK" and action=="escort":cap=preload("res://scripts/units/leizhu_command.gd").OPEN_RANK
	if hero_id=="TTNK" and action=="survival":cap=preload("res://scripts/units/leizhu.gd").OPEN_RANK
	if hero_id in Stars.IDS: cap=2
	var costs:Array=GameData.meta_config.get("hero_talent_rank_costs",[])
	if rank<0 or rank>=cap or rank>=costs.size():return 0
	return maxi(0,int(costs[rank]))

const CARD_MAX_RANK := 3

static func card_upgrade_cost(id:String, current_rank:int) -> int:
	if current_rank<0 or current_rank>=CARD_MAX_RANK:return 0
	var card:=GameData.get_skill(id)
	var costs:Array=GameData.meta_config.get("card_upgrade_costs",{}).get(str(card.get("rarity","")),[])
	if current_rank>=costs.size():return 0
	return maxi(0,int(costs[current_rank]))

const HERO_TRAINING_SCALE := 0.25
const HERO_STEP := {"firepower":2,"health":3}
const HERO_BONUS_CAP := {"firepower":400,"health":600}

static func training_cap(track:String) -> int:
	return ceili(P.number("hero/training","attack_cap" if track=="firepower" else "health_cap")/P.number("hero/training","attack_step" if track=="firepower" else "health_step"))

static func training_rank(training:Dictionary,id:String,track:String) -> int:
	var entry=training.get(id,0)
	# Before the split, one paid level granted both bonuses.
	if not entry is Dictionary: return clampi(int(entry),0,10)
	return clampi(int(entry.get(track,0)),0,training_cap(track))

static func training_percent(track:String,rank:int,scale:float = HERO_TRAINING_SCALE) -> float:
	return minf(rank*P.number("hero/training","attack_step" if track=="firepower" else "health_step"),P.number("hero/training","attack_cap" if track=="firepower" else "health_cap")) * scale

static func hero_training_cost(current_rank: int) -> int:
	var rank := maxi(0,current_rank)
	return int(P.number("hero/training","cost_base")+P.number("hero/training","cost_linear")*rank+P.number("hero/training","cost_squared")*rank*rank)

static func card_rank(meta, id: String) -> int:
	return clampi(int(meta.academy.get("levels", {}).get(id, 0)), 0, CARD_MAX_RANK)

static func card_strength(rank: int, card: Dictionary = {}) -> float:
	var level := clampi(rank,0,CARD_MAX_RANK)
	if card.has("strength_by_rank"): return float(card.strength_by_rank[level])
	return 1.0 + 0.15 * level

static func skill_number(value:float) -> String:
	return String.num(value,2).trim_suffix("0").trim_suffix("0").trim_suffix(".")

static func skill_description(card:Dictionary,rank:int,value:=NAN,duration:=NAN,cooldown:=NAN) -> String:
	return P.describe(str(card.id),base_skill_description(card,rank,value,duration,cooldown))

static func base_skill_description(card:Dictionary,rank:int,value:=NAN,duration:=NAN,cooldown:=NAN) -> String:
	if card.get("expansion",false):return preload("res://scripts/rules/expansion_catalog.gd").description(card,rank)
	rank=clampi(rank,0,CARD_MAX_RANK)
	if card.id=="ap_furnace_bastion":
		return "按 W 切换卧倒和起身，无姿态冷却。本级卧倒攻击 %s 倍，可缓慢移动；护盾就绪时卧倒获得最大生命 %s%% 的护盾，持续 %s 秒，并开始 %s 秒护盾冷却；冷却中卧倒仍有火力加成。移动速度为基础的 %s%%。受击破盾或带盾起身时，对 %s 格内敌人造成 %s%% 攻击力溅射。"%[skill_number(card.attack_by_rank[rank]),skill_number(card.shield_by_rank[rank]*100),skill_number(P.number("mechanic/ap_furnace_bastion","shield_seconds")),skill_number(card.cooldown_by_rank[rank]),skill_number(card.speed_by_rank[rank]*100),skill_number(P.number("mechanic/ap_furnace_bastion","blast_radius")),skill_number(card.burst_by_rank[rank]*100)]
	if card.id=="ps_furnace_flak":
		return "%s　车辆生命 %d%%，攻速 %d%%，持续 %d 秒。"%[card.desc,roundi(card.hp_by_rank[rank]*100),roundi(card.rof_by_rank[rank]*100),card.life_by_rank[rank]]
	if not card.has("rank_text"): return str(card.get("desc",""))
	rank=clampi(rank,0,CARD_MAX_RANK)
	var strength:=card_strength(rank,card)
	if is_nan(value): value=float(card.value)*strength
	if is_nan(duration):
		duration=float(card.get("duration",0))
		if card.effect=="stun": duration*=strength
	var fields:={"pct":skill_number(value*100),"value":skill_number(value),
		"reduction":skill_number(100.0*value/(1.0+value)),"duration":skill_number(duration),
		"radius":card.get("radius",0),"full":skill_number(value*300)}
	if card.has("objective_by_rank"): fields.goal = int(card.objective_by_rank[rank])
	match str(card.id):
		"ap_tesla_chain":
			fields.primary=skill_number(card.primary_bonus_by_rank[rank]*100)
			fields.branch=skill_number(card.branch_by_rank[rank]*100)
		"ap_decoy":
			fields.window=card.echo_seconds
		"ap_twin":
			var count:int=card.twin_hits[rank]
			fields.window=skill_number(card.twin_windows[rank])
			fields.shots="%d 发" % count
			if card.twin_extra_chance[rank]>0:
				fields.shots+="，第 %d 发有 %d%% 概率额外强化" % [count+1,roundi(card.twin_extra_chance[rank]*100)]
		"ap_slope":
			fields.drive=card.drive_seconds
			fields.speed=skill_number(card.speed_by_rank[rank]*100)
		"ps_contact":
			fields.sight=skill_number(card.contact_seconds[rank])
			fields.report_cd=card.contact_cooldowns[rank]
	var text:="Lv.%d　%s" % [rank,str(card.rank_text).format(fields)]
	if card.type=="active":
		if is_nan(cooldown): cooldown=Ability.cooldown_at_rank(card,rank)
		text+=" 基础冷却 %s 秒。" % Ability.cooldown_text(cooldown)
	var scope:=preload("res://scripts/rules/skill_scope.gd").description(card)
	return text+("\n"+scope if not scope.is_empty() else "")

static func migrate_card_ranks(meta) -> void:
	var levels: Dictionary = meta.academy.get("levels", {})
	for id in levels:
		var old := clampi(int(levels[id]), 1, 10)
		var rank := floori((old - 1) / 3.0)
		var threshold := 1 + 3 * rank
		var unused := 5 * (old * (old - 1) - threshold * (threshold - 1))
		meta.currency.cores = meta.balance("cores") + unused
		levels[id] = rank

const DIAMOND_TASKS := {
	"start": {"title":"开启一场遭遇战", "goal":1, "reward":100},
	"units": {"title":"生产 10 个单位", "goal":10, "reward":50},
	"t3": {"title":"生产 1 个 T3 单位", "goal":1, "reward":150}
}

static func day() -> String:
	return Time.get_date_string_from_system()

static func today(meta) -> Dictionary:
	var daily: Dictionary = meta.academy.get("daily", {})
	var date := day()
	return daily if daily.get("date") == date else {"date":date, "units":0, "t3":0, "start":0, "win":0}

static func eligible(world) -> bool:
	return world.skirmish and not world.gm_unit_lab and not world.match_id.is_empty()

static func started(meta, world) -> void:
	if not eligible(world): return
	var daily := today(meta)
	if int(daily.start) != 0: return
	daily.start = 1
	meta.academy.daily = daily
	meta.currency.diamonds = meta.balance("diamonds") + int(DIAMOND_TASKS.start.reward)
	meta.save()

static func t3(id: String) -> bool:
	if int(GameData.get_unit(id).get("ra3_clearance", 0)) >= 3: return true
	for pre in GameData.ra2_prereq.get(id, []):
		if pre in ["TECH","GATECH","NATECH","YATECH"]: return true
	return false

static func hero_label(id:String) -> String:
	return ("☆ " if id in Commandos.IDS else "") + str(HEROES[id])

static func built(meta, world, id: String, unit, factory:Building=null) -> void:
	if not eligible(world) or meta.stats.get("player_production", {}).get("settled", {}).has(world.match_id): return
	var hero_id:="ORCA" if aircraft_product(unit) else id
	if hero_id in ["ORCA","TTNK"] and (not BattleRequest.combat_context.get("expedition",{}).is_empty() or not is_instance_valid(unit) or unit.side!="ally" or Commandos.R.temporary(unit)):return
	if id in Commandos.IDS and (not BattleRequest.combat_context.get("expedition",{}).is_empty() or not is_instance_valid(unit) or unit.side!="ally" or Commandos.R.temporary(unit)):return
	var daily := today(meta)
	var counts: Dictionary = world.allied_state.player_production.unit
	var match_counts: Dictionary = meta.academy.get_or_add("build_records", {}).get_or_add(world.match_id, {})
	var previous := int(match_counts.get(id, 0))
	var count := int(counts[id])
	if (id in Commandos.IDS or hero_id in ["ORCA","TTNK"]) and count<=previous:return
	if count > previous:
		match_counts[id] = count
		var diamonds := 0
		if int(daily.units) < int(DIAMOND_TASKS.units.goal):
			daily.units = int(daily.units) + 1
			if int(daily.units) == int(DIAMOND_TASKS.units.goal): diamonds += int(DIAMOND_TASKS.units.reward)
		if int(daily.t3) == 0 and t3(id):
			daily.t3 = 1
			diamonds += int(DIAMOND_TASKS.t3.reward)
		meta.academy.daily = daily
		meta.currency.diamonds = meta.balance("diamonds") + diamonds
		if HEROES.has(hero_id) and hero_id not in Stars.IDS and hero_id not in ["FV","HARV"]:
			var totals: Dictionary = meta.academy.get_or_add("hero_builds", {})
			totals[hero_id] = int(totals.get(hero_id, 0)) + 1
			var new_hero: bool = BattleRequest.extensions_enabled() and not world.allied_state.get("named_heroes",{}).has(hero_id)
			if totals[hero_id] <= hero_requirement(hero_id) or new_hero:
				var recent: Array = meta.academy.get_or_add("hero_recency", [])
				recent.erase(hero_id)
				recent.push_front(hero_id)
		meta.save()
	if id in Stars.IDS or id in ["FV","HARV"]:
		return
	if not HEROES.has(id) or not BattleRequest.extensions_enabled() or id in ["MTNK","HTNK","ORCA","TTNK"]: return
	promote(meta,world,id,unit,factory)

static func promote(meta,world,id:String,unit,factory:Building=null) -> void:
	if id in Commandos.IDS and (not BattleRequest.extensions_enabled() or not is_instance_valid(unit) or unit.unit_id!=id or unit.side!="ally" or Commandos.R.temporary(unit)):return
	var expedition:Dictionary=BattleRequest.combat_context.get("expedition",{})
	if not expedition.is_empty():
		var roster=preload("res://scripts/expedition/heroes.gd")
		if id not in roster.owned(expedition) or id in roster.wounded(expedition):return
		meta=BattleRequest.combat_context.expedition_hero_profile
	if id in Stars.IDS:
		if not expedition.is_empty():Stars.promote(unit)
		return
	if id in ["FV","HARV"]:
		if not expedition.is_empty():preload("res://scripts/units/convoy_heroes.gd").promote(unit,world,meta)
		return
	if id=="ORCA":
		preload("res://scripts/units/peregrine.gd").promote(meta,world,unit)
		return
	if id=="TTNK":
		preload("res://scripts/units/leizhu.gd").promote(meta,world,unit)
		return
	var deployed: Dictionary = world.allied_state.get_or_add("named_heroes", {})
	if id in Commandos.IDS and expedition.is_empty() and not BattleRequest.combat_context.get("commando_hero_unlocked",{}).get(id,false):return
	if deployed.has(id) or (id not in Commandos.IDS and expedition.is_empty() and int(meta.academy.get("hero_builds", {}).get(id, 0)) < hero_requirement(id)): return
	deployed[id] = 10
	unit.special.academy_hero = id
	unit.equip_hero_cards()
	unit.special.hero_command_rank = int(BattleRequest.combat_context.get("hero_escort_ranks",{}).get(id,0))
	unit.special.hero_survival_rank = int(BattleRequest.combat_context.get("hero_survival_ranks",{}).get(id,0))
	unit.display_name = "%s · %s" % [unit.display_name, HEROES[id]]
	if id in Commandos.IDS:unit.display_name=hero_label(id)
	unit.special.hero_skin = meta.academy.get("hero_skin", {}).get(id, false)
	var training:Dictionary=BattleRequest.combat_context.get("hero_training",meta.academy.get("hero_training",{}))
	var scale := float(BattleRequest.combat_context.get("hero_training_scale", 1.0))
	var hp_multiplier:=1.0+0.01*training_percent("health",training_rank(training,id,"health"),scale)
	var attack_multiplier:=1.0+0.01*training_percent("firepower",training_rank(training,id,"firepower"),scale)
	unit._grant_veteran(int(GameData.ra2_veteran_rules().get("cap", 2)), false)
	unit._base_max_hp *= hp_multiplier
	unit.max_hp = unit._base_max_hp
	unit.hp = unit.max_hp
	unit._base_atk *= CombatMath.additional_growth_ratio(unit.bonuses, attack_multiplier)
	unit._recompute_bonuses()
	unit._refresh_weapon_derived()
	if id in Commandos.IDS:Commandos.install(unit)
	if id in ["MTNK","HTNK"]:
		unit.add_to_group(NavalContact.sensor_group(unit.side))
		if Unit.TankHero.rank(unit,true)>=2:unit.sight+=P.number("hero/tank/survival","sight_cells")*Ra2Damage.PX_PER_CELL
	unit.refresh_house_color()
	if factory!=null and id in ["E1","E2"]:
		var talent:=clampi(int(BattleRequest.combat_context.get("hero_escort_ranks",{}).get(id,0)),0,ESCORT_RANKS.size()-1)
		var queue:Array=factory.special.get_or_add("hero_escort_queue",[])
		for stars in ESCORT_RANKS[talent]: queue.append({"unit":id,"stars":stars,"leader":unit})
		release_escorts(factory)

static func release_escorts(factory:Building) -> void:
	var queue:Array=factory.special.hero_escort_queue
	while not queue.is_empty() and factory.side=="ally":
		var next:Dictionary=queue.front()
		var point:=factory._spawn_point(next.unit)
		if point==Vector2.INF:
			factory.special.hero_escort_retry=0.25
			return
		var guard=factory.battle.spawn_unit(next.unit,"ally",point,factory)
		guard.special.initial_escort_owner=next.get("leader")
		guard._grant_veteran(next.stars,false)
		queue.pop_front()
	factory.special.erase("hero_escort_queue")
	factory.special.erase("hero_escort_retry")

static func hero_attacker(source) -> String:
	if not is_instance_valid(source): return ""
	if source is Projectile and source.owner_side=="ally" and source.attacker_bonus.get("boris_mig",false):return "BORIS"
	var actor = source.shooter() if source is Projectile else source
	if actor is Unit and actor.side=="ally" and actor.special.has("tanya_breach_charge"):return "TANY"
	if actor is Unit and actor.side == "ally": return str(actor.special.get("academy_hero", ""))
	return ""

static func hit(target, source) -> void:
	if target.side != "enemy": return
	var id := hero_attacker(source)
	if not id.is_empty(): target.special.get_or_add("hero_assists", {})[id] = true

static func contract_damage(world, target, source, health_loss:float) -> void:
	if world == null or health_loss<=0 or hero_attacker(source)!="E2":return
	world.allied_state.furnace_attacked=true
	if target.side=="neutral" or BattleRequest.friendly(target.side,"ally"):return
	var total:=float(world.allied_state.get("furnace_damage",0))
	world.allied_state.furnace_damage=minf(10000,total+minf(target.hp,health_loss))

static func defeated(world, target, source) -> void:
	preload("res://scripts/units/convoy_heroes.gd").defeated(world,target,source)
	preload("res://scripts/rules/commando_contracts.gd").killed(world,target,source)
	preload("res://scripts/units/progression_expansion.gd").killed(world,target,source)
	if world == null or target.side=="neutral" or BattleRequest.friendly(target.side,"ally"): return
	var deployed: Dictionary = world.allied_state.get("named_heroes", {})
	if deployed.is_empty(): return
	var killer := hero_attacker(source)
	if killer == "E2" and BattleRequest.combat_context.get("furnace_contract",false):
		if (target is Building and target.is_hq) or (target is Unit and (target.special.has("academy_hero") or target.unit_id in ["BORIS","TANY","YURIPR"])):
			world.allied_state.furnace_takedown = true
	for id in deployed:
		if id == killer: deployed[id] += 5
		elif target.special.get("hero_assists", {}).has(id): deployed[id] += 2

const AFFINITY_CAP := 200

static func affinity_level(xp:int) -> int:
	return clampi(xp/100,0,AFFINITY_CAP)

static func affinity_reward(level:int) -> Dictionary:
	if level < 1 or level > AFFINITY_CAP: return {}
	return {"diamonds":100} if level%5==0 else {"credits":100}

static func grant_affinity_rewards(meta, old_level:int, new_level:int, migrating:=false) -> void:
	for level in range(old_level+1,new_level+1):
		if migrating and level%5==0: continue # Already paid by the old milestone schedule.
		var reward:=affinity_reward(level)
		for key in reward:
			meta.currency[key]=meta.balance(key)+int(reward[key])

static func migrate_affinity_rewards(meta) -> void:
	var xp:Dictionary=meta.academy.get("affinity",{})
	for id in HEROES:
		grant_affinity_rewards(meta,0,affinity_level(int(xp.get(id,0))),true)

static func settled(meta, world, win: bool) -> void:
	if not eligible(world): return
	preload("res://scripts/rules/expansion_contracts.gd").settle(meta,world,win)
	if BattleRequest.combat_context.get("furnace_contract",false) and meta.academy.get("furnace_contract",false) and not meta.academy.get("furnace_complete",false):
		var quest:Dictionary=meta.academy.get_or_add("furnace_tasks",{})
		if world.allied_state.get("furnace_takedown",false): quest.takedown=true
		quest.damage=minf(10000,float(quest.get("damage",0))+float(world.allied_state.get("furnace_damage",0)))
		if win and BattleRequest.victory_difficulty()>=2 and not world.allied_state.get("furnace_attacked",false): quest.peace=true
		if quest.get("takedown",false) and quest.damage>=10000 and quest.get("peace",false):
			meta.academy.furnace_complete=true
			for card in ["ap_furnace_bastion","ps_furnace_flak"]:
				if not meta.unlocked_skills.has(card): meta.unlocked_skills.append(card)
	meta.academy.get("build_records", {}).erase(world.match_id)
	var daily := today(meta)
	if win and int(daily.win) == 0:
		daily.win = 1
		meta.academy.daily = daily
		meta.academy.victory_shards = int(meta.academy.get("victory_shards", 0)) + 1
	var deployed: Dictionary = world.allied_state.get("named_heroes", {})
	var xp: Dictionary = meta.academy.get_or_add("affinity", {})
	for id in deployed:
		var old := int(xp.get(id, 0))
		var next := mini(AFFINITY_CAP*100, old + int(deployed[id]) + (20 if win else 0))
		grant_affinity_rewards(meta,affinity_level(old),affinity_level(next))
		xp[id] = next

static func commit(meta, previous: Dictionary, funds: Dictionary, cards: Array) -> bool:
	if meta.save():
		Events.meta_changed.emit()
		return true
	meta.academy = previous
	meta.currency = funds
	meta.unlocked_skills.assign(cards)
	return false

static func daily_draw_available(meta, date: String) -> bool:
	return str(meta.academy.get("last_free_draw_date", "")) < date

static func draw(meta, count: int, daily_free := false) -> Array:
	if count not in [1,10] or not meta.skill_draw_enabled(): return []
	var paid_count := count
	var date := day()
	if daily_free:
		if count != 1 or not daily_draw_available(meta, date): return []
		paid_count = 0
	var tickets := mini(paid_count, int(meta.academy.get("tickets", 0)))
	var cost: float = (paid_count - tickets) * meta.skill_draw_cost()
	if meta.balance("diamonds") < cost: return []
	var groups := {}
	var weights: Dictionary = meta.skill_draw_rules().rarity_weight
	for card in meta.skill_draw_candidates():
		groups.get_or_add(card.rarity, []).append(card)
	for rarity in weights:
		if not groups.has(rarity): return []
	var old: Dictionary = meta.academy.duplicate(true)
	var wallet: Dictionary = meta.currency.duplicate()
	var owned: Array = meta.unlocked_skills.duplicate()
	if daily_free:
		meta.academy.last_free_draw_date = date
	meta.academy.tickets = int(meta.academy.get("tickets", 0)) - tickets
	meta.currency.diamonds = meta.balance("diamonds") - cost
	var rewards := []
	for i in count:
		var contract:=ContractPool.draw(meta)
		if not contract.is_empty():
			meta.academy.card_shards = int(meta.academy.get("card_shards",0)) + 1
			rewards.append({"id":contract,"duplicate":false,"extra":0})
			continue
		var roll := randf() * 100.0
		for rarity in weights:
			roll -= float(weights[rarity])
			if roll > 0.0: continue
			var card: Dictionary = groups[rarity].pick_random()
			var duplicate: bool = meta.skill_unlocked(card.id)
			if not duplicate: meta.unlocked_skills.append(str(card.id))
			var extra := int(DUPLICATES[rarity]) if duplicate else 0
			meta.academy.card_shards = int(meta.academy.get("card_shards", 0)) + 1 + extra
			rewards.append({"id":card.id,"duplicate":duplicate,"extra":extra})
			break
	if not commit(meta, old, wallet, owned): return []
	for row in rewards:
		if ContractPool.entry(row.id).is_empty() and not row["duplicate"]: Events.meta_skill_unlocked.emit(row.id)
	return rewards

static func purchase(meta, action: String, id := "") -> bool:
	if not ContractPool.entry(action).is_empty():return ContractPool.purchase(meta,action)
	var old: Dictionary = meta.academy.duplicate(true)
	var wallet: Dictionary = meta.currency.duplicate()
	var owned: Array = meta.unlocked_skills.duplicate()
	match action:
		"tickets","skin_ticket":
			if int(meta.academy.get("victory_shards", 0)) < 10: return false
			meta.academy.victory_shards -= 10
			meta.academy[action] = int(meta.academy.get(action, 0)) + 1
		"redeem":
			var card := GameData.get_skill(id)
			var cost := int(EXCHANGE.get(card.get("rarity", ""), 0))
			if card.is_empty() or not meta.skill_draw_candidates().has(card) or meta.skill_unlocked(id) or cost <= 0 or int(meta.academy.get("card_shards", 0)) < cost: return false
			meta.academy.card_shards -= cost
			meta.unlocked_skills.append(id)
		"level":
			if not meta.unlocked_skills.has(id): return false
			var level := card_rank(meta, id)
			var cost:=card_upgrade_cost(id,level)
			if cost<=0 or meta.balance("cores")<cost:return false
			meta.currency.cores = meta.balance("cores") - cost
			meta.academy.get_or_add("levels", {})[id] = level + 1
		"escort","survival":
			if not HEROES.has(id) or int(meta.academy.get("hero_builds",{}).get(id,0))<hero_requirement(id): return false
			var key:="hero_escort_ranks" if action=="escort" else "hero_survival_ranks"
			var cap:=ESCORT_RANKS.size()-1 if action=="escort" else SURVIVAL_STAGES.size()-1
			if id in ["TANY","BORIS","ORCA","TTNK","FV","HARV"]:cap=5
			var rank:=int(meta.academy.get(key,{}).get(id,0))
			var cost:=hero_talent_cost(action,rank,id)
			if rank>=cap or cost<=0 or meta.balance("cores")<cost: return false
			meta.currency.cores=meta.balance("cores")-cost
			meta.academy.get_or_add(key,{})[id]=rank+1
		"firepower","health","skin":
			if action=="skin" and (id in Stars.IDS or id in ["ORCA","TTNK"]):return false
			if not HEROES.has(id) or int(meta.academy.get("hero_builds", {}).get(id, 0)) < hero_requirement(id): return false
			if action == "skin":
				if id in ["FV","HARV"] and not meta.academy.get("hero_contracts",{}).get(id,{}).get("complete",false):return false
				var skins: Dictionary = meta.academy.get_or_add("hero_skin", {})
				skins[id] = not skins.get(id, false)
			else:
				var training:Dictionary=meta.academy.get("hero_training",{})
				var rank:=training_rank(training,id,action)
				var cost:=hero_training_cost(rank)
				if rank>=training_cap(action) or meta.balance("credits")<cost: return false
				var ranks:={"firepower":training_rank(training,id,"firepower"),"health":training_rank(training,id,"health")}
				ranks[action]=rank+1
				meta.currency.credits=meta.balance("credits")-cost
				meta.academy.get_or_add("hero_training",{})[id]=ranks
		_: return false
	return commit(meta, old, wallet, owned)
