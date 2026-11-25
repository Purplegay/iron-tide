# CHANGELOG —— Phase A4/A5/A6 + B2/B3/B4（2026-10-10 第三轮）

> 承接第二轮（阵营涂装自选 + D6/D7）。本轮按 `RA2_PORT_DECISIONS.md` 默认推荐，落地「第一批（推荐，无需新素材）」的 6 项，并补上 A6 所需的原版建造序列素材。

## 一、本轮做了什么

| 阶段 | 内容 | 状态 |
|---|---|---|
| **A4** | 维修厂 `GADEPT` 进驻修理载具（RA2 service depot 语义） | ✅ 已实测 |
| **A5** | 矿点耗尽/缓慢再生 + 采集车自动换矿 | ✅ 已实测 |
| **A6** | 建筑「建造序列」= RA2 原版 `Buildup` SHP（新提取 40 张） | ✅ 已实测 |
| **B2** | 边缘滚屏参数可调（开关 + 速度）+ 新「设置」页 | ✅ 已实测 |
| **B3** | 战术地图雷达事件闪烁（受袭红环 / 建成黄环） | ✅ 已实测 |
| **B4** | 编队热键对齐 ts-ra2（连按两下数字 = 选中并居中） | ✅ 编译通过（无头无法测鼠标连击） |

---

## 二、A6：原版建造序列（含素材管线扩展）

**问题**：`art.ini` 里每个建筑有 `Buildup=<NAME>`，指向**独立 SHP**（如 `GADEPTMK.SHP`）。旧管线只提取了「主体 SHP」和「ActiveAnim/IdleAnim 层」，**没提取 Buildup**，所以上一轮 A6 只能取帧 0 静态。

**做法**：给 `ra2pipe/art_build.mjs` 增加 `buildup` 模式：
```powershell
node ra2pipe/art_build.mjs buildup     # 产出 assets/ra2/shp/<NAME>.png|json，40 张
```
- Buildup SHP 与主体一样**把影子帧追加在后半段**（count 恒为偶数），故取**前半段**作为可见序列：第 0 帧 = 刚放下的空基座，末帧 = 落成。
- 运行时按建造进度取帧：`fi = floor(progress * (count-1))`，**正序**（0→落成）。
- 锚点用**落成帧**，保证完工瞬间与主体贴图同位置，不跳位。
- 顺手修复：`art_build.mjs` 结尾改为**仅 `all` 模式**才写 `ra2_art_index.json`，避免单模式运行覆盖完整清单。

**代码**：`scripts/buildings/building.gd`
- 新增 `var _buildup_art`，`setup()` 里按 `data.buildup` 载入（`RA2Art.has_art/art`）。
- `_draw_ra2_sprite()` 顶部：`if under_construction and _draw_buildup(r): return`。
- 新方法 `_draw_buildup(r)`：按 `build_elapsed/build_total` 取帧绘制 + 影子 + 选中菱形。

---

## 三、A4：维修厂进驻修理（RA2 Service Depot）

**数值全部取自 `rules.ini`**（RA2 是规则唯一事实源）：

| 常量 | 来源 | 值 | 含义 |
|---|---|---|---|
| `REPAIR_STEP` | `[General] RepairStep` | 8 | 每步回血 HP |
| `REPAIR_INTERVAL` | `[General] URepairRate=0.016min` | 0.96 s | 每步间隔 |
| `REPAIR_PERCENT` | `[General] RepairPercent` | 15% | 满修费用占单位造价比例 |

**判定**：运行时建筑数据用 `tags: ["repair"]`（`ra2_allied.json`）；兼容 `buildings.json` 的 `extra.UnitRepair=yes`。故 `REPAIR()` 识别 `GADEPT`（维修厂）。

