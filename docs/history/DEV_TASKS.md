# Iron Tide —— 开发目标与待办台账

> 本档由 2026-10-14 会话起立，集中管理本工程当前目标、进行中任务、未决待办与已完成项。
> 与 `RA2_PORT_ROADMAP.md`（长期路线图）、`RA2_RULES_MIGRATION.md`（规则迁移台账）互补：
> **本档 = 工作面执行清单**，那两份 = 战略层档案。
> 每项完成后标 ✅ 并注明日期与验证方式。

---

## 0. 工程环境速查

| 项 | 值 |
|---|---|
| 工程根 | `iron_tide/`（`project.godot` 所在） |
| Godot | `C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe` |
| 规则唯一事实源 | `refs/ts-ra2` + `data/ra2/*.json`（ra2pipe 生成，禁手改） |
| 判定几何事实源 | `Building.footprint_poly()`（WYSIWYG） |
| z_index 唯一事实源 | `scripts/core/depth_layers.gd`（`DepthLayers`） |
| 非版本控制 | 不是 git 仓库，改动前自行备份 |
| 验证准则 | 无头编译自检 + 有头截图 + 临时探针验证后必删 |

---

## 1. 当前优先级队列（本会话）

用户 2026-10-14 批量指令，按用户给定优先级排列：

| # | 任务 | 用户口令 | 状态 |
|---|---|---|---|
| T1 | **单位贴建筑画在建筑之上**（含血条/标签） | "A1全部" | ✅ 已完成（上一会话修单位；血条见 T1b） |
| T1b | 血条/名称标签也画在建筑之上 | "A1全部" | ✅ 已完成（2026-10-14，见 §5.1） |
| T2 | **path_service 漏格修复** | "B2处理" | ✅ 已完成（2026-10-15，见 §5.5） |
| T3 | **音效补全**（全库抽取 1153 条） | "3补全" | ✅ 已完成（2026-10-16，见 §5.8） |
| T4 | 遭遇战「玩家阵营」选择 | "4后续做" | ✅ 已做（2026-10-19：盟军五国/国家选择 + 起手加成；苏军运行时仍未接入） |
| T5 | **PrismSupport 棱镜支援链** | "5做" | ✅ 完成（2026-10-16，见 §5.7a） |
| T6 | **LaserFire 类武器移植** | "6移植" | ✅ 早已接通（2026-10-17 核实，见 §5.4） |
| T7 | **采矿车回不动（卡住）** | "7就是采矿车回不动" | ✅ 已修（2026-10-19：任务开局缺矿场，见 §5.11） |
| T8 | **DEPTH_HALF 对 >3800 地图是否够用** | "8你来决定" | ✅ 无需改动（2026-10-14 定论，理由见 §5.5.2） |
| T9 | 鼠标光标变更（释放技能时，参考 RA2） | 用户新增 | ✅ 已做（2026-10-19，见 §5.12） |
| T10 | 采矿车主动倒车问题修复 | 用户新增 | ✅ 已完成（2026-10-15，见 §5.6） |
| T11 | 矿做成 RA2 式散出来的（视觉） | 用户新增 | ✅ 已完成（2026-10-15；2026-10-16 放大，见 §5.7/§5.7b） |
| T14 | 矿车在矿田内游走采集（非锁定单格，贴 RA2） | 探针发现 | 🔄 待定（见 §5.7b 实测发现） |
| T12 | 去采矿时鼠标变化 | 用户新增 | ✅ 已做（2026-10-19，见 §5.12） |
| T13 | 哪些部分不是 RA2，尽量源码移植 | 用户新增 | 🔄 审查中 |
| T14 | 清理探针/日志 | — | ✅ 已完成 |
| T15 | **防空补全：爱国者飞弹 `NASAM` 进建造清单 + 防御页签对空** | "我放空台呢" | ✅ 已完成（2026-10-16，见 §5.9） |
| T16 | **盟军可建造清单补全**（隐藏科技步兵 + 剩余单位盘点） | "剩余单位都补全" | ✅ 无头/有头验证（2026-10-16，见 §5.9）；海军/超武已于 2026-10-19 完成，见 §5.13/§5.14 |
| C2 | **海军水面移动（GAYARD + 六舰）** | "都做" | ✅ 2026-10-19，见 §5.13 |
| SW | **超级武器（GACSPH / GAWEAT）** | "都做" | ✅ 2026-10-19，见 §5.14 |

