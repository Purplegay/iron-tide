# Iron Tide 迁至 GitHub

2026-11-27，项目按用户选择公开托管于 https://github.com/Purplegay/iron-tide 。本地默认远端为 `origin`，当前分支 `codex/ra2-independent` 跟踪 GitHub 同名分支。原 Gitee 仓库保留为远端 `gitee`。

Gitee 源端只有一个分支，迁移时指向 `afcbb646`，没有标签。首次推送含完整提交历史和本机项目快照，GitHub 的 HEAD 与本地迁移提交 `666ec3b0` 一致。验收覆盖 Git 分支、提交和远端跟踪配置。


## 首个公开版本 v0.33

Windows x64 便携包由提交 `90d997e3cf8dc26e8cfe0001b68cf953cbdd2d84` 的独立源码快照构建，游戏内版本为 0.33。用匹配的 Godot 4.7.2 编辑器和导出模板，通过 `tools/package_windows.py` 冻结 16,057 个源文件。导入、导出、成品主菜单、独立测试档生成和成品战场冷读均以 0 退出，战场断言 314 项全部通过。测试采用无头模式。构建记录在本机 `%LOCALAPPDATA%/IronTide/package-builds/github-v033-90d997e3/validation/delivery.json`。

公开 ZIP 为 871,940,890 字节，SHA-256 为 `38a1c1a243d67ae900223ce96992032f0f19bf2c2b87f664ee177077843f85a5`。归档 CRC、逐文件摘要和 GitHub 返回的附件摘要均已校验。发布后匿名下载校验文件并读取 ZIP 文件头，HTTP 206，公开标签指向构建提交。[发布页](https://github.com/Purplegay/iron-tide/releases/tag/v0.33) · [Windows x64 下载](https://github.com/Purplegay/iron-tide/releases/download/v0.33/IronTide-0.33-Windows-x64.zip)
