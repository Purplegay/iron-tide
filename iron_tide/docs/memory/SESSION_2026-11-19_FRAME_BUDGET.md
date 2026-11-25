# 第 17 轮：真实候选测试（B1 已证否）+ process 段绝对耗时闭环 · 2026-11-19

用户指示「大胆做几轮测试，先跑进 33ms」。本轮**真的跑了候选和完整 ABBA**，结论是否定的，但拿到了两个此前缺失的决定性数据。

生产 `iron_tide/` **零改动**。`work/` 已恢复到 `base/` 一致（仅 `project.godot` 的隔离目录名不同）。

## 1. 本轮完成的实测

### 1.1 process 段绝对耗时闭环（此前 8 个根回调份额只覆盖 1.5 ms，缺口 14 ms）

在 `base` 的干净副本里给 8 个 process/draw owner 加 `Time.get_ticks_usec()` 首尾戳，跑 30 s 真实图形场（`probe-cb3`，208 建筑 / 334 单位）。归一化到探针 20 s 窗口内的 142 帧：

| owner | ms/frame | us/call | 份额 |
|---|---|---|---|
| `building._process` | **6.171** | 29.67 | **40.6%** |
| `fog_of_war._process` | **4.563** | 4554.63 | **30.0%** |
| `house_ai._process` | **2.477** | 3162.60 | **16.3%** |
| `minimap._draw` | 1.098 | 3457.09 | 7.2% |
| `hud._process` | 0.458 | 854.41 | 3.0% |
| `building_damage_fire._process` | 0.245 | 1.18 | 1.6% |
| `building_repair_indicator._process` | 0.159 | 0.76 | 1.0% |
| `ra2_fx._process` | 0.039 | 0.75 | 0.3% |
| **合计** | **15.210** | | |

**`previous_process_ms` 实测 14.69 → 缺口 −0.52 ms，在误差内。process 的 15 ms 至此完全分解。**

关键口径纠正：上一轮用 `unitwork`/`frameprofile` 份额推算 8 个根回调合计约 1.5 ms 是**错的**——那些份额来自另外两个 instrumented run，与本场 process 段不可换算。必须用绝对戳。

### 1.2 运行时节点普查（首次）

`battle` 子树里 `is_processing()` 的节点实例数：

- `building.gd` **208**、`building_damage_fire.gd` **208**、`building_repair_indicator.gd` **208**
- `ra2_fx.gd` 56、空脚本 21、`projectile_tail.gd` 10、`native_ore_drill.gd` 10、`siege_rotor_animation.gd` 9、`night_hunter_clock.gd` 7、`house_ai.gd` 5、`yr_death_fx.gd` 3 …
- 另有 `resource_node.gd` 1006 个实例（无 `_process`）、`unit_selection_outline.gd` 70 个

⇒ 每帧约 **520 次** `_process` 调用，其中 416 次是建筑的 2 个纯视觉子节点。

## 2. 候选 B1：`fog_of_war` transient 迭代去掉每帧数组分配

改法：`for child in host.get_children()` → `for index in host.get_child_count(): host.get_child(index)`，两个根都改。**同节点、同顺序、同调用**，只省掉每帧两个 `Array` 分配。`base` 里 L146/L148 已用 `child_entered_tree` 钩子（含 `_filter_transient.call_deferred`）覆盖新生成对象，所以不存在漏过滤。

**ABBA 四场（60 s，真实图形，`IronTideRuntime.exe` SHA `d34d36f3…` 与基线一致）**

| run | frames | steps | mean | p50 | p95 | p99 | proc | logic | other |
|---|---|---|---|---|---|---|---|---|---|
| fogidx-A1 | 1118 | 894 | 53.22 | 56.51 | 75.64 | 87.40 | 14.00 | 24.90 | 14.32 |
| fogidx-B1 | 1207 | 890 | 49.10 | 53.57 | 73.43 | 89.11 | 12.97 | 22.69 | 13.44 |
| fogidx-B2 | 1252 | 892 | 47.45 | 52.62 | 71.41 | 79.09 | 12.86 | 21.41 | 13.18 |
| fogidx-A2 | 1189 | 891 | 49.99 | 54.66 | 73.92 | 85.95 | 12.86 | 23.32 | 13.80 |

