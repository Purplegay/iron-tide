class_name Placement
extends RefCounted
## RA2 式占点/占地判定工具（凸多边形几何）。
## 所有几何都在「地面空间」= 世界坐标 = 建筑节点局部坐标里做，
## 因为建筑节点的局部坐标就是地面坐标（等距投影由相机完成，见 Iso）。

const EPS := 0.0001


## 多边形（可带偏移）的轴对齐包围盒
static func aabb(poly: PackedVector2Array, off: Vector2 = Vector2.ZERO) -> Rect2:
	if poly.is_empty():
		return Rect2(off, Vector2.ZERO)
	var mn := poly[0]
	var mx := poly[0]
	for p in poly:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	return Rect2(mn + off, mx - mn)


## 两个包围盒之间的间距（相交时为 0；用切比雪夫距离，够用来做 RA2 邻接判定）
static func aabb_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), 0.0)
	var dy := maxf(maxf(b.position.y - a.end.y, a.position.y - b.end.y), 0.0)
	return maxf(dx, dy)


## 点在凸多边形内（顶点需同向；含边界）
static func point_in_poly(poly: PackedVector2Array, p: Vector2) -> bool:
	if poly.size() < 3:
		return false
	var sgn := 0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var c := (b - a).cross(p - a)
		if absf(c) < EPS:
			continue
		var s := 1 if c > 0.0 else -1
		if sgn == 0:
			sgn = s
		elif s != sgn:
			return false
	return true


## 点到线段的距离
static func seg_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < EPS:
		return (p - a).length()
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (p - (a + ab * t)).length()


# Conservative native broad phase. Inclusive edge contact matches circle_hits_poly.
static func circle_hits_rect(rect: Rect2, center: Vector2, radius: float) -> bool:
	var bounds := rect.grow(EPS)
	return center.distance_squared_to(center.clamp(bounds.position, bounds.end)) <= radius * radius


## 圆 与 凸多边形 是否相交（圆心在内 / 任一近边）
static func circle_hits_poly(poly: PackedVector2Array, c: Vector2, r: float, off: Vector2 = Vector2.ZERO) -> bool:
	if poly.size() < 3:
		return false
	if point_in_poly(poly, c - off):
		return true
	for i in poly.size():
		var a := poly[i] + off
		var b := poly[(i + 1) % poly.size()] + off
		if seg_dist(a, b, c) <= r:
			return true
	return false


## 两个凸多边形（各自带世界偏移）是否重叠；pad>0 时表示「间距 ≤ pad 也算重叠」
static func polys_overlap(pa: PackedVector2Array, oa: Vector2, pb: PackedVector2Array, ob: Vector2, pad: float = 0.0) -> bool:
	if pa.size() < 3 or pb.size() < 3:
		return false
	if not aabb(pa, oa).grow(pad).intersects(aabb(pb, ob).grow(pad)):
		return false
	var axes: Array = []
	for i in pa.size():
		var e := pa[(i + 1) % pa.size()] - pa[i]
		axes.append(Vector2(-e.y, e.x).normalized())
	for i in pb.size():
		var e := pb[(i + 1) % pb.size()] - pb[i]
		axes.append(Vector2(-e.y, e.x).normalized())
	for ax in axes:
		var amin := INF
		var amax := -INF
		for p in pa:
			var d := (p + oa).dot(ax)
			amin = minf(amin, d)
			amax = maxf(amax, d)
		var bmin := INF
		var bmax := -INF
		for p in pb:
			var d := (p + ob).dot(ax)
			bmin = minf(bmin, d)
			bmax = maxf(bmax, d)
		if amax < bmin - pad or bmax < amin - pad:
			return false
	return true


## 把多边形沿「离开中心」方向推出一个圆（用于建筑落成后把卡住的单位挤出来）
static func push_out_dir(poly: PackedVector2Array, c_local: Vector2, c_world: Vector2, from: Vector2) -> Vector2:
	if poly.size() < 3 or not point_in_poly(poly, c_local):
		return Vector2.ZERO
	var best_d := INF
	var best_p := c_world
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var p := a + (b - a) * clampf((c_local - a).dot(b - a) / maxf((b - a).length_squared(), EPS), 0.0, 1.0)
		var d := c_local.distance_to(p)
		if d < best_d:
			best_d = d
			best_p = p + c_world
	return best_p
