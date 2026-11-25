# 远征/情报共用左上页签

用户指出远征面板与情报条重叠，要求两个切换页签。hud.gd 新增 mount_expedition_panel/_select_expedition_page：远征panel reparent到现有_log_holder VBox，隐藏旧情报展开按钮，增加远征/情报两个互斥页签（默认远征），容器宽320逻辑像素。重要告警仍在页签上方。运行时远征install_hud不再固定position，交HUD容器排版；原紧凑/展开详情保留。情报内容增加180高滚动区，远征模式旧/新消息Label设置290最小宽并自动换行，避免撑宽；页签加入covers_world_pixel防止点击穿透。非远征保留情报展开按钮，情报滚动区也适用。

扩展tests/expedition_compact_hud_regression至16项，覆盖互斥显示、共用父容器、长消息限宽限高、点击归属及页签与内容几何不重叠。隔离真实远征16/16 exit0、无脚本错；已查看expanded.png/intel.png，确认共用位置无重叠。

证据 .validation/tabs-run2.log，截图及Godot日志 C:/Users/admin/AppData/Local/Temp/IronTideCompactHud-9d54472df1994f43992766fc749cf1f3/report/tabs2.log。测试沿用上一轮隔离底座并同步当前hud.gd/runtime.gd/objectives.gd；首次漏同步objectives导致completed_items接口错，首次结果作废，不计通过。不宣称完整当前工作区集成通过；未测多分辨率/非远征完整回归，未打包提交。工作区并行runtime新增了任务完成提示，本轮已保留。
