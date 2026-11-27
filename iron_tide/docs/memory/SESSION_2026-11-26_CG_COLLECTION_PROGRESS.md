# 2026-11-26 · CG 收藏进度条

- 主菜单进入「CG 收藏」后，在右上角原「战役影片 已收藏数 / 总数」下新增暖色进度条。`scripts/screens/cg_collection.gd` 直接复用由 `Catalog.GROUPS` 和 `MetaProgress.campaign_cg` 得出的总数，随目录变化，不计百合子手记或目录外记录，切换阵营不重算、不改条。保留原版面、解锁、发奖和存档规则。
- `tests/cg_collection.gd` 新增实际画廊场景空档、部分、全满及目录外记录检查，并从主菜单验证冷读档后的进度及切换阵营。Godot 4.7.2 无头、独立 APPDATA：首进程 18/18，冷启动 48/48，均退出 0。首跑写盘失败告警是既有用例故意制造；冷启动无 stderr。日志见父目录 `.validation/cg-progress-20261126/`，`git diff --check` 通过。
- 未做有头目检或打包，未修改玩家档和其他任务改动。
