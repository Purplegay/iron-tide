extends Control
class_name UnitIcon
## HUD 共用身份图标：优先使用目录中的 cameo，缺图时按兵种绘制备用剪影。
## 右下角显示同类数量，底部显示血条，右上角显示有无武器。
## 头像为「动态」：每帧按 _t 驱动履带滚动、炮塔摆动、旋翼旋转、
## 机体呼吸起伏与掠光扫过，让单位图标在界面上活起来。

var data: Dictionary = {}
var col: Color = Color(0.35, 0.65, 1.0)
var count: int = 1
var show_count := false
var hp_frac: float = 1.0
var damaged: bool = false
var cameo_texture: Texture2D = null
var show_status: bool = true
var veteran_rank: int = 0
var rank_badge: Texture2D:
	get: return HpBar.rank_texture(veteran_rank, data)

var _t: float = 0.0
var _acc: float = 0.0
var animate: bool = true
const ANIM_STEP: float = 0.033   # 约 30fps，多个头像同屏也不吃性能

## 势力动画风格：盟军干净 / 苏联笨重 / 帝国花哨 / 虫群有机
const FACTION_STYLE := {
	"allied": {"tempo": 1.12, "edge": 1.0, "flash": 0.0, "grit": 0.0},
	"soviet": {"tempo": 0.72, "edge": 1.7, "flash": 0.0, "grit": 1.0},
	"empire": {"tempo": 1.30, "edge": 1.15, "flash": 1.0, "grit": 0.0},
	"swarm": {"tempo": 1.10, "edge": 1.2, "flash": 0.5, "grit": 0.0},
}
var selected: bool = false
var _fs_tempo: float = 1.0
var _fs_edge: float = 1.0
var _fs_flash: float = 0.0
var _fs_grit: float = 0.0

func setup(p_data: Dictionary, p_color: Color, p_count: int = 1, p_hp_frac: float = 1.0, production: bool = false) -> void:
	_apply_style(str(p_data.get("faction", "")), str(p_data.get("role", "")))
	data = p_data
	cameo_texture = null
	var cameo_path := GameData.ra2_cameo_path(str(data.get("id", "")))
	var art: Dictionary = GameData.ra2_art.get(str(data.get("id", "")), {})
	# IronTide: production uses Portrait; selection uses the native Button/cameo.
	if production: cameo_path = str(art.get("portrait", cameo_path))
	if not cameo_path.is_empty():
		cameo_texture = ResourceLoader.get_cached_ref(cameo_path) as Texture2D
		if cameo_texture == null and ResourceLoader.exists(cameo_path):
			cameo_texture = load(cameo_path) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if art.has("portrait") else CanvasItem.TEXTURE_FILTER_NEAREST
	col = p_color
	count = maxi(1, p_count)
	hp_frac = clampf(p_hp_frac, 0.0, 1.0)
	damaged = hp_frac < 0.995
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(46, 46)
	tooltip_text = "%s ×%d\n%s" % [str(data.get("name", "?")), count, EntityDescription.text(data)]
	queue_redraw()

func set_hero(id:String) -> void:
	var portrait:=preload("res://scripts/ui/hero_portraits.gd").texture(id)
	if id in ["FV","HARV"] and not preload("res://scripts/ui/hero_portraits.gd").showing_driver(id):
		portrait=load("res://assets/ui/heroes/%s-unit.png"%("yinpian" if id=="FV" else "laocheng"))
	if portrait==null:return
	cameo_texture=portrait
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()

func _process(delta: float) -> void:
	if not animate or (cameo_texture != null and not selected):
		return
	if not is_visible_in_tree():
		return
	anim_tick(delta)

## 推进动画时钟（与可视性解耦，便于无头校验）。
func anim_tick(delta: float) -> void:
	_t += delta * _fs_tempo
	_acc += delta
	if _acc >= ANIM_STEP:
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	if cameo_texture != null:
		_draw_cameo()
	else:
		_draw_base()
	_draw_overlay()

