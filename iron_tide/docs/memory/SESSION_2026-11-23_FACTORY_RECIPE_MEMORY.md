# 每座生产设施的配方选择

production_recipes.gd 按当前生产建筑的 faction 和生产页读取模板，沿用旧模板键。每座建筑在 special.recipe_selection 按页记录选项。首次打开时使用 MetaProgress.recipe_defaults 中该阵营、建筑型号和页签的上次选择。已删除的模板回到新建。窗口下单校验当前工厂与打开时的工厂一致。

扩展遭遇战 tests/repair_recipes_regression.tscn 使用独立玩家目录运行通过。覆盖两座 GAPILE 选用不同模板、NAHAND 独立保存同名模板、同型初始默认、局外档重读和战场快照恢复建筑选择。日志 %TEMP%/recipe-memory-test.log 输出 TECH_OPS_PASS。载具、飞机和舰船共用窗口，本次实机场景用例覆盖步兵页。验证使用 Godot 4.7.2 无头模式。
