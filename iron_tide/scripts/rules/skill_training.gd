extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Unit-specific progression, separate from Q card / equipped W / passive cards.
## A frozen version marker keeps old battles on their previous card scaling rules.
const PROFILES := {
	"E1": [["deploy_def", "卧倒防御系数", "up", "倍"]],
	"GGI": [["deploy_def", "部署防御系数", "up", "倍"]],
	"CLEG": [["chrono_time", "传送后恢复耗时", "down", "倍"]],
	"SCHP": [["siege_range", "部署后额外射程", "range", "格"]],
	"DESO": [["radiation", "部署辐射伤害加成", "radiation", "%"]],
	"IVAN": [["fuse", "炸弹引信", "fuse", "秒"]],
	"CIVAN": [["fuse", "炸弹引信", "fuse", "秒"]],
	"BORIS": [["arrival", "米格抵达等待系数", "down", "倍"]],
	"LCRF": [["unload", "逐个卸载间隔", "down", "秒"]],
	"SAPC": [["unload", "逐个卸载间隔", "down", "秒"]],
	"SHAD": [["unload", "逐个卸载间隔", "down", "秒"], ["altitude", "起降速度", "up", "倍"]],
	"AMCV": [["mcv", "展开／收起耗时", "down", "秒"]],
	"SMCV": [["mcv", "展开／收起耗时", "down", "秒"]],
	"DOG": [["attack_cd", "扑咬攻击间隔", "down", "秒"]],
	"SOV_DOG": [["attack_cd", "扑咬攻击间隔", "down", "秒"]],
	"SREF": [["prism", "分裂光束伤害系数", "up", "倍"]],
	"R3MIRAGE": [["field", "幻影场覆盖半径", "up", "像素"]],
	"R3FUTURE": [["riot", "暴乱光束冷却", "down", "秒"]],
	"R3APOC": [["drag", "鱼叉拖拽速度", "up", "像素/秒"]],
	"R3REAPER": [["leap", "跳跃落地伤害半径", "up", "像素"]],
	"R3TESLA": [["emp", "切换后磁场半径", "up", "像素"]]}

static func current_rules() -> bool:
	return BattleRequest.extensions_enabled() and int(BattleRequest.combat_context.get("native_training_version", 1 if BattleRequest.combat_context.is_empty() else 0)) >= 1

static func scale(actor) -> float:
	if not is_instance_valid(actor) or not current_rules() or not PROFILES.has(actor.unit_id): return 1.0
	if actor.unit_id in ["LCRF","SAPC","SHAD"]:return 1.0
	if int(BattleRequest.combat_context.get("native_training_version",4))>=4:
		var id:=talent_id(actor.unit_id)
		var rank:=effect_rank(actor)
		if rank<0:return 1.0
		return power_at(actor.unit_id,rank)
	return maxf(1.0, actor.skill_power)

static func talent_id(id:String) -> String:
	return "native_"+str(PROFILES[id][0][0]) if PROFILES.has(id) and id not in ["LCRF","SAPC","SHAD"] else ""

static func power_at(id:String,rank:int) -> float:
	var row:Dictionary=MetaProgress.talent_options(id).get(talent_id(id),{})
	return float(row.get("values",{}).get("power",[1.3,1.6,1.9,2.2])[clampi(rank,0,3)])

static func defense_at(id:String,rank:int) -> float:
	return float(MetaProgress.talent_options(id)[talent_id(id)].values.defense[clampi(rank,0,3)])

static func talent_description(id:String) -> String:
	var lines:=PackedStringArray()
	for rank in 4:
		var parts:=PackedStringArray()
		for spec in PROFILES.get(id,[]):
			parts.append(str(spec[1])+" "+String.num(projected(base_value(id,spec[0]),spec[2],power_at(id,rank)),2)+str(spec[3]))
		if id in ["AMCV","SMCV","DOG","SOV_DOG"]:parts.append(("车形态" if id in ["AMCV","SMCV"] else "正面120度")+"防御系数 +%d%%" % roundi(defense_at(id,rank)*100))
		lines.append("%d 级　%s" % [rank,"；".join(parts)])
	return "\n".join(lines)

static func defend(actor,damage:float,source) -> float:
	if actor.unit_id not in ["AMCV","SMCV","DOG","SOV_DOG"] or effect_rank(actor)<0:return damage
	if actor.unit_id in ["DOG","SOV_DOG"]:
		var gun=source.shooter() if is_instance_valid(source) and source is Projectile else source
		if not is_instance_valid(gun) or not gun is Node2D or gun.get("side")==actor.side or gun.get("side") not in ["ally","enemy"]:return damage
		var offset:Vector2=gun.global_position-actor.global_position
		if offset.is_zero_approx() or absf(angle_difference(actor.hull_angle,offset.angle()))>PI/3.0:return damage
	var rank:=effect_rank(actor)
	return damage/(1.0+defense_at(actor.unit_id,rank))

# Native talent ranks reuse the bounded scalar, capped at half duration.
# Existing native-v1 battle saves retain their frozen reciprocal scaling.
static func time_fraction(power: float) -> float:
	return 1.0 - P.number("mechanic/native_training","time_reduction_cap") * clampf((power - 1.0) / P.number("mechanic/native_training","power_span"), 0.0, 1.0)