func _draw_cameo() -> void:
	var extent := size
	if extent.x <= 4.0 or extent.y <= 10.0:
		return
	draw_rect(Rect2(Vector2.ZERO, extent), Color(0.06, 0.075, 0.10, 0.95))
	var available := extent - Vector2(4.0, 10.0 if show_status else 4.0)
	var source := cameo_texture.get_size()
	var fit := minf(available.x / source.x, available.y / source.y)
	var image_size := source * fit
	var origin := Vector2(2, 2) + (available - image_size) * 0.5
	var image_rect := Rect2(origin, image_size)
	draw_texture_rect(cameo_texture, image_rect, false)
	if data.get("id","") in MetaProgress.Academy.Stars.IDS:
		preload("res://scripts/ui/hero_portraits.gd").draw_name(self, image_rect, data.id)
	var border := col.lerp(Color(1.0, 0.35, 0.3), 0.55) if damaged else col
	draw_rect(Rect2(Vector2.ONE * 0.5, extent - Vector2.ONE), border, false, 1.0)
	if show_status:
		_draw_status(extent, extent.x / 54.0)

func _draw_base() -> void:
	var s := Vector2(46, 46)
	if size.x > 8.0 and size.y > 8.0:
		s = size
	var c := s * 0.5
	c.y += sin(_t * 2.2) * 0.9 * (s.x / 54.0)   # 呼吸起伏
	var k: float = s.x / 54.0
	# 底板 + 边框
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.075, 0.10, 0.95))
	var border := col
	if damaged:
		border = col.lerp(Color(1.0, 0.35, 0.3), 0.55)
	draw_rect(Rect2(Vector2.ONE * 0.5, s - Vector2.ONE), border, false, maxf(1.0, 1.5 * k))

	var body := col
	var dark := col.darkened(0.45)
	var light := col.lightened(0.32)
	var tags: Array = data.get("tags", [])
	var role := str(data.get("role", ""))
	var is_harv: bool = data.get("is_harvester", false) == true or tags.has("harvester") or role == "harvester"

	if tags.has("beast") or role == "beast" or role == "swarm":
		_draw_beast(c, k, body, dark, light)
	elif tags.has("air"):
		_draw_air(c, k, body, dark, light)
	elif role == "infantry":
		_draw_infantry(c, k, body, dark, light)
	elif is_harv:
		_draw_harvester(c, k, body, dark, light)
	elif role == "mech":
		_draw_mech(c, k, body, dark, light)
	elif role == "structure":
		_draw_structure(c, k, body, dark, light)
	else:
		_draw_vehicle(c, k, body, dark, light)

	# 掠光扫过（金属高光感）
	var sweep := fmod(_t * 22.0, s.x + 26.0 * k) - 13.0 * k
	var hw := 6.0 * k
	draw_colored_polygon(PackedVector2Array([
		Vector2(sweep - hw, s.y), Vector2(sweep, 0.0),
		Vector2(sweep + hw, 0.0), Vector2(sweep + hw * 2.0, s.y),
	]), Color(1.0, 1.0, 1.0, 0.045))

	if show_status:
		_draw_status(s, k)

