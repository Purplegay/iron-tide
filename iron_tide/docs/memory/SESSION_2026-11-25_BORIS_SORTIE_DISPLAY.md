# 鲍里斯空袭冷却显示

战场入口 `scripts/ui/attack_cooldown_indicator.gd` 按 `airstrike_wing` 区分机群执行任务与返航后的冷却。米格执行任务期间隐藏空袭圈，最后一架离场后显示蓝色倒数。此时切换到步枪目标能同时看到步枪和空袭两项计时。使用现有武器、派机和恢复计时，包含扩展训练修正。

基础架数与时间见 SESSION_2026-11-25_BORIS_CD_AUDIT.md。末机离场这个起算点沿用项目现有机制，原版实机逐帧对照仍待完成。

`soviet_completion_regression.gd` 在场景中验证派机后隐藏空袭圈，取消指示后可以打步兵，冷却过半时显示两个独立计时。无窗口 492/492，报告在 %TEMP%/IronBorisCD-headless-77816/result.json。图形场景 494/496，报告在 %TEMP%/IronBorisCD-83884/result.json。两模式均通过本轮计时断言。两项失败均为在建筑 art_center 周围 120×100 区域比较前后截图时未检出红色增量，目标调色状态检查通过，实际建筑显色仍待定位。未打包。
