# 私信头像尺寸与手记对齐

`scripts/screens/yuriko_school.gd` 的手记和私信头像共用 `place_portrait`，随页面大小按同一组锚点排布，保持素材比例并居中。

`tests/yuriko_school_regression.gd` 从手记点击「私信与礼物」，比较两个头像控件的全局矩形。Godot 无头运行使用独立存档，1210 项检查全部通过。验证覆盖控件位置和尺寸，未逐套服装比较画面截图。
