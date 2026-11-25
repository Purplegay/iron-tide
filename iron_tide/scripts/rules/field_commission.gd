extends RefCounted
## Battle-local recruitment objectives. No permanent unlocks or live profile reads.
const SEAL := "ps_chrono_commission"
const IVAN := "ps_chrono_sabotage"
const PRODUCTS := {"CCOMAND": SEAL, "CIVAN": IVAN}
const STATE := "field_commissions"
const HIDDEN := ["PTROOP"]

static func product(card:String) -> String:
	return "CCOMAND" if card==SEAL else "CIVAN"

static func equipped(card:String) -> bool:
	var loadouts:Dictionary=BattleRequest.combat_context.get("loadouts",{})
	if str(loadouts.get(product(card),{}).get("passive",""))==card:return true
	# Existing battles retain their frozen legacy loadout, not the live profile.
	if int(BattleRequest.combat_context.get("field_commission_version",0))==1:
		return str(loadouts.get("GHOST" if card==SEAL else "IVAN",{}).get("passive",""))==card
	return false

static func migrate_loadouts(loadouts:Dictionary) -> bool:
	var changed:=false
	for pair in [["GHOST",SEAL],["IVAN",IVAN]]:
		var old:Dictionary=loadouts.get(pair[0],{})
		if str(old.get("passive",""))!=pair[1]:continue
		var next:Dictionary=loadouts.get(product(pair[1]),{}).duplicate(true)
		if str(next.get("passive","")) in ["",pair[1]]:
			next.passive=pair[1];loadouts[product(pair[1])]=next
		old.passive="";changed=true
	return changed

static func enabled() -> bool:
	return BattleRequest.extensions_enabled() and int(BattleRequest.combat_context.get("field_commission_version", 0)) >= 1

static func goal(card: String) -> int:
	var rank := clampi(int(BattleRequest.combat_context.get("card_ranks", {}).get(card, 0)), 0, 3)
	var thresholds: Array = GameData.get_skill(card).get("objective_by_rank", [])
	return int(thresholds[rank]) if thresholds.size() == 4 else 1

static func entry(state: Dictionary, side: String, card: String) -> Dictionary:
	return state.get(STATE, {}).get(side, {}).get(card, {})

static func count(state: Dictionary, side: String, card: String) -> int:
	return int(entry(state, side, card).get("count", 0))

static func completed(state: Dictionary, side: String, card: String) -> bool:
	return bool(entry(state, side, card).get("unlocked", false))

static func lab_ready(world, side: String) -> bool:
	return world != null and world.owned_building_ids(side).any(func(id): return GameData.supplies_prerequisite(str(id), "TECH"))

static func carrier(unit, card: String) -> bool:
	if not enabled() or not is_instance_valid(unit) or not unit is Unit: return false
	var required: String = "GHOST" if card == SEAL else "IVAN"
	return unit.side == "ally" and unit.unit_id == required and equipped(card)

static func hostile(target, side: String) -> bool:
	return is_instance_valid(target) and (target is Unit or target is Building) and BattleRequest.is_house(target.side) and not BattleRequest.friendly(target.side,side)

static func advance(world, side: String, card: String) -> void:
	if not enabled() or not is_instance_valid(world): return
	var sides: Dictionary = world.allied_state.get_or_add(STATE, {})
	var cards: Dictionary = sides.get_or_add(side, {})
	var progress: Dictionary = cards.get_or_add(card, {"count": 0, "unlocked": false})
	if progress.unlocked: return
	progress.count = mini(int(progress.count) + 1, goal(card))
	progress.unlocked = progress.count >= goal(card)
	if side == "ally":
		var label := str(GameData.get_skill(card).name)
		var result: String = "本局已解锁：" + GameData.get_unit("CCOMAND" if card == SEAL else "CIVAN").name if progress.unlocked else "%s：%d/%d" % [label, progress.count, goal(card)]
		Events.battle_message.emit(result, Color("#84e6bc"))

static func defeated(world, target, source) -> void:
	if not carrier(source, SEAL) or not hostile(target, source.side): return
	if target is Unit and AlliedAbilities.flag(target, "DontScore"): return
	if target.special.get("field_commission_counted", false): return
	# Called only by the actual death entry, not veteran/GM experience grants.
	target.special.field_commission_counted = true
	advance(world, source.side, SEAL)

static func stamp_bomb(unit, target, bomb: Dictionary) -> void:
	if not carrier(unit, IVAN) or not hostile(target, unit.side): return
	# Persist eligibility on the bomb, so the planter may die before detonation.
	bomb.field_commission = IVAN

static func detonated(world, target, bomb: Dictionary) -> void:
	if str(bomb.get("field_commission", "")) != IVAN: return
	var side := str(bomb.get("side", ""))
	if hostile(target, side): advance(world, side, IVAN)

static func production_reason(id: String, state: Dictionary, side: String) -> String:
	var card: String = PRODUCTS[id]
	if completed(state, side, card): return ""
	var label := str(GameData.get_skill(card).name)
	var action := "海豹击杀" if card == SEAL else "伊文装弹并引爆"
	return "在%s改造栏装配「%s」：%s %d/%d（本局累计，无需先造超时空单位或实验室）；或间谍窃取对应科技" % [GameData.get_unit(id).name,label, action, count(state, side, card), goal(card)]

static func progress_text(unit) -> String:
	var card := str(unit.passive.get("id", ""))
	if card not in [SEAL, IVAN] or not enabled(): return ""
	var world = unit._battle_world()
	if world == null: return ""
	if completed(world.allied_state, unit.side, card): return "本局已完成，生产已解锁；仍需保有作战实验室。"
	return "本局进度 %d/%d（无需先建实验室；任务解锁生产仍需实验室）" % [count(world.allied_state, unit.side, card), goal(card)]
