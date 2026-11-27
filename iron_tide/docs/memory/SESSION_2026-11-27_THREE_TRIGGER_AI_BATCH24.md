# 第 24 批：好莱坞简单难度售炮、苏一继承启用核查

用户目标新增 70 条 AI、继续接任务。实际新增正式部分接线任务 1 条，新增 AI 0 条；未把筛查条目当作新增。原图沿用 `.validation/three-trigger-ai-19/` 的 Steam MAP 提取件，导出器校验 SHA。

|关卡|零售任务总数|本轮新增|累计有接线|仍未接|
|---|---:|---:|---:|---:|
|苏一|302|0|300|2|
|好莱坞|253|1|247|6|
|首脑|126|0|126|0|
|合计|681|1|673|8|

本轮唯一新增 ID：ALL02UMD `10A9144C`。`0EB68F3C` 的 Triggers 链接字段指向 `10A9144C`，`10A95F4C` 是该链头的 Tag，挂在原 NAFLAK `(159,165)`；本地公开参考 `../refs/ra2yr-resource/src/team/tag.cpp` 显示同一 Tag 遍历 linked trigger chain。只改 `export_hollywood_drivers.mjs` 向既有正式 `hollywood_retail_sequences.gd::closure_tick` 导出此绑定，没有新造建筑。简单分支沿用现版交控后的计时，1 秒后原炮出售，退款归玩家；普通/困难沿用既有先转房再出售（本轮普通已回归，困难未另跑）。核验售出前冷读补发一次，售出后冷读不再退款。剩余任务原 ID：`0441BAAC 0C46AB3C 0930C39C 0ACD381C 08E7FB5C 07F39F3C 07F31BAC 07F3122C`。`0C46AB3C` 已找到 `0C46AA5C → 097DDE6C → 0951918C → 0C46AB3C` 及六座电厂绑定，但回城换场目前整体移除旧时代发电设施，而原动作在 `0BDCDD0C` 阶段后才运行；本轮不冒然将当前阶段的玩家发电设施改回盟军。其余不作无对象接线。

|AI 来源|原总|本轮新增|累计进入评估/调度|余项|
|---|---:|---:|---:|---|
|苏一继承|165|0|45|120 未纳入|
|好莱坞本图|36|0|36|201 全局覆盖被原图忽略|
|首脑本图|74|0|73|1 空编组；240 全局覆盖被原图忽略|

苏一 `AITriggerTypesEnable` 165 条为规则覆盖，不是启动房 AI。扫描原 `[Actions]` 全部操作码，3=生产开始、13=自动编队开始、74=AI 条件开始均未找到；公开参考 `house.cpp` 中两布尔构造默认 false，但不能据此排除其他引擎启动机制。已有第22批返城三档负例，且原返城无尤里兵营。此次把阻塞依据逐 ID 写入 120 条台账，不开早期 AI、不加原图没有的工厂，不新增自然出厂证据。下一步需从零售执行路径证实房启动或确定非原版扩展边界后，才可能批量启用。

`.validation/three-trigger-ai-24/`：Godot 4.7.2 `--headless --path . res://tests/hollywood_campaign.tscn -- --campaign-test-no-autosave`，分别追加 `--retail-closure21` 15、`--seed-retail-easy-sale` 8、`--cold-retail-easy-sale` 6，合计 29 断言，三组 exit 0、空 stderr；种档与冷读共享隔离 APPDATA。生成器 `tools/export_hollywood_drivers.mjs` 及 `tools/export_three_mission_triggers.mjs`、`tools/export_three_mission_ai_coverage.mjs` 已复跑。未测整关自然通关、图形窗口、困难单独或发行；未改玩家存档。
