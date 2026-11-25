# 远征攻防带入

开局取同兵种局外攻防的较低等级，除以 4 四舍五入，攻防共用初值。已有 unit_growth 记录优先，保留营地养成成果。远征训练、特殊部队晋升、战斗倍率忽略局外攻防停用开关。营地显示原始等级及折算初值。修改 scripts/expedition/{growth,market,screen}.gd，并更新成长和提醒回归用例。

Godot 4.7.2 隔离运行 expedition_growth_regression，93 项中 90 项通过，包括局外 12/20 带入 3/3，旧停用记录 3/5 强化为 4/5，以及普通单位战斗倍率。基地车展开、展开后建筑防御和该建筑存读档防御三项失败。结果在 %TEMP%/CodexIronTideValidationGrowth165855/result.json 和 test2.log。未单跑提醒场景、未测试玩家存档、未打包。
