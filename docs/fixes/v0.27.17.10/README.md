# v0.27.17.10 · 桥面移动中断

## 复现与根因

用户反馈桥上经常卡住、单位无法前进。在 Islands on the Land 长桥与 Circuit Board 短桥的混编通行测试中，捕获真实移动链路错误：

`Left operand of 'is' is a previously freed instance`，位于 `Unit._slide_across_bridge_layers`。

桥上每次移动需要排除桥下船只的碰撞。候选列表可能保留已销毁对象，原代码先执行 `other is Unit`，随后才通过 `actor_alive` 检查有效性。Godot 在前一个类型判断就报错，后面的 `move_and_slide()` 未执行，重复到下一帧，造成有通路但不移动。错误日志持续写入也增加额外负担。

本次在类型判断前增加 `is_instance_valid(other)`。小规模的全单位列表与大规模空间邻域查询均经过同一个保护。正常同层碰撞、桥下船只临时排除、移动速度和寻路规则不变。

## 后台验证

全部使用 Godot 4.7.2 headless、CREATE_NO_WINDOW、独立用户目录；未打开游戏窗口，未改写玩家存档。固定模拟步长用于功能验证，不作为实际帧率测试。

- 新增 `bridge_stale_actor_regression`：分别向全单位列表和空间邻域快照放入失效引用，覆盖经典／扩展模式。旧实现 16 项中 4 项移动失败，修正后 16 项全部通过；同时验证活友军碰撞、桥面地形和临时碰撞例外不泄漏。
- 新增 `bridge_crowd_regression`：长桥、短桥各做 60 名步兵双向通行及 60 个步兵／坦克／战斗要塞混编双向通行，四组均全部到达对岸。该新增混编矩阵使用经典模式，扩展模式另由以下既有测试覆盖。
- `native_bridge_traffic_regression`：30 项通过，覆盖桥面往返、岸边恢复、低桥挡船和读档纠偏。
- `bridge_queue_regression`：208 项通过，覆盖经典／扩展、玩家／AI、15／60 Hz，24 辆坦克双向通过桥上 3 辆停放车辆。

总计 258 项检查通过。仅修复已复现的桥面移动中断，不宣称所有地图的任意拥堵都已消除，也不宣称大型对局帧率问题全部解决。

可在隔离工程中设置 `IRON_TIDE_REPORT_DIR` 后运行：`Godot --headless --fixed-fps 60 --path <project> res://tests/bridge_stale_actor_regression.tscn`；其他三个场景替换文件名即可。必须使用隔离用户目录。原始证据在 `C:/Users/admin/Temp/iron-bridge-20261108`，精简断言与源指纹见 `verification.json`。

旧档无需迁移。未打包、未提交推送；旧试玩包不会自动更新。
