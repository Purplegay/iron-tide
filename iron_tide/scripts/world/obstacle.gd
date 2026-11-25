extends StaticBody2D
class_name Obstacle
## 静态掩体 / 岩体。阻挡地面单位通行。
##
## 碰撞体积：StaticBody2D + CollisionPolygon2D，顶点与 _draw 的「地面轮廓」完全相同
## → 看到的岩石落点轮廓 = 撞得到的碰撞体积（WYSIWYG）。
## 物理层 = layer 3（数值 4）；空中单位（layer 8）飞越不受影响。
##
## 绘制（第 7 批 视觉升级）：地面轮廓保持不变，向上（屏幕 -Y）拉出岩壁 + 受光顶面
## → 伪 3D 高台。挤出只发生在轮廓上方，不改变任何判定几何。

const SUN := Vector2(-0.66, -0.75)        # 阳光方向（屏幕空间，自左上）
const SUN_SHADOW := Vector2(0.46, 0.30)   # 影子的地面偏移比例

const COL_WALL := Color(0.150, 0.148, 0.150)
const COL_WALL_DARK := Color(0.086, 0.084, 0.090)
const COL_TOP := Color(0.372, 0.362, 0.344)
const COL_TOP_LIT := Color(0.470, 0.462, 0.446)

var radius: float = 46.0
var _seed: int = 0
var _pts: PackedVector2Array = PackedVector2Array()
var _poly: CollisionPolygon2D = null
var _h: float = 24.0
var _speckles: Array = []

func _ready() -> void:
	add_to_group("obstacles")
	_seed = int(global_position.x) * 7 + int(global_position.y) * 13
	_build_points()
	_build_body()
	_build_profile()
	queue_redraw()

## 轮廓顶点（绘制与碰撞共用）。半径抖动控制在 0.88~1.06 保证多边形凸性，
## 避免 draw_polygon 三角化失败，同时保留手绘岩石的随机感。
func _build_points() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_pts = PackedVector2Array()
	var n := 11
	for i in range(n):
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.05, 0.05)
		var rr := radius * rng.randf_range(0.88, 1.06)
		_pts.append(Vector2(cos(a), sin(a)) * rr)

func _build_profile() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 991
	_h = clampf(radius * rng.randf_range(0.28, 0.44), 10.0, 28.0)
	_speckles.clear()
	var c := _centroid()
	for i in range(8):
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.12, 0.66) * radius
		_speckles.append({
			"p": c + Vector2(cos(a), sin(a)) * d,
			"r": rng.randf_range(0.09, 0.20) * radius,
			"a": rng.randf_range(0.05, 0.11),
		})

func _centroid() -> Vector2:
	var c := Vector2.ZERO
	for p in _pts:
		c += p
	return c / float(maxf(1.0, float(_pts.size())))

func _build_body() -> void:
	collision_layer = 4
	collision_mask = 0
	if _poly == null:
		_poly = CollisionPolygon2D.new()
		_poly.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		add_child(_poly)
	_poly.polygon = _pts

func collision_radius() -> float:
	var m := 0.0
	for p in _pts:
		m = maxf(m, p.length())
	return m

func visual_height() -> float:
	return _h

func _draw() -> void:
	if _pts.is_empty():
		_build_points()
	if _speckles.is_empty():
		_build_profile()

	Iso.begin(self)
	var base := PackedVector2Array()
	for p in _pts:
		base.append(Iso.dir(p))
	var top := PackedVector2Array()
	for p in base:
		top.append(p - Vector2(0.0, _h))

	# 1) 地面接触阴影（左下方向外扩 + 右下偏移，三层软边）
	var so := Vector2(_h, _h) * SUN_SHADOW
	for i in range(3, 0, -1):
		var k := 1.0 + 0.05 * float(i)
		var sh := PackedVector2Array()
		for p in base:
			sh.append(p * k + so * (1.0 + 0.14 * float(i)))
		draw_colored_polygon(sh, Color(0.02, 0.024, 0.038, 0.105))

	# 2) 岩壁：逐边四边形，按边法线决定明暗（左下侧受光较亮，右上/正面更暗）
	var n_edges := base.size()
	for i in n_edges:
		var j := (i + 1) % n_edges
		var mid := (base[i] + base[j]) * 0.5
		var nrm := (mid - Iso.dir(_centroid())).normalized()
		var lit := clampf(nrm.dot(SUN) * 0.5 + 0.5, 0.0, 1.0)
		var col := COL_WALL_DARK.lerp(COL_WALL, lit)
		draw_colored_polygon(
			PackedVector2Array([base[i], base[j], top[j], top[i]]), col)
		# 竖向纹理
		draw_line(base[i].lerp(base[j], 0.5), top[i].lerp(top[j], 0.5),
			Color(0.196, 0.190, 0.186, 0.40), 1.0)

	# 3) 顶面：逐顶点着色的方向渐变（无质心扇 → 不会出现放射状接缝）
	var grad_pts := PackedVector2Array()
	var grad_cols := PackedColorArray()
	var c_top := Iso.dir(_centroid()) - Vector2(0.0, _h)
	for i in top.size():
		var p := top[i]
		grad_pts.append(p)
		var lit2 := clampf(0.5 - (p - c_top).normalized().dot(SUN) * 0.5, 0.0, 1.0)
		# 顶点色调抖动 → 顶面不平整，像真石面而非矢量光盘
		var jit := (float((_seed + i * 37) % 13) / 13.0 - 0.5) * 0.11
		grad_cols.append(COL_TOP * (0.74 + 0.62 * lit2) + Color(jit, jit, jit))
	draw_polygon(grad_pts, grad_cols)

	# 4) 顶面碎石
	for s in _speckles:
		draw_circle(Iso.dir(s["p"]) - Vector2(0.0, _h), s["r"], Color(0.058, 0.064, 0.078, s["a"]))
	# 顶面边缘暗环（让顶面收边）
	var ring := top.duplicate()
	ring.append(top[0])
	draw_polyline(ring, Color(0.055, 0.061, 0.074, 0.75), 2.4)

	# 5) 底面暗描边 + 迎光侧亮沿
	var closed_base := base.duplicate()
	closed_base.append(base[0])
	draw_polyline(closed_base, Color(0.026, 0.031, 0.042, 0.85), 1.4)
	var rim := PackedVector2Array()
	for i in top.size():
		var a := top[i]
		var b := top[(i + 1) % top.size()]
		var nr := (b - a).normalized().orthogonal()
		if nr.dot(SUN) > 0.25:
			rim.append(a)
			rim.append(b)
	if rim.size() >= 2:
		draw_polyline(rim, Color(0.42, 0.48, 0.56, 0.60), 1.3)
