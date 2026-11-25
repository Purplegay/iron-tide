# Iron Tide —— 红警2「移植化」长期路线图

> 立档时间：2026-10-10
> 用户原话（本轮定调）：
> > 「从这边开始以后，我们所有东西都相当于做 ra2 的移植。采矿车的修复也要做。开始进行 ra2 移植吧，
> > 后面我们自己做局外养成一些列的事情，另外 ui 最好像 ra3 那种 飞机船分开。
> > 我们的操控和地图放大和移动太难绷了，不如 ra2 移植。地图音效也移植，我们设定个长期目标」

---

## 0. 长期总目标（一句话）

**把 Iron Tide 做成「红警2 手感 + 红警3 表现力 + 自有卡池局外养成」的现代复刻 RTS**：
游戏底层规则（建造、经济、寻路、命令、音效）**照搬红警2 语义**，
UI/表现（页签分类、全息预览、水面/现代 HUD）**向红警3 靠**，
卡池流派与局外养成是**我们自己的原创增量**。

三条不可动摇的原则：
1. **RA2 是规则唯一事实源**：`refs/ts-ra2` + `data/ra2/*.json`（由 `ra2pipe/build.mjs` 生成，禁止手改）。
2. **WYSIWYG**：一切判定（占点 / 碰撞 / 选中 / 预览）共用同一份美术底盘几何，见 `Building.footprint_poly()`。
3. **每一步都必须可验证**：无头编译自检 + 有头离屏截图 + 实测日志，跑完删临时工装。

---

## 1. 移植范围分层

| 层 | 内容 | 对齐目标 |
|---|---|---|
| L1 建造 / 占点 | 底盘多边形、邻接建造、红警2 建造页、进度擦除、造价+耗时 | RA2 |
| L2 经济 | 矿车自动就近卸矿、精炼厂卸矿口、矿石再生、维修厂修车 | RA2 |
| L3 军事 | 单位数值/武器/弹头、命令集（移动/攻击/警戒/部署/巡逻）、编队 | RA2 |
| L4 操作 | 边缘滚屏、战术地图、命令热键、编队热键、**鼠标锚点缩放** | RA2 手感 + RA3 缩放 |
| L5 UI | 指令甲板页签（建筑/防御/步兵/载具/**空军**/**海军**）、卡面、提示 | RA3 |
| L6 音频 | EVA 语音、单位应答、开火/爆炸、建造/完成音、环境音 | RA2 |
| L7 卡池 / 局外 | 卡池抽卡、局内三选一、关卡链、局外养成 | **原创** |

---

## 2. 分期路线图（每期都有可验收标准）

### Phase A —— 建造与经济手感（进行中，本轮已推进）
- [x] A1 建筑占点/碰撞/寻路 = 真实美术底盘多边形（上一轮）
- [x] A2 卡面显示「造价 · 耗时」，队列卡显示进度擦除 + 数量角标，队列栏显示「剩 Ns」（本轮）
- [x] A3 采矿车：只就近**精炼厂**(`tag=refinery`)卸矿；停靠点在**占地多边形之外**；修掉「停止距离 > 到达阈值 导致原地空转」（本轮）
- [ ] A4 维修厂(`GADEPT`, `tag=repair`)进驻修理载具（红警2 的 service depot 语义）
- [ ] A5 矿石再生 / 矿点耗尽切换 / 矿车满仓自动返厂排队
- [ ] A6 建筑「建造动画 → 落成」阶段（现有 `under_construction` 补美术与音效）

**验收**：连续 3 个矿车 5 分钟无卡死、无穿模；资金曲线单调；截图留证。

### Phase B —— 操作与相机 RA2 化（本轮已完成最关键两项）
- [x] B0 **拾取判定 = 可见像素（WYSIWYG）**：建筑/单位改为「鼠标点反解回绘制空间 + 贴图 alpha 逐像素」判定，修掉「点建筑中间点不到」（旧半径圆只覆盖可见像素 34%~45%）。详见 `CHANGELOG_ra2_click_hit.md`
- [x] B1 缩放改为**鼠标锚点**（光标下的地图点缩放后不漂移，实测 drift = 0.000 px）
- [ ] B2 边缘滚屏参数对齐红警2（速度可调、可关）
- [ ] B3 战术地图：左键跳转、右键视野框、雷达事件闪烁
- [ ] B4 编队热键（Ctrl+1..9 / 双击居中）、Tab 循环同类
- [ ] B5 **待定**：右键既要「命令」又要「拖屏」是当前「太难绷」的主因之一 —— 建议改为红警2 语义（右键=纯粹命令，拖屏只用中键/边缘/战术地图）。**需用户拍板**。

### Phase C —— UI 红警3 化
- [x] C1 指令甲板页签拆分：建筑 / 防御 / 步兵 / 载具 / **空军(Z)** / **海军(V)**（飞机不再混在载具里）
- [ ] C2 海军内容接入：`GAYARD` 船厂 + `DDEST/AEGIS/CARRIER/DLPH`（美术已提取，缺登录 + 水面移动）
- [ ] C3 水面建造（红警3 海上平台）、全息建造预览升级
- [ ] C4 卡池局内「三选一」面板 + 本局卡牌栏
- [ ] C5 **阵营颜色自选**（RA2 房色语义）：8 色色板 + 运行时房屋色重映射（shader）/ 或构建期多套色板；覆盖单位/建筑/血条/选中框/建造预览；主菜单"涂装"页 + `MetaProgress.house_color` 存档。详见 `RA2_PORT_DECISIONS.md` D1–D5