### 用户批量指令原文（存档）
> A1全部 / B2处理 / 3补全 / 4后续做 / 5做 / 6移植 / 7就是采矿车回不动 / 8你来决定 / 91011清理你处理吧
> 另外我们单机释放技能，需要变更鼠标形状，参考ra2
> 继续补全音效
> 采矿车逻辑仍然有问题，有时候会主动倒车，我们矿做成ra2那种散出来的，去采矿应该有鼠标变化
> 你看哪些部分不是ra2，我们尽量源码移植
> 需要做个md放置我们的目标和未完成的东西

---

## 2. 已完成 ✅

| 项 | 日期 | 验证 |
|---|---|---|
| 单位画在建筑上方（兜底抬升 `_over_building_body`） | 2026-10-13 | 逻辑探针 + 真窗口截图三重验证 |
| 血条/标签抬层：新增 `DepthLayers.WORLD_HUD=3850` + `battle.hp_overlay` 统一绘制 | 2026-10-14 | 无头编译 0 错 + 真窗口 ON/OFF 对照（血条盖建筑 diff=917px）+ z 确定性（3850>最大实体2621） |
| 清理探针/日志（`_zz_*`、`_m4_probe.gd.uid`、沙箱 `zz*`） | 2026-10-14 | `Get-ChildItem` 复核为 0 |
| **寻路网格漏格修复**（`_stamp_rect` 外扩半格；`_stamp_water` 统一走 `_stamp_rect`） | 2026-10-15 | 无头探针：建筑/水域漏格 4→0、7→0、8→0；端到端穿越测试：贴墙卡死 → 正常绕行到点 |
| T8 结论落档（`DEPTH_HALF=1900` 对大图亦够用，无需动态化） | 2026-10-15 | 公式按 `map_size` 归一化，z 恒落 [1,3801]，与地图尺寸无关 |
| **采矿车主动倒车修复**（采集行驶段补 `_face_if_moving()`，车头对齐行进方向） | 2026-10-15 | 无头探针：向西行驶倒车帧「整段累加」→ 仅掉头瞬态；9000 帧无头跑通完整往返（含倒车入库）0 报错；有头截图车头对齐速度 |
| **矿体 RA2 式「散出来」（T11）**（`battle._scatter_ore` 铺开小矿格，总量守恒） | 2026-10-15 | 无头探针：4 处矿体 → 42 枚小矿格（每枚 540），总储量 24000 守恒；无嵌建筑/障碍/水域；矿格不进寻路网格（每处各起一质心汇聚，寻路不受影响）；多辆矿车完整往返 `to_node→harvesting→to_base→unloading` 0 报错；有头截图确认连片散布外观 |
| **矿体放大（T11b）**（`ORE_TILE_*` 4×3/36/30 → 5×4/46/38，纯常量） | 2026-10-16 | 无头探针：4 片 → 70 枚矿格（每格 radius 34.2），总储量 24000 守恒，无落水，矿车完整往返、资金 5040→6540；有头截图确认连片更醒目（约 252×206px，原约 162×126） |
| **盟军建筑加 `NASAM` 爱国者飞弹（T15）** | 2026-10-16 | 无头探针：盟军建筑 16→17、`NASAM` 在防御页签、`weapon.ra2_aa=true`（弹道 `AAHeatSeeker`）、`ra2_prereq_ok(NASAM,[GAPILE,GACNST])=true`；有头截图：防御页签出现「爱国者飞弹 1000·20s」 |
| **单位补全：`CCOMAND`/`PTROOP`（T16）** | 2026-10-16 | 无头探针：盟军单位 19→21、两者 `built_at=GAPILE`、cameo/语音齐（`ChronoCommando*`/`Yuri*`）；有头截图：步兵页签出现「超时空突击/心灵突击」且 cameo 为 RA2 原图 |
| **音效全库抽取（T3）**（`sfx_build.mjs all`） | 2026-10-16 | 写盘 ok=1153 fail=0（62.94MB），`sfx_index.json` 580→1153；引用 id 277→284、specs 233→240（新增 `PatriotAttack`/`ChronoCommando*`/`Yuri*`）；无头跑 900 帧 0 报错 |
| **老兵/精英等级系统（VeteranLevel）** | 2026-10-16 | 新增 `data/ra2/general.json`（rules.ini [General] 老兵倍率）+ `ra2_allied.json` 每单位 `veteran`/`elite_weapon` 块；`unit.gd` 击杀累积→升级→叠加 FIREPOWER/ROF/FASTER/STRONGER/SELF_HEAL 并切换 `ElitePrimary` 武器；血条绘 RA2 式「V」等级标；HUD 显示「★老兵/★精英」+ 老兵倍率芯片。探针：E1 击杀后 maxhp 168.75→253.125(×1.5)、veteran_attack=1.1、rof=0.6、speed=1.2；升 Elite 后 FASTER 消失（依数据）、精英武器 M60E 生效；血条渲染 rank=0/1/2 对照截图正确；900 帧 0 报错 |
| 本档建立 | 2026-10-14 | — |

