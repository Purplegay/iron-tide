# Iron Tide 性能优化合并交接（2026-11-26）

**接手先看本页。** 汇总本串从存档1热点、命中/AI/贴图、索敌、移动交通、尤复堵路，到桥梁路径版本和原生网格填表。下方链接是详细原始记录，不是重复待办。本次交接无新增游戏逻辑、无复测、无提交打包；「合入」指主工作区源码，不表示 Git 已提交或发布。

## 1. 当前 P95 与测量口径

玩家目标是六家完整图形战场 16 ms。固定存档1 `yr_isleland`，初始381单位/207建筑/5 AI，Godot 4.7.2 Release、1600×900、3×、30秒墙钟、保留玩家、私有未激活桌面。原始报告 `.validation/p95-hotspots-20261126/report.md`：当时两场有效P95 229.076 / 226.074 ms（不同源码，不能跟现在算净收益）。

最新当前工作区无强制断修、无函数插桩两场：P95 **329.661 / 295.318 ms**，P99 **339.128 / 325.565 ms**，145/142帧，推进93.738/93.416模拟秒。冻结运行源码指纹一致、无脚本错误；均检测到外部引擎，第二场记录主源 `campaign_cg_catalog.gd` 并行漂移，属带负载观测，非正式干净验收。证据 `.validation/current-p95-next-20261126/p95-{1,2}/`，详见 [当前 P95](SESSION_2026-11-26_CURRENT_P95_BRIDGE_RESTORE_NEXT.md)。较早 478.480 / 388.707 ms 两场同样未组成有效双样本，见 [早期复测](SESSION_2026-11-26_P95_THREE_TWO_ROUNDS_AND_TARGETING.md)。

用户允许外部游戏开启时继续隔离测试，不停止外部进程；有重叠必须标记，不能当净整帧收益。函数插桩、固定事件的同步耗时、事件后整帧、自然存档整窗P95是四种不同口径；父子包含耗时不能相加，不把不同补步数的诊断相减。固定样本保留原存档与 meta，`IRON_TIDE_CALL_LOG=0`，性能 runner `../tools/performance_soak.py`；正式自然存档用 `--release-template --isolated-desktop --render-size 1600x900 --frame-only --host-cpu --preserve-player --seconds 30 --speed 3 --expect-map yr_isleland`，函数诊断另用 `--engine-phases`。同源 A/B 检查业务指纹、输入、模拟推进、脚本日志和进程审计；带负载不与空档混均值。

## 2. 正式工作区已在用的改动

