# 2026-11-20 远征矿车卡死：基础穿越规划与碰撞条件不一致

用户反馈当前远征矿车不动，先要求备份检查，随后授权修复。未改玩家存档、未停止游戏、未打包提交。

## 备份与事实

原档 C:/Users/admin/AppData/Roaming/Godot/app_userdata/Iron Tide RTS/expedition.itrung，最后写入16:18:23。主档与.bak已复制至 `.validation/miner-stuck-20261120-1626/`。
主档SHA256 F16BA58831DDA25A639E734956D9F044B13C3DCAFF1388F7A77B83D03EF81096。
第2关yr_unrepent，己方3辆/敌方2辆HARV。先前回复“5辆己方”错误；总计5辆矿车。
关注己方cargo16、position(3758.781,645.8715)矿车。此前仅据expedition_still=10推断矿点接近卡死不成立：此字段采矿驻留也累计，上份cargo9而当前16。恢复完整战场才复现真实故障。

## 根因与修复

Battle.path_for_unit中FoundationTransit.enabled+crosses给所有远征己方地面单位直接两点路径，包含没有has_move_order的自动采矿。Unit._traffic_collision_exceptions只在enabled && has_move_order && !_deployed提供穿友方建筑碰撞豁免。自动矿车因此获得穿新建NAPOWR(3800,1040)的路线，却受真实建筑碰撞阻挡；stuck重复重算仍选相同直线，连带矿车堵车。

生产只改scripts/world/battle.gd这一条分支，加入u.has_move_order && !u._deployed，与碰撞条件一致。自动采矿/返厂恢复正常建筑绕行，显式移动仍支持远征友方基础穿越。旧检查点直线路径通过既有stuck重新规划可恢复，无需改存档。

## 验证

隔离完整项目：C:/Users/admin/AppData/Local/Temp/IronTideMiner-20261120，独立custom_user_dir CodexIronTideValidation-Miner20261120。Godot4.7.2 headless --fixed-fps60真实scenes/battle.tscn恢复备份。

- 未修复：probe-full.log/probe-hit.log，全战场7200 physics frames，采满40后卡在电厂及其他HARV，长期位置约(3781.5,1123.4)，没有卸货。
- 修复后：probe-fixed-verified.log，同存档7200步，全战场正常tick，关注矿车完成5次卸矿（cargo>0到0计数），exit0，无SCRIPT ERROR/ERROR。
- tests/expedition_foundation_transit_regression.gd新增3断言：自动矿车绕行、路线不穿工厂、手动矿车仍可直穿。17/17通过。
- native_ore_regression真实场景48/48通过，RA2/扩展、美苏采集卸矿及存档恢复覆盖。
- git diff --check通过。

证据与回放脚本存于.validation/miner-stuck-20261120-1626。测试副本为绕开既有field_operations循环加载，campaign/runtime/battle_snapshot对该脚本改动态load并补campaign数组类型；生产未引入这些无关改动。最终field_operations从生产重新复制，早期测试副本的手工缩进错误已消除。最终验证日志无脚本错误。生产工作区存在大量并行未提交修改，未覆盖其他修改。
