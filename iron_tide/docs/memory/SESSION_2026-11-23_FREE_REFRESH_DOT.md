# 军需商店免费刷新红点

`scripts/expedition/screen.gd` 让商店页签、刷新按钮和营地待办共用 `free_refresh_available()`。处于营地准备阶段、实际刷新价格为零且可更换格数大于零时显示提醒。锁定和解锁成功后随营地页面重建即时更新。

Godot 4.7.2 在隔离存档的真实营地场景完成 9 项检查，覆盖建局、首次免费、全锁、解锁一格和使用免费刷新后转为付费。两处控件均检查实际红点子节点。日志在 `%TEMP%/IronTide-FreeRefill-181255/project/refresh_check.log`。验证范围为无头场景，未做打包目视检查。
