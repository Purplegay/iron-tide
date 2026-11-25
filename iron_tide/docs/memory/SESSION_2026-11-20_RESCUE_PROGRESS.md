# 2026-11-20 主线救援进度条与完成清理

用户截图11关：救援无进度条，1/2后圆圈/标签不消失。已改objectives.gd：救援累计clamp20；rescue_progress统一0..1；draw_rescue_progress屏幕坐标固定180x12绿色条及百分比/秒数；visible_points救援仅返回未在state.rescued中的点，使世界绘制、小地图、focus_next同源排除已完成。救援发放的3友军保留。既有已完成checkpoint会直接隐藏该点。

新增tests/expedition_rescue_progress_regression.gd/.tscn，实际GUI战场11/11通过：10秒50%、21秒clamp20、完成世界与minimap隐藏、总进度1/2、奖励不重复、磁盘Snapshot保存恢复仍隐藏且保留单点进度。截图reports/rescue-half-progress.png已view_image检查绿条与50% 10/20秒可见。

隔离副本C:/Users/admin/AppData/Local/Temp/IronTideExpedition-20261120，独立user目录。首次完整当前树有并行性能Unit._enter_tree调用缺失Battle._place_simulation_lane_deferred报错，11断言通过但日志有错，不能当干净验收。仅副本unit.gd注释此无关不完整调用后重跑，rescue-progress-isolated.log干净11/0，生产性能代码未改；因此测试结论为隔离救援功能通过，非完整生产树启动验收。当前其他并行修改持续，勿覆盖。

用户截图运行旧任务标题，源码summary已含姓名/秒数，本轮加的绿色条在世界绘制，与HUD旧版本无关。源码未打包提交，不修改玩家存档。持久记忆100条满，本轮项目交接保存。
