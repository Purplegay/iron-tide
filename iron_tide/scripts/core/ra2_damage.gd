class_name Ra2Damage
extends RefCounted
## 第 8 批「引擎整合 ts-ra2」：命中模型的唯一事实源。
##
## 逐条对应参考实现（refs/ts-ra2，GPL 参考工程，只读参考、不复制代码）：
##   · game/Warhead.ts  computeDamage()      —— Verses / ProneDamage / 量化
##   · game/Warhead.ts  detonate()           —— CellSpread + PercentAtMax 线性衰减
##   · game/Warhead.ts  pickExplodeAnim()    —— 命中动画按伤害选档
##   · game/gameobject/Vehicle.ts applyRocking() —— 受击摇晃
##   · game/gameobject/common/AnimTerrainEffect.ts —— 地面变形（crater）
##
## 铁律：本文件不产生任何碰撞多边形 / 判定几何改动，只回答「打多少血、放哪个特效」。

## 1 个 RA2 格子 = 多少世界像素。⚠ 必须与 Ra2Sfx.PX_PER_CELL 同值（探针会断言）。
const PX_PER_CELL := 55.0
## 命中动画步长：索引 = clamp(floor(damage / 25), 0, n-1)
const ANIM_DAMAGE_STEP := 25.0
## 受击摇晃：RA2 ROCKING_TICKS = 34 tick @ 15 TPS
const ROCK_TICKS := 34.0
const ROCK_TPS := 15.0
## ts-ra2 engine/renderable/entity/Vehicle.ts: const P = Math.PI / 4
const ROCK_MAX_TILT := PI / 4.0
## ts-ra2 Warhead: clamp(damage / 300, 0, 1)
const ROCK_DAMAGE_DIVISOR := 300.0


# ---------------------------------------------------------------- 弹头字段

static func _wh(warhead_id: String) -> Dictionary:
	if warhead_id == "":
		return {}
	return GameData.ra2_warheads.get(warhead_id.to_lower(), {})


static func has(warhead_id: String) -> bool:
	return not _wh(warhead_id).is_empty()


static func _extra(warhead_id: String, key: String) -> String:
	var e = _wh(warhead_id).get("extra", null)
	if typeof(e) != TYPE_DICTIONARY:
		return ""
	var v = e.get(key, null)
	return "" if v == null else str(v)


## CellSpread（单位：格）
static func cells(warhead_id: String) -> float:
	return GameData.ra2_cell_spread(warhead_id)


## PercentAtMax（0..1，缺省 100%）
static func percent_at_max(warhead_id: String) -> float:
	return GameData.warhead_combat_rule(warhead_id).get("percent_at_max", 1.0)


## ProneDamage（0..1，缺省 1.0 = 不减免）
static func prone_damage(warhead_id: String) -> float:
	return GameData.warhead_combat_rule(warhead_id).get("prone_damage", 1.0)


static func is_rocker(warhead_id: String) -> bool:
	return GameData.warhead_combat_rule(warhead_id).get("rocker", false)


static func is_sparky(warhead_id: String) -> bool:
	return GameData.warhead_combat_rule(warhead_id).get("sparky", false)


static func is_bright(warhead_id: String) -> bool:
	return GameData.warhead_combat_rule(warhead_id).get("bright", false)


## Deform= 形变比例（"15%" / 0.15 / 15 都接受）
static func deform_ratio(warhead_id: String) -> float:
	return GameData.warhead_combat_rule(warhead_id).get("deform_ratio", 0.0)


## DeformThreshhold= 低于该伤害不产生形变
static func deform_threshold(warhead_id: String) -> float:
	return GameData.warhead_combat_rule(warhead_id).get("deform_threshold", 0.0)


# ---------------------------------------------------------------- 伤害量纲

## RA2 量化：正数 floor、负数 ceil（Warhead.computeDamage 结尾）
static func quantize(v: float) -> float:
	if v > 0.0:
		return floorf(v)
	return ceilf(v)


## 目标护甲分类：优先 RA2 真实类别，其次由引擎旧词表换算
static func armor_of(target) -> String:
	if target == null:
		return "none"
	var a = target.get("ra2_armor")
	if a != null and str(a) != "":
		return str(a)
	var e = target.get("armor")
	return GameData.to_ra2_armor(str(e) if e != null else "none")


## 卧倒（本工程 = 部署据守；RA2 = Prone）
static func is_prone(target) -> bool:
	if target == null:
		return false
	if target.has_method("is_prone"):
		return (target.call("is_prone") == true)
	return false


