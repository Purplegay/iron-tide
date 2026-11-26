# GDScript 报错堆栈可行性

Godot 4.7.2 console 在独立最小工程开启 `debug/settings/gdscript/always_track_call_stacks=true`，通过 `--headless --script res://probe.gd --log-file <文件>` 运行三层调用中的空数组越界。日志包含 `SCRIPT ERROR`、出错行，以及从内到外的 `failing (res://probe.gd:9)`、`caller (res://probe.gd:6)`、`_initialize (res://probe.gd:3)`。

## 项目接入与 Windows Release 复验

项目 `project.godot` 的 `[debug]` 已显式启用 `settings/gdscript/always_track_call_stacks` 和 `file_logging/enable_file_logging`。通过启动脚本从源码游玩，默认日志在 `%APPDATA%\Godot\app_userdata\Iron Tide RTS\logs\godot.log`。根据 `tools/package_windows.py` 的自定义用户目录，重新打包后的朋友版使用 `%APPDATA%\IronTideFriends\logs\godot.log`。

将项目自带的 `IronTideRuntime.exe` 和项目的 `[debug]` 配置放入隔离工程 `%TEMP%\IronTideStackRelease20261125221852`，以主场景启动，使用默认文件日志。`OS.has_feature("release")` 返回 true。`push_error` 与请求不存在的节点均记录三层调用，节点错误从 `failing (res://probe.gd:11)` 追到 `caller (:7)` 与 `_ready (:4)`。重新启动后日志目录保留带时间戳的上一局日志。原始证据在 `%APPDATA%\Godot\app_userdata\IronTideStackRelease20261125221852\logs\`。

同一 Release 运行时读取空数组的索引 0 得到 `<null>`，该次操作没有产生报错堆栈。该设置记录引擎报告的脚本调用链。验证使用隔离主场景，未重打完整发行包、测量战场性能或验证 Windows 原生崩溃转储。