### Phase D —— 音效移植
- [ ] D1 建立 `Sfx` autoload + 音频总线（SFX / EVA / BGM）
- [ ] D2 EVA 语音：`extracted/eva.ini` 已在手（事件→语音），可先驱动**字幕 + 事件提示**，音频到位后接真实语音
- [ ] D3 单位应答 / 开火 / 爆炸 / 建造完成音效
- [ ] D4 环境音（基地循环、风声、矿区）
- ⚠️ **资源缺口**：沙箱内**没有任何音频文件**，`extracted/` 只有 ini。需要把 RA2 的 `speech.mix` / `audio.mix` / `sounds.mix`（或 ts-ra2 的音频目录）放进沙箱，才能做真正的音频移植。

### Phase E —— 卡池 / 局外养成（原创，仍未开工）
- [ ] E1 `data/cards.json` v2（卡牌定义）
- [ ] E2 `MetaProgress` 卡池解锁 / 卡组存档
- [ ] E3 `GameData` 卡牌索引 + `get_card()`
- [ ] E4 `battle.gd` 全局 buff 广播 + 按稀有度抽 3；`Events` 卡牌信号
- [ ] E5 `hud.gd` 局内三选一面板；`meta_screen.gd` 卡组页
- [ ] E6 `waves.json` mission `requires/rewards`；`lobby.gd` 关卡链

默认值（待用户确认）：卡语义只做「全局 buff + 经济」两类复用现有 17 token；局内获取三种全开（波次全清三选一 + 任务必得 + 定时事件三选一）；卡组上限 8 张，仅 `start:true` 开局生效。

---

## 3. 本轮（Phase A/B/C 的第一刀）已完成

| 项 | 文件 | 说明 |
|---|---|---|
| 6 页签（RA3 式细分） | `scripts/ui/hud.gd` `_add_prod_tabs` / `_tab_label` / `_tab_for_building` / `_unit_cat` / `_cat_match` / `_input` | 建筑 Q / 防御 W / 步兵 E / 载具 R / **空军 Z** / **海军 V**；Shift+Z/V 顺带给到第 5/6 个技能槽 |
| 卡面「造价 · 耗时」 | `_make_cameo` | 例：`200 · 4s` |
| 进度擦除 + 数量角标 | 新增内部类 `CameoWipe` + `_prod_wipes` + `_update_cameo_wipes()` | 红警2 侧栏卡片风格，从底向上填充 + `x3` 角标 |
| 剩余时间显示 | `_update_production_live` | 「施工进度 X% · 剩 Ns」/「生产中 单位 · X% · 剩 Ns」 |
| 采矿车（经济闭环） | `scripts/units/unit.gd` `_process_harvester` / 新增 `_pick_home_base()` / `_dock_point()` / `_go_to` 改返回 bool | 只认精炼厂；停靠在底盘多边形外；修掉 `stop 60 > 阈值 52` 的永久空转 |
| 鼠标锚点缩放 | `scripts/world/battle.gd` `zoom_camera` | 用画布变换精确求解，实测漂移 0.000 px |
| **点击命中 = 可见像素** | `scripts/core/ra2_art.gd`（+`art_dir/draw_rect/draw_center/hits_pixel`）、`building.gd`/`unit.gd`（+`hit_test/art_center`）、`battle.gd`（`_pick_at`/`_pick_enemy_at`/拖框） | 7/7 对象 mismatch=0；可见中心点击旧判定=false、新=true；拖框改用可见像素中心 |

**实测（`_probe.gd`，有头离屏，日志见交付件）**
- 页签 6 个：`building/defense/infantry/vehicle/air/naval`
- `vehicle` = AMCV,MTNK,TNKD,CMIN,SREF,MGTK,FV（**不再含飞机**）；`air` = JUMPJET,SHAD,ORCA,BEAG
- 矿车：`_pick_home_base() → GAREFN`；`dock_dist` 落在 `footprint_clearance` 之外
- 矿车完整闭环：采矿 → `harvesting` → `to_base` → `unloading`(cargo=500) → **资金 +488** → `to_node`（跑了 2 轮）
- `ZOOM anchor drift = 0.000 px`
- `main.tscn` / `battle.tscn` 无头 300 帧无脚本错误

---

## 4. 待用户拍板

1. **右键语义**（Phase B5）：是否按红警2 改成「右键只命令，不拖屏」（拖屏用中键/边缘/战术地图）？当前右键拖屏是「太难绷」的主要来源之一。
2. **海军页签可见性**：现在 6 个页签常驻，海军页是空态（提示「海军船坞尚未接入」）。要不要像红警3 那样**没有海军内容时自动隐藏**该页？
3. **音效资源**：请把 RA2 的音频包（`speech.mix`/`audio.mix`/`sounds.mix` 或 ts-ra2 音频目录）放进沙箱，否则 Phase D 只能做「字幕 + 事件提示」骨架。
4. 卡池 3 个决策点（默认值见 Phase E）是否照默认开工。
5. **阵营颜色自选**（用户 2026-10-10 新增）：形态（固定色板 / 色板+自由取色 / 只改 UI）、实现路线（构建期多套色板 / 运行时 shader 重映射 / 混合）、作用对象、敌方撞色处理、选择入口。

> 📋 以上 5 项及其余分叉项已整理成可编号拍板清单：**`iron_tide/RA2_PORT_DECISIONS.md`**（或交付件 `RA2移植_待拍板抉择清单.md`）。
> 技术事实提示：RA2 贴图的阵营色是**构建期烘焙**的（`ra2pipe/art_build.mjs` 的 `SIDE_HOUSE_RGB`，UNITTEM.PAL 16..31 号房色阶 → 盟军蓝），SHP 为索引 PNG（Godot 导入后调色板丢失），因此运行时改色只能走 **shader 颜色重映射** 或 **重新烘焙多套贴图**。

