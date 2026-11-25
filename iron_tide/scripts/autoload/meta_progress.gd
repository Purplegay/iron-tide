extends Node
## 局外养成（老家）存档与结算。
## 存档位置：user://iron_tide_meta.json
## 结构：{ currency, current_tier, unlocked_tiers[], upgrade_levels{}, idle{last_tick_unix, pending{}}, stats{}, house_color }

signal model_smoothing_changed(enabled: bool)

const SAVE_PATH := "user://iron_tide_meta.json"
const DEFAULT_OFFLINE_HOURS := 12.0   ## offline_cap_hours 缺失时的回退值

var currency: Dictionary = { "credits": 0.0, "cores": 0.0 }
const Academy = preload("res://scripts/rules/academy.gd")
var academy: Dictionary = {"bunker_optics_four_ranks":true}
var current_tier: String = "t0"
var unlocked_tiers: Array[String] = ["t0"]
var upgrade_levels: Dictionary = {}          # upgrade_id -> level
var idle: Dictionary = {}                    # last_tick_unix, pending{credits, cores}
var stats: Dictionary = {"appearance_wins":0}                   # battles_won 等统计
var settled_matches: Dictionary = {}        # Match IDs survive loading an earlier battle snapshot.
var contact_archive: Dictionary = {}        # NPC ID -> chapter ID -> expedition appearance.
var contact_transcripts: Dictionary = {}    # NPC ID -> field communications, separate from chapter unlocks.
signal hero_portrait_changed
var driver_portraits: Dictionary = {}
var hero_story_archive: Dictionary = {}
var yuriko_school: Dictionary = {}
var commander_alias: String = ""
var unit_levels: Dictionary = {}             # unit_id -> { track_id: level }
const MAX_TALENT_SLOTS := 2
var talent_slots:Dictionary = {} # Purchased capacity per unit type, independent of the point wallet.
var owned_talent_points:=0 # Total redeemed, including points currently assigned.
var unit_talents: Dictionary = {} # Unit type -> allocated talents (legacy saves may hold one string).
var production_recipes: Dictionary = {}
var recipe_defaults: Dictionary = {}
var unit_loadouts: Dictionary = {}           # unit_id -> { active: [W skill_id], passive: skill_id }; legacy arrays are read compatibly
var unlocked_skills: Array[String] = []      # 已抽取获得的技能 id（通用 base 技能不落盘，恒为可用）
var disabled_effects: Dictionary = {} # Sparse opt-outs. Older profiles enable their purchased effects.
var unlocked_technologies: Array[String] = [] # 永久科技；开局复制到扩展模式，旧对局不追溯。
const ProductionTechnology = preload("res://scripts/rules/production_technology.gd")
const Cosmetics = preload("res://scripts/rules/cosmetic_catalog.gd")
var owned_cosmetics: Dictionary = {}
var unit_cosmetics: Dictionary = {}
var attachment_positions: Dictionary = {}
var house_color: String = "allied"
# ---- 操控 / 显示设置（B2）----
var model_smoothing: bool = true     # World sprites only; UI retains native pixel sampling.
signal camera_settings_changed
var edge_scroll: bool = true          # 边缘滚屏开关
var scroll_speed: int = 50            # 滚屏速度 10..100（50=1170 屏幕像素/秒）
var subtitles: bool = true            # 事件字幕（E 音效前的降级提示）
const SCROLL_BASE := 1170.0           # 原 780 的 1.5 倍；键盘与边缘滚屏共用，独立于战斗倍速

func _ready() -> void:
	load_save()
	preload("res://scripts/rules/hero_loadouts.gd").migrate(self)
	UnitSkillLayout.migrate_card_primaries(self)
	HouseColor.set_player_id(house_color)   # 同步涂装到血条/上色系统（新存档也走这条）
	if idle.is_empty():
		idle = { "last_tick_unix": _now(), "pending": { "credits": 0.0, "cores": 0.0 } }
	# 每次进入游戏时结算一次离线收益
	accrue_idle()
	save()

func _now() -> float:
	return float(Time.get_unix_time_from_system())

## 退出游戏时把挂机进度落盘，避免未领取的收益丢失
func _exit_tree() -> void:
	accrue_idle()
	save()

# ------------------------------------------------------------------ 档位 / 升级

func tiers() -> Array:
	return GameData.meta_config.get("tiers", [])

func upgrades() -> Array:
	return GameData.meta_config.get("upgrades", [])

func get_tier(tier_id: String) -> Dictionary:
	for t in tiers():
		if str(t.get("id", "")) == tier_id:
			return t
	return {}

func current_tier_data() -> Dictionary:
	return get_tier(current_tier)

func upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))

func get_upgrade_def(upgrade_id: String) -> Dictionary:
	for u in upgrades():
		if str(u.get("id", "")) == upgrade_id:
			return u
	return {}

## 某升级项升到下一级的价格（不满级时有效）
func upgrade_cost(upgrade_id: String) -> float:
	var def := get_upgrade_def(upgrade_id)
	if def.is_empty():
		return 0.0
	var lvl := upgrade_level(upgrade_id)
	var base := float(def.get("cost_base", 100))
	var growth := float(def.get("cost_growth", 1.3))
	return floor(base * pow(growth, lvl))

func upgrade_currency(upgrade_id: String) -> String:
	return str(get_upgrade_def(upgrade_id).get("currency", "cores"))

func upgrade_is_maxed(upgrade_id: String) -> bool:
	var def := get_upgrade_def(upgrade_id)
	return upgrade_level(upgrade_id) >= int(def.get("max_level", 0))

func can_buy_upgrade(upgrade_id: String) -> bool:
	if upgrade_is_maxed(upgrade_id):
		return false
	return balance(upgrade_currency(upgrade_id)) >= upgrade_cost(upgrade_id)

func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy_upgrade(upgrade_id):
		return false
	var cur := upgrade_currency(upgrade_id)
	spend(cur, upgrade_cost(upgrade_id))
	var lvl := upgrade_level(upgrade_id) + 1
	upgrade_levels[upgrade_id] = lvl
	Events.meta_upgrade_bought.emit(upgrade_id, lvl)
	Events.meta_changed.emit()
	save()
	return true

func tier_unlock_cost(tier_id: String) -> float:
	return float(get_tier(tier_id).get("unlock_cost", 0))

func tier_order() -> Array[String]:
	var ids: Array[String] = []
	for tier in tiers():
		ids.append(str(tier.id))
	return ids

func next_tier() -> String:
	var ids := tier_order()
	var index := ids.find(current_tier)
	if index < 0 or index + 1 >= ids.size(): return ""
	return ids[index + 1]

func can_unlock_tier(tier_id: String) -> bool:
	return not tier_id.is_empty() and tier_id == next_tier() and balance("credits") >= tier_unlock_cost(tier_id)

func unlock_tier(tier_id: String) -> bool:
	if not can_unlock_tier(tier_id): return false
	return _advance_tier(tier_id, tier_unlock_cost(tier_id))

func grant_final_tier() -> bool:
	var ids := tier_order()
	if ids.is_empty(): return false
	if current_tier == ids.back(): return true
	return _advance_tier(ids.back(), 0.0)

