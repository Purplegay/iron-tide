# 属性重算调用来源诊断 · 2026-11-19

用户要求开始查看下一方向，本轮仅来源诊断，生产逻辑未改，未实施优化候选。避免重复固定名单查找、空状态早退及碰撞查询局部复用/单格复制候选。

## 方法与证据
冻结当前源码，在所有直接_recompute_bonuses调用处加来源标签；重算入口探针统计调用数、单位类型、攻防移速三个输出前后是否完全相等与包围耗时。使用相同slot3/meta，334单位206建筑/5AI，Debug headless 60.058墙钟秒、63.800模拟秒，峰值376单位。verified/source-audit.json无漂移，脚手退出0，无脚本错误。
原始数据 verified/bonus-sources.json、callsites.json、verified/result.json及host-cpu.json保留。两次早期脚手缩进失败（换行格式/字符串注入）未运行有效场景，日志保留，不算测量。
隔离副本继续包含启动音乐Building/unit_id调用保护，与生产功能无关、未合入。

## 来源结果
|调用点（冻结源码行号）|次数|攻防速变化次数|包围耗时us|
|---|---:|---:|---:|
|unit.gd:5099 _tick_skills|293669|0|1094964|
|progression_expansion.gd:26 tick|166434|0|780452|
|unit.gd:5519 部署|23|23|353|
|tank_hero.gd:247|19|12|232|
|expansion_cards.gd:196|4|0|40|

总计460149次、35次输出变化。两个常规入口合计460103次，占99.990%。重算值未变不等于调用不必要，也不是证明没有依赖变化。探针前置统计开销不在包围时间内，但会影响调度及缓存；耗时只辅助定位，不能当Release性能收益。

## 环境限制
测量期engine_process_audit.measurement_requires_review=true（外部游戏存在）。本轮为调用来源诊断，不作完整帧收益比较，也未声称环境干净。后续Release验收须先排除外部游戏；不停止用户进程。

## 下一步
对_tick_skills与progression_expansion.tick之间的实际时序、输入写入和消费者做审计，量化同一个单位/物理步跨入口重复次数。现有same_physics_step只按同来源同单位统计，不能拿来证明跨入口重复。重点检查_tick_buffs到期会在_tick_skills最终重算之前再重算，扩展状态tick也可能即时重算；需保证移速、攻防读取及回调语义。若设计按步合并或脏标记，必须完整覆盖add_buff/clear_buff、直接buffs和special写入、部署、归属变化、斜坡、英雄成长、存档恢复及实时养成，不能仅因输出未变就删调用或泛化空状态早退。

无优化合入、无ABBA，本次完成“查看来源”。未打包提交推送，交接同步到项目docs/memory。