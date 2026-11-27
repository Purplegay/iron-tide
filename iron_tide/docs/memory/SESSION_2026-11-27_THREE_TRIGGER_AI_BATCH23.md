# 第 23 批：首次穿越旧机归属与苏一排产一致性

接续第 22 批，仍用 `.validation/three-trigger-ai-19/` 三张零售提取件。逐项扫描原图所有 INI 节中余 10 条及其 Tag 的引用，结果 `.validation/three-trigger-ai-23/trigger-references.jsonl`。找到 `09601D2C` 的间接对象链：`0BDE287C` 启用，`079D7E1C` 在 Triggers 的链接字段指向它；`09519F4C` 指向 `079D7E1C`，附在 `(142,96)` 的 CATIME01 上。`time_shift.gd::advance_crossing` 按原 1 秒将旧机退出玩家控制并记录房15 `Soviet2House`，继续现版时代切换；新 `CATIME02` 仍可控。旧机的中立侧是现版适配，不是独立原房外交。断点夹具验证差一、到点和换场后，未做该动作跨进程冷读。

任务原数 681，本轮 1 条新增部分接线（`09601D2C`），累计 672/681（苏一 300/302、好莱坞 246/253、首脑 126/126）。余 9 条保留未接：`0441BAAC 0C46AB3C 0930C39C 0ACD381C 08E7FB5C 10A9144C 07F39F3C 07F31BAC 07F3122C`。其中 `0C46AB3C` 来自触发链接 `0951918C`，尚未证明能继承 `097DDE6C` 的电厂标签及具体选中对象；`10A9144C` 与普通/困难的 `0EB68F3C` 有链接，但未证明简单分支会对同一建筑完成出售，保留不接。双表不把静态引用当动态可达。

AI 原数 275，本轮新增启用 0，仍 154 进入评估/调度；苏一 120 未纳入、首脑 1 空组。本轮修的是苏一 165 条继承规则使用的共享调度，不新增逐 ID 自然生产证据。`time_shift_global_ai.gd` 主副队使用同一可招募清单与原房预算，不重复使用同一个人或同一笔可用资金；主队满足但副队不够时只建立主队。`battle.gd` 仅 `from_queue` 报告实际排产出厂；回调核对工厂、房、组和产品，取消/丢失产线时过期票据不阻止重新排队。实测使用 fixture 队，不记作零售 AI ID。

证据 `.validation/three-trigger-ai-23/`。Godot 4.7.2 隐藏无头、独立 APPDATA、`--campaign-test-no-autosave`。`tests/time_shift.tscn -- --campaign-test-no-autosave --retail-room-economy` 17、`--cold-room-economy` 3、`--retail-landing-teams` 7、`--retail-first-machine-return` 4，共 31 条通过，四组 exit 0/空 stderr。预算与重复招募、取消后重排、同厂非排产生成、真实出厂及资金冷读有实测；未做自然整关、玩家实机、AI 工厂转属专项或打包，未改玩家存档。不是帧率优化或性能验收。