---

## 5. 临时工装

- `iron_tide/_probe.gd` + `_probe.tscn`：有头离屏探针（页签 / 卡面 / 擦除 / 矿车闭环 / 缩放锚点 + 截图）。可复用。
- `iron_tide/_check.gd`：**已知不可靠**（缺 autoload 时 `load()` 假通过），不要用它判定编译通过；改用「跑真实场景 300 帧 + 看 stderr」。

---

## 6. 本轮新增（2026-10-10 第二轮）：阵营涂装自选 + 右键/页签按默认落地

> 用户回「全按默认」后开工。已交付：D1=A / D2=C / D3=A / D4=A / D5=A，并按默认落 **D6=A**（右键只命令）、**D7=B**（无内容页签自动隐藏）。
> 详见 `iron_tide/CHANGELOG_house_color.md`（含诊断证据）。

### 已完成
| 项 | 落点 | 验证 |
|---|---|---|
| 房色重映射着色器 | `shaders/house_remap.gdshader`（归一化方向匹配 + 只用 `COLOR`） | 6 张真实素材逐像素 = CPU 真值 **0 mismatch**；无贴图图元 8/8 不误伤 |
| 阵营涂装中枢 | `scripts/core/house_color.gd`（`class_name HouseColor`） | 8 色色板 / 避让 / 材质缓存 / `apply_to` |
| 涂装工房入口 | `scripts/screens/paint_screen.gd` + `scenes/paint.tscn`；主菜单「涂 装」 | 实拍截图 OK |
| 存档字段 | `MetaProgress.house_color`（默认 `"allied"`） | 读写 + `set_house_color()` |
| 血条打通 | `hp_bar.gd` 静态 `ally_fill/enemy_fill` | D3=A |
| 单位/建筑上色 | `unit.gd` / `building.gd`：`_col` + 节点材质 + `refresh_house_color()` | 战场实拍：基地整体变绿 |
| 敌方避让 | `HouseColor.enemy_color_for()`，`CLASH_DIST=0.30` | 玩家=红/橙 → 敌军转青 |
| 右键语义 | `battle.gd` `right_click_scroll` 默认 `false` | D6=A |
| 页签自动隐藏 | `hud.gd` `_tab_available()` | 实拍：海军页签消失 |

### 关键技术结论（务必保留）
- RA2 阵营色是**构建期烘焙**（`SIDE_HOUSE_RGB` → 盟军蓝 `#57a8ff`），SHP 索引 PNG 导入后调色板丢失 → 运行时只能按**色相**判定重映射。
- 判据必须用**归一化方向**（`cos_tol=0.995`），不能用绝对残差（低亮度灰会误判）。
- Godot 4.7.2 `canvas_item` 片元的 `COLOR` 输入**已 = 顶点色×贴图采样**：
  - `COLOR = texture(...)` → 无贴图图元（血条/选中框/程序化建模）**全变白**；
  - `COLOR * texture(...)` → 贴图色**平方变暗**；
  - ✅ 只用 `COLOR`。

### 仍待办（未动）
- Phase C2 海军接入（美术已提取）
- Phase D 卡池（`cards.json` 仍 `enabled:false`）；Phase E 音效（沙箱仍零音频素材，需用户放包）
- 涂装：血条在玩家选红色时告警可读性下降（待加描边）；建造预览/选中框目前靠同色相一并重映射。

---

## 7. 本轮新增（2026-10-10 第三轮：Phase A4/A5/A6 + B2/B3/B4）

> 详见 `CHANGELOG_phase_a456.md`。无头探针 **24/24 PASS（FAIL=0）**。

| 交付 | 位置 | 说明 |
|---|---|---|
| A4 维修厂进驻修理 | `building.gd`（`is_repair_depot/dock_point/_process_repair`）+ `unit.gd`（`order_repair/_process_repair/_end_repair`）+ `battle.gd`（`_pick_building_at/_try_repair_at`） | 数值取 `rules.ini`：RepairStep=8HP / URepairRate≈0.96s / RepairPercent=15% |
| A5 矿点耗尽再生 | `resource_node.gd`（不再 `queue_free`，`REGEN_FRACTION=0.02`）+ `unit.gd`（`_node_ok/_nearest_ore_node`） | 采集车自动换矿 |
| A6 建造序列 | `art_build.mjs` 新增 `buildup` 模式（提取 40 张 `*MK`）+ `building.gd`（`_buildup_art/_draw_buildup`） | 帧 0=空基座 → 末帧=落成，按进度正序取帧 |
| B2 滚屏可调 | `meta_progress.gd`（`edge_scroll/scroll_speed/subtitles` + `scroll_px_per_sec()`）+ `battle.gd` `_ready` + 新 `settings_screen.gd`/`scenes/settings.tscn` + 主菜单「设 置」 | 50 档 = RA2 基准 780 px/s |
| B3 雷达闪烁 | `events.gd`（`radar_ping`）+ `unit.gd`/`building.gd` 发射 + `minimap.gd` 闪烁 | 受袭红环 / 建成黄环 |
| B4 编队热键 | `hud.gd` 数字键处理 | 连按两下数字 = 选中并居中（对齐 ts-ra2） |

