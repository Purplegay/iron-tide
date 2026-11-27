# 性能重新按函数耗时排序（2026-11-26）

用户纠偏：先用时间定位真正热点，再优化逻辑；访问数/扫描量用于解释工作，不等于收益。本轮没有生产代码、玩家存档、打包变更。证据 `.validation/hotspot-time-first-20261126/`；准备器 `.validation/prepare_hotspot_time_first.py`、`prepare_hotspot_ai_leaf.py`、`prepare_hotspot_base_leaf.py`、`prepare_placement_structure_scan.py`（最后一个首次探针需把 `rr` 声明改为 `var rr: float = ...`；实际成功副本已修）。

`natural1/2` 同冻结源码、同兼容 checkpoint（307单位/179建筑/5AI）、同 meta，Release 4.7.2 私有图形1600×900、3×、30秒，451/449物理步，256/250帧，推93.235/92.785模拟秒，退出0、无脚本错误或源码漂移、外部引擎未检出。34点诊断开销约2.08ms/步；以下按实际物理步归一、父子包含不相加，不视为正式 P95：

| 函数 | 两场 ms/步 |
|---|---:|
| Unit._physics_process | 35.267 / 35.285 |
| Unit._process_combat | 9.281 / 9.104 |
| Fog._process | 7.520 / 7.128 |
| Fog.rebuild | 6.458 / 6.226 |
| HouseAI._process | 4.155 / 4.051 |
| Unit._move_toward | 3.668 / 3.697 |
| Unit._refresh_target | 3.232 / 3.146 |
| Unit._weapon_domain_valid | 2.024 / 1.933 |
| Fog._hold_vacated_scouts | 1.028 / 1.056 |
| BattleNeighborhood.traffic_contact_buckets | 0.093 / 0.099 |

AI 下钻 `ai1`：`run_decisions` 3.841、`_manage_base` 2.324、`train_army` 0.675ms/步。第二级 `base1`：`_manage_base` 2.098、`building_site` 0.756（含 `expansion_site_ok` 0.459）、`train_army` 0.648、`place_ready_construction` 0.617（含 `building_site` 0.322）。两诊断外部进程需复核，只用于归因，不当独立同源收益对照。

选址隔离候选：`build_spot_ok` 的建筑碰撞阶段取原结构桶代替混合桶，保留格/桶相对顺序和全员回退。首次影子 `placement1` 因探针类型推断失败无效；`placement2` 2124 次有序建筑对拍零差异，输入85,000→50,471（−40.62%），不是最终合法性输出的逐候选影子。去双跑后的 `time-A/B` 业务仅一处选桶不同，450/449步、相同存档、exit0无日志错无运行源漂移。`build_spot_ok` 0.573→0.467ms/步，但调用2,966→2,425，约86.9→86.5μs/次；两场均有外引擎、其它主机CPU约42.86%→31.90%，也非相同轨迹。**没有证实时间改善，不合入**；无需重复用相同混桶剪枝作主候选。

后续优先回到更大且两场稳定的战斗链 `_process_combat/_refresh_target → _weapon_domain_valid`，拆规则、武器解析和覆盖检查，再用原覆盖语义验证上游能消掉哪些重复工作；AI 仅在找到可以减少完整合法性判断或训练决策的前提下续作。不要恢复「以访问数代替时间」或重复微型桶/掩码候选。不降低模拟步、刷新或决策频率来达成预算。`summary.json`、`ai-summary.json`、`base-summary.json`、`placement-summary.json` 保存各口径。
