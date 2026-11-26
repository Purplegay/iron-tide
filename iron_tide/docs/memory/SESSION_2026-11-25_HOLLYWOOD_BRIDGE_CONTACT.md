# 好莱坞桥面车辆接地

玩家截图显示地面车辆与绿色选中圈、阴影分离。此前车辆贴图随桥高抬升，体素和贴图阴影却抵消了全部抬升量，绿色圈、四角框与射程圈沿用街面坐标。Unit.bridge_contact_offset 读取桥面高度比例，为阴影、选中标记与射程预览提供同一个桥面偏移。

Godot 4.7.2 OpenGL 窗口从战役指挥室进入，tests/hollywood_campaign.tscn -- --bridge-tech --deck-contact-picture 通过 56 项检查。灰熊坦克从引道进入桥面后选中，核看截图中履带、阴影、选中圈与射程圈的位置，亦检查横穿街道后的图层。截图 %TEMP%/hollywood-deck-contact.png，日志 %TEMP%/holly-deck-contact-out.log。窗口核验使用标准等距镜头和灰熊坦克。