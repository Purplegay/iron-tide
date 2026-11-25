# 运行时性能任务最终交接（用户要求写记忆后结束）

用户最后指令：写记忆，结束当前任务，不再继续测试/改动。

最近完整结果见SESSION_2026-11-20_RUNTIME_CANDIDATES.md：AutoW单次技能槽解析、寻路_nearest_walkable越界裁剪两个候选均未推广。前者行为回归两版各24756通过，后者合成25600及真实slot2 2226、slot3 2004对照通过、局部约25%更快，但两档Release ABBA均无稳定整帧改善；外部游戏/测试干扰，不宣称收益。生产玩法没有本轮候选合入，未打包。不要重复这两候选当新方向。下一方向应按真实尖峰帧分解单位脚本、原生物理碰撞、寻路成本。

更早结果：SESSION_2026-11-20_P95_LOG_OFF.md（日志off slot2 P95115.184/slot3 84.761ms，受外部游戏干扰）；SESSION_2026-11-20_SHADOW_UI_LOG.md（5槽测试更新142/142、影子233/233/41步、15Hz仅观察原Node回调；需隔离副本field_operations循环依赖修正，不能说新集中调度通过）；SESSION_2026-11-20_SIMULATION_PHASE2_ABORTED.md（单位集中调度第二阶段撤回，保留第一阶段登记/空间索引，不能说底层重构完成）。docs/SIMULATION_REBUILD.md路线持续有效。网页RA2 refs/ts-ra2/LICENSE含未授权Chrono Divide派生部分，不复制，仅架构分析独立实现。

本轮新增tests/path_bound_reference.gd、path_bound_regression.gd/.tscn、path_bound_saved.gd/.tscn（整理引用后未复验）。实际实验源码/报告在.validation/autow-single-lookup-20261120-183206与.validation/path-bound-20261120。正式auto_w哈希4c5de4bf13319202ae17c6ec52b408a6121c35691d6ce9e8207033dab18d4e58。slot2原档ec911749e4c2effb5ae4885b4dd7c35e98185aa4ccab6befc1314e4ea388e125；slot3原档8a9bb4d7b37eb8689bfca8be9e291318fc739875dc1bc602ba28fabc8de003ca；最终均未变。多个窗口并行改源码，不覆盖/回滚其它修改，不停止用户游戏。全局记忆100条上限，此项目交接为持久记录。
