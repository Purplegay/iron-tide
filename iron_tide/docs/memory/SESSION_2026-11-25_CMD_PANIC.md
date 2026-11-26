# CMD 在游戏报错后等候按键

双击 `启动游戏.bat` 后，`launch_game.ps1` 等候游戏进程退出，并将本次标准错误流写入 `%LOCALAPPDATA%\IronTide\startup-logs\*-runtime.log`。运行时返回非零退出码或标准错误出现 Godot 错误标记时，启动器显示退出码、错误摘要和日志路径，返回 1 触发批处理的 `pause`。正常退出时批处理自动结束。批处理使用 UTF-8 和 CRLF。

在 `%TEMP%\IronTideCmd20261125222203` 用真实 cmd.exe、项目启动脚本、Release 运行时和隔离场景验证。`push_error` 后游戏返回 0，CMD 显示 probe.gd 第 3 行堆栈并等候按键。正常返回 0 自动关闭。模拟退出码 7 显示退出码并等候按键。测试输出在该目录的 `result.txt`。验证使用小场景，异常退出码由脚本主动返回。