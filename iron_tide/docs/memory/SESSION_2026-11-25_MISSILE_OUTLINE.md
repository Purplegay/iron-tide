# 飞行弹体描边

普通 Projectile 已在单位描边系统之外。V3ROCKET、DMISL、CMISL 使用 Unit，过去会随己方单位获得黄边。scripts/ui/unit_selection_outline.gd 的 eligible 现排除这三种弹体，覆盖友军、选中和攻击目标的描边绘制。

Godot 4.7.2 隔离运行 tests/friendly_outline_regression.tscn，原版与扩展模式共 82/82 通过，退出码 0。每个模式实例化三种弹体并同时设置三种标记，验证不会创建描边层。其余检查覆盖坦克和建筑。验证范围为战场绘制入口，未逐帧复拍原截图的发射过程。隔离工程缺窗口图标，启动时有一条图标加载报错。报告在 %TEMP%/IronTideMissileOutline-87928/result.json。
