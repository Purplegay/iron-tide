# 索敌地空粗筛、静态弹体规则复用与 C4 评分（2026-11-26）

接续 `SESSION_2026-11-26_P95_THREE_TWO_ROUNDS_AND_TARGETING.md`。用户拍板两个方案同时合入并继续下一刀。本轮在工作区实现，未打包或提交，保留所有并行修改。

- `scripts/units/unit.gd::_refresh_target`：在已有同次扫描可共享武器的分支，第一次成功解析武器后，若非空、STANDARD 目标规则、未登载、无乘员且明确不能对空，后续伤害目标若是 Unit 且现场 `is_air_target()` 为真，则在精确距离和域验证前跳过。无重排行为、不是削减扫描频率；首个需解析武器的候选仍走完整检查。着陆、伞降现状实时读取；特殊目标和乘员仍走既有路径。
- 本轮最初实现按弹体 ID 同次扫描惰性缓存 `AG`。期间并行工作把 `AG`、`LandTargeting` 转为 GameData 规则编译，并把 `_weapon_domain_valid` 改为调用 `GameData.projectile_blocks_ground` / `unit_blocks_land_targeting`；保留该统一实现，不再叠加每次扫描 Dictionary 或改变资格函数接口。不认领并行规则编译为本轮独立改动。
- 下一刀：通过域验证之后的区段只计算一次 `CommandoCombat.building_c4`，供墙遮挡和评分共同消费；可贴 C4 时不跑会被覆盖的常规 `TacticalTargeting.score`，直接用原 `4 - d / max(1, sight)`。域验证内原 C4 规则、同分次序、命令、实际开火/贴弹逻辑不变。`WallArt.shot_blocked` 为读查询，普通评分无需保留被覆盖结果。

行为验证：真实 Godot 4.7.2 headless `tests/target_scan_reuse_regression.tscn`，最终源码 28 项通过、exit 0、stderr 空（`.validation/target-scan-reuse/current-out.log`/`current-err.log`）。普通对地候选在夹具中少做一次域检查而不改变目标；覆盖着陆、伞降、对空武器、同分组顺序、C4 自动选中建筑、已贴 C4 的资格、弹体规则重建与缺省。未证明所有地图、局部网格候选同分、实际开火时刻和完整 C4 战场行为；没有测整个存档粗筛命中率。

正式 Release 原始证据 `.validation/target-scan-reuse/`：旧快照（扫描内 AG 缓存，尚不含统一 GameData 复用及 C4）以存档 1、3×、30 s、1600×900、全特效、无插桩运行。B1 P95 328.674/P99 366.812 ms、模拟93.788s；A1只撤本轮当时两刀，P95 305.044/P99 329.887 ms、模拟93.962s；两场外部引擎审计通过。A2 546.036 ms采样有外部引擎，不纳入成绩；B2 启动前检测到外部引擎，未跑。最终组合 current-C1 也在启动前阻断（多个 Godot 与 IronTideRuntime 正运行）；未停止外部进程，不能用旧 A1/B1 宣称最终组合收益。只得到旧版单对观察，未形成两场同期基线/候选验收。

下次等游戏和并行 Godot 全部自然退出后，冻结当前组合，A/B 分别以同份工作区源码回退或保留粗筛/C4；统一 AG 规则保持为两边共有。先做专项统计：粗筛通过/拒绝、域检查次数、C4 候选数和实际少算的普通评分，再按既定存档 1 图形双样本验收。不要用多负载样本拼均值。
