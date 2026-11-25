# 矿车吸矿表现（2026-10-23）

现象：原版 CMIN 停在矿堆旁，载货增长，但没有吸矿特效。
源码确认采矿分支只执行 extract / cargo；原版贴图绘制没有采矿层，
静止、未选中、无伤害反馈的单位也不持续 queue_redraw。

新增 HarvesterIntakeFx，由真实正数取矿刷新 0.15 秒表现窗口。
矿粒从当前矿点向车头移动，普通矿石金黄、宝石多色；少量尘土收在吸入口。
使用当前车头方向与 Iso 投影，按车头前后先画或后画，避免背向时透过车体。
跟随单位可见性、深度、暂停和生命周期，无独立粒子节点或随机数消费。
窗口存续和最后到期帧均触发重绘，未选中的静止矿车也有连续表现。
手动移动、返场、卸货、眩晕、死亡、运输隐藏、切换或销毁矿点时禁止绘制；
零取矿不触发，满载返场停止。采集量、货仓、卸货收入、行驶与朝向规则不变。

验证：实际工程 Godot editor import 无 SCRIPT ERROR / ERROR。
harvest_fx_regression(Render) 120 项、harvester_regression 86 项，共 206 项通过。
覆盖两模式、矿石/宝石、八方向真实贴图、未选中时连续帧差异、停止状态、
真实取矿与货仓守恒、完整返场卸货、矿场制造矿车。已检查截图矿粒位置与停止后消失。
harvester 专项退出有 13 个 ObjectDB 残留警告，未在此表现改动中修复。

运行使用隔离工程/custom_user_dir，无网络、服务、端口或数据库依赖。
两轮源码指纹一致，交付时再次核对当前代码/数据/资源与测试版本一致。
原正在运行的游戏进程保持不动；从原启动脚本重开加载本次代码。
最终观感状态：`pending_user_visual_confirmation`，不写成使用者已确认。

证据：`C:/Users/admin/Temp/iron-tide-harvest-fx-20261023/delivery-audit.json`，
截图及断言位于 visual/reports，经济回归位于 economy/reports。

```powershell
./iron_tide/tests/run-navigation-building.ps1 -Suite harvest_fx_regression -Render -RunRoot '全新的外部验证目录'
./iron_tide/tests/run-navigation-building.ps1 -Suite harvester_regression -RunRoot '另一个全新的外部验证目录'
```