static func timing_scale(actor) -> float:
	var power := scale(actor)
	var version := int(BattleRequest.combat_context.get("native_training_version", 2 if BattleRequest.combat_context.is_empty() else 0))
	return 1.0 / time_fraction(power) if version >= 2 else power

static func boris_arrival_scale(actor) -> float:
	var version := int(BattleRequest.combat_context.get("native_training_version",3 if BattleRequest.combat_context.is_empty() else 0))
	return timing_scale(actor) if version >= 3 else 1.0

static func boris_reload_scale(actor) -> float:
	var version := int(BattleRequest.combat_context.get("native_training_version",3 if BattleRequest.combat_context.is_empty() else 0))
	return timing_scale(actor) if version < 3 else 1.0

static func card_scale(actor) -> float:
	return 1.0 if current_rules() else actor.skill_power

static func siege_extra(actor) -> float:
	return minf(P.number("mechanic/native_training","siege_cap"), maxf(0.0, scale(actor) - 1.0) / P.number("mechanic/native_training","siege_scale"))

static func radiation_damage(actor) -> float:
	return 1.0 + projected(0.0,"radiation",scale(actor)) * 0.01

static func fuse(actor, base: float) -> float:
	return projected(base, "fuse", scale(actor)) if current_rules() else base

static func base_value(id: String, key: String) -> float:
	var unit := GameData.get_unit(id)
	match key:
		"deploy_def": return float(unit.get("deploy_defense_mult", 1.0))
		"fuse": return float(preload("res://scripts/core/yr_death_rules.gd").data().combat.ivantimeddelay) / 15.0
		"airstrike", "airstrike_elite":
			var row := preload("res://scripts/core/yr_death_rules.gd").type_data("BORIS")
			return float(row.eliteairstrikerechargetime if key == "airstrike_elite" else row.airstrikerechargetime) / 15.0
		"unload": return 0.35
		"mcv": return GameData.ra2_buildup_seconds()
		"attack_cd": return float(unit.get("weapon", {}).get("cooldown", 1.0))
		"field": return 262.5
		"riot": return preload("res://scripts/units/ra3_riot.gd").cooldown()
		"drag": return 60.0
		"leap", "emp": return 75.0
	return 1.0

static func projected(base: float, mode: String, power: float) -> float:
	match mode:
		"radiation": return clampf((power-1.0)*P.number("mechanic/native_training","radiation_per_power"),0.0,P.number("mechanic/native_training","radiation_cap"))
		"down": return base * time_fraction(power)
		"range": return minf(P.number("mechanic/native_training","siege_cap"), (power - 1.0) / P.number("mechanic/native_training","siege_scale"))
		"fuse": return lerpf(base, minf(base, P.number("mechanic/native_training","fuse_floor")), clampf((power - 1.0) / P.number("mechanic/native_training","power_span"), 0.0, 1.0))
	return base * power

static func benefits(meta, unit_id: String) -> Array:
	return [] # Retired purchase track; mechanisms now belong to exclusive talents.

static func legacy_benefits(meta, unit_id: String) -> Array:
	if not PROFILES.has(unit_id): return []
	var track: Dictionary = meta.get_unit_track("skill")
	var level: int = meta.unit_level(unit_id, "skill")
	var next: int = mini(level + 1, int(track.max_level))
	var per := float(track.effect_per_level)
	var changes: Array = []
	for spec in PROFILES[unit_id]:
		var base := base_value(unit_id, spec[0])
		changes.append({"key": spec[0], "label": spec[1], "before": projected(base, spec[2], 1.0+level*per), "after": projected(base, spec[2], 1.0+next*per), "unit": spec[3]})
	var note := "仅作用于本兵种机制，不强化 Q 卡牌、W 或装配被动。"
	if PROFILES[unit_id].any(func(spec): return spec[2] == "down"): note += " 冷却／耗时每级缩短 2.5%，最多缩短 50%。"
	if unit_id == "BORIS": note += " 按入场距离缩短米格抵达等待；不按建筑血量计算，不缩短离场后的再充能或返航时间。"
	if unit_id == "DESO": note += " 每级 +0.6%，20 级最多 +12%；直接作用于部署辐射，不再采样叠加。"
	if unit_id == "SREF": note += " 每条分裂光束伤害不超过本次主光束基础伤害，不逐跳重复叠乘。"
	if unit_id in ["IVAN", "CIVAN"]: note += " 每级缩短 0.75 秒，20 级达到 15 秒下限。"
	if unit_id == "SCHP": note += " 每级 +0.1 格，最多 +2 格；仅部署火炮生效。"
	return [{"id": unit_id, "slot": "兵种机制", "name": GameData.get_unit(unit_id).get("name",unit_id), "changes": changes, "note": note}]

static func description(rows: Array, maxed: bool) -> String:
	var lines := PackedStringArray()
	for row in rows:
		for change in row.changes:
			var text: String = change.label + "：" + String.num(change.before, 2)
			if not maxed: text += " → " + String.num(change.after, 2)
			lines.append(text + " " + change.unit)
		lines.append(row.note)
	return "\n".join(lines)

static func effect_rank(actor) -> int:
	var rank:=-1
	if BattleRequest.has_unit_talent(actor.unit_id,talent_id(actor.unit_id),actor.side):rank=MetaProgress.talent_rank(actor.unit_id,talent_id(actor.unit_id),BattleRequest.combat_context.get("unit_talents",{}))
	return rank
