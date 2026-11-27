# 苏军 07 未攻击有头观察（无截图）

用户同意开一次游戏窗口、不截图。此前未攻击的无头报告见 `SESSION_2026-11-27_SOV07_UNTOUCHED_FRAME.md`。本轮从困难战役正式菜单出击，跳过简报后 ×1，不下单、不移动镜头、不攻击，保留两座信标。使用一次有头 Godot 4.7.2 开发构建，Windows Compatibility / RTX 5060 Ti，1600×900、VSync 关闭、不限帧。实测绘制计数非零。隔离 APPDATA / LOCALAPPDATA，测试参数关闭自动保存，非远征，未写战斗槽。未截图、未动玩家存档、未改生产代码。

复跑参数 `--resolution 1600x900 --position 80,80 --path . res://tests/head_games.tscn -- --campaign-test-no-autosave --battle-frame-perf --battle-untouched --battle-long`。在 `tests/head_games_frame_probe.gd` 增加仅测试使用的引擎 process/physics 监测值及绘制计数、显示模式元数据。引擎 monitor 的数值可连续多帧保持不变，不能和同一行 wall interval 做逐帧减法，也不据此判断 GPU 根因；`battle_frame_pacing` 的物理回调计时仍按实际帧记录。

结果：Exit 0，stderr 0，8 项通过。90.393 秒、6,556 帧、均值 72.53 FPS，P95 24.852 ms；最慢帧 59.231 ms，≥50 ms 共 8 帧，最低约 2 秒窗口 62.42 FPS，未复现连续数秒 20 FPS。8 个尖峰均隔开，其中 2 次已测物理回调 44–46 ms，其余 6 次仅 9–13 ms；这些帧绘制计数均 386。301 建筑、298 单位稳定，未见寻路调用或投射体。证据 `.validation/s07-window-20261127-204809/graphic.out` 与 `graphic` 隔离 profile 内 `s07_frame_probe.json`。

不能直接和前一轮无头作因果比较：有头起测时有其它无头开发测试进程，结束时均已退出；没有启动前发现的玩家游戏；受并行活动影响，工作树 diff 哈希前后变化。不是冻结对照，不从此结果推导有头更快或图形无问题。未覆盖发行包和后期存档，自动保存关闭也意味着未覆盖真实保存尖峰。后续优先用同一冻结场景拆 process 回调及单独的隔离保存专项；避免反复打开窗口、不需要截图。若仍需精确对齐玩家一例，再用兼容存档副本或 F8 快照。
