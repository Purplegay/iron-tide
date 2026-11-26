# 金门大桥舰队红边回归

苏军第一关和第七关在 `scripts/ui/unit_selection_outline.gd` 按任务 ID 给友方识别描边传入 `actor._col`。苏军红色涂装因此扩展到了整个单位轮廓。已移除该分支，己方识别层使用 OWN_COLOR，友军使用 FRIEND_COLOR，攻击目标优先使用 ATTACK_COLOR。

在 Godot 4.7.2 图形窗口分别运行 `res://tests/time_shift.tscn` 和 `res://tests/head_games.tscn`，追加 `-- --outline`，从战役菜单出击。第一关新增回归，逐个读取 3 艘潜艇、2 只巨型乌贼、5 艘海蝎和 3 艘无畏舰实际描边材质的颜色，13/13 为黄色。第七关基地车红色涂装与黄色描边断言均通过。日志在 `%TEMP%/IT-rededge-1125-time_shift/out` 和 `%TEMP%/IT-rededge-1125-head_games/out`。本次覆盖开局的己方描边材质，未跑攻击目标切换和整关流程。后续迁移检查见 `YR_CAMPAIGN_PORTING.md` 的「战役单位红边回归」。
