# CHANGELOG · 第 7 批：星际2 化视觉（地图质感 / 立体感）

**本轮口令**：用户「可以优化成星际2 的那种感觉，我觉得我们地图和立体感有点太像素风了」

**定位**：不改任何规则、不改任何判定几何，只重做**表现层**。判定几何零变化由 `_probe_v7.gd` 无头自检 20/20 断言背书。

---

## 1. 问题诊断（先量后改）

对第 5 批截图做区域亮度统计（世界区域 x0..1020 / y70..900，步长 3）：

| 指标 | 改造前（第 5 批） | 改造后 |
|---|---|---|
| 地面中位亮度 p50 | **0.112** | 0.274 ~ 0.360 |
| p25 / p75 | 0.106 / 0.112（几乎重合） | 0.245 / 0.340（分出层次） |
| 均值 | 0.161 | 0.272 ~ 0.341 |
| 标准差 sd | — | 0.093 ~ 0.136 |

结论：改造前**地面几乎是纯色**（p25≈p50≈p75，只有两种棋盘格色），加上 80px 硬网格线、扁平多边形障碍、纯色矩形水面 → 观感"平 + 像素 + 廉价"。根因不是「分辨率不够」，而是**地表没有材质、场景没有统一光向、物体没有体积**。

---

## 2. 改动总览

| 文件 | 改动 |
|---|---|
| `scripts/world/ground.gd` | **重写**：程序化岩地（可平铺 fbm + 周期化 Voronoi 岩板 + 岩层脉络 + 颗粒）替代棋盘格；默认不再画网格 |
| `scripts/world/obstacle.gd` | **_draw 重写**：地面轮廓不变，向上挤出岩壁 + 受光顶面 + 顺光接地影（伪 3D 岩台） |
| `scripts/world/water.gd` | **新建 `WaterLayer`**：岸上沙砾 → 岸影（下沉感）→ 三层水色 → 动态波纹 → 岸线泡沫 → 高光 |
| `scripts/world/resource_node.gd` | **_draw 重写**：扁平青色圆盘 → 立体结晶矿簇（受光面/暗面/折射面/尖端高光/地表光晕），结晶数量与高度随储量 k 增减；采空态改为暗淡裸地 + 岩渣 |
| `scripts/core/iso.gd` | `Iso.shadow()` 改**软边**（三层同心椭圆叠加），并作为全局接地影入口 |
| `scripts/units/unit.gd` | 6 处接地影偏移 `Vector2(0, …)` → `Vector2(r*0.34, …)`：与「阳光自左上」统一（原为影子垂直向下，与岩台影子方向矛盾） |
| `scripts/world/building.gd` | 2 处同上（r*0.34） |
| `scripts/ui/post_layer.gd` | **新建 `PostLayer`**：CanvasLayer layer=1（世界 0 之上、HUD 20 之下），只给战场调色，不污染 UI |
| `shaders/post_grade.gdshader` | **新建**：饱和度 / 对比 / 中间调提亮 / 暖高光·冷暗部 / 左上阳光渐变 / 暗角 / 极轻颗粒 |
| `scripts/world/battle.gd` | `_draw_water()` 改为挂载 `WaterLayer`（幂等）；`_process` 里 `_ensure_visual_layers()` 挂载水面层与后期层 |

**未改**：`_pts` 碰撞多边形生成、物理层、寻路 blockers、`water_rects` 逻辑矩形、投影常量、相机、所有规则数据。

---

## 3. 关键技术点

1. **岩板地表（周期化 Voronoi）**：24→15 个站点在 128² 纹理上做**环面距离**评判，得到**边界无缝**的岩石板块；板内色调抖动 + 板缝暗线。纹理覆盖 900 世界像素一张，平铺重复感弱。
2. **各向异性补偿**：相机是 `45° 旋转 + Y×0.5 压扁`，因此纹理采样时 `v × 0.5`（纵向拉伸 2 倍）→ 屏幕上岩板是各向同性的，不会出现"被压扁的花纹"。
3. **岩台挤出但不改判定**：`Iso.begin()` 进入直立空间后，地面点为 `Iso.dir(p)`，顶面点为 `Iso.dir(p) - (0, h)`。挤出只发生在轮廓**上方**，落点轮廓仍等于碰撞多边形 → WYSIWYG 不破。侧壁逐边四边形绘制（避免自相交多边形三角化失败），顶面用**逐顶点着色**做方向渐变（无质心扇 → 无放射状接缝）。
4. **统一光向**：屏幕空间阳光取左上（`SUN = (-0.66,-0.75)`），岩台影子投向右下、单位/建筑接地影同步右偏（`r*0.34`），后期层再加一层左上亮/右下暗的全局渐变。
5. **水面下沉感**：水体外围先铺「沙砾圈 + 两层岸影」，再画水体，最后岸线泡沫呼吸 + 波纹相位推移（`WaterLayer._process` 自驱动 `queue_redraw`，不拖累 battle 的整体重绘）。
6. **性能**：地表纹理一次性生成 **376 ms**（128²，含岩板判定），只画一次；水面/后期各一层。

---

## 4. 验证（可复现）

```powershell
$exe="C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"; $abs=(Resolve-Path "iron_tide").Path
& $exe --headless --path $abs --editor --quit                    # 编译自检 exit=0
& $exe --headless --path $abs --fixed-fps 60 --quit-after 900 res://scenes/battle.tscn
# 无头视觉探针（20 断言）
Start-Process $exe -ArgumentList @("--headless","--path",$abs,"--fixed-fps","60","--quit-after","300","res://_probe_v7.tscn") -RedirectStandardOutput out.txt -NoNewWindow
```

- `_probe_v7`：**20/20 PASS**，`V7PROBE FINAL fails=0` / `VERDICT PASS`
  - 岩体 12/12：碰撞多边形 `_poly.polygon == _pts`（所见轮廓 = 撞得到的体积）、挤出高度 > 0（纯视觉）、物理层仍为 layer 3
  - 矿点：圆形碰撞半径仍 = `radius × 0.85`
  - 视角：`Iso.inv_k() = 2.00`（K=0.50）、相机 zoom=2.0 未动
  - 层次：`WaterLayer.rects` 直接引用逻辑水域、`PostLayer.layer = 1` 且 HUD(20) 在其之上
- 有头离屏截图 5 张（站立/岩台/基地/水面/远景），并做像素统计（见第 1 节表格）

---

## 5. 未做 / 下一步候选（视觉线）

1. **单位与建筑的位图着色**（本批最大遗留）：单位仍是 RA2 位图（黑描边像素），与已成型的 3D 感地表有割裂感。候选方案：
   a. 给位图加 `sprite grade` 着色器（左上受光/右下压暗 + 边缘轮廓光 + 轻微柔化）；
   b. 改走已有矢量画法（`Iso.extrude/box` 一条线）。
2. **地形高度与通行性**：目前岩台只有视觉高度，通行性没有高度概念（`MovementZone`/`SpeedType` 未接）。
3. **地貌内容**：道路 / 河堤 / 装饰岩群 / 水体形状非矩形。
4. **昼夜光照与 EVA 联动**（如低电时压暗）。
5. 已知历史遗留（与本批无关）：`hud.gd::_make_cameo` 打开 cameo 时偶发 `GOREP.png` 大小写不匹配报错。
