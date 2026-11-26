# 存档 1 常态 P95：移动和碰撞重新采样（2026-11-26）

接 [合并交接](SESSION_2026-11-26_P95_OPTIMIZATION_HANDOFF.md)。本轮只做诊断：没有改生产脚本、桥梁或玩家存档，没有提交、导出，不宣称提速。

## 复测口径与证据

- 证据目录 `.validation/current-movement-p95-20261126/`，`summary.json` 含按物理步归一化的点/边、审计和日志检查。复现准备脚本 `.validation/prepare_current_movement_p95.py`，汇总脚本在证据目录。四场顺序：`baseline-1, baseline-2, diag-1, diag-2`，退出码均为 0，结束正常且日志无 `SCRIPT ERROR`、`Parse Error` 或 `ERROR:`。
- 原存档 1 `yr_isleland`，381 单位、207 建筑、5 AI、保留玩家、无强制桥断修；Godot 4.7.2 Release，私有未激活图形桌面 1600×900、3×、各约 30 墙钟秒。存档与 meta 哈希四场相同。基线使用 `--frame-only`；诊断使用 `--engine-phases` 和 33 个计时点。每对源码指纹一致，运行审计无副本漂移；冻结涵盖 1551 个作者源文件，资源、测试和导入目录共享，不声称资产快照全冻结。跑完主工作区 `campaign_command.gd`、`unit.gd`、`head_games.gd` 相对冻结点已变化；`unit.gd` 的差异是并行战役 `campaign_area_guard` 分支，不来自本轮。下轮重新冻结。
- 开跑前一次进程快照未见外部引擎，但四场正式窗口各六次审计均被标记需复核，发现外部 Godot。没有停止外部进程。两个基线只作**带负载观测**，不与历史混算或作干净验收；诊断帧长不与基线作比较。

| 无插桩样本 | 帧数 | P95 ms | P99 ms | 模拟秒 |
|---|---:|---:|---:|---:|
| baseline-1 | 168 | 271.179 | 302.940 | 93.693 |
| baseline-2 | 148 | 329.008 | 362.129 | 93.467 |

## 调用链复测

表内单位是 **ms / 实际物理步**（诊断 449 / 450 步），父子耗时包含，不相加。计时器无栈错、负自耗或未结作用域；enter/add 内测开销 1.940 / 1.882 ms/步，尚不包括包装分派、额外计时调用及未插桩区。结果只用来排优先级，不把微小时间当可节省量。边表示最近的已插桩调用者，并非都直接调用。

| 入口或分段 | diag-1 | diag-2 |
|---|---:|---:|
| `_process_combat` | 9.422 | 8.893 |
| `_refresh_target`（全入口） | 4.433 | 4.469 |
| `progression_expansion.tick` | 3.736 | 3.866 |
| `_move_water_safe → _slide_across_bridge_layers` | 2.192 | 2.088 |
| `slide → _traffic_collision_exceptions` | 1.196 | 1.145 |
| `slide → native move_and_slide` | 0.555 | 0.532 |
| 碰撞例外 → `test_move` | 0.332 | 0.317 |
| 碰撞例外 → 候选循环（含判定） | 0.309 | 0.318 |
| 碰撞例外 → 邻居查询 | 0.075 | 0.072 |
| `slide → _record_overpass_move` | 0.056 | 0.055 |
| 单位例外 `add_collision_exception_with` + slide 的逐个 remove（不含建筑/无人机入口内部增设及后续引擎成本） | 0.010 | 0.012 |
| `_move_toward → LocalTraffic.apply`（经 `apply_separation`） | 1.586 | 1.468 |
| `apply → ensure_candidates` | 0.877 | 0.820 |
| `apply → 避让候选循环` | 0.347 | 0.310 |
| `ensure_candidates` 全入口 | 1.987 | 1.803 |
| `ensure_candidates → _can_reuse_candidates` | 0.725 | 0.666 |
| `ensure_candidates → _rebuild_candidates` | 0.822 | 0.727 |

`test_move` 执行 42,188 / 38,833 次；碰撞候选遍历 11,379 / 10,817 次（包括少量非 slide 的 `move_and_collide` 链，并有无世界早退，不能把两者直接做精确命中率）。实测添加单位例外 8,226 / 9,633 次、slide 移除 8,182 / 9,637 次。它们不是这条链的主要同步开销；不为此改例外生命周期，也不删预扫、物理移动或桥层记录。

## 下一步只做可归因的候选

1. 优先在同源冻结副本细分 `ensure_candidates`：分别标出 `tick_congestion`、`apply`、`VehicleSteering.open_corridor` 入口，拆区域版本、Watch 同格核验、宽名单重建。`_physics_process → ensure_candidates` 目前记录 38,054 / 35,440 次、1.087 / 0.961 ms/步；它不是已经证明可删除的 `tick_congestion` 独占。`_move_toward → ensure_candidates` 的最近调用边仅 1,145 / 1,117 次、0.017 / 0.016 ms/步；该形态下 `apply → open_corridor` 复用不是主要杠杆，先不做候选。
2. 只在确认重复校验的输入、候选位置/层和调用间副作用不变后，考虑窄范围影子对照。不能用同物理步作唯一条件。专项包括同格进入、跨格、层切换、出生和移除、96 单位阈值、桥上桥下及友军堵路。常态 P95 验收另取无插桩干净同源对照；外部引擎出现的运行只能保留为观察。
3. 桥断修格数尚未量；这是单独目标，不从自然对局的结果推断桥尖峰。