func _draw_status(s: Vector2, k: float) -> void:
	if veteran_rank > 0:
		draw_rect(Rect2(2, 2, 16, 16), Color(0.02, 0.03, 0.04, 0.85))
		var badge := rank_badge
		var badge_size := badge.get_size()
		badge_size = (badge_size * minf(1.0, 16.0 / maxf(badge_size.x, badge_size.y))).round()
		var badge_pos := (Vector2(10, 10) - badge_size / 2.0).floor() if HpBar.uses_ra3_ranks(data) else Vector2(5, 15 - badge_size.y)
		draw_texture_rect(badge, Rect2(badge_pos, badge_size), false)
	# 右上：有无武器
	var wv = data.get("weapon", null)
	var has_gun := typeof(wv) == TYPE_DICTIONARY and not (wv as Dictionary).is_empty()
	draw_circle(Vector2(s.x - 8.0 * k, 8.0 * k), 4.0 * k, Color(0.45, 1.0, 0.55, 0.95) if has_gun else Color(0.4, 0.44, 0.5, 0.8))

	# 底部血条（红警3 风格：与场上血条同一套造型）
	var bar_h: float = maxf(4.0, 5.0 * k)
	var bar_y: float = s.y - bar_h - 1.0 * k
	HpBar.draw_bar(self, Rect2(1.0 * k, bar_y, s.x - 2.0 * k, bar_h), hp_frac, HpBar.tier_color(hp_frac))

	# A width-aware count box also fits three-digit armies; keep it above HP.
	if count > 1 or show_count:
		var font := get_theme_default_font()
		var font_size := maxi(11, roundi(12.0 * k))
		var label := "×%d" % count
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0
		var height := float(font_size) + 5.0
		var box := Rect2(s.x - width - 2.0, bar_y - height - 2.0, width, height)
		draw_rect(box, Color(0.035, 0.055, 0.08, 0.96))
		draw_rect(box, col.lightened(0.25), false, 1.0)
		draw_string(font, box.position + Vector2(4.0, font_size), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_structure(c: Vector2, k: float, body: Color, dark: Color, light: Color) -> void:
	var w := 32.0 * k
	var h := 22.0 * k
	draw_rect(Rect2(c.x - w * 0.5, c.y + h * 0.28, w, h * 0.42), dark)
	draw_rect(Rect2(c.x - w * 0.5, c.y + h * 0.28, w, h * 0.10), light)
	var tw := w * 0.66
	var th := h * 0.95
	var tx := c.x - tw * 0.5
	var ty := c.y - h * 0.72
	draw_rect(Rect2(tx, ty, tw, th), body)
	draw_rect(Rect2(tx, ty, tw, th * 0.16), light)
	draw_rect(Rect2(tx + tw - 3.0 * k, ty, 3.0 * k, th), dark)
	for i in range(3):
		var wx := tx + 3.5 * k + float(i) * (tw - 7.0 * k) / 3.0
		draw_rect(Rect2(wx, ty + 6.0 * k, 3.0 * k, 3.0 * k), Color(1.0, 0.94, 0.62, 0.85))
	draw_line(Vector2(c.x, ty), Vector2(c.x, ty - 7.0 * k), light, maxf(1.0, 1.2 * k))
	draw_circle(Vector2(c.x, ty - 7.0 * k), 1.8 * k, Color(1.0, 0.5, 0.45, 0.95))

func _draw_vehicle(c: Vector2, k: float, body: Color, dark: Color, light: Color) -> void:
	var w := 30.0 * k
	var h := 18.0 * k
	draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.05, w, h * 0.55), dark)
	# 履带滚动刻线
	var tr := fmod(_t * 9.0, 5.0) * k
	var i := -3
	while i <= 3:
		var tx := c.x + float(i) * 5.0 * k + tr
		if tx > c.x - w * 0.46 and tx < c.x + w * 0.46:
			draw_line(Vector2(tx, c.y + h * 0.02), Vector2(tx, c.y + h * 0.48), dark.lightened(0.28), maxf(1.0, 1.1 * k))
		i += 1
	draw_rect(Rect2(c.x - w * 0.42, c.y - h * 0.5, w * 0.84, h * 0.5), body)
	draw_circle(Vector2(c.x + 1.0 * k, c.y - h * 0.45), 6.0 * k, light)
	# 炮塔轻微摆动
	var p0 := Vector2(c.x + 2.0 * k, c.y - h * 0.5)
	var p1 := Vector2(c.x + 15.0 * k, c.y - h * 1.15)
	var dirv := (p1 - p0).rotated(sin(_t * 1.7) * 0.12)
	draw_line(p0, p0 + dirv, dark, 3.0 * k)

