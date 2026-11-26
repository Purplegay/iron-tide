# 2026-11-26 · 战役 CG 首次收藏奖励

- 每段战役 CG 首次在剧情开始播放时，自动收藏并发放钻石 5、战略点 25、军需券 150。立即跳过也保留；重打、回看和旧档已收藏不补发。百合子付费 CG 的规则不变。数额为本次实现默认值。
- `scripts/ui/campaign_cg_catalog.gd` 集中定义金额和展示文字。`scripts/autoload/meta_progress.gd::collect_campaign_cg` 按影片 ID 去重，收藏和余额使用同一次原子存档，失败一同回滚，成功只通知一次余额更新。战略点是战役货币 `war_points`，不是战略核心 `cores`。`scripts/ui/hollywood_film.gd` 仅战役成功首解锁时在影片顶部提示，结束或跳过时写入战场消息；`scripts/screens/cg_collection.gd` 在收藏页说明收益。
- Godot 4.7.2 OpenGL 窗口，`tests/cg_collection.tscn` 使用隔离 APPDATA，两次独立进程：`-- --reward-shot` 17/17，`-- --cold --gallery-shot` 48/48，均 exit 0。首跑写盘失败用例有预期警告；冷进程 stderr 空。覆盖真实影片首播、提示、跳过、重打、无效 ID、既有收藏、写盘回滚、冷加载、收藏回看和百合子入口。已目检到账及收藏文案截图，日志和截图在仓库根目录 `.validation/cg-reward-20261126/`。
- 同日用户反馈别反复弹框：移除影片内到账提示和跳过/结束时的战场通知。奖励静默自动到账，收藏页仍说明金额。之前有头截图仅为旧版证据。最终改用 `--headless` + 隐藏控制台 + 隔离 APPDATA，首进程 15/15、冷进程 46/46，均 exit 0；日志 `.validation/cg-reward-quiet-20261126/`。后续验证默认无头，不反复打开测试窗口；需有头验收时先征求用户同意。
- 未逐关复跑全部 11 段战役触发、未测导出包；未改玩家档，未打包或提交。
