# 好感手记目录恢复百合子立绘

`scripts/screens/yuriko_school.gd` 的好感手记目录现在复用手记主页的可切换立绘，并沿用本次进入手记后选择的造型。正文使用既有的说话人立绘逻辑。

`tests/yuriko_school_regression.gd` 分别从手记和私信与礼物进入目录，核对控件可见性、当前纹理与布局。独立档案 Godot 无头校园回归 1285 项通过。验证范围为源码场景的控件属性。运行日志 `%TEMP%/YurikoReply-dd75c3e6/affinity-portrait.log`。
