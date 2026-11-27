# 苏军 07 未攻击仍卡顿：真实战场复跑

用户明确纠正：没打信标时就有卡顿。信标同步转属是独立尖峰，不作为本问题归因。上一轮见 `SESSION_2026-11-27_SOV07_FRAME_DROP.md`。

新增仅供测试的 `tests/head_games_frame_probe.gd`，由真实苏军菜单出击测试 `tests/head_games.gd` 的 `--battle-frame-perf` 启用。隐藏无头 Godot 4.7.2，原图困难难度，跳过开场简报后，`--battle-untouched` 不下任何玩家命令、不攻击、不改摄像机，原图脚本正常运行，×1，分别采 15 或 45 个约 2 秒窗口。复跑 `--headless --path . res://tests/head_games.tscn -- --campaign-test-no-autosave --battle-frame-perf --battle-untouched [--battle-long]`。独立 APPDATA / LOCALAPPDATA，日志计数关闭，检查 BattleAutosave 无 process、非远征，两个 profile 都无战斗槽文件。两次进程退出 0、stderr 空，各 8 项通过（印出的 SOV07 true），结尾两信标均活且未解放。证据 `.validation/s07-combat-frame-20261127-203818/untouched*.{out,err}`，对应隔离用户目录下的 `Godot/app_userdata/Iron Tide RTS/s07_frame_probe.json` 为逐帧原始数据。开场为自动脚本已接管至 298 单位、301 建筑，主窗口内编制未变、无路径计算、无在飞投射体。长测到任务时钟 100.159 秒；不是任意后期存档。

| 模式 | 墙钟秒 / 样本 | ≥50 ms | 无物理步的慢帧 | 已计物理不足慢帧一半 | 最长单帧 / 最低二秒窗口 |
|---|---:|---:|---:|---:|---:|
| 未攻击短测 | 30.21 / 1256 | 33 | 4 | 30 | 93.93 ms / 31.84 FPS |
| 未攻击长测 | 90.52 / 5130 | 99 | 10 | 97 | 90.27 ms / 43.90 FPS |

最慢两次分别有 70.90 / 67.47 ms 在物理回调；但合计 127/132 次慢帧的已计物理回调不足该帧间隔一半，14 次无物理步。非已计物理时间不能直接叫渲染或某模块：计时排除后续 physics server，且包括 process、调度等待等。无头没有真实玩家 GPU 负载；主机并行 Godot 测试和部分窗口有外部 IronTideRuntime，均未干预，host JSON 记录边界。本轮是有并行负载的定位证据，不是发行帧率验收。连续 ≥50 ms 的最长链为 160.8 / 90.3 ms，未复现持续几秒 20 FPS。正常速度接管后待机/集团进攻各有完成样本，和用户纠正后的开局不混用；fast 批次被外层工具 120s 超时截断，不作结论。无生产修改、无玩家存档修改。

下一步优先冻结未攻击场景，分离引擎 process / physics server / OS 等待，并在正式图形条件同机位确认是否有连续慢窗；有头先征得用户同意。不先做信标优化或降低刷新节奏来掩盖问题。性能索引记录本结果。
