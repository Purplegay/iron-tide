# 2026-11-26 · 战役选关完成标记

- 玩家从主菜单进入「战役」并选择阵营后，已通关任务在左侧任务行显示「已完成」，选中时右侧简报也显示。标记不拦截点击，已通关任务可继续出击。
- `scripts/screens/campaign_command.gd` 在任务行和简报复用 `Payout.cleared(id)`，读取现有 `MetaProgress.stats.campaign_victories`。既有胜利记录直接生效，不改写存档或结算；未胜利任务不标记，无尽关仍按波数结算。
- Godot 4.7.2 无头、独立 APPDATA：`tests/campaign_completion.tscn` 实例化真实战役指挥室，调用既有结算接口并保存，验证空档、失败、胜利、切关及跨阵营隔离，8/8；冷进程同档重跑 5/5。两次均退出 0、stderr 空。日志在仓库根 `.validation/campaign-completion-20261126-190307/`。
- 既有 `campaign_menu_routes.tscn` 10/11；失败项「换关恢复原版配置」与已记录的跨关保留配置规则不符（见 `SESSION_2026-11-25_CAMPAIGN_PREFERENCES.md`），本轮未改该行为或断言。本次修改范围 `git diff --check` 通过。未开战重跑完整结算、未做有头目检或打包，未碰玩家存档。