func _advance_tier(tier_id: String, price: float) -> bool:
	var old_tier := current_tier
	var old_unlocked := unlocked_tiers.duplicate()
	var old_idle := idle.duplicate(true)
	var old_balance := balance("credits")
	accrue_idle()
	currency.credits = old_balance - price
	current_tier = tier_id
	var ids := tier_order()
	unlocked_tiers.assign(ids.slice(0,ids.find(tier_id)+1))
	if not save():
		current_tier = old_tier
		unlocked_tiers = old_unlocked
		idle = old_idle
		currency.credits = old_balance
		return false
	Events.meta_tier_unlocked.emit(tier_id)
	Events.meta_changed.emit()
	return true

func _restore_highest_tier() -> bool:
	var ids := tier_order()
	if ids.is_empty(): return false
	var highest := maxi(0, ids.find(current_tier))
	for id in unlocked_tiers:
		highest = maxi(highest,ids.find(id))
	var completed := ids.slice(0,highest+1)
	if current_tier == ids[highest] and unlocked_tiers == completed: return false
	if current_tier != ids[highest] and ids.has(current_tier) and not idle.is_empty():
		accrue_idle()
	current_tier = ids[highest]
	unlocked_tiers.assign(completed)
	return true

# ------------------------------------------------------------------ 永久科技

func technology_definition(id: String) -> Dictionary:
	if not ProductionTechnology.NODES.has(id): return {}
	var pricing: Dictionary = GameData.meta_config.get("technologies", {}).get(id, {})
	if pricing.is_empty(): return {}
	var definition: Dictionary = ProductionTechnology.NODES[id].duplicate(true)
	definition.merge(pricing, true)
	if definition.has("capacity"):
		definition.desc = "每座单位生产建筑的订单上限提高至 %d 项，包含正在生产的一项。矿场容量由矿场科技决定。" % definition.capacity
	definition.id = id
	return definition

func technology_owned(id: String) -> bool:
	return ProductionTechnology.NODES.has(id) and unlocked_technologies.has(id)

func effect_enabled(kind:String, id:String, unit_id:="") -> bool:
	return not disabled_effects.has("/".join([kind,unit_id,id]))

func set_effect_enabled(kind:String, id:String, unit_id:String, enabled:bool) -> bool:
	match kind:
		"tech":
			if not unit_id.is_empty() or not technology_owned(id):return false
		"talent":
			if id not in selected_talents(unit_id,unit_talents):return false
		"track":
			if unit_level(unit_id,id)<=0:return false
		_:return false
	var key:="/".join([kind,unit_id,id])
	if enabled==effect_enabled(kind,id,unit_id):return true
	if enabled:disabled_effects.erase(key)
	else:disabled_effects[key]=true
	if not save():
		if enabled:disabled_effects[key]=true
		else:disabled_effects.erase(key)
		return false
	Events.meta_changed.emit()
	return true

## Grouped technology UI changes the existing tier switches in one durable write.
func set_technology_group_level(id:String, level:int) -> bool:
	var tiers:Array=ProductionTechnology.UPGRADE_GROUPS.get(id,[])
	if tiers.is_empty() or level<0 or level>tiers.size():return false
	for i in level:
		if not technology_owned(str(tiers[i])):return false
	var before:Dictionary=disabled_effects.duplicate(true)
	for i in tiers.size():
		if not technology_owned(str(tiers[i])):continue
		var key:="tech//"+str(tiers[i])
		if i<level:disabled_effects.erase(key)
		else:disabled_effects[key]=true
	if disabled_effects==before:return true
	if not save():
		disabled_effects=before
		return false
	Events.meta_changed.emit()
	return true

func technology_active(id:String) -> bool:
	if not technology_owned(id) or not effect_enabled("tech",id):return false
	for prerequisite in ProductionTechnology.NODES[id].requires:
		if not technology_active(prerequisite):return false
	return true

func active_talents() -> Dictionary:
	var active:Dictionary={}
	for unit_id in unit_talents:
		var choices:=selected_talents(unit_id,unit_talents).filter(func(id):return effect_enabled("talent",id,unit_id))
		if not choices.is_empty():
			active[unit_id]={}
			for talent in choices:active[unit_id][talent]=talent_rank(unit_id,talent,unit_talents)
	return active

func technology_block_reason(id: String) -> String:
	if id in ProductionTechnology.BUNKER_LEVELS:return "已迁至单位改造：战斗碉堡的专属天赋"
	var definition := technology_definition(id)
	if definition.is_empty(): return "科技配置不可用"
	if technology_owned(id): return "已永久解锁"
	for dependency in definition.requires:
		if not technology_owned(str(dependency)):
			return "需要前置科技：" + str(ProductionTechnology.NODES.get(dependency, {}).get("name", dependency))
	var cost := float(definition.get("cost", -1.0))
	var cur := str(definition.get("currency", ""))
	if not is_finite(cost) or cost < 0.0 or not GameData.meta_config.get("currencies", {}).has(cur): return "科技价格配置无效"
	if balance(cur) < cost:
		return "%s不足：还差 %d" % [currency_name(cur), int(ceil(cost - balance(cur)))]
	return ""

func research_technology(id: String) -> bool:
	if not technology_block_reason(id).is_empty(): return false
	var definition := technology_definition(id)
	var cur := str(definition.currency)
	var previous := balance(cur)
	currency[cur] = previous - float(definition.cost)
	unlocked_technologies.append(id)
	var granted:=grant_research_cosmetics()
	if not save():
		for reward in granted:owned_cosmetics.erase(reward)
		currency[cur] = previous
		unlocked_technologies.erase(id)
		Events.emit_message("科技保存失败，未扣除核心，请重试。", Color(1.0, 0.6, 0.4))
		return false
	Events.meta_changed.emit()
	return true

# ------------------------------------------------------------------ 属性加成

## 档位和后勤升级共用对局的基础倍率。
func stat_bonuses() -> Dictionary:
	var out := MatchRules.neutral_bonuses()
	# 档位基础加成
	var tier := current_tier_data()
	var bonus: Dictionary = tier.get("stat_bonus", {})
	for key in bonus.keys():
		if out.has(key):
			out[key] = float(bonus[key])
	# 升级项加成
	for u in upgrades():
		var uid := str(u.get("id", ""))
		var lvl := clampi(upgrade_level(uid), 0, int(u.max_level))
		if lvl <= 0:
			continue
		var stat := str(u.get("stat", ""))
		var per := float(u.get("effect_per_level", 0.0))
		if stat == "cap_bonus":
			out["cap_bonus"] = float(out.get("cap_bonus", 1.0)) + per * lvl
		elif out.has(stat):
			out[stat] = float(out[stat]) + per * lvl
	return out

# ------------------------------------------------------------------ 单位改造（逐单位）

func talent_shop_price() -> int:
	return int(GameData.meta_config.get("talent_shop",{}).get("cost",0))

func talent_shop_currency() -> String:
	return str(GameData.meta_config.get("talent_shop",{}).get("currency","credits"))

func redeemed_points_in_use() -> int:
	var total:=0
	for id in unit_talents:
		total += selected_talents(id,unit_talents).size()
	return total

func unassigned_talent_points() -> int:
	return owned_talent_points-redeemed_points_in_use()

