# 成长优化 P95 补测预检 · 2026-11-27

用户已确认恢复并开始补测。[原交接及 ABBA 命令](SESSION_2026-11-27_PERFORMANCE_HANDOFF.md)。本次仅完成预检，未启动测试，未改玩法源码、运行时或玩家存档。

- 原 A/B 隔离快照均存在，各 1,640 个已归档源码指纹逐项核对，均无漂移；两版仅 `scripts/units/expansion_2_infiltration.gd`、`scripts/units/progression_expansion_2.gd` 不同。
- 归档存档、meta 的 SHA-256 均匹配两版环境记录；Release 模板 SHA-256 匹配历史记录，原说明中的 Python 路径可用。
- 两版 `battle_autosave.gd` 和 `expedition/runtime.gd` 均在定时累加之前以 `IRON_OUT` 跳过定时保存。开跑前仍须重新核验。
- 外部 `IronTideRuntime.exe` PID 41968，有 `Iron Tide RTS` 窗口且 CPU 累积量持续增长。另有外部 `Godot` PID 39908，命令为 `--version`，CPU 未见增长。未停止任一进程，也未在并发下采样。

续测：待玩家退出游戏，重新核验外部引擎、输入和隔离开关，按原交接跑 A1→B1→B2→A2，逐场审计，并报告真实 P95 和推进量。索敌拆分未启动。
