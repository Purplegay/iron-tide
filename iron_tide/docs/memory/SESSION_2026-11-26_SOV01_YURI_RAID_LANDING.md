# 苏军第一关尤里运输艇登陆修复

原图依据：`SOV01UMD.MAP`，SHA-256 `498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b`；事件链见 `SOV01_TRIGGER_INDEX.md` 中 `Audio_YuriCapturePower`、`Reinforce_Atk Group 1`、`Reinforce_Cap Group 1`。`data/time_shift_field.json` 的首批三艘船各载三名尤里新兵 `INIT`，第二批三艘各载一名尤里工程师 `YENGINEER`。当前任务时钟第 65 秒播抢电警告，第 68 秒首批出发，第 98 秒第二批出发。警告不是“兵已到岸”。

问题与修复：原图起点航点 133 在本关当时的可玩边界外，`nearest_reachable()` 将三艘船投影到同一点 `(140.5,57.5)`；旧测试只检查船生成，未检查船体相撞、航行和卸载。`scripts/world/time_shift_events.gd::raid` 现为投影后的水域选互不重叠的船体出生槽；第三艘到 130 号岸点的船按原图路线先经 459 号航点，避免直线近路在约 `(93,92)` 被中立车辆挡住。`power_contest` 到中途航点再接续最终岸点，继续使用原有卸载、工程师占领逻辑。原图车辆未移除，时钟和编组未改。中途航点状态保存在单位 `special`，随普通战场快照保存；旧档恢复未实测。

验证：Godot 4.7.2、隔离 APPDATA、从苏军战役菜单出击，`res://tests/time_shift.tscn -- --raid-timing --raid-voyage`，使用真实物理步验证首批三船自然驶抵、船舱清空且九名新兵在岸上，29 条断言、退出 0、标准错误空；自然航行分支为隔离首批将 `raid_index` 置 4。`--raid-timing` 验证 65/68/98 秒时序和六船十二乘员，以测试夹具把船置于原图登陆点，再以真实卸载和占领逻辑验证新兵、工程师落地及发电厂登记尤里归属，32 条断言、退出 0、标准错误空。日志：`%TEMP%/IT-s01-raid-final-voyage.out/.err`、`%TEMP%/IT-s01-raid-final-capture.out/.err`。

未验证：第二批与第一批同时自然航行的完整时序、普通/困难后续两波、存档冷读后的中途航线、旧玩家档、实际图形窗口截图与发行包。测试推进了部分任务时钟、破坏岸防目标；不是不干预的完整通关。源文件 `time_shift_events.gd` 和 `tests/time_shift.gd` 在当前工作区未跟踪，未提交。
