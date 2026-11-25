class_name CombatMath
extends RefCounted
const FinalDamage=preload("res://scripts/core/final_damage.gd")
## 战斗数学的唯一来源。所有伤害都要经过这里，方便平衡与调试。

## 克制倍率：攻击类型 × 护甲类型
static func multiplier(attack_type: String, armor_type: String) -> float:
	return GameData.armor_multiplier(attack_type, armor_type)

## 单发伤害（RA2 弹头 Verses 优先；否则回退旧克制表）
static func raw_damage(weapon, target_armor: String, target_ra2_armor: String = "") -> float:
	if weapon == null or weapon.is_empty():
		return 0.0
	var dmg := float(weapon.get("damage", 0.0))
	# RA2 规则路径：武器带真实弹头 -> 伤害 = damage × warhead.Verses[目标护甲类别]
	var wh := str(weapon.get("ra2_warhead", ""))
	if wh != "":
		var cls := target_ra2_armor if target_ra2_armor != "" else GameData.to_ra2_armor(target_armor)
		var v := GameData.ra2_verse(wh, cls)
		if v >= 0.0:
			return dmg * v
	# 回退：引擎自带单位 / 未知弹头 -> 旧克制表
	var at := str(weapon.get("attack_type", "bullet"))
	return dmg * multiplier(at, GameData.to_engine_armor(target_armor))

## 该武器能否攻击空中目标（RA2 用弹道 AA 标志；引擎自带单位回退旧克制表）
static func can_hit_air(weapon) -> bool:
	if weapon == null or weapon.is_empty():
		return false
	if weapon.has("ra2_aa"):
		return (weapon.get("ra2_aa", false) == true)
	var at := str(weapon.get("attack_type", "bullet"))
	return multiplier(at, "air") >= 0.6

## 局外攻击加成
## Growth only: skills, veterancy, weapon verses and target armor stay outside.
static func compress_growth(raw: float, cap: float = 0.0, threshold: float = 2.0) -> float:
	if cap <= threshold or raw <= threshold: return raw
	var span := cap - threshold
	var curve := log(1.0 + (raw - threshold) / span)
	return threshold + span * curve / (1.0 + curve)

static func begin_growth(bonuses: Dictionary, cap: float) -> void:
	if cap <= 2.0: return
	var raw := float(bonuses.get("attack_bonus", 1.0))
	bonuses.growth_attack_raw = raw
	bonuses.growth_attack_cap = cap
	bonuses.attack_bonus = compress_growth(raw, cap)

## Replace the previous compressed growth with the aggregate, preserving cards/buffs.
## Caller applies this ratio to its cached base attack, not every projectile/hit.
static func additional_growth_ratio(bonuses: Dictionary, factor: float) -> float:
	var cap := float(bonuses.get("growth_attack_cap", 0.0))
	if cap <= 2.0: return factor
	var old := float(bonuses.get("growth_attack_raw", 1.0))
	bonuses.growth_attack_raw = old * factor
	return compress_growth(old * factor, cap) / maxf(0.0001, compress_growth(old, cap))

static func with_offense(damage: float, bonuses: Dictionary) -> float:
	# 老兵 FIREPOWER 与常规攻击乘算（RA2：VeteranCombat ×）
	return damage * float(bonuses.get("attack_bonus", 1.0)) * float(bonuses.get("veteran_attack", 1.0))

## 老兵 ROF 修正后的冷却（RA2 VetROF=0.6 → 射速更快）
static func veteran_cooldown(base: float, bonuses: Dictionary) -> float:
	return max(0.05, base * float(bonuses.get("veteran_rof", 1.0)))

## 局外防御加成（作为除数，越高受伤越少）
static func with_defense(damage: float, bonuses: Dictionary) -> float:
	return damage / maxf(0.05, float(bonuses.get("defense_bonus", 1.0))) \
		/ maxf(0.05, float(bonuses.get("veteran_defense", 1.0)))

## 完整伤害预估（AI/UI）；发射/投射物传 null 防御，实际防御只在 receive_hit 扣一次。
## dist_px：弹着点到目标中心的距离（格 = PX_PER_CELL）。>0 时按 RA2 CellSpread/PercentAtMax 衰减。
## target：目标节点，用于 ProneDamage（卧倒减免）判定；不传则不减免。
static func full_damage(weapon, target_armor: String, attacker_bonus = null, defender_bonus = null, target_ra2_armor: String = "", dist_px: float = 0.0, target = null) -> float:
	var d := raw_damage(weapon, target_armor, target_ra2_armor)
	var wh := str(weapon.get("ra2_warhead", "")) if weapon is Dictionary else ""
	if wh == "RA3_PRISM" and target != null:
		d = Ra3MirageDamage.raw_damage(weapon,target)
	if wh != "" and Ra2Damage.has(wh):
		# RA2 Warhead.computeDamage：Verses 之后、量化之前
		if target != null and Ra2Damage.is_prone(target):
			d *= Ra2Damage.prone_damage(wh)
		# RA2 Warhead.detonate：PercentAtMax 线性衰减
		d *= Ra2Damage.distance_factor(dist_px, wh)
	d = with_offense(d, attacker_bonus if attacker_bonus is Dictionary else {})
	return with_defense(d, defender_bonus if defender_bonus is Dictionary else {})

## 对 UI 展示用的克制提示
static func describe_weapon(weapon) -> String:
	if weapon == null or weapon.is_empty():
		return "无武装"
	# RA2 规则路径：按真实护甲类别列出克制/弱势
	var wh := str(weapon.get("ra2_warhead", ""))
	if wh != "" and GameData.has_ra2_warhead(wh):
		var b := ""
		var bv := -1.0
		var w := ""
		var wv := 99.0
		for armor in GameData.RA2_ARMOR_ORDER:
			var v := GameData.ra2_verse(wh, str(armor))
			if v > bv:
				bv = v
				b = str(armor)
			if v < wv:
				wv = v
				w = str(armor)
		var aa := " · 可打空" if (weapon.get("ra2_aa", false) == true) else ""
		return "克制 %s(×%.2f) · 弱于 %s(×%.2f)%s" % [
			GameData.ra2_armor_label(b), bv, GameData.ra2_armor_label(w), wv, aa
		]
	var at := str(weapon.get("attack_type", "bullet"))
	var best := ""
	var best_v := 0.0
	for armor in GameData.combat_armor_types:
		var v := multiplier(at, str(armor))
		if v > best_v:
			best_v = v
			best = str(armor)
	var worst := ""
	var worst_v := 99.0
	for armor in GameData.combat_armor_types:
		var v2 := multiplier(at, str(armor))
		if v2 < worst_v:
			worst_v = v2
			worst = str(armor)
	return "克制 %s(×%.2f) · 弱于 %s(×%.2f)" % [
		GameData.armor_label(best), best_v, GameData.armor_label(worst), worst_v
	]

## 秒伤期望（不含克制）
static func dps(weapon) -> float:
	if weapon == null or weapon.is_empty():
		return 0.0
	var dmg := float(weapon.get("damage", 0.0))
	var cd: float = max(0.05, float(weapon.get("cooldown", 1.0)))
	var burst: int = int(max(1, int(weapon.get("burst", 1))))
	return dmg * float(burst) / cd
