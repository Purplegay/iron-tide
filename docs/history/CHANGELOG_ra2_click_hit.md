# CHANGELOG —— 点击命中修复（判定几何 = 绘制几何 / WYSIWYG）

日期：2026-10-10
问题：**点建筑/单位的身上（尤其"中间"）点不到，必须精确点在脚底那一小块。**

---

## 1. 根因（已实测确认）

拾取用的是「**以对象原点为圆心的世界空间圆**」：

```gdscript
# 修复前 battle.gd
if p.distance_to(bld.global_position) < bld.radius + 6.0:   # 建筑
var d := p.distance_to(u.global_position)
if d < u.radius + 12.0:                                      # 单位
```

但 RA2 贴图是**从原点往上画**的（`base.y = radius*0.35 - anchor.y*scale`），一栋战车工厂的可见贴图
高度可达 224px，经等距变换后，**贴图"中间"对应的世界点，离原点有 100~280 世界单位远**，
远超 `radius + 6`（战车工厂仅 61）。

实测：`radius+6` 的圆**只覆盖到可见像素的 33.6% ~ 45.2%**（战车工厂 45.2%、矿厂 38.4%、兵营 38.1%、电厂 33.6%）。
→ 于是"点建筑中间"命中率极低，这就是用户反馈的「点击在中间也点不到」。

---

## 2. 修复方案：判定几何 = 绘制几何

新增一层**与绘制同源**的命中工具，把鼠标世界点**反解回绘制空间**，再按**贴图 alpha 逐像素**判定。

### 2.1 `scripts/core/ra2_art.gd`（新增 3 个 static）
- `art_dir(v)` —— 绘制空间向量 → 世界向量（`Iso.dir` 的严格逆：`Vector2(v.x, v.y/K).rotated(Iso.eff_angle())`）。
- `draw_rect(m, radius, frames, lift, sc)` —— 可见精灵矩形（绘制空间），`base.y = radius*0.35 - anchor.y*sc - lift`，与 `_draw_ra2_sprite` 一字不差。
- `draw_center(origin, m, radius, frames, lift, sc)` —— 可见像素中心的世界坐标（拖框/就近判定用）。
- `hits_pixel(world_p, origin, m, radius, frames, frame, lift, sc, alpha_min=20)` —— 世界点 → `Iso.dir(p - origin)` → 落在 `draw_rect` 内 → 映射到图集像素 → `img.get_pixel().a >= alpha_min`。

### 2.2 `scripts/buildings/building.gd`
- 新增 `_art_frame / _art_aframes / _art_sc / _art_lift`，在 `_draw_ra2_sprite()` 结尾**记录本帧真实绘制参数**（SHP 与 VXL 两条分支都记）。
- 新增 `hit_test(world_p) -> bool` / `art_center() -> Vector2`；无 RA2 贴图或未绘制过一帧时退回 `radius + 10` 兜底。

### 2.3 `scripts/units/unit.gd`
- 同上（记录 `frame / aframes / sc / lift`），新增 `hit_test()` / `art_center()`。

### 2.4 `scripts/world/battle.gd`
- `_pick_at()`：单位 → 建筑，均改为 `hit_test()`；**就近判定改用「可见像素中心」** `art_center()`（不再用脚底原点）。
- `_pick_enemy_at()`：同样改 `hit_test()` + `art_center()`（敌方单位若没有方法则退回旧公式，保证健壮）。
- **拖框选择**：由 `get_global_transform_with_canvas().origin`（脚底）改为 `get_viewport().get_canvas_transform() * u.art_center()`（贴图中心），框选手感与视觉一致。

> ℹ️ 记录「本帧绘制参数」而不是在 `hit_test` 里重算，是为了**从机制上杜绝判定与绘制漂移**——绘制什么，就判定什么。

---

## 3. 验证（`iron_tide/_verify_hit.tscn` 有头离屏探针）

对每个对象**遍历整张画布的每一个像素**，比较「`hit_test` 结果」与「该像素的贴图 alpha ≥ 20」：

| 对象 | 画布像素 | 不透明像素 | hit_test 命中 | **mismatch** | 旧半径圆覆盖 |
|---|---|---|---|---|---|
| 建筑/GAWEAP 战车工厂 | 59584 | 12659 | 12659 | **0** | 45.2% |
| 建筑/GAREFN 矿石精炼厂 | 41160 | 8277 | 8277 | **0** | 38.4% |
| 建筑/GAPILE 兵营 | 37000 | 7003 | 7003 | **0** | 38.1% |
| 建筑/GAPOWR 发电厂 | 15620 | 4292 | 4292 | **0** | 33.6% |
| 单位/E1 美国大兵 | 5148 | 239 | 239 | **0** | 110.5% |
| 单位/MTNK 灰熊坦克 | 3542 | 771 | 771 | **0** | 89.4% |
| 单位/CMIN 超时空采矿车 | 4968 | 1568 | 1568 | **0** | 43.5% |

- 另有端到端：在**可见几何中心**点一下 → 7/7 都**正确选中该对象**；
  （战车工厂/矿厂/兵营/电厂/灰熊/矿车：旧判定 = `false`（点不到），新判定 = `true`；大兵因本体小而旧圆偏大，两者皆为 `true`）
- 反例：建筑外 700 世界单位处 `hit_test = false`（不会误选）。
- 截图：`ra2移植_点击命中修复_命中蒙版.png`（绿 = 新命中区，红 = 旧命中区，黄框 = 可见精灵矩形）。
- 无头自检：`--headless --path iron_tide --quit-after 300 res://scenes/battle.tscn` → **stderr 0 字节**。

---

## 4. 影响文件

| 文件 | 改动 |
|---|---|
| `scripts/core/ra2_art.gd` | +`art_dir` / `draw_rect` / `draw_center` / `hits_pixel`（约 +70 行） |
| `scripts/buildings/building.gd` | +4 个记录字段、`_draw_ra2_sprite` 记录绘制参数、+`hit_test` / `art_center` |
| `scripts/units/unit.gd` | 同上 |
| `scripts/world/battle.gd` | `_pick_at` / `_pick_enemy_at` 改像素命中；拖框改用可见像素中心 |
| `_verify_hit.gd` / `_verify_hit.tscn` / `_hit_overlay.gd` | 新增验证探针（可复用，保留） |

未动 `data/**`；未动经济/建造/寻路逻辑。

---

## 5. 铁律落实

> **判定几何 WYSIWYG**：任何"能不能点到/占不占位/选不选中"的判定，都必须走**与绘制同源**的几何；
> 本次把「拾取」从"世界空间圆"改成"绘制空间像素"，并让建筑/单位把**本帧真实绘制参数**暴露出来给判定层复用。
> 新增建筑/单位类型时，只要它走 `_draw_ra2_sprite` 家族，`hit_test` 自动同源，无需再单独调参数。