func redeem_talent_point() -> bool:
	var price:=talent_shop_price()
	var cur:=talent_shop_currency()
	var previous:=balance(cur)
	if price<=0 or previous<price:return false
	currency[cur]=previous-price
	owned_talent_points+=1
	if not save():
		currency[cur]=previous
		owned_talent_points-=1
		return false
	Events.meta_changed.emit()
	return true

func talent_unlock_quote(unit_id:String,talent:String) -> Dictionary:
	return preload("res://scripts/rules/talent_unlock.gd").quote(self,unit_id,talent)

func unlock_unit_talent(unit_id:String,talent:String,expected_cost:int) -> bool:
	return preload("res://scripts/rules/talent_unlock.gd").purchase(self,unit_id,talent,expected_cost)

func talent_options(unit_id:String) -> Dictionary:
	return GameData.meta_config.get("unit_talents",{}).get(unit_id,{})

func talent_capacity(unit_id:String) -> int:
	return clampi(int(talent_slots.get(unit_id,0)),0,3 if unit_id=="V3" else MAX_TALENT_SLOTS)

func available_talent_slots(unit_id:String) -> int:
	return mini(3 if unit_id=="V3" else MAX_TALENT_SLOTS,talent_options(unit_id).size())

func talent_slot_price(slot:int) -> int:
	var prices:Array=GameData.meta_config.get("talent_shop",{}).get("slot_prices",[])
	if slot==3:return 120
	if slot<1 or slot>MAX_TALENT_SLOTS or slot>prices.size():return 0
	return int(prices[slot-1])

func buy_talent_slot(unit_id:String,slot:int) -> bool:
	if slot<1 or slot>available_talent_slots(unit_id):return false
	if (not GameData.unit_index.has(unit_id) and unit_id!="NABNKR") or slot!=talent_capacity(unit_id)+1:return false
	var price:=talent_slot_price(slot)
	var cur:=talent_shop_currency()
	var previous:=balance(cur)
	if price<=0 or previous<price:return false
	currency[cur]=previous-price
	talent_slots[unit_id]=slot
	if not save():
		currency[cur]=previous
		if slot==1:talent_slots.erase(unit_id)
		else:talent_slots[unit_id]=slot-1
		return false
	Events.meta_changed.emit()
	return true

func selected_talents(unit_id:String, selections:Dictionary) -> Array:
	var value = selections.get(unit_id,[])
	if value is Dictionary:return value.keys()
	if value is Array:return value
	return [value] if value is String and not value.is_empty() else []

func talent_rank(unit_id:String,talent:String,selections:Dictionary) -> int:
	var ranks=selections.get(unit_id)
	if not ranks is Dictionary:return 0
	return clampi(int(ranks.get(talent,0)),0,talent_options(unit_id).get(talent,{}).get("ranks",[]).size())

func talent_upgrade_cost(unit_id:String,talent:String) -> int:
	if talent not in selected_talents(unit_id,unit_talents): return 0
	var rank:=talent_rank(unit_id,talent,unit_talents)
	var costs:Array=GameData.meta_config.get("talent_rank_costs",[])
	if rank>=talent_options(unit_id).get(talent,{}).get("ranks",[]).size() or rank>=costs.size(): return 0
	return maxi(0,int(costs[rank]))

func upgrade_talent(unit_id:String,talent:String,expected_rank:int) -> bool:
	var cost:=talent_upgrade_cost(unit_id,talent)
	var rank:=talent_rank(unit_id,talent,unit_talents)
	if cost<=0 or balance("cores")<cost or rank!=expected_rank:return false
	return _save_talent_rank(unit_id,talent,rank+1,cost)

func talent_points(unit_id:String) -> int:
	if talent_options(unit_id).is_empty():return 0
	return mini(unassigned_talent_points(),talent_capacity(unit_id)-selected_talents(unit_id,unit_talents).size())

func set_unit_talent(unit_id:String, talent:String, allocate:=true) -> bool:
	if not allocate or (not GameData.unit_index.has(unit_id) and unit_id!="NABNKR") or not talent_options(unit_id).has(talent):return false
	if talent in selected_talents(unit_id,unit_talents):return true
	if talent_points(unit_id)<1:return false
	return _save_talent_rank(unit_id,talent,0)

func _save_talent_rank(unit_id:String,talent:String,rank:int,core_cost:=0) -> bool:
	var previous_cores := balance("cores")
	var previous=unit_talents.get(unit_id)
	var ranks:Dictionary={}
	for id in selected_talents(unit_id,unit_talents):ranks[id]=talent_rank(unit_id,id,unit_talents)
	ranks[talent]=rank
	unit_talents[unit_id]=ranks
	if core_cost > 0: currency.cores = previous_cores - core_cost
	if not save():
		if core_cost > 0: currency.cores = previous_cores
		if previous==null:unit_talents.erase(unit_id)
		else:unit_talents[unit_id]=previous
		return false
	Events.meta_changed.emit()
	return true

func unit_upgrade_config() -> Dictionary:
	return GameData.meta_config.get("unit_upgrades", {})

func unit_upgrade_tracks() -> Array:
	return unit_upgrade_config().get("tracks", []).filter(func(t):return not t.get("retired",false))

## 玩家装配槽数量；单位固有 Q 与特殊 E 不占用装配槽。
func unit_slot_counts() -> Dictionary:
	return {"active": 1, "passive": 1}

func get_unit_track(track_id: String) -> Dictionary:
	for t in unit_upgrade_config().get("tracks", []):
		if str(t.get("id", "")) == track_id:
			return t
	return {}

func unit_level(unit_id: String, track_id: String) -> int:
	var row: Dictionary = unit_levels.get(unit_id, {})
	return int(row.get(track_id, 0))

func unit_upgrade_maxed(unit_id: String, track_id: String) -> bool:
	var def := get_unit_track(track_id)
	return unit_level(unit_id, track_id) >= int(def.get("max_level", 0))

func unit_upgrade_cost(unit_id: String, track_id: String) -> float:
	var def := get_unit_track(track_id)
	if def.is_empty():
		return 0.0
	var lvl := unit_level(unit_id, track_id)
	var base := float(def.get("cost_base", 100))
	var growth := float(def.get("cost_growth", 1.3))
	return floor(base * pow(growth, lvl))

func unit_upgrade_currency(track_id: String) -> String:
	return str(get_unit_track(track_id).get("currency", "credits"))

func skill_training_benefits(unit_id: String) -> Array:
	return preload("res://scripts/rules/skill_training.gd").benefits(self, unit_id)

func can_buy_unit_upgrade(unit_id: String, track_id: String) -> bool:
	if track_id == "skill" and skill_training_benefits(unit_id).is_empty(): return false
	if not GameData.unit_index.has(unit_id) or get_unit_track(track_id).is_empty(): return false
	if unit_upgrade_maxed(unit_id, track_id):
		return false
	return balance(unit_upgrade_currency(track_id)) >= unit_upgrade_cost(unit_id, track_id)

func buy_unit_upgrade(unit_id: String, track_id: String) -> bool:
	if not can_buy_unit_upgrade(unit_id, track_id):
		return false
	var cur := unit_upgrade_currency(track_id)
	var old_balance := balance(cur)
	var previous = unit_levels.get(unit_id)
	var row: Dictionary = unit_levels.get(unit_id, {}).duplicate()
	currency[cur] = old_balance - unit_upgrade_cost(unit_id, track_id)
	var lvl := int(row.get(track_id, 0)) + 1
	row[track_id] = lvl
	unit_levels[unit_id] = row
	if not save():
		currency[cur] = old_balance
		if previous == null: unit_levels.erase(unit_id)
		else: unit_levels[unit_id] = previous
		return false
	Events.meta_unit_upgraded.emit(unit_id, track_id, lvl)
	Events.meta_changed.emit()
	return true

