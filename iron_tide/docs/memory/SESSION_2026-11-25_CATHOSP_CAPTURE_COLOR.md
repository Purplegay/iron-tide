# 科技医院的中立标识和占领涂装

好莱坞科技医院 CATHOSP 的城市贴图使用原生红色色阶。HouseColor 现在为它启用 CITY_RED_RAMP，中立时取 Color.GRAY，有主时取当前所有者的阵营色。HpBar 在显示中立对象的世界血条读数时绘制“中立”，中立血条的基础色也取灰色。

Godot 4.7.2 好莱坞战役 --capture-aid 测试覆盖开场中立灰、工程师占领后的玩家涂装以及同进程快照恢复后的涂装。独立 OpenGL 渲染测试分别使用灰、蓝、绿色，每种命中 1375 个阵营色像素，所有不透明像素的超差数均为零。战役日志位于 %TEMP%/IT-Hospital-Pixel/campaign.log。本轮验证使用源码运行，中文标签按绘制逻辑核对，未做战场截图验收。
## 外墙实机复核

原城市医院 CATHOSP 的红色房色阶集中在屋顶。按玩家截图扩大了占领反馈。house_color.gd 给有主医院选择 HOSPITAL_FACADE，house_remap.gdshader 按石材色阶给墙柱和门廊上色，保留明暗、窗格和医疗标识。中立仍走原有模式。

Godot 4.7.2 源码从盟军战役出击，以工程师右键占领。tests/hollywood_campaign.tscn -- --capture-aid --hospital-pictures 完成，占领与同进程快照恢复检查通过，退出码 0，标准错误为空。两次实景裁图确认灰褐外墙变为蓝色。左中立、右占领的截图及日志见 evidence/hospital-facade/。画面覆盖好莱坞完好医院与默认盟军色。其他选色、受损外观和导出包未实测。
