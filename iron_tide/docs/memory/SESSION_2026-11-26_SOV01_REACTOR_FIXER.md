# 苏军首关恶魔岛：尤里工程师修核电站

零售 `SOV01UMD.MAP`（SHA-256 `498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b`）：最终时代搭建 `06B2A4DC` 动作 7 派 `0442B86C`（`TM_Yuri_1 Engineer 4 Reactor`，House=YuriCountry，Waypoint=BB，TaskForce=`0998FF1C`）；脚本 `0442F31C` 名 `Fix Nuke Reactor`，`0=59,101`。航点 101 贴原图 `(48,72)` 的 `NANRCT`（128/256，初始半血），不是 `(20,44)` 的另一座。原移植 `FIELD.yuri` 有工程师但给了 `order_guard()`。

`time_shift.gd` 在第二次穿越后装配指定工程师与半血核电站标志，`time_shift_events.gd` 最终阶段用正式工程师交互下令；`allied_abilities.gd` 让该工程师知道指定己方建筑位置，不对变成玩家归属的目标发占领命令。沿用寻路到门和同房修理结果，核电站修满、工程师消耗。无新兵或新目标、无房色变更。只给新装配对象标注；旧档如已停在返回时代，未回填旧对象，不修改玩家档。

Godot 4.7.2 `--headless --path . res://tests/time_shift.tscn -- --reactor-fixer`，独立 APPDATA，在真战场执行两次穿越（夹具推进早期关卡）；工程师修理段实际物理步、未摆位，检查目标半血、下令不提前修及抵达后满血消耗，退出 0，stderr 空。日志 `.validation/s01-reactor-fixer/run.out`。未独立冷读、未测试玩家途中摧毁/夺占的实战分支、未打包。