## 逐单位属性加成：{ attack_bonus, defense_bonus, skill_bonus, hp_bonus }
func unit_stat_bonus(unit_id: String) -> Dictionary:
	var out := { "attack_bonus": 1.0, "defense_bonus": 1.0, "skill_bonus": 1.0, "hp_bonus": 1.0 }
	for t in unit_upgrade_tracks():
		var tid := str(t.get("id", ""))
		var lvl := unit_level(unit_id, tid)
		if lvl <= 0 or not effect_enabled("track",tid,unit_id):
			continue
		var stat := str(t.get("stat", ""))
		var per := float(t.get("effect_per_level", 0.0))
		if out.has(stat):
			out[stat] = float(out[stat]) + per * lvl
	return out

func unit_upgrade_summary(unit_id: String) -> String:
	var parts := PackedStringArray()
	for t in unit_upgrade_tracks():
		var tid := str(t.get("id", ""))
		parts.append("%s %d/%d" % [str(t.get("name", tid)), unit_level(unit_id, tid), int(t.get("max_level", 0))])
	return "　".join(parts)

# --- 技能装配（W 主动 + 1 被动）---

func unit_default_loadout(unit_id: String) -> Dictionary:
	return UnitSkillLayout.normalize(unit_id, UnitSkillLayout.without_legacy_primary(unit_id,GameData.skill_defaults.get(unit_id, {})))

func unit_loadout(unit_id: String) -> Dictionary:
	if unit_loadouts.has(unit_id):
		return UnitSkillLayout.normalize(unit_id, unit_loadouts[unit_id])
	return unit_default_loadout(unit_id)

func set_unit_skill(unit_id: String, slot_type: String, index: int, skill_id: String) -> bool:
	if index != 0 or slot_type not in ["active", "passive"] or (not GameData.unit_index.has(unit_id) and not preload("res://scripts/rules/skill_scope.gd").defense(unit_id)) or not UnitSkillLayout.compatible(unit_id, skill_id) or not can_set_unit_skill(skill_id):
		return false
	if slot_type == "active" and not UnitSkillLayout.equippable(unit_id, skill_id): return false
	if slot_type == "passive" and not skill_id.is_empty() and GameData.get_skill(skill_id).get("type", "") != "passive": return false
	var lo: Dictionary = unit_loadout(unit_id).duplicate(true)
	if slot_type == "passive":
		lo["passive"] = skill_id
	else:
		var n := 1
		var act: Array = lo.get("active", [])
		while act.size() < n:
			act.append("")
		if index >= 0 and index < n:
			act[index] = skill_id
		lo["active"] = act
	var had_previous := unit_loadouts.has(unit_id)
	var previous: Dictionary = unit_loadouts.get(unit_id, {}).duplicate(true)
	unit_loadouts[unit_id] = lo
	if not save():
		if had_previous: unit_loadouts[unit_id] = previous
		else: unit_loadouts.erase(unit_id)
		return false
	Events.meta_loadout_changed.emit(unit_id)
	Events.meta_changed.emit()
	return true

func clear_unit_loadout(unit_id: String) -> void:
	unit_loadouts.erase(unit_id)
	Events.meta_loadout_changed.emit(unit_id)
	Events.meta_changed.emit()
	save()

func auto_configure_unit_skills(ids: Array) -> Dictionary:
	var plan := preload("res://scripts/rules/auto_skill_loadout.gd").plan(self,ids)
	if not plan.ok: return {"ok":false,"changed":0,"reason":plan.reason}
	var changes: Dictionary = plan.changes
	if changes.is_empty(): return {"ok":true,"changed":0,"total":plan.total}
	var previous := unit_loadouts.duplicate(true)
	for uid in changes: unit_loadouts[uid] = changes[uid]
	if not save():
		unit_loadouts = previous
		return {"ok":false,"changed":0,"reason":"save_failed"}
	for uid in changes: Events.meta_loadout_changed.emit(uid)
	Events.meta_changed.emit()
	return {"ok":true,"changed":changes.size(),"total":plan.total}

# ------------------------------------------------------------------ 技能获取（通用 / 抽取）

## 该技能当前是否可用（通用技能恒可用；抽取技能需已解锁）
func skill_unlocked(skill_id: String) -> bool:
	if skill_id == "":
		return false
	if GameData.is_base_skill(skill_id):
		return true
	return unlocked_skills.has(skill_id)

## 解锁一个抽取技能；返回是否本次新解锁
func unlock_skill(skill_id: String) -> bool:
	if skill_id == "" or GameData.get_skill(skill_id).is_empty():
		return false
	if skill_unlocked(skill_id):
		return false
	unlocked_skills.append(skill_id)
	Events.meta_skill_unlocked.emit(skill_id)
	Events.meta_changed.emit()
	save()
	return true

