# 战场单位统一百合子护盾

`tools/bake_unit_shield.gd` 从 classic/JapanYurikoTech1.glb 的 YurikoShield 网格、FXYURIKOSHIELD.json、三张原纹理、yuriko_blast.gdshader 和现用亮度 1.15 烘出 32 帧 RGBA 图集。`unit.gd` 的世界血条入口复用已有的护盾总量，`unit_shield_visual.gd` 在可见单位首次开盾时分配 Sprite2D，复用纹理和加法材质，按本体包围盒缩放。多层盾共用一个外壳，破盾隐藏，再开复用。百合子自身灵能盾仍用对应衣装原模型。接入救援无敌及有增益时的车队救援盾。各技能移除重复盾圈，护盾条及单纯减伤提示保留。范围是单位战场外观，建筑和教学界面沿用原效果。

Godot 4.7.2 隔离用户目录运行 shield_catalog_regression，150/150 通过。GL Compatibility 实机场景在 64 个混合 MTNK、HTNK、E1、ORCA 上注入救援盾，正常世界绘制入口生成 64 个可见盾。破盾隐藏、再次开盾复用、死亡隐藏通过。预热后 500 批调用，每 64 个盾同步平均 67.336 微秒，只计 CPU 同步，不含 GPU 或完整帧。场景测试 stderr 有隔离目录缺 icon.ico 的日志。未逐技能截图、测长局帧率或打包。

证据在 `.validation/unit-shields-20261125/`，含 battle.png、临时实机用例、日志和目录回归结果。
