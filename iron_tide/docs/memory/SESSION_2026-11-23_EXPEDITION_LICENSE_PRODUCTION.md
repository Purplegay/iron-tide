# 远征工厂按本轮许可生产

用户更新了 11 月 19 日的规则。远征玩家在对应工厂取得兵种许可即可下单。许可取代前置建筑、国家和单位研发要求。营地出战名单不控制工厂生产。队列满、机位满、英雄已在场等状态只影响下单，已许可的兵种仍显示在对应工厂。

修改 scripts/expedition/rules.gd、scripts/autoload/game_data.gd、scripts/buildings/building.gd 和 scripts/ui/hud.gd。tests/expedition_production_unlock_regression.gd 增加可选第 19 关存档场景验证。

从 17:02 的第 19 关存档副本恢复实际战场，在没有己方盟军作战实验室的条件下，光棱坦克出现在载具页、成功进入盟军战车厂队列并通过在产前置检查。填满队列后图标保留，移除许可后隐藏并拒绝下单。Godot 无头回归 14/14，日志在 %TEMP%/CodexIronTideValidationPrism19/run.log。验证范围至生产入队及前置检查，交付形式为源码。