### 关键技术结论（务必保留）
- **A6 素材管线**：`art.ini` 的 `Buildup=<NAME>` 指向**独立 SHP**（如 `GADEPTMK.SHP`），旧管线未提取。Buildup SHP **影子帧追加在后半段**（count 恒偶数），可见序列 = **前半段**，第 0 帧=空基座、末帧=落成，**正序**映射建造进度。锚点用**落成帧**防跳位。
- **A4 数值锚点**：`rules.ini` `RepairStep=8` / `URepairRate=0.016`(=0.96s) / `RepairPercent=15%`。判定用运行时 `tags` 含 `"repair"`（`ra2_allied.json`），兼容 `buildings.json` 的 `extra.UnitRepair=yes`。
- **坑**：自定义 `_process_xxx` 里若忘记 `move_and_slide()`，单位会**完全不动**（`_move_toward` 只设 velocity）。
- **停机位**：`dock_point()` 取**占地外侧**最近正交方位（`footprint_clearance(dir)+38`），否则载具被建筑碰撞挡在外侧、永远到不了 `footprint` 内的点。

### 仍待办（本轮后）
- **C2 海军接入**：`GAYARD`/`NAYARD` + `DEST`/`CDEST`/`AEGIS`/`CARRIER`/`DLPH`（缺水面移动 + 船厂放置规则）；接入后 D7=B 的海军页签会自动出现。
- **D 卡池**：`data/cards.json` 仍 `version:1 / enabled:false`，**完全未动工**。
- **E 音效**：沙箱仍**零音频文件**（`extracted/` 只有 `eva.ini`），需用户放 `speech.mix`/`audio.mix`/`sounds.mix`；本轮已先把「设置 → 事件字幕」开关预埋。
- 维修厂 `SpecialAnim`（吊臂）层偏移为 0，实拍略偏（bldanim 层偏移未逐层校对的既有问题）。

---

## 8. RA2 规则迁移 第 1 批：战斗规则（2026-10-11 第四轮）

用户指示「先把 ra2 的各种规则全部迁移」。本轮先做**战斗**这一类（缺口最大、无需新素材），其余类别在 `RA2_RULES_MIGRATION.md` 台账里列出并排好序。

### 本轮完成
- **护甲**：引擎 6 类近似 → **RA2 真实 11 类**（`ra2_armor`）。
- **伤害克制**：手写 7×6 表 + 按弹头名字猜类型 → **`warhead.Verses[护甲类别]`**（83 弹头）。
- **防空**：`armor_multiplier(at,"air")>=0.6` → **弹道 AA 标志**（`ra2_aa`，来自 `[Projectiles] AA=`）。
- **武器**：删掉手写 `UNIT_WEAPON_OVERRIDE`/`DEF_WEAPON`，改取真实 `Primary=`/`Weapon1..N`；建筑武器由 build.mjs 提取。
- 新增 `data/ra2/projectiles.json`（49 条）。

### 关键技术结论（务必保留）
- **RA2 ROF 单位 = 1/15 秒**（逻辑 15fps）：`cooldown = rof/15`。冷却上限放宽到 30s（原 8s 会截断巨炮/光棱）。
- **弹头 `Verses` 缺省槽位 = 100%**（ModEnc）：未列出的护甲按 100% 计，不是 0%。
- **防空是「弹道」属性不是「弹头」属性**：`[Projectiles] AA=yes`。RA2 没有 "air" 护甲类别。
- **ini 注释坑**：`[MirageWH]\t// ...` 这种**段头带 `//` 注释**的行，旧解析器（只剥 `;`）不认 → 整段被吞进上一段，`MirageWH` 丢失。已让 `parseIni` 同时剥 `;` 与 `//`。
- **`[SREF]`（光棱坦克）的 `Primary=` 被注释掉**，实际用 `Weapon1=Comet` + `WeaponCount=1`。这就是旧 `UNIT_WEAPON_OVERRIDE` 存在的原因。
- **双轨兼容**：RA2 实体同时带 `armor`（旧词表，供 UI/旧路径）与 `ra2_armor`（真实类别）；引擎自带单位无 `ra2_*` → 自动回退旧克制表；跨阵营用 `to_ra2_armor`/`to_engine_armor` 互通。

### 验证
- 探针（真实场景 `_probe_rules.tscn`）**24/24 PASS，FAIL=0**。
- 有头离屏截图：`RA2移植_规则对照表_护甲x弹头.png`（运行时实读渲染）。
- 战斗场景无头 300 帧 exit 0、无脚本错误。

### 仍待办（下一批，见 `RA2_RULES_MIGRATION.md`）
- **电力系统**（Power 产出/消耗 + 低电惩罚）——数据已就绪，引擎无电力系统。
- **老兵等级**（VeteranAbilities/EliteAbilities）。
- **苏军阵营运行时** + **命令集**（巡逻/警戒/守卫）+ **建造耗时公式** + **超武**。

---

## 9. RA2 规则迁移第 2 批：攻击特效 + 移动 + 采矿卡死（2026-10-11）

### 9.1 目标
用户口令：「所有单位的攻击特效 移动 都没迁移 还有我们采矿卡死的问题也得迁移」。
三项一起做：**攻击特效照搬 rules.ini/art.ini**、**移动照搬 ROT/Accelerates/Crusher**、**修掉矿车卡死**。

### 9.2 攻击特效（从「程序化色块」改为「真实动画 SHP」）
- 新增素材管线：`build.mjs → data/ra2/animations.json`（53 条）+ `art_build.mjs fx 阶段 → assets/ra2/fx/*.png|json`（65 个动画，`ANIM.PAL` 上色，1.4MB）。
- 帧率口径：`fps = art.ini Rate / 60`，缺省 `900 → 15fps`（依据 `refs/ts-ra2` 的 `AnimProps.defaultRate = BASE_TICKS_PER_SECOND = 15`）。
- 新 `class_name Ra2Fx` 播放器：武器 `Anim=`（8 向按炮塔朝向）、弹头 `AnimList=`（列表随机）、弹道 `Image=`。
- `Projectile` 落地 `Inviso / Arcing（抛物线）/ Shadow / ROT（追踪限速）`，`CellSpread → 溅射半径`。

