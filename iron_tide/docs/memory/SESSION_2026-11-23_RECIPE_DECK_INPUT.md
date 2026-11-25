# 配方窗口跟随右侧指令甲板

按玩家截图修正交互。production_recipes.gd 移除窗口内的类别和工厂选择器，解除输入独占。hud.gd 在刷新生产栏时同步已打开的配方窗口，使用甲板当前页签和工厂。标题标明工厂和编号，在可编辑页之间切换时按原分类和工厂恢复草稿。切到建筑或防御等无配方入口的页面会关闭窗口。

Godot 4.7.2 独立用户目录运行 tests/repair_recipes_regression.tscn，通过甲板页签和工厂按钮的 pressed 信号切换，验证二厂单独接单、一厂和步兵草稿恢复，输出 TECH_OPS_PASS，退出码 0。日志 %TEMP%/RecipeDeck-d07f55af/output.txt。验证为无头按钮回归，未做桌面鼠标实点或发行包验证。
