# 单位延迟任务重复登记与当前热点

续 `SESSION_2026-11-26_YR_BLOCKAGE_INTEGRATION.md`。用户要求单位重复任务优化、跑一版并找热点子函数。正式修改 `scripts/world/ai_unit_dispatch.gd`：只对未获准、已经等待的相同任务减少等值写入，同步 `path_tick` 同物理步不再重写、跨步续期不变，scan 只写一次，派单 pending 标记不重复写；operations/recover 相同标记、board 同一目标不覆写。队列先前就按 actor+kind 合并，本轮没有把原来的一次执行再说成减少执行；没有改已获准即时任务、玩家显式队列、`interaction` 的结构负载、`micro` 时间负载、不同目标覆盖与顺序。等值检查本身也有成本，本轮未做开关对照，不能宣称加速。未提交打包。

新增 `tests/pending_task_merge_regression.gd/.tscn`，隔离用户目录实际 Godot headless 26/26，stderr空。夹具强制预算全满，验证同一单位各类任务只占一个槽、换目标替换、micro 继续使用最新负载、path 跨步续期，授予一种任务不误删另一种。未覆盖完整 AI 指令链或入队任务存读档，本轮未做真实性能 A/B 或全局重复写次数。

当前版诊断准备器 `.validation/prepare_pending_task_hotspots.py`；证据 `.validation/pending-task-hotspots-20261126/run-1/`。正式 Release 图形私有桌面，存档1 yr_isleland、3×、1600×900 30秒，推进93.325s；41点，87帧取最慢5帧，8/9物理补步；外部进程审计通过、源无漂移、无脚本错误、栈/边闭合。探针账务28.331ms/慢帧，非正式P95、不同父子值不可叠加、单轮不宣称相对旧版本收益。

`Unit._physics_process` 409.405 incl/138.528 self残差 ms/慢帧，最大已测子调用 `_process_combat` 88.763（self20.639）→`_move_toward` 29.490、`_move_water_safe` 22.855、`_tick_path_stuck` 7.123、`_weapon_domain_valid` 6.883。`_move_toward`→`LocalTraffic.apply` 14.746（全调用路径）；另 `tick_congestion` 18.331。`ensure_candidates`→重建9.080、复用校验6.688（跨入口）。`_refresh_target` 54.023（self28.719）→域验证10.423、墙体清障7.716、AI扫描准入3.666、候选搜集2.872。`progression_expansion.tick` 43.671（self23.393）→第二阶段10.656、属性重算7.862；属性重算不要重复历史判退的简单跨入口跳过。`projectile._explode` 32.137含、单位receive_hit全入口23.039含。迷雾23.280含。AI dispatch 入口 `allow` 4.989/997.8次、`allow_scan`3.666/1008.6次、`pump`7.073/1次、`defer_job`0.191/47次，`_admit`和`_begin`为部分重叠子调用。优先继续拆 `_move_water_safe` 下真实碰撞/例外及 `allow` 拒绝排队剩余成本；已有扫掠窄查询与九格擦除判退，不重复。若认定新增等值检查应长期保留，补同源 A/B 或成对微基准含比较与写成本。
