# 存档UI、影子调度、日志审计

用户要求先修2个存档UI回归，再用影子调度对照15Hz顺序，覆盖暂停/死亡/心控/运输，并检查大日志能否停写。

日志：APPDATA/Godot/app_userdata/Iron Tide RTS/performance_calls历史603文件141606324字节（135MiB），最大4.12MB。普通logs5文件1582字节。battle_call_log.setup已默认只有IRON_TIDE_CALL_LOG=1才启动，否则closed且无writer/base_path；进程和用户环境变量查无主动开启。未删除历史日志，未动用户游戏。launch_game.ps1启动游戏前显式env:IRON_TIDE_CALL_LOG='0'，防继承壳环境；PowerShell parser0错误。自动存档每60秒是存档非日志，保留。

UI：SLOTS新增auto后5个槽，tests/savegame_regression.gd仍硬编码4导致两模式断言失败。改核对SLOTS.size及has_all，新增auto.save.disabled；142/142通过exit0，无SCRIPT ERROR/ERROR，含子进程cold-save16检查。不改变实际5槽UI。

影子：新增tests/simulation_shadow_regression.gd/.tscn。只在隔离副本Unit._physics_process首行注入get_meta shadow observer record，不二次执行任何模拟逻辑。每步由priority-2000000 observer收集实际SceneTree预期Unit顺序；priority2000000核验实际列表（有序完全相等=无多无漏），delta与15Hz；涵盖normal/paused/resumed/mind_control(实际AlliedAbilities.change_side)/transported/unloaded(set_stowed)/death_sequence(_dead与_dying夹具，非完整死亡信号)/disabled/enabled。最终233检查41步0失败exit0日志无错误，delta仅0.06666666666667。覆盖原Node路径，不是新集中调度的等价证明，不是P95。

证据.validation/shadow-ui-20261120/{savegame_regression,simulation_shadow_regression}/result.json、log；冻结project包含观察注入。默认日志测试验证call_log.closed/base_path空/writer null/counters.owner0，文件扫描无performance_calls。

隔离限制：当前并行远征campaign/runtime preload field_operations循环导致首测虽142检查0失败但SCRIPT ERROR，首测拒绝。仅测试副本把两处preload改load，并显式campaign4处推断类型，生产远征代码未动。最终通过依赖此兼容修正，不宣称整个当前生产源码无错误。影子早期失败均夹具：预热60Hz转15Hz、scene继承ALWAYS导致暂停仍跑、死亡free未从world.units移除。已修：1s预热后固定15Hz、screen PAUSABLE/observer ALWAYS、退出从列表erase；保留最终报告明确范围。

未打包，未做P95；底层迁移仍仅phase1，phase2未接管。本轮可合入代码仅测试修正、新影子夹具、正常启动强制关闭性能日志。全局记忆已满，项目文档交接。