---

## 3. 未决/需用户拍板

| # | 议题 | 现状 | 建议 |
|---|---|---|---|
| P1 | DEPTH_HALF=1900 对大图：当前 z 域 [1,3801]，>3800 地图会压层 | ✅ 已结论（2026-10-14） | 公式按 `map_size` 归一化 → 与地图大小无关，无需改动；见 §5.5.2 |
| P2 | `_zz_inside` 在途任务 | 工程查不到源码 | 已清理，如有需要重建 |
| P3 | 卡住语义 | 用户明确="采矿车回不动" | T7 处理 |

---

## 4. RA2 规则移植进度（对照路线图）

详见 `RA2_RULES_MIGRATION.md` 与 `RA2_PORT_ROADMAP.md`。

### 已移植 ✅
- [x] 建造/占点/碰撞（footprint 多边形）
- [x] 经济闭环（采矿→卸矿→再生）
- [x] 维修厂进驻修理
- [x] 建造动画序列（bldanim SHP）
- [x] 鼠标锚点缩放
- [x] 点击命中 = 可见像素（WYSIWYG）
- [x] 护甲 11 类 + 弹头 Verses 克制
- [x] 防空（弹道 AA 标志）
- [x] 武器数据驱动（Primary/Weapon1..N）
- [x] 攻击特效（真实 SHP 动画）
- [x] 移动规则（ROT/Accelerates/Crusher）
- [x] 采矿卡死修复（流场 + 脱困）
- [x] 部署/卧倒（Deployer + Deployed 序列）
- [x] 矿车倒车入库
- [x] 武器开火音效
- [x] 单位语音（选中/下令/反馈/部署/阵亡）
- [x] EVA 播报
- [x] 电力系统
- [x] 星际2 化视觉（地表/岩体/水面/后处理）
- [x] 命中判定（Ra2Damage 完整模型）
- [x] 房色重映射（shader）
- [x] 右键只命令 + 海军页动态隐藏

### 待移植 🔄
- [x] PrismSupport 棱镜支援链（T5）—— 2026-10-16 完成，见 §5.7
- [ ] LaserFire 类武器（T6）
- [ ] 命中音效（开火音已有；`animations.json` 无 `start_sound` 字段，命中冲击音**数据缺失**，须先补提取管线）
- [ ] 盟军海军（`GAYARD`+`DEST/AEGIS/CARRIER/LCRF/DLPH/CDEST`）——依赖 C2「登录 + 水面移动」，本轮未做
- [ ] 超武建筑（`GACSPH` 超时空传送仪 / `GAWEAT` 天气控制器）——依赖超武系统，本轮未做
- [ ] 老兵等级（VeteranAbilities/EliteAbilities）
- [ ] 苏军阵营运行时
- [ ] 命令集（巡逻/警戒/守卫）
- [ ] 建造耗时公式
- [ ] 超武
- [ ] 地形/水 MovementZone/SpeedType
- [ ] 卡池局外养成（原创增量）
- [ ] 鼠标光标系统（T9/T12）

---

## 5. 技术备忘

### 5.1 深度排序
- 排序键 = `world.y - world.x`（越大越靠前）
- z 域：实体 ∈ [1, 3801]（`DEPTH_HALF=1900` + `OFFSET=1901`）
- 建筑用 `depth_anchor()`（占地形心），单位用 `global_position`
- 兜底：单位落在建筑可见体内且 z ≤ 建筑 → 抬到 `b.z_index + 1`（`_over_building_body`）

#### 5.1.1 血条/标签高层 overlay（T1b，2026-10-14）
- 新增常量 `DepthLayers.WORLD_HUD = 3850`（> 实体上限 3801，< PROJECTILE 3900）。
- `battle._build_world()` 建 `hp_overlay: Node2D`（z=WORLD_HUD），`draw` 信号连 `_draw_hp_overlay`。
- `battle._process()` 每帧 `hp_overlay.queue_redraw()`，统一绘制所有 unit/building 血条。
- 实体原内联血条已抽为 `draw_hp_bar(ci, origin)`（unit.gd / building.gd），由 overlay 调用。
- **关键坑（相机 45° 等距）**：实体有 `T(p)` 节点变换，overlay 是 `T(0)`；不能把世界坐标直接
  当绘制坐标，否则映射成 `S(z,z)·p` 飞离实体。必须在 `Iso.begin(hp_overlay)` 后以
  `Iso.dir(world)`（begin 的逆映射）作原点，才能与实体对位并直立绘制。

