# CHANGELOG —— 等距投影真正的根因修复（「拉扯 / 扁」）+ 单位细化

## 一句话

上一轮只关掉了 `Camera2D.ignore_rotation`，把**地平面**变成了正确的菱形，但**立体元素**（单位/建筑/障碍/资源）因为 `Iso.begin()` 的预补偿旋转**符号写反**，被横向压扁/剪切——所以看起来仍然「拉扯、扁」。这一轮把预补偿与相机改成严格互逆，整个画面才真正成立。

## 根因（数学）

- 相机：`C = Zoom(z, z*K) · Rot(-cam_angle())`（`cam_angle()` = 相机 `rotation` = 45°）。
- `Iso.begin()` 进入「直立绘制」空间：`D = Rot(begin_rot) · S(1, 1/K)`。
- 想要 `C · D = S(z, z)`（即：里面画的东西 1:1 直立、按 zoom 缩放），必须满足
  **`begin_rot == +cam_angle()`**，同时 `dir(v)` 的旋转必须是 **`-cam_angle()`**（这样 `dir()` 的结果与「世界向量直接被相机投影」完全一致）。
- 修复前两者符号刚好相反（begin 用 `-a`、dir 用 `+a`），于是 `Rot(-a)·Rot(-a) = Rot(-2a) = Rot(-90°)`：
  - 高度方向 `(0, -h)` 被映射成**水平**方向 → 所有立体元素被横向剪切（坦克变成扁箭头）；
  - 地平面方向被压成约 **5:1** → 阴影/障碍/资源变成又扁又宽的饼。
- 这也解释了修复前的两个症状：地面是轴对齐宽矩形（旋转被吞），而单位/建筑却带 45°——同一处符号错误的正反两面。

## 改动

| 文件 | 改动 |
|---|---|
| `scripts/core/iso.gd` | `begin()` 旋转 `-eff_angle()` → `+eff_angle()`；`dir()` 旋转 `+eff_angle()` → `-eff_angle()`；`extrude()` 侧面轮廓角 `a_l/a_r` 由 `PI-a/TAU-a` 改为 `PI+a/TAU+a`（随 dir 符号同步重推）；`K` 默认 `0.4444 → 0.50`（红警2 标准 2:1）；`preset_index` 默认 `1 → 0`；新增 `USE_YAW` / `toggle_yaw()`（`'` 键：菱形 45° ↔ 轴向对齐俯视）；`preset_label()` 追加「无偏航」 |
| `scripts/world/obstacle.gd` | 删除 `Iso.begin(self)`：地平面多边形必须裸画世界坐标，否则轮廓与 `CollisionPolygon2D` 对不上 |
| `scripts/world/resource_node.gd` | 同上（矿体/晶体轮廓、采集进度环） |
| `scripts/units/unit.gd` | 载具细化：修掉前装甲高光「世界向量直接加到已投影点」的坐标混用错误；新增前顶棱线高光、双侧车灯、尾部排气热光、炮塔尾舱、车体置物箱、备用履带块 |
| `scripts/world/battle.gd` | 新增 `toggle_view_yaw()` |
| `scripts/ui/hud.gd` | `'` 键切换偏航；帮助行补「视角：[ ] 压扁 · ' 菱形/正视 · \ 镜像」 |

## 验证

- 导入：无 Parse Error / SCRIPT ERROR。
- 冒烟：`SMOKE_SUMMARY ok=180 fail=0`（新增 8 项投影不变量用例，其中 `iso_begin_dir_inverse` 直接断言「begin/dir 与相机严格互逆」，`iso_cam_equals_eff` 断言 `cam_angle()==eff_angle()`）。
- 实拍 DIAG：同为世界 Δ(62,0) 的两台坦克，屏幕坐标 Δ 由修复前的 `(131,-59) ≈ 2.22:1` 变为 **`(88,-44)` 精确 2:1**（红警2 标准）。
- 实拍：地面网格、单位、建筑、岩石、资源点全部对齐同一菱形；坦克/步兵「立」了起来。

## 说明：关于「45°」

等距投影的偏航角本就固定 45°（红警2/星际同此定义），决定画面「陡/平」的是俯角压扁系数 K。之前别扭并不是因为「45°」本身，而是那个 45° 被 `begin()` 叠成了 90°。如果确实不想要菱形，可按 `'` 切换成「轴向对齐俯视」。
