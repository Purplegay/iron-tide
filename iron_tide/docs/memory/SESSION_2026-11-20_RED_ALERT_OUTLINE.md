# 警戒值文字描边

根据用户截图，为 `scripts/ui/uprising_red_alert_button.gd` 的警戒值标签改用亮色 `UiKit.COL_TEXT`，并加入深色描边（`outline_size = 4`）。标签位置、字号和警戒值逻辑不变，同一标签的就绪和生效文案共用样式。

`tests/red_alert_ui_acceptance.gd` 加入描边检查。Godot 4.7.2 独立用户目录 GUI 验收 18/18 通过，退出码 0；已查看盟军充能状态截图，确认描边可见。证据：`C:/Users/admin/AppData/Local/Temp/IronTideRedAlertOutline-20261120/report/`。未单独截图验证苏联外框，未重新打包或提交。
