# 通用复制中心与《首脑游戏》占领

用户要求步兵复制接入各模式，不只遭遇战，并让本关占领后能用。零售 `rulesmd.ini` 导出的 `data/ra2/buildings.json::NACLON` 为 `Cloning=yes`、`capturable=false`、`powered=false`、`CreateUnitSound=CloningVatsCreate`；`SOV07UMD` 零售结构 `1037153=BadGuy1 House,NACLON,...`，无 `[NACLON]` 覆盖。开放苏七占领是当前项目玩法调整，不是零售行为，其他地图仍用各自占领规则。没有增改地图任务触发器或 AI 表。

- `building.gd` 的兵营队列成功生成才调用 `yuri_support.gd`，不再看遭遇战标识。每座同房、正常运转且有合法出口的 `NACLON` 免费出一个副本，使用建筑生产来源和原版出兵声；不重入队列，不复制脚本增援、载具或项目唯一英雄。出口被堵不补排。不额外写生产计数。房号使用既有经济归属（含首脑游戏），好莱坞、盟军首关、盟军终关用各自房号字段区分共用敌方 side 的房。仍用现有出口选位与单位上限，不声称完整仿真零售细节。
- `GameData._building_definition` 只为 `yr_head_games` 开放占领，并补中文提示。`battle_snapshot.gd` 读本关旧快照刷新占领字段和说明，不改变设施归属。战役与遭遇战说明同步，后者生成器同步。
- Godot 4.7.2 隐藏无头、隔离存档：`tests/head_games.tscn -- --cloning-vats` 21 项、`--cold-cloning-vats` 5 项、`tests/yuri_skirmish.tscn` 101 项。三组 exit 0、stderr 空。覆盖工程师命令与进门、同一正式训练队列占领前后出兵数与扣费、复制位置、未运转/摧毁、唯一英雄排除，以及改旧字段后写盘再用独立进程读回并继续复制。日志 `.validation/cloning-vats-20261127/*-final.out`。测试用夹具调整到门位置并推进队列；未做有头试听、其他战役逐关、远征实战、玩家存档或重新打包。
