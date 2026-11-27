# Windows 便携包

在工程根目录双击 **打包游戏.bat**（与 `启动游戏.bat` 同级）。默认在用户的 `Downloads` 下生成带版本和时间戳的 ZIP，不覆盖旧包。完整解压后双击 `IronTide.exe`，EXE 和 PCK 需同目录。发布版设置和存档使用 `%APPDATA%\IronTideFriends`。

```powershell
.\打包游戏.bat -CheckOnly
.\打包游戏.bat -OutputDirectory 'D:\Iron Tide Builds'
```

需要完整 Git 工作副本、Git、Python 3.11+、Godot 编辑器及相同版本的 `IronTideRuntime.exe`。可用 `IRON_TIDE_PYTHON`、`IRON_TIDE_GODOT`、`IRON_TIDE_RUNTIME` 指定路径。源码取自运行时的工作区（包括有效的未提交文件，不只打包已提交内容）。如果文件在冻结时变化，本次会停止，待改动暂停后重试。冻结后的修改不会写入成品；已冻结文件的变化会在窗口和包内 `build-manifest.json` 中提示。

工具使用独立临时存档生成并回读测试场景，不访问玩家存档。成功后 ZIP 会通过完整性校验并附带构建清单；失败时看窗口显示的日志目录，默认 `%LOCALAPPDATA%\IronTide\package-builds\<本次编号>`。这里也保留本次源快照和成品测试档，占用磁盘空间。许可证文件沿用现有 Godot 发行包。
