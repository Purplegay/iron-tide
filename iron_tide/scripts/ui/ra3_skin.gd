class_name Ra3Skin
extends RefCounted
## 红警3（RA3）铬合金 UI 皮肤引擎
## ---------------------------------------------------------------------------
## 现状问题：原 UI 全部使用扁平的 StyleBoxFlat（纯色 + 细边），观感是「通用深色科幻 HUD」，
## 与红警3 界面差距很大。红警3 界面的设计语言可归纳为 6 条：
##   1) 深钢蓝底 + 自上而下的金属渐变（顶部镜面亮、底部近黑）；
##   2) 顶部一条镜面高光带（gloss band）+ 1px 镜面亮线，像抛光金属；
##   3) 四角 45° 倒角（chamfer），边线「上/左亮、下/右暗」形成 3D 倒角；
##   4) 边框内侧一条阵营色饰条（盟军青 / 苏联红 / 帝国金）；
##   5) 可交互格为「下沉暗槽 + 内阴影 + 亮顶边」，悬停泛青蓝光晕，按下整格染阵营色；
##   6) 字体为工业窄体大写 + 明显字距，文字带深色投影。
## 关键实现：九宫格会把「中段」拉伸，所以渐变必须是三段式（亮顶 / 中段平台 / 暗底），
## 否则面板中段会被拉成一块死板的平色 —— 这正是上一版材质看起来发平的原因。
## 本模块用代码程序化生成贴图（Image → ImageTexture），再用 StyleBoxTexture 铺贴，
## 从而在不改动既有控件树结构的前提下，把整界面换成 RA3 质感。

const CYAN := Color(0.36, 0.80, 1.00)        # 盟军/系统青
const CYAN_SOFT := Color(0.68, 0.93, 1.00)
const CYAN_DIM := Color(0.22, 0.50, 0.66)
const GOLD := Color(1.00, 0.82, 0.34)
const RED := Color(1.00, 0.44, 0.34)
const GREEN := Color(0.42, 0.95, 0.52)
const TEXT := Color(0.88, 0.93, 0.98)
const INSET_TOP := Color(0.100, 0.132, 0.172)
const INSET_BOT := Color(0.018, 0.027, 0.038)

static var _tex: Dictionary = {}
static var _font: FontVariation = null

# =============================================================== 字体
## RA3 字体：工业窄体 + 字距 + 轻微加粗。Godot 无字距属性，用 FontVariation.spacing_glyph 实现。
static func font() -> FontVariation:
	if _font != null:
		return _font
	var fv := FontVariation.new()
	var base: Font = ThemeDB.fallback_font
	if base != null:
		fv.base_font = base
	fv.set_spacing(TextServer.SPACING_GLYPH, 1)
	fv.variation_embolden = 0.04
	_font = fv
	return _font

static func apply_font(c: Control, size: int = -1) -> void:
	if not c.has_theme_font_override("font") or c.get_theme_font("font") != font():
		c.add_theme_font_override("font", font())
	if size > 0 and (not c.has_theme_font_size_override("font_size") or c.get_theme_font_size("font_size") != size):
		c.add_theme_font_size_override("font_size", size)

