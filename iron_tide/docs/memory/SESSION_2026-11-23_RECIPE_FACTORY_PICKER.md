# 配方窗口直接切工厂

scripts/ui/production_recipes.gd 在页签下方加入接单工厂选择器，复用指令甲板的候选建筑、编号和选择逻辑。展开时刷新候选，切换后重载该厂的兵种目录与配方。窗口内的编辑草稿按阵营、页签和建筑实例保存。

Godot 4.7.2 隔离用户目录运行 tests/repair_recipes_regression.tscn，输出 TECH_OPS_PASS。两座 GAWEAP 来回切换，二厂收到一项 MTNK 订单，一厂队列为空，切回一厂恢复名称和草稿。日志位于 %TEMP%/recipe-factory-test.log。验证范围为无头遭遇战和选择信号，未进行鼠标实点。
