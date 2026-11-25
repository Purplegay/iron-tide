# 本轮变更：碰撞体积（Collision Volumes）

日期：2026-10-09

## 问题
此前工程里只有「寻路阻挡 + 软避让（steering）」和单位/建筑的基础圆形碰撞体，**障碍岩体与资源矿点完全没有物理碰撞体积**：
- `obstacle.gd` 是 `Node2D`，没有 StaticBody / CollisionShape，单位靠 `_avoid_obstacles` 软推挤，速度快或成群时仍会「穿石而过」；
- `resource_node.gd` 是 `Node2D`，单位可整块压进结晶矿里；
- `Unit` 未设置 `motion_mode`，Godot 4 默认 `MOTION_MODE_GROUNDED`，在俯视 2D 场景语义错误（贴碰撞体时倾向「卡住」而非顺滑绕行）。

## 改动
| 文件 | 改动 |
|---|---|
| `scripts/world/obstacle.gd` | `Node2D` → `StaticBody2D`；新增 `_build_points()` / `_build_body()` / `collision_radius()`。碰撞多边形与 `_draw` **共用同一组顶点**，保证「看到的轮廓 = 撞得到的体积」。`collision_layer = 4`（layer 3 障碍层），`collision_mask = 0`。 |
| `scripts/world/resource_node.gd` | `Node2D` → `StaticBody2D`；新增 `_build_body()`，圆形碰撞体半径 = `radius × 0.85`（避开外圈光晕的虚胖碰撞）。`collision_layer = 4`，`collision_mask = 0`。 |
| `scripts/units/unit.gd` | `_apply_physics()` 增加 `motion_mode = MOTION_MODE_FLOATING`，俯视 RTS 的正确运动模式。 |
| `scripts/world/battle.gd` | `build_spot_ok()` 增加两项落点校验：不得压在地面单位上（`ground_units`）、不得压在资源点上（`resource_nodes`），避免新建建筑把单位卡死。 |

## 层次划分（沿用既有约定）
- layer 1 = 地面单位（`collision_mask = 1|2|4`）
- layer 2 = 建筑 / 生产设施（静态）
- layer 3（数值 4）= 障碍岩体 + 资源矿点（静态）→ 地面单位被阻挡，**空中单位（layer 8）飞越不受影响**
- layer 4（数值 8）= 空中单位

## 兼容性
- 障碍物仍保留 `radius` 字段并仍加入 `obstacles` 组，寻路阻挡（`radius + 12`）与 `_avoid_obstacles` 行为不变。
- 矿点碰撞半径 `radius × 0.85 = 28.9`，采集车停靠距离 52 > 28.9 + 车身 12，采集流程不受影响。
- `Obstacle` / `ResourceNode` 均为 `Node2D` 子类，`Iso.begin(self)` 绘制逻辑不变。

## 验证
- 逐文件 `--check-only`：无新增语法错误。
- `-Stage import`：无 Parse Error / SCRIPT ERROR / Failed to load。
- `-Stage smoke`：**ok=122 fail=0**（上一轮 109，本轮 +13 项碰撞回归）。
  新增：`coll_obstacle_exists / coll_resource_exists / coll_obstacle_body / coll_obstacle_shape /
  coll_resource_body / coll_resource_shape / coll_unit_floating / coll_unit_mask_obstacle /
  coll_unit_shape / coll_query_hits_obstacle / coll_query_hits_resource / coll_query_hits_unit /
  coll_unit_blocked_by_resource`
  - 前 12 项为结构与 `PhysicsDirectSpaceState2D.intersect_point()` 点查询，直接证明碰撞体已注册进物理世界。
  - 最后一项为行为验证：命令单位撞向矿心，100 物理帧内最近中心距必须 > 矿体碰撞半径 × 0.9。
- `-Stage shot`：`DIAG collide rock_min=70.6 rock_radius=62.0 ore_min=53.1 ore_radius=46.0`。
  - `ore_min = 53.1 = 46 × 0.85（矿体碰撞半径 39.1）+ 14（坦克碰撞半径）`，即单位精确停在矿体外缘切点上——这是物理碰撞体积生效的直接证据。
