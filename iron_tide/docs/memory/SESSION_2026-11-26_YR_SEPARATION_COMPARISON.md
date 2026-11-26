# 尤复移动阻塞与 Iron Tide 连续避让对照

本轮按用户要求先核对尤复机制。`../refs/ra2yr-resource` b01d3cf 的 `src/object/foot.hpp:283` 有 `pathDelayTimer`、`blockagePathTimer`。`src/system/cell.hpp:225` 有按桥层选择本格对象的接口及 `firstObject`、`altObject`。`src/object/foot.cpp:1642` 的 `CanEnterCell` 是返回 false 的占位实现。证据覆盖数据结构，零售执行文件的车辆阻塞调用链和逐步查询次数仍待验证。

`../extracted/rules.ini:54`、`:2574` 有 `CloseEnough=2.25`、`PathDelay=.01`、`BlockagePathDelay=60`。注释分别描述受阻时离目的地足够近可结束移动、受阻后重试延迟以分钟计、绕过全部阻塞前的帧延迟。`.01` 分钟等于 0.6 规则秒。工程内本次找到的是 `rules.ini`，数值是否被尤复 `rulesmd.ini` 覆盖尚未核实。

网页版 `../refs/ts-ra2` 898d891 的 `src/game/gameobject/task/move/MoveTask.ts:556` 从当前航点开始遍历路径节点，通过 `findObstacles` 检查节点障碍。步兵会查子格，忙碌对象按条件等待或重规划。允许让路时给阻挡单位添加 `MoveAsideTask`，请求方暂停一步后继续检查，见 `MoveTask.ts:760` 和 `:790`。这些分支是社区实现，`WAIT_TICKS=40` 和 `MAX_PLANNING_TICKS=200` 属于该实现。

Iron Tide `scripts/units/local_traffic.gd:176` 当前在 3× 下每次有效的避让调用都因 0.2 游戏秒步长超过 0.1 秒缓存期而刷新邻居，空间查询候选再进入第二轮几何筛查、推力及让行。拟比较的候选方向是让行与堵塞处理由实际前方路段出现相关阻挡触发，保留实时接触、分层通行与脱困语义。先以同一存档逐步记录刷新原因、前路实际阻挡、新进入名单的候选及其是否改变结果，再决定按格或扫掠范围缩减查询。无源码改动，未新增游戏运行样本。
