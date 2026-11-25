# IronTide v0.5.8–v0.5.9 功能交接记忆

用户于2026-10-29明确要求“写之前功能的记忆”。将以下事实补入IronTide主题；不要写入KFramework业务系统记忆。此次只保存记忆，未重跑历史回归、未修改游戏代码。

## 工作区与权威
- 实际仓库 `C:\Users\admin\IronTide`，Godot工程 `iron_tide/`；聊天cwd可能仍是KFramework。此次重新读取确认版本0.5.9、分支 `codex/ra2-independent`。共享工作区有大量其它修改，不能回退/清理；这些批次没有提交、推送或打包。
- 运行入口 `C:\Users\admin\IronTide\iron_tide\启动游戏.bat`；`launch_game.ps1 -PrepareOnly`仅准备资源并校验启动，不打开玩家游戏。Godot4.7.2。
- 长期交接以仓库 `docs/SKIRMISH_AI.md`、`docs/YR_DEATH_AND_SURVIVORS_AUDIT.md`、`docs/VERIFICATION.md`、`docs/CHANGELOG.md`为细节入口。后续先核实代码/版本，不能将历史测试数字当作新修改的验收。

## v0.5.8：YR死亡、建筑逃生、碎片与废墟
- `ra2pipe/death_assets.mjs`从本机正版YR导入36组媒体和 `data/ra2/death.json`。553类型是规则查询范围，不是新增553个可造单位。DBRIS10LG/DBRIS10SM原引用资源未找到，保留missing，不用其它素材冒充。
- `scripts/buildings/building_crew.gd`接建筑 `_die/retire_sold`；按Crewed/NoCrew、阵营售价除数、占领惩罚、建造场工程师等条件生成逃生人员。普通受伤、未完工、超时空抹除不会新生crew；原驻军疏散独立。16候选出口检查碰撞/水域，堵住不强行叠人。
- `ra2pipe/death_cpu_audit.py`对本机gamemd.exe核验18条字节；原程序SHA256 `3e81a61775d2745d1dabe397325ef663cd994ffc194da4e998e3bf5d2d308600`。Crewed缺省false；+0x540是C4AppliedBy，不能误作出售标志；废弃SurvivorRate=.4和载具CrewEscape不能套成所有建筑的逃生概率。社区逆向仓并非完整官方源码。
- Unit普通死亡从首帧完整播放Die1/Die2，清碰撞并到期释放；按InfDeath接特殊死亡。`yr_death_fx.gd`播放原Explosion及建筑DebrisAnim，有限碎片生命周期、暂停/迷雾处理。火焰只选一个方向接倒地段，电击保留循环；时钟和连续弹道属于Godot适配。
- `building_rubble.gd`为支持LeaveRubble的民居留下原最终帧，当前是无碰撞、不可选的持久画面，带见过状态的迷雾记忆。逃生兵、占领标识、随机状态、废墟支持存档；瞬时爆炸和未播完尸体不持久化。
- 逃生专用CTECH/E2/INIT经GameData私有fallback解析，不加入生产unit_index；未来正式单位目录优先。新存档校验death_rules，旧档无该字段仍可接受。
- 历史验收：731项回归、18项原程序核对和启动准备通过；yr_death_regression100项。最终画面仍 `pending_user_visual_confirmation`。
- 未完成：车辆体素碎块、驾驶员/飞行员逃生、DeathWeapon/碎片溅射、病毒/变异连锁、原版出口格数组、完整废墟占地/重建和燃烧奔跑轨迹；不能称整个YR死亡系统完整复刻。

## v0.5.9：盟军遭遇战AI部署与经济
- `scripts/world/skirmish_ai.gd`调用新增 `skirmish_micro.gd`、`skirmish_economy.gd`，只控制敌方盟军；保留既有海空、间谍、运输、维修、超武策略和虫群独立收入。
- E1/GGI每0.5游戏秒按可见目标、真实普通/精英/部署武器的装甲效率、射程和最小射程决定姿态；GGI对装甲/空中用导弹，近距/步兵适合时用步枪。接敌结束2秒后起身恢复原移动/攻击移动/守卫任务，集结不覆盖部署接敌。调用真实set_deployed与开火，不给伤害/视野加成。
- `Unit.set_deployed(want, notify_player=true)`新增可选参数；AI传false避免刷玩家情报，敌方部署声音只在玩家可见时播放；原玩家调用缺省行为保留。
- 简单维持2矿车；普通/困难尝试最多2/3矿场、4/6矿车（每矿场通常2辆）。有战车厂、至少2辆实际矿车及资金后才扩矿；只向已探索矿石附近、当前可见且合法的建造区域扩建，避开可见敌军。尚无派MCV远征开矿。
- 活矿车、所有生产队列、矿场待赠矿车共同计数；先补矿车再买军备，未排上矿车订单时保留补车资金。闲置敌方矿车恢复自动采矿，保留活动卸货/离场流程及玩家自动采矿开关。
- 救急不是常驻收入：普通/困难无活矿车、有可用矿场和生产者、有已探索矿石、资金不足持续45游戏秒后，仅补缺口；整局上限1/2辆CMIN价格，当前1400/2800，简单为0。待赠矿车不触发，部分付款只补余款；仍需正常生产付款出厂。
- 单位 `special.ai_deploy_mission`保存原任务；微操/经济节拍、救急计时、已用额度在已有 `allied_state`，暂停/结束不推进，旧档缺省兼容，读档不刷新额度。经济检查每秒一次。
- 历史验收：11套866项、0断言失败，最终日志无SCRIPT ERROR/ERROR，PrepareOnly Ready。新专项 `skirmish_strength_regression`112项；MCV开局77项覆盖2400/3200/4000实际采矿交款。部署/导航部分用 `--fixed-fps 60`，不伪称全是实时时钟。
- 隔离验证根 `C:\Users\admin\Temp\iron-sidebar-20261028`；独立custom_user_dir，无DB/端口/服务，未操作玩家存档。正式入口 `iron_tide/tests/run-navigation-building.ps1 -Suite skirmish_strength_regression -RunRoot <新隔离目录>`。7个相关源文件SHA复核一致，详见VERIFICATION结果表。
- 测试注意：军备配比测试需先满足两辆矿车经济底线；MCV初始建筑统计排除中立民居；导航测试退出要停止音频并清stream。不要删除这些断言掩盖新策略或退出问题。共享RA3 extras的bone变量仅补int恢复编译，未改其玩法。
- 微操节拍、经济上限、选址评分和补助均为IronTide独立策略；不是完整YR AI脚本解释器。未做长局胜率平衡或得到用户实际对战体验确认。
