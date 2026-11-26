# 2026-11-26 · CG 收藏

## 玩家入口与规则

- 主菜单「CG 收藏」列出当前已实现的 11 段尤复战役影片（盟军《好莱坞梦一场》、苏军《时空转移》《首脑游戏》，含苏军结局），显示战役收集进度和未解锁条件。影片在剧情中首次启动播放时自动收录，跳过也算；不消耗资源。旧档没有逐片记录，不按通关成绩猜测历史观看，不自动补发，重新触发即可收录。
- 「回看」全屏播放原影片（保持各自原画面比例），沿用原音、独立音轨和中文字幕。「返回收藏」、Esc 或影片结束回收藏并恢复焦点。回看不推进任务、不再次写收藏、不暂停场景。
- 收藏页显示百合子婚纱 CG 的持有数量，「打开百合子 CG 集」直接进入原页面，返回收藏；原购买、剧情和赏图规则未改。

## 实现入口

- `scripts/ui/campaign_cg_catalog.gd` 共用影片 ID、目录、音轨路径和玩家解锁提示。`scripts/ui/hollywood_film.gd` 复用原播放器，区分战役与回看：战役保持原暂停、雷达覆盖和片后回调；缺影片不入册且放行回调。
- `scripts/autoload/meta_progress.gd` 将 `campaign_cg` 存到 `user://iron_tide_meta.json`，旧档默认空，重置局外存档时清除，保存失败撤销本次记录。`scenes/cg_collection.tscn`、`scripts/screens/cg_collection.gd`、主菜单与百合子手记负责导航。

## 验证与限制

- Godot 4.7.2，无头场景、独立 APPDATA：`tests/cg_collection.tscn` 首进程 6/6、`-- --cold` 冷进程 27/27，均退出 0，无 stderr。覆盖首播、跳过、无效资源、去重、跨进程留存、锁定限制、回看视频推进和字幕、按钮/Esc/结束信号返回、百合子往返、11 个影片和 4 个独立音轨可加载。测试安全护栏：环境变量 `IRON_TIDE_CG_TEST_PROFILE` 必须等于 Godot 当前用户数据目录；从空隔离目录开始，两个进程共用它。
- 真实战役 `tests/time_shift.tscn -- --media` 从战役菜单出击，50/50 通过，退出 0、无 stderr；检查雷达小窗、字幕、三倍速视听同步、片尾原电台，并核对该隔离档收录 4 段。
- `tests/campaign_menu_routes.tscn` 11/12；旧断言「换关恢复原版配置」与当前 `campaign_command.gd::select_mission` 保留 `DisplayPreferences.campaign_growth` 的实现不符，两处均未修改。百合子原完整回归受其运行护栏限制，需要自定义用户目录项目配置，本次未运行到用例；新回归覆盖实际入口和原未购买状态。
- 日志 `%TEMP%/IronTideCg-20261126-174305/`（`final-seed`、`final-cold-esc`、`time-shift`、`campaign-menu`）。未逐关实玩其他 7 段的触发，未验实际窗口排版、物理鼠标、导出包；未改玩家存档，未打包或提交。
