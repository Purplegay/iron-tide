# 中立建筑驻军初查（关卡归属已更正）

> 存档 4 证实截图为盟军 07《脑死》，并非《时空转移》。以下保留初查过程；实际帐篷 ID 和血量见 [存档 4 核对](SESSION_2026-11-27_ALLIED_FINALE_TENT_SAVE4.md)。

- 玩家截图为火地岛接管基地阶段，框内对象显示“中立”，血条目测约四分之一；未从截图唯一确认建筑 ID，未读取玩家存档。
- `data/time_shift_field.json` 的零售数据摘录包含多座初始生命 `64/256` 的中立可驻军民房；`scripts/world/native_maps.gd` 按 `/256.0` 还原预置民房血量。`time_shift_assets.json` 的驻军位由原版 `CanBeOccupied` 和 `MaxNumberOccupants` 导出；非驻军建筑不能靠维修变为可驻军。
- `scripts/units/civilian_orders.gd::can_enter`：中立民用可驻军建筑允许有驻军资格的步兵进驻，常规驻军须建筑可用、血量严格大于 25% 且有空位。`allied_abilities.gd` 有对受损中立可驻军建筑的工程师修理分支。玩家可用苏联工程师先修，再试动员兵驻军。
- 后续按用户授权只读检查标准玩家目录 `battles/` 的 14 个普通槽及备份。独立无头 Godot 脚本校验 ITSAVE01 长度、外层与载荷 SHA-256，安全反序列化读取任务 ID，未加载战场或写入存档。最新自动档与备份是 `yr_allied_finale`，最近手动档 slot2 为 `yr_head_games`；现有 14 文件无 `yr_time_shift`，因此无法用本轮玩家快照定位截图对象。此结论限于检查时的标准槽目录。
- 无游戏逻辑改动、无有头或战场实测，未确认截图对象 ID。