### 5.2 采矿车状态机
```
to_node → harvesting → to_base(两段式泊位) → unloading → to_node
```
- 流场寻路 `_steer_field_to`（挂 PathService）
- 卡滞脱困 `_track_stuck`（重算流场 / 侧移 / 换目标）
- 矿点认领 `ResourceNode.claim_by/claim_release`
- 泊位冻结 `_lock_dock`（300px 内不再漂移）
- 倒车 `_reverse_to`（车头朝外，速度 ×0.55）

### 5.5 寻路通行网格（T2，2026-10-15）
`PathService` 网格 `CELL=40`，`cost<0` = 不可通行；`_stamp_blocker` 对建筑走**占地矩形**分支
（`Placement.aabb(footprint_poly(), pos).grow(2.0)`），其它遮挡物走半径分支 `_stamp`（本会话未动）。

#### 5.5.1 漏格根因与修法
- **根因**：`_stamp_rect` 只标记「格心落在矩形内」的格（`rect.has_point(cc)`），等价于把阻挡区在
  四边各**内缩最多半格（20px）**；建筑/水域每条边都漏出一条 ~1 格宽的「可通行带」
  （实测：GAPOWR 几何上应占 9 格、实际只刷 1 格；GAPILE 应 16 只刷 4）。
- **症状**：单位贴着建筑外墙行进时，其所在格是漏格（流场视为可通行且方向指向建筑内部），
  被物理墙挡住后速度非零但位置**永久冻结**（实测 t=300 起 600 帧位置零位移）= 「卡住 / 回不动」。
- **修法（最小改动）**：`var grown := rect.grow(cell * 0.5)`，判定改用 `grown.has_point(cc)`。
  二者严格等价于「与矩形有正面积相交的格」（建筑对齐格线时行为不变，错位时逐边补回 1 格）。
  水衍同一缺陷，故 `_stamp_water` 简化为 `for r in water_rects: _stamp_rect(r)`。
- **验证**（无头探针，已删）：合成放置 GACNST/GAPOWR/GAPILE 漏格 9/8/12 → 全部 0；
  真地图 4 栋建筑漏格 9/7/7/4 → 全 0；全图阻挡格 509 → 589（+80，约 +1.25%），无窄通道堵死。
  端到端：E1 从建筑西北走到东南，修复前单位心最短距占地边 7.0px 且永久卡死（残距 251px 未达），
  修复后最短距 29.8px、正常绕行到点（残距 5.0px）。
- **安全点**：`FlowField.compute` 对**目标格不可通行**会向外最多扩 6 格找多源种子，
  故加厚阻挡不会让「建筑/岸边目标」变得不可达；单位落在阻挡格时 `_steer_dir` 兜底直行，不会零速僵死。

#### 5.5.2 T8 结论（DEPTH_HALF 大图够用）
`entity_z = round((y−x)·1900/map_size)+1901`，因 `(y−x)` 最大值 ≈ `map_size`，z 恒落在 [1,3801]，
**与地图尺寸无关**，>3800 大图不会被压层，无需动态化。代价仅是大图上沿对角线有一格级 z 并列，
属 RA2 本身也有的深度粒度，可接受。

### 5.6 采矿车「主动倒车」（T10，2026-10-15）
- **根因**：`_process_harvester` 的行驶段（`to_node`、`to_base` 泊位前段）**从不更新 `hull_angle`**；
  车身朝向一直是出厂初值 0°（朝东）。车体绘制按 `hull_angle`，于是任何向西/西南行驶看起来都在**倒着开**。
  实测（无头探针）：目标在西侧的矿车整段 `hull=0°` 而 `vel=180°`，倒车帧逐帧累加。
- **已有设施**：`_face_if_moving()`（把车头/炮塔对齐速度方向）+ 门禁 `_harvest_heading_free()`
  （倒车入库 / 卸矿 / `to_base` 倒车段返回 false）本就是为此预留，只是**未被调用**。
- **修法（最小改动，`scripts/units/unit.gd` 2 处）**：在 `to_node` 行驶的 `else` 分支、
  以及 `to_base` `_dock_phase==0` 行驶的 `else` 分支各补一行 `_face_if_moving()`。
