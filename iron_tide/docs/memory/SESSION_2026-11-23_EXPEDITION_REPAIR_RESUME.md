# 第 19 关旧远征恢复自动抢修

玩家局外已启用 repair_auto，第 19 关远征的 frozen.technologies 只有一级维修。battle_screen.gd 现在在恢复战场检查点之后、刷新指令甲板之前，对已有一级维修的远征战场补入局外已启用的二级维修。范围只涉及这项科技。

隔离复制局外档和远征档，Godot 4.7.2 无头运行 tests/expedition_repair_resume.tscn。载入第 19 关真实战斗检查点，向按钮中心发送鼠标按下及释放，确认文字变为「自动抢修」且战场进入持续维修状态。随后损伤新电厂，执行维修检查，确认开始维修。该回归需要具有上述旧状态的存档副本。日志位于 %TEMP%/CodexIronTideValidation-repair-0540360b-50bb-42ef-ae18-46b486b3fd1a/test.log，含 EXPEDITION_REPAIR_RESUME_PASS。本次交付为工程源码。
