# 第 19 批：从第 18 批接手续补余项

按用户要求先读第 18 批、逐 ID 表和迁移规范；从本批起以补完剩余任务和 AI 为目标，不把「已出表」「可进入选择分支」当作等价完成。本批接入和限制见[完整逐 ID 对照](THREE_TRIGGER_AI_BATCH19_IDS.md)。

|关卡|原任务总数|本批新增部分接线|累计有正式接线|待逐条核验|其他|
|---|---:|---:|---:|---:|---|
|SOV01UMD|302|1|284|18|0|
|ALL02UMD|253|13|238|14|1 缺原图专用链|
|SOV07UMD|126|0|126|0|0|
|合计|681|14|648|32|1 缺原图专用链|

任务累计 648 含 631 条部分接线、17 条此前专项验证。本批 14 条中 11 条有本轮专门条件或行为断言，1 条仅验证媒体和坐标，2 条正例未独立实测。与第 18 批「635 已核验」口径对应，本批核验总计 649（含一条已明确缺专用链），不是 649 条完整实现。

|AI 来源|原条目|本批补纳评估|累计进入评估/调度|未进入主分支|其他|
|---|---:|---:|---:|---:|---|
|苏一全局 aimd|165|4|45|120|不算本图 AI|
|好莱坞本图|36|0|36|0|全局 201 项启用覆盖被忽略|
|首脑游戏本图|74|0|73|0|一条原空编组；全局 240 项启用覆盖被忽略|
|合计|275|4|154|120|1 空编组|

苏一四条原条件码 7 的机制不是本轮从零新增：旧代码已有条件比较，本轮限制成完工中立建筑、过滤错误交互目标、补工程师到门转属时确切房号，补入漏记的台账；不宣称四条自然出厂。四条均测难度和无目标，三条以实战地图夹具证实到门，机场原图无目标不伪造。既有逐 ID 自然/生产证据口径仍 10；本轮不增加生产完成计数。另 120 条已按房号/阵营/IQ/初始外交静态标注，不把 7 条没有静态候选当作原版最终不可达。`SOV07UMD` 本轮无代码改动。

## 正式入口和来源

- Steam `mapsmd03.mix` 重取 `SOV01UMD`、`ALL02UMD`，第三关复用本机零售提取件 `$env:TEMP/IronTide-S07-retail/sov07.map`。三张 SHA 与第 18 批相同，导出器硬校验。FinalAlert 2 `FAData.ini` 核对事件 58=指定房满电，59=进入或飞越格，33=选中，4=从黑幕中发现。零售 `soundmd.ini` 与 `audio.idx/bag` 取 12 条原声；未更换任何地形、单位或建筑美术。
- 《好莱坞》`battle.gd::_apply_selection` → `hollywood_retail_sequences.gd` 以原 TeamType 标签发平民点击语音，不给中立单位指令；按原十秒重新启用。`hollywood_mission.gd::tick/discover` 接卫星、36 个原备援格、点击及黑幕发现，共用现有英雄入队。回收区环境音仍走最近点播放器，没有复刻原引擎的并发混音。原受害队未齐。
- 《时空转移》`time_shift_events.gd::dominator_power_alarm` 走原警笛、中文任务讯息、EVA 与关闭标记；沿用现版四厂代表 Arabs 满电的失败门槛，没有改为分房电网。`time_shift_global_ai.gd` 与 `allied_abilities.gd` 走原目标编号和通用工程师交互，到门才替换原房。

## 证据及复跑

`.validation/three-trigger-ai-19/`：Godot 4.7.2 隐藏 `--headless --path .`，每组独立 APPDATA，以下门槛 exit 0、stderr 空。`hollywood_campaign.tscn -- --retail-batch19` (`holly-clean`) 32、`--retail-batch15` (`holly-reg`) 46、`--actor-report-sale` (`holly-report-final`) 17；`time_shift.tscn -- --retail-tech-capture` (`tech-gate`) 24、`--retail-power-alarm` (`alarm`) 6、`--retail-global-rally` (`global-rally`) 77，共 202。原开发日志保留，不算通过证据。生成：`node tools/hollywood_media.mjs <Steam游戏根目录>`、`node tools/export_hollywood_drivers.mjs <ALL02原图>`、`node tools/export_time_shift_fleet.mjs <SOV01原图>`；再对按 SOV01/ALL02/SOV07 顺序的三个 MAP 运行双台账 `tools/export_three_mission_triggers.mjs`、`tools/export_three_mission_ai_coverage.mjs`。

未做本批新状态的冷读、有头、真实鼠标选择正例、所有任务自然通关和全难度验证；未改玩家档、未打包。下一批先处理苏一 18 条与好莱坞 14 条待核验以及 1 条专用链；AI 优先核实苏一盟军/阿拉伯房在哪个时代实际允许选队、原超武条件与脚本差集，再补各自的资金、产线和阶段门控，不统一硬开 120 条。随后继续对 631 个部分接线 ID 补其同行动作及验收。