### 9.3 移动
- 速度统一口径：`px/s = Speed × 45/3`（≈3 Speed = 1 格/秒），删除步兵/载具/空军各自手写的 26/15/24。
- `ROT` 落地为车体+炮塔转向速率（1/256 圈 / 1/15s），实测 180° 掉头 1.68s（理论 1.71s）。
- `Accelerates`（仅 `=yes` 起停斜坡，盟军白名单内无单位开启）、`Crusher/Crushable`（可碾压步兵，`_crush_tick`）落地。
- 新增运行时 `move{}` 块（speed/rot/accel_time/turret/crusher/crushable/weight/movement_zone/speed_type/locomotor/dock）。

### 9.4 采矿卡死（实测复现 → 根因 → 修复 → 复验）
- 复现：矿车直线奔赴 603px 外的矿脉，**97.6% 正面顶死自家发电厂东面**，每帧只挪 0.014px，`deliveries=0` 永久卡在 `to_node`。
- 根因：**采集行程没挂寻路流场**（只有修理工单挂了），而引擎 `PathService` 流场是现成的。
- 修复：`_steer_field_to` 挂流场 + `_track_stuck` 卡滞脱困（重算流场/侧移 9px/换目标）+ `_ore_target` 矿点黑名单。
- 复验：`stalls=0 FAIL=0`，两台矿车正常往返卸矿（500/次）；首次到矿 33s → 9.2s；抽干全部矿点后会自己换矿点。

### 9.5 顺带修掉的两个真 bug
- `Object.get(k, default)` 传 2 参（Godot 4 只收 1 参）→ **第 1 批的「弹头 Verses 走真值」在实机开火里一直静默失效**（无头探针直接调 CombatMath 所以没暴露）。本轮「实机开火」检查才抓到。
- 建造场 `GACNST` 漏进运行时白名单 → `_check_end` 找不到 HQ → **开局第 1 帧弹「败北」**。已在 `BUILDING_TAGS` 补上（building 15→16）。

### 9.6 验证方式（可复现）
```
# 编译自检
& $exe --headless --path $abs --editor --quit
# 攻击特效（数据 + 实机开火）   41/41 PASS
& $exe --headless --path $abs --fixed-fps 60 --quit-after 1600 res://_probe_fx.tscn
# 移动规则（ROT/加速/碾压/实机掉头）  8/8 PASS
& $exe --headless --path $abs --fixed-fps 60 --quit-after  500 res://_probe_move.tscn
# 采矿（三段：无矿厂/放矿厂/抽干矿脉）
& $exe --headless --path $abs --fixed-fps 60 --quit-after 3650 res://_probe_harvest.tscn
```
（`_probe_*` / `_shot_*` 为临时工装，交付前已删除。）

### 9.7 下一批建议
音效（Report/StartSound，缺 WAV 提取）→ 电力系统 → 老兵等级 → 苏军阵营运行时 → 命令集 → 地形/水 + 建造耗时公式 + 超武。

---

## 10. 第 3 批：音效（武器开火音）

命令：`node ra2pipe/sfx_build.mjs needed`。事实源：`LANGUAGE.MIX` → 容器 `0xad29acfa` 内的
`audio.idx`(GABA 索引, 1153 条) + `audio.bag`(16.8MB)。**Godot 不支持 IMA ADPCM WAV** → 管线解码为 PCM16。

- 产物：`assets/ra2/sfx/*.wav`（381 个，21.3MB）/ `data/ra2/sfx_index.json` / `data/ra2/sound_specs.json`（184 条）
- 引擎：`scripts/core/ra2_sfx.gd`（autoload `Ra2Sfx`，`AudioStreamPlayer2D` 池 + 缓存 + Volume/Range 口径）
- 接线：`unit.gd::_fire_shot` / `building.gd::_fire` → `Ra2Sfx.play_weapon(weapon, muzzle)`（与炮口火光同帧）
- 自检：**PASS**（真实开火 plays=57 / misses=0 / cached=9；单位+建筑两条链路）

```powershell
$exe="C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"
$abs=(Resolve-Path "iron_tide").Path
& $exe --headless --path $abs --editor --quit                        # 编译自检
& $exe --headless --path $abs --fixed-fps 60 res://_probe_sfx.tscn   # 音效链路（临时工装，已删）
& $exe --headless --path $abs --quit-after 900 res://scenes/battle.tscn
```

### 10.1 下一批建议
单位语音的 UI/命令钩子 → 电力系统 → 老兵等级 → 苏军阵营运行时 → 命令集 → 地形/水 + 建造耗时公式 + 超武。

---

## 11. 第 4 批：单位语音（选中 / 下令 / 反馈 / 部署 / 阵亡）

命令：`node ra2pipe/faction.mjs` → `node ra2pipe/sfx_build.mjs needed`。

事实源链：`rules.ini` 单位/建筑小节的 `VoiceSelect/VoiceMove/VoiceAttack/VoiceFeedback/`
`VoiceSpecialAttack/DieSound/CrushSound/DeploySound/UndeploySound` → `[sound.ini]` 条目
（原版这些条目的 `Sounds=` 值带 `$` 前缀 = 语音；无 `$` = 纯音效）→ `LANGUAGE.MIX` 容器
`0xad29acfa` 的 `audio.idx`(GABA) + `audio.bag`。**语音与武器开火音是两套东西**
（`GIAttackCommand`=下达攻击命令的语音，`GIAttack`=开火的枪声）。

