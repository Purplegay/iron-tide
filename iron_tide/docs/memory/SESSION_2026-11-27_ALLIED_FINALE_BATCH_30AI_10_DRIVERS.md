# 《脑死》：30 条地图 AI、10 条正式任务驱动

承接 [25 AI／10 驱动](SESSION_2026-11-27_ALLIED_FINALE_BATCH_25AI_10_DRIVERS.md)。本轮接手时 10+30 的导出与部分运行代码已在工作树，双表还停在上批，AI 场景有 1 项计时断言失败。复核并完成此批，不再重复加入 10+30。[本批全部 40 个零售 ID 与验证范围](ALL07SMD_BATCH_30AI_10_DRIVERS_IDS.md)。

## 零售依据与覆盖

Steam `mapsmd03.mix/ALL07SMD.MAP`。本地解包 `.validation/allied-ends-20261126/source/all07smd.map.map` 实际 SHA-256 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`，用同目录 `audit/yr_all07smd_index.json` 关联原图。两份 TSV 的原始行均与索引对照；两导出器重新生成的《脑死》任务切片与终关 AI JSON 均与正式加载数据一致。

| 层 | 零售数 | 本批补接 | 累计进正式战场 | 实测范围 | 尚未进正式入口 |
|---|---:|---:|---:|---|---:|
| Tasks / Triggers | 88 | 10 | 80 | 10 个新增 ID 都在真实菜单出击的夹具流程看到触发/结果或执行标记；其中转属仅部分，字幕/音轨和精确镜头时序未逐动作验 | 8 |
| 本图 AITriggerTypes | 84 | 30 | 78 | 新增 1/30 专项：`087AB06C` 负条件、选队、真实扣款、完整出厂与接令；另外 29 只算进正式选队 | 6 |
| 本图对全局 AIMD 继承 | `IgnoreGlobalAITriggers=yes` | 0 | 不继承 | `AITriggerTypesEnable` 是启用覆盖表，不是额外的本图队伍 | 不适用 |

任务剩余 `0955DD2C／0960EE5C／078F61FC／061BD4EC／0EE0857C／04F32AFC／090AD17C／09197EDC`，其中油井外链难度与启用源未确认，不擅自打开；`09197EDC` 原图无动作，不计接入。地图 AI 剩余 `0C576C3C／13525D8C／095192DC／0A5A71BC／05ED315C／05ED772C`。脚本登陆队、开场空降和现有飞碟招募单列任务动作，不凑地图 AI 数。

## 正式入口与玩家结果

- `tools/export_allied_script_slice.mjs` → `data/ra2/allied_script_slice.json` → `scripts/world/allied_finale.gd` 的 `tick/apply/opening_action`。七条开场触发接管镜头、揭雾、五名工程师空降、雷达简报和交控；以小窗结束且空投落地作交控门。`06C3397C` 仅保留转属标记，玩家仍须按现有工程师接管流程操作，不把它算完整换房。拥有超时空传送仪后，`08E97BEC → 08E9757C` 播尤里原声并调动现有飞碟，不凭空新增；完整飞碟选敌脚本仍是近似。
- `04E8103C` 对应零售 Arabs 敌对。原图没有该房预置单位或建筑；本轮把其结果接入新开局 Arabs 登陆门，不只记一个标记，不对旧版存档回补开场。`0960D93C` 原图起始启用，75 是从触发器启用开始计时，兵营打开局部变量，不重启计时。将失效测试改为读正式驱动时钟分界，验证到点前不生成、到点后确实派艇；不是改短计时以通过回归。
- `tools/export_allied_finale_ai.mjs` → `data/ra2/allied_finale_ai.json` → `scripts/world/allied_finale_ai.gd::tick`。11 条尤里主房、19 条第二房（非洲）；24 条响应玩家兵种/设施、6 条按己房设施条件调度。保留原图数量、难度、初始权重、编组和脚本，生产走真实兵营／车厂、同房前置和现有经济。非洲兵营测试隔离其它候选，玩家有动员兵才选 `087AB06C`，实际训练 2 名病毒狙击手和 4 名尤里新兵并下令。复杂防守/择敌、权重更新、完整房经济和逐队抵达交火仍不能认为等价。

## 复跑与边界

- 两份数据复跑：`node tools/export_allied_script_slice.mjs .validation/allied-ends-20261126/audit <输出>`；`node tools/export_allied_finale_ai.mjs .validation/allied-ends-20261126/audit/yr_all07smd_index.json <输出>`。共享任务 JSON 只比较终关键，不覆盖并行修改的盟军首关。
- Godot 4.7.2 隐藏无头，隔离 APPDATA。`res://tests/allied_finale_playable.tscn` 主线 **91/91**、`-- --branches` **71/71**、`-- --enemy-ai` **43/43**、同主线快速存档独立进程 `-- --cold` **5/5**；均 exit 0、stderr 空，最终日志 `.validation/finale-30ai-handoff/`。本轮实测含从真实菜单出击、雷达续音保留、工程师真实移动/进门、登陆艇航行卸载及火地岛命中、雷达断点恢复不重发基地车。计时和战斗使用夹具；非洲专项未实际打到交火。本轮未重跑 slot4/slot5 旧档，前序工作树 `.validation/finale-30ai-10drivers/` 有既有各 8/8 日志，不计入本次结果。
- 未逐队自然打、未逐动作自然播放、未测开场空投或 AI 队列中途的独立冷读，未增加或重烘贴图，未做有头、未改玩家档、未打包发布。80/88 与 78/84 是接入覆盖率，不是整关复刻完成率。