## 当前可用技能（通用 + 已抽取），可按类型过滤（"active" / "passive" / ""）
func owned_skills(type: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in GameData.skills_by_unlock("", type):
		if skill_unlocked(str(s.get("id", ""))):
			out.append(s)
	return out

## 尚未解锁、需要抽取的技能
func locked_skills(type: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in GameData.skills:
		if type != "" and str(s.get("type", "")) != type:
			continue
		if not skill_unlocked(str(s.get("id", ""))):
			out.append(s)
	return out

func owned_skill_count() -> int:
	return owned_skills().size()

func total_skill_count() -> int:
	return GameData.skills.size()

## 能否把技能装入槽位（未解锁的技能不允许装配）
func can_set_unit_skill(skill_id: String) -> bool:
	return skill_id == "" or skill_unlocked(skill_id)

## 有效装配：过滤掉未解锁的技能（即便被写进存档也不生效）
func unit_effective_loadout(unit_id: String) -> Dictionary:
	var lo: Dictionary = unit_loadout(unit_id).duplicate(true)
	var act: Array = lo.get("active", [])
	var out: Array = []
	for s in act:
		var sid := str(s)
		out.append(sid if skill_unlocked(sid) else "")
	lo["active"] = out
	if not skill_unlocked(str(lo.get("passive", ""))):
		lo["passive"] = ""
	return lo

# --- 技能抽取 ---

func skill_draw_rules() -> Dictionary:
	return GameData.skill_draw_rules()

func skill_draw_name() -> String:
	return str(skill_draw_rules().get("name", "技能抽取"))

func skill_draw_cost() -> float:
	return float(skill_draw_rules().get("cost", 0))

func skill_draw_currency() -> String:
	return str(skill_draw_rules().get("currency", "credits"))

func skill_draw_candidates() -> Array[Dictionary]:
	var allowed: Array = skill_draw_rules().universal_cards
	return GameData.skills_by_unlock("gacha").filter(func(card): return not card.get("allowed_units",[]).is_empty() or card.id in allowed)

func skill_draw_enabled() -> bool:
	return skill_draw_rules().get("enabled", false) and not skill_draw_candidates().is_empty()

func can_draw_skill() -> bool:
	return skill_draw_enabled() and (balance(skill_draw_currency()) >= skill_draw_cost() or int(academy.get("tickets", 0)) > 0)

func draw_skill() -> String:
	var rewards := Academy.draw(self, 1)
	return str(rewards[0].id) if not rewards.is_empty() else ""

# ------------------------------------------------------------------ 货币

func balance(cur: String) -> float:
	return float(currency.get(cur, 0.0))

func grant(cur: String, amount: float) -> void:
	currency[cur] = balance(cur) + amount
	Events.meta_changed.emit()

func spend(cur: String, amount: float) -> bool:
	if balance(cur) < amount:
		return false
	currency[cur] = balance(cur) - amount
	Events.meta_changed.emit()
	return true

func currency_name(cur: String) -> String:
	var defs: Dictionary = GameData.meta_config.get("currencies", {})
	return str(defs.get(cur, {}).get("name", cur))

# ------------------------------------------------------------------ 挂机收益

## 当前档位的每小时收益（含后勤网络加成）
func hourly_rate() -> Dictionary:
	var tier := current_tier_data()
	var inc: Dictionary = tier.get("income_per_hour", {})
	var b := stat_bonuses()
	var mult := float(b.get("income_bonus", 1.0))
	return {
		"credits": float(inc.get("credits", 0)) * mult,
		"cores": float(inc.get("cores", 0)) * mult
	}

## 离线结算硬上限（小时）：数据单源 = meta.json 的 idle.offline_cap_hours
func offline_hard_cap() -> float:
	var idle_cfg: Dictionary = GameData.meta_config.get("idle", {})
	return float(idle_cfg.get("offline_cap_hours", DEFAULT_OFFLINE_HOURS))

## 挂机累积上限（小时）
func cap_hours() -> float:
	var tier := current_tier_data()
	var b := stat_bonuses()
	return float(tier.get("cap_hours", 6)) + float(b.get("cap_bonus", 1.0)) - 1.0

## 距离上次结算经过的秒数（已按上限截断）
func elapsed_seconds() -> float:
	var last := float(idle.get("last_tick_unix", _now()))
	var secs: float = max(0.0, _now() - last)
	var cap: float = min(cap_hours(), offline_hard_cap()) * 3600.0
	return min(secs, cap)

## 结算挂机收益：把经过时间的产出累加到 pending
func accrue_idle() -> Dictionary:
	var secs := elapsed_seconds()
	var rate := hourly_rate()
	var earned := {
		"credits": rate["credits"] / 3600.0 * secs,
		"cores": rate["cores"] / 3600.0 * secs
	}
	idle["pending_seconds"] = _banked_seconds(rate) + secs
	idle["last_tick_unix"] = _now()
	var pending: Dictionary = idle.get("pending", { "credits": 0.0, "cores": 0.0 })
	pending["credits"] = float(pending.get("credits", 0.0)) + float(earned["credits"])
	pending["cores"] = float(pending.get("cores", 0.0)) + float(earned["cores"])
	idle["pending"] = pending
	return earned

## 当前可领取的挂机收益
func pending_rewards() -> Dictionary:
	var p: Dictionary = idle.get("pending", { "credits": 0.0, "cores": 0.0 })
	return { "credits": float(p.get("credits", 0.0)), "cores": float(p.get("cores", 0.0)) }

func claim_idle() -> Dictionary:
	accrue_idle()
	var rewards := pending_rewards()
	grant("credits", rewards["credits"])
	grant("cores", rewards["cores"])
	idle["pending"] = { "credits": 0.0, "cores": 0.0 }
	idle["pending_seconds"] = 0.0
	save()
	Events.idle_income_claimed.emit(rewards)
	return rewards

func _banked_seconds(rate: Dictionary) -> float:
	if idle.has("pending_seconds"): return float(idle.pending_seconds)
	# Older saves only stored rewards. Estimate their duration once at the current rate.
	var pending := pending_rewards()
	for key in ["credits", "cores"]:
		if rate[key] > 0.0 and pending[key] > 0.0:
			return float(pending[key]) * 3600.0 / float(rate[key])
	return 0.0

func pending_hours() -> float:
	return (_banked_seconds(hourly_rate()) + elapsed_seconds()) / 3600.0

# ------------------------------------------------------------------ 战斗结算

func apply_battle_result(result: Dictionary, persist:=true) -> Dictionary:
	var match_id := str(result.get("match_id", ""))
	if not match_id.is_empty() and settled_matches.has(match_id):
		return {"credits": 0.0, "cores": 0.0, "already_settled": true}
	if not match_id.is_empty(): settled_matches[match_id] = true
	## result: { win: bool, kills: int, waves: int, endless: bool }
	var cfg: Dictionary = GameData.meta_config.get("idle", {}).get("settlement", {})
	var credits := 0.0
	var cores := 0.0
	var win := bool(result.get("win", false))
	if win:
		credits += float(cfg.get("win_credits", 0))
		cores += float(cfg.get("win_cores", 0))
	else:
		credits += float(cfg.get("lose_credits", 0))
		cores += float(cfg.get("lose_cores", 0))
	credits += float(cfg.get("per_kill_credits", 0)) * float(result.get("kills", 0))
	var waves := int(result.get("waves", 0))
	credits += float(cfg.get("wave_credits", 0)) * waves
	cores += float(cfg.get("wave_cores", 0)) * waves
	var adjustment: Dictionary = result.get("alliance_reward", {})
	if win and not adjustment.is_empty():
		var multiplier := float(adjustment.percent) / 100.0
		credits = roundf(credits * multiplier)
		cores = roundf(cores * multiplier)
	if persist:
		grant("credits", credits)
		grant("cores", cores)
	else:
		currency.credits=balance("credits")+credits
		currency.cores=balance("cores")+cores
	stats["battles"] = int(stats.get("battles", 0)) + 1
	if win:
		stats["battles_won"] = int(stats.get("battles_won", 0)) + 1
	if persist:save()
	return { "credits": credits, "cores": cores }

# ------------------------------------------------------------------ 存档

static func system_login(platform:String=OS.get_name()) -> String:
	match platform:
		"Windows":return OS.get_environment("USERNAME").strip_edges()
		"macOS":
			var login:=OS.get_environment("USER").strip_edges()
			return OS.get_environment("LOGNAME").strip_edges() if login.is_empty() else login
	return ""

func commander_name() -> String:
	return system_login() if commander_alias.is_empty() else commander_alias

func set_commander_alias(value:String) -> bool:
	var previous:=commander_alias
	commander_alias=value.strip_edges()
	if previous==commander_alias:return true
	if save():return true
	commander_alias=previous
	return false

func to_dict() -> Dictionary:
	return {
		"currency": currency,
		"academy_version": 4,
		"academy": academy,
		"current_tier": current_tier,
		"unlocked_tiers": unlocked_tiers,
		"upgrade_levels": upgrade_levels,
		"unit_levels": unit_levels,
		"production_recipes": production_recipes,
		"recipe_defaults": recipe_defaults,
		"unit_loadouts": unit_loadouts,
		"unit_talents": unit_talents,
		"owned_talent_points": owned_talent_points,
		"talent_slots": talent_slots,
		"disabled_effects": disabled_effects,
		"unlocked_skills": unlocked_skills,
		"unlocked_technologies": unlocked_technologies,
		"idle": idle,
		"stats": stats,
		"settled_matches": settled_matches,
		"contact_archive": contact_archive,
		"contact_transcripts": contact_transcripts,
		"driver_portraits": driver_portraits,
		"hero_story_archive": hero_story_archive,
		"yuriko_school": yuriko_school,
		"commander_alias": commander_alias,
		"house_color": house_color,
		"unit_cosmetics": unit_cosmetics,
		"attachment_positions": attachment_positions,
		"owned_cosmetics": owned_cosmetics,
		"edge_scroll": edge_scroll,
		"scroll_speed": scroll_speed,
		"subtitles": subtitles,
		"model_smoothing": model_smoothing
	}

## (B2) 设置：边缘滚屏开关 / 速度 / 字幕，改后即落盘。
func set_edge_scroll(on: bool) -> void:
	edge_scroll = on
	camera_settings_changed.emit()
	save()

func set_scroll_speed(v: int, persist := true) -> void:
	scroll_speed = clampi(v, 10, 100)
	camera_settings_changed.emit()
	if persist: save()

## Register only battle actors; changing this never replaces their team/effect material.
func register_model_display(actor: CanvasItem) -> void:
	actor.add_to_group("model_display")
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if model_smoothing else CanvasItem.TEXTURE_FILTER_NEAREST

func _refresh_model_display() -> void:
	var filtering := CanvasItem.TEXTURE_FILTER_LINEAR if model_smoothing else CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().set_group("model_display", "texture_filter", filtering)
	model_smoothing_changed.emit(model_smoothing)

func set_model_smoothing(on: bool) -> void:
	model_smoothing = on
	_refresh_model_display()
	save()

func set_subtitles(on: bool) -> void:
	subtitles = on
	save()

## (B2) 当前边缘滚屏速度（像素/秒）：设置 50 对应 1170 屏幕像素/秒。
func scroll_px_per_sec() -> float:
	return SCROLL_BASE * (float(scroll_speed) / 50.0)

## 设置玩家涂装（色板 id）并落盘。由 HouseColor.set_player() / 涂装页调用。
func attachment_position(id:String, slot:String) -> Vector3i:
	var slots = attachment_positions.get(id)
	var axes = slots.get(slot) if slots is Dictionary else null
	if axes is Dictionary: axes=axes.get("offset")
	if not axes is Array or axes.size()!=3: return Vector3i.ZERO
	var result := Vector3i.ZERO
	for i in 3:
		if typeof(axes[i]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(axes[i])): return Vector3i.ZERO
		result[i] = clampi(roundi(axes[i]),-Cosmetics.Styles.SHIFT_LIMIT,Cosmetics.Styles.SHIFT_LIMIT)
	return result

func attachment_pose(id:String, slot:String) -> Dictionary:
	var slots=attachment_positions.get(id)
	var row=slots.get(slot) if slots is Dictionary else null
	var part:String=str(row.get("part","")) if row is Dictionary else ""
	if not Cosmetics.Styles.PARTS.get(id,{}).has(part): part=""
	var pitch_value=row.get("pitch",0) if row is Dictionary else 0
	var pitch:=clampi(int(pitch_value),-180,180) if typeof(pitch_value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(pitch_value)) else 0
	return {"part":part,"pitch":pitch}

func attachment_rotation(id:String,slot:String) -> Vector3i:
	var slots=attachment_positions.get(id)
	var row=slots.get(slot) if slots is Dictionary else null
	var result:=Vector3i(0,0,attachment_pose(id,slot).pitch)
	if row is Dictionary:
		for i in 2:
			var value=row.get(["roll","yaw"][i],0)
			if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)):result[i]=clampi(roundi(value),-180,180)
	return result

