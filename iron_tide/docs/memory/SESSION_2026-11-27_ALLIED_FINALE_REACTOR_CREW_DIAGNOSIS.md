# 《脑死》清剿时打爆反应炉出现紫色美国大兵：静态诊断

- 玩家报告盟军第七关末段打电厂出现紫色美国大兵。定位 Steam 尤复 `ALL07SMD`／`yr_allied_finale`。零售索引 SHA `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`；正式预置表 `data/ra2/allied_finale_field.json` 的可玩区含 `YuriCountry` 29 座、`Yuri2` 6 座 `YAPOWR`，另有 `Special` 的一座 `NAPOWR`，不要把开场苏军反应炉与南极清剿混为一谈。
- `data/ra2/death.json` 的零售通用规则：`YAPOWR` 为 `Crewed=yes`、无主武器；`AlliedCrew=E1`，`ThirdCrew=INIT`（尤里新兵）。`building.gd` 的普通摧毁以及出售入口都会调用 `building_crew.gd::eject`；这是建筑人员逃生，成功出生取决于随机判定和出口净空，并非末段任务刷兵。战役出击未传 `enemy_country`，`battle.gd::setup` 通用 `enemy` 国家缺省美国。逃生兵种查询认 `hollywood_house`，却不认盟军终关预置进 `allied_finale_room` 的真实归属，因此在正常菜单开局条件下走 `alliedcrew=E1`。逃生单位仍属于 enemy，按终关房色呈紫色；当前工作树的逃生逻辑还把 `allied_finale_room` 复制给单位后重新着色。
- 正确方向：保留逃生，按当前有效建筑所属房取兵种；尤里反应炉为 `INIT` 而非把 E1 改色或删除。若实施，需正反核对三尤里房、占领后归属、出售/摧毁路径及正常房色；勿全局改掉国家默认值。此轮仅静态走查生产代码、零售规则抽取及地图数据；未开游戏逐座复现、未查玩家存档、未改实现。
