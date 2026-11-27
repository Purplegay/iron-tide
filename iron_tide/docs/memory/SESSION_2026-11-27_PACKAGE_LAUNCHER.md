# 2026-11-27 一键 Windows 打包入口

`打包游戏.bat` 与 `启动游戏.bat` 同级；启动脚本未改。配套 `package_game.ps1` 检查 Git、Python 3.11+、匹配版本的 Godot 编辑器及 Release 模板，默认输出 Downloads 中带版本与时间戳的便携 ZIP，支持 `-CheckOnly`、`-OutputDirectory`。许可证从现有发行版复用至 `tools/packaging/`，使用说明见该目录 README。默认日志和构建工作区 `%LOCALAPPDATA%/IronTide/package-builds/<编号>`。

仓库根 `tools/package_windows.py` 的外部 `--save` 仍可用，默认由当前导出的 EXE/PCK 在新隔离 profile 生成大型测试档，再在另一个 profile 读回。`package_smoke.gd` 关闭并验证该验证链的普通自动保存，未进远征。不动玩家存档。冻结时内容变化仍停机；归档前只报告后来变化的已冻结文件，ZIP 只含已验证快照；`post_freeze_drift` 记录具体路径。ZIP CRC、逐文件 SHA-256、最终 SHA-256 都保留。

验证：实际通过 BAT 跑预检，缺失模板返回 1；实际通过 BAT 和自定义目录跑完整导入、导出、主菜单、当前成品造档和成品回读，314/314。第一次在归档前被原有实时源漂移管控中止；将归档抽出并调整后保持该次已验快照，仅以最终的 `archive()` 恢复归档，记录六个后改文件，CRC/逐文件 SHA-256 通过。实际检查的各阶段通过，未在最后调整后再全量重导同一工程。构建证据 `%LOCALAPPDATA%/IronTide/package-builds/20261127-212139-0837b7/{delivery.json,smoke.json,fixture.log,battle.log}`，验证包在 `%LOCALAPPDATA%/IronTide/package-tool-validation/`，871939027 字节，SHA256 `fbf05737e8c7b5626fb2006c44503247468d23b6c3eb7db6aa18c2c07966dbc5`。未作有头验收或 Git 推送。