**流程**：
1. 框选受损载具 → 右键己方维修厂 → `Battle._try_repair_at()` → `Unit.order_repair(depot)`（满血的不派）。
2. 载具开往 `depot.dock_point()`（**占地外侧、最近的正交方位**，避免斜向卡角）；到点后停车。
3. 维修厂 `_process_repair()` 每 `0.96s` 对停在**占地旁**（`footprint_radius()+80`）的载具回 8 HP，并按 `造价×15%/max_hp × 回血量` 扣钱（资金不足则暂停）；播放 `SpecialAnim`（吊臂）。
4. 满血 → 自动驶离停机位，让位给下一辆。

**关键坑（已修）**：`_process_repair()` 起初忘了调 `move_and_slide()` → 载具纹丝不动，维修厂因距离判定一直跳过。补上 `move_and_slide()` 后闭环。

---

## 四、A5：矿点耗尽 / 再生 / 采集车换矿

- `scripts/world/resource_node.gd`：**采空不再 `queue_free()`**，改为留在地图上以暗淡裸地呈现，并按 `REGEN_FRACTION=0.02`（约 50s 回满）缓慢再生；新增 `is_empty()`。
- `scripts/units/unit.gd`：新增 `_node_ok(n, min_frac)` 与 `_nearest_ore_node(min_frac)`；采集状态机在「矿点空了」时**立即改投最近的非空矿点**，附近全空则先把已有货送回。

---

## 五、B2：边缘滚屏可调 + 新「设置」页

- `scripts/autoload/meta_progress.gd`：新增 `edge_scroll: bool`、`scroll_speed: int`(10..100)、`subtitles: bool`；`scroll_px_per_sec()`（以 **RA2 基准 780 px/s = 50 档**线性缩放）；读写存档 + `set_*()` 即落盘。
- `scripts/world/battle.gd`：`_ready()` 读取设置 → `edge_scroll_enabled` / `cam_speed`。
- 新建 `scripts/screens/settings_screen.gd` + `scenes/settings.tscn`：边缘滚屏开关 / 速度滑条 / 事件字幕；主菜单新增「设 置」按钮（box 540→600）。

---

## 六、B3 / B4

- **B3**：`Events` 新增 `signal radar_ping(world_pos, kind)` + `emit_radar_ping()`；`unit.gd`/`building.gd` 受袭时发 `attack`，建筑**建成**时发 `ready`；`minimap.gd` 入队并**闪烁扩散淡出**（受袭红环 / 建成黄环）。
- **B4**：`hud.gd` 数字键处理：**连按两下同一编队数字（≤400ms）= 选中并居中**（对齐 ts-ra2；保留 Alt+数字）。

---

## 七、验证证据（无头探针，24/24 PASS，`FAIL=0`）

```
OK   battle ready
OK   A5 ore nodes>=4        n=6
OK   A5 regen > 0           amount=77.9
OK   A5 not freed
OK   A5 harvester exists
OK   A5 skip empty node
OK   A4 depot placed
OK   A4 depot is_repair
OK   A4 tank spawned
OK   A4 repairing flag
OK   A4 hp increased        389.0 -> 405.0 / 405.0
OK   A4 funds spent         100000.0 -> 99995.4   （涓流已关，纯扣费）
OK   A4 fully repaired
OK   A4 auto eject
OK   A6 placed
OK   A6 under construction
OK   A6 buildup loaded      key=GAPOWRMK
OK   A6 buildup frames>=5   count=25
OK   A6 frame0 != frameN
OK   B2 base 780px/s
OK   B2 battle cam_speed
OK   B2 edge flag synced
OK   B2 speed100=1560
OK   B3 ping queued
OK   B3 ping expired
FAIL=0
```
- 战斗场景无头 300 帧：**exit 0，stderr 仅 Godot 横幅**。
- 截图：建造序列三档进度 / 维修厂进驻 / 设置页（见随附 PNG）。

## 八、已知遗留（非本轮回归）

- 维修厂 `SpecialAnim`（吊臂）在提取的 bldanim 层里**层偏移为 0**，实拍中吊臂相对主体略偏；属 bldanim 层偏移未逐层校对的既有问题，机械逻辑不受影响。
- 玩家选「战火红」时血条告警可读性下降（待描边）；建造预览/选中框仍靠同色相一并重映射。
