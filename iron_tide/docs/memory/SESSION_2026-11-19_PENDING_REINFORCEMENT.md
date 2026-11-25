# 未入场超时空增援不算阵亡（2026-11-19）

用户反馈：超时空增援尚未出来时不能算阵亡，否则每关都要救援。

根因：`run.gd::collect()`结算时会收集战场现存单位，并补回未出战编制旧库存；但 `runtime.gd`中仍未到期/未成功部署的单位只在 `world.allied_state.expedition_reinforcement_plan`，随后settle把 `next.reinforcements=[]`，所以未入场的出战单位被丢失，并可能表现为需要救援。

修复：`scripts/expedition/run.gd::collect()`在收集现存单位和旧库存后，读取 `world.allied_state.expedition_reinforcement_plan`，把每个待入场条目按满血、0军衔、0经验、原hero/variant加入 survivors。它们从未入场，因此不可能阵亡/负伤；settle后仍按普通幸存者进入下一关，`Heroes.update_wounded`不会把它们标伤。已入场后阵亡的单位仍走原规则。

回归：`tests/expedition_pending_reinforcement_regression.gd/.tscn`隔离用户目录最终3/3通过，exit=0，最终日志无脚本错误。覆盖待入场坦克回收、待入场英雄保留且不负伤、满血。中间测试曾因夹具不完整状态触发spawn_stats错误，已移除不必要现场单位后重跑通过。测试临时根目录 C:/Users/admin/AppData/Local/Temp/IronTidePendingReinforcement-b8d3dc100daf444c92e2ed559de3ff46。未人工跑完整胜利结算界面，未打包提交推送；生产正式代码只改run.gd，其他工作区修改保留。
