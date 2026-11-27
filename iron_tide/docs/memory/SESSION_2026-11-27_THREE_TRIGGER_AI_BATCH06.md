# 第 6 批：任务触发与地图 AI 并行接入

用户要求每批双线接入并分别报总数、正式接入、实测和剩余，已记录在 `AGENTS.md`。接[第5批](SESSION_2026-11-27_THREE_TRIGGER_AUDIT_BATCH05.md)。

## 任务触发

- `SOV01UMD 08E4940C`（原图 SHA 同第5批），`0B752F3C → 0BBB5C6C → 08E4940C`：最后一个带标签的岸防目标消失后，按原 `13,1` 等一规则秒，执行 `MISSION:Obj1Comp` 中文战报和 `EVA_ObjectiveComplete` 原音轨 `csof124`。`tools/export_time_shift_fleet.mjs` 编译该链，正式 `time_shift.gd::tick` 读取 `data/maps/time_shift_fleet.json` 并保存待播时间；不阻止正常的登陆雷达片。未向旧登陆档补播，未改变四艇顺序。
- 一条既有部分接线补至专项验证，不是新核验行。触发累计仍 108/681、待 573；总表由 16/91/1 改为 17 已接并专项验证、90 部分、1 缺专用链。

## 地图 AI

- 签名校验三图，新增 `tools/export_three_mission_ai_coverage.mjs` / [275 行 AI 台账](THREE_MISSION_AI_COVERAGE.tsv)。苏军首关 0 本图、165 个允许继承的 aimd 关联，39 行过现有尤里静态筛选，126 行不进入现有分支；39 未逐 ID 确认可在原场配出队，不是 39 个已验。好莱坞 36/36 进入现有正式选择（取代历史仅 6 条的口径）；首脑游戏 73/74 进入共享选择，`08CF30FC` 为原版空编组。合计 148 条正式候选或可评估、126 未进当前分支、1 空编组，本图规则合计110；好莱坞201、首脑游戏240 个启停覆盖因忽略全局 AI 不另计为可造队。
- 好莱坞 9 条已有规则补接真实区域警戒：`0B0615AC/0B08899C/0B08884C/0B08830C/0F7CBAEC/0F7CB99C/0F7CB84C/0C887AEC/0C88799C`。先对照零售 Team/TaskForce/Script 和数据中的 `11,11 → 49,0`，再用 [ModEnc ScriptActions](https://modenc.renegadeprojects.com/ScriptTypes/ScriptActions) 交叉确认 `11,11` 是不带计时的长期区域警戒，不是 11 秒；不主动执行后续 49。`hollywood_bases.gd::deploy_team_member` 按数据切到共用区域警戒（警戒点、视野内追击与归位），不再退化成固定原地警戒。`hollywood_mission.gd::hunt_house` 接管追猎时清旧警戒点。原版精确警戒半径、编队协同和权重仍非等价。新增接入 9 条的动作，不新增 9 个候选 ID。
- 本表精确关联到逐 ID 生产证据 10 条：本轮 9 + 旧 `0F7CB6FC`。另《首脑游戏》有三房随机选队、排产及一代表产品出厂的组回归，不能算多条固定 ID；苏一尚无逐 ID 原场出队证据。未逐条验自然交火，不声称 10 条整链完成；至少余 265 条未有本表逐 ID 生产证据，包含不适用和未接项，不等于 265 条都能自然执行。

## 复跑与边界

- 地图路径见第5批。重建 `node tools/export_three_mission_ai_coverage.mjs docs/memory/THREE_MISSION_AI_COVERAGE.tsv <SOV01> <ALL02> <SOV07>`；任务表按第5批命令。九条 AI 的原脚本、合成数据逐 ID 核对；其余 AI 的运行状态按对应选择器静态筛选，非完整指令审计。
- 日志 `.validation/three-trigger-ai-06/`。Godot 4.7.2 隐藏 `--headless --path <项目> res://tests/<关卡>.tscn -- <参数>`，隔离用户目录。最终八组 exit 0、stderr 空：`--retail-guard-ai` 45、`--retail-ai` 14、`--actor-report-sale` 17、`--naval-objective` 8、`--cold-naval-objective` 4、`--fleet-reinforcements` 28、`--cold-fleet-disarmed` 5、`--orders` 18，共 **139 项**。终验副本仅复制脚本/测试，引用同项目资源；只在副本给并行修改中的 `allied_first_transition.gd:70` 的 `half` 补类型以解除无关编译错误，正式源码未改该文件。首轮并行改动的公用护盾签名也曾短暂报错，最终证据不计失败轮。
- AI 专项在实际菜单战场中给玩家侧补齐前置、每条补足夹具资金，按 ID 指定选中的队，使用真实工厂扣费和出厂回调；验证九条在编组完整后收到警戒、一代表坦克摆位后 45 物理步回岗 `95→约17` 世界单位。未逐条验随机权重命中、自然交火、守备冷读、发包或玩家档。
