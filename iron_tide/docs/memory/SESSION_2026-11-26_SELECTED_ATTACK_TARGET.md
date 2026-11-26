# 选中交战单位时显示当前攻击目标

用户反馈点击正在攻击的友方单位后看不出它在打谁。`scripts/world/movement_order_preview.gd` 原先只在 `attack_ordered` 且队列非空时绘制攻击路线，漏掉自动寻敌和无队列的单次手动攻击。现从选中的己方单位读取当前 `attack_target`，绘制红色虚线到可见目标的美术中心（强攻地面用下令点）；排队后续段仍用原路线色，自动交战连线与攻击移动路线可以同时显示。死亡、隐身、战争迷雾中的单位不显示，取消选择、停火或对局结束清除连线。未改战斗判定、选敌、全局识别描边和存档。

Godot 4.7.2 图形窗口隔离工程：`tests/movement_order_regression.tscn` 在 RA2 和 Iron Tide 扩展模式共 64/64。真实战场用生产选敌逻辑取得目标，经 SubViewport 鼠标事件选中单位，检查实际绘制像素及截图；覆盖直接点名、自动交战、同时攻击移动、死亡/隐身/迷雾、停止、取消选择以及既有移动路线。`tests/force_fire_regression.tscn` 无头 201/201，包含强攻和排队。两场退出 0、运行 stderr 为空；证据 `%TEMP%/IT-AttackPreview-20261126/{movement,force}`，已查看 `movement/ra2-attack-current.png`。未复现玩家原局，未单测防御建筑作为攻击者和特殊技能瞄准，未改玩家存档，未打包。
