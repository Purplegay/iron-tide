# 油车旁按钮的跨帧点击

runtime.gd 的 update_tanker_bar 原本每帧先隐藏容器再显示，打断按下到释放之间的 GUI 状态。现在只在离开视野、车辆失效或任务离开选择阶段时隐藏。hud.gd 的 covers_world_pixel 也纳入可见的随车按钮栏。

expedition_field_missions_regression.gd 的油车护送、拆解两条路径现直接向车旁按钮坐标发送鼠标移动、按下和跨帧释放。测试夹具冻结整场模拟，因此单独启用按钮栏的 GUI 处理。Godot 4.7.2 独立档案专项回归 56 项通过，含真实战场部署、车辆进站、维修、恢复和拆解结算。源码无头测试记录位于 %TEMP%/CodexIronTideValidationFuel024745/after2.log。
