# 百合子护盾不透明度

在 `scripts/units/yuriko_model.gd` 将三套衣装共用的护盾材质 opacity 从 1.0 调至 1.15。静态核对了战斗和技能演示的护盾显示路径，以及实际材质 `yuriko_blast.gdshader` 的计算。覆盖值随系数提高，上限为 1。本次未做画面对比。
