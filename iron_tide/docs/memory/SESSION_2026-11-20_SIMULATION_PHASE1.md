# 网页RA2类底层重构：第一阶段
用户明确说直接重构成网页RA2那种底层，已开始实施不是仅方案。生产改simulation_world.gd（新增无class_name独立实体/组件注册表、稳定步调度）、battle.gd增加simulation并让neighborhood同一实例别名；unit.gd/building.gd生命周期register/relocate/remove改走simulation。没有覆盖并行修改。组件调度step尚未接管战斗，原玩法回调仍运行，无双重更新；不能宣称FPS收益/完整重构。

测试新增simulation_world_regression.gd/.tscn、simulation_saved_regression.gd/.tscn。隔离工程.validation/simulation-phase1-20261120/project，自定义APPDATA/profile，源码复制，共享assets/.godot junction。7组件测试+121邻域+1202建筑membership+140存档回归+slot2真实1774+slot3真实1627=4871，零失败，全部exit0无SCRIPT ERROR/ERROR。slot2 371单位218建筑，slot3 334单位206建筑。真实存档只读复制不写回。阶段尚无Release性能测量/新包。

参考许可证重要发现：refs/ts-ra2/LICENSE声明Chrono Divide派生代码未获开源许可。只架构分析，独立实现，不复制代码；此前把仓库称作开源不准确。Yuri复原库很多stub不能当完整运行逻辑。架构参照GameObject.cachedTraits.tick、RenderableManager生命周期维护空间索引/呈现、RenderableContainer队列。路线docs/SIMULATION_REBUILD.md。

下一步必须继续实际接管组件，不能把注册表壳当完成：审计一个组件生命周期/动态状态/消费者与顺序，再从原回调切换到sim.step，影子对照及真实行为回归，所有单位时间/顺序不变。后续分模拟与渲染、命令队列/格子占用，再slot2/3干净Release ABBA。持续用户授权，无需再询问开始重构。第一阶段本轮收尾，整任务未完成。
