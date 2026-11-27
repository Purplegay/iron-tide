# 三关任务触发逐条建表与结算链首批接入

沿用 `SESSION_2026-11-27_THREE_MISSION_SCRIPT_COUNTS.md` 的 Steam 零售地图与 SHA。`tools/export_three_mission_triggers.mjs` 验 SHA，逐条关联合成 [THREE_MISSION_TRIGGER_COVERAGE.tsv](THREE_MISSION_TRIGGER_COVERAGE.tsv)：302+253+126=681 条；8 条已标为 2 条接线专项验证、6 条部分接线，另外 673 条为已提取待逐条核验，不等于没接，也不代表已完成。AI 表是独立口径，本轮不改 AI 定义。复跑命令：`node tools/export_three_mission_triggers.mjs docs/memory/THREE_MISSION_TRIGGER_COVERAGE.tsv "$env:TEMP/IronTide-S01-retail/sov01.map" "$env:TEMP/it-hollywood-retail/all02umd.map.map" "$env:TEMP/IronTide-S07-retail/sov07.map"`。

- SOV01 `0C47F71C` → `06B600EC`：`time_shift.gd::finish_dominator` 将摧毁最终控制器原先立刻结算补成镜头转航点144、欢呼与5规则秒计时；不继续调度阶段内其它部队。原图禁用目标提示由本项目清标记近似，附带 `08E497AC` 链没有新增执行。未实测空袭自然路径、音景或等待中冷读。
- ALL02 `0CDDECBC` 同时开启 `0CDDC53C` 与 `0CDDC22C`：`hollywood_mission.gd::finish_timeline` 从进入收尾开始，3秒欢呼、10秒胜利，两计时并行；旧档已在 phase 3 保留旧行为。保留既有获救居民的欢呼；原图单独平民房 `088F344C` 未另做。`09635F3C` 的副基地立即 Hunt 与原已有5秒后重复下令接回，启用前置与目标选择仍有适配，未测试逐队真实交火。
- SOV07 `0B0A52BC` → `0E2AB85C/0CD9E15C`：`head_games.gd::objectives` 保留既有 3 秒解放与 12 秒胜利，但新增城堡先毁时两侧剩余信标在解放前确实移除，不留可用信标。未先拆城堡且早已解放的异常旧档不重置。

Godot 4.7.2 隐藏无头、隔离 APPDATA：`res://tests/time_shift.tscn` 54/54，`res://tests/hollywood_campaign.tscn` 102/102，`res://tests/head_games.tscn -- --castle-first` 7/7，stderr 空，日志 `.validation/three-trigger-pass-20261127/`。夹具推进计时和造成伤害，不是自然通关；没有改玩家档、发包或做新等待阶段跨进程冷读。

后续沿 TSV 的原图 ID 补证据、状态和动作，优先既有差异显著的首关阶段失败链、好莱坞片场/平民房、第七关多轮编组和标签互斥。未声称三关全部接完。
