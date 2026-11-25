class_name DecalLayer
extends Node2D
## 战损贴花层（第 8 批）：地面灼痕 / 弹坑。
##
## 规则口径来自 [Warhead] 的 Deform= / DeformThreshhold=（RA2 真实字段），
## 由 Ra2Fx.spawn_scorch() 决定要不要落、落多大；本文件只负责画。
##
## 铁律：不参与任何碰撞 / 判定，纯粹是「画在地上的一层脏」。
## 画法：与 WaterLayer 一致 —— 地平面元素「裸画」世界坐标，不调 Iso.begin()，
##       交给相机做 45° 旋转 + K 压扁，自动得到等距贴地形状。
## z_index = DepthLayers.DECAL：贴地，低于一切实体（水面上、单位下）。

## 上限（RA2 对单元格 smudge 有数量上限，这里取一个够用又不掉帧的值）
const MAX_DECALS := 140

var _decals: Array = []


func add_scorch(pos: Vector2, radius: float, strength: float) -> void:
	if radius <= 0.0:
		return
	_decals.append({
		"pos": pos,
		"r": radius,
		"k": clampf(strength, 0.15, 1.0),
		"seed": randi(),
	})
	if _decals.size() > MAX_DECALS:
		_decals.pop_front()
	queue_redraw()


func count() -> int:
	return _decals.size()


func clear_all() -> void:
	_decals.clear()
	queue_redraw()


func _draw() -> void:
	for d in _decals:
		var c: Vector2 = d["pos"]
		var r: float = d["r"]
		var k: float = d["k"]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(d["seed"])
		# 外圈焦褐：8 个偏移圆叠出不规则边（不用多边形，避开三角化失败）
		for i in 8:
			var a := TAU * float(i) / 8.0 + rng.randf_range(-0.18, 0.18)
			var off := Vector2(cos(a), sin(a)) * r * rng.randf_range(0.28, 0.46)
			draw_circle(c + off, r * rng.randf_range(0.32, 0.44), Color(0.105, 0.090, 0.075, 0.26 * k))
		# 内核焦黑
		draw_circle(c, r * 0.32, Color(0.052, 0.046, 0.040, 0.40 * k))
		# 少量残留余烬（暖色微点）
		for i in 3:
			var a2 := rng.randf() * TAU
			var p2 := c + Vector2(cos(a2), sin(a2)) * r * rng.randf_range(0.10, 0.30)
			draw_circle(p2, r * 0.05, Color(0.30, 0.16, 0.08, 0.22 * k))
