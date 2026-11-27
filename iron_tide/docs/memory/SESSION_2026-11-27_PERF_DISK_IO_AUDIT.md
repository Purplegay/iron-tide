# 2026-11-27｜优化、正常游玩与写盘排查

用户询问写盘是否会抬高 CPU。只读静态审计，无生产改动，不恢复优化批次，未启动压测、未碰玩家存档。近期心控弧线与房色建筑索引优化均为内存操作，无新增文件 I/O。

用户随后定规：性能采样、压测和 A/B 验收必须在隔离进程关闭普通自动存档与远征定时检查点，开跑前确认两边关闭；缺开关先补并验证，不能用短窗口替代，不影响玩家正常存档。已写入根 `AGENTS.md`，本次未实施开关。

- `battle_screen.gd` 每场无条件启动 `battle_crash_trace.gd`，`PROCESS_MODE_ALWAYS`。`user://battle-traces/*.jsonl` 每秒一条心跳，开局/恢复/退出及自动存档边界亦写，每条在主线程 `JSON.stringify` + `store_line` + `flush`。`flush` 不等同已实测物理磁盘写入或 CPU 开销。
- `battle_autosave.gd` 非远征累计 60 有效现实秒，远征 `runtime.gd` 累计有效回调 delta 30 秒。`battle_saves.gd` / `expedition/run.gd` 快照、校验、序列化和临时文件写读验证、备份均同步处理；区分序列化 CPU 与 I/O 等待。两者都可能造成周期慢帧，未量化。
- `battle_call_log.gd` 仅 `IRON_TIDE_CALL_LOG=1` 开启；测量启动器 `../tools/performance_soak.py` 未显式指定时默认设 1，正式无插桩对照应明确传 0，且该开关不会关闭崩溃心跳。调用日志在内存采样，约每 30 秒异步写，不是每次调用写。HUD 普通帧仅将间隔和步数写入内存环形缓冲，F8 手动导出时才写盘。
- 未采集进程 CPU/磁盘事件，不能归因玩家现场 CPU 或声称这几处是持续高占用主因。后续如需验证，用只读现场按进程对时或隔离复现，分别标记 heartbeat 和 save，不能直接禁用自动保存或改盘。
