# 计划攻击路线结束后的还击

单位完成计划攻击路线后，unit.gd 的 _refresh_target 原先直接清空目标，使射程内的有效受击来源也进不了武器判定。现有还击计时有效时，仅把实际攻击者送入原有选敌流程，并检查敌对分组。还击结束后继续在终点待命。

Godot 4.7.2 无头战场 tests/ai_engagement_regression.tscn。在 RA2 和扩展模式让玩家灰熊坦克结束计划路线，附近放置两辆敌车，直接调用受击入口模拟较远敌车命中。修前新增八项中四项失败，均为锁定或实际开炮。修后完整 132/132 通过。日志在 %TEMP%/CodexIronTideValidation-RouteBefore/log.txt 与 %TEMP%/CodexIronTideValidation-RouteAfter/final.txt。截图原局的指令状态及具体兵种待核实，发行包待构建。