## Percentages are separate so uniform resizing preserves the authored aspect ratio.
func attachment_size(id:String, slot:String) -> Dictionary:
	var slots=attachment_positions.get(id)
	var row=slots.get(slot) if slots is Dictionary else null
	var size_percent:=100
	var stretch:=Vector3i.ONE*100
	if row is Dictionary:
		size_percent=_attachment_percent(row.get("size",100))
		var axes=row.get("stretch")
		if axes is Array and axes.size()==3:
			for i in 3: stretch[i]=_attachment_percent(axes[i])
	return {"size":size_percent,"stretch":stretch}

func _attachment_percent(value:Variant) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return 100
	return clampi(roundi(value),Cosmetics.Styles.SIZE_MIN,Cosmetics.Styles.SIZE_MAX)

func attachment_scale(id:String,slot:String) -> Vector3:
	var dimensions:=attachment_size(id,slot)
	return Vector3(dimensions.stretch)*float(dimensions.size)/10000.0

func set_attachment_position(id:String, slot:String, offset:Vector3i) -> bool:
	var pose:=attachment_pose(id,slot)
	var dimensions:=attachment_size(id,slot)
	var angles:=attachment_rotation(id,slot)
	return save_attachment(id,slot,offset,pose.part,pose.pitch,dimensions.size,dimensions.stretch,angles.x,angles.y)

func save_attachment(id:String, slot:String, offset:Vector3i, part:String, pitch:int, size_percent:=100, stretch:=Vector3i(100,100,100), roll:=0, yaw:=0) -> bool:
	if slot not in Cosmetics.Styles.MOUNT_SLOTS or not Cosmetics.Styles.is_ra3(GameData.get_unit(id)): return false
	var limit := Vector3i.ONE * Cosmetics.Styles.SHIFT_LIMIT
	if offset != offset.clamp(-limit,limit) or absi(pitch)>180 or absi(roll)>180 or absi(yaw)>180: return false
	if not part.is_empty() and not Cosmetics.Styles.PARTS.get(id,{}).has(part): return false
	if size_percent<Cosmetics.Styles.SIZE_MIN or size_percent>Cosmetics.Styles.SIZE_MAX:return false
	for axis in 3:
		if stretch[axis]<Cosmetics.Styles.SIZE_MIN or stretch[axis]>Cosmetics.Styles.SIZE_MAX:return false
	if attachment_position(id,slot)==offset and attachment_pose(id,slot)=={"part":part,"pitch":pitch} and attachment_rotation(id,slot)==Vector3i(roll,yaw,pitch) and attachment_size(id,slot)=={"size":size_percent,"stretch":stretch}: return true
	var funds:=balance("credits")
	if funds<Cosmetics.Styles.ADJUST_COST: return false
	var previous = attachment_positions.get(id)
	var slots: Dictionary = previous.duplicate() if previous is Dictionary else {}
	if offset==Vector3i.ZERO and part.is_empty() and pitch==0 and roll==0 and yaw==0 and size_percent==100 and stretch==Vector3i(100,100,100): slots.erase(slot)
	else: slots[slot]={"offset":[offset.x,offset.y,offset.z],"part":part,"pitch":pitch,"roll":roll,"yaw":yaw,"size":size_percent,"stretch":[stretch.x,stretch.y,stretch.z]}
	if slots.is_empty(): attachment_positions.erase(id)
	else: attachment_positions[id]=slots
	currency.credits=funds-Cosmetics.Styles.ADJUST_COST
	if save():
		Events.meta_changed.emit()
		return true
	currency.credits=funds
	if previous==null: attachment_positions.erase(id)
	else: attachment_positions[id]=previous
	return false

