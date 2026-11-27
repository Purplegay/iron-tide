# 2026-11-27 战役中立单位避障

## 问题与决定

战役里中立居民是实体碰撞体，但原 `Battle.path_for_unit` 主要按静态地形和同边部署单位规划；`LocalTraffic.stalled_blockers` 只接受友军。`BattleRequest.friendly` 没有把玩家和 `neutral` 视为友军，所以旧逻辑会直走、顶住后重复求直线，仅靠临时侧闪脱困。没有更改中立外交、目标识别、碰撞例外、任务脚本或地图数据。

原图依据：本轮使用盟军第二关《好莱坞与虚荣》现有零售地图迁移。`scripts/world/hollywood_bases.gd` 依载入的居民摆位及房号生成 `neutral` 角色；真实 Battle 装配含 41 名 `CIV*` 中立居民。本次是连续世界寻路修复，不宣称复刻了零售引擎内部避障算法。

- `scripts/units/local_traffic.gd`：每次求路或实际卡滞，从空间索引找当前路段前方最多 240 世界单位内的可见、同层、实际有碰撞的中立地面单位；只有占住路线才把附近中立单位按车身结合半径临时交给现有求路器。初次求路忽略主动移动的中立单位；卡住重算时也可绕开虽有命令但几乎没动的中立单位。不触发中立让路或移动其自身。高架桥面专用路线保留原有逻辑；遭遇战、无尽、远征和空海移动不使用本次规则。
- `scripts/world/battle.gd::path_for_unit`：初次/普通求路纳入临时圆；卡住时通过既有 `stalled_blockers` → `_recover_stalled_path` 或矿车的 `_track_stuck` 传递。不永久占格、不修改共享地形网格。障碍完全封死时没有保证一定能绕行。

## 验证

Godot 4.7.2，隐藏控制台，隔离 APPDATA，真实 `scenes/battle.tscn` 好莱坞地图；冻结关卡脚本和战斗，在实际开阔地面 `(3600,8600)` 受控摆位，用选择单位和 `_command_move` 下达玩家移动命令，逐物理步推进。`--headless --path <project> --fixed-fps 120 --quit-after 50000 res://tests/campaign_neutral_traffic.tscn`，环境变量 `APPDATA` 与 `IRON_TIDE_TEST_PROFILE` 同设独立目录。检查脚本主动退出和 stderr，不把看门狗退出当成功。

- 修改前 12/14，修改后 14/14（退出 0，两边 stderr 空）。两项差异是灰熊坦克下令即得到绕行路线、步兵遇到后出现的居民时卡滞重算实际得到绕行路线。坦克完成订单 210→136 个模拟物理步；步兵插入居民后 215→207。该数据仅指本摆位，不是性能或全战役估计。居民没有被移位或受到伤害；未显露、非实体、不同桥层、正在移动的居民不参与初始规划；共享地形代价不变。
- `native_bridge_traffic_regression.tscn` 同一工作树的隔离前后对照（基线仅撤回本轮代码），均 29/30、stderr 空：RA2 灰熊坦克一项对岸到达判断在相同坐标 `(6235.856, 3082.529)` 失败，未修此既有桥梁问题。
- 证据：`.validation/campaign-neutral-traffic-20261127/` 的 `final-before.*`、`final-after.*`、`bridge-before.*`、`bridge-after.*` 和两个桥梁 JSON。玩家存档未改。
- 未验证：自然游玩整关、大编队、狭道拥堵、矿车/AI 端到端、桥面专用中立避障、冷读档和有头体验；未打包。高桥桥面及上下桥仍不是本修复的适用范围。
