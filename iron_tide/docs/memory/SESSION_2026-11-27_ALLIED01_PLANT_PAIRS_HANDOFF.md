# 接手交接：尤复盟军首关《时间流逝》电厂驱动（2026-11-27）

## 先看这里

项目在 `C:/Users/admin/IronTide/iron_tide`，Godot 4.7.2。先读 `AGENTS.md`、`YR_CAMPAIGN_PORTING.md`、`YR_CAMPAIGN_MEMORY_INDEX.md`（后两份在 `docs/memory/`）并加载 `yr-campaign-porting`。本关零售 `ALL01UMD.MAP`，不要与苏军《时空转移》混用。原图、事件号和之前留的缺项见 `ALL01UMD_DRIVER_INVENTORY.md`、`ALL01UMD_SCRIPT_RECHECK.tsv`、`SESSION_2026-11-27_ALLIED01_PLANT_TRIGGER_DRIVER.md`。任务触发与全局 AI 分开验。本关原图有 334 条任务触发；现在通用表导出 84 条（本批从 54 条新增 30 条），还不能算全关接入；剩余 250 条不在通用表，其中有些由关卡专用代码近似处理。终关仍 43 条，未改其选择集。

**工作区不是清洁快照。** 相关文件在 `git status` 中显示未跟踪，包括 `scripts/world/allied_first.gd`、`tools/export_allied_script_slice.mjs`、`data/ra2/allied_script_slice.json`、`tests/allied_first_playable.gd`；换工作树或交给别人前必须传当前工作区及关联资源，不能以 `git diff` 或仅拉取提交为交接。不要清理其他并行改动。`.validation` 的本地原图索引和日志不会随常规 Git 文件自动分发，按原图交接重建或在原机复跑。

## 已做改动和原图依据

- 导出器扩入 8 条 `PP*_Entered`、12 条 `PP*_Group_Done_*`、6 条 `Check_PP*`、3 条 `Ping_PP_*` 和 1 条 `Good_Job_1`。原图 `ALL01UMD` 航点 CJ/AR/S 对应 87/43/18。`allied_first.gd::tick_plant_driver` 用实战建筑的玩家归属代理事件 1；事件 61 仍看物理毁坏。配对动作按原表触发局部变量和启停、17 显露区域、19 信号音、21 伊娃供电提示、55 雷达事件。变量 47 跟随已经进入供电后的阶段，限制相关雷达提醒。显露的半径/短时视野是工程近似；未改开场全八厂的通用任务标记，不能称按原版逐组隐藏和开放。
- 最后一笔**尚未回归**：`plant_pair_driver_initialized` 让进入事件只初始化一次，避免每帧把原图禁用的行重新启用；旧档 `plant_external_links` 里的挂起启停，初始化时对已经导入的行回放并移除，对仍未覆盖的行继续保留。须检验已毁电厂的进入检查不复活、旧档不会重复显露或漏标，并检查尚未支持的外部启停是否需要保持顺序而非仅存最后状态。

## 已跑证据 vs 必须重跑

最后一笔兼容改动**之前**，隔离无头实际战役菜单：`--plant-pairs` **26/26**、`--power-loss` **25/25**，两次退出 0，日志 `.validation/allied01-playable/pair-{pairs,loss}.{out,err}`。配对夹具：第一厂走真实工程师最后一段，第二厂直接转属；验证单厂不显露、配对后显露 87、延迟一秒发 CJ 雷达事件、重复推进不发第二次。不是自然跑完整条路线。此批未做配对档独立冷读或全部配对实测；没有改用户原档、没图形验收或打包。

先用最终工作区连接着跑：

1. 实际测试场景 `res://tests/allied_first_playable.tscn -- --plant-pairs`。
2. 同场景 `-- --power-loss`、`-- --power-loss --easy`、`-- --power-loss --hard`，并顺跑普通 `-- --power-loss --save-plant-driver` 与同隔离目录另进程 `-- --cold-plant-driver`。独立进程不要拿用户原档测试。
3. 新加一个 54 条版本旧驱动快照的迁移夹具（已完成一对、曾登记外部启动/禁用），检查加入 84 条脚本后按次接回、不误判。验证 `--plant-pairs` 的实际显露，包括另外两组、先毁后占及一厂被夺回。检查 `stderr`、完整 `ALLIED01_RESULT` 和进程退出，不能只看退出码。
4. 如需重生通用表，从项目执行 `node tools/export_allied_script_slice.mjs .validation/allied-ends-20261126/audit data/ra2/allied_script_slice.json`。Godot 控制台版在 `%LOCALAPPDATA%/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe`；用 PowerShell `Start-Process` 隐藏窗口、指定项目工作目录和 `--headless --path ...`，重定向 stdout/stderr 后 `WaitForExit`。每组用新隔离 `APPDATA`，冷读只在同组共享。

## 接下来

最终态回归通过后，再补供电上线/毁机原图事件链、开场导演和其他未接任务。全局 AI 165 开关另有核对，不因任务表扩充算已实现。金门桥附着级联、分层通行仍未完成；控制器双链目前有代理语义；不要以旧档局部胜负回归代替新开局全关通关。需要图形验收按项目规则先问用户。