- **验证**：修前向西矿车整段倒车帧持续累加（>239 帧 / 1600 帧）；修后仅剩掉头瞬态（CMIN `ROT`≈105°/s，
  180° 掉头约 0.85s 内 `diff>90°`）。9000 帧无头完整跑通
  `to_node→harvesting→to_base→unloading（倒车入库 back=true 仍在）→to_node→harvesting`，0 报错。
  有头截图：A 车 `hull=vel=180°`、B 车 `hull=vel=0°`，车头均对齐行进方向。
- **备份**：`_backup_20261015/unit.gd.before_harvest_heading`。

### 5.7b 矿体 RA2 式「散出来」（T11，2026-10-15）
- **用户拍板**：选方案 B（结构对齐）——把每个大矿点展开成多个小 `ResourceNode`；
  参数：**每处 4×3 格位（地图边界内保留需≥3 枚） / 总量守恒 6000**。
- **做法（`scripts/world/battle.gd`）**：新增 `_scatter_ore(center, 4, 3)` / `_spawn_ore_tile` / `_ore_tile_blocked`；
  常量 `ORE_TILE_SPACING=36`（格心距）、`ORE_TILE_SEP=30`（最小圆心距，略小于间距→邻格轻微相接）、
  `ORE_CLUSTER_TOTAL_AMOUNT=6000`、`ORE_CLUSTER_MIN_NODES=3`。
  - 每处在地图上铺开 **4×3 格位**（确定性抖动 seed = 中心坐标哈希），跳过 水域 / 建筑底盘 / 障碍 / 边缘外；
  - 每枚小矿格 `radius=sep*0.90=27`（逻辑毛径≈0.9×30=27px），单格储量 = 6000/格数 → **总量守恒**；
  - 地形太挤（可用格位 < 3）时退回 **单个大矿点**（保底不留空矿）；
  - 旧 4 个固定矿点坐标保持不动（不牵动其它建筑/寻路）；`_add_skirmish_ore` 同样走 `_scatter_ore`。
- **寻路关键点**：矿格是 `StaticBody2D` 但**不进 `path_service` 阻挡网格**（无阻挡格），寻路不受影响；
  4×3=12 枚同属一处，但各到质心距离 < `lock_dock` 300px → 矿车仍汇聚同一泊位，不四处乱跑。
  每片 12 枚合计 6000，每趟满载 20 的收入与旧单矿点一致（经 1~4 片后收入速度略降，属贴近原版的多矿位线）。
- **两个配套**：①（防矿主退回）`_face_if_moving()` 在采集行驶段已生效（§5.6）；
  ② 小地图已按邻近聚合显示，避免「一处矿体」被画成一堆小点。
- **验证**：无头探针 4 处 → 42 枚小矿格（每枚 540），总储量 24000 守恒，均无非法落点，无报错；
  有头截图——原本孤立圆堆 → 一片密集散矿，外观达标。
- **备份**：`_backup_20261015/battle.gd.before_ore_scatter`。
- **备注**：长周期无头日志出现的 `Invalid polygon data, triangulation failed`（来自 `unit.gd` 车辆痕迹四边形）在 T11 **之前就存在**（未改前基线 224 次，改后 158 次），与矿体无关，可忽略。

#### 5.7b 矿体放大（T11b，2026-10-16）
- 用户要求矿体更「一眼可见」→ **只调 4 个常量**（纯数值，无新逻辑）：
  `ORE_TILE_SPACING` 36→**46**、`ORE_TILE_SEP` 30→**38**、`ORE_TILE_WIDE` 4→**5**、`ORE_TILE_HIGH` 3→**4**。
- 效果：单格 radius 27→**34.2**（晶簇同步变粗），整片跨度约 162×126 → **约 252×206px**（面积 ≈2.5×）；储量仍守恒（每片 6000）。
- 常量区顶部已加注释：想再放大就改这 4 个数（缩放档位）。
- **实测发现（重要，供后续任务 T14）**：跑 60s 探针，每片矿体 16~18 格里**只有最近约 1 格**被反复采（其余恒为满量 1.00）——矿车其实**锁定最近矿格**（regen 2%/s 让它永不空），所以「散出来」目前是**纯视觉**。这与 RA2（收割机在矿田里巡游吸取）不同，属**行为**差异。
- **备份**：`_backup_20261015/battle.gd.before_ore_scale`。

