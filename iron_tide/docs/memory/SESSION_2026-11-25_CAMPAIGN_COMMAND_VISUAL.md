# 战役指挥室实机排版

campaign_command.gd 按第二版稿实现页头、导航条、阵营侧栏、任务卡、地图边框、目标列表、三列资源表、养成选择和金色出击按钮。按参考画布等比适配窗口，标题和金额直接读取当前任务数据。资源表列头使用战略点、军需券和钻石的钱包图标。

在 Godot 4.7.2 OpenGL 窗口从主菜单打开盟军任务，截取并人工检查最终画面，截图 %TEMP%/it-command-live.png。菜单路径回归 7 项通过，从新页面出击的关卡回归通过胜利结算。日志 %TEMP%/it-command-live.log 和 it-command-launch.log。