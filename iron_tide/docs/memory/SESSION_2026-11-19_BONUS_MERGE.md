# 属性重算合并候选评估 · 2026-11-19

用户要求开始优化。本轮只在隔离副本尝试合并：progression_expansion.tick正常返回路径不再立即调用_unit._recompute_bonuses，交给同一物理步后面的Unit._tick_skills结尾统一重算；特殊英雄、临时单位、事件/提前返回路径保持原即时行为。生产源码未改。

## 正确性
- candidate/tests/bonus_merge_regression.gd真实战场回归2/2通过，覆盖36单位（E1/MTNK/HTNK/MGTK/V3/DEST/DLPH/CARRIER/BEAG）、攻防速buff、progression_v1、240物理步、事件buff即时防御及普通路径运行。
- 隔离项目exit 0，无脚本错误（bonus-merge-candidate），证明该窄改动基础行为可运行；不是全规则回归。

## 计数/性能测量状态
- 首次全函数profiler：基线完成，_recompute_bonuses 401239次；候选因外层110秒等待超时被中断，只有部分profiler导出，不计对比。基线host审计外部游戏存在，亦不作干净收益证据。
- 后续轻量计数器脚手复制错误，首次数组只有7项却注入slot7，产生持续Index 7越界并使场景超时；修正写入了错误工具副本/未同步到实际运行副本，重跑仍同样报错。所有这类场次作废，不采信调用数/耗时。
- 本轮没有任何Release ABBA，未声称性能收益。

## 决策
候选不合入，不推广；隔离副本和失败日志完整保留。本轮唯一可用结论是行为回归通过，不能证明真实战场收益。用户正式游戏进程未停止；生产代码未改。已避免重复固定名单查找、空状态早退和已否决的碰撞局部候选。

## 下一步
若继续，先修复/单测诊断脚手本身（计数数组扩容必须与实际运行复制的unit_call_probe一致），然后用无原生profiler的短计数场验证调用数；但整帧验收前必须排除外部游戏。也可回到变化字段/全局依赖审计，不应直接推广“正常路径必可合并”的假设。
证据目录：本目录 base/candidate、baseline、candidate-diag、base-counts及日志；未打包提交推送。