| 方向 | 实际代码与行为 | 已验／未验 |
|---|---|---|
| 首批命中、AI选兵、贴图 | `Unit.receive_hit` 只在原入口条件可能生效时调用 MGTK/APOC 的两类防御；不改伤害/死亡顺序。`HouseAI.train_army/choose_combat_unit` 同轮复用静态兵种资格，价格和 `can_queue` 仍实时。战场恢复后预热现存建筑活动/待机页；已出现 SHP 单位只排站立入口页，队列去重。 | 局部9/9，完整对局收益未证。LRU 已撤回；未在下单时同步加载或接出厂预取。见 [首批候选](SESSION_2026-11-26_P95_THREE_HOTSPOTS_CANDIDATE.md)。 |
| 索敌地空、弹体规则、C4 | `_refresh_target` 仅已解析且可共享的普通单武器明确不可对空时，对后续实时在空候选做保守拒绝；不改同分顺序。采用并行 `GameData` 统一预解析 AG / LandTargeting，未再嵌套同轮字典。C4 在域验证后共享一次判定，直接用原 C4 分数，不算注定被覆盖的普通伤害评分。 | 当前组合专项28/28。旧版本 A/B 单对不代表现组合；无正式净 P95。见 [索敌接入](SESSION_2026-11-26_TARGET_SCAN_AIR_AG_C4.md)。 |
| 邻居宽名单（并行接入） | `local_traffic` / `vehicle_steering` / `battle_neighborhood` 当前是**整场复用、变化失效**，没有旧 TTL。出生/移除/跨格走桶版本，Watch 检查同格进入及碰撞层；锚点、查询范围/半径等照原约束；小场景物理回退仍实时查。 | 2079专项，桥专项与基线同8失败，查询重建/逻辑步下降56.7%，总CPU/P95未证。 [当前缓存交接](SESSION_2026-11-26_BATTLE_LIFETIME_TRAFFIC_CACHE.md) **替代旧两帧待办**。 |
| 尤复普通地面堵路 | `yr_blockage_policy.gd` / `Unit._ordinary_move_blockage`：仅实时已确认的友军拥堵，`PathDelay=.01` 分钟=0.6规则秒，`BlockagePathDelay=60`基准规则帧=4规则秒，`CloseEnough=2.25`格（123.75px）。短重试不清长钟；同单位同一步只消费一次；解除/新指令/换路清状态。提前停还需静态友军占终点、自身不重叠且地形与层级合法；不是通用抵达半径。矿车、维修、显式攻击、攻击移动、空海、两栖等保留原路线。 | 132/132。旧7点A/B 同450步，恢复调度28,042→24,807（−11.5%），却重算481→547，计时点累计自身603.791→626.284ms；不是加速。堵塞钟瞬态、冷读重建，未测密集堵塞持续时长。见 [堵路接入](SESSION_2026-11-26_YR_BLOCKAGE_INTEGRATION.md)。 |
| 单位延迟任务 | `AIUnitDispatch` 原本就按单位＋类型合并；本轮只去掉等值等待登记。路径同一步不重写、跨步续期；索敌与 pending 标记一次；相同 operations/recover、同一 board 目标不覆写；新目标、微操时间、结构化交互和玩家显式队列不改。 | 26/26，未对等值比较与写入做净收益 A/B；`defer_job` 约0.19ms/慢帧，不是下一优先。见 [任务合并与热点](SESSION_2026-11-26_PENDING_TASK_MERGE_HOTSPOTS.md)。 |
| 桥梁局部路线版本 | `BridgeDamage.restore/_route_change_bounds` 合并旧新桥旗标和断段差异；仅原生图、无遮罩、恰好单 epoch，且范围外五种网格与形状一致才登记局部历史，证明失败继续全局回退。仍完整重建，不改碰撞/路径安全。 | 合入后六段含双断段46/46；候选桥段回归344/344；固定两对12条远路全复用、跨段仍失效。实车写盘8/8、独立进程冷读6/6，先上桥才执行一次排队下桥。未测密集堵桥断修实车。见 [桥局部范围续测](SESSION_2026-11-26_BRIDGE_ROUTE_BOUNDS_FOLLOWUP.md)。 |
| 原生通行网格快路径 | `PathService._stamp_native_aligned`：55px原生对齐、无遮罩、范围不超原图时，每次取一次 packed mask，断桥旗标写副本，直接按行填原值；其它情况走旧实现。已合入无测试开关版本。 | 37图58状态、七数组10,529,820对应元素零差异、4类回退正确；桥回归344/344、写盘8/8、冷读6/6。[网格验收](SESSION_2026-11-26_NATIVE_STAMP_MATRIX_GATE.md)。全图形固定六段12次断修 ABBA：同步累计 213.981→121.913ms、215.144→115.277ms，逐事件24/24更短；整帧有外部负载，不宣称正式P95。见 [图形ABBA](SESSION_2026-11-26_NATIVE_STAMP_MERGE_EVENT_AB.md)。 |

原版资料：两份零售 `rulesmd.ini` SHA256 一致，三项参数已核实；不要把社区网页版 `MoveAsideTask` 或本地重建 `CanEnterCell` 占位当零售精确调用顺序。先读 [桥坡交接](BRIDGE_PORTING.md) 与 [斜坡记录](YR_SLOPE_PORTING.md) 再改通行层、桥损或格高。

## 3. 热点的因果链：不要把重算增加归错

