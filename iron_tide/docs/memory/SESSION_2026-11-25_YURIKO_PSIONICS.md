# 百合子免疫心灵控制

在 data/yuriko.json 的 unit 段补上 immune_to_psionics。GameData 将其加载为 YURIKO 的兵种属性，心灵控制塔、精控武器和心灵支配仪的夺取判定均通过 AlliedAbilities.flag 读取。

Godot 4.7.2 临时无头场景加载项目数据，分别让 YURI、YURIPR、MIND 使用 Controller 弹头判断目标，三者均拒绝百合子、接受 E1。YAPSYT 实际执行一次范围内选敌，目标保持 ally、无 controller，塔的控制列表为空。退出码 0。支配仪仅核对代码，未重放截图战局、测试旧档既有控制关系或打包。