表面看 A→B 均值 −6.46%、P95 −3.15%。**但这是假象**，用不随帧数变化的量一验就穿：

| run | process ms / 墙钟秒 |
|---|---|
| A1 | 260.89 |
| B1 | 260.83 |
| B2 | 268.26 |
| A2 | 254.86 |

**A 组和 B 组完全重叠（254.9–268.3 覆盖两组各自的上下限）。** 总逻辑步数两臂都是 890–894（60 s 墙钟预算固定），所以「B 帧数多 8%」只意味着每帧步数更少，不是工作量减少。

⇒ **B1 无收益，不合入生产。** 原因也清楚：每帧 2 次 `Array` 分配在 29.67 us/次的 `building._process` 面前微不足道，而 `fog_of_war._process` 的 4554 us 几乎全在 `rebuild()` 的 550 actor 遍历里，不在迭代方式上。

## 3. 决定性的结构性结论（本轮最重要）

用实测参数（physics 每步 31.1 ms；process 13.4 ms/帧；other 14.1 ms/帧，`A=proc+other=27.5`，`B=logic+份额≈45`）做自洽模拟：

| A | B | mean | p95 | |
|---|---|---|---|---|
| 27.5 | 45.0 | 85.8 | 137.2 | 今日（该拟合偏悲观） |
| **2.0** | **45.0** | 6.3 | **46.1** | **把 process/other 全部删掉（不可能）** |
| 27.5 | 31.1 | 52.3 | 76.0 | physics/步 31.1，process 不动 |
| 14.0 | 20.0 | 20.3 | 40.0 | physics/步 20（−36%） |
| **14.0** | **14.0** | 18.0 | **32.6** | **physics/步 14（−55%）PASS** |
| 10.0 | 10.0 | 11.9 | 22.0 | physics/步 10（−68%） |

**即使把 process 段的脚本开销全部删到 0（A=2 ms），P95 仍是 46 ms。** 因为 1 步帧 = A+B，占 75–89% 的帧都是 1 步帧，P95 分位点必然落在 1 步帧里。

⇒ **33.33 ms 的唯一杠杆是 physics 每步成本 31.1 → ≈14 ms（−55%），process 侧再怎么削都不够。** 这与上一轮的结论一致，但这次是实测 A/B 参数算出来的，且 B1 用四场真跑证实了「削 process 里的分配类开销无效」。

## 4. physics 侧的真实靶子（份额口径，仅用于排序）

`frameprofile-base`（17 帧，插桩扰动大，只可用份额）：`phase_movement_combat` 683.85 incl/帧（32.3%）、`phase_skills_target` 306.41（14.5%）、`phase_entry` 242.20（11.4%）、`phase_turn_fire` 170.18（8.0%）；`progression_expansion.tick` self 2.407 ms/step（349.6 次/步）、`_recompute_bonuses` 1.656 ms/step（493.3 次/步）。

要 −55% 必须动这些每单位每步的算法，而不是再找 allocation 级浪费。

## 5. 未做 / 下一步

- 未做 `building._process`（40.6%，6.17 ms/帧）的候选：其内部 `queue_redraw()` 有 8 处，其中 `_refresh_power_warning()` 返回 `warning or changed`，低电时**每帧都重绘**驱动「无电」角标呼吸闪烁——这是有意设计，改动会改变视觉，需用户点头，本轮未擅自改。这是 process 侧最大的单点，但即便全砍也只值 ~6 ms。
- 未做 `fog_of_war.rebuild()` 的 550 actor 遍历（4554 us/次）算法化。
- process 尖峰成因仍未采集（需按根回调加时间戳）。
- `work/` 已恢复干净，可随时作为下一轮候选起点。

## 6. 证据

`.validation/perf-16ms-20261119/`：`probe-cb3`（8 owner 绝对戳）、`probe-census`（节点普查）、`runs/fogidx-{A1,B1,B2,A2}`（ABBA 四场）、`probe-*`（若干失败诊断场，见 §3 说明）。失败场：整树普查两次 `add_child` 崩溃（`rp_child` null），已放弃；`--source work` 两次异常退出，第三次单独重跑成功。

生产源码未改，未打包/提交/推送。
