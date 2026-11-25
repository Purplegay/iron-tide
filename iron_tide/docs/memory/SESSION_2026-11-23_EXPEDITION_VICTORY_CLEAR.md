# 远征胜利清场

Battle.end_battle 在远征胜利成功存档、设置 ended 之后，发送 battle_ended 信号之前清除所有敌对房色的单位和建筑。幸存部队、战报、奖励在清场前确定。house_elimination.gd 将原有的标记阵营、快照对象和执行死亡逻辑抽成共用函数，按玩家的队伍关系选择敌军。

更新 expedition_control_regression 的机动指挥车用例，验证最后一座敌方建筑被毁前，指挥车存活，任务胜利后指挥车死亡。Godot 4.7.2 独立用户目录无头运行，远征任务 29/29，阵营淘汰 25/25，额外多阵营战场 6/6。日志位于 %TEMP%/IronTideVictory175118。验证覆盖游戏逻辑，未做画面验收或导出构建。
