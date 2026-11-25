class_name Iso
extends RefCounted
## 红警2 式等距（2:1 dimetric）投影工具。
##
## 相机 = rotation(ANGLE=45°) + 非均匀 zoom(z, z*K)：
##   世界地平面被旋转 45° 并纵向压扁 -> 菱形网格。
##   RA2 的地图投影为 screen = ( (x-y)*30, (x+y)*15 )，即 K = 15/30 = 0.5；
##   取 K=0.5 时本工程与 RA2 的 IsoMapPack 投影**逐像素一致**（地块 60x30）。
## 「立起来」的实体在各自 _draw 顶部调用 begin()，抵消相机的旋转+压扁，
##   使其 1:1 直立绘制（地面方向用 dir()，高度直接用 (0, -h)）。
## 地平面元素（地面/障碍/资源/阴影/占地/半径环）不要补偿，
##   直接按世界坐标画即可被相机正确投影成菱形。
## 重要：begin() 与 dir() 的旋转必须**符号相反**且同用一个 eff_angle()，
##   否则旋转会被叠成 2a，实体被横向压扁/剪切（表现为「拉扯」）。

## 纵向压扁系数（camera.zoom.y / camera.zoom.x）。0.5 = RA2 标准 2:1（默认）。
static var K: float = 0.5
## 45° 等距旋转角
static var ANGLE: float = 0.7853981633974483
## 镜像：翻转 45°（南北视觉互换，只影响观感不影响逻辑）
static var MIRROR: bool = false
## 预设：名字里的比值 = 1/K（屏幕宽 : 高的菱形比例）
static var PRESETS: Array = [
	{ "name": "红警2 标准 2:1", "k": 0.5 },
	{ "name": "略平视 2.25:1", "k": 0.4444 },
	{ "name": "平视 2.5:1", "k": 0.4 },
	{ "name": "平视 2.8:1", "k": 0.3571 },
	{ "name": "略俯视 1.8:1", "k": 0.5556 },
	{ "name": "斜视 1.6:1", "k": 0.625 },
	{ "name": "高俯视 1.4:1", "k": 0.7143 },
]
static var preset_index: int = 0

static func inv_k() -> float:
	return 1.0 / maxf(0.05, K)

## 是否启用等距偏航（45° 菱形网格）。关掉则变成轴向对齐的俯视 + 纵向压扁。
static var USE_YAW: bool = true

## 生效的旋转角（含镜像 / 偏航开关）
static func eff_angle() -> float:
	if not USE_YAW:
		return 0.0
	return -ANGLE if MIRROR else ANGLE

static func cam_zoom(z: float) -> Vector2:
	return Vector2(z, z * K)

static func cam_angle() -> float:
	return eff_angle()

## 世界地平面向量 -> 本地绘制空间方向（含旋转 + 纵向压扁，不含缩放）。
## 本函数与 begin() 是一对互逆变换：必须用同一个 eff_angle()，
## 符号相反（dir 用 -a、begin 用 +a），否则会把旋转叠成 2a 而把画面压扁。
static func dir(v: Vector2) -> Vector2:
	var r: Vector2 = v.rotated(-eff_angle())
	return Vector2(r.x, r.y * K)

## 进入「直立绘制」空间。
## 相机变换是 S(z, z*K) * Rot(-eff_angle())；本变换取 Rot(eff_angle()) * S(1, 1/K)，
## 二者相乘恰好 = S(z, z)：所以这里屏幕向下就是 +y，屏幕向上就是 -y，
## 地面方向用 dir(v)，高度直接用 (0, -h)。
## 注意：地平面元素（地面/障碍/资源）应“裸画”世界坐标，不要进 begin()。
static func begin(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, eff_angle(), up())

static func up() -> Vector2:
	return Vector2(1.0, inv_k())

# ------------------------------------------------------------ 视角预设

static func set_preset(i: int) -> String:
	preset_index = wrapi(i, 0, PRESETS.size())
	K = float(PRESETS[preset_index]["k"])
	return preset_label()

static func next_preset() -> String:
	return set_preset(preset_index + 1)

static func set_k(v: float) -> String:
	K = clampf(v, 0.2, 1.2)
	preset_index = -1
	return preset_label()

static func toggle_mirror() -> String:
	MIRROR = not MIRROR
	return preset_label()

static func toggle_yaw() -> String:
	USE_YAW = not USE_YAW
	return preset_label()

static func preset_label() -> String:
	var nm := "自定义"
	if preset_index >= 0 and preset_index < PRESETS.size():
		nm = str(PRESETS[preset_index]["name"])
	var extra := ""
	if MIRROR:
		extra += " 镜像"
	if not USE_YAW:
		extra += " 无偏航"
	return "%s K=%.2f%s" % [nm, K, extra]

## 把当前投影应用到相机（z <= 0 时沿用相机现有 zoom.x）
static func apply_to(cam: Camera2D, z: float = -1.0) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	var zz := z
	if zz <= 0.0:
		zz = cam.zoom.x
	cam.zoom = cam_zoom(zz)
	# Godot 4 的 Camera2D 默认 ignore_rotation=true，会直接丢弃 rotation，
	# 导致等距投影失效（地面不旋转被压扁、其它元素却旋转 45°，画面被"拉扯"）。
	# 这里必须显式关闭，rotation 才会真正进入画布变换。
	cam.ignore_rotation = false
	cam.rotation = cam_angle()

