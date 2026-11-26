# 苏军第一关尤里运输艇出发时间

零售 SOV01UMD.MAP 中 Destroy_Time Defenses 启用 Audio_Time Machine Off（5），后者启用 Audio_YuriCapturePower（60），警告启用 Reinforce_Atk Group 1（3），随后启用 Reinforce_Cap Group 1（30）。首两批各三船，分别运新兵和工程师。第二组的两条触发器只对普通、困难启用。迁移时顺着 Actions 53/54 查谁启用和取消定时器，只抄事件自身的 3 会让敌军在苏军登陆时误出场。

修正 scripts/world/time_shift.gd 和 time_shift_events.gd。摧毁时光机守卫时建立独立争电时钟，足电转场先于出兵。旧档缺时钟从零起算，沿用已出波次索引。已生成单位不回收。

Godot 4.7.2 图形场景 tests/time_shift.tscn -- --raid-timing 从菜单出击，清除岸防、等待鲍里斯登陆、清除时光机守卫。之后直接推进任务时钟，验证接管时零船，64 秒无预警、65 秒警告、67 秒零船、68 秒三船、98 秒六船。日志 %TEMP%/IT-S01-raid-timing/out。此次验证出兵，未实测各难度后续波次、循环、驶抵时间及旧档恢复。