- 管线：
  - `faction.mjs` 新增 `VOICE_MAP` + `buildVoice()`（9 个键：`select/move/attack/feedback/special/die/crush/deploy/undeploy`）
    → 每个单位/建筑带 `voice:{...}`；数字台账（`faction.mjs` 自报）追加语音清单
  - `sfx_build.mjs` 新增 `collectVoices()`；**并把扫描范围从 `data/ra2/*.json` 扩到
    `data/ra2_*.json`**（上一轮只扫了 `data/ra2/`，`ra2_allied.json` 在上一级 → 语音全漏）
- 提取：`needed` 模式 → **580 个 WAV / 29.02MB**（语音 +199 个 / +7.7MB）；`sfx_index.json` 580 项、
  `sound_specs.json` **233 条**（原 184）。语音全部 22050Hz PCM16（同上一轮的解码口径）。
- 引擎：`ra2_sfx.gd` 新增 `voice_id()` / `has_voice()` / `play_voice(data, kind, pos, throttle_ms)`。
  `stats()` 增加 `voice_plays` / `voice_misses`。同一 sound id 节流（近似 RA2 `Limit=`），
  避免框选 20 个单位 / 群体阵亡时叠成机关枪。
- 接线（8 条事件，全部走 `rules.ini` 数据，无硬编码）：
  | 事件 | 接入点 | voice 键 |
  |---|---|---|
  | 选中 | `battle.gd::_emit_selection()`（选择签名去重 + 随机代表） | `select` |
  | 移动 / 采集下令 | `battle.gd::_command_move()` / `_try_harvest_at()` | `move` |
  | 集火下令 | `battle.gd::force_attack()` | `attack` |
  | 无法服从（卧倒单位收到移动令） | `unit.gd::order_move()` | `feedback` |
  | 部署 / 起身 | `unit.gd::_toggle_deploy()` | `deploy` / `undeploy` |
  | 阵亡 | `unit.gd::_die()` | `die` |
  | 被碾压 | `unit.gd::receive_hit(..., "crush")` 置位 → `_die()` | `crush` |
  | 建筑阵亡 | `building.gd::_die()` | `die` |
- 设计口径：**一次选择 / 一条命令只播一条语音**（RA2 亦如此；从"有该语音的单位"里随机取代表，
  与 RA2 的随机响应一致），而非每个单位各播一条。
- 自检：**PASS** —— 29/29 断言（数据链 13 项 + 行为 16 项）；
  `plays=10 misses=0 voice_plays=9 voice_misses=1`（miss 那条是刻意构造的"无语音数据"路径）,
  `pool=32 cached=10`；`editor --quit` 与 `battle.tscn` 回归均 `exit=0`。
  有头离屏截图：`_shot_voice_wave.png`（6 条语音真实波形）、`_shot_voice_wiring.png`（19 单位 + 2 建筑的语音接线总览）。

```powershell
$exe="C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"
$abs=(Resolve-Path "iron_tide").Path
& $exe --headless --path $abs --editor --quit                        # 编译自检
& $exe --headless --path $abs --fixed-fps 60 res://_probe_voice.tscn # 语音链路（临时工装，已删）
& $exe --headless --path $abs --quit-after 900 res://scenes/battle.tscn
```

### 11.1 下一批建议
电力系统 → 老兵等级 → 苏军阵营运行时 → 命令集 → EVA 播报（`eva.ini`，与单位语音不同源）→ 地形/水 + 建造耗时公式 + 超武。

---

## 12. 第 5 批：电力系统（产电 / 耗电 / 低电惩罚）

命令：`node ra2pipe/build.mjs` → `node ra2pipe/faction.mjs`。

事实源链：`rules.ini` 建筑小节 `Power=`（正=发电 / 负=耗电）+ `Powered=yes`（低电离线）
→ `[General] MinLowPowerProductionSpeed=.5 / MaxLowPowerProductionSpeed=.8 / LowPowerPenaltyModifier=1`
→ 参考实现 `refs/ts-ra2` 的 `PowerTrait.ts` + `ProductionTrait.computeLowPowerBuildSpeedModifier()`。

- 管线：
  - `build.mjs` 建筑段新增 `o.powered`（`Power=` 早已提取）
  - `faction.mjs` 建筑 entry 落 `power`/`powered`，report 追加电力清单
  - 产物：`ra2_allied.json` 16 建筑中 12 带电力字段：`gen=1（GAPOWR +200）`、`drain=11`、`powered=5（GAOREP/ATESLA/GTGCAN/GAGAP/GASPYSAT）`
- 引擎：
  - `events.gd` 新增 `signal power_changed(produced, drain, low)`
  - `battle.gd` 新增 `_update_power()`（每帧重算，仅变化时发事件）/ `power_build_factor()` / `power_stats()`；
    结构队列 `_tick_structure_queue()` 的「付款 + 计时」同步乘低电系数
  - `building.gd` 新增 `power`/`powered` 字段、`is_operational()`、`_power_build_factor()`；
    建造 & 生产队列乘低电系数；涓流与 `_fire()` 受 `is_operational()` 门控；画红「无电」呼吸角标
  - `ui/power_bar.gd`（新）顶栏电力条；`ui/hud.gd` 「电力 x/y」标签（低电变红 + `⚠低电`）
  - GM 新增 `infinite_power`
- 规则口径（照搬 RA2）：
  - 发电量 = **Σ ceil(Power × 当前血量%)**（受损电站出力下降；未落成不计）
  - `produced < drain` → 低电；建造/生产系数 = `clamp(1 − 0.3·ratio/0.15, .5, .8)`（ratio = 1 − prod/drain）
  - `Powered=yes` 建筑低电离线（防御塔停火、矿石精炼器停涓流）
