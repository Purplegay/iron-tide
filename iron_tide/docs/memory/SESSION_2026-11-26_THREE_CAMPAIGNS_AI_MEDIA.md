# 三关 AI、事件、原声与 CG 复查

## 证据与范围

`tools/audit_three_campaign_media_ai.mjs` 将现有零售 `mapsmd03.mix` 的三个提取件与安装版 `evamd.ini`、`soundmd.ini`、`artmd.ini` 串起，导出原始 AI 行、开启覆盖、Team/TaskForce/Script、动作 19/21/100 及来源样本。生成 `.validation/three-ai-media/retail-audit.json`；原始地图与 SHA 见 [上轮交接](SESSION_2026-11-26_THREE_CAMPAIGN_TRIGGER_FOLLOWUP.md)。动作 100 的 `movieIniSameKey` 是 artmd 编号同键参考，不代表已证明引擎用同键索引。复跑：`node tools/audit_three_campaign_media_ai.mjs '<Steam 尤复目录>' '.validation/three-ai-media' "$env:TEMP/IronTide-S01-retail/sov01.map" "$env:TEMP/it-hollywood-retail/all02umd.map.map" "$env:TEMP/IronTide-S07-retail/sov07.map"`。

| 地图 | 任务触发器 / 本图 AI 行 / AI 启停覆盖 | 补接与未完成 |
|---|---:|---|
| SOV01UMD | 302 / 0 / 165 | `time_shift_events.gd` 让上岸 INIT 针对零售行动组指向的电厂推进；电厂是玩家所有时下攻击目标指令，同战斗侧时攻移到周边，未实现跨细房攻击盟军电厂。原图未忽略全局 AI，0 条本图条件不等于没有 AI，也不把启停覆盖数当攻击波数。波次航线、返航和全局选择仍非完整复刻。 |
| ALL02UMD | 253 / 36 / 201 | `hollywood_bases.gd` 将两基地共用四队轮播替换为第一批六条有依据的本图规则 `0C6C0EDC/0C6C0D8C/0C6C0C3C/0973075C/0F7CB6FC/05D5239C`，用对方/本房对象存在控制，按初始权重、队伍和本房现存工厂付费生产，齐员统一出击。副基地后门队使用 105/94；原图目标类型优先级仍近似 `_player_target`，其余 30 条未纳入，仍共用战斗侧资金、适配轮询。旧存档不接续旧轮播进度，但保留既有旧标记生产单的出厂派发。 |
| SOV07UMD | 126 / 74 / 240 | `head_games_orders.gd` 选队前查实际所属房能提供每种编组产品。`0A2F2EDC/08CF608C` 的触发房字段是 BadGuy2，TeamType 的 House 是 BadGuy3；改按 TeamType 生产房选择，避免用错误产线和账户。动态权重、各队专属目标顺序仍未等价；本轮未分别强制选中两条差异规则。 |

## 语音与影片

- 首关 `0D17FAAC` 与后续 `0D17876C` 支持鲍里斯报到、索菲亚介绍的相对顺序。`time_shift.gd` 移除此前在片尾提前连发的鲍里斯报到和介绍，给实际登陆对象标记，`time_shift_events.gd` 在下船后报到、3 规则秒后介绍，各用原声。简单化的其它连发片尾对白仍在，不宣称原版全部间隔。
- 好莱坞 `07F40CAC` 由四条 Grinder Gone 启用；`hollywood_mission.gd` 允许先拆任一厂，延迟 1 规则秒再播放 `xs3yu05` 一次，兼容旧档已拆第一厂。`094D821C` 建筑索引 27 是 `NADEPT`，不再把盟军维修厂也当触发。`hollywood_dialogue.gd` 对照 `evamd.ini` 修正第二段尤里字幕。`xa2ev03` 无已确认对应原图调用，不强接。
- CG 无缺资源：三关目录 11 段正片与各自同 ID 收藏节选，首关 4 个独立音轨均非空。首关 4 段媒体运行、第七关短片续音/字幕/基因突变器通讯与胜利后 `S08_F00E` 已跑；好莱坞主线验 3 段进入播放、字幕和交还控制。好莱坞 `05D9EE6C Carville_Comment` 与发现片场相关，现版把 `A02_P02E` 用于开场回收厂导览；旧交接中对该媒体的说法与当前字幕/时序不同，仍需按实际音画、零售索引语义确认后重接，未贸然调换。独立音轨 `A02_p01` 不能按缺同名 WAV 报遗失，现有影片内嵌音轨。

## 回归

Godot 4.7.2 隐藏无头、隔离 APPDATA。`hollywood_campaign.tscn -- --retail-ai` 13/13、主线 94/94；`time_shift.tscn -- --raid-orders` 23/23、`--media` 50/50；`head_games.tscn -- --orders` 17/17、`--media` 42/42；`cg_collection.tscn -- --three-campaign-assets` 26/26。计 265 项，最终这些日志无 stderr。日志 `%TEMP%/IT-three-ai-media-e6d2ec3e11a94306a469928094bdcb1e` 的 `h-final`、`h-main-b`、`s1-ai-b`、`s1-media-b`、`s7-ai-b`、`s7-media-b`、`cg-assets`。另一个既有通用收藏测试 25 断言通过但报一次 MetaProgress 写档告警，不计入干净通过。夹具推进工时/计时及摆位。未做四队剩余路径自然到场交火、媒体逐句耳听、完整新开局自然通关、冷读或打包，不改玩家档。
