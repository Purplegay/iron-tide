# 2026-11-26 Temp 与全局缓存清理

## 授权与范围
用户确认清理两个 Temp 根内固定清单中的 Godot 生成缓存、全局 Go 编译缓存及 npm/pip/NuGet 下载缓存。目标是继续释放 C 盘空间，检查能否达到 1 TiB。没有扩大到源码、存档、唯一备份、系统文件或应用运行时。

## 结果
- Godot：固定清单 291 个 `.godot`，完整事件记录删除 482,848 个文件、14.83 GiB 逻辑字节。一次自主清理进程为优化元数据读取而重启，部分已删文件没有最终目录事件，故该数值为下限，不冒充精确物理回收量。
- Go：使用显式 GOCACHE 指向 `C:/Users/admin/AppData/Local/go-build`，执行官方 `go clean -cache` 成功；清理前 37,851 个文件、14.66 GiB 逻辑字节。
- 下载缓存：仅 npm `_cacache`、pip `http-v2`、NuGet `v3-cache`，合计 693 个文件、0.48 GiB；npm `_npx` 和全局 NuGet packages 保留。
- 三项累计清理逻辑大小至少 29.98 GiB。本批操作起点可用 781,322,366,976 字节，最终审计 804,158,242,816 字节，整盘净增加 21.27 GiB，最终可用 748.93 GiB，距离 1 TiB（1024 GiB）还有 275.07 GiB。其他任务同时写盘，磁盘净变化不能等同删除逻辑量。

## 保全与验证
固定清单中的 291 个 `project.godot` SHA-256 均与清理前一致，审计错误为零。保留 249 个重解析链接和 10,698 个共享硬链接文件；不遍历链接目标。源码、报告、玩家及测试存档、唯一历史归档均未作为本批删除对象。没有停止其他测试进程。

主体清理无活动跳过、无目录级错误。305 个 Windows 超长路径缓存文件首次因原生句柄路径限制留下；已补上扩展路径支持，复查这些文件总计仅 2,557,293 字节（2.44 MiB）。后续补清理遇到新 Godot 测试缺少显式项目路径，按保守保护规则未删除。最终 251 个残留缓存根包含上述链接或小文件，不代表 251 份完整缓存仍占空间。

当前可安全清理的缓存不足以到 1 TiB。历史未跟踪源码/表格备份、唯一截图归档、Docker 数据盘、Codex 工具运行时、pagefile/hiberfil 等没有按垃圾删除。任何扩大清理范围应另列具体对象及可恢复性再确认。

## 证据
`C:/Users/admin/KFramework_server/.harness-cache/temp-cache-cleanup-20261126/`

- `godot-cache-manifest.json`、`project-markers-before.json`：固定范围及原始配置哈希。
- `operations.jsonl`：追加操作记录，保留原失败和工作进程重启事件。
- `summary.json`：Go/下载缓存结果。
- `godot-retry-summary-before-longpaths.json`：Godot 主体成功结果。
- `godot-retry-summary.json`：后续受活动进程保护的尝试，不覆盖主体成功证据。
- `final-audit.json`：最终空间、残留分类及全部项目配置哈希核验。

没有修改游戏或服务器业务代码，未运行游戏功能回归；本次验收针对清理边界、文件保全和磁盘结果。
