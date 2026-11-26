# 好莱坞桥口转弯

`hollywood_overpass.gd` 原有路线在桥头相邻一格即可折返。现在桥头路线沿引道轴线向街道多走两格，寻路检查该段地形可走，再连接街道路段。两格距离是移植取值。

`tests/hollywood_campaign.tscn -- --bridge-orders` 在隔离 APPDATA、Godot 4.7.2 headless、fixed-fps 60 下 11 项通过，stderr 空。南段桥面目标 (55.5,139.5)，光棱坦克从正下方接令后在地面到达桥口外转向点，再经多个物理步抬升并抵达点击处。也覆盖从街道上桥和返回街道。日志 `%TEMP%/holly-turn-final.log`。窗口遮挡观感、其他桥头和编队尚待验证。
