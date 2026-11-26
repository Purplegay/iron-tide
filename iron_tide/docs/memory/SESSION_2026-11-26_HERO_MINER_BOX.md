# 英雄矿车「老秤」框选核查与调整

## 用户确认后的现行规则

用户明确希望英雄矿车可以和部队一起框选。`scripts/world/battle.gd::_apply_selection` 的优先判断和候选过滤均改用已有的 `Unit.is_ordinary_harvester()`：英雄老秤与非矿车同优先级，可和步兵、坦克一起框选；老秤与普通矿车混框时只选老秤；框里只有普通矿车时仍能选。普通武装采矿车与超时空采矿车都继续被混框过滤。Shift 追加机制、点选、描边、采矿和存档逻辑未改。

更新 `tests/miner_selection_regression.gd`，用真实晋升的 HARV、普通 HARV 与 CMIN，在经典和扩展模式通过实际战斗/HUD 注入鼠标，覆盖 0.5/1/2 倍缩放、正反向混框、与两名步兵混框、英雄单独框选、普通矿车单独成组和 Shift 追加，检查选中列表及选中标记。Godot 4.7.2 图形窗口隔离用户目录，242/242 通过、退出 0、stderr 为空；证据 `%TEMP%/IronTideHeroMinerBox-20261126/hero-included/`。未改玩家存档、未验证原局或打包。

## 改动前的核查（历史）

用户截图中，两名步兵脚下有选中圈，矿车只有黄色描边。改动前 `scripts/world/battle.gd::_apply_selection` 的混框过滤使用 `Unit.is_harvester`，不会因为 HARV 晋升为老秤而放行；此前 `is_ordinary_harvester()` 的英雄例外用于攻击等其他入口，不用于框选。普通混框只选非矿车；只框矿车时仍可选，Shift 混框保留原先已选的矿车但不会新增框里的矿车。`attack_target_outlines.gd` 与 `unit_selection_outline.gd` 对可见己方单位绘制常驻黄色归属描边，和 `selected_units` 及单位选中圈独立。这与截图外观一致，但未读取原局，不能仅凭截图确认其选择列表。

实际只修改 `tests/miner_selection_regression.gd`：从真实 HARV 晋升老秤，覆盖与坦克、两名步兵混框、点选、矿车单独成组框选、Shift 追加保留、普通框选清除旧选择，以及未选中仍有黄色描边。每个缩放在首帧绘制后为隔离夹具明确设置焦点，避免初次系统焦点事件吞掉鼠标输入。Godot 4.7.2 图形窗口、独立用户目录、真实战斗/HUD 和 SubViewport 注入，经典及扩展两模式，0.5/1/2 倍缩放，226/226 通过，退出 0、stderr 为空。日志及 JSON 在 `%TEMP%/IronTideHeroMinerBox-20261126/after/`。未改生产逻辑、原存档或导出包；未复测玩家原局及其版本。
