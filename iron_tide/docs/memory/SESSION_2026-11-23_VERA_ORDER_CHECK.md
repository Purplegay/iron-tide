# 远征「合闸」排查

截图仅显示维拉的信物按钮。查阅 keepsake_orders.gd 与现有远征战场回归，在隔离 APPDATA 中运行 expedition_keepsake_regression.tscn。空选保留次数，选 TTNK 后调用 press 可造成伤害并消耗次数，TTNK 与 SREF 同选时调用 fire_at 可完成联动。共 195 项检查，其中 gift ines 失败。该测试绕过实际侧栏鼠标输入，无法据此确认玩家现场原因。未改生产代码或玩家存档。

日志位于 %TEMP%/CodexIronTideValidation-Vera-0021d67f-327f-48b9-a105-370fdfabfa51/result.txt。
