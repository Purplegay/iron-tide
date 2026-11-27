# 第 7 批：三图全图验收、任务触发与 AI

接第6批。原图沿用 Steam mapsmd03.mix 提取件，三图 SHA 见 [第5批](SESSION_2026-11-27_THREE_TRIGGER_AUDIT_BATCH05.md) 和 [零售地图复核](SESSION_2026-11-26_THREE_RETAIL_MAPS_WALLS.md)。隔离证据 `.validation/three-trigger-ai-07/`，不改玩家档或发行包。

| 项目 | 苏军首关 | 好莱坞 | 首脑游戏 |
|---|---|---|---|
| 地形格 / 坡格 | 14,124 / 1,331 | 18,972 / 1,286 | 18,414 / 1,902 |
| 裁剪内 Structures 坐标 | 三时代合计 149，另4条零耐久未装配 | 368 | 171，另16个渲染光照节点、2条零耐久未装配 |
| 贴图高差扫描 | 1,308 格，无告警 | 2,462 格，无告警 | 1,239 格，54个告警格归11处，待同机位人工判读 |
| 桥 | 金门任务桥坍塌及冷读；非通用工程师维修 | 100桥片；六高桥11个可玩入口车辆检验；逐桥断面、维修、断/修冷读 | 18桥片；一座低桥中段、两小屋、维修与断/修冷读；未补逐端桥下驾驶 |
| 中立设施、房色和语音 | 医院治疗、维修厂工程师占领/材质、任务媒体；修核电站与两个油桶错色 | 全建筑坐标、188墙栏、阵营专题、维修厂所有权与维修、明星媒体专项 | 各房、设施与秘密实验室、剧情媒体；16个光照具名入表 |

全图逐格 51,510、坡格 4,519 与零售 TMP 高度/坡向数据对照零差异；矿与墙栏数据比对通过。710 条裁剪内 Structures 中 688 坐标配对、16光照专用、6零耐久未装配，无未匹配/重复。`tools/audit_three_campaign_maps.py` 从零售提取坐标、房号、耐久、朝向、标签；菜单 `--map-inventory` 快照读取实际实体、材质色和运行地基；`node tools/compare_campaign_map_inventory.mjs .validation/three-trigger-ai-07` 生成 `building-comparison.json`。苏一任务电厂需用任务类型 2x2 地基；首脑游戏有139条使用运行地基反推中心，不能当独立的原始 artmd 地基核完。当前只配对坐标，不宣称逐建筑耐久、朝向、碰撞、贴图视觉、所有动态转属、单位声库或全部音轨都等价。房号统计暴露苏一返回时代三处 `YuriCountry` 被按通用蓝色渲染，`time_shift.gd::populate` 记录原房号、`HouseColor` 用原房作为尤里色依据，实际战场复测；已落入旧档的对象未迁移。苏一 Confederation 与部分好莱坞开场房仍有合并色/中立呈现，待单独对齐，不能以全通过交付。

## 双线接入

- **任务触发 +1**：`094D448C`，原图由 `0D0E096C` 启用，`0B752F3C` 清岸防取消；正式苏一开场玩家接管安排 100 秒未清岸防提醒，到期仅发一次，先清则取消。计时数据读零售表 `time_shift_fleet.json`，正式 `time_shift.gd` 执行。接管代原分镜起点，记部分而非等价；未专项冷读新的100秒提醒。本批 109/681、待572（苏一237、好莱坞226、首脑游戏109），17专项、91部分、1未接专用链。
- **AI 新增2条正式候选**：苏一 `0611A33C-G` 少于2辆奴隶矿车、`043F521C-G` 等于0个建造场，原来仅解读 `>=`，现在按零售完整比较码进入正式筛选。条件4查询该 AI 的敌方钱包（玩家），不误用己方。两个比较边界实测；未改科技、真实产线与招募前置，没有原场新出厂证据。三关合计 150/275进入调度或静态评估：苏一41/165、好莱坞36/36、首脑游戏73/74；124条未进现有分支、1原空编组；逐 ID 生产证据仍10。比较码语义用 [ModEnc AITriggerTypes](https://modenc.renegadeprojects.com/AITriggerTypes) 交叉核对。

## 验证证据

Godot 4.7.2 隐藏无头，按场隔离 APPDATA/LOCALAPPDATA；25份采用日志累计769条通过断言、无失败断言、stderr空。包括 `--map-inventory` 三关、好莱坞 `--all-retail-layout/--all-houses/--bridge-all-entries/--cast-media/--shop-repair`、苏一 `--hospital-feature/--shop-capture-color/--media/--naval-reminder/--naval-objective/--write-golden-gate/--cold-golden-gate`、首脑游戏 `--sites/--secret-lab/--house-economy/--media`，好莱坞和首脑游戏两套 `--write-broken-bridge → --cold-bridge-broken → --cold-bridge-repaired`。苏一最终房色/提醒测试为最后源码重跑；其它地图专项在同批但房色补丁前。断言含每实体检查，不等于逐项完整通关。部分批量进程只保留日志，未统一记录退出码；终版苏一三组明确 exit0。地形未开有头窗口，11处告警、逐坡路缘/车道接缝、逐房完整音画、桥下与自然操作仍需按矩阵后续补齐。
