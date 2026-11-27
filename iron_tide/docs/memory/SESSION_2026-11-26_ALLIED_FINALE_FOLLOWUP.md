# 终关继续复查：资金箱和第五支陆路袭击

续 `ALLIED_FINALE_SCRIPT_RECHECK` 和 `ALLIED_FINALE_ENDGAME_BRANCHES`。对照 Steam ALL07SMD 解包索引（地图 SHA `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`）：`04F0AACC` 初始启用、简单／普通、20 时间字段，动作 108 在 AU/AV 放置类型 0；参考枚举类型为 Money，本项目按零售 General.SoloCrateMoney=5000。切片及导出工具登记，`allied_finale.gd` 在实际可见时显示资金箱，己方未搭载地面单位踩同格一次性拾取。资金箱位置及拾取状态随现有 allied_state 保存；清剿旧档不补造，非胜负目标。复用项目现有资金箱图，未新增兵种或重烘资产。

`0B829CAC` 关联 `08D6A1CC`，原图 TZ（545）是陆地，编组 4 INIT + 1 VIRUS，没有 YHVR；本次 `allied_finale_ai.gd` 和导出数据补第五队，保留 521→106 的原图路点，沿用现有任务调度与最后的攻击移动适配。没有接完整变量 22 的卸载互锁和回到第一队的零售可重入循环，当前仍按前四队适配时序后再出第五队。首次支线回归通过不等于第五队自然行军/交火已证实。

Godot 4.7.2 真实菜单、隔离无头，`tests/allied_finale_playable.tscn` 主线 55/55、`-- --branches` 45/45、雷达后 `-- --cold` 5/5、真实存档5隔离副本 `-- --slot5-cleanup` 8/8，均退出0且 stderr 空，日志 `.validation/finale-followup/`。支线用夹具加速计时、摆位及直接启用第五队，验证 AU/AV、重复拾取防重、困难开关和第五队编组/陆路命令；未跑两箱独立冷读或图形目检。逐房原版胜负转属、完整返航/回环、船只实际交火及完整 AI 仍待补。未改玩家存档或发行包。