### 5.3 音效管线
- 事实源：`data/ra2/sound_specs.json`（240 条，被引用者）+ `data/ra2/sfx_index.json`（1153 项，全库）
- 音频：`assets/ra2/sfx/*.wav`（1153 个，62.94MB）
- 引擎：`scripts/core/ra2_sfx.gd`（autoload `Ra2Sfx`）
- 构建：`node ra2pipe/sfx_build.mjs needed`（按引用增量）/ `... all`（全库，T3 已跑）
- 不可抽取：9 个 token（`gcamlo1a..f` 音乐、`irocdia/b` 过场语音等）不在 `audio.bag` 内，忽略。

### 5.4 光束/激光武器
- 数据驱动：`GameData.ra2_beam_spec(weapon_id)` 读 `weapons.json extra.*`
- 标志：`IsLaser` / `IsRadBeam` / `IsElectricBolt` / `IsHouseColor` / `IsBigLaser`
- 渲染：`Effects.spawn_beam(muzzle, target, color, kind, thickness, duration)`
- 已覆盖 27 把光束武器。**T6 激光全链路已接通**（`Comet`/`SuperComet`/`PrismShot` 的 `IsLaser/IsHouseColor/LaserDuration` 已提取并被 `ra2_beam_spec()` 消费）。**T5 棱镜支援链 2026-10-16 已完成**，见 §5.7。

### 5.7a 棱镜支援链（T5，2026-10-16 完成并验证）
- **结论**：RA2 光棱塔（ATESLA）"多塔合流"已全链路接通。数据早已提取（`weapons.json` 有 `PrismShot`/`PrismSupport`，`rules.ini [General]` 有全球 `PrismSupportModifier/Max/Delay/Duration/Height`），只是引擎没有链路概念。
- **RA2 语义**（照搬 ts-ra2 `AttackTask.ts` + `Projectile.ts`）：
  1. 光棱塔主武器开火时，遍历【同族友方、同为棱镜、已运转】的塔；
  2. 每座支援塔必须【自身也在目标射程内】（用 `Secondary=PrismSupport` 的射程 8 格 = 440px 判定），最多 `PrismSupportMax=8` 座；
  3. 每座支援塔射出一束支援光束到目标，本次伤害 ×（1 + 支援数 × `PrismSupportModifier`=1.5）；
  4. 支援塔随即离线 `PrismSupportDelay=60` 帧（4s）；
  5. 支援光束瞄准点抬高 `PrismSupportHeight` leptons。
- **本作简化**：支援光束为纯表现（不单独 `receive_hit`），伤害统一挂在主光束上，避免同帧多次命中。
- **改动文件**：`ra2pipe/build.mjs`（`[General]`→`prism` 块）、`ra2pipe/faction.mjs`（写 `prism_type`/`prism_support_weapon`/`prism_support_range`）、`data/ra2/general.json`（prism 块：type=ATESLA, modifier=1.5, max=8, delay=60, duration=15, height=420）、`data/ra2_allied.json`（重生成）、`scripts/autoload/game_data.gd`（`ra2_prism_rules()`）、`scripts/buildings/building.gd`（vars + `is_operational` 认离线 + 炮塔段门控 + `_fire` 乘链 + `_prism_support_chain()`）。
- **验证**：逻辑探针（已删）三塔+敌靶 → 倍率 **4.0**；支援塔 `_prism_offline=60`、`is_operational()=false`；超程塔不计（1.0）。有头截图确认 2 束房色激光汇向敌方发电厂，同局 `击杀 1`。900 帧回归 **0 报错**。
- **备份**：`_backup_20261016c/`。

---

### 5.9 本轮（2026-10-16）：防空 / 单位补全 / 音效全库
- **唯一数据源**：`data/ra2_allied.json` 由 `node ra2pipe/faction.mjs` 生成——**不要手改**该 json，改 `ra2pipe/faction.mjs` 后重跑。
- **T15 爱国者飞弹**：`faction.mjs` 的 `BUILDING_TAGS` 加 `NASAM: ['structure','defense']`。武器 `RedEye2` → 弹道 `AAHeatSeeker`（`aa=yes`）→ 运行时 `weapon.ra2_aa=true`。
- **T16 单位补全**：`UNIT_WHITELIST` 加隐藏科技步兵 `CCOMAND`（超时空突击队）/ `PTROOP`（心灵突击队，`Deployed=299` 即卧倒姿态）。
- **对空盘点**：全项目 `ra2_aa=true` 现为 `JUMPJET`/`FV`/`NASAM` 三项——**防御工事里只有 NASAM 能打空**。其余盟军防空建筑（如无）。
- **T3 音效全库**：`node ra2pipe/sfx_build.mjs all` → `assets/ra2/sfx/*.wav` 580→1153。之后必须跑 `godot --headless --path iron_tide --import` 让 Godot 重新导入，否则新 wav 在无编辑器运行时不加载。
- **本轮未做（分档）**：盟军海军（`GAYARD`+6 舰）依赖 C2 水面移动；超武建筑（`GACSPH`/`GAWEAT`）依赖超武系统；命中冲击音数据缺失。
- **备份**：`_backup_20261016/`（`faction.mjs.before_aa_units`、`ra2_allied.json.before_aa_units`）。
- **坑**：`edit_file` 同一文件**并行多次调用会互相覆盖**（后写者丢前者改动）——同一文件多处改必须用单次 `edits[]`。

