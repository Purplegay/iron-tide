class_name DepthLayers
extends RefCounted
## 等距深度分层（全工程唯一的 z_index 事实源）。
##
## 背景：本工程相机 = 45° 旋转 + 纵向压扁(K=0.5)。实测（M9 探针）投影为
##   screen_x ∝ (x + y)   screen_y ∝ (y − x)
## 即「屏幕上越往下 = 越靠近观察者」对应世界量 **(y − x)**。
## 因此等距遮挡的正确排序键 = world.y − world.x（越大越靠前、越后绘制）。
## 纯按世界 y 排序（Godot y_sort 的默认口径）在 45° 等距下是错的。
##
## 做法：把移动实体（单位/建筑）的 z_index 由深度键线性映射到一条宽带。
## 关键点：整条实体带取 **正值**（≥1），这样实体恒压在 Battle 自身绘制
## （框选矩形 / 建造预览 / 航点，都在 z=0）之上——与旧行为一致；
## 否则带跨过 0 时，Battle 的 overlay 会反过来盖住远处实体。
##
## 常量均为「绝对 z_index」，写节点时配 z_as_relative=false 或挂在 z=0 的父下。

## —— 带下静态层（恒在所有实体之下，且低于 Battle overlay）——
const GROUND := -4000      # 地面
const WATER := -3900       # 水面
const BRIDGE_DECK := -3701 # Above passing ships and water, below surface traffic.
const DECAL := -3800       # 焦痕贴花（贴地）
const GROUND_OBJ := -3700  # 障碍 / 矿点（地面物，恒在地面实体之下）

## —— 实体深度带 = [1, 2*DEPTH_HALF + 1] ——
## 世界坐标范围 [0, map_size] ⇒ 深度键 ∈ [−map_size, +map_size]。
## 以 map_size 归一化后落在 ±DEPTH_HALF，再加 DEPTH_OFFSET 抬为正区间。
const DEPTH_HALF := 1900.0
const DEPTH_OFFSET := 1901 # = int(DEPTH_HALF) + 1 → 实体 z ∈ [1, 3801]

## —— 带上层（恒在所有实体之上）——
const AIR := 3820         # Airborne units clear the ground entity band; landed aircraft use ground depth.
const WORLD_HUD := 3850   # 血条/名称标签 overlay：恒盖在所有实体（含建筑）之上，低于弹道/特效
const PROJECTILE := 3900   # 弹体
const FX := 3950           # 特效（炮口火光 / 命中动画；宿主 Effects._host()=effects_root）
const ORDER_PREVIEW := 4091 # 自己已下达的命令高于迷雾（4090），不揭露地形或敌人。

## 按当前镜头的屏幕向下轴投影。标准 45° 下等价于 y − x。
static func entity_z(pos: Vector2, map_size: float) -> int:
	var axis := Vector2.DOWN.rotated(Iso.eff_angle())
	var center := Vector2.ONE * map_size * 0.5
	var extent := projection_extent(axis, map_size)
	return projected_z(pos, axis, center, extent)

static func projection_extent(axis: Vector2, map_size: float) -> float:
	return maxf(1.0, (absf(axis.x) + absf(axis.y)) * map_size * 0.5)

static func projected_z(pos: Vector2, axis: Vector2, center: Vector2, extent: float) -> int:
	var depth := (pos - center).dot(axis) / extent
	return DEPTH_OFFSET + roundi(clampf(depth, -1.0, 1.0) * DEPTH_HALF)
