# Buff到期重复重算候选 · 2026-11-19

用户要求开始优化。已完成隔离候选和评估，未合入生产。

## 时序审计
progression_expansion.tick在_physics_process前段，常规_tick_skills在后段，两者之间存在英雄/阵营状态、回调及属性消费者，不可直接删除某一入口；未尝试空状态早退或固定名单查找。
更窄候选：_tick_skills调用_tick_buffs时仅延后其到期重算，统一由_tick_skills结尾重算一次。Ability.tick只递减cd_left/active_left；其余直接_tick_buffs调用默认仍即时重算。

## 隔离实现
candidate/scripts/units/unit.gd：_tick_buffs增加defer_recompute默认false，_tick_skills调用传true，到期时仅非defer立即重算。其他语义和回调顺序保留。
启动音乐Building/unit_id保护只在隔离副本，与优化无关，不合入。

## 验证
真实场景224项对照0失败：attack/defense/speed/electric_slow/leizhu_slow_20/regen/tesla_emp ×4种剩余时间×4种delta，比较buff数组、攻防、移速、生命。仍未覆盖全部英雄、全部复杂回调和自定义Ability派生类型，不称全面机制回归。
10批交替局部测试，每批3000次且每次都触发speed buff到期：参考中位14947us，候选10627.5us，下降28.9%。该负载刻意强化到期，不能外推真实战场。

## 决策
前一场真实slot3来源诊断verified/bonus-sources.json中，unit.gd:5218（_tick_buffs到期重算）来源条目为0。因此该候选未覆盖已观察到的46万次主热点重算，没有实际工作量收益证据。停止本候选，不合入、不做无意义完整图形ABBA、不计有效优化轮次。
生产代码未改，原始测试/候选/result.json/test.log/error.log完整保留。

## 后续
下一步须为常规两入口建立跨入口同单位同物理步的输入变化/属性消费证据，或继续碰撞查询内部阶段采样；不得因值未变就删除重算。不重复本候选或之前固定名单/空状态/单格复制候选。
未打包提交推送。整体性能目标未完成。