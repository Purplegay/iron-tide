# 自动抢修开关记忆

玩家操作维修按钮时，进入或退出自动抢修会将选择写入 DisplayPreferences 的 HUD 设置。新战斗在完成科技初始化后读取偏好，已解锁两级维修的战场可直接进入持续维修状态。读取已有战斗时沿用战斗快照。本轮抢修限当局使用。

Godot 4.7.2 使用独立 APPDATA 和 tests/repair_preference.tscn，依次启动三个独立游戏进程。enable 首次开局待命后开启，disable 冷启动确认自动模式后关闭，verify 冷启动确认待命，三个进程均输出 REPAIR_PREFERENCE_PASS。本次验证使用扩展遭遇战，远征换关和旧检查点仅检查装配顺序。
