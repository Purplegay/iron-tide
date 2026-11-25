# 模拟底层第二阶段暂停
用户要求做完并测P95。尝试把Unit physics迁移到SimulationWorld lane drivers：新增simulation_lane_driver.gd、给Unit注册lane组件、关闭live Node physics并由enemy/ally lanes调用原Unit._simulation_tick。发现风险：单位死亡动画、心控改阵营、运输/部署启停、单体测试直接调用、SceneTree顺序与物理插值耦合，且初始接线存在旧Node回调与新组件双跑风险。未形成可验收候选，已撤回第二阶段，正式工程恢复到.validation/simulation-phase1-20261120/project的第一阶段版本（仍保留simulation_world、battle实体注册/索引及第一阶段tests/docs）。simulation_lane_driver.gd已删除。

第一阶段真实存档检查仍有效：slot2 1774项、slot3 1627项，基础组件/邻域/建筑/save初次总4871项通过。第二阶段恢复后重新跑基础：simulation7、neighborhood121、building1202通过；savegame regression 140项中2失败，均为既有“slot browser pauses battle and exposes all four slots” RA2/iron_tide UI断言，exit1，无脚本解析错误；不是单位迁移引入的已证明回归，但因此不能宣称全回归通过。

没有有效第二阶段P95，不能拿旧slot2基线或有外部游戏干扰的结果冒充重构收益。用户正式游戏/其他Godot测试进程仍存在时不做新整帧验收，不停用户进程。编辑器扫描post rollback exit0，无SCRIPT ERROR/ERROR。后续须先修复/隔离存档槽浏览器既有2失败，再以影子计数对照Unit每15Hz调用顺序、暂停/死亡/心控/运输边界，确认旧新不双跑后才能继续集中驱动；之后才跑slot2/3干净Release ABBA P95/P99。任务未完成、未打包。
