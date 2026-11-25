# 生产配方窗口切页

scripts/ui/production_recipes.gd 在窗口顶部显示指令甲板已开放的兵种分类。切换时调用 HUD.select_prod_tab，按新分类读当前工厂、配方和兵种目录。窗口按阵营及分类暂存配方选择、编辑名称和草稿顺序，关闭时释放。

Godot 4.7.2 通过隔离用户目录运行 tests/repair_recipes_regression.tscn。步兵草稿切载具再切回，检查分类同步、名称、顺序、兵营及后续下单。输出 TECH_OPS_PASS，退出码 0，日志 %TEMP%/recipe-tabs-test.log。验证限于无头场景，未进行鼠标实点及发行包验证。
