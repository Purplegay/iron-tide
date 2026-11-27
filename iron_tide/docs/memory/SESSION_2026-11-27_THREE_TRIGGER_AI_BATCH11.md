# 第 11 批：《首脑游戏》混编、导览、结算与 AI 资金条件

本轮目标 40+15，实际 40 条待核验任务迁至部分接线、44 条已有 AI 候选修正条件并实测比较边界（不是新增候选）。[本轮完整逐 ID 清单](THREE_TRIGGER_AI_BATCH11_IDS.md)。触发累计 241/681：17 专项、223 部分、1 缺专用链，待核验 440（苏一175、好莱坞226、首脑游戏39）。AI 仍 150/275 进入调度/评估，124 未进入，1 原图空编组；逐 ID 生产证据仍10，外层待办合计564，不含补齐部分接线及后续验收。

- 33 条混编链：`tools/export_head_games_drivers.mjs` 从经 SHA 审计的零售 `SOV07UMD` 提取启动、装载、并行倒计时、启用关系、旗标和伤亡替补。`head_games_combine.gd` 用真实 IFV 登车与运输车换乘驱动 Alpha/Beta；实验室条件或时间启用、两路替补读取原两秒、装配与告警不提前、两组 Alpha 完成后的五秒清旗和下一轮240秒。已派出的 Alpha 不被新队重招；Beta 装载就绪再等两秒卸载，保留五车队及原瞄准路线适配。本批没有逐动作解释所有原房、局部变量和难度演出，仍属部分。
- 4 条城堡收尾：`head_games.gd::objectives` 读取城堡触发后3秒欢呼、再9秒结算、欢呼循环3秒及启用关系。保持先处理两翼解放。3 条导览：盟军、苏军心灵信标及结束读取后继10/4/17秒；开场及语音入口仍使用项目既有雷达简报，未计为本批迁移。
- 44 条 AI 条件4：`head_games_orders.gd::dispatch` 按 `Credit` 原比较码和阈值读玩家账户，不用选队方的账户，生产队列原有扣所属房账户不变。44是非空已有规则数，未修改科技、权重和生产前置。动作参考零售 `AITriggerTypes` 及 ModEnc condition 4；44条比较边界均测试，加一个玩家实际钱包改值用例。未逐ID验选中、生产和交火。

## 验证与复跑

Godot 4.7.2 隐藏无头，真实菜单、隔离 APPDATA/LOCALAPPDATA。`.validation/three-trigger-ai-11/`：`credit-end`49、`combine-end`13、`kia-end`10、`castle-end`7、`main-end`52，合计131、全部 exit0、stderr空。实际生产队列代表回归造出 FV 和疯狂伊文，五车换乘、替补登车、城堡结算均覆盖；二次 Alpha 重启用状态夹具，未自然等完二轮。未新做独立冷读、未有头、未改玩家档或发行包。

地图 `SOV07UMD` SHA `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`。先 `node tools/export_head_games_drivers.mjs "$env:TEMP/IronTide-S07-retail/sov07.map"`，再照前批重建 `export_three_mission_triggers.mjs` 与 `export_three_mission_ai_coverage.mjs`；和本轮开始前两表比较仅40条任务状态从待核验更新、44条AI证据补注。用户交付要求按功能说明并提供完整 ID，已记录在 AGENTS.md。
