# 原生地形网格快路径：全图矩阵与桥梁回归

续 `SESSION_2026-11-26_BRIDGE_BOUNDS_MERGE_NATIVE_GRID.md`。本轮仅隔离验证，不改生产、不提交打包。准备器 `.validation/prepare_native_stamp_matrix.py`（复用上一轮快路径函数），证据 `.validation/native-stamp-matrix-20261126/`，matrix.json、独立进程日志、sections/result.json。正式 bridge_damage 已保有上轮合入的局部历史，path_service 未合入快路径。

Godot 4.7.2 headless 实际项目，37张原生地图（Native.IDS 34张＋三个战役地图）对比完整对齐地图；有桥格映射的地图另比较所有桥覆盖同时注入。58种状态，54走快路径、4走原分支；明确验证40px非对齐、对齐但超出原图边界、苏一时空遮罩、非原生四种回退，另覆盖裁剪后的对齐网格及显式0/1/2/4覆盖旗标。逐项比较 cost/crusher/water/amphibious/_blocked/_water_mask/passages.terrain 共7张数组、10,529,820个对应元素，0差异、0回退错误，exit0无stderr。测试遮罩是在新 service 初始化时设定，未声称改动或验证运行时任意切换遮罩的缓存行为。

快路径默认开启的隔离候选又跑 `tests/bridge_sections_regression.tscn` 344/344（原生横竖段、非原生回退、断桥快照恢复、修复与爆炸传播），以及好莱坞隔离用户目录 `--write-bridge-move-queue` 8/8、全新进程 `--cold-bridge-move-queue` 6/6。实车上桥执行后才执行排队下桥，只有一次并停在街道；全 exit0无stderr。实车冷读未边走边炸桥，断桥读回属于另一组快照回环，未验证密集编队或时空遮罩转换实景。未访问、改写玩家槽。

上一轮固定 12 次断修 ABBA 已量得逐格139–148→23–25ms、重建161–177→43–46ms；本轮仅扩正确性验证，未复测性能或正式存档全帧。候选已达到本轮网格与现有桥语义正确性门槛，待命合入时不要带探针条件/静态测试字段；合入后应选固定断修事件做完整图形与无插桩对照，局部收益不得说成 P95 已改善。