func cosmetic_style(id:String) -> Dictionary:
	var style = unit_cosmetics.get(id)
	return style if style is Dictionary else {}

func appearance_wins() -> int:
	return int(stats.get("appearance_wins",0))

func grant_win_milestones() -> PackedStringArray:
	var granted:=PackedStringArray()
	var rewards:Dictionary=GameData.meta_config.get("cosmetic_win_rewards",{})
	for value:String in rewards:
		if appearance_wins()>=int(rewards[value]) and not cosmetic_owned(value):
			owned_cosmetics[value]=true
			granted.append(value)
	return granted

func researched_count() -> int:
	var total:=0
	for id in unlocked_technologies:
		if ProductionTechnology.NODES.has(id):total+=1
	return total

func grant_research_cosmetics() -> PackedStringArray:
	var granted:=PackedStringArray()
	var count:=researched_count()
	var rewards:Dictionary=GameData.meta_config.get("cosmetic_research_rewards",{})
	for value:String in rewards:
		if count>=int(rewards[value]) and not cosmetic_owned(value):
			owned_cosmetics[value]=true
			granted.append(value)
	return granted

func cosmetic_owned(value:String) -> bool:
	return Cosmetics.owned(owned_cosmetics,value)

func buy_cosmetic(id:String,slot:String,value:String) -> bool:
	if not Cosmetics.available(id,slot,value) or cosmetic_owned(value) or Cosmetics.victory_tier(value)>0 or Cosmetics.win_reward_only(id,value):return false
	var cost:=Cosmetics.price(slot)
	var previous:=balance("diamonds")
	var use_ticket := slot in ["skin", "weapon_fx"] and int(academy.get("skin_ticket", 0)) > 0
	if cost <= 0 or (not use_ticket and previous < cost): return false
	if use_ticket: academy.skin_ticket -= 1
	else: currency.diamonds = previous - cost
	owned_cosmetics[value]=true
	var previous_style:=cosmetic_style(id)
	var equipped:=previous_style.duplicate()
	equipped[slot]=value
	unit_cosmetics[id]=equipped
	if not save():
		currency.diamonds=previous
		if use_ticket: academy.skin_ticket += 1
		owned_cosmetics.erase(value)
		if previous_style.is_empty():unit_cosmetics.erase(id)
		else:unit_cosmetics[id]=previous_style
		return false
	Events.meta_changed.emit()
	return true

func award_victory_skins(difficulty:int,persist:=true) -> PackedStringArray:
	var granted:=PackedStringArray()
	for value:String in Cosmetics.VICTORY_SKINS:
		if difficulty>=int(Cosmetics.VICTORY_SKINS[value]) and not cosmetic_owned(value):
			owned_cosmetics[value]=true
			granted.append(value)
	if persist and not granted.is_empty():
		if not save():
			for value in granted:owned_cosmetics.erase(value)
			return PackedStringArray()
		Events.meta_changed.emit()
	return granted

func set_cosmetic(id:String,slot:String,value:String) -> bool:
	if not cosmetic_owned(value) or not Cosmetics.available(id,slot,value):return false
	var style:=cosmetic_style(id).duplicate()
	var previous:=cosmetic_style(id)
	if value=="stock":style.erase(slot)
	else:style[slot]=value
	if style.is_empty():unit_cosmetics.erase(id)
	else:unit_cosmetics[id]=style
	if save():return true
	if previous.is_empty():unit_cosmetics.erase(id)
	else:unit_cosmetics[id]=previous
	return false

func set_house_color(id: String) -> void:
	house_color = id
	save()