- 设计口径：低电**同时拖慢计时与付款**（总花费不变、只拉长工期），避免只拖计时导致超收资金。
- 自检：**PASS** —— 31/31 断言（数据链 4 + 血量缩放 2 + 低电/离线 6 + 系数公式 5 + 队列联动 2 + GM 3 + 事件 1 + HUD 6 + 恢复 2）；
  `editor --quit` 与 `battle.tscn` 回归均 `exit=0`。
  有头离屏截图：`_shot_power_cmp.png`（充足 1000/735 绿条 vs 低电 0/735 红条 + 红「无电」角标）。

```powershell
$exe="C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"
$abs=(Resolve-Path "iron_tide").Path
& $exe --headless --path $abs --editor --quit                        # 编译自检
& $exe --headless --path $abs res://_probe_power.tscn                # 电力链路（临时工装，已删）
& $exe --headless --path $abs --quit-after 900 res://scenes/battle.tscn
```

### 12.1 下一批建议
EVA 播报（`eva.ini` → `sound.ini`，含「电力不足 / 电力恢复」，与电力系统天然衔接）→ 老兵等级 → 苏军阵营运行时 → 命令集 → 地形/水 + `MovementZone` + 建造耗时公式 + 超武 + 命中音效。
（实际第 6 批先做了用户报的「大兵卧倒 + 矿车倒车入库」两处修复/打磨，EVA 仍待接。）

## 13. 第 6 批：部署/卧倒修复（单点主技能）+ 矿车倒车入库（2026-10-12）

本轮不是新规则，而是**两条已迁规则的回归修复 + 手感打磨**（用户：美国大兵不能卧倒了 / 改成单点能放主技能 / 采矿车倒车入库 / 采矿优化一下）。

### 13.1 美国大兵卧倒
- 事实源：`rules.ini [E1] Deployer=yes` + `art.ini [GISequence] Deployed=292,1,1`
- **回归根因**：`deploy_frame` 曾由一次性脚本 `p7_deploy.mjs` 直接写进 JSON（不在事实源链上），第 5 批全量重产 `ra2_allied.json` 时被丢掉 → 「能部署但躺不下去」。
- 修复：
  - `build.mjs::deployedFrameOf()`：从 art.ini `<Image>Sequence` 的 `Deployed=` 数据化取首帧 → `deploy_frame=292`（落 `data/ra2/units.json`）
  - `faction.mjs`：`deployer` / `deploy_frame` / `deploy_attack_mult=1.5` / `deploy_defense_mult=1.15` 落入 `ra2_allied.json`
  - `battle.gd::deploy_selected()`：改调 `unit.deploy()`（旧版调不存在的 `u.deploy()`，点 D 静默无反应）
  - `unit.gd`：新增 `can_deploy()/deploy()/set_deployed()/is_deployed()/_deploy_skill_index()`；`_toggle_deploy()` 改为薄封装
  - HUD：`_refresh_deploy_cmd()` 状态化（按钮转琥珀 + tooltip「起身 (D)」）；姿态卡显示「卧倒据守」

### 13.2 矿车倒车入库 + 采矿优化
- 泊位冻结 `_lock_dock()`（进入 300px 后不再随方位漂移，修掉「绕着矿厂打转」）
- 两段式：待泊位 `_dock_stage()`（泊位外侧 46px）→ 倒车 `_reverse_to()`（车头朝外，倒车速度 ×0.55）
- 卸矿口占用等待 `_dock_occupied()`（在待泊位等，超时 6s 强行入库，防互锁）
- 矿点认领 `ResourceNode.claim_by/claim_release/claim_held_by`（弱引用）+ `_ore_target()` 未认领优先
- 卸完立即前驶离场（`_unlock_dock()`，此时车头已朝外）
- 绘制：`_draw_reverse_tag()` 车尾琥珀倒车灯 + 「倒车」小标

### 13.3 验证
- 无头探针：**PASS**，36/36 断言（卧倒 23 + 采矿 13）；采矿关键证据：2/2 台出现倒车段（速度·车头 = -0.99/-1.00）、泊位冻结、卸矿时车头朝外、完整循环 2/2、两车同时持不同矿点、资金 5040 → 7040
- `editor --quit` / `battle.tscn` 回归均 `exit=0`
- 有头离屏截图：`RA2移植_大兵卧倒_采矿倒车_对比.png`（站立 vs 卧倒 / 倒车入库 / 卸矿姿态）

```powershell
$exe="C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"
$abs=(Resolve-Path "iron_tide").Path
& $exe --headless --path $abs --editor --quit                             # 编译自检
& $exe --headless --path $abs --fixed-fps 60 res://_probe_m6.tscn         # 卧倒/采矿探针（临时工装，已删）
& $exe --headless --path $abs --quit-after 900 res://scenes/battle.tscn
node ra2pipe/build.mjs ; node ra2pipe/faction.mjs                          # 重产（新增 deploy_frame 链）
```

### 13.4 下一批建议（不变）
EVA 播报（`eva.ini`，与电力天然衔接）→ 老兵等级 → 苏军阵营运行时 → 命令集（巡逻/警戒/守卫）→ 地形/水 + `MovementZone` + 建造耗时公式 + 超武 + 命中音效。



---

## 第 14 节：第 7 批 星际2 化视觉（地图质感 + 立体感）

**用户口令**：「可以优化成星际2 的那种感觉，我觉得我们地图和立体感有点太像素风了」。

**先量化后动手**：统计第 5 批截图世界区域亮度 → 地面 p25/p50/p75 = 0.106/0.112/0.112（注释：几乎纯色棋盘）+ 硬网格 → 判定根因是「地表无材质、无统一光向、物体无体积」，不是分辨率。

