# 2026-11-20 总攻左侧圆环灯数倒计时

用户提供总攻HUD截图，要求用左边圆环光照数量标记时间，复用起义素材。此前本窗口误把任务理解为增援计时，最终已纠正为总攻倒计时，未修改增援。

生产修改：scripts/ui/uprising_threat_meter.gd新增time_fraction，负值不显示时间；24段环形区域复用experience_panel.png原生圆环贴图UV，点亮数ceil(clamp(fraction)*24)，总攻剩余时间减少逐格熄灭。原生外框和中心保留；不是已找到原生倒计时动画，实际为原图圆环分区调色。scripts/ui/uprising_red_alert_button.gd不再显示上方“总攻 mm:ss”；总攻期间传递left/DURATION至左环，横槽保持满格，不再用横槽表示剩余时间。非总攻保持原警戒值显示。

验证：已实际查看experience_panel.png与native_layout_preview.png确认素材；git diff --check通过。未运行Godot脚本/实际HUD截图，24段几何是否贴合原生辐条和亮度尚未验收，不宣称视觉通过。未打包、提交。未改玩家存档或其他并行修改。
