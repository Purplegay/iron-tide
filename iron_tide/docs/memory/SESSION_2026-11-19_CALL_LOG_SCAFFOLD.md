# SESSION 2026-11-19 · 第20轮：关闭常开诊断脚手架（已合入生产）

## 结论先行

本轮**改动了生产代码**（前 19 轮基本零改动），并**判定合入**：

- `iron_tide/scripts/world/battle_call_log.gd`：`setup()` 从「`IRON_TIDE_CALL_LOG=="0"` 才关闭」改为「**仅 `=="1"` 才开启**」，默认关闭。
- `tools/performance_soak.py`：`env.setdefault('IRON_TIDE_CALL_LOG','1')`，探针仍显式开启诊断；调用方显式设置的环境变量优先，因此同一份源码可做 A/B。

收益**真实但小**：逻辑帧 −2.56%，整帧 mean −5.9%、p95 −3.8%。**远不足以把 p95 从 ~71 ms 拉进 33.33 ms**，不要把它当成阶段目标达成的证据。额外收益：每场对局不再向玩家 `user://performance_calls/` 写 JSONL。

## 为什么这是 bug 级的发现

`battle_screen.gd` 无条件 `add_child(call_log)` 并 `setup(battle)`。旧逻辑下只有显式 `IRON_TIDE_CALL_LOG=0` 才关闭，而没人会设 → **每一场正式对局都在跑性能探针**：

- `Counters.start(session)` 执行 → `battle_call_counters.enter()` 逐物理步 2199 次/step、`iterations()` 573 次/step。
- 按 `unitwork-base` 折算 `call_counters` self = 1.975 ms/step（在 instrumented 口径下占 3.25%）。
- 每帧 `bridge_traffic.sample` 采样最多 16 个 actor；该文件自注 `## Diagnostics only. ... never issue orders.` ⇒ 关闭不改游戏行为。
- 每场整局 JSONL 落盘到玩家档案。

## 验收方法与数据

同一份 work 源码，显式 `$env:IRON_TIDE_CALL_LOG` 控制，跑 **两轮 A-B-B-A 共 8 场**（A=开、B=关），每场 60 s 墙钟、1600x900 真实图形、简化隔离桌面、897±1 物理步：

| 指标 | A（诊断开，4 场） | B（关，4 场） | delta |
|---|---|---|---|
| logic ms/step | 30.43 (sd 0.23) | 29.65 (sd 0.12) | **−2.56%，分离** |
| logic ms/simS | 429.96 (sd 3.33) | 419.30 (sd 1.81) | −2.48%，分离 |
| frame mean | 47.48 (sd 1.02) | 44.68 (sd 0.55) | **−5.91%，分离** |
| frame p95 | 71.93 (sd 1.51) | 69.21 (sd 0.70) | −3.79%，区间重叠 |
| proc ms/simS | 248.30 (sd 2.33) | 251.09 (sd 1.18) | +1.13%，重叠 |

- 8 场全部 `SCRIPT ERROR=0`、`ERROR=0`。
- A 组每场产出 1 个 `performance_calls/*.jsonl`，B 组 **0 个** ⇒ 开关确实生效。
- `proc ms/simS` 反向 +1.13% 属**预期**：帧率升高导致 process 回调次数增多（第 19 轮被否的同一反馈环）。故判据取 `logic ms/step` 与帧 mean，不用 proc/wall_s。

## 口径教训（重要，写下来避免再踩）

1. **先跑空对照再宣称收益**。本轮第一次四场 ABBA 因 `env['IRON_TIDE_CALL_LOG']='1'` 硬编码，两臂实际都开着 → 成了空对照，但正好测出**同配置四场自然波动**：`logic ms/step` ±2.3%、`proc ms/simS` ±3.5%。据此把第二轮的 −2.56% 判为「刚好超出噪声、靠 sd 小与两臂分离支撑」，而不是「大幅收益」。
2. `setdefault` vs `[]=` 的语义差别直接决定实验是否有效。
3. 探针跑场默认开启诊断是**正确的**：`verify-work` 单场确认调用日志仍产出含 `bridge_traffic` 的 JSONL，诊断能力无损失。

## 已否决的下一轮候选（量级不够，勿重做）

- 把 893 处 `, {})` 默认参数换成共享 const：微基准 `dict.get(missing,{})` 163.4 ns vs 共享 110.5 ns，省 ~53 ns。每步 350 次 ≈ **0.02 ms/step**。
- `GameData.get_skill` 默认分支、`expansion_2_*.tick` 的 `{}` 守卫：同量级。
- 微基准（Godot 4.7.2 headless 本机）：`Dictionary.has` 89.2 ns、缓存 StringName 62.3、静态调用 88.8、`RefCounted.new(Array)+free` **1012 ns**、空字面量 `{}` 79.4、`Array.size()` 23.0。

## 下一轮建议靶点（按性价比）

1. **`allied_abilities.tick_actor`：12069 ns/call × 345 次/step = 1.147 ms/step（real）** — 单次成本异常高，先拆内部（疑似字典重建/遍历），不要先谈上提。
2. **入口段上提**（`BattleRequest.extensions_enabled` 872/step、`friendly` 717、`is_ai_house` 672、`AlliedAbilities.alive` 1736、`frozen` 651）合计 ~1.5 ms/step real。需先证明「同物理步内输入不变」。
3. `movement_combat` 仍是最大 phase（11.72 ms/step real）——单点节流/空间分区优先于函数级微调。

**铁律不变**：唯一进 33 ms 的杠杆是 physics 每步 31.1 → ~14 ms（−55%）。本轮 −0.78 ms/step 只覆盖其中 6%。若继续单点优化而无结构变化，需向用户说明 P95 阶段目标不可达，让其裁决放宽负载/阈值或改验收口径。

## 产物

- 跑场：`.validation/perf-16ms-20261119/runs/{fcl,fcl2}-{A1,B1,B2,A2}`、`soak-fcl*.txt`、`soak-verify-work.txt`。
- 空对照（测量噪声地板）：`runs/ship-{A1,B1,B2,A2}`。
- 台账：`C:\Users\admin\IronTide\tools\PERFORMANCE.md` 末条 2026-11-19 第20轮。
- 临时脚本：`C:\Users\admin\AppData\Local\Temp\chatbox-sandbox\a737fbd5-.../abba_fcl.ps1`、`abba_fcl2.ps1`、`abba_ship.ps1`。
- 生产改动未提交：`git status` 显示 `M iron_tide/scripts/world/battle_call_log.gd`、`M tools/performance_soak.py`、`M tools/PERFORMANCE.md`。其余 300+ 行未提交改动为他人/历史遗留，**不要误提交或覆盖**。
