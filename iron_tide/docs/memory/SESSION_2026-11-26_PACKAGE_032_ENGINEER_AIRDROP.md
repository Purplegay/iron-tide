# Windows 0.32 便携包：第一关工程师空投修复

用户要求打包。使用 `../tools/package_windows.py` 和 Godot 4.7.2，冻结当前工作区 15694 个源文件（含工程师空投修复和打包时其他现有未提交改动）；未改项目版本或玩家档。Windows x64 Release，独立 EXE/PCK，配置与存档使用 `%APPDATA%/IronTideFriends`。临时打包目录 `%TEMP%/IronRelease032-20261126-184936`，含冻结清单、导入/导出/战场日志、delivery.json；另存 `Downloads/IronTide-0.32-Windows-x64.zip` 并经 Chatbox 下载卡交付。ZIP 803576352 字节，SHA256 `b99ea68dc81c24987e8d0fc3ef19ebe4749246245f872d21f81acdf6bab476af`，归档 CRC、逐文件 SHA256 和源漂移校验通过。

导入、导出及主菜单启动 exit 0，标准发行版战场验证 279 项通过，包括从当前源码隔离生成的大型遭遇战档（315 单位、219 建筑）恢复。额外用成品 EXE/PCK 的硬链接及独立 override 外挂测试（非包内文件）运行第一关用例：第一次外挂根节点写法在 `scene_changed` 等待处超时，冷读未生成的档随之不通过；修正为子节点挂载、显式等待实际 BattleScreen，隔离新档重跑专项 33 项、待空投与在途两个独立进程各 4 项全部通过，stderr 均为空。日志 `airdrop-smoke/*-final.log`。未做有头或自然通关，未直接测试用户旧档，旧档里已生成的单位不清除。修复机制见 SESSION_2026-11-26_SOV01_ENGINEER_AIRDROP.md。
