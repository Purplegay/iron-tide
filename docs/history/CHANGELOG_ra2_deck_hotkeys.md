# 变更日志：红警2 热键对齐 + 底部指令甲板（SidebarCard/Tabs 落地）

日期：2026-10-09
范围：`scripts/ui/hud.gd`、`scripts/world/battle.gd`、`scripts/buildings/building.gd`

## 1. 底部指令甲板（把生产区从右栏挪到底部）

- 生产面板（`prod_panel`）由右上栏改为**底部指令甲板**：
  - 锚点 `PRESET_BOTTOM_WIDE`，`left=340 / right=-660 / top=-242 / bottom=-10`，
    位于小地图（左）与选中条（右）之间，宽约 600。
  - 结构：标题行（`指令甲板 · <页签>`）+ **红警2 四页签** + `ScrollContainer` 内容网格 + 页脚进度。
- 右侧栏 `ra_rail` 现只保留**选中信息 + 指令网格**，生产不再占位。
- `build_panel`（旧建造浮层）停用，建筑/防御改由甲板页签承载，与红警2 侧栏一致。

### 页签与分类（对齐红警2 侧栏语义）

| 页签 | 热键 | 内容 |
|---|---|---|
| 建筑 | Q | 非防御建筑目录（兵营/战争工厂/空军基地…），点击进入放置模式 |
| 防御 | W | 防御建筑目录（棱镜塔/防空…） |
| 步兵 | E | 可生产步兵（自动路由到兵营） |
| 载具 | R | 可生产载具/空军/支援（自动路由到工厂/空军基地） |

- `_building_catalog()`：按 `GameData.buildings_for_faction("allied")` 的 `tags` 分类（`defense` / 非 `hq` 且有造价）。
- `_unit_catalog()`：汇总所有我方生产建筑的 `buildable`（去重）；未建成时回退到阵营表以便预览。
- **自动路由**：点击单位 cameo 时若未选中对应建筑，通过 `_producer_for(uid)` 自动找能生产它的建筑再入队（红警2 行为）。
- 保留原有「签名守卫 + 原地刷新」连续建造修复：`_prod_signature()` 改为基于**目录 + 活跃建筑队列**，结构未变时不重建按钮。
- `_process` 现**常驻刷新甲板**（原先仅在选中建筑时刷新，导致空网格）。

## 2. 红警2 热键对齐（对齐 `KeyBinds.ts` / 原版 `Keyboard.ini`）

来源：`refs/ts-ra2/.../keyboard/KeyBinds.ts` + `KeyCommandType.ts`，并以素材包内**原版 `Keyboard.ini`** 交叉验证。

| 键 | 功能 | 键 | 功能 |
|---|---|---|---|
| Q/W/E/R | 侧栏页签 建筑/防御/步兵/载具 | S | 停止 |
| G | 警戒（GM 控制台改 Ctrl+G） | X | 攻击移动 |
| T | 选择同型 | P | 全选作战单位 |
| H | 镜头回主基地 | D | 部署 |
| K | 维修（切换，回血消耗资金） | L | 出售（返还半价） |
| M / N | 上一个 / 下一个单位 | F | 跟随（再按取消；Ctrl+F 循环阵型） |
| A | 攻击 | Y | 采集 |
| C | 镜头对准选中 | B | 切到「建筑」页 |
| 1-9,0 | 选中编队 | Ctrl+数字 | 编组 | Alt+数字 | 聚焦编队 |
| Shift+Q/W/E/R | 释放单位技能 1-4 | Space/Tab/Esc | 暂停/倍速/取消 |

- 单位技能由 Q/W/R/D 改为 **Shift+Q/W/E/R**（原 Q/W/E/R 让位给侧栏页签）。
- 阵型切换由 F/1/2/3 改为 **Ctrl+F**（1-9 让位给编队控制组）。
- 指令网格新增：回基地(H)、跟随(F)、上一个(M)、下一个(N)、维修(K)、出售(L)、部署(D)，共 18 项。

## 3. 新增战斗方法（`battle.gd`）

`select_cycle(dir)`、`center_on_base()`、`follow_selected()`（+`follow_target` 相机跟随，手动平移即解除）、
`deploy_selected()`、`toggle_repair_selected()`、`sell_selected_building()`、
控制组 `assign_control_group / select_control_group / center_control_group`（+`control_groups`）。

## 4. 建筑维修（`building.gd`）

新增 `repairing` 状态；`_process` 中按 6%/秒 回血，按造价折算扣资金；资金不足自动停止并提示。

## 5. 校验

- 冒烟：`ok=219 fail=0`（旧基线 207 → 新增 12 项甲板/热键断言）。
  - 注意：技能抽卡用例**非幂等**（会把技能池抽干且不清档），二次运行会误报 7 项 `skill_*` 失败；跑基线前请清理 `%APPDATA%\Godot\app_userdata\Iron Tide RTS`。
- 截图：`iso_ui.png`（主界面+甲板）、`iso_deck_infantry.png`、`iso_deck_vehicle.png`。

## 6. 待办 / 观察

- 技能抽卡冒烟用例需补 `MetaProgress` 重置以恢复幂等。
- ~~`_unit_cat` 将 `antitank` 归入载具，故「标枪小队」出现在载具页~~ → **已修**：`_unit_cat` 现把 `antitank` 归入步兵页（对齐红警2 Javelin / 红警3 Tankbuster 均为步兵口径）。标枪小队(`allied_javelin`)、反装甲机甲兵(`empire_tankbuster`) 均从载具页移至步兵页。