# =============================================================== 绘图原语
static func _brect(img: Image, rect: Rect2i, c: Color) -> void:
	if c.a <= 0.0:
		return
	var full := Rect2i(0, 0, img.get_width(), img.get_height())
	var r: Rect2i = rect.intersection(full)
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var src := Image.create_empty(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	src.fill(c)
	img.blend_rect(src, Rect2i(0, 0, r.size.x, r.size.y), r.position)

## 三段式金属渐变（亮顶 → 中段平台 → 暗底），保证九宫格拉伸后依然是金属面而非平色
static func _metal(img: Image, hi: Color, mid: Color, bot: Color) -> void:
	var h := img.get_height()
	var w := img.get_width()
	for y in h:
		var t := float(y) / float(maxi(1, h - 1))
		var c: Color
		if t < 0.36:
			c = hi.lerp(mid, t / 0.36)
		elif t < 0.64:
			c = mid
		else:
			c = mid.lerp(bot, (t - 0.64) / 0.36)
		_brect(img, Rect2i(0, y, w, 1), c)

static func _cut_px(img: Image, x: int, y: int, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var c := img.get_pixel(x, y)
	c.a *= a
	img.set_pixel(x, y, c)

## 四角 45° 倒角（仅动角部小三角区，开销可忽略）
static func _carve(img: Image, cut: int, feather: int) -> void:
	if cut <= 0:
		return
	var w := img.get_width()
	var h := img.get_height()
	var n: int = mini(cut + feather, mini(w, h))
	for iy in n:
		for ix in n:
			var d: int = ix + iy + 1 - cut
			var a: float = clampf(float(d) / float(maxi(1, feather)), 0.0, 1.0)
			if a >= 1.0:
				continue
			_cut_px(img, ix, iy, a)
			_cut_px(img, w - 1 - ix, iy, a)
			_cut_px(img, ix, h - 1 - iy, a)
			_cut_px(img, w - 1 - ix, h - 1 - iy, a)

## 边线：上/左亮（高光倒角），下/右暗（阴影倒角），斜边渐变
static func _rim(img: Image, cut: int, accent: Color, rim_a: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var hi := Color(
		accent.r + (1.0 - accent.r) * 0.35,
		accent.g + (1.0 - accent.g) * 0.35,
		accent.b + (1.0 - accent.b) * 0.35, rim_a)
	_brect(img, Rect2i(cut, 0, w - cut * 2, 2), hi)
	_brect(img, Rect2i(0, cut, 2, h - cut * 2), Color(hi.r, hi.g, hi.b, hi.a * 0.55))
	_brect(img, Rect2i(cut, h - 2, w - cut * 2, 2), Color(0, 0, 0, 0.55))
	_brect(img, Rect2i(w - 2, cut, 2, h - cut * 2), Color(0, 0, 0, 0.38))
	if cut <= 0:
		return
	for i in cut:
		var t := float(i) / float(maxi(1, cut - 1))
		var c := Color(hi.r, hi.g, hi.b, hi.a * (1.0 - 0.6 * t))
		var d := Color(0, 0, 0, 0.45 * (1.0 - 0.35 * t))
		_brect(img, Rect2i(i, cut - i, 1, 1), c)
		_brect(img, Rect2i(w - 1 - i, cut - i, 1, 1), c)
		_brect(img, Rect2i(i, h - 1 - cut + i, 1, 1), d)
		_brect(img, Rect2i(w - 1 - i, h - 1 - cut + i, 1, 1), d)

static func _ck(c: Color) -> String:
	return "%02x%02x%02x%02x" % [
		int(clampf(c.r, 0, 1) * 255.0), int(clampf(c.g, 0, 1) * 255.0),
		int(clampf(c.b, 0, 1) * 255.0), int(clampf(c.a, 0, 1) * 255.0)]

# =============================================================== 贴图生成
static func _plate_tex(key: String, size: int, cut_f: int, hi: Color, mid: Color, bot: Color,
		accent: Color, rim_a: float, stripe_a: float, gloss: float, inset: bool, bracket: bool = false) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var ss := 2
	var W := size * ss
	var H := size * ss
	var cut := cut_f * ss
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_metal(img, hi, mid, bot)
	if inset:
		_brect(img, Rect2i(0, 0, W, 3 * ss), Color(0, 0, 0, 0.45))
		_brect(img, Rect2i(0, 0, 3 * ss, H), Color(0, 0, 0, 0.35))
		_brect(img, Rect2i(0, H - 2 * ss, W, 2 * ss), Color(1, 1, 1, 0.09))
	# 镜面高光带（顶部）
	if gloss > 0.0:
		var gh: int = maxi(1, int(float(H) * 0.18))
		for y in gh:
			var t := float(y) / float(maxi(1, gh - 1))
			_brect(img, Rect2i(0, y, W, 1), Color(1, 1, 1, gloss * pow(1.0 - t, 1.8)))
		# 最顶部 1px 镜面亮线
		_brect(img, Rect2i(0, 0, W, 1), Color(1, 1, 1, 0.42))
	# 阵营色饰条
	if stripe_a > 0.0:
		_brect(img, Rect2i(cut, 3 * ss, W - cut * 2, 3 * ss), Color(accent.r, accent.g, accent.b, stripe_a))
	_carve(img, cut, 1)
	_rim(img, cut, accent, rim_a)
	if bracket:
		# RA3 标志性角标：在左上角区画「内折角」，九宫格会自动把它镜像到四个角
		var bx := cut + 5 * ss
		var by := cut + 6 * ss
		var bl := 15 * ss
		var bc := Color(accent.r, accent.g, accent.b, 0.80)
		_brect(img, Rect2i(bx, by, bl, 2 * ss), bc)
		_brect(img, Rect2i(bx, by, 2 * ss, bl), bc)
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex

static func _wrap_hv(tex: Texture2D, mx: int, my: int, pl: int, pt: int, pr: int, pb: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	var tx: float = float(clampi(mx, 0, tex.get_width() / 2))
	var ty: float = float(clampi(my, 0, tex.get_height() / 2))
	s.texture_margin_left = tx
	s.texture_margin_right = tx
	s.texture_margin_top = ty
	s.texture_margin_bottom = ty
	s.content_margin_left = float(pl)
	s.content_margin_right = float(pr)
	s.content_margin_top = float(pt)
	s.content_margin_bottom = float(pb)
	s.set_meta("ra3", true)
	return s

# =============================================================== 公开 API
## 主面板：bg 为底色（内部自推金属渐变），accent 为边框/饰条色
static func plate_from(bg: Color, accent: Color, radius: int = 4, pad: int = 8,
		top_accent: bool = true, bracket: bool = false) -> StyleBoxTexture:
	var base := Color(bg.r, bg.g, bg.b, bg.a)
	var hi := base.lightened(0.42)
	var mid := base.lightened(0.05)
	var bot := base.darkened(0.62)
	var cut: int = clampi(maxi(radius * 2 + 3, 8), 8, 16)
	var key := "P|%d|%s|%s|%s|%s|%d|%d" % [cut, _ck(hi), _ck(mid), _ck(bot), _ck(accent), 1 if top_accent else 0, 1 if bracket else 0]
	var tex := _plate_tex(key, 112, cut, hi, mid, bot, accent, 0.90, 0.85 if top_accent else 0.0, 0.32, false, bracket)
	var mx: int = cut + 24 if bracket else cut + 12
	return _wrap_hv(tex, mx, 40, pad + 3, pad + 1, pad + 3, maxi(3, pad - 2))

## 下沉暗槽（小地图、图标格、列表底）
static func inset_from(bg: Color, accent: Color, radius: int = 3, pad: int = 4) -> StyleBoxTexture:
	var base := Color(bg.r, bg.g, bg.b, bg.a)
	var hi := base.lightened(0.16)
	var mid := base
	var bot := base.darkened(0.55)
	var cut: int = clampi(maxi(radius * 2 + 2, 6), 6, 12)
	var key := "I|%d|%s|%s|%s|%s" % [cut, _ck(hi), _ck(mid), _ck(bot), _ck(accent)]
	var tex := _plate_tex(key, 72, cut, hi, mid, bot, accent, 0.60, 0.0, 0.14, true)
	return _wrap_hv(tex, cut + 8, 14, pad + 2, pad + 2, pad + 2, pad + 1)

## 可交互图标格 / 指令按钮：normal / hover / pressed / active / disabled
static func tile(accent: Color = CYAN, state: String = "normal") -> StyleBoxTexture:
	var cut := 7
	var hi := INSET_TOP.lightened(0.30)
	var mid := INSET_TOP
	var bot := INSET_BOT
	var rim := 0.70
	var stripe := 0.0
	var gloss := 0.26
	match state:
		"hover":
			hi = INSET_TOP.lightened(0.70)
			mid = INSET_TOP.lightened(0.34)
			bot = INSET_BOT.lightened(0.20)
			rim = 1.0
			gloss = 0.40
		"pressed":
			hi = INSET_TOP.lerp(accent, 0.55)
			mid = INSET_TOP.lerp(accent.darkened(0.45), 0.55)
			bot = INSET_BOT.lerp(accent.darkened(0.62), 0.40)
			rim = 1.0
			stripe = 0.55
			gloss = 0.26
		"active":
			hi = INSET_TOP.lightened(0.50)
			mid = INSET_TOP.lightened(0.10)
			bot = INSET_BOT.lerp(accent.darkened(0.60), 0.30)
			rim = 1.0
			stripe = 0.75
			gloss = 0.32
		"disabled":
			hi = Color(0.120, 0.132, 0.152)
			mid = Color(0.082, 0.090, 0.104)
			bot = Color(0.038, 0.043, 0.052)
			rim = 0.25
			gloss = 0.10
	var key := "T|%s|%s" % [state, _ck(accent)]
	var tex := _plate_tex(key, 72, cut, hi, mid, bot, accent, rim, stripe, gloss, true)
	return _wrap_hv(tex, 14, 12, 6, 4, 6, 4)

## 顶部横幅（RA3 顶栏）：更亮的钢面 + 强镜面
static func banner(accent: Color = CYAN, height: int = 44) -> StyleBoxTexture:
	var cut := 12
	var hi := Color(0.240, 0.295, 0.360)
	var mid := Color(0.078, 0.102, 0.134)
	var bot := Color(0.026, 0.036, 0.050)
	var key := "B|%d|%s|%d" % [cut, _ck(accent), height]
	var tex := _plate_tex(key, 112, cut, hi, mid, bot, accent, 0.95, 0.85, 0.42, false)
	return _wrap_hv(tex, cut + 14, 36, 20, 6, 20, 6)

## 进度/血量条
static func bar(fill: Color, is_bg: bool = false) -> StyleBoxTexture:
	var cut := 3
	var hi := fill.lightened(0.45)
	var mid := fill
	var bot := fill.darkened(0.32)
	var rim := 0.55
	var gloss := 0.32
	var inset := false
	if is_bg:
		hi = Color(0.070, 0.088, 0.112)
		mid = Color(0.040, 0.052, 0.068)
		bot = Color(0.020, 0.028, 0.038)
		rim = 0.30
		gloss = 0.0
		inset = true
	var key := "R|%s|%d" % [_ck(fill), 1 if is_bg else 0]
	var tex := _plate_tex(key, 40, cut, hi, mid, bot, fill if not is_bg else CYAN_DIM, rim, 0.0, gloss, inset)
	return _wrap_hv(tex, 8, 5, 3, 2, 3, 2)

## 发光分隔线（两端渐隐）
static func hline(accent: Color = CYAN, thick: int = 1) -> StyleBoxTexture:
	var key := "L|%s|%d" % [_ck(accent), thick]
	if not _tex.has(key):
		var W := 64
		var H: int = maxi(3, thick + 2)
		var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var mid: float = float(H - 1) * 0.5
		for y in H:
			var dy: float = absf(float(y) - mid)
			var a: float = 1.0 if dy < 0.5 else maxf(0.0, 1.0 - dy * 0.6)
			for x in W:
				var fx: float = minf(1.0, minf(float(x) / 14.0, float(W - 1 - x) / 14.0))
				if fx <= 0.0:
					continue
				_brect(img, Rect2i(x, y, 1, 1), Color(accent.r, accent.g, accent.b, a * fx * 0.9))
		_tex[key] = ImageTexture.create_from_image(img)
	return _wrap_hv(_tex[key], 14, 0, 0, 0, 0, 0)

## 四角支架（RA3 面板的标志性角标）
static func ticks(accent: Color = CYAN, size: int = 64, cut: int = 12, length: int = 20, thick: int = 2) -> StyleBoxTexture:
	var key := "K|%s|%d|%d|%d" % [_ck(accent), cut, length, thick]
	if not _tex.has(key):
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var c := Color(accent.r, accent.g, accent.b, 0.95)
		var g := 3
		_brect(img, Rect2i(g, g, length, thick), c)
		_brect(img, Rect2i(g, g, thick, length), c)
		_brect(img, Rect2i(size - g - length, g, length, thick), c)
		_brect(img, Rect2i(size - g - thick, g, thick, length), c)
		_brect(img, Rect2i(g, size - g - thick, length, thick), c)
		_brect(img, Rect2i(g, size - g - length, thick, length), c)
		_brect(img, Rect2i(size - g - length, size - g - thick, length, thick), c)
		_brect(img, Rect2i(size - g - thick, size - g - length, thick, length), c)
		_tex[key] = ImageTexture.create_from_image(img)
	var s := StyleBoxTexture.new()
	s.texture = _tex[key]
	s.draw_center = false
	s.texture_margin_left = 22.0
	s.texture_margin_right = 22.0
	s.texture_margin_top = 22.0
	s.texture_margin_bottom = 22.0
	s.set_meta("ra3", true)
	return s

# =============================================================== 通用换肤
## 把一棵控件树里所有「扁平 StyleBoxFlat」就地升级为 RA3 铬合金 StyleBoxTexture：
## 读取控件当前生效的 StyleBoxFlat（保留其原有配色意图），按槽位翻译成 RA3 面板/图标格。
## 这样无需改动既有控件结构，也不会覆盖各处刻意设置的配色。可反复调用（幂等）。
static func upgrade_tree(root: Node, accent: Color = CYAN) -> int:
	if root == null:
		return 0
	var n := upgrade_control(root as Control, accent)
	for ch in root.get_children():
		n += upgrade_tree(ch, accent)
	return n

static func upgrade_control(c: Control, accent: Color = CYAN, faction_blue := false) -> int:
	if c == null or c.has_meta("ra3_skip"):
		return 0
	var done := 0
	if c is BaseButton:
		for slot: String in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
			var sb: StyleBox = c.get_theme_stylebox(slot)
			if sb is StyleBoxTexture and sb.has_meta("ra3"):
				continue
			if sb is StyleBoxFlat:
				if slot == "focus":
					c.add_theme_stylebox_override(slot, StyleBoxEmpty.new())
					done += 1
					continue
				var state := "normal"
				match slot:
					"hover", "hover_pressed":
						state = "hover"
					"pressed":
						state = "pressed"
					"disabled":
						state = "disabled"
				var fl: StyleBoxFlat = sb
				var ac := accent
				if _sat(fl.border_color) > 0.25 and fl.border_color.a > 0.3:
					ac = fl.border_color
				elif _sat(fl.bg_color) > 0.25:
					ac = fl.bg_color
				if faction_blue and ac.b > ac.r * 1.15 and ac.b > ac.g:
					ac = accent
				c.add_theme_stylebox_override(slot, tile(ac, state))
				done += 1
	elif c is ProgressBar:
		for slot2: String in ["background", "fill"]:
			var sbp: StyleBox = c.get_theme_stylebox(slot2)
			if sbp is StyleBoxTexture and sbp.has_meta("ra3"):
				continue
			if sbp is StyleBoxFlat:
				var fp: StyleBoxFlat = sbp
				c.add_theme_stylebox_override(slot2, bar(fp.bg_color, slot2 == "background"))
				done += 1
	elif c is PanelContainer or c is Panel:
		var sb2: StyleBox = c.get_theme_stylebox("panel")
		if not (sb2 is StyleBoxTexture and sb2.has_meta("ra3")) and sb2 is StyleBoxFlat:
			var f2: StyleBoxFlat = sb2
			var ac2 := accent
			if _sat(f2.border_color) > 0.25 and f2.border_color.a > 0.3:
				ac2 = f2.border_color
			if faction_blue and ac2.b > ac2.r * 1.15 and ac2.b > ac2.g:
				ac2 = accent
			var r: int = maxi(f2.corner_radius_top_left, f2.corner_radius_top_right)
			var pad: int = maxi(2, int(round(f2.content_margin_left)))
			var col := f2.bg_color
			var big: bool = c.size.x > 240.0 or c.custom_minimum_size.x > 240.0
			if col.a <= 0.55:
				c.add_theme_stylebox_override("panel", inset_from(col, ac2, r, pad))
			else:
				c.add_theme_stylebox_override("panel", plate_from(col, ac2, maxi(r, 2), pad, true, big))
			done += 1
	if c is Label or c is RichTextLabel or c is Button:
		apply_font(c)
		if not c.has_meta("ra3_txt"):
			c.set_meta("ra3_txt", true)
			c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
			c.add_theme_constant_override("shadow_offset_x", 1)
			c.add_theme_constant_override("shadow_offset_y", 1)
			done += 1
	return done

static func _sat(c: Color) -> float:
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	return 0.0 if mx <= 0.0001 else (mx - mn) / mx