---

## 7. 常驻准则（记忆库已满，暂存此处）
> 2026-10-15：`save_memory` 返回 `Memory limit of 100 entries reached`，且本会话系统提示中
> 无可见 Memories 条目，无法选定旧条目删除 → 关键准则暂存本档；待用户在
> Chatbox 设置 → 记忆中清理条目后再回填。

- **环境**：工程根 `iron_tide/`；Godot `C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe`。
- **非 git 仓库**：改动前自行备份（`_backup_20261015/`：`battle.gd.before_ore_scatter`（T11 前）、`battle.gd.before_ore_scale`（T11b 前）、`unit.gd.before_harvest_heading`、`path_service.gd.before`）。
- **工作准则**：改前先读源码 → 最小改动 → headless 编译自检 + 真窗口/探针对照 → 探针用完必删。
- **探针常识**：显式类型标注（`var total: int = ...`）否则 Godot 报 `Cannot infer the type`；
  无头运行加 `--quit-after <frames>` 兜底；`hud.gd` cameo 大小写 WARNING 为无害噪声。

---


### 5.8 T3 命中冲击音（2026-10-19）

- 事实源：RA2 爆炸动画在 `art.ini` 使用 **`Report=`**，不是 `StartSound=`。
  `EXPLOSML Report=Explosion13`、`EXPLOLRG Report=Explosion09`。
- `ra2pipe/build.mjs`：动画提取改为 `start_sound = StartSound || Report`，并保留 `report`。
- `ra2pipe/art_build.mjs`：fx JSON 增写 `sound`；`RA2Art.fx()` 读出；`Ra2Fx.play()` 在动画创建时播一次。
- `sfx_build.mjs needed` 自动从 `animations.json` 收集 Report 并抽出 WAV（本轮新增 ~615 个）。
- 验证：`assets/ra2/fx/EXPLOSML.json` sound=`Explosion13`，`sound_specs["Explosion13"]` → `gexp14a-d.wav` 均存在。

### 5.11 T7 采矿车回程（2026-10-19）

- 根因不是移动/寻路，而是**任务开局没有矿场**（m01 只有 GACNST/GAPOWR/GAPILE），
  采矿车满仓后 `_pick_home_base()` 找不到矿场，永远停在 `to_node`/装矿循环，表现为“回不动”。
- 修复：事件开局补 `GAREFN`（RA2 盟军开局本就 1 矿场 + 矿车），并把矿场放在基地左下。
- 探针：满仓强制 `to_base` → 状态 `to_base → unloading → to_node`，cargo 500→0。

### 5.12 T9/T12 光标状态机（2026-10-19）

- `battle._update_cursor()` 统一裁决：
  - 命令模式/建造/技能/超级武器 → `CURSOR_CROSS`
  - 悬停敌方 → `CURSOR_CROSS`
  - 命令“采集”或选中矿车且悬停矿田 → `CURSOR_POINTING_HAND`
  - 其余 → 箭头
- 矿田判定走 `resource_nodes` 组，半径 34px，与采矿车采集半径一致。

### 5.13 C2 海军水面移动（2026-10-19）

- 数据：`GAYARD`（Naval/WaterBound）+ 六舰 `DEST/AEGIS/CARRIER/LCRF/DLPH/CDEST`，
  `role=naval`、`built_at=GAYARD`、`water_bound=true`。
- `PathService` 新增独立 `water_cost` 网格与 `_water_fields` 缓存：
  水域可走、陆地/建筑 -1；陆军网格规则不变。
- `Unit.is_naval`：只用海军流场；`_move_water_safe()` 统一包住全部 `move_and_slide()`，
  岸线处做 X/Y 滑移并禁止登岸；陆海空分离互不挤压；海军跳过陆地障碍。
