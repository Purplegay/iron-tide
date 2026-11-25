# 生产配方当局启用与逐项下单

扩展对局的己方生产配方直接读取 MetaProgress.technology_active。HUD 监听 meta_changed 刷新生产面板。科技树的购买提示和开关文案同步更新。

Building.order_recipe 按模板顺序检查普通生产条件，符合的订单立即追加，再检查下一项。队列空位也逐项占用。部分或全部跳过时显示实际排入数、跳过数和首个原因。配方模板保留原顺序，下次下单重新检查。

隔离用户目录运行 Godot 4.7.2 的 tests/repair_recipes_regression.tscn，输出 TECH_OPS_PASS，日志在 %TEMP%/recipe-live-run.log。覆盖真实战场加载后购买、按钮刷新、错误兵种全跳过、首项受阻后继续、剩一空位时部分成功、配方读回和队列快照恢复。验证使用扩展遭遇战场景。未单测远征存档或导出发行包。
