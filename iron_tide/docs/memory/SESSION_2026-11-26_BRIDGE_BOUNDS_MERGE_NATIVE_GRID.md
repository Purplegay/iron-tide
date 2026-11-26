# 桥梁范围记录合入与原生网格重建专项

续 `SESSION_2026-11-26_BRIDGE_ROUTE_BOUNDS_FOLLOWUP.md`。用户批准将局部桥梁路径版本合入；主工作区仅在 `scripts/world/bridge_damage.gd` 合入既有候选 `_route_change_bounds` + `restore` 局部范围记录，保留此前并行的 `hit/collapse_units` 修改。仍须原生图、无遮罩、单 epoch、范围外通行数组与形状一致才记局部历史，不修改安全回退。主源码复制到隔离项目跑原生6段含双段更新 46/46，exit0、stderr空 (`.validation/bridge-cost-split-20261126/merged.log/.err`)。未提交、打包，未修改玩家存档。

下一步固定断修6段各一次，9点成本拆分（准备器 `.validation/prepare_bridge_cost_split.py`，原始 `.validation/bridge-cost-split-20261126/out.log`）：12次桥 `restore` inclusive 213.396ms、其中重建172.229ms；`_fill_cost`146.682包含 `_stamp_water`145.283，建筑盖格9.457、水域派生14.130；快照复制0.451、范围外对账2.708、变化范围0.126。父子不可相加；优先 `_stamp_water`，不取消范围证明。

独立候选 `.validation/prepare_native_stamp_candidate.py`：原生图、55px对齐、无遮罩、网格在原图内时，每次重建只取一次原图 packed flags；桥格覆写用掩码副本，之后以行列索引顺序填原有4数组，不逐格重新调用 native_flags / 做 Vector2 到格换算。不更改正式 PathService，旧分支处理非原生/非55/时空遮罩/尺寸异常。固定相同12次断修 A1/B1/B2/A2 共4个 Godot headless 进程，各43/43、stderr空、各阶段7数组哈希完全一致，12条远处合成路径全部保留。`_stamp_water`累计148.445/24.617/22.830/138.678ms，`rebuild_terrain`177.067/45.721/42.730/161.157ms，夹具桥更新总220.809/72.957/68.625/190.148ms。每场同一张原生 Circuit Board，不是发布版本整帧；不宣称P95，未验证其它地图/回退分支实际调用、全场A/B、密集车队，亦未扩大桥通行规则。隔离项目测试复核时已用正式源覆盖两个脚本；复做快路径按准备器重建新诊断目录，原始 ABBA 日志保留。

后续门槛：逐原生地图比较旧/新7数组、旗标包含0与水域、遮罩/不同格宽/边界回退；加断修实车与存档；再考虑推广该快路径并做固定桥事件全图形 A/B，不能用桥尖峰内的时间下降外推出常态帧率。
