class_name HpBar
extends RefCounted
## 红警3 风格血条绘制工具（世界血条与面板血条共用同一套视觉语言）。
##
## 造型要素（对齐 RA3 单位血条）：
##   · 深色凹槽底槽 + 1px 硬描边外框
##   · 填充顶部高光 / 底部阴影，制造斜面金属感
##   · 整条等分刻线（RA3 的「分格」读数，血量一眼可读）
##   · 低血时整体脉冲闪烁提醒
##
## 只做绘制、不持有状态；调用方传入 CanvasItem 与矩形即可，不依赖节点类型。

static var world_batch: MultiMeshInstance2D

# ---------------- 调色板 ----------------
const FRAME: Color = Color(0.012, 0.018, 0.028, 0.95)     # 外框
const TRACK: Color = Color(0.055, 0.068, 0.088, 0.82)     # 底槽
const TRACK_TOP: Color = Color(0.0, 0.0, 0.0, 0.42)       # 内衬：上暗
const TRACK_BOT: Color = Color(0.36, 0.44, 0.56, 0.20)    # 内衬：下亮
const NOTCH: Color = Color(0.0, 0.0, 0.0, 0.34)           # 分段刻线

const COL_ALLY: Color = Color(0.36, 0.86, 0.42)
const COL_ENEMY: Color = Color(0.95, 0.38, 0.32)

## 运行时阵营色（由 HouseColor.sync_hp() 随玩家涂装更新；默认沿用经典绿/红）。
static var ally_fill: Color = COL_ALLY
static var enemy_fill: Color = COL_ENEMY

const TIER_HI: Color = Color(0.38, 0.88, 0.44)
const TIER_MID: Color = Color(0.98, 0.79, 0.24)
const TIER_LOW: Color = Color(0.94, 0.28, 0.22)

const CRIT: float = 0.18   # 低于此比例触发脉冲闪烁
const NOTCH_PITCH: float = 9.0   # 每格目标宽度（像素；越小分格越密）

# ---------------- 表现层（本轮新增） ----------------
const GHOST: Color = Color(1.0, 1.0, 1.0, 0.40)      # 掉血残影（延迟下落的旧血）
const FLASH: Color = Color(1.0, 1.0, 1.0, 0.92)      # 受击白闪
const ALERT: Color = Color(1.0, 0.30, 0.24)          # 建筑受损警戒脉冲
const RIM_ENEMY: Color = Color(1.0, 1.0, 1.0, 0.62)  # 敌方血条细描边（非颜色维度区分）
const NO_RIM: Color = Color(0.0, 0.0, 0.0, 0.0)

## 返回该阵营血条的额外描边色（敌方给一条细窄白描边，便于颜色之外辨识）。
static func shield_number(amount: float) -> String:
	return str(maxi(1, roundi(amount))) if amount > 0.0 else "0"

static func readout(side: String, hp: float, maximum: float, shield: float) -> String:
	if side != "ally": return ""
	var text := "%s/%s" % [shield_number(hp), shield_number(maximum)]
	if shield > 0.0: text += "  盾 " + shield_number(shield)
	return text

static func draw_readout(canvas: CanvasItem, rect: Rect2, side: String, hp: float, maximum: float, shield: float) -> void:
	var text := readout(side, hp, maximum, shield)
	if text.is_empty(): return
	var baseline := Vector2(rect.get_center().x - 90.0, rect.position.y - (8.0 if shield > 0.0 else 3.0))
	var font := ThemeDB.fallback_font
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, 3, Color("#071018"))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color.WHITE)

static func rim_for(side: String) -> Color:
	return RIM_ENEMY if side == "enemy" else NO_RIM

## 面板血条用：按血量三分段取色（红警3 信息栏）。
static func tier_color(frac: float) -> Color:
	if frac < 0.33:
		return TIER_LOW
	if frac < 0.66:
		return TIER_MID
	return TIER_HI

static func faction_color(side: String) -> Color:
	return ally_fill if side == "ally" else enemy_fill

## 世界血条填充色：满血用阵营色，掉血后向红警式告警红过渡（低血=危险）。
static func world_fill(side: String, frac: float) -> Color:
	var c: Color = faction_color(side)
	if frac < 0.5:
		var k: float = clampf((0.5 - frac) / 0.35, 0.0, 1.0)
		c = c.lerp(TIER_LOW, k * 0.8)
	return c

## 按宽度推算分段数（避免小血条刻线过密）。
static func seg_count(width: float) -> int:
	return clampi(int(round(width / NOTCH_PITCH)), 2, 16)

