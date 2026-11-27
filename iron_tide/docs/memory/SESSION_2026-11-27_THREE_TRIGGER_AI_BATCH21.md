# 第 21 批：时代收尾、返航、好莱坞后继与逐房 AI 产线

目标 20 任务 + 60 AI。实际 **14 任务 ID 正式部分接线（13 原待核验 + 1 原缺专用链），74 个已挂接 AI ID 补机制（73 首脑 + 1 好莱坞），零新增 AI ID**。未把静态取证或无对象节点当成已迁移。Steam 三张提取件和硬校验 SHA 沿用 `.validation/three-trigger-ai-19/`；双台账重建。

|关卡|零售任务总数|本次新增部分接线|累计正式接线|待核验|
|---|---:|---:|---:|---:|
|苏一|302|9|296|6|
|好莱坞|253|5|246|7|
|首脑游戏|126|0|126|0|
|合计|681|14|668|13|

## 本轮完整任务 ID

|关卡|原 ID|正式入口、玩家结果与边界|
|---|---|---|
|苏一|`096879AC`|阶段收尾后 45 秒清指定旧房 Arabs 单位；夹具验差一与到点，旧房建筑、原多房清除未全迁|
|苏一|`097651DC`|时光机就绪时，如果鲍里斯在世，取消替补；夹具验待办取消，未复刻销毁原附属 Tag|
|苏一|`0CAAF7DC`|第二次换场前，将旧 `CATIME02` 恢复为原 `Soviet2House`；夹具验归属元数据及可用侧|
|苏一|`07F2978C`|记住第二艘指定巨型乌贼死亡旗标，返回时代收尾后在门槛满足时执行，美军余部以中立适配；实测门槛，未测自然残余部队与外交|
|苏一|`0937687C`|七处零售原路点重盖局部黑幕，保留可见区域；验一处实际黑幕，未迁原裁切矩形|
|苏一|`078C97EC`|桥损毁接一秒后继，本节点没有零售附属对象；夹具验排程|
|苏一|`079BB93C`|原桥附属五种类型恢复中立；夹具验一处实际转属|
|苏一|`06A67A6C`|已卸空的 Grand 船仅在 Gas 卸载旗标成立时拿到原返航路线；夹具验差一和刚满足，复用实船不另生船|
|苏一|`0C122E5C`|原一秒后清 Grand 旗标；实测计时，不宣称原制队继承完全一致|
|好莱坞|`08D5E88C`|阿拉伯房全灭后启用原无目标后继；实测全灭、未复刻凭空生成光棱|
|好莱坞|`08E7FF3C`|苏军房全灭同样启用其无目标后继；未独立实测|
|好莱坞|`0EB68F3C`|原坐标 (159,165) 防空炮正式落图，普通/困难按零售转房并出售；实测简单、普通边界及实际出售，场景计时从交控起算|
|好莱坞|`0963AA4C`|原 3 尤里新兵 + 1 盖特齐员后，复用原队设/清局部 15 并下攻击命令；实测正式完成队伍入口，不算逐队自然出厂|
|好莱坞|`088F344C`|从原缺专用链改为中立居民独立欢呼时钟，十秒时执行；与目前结算同刻，未实测玩家可见动画持续时长|

苏一正式入口 `time_shift_retail_cleanup.gd`, `time_shift_staging.gd`, `time_shift_events.gd`, `time_shift_late.gd`, `time_shift.gd`, `battle.gd::_on_unit_died`；局部黑幕由 `fog_of_war.gd` 执行。好莱坞入口 `hollywood_retail_sequences.gd`, `hollywood_mission.gd`, `hollywood_bases.gd`。继续核查剩余苏一 `09601D2C 0441BAAC 0C46AB3C 087D15EC 082B950C 082B933C`；好莱坞 `0930C39C 0ACD381C 08E7FB5C 10A9144C 07F39F3C 07F31BAC 07F3122C`。其中一些原图未绑定对象或缺旗标来源，不填造假对象，不直接计作迁移完成。

## AI 本轮范围

|来源|原总数|本轮新增|本轮补已挂接|累计评估/调度|未进入/其他|
|---|---:|---:|---:|---:|---|
|苏一继承 aimd|165|0|0|45|120 未进入|
|好莱坞本图|36|0|1|36|201 全局启用覆盖被忽略|
|首脑本图|74|0|73|73|1 原图空编组；240 全局启用覆盖被忽略|

首脑 `head_games_orders.gd::dispatch/production_plan_ready` 对全队实时检查本房余额、可用工厂与生产前置；`building.gd::unit_prereqs_ok` 实际排队也查本房完工建筑，避免跨房借前置；资金只门控、不预扣整队，既有工厂分步扣费保持。玩家钱包仍用于原 AI 条件，不和队伍本房余额混用。逐 ID 夹具 73 条都有差一反例、满额与本房工厂资格对照，当前开局 65 条有合格产线，8 条没有，不判定其永久不可达。另好莱坞 `0BA16EDC` 测齐员后进入任务 `0963AA4C`，不重复制队。逐 ID 自然/生产档口径未增加。

首脑 73 个 ID（原队、任务组、脚本和本轮证据见 [AI 台账](THREE_MISSION_AI_COVERAGE.tsv)）：

```
0A2F2EDC 08CF099C 0A2F2C3C 0A2F2AEC 0A2F299C 0A2F284C 0A2F26FC 043B30BC 043B0EDC 0CC7851C 0CC7B36C 0CC7B21C 0CC7CDCC 0CC7CC7C 0CC7C1FC 0CC7DB8C 08CF114C 08CF2EDC 08CF2D8C 08CF2C3C 08CF2AEC 08CF299C 08CF16FC 08CF15AC 08CF251C 08CF23CC 08CF227C 08CF212C 08CF3EDC 08CF3D8C 08CF3C3C 08CF3AEC 08CF284C 08CF26FC 08CF363C 08CF34EC 08CF339C 08CF324C 08CF4EDC 08CF4D8C 08CF4C3C 08CF399C 08CF384C 08CF476C 08CF461C 08CF44CC 08CF437C 08CF422C 08CF40DC 08CF5EDC 08CF5D8C 08CF4AEC 08CF499C 08CF588C 08CF573C 08CF55EC 08CF549C 08CF534C 08CF51FC 08CF50AC 08CF6EDC 08CF5C3C 08CF5AEC 08CF69BC 08CF686C 08CF671C 08CF65CC 08CF647C 08CF632C 08CF61DC 08CF608C 08CF6D8C 08CF6C3C
```

## 验证与复跑

`.validation/three-trigger-ai-21/`。Godot 4.7.2 隐藏无头、每组隔离 APPDATA，用 `--campaign-test-no-autosave`（editor 构建才认，首脑最终组已断言不处理自动保存；无远征进程）。`time_shift.tscn -- --campaign-test-no-autosave --retail-batch21` 11、`--raid-return-chain` 75；`hollywood_campaign.tscn -- --campaign-test-no-autosave --retail-closure21` 13；`head_games.tscn -- --campaign-test-no-autosave --retail-ai-production-budget` 222、`--orders` 19。合计 340，最终组皆 exit 0 且 stderr 空；开发期好莱坞失败日志保留，不计通过。重跑导出 `tools/export_time_shift_fleet.mjs`、`tools/export_hollywood_drivers.mjs`，再用苏一/好莱坞/首脑原图顺序运行双 TSV 生成器。未做本轮新状态冷读、真实有头、整关自然通关、全难度逐队出厂；未改玩家存档、未打包。