func _draw_infantry(c: Vector2, k: float, body: Color, dark: Color, light: Color) -> void:
	draw_circle(Vector2(c.x - 6.0 * k, c.y - 14.0 * k), 5.5 * k, light)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 11.0 * k, c.y + 12.0 * k),
		Vector2(c.x - 3.0 * k, c.y - 9.0 * k),
		Vector2(c.x + 4.0 * k, c.y - 8.0 * k),
		Vector2(c.x + 8.0 * k, c.y + 12.0 * k),
	]), body)
	draw_line(Vector2(c.x - 12.0 * k, c.y + 13.0 * k), Vector2(c.x + 11.0 * k, c.y - 2.0 * k), dark, 3.0 * k)
	# 持枪手臂轻微摆动
	var sway := sin(_t * 2.4) * 1.3 * k
	draw_line(Vector2(c.x + 8.0 * k, c.y - 1.0 * k + sway), Vector2(c.x + 18.0 * k, c.y - 8.0 * k + sway), dark, 2.5 * k)

func _draw_mech(c: Vector2, k: float, body: Color, dark: Color, light: Color) -> void:
	# 双腿交替迈步
	var step := sin(_t * 2.0) * 1.6 * k
	draw_line(Vector2(c.x - 8.0 * k, c.y + 2.0 * k), Vector2(c.x - 12.0 * k, c.y + 16.0 * k + step), dark, 4.0 * k)
	draw_line(Vector2(c.x + 6.0 * k, c.y + 2.0 * k), Vector2(c.x + 10.0 * k, c.y + 16.0 * k - step), dark, 4.0 * k)
	draw_rect(Rect2(c.x - 12.0 * k, c.y - 12.0 * k, 24.0 * k, 15.0 * k), body)
	draw_rect(Rect2(c.x - 6.0 * k, c.y - 19.0 * k, 12.0 * k, 8.0 * k), light)
	draw_line(Vector2(c.x + 5.0 * k, c.y - 8.0 * k), Vector2(c.x + 18.0 * k, c.y - 14.0 * k), dark, 3.0 * k)
	# 光学眼脉冲
	var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 4.0))
	draw_circle(Vector2(c.x - 1.0 * k, c.y - 15.0 * k), 1.8 * k, Color(1.0, 0.4, 0.35, pulse))

func _draw_beast(c: Vector2, k: float, body: Color, dark: Color, light: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 16.0 * k, c.y + 2.0 * k),
		Vector2(c.x - 5.0 * k, c.y - 10.0 * k),
		Vector2(c.x + 10.0 * k, c.y - 9.0 * k),
		Vector2(c.x + 17.0 * k, c.y + 1.0 * k),
		Vector2(c.x + 6.0 * k, c.y + 10.0 * k),
		Vector2(c.x - 9.0 * k, c.y + 11.0 * k),
	]), body)
	# 多足摆动
	for i in range(3):
		var lx := c.x - 10.0 * k + 9.0 * k * float(i)
		var wig := sin(_t * 3.0 + float(i) * 1.1) * 1.6 * k
		draw_line(Vector2(lx, c.y + 8.0 * k), Vector2(lx - 3.0 * k + wig, c.y + 17.0 * k), dark, 2.5 * k)
	var glow := 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 5.0))
	draw_circle(Vector2(c.x + 6.0 * k, c.y - 4.0 * k), 2.6 * k, Color(1.0, 0.85, 0.3, glow))
	draw_line(Vector2(c.x + 15.0 * k, c.y - 6.0 * k), Vector2(c.x + 21.0 * k, c.y - 12.0 * k), light, 2.0 * k)

func _draw_air(c: Vector2, k: float, body: Color, dark: Color, light: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - 16.0 * k),
		Vector2(c.x + 6.0 * k, c.y + 6.0 * k),
		Vector2(c.x, c.y + 14.0 * k),
		Vector2(c.x - 6.0 * k, c.y + 6.0 * k),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 20.0 * k, c.y + 6.0 * k),
		Vector2(c.x + 20.0 * k, c.y + 6.0 * k),
		Vector2(c.x + 8.0 * k, c.y + 12.0 * k),
		Vector2(c.x - 8.0 * k, c.y + 12.0 * k),
	]), dark)
	draw_circle(Vector2(c.x, c.y - 6.0 * k), 3.4 * k, light)
	# 旋翼旋转
	var ra := _t * 11.0
	var rr := 14.0 * k
	for j in range(3):
		var a := ra + float(j) * TAU / 3.0
		draw_line(
			Vector2(c.x - cos(a) * rr, c.y - 6.0 * k - sin(a) * rr * 0.32),
			Vector2(c.x + cos(a) * rr, c.y - 6.0 * k + sin(a) * rr * 0.32),
			Color(light.r, light.g, light.b, 0.5), 1.4 * k)

