# 全选排除状态提示

单位指令的排除按钮采用圆圈减号，当前选中可操作单位全部排除时保持点亮。混选时保留原有一次点击统一排除的行为。己方排除单位在脚下绘制金色减号，状态栏首项显示「已从全选中排除」。三个提示读取原有单位字段。修改位于 scripts/ui/hud.gd、scripts/units/unit.gd、scripts/ui/progression_icon.gd。

在第 12 关隔离检查点上从 HUD 按钮验证单选排除、混选、整队排除及恢复。Godot 4.7.2 无头与完成初始化的 OpenGL 窗口均得到四项 true，窗口中状态栏图标检查通过。单独截图核对防空步兵脚下金色减号。覆盖当前测试视角和单位。证据位于 %TEMP%/IT-point-1938/exclude.log、graph.log、marker.png。
