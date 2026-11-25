# 2026-11-20 基地车展开后的远征防御等级

用户指出远征养成中已购买的兵种防御强化也应保留到其建筑形态。核对 `scripts/expedition/growth.gd`、`scripts/world/battle.gd::deploy_construction_vehicle` 与 `scripts/buildings/building.gd::setup`：单位按unit_id获得的防御等级倍率已进入基地车 bonuses；基地车展开会新建建筑，建筑只初始化该阵营全局防御加成，原先未承接基地车专属成长。

实现：`battle.gd::deploy_construction_vehicle` 展开成功创建建筑后，仅对 ally 读取 `Growth.actor_factor(unit,"def")`，乘到新建筑既有 `bonuses.defense_bonus`。这样保留全局/建筑现有加成，不重复叠加已在创建建筑时应用的全局养成；敌方转换不变。读档快照原本序列化建筑 `bonuses`，不改存档schema。收起建筑后回基地车，单位按当前兵种成长初始化；再次展开由新基地车再次应用一次。

回归补充在 `tests/expedition_growth_regression.gd`：设置AMCV成长等级，验证基础车辆防御、实际展开后建造厂防御，以及远征检查点恢复后建筑加成未二次叠乘。

验证边界：`git diff --check` 通过；目标脚本和测试在独立副本与当前工作树SHA256一致。但 `tests/run-navigation-building.ps1 -Suite expedition_growth_regression` 首次隔离准备超过120秒；尝试复用已有导入缓存的副本运行仍超时，未得到Godot断言报告。因此这次引擎回归未通过也未失败，状态为未完成/未验证，不可宣称通过。未改动其他并行工作，未打包、提交。
