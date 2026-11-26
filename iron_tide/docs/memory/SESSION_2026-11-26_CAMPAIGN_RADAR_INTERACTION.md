# 战役小地图：下令、地点闪烁与事件回跳

原版语义参考 `refs/ts-ra2` 的 `WorldInteraction.executeMinimapClickCommand`（命令未处理则定位）、`CreateRadarEventExecutor`（地图动作 55 可按航点生成事件）与 `LastRadarEventCmd`（最近八条、400 ms 连按回看）。现保留本项目左键移动镜头、空格暂停；默认 `.` 回跳，可在战斗快捷键改绑。本轮不是逐条移植零售地图动作 55 或原版右键默认动作类型。

实际修改：共用 `minimap.gd` 左键对公开任务菱形和可见闪烁点有像素容差；左拖仍连续定位。右键短击用 `battle.gd::radar_ground_order` 走现有编队移动（Shift 排队、Ctrl 攻击移动）或选中工厂集结，并在没有可执行命令时定位。仅下达地面命令，不从小地图点名攻击或采集；未改选关静态预览。战役 `hollywood_film.gd` 小窗画面让开鼠标，跳过按钮保留；全屏仍锁战场。共用输入保留暂停、干扰、好莱坞雷达供电门控。`hud.gd` 与 `battle_hotkeys.gd` 接可改键的事件回跳，旧键表保留原绑定。闪烁重复触发去重，保留最多八个近期位置，非公开事件收录时必须可见；`fog_of_war.gd` 在战斗视野同步后广播既有火力源提示。苏军第一关在简报结束、开始夺取发电厂、接管基地等节点用已公开目标闪烁；切换时代清掉旧位置。雷达闪烁和回跳历史是临时界面状态，不写入存档；读档后持续目标继续按战役数据绘制。

测试：Godot 4.7.2 隔离用户目录。`campaign_radar_input.tscn` 苏军第一关实际战场与 HUD，SubViewport 注入鼠标/键盘，图形窗口 19/19；验证开场闪烁、目标点击、回跳、去重、过期、迷雾、右键移动/集结/无选择回退、真实通讯窗穿透，以及离线（夹具）和暂停。`minimap_regression.tscn` 图形 160/160、无头 133/133；此前镜头框像素检查混用逻辑坐标与物理像素，测试现换算分辨率并按抗锯齿后的线色检查，未改镜头框生产绘制。`time_shift.tscn` 无头 49 项通过，含从菜单出击到结算、时代与目标切换；`combat_building_fog_regression.tscn` 退出 0。最终各运行 stderr 为空。日志 `%TEMP%/IronTideHeroMinerBox-20261126/radar-delivery-*`，第一关整关日志同目录 `radar-pass-time_shift-headless/`。未逐关实测、未复播玩家原局、未改玩家存档或打包。未专项实测 Shift/Ctrl 小地图修饰键和战役中的风暴干扰。
