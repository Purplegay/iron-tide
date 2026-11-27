# 存档 1 三倍速下的单位成长与渗透更新

2026-11-27。承接[上一轮静止重绘优化](SESSION_2026-11-27_IDLE_RENDER_AND_REGRESSIONS.md)。当前工程版本 0.32。存档 1 的 yr_isleland，381 个单位、207 栋建筑、5 个 AI。隔离测试进程关闭定时保存。所有正式帧测均使用发布版模板、独立未激活桌面、1600×900 全画质、3×、30 秒。原生全函数诊断单独使用调试引擎。使用 tools/performance_soak.py 的 --native-profile 与 --frame-only 两个独立入口。

基线原生采样实际执行 2382 个玩法函数。Unit._physics_process 含子调用耗时 24,462 ms。沿成长链定位到 progression_expansion_2.eligible 的单位类型判断和 expansion_2_infiltration.tick 的无状态计时、隐身检查、加速和重绘判定。Top 10 自身与含子调用排名、调用数、所有函数明细均见[原生函数记录](../../../.validation/20261127-growth-hotspots/hotnov-prof2/functions.md)。不同运行的单位步骤和开火数量会变化，父子含调用耗时重叠。

两处改动已写入 Iron Tide 工程，局部净收益以同进程交错测试为准。

- 渗透模块在单位未装备滩头预备，且没有上岸加速、隐身、护送冷却或护送增益时立即返回。普通受援步兵与未装备原卡但带有效果的存档仍推进状态。有效果时共享该步更新后的速度，用于数值重算和重绘判断。
- 二期成长的原有 24 种单位通过常量表查询。已保存二期效果、特殊飞机、无畏舰、所属阵营、技能卡与天赋继续使用原有规则。
- 尤里参考文件 refs/ra2yr-resource/src/object/techno.cpp 的 TechnoClass::Cloak/Uncloak 显式切换隐身状态（b01d3cf9）；网页红警 refs/ts-ra2/src/game/gameobject/trait/CloakableTrait.ts 在可隐身对象上管理冷却（898d8918）。借用能力或状态决定是否更新的结构。上岸触发、护送对象与持续时间沿用 Iron Tide 扩展。

## 验证

二期成长_infiltration_regression 199/199（脚本错误 0），二期成长_owner_regression 108/108（脚本错误 0），二期成长_regression 1035/1036（脚本错误 0）。渗透专项覆盖四档技能、上岸隐身与加速独立到期、开火与 C4 破隐、护送受益单位、存读档以及原版模式。

同一进程新旧函数交错 10 轮，每轮 20,000 次，中位单位为 ms。测试单位为携带二期状态、没有渗透和护送效果的 E1。

| 路径 | 改前 | 候选 |
| --- | ---: | ---: |
| eligible | 38.88 | 29.84 |
| tick | 118.58 | 17.05 |

| 调试采样 | 函数 | 调用次数 | 自身 ms | 含调用 ms |
| --- | --- | ---: | ---: | ---: |
| hotnov-prof2 | progression_expansion_2.gd.eligible | 160837 | 139.43 | 269.80 |
| hotnov-prof2 | expansion_2_infiltration.gd.tick | 14871 | 22.34 | 144.69 |
| hotnov-prof2 | expansion_2_infiltration.gd.speed | 49243 | 16.36 | 63.66 |
| hotnov-prof2 | expansion_2_infiltration.gd.escort_speed | 49505 | 14.44 | 24.96 |
| hotnov-prof-after | progression_expansion_2.gd.eligible | 151110 | 116.02 | 241.52 |
| hotnov-prof-after | expansion_2_infiltration.gd.tick | 13128 | 7.84 | 26.38 |
| hotnov-prof-after | expansion_2_infiltration.gd.escort_speed | 4196 | 1.80 | 2.90 |
| hotnov-prof-after | expansion_2_infiltration.gd.speed | 3986 | 1.70 | 6.77 |

资格交叉矩阵和旧效果逐步比对 488/488 通过。1,640 项运行源码及配置指纹仅两个目标脚本不同。成长总回归与基线逐条比较，1,036 个断言结果一致。其中既有失败为 V3 天赋上限，配置实际有空爆子母弹、失联预案和发射隔舱三项。候选的全函数复采检测到外部引擎，并且推进的模拟时间不同，函数调用数只用于确认分支变化。

## 发布版 P95

可比较的独立测量组数不足。

| 场次 | P95 ms | 帧数 | 外部 CPU 估算 % | 并发审计 |
| --- | ---: | ---: | ---: | --- |
| base-1 | 410.68 | 131 | 24.51 | 通过 |
| opt-1 | 462.23 | 121 | 42.59 | 检测到外部引擎或缺少干净样本 |
| opt-2 | 499.19 | 109 | 35.12 | 检测到外部引擎或缺少干净样本 |
| base-2 | 539.73 | 80 | 75.36 | 检测到外部引擎或缺少干净样本 |

[采样与证据索引](../../../.validation/20261127-growth-hotspots/summary.json)。首个控制台启动器的私有桌面诊断未通过窗口核验并已剔除。局部净收益按同进程计时验收，整帧结果单列。
