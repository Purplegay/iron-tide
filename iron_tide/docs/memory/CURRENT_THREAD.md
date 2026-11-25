# 本次聊天补充：2026-11-19

## 性能第20轮（最新）：只沉淀，不再改代码

用户表态「不改，写入记忆到主干，让它吸收一下」。本节点只做记忆沉淀：未改代码、未提交、未跑新场次。

结论：第20轮关闭了发售构建中一直默认开启的性能诊断脚手架（`battle_call_log.gd` 改为仅 `IRON_TIDE_CALL_LOG=="1"` 才开启；`tools/performance_soak.py` 用 `env.setdefault` 让探针仍开，显式 env 优先）。8场A-B-B-A判定合入：logic ms/step 30.43→29.65（−2.56%，分离）、frame mean 47.48→44.68（−5.91%，分离）、p95 −3.79%（重叠）。收益真实但小，约 physics −0.78 ms/step，仅覆盖 31.1→14 ms 所需的约6%；P95 阶段目标仍远未达成。

口径铁律：先跑空对照测噪声地板（同配置四场 logic/step 波动 ±2.3%、proc ms/simS ±3.5%），再判收益；判据只用 `logic ms/step` 与帧 `mean`，`proc ms/simS`／`proc/wall_s` 与帧率耦合，不得用于 physics 侧判定。

详情见[性能主题页](PERFORMANCE.md)与[本轮交接](SESSION_2026-11-19_CALL_LOG_SCAFFOLD.md)；原始台账在仓库 `tools/PERFORMANCE.md` 末条。

## 60 FPS

用户明确目标为稳定60 FPS、约16.67ms整帧预算，并要求记忆四项优化方向，见[PERFORMANCE](PERFORMANCE.md)。本页原整理阶段仅记录、不启动持续优化；后续用户已明确授权开展第一轮及Second.tick子调用、平均帧/P95测试，实际结果与今天本对话后续修复见[11月19日Chatbox交接](SESSION_2026-11-19_CHATBOX.md)。

与Yuri比较需区分游戏逻辑速度、实际出帧和显示包装器FPS。本聊天没有同机同负载原版Yuri性能对测，不给出已证实的倍数差距。

## 闪电风暴

用户要求“闪电风暴那就加强额外强化”。按已告知范围实施：扩展模式AI闪电获得核弹已有的七档难度倍率1／1.2／1.6／2／2.6／3.4／4，友敌AI分别按本局等级；玩家科技规则继续沿用。

scripts/rules/superweapon_damage.gd的通用multiplier读取已有ai_nuke_levels，核弹入口复用。闪电发射和伤害入口原来已调用通用multiplier，接入AI分支后生效。复用既有存储字段，不另建存档状态。发射伤害冻结，占领／移除发射建筑及读档不重乘。

七档单位／建筑扣血、玩家科技、核弹／辐射、冷读档、风暴暂停／断电／销毁／结束等580项通过：287＋16＋265＋12。无可见窗口，1944个运行相关文件与冻结副本一致；版本v0.30.48.5，未打包、提交、推送，实战强度待确认。

此次迁入重新核对汇总中的3个修改源码哈希匹配。见[证据副本](evidence/ai-storm-damage-20261119-summary.json)。完整运行在仓库.validation/ai-storm-damage-20261119；本次整理未重跑580项。

## 远征 60/60 胜利结算重试修复

用户反馈远征任务显示 60/60 但没有胜利，截图显示基地资产仍在；先前将原因归于基地资产检查是误判，已恢复原检查规则。真正修复：`finish()` 原本先设置 `state.outcome`，再调用 `world.end_battle()`；若 `Expedition.settle()` 因存档/提交暂时失败，world 不会 ended，但 outcome 已锁定，后续任务 tick 直接返回，导致无法重试。现任务 tick 在 outcome 非零而战斗仍活动时会重试 `finish()`；`finish()` 仅在 world 已 ended 时返回，恢复检查点中已有 outcome 也会继续结算。新增 `tests/expedition_settlement_retry_regression.gd/.tscn`，隔离运行7/7通过：初次失败可重试、重试成功、已结束不重复结算、完成检查点能恢复、失败结果及基地存活检查保持。未打包、提交。
