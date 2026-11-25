# 模拟底层重构

用户2026-11-20决定按网页RA2类架构重构底层。保留当前卡池/养成、战斗规则、表现层和玩家存档；不能以降单位数、降低模拟速度、关闭AI换性能。

## 已落地：实体生命周期边界

scripts/world/simulation_world.gd独立维护实体登记、组件调用序列和唯一空间索引。battle.simulation拥有登记表；battle.neighborhood保留为同一索引的兼容入口。Unit/Building进入、退出、移动事件经simulation注册/移除/重定位。既有查询顺序、索引格子和回退不变。

组件调度定义：登记顺序稳定；步内detach/remove立即影响后续调用；步内attach下一步开始调用；禁止嵌套step。新调度尚未自动驱动战斗：现有Unit physics和Building process仍执行，不重复调用。这一步是可测试的迁移边界，不宣称性能提升。

独立实现，不复制参考源码。refs/ts-ra2/LICENSE明确Chrono Divide派生部分未获开源许可；只参考架构行为。参考GameObject.ts中cachedTraits.tick、RenderableManager.ts中生命周期事件、OctreeContainer.ts中位置/相机变更维护；Yuri复原库存在stub，不把简化Update当作完整引擎。

## 后续接管顺序

1. 从实体登记层划分模拟组件与表现组件，建立每个组件输入、输出、依赖顺序及添加/卸载事件清单。动态换卡、心控、运输、英雄形态、buff到期必须即时生效。
2. 以一个独立子系统切换到simulation.step，并同步关闭它原有回调；保持全体单位原模拟步与顺序。先影子输出对照，再真实接管，禁止新旧同时执行。
3. 拆分单位移动、攻击、状态更新；将生产/经济/建筑武器移到明确的模拟步；动画与UI仅由渲染时钟驱动。现有混在_process的生产和攻击迁移需要时间边界回归，不能直接更名回调。
4. 统一命令队列和格子占用/空间查询。删除各系统私自全量重建的索引前，证明目标候选顺序、范围和失效条件。
5. 以slot2/slot3真实输入做Release图形ABBA；核验模拟秒、兵力、生产、AI公平性、均值/P95/P99及超预算比例。预先排除外部游戏干扰，不停用户游戏。没有干净测量不宣称收益。

## 第一阶段验证

.validation/simulation-phase1-20261120隔离工程、自定义存档目录。simulation_world_regression7，unit_neighborhood121，building_membership1202，savegame140，slot2真实读档1774，slot3真实读档1627，共4871项，0失败，全部exit0且无SCRIPT ERROR/ERROR。

slot2 371单位218建筑，slot3 334单位206建筑；核对每个实体登记、索引、类型、移位更新、退出/重新加入。测试未修改玩家存档。

限制：组件调度接口仅夹具验证，尚未接管玩法；未做本轮Release性能验收/新包；不是完成整套重构。
