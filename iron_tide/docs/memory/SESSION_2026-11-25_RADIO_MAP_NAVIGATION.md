# 通讯头像期间的小地图导航

`scripts/ui/minimap.gd` 让通讯期间的左键定位和拖动复用雷达地图投影，切换说话人时可延续拖动。悬停提示列出镜头操作。雷达干扰、暂停和地图有效边界沿用现有判定。

`tests/expedition_field_operations_regression.gd` 在真实救援通讯场景向小地图输入处理方法送入点击、拖动和松键事件，检查镜头位置、头像可见和拖动结束。Godot 无窗口测试 1029 项通过。日志在 `%TEMP%/RadarClick-021902/test.log`。验证范围为场景逻辑与控件输入处理。
