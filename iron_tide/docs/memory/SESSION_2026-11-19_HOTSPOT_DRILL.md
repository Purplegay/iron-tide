# 耗时继续下钻 · 2026-11-19

本轮只完成新热点定位与移动边界诊断，没有推广候选，没有修改生产游戏代码。不重复固定名单查找或空状态早退。

## 测量
使用上一轮相同slot3/meta，yr_isleland，334单位/206建筑/玩家+5AI，1倍速，15Hz，64补步。Debug/headless全函数计时仅作诊断，不作Release完整帧验收；inclusive父子不可相加，边界包装也有额外调用开销。

- diagnostic：60.752墙钟秒/63.317模拟秒，2142个执行过的业务函数。生产source-audit发现battle_screen.gd和battle.gd并行变化，只作辅助定位。
- movement：冻结准备漏复制icon，未进入游戏；保留原失败。
- movement-retry：游戏退出0但脚手拒绝。启动音乐阵容采集对Building调用AlliedAbilities.flag，访问unit_id出错，本场作废。
- 隔离frozen副本仅给该调用增加actor is Unit保护，不写回生产，不作为正式功能修复验收。
- frozen-profile：完整60秒诊断成功，source-audit无漂移。桥层移动65597次/1778.330ms inclusive；碰撞例外查询65629次/981.160ms；属性重算456718次/2630.000ms。
- movement-boundaries：只在隔离副本将原生move_and_slide及临时例外清理包进独立函数以测边界，source-audit无漂移，无脚本错误。60.333墙钟秒/62.501模拟秒，峰值379单位。

## 移动边界结果
|函数|调用数|inclusive ms|
|---|---:|---:|
|_slide_across_bridge_layers|64268|1632.140|
|_traffic_collision_exceptions|64313|900.660|
|_diagnostic_native_slide|64268|625.520|
|_diagnostic_remove_exceptions|64268|10.920|
|friendly_unit_pair（全场全部入口）|72782|237.460|
|battle_neighborhood.nearby（全场全部入口）|145207|857.460|
|PathService.near_deck（全场全部入口）|2883|9.980|

跨场模拟轨迹不同，不能用两场总耗时相减认定优化。全场公共函数耗时尚不能全部归于碰撞例外这条边。

## 下一步
优先对_traffic_collision_exceptions内部“邻居查询→距离筛选→友军通行判定/安装例外”分别采样，并记录候选数及最终临时例外数。清理例外仅约11ms，无证据优先改它。原生移动约626ms也不能当作脚本循环成本。另一个后续目标是_recompute_bonuses的调用来源与必要性，但不做泛化空状态早退。

本轮无新的优化候选，所以没有ABBA提速结论。用户授权继续优化仍有效；下一会话从上述边计时接续，不重跑固定名单/空状态方向。未打包提交推送，未覆盖并行改动。环境/原始日志及所有函数榜保留在本目录。未新增独立外部游戏进程审计，不声称背景环境已完全排除。