func _draw_harvester(c: Vector2, k: float, body: Color, dark: Color, light: Color) -> void:
	draw_rect(Rect2(c.x - 15.0 * k, c.y - 4.0 * k, 30.0 * k, 16.0 * k), body)
	draw_rect(Rect2(c.x - 11.0 * k, c.y - 12.0 * k, 16.0 * k, 9.0 * k), light)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 15.0 * k, c.y + 12.0 * k),
		Vector2(c.x - 22.0 * k, c.y + 20.0 * k),
		Vector2(c.x + 2.0 * k, c.y + 20.0 * k),
		Vector2(c.x + 6.0 * k, c.y + 12.0 * k),
	]), dark)
	# 采集滚筒旋转
	var wa := _t * 6.0
	var bc := Vector2(c.x + 9.0 * k, c.y + 8.0 * k)
	draw_circle(bc, 3.5 * k, Color(1.0, 0.82, 0.4))
	for j in range(3):
		var a := wa + float(j) * TAU / 3.0
		draw_line(bc, bc + Vector2(cos(a), sin(a)) * 3.2 * k, Color(0.5, 0.4, 0.12), 1.0 * k)

func _apply_style(fid: String, p_role: String = "") -> void:
	var st: Dictionary = FACTION_STYLE.get(fid, FACTION_STYLE["allied"])
	_fs_tempo = float(st.get("tempo", 1.0))
	_fs_edge = float(st.get("edge", 1.0))
	_fs_flash = float(st.get("flash", 0.0))
	_fs_grit = float(st.get("grit", 0.0))
	if p_role == "infantry":
		_fs_tempo *= 1.12
	elif p_role == "air":
		_fs_tempo *= 1.08

func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()

## 势力/选中 覆盖层：在原 _draw 之上叠加（帝国金边呼吸 / 苏联厚钢框 / 选中描边脉冲）
func _draw_overlay() -> void:
	var s := size
	if s.x <= 0.0:
		return
	var k := s.x / 54.0
	if _fs_flash > 0.0:
		var fp := 0.5 + 0.5 * sin(_t * 4.6)
		var gold := Color(1.0, 0.82, 0.35)
		draw_rect(Rect2(Vector2(0.5, 0.5), s - Vector2.ONE), Color(gold.r, gold.g, gold.b, (0.10 + 0.5 * fp) * _fs_flash), false, maxf(1.2, 1.5 * k * _fs_edge))
		var sw := fmod(_t * 40.0 * _fs_tempo, s.x + 30.0 * k) - 15.0 * k
		var sh := Color(1.0, 0.93, 0.7, 0.12 * _fs_flash * (0.5 + 0.5 * sin(_t * 6.0)))
		draw_rect(Rect2(Vector2(maxf(0.0, sw - 4.0 * k), 2.0 * k), Vector2(8.0 * k, s.y - 4.0 * k)), sh)
	if _fs_grit > 0.0:
		var gp := 0.5 + 0.5 * sin(_t * 2.0)
		var steel := Color(0.62, 0.66, 0.72)
		draw_rect(Rect2(Vector2(0.5, 0.5), s - Vector2.ONE), Color(steel.r, steel.g, steel.b, (0.10 + 0.18 * gp) * _fs_grit), false, maxf(2.0, 2.2 * k * _fs_edge))
	if selected:
		var sp := 0.5 + 0.5 * sin(_t * 3.4)
		draw_rect(Rect2(Vector2(1.5, 1.5), s - Vector2(3.0, 3.0)), Color(1.0, 1.0, 1.0, 0.10 + 0.30 * sp), false, maxf(1.6, 2.0 * k))
		draw_rect(Rect2(Vector2(3.0, 3.0), s - Vector2(6.0, 6.0)), Color(0.62, 0.92, 1.0, 0.08 + 0.34 * sp), false, maxf(1.2, 1.6 * k))