- 旧7点 A/B `_repath_now` **481→547**：恢复入口 +17，未标记入口 +49。新26点补测同450步 **486→584**：`_steer_dir` +102、卡滞恢复 −4，其余标记入口0；旧49不能逐笔回填。[归因与实车桥层](SESSION_2026-11-26_BLOCKAGE_REPATH_BRIDGE_REVIEW.md)：现成单车上桥、下桥、桥正下方绕引道11/11；队列真实冷读验证同条记录，不涵盖桥头密集堵车。
- 路线核验专项 **12,100** 次中，512复用、11,202 AI拒绝、212刷新预算拒绝、**174实际重算**。其中 **121** 是桥更新后缺局部历史，35终点不同，13未标记原因的缺历史，5确实相交。桥局部历史已针对前者；不能把121都算成可省，也不能把等待申请当执行。见 [版本归因](SESSION_2026-11-26_ROUTE_EPOCH_BRIDGE_ATTRIBUTION.md)。
- 常态热点最后一次 41 点诊断：`_process_combat` **88.76ms/慢帧**，直系 `_move_toward`29.49、`_move_water_safe`22.86、`_tick_path_stuck`7.12；`_refresh_target`54.02（域10.42、墙体7.72、扫描准入3.67）；`progression_expansion.tick`43.67（第二阶段10.66、属性重算7.86）。均为插桩父子数据，不是可节省量。更窄26点诊断中 `_move_water_safe → _slide_across_bridge_layers`14.41，后者→临时碰撞例外7.44、桥层记录0.45。新的当前版**常态**函数分布还需重测。[当前热点](SESSION_2026-11-26_PENDING_TASK_MERGE_HOTSPOTS.md)｜[移动下钻](SESSION_2026-11-26_CURRENT_HOTSPOT_MOVEMENT_REVIEW.md)。
- 交通全窗口 `ensure_candidates` 95,733次，非步兵49,570次中73.1%复用，Watch 266,203项捕获639次入圈；区域比187,971格，避让列表96,581访问中84.3%几何淘汰。转向1296次同位置复用仍扫9046 Watch 项，但同一个物理步不证明所有候选位置不变。[循环归因](SESSION_2026-11-26_TRAFFIC_LOOP_ATTRIBUTION.md)。

## 4. 已判退或未推广：不要原样重做

| 尝试 | 裁决 |
|---|---|
| 共享贴图 LRU 命中删插 | 已撤回，主页引用常绕过共享字典；优先减少同步加载，不靠放大预算宣称收益。 |
| `apply` 扫掠窄框 + `wide.find` 保序 | 28,657次候选身份与次序0差异；256px整桶访问107,115→139,705，局部81.00→130.57ms。不推广。[原始记录](SESSION_2026-11-26_TRAFFIC_SWEEP_SHADOW.md) |
| 按物理步共享精确矩形、全局失效 | 小矩形影子命中8.1%，局部查格看起来下降，但固定先旧后新、未含完整处理，只留研究证据。[记录](SESSION_2026-11-26_GRID_SHARED_PROBE.md) |
| 中心格＋周围8格，成员变化擦周围9个中心 | 合格命中53.7%、顺序零差异，计入失效67.760→72.337ms（+6.8%），判退。不是已测过用九格直接替代 `apply` 的全部宽查询。[记录](SESSION_2026-11-26_CENTER_NINE_YR_BLOCKAGE.md) |
| `BridgeDamage.restore` 合并状态扫描 | 同样断修哈希一致，ABBA全段一进一退，未合入。不再原样合并地图/血量/维修屋扫描。[记录](SESSION_2026-11-26_CURRENT_P95_BRIDGE_RESTORE_NEXT.md) |
| 水域/两栖表写回原生逐格循环 | 全部网格一致，独立派生约13ms→0，但填表加重，重建54.11→55.64与49.43→51.63ms，桥全段90.77→98.45与80.68→91.17ms。两对均输，判退，正式 PathService 保留单独派生。[记录](SESSION_2026-11-26_FUSED_WATER_DOMAINS.md) |

另保留历史禁令：不重复固定名单字典、空状态早退、纯距离复用、单纯延长索敌间隔；不调低实际模拟步或删桥层安全检查充当收益。`prepare_turn_reuse_shadow.py` 是未在本串执行的独立同步链设想，不是合入项。

## 5. 下一位从哪里开始

1. **先问要降常态 P95 还是只降桥尖峰。** 若目标仍是16ms的常态战斗，先以当前工作区冻结源码复测最大子调用，优先 `Unit._process_combat → _move_water_safe → _slide_across_bridge_layers → _traffic_collision_exceptions`。拆候选遍历、实际 add/remove、物理移动与桥层记录；同时看 `_move_toward → LocalTraffic.apply/ensure_candidates`，必要时审 `apply → open_corridor` 同步复用，不能只按帧号跳过 Watch。共同 review 时用逐行注释 Go 伪代码指出内外层循环。
2. 若继续桥尖峰，先统计断修实际变化的原图旗标、断段和通行格数量，再评估能否安全**少重建格子**；原生逐格已加速且合入，不再融合水域表或重复桥状态合并。现范围证明必须保留，任何替代要逐格对照全部域与形状，并覆盖桥上/桥下、引道、断修、实际走车、存读档。
3. 定向行为先过，再比较成本和整帧；有外部进程可继续观察但单列。不要用调用次数下降宣称提速，不用旧源码、强制桥事件和自然对局的P95横比。玩家存档不动；交付标清哪些是工作区改动，哪些只在 `.validation`。
