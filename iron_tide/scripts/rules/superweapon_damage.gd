extends RefCounted
## Launch-time progression; both AI superweapons share the frozen per-house levels.
const ID := "superweapon_damage_1"
const AI_NUKE_LEVELS := [0, 1, 3, 5, 8, 12, 15]
const LEVELS := ["superweapon_damage_1", "superweapon_damage_2", "superweapon_damage_3", "superweapon_damage_4", "superweapon_damage_5", "superweapon_damage_6", "superweapon_damage_7", "superweapon_damage_8", "superweapon_damage_9", "superweapon_damage_10", "superweapon_damage_11", "superweapon_damage_12", "superweapon_damage_13", "superweapon_damage_14", "superweapon_damage_15", "superweapon_damage_16", "superweapon_damage_17", "superweapon_damage_18", "superweapon_damage_19", "superweapon_damage_20"]

static func percent(level: int) -> int:
	return 100 + 20 * clampi(level, 0, LEVELS.size())

static func new_match_ai_levels() -> Dictionary:
	var result := {}
	if not BattleRequest.skirmish or not BattleRequest.extensions_enabled(): return result
	result["enemy"] = AI_NUKE_LEVELS[BattleRequest.house_difficulty("enemy")]
	for side: String in BattleRequest.house_teams:
		if BattleRequest.is_ai_house(side):
			result[side] = AI_NUKE_LEVELS[BattleRequest.house_difficulty(side)]
	return result

static func nuke_multiplier(side: String) -> float:
	return multiplier(side)

static func ai_description() -> String:
	var rows := PackedStringArray()
	for i in AI_NUKE_LEVELS.size():
		rows.append("%s Lv.%d（%d%%）" % [GameData.DIFFICULTY_NAMES[i], AI_NUKE_LEVELS[i], percent(AI_NUKE_LEVELS[i])])
	return "AI 核弹和闪电风暴按各自难度强化：" + "、".join(rows) + "。敌方及友方 AI 均适用，独立于玩家研究及开关；影响核弹爆炸、辐射和每道闪电伤害。扩展对局使用本局已保存的强化等级；已发射效果保持发射时倍率。"

static func multiplier(side: String) -> float:
	if not BattleRequest.extensions_enabled(): return 1.0
	if side != "ally":
		var ai_level := int(BattleRequest.combat_context.get("ai_nuke_levels", {}).get(side, 0))
		return percent(ai_level) / 100.0
	var technologies: Array = BattleRequest.combat_context.get("technologies", [])
	var level := 0
	for id: String in LEVELS:
		if not technologies.has(id): break
		level += 1
	return percent(level) / 100.0
