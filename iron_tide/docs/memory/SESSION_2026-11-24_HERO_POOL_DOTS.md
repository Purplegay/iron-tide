# 英雄契约奖励卡的养成提醒

`progression_upgrade.gd` 按英雄契约表筛除奖励卡。`meta_screen.gd` 的技能抽卡页签用筛选后的可升级卡名和可兑换传说卡名驱动红点与悬停说明。对应英雄、英雄页签及奖励卡操作继续按原支付条件提示。

`progression_upgrade_regression.tscn` 使用独立存档启动真实养成界面，73 项通过，覆盖英雄奖励卡归属、普通卡升级、传说兑换和操作后的红点刷新。日志在 `%TEMP%/CodexIronTideValidation-HeroDots-152529/`。隔离目录缺少窗口图标，验证范围为开发工程场景。