func save() -> bool:
	# Write then replace: a failed technology purchase must leave the previous
	# progression file intact. Other existing save callers may ignore the result.
	var temporary := SAVE_PATH + ".tmp"
	var f := FileAccess.open(temporary, FileAccess.WRITE)
	if f == null:
		push_warning("MetaProgress: 无法写入存档")
		return false
	f.store_string(JSON.stringify(to_dict(), "  "))
	f.flush()
	var error := f.get_error()
	f.close()
	if error != OK: return false
	return DirAccess.rename_absolute(temporary, SAVE_PATH) == OK

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	currency = parsed.get("currency", currency)
	academy = parsed.get("academy", {})
	current_tier = str(parsed.get("current_tier", "t0"))
	var ut: Array = parsed.get("unlocked_tiers", ["t0"])
	unlocked_tiers.clear()
	for t in ut:
		unlocked_tiers.append(str(t))
	upgrade_levels = parsed.get("upgrade_levels", {})
	unit_levels = parsed.get("unit_levels", {})
	recipe_defaults = parsed.get("recipe_defaults", {}) if parsed.get("recipe_defaults") is Dictionary else {}
	production_recipes = parsed.get("production_recipes", {}) if parsed.get("production_recipes") is Dictionary else {}
	unit_loadouts = parsed.get("unit_loadouts", {})
	unit_talents = parsed.get("unit_talents", {})
	# The former fourth radiation tier is now tier three. Preserve its paid benefit.
	var merged_radiation_rank:=false
	var deso_talents=unit_talents.get("DESO")
	if deso_talents is Dictionary and int(deso_talents.get("deso_expansion",0))>3:
		deso_talents.deso_expansion=3
		merged_radiation_rank=true
	disabled_effects = parsed.disabled_effects if parsed.get("disabled_effects") is Dictionary else {}
	var us: Array = parsed.get("unlocked_skills", [])
	unlocked_skills.clear()
	for sid in us:
		unlocked_skills.append(str(sid))
	if int(parsed.get("academy_version", 0)) == 0:
		var retired := {}
		for card in GameData.skills_by_unlock("gacha"):
			retired[str(card.id)] = true
		unlocked_skills.assign(unlocked_skills.filter(func(id): return not retired.has(id)))
		for uid in unit_loadouts:
			var lo := unit_loadout(uid).duplicate(true)
			for i in lo.active.size():
				if retired.has(lo.active[i]): lo.active[i] = ""
			if retired.has(lo.passive): lo.passive = ""
			unit_loadouts[uid] = lo
	unlocked_technologies.clear()
	var technologies = parsed.get("unlocked_technologies", [])
	if technologies is Array:
		for id in technologies:
			if id is String and not id.is_empty() and not unlocked_technologies.has(id):
				unlocked_technologies.append(id)
	idle = parsed.get("idle", {})
	stats = parsed.get("stats", {})
	contact_archive = parsed.get("contact_archive", {})
	contact_transcripts = parsed.get("contact_transcripts", {})
	driver_portraits = parsed.get("driver_portraits", {})
	hero_story_archive = parsed.get("hero_story_archive", {})
	yuriko_school = parsed.get("yuriko_school", {})
	var alias_value:Variant=parsed.get("commander_alias","")
	commander_alias=alias_value.strip_edges() if alias_value is String else ""
	if int(parsed.get("academy_version", 0)) == 0:
		var totals := {}
		for faction in stats.get("player_production", {}).get("factions", {}).values():
			for id in Academy.HEROES:
				totals[id] = int(totals.get(id,0)) + int(faction.get("unit",{}).get(id,{}).get("built",0))
		academy.hero_builds = totals
	for id in ["MTNK","HTNK"]:
		var builds:Dictionary=academy.get_or_add("hero_builds",{})
		if not builds.has(id):
			var total:=0
			for faction in stats.get("player_production",{}).get("factions",{}).values():
				total+=int(faction.get("unit",{}).get(id,{}).get("built",0))
			builds[id]=total
	settled_matches = parsed.get("settled_matches", {})
	owned_cosmetics = parsed.owned_cosmetics if parsed.get("owned_cosmetics") is Dictionary else {}
	if not stats.has("appearance_wins"):stats.appearance_wins=maxi(0,int(stats.get("battles_won",0)))
	grant_win_milestones()
	grant_research_cosmetics()
	attachment_positions = parsed.attachment_positions if parsed.get("attachment_positions") is Dictionary else {}
	unit_cosmetics = parsed.unit_cosmetics if parsed.get("unit_cosmetics") is Dictionary else {}
	# Legacy free selections are not proof of a purchase or a difficulty win.
	for id in unit_cosmetics.keys():
		if unit_cosmetics[id] is Dictionary:
			var style:Dictionary=unit_cosmetics[id]
			for slot in style.keys():
				if not style[slot] is String or not cosmetic_owned(style[slot]):style.erase(slot)
			if not style.has("paint"):
				for old_slot in ["body", "weapon"]:
					var dye: String = style.get(old_slot, "stock")
					if dye != "stock" and Cosmetics.available(id, "paint", dye):
						style.paint = dye
						break
			style.erase("body")
			style.erase("weapon")
			if style.has("track") and not Cosmetics.available(id,"track",style.track): style.erase("track")
			# Owned attachments take priority over badges from the old two-slot layout.
			if not style.has("top"):
				var ornament=style.get("ornament")
				var decal=style.get("decal")
				if ornament in ["beacon","crystal"]:style.top=ornament
				elif decal in ["star","diamond"]:style.top=decal
			style.erase("ornament")
			style.erase("decal")
			if style.has("top") and not Cosmetics.available(id,"top",style.top):style.erase("top")
			if style.get("tail") == "amber_tail": style.erase("tail")
			if not style.is_empty():continue
		unit_cosmetics.erase(id)
	house_color = str(parsed.get("house_color", "allied"))
	edge_scroll = (parsed.get("edge_scroll", true) == true)
	scroll_speed = clampi(int(parsed.get("scroll_speed", 50)), 10, 100)
	subtitles = (parsed.get("subtitles", true) == true)
	model_smoothing = (parsed.get("model_smoothing", true) == true)
	_refresh_model_display()
	HouseColor.set_player_id(house_color)

	# Convert the paid technology into its selected talent on the same save
	# as the refund. Re-loading the old file starts from its original balance.
	var migrated_research:=unlocked_technologies.has("reaper_fire_control")
	if migrated_research:
		unlocked_technologies.erase("reaper_fire_control")
		unit_talents["R3REAPER"]="reaper_fire_control"
		currency["credits"]=balance("credits")+1200.0
	talent_slots = parsed.talent_slots if parsed.get("talent_slots") is Dictionary else {}
	# Old profiles had free capacity. Preserve exactly the slots already in use.
	for id in unit_talents:
		var used:=mini(available_talent_slots(id),selected_talents(id,unit_talents).size())
		if talent_capacity(id)<used:talent_slots[id]=used
	var owned_points := int(parsed.get("owned_talent_points",0))
	if int(parsed.get("academy_version",0)) < 3:
		# Before direct core upgrades, the lifetime wallet included points spent on ranks.
		for unit_id in unit_talents:
			for talent in selected_talents(unit_id,unit_talents):
				if talent=="reaper_split_fire" and unit_talents[unit_id] is Dictionary:
					owned_points-=clampi(int(unit_talents[unit_id][talent]),0,3)
				else:owned_points -= talent_rank(unit_id,talent,unit_talents)
	owned_talent_points = maxi(owned_points,redeemed_points_in_use())
	if int(parsed.get("academy_version", 0)) == 1: Academy.migrate_card_ranks(self)
	var folded_points := academy.has("strategy_points")
	if folded_points:
		currency.cores=balance("cores")+maxi(0,int(academy.strategy_points))
		academy.erase("strategy_points")
	var migrated_tier := _restore_highest_tier()
	var migrate_affinity:=int(parsed.get("academy_version",0))<4
	if migrate_affinity: Academy.migrate_affinity_rewards(self)
	var retired_sample:=_retire_radiation_sample()
	var migrated_native:=preload("res://scripts/rules/native_talent_migration.gd").apply(self)
	var migrated_bunker:=preload("res://scripts/rules/bunker_talent.gd").migrate(self)
	var migrated_commissions:=preload("res://scripts/rules/field_commission.gd").migrate_loadouts(unit_loadouts)
	var migrated_heroes:=preload("res://scripts/rules/hero_loadouts.gd").migrate(self)
	var migrated_q:=UnitSkillLayout.migrate_card_primaries(self)
	var migrated_gifts := preload("res://scripts/expedition/commander_keepsakes.gd").migrate_cycles(self)
	if migrated_gifts or folded_points or migrated_tier or migrated_research or migrate_affinity or merged_radiation_rank or retired_sample or migrated_native or migrated_bunker or migrated_commissions or migrated_heroes or migrated_q: save()

func _retire_radiation_sample() -> bool:
	const ID := "deso_sample"
	if ID not in selected_talents("DESO",unit_talents): return false
	var previous=unit_talents.DESO
	var rank:=clampi(int(previous.get(ID,0)),0,3) if previous is Dictionary else 0
	var remaining:Dictionary={}
	for id in selected_talents("DESO",unit_talents):
		if id!=ID: remaining[id]=int(previous.get(id,0)) if previous is Dictionary else 0
	if remaining.is_empty():unit_talents.erase("DESO")
	else:unit_talents.DESO=remaining
	# Removal frees one allocated point; lifetime points and purchased slots stay intact.
	currency.cores=balance("cores")+int([0,40,160,400][rank])
	disabled_effects.erase("talent/DESO/"+ID)
	return true

func reset_save() -> void:
	contact_archive.clear()
	contact_transcripts.clear()
	driver_portraits.clear()
	hero_story_archive.clear()
	yuriko_school.clear()
	commander_alias=""
	academy = {"bunker_optics_four_ranks":true,"native_q_cards_removed":true}
	settled_matches.clear()
	currency = { "credits": 0.0, "cores": 0.0 }
	current_tier = "t0"
	unlocked_tiers = ["t0"]
	upgrade_levels = {}
	unit_levels = {}
	production_recipes = {}
	recipe_defaults = {}
	unit_loadouts = {}
	preload("res://scripts/rules/hero_loadouts.gd").migrate(self)
	disabled_effects = {}
	unit_talents = {}
	talent_slots = {}
	owned_talent_points = 0
	unlocked_skills = []
	unlocked_technologies = []
	idle = { "last_tick_unix": _now(), "pending": { "credits": 0.0, "cores": 0.0 } }
	stats = {"appearance_wins":0}
	unit_cosmetics.clear()
	attachment_positions.clear()
	owned_cosmetics.clear()
	house_color = "allied"
	edge_scroll = true
	scroll_speed = 50
	subtitles = true
	model_smoothing = true
	_refresh_model_display()
	HouseColor.set_player_id(house_color)
	save()
	Events.meta_changed.emit()
