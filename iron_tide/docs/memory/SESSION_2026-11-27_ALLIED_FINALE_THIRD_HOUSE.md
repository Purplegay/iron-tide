# 《脑死》第三房资金、建造与沉船分支

按触发器/地图 AI 双表，续 OPENING_TRANSFER、ENDGAME_BRANCHES、RETAIL_RAID_CHAIN。Steam ALL07SMD 索引原哈希 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`。Yuri3 Credits=1000（地图单位百元，项目 100000），13 个 base node，其中 10 个原点在 LocalSize；原图 08CBA4FC 关联的建造场、三个反应炉均在界外，不往玩家可玩区补种。0930A91C/093138DC 抢油后 3/74 启用房建造/AI；08CBA40C 油井不再存在后 action 14 目标 French，参考 `ChangeHouseExecutor.ts` 对附属对象而非整房。08CBA88C 无挂标对象，保留空动作，不把六艇一起转走。任务事件 Win_Check 明确 9/14 两房；事件 9 在参考枚举是 DestroyedUnitsAll；运行仍用此前敌人+建筑与第三房残局保护（显式单列，房身份不再 mangle）。不是原版完整逐房结算。

`data/ra2/allied_finale_third_house.json` 按原图与 native origin 转 13 节点；`allied_finale_branches.gd` 独立资金、可玩且净空的原图节点逐个施工。因原建造场图外，只允许这批固定节点不受建造半径限制、保留地形和实体占用。实际施工使用 `_place_building(..., force_construction=true)`，修缺省共享 enemy 直接完工；油井收益、施工分期扣费、单位生产扣款经 `Battle.economy_owner` 取独立账本。不创建共享敌账的副本，旧档懒初始化而不重复发油井首占钱。74 开关记录但第三房 16 条专属地图 AI 尚未接，其他两房仍共用资金；围栏和邻域未全面验证。转属只作用带精确标签建筑，French 在项目以 neutral 适配；无标潜艇不动。停止后续第三房新施工，未专项验证在建项目转属。

`allied_finale_ai.gd` 装甲队新增 active team/outcome。艇仍活且未卸则保持联锁；死亡或脱离敌方记录 lost、允许正常计时的下一批，不假调用卸载或返航。这个可用性旁路是项目适配，原图没有查实通用同等被击沉旁路，不宣称逐触发等价；步兵与装甲的全套零售重入/返航联锁仍缺。

Godot 4.7.2 独立 APPDATA 隐藏无头真实菜单：主线 59/59、雷达冷读 5/5、玩家存档5隔离副本 8/8、支线 59/59（后两条转属断言加入后单独重跑，真实 ENGINEER 抢油、真实施工扣钱、夹具标签对象和实际载货艇 `_die()`，校验同房命令）。均 exit0 stderr 空，`.validation/finale-third-house/`。未试完整自然局、中途施工/沉船持久化冷读、实际法军外交或发行包；未改玩家存档。
