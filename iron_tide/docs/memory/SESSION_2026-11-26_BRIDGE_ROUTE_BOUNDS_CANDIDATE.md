# 桥梁局部路径版本记录候选

续 `SESSION_2026-11-26_ROUTE_EPOCH_BRIDGE_ATTRIBUTION.md`，已读取 `BRIDGE_PORTING.md`、`YR_SLOPE_PORTING.md`。本轮只改隔离候选，无生产改动、无提交打包；生产 bridge_damage/path_service 有其它工作修改，未覆盖。

准备器 `.validation/prepare_bridge_route_bounds.py`，A/B 目录 `.validation/bridge-route-bounds-20261126/`。B 在 `BridgeDamage.restore` 合并旧新 native bridge_flags 与断段矩形对称差，按一格+2px扩边；只有原生图、无时空遮罩且恰好推进一个 epoch，现有 `route_matches_outside` 对范围外五种网格、外围通行形状、网格配置比对通过才登记局部变化。旗标与断段列表的变化都纳入范围。其它情况（含非原生、没有区域、证明失败）保留原回退；仍完整重建通行网格，没改实际移动/桥层。额外快照复制与范围外证明有成本，不能假定121次全可省。

独立真实 Godot 场景 `B/light-source/bridge_bounds_probe.tscn` 在原生 `yr_crctbrd` 六段上43/43、exit0、无stderr：崩塌与修复各生成范围，穿过影响区域的合成旧线路拒绝保留，远处合成路线保留；崩塌地面格不可通，维修恢复。既有 `tests/bridge_sections_regression.tscn` 在同候选隔离配置344/344、exit0、无stderr，覆盖原生横竖段与非原生图、断桥两侧、快照恢复与修复。后者是快照回环而不是冷读档。本候选没有跑实际桥上桥下车辆路径和多事件同帧叠加；前一轮实车冷读是不同版本，不用于代替本轮。

性能 A/B 前置检查两次检测到外部 IronTideRuntime PID88560 与 Godot PID82932，未启动采样、未关闭任何进程。待外部游戏自然退出后运行同一准备器 A/B runner，30秒3×存档1、先同探针比较 `_repath_now` 调用、恢复证明（包含范围构造和重建）、旧路校验和实际模拟推进，再做无插桩交错复测和桥层实车，不以行为测试通过直接合入。B 行为夹具添加了隔离 user dir 设置，runner 会重写相应字段；正式比较应重新冻结并核对源码哈希与配置规范化差异。
