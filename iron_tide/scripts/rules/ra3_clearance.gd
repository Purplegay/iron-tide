class_name Ra3Clearance
extends RefCounted
## Uprising Upgrade_AlliedTech2/3 and AlliedConstructionYard TechUpgrade.
## Match-local object upgrades; special is included in the existing save schema.
const KEY := "ra3_clearance"
const RADIUS := 600.0 * 1.5
const FACTORIES := ["GAPILE", "GAWEAP", "GAAIRC", "GAYARD"]
const TIERS := {2: {"name": "高级许可", "cost": 1500.0, "seconds": 15.0},
	3: {"name": "最高许可", "cost": 3000.0, "seconds": 60.0}}

static func state(base) -> Dictionary:
	return base.special.get(KEY, {"tier": 1, "target": 0, "elapsed": 0.0, "paid": 0.0, "paused": false})

static func level(factory) -> int:
	if factory == null or factory.battle == null: return 1
	if factory.building_id == "GACNST": return int(state(factory).tier)
	if not factory.building_id in FACTORIES: return 1
	var result := 1
	for base in factory.battle.buildings:
		if not is_instance_valid(base) or base.side != factory.side or base.building_id != "GACNST" or not base.is_operational(): continue
		var offset: Vector2 = factory.global_position - base.global_position
		# SDK RECTANGULAR projection, in world/map coordinates rather than screen pixels.
		if absf(offset.x) <= RADIUS and absf(offset.y) <= RADIUS:
			result = maxi(result, int(state(base).tier))
	return result

static func block_reason(factory, uid: String) -> String:
	var required := int(GameData.get_unit(uid).get("ra3_clearance", 0))
	if required > 0 and required > level(factory): return "RA3 前置：附近基地需" + str(TIERS[required].name)
	return ""

static func start_reason(base) -> String:
	if not is_instance_valid(base) or base.building_id != "GACNST" or base.battle == null or not base.is_operational(): return "基地尚未就绪"
	if base.battle.paused or base.battle.ended: return "战斗暂停或已结束"
	var current := state(base)
	if int(current.target) != 0: return "许可升级进行中"
	if int(current.tier) >= 3: return "已获得最高许可"
	if int(current.tier) == 1 and not base.battle.owned_building_ids(base.side).has("GAREFN"): return "需要盟军矿石精炼场"
	return ""

static func start(base) -> bool:
	if not start_reason(base).is_empty(): return false
	var current := state(base).duplicate(true)
	current.target = int(current.tier) + 1
	current.elapsed = 0.0
	current.paid = 0.0
	current.paused = false
	base.special[KEY] = current
	Events.production_queue_changed.emit()
	return true

static func right_click(base) -> void:
	var current := state(base).duplicate(true)
	if int(current.target) == 0: return
	if not current.paused:
		current.paused = true
	else:
		base.battle.credit_side(base.side, float(current.paid))
		current.target = 0
		current.paid = 0.0
		current.elapsed = 0.0
		current.paused = false
	base.special[KEY] = current
	Events.production_queue_changed.emit()

static func tick(base, delta: float) -> void:
	if base.building_id != "GACNST" or base.battle == null or base.battle.paused or base.battle.ended or not base.is_operational(): return
	var current := state(base)
	if int(current.target) == 0 or current.paused: return
	var rule: Dictionary = TIERS[int(current.target)]
	var step := minf(maxf(delta, 0.0), float(rule.seconds) - float(current.elapsed))
	var due := step * float(rule.cost) / float(rule.seconds)
	var paid := minf(due, maxf(0.0, base.battle.funds_for(base.side)))
	if base.side == "ally" and GM.infinite_funds: paid = due
	if paid <= 0.0 or not base.battle.spend_side(base.side, paid): return
	current.paid = float(current.paid) + paid
	current.elapsed = float(current.elapsed) + paid * float(rule.seconds) / float(rule.cost)
	if float(current.elapsed) >= float(rule.seconds) - 0.00001:
		current.tier = current.target
		current.target = 0
		Events.production_queue_changed.emit()
	base.special[KEY] = current
