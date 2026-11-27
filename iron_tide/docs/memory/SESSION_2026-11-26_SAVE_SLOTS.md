# 2026-11-26 对局手动存档扩至 10 槽

- `scripts/save/battle_saves.gd` 的共享槽位清单由 3 个手动槽扩为 `slot1` 至 `slot10`，另保留 `auto` 和 `quick`（界面共 12 项）。文件名、目录、格式版本、原有覆盖备份和读取规则不变；没有迁移或写入玩家存档。远征独立存档未改。
- `scripts/ui/save_panel.gd` 的战中与主菜单共用列表加纵向滚动，每次打开从顶部开始；标题、状态和返回按钮不随列表滚动。自动槽仍只能读取，主菜单仍不允许保存。
- `tests/battle_save_slots_regression.tscn`：Godot 4.7.2 无头、独立 `APPDATA`、真实 RA2 遭遇战场景和 1067×600 测试视口。31/31 通过，退出码 0，stderr 空。覆盖槽位顺序/路径、旧槽保持原样、滚到第 10 槽后实际点击保存、覆盖备份、用 `prepare_load`/`restore_pending` 恢复资金，以及主菜单共享面板按钮状态。日志 `.validation/save-slots-20261126/out-1.txt` 和 `err-1.txt`。
- 未做有头验收、冷进程恢复或从主菜单点击读取后的完整切场，不涉及打包。旧槽使用隔离夹具验证，没有读取玩家存档。