**做法**（全部只改表现层）：
1. `ground.gd` 重写：程序化岩地（可平铺 fbm + 15 站点周期化 Voronoi 岩板 + 岩层脉络 + 高频颗粒），一张覆盖 900 世界像素；默认关闭建造网格（放置建筑时再开）。
2. `obstacle.gd` 的 `_draw` 重写：地面轮廓（= 碰撞多边形）不变，向上挤出岩壁与受光顶面 → 12 个岩体全部变成有体积的岩台；侧壁逐边四边形（规避自相交多边形三角化失败），顶面逐顶点着色（无质心扇 → 无放射接缝）。
3. 新增 `water.gd`(`WaterLayer`)：岸砾/岸影/三层水色/动态波纹/泡沫/高光；`battle._draw_water()` 退化为幂等挂载。
4. `resource_node.gd` 的 `_draw` 重写：扁平圆盘 → 立体结晶簇，随储量 k 缩放高度与数量；采空态为暗淡裸地。
5. `Iso.shadow()` 改三层软边；`unit.gd`(6 处)/`building.gd`(2 处) 接地影偏移统一为右偏 `r*0.34`，与「阳光自左上」一致。
6. 新增 `shaders/post_grade.gdshader` + `scripts/ui/post_layer.gd`（layer=1，压在世界与 HUD 之间）：饱和度/对比/中间调提亮/暖高光·冷暗部/左上阳光渐变/暗角/极轻颗粒。

**验证**：`_probe_v7` 无头探针 **20/20 PASS**（重点：碰撞多边形 == 所见轮廓 12/12、矿点碰撞半径 = radius×0.85、岩体物理层未变、`Iso.inv_k()=2.00`、相机 zoom=2.0、`PostLayer.layer=1` 且 HUD(20) 在上、`WaterLayer.rects` 直接引用逻辑水域）；`editor exit=0` / `battle exit=0`；纹理一次性生成 376ms。有头离屏截图 5 张 + 像素统计（p50 0.112 → 0.274~0.360）。

**下一步候选（视觉线）**：① 单位/建筑位图着色（本批最大遗留：RA2 黑描边像素 vs 已成型的 3D 地表）；② 地形高度/`MovementZone`/`SpeedType`；③ 道路/河堤/装饰岩群/非矩形水体；④ 昼夜光照与 EVA 联动。


---

## 15. 第 8 批：引擎整合 ts-ra2 —— 命中判定 / 攻击特效（+ 电力牌）

**用户指令**：「C 然后我们引擎逻辑整合一下 ra2 那个 gitclone 的东西，现在碰撞打击感 攻击特效一坨屎」
- **C** = 保留 RA3 皮肤，只把电力做成 RA2 信息密度 → 已成电力牌（产电/耗电/余量赤字/RA2 原文低电提示）。
- 后半 = 把 `refs/ts-ra2`（GPL 参考工程，只读参考）的命中模型搬进本工程。

**先量后改**：动手前拿到 5 条**事实性偏差**（非审美）：
1. AnimList 该按伤害选档（`clamp(floor(damage/25))`），本工程原为随机取一；
2. 溅射该用 `PercentAtMax` 线性衰减，本工程原为自创公式；
3. **弹道武器完全不吃 Verses 护甲表**（把发射时算好的一份伤害照抄给溅射所有人）——「打上去没感觉」的主因；
4. 伤害缺 RA2 量化（正 floor / 负 ceil）；
5. `ProneDamage` 未实现（而第 6 批刚做完部署卧倒）。

**新增**：`Ra2Damage`（命中模型唯一事实源）、`DecalLayer`（地面灼痕）。
**补齐的反馈件**：受击摇晃（`Rocker=yes`，强度 `clamp(dmg/300)`、46 tick@15TPS 抛物线、峰值 45°）、命中火花（`Sparky`）、命中闪光（`Bright`）、地面灼痕（`Deform=`/`DeformThreshhold=`）。
**改动**：`projectile.gd`（`base_damage` + `_explode` 逐目标结算）、`combat.gd`（`full_damage` 增 `dist_px`/`target`）、`unit.gd`（量化 + 摇晃 + `is_prone`）、`building.gd`、`ra2_fx.gd`、`effects.gd`、`hud.gd`。

**验证**：`_probe_v8` **72/72 PASS**（新增「完整性闸门」：运行时错误导致断言中断即 FAIL，本轮靠它抓到 GDScript `cosf/sinf` 不存在、`battle.tscn` 根节点是 `BattleScreen` 两处真错）；`editor exit=0` / `battle exit=0`；有头离屏截图证实「伤害不同→弹着不同」「灼痕可见且留存」「电力牌实时 200/10 余量 +190」。

**修正台账**：A2 节原记「命中动画 ✅ 已对齐（列表随机取一）」是**错误记载**，实为按伤害选档，已改实现并更正台账。

**未做**：`SplashList`（水面弹着，需扩 `ra2pipe` 管线）、`WeaponNullifyAnim`、`InfDeath` 逐武器步兵死亡动画（数据已提取，留下一批）、原版 `art.ini Crater/Scorch` 贴花贴图（灼痕改程序化绘制，规则口径仍以 `Deform=` 为准）、`AffectsAllies`（按默认 no）。数据侧另记：本作 rules 提取值中无任何弹头 `Sparky=yes`。

**下一步建议**：① `InfDeath` 接线（数据已就位，投入产出最高）；② 扩 `ra2pipe` 提取 `[CombatDamage] SplashList` + `art.ini` 的 `Crater/Scorch` 与 smudge 贴图，把灼痕/水花换成原版美术；③ 回到规则主线：EVA 播报、老兵等级。
