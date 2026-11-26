# 黑匣子一键送回

战场远征面板在携带阶段提供「送回交付点」和「放下黑匣子」。送回按钮通过现有 order_move 向当前携带者下达移动指令，到达后沿用支线交付结算。支线百科同步说明操作。F2/P 和 T 按实时 field_box 标记过滤携带者，手动点选仍可指挥。

Godot 4.7.2 使用隔离 APPDATA 运行 expedition_field_missions_regression.tscn，155 项检查全部通过，退出码 0。覆盖折叠 HUD 点击、移动目标、F2/T 排除、放下后恢复 F2、转交与交付结算。交付用例将携带者置于交付点，未逐图验证完整寻路。报告在 %TEMP%/CodexIronTideValidation-box-130717/field-missions.json。