## CellSpread / PercentAtMax：t = 距离/溅射半径，线性插值 1 → PercentAtMax
static func distance_factor(dist_px: float, warhead_id: String) -> float:
	var cs := cells(warhead_id)
	if cs <= 0.0:
		return 1.0
	var t := clampf((dist_px / PX_PER_CELL) / cs, 0.0, 1.0)
	return lerpf(1.0, percent_at_max(warhead_id), t)


## 目标是否落在 CellSpread 内
static func in_spread(dist_px: float, warhead_id: String) -> bool:
	var cs := cells(warhead_id)
	if cs <= 0.0:
		return false
	return dist_px <= cs * PX_PER_CELL


## 单个目标的命中伤害（防御前、量化前）。
## RA2 顺序：Verses(目标护甲) → ProneDamage → CellSpread 衰减 → 局外加成/防御 → 量化
static func target_damage(base: float, warhead_id: String, target, dist_px: float) -> float:
	var d := base
	if has(warhead_id):
		var v := GameData.ra2_verse(warhead_id, armor_of(target))
		if v >= 0.0:
			d *= v
		if is_prone(target):
			d *= prone_damage(warhead_id)
		d *= distance_factor(dist_px, warhead_id)
	return d


# ---------------------------------------------------------------- 命中动画

## RA2 Warhead.pickExplodeAnim：索引 = clamp(floor(damage / 25), 0, n-1)
## EMEffect=yes 的弹头保持随机（RA2 原语义）
static func anim_index(warhead_id: String, damage: float) -> int:
	var list := GameData.ra2_impact_anims(warhead_id)
	if list.is_empty():
		return -1
	if GameData.warhead_combat_rule(warhead_id).get("em_effect", false):
		return randi() % list.size()
	return clampi(int(floorf(maxf(damage, 0.0) / ANIM_DAMAGE_STEP)), 0, list.size() - 1)


static func pick_impact_anim(warhead_id: String, damage: float) -> String:
	var list := GameData.ra2_impact_anims(warhead_id)
	if list.is_empty():
		return ""
	return str(list[anim_index(warhead_id, damage)])


# ---------------------------------------------------------------- 受击反馈

## 摇晃强度：clamp(damage / 300, 0, 1)
static func rocking_intensity(damage: float) -> float:
	return clampf(damage / ROCK_DAMAGE_DIVISOR, 0.0, 1.0)


## 摇晃时长（秒）= 34 tick / 15 TPS ≈ 2.267s
static func rocking_seconds() -> float:
	return ROCK_TICKS / ROCK_TPS


## 进度 s∈[0,1] → 倾斜角（弧度）：r = P · I · (1-(2s-1)²)
static func rocking_tilt(s: float, intensity: float) -> float:
	var e := 1.0 - pow(2.0 * clampf(s, 0.0, 1.0) - 1.0, 2.0)
	return ROCK_MAX_TILT * intensity * e


## Orthographic projection of a sprite rolling about its ground contact edge.
## Screen right is the camera's horizontal axis; ground depth is compressed by Iso.K.
static func rocking_xform(hit_dir: Vector2, tilt: float, radius: float) -> Transform2D:
	if is_zero_approx(tilt) or hit_dir.is_zero_approx():
		return Transform2D.IDENTITY
	var n := hit_dir.normalized().rotated(-Iso.eff_angle())
	var ground := Vector2(n.x, n.y * Iso.K)
	var c := cos(tilt)
	var s := sin(tilt)
	var across := Vector2.RIGHT + ground * (n.x * (c - 1.0)) + Vector2.DOWN * (n.x * s)
	var down := Vector2.DOWN * c - ground * s
	var lift := radius * (ground * (1.0 - c) + Vector2.UP * s)
	return Transform2D(across, down, lift)


# ---------------------------------------------------------------- 地面变形

## 该弹头是否够格在地面留下灼痕（Deform= + DeformThreshhold= 驱动）
static func should_deform(warhead_id: String, damage: float) -> bool:
	if deform_ratio(warhead_id) <= 0.0:
		return false
	var th := deform_threshold(warhead_id)
	return th <= 0.0 or damage >= th


## 灼痕半径（像素）：以溅射半径为准
static func deform_radius_px(warhead_id: String) -> float:
	return maxf(cells(warhead_id) * PX_PER_CELL, 0.0)