- 船坞只允许全占地落在水面（其他建筑禁止占水）；舰船出生点从船坞向 24 个方向找可通行水面。
- 探针：GAYARD 强制放置水面成功；DEST 出生即在水面，移动 143px 后仍在水中。

### 5.14 超级武器（2026-10-19）

- 数据：`build.mjs` 提取 `[SuperWeaponTypes]` → `data/ra2/superweapons.json`；
  `faction.mjs` 把 `GACSPH → ChronoSphereSpecial`、`GAWEAT → LightningStormSpecial` 挂到建筑。
- 充电：`RechargeTime`（分钟）×60；低电暂停；就绪播 `RechargeVoice`。
- 超时空传送：把当前选中己方单位按 3×3 网格搬到目标点，播 `CHRONOFD/CHRONOTG` + `ChronoMinerTeleport`；
  舰船落水、陆军落地。
- 天气控制器：`LightningDeferment=250` 帧预警 → `LightningDuration=180` 帧；
  每 10 帧命中目标点 250 伤害，每 5 帧在 `LightningCellSpread=10` 格内随机落雷；
  播 `WCLBOLT1-3` + `WeatherStrike`。
- UI：选中建筑面板出现充能百分比按钮；点击后进入 `command_mode="superweapon"`，左键选目标、Esc 取消。
- 探针：超时空 2 个 E1 位移 92px；天气落雷击杀目标；充能归零。

### 5.15 回归与探针（2026-10-19）

- 900 帧无头 `battle.tscn`：0 SCRIPT ERROR / Parse Error；`lobby.tscn` 120 帧 0 错误。
- 探针（已删）：海军位移/水域、超时空、天气、采矿回程全部通过。

### 5.16 寻路收尾与建造动画核验（2026-10-20）

- 本轮修改 `scripts/units/unit.gd`、`scripts/world/path_service.gd`、`scripts/world/battle.gd`：
  - 友军分离力方向纠正，避免把单位拉向彼此。
  - 脱困检测改为判断到当前路点的进展，正常绕障暂时远离终点不再触发重算/侧闪。
  - 编队间距包含车身直径、分离距离及两侧到达容差，减少到达后相互挤开。
  - 路径平滑遍历经过的网格，并遵守与 A* 相同的禁止对角切角规则。
- 修前真实战场复现：6 辆 MTNK 运行 120 秒仍只有 5 辆到达，剩余单位持续被友军/障碍卡住。
  修后同场景约 29.5 秒全部到达，移动指令结束、无车身重叠；保持 60 秒期限及 26 世界单位落点容差断言。
- 既有建筑展开代码无需改动：通过真实侧栏生产与合法放置入口验证，
  GAPOWR 只扣一次 800 费用、播放 3.6 秒展开动画、完成后可运转、占地保持稳定。
  实际 OpenGL 渲染采样帧为 0、10、20，并已检查展开中/完成截图。
- 新增 `tests/navigation_building_regression.gd` / `.tscn` 及
  `tests/run-navigation-building.ps1`；命令和边界见 `tests/README.md`。
  入口复制工程并使用独立存档目录，避免测试读写真实玩家局外进度。
- 验证：候选无头 23/23；实际渲染 28/28；写回后从原项目重新复制、导入并运行 23/23，
  回归前后源码指纹一致。未连接网络、数据库或 Unity。
- 本机证据：`C:\Users\admin\Temp\iron-tide-validation-20261020-1100\reports\`；
  交付复核：`C:\Users\admin\Temp\iron-tide-delivery-check-20261020-1130\reports\`；
  修前代码备份：`C:\Users\admin\Temp\iron-tide-validation-20261020-1100\baseline\`。
- 边界：这不是全机制 RA2 移植验收，未覆盖全部地图、兵种和规模。
  移动手感与建筑动画观感仍为 `pending_user_visual_confirmation`。

## 6. 变更日志索引

历次变更记录在 `CHANGELOG_*.md`，按时间倒序：
- `CHANGELOG_ra3_hpbar.md` / `CHANGELOG_hpbar_depth.md`（血条）
- `CHANGELOG_phase_a456.md`（建造/经济/视觉）
- `CHANGELOG_rules_m*.md`（规则迁移各批）
- `CHANGELOG_skill_unlock.md`（技能解锁）
- `CHANGELOG_house_color.md`（阵营涂装）
- `CHANGELOG_ra2_click_hit.md`（点击命中）
- `CHANGELOG_camera_pan_ra2.md`（相机）
