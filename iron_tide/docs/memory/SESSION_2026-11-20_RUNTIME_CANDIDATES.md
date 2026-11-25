# 运行时优化两候选：不合入
用户要求开始优化。证据均在iron_tide/.validation，正式玩法零合入，原slot2/3最终hash未变。

1 autow-single-lookup-20261120-183206：原evaluate通过enabled/card_id/index重复解析W，候选在一次同步决策中解析一次，不跨帧缓存，Building路径保留。两版分别auto_w402、skill_eligibility24354全部通过，无脚本错误。真实Release1600x900/15Hz/1x/日志off/frame-only/preserve-player/meta/no镜像，slot2与3各30s ABBA八场，source-audit无漂移。slot2原均值67.975/P95106.238 vs候选75.186/122.020；slot3原63.381/97.366 vs候选61.535/91.806。全部external=true，波动且slot2恶化，不推广。

2 path-bound-20261120：_nearest_walkable裁掉必然越界格子，保留每圈dy/x次序、距离/平局/zone判断，无缓存。合成25600项精确对照0失败，8批原81-87ms→新12-14ms，偏越界负载不推整帧。真实存档网格/单位位置与move_target查询重放，slot2 2226/0，slot3 2004/0，8批交错局部中位old52.706→39.692ms、55.275→41.522ms（约25%）；非实战收益。Release同入口ABBA八场，slot2原67.524/P95110.052 vs候选75.245/125.628；slot3原50.691/75.206 vs候选53.384/81.538。外部进程变化：仅slot3末a2 external=false，其余true。两场景整帧无收益证据，不推广，不拿不同负载区间相减。所有运行source无漂移exit0。禁止把该候选再当新方向重复。

冻结源码来自上一轮已通过UI/shadow的兼容快照（field_operations preload→load仅副本修正），AutoW取当前生产，不是完整当前生产等价快照。模拟约33.6-34.3秒/30墙钟的偏差保留，未解决。外部用户游戏/其他任务未停止。没有新增P95验收、没有新包。

新增可复跑夹具tests/path_bound_regression.gd/.tscn、path_bound_saved.gd/.tscn、path_bound_reference.gd（冻结当前原_nearest_walkable）。候选实现仅.validation/path-bound-20261120/candidate/scripts/world/path_service.gd。原夹具res://old_nearest.gd只存在候选根，已将生产夹具引用整理为tests/path_bound_reference.gd；整理后未复验，不误称最终版本已测试。

最终生产auto_w SHA4c5de4bf13319202ae17c6ec52b408a6121c35691d6ce9e8207033dab18d4e58，path_service当前54f3d8bf7fdc2893b4f6fe5bbca8da0367c06fd92278b1e82f27a1f5dfbdd135（既有并行修改，不属于本轮合入）。下一步应沿真实慢帧分解单位更新/原生物理/寻路尖峰，不能因局部快25%就推广。用户授权重构持续，不能把本轮两候选结束说成优化任务完成。全球记忆满，交接在此。
