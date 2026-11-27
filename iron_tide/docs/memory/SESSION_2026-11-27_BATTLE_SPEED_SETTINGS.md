# 2026-11-27 战斗倍速勾选

- 玩家可在主菜单「设置」和战场设置的「战斗倍速」勾选 ×1、×1.25、×1.5、×2、×3；默认全选。选项是循环候选，不是独立的默认倍速。新开或重建战场从最低已选档开始；倍速按钮／倍速快捷键从低到高循环、到末尾回第一档。取消战场当前档立即跳到下一档，至少留一档；战场设置打开时 Tab 可用于焦点导航。
- `scripts/ui/battle_speed_controls.gd` 提供共享复选框；`scripts/autoload/display_preferences.gd` 将有序选项保存到 `user://display_settings.cfg` 的 `[battle] speeds`，旧设置、无有效值时启用全部。倍率继续走 `BattleClock`，未改更新频率、生产换算、自动保存计时或 GM 倍速接口。战场初始化应用偏好，BattleScreen 在初始化后刷新 HUD 文案；主设置可滚动到返回按钮。
- 验证：Godot 4.7.2 隐藏无头模式，脚本副本和唯一 `CodexIronTideValidation/BattleSpeed-20261127-120406` 用户目录，未读写玩家存档。真实主设置页和 RA2 遭遇战 `tests/battle_speed_settings.tscn` 22/22；既有 `tests/display_settings_regression.tscn` 81/81；均退出 0、标准错误为空。覆盖 1280×720 布局/滚动、两处设置共享、选项更新和重新读档、保护末档、当前档取消、HUD 按钮与 Tab、实际引擎倍率、离场恢复和坏值兜底。证据 `.validation/battle-speed-20261127-120406/`。
- 未做有头点击验收、战役/远征专项战斗测试或打包验证；未改玩家存档。