## 在 CanvasItem 上绘制一条 RA3 风格血条。rect 为底槽矩形（不含 1px 外框）。
## 可选表现层参数（保持向后兼容，旧调用只传前 5 个即可）：
##   ghost  掉血残影（上一次的较高血量比例，收尾时向下追赶 frac）
##   flash  受击白闪强度 0..1（命中瞬间整条填充泛白）
##   alert  受损警戒脉冲强度 0..1（建筑受损时血条闪烁）
##   rim    额外细描边（敌方血条用它，提供颜色之外的区分维度）
static func draw_bar(ci: CanvasItem, rect: Rect2, frac: float, fill: Color,
		segments: int = 0, ghost: float = -1.0, flash: float = 0.0,
		alert: float = 0.0, rim: Color = NO_RIM, rank: int = 0) -> void:
	if world_batch != null and ci == world_batch.get_parent() and flash <= 0.01 and alert <= 0.01 and rank == 0 and segments == 0 and rect.size.x > 2 and rect.size.y > 2:
		if world_batch.append(rect,frac,fill,ghost,rim): return
	var w: float = rect.size.x
	var h: float = rect.size.y
	if ci == null or w <= 2.0 or h <= 2.0:
		return
	var f: float = clampf(frac, 0.0, 1.0)
	var pos: Vector2 = rect.position

	# ① 外框（1px 深色硬描边）
	ci.draw_rect(Rect2(pos - Vector2.ONE, Vector2(w + 2.0, h + 2.0)), FRAME)
	# ② 底槽
	ci.draw_rect(rect, TRACK)
	# ③ 内衬：上暗下亮，制造内凹感
	if h >= 4.0:
		ci.draw_rect(Rect2(pos, Vector2(w, 1.0)), TRACK_TOP)
		ci.draw_rect(Rect2(pos + Vector2(0.0, h - 1.0), Vector2(w, 1.0)), TRACK_BOT)

	var ix: float = pos.x + 1.0
	var iy: float = pos.y + 1.0
	var iw: float = w - 2.0
	var ih: float = h - 2.0

	# ④ 掉血残影：落在当前血量与旧血量之间的裸槽上（先画，被填充盖住重叠部分）
	var g: float = clampf(ghost, f, 1.0)
	if g > f + 0.004:
		ci.draw_rect(Rect2(ix, iy, iw * g, ih), GHOST)

	# ⑤ 填充（内缩 1px，让外框始终可见）
	var fw: float = iw * f
	if fw > 0.5:
		var fcol: Color = fill
		if f < CRIT:
			fcol.a *= 0.60 + 0.40 * sin(float(Time.get_ticks_msec()) * 0.012)
		ci.draw_rect(Rect2(ix, iy, fw, ih), fcol)
		# 顶部高光条（斜面金属感）；仅当条体够高时才加底部阴影，避免小条出现碎条纹
		var gh: float = maxf(1.0, ih * 0.34)
		ci.draw_rect(Rect2(ix, iy, fw, gh), fcol.lightened(0.16))
		if ih >= 5.0:
			var dh: float = maxf(1.0, ih * 0.24)
			ci.draw_rect(Rect2(ix, iy + ih - dh, fw, dh), fcol.darkened(0.16))
		# 受击白闪：覆盖在填充之上，命中瞬间整条泛白
		if flash > 0.01:
			ci.draw_rect(Rect2(ix, iy, fw, ih), Color(FLASH.r, FLASH.g, FLASH.b, FLASH.a * clampf(flash, 0.0, 1.0)))

	# ⑥ 等分刻线（整条都刻，红警式分格读数）
	var n: int = segments
	if n <= 0:
		n = seg_count(iw)
	if n > 1:
		var step: float = iw / float(n)
		for i in range(1, n):
			var x: float = ix + step * float(i)
			ci.draw_line(Vector2(x, pos.y + 1.0), Vector2(x, pos.y + h - 1.0), NOTCH, 1.0)

	# ⑦ 受损警戒脉冲（建筑受损时血条闪烁；强度越高越明显）
	if alert > 0.01:
		var p: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.014)
		var a: float = clampf(alert, 0.0, 1.0) * (0.30 + 0.55 * p)
		ci.draw_rect(Rect2(pos - Vector2.ONE, Vector2(w + 2.0, h + 2.0)), Color(ALERT.r, ALERT.g, ALERT.b, a), false, 1.0)

	# ⑧ 细描边（敌方血条：颜色之外的区分维度）
	if rim.a > 0.0:
		ci.draw_rect(Rect2(pos - Vector2.ONE, Vector2(w + 2.0, h + 2.0)), rim, false, 1.0)

	# ⑨ 老兵等级标（RA2：原版老兵单箭头、精英三箭头，绘于血条左上方）
	if rank > 0:
		_draw_rank(ci, pos, rank)

## Original Yuri PIPS frames 14 (veteran) / 15 (elite), no synthetic chevrons.
static var _rank_textures: Dictionary = {}

static func uses_ra3_ranks(unit_data: Dictionary) -> bool:
	return str(unit_data.get("id", "")).begins_with("R3")

## Keep the RID alive after CanvasItem._draw returns, even for unselected units.
static func rank_texture(rank: int, unit_data: Dictionary = {}) -> Texture2D:
	if rank <= 0: return null
	var path: String
	if uses_ra3_ranks(unit_data):
		var folder := "soviet" if unit_data.get("faction") == "soviet" else "mirage/uprising"
		path = "res://assets/ra3/%s/rank%d.png" % [folder, mini(rank, 3)]
	else:
		path = "res://assets/ra2/pips/" + ("veteran.png" if rank == 1 else "elite.png")
	if not _rank_textures.has(path): _rank_textures[path] = load(path)
	return _rank_textures[path]

static func _draw_rank(ci: CanvasItem, bar_pos: Vector2, rank: int) -> void:
	var texture := rank_texture(rank)
	if texture == null: return
	ci.draw_texture(texture, (bar_pos + Vector2(-1, -texture.get_height() - 1)).floor())