# ------------------------------------------------------------ 地平面图形

## 地平面上的椭圆（中心 center，地面半轴 rx/ry）投影为屏幕多边形
static var _circle_vertices: Dictionary = {}

static func unit_circle(n: int) -> PackedVector2Array:
	if not _circle_vertices.has(n):
		var points := PackedVector2Array()
		for i in range(n):
			points.append(Vector2.from_angle(TAU * float(i) / float(n)))
		_circle_vertices[n] = points
	return _circle_vertices[n]

static func ell(center: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var projection := Transform2D(dir(Vector2(rx, 0)), dir(Vector2(0, ry)), center)
	return projection * unit_circle(n)

## Raw world-ground circle. Use outside begin(); the camera performs projection once.
static func ground_circle(center:Vector2,radius:float,n:int=96) -> PackedVector2Array:
	return Transform2D(Vector2(radius,0),Vector2(0,radius),center)*unit_circle(n)

static func outline(ci: CanvasItem, poly: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	if poly.size() < 2:
		return
	var closed := PackedVector2Array(poly)
	closed.append(poly[0])
	ci.draw_polyline(closed, color, width, true)

## 地面投影阴影（rx = 地面半轴，调用方直接给阴影半宽，内部不再放大）
## (第 7 批) 软边：三层同心椭圆叠加，避免「硬边黑饼」，接近星际2 的柔和接地影。
static var _shadow_mesh: ArrayMesh

static func shadow_mesh() -> ArrayMesh:
	if _shadow_mesh != null: return _shadow_mesh
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var circle := unit_circle(24)
	for layer in range(3, 0, -1):
		var t := float(layer) / 3.0
		var scale := 0.70 + 0.30 * t
		var begin_index := vertices.size()
		for point in circle:
			vertices.append(Vector3(point.x * scale, point.y * scale, 0))
			colors.append(Color(1,1,1,0.26 + 0.24 * t))
		for i in range(1, circle.size()-1):
			indices.append_array(PackedInt32Array([begin_index,begin_index+i,begin_index+i+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_shadow_mesh = ArrayMesh.new()
	_shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _shadow_mesh

static func shadow(ci: CanvasItem, center: Vector2, rx: float, alpha: float = 0.28) -> void:
	# Reuse triangulation while retaining all three layers and their original opacity.
	var projection := Transform2D(dir(Vector2(rx,0)),dir(Vector2(0,rx)),center)
	ci.draw_mesh(shadow_mesh(),null,projection,Color(0,0,0,alpha))

static func _arc(center: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(center + dir(Vector2(cos(a) * rx, sin(a) * ry)))
	return pts

# ------------------------------------------------------------ 立体

## 竖直圆柱体：底面与顶面都投影成菱形椭圆，返回顶面中心
static func extrude(ci: CanvasItem, center: Vector2, rx: float, h: float, body: Color, top: Color, n: int = 18) -> Vector2:
	var a := eff_angle()
	var cap_center := center + Vector2(0.0, -h)
	# 屏幕最左/最右点对应的地面角（由 screen_x = cos(theta - a) 推导，镜像自动成立）
	var a_l := PI + a
	var a_r := TAU + a
	var sil := PackedVector2Array()
	# 底：从左沿「下弧」到右
	var lower := _arc(center, rx, rx, a_l, a_r - TAU, n)
	# 顶：从右沿「上弧」回到左
	var upper := _arc(cap_center, rx, rx, a_r, a_l, n)
	sil.append_array(lower)
	sil.append_array(upper)
	if sil.size() >= 3:
		ci.draw_colored_polygon(sil, body)
	var top_poly := ell(cap_center, rx, rx, n * 2)
	ci.draw_colored_polygon(top_poly, top)
	outline(ci, top_poly, body.darkened(0.45), 1.0)
	return cap_center

## 竖直长方体（等距盒）：footprint = 地面矩形 w×d，高 h。返回顶面中心
static func box(ci: CanvasItem, center: Vector2, w: float, d: float, h: float, body: Color, top: Color) -> Vector2:
	var hw := w * 0.5
	var hd := d * 0.5
	var ground := [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]
	var base := PackedVector2Array()
	for c in ground:
		base.append(center + dir(c))
	var upv := Vector2(0.0, -h)
	var top_poly := PackedVector2Array()
	for p in base:
		top_poly.append(p + upv)
	# 侧面：只画朝前的两面（面中点位于中心屏幕下方）
	for i in range(4):
		var a := base[i]
		var b := base[(i + 1) % 4]
		var mid := (a + b) * 0.5
		if mid.y > center.y:
			var ta := top_poly[i]
			var tb := top_poly[(i + 1) % 4]
			ci.draw_colored_polygon(PackedVector2Array([a, b, tb, ta]), body.darkened(0.08))
	ci.draw_colored_polygon(top_poly, top)
	outline(ci, top_poly, body.darkened(0.5), 1.0)
	return center + upv
