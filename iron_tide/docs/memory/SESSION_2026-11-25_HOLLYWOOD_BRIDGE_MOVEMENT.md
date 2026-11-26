# 好莱坞第二关车辆从桥边掉层

本地尤里逆向重建资料 `../refs/ra2yr-resource/src/object/foot.cpp` 约 1412 行记录 Foot 更新 `onBridge = IsOnBridge()`，只支持单位保存桥层状态这一结论。原版护栏的精确碰撞算法仍待核实。

旧 `hollywood_overpass.gd::sort_unit` 在排序时采样单位中心，中心离开桥面格便丢掉桥层。现在普通滑动与带交通例外的实际碰撞移动把前后位置交给 `record_move`，试探移动不改状态。完整桥段限制侧面越界，允许从入口驶离，地面车辆可横穿桥下。排序使用已记录层，断面缺失时清层。

隔离 APPDATA，Godot 4.7.2 headless 运行 `tests/hollywood_campaign.tscn -- --bridge-tech`，56 项通过，退出 0。六桥地形、损坏与小屋仍由原用例覆盖。车辆移动用例在 u=150 的桥验证灰熊从桥头爬坡、连续六次侧移保持桥高、返回桥头下桥及街道横穿。日志 `%TEMP%/holly-rail.log`。寻路仍使用单层网格。未覆盖玩家编队实战、全部桥端的车辆移动、冷读档与打包版本。
