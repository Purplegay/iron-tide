# 验证记录 · 更新至 2026-11-02

## v0.6 · 驱逐舰反潜与水下侦测

本机尤复 expandmd01.mix 的 rulesmd.ini 给出 DEST 的 SensorsSight=8、Spawns=ASW、SpawnsNumber=1、SpawnReloadRate=150、SpawnRegenRate=400。ASW 使用 Ammo=1、NavalTargeting=2、ASWBomb（Damage=50, Range=3, DepthCharge, APSplash）。DLPH 为 8 格、SUB 为 7 格，与基础 RA2 导入表不同。海豚或驱逐舰可给同侧其他舰只提供接触。ASWLauncher 的 Range=-2 用于已明确指定且可探测的目标。实际半径、机动与朝向使用 Godot 的连续世界适配。

双模式专项 60 项，覆盖侦测边界、普通目视与声呐区分、切换武器、伤害、真实返舰补给、丢失与重获接触、击落重建、出击中存读档、旧空机库恢复及原版空甲板和阴影。另有舰载与运输 180、存档 120、船舶航行 124、迷雾规则 492、生产栏 1282，共 2258 项通过。全歼夹具按当前建筑逃生规则准备最终资产状态，大厅预设写入隔离配置，生产清单补回既有起义单位并检查 ASW/SUB 不可排队。

Godot 4.7.2，独立工程与用户目录。报告在 `C:/Users/admin/Temp/iron-sidebar-20261028/`，其中专项为 `asw_regression-1793589757971`。实机渲染截图为 `C:/Users/admin/Pictures/IronTide/v0.6/asw-sortie.png`。空甲板取自本机 DESTWO.VXL/HVA，32 朝向重烘入口为 `ra2pipe/vehicle_surfaces.mjs` 的 `asw-deck` 范围。动画和声音观感等待试玩确认。

## 2026-10-29 · v0.5.13.1 船厂平台与舰船移动

船厂圈来自Building._draw_water_platform无条件叠加在水上建筑SHP下方，与源船坞底座重复；现在只为无原版素材的水上建筑绘制。舰船被Unit._align_drive_velocity排除，移动向量瞬间转向而船头仍受ROT限速，基线中60°／180°命令分别出现约58°／178°滑行。现将海军纳入朝向约束，VehicleSteering按水面／两栖域检查开阔转向，不改速度和ROT。源字段参照本机extracted/rules.ini的DEST／AEGIS／CARRIER／DLPH／LCRF（例如AEGIS ROT=1）；不宣称复刻原EXE船舶运动器。

新增naval_navigation_regression：RA2与扩展模式共124项通过，覆盖五类海军60°／180°掉头、原ROT上限、实际到达与停止、驱逐舰／海豚绕船厂、四向岸边出口、水陆域及实际海豚生产。DLPH在海军目录，前置GAYARD＋GATECH，真实Guard／Walk／FireUp／Die1帧均有不透明像素，完成生产后能游出；未复现海豚资源缺失，不删除其原科技前置。新测试早期误用Ready／stride键，已按实际Guard／per帧表修正；慢速ROT=1舰艇用30秒模拟预算覆盖掉头＋行驶，未改游戏速度来迎合测试。

最终海军124项报告：`C:/Users/admin/Temp/iron-sidebar-20261028/naval_navigation_regression-1793253591258/result.json`；地面转向176项报告：`C:/Users/admin/Temp/iron-sidebar-20261028/vehicle_turn_regression-1793253611429/result.json`。共300项，无脚本错误与退出资源泄漏；测试退出前释放音频流并等待音频线程，修正的是测试清理。环境为Windows／Godot4.7.2、隔离project和独立user目录，服务／DB／端口none，未启动可见游戏或触及玩家存档。未改生产出口逻辑、伤害与存档格式；未推送／打包。船厂圈和移动观感仍为pending_user_visual_confirmation；海豚未显示若发生于特定存档，当前夹具不能替代该场景复现。

## 2026-10-29 · v0.5.13 单位选中轮廓

新增SELECTED浅绿色模型描边，接实际SHP/VXL高清帧与RA3动态纹理，不描阴影／HUD，不改选中和战斗结果。参考官方SDK的OutlineDrawType与RenderScene分流，颜色、线宽和alpha采样属Godot适配。完整说明及报告见[描边交接](UNIT_SELECTION_OUTLINE.md)。

三套headless共1150项通过：新专项46、原选择178、单位素材926；无SCRIPT ERROR/ERROR。旧unit_art的0.7秒回收断言按已实施的完整死亡序列契约更新，同时增加到期前不得截断的断言，死亡实现未改变。没有启动可见窗口；未做GPU截图，表现仍为pending_user_visual_confirmation。Windows/Godot4.7.2、独立用户目录和测试工程、服务/DB/端口none，未触及正式存档。

## 2026-10-29 · v0.5.12.1 对空命中特效高度

根因：通用导弹飞行显示已有目标高度插值，但_explode把原地面target_point直接交给爆炸／闪光／火花／灼痕；Unit伤害数字也直接使用global_position。新增Effects.hit_position用于空中显示坐标，Projectile在伤害前捕获目标高度；末次高度随splinters保存，目标死亡／移除后不回落地面。只变表现落点，逻辑target_point、命中、伤害、范围、飞行速度均保留。空中不留地面灼痕，地面保持原行为；Unit通用瞬发显示同样消费高度并跳过空中灼痕。

air_impact_regression使用真实精英FV的开火入口／实际弹道击中R3HARBINGER、ORCA、JUMPJET和MTNK；修前31项失败6项，明确是三种空中目标的爆炸和数字坐标。最终专项43项覆盖命中高度、伤害仍发生、逻辑坐标未变、下降、致死、不可见弹体、目标移除后存读档、旧存档活目标及瞬发地面灼痕边界。真实Compatibility截图已查看，炮艇机身附近可见爆炸、导弹尾迹及数字；首次截图因测试相机倍率过大目标在顶栏之外，调整测试相机至1倍并重拍，不算视觉通过证据。

稳定源码完整回归：专项40、weapon_trail316、projectile_lifetime168、yr_damage1988、savegame120，共2632项，全部退出0且无脚本错误／资源泄漏，前后源码指纹一致，证据`refs/ra3-expansion/air-impact/final-stable/audit.json`。之后仅补瞬发空中灼痕开关及三个专项断言，43项重跑通过、前后指纹一致，证据`instant-confirm/audit.json`；替换原40项后覆盖合计2635项，未把重复运行累加。最终截图`refs/ra3-expansion/air-impact/instant-confirm/air_impact_regression/R3HARBINGER-impact.png`。

较早final及final-confirm回归遇到共享Unit／模型绘制／AlliedAbilities修改，保留原报告但不作为稳定源码验收。环境是实际IronTide源码／资源、Godot4.7.2、隔离project与用户目录；逻辑headless，专项为不抢焦点离屏Compatibility渲染，服务／DB／协议none。未操作玩家游戏进程或存档；未提交／推送／打包。坐标／生命周期和截图客观检查通过，实际对局视觉仍为pending_user_visual_confirmation。

## 2026-10-29 · v0.5.12 未来坦克Q建筑伤害削弱

按用户授权进行玩法平衡调整，不宣称发现重复结算Bug。对照官方Weapon_EP1.xml的AlliedFutureTankLaserSweepWeapon：沿线25、末端50，两者非步兵30%；现有两束15Hz游标独立且不重放。新增独立IronTide配置将Q对建筑伤害减半；官方导出、其他武器和目标类型不变。

新增ra3_riot_balance_regression 40项，用真实Projectile/Building/CombatMath/receive_hit链比较旧倍率1与新倍率0.5的完整Q，覆盖四种建筑、新兵与英雄、四种时间步、四种单位伤害保持原值、真实快照中途恢复及技能文案。受测目标临时提高当前／最大血量以避免提前死亡截断统计，跨代换算仍读取原data.hp，报告保留原最大血量。盟军基地新兵完整Q182.8125→91.40625，兵营285.9375→142.96875；不是保证每个落点相同伤害。

最终4组624项：平衡40、Q流程32、完整开火链432、存档120；全部退出0、无脚本错误或资源泄漏。结果与前后源码指纹在`refs/ra3-expansion/riot-balance/final/audit.json`及各专项result.json。scripts/data/tests回归前后一致，环境为Godot4.7.2 headless、真实IronTide源码／资源、隔离用户目录；DB、服务、协议none。技能外观未改，文本检查通过；长期对局平衡手感尚无用户确认。不触及玩家进程或存档，未提交／推送／打包。


## 2026-10-29 · v0.5.11 尤复车辆死亡闭环

新增车辆碎块、驾驶员和死亡伤害，源码入口与原规则证据见[死亡对照](YR_DEATH_AND_SURVIVORS_AUDIT.md#v0511-车辆碎块驾驶员和死亡溅射2026-10-29)。新增专项及相关回归全部采用真实Godot脚本消费者，headless执行，不打开游戏窗口。

| suite | 通过 | 外部报告目录（共同前缀 `C:/Users/admin/Temp/iron-sidebar-20261028/`） |
|---|---:|---|
| yr_vehicle_death_regression | 260 | yr_vehicle_death_regression-1793250706411 |
| yr_death_regression | 100 | yr_death_regression-1793250113605 |
| logistics_regression | 180 | logistics_regression-1793250294002 |
| yr_damage_regression | 1988 | yr_damage_regression-1793250317888 |
| savegame_regression | 120 | savegame_regression-1793250149256 |
| ra3_completion_regression | 36 | ra3_completion_regression-1793250819658 |

合计2684项，退出码0、无SCRIPT ERROR/ERROR。`death_cpu_audit.py`27条通过，报告`yr-death-cpu-20261029.json`。新专项首轮暴露条件表达式推导Array[String]后赋普通Array的运行错误，改为明确Array后通过；水域夹具必须同步path_service，读档后按既有暂停规则恢复才推进模拟，扩展姿态加成与原ProneDamage分开断言。未删除原始失败报告。

环境：Windows，Godot4.7.2，独立复制项目`.../project`，每次唯一custom_user_dir；headless、固定60FPS测试推进，不改变玩法15tick数值。服务/端口/DB均none，不写正式存档，不停止玩家进程。原Yuri安装仅只读提取和二进制核对。共享目录存在并行RA3修复，保留v0.5.10.1；本次增至0.5.11，未提交、推送、打包或清理他人缓存。

补充边界：gm_death_cleanup_regression明确要求真实3D渲染，headless前置检查拒绝，报告`gm_death_cleanup_regression-1793250344928`；不计入通过、不改断言，也未为此弹出窗口。RA3逻辑坠毁/伤害由上表completion专项回归。已查看新油箱图集的翻滚帧；没有据此宣称游戏运行画面已验收。残骸、逃生和爆炸观感仍为pending_user_visual_confirmation。本轮不是长局压力或全局胜负/全阵营复刻验收。

## 2026-10-29 · v0.5.11.1 GM飞行与死亡回收

GM静止标志原来同时禁用物理回调并跳过全部更新，炮艇无法盘旋，飞行兵悬浮时钟也停住，读档恢复回调仍被标志拦截。现GM仅限制行为：地面靶静止，空中靶走既有flight的待命运动且不索敌／开火；所有新靶保留引擎回调，死亡保留兼容旧暂停状态的恢复保护。没有改RA3武器、飞行和残骸源参数。

新增gm_air_motion_regression修前11项失败5项，修后全部通过；覆盖真实GM生成、引擎计时盘旋／转向、飞行兵悬浮、不还击、地面静止及真实存读档恢复。最初脚手将void restore当bool的解析错误已修正，不计业务基线。gm_death_cleanup_regression补启用projectiles_root，检查炮艇先自然坠落再启动残骸寿命；真实等待检查三种RA3的碎块渐隐、释放，非手动写age。幻影碎块永久滞留在当前源码未复现，既有5秒后淡出／9秒释放验证通过；不将旧修补重复宣称为新根因。

最终7组340项：GM飞行11、动态靶标21、真实死亡29、GM受损66、RA3完整链36、幻影瞄准57、存档120。全部退出0，无脚本错误／资源泄漏。证据`refs/ra3-expansion/gm-flight/final/audit.json`和各专项result.json；修前失败留于before。早期死亡试跑用帧数上限提前退出、无result.json，不计通过。

环境：Godot4.7.2，真实IronTide源码／资源，隔离project及独立用户目录；逻辑headless，死亡与受损采用不抢焦点的离屏Compatibility渲染；服务、DB、协议均none。回归前后scripts/data/tests指纹一致，回归后再核对无变化。共享工程版本随后升级0.5.11，本次顺延0.5.11.1，保留并行死亡功能。未操作玩家游戏或存档，未提交／推送／打包。生命周期逻辑验证通过，外观仍为pending_user_visual_confirmation。

最终交付审计：`C:/Users/admin/Temp/iron-sidebar-20261028/yr-death-delivery-20261029/delivery-audit.json`，283个实际脚本／数据／死亡素材／专项文件与隔离工程字节一致。最终增量为碎片ExpireAnim避免叠加第二次爆炸画面，以及过滤待删除目标；新专项260项重新通过。另检测到并行ra3_expansion／ra3_riot变动，因此追加重跑最新RA3 completion 36项通过；最后指纹复查无再漂移。整个共享工程仍未宣称全量验收。

## 2026-10-29 · v0.5.10.1 幻影车身瞄准

根因：RA3幻影数据无`ra2=true`，旧`_weapon_uses_hull`错误排除它，`_face`不转车身且`_weapon_aligned`直接返回true。并非仅2°容差偏严。现单独识别RA3固定挂点，并读取普通／英雄官方`AcceptableAimDelta=10d`；RA2炮塔逻辑不变。

`ra3_mirage_aim_regression`先在旧代码复现57项中31项失败，修复后57项通过：真实`_try_fire_ready`及Unit物理帧，背向／侧向／10°边界、主动及自动索敌、15／60／120Hz限速转身、原地转动、背向行进、中途读档、RA2独立炮塔与2°边界。不是直接调用低层`_fire_shot`冒充开火门槛验证。

最终8套headless共1004项通过：瞄准57、持续射击432、SDK时序116、补齐36、幻影46、载具转向176、存档120、GM靶标21。零失败、退出码全0，无SCRIPT ERROR／ERROR／资源泄漏，前后运行脚本／数据／测试指纹未变化。图形专属断言未在headless执行，不计入该数字。

证据 `refs/ra3-expansion/mirage-aim/{before,after,regression}/`，最终`regression/audit.json`包含来源指纹和运行环境。实际工程 `C:\Users\admin\IronTide\iron_tide`，隔离junction项目 `refs/ra3-mirage/integration-test/project`、独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`，Godot4.7.2 headless，服务／网络／数据库／端口均none。未弹图形窗口、未改玩家存档、未启停玩家游戏、未提交／推送／打包。

## 2026-10-29 · v0.5.10 GM动态RA3靶标

`gm_targets_regression` headless运行21项通过，无SCRIPT ERROR／ERROR／泄漏告警。实际GM面板的SpawnTargets按钮信号经单例和Battle hook生成步兵、灰熊、幻影、未来坦克、先锋炮艇；临时注册R3测试单位验证自动纳入，移除注册验证不残留名单；逐个断言敌方、静止、禁自动开火及GM清理。测试临时数据仅在隔离进程内，未修改玩家进度或存档。

证据 `refs/ra3-expansion/gm-targets/{run.log,result.json}`；Godot4.7.2，隔离项目 `refs/ra3-mirage/integration-test/project` 的scripts/data/assets junction指向实际IronTide，独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`。服务、端口、数据库、网络均none；无图形窗口、未启停玩家游戏。改动仅GM名单和按钮文案，不改RA3武器／移动／晋升规则。

## 2026-10-29 · v0.5.9.1 RA3差距补齐

实际源码 `C:\Users\admin\IronTide\iron_tide`，分支 `codex/ra2-independent`。Godot4.7.2、OpenGL Compatibility（RTX5060Ti）、WASAPI；隔离项目 `refs/ra3-mirage/integration-test/project` 通过junction消费实际工程，独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`。网络／服务／端口／数据库均none，未停止玩家游戏、未读写玩家存档、未提交／推送／打包。

- 最终35套、2126项运行检查通过，退出码0，无SCRIPT ERROR／ERROR／资源泄漏；其中新增 `ra3_completion_regression` 42项，包含实际射击、英雄二次散射、独立弹匣、曲线炮弹、15／60／120Hz到达、追踪、坠毁与中途读档、碰撞击退、GM重置、停机／抹除、原媒体和动画过渡。来源契约独立245项通过。
- 完整批次 `refs/ra3-expansion/completion/closure/audit.json` 保留原始一项失败：旧 `ra3_sdk_timing_regression` 将首跳边界外的目标放在首跳目标旁，新增英雄二跳会合法命中它。将该外侧目标移到相反方向，保留原首跳射程断言；整套116项在 `timing-boundary/result.json` 复测通过。并非删除断言或缩减射程。
- 最终汇总 `refs/ra3-expansion/completion/final-audit.json` 链接原始批次和补测。前后指纹确认：该批次只改变上述测试夹具，运行代码／数据／资源未变；补测后重新核对实际字节与记录一致。早期诊断批次遇到共享工作区另一项修改的临时 `audible` 类型解析错误，修正后的完整最终批次无此错误，早期结果不计入通过。
- `new/crash.png` 与 `new/mirage-extra.png` 由真实运行渲染并人工检查。检查中纠正LightSource误画成大光斑，现按照明节点消费；爆炸读档清理和触地不重复伤害有断言。截图不能证明所有SAGE HDR／折射／地形条件下逐像素相同，明确残余边界见 [补齐记录](RA3_COMPLETION.md)。
- 本机实际工程执行 `iron_tide/launch_game.ps1 -PrepareOnly` 成功，新增媒体和脚本导入完成；只准备运行资源，没有重新启动玩家的游戏。

## 2026-10-29 · 开发验证后台运行

用户要求开发弹框不要置顶、打断操作。`tests/run-navigation-building.ps1`保持默认headless；隔离测试副本启动前写入 `display/window/size/no_focus=true`、`always_on_top=false`。仅将窗口放到屏幕外不能阻止激活，依据[Godot ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-display-window-size-no-focus)设置原生禁焦点。正式玩家工程和手动游戏启动行为不变，游戏版本保持0.5.9。

导入及运行子进程统一 `Start-Process -WindowStyle Hidden` 并将stdout/stderr写报告目录。外部复用runner `C:/Users/admin/Temp/iron-display-run.mjs`同步隔离窗口设置，原有`windowsHide:true`保留。后续开发默认无窗口验证，不主动弹出交互游戏；需要实际键盘焦点的验收不能把禁焦点自动运行当作真实输入验收。

PowerShell/Node语法及diff检查通过，提取实际后台启动函数调用Godot `--version`返回0并输出4.7.2，证据 `C:/Users/admin/Temp/iron-background-check-20261029`。额外headless AI112项断言通过，但该次退出出现1项资源未释放告警（`skirmish_strength_regression-1793248993326`），不记为无错误回归；与本次窗口配置检查分开。没有为验证禁焦点再次打开图形窗口。

## 2026-10-29 · v0.5.9 AI部署、扩矿与有限救急

实际源码 `C:\Users\admin\IronTide\iron_tide`，分支 `codex/ra2-independent`；保留共享工作区其它改动。使用Godot4.7.2在 `C:\Users\admin\Temp\iron-sidebar-20261028\project` 隔离副本运行，每次独立 `CodexIronTideValidation/special-UUID` 用户目录，未接触玩家存档。服务／端口／数据库均none，没有启动或停止玩家游戏、没有提交／推送／打包。

| 专项 | 检查通过 | 上述Temp根下结果目录 |
|---|---:|---|
| skirmish_strength_regression | 112 | skirmish_strength_regression-1793248460871 |
| skirmish_tactics_regression | 50 | skirmish_tactics_regression-1793247815542 |
| skirmish_operations_regression | 52 | skirmish_operations_regression-1793247547306 |
| economy_ai_regression | 50 | economy_ai_regression-1793247866709 |
| mcv_opening_regression | 77 | mcv_opening_regression-1793248058257 |
| base_recovery_regression | 99 | base_recovery_regression-1793248162892 |
| savegame_regression（含冷启动） | 120 | savegame_regression-1793248180256 |
| auto_harvest_regression | 62 | auto_harvest_regression-1793248196431 |
| ggi_skill_regression | 114 | ggi_skill_regression-1793248468616 |
| deployed_attack_regression | 22 | deployed_attack_regression-1793248475167 |
| mining_obstruction_regression | 108 | mining_obstruction_regression-1793248612705 |

合计 **866项、0断言失败**；表内最后结果均退出0且无SCRIPT ERROR／ERROR。AI新专项覆盖实际部署伤害、最小射程/对空/反步兵、原任务恢复、敌我隔离、暂停/迷雾、AI正式_process入口、真实扩矿付款/放置、矿场赠车去重、经济资金预留、闲置矿车、补助限额/部分付款/存档恢复。MCV开局在2400／3200／4000真实生成地图完成首车采矿返场入账；不是只检查helper返回值。

最后四类部署/导航专项使用Godot原生 `--fixed-fps 60` 关闭实时同步，固定模拟步长加速测试；MCV完整采矿、基地恢复、经济、普通战术、自动采矿及存档为普通headless运行。命令为外部复用runner `node C:/Users/admin/Temp/iron-display-run.mjs <suite> [--fast]`，仓库正式入口也已登记新专项。新专项首次110项实时运行通过，后补AI消息隔离两项后112项固定步长通过。未把重复重跑计入总数。

修正测试前置：旧经济去重案例明确使用仍为两辆矿车的简单难度；军备配比／付款测试先提供两辆真实矿车，符合新经济优先级；MCV初始断言排除已引入的中立民居，仍要求双方都只有基地车且无己方建筑。导航实时补跑未结束便切换固定步长，首次固定步长108项通过但退出音频资源未清空；在该测试finish显式停止音频、释放stream后重跑无退出告警。早期动态类型推导错误已修正；共享RA3脚本 `ra3_mirage_extras.gd` 的bone局部变量仅补显式int以恢复编译，未调整其玩法。

环境复核：AI三个脚本、Unit、RA3局部编译修正、新专项与盟军源数据共7个文件与隔离工程SHA256一致，记录在新专项目录 `source-closure.json`。`launch_game.ps1 -PrepareOnly` 返回Ready，相关diff检查通过。额外存档字段在已有special/allied_state字典内，旧档缺省兼容；补助已用额度经过真实capture/restore验证。

策略与来源边界见[AI说明](SKIRMISH_AI.md)：本轮是Godot独立策略，邻接矿场扩建而非远征基地车开矿，有限救急而非常驻收入；不宣称原版AI脚本完整移植、长期胜率平衡或实机观感已验收。

## 2026-10-29 · RA3 三单位集中检查（修复条目 v0.5.7.5，当前工程 v0.5.8）

完整来源／消费者／缺口见 [RA3_THREE_UNIT_AUDIT.md](RA3_THREE_UNIT_AUDIT.md)。修复未来坦克漏接的基础回血及三个 RA3 单位的军衔经验文字；官方炮口事件本来共用，不添加不存在的晋升变色或伤害加成。新增生命周期44项、持续开火432项，修正阴影网格误计及前一靶场逃生兵串入下一散射用例的测试隔离问题，原数量／端点断言保留。

最终 `refs/ra3-expansion/three-unit-audit/closure/audit.json`：**34 套、2084 项、0 失败**，所有进程退出0，日志无 SCRIPT ERROR／ERROR／泄漏。包含全部 `ra3_*regression.tscn`，另加 GM伤害、生产暂停、存档和通用晋升。图形测试真实使用 Compatibility，已查看双炮充能、质子炮爆点、英雄军衔等截图。PrepareOnly返回Ready，相关diff检查及Python语法检查通过。统计不包含重复重跑或性能记录。

独立来源证据：`source/contracts.json`245项通过；四个原程序绑定专项共36项；激光原指令算术35组输入／1120项通过，最大绝对误差4.21e-6。这些不与2084项混算，也不证明完整SAGE世界更新或GPU实现。

环境：Godot4.7.2、OpenGL Compatibility、RTX5060Ti、WASAPI；`refs/ra3-mirage/integration-test/project`通过junction消费当前源码，独立用户目录`CodexIronTideValidation/ra3-mirage-20261027`；网络／服务／端口／数据库none。没有停止用户游戏或修改玩家存档。每场景使用独立`IRON_TIDE_REPORT_DIR`，命令为`Godot --path <隔离工程> --rendering-method gl_compatibility --audio-driver WASAPI --scene res://tests/<专项>.tscn`。

环境复核：早期批次存在缺失RA2资源导入、测试串扰及并发存档代码变化，保留失败原文，补导入并重跑全套后采用closure结果。closure期间仅`building_rubble.gd`改变；检查调用门槛为LeaveRubble建筑及已有废墟记录，本轮34套不构造／销毁这些民居，也不包含废墟记录，不在该变化消费范围。其余纳入审计的脚本／shader／数据／RA3媒体／测试前后指纹一致；不是宣称共享工程完全静止。生产工程已更新至另一路功能的v0.5.8，未回退版本。

剩余原版差距已逐项登记，包括幻影英雄第二跳、炮艇独立炮位／抛射曲线／空中坠毁链与物理冲击。上述回归通过仅针对现有实现和已明确的断言，不把缺口写成已完成，也不要求使用者代替自动检查逐个找问题。本轮没有提交、推送或打包。

## 2026-10-29 · v0.5.8 YR死亡、建筑逃生与废墟

实际工程`C:\Users\admin\IronTide\iron_tide`，`codex/ra2-independent`共享脏工作区，保留同期RA3改动。隔离副本`C:\Users\admin\Temp\iron-sidebar-20261028\project`，Godot4.7.2 Compatibility／headless；每次使用独立`CodexIronTideValidation/special-UUID`用户目录。无网络服务、端口或数据库；未操作玩家存档、游戏窗口、远端Git。代码/配置12个关键文件与隔离副本SHA256复核一致（最后微调废墟迷雾记忆后再跑目标专项及启动准备）。

| 回归 | 通过 | 本机结果目录（上述Temp根下） |
|---|---:|---|
| yr_death_regression | 100 | yr_death_regression-1793246820166；覆盖源字段、真实死亡/出售、堵出口、类型/数量、保存校验/恢复及截图 |
| gm_death_cleanup_regression | 29 | gm_death_cleanup_regression-1793245932389 |
| special_mechanics_regression | 162 | special_mechanics_regression-1793245554372 |
| savegame_regression（含独立冷启动子进程） | 120 | savegame_regression-1793246521914 |
| building_actions_regression | 126 | building_actions_regression-1793246007403 |
| base_recovery_regression | 99 | base_recovery_regression-1793246139783 |
| ra3_native_regression | 95 | ra3_native_regression-1793246248262 |

合计731项；另`ra2pipe/death_cpu_audit.py`18条本机原程序字节匹配，`node --check`两个导入/对照脚本通过。`launch_game.ps1 -PrepareOnly`实际启动资源准备返回Ready，未启动玩家游戏。

初次专项失败来自测试脚手：`:=`无法推导动态battle字段类型、水域没同步path_service、恢复后树暂停未复位；已修正脚手且保留断言。新增完整15帧死亡后，GM自然等待由0.8／1.2秒改为1.25／1.6秒，仍验证真实引擎释放及5～9秒RA3残骸淡出。基地恢复脚手移除人工障碍时使用NoCrew，避免把“清除障碍”变成“生成一名随后被脚手冻结的新障碍”，保留真实MCV移动/部署/重建断言。误输入一次不存在的native_regression场景已纠正为ra3_native_regression，缺场景结果不计通过。

源码来源与适配/未完成项见[YR死亡与逃生对照](YR_DEATH_AND_SURVIVORS_AUDIT.md)。渲染截图能看到GI尸体、原爆炸、碎片、逃生兵和原民居废墟；用户目标环境观感及声音仍为`pending_user_visual_confirmation`。

## 2026-10-29 · v0.5.7.4 自然晋升中子球伤害核验（无玩法改动）

针对用户先报伤害暴涨、随后澄清“没事了，但是好像伤害没增加”，新增 `ra3_neutron_natural_rank_regression`。隔离工程 headless 实测 21 项通过，日志无脚本错误。准备经验到晋升边界之前，由真实中子球致死触发 `Unit._die → credit_kill → announce=true`，未使用 GM 或直接授予军衔。固定原版未来坦克靶、排除局外加成、保持接触完整球生命周期：新兵 65.1，老兵／精英／英雄均 81.375（1.25倍）；每球7次点查询＋19次扩张查询。英雄装填2.5秒；晋升前已发射的球保持发射时倍率，下一发继承新军衔，普通加成刷新保留军衔倍率。

来源链：官方 Uprising `ExperienceLevels_EP1.xml → ExperienceLevels.xml → AttributeModifier.xml`，`Unit_Veteran` DAMAGE_MULT=125，`Unit_Elite` HEALTH_MULT=125，`Unit_Heroic` RATE_OF_FIRE=120%、RANGE=125%；`AlliedFutureTankNeutronScramblerNode_Vet`仅替换Draw，没有额外伤害覆盖。未发现该固定场景的自然晋升加成失效，未修改伤害规则或版本。该测试手动推进真实弹体，不是完整对局／自动寻敌射击循环，也不证明用户正在运行的旧进程已加载当前代码。

命令：Godot4.7.2 `--headless --path refs/ra3-mirage/integration-test/project --scene res://tests/ra3_neutron_natural_rank_regression.tscn`，环境变量 `IRON_TIDE_REPORT_DIR=refs/ra3-expansion/natural-rank-damage`（运行时绝对路径）。结果 `result.json` 与 `run.log` 位于该目录；源码为 IronTide junction，隔离用户目录，服务／数据库／网络无依赖。仅新增测试，保留共享目录其它变更。

## 2026-10-29 · v0.5.7.4 残骸分离

真实致死入口复现用户截图：分块存在但水平距离太小，落地立即冻结水平／自转。修补Godot几何尺度换算、地面阻尼及动态捕获，官方COL／源参数／生命周期未修改。边界与新旧数值见[残骸审计](RA3_WRECK_DYNAMICS_AUDIT.md)。

独立新专项`ra3_wreck_scatter_regression`用相同局部种子12345、自然等待2.6秒截图；修前5项有2失败，最终5项全通过，已查看原聚拢／最终分离的实际渲染图。最终随机残骸107、native95、expansion63、GM真实死亡回收29与新专项5，共299项通过。最终证据在`refs/ra3-expansion/wreck-scatter/final*`，保留`before`失败与`after`中间调试，不能把中间版作为交付证据。

环境：Godot4.7.2 Compatibility、RTX5060Ti 610.88；既有`refs/ra3-mirage/integration-test/project`隔离工程通过junction消费当前IronTide源码／资源，独立用户目录，服务／端口／DB none。日志无SCRIPT ERROR／ERROR／leaked；PrepareOnly与回归后源码指纹核对。未停止玩家进程、改玩家存档或提交推送。最终观感待用户确认，`pending_user_visual_confirmation`。

运行：设置独立`IRON_TIDE_REPORT_DIR`后，`Godot_v4.7.2-stable_win64_console.exe --path refs/ra3-mirage/integration-test/project --windowed --resolution 1600x900 --rendering-method gl_compatibility --audio-driver WASAPI --scene res://tests/ra3_wreck_scatter_regression.tscn`。

## 2026-10-29 · v0.5.7.3 未来坦克飞行球／英雄颜色

修补及官方XML／原程序证据见[中子球对照](RA3_NEUTRON_FLIGHT.md)。新增flight→node阶段，在真实炮口起飞；到达前无节点伤害，到达时重置节点时钟。普通／英雄均使用已导入原模型、材质，最高英雄级才消费Vet版本。没有改原装填、伤害倍率及Q规则。

Godot4.7.2 Compatibility、NVIDIA RTX5060Ti 610.88，隔离工程`refs/ra3-mirage/integration-test/project`的scripts/assets/tests junction指向当前IronTide源码，独立用户目录`CodexIronTideValidation/ra3-mirage-20261027`。服务／端口／数据库none。未启动或停止玩家游戏，未改玩家存档。最终PrepareOnly返回Ready。

实际渲染回归 **416项、0失败**：新flight34、neutron_visibility14、rank61、expansion63、future_presentation58、gm_ra3_damage66、savegame120。另有新flight headless23项通过，不重复计入416。所有结果文件均存在且日志无SCRIPT ERROR／ERROR／leaked；专项手动推进真实生产逻辑，截图使用实际渲染器，不等同原引擎实机对照。像素断言确认两色可区分；人工检查普通、英雄飞行球及战场位置截图，最终使用者视觉确认仍待进行。

证据根`refs/ra3-expansion/neutron-flight/`；每套`result.json`、`run.log`，visual目录含飞行四军衔及命中节点截图。`source-fingerprints.json`记录回归后关键源码／资源指纹；`native-audit.json`记录9项原程序绑定检查、官方源文件哈希与继承。此前测试假设瞬间生成节点的fixture改为先推进真实飞行到达，再执行原伤害／保存／表现断言，未删减断言。

复用命令（先创建独立输出目录并设置`IRON_TIDE_REPORT_DIR`）：
`Godot_v4.7.2-stable_win64_console.exe --path refs/ra3-mirage/integration-test/project --windowed --resolution 1600x900 --rendering-method gl_compatibility --audio-driver WASAPI --scene res://tests/ra3_neutron_flight_regression.tscn`。
原生静态检查：`python tools/ra3_mirage/audit_neutron_flight.py --game "<起义Data>/ra3ep1_1.1.game" --output refs/ra3-expansion/neutron-flight/native-audit.json`。

状态：逻辑／保存／渲染客观检查通过；`pending_user_visual_confirmation`。未提交、推送或打包。

## 2026-10-29 · v0.5.7.2 静止靶标死亡回收

根因：`gm_unit_tools.spawn_count` 对静止靶标调用 `set_physics_process(false)`；Unit死亡的Die1动画依赖 `_physics_process` 推进 `_dying` 后queue_free。即使重启物理回调，旧代码最前面的gm_stationary无条件return仍会拦截。修复仅让该标志限制存活行为，并在进入Die1死亡动画时重启回调；存活靶标保持原冻结机制。

新专项 `gm_death_cleanup_regression` 使用实际GM入口生成E1/灰熊/幻影/未来坦克/炮艇，调用真实receive_hit杀死，等待引擎回调回收，另外覆盖静止标志仍存在但回调已启用的读档形态。真实等待约9.6秒检查三种RA3碎块计时推进、5～9秒渐隐、最终节点释放，不直接写age、不手调死亡回调。

修复前29项失败2项：GM步兵尸体、恢复回调的静止步兵尸体均未释放；RA3独立碎块本身正常到期。修复后29项全部通过。其它专项GM伤害66、native95、savegame120，共310项；均退出0且无脚本/资源报错。首次GM专项因隔离副本缺少一份新增音频sample报错，未算通过；对同一隔离项目执行import后完整重跑通过。实际PrepareOnly返回Ready。

证据根 `C:/Users/admin/Temp/iron-sidebar-20261028/`：
- 修复前 `gm_death_cleanup_regression-1793241702225`；修复后 `gm_death_cleanup_regression-1793241737349`。
- `gm_ra3_damage_regression-1793241848468`、`ra3_native_regression-1793241790098`、`savegame_regression-1793241856980`。
- 隔离导入 `import-1793241816945`；此前音频缺失失败输出保留。

环境为Godot4.7.2 Compatibility、当前共享IronTide源码、独立CodexIronTideValidation用户目录、离屏窗口；服务/端口/DB均none。回归后核对Unit、GM生成、残骸、专项源码与隔离副本指纹。保留同期v0.5.7.1修补，未操作玩家游戏进程或存档，未提交/推送/打包。生命周期逻辑回归通过；用户实际观感为 **pending_user_visual_confirmation**。

可复用：`powershell -File iron_tide/tests/run-navigation-building.ps1 -Suite gm_death_cleanup_regression -Render -RunRoot <独立目录>`。

## 2026-10-29 · v0.5.7.1 未来坦克／炮艇确认问题

源与适配边界见[本轮审计](RA3_EXPANSION_FIX_AUDIT.md)。14项专项共678检查通过：expansion_fix 34、riot 32、rank 61、gunship_flight 15、neutron_visibility 13、expansion 63、gunship_weapons 69、future_presentation 58、future_glow 12、gunship_presentation 40、savegame 120、audio_lifecycle 78、gunship_range 17、gm_ra3_damage 66。各最终日志无SCRIPT ERROR/ERROR/泄漏。另有15项起义原程序静态绑定／指令检查通过，不冒充运行原引擎。

证据根`C:/Users/admin/IronTide/refs/ra3-expansion/bug-sweep/`。运行Godot4.7.2、Compatibility/NVIDIA610.88、WASAPI；逻辑专项用headless，其余真实渲染。隔离工程`refs/ra3-mirage/integration-test/project`通过目录联接消费本工作区源码／资源，用户目录CodexIronTideValidation/ra3-mirage-20261027；网络、服务、端口、DB均none。同期v0.5.7光照修改保留，最终14项按共享源码全部重跑；最后11份关键运行文件前后SHA256无变化。PrepareOnly返回Ready，未重启玩家游戏。检查了当前Q与炮艇截图；视觉／听感仍pending_user_visual_confirmation。

初次编译发现新beam变量类型推断错误，已修正；旧炮艇fixture只推进渲染、未推进新模拟炮台，已按真实射界更新前置后重跑，断言未减。GM图形专项误用headless等待frame_post_draw，仅终止本轮命令行精确匹配的测试进程，改用渲染后66项通过。

额外旧audio_regression总套件2004项有34失败，保留result.json/run.log：24项旧尤复覆盖断言、10项旧建筑队列／资金预期。没有修改这份总套件、尤复声音配置或生产规则，也没有把它计入678项通过；新增RA3双层播放与音频退出专项通过。没有提交、推送或打包。

## 2026-10-29 · v0.5.7 RA3模型光照和轮廓阴影

5组渲染专项共329项：lighting28、native95、expansion63、mirage_conditions36、wreck_random107。全部退出0、失败0、无脚本错误，实际启动PrepareOnly返回Ready。源码/原配置/适配范围见[RA3_LIGHTING_AUDIT.md](RA3_LIGHTING_AUDIT.md)。

证据根 `C:/Users/admin/Temp/iron-sidebar-20261028/`（复用既有缓存根，日期以本节为准）：
- `ra3_lighting_regression-1793241440957`：3单位正面/转向模型与阴影、实际战场截图。
- `ra3_native_regression-1793241268838`、`ra3_expansion_regression-1793241275438`。
- `ra3_mirage_conditions_regression-1793241282265`、`ra3_wreck_random_regression-1793241447861`。

首轮暴露独占Viewport.world_3d为null，第二轮确认模型搭建尚未进入场景树，改为显式共享World3D解决空影子；后续暴露未来坦克长影子裁切，捕获范围扩大后原断言完整通过。失败输出保留，未删断言。已查看模型、轮廓、战场图片；最终观感待使用者确认，状态 **pending_user_visual_confirmation**。

环境：Godot4.7.2 Compatibility；本机当前IronTide源码；离屏1600×900原生窗口、测试内SubViewport、独立CodexIronTideValidation用户目录；无服务、端口、数据库。回归后9份运行源码/Shader/规则/测试与隔离副本SHA256一致，4份官方来源指纹匹配。未修改玩家显示设置，未启停玩家游戏、提交、推送或打包。

可复用命令：`powershell -File iron_tide/tests/run-navigation-building.ps1 -Suite ra3_lighting_regression -Render -RunRoot <独立验证目录>`。仅headless会明确失败，不能冒充阴影渲染验收。

## 2026-10-28 · v0.5.6.6 RA3残骸随机抛散

官方源/参数/适配边界见[RA3_WRECK_DYNAMICS_AUDIT.md](RA3_WRECK_DYNAMICS_AUDIT.md)。共263项通过：随机残骸渲染107、原native渲染93、expansion渲染63；日志无脚本错误。实际 `iron_tide/launch_game.ps1 -PrepareOnly` 返回Ready，未启动或关闭玩家游戏。

证据根 `C:/Users/admin/Temp/iron-sidebar-20261028/`：
- `ra3_wreck_random_regression-1793191023264`：三单位两次死亡、0.6秒/3.5秒共12张截图。
- `ra3_native_regression-1793191043918`：真实死亡、去重、RA2/超时空隔离、24个上限、读档清理。
- `ra3_expansion_regression-1793191071874`：未来坦克/炮艇共用模型回归。

固定种子可复现、不同种子逐块不同；零配置禁用对应分量；质量/原骨名映射匹配所有COL表面。首轮测试错误使用不存在的炮艇ID导致脚手失败，改用生产常量Ra3Expansion.HARBINGER后完整重跑，未减测。旧失败目录保留。

环境Godot4.7.2 Compatibility、当前共享IronTide源码、复用隔离项目、每轮独立CodexIronTideValidation用户目录；原生窗口离屏；服务/端口/DB均none。回归后7份消费源码/规则/测试与隔离副本SHA256一致，6份官方输入SHA256匹配。未提交、推送或打包。已检查随机散落截图；最终游戏观感为 **pending_user_visual_confirmation**，不是完整SAGE物理验收。

## 2026-10-28 · v0.5.6.5 幻影受损状态与漏接审计

本轮源、字段、适配及仍未实现项见 [RA3_MIRAGE_CONDITIONS_AUDIT.md](RA3_MIRAGE_CONDITIONS_AUDIT.md)。受损纹理/烟火、伪装抑制、维修恢复、75%移动已接入，未修改共享工作区其它RA3修补。SDK/Uprising差异按原文记录，不静默改写场/英雄光束。用户视觉反馈前状态为pending_user_visual_confirmation。

最终7项专项共645检查：mirage_conditions渲染36、native渲染93、cloak渲染34、savegame离线120、allied_abilities离线200、mirage离线46、sdk_timing离线116。均退出0、无脚本错误；PrepareOnly返回Ready。受损专项包含实际材质和像素差异、旁车隔离、暂停/离屏、存档恢复以及真实移动速度；新粒子图集和原模型截图已检查。没有服务/端口/数据库依赖，Godot4.7.2 Compatibility，测试源码来自当前IronTide共享工作区，隔离用户目录CodexIronTideValidation，原生窗口离屏。

证据根为 C:/Users/admin/Temp/iron-sidebar-20261028/，各运行目录：
- ra3_mirage_conditions_regression-1793190074691
- ra3_native_regression-1793190079830
- ra3_cloak_regression-1793190084966
- savegame_regression-1793190089813
- allied_abilities_regression-1793190105160
- ra3_mirage_regression-1793190272730
- ra3_sdk_timing_regression-1793190278117

回归后8份相关源码/规则/测试与隔离副本SHA256一致，官方输入/4张输出纹理另有conditions.json来源哈希。导入器最初只比较属性漏掉文本差异，现保留节点文本并识别ShieldDraw及英雄ColorEmissive两处版本差异。旧失败记录保留；没有减测、修改玩家存档、提交或推送。

## 2026-10-28 · v0.5.6.4 炮艇冲击波尺寸

定位起义 1.1 ClientRandomVariable 倒序区间行为：`High <= Low` 返回 High，普通／英雄冲击波原 SizeRate `.75 → .1` 不能做倒序随机插值。旧实现专项15项失败8项；修正后新增17项通过，包含原粒子消费、最终径向尺度、两种军衔和未来坦克／炮艇重伤火焰负区间。

本轮5组250项：range17、gunship_weapons69、gunship_presentation40、future_presentation58、gm_ra3_damage66；全退出0、失败0，日志无脚本错误／警告／资源泄漏。主工程headless editor import退出0。原程序静态SHA／指令／4个实际配置案例断言通过，不等于原引擎实机oracle。

证据：[audit.json](../refs/ra3-expansion/shockwave-range/audit.json)、[native-cpu.json](../refs/ra3-expansion/shockwave-range/native-cpu.json)，before／after六组普通／英雄截图、footprints.json和各suite结果。已查看0.5秒前后及1.1秒修改后战斗截图，光圈由大面积扩张收回命中点周围。

环境Godot4.7.2、Compatibility／RTX5060Ti 610.88、WASAPI、1600×900；隔离项目`refs/ra3-mirage/integration-test/project`复用当前源码，user目录`CodexIronTideValidation/ra3-mirage-20261027`，DB／服务／网络none。回归后复核隔离路径与关键源码指纹；未改用户显示设置，未打包或推送。HDR／完整粒子调度仍为适配，视觉状态 **pending_user_visual_confirmation**。

## 2026-10-28 · v0.5.6.3 官方起义军衔／球体时钟

用户确认官方起义为最终规则，Upheaval仅作查漏。三种RA3单位实际命中、军衔血量／射程／射速、被动和英雄回血、炮艇切模式保留弹匣和冷却、真实保存恢复均验收。中子球覆盖第3秒才进入无伤害、60/15/2.5Hz外部时间步、强制攻击地面后低空接触、高空投影重叠不命中、19次原生逻辑展开查询、旧节点保存兼容；Q覆盖15Hz及旧30Hz游标迁移。

10组606项：rank61、neutron14、riot32、gunship_weapons69、gunship_presentation40、expansion63、future_presentation58、mirage83、savegame120、gm_ra3_damage66。全部退出0、失败0，无脚本错误／资源泄漏／警告；主工程editor import退出0。首次Mirage旧专项5项失败来自缺少最高许可前置；只修测试夹具，增加真实T2/T3购买及未升级仍不能生产的断言，重跑83项通过，没有放松产品许可限制。

证据：[audit.json](../refs/ra3-expansion/rank-official/audit.json)、各suite的result.json/run.log及main-import.log；CPU静态断言见同目录neutron-cpu.json。环境Godot4.7.2／Compatibility／WASAPI，隔离项目`refs/ra3-mirage/integration-test/project`，隔离user目录`CodexIronTideValidation/ra3-mirage-20261027`，服务／网络／DB依赖none。运行源码前后SHA一致；仅Mirage测试夹具发生已登记修订，并已独立重跑。

原程序静态证据不是完整引擎运行oracle；首次调度相位、跨引擎碰撞体、BeamSpecialAbility完整调度以及粒子末尾数帧同步仍有边界，详见[完整审计](RA3_UPHEAVAL_FULL_AUDIT.md)。已查看炮艇原模型开火渲染图；炮台及接触视觉状态 **pending_user_visual_confirmation**。未据此宣称所有XML功能已完整复刻。

## 2026-10-28 · v0.5.6.2 炮艇 Upheaval 武器表现

按 [炮艇武器对照](RA3_GUNSHIP_WEAPONS_AUDIT.md) 修正瞄准状态、原版命中粒子／图集、英雄曳光、离屏采样分辨率。范围对照：20个原版命中粒子定义一致；核心与冲击波 W3X 顶点最大误差小于0.000001，没有引入缩小／扩大世界尺寸的自定义参数。CPU扩张、SweepSpeed、HDR／深度仍有明确边界，不能把“XML一致”写成“原版实机完全一致”。

最终7组431项：gunship_weapons69、gunship_presentation40、gunship_flight15、expansion63、future_presentation58、savegame120、gm_ra3_damage66。全退出0、失败0，日志无脚本错误／资源泄漏／警告；主工程editor import退出0。源码／shader／资源／测试指纹在回归期间无变化，网络／数据库／服务依赖均none，实际环境与RA3_GUNSHIP_WEAPONS_AUDIT一致。保留其他线程的v0.5.6.1显示修补。

证据：`refs/ra3-expansion/gunship-weapons-release/audit.json`，各同名suite的result.json、run.log，`main-import.log`；新专项截图`native-bullet-hits.png`、`impact-zoom2.png`已检查。状态 **pending_user_visual_confirmation**，未提交、未打包。


## 2026-10-28 · v0.5.6.1 分辨率切换同步修补

用户反馈切换1080p后画面缩在左下，上/右侧黑块。此前130项检查没有覆盖真实根窗口上的PopupMenu激活过程：界面使用SubViewport测试，原生尺寸检查没有在根窗口绘制设置页。旧实现的根窗口普通连续resize与菜单激活离屏探针未复现同款黑块，因此不能将本次时序修补写成已证实该显卡症状消失。

DisplayPreferences现在延迟处理窗口请求，等PopupMenu激活调用返回；原生模式改变后等待一帧再设尺寸，之后再按DisplayServer实际客户区同步Window.size（画布/输入变换）。递增请求号淘汰过期请求，状态文案显示实际客户区及应用中状态。仍默认窗口，没有修改真实用户配置。对照Godot官方Window实现：https://github.com/godotengine/godot/blob/master/scene/main/window.cpp （接口参考，不作为本机4.7.2二进制根因证明）。

扩展display_settings_regression：真实设置场景挂到根Window，打开实际OptionButton菜单，通过PopupMenu.activate_item_by_event进入激活/关闭链路；连续1080/1440/720/2160/900/1080，验证延迟应用、系统客户区/Window/帧缓冲尺寸一致、四角背景像素、按原生像素位置注入点击命中真实CheckBox，以及同帧多次请求以最后一次为准。测试窗口在frame_pre_draw保持负坐标，不切到全屏、不接管用户鼠标。菜单激活以加速键入口驱动，非桌面鼠标实录。

最终渲染96项、离线69项，共165项通过，退出0且无脚本错误；启动PrepareOnly返回Ready。最终截图已检查，当前测试1080p设置页填满并居中。Godot4.7.2/Compatibility/NVIDIA RTX5060Ti，隔离CodexIronTideValidation用户目录，服务/端口/数据库none；三份修改源码与最终测试副本哈希一致。证据：
- C:/Users/admin/Temp/iron-sidebar-20261028/display_settings_regression-1793184552322/
- C:/Users/admin/Temp/iron-sidebar-20261028/display_settings_regression-1793184559650/

最初脚手的PopupMenu.push_input未进入内部菜单激活，activate_item未暴露给脚本，两类脚手失败均保留且不计通过。仍需用户重启实际游戏后复测原切换顺序：pending_user_visual_confirmation；不得把旧版本的客观通过数量当成表现问题已确认解决。

## 2026-10-28 · v0.5.6 默认窗口启动

按用户“先别设置全屏”改为默认1440p窗口。project.godot初始模式为windowed，DisplayPreferences缺省与非法模式回退false；显示偏好version=2才恢复保存的fullscreen，旧配置保留分辨率但忽略全屏标记，下一次手动设置保存新版。全屏入口/F11仍保留。未修改真实用户存档或显示偏好文件。

display_settings_regression离线69项、离屏渲染37项，以及display_resolution_regression离屏渲染24项通过，共130项，均退出0且无脚本错误。覆盖新用户窗口默认、旧全屏迁移/分辨率保留、新版模式记忆、五档窗口尺寸、两处设置布局与1440p点选/框选/生产入口；实际启动脚本PrepareOnly返回Ready。

- C:/Users/admin/Temp/iron-sidebar-20261028/display_settings_regression-1793183989290/
- C:/Users/admin/Temp/iron-sidebar-20261028/display_settings_regression-1793184002196/
- C:/Users/admin/Temp/iron-sidebar-20261028/display_resolution_regression-1793184009291/

Godot4.7.2/Compatibility，隔离CodexIronTideValidation用户目录，服务/端口/数据库none，原生窗口测试位于屏幕外；相关源码与测试副本结束后核对一致。用户实际窗口大小与操作观感仍为pending_user_visual_confirmation。

## 2026-10-28 · v0.5.5 分辨率选项与记忆

DisplayPreferences 保存独立 user://display_settings.cfg：width/height 为白名单整数，fullscreen 为布尔；缺失文件或非法字段回退1440p／全屏。主菜单与战斗共用 display_controls，提供720p/900p/1080p/1440p/2160p窗口尺寸、全屏／窗口模式及实际输出；原生全屏时禁用窗口尺寸，窗口按当前屏幕工作区等比例缩小并居中，F11保存模式。没有修改养成／对局存档。

最终 display_settings_regression 离线66项、渲染37项，共103项通过。覆盖两处控件同步、五档经真实控件信号保存、独立新偏好实例读取、非法索引不落盘、非法字段回退、三种屏幕工作区适配、双模式720/900布局截图，以及真实Window调用应用五档尺寸。真实窗口验证使用负坐标工作区，保持离屏。记录：
- C:/Users/admin/Temp/iron-sidebar-20261028/display_settings_regression-1793183589092/
- C:/Users/admin/Temp/iron-sidebar-20261028/display_settings_regression-1793183595252/

Godot4.7.2 / Compatibility，独立CodexIronTideValidation用户目录，服务／端口／数据库none；退出0且无脚本错误，实际启动入口PrepareOnly返回Ready。控件最终视觉和用户显示器全屏切换手感仍为 pending_user_visual_confirmation。没有把无画面字段测试计作用户实机全屏验收。

测试脚手发现Godot4.7不会从OS.get_cmdline_args返回已消费的--windowed等引擎参数，且不允许隐藏主窗口；初稿失败记录保留，不计入最终通过。现使用明确的隔离运行合同保留测试窗口设置，并在测试副本设窗口模式、负坐标工作区验证实际resize。普通用户启动仍恢复偏好；命令行需要保留外部窗口控制时，可用用户参数 -- --keep-display。依据：[Godot OS命令行参数文档](https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-get-cmdline-args)。

## 2026-10-28 · v0.5.4 Upheaval 受损补齐与 GM 测试场

9 组 686 项通过，主项目导入无脚本错误。新增 GM/受损专项覆盖真实按钮信号、场景切换、敌我生成、军衔、血量、静止靶标存档、受损贴图／烟火／速度、维修恢复，以及测试场不结算；截图和 alpha 像素断言均已执行。使用既有隔离 Godot 4.7.2 Compatibility 工程与用户目录，显式窗口 1600×900，网络／服务／DB none。源哈希、并行显示设置变动及最终 66 项稳定补验见 [RA3_UPHEAVAL_GM_AUDIT.md](RA3_UPHEAVAL_GM_AUDIT.md)，未以旧的中途失败或无日志检查的退出码作为通过。后续实际表现待用户确认，未提交／推送／打包。


## 2026-10-28 · v0.5.3 默认 1440p

按用户最新选择，默认目标改为 2560×1440；全屏原生输出、HiDPI、1600×900 逻辑布局与 F11 保留。既有 display_resolution_regression 同步到 1440p 并通过24项：双模式实际2560×1440渲染、布局、点选／框选和生产交互。证据 C:/Users/admin/Temp/iron-sidebar-20261028/display_resolution_regression-1793182793291/，Godot4.7.2 / Compatibility / 隔离用户目录，服务／端口／DB none，无脚本错误。实际启动 PrepareOnly 返回 Ready；仅配置和对应说明／测试更新，最终观感仍待用户确认。

## 2026-10-28 · v0.5.2.1 启动脚本解析

用户日志 20261028-180523-5896e7f7-import.log 明确记录 ra3_damage_state.gd 的 key 无法推断类型及 volume 从 Variant 推断警告升为错误。检查时共享工作区已经将两者改为 String/Dictionary，首次 PrepareOnly 成功；工作区继续更新期间再次出现 ra3_expansion_model 无法 preload 受损特效、继而自动加载失败。本轮将该模型的 damage_state 创建改为运行时 load，避免 damage → gunship helper → Battle/Unit → model 的编译期回引，不修改受损阈值、粒子或伤害规则。

新增 damage_startup_regression，真实扩展战斗入口创建 R3FUTURE/R3HARBINGER，检查模型及受损组件、健康初态、重伤发射、非空贴图与修复后的粒子／灯光清理，12 项通过、退出0、日志无 SCRIPT ERROR/ERROR。证据：C:/Users/admin/Temp/iron-sidebar-20261028/damage_startup_regression-1793182690622/。Godot4.7.2 / Compatibility / 离屏渲染，隔离 CodexIronTideValidation 存档，服务／端口／DB none。实际 launch_game.ps1 -PrepareOnly 验证成功。表现不是本次修改目标，未将烟火观感计为已验收。

中间的 GM 综合测试因隔离目录缺少新增导入缓存先失败，导入后曾56项通过；后续同套恢复 preload 的对照及正常版本均出现不相关的 GM cleanup 断言失败，因此不将 GM 综合套件算作本次最终通过，也不将循环加载视为已通过该对照稳定复现。原失败日志保留。新增专项单独验证本次启动与组件加载边界，未删改 GM 原断言。用户报错中的类型错误已有原始导入日志证据；共享工作区其它 RA3 修改原样保留。

## 2026-10-28 · v0.5.2 默认 4K 目标与全屏

默认窗口目标设为 3840×2160，默认 MODE_FULLSCREEN、HiDPI；逻辑布局保持 1600×900、canvas_items，直接按实际输出尺寸绘制画布，不把逻辑尺寸误称为低清 framebuffer。全屏遵守显示器当前模式，不修改系统分辨率、不进行强制 4K 超采样。本机两台屏幕当前查询均为 2560×1440，因此本机默认实际输出为 1440p；4K 模式／显示器可输出 2160p。方案依据 [Godot 多分辨率官方文档](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)。F11 全屏／窗口切换独立于游戏暂停；窗口返回当前屏幕可用区域内，两个设置入口补充提示。

`display_resolution_regression` **24 项通过**：双模式真实 3840×2160 SubViewport 渲染及截图、1600×900 UI 逻辑布局、边界、点选／框选、生产卡片悬停及真实下单。证据 `C:/Users/admin/Temp/iron-sidebar-20261028/display_resolution_regression-1793182206318/`，环境与源码在 environment.json 中说明；测试宿主命令强制窗口化／离屏，未接管用户显示器或改真实存档。Godot4.7.2 / OpenGL Compatibility，退出0、无脚本或资源错误；实际启动入口 PrepareOnly 返回 Ready。服务／端口／数据库 none。F11 全屏切换及用户实际观感仍为 `pending_user_visual_confirmation`，离屏 4K 截图不代表已在用户 4K 显示模式验收。注册 runner 的 Render 也显式窗口化，避免新全屏默认值影响测试宿主。

## 2026-10-28 · v0.5.1 右侧生产情报区

将生产卡片、分类、工厂、维修／出售和单位队列说明收进右栏底部，取消这些控件的悬浮窗口。ProductionTooltip 保留 tooltip_text 供现有状态／解锁逻辑使用，只在绑定侧栏详情后抑制原生 popup；非侧栏的单位说明仍使用旧提示。ProductionInspector 用 WeakRef 持有当前查看控件，分类／工厂重建清理旧引用，内容变更才刷新文字；解锁路线显示期间隐藏详情，避免叠占列表高度。生产、费用、队列、战斗规则未修改。

最终 **7 组 1269 项通过**：新增 production_sidebar 76、production_reason 70、production_hold 72、ready_tab 34、hud_layout 584、factory_tabs 375、unlock_navigation 58。新增专项经真实 Viewport.push_input 覆盖禁用卡片悬停、维修／工厂／队列提示、固定区输入归属、720p/900p 布局、切页清理、就绪状态实时更新、左键下单与右键先暂停再取消；旧布局专项覆盖更多分辨率，截图仅证明渲染／边界，用户观感状态仍为 `pending_user_visual_confirmation`。

首轮 factory_tabs 14 项失败：12 项因测试直接点击滚出列表的队列图标；2 项矿车测试在移除本次详情区的隔离对照中仍失败，旧夹具只推进一帧，没有等原有出厂离场流程。更新测试先滚动并等待皮肤尺寸稳定，再点击真实控件；矿车通过真实物理入口有界等待离场／认领矿场，未删除旧断言、未修改矿车业务。中间调试的失败报告全部保留，不计入最终通过数。

证据：`C:/Users/admin/Temp/iron-sidebar-20261028/delivery-audit.json`，含每组原始报告路径、SHA256、隔离配置和本次 UI／测试文件与实际工程一致性。最终截图位于 `production_sidebar_regression-1793181794899/`。环境为 Godot4.7.2、OpenGL Compatibility、离屏真实 SubViewport；测试使用独立 CodexIronTideValidation 用户目录，服务／端口／DB 均 none。最终实际 `launch_game.ps1 -PrepareOnly` 返回 Ready；共享分支与其它修改保留，未提交、推送或打包。交接入口为 `scripts/ui/production_inspector.gd`、`production_tooltip.gd` 以及 HUD 的绑定和刷新点；已有 runner 已登记新专项。

## 2026-10-28 · v0.5.0.7 弹丸目标失效

用户截图为 `force_fire.gd:87 impact_candidates → projectile._explode → _step_homing` 的 `Left operand of 'is' is a previously freed instance`。实际复现：目标在弹丸抵达前free/queue_free，`is ForceFirePoint`先访问失效引用，范围结算丢失；单体弹的同类分支还会中断尾部queue_free。只在ForceFire.impact_candidates、Projectile._explode和Ra3Mirage.tick_impact三处类型判断前添加is_instance_valid，保留落点、伤害、友伤、冷却和结算去重。

修复前专项128项中32项失败，并出现与截图相同错误；修复后扩展为168项全部通过，覆盖双方/双模式/普通与强制攻击、立即与延后释放、发射者也释放、原版CellSpread/普通AOE/单体/幻影延迟命中、范围伤害与友伤、不转移单体目标、不重复结算及弹丸释放。关联强制攻击161项及独立冷启动8项、盟军能力200项通过，最终共537项；计入日志无SCRIPT ERROR/ERROR，PrepareOnly返回Ready。

强制攻击旧夹具有两个CLEG失败，撤回本轮三个保护的隔离基线也同样失败：所谓空地指令实际可命中前面案例的大模型。将禁用武器检查移至独立空地并增加ForceFirePoint断言，原飞机弹药、部署步兵射程、武器资格断言均保留，未改游戏规则迁就测试。中间曾把后续近程测试共用落点也移远导致四项失败，随后将两个落点分开，失败结果保留且不计入通过。

证据根 `C:/Users/admin/Temp/iron-projectile-20261028/`，计入报告、SHA256及修改源码与隔离副本逐文件一致性见 `delivery-audit.json`。Godot4.7.2，真实战斗场景与Projectile._physics_process，隔离CodexIronTideValidation用户目录；服务/端口/DB均none，不操作真实玩家存档。原有共享修改和并行v0.5.0.6保留，本次补丁递增为v0.5.0.7，未提交、推送或打包。

## 2026-10-28 · v0.5 RA3 两单位与独立许可

7 组回归共 **541 项通过**：扩展专项 53、隐形 34、起义表现 43、原版资源/残骸 93、生产暂停 72、存档 120、晋升 126。Godot 4.7.2 / OpenGL Compatibility / WASAPI，全部退出码 0，日志无脚本错误和资源泄漏；脚本、配置、着色器、RA3 资源与测试源码前后指纹一致。

证据：`refs/ra3-expansion/validation/audit.json`，每组目录含 result.json/run.log，扩展专项含原版模型与特效渲染 PNG。隔离用户目录、源码映射、复现步骤、CPU/表现适配边界和用户待验收项见 [RA3 移植交接](RA3_PORTING.md)。用户画面/声音/手感验收仍为 `pending_user_visual_confirmation`；没有把未复刻的完整粒子、JetAI、动画条件链计为通过。

## 2026-10-28 · v0.4 特殊机制、风暴与 AI

本轮最终计入 **1812项通过**：特殊机制162、AI特殊任务52、风暴253及独立冷启动12、支援建筑236、存档120及独立冷启动16、基地恢复99、盟军能力200、间谍真实进入426、既有AI战术50、运输/航空180、真实渲染采样6。计入运行退出码0、无SCRIPT ERROR/ERROR/WARNING。实际启动入口 `iron_tide/launch_game.ps1 -PrepareOnly` 返回Ready，资源抽取脚本Node语法检查通过。

新专项覆盖双方与两种模式的超时空转移、步兵例外、水陆危险、雷达重置与超武归零；民居满员/损坏撤军、驻军武器真实伤害及引用恢复、工程师实际物理进入修桥、桥在小屋毁坏后存读档、警犬接触扑杀及扑空、寻路边界；风暴慢帧/15/60帧同结果、散云间距、声明避雷针与近邻遮挡、暂停及云截止事件读档不重放。AI检查真实机场扣款生产、满弹出击而不干预玩家飞机、可见目标限制、海军可达性、维修订单、间谍目标、夜鹰实际登机/卸人/返航、海豹C4攻击订单和超武只消耗一次充能。不是完整长局胜率测试，也不代表苏联/尤里AI完成。

证据根 `C:/Users/admin/Temp/iron-special-20261028/`；最终逐项路径和计数见 `delivery-audit.json`，5520个脚本/场景/数据/着色器/测试/资源文件哈希在 `source-audit.json`，最终与隔离副本一致（不把引擎生成的UID/import sidecar列为逻辑源码）。最终批次前后只有测试退出清理 `selection_regression.gd` 变化，相关间谍/盟军能力/运输三组已重跑；比较见 `stability-audit.json`。每组独立CodexIronTideValidation用户目录，Godot4.7.2，逻辑headless、视觉OpenGL；无服务、DB、端口，不读写真实玩家存档。配置除隔离用户目录一致；共享另一项任务已将总体版本推进到v0.5，保留其版本与内容，本轮内容仍登记v0.4。

已查看原始云层、民居、简化桥面、战场变暗与小地图干扰的真实渲染截图，用户观感状态仍是 `pending_user_visual_confirmation`。桥面是独立地面通道，不具备原版高架桥/桥下通航。新机制范围与原版差异见 [SPECIAL_MECHANICS.md](SPECIAL_MECHANICS.md)。未提交、推送或打包。

未计入通过数的早期结果保留：类型推断错误、冻结场景物理夹具缺激活、共享RA3脚本内置material属性重名、隔离副本缺并行新增资源、测试退出音频资源占用。按真实身体入口改进夹具、同步新资源、最小重命名fx_material、测试结束停止音频后复验。双风暴测试原先用固定21秒推断所有随机云都结束，改为固定随机种子并读取真实最后云截止时间验证先后结束，保留伤害与互不取消断言。一次复制过程中源核对遇到EBUSY，等待全部运行完成后重新核对成功，旧结果不计为通过。

## 2026-10-27 · v0.3.12 一秒整车交矿与卸矿通道

最终计入822项断言：一秒交矿/实际四车FIFO/旧计时与内容指纹兼容专项132，经济细节178、超时空经济链218、经济守恒52、完整矿车循环及制造交互106、存档120和独立冷启动16。全部通过，计入运行无SCRIPT ERROR/ERROR/WARNING；PrepareOnly返回Ready，导出器Node语法检查通过。

专项覆盖双方和两种模式，0.99秒无收入、1.00秒一次整车转账、部分货舱也完整等待、混矿/精炼器与双方资金隔离、超大步长不重付、手动中断保货、精确旧4秒配置指纹可加载而额外价格差异拒绝、卸矿进度比例迁移、离场车辆与下一辆FIFO存读档。实际四车物理循环均为倒车1.3秒/卸矿1.0秒，离场1.6至1.87秒，全部完成22.03秒；无重叠。较大下一辆需等待两车半径加6单位间隙，清空通道立即放行。上述耗时是本轮受控场景结果，不是所有地图的固定保证。

证据根 `C:/Users/admin/Temp/iron-miner-unload-20261027-final/`；最终专项 `delivery/miner_unload_regression/`，守恒/完整矿车/存档 `confirmed/`，经济细节/经济链 `regressions/`，清单与哈希在 `delivery-audit.json`。初始runner全源前后一致；后续精确存档兼容、测试夹具更新后重跑对应专项及存档。共享RA3军衔贴图缓存修复已同步至隔离副本后再跑矿车专项；该独立显示修复不计入卸矿验证。最后仅同步新测试的UID sidecar与JSON换行，脚本/解析数据不变；项目配置除隔离用户目录和版本字符串外一致。

每组新建独立CodexIronTideValidation用户目录，Godot 4.7.2，离线，无服务/端口/DB，不读写玩家存档。初轮失败未计入：专项精炼器夹具缺电，补足真实电力后通过；旧harvester制造测试仍读取空Button.text、未换算生产时钟并假设一次取消，改为真实Caption、现行时间换算及先暂停后取消后重跑，保留所有扣费/出口/退款断言；守恒测试结束停止音频，清除退出时异步资源占用。未改游戏制造逻辑来迁就测试。

已查看真实矿场卸矿截图，原卸矿动画仍触发；实机倒车、卸矿与离场观感为 `pending_user_visual_confirmation`。交接见CHRONO_MINER_ECONOMY及BATTLE_SAVES；未提交、推送或打包。

## 2026-10-27 · v0.3.11 盟军遭遇战 AI

本轮最终计入662项断言：新AI指挥专项50、真实经济/生产50、基地车开局77、基地恢复99、原战术目标选择60、存档120及独立冷启动16、双模式隔离87、矿场赠车53、大厅选项记忆48及独立冷启动2。全部通过，计入运行无SCRIPT ERROR/ERROR/WARNING。PrepareOnly返回Ready，目标diff空白检查通过。

新专项在RA2/扩展两种模式调用真实AI/工厂：过滤未解锁候选、可见空军/步兵克制、配兵多样性、已承诺矿车资金、无钱不下军备单、真实付款出兵及集结回调、留守/迟到增援、救援解除固守、已出击命令不覆盖、闲置归队、非战斗资产排除、改变归属与暂停、真正每方迷雾隔离、三档候选池。既有战术专项实际生成弹丸并击杀所选残血目标；基地车开局专项在三种地图尺寸运行首辆矿车真实采矿回款。没有改战斗伤害、矿车卸货、迷雾或存档schema。

证据根 `C:/Users/admin/Temp/iron-ai-tactics-20261027-final/`；AI/基地恢复/目标选择/存档使用 `regressions/`，经济/开局/双模式/赠车/大厅使用 `confirmed/`；总清单及源快照核对在 `delivery-audit.json`。最终脚本/资源/场景/数据/测试逐文件与隔离快照一致；项目配置仅用户目录和并行任务将0.3.11提升至0.3.11.1的版本字符串不同，剔除这两项后配置一致。每组独立CodexIronTideValidation用户目录，固定隔离项目，Godot 4.7.2；无服务/端口/DB，不读写玩家存档。测试驱动为冻结真实场景上的直接逻辑调用，不是用户鼠标操作或完整长局胜率测试。

早期失败均保留，未计入最终通过数：v1类型推断编译失败；v2测试夹具重复登记心控单位且取错被转移对象；排查中修正AI移动前解除固守。关联首轮旧夹具仍假定BattleRequest负责大厅恢复、矿场不赠首车、未换算当前生产时钟，另经济测试未停止音频即退出。按现行已确认规则更新夹具，保留扣费/半进度/低电/预算断言并加上赠车和大厅独立专项复验；没有为了通过而改变游戏规则或删掉失败断言。

本轮为独立Godot策略改进，参考aimd.ini与非官方逆向类型声明，来源和剩余边界见 [SKIRMISH_AI](SKIRMISH_AI.md)。实战强度尚未由使用者确认；未提交/推送/打包。共享工作区的后续RA3表现修复及版本后缀保留，不将其当成本轮AI验证内容。

## 2026-10-27 · v0.3.10 治疗加号

治疗显示专项50项、真实维修厂进出场与扣费54项、攻击冷却标识82项、盟军能力200项通过，共386项。专项在RA2/扩展双模式触发实际Unit.heal与矿车以外通用载具维修，验证无效/满血治疗不提示、未选中仍显示、暂停/淡出、隐藏/载运/迷雾外不泄露、维修缺钱无提示、原收费量和连续维修刷新。0.5/1/2/4倍相机缩放的实际绿色像素与CD间距断言通过；已检查真实OpenGL截图，状态仍为 `pending_user_visual_confirmation`。

证据：`C:/Users/admin/Temp/iron-healing-indicator-20261027-final/`，专项`reports/`，三组关联`regressions/`，环境及源快照核对见`delivery-audit.json`。Godot 4.7.2，固定隔离项目、每组独立CodexIronTideValidation用户目录，无服务/端口/DB；没有读写玩家存档。PrepareOnly返回Ready，目标diff空白检查通过，计入运行无SCRIPT ERROR/ERROR/WARNING。修改限于表现metadata及维修厂复用原等价回血入口，不改变回血公式、扣款或存档schema；按实际调用路径运行维修厂/盟军能力回归。

首轮v1的50项断言通过，但运行时另一任务修改`tests/ra3_presentation_regression.gd`，runner据全源审计拒绝。未忽略审计：在final全新隔离快照和用户目录重新通过，v1失败保留。交接见ALLIED_ABILITIES的v0.3.10段；未提交、推送、打包或归档，未将截图标记为使用者已确认。

## 2026-10-27 · v0.3.9.2 生产出生点与受阻偏移

最终出兵专项208项、建筑出厂/动画86项、机场停机104项、批量与集结42项、矿场赠车53项、存档120项及独立冷启动16项通过，共629项。实际Godot 4.7.2渲染检查出口/朝向、屋顶出生和四个停机坪；真实MTNK物理移动会让开出口。PrepareOnly返回Ready，目标diff空白检查通过。外观与连续出兵手感仍为 `pending_user_visual_confirmation`，不以坐标和截图断言代替用户体验确认。

覆盖RA2/扩展模式，真实生产队列扣费/生成、固定点优先、160世界单位内前向偏移及确定性、现有单位间距、全堵保留已付款队列、解除阻挡后偏移出兵一次、初始两辆矿车、初始兵营可出兵、所属机场四格预约与满位等待、舰船水面出口、自己的集结点及无集结点实际驶离。隐藏乘员和等待删除单位不占用出口。不同机场返航后备与已有停机位置计算保留；未引入新存档字段。

证据根：`C:/Users/admin/Temp/iron-production-origin-20261027-final/`，最终专项为`confirmed/`，五组关联为`regressions/`，`delivery-audit.json`核对结果及源文件。固定隔离工程，每组使用独立CodexIronTideValidation用户目录；离线，无服务、端口、数据库，不触及真实玩家存档。源码与隔离快照逐文件哈希核对，项目配置仅隔离用户目录差异。共享RA3修复保留，本次生产修复单独提升至0.3.9.2，未提交/推送/打包。

失败保留：早期出口仅清可见多边形仍落在路径AABB栅格内，已同步避让导航包围；原单点方案被用户纠正为受阻附近偏移。早期建筑/批量夹具按旧速度直接推进导致提前完成，改用production_work_rate换算，并清除随机障碍后再显式注入堵门；原断言保留。v2/v3专项期间其它任务修改RA3测试，环境审计拒绝，未计入通过；v5原偏移专项206项通过。final首轮渲染在首张截图后未继续推进，已终止明确属于该隔离工程的进程，不算通过；带阶段日志探针208项通过后，恢复源测试原字节，独立profile的confirmed重跑208项通过。失败日志保留，不掩盖最初停滞原因尚未确定。

## 2026-10-27 · v0.3.9 强制攻击

最终专项147项、独立冷启动8项通过；普通开火188、防御开火716、战斗要塞174、尤复伤害1988、飞机弹药显示94、普通鼠标62、通用存档120及其独立冷启动16项通过，共3513项。计入结果无 SCRIPT ERROR/ERROR/WARNING；Godot 4.7.2真实OpenGL专项截图已检查攻击图标。PrepareOnly返回Ready，git diff --check通过。没有以自动验证代替使用者的鼠标手感/表现确认，状态为 `pending_user_visual_confirmation`。

强制攻击覆盖RA2/扩展双模式、真实Ctrl左键输入、友军/敌军实体拾取、固定地面落点、冷却/弹药/最低射程/部署限制、移动接敌、飞机从停机状态出击、混编非战斗单位过滤、战斗要塞乘员、建筑受击/防御建筑手动攻击、友军击杀不计经验、停止/改道/目标死亡清理、UI/小地图输入所有权、普通右键和Ctrl右键保留。旧schema指纹相同数据可读、不同规则拒绝、在途友伤标记和地面对象引用保存/恢复均已覆盖。

证据根：`C:/Users/admin/Temp/iron-force-fire-20261027-final3/`，`delivery-audit.json`列出全部10份结果。关联结果在`iron-force-fire-20261027-v4/regressions/{unit_fire_regression,defense_fire_regression,yr_fortress_regression,yr_damage_regression}`、`iron-force-fire-20261027-final/aircraft_ammo_regression`、`iron-force-cursor-20261027-final/reports`、`iron-force-save-20261027-final/reports`。隔离工程及CodexIronTideValidation用户目录；离线，无服务/端口/数据库，未读写玩家真实存档。各主runner运行期间源码指纹稳定；关联快照之后的本轮runtime差异仅ForceFire.pick改为显式允许敌军拾取，相关Ctrl输入已由最终专项覆盖，普通攻击/伤害/存档实现未变。版本号与测试夹具变化单独核对，不把旧快照宣称为所有最新文件全量验收。

失败与修正记录保留：v1巨炮目标误放在最小射程内，修正夹具距离并新增最小射程断言；v2冻结物理体无space、死亡引用未清理、RA3更新后射程夹具超距和首次渲染失焦，分别修正夹具；final2新增敌军使用空地图波次默认集结，触发旧路径边界错误，改为静止生成并通过真实change_side注册敌军，最终无错误。普通鼠标旧夹具的飞机固定像素失败在改动前battle_cursor同样复现，改用当前art_center投影并注入实际焦点返回，所有原断言保留。飞机显示专项误用headless等待绘制已终止自有进程，改为Render后94项通过。最初批量复用用户目录导致存档坏文件测试读到上一组slot3备份，已停止并在全新隔离profile重跑120+16项通过；这些失败未算作通过。

最终专项之后共享目录又出现另一任务的RA3表现改动（`ra3_mirage_fx.gd`、场shader和4份起义资源元数据），delivery-audit逐项列出；本轮强制攻击/伤害/存档实现保持通过快照字节，未修改、回滚或验收这些并发效果。未继续其它特殊机制，也未提交、推送、打包或归档。操作和实现交接见ALLIED_ABILITIES的v0.3.9段落。

## 2026-10-21 经济链、建造场收起与 RA3 操作区

最终源快照 **905 项断言通过**：economy_chain 132、harvester 86、base_recovery 99、hud_layout 508、veterancy 80。
最终目录：`C:/Users/admin/Temp/iron-tide-economy-chain/final-<suite>/reports/`；完整审计 `C:/Users/admin/Temp/iron-tide-economy-chain/delivery-audit.json`。
新增专项同时覆盖 RA2/扩展模式和双方矿车、传送延迟/阻挡/手动取消/暂停/空车、真实进站前不入账、精炼器身份/前置/所有权/断电/干扰/部分卸货、RA2 增长周期/合法扩散/空格重播/有限宝石、基地车收起往返/血量/费用/双队列续建/战役保护、实时 UI 和 1280x720 操作按钮。
真实采矿专项完成双方初始矿车入账及两轮采矿→传送→短距离倒车→卸货，保留矿场付费造矿车；旧朝向断言分开校验传送跳变和普通行驶，没有删除原有前进行驶要求。

本轮前期经济明细 178、双建造队列 70、多工厂标签 192、矿车朝向 32 项也通过；这些证据为界面状态条位置最终调整之前，**不计入最终 905 项**。
前期失败留在 run-01/run-02 和 harvester_regression 中：运行时字段引用、测试物理空间/水域夹具及把传送误当普通位移的旧断言均已定位；最终轮均无 SCRIPT ERROR/ERROR。harvester 退出有 12、veterancy 退出有 18 个 ObjectDB 实例清理警告，未将其登记为已解决或称日志完全无告警。

环境为 Windows / Godot 4.7.2；纯逻辑套件 headless，经济链/UI 布局使用 RTX 5060 Ti OpenGL Compatibility；固定 60 FPS。每套独立复制工程和 custom_user_dir，无网络、服务、端口、DB。最终五套源指纹前后一致，且均与交付时源文件逐字节匹配。
真实存档最后修改时间为 16:56:04，早于本轮源码备份创建 16:58:25；本轮中后两次读取 SHA256 均为 `F86523C47218850819F925A52B94A01CAAD133FF4494CF2394442B29556C1490`。未把上一轮不同的存档哈希冒称本轮起始值。结束检查无残留测试 Godot 进程。

已查看 1600x900 矿车状态与基地操作截图、1280x720 收起按钮截图。画面、传送音效及手感仍为 `pending_user_visual_confirmation`；正常入口 `C:/Users/admin/IronTide/iron_tide/启动游戏.bat` 重启读取新脚本，不需另做导出安装。

## 最新：尤里版补充语音与 RA3 SDK 本地部署

2026-10-21 接入 Vector 的 YR 单位语音补充包，9 种现有单位、23 组应答、124 段 WAV。
新增 `yr_voice_build.py` 只读取语音映射并转换单声道 PCM/IMA 数据，完整校验之后才写输出；
可选 JSON 覆盖包和 `sfx/yr` 独立存储，保留单位规则、原音频、死亡音、EVA 与播放限频。
来源、下载哈希和导入命令见 RA3_INTEGRATION.md。

124 段实际音频解码与 CPython 3.12 audioop 独立 IMA 实现逐字节相等。
audio_regression **426 项通过**：全部新增 WAV 解码、九种单位两模式的选择映射、
所有补充指令播放与非零混音输出、原单位数据不变、GI/死亡音保留、无包/无映射回退、
热重载恢复，以及原有武器远近衰减、建造生产 EVA、退出和下一局恢复。
audio_lifecycle_regression Render **78 项通过**，合计 **504 项**。
前者使用 headless + WASAPI 实际混音和墙钟计时，后者使用 OpenGL Compatibility / 固定 60 FPS。
全部为 Windows / Godot 4.7.2，隔离复制工程与 custom_user_dir，网络/服务/端口/DB 为 none。
两组源指纹前后及彼此一致，当前启动目录匹配；日志无错误/警告，实际玩家存档哈希未变，
审计时无 Godot 进程。自动混音证明不代替用户试听：pending_user_visual_confirmation。
证据根 `C:/Users/admin/Temp/iron-tide-yr-voice-20261021/`，包含备份、解码对照日志和 delivery-audit.json；
测试报告分别位于 `C:/Users/admin/Temp/iron-tide-yr-voice-audio-01/reports/` 和
`C:/Users/admin/Temp/iron-tide-yr-voice-lifecycle-01/reports/`。

RA3 SDK 便携部署位于 `refs/ra3-sdk/installed`，保留原包和解包原件，仅给本地工具副本添加
CLR v4 启动配置及必要 x86 标志。原静默安装返回 -5，不计为成功安装；便携部署后独立
ArmorTemplate XML 编译、MakeBig 打包退出码均为 0，日志无 Error/Critical，已产出 manifest/bin/BIG。
复核入口 `tools/check-ra3-sdk.ps1`；通过证据 `installed/validation/20261021-164622/result.json`。
官方 SampleMod 因原包缺少部分引用美术等资源仍报 Error，不能标记完整示例通过。
本机未找到 RA3 游戏安装，ModStudio GUI、3ds Max 插件和游戏内 Mod 加载未验收；
未修改系统注册表、未安装系统 .NET 组件、未将 RA3 素材并入 Godot 运行资源。

## 单位等级、经验与军衔

修前实际武器击杀已经发生，但普通弹体未转交击杀经验，建筑死亡丢弃攻击来源；
单位直击还可能从友军死亡获得经验。原选中面板没有经验显示，军衔变化也不刷新详情。
修前两模式 14 项中 10 项失败，击杀前提通过，无脚本错误。

普通弹体通过弱引用把敌方击杀经验转交给仍存活的射手，建筑按造价给经验；
友军、重复死亡、已死亡射手和不可训练单位不获经验。沿用每级自身造价三倍的门槛、
两次晋升及既有属性/精英武器规则，经验溢出保留，不增加局外等级。
选中面板实时显示 Lv.1 新兵、Lv.2 老兵、Lv.3 精英、经验条和下一军衔所需经验；
部队头像补军衔角标，晋升刷新当前属性与实际精英武器。

最终 Render 验证：veterancy_regression 80、unit_fire_regression 188、
hit_structure_regression 136、sonic_regression 464、hud_layout_regression 508、
hud_identity_regression 314，合计 **1690 项通过**。经验专项覆盖真实弹体击杀、建筑、
双方晋升、友军过滤、重复死亡、经验溢出、不可晋升、死亡/释放射手和实时 UI。
初轮修后 2 项失败暴露 ProgressBar 默认整数步长导致比例取整，设置连续步长后通过。
最终专项补刷新冻结测试场景的血条层，已查看精英截图，场上和头像军衔、面板信息可见。
测试不是完整对局或所有特殊召唤物经验归属的等价证明。

环境：Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS；
各测试使用外部隔离项目和 custom_user_dir，服务、网络、端口、DB 均为 none。
源指纹前后稳定，当前目录匹配最终专项；其余五组运行时代码与资源一致，唯一差异是
经验专项截图时刷新血条层的测试代码。导入及运行日志无错误或警告，真实玩家存档
哈希不变，审计时无 Godot 进程。表现状态 pending_user_visual_confirmation。

证据根：C:/Users/admin/Temp/iron-tide-veterancy-20261021/，含修前备份与 delivery-audit.json；
修前：C:/Users/admin/Temp/iron-tide-veterancy-before-01/reports/；
最终经验专项及截图：C:/Users/admin/Temp/iron-tide-veterancy-final-02/reports/；
其它五组：C:/Users/admin/Temp/iron-tide-veterancy-final-<suite>/reports/。
复跑：`./tests/run-navigation-building.ps1 -Suite veterancy_regression -Render -RunRoot <新的外部目录>`。
重开原启动脚本即可加载；未提交或推送。

## RA2 单选与攻击鼠标图标

第一偏离点是 Battle._update_cursor 仅设置系统箭头 / 十字 / 手型，没有加载 RA2 光标素材。
本批新增 battle_cursor.gd 屏幕层，使用本地 MOUSE.SHP 和 MOUSEPAL.PAL 导出的 45 帧；
单选悬停、攻击、禁用、移动及原有命令状态独立切图，保留既有点击和命令执行入口。
当前动画采用 15 FPS，不声称所有原版特殊指令光标及动画节奏完全等价。
素材帧号与调色板参考来源、重建命令和内容哈希见 RA3_INTEGRATION.md 与 mouse.json。

cursor_regression Render 最终 62 项通过：两模式真实鼠标输入、单选与右键攻击、
显式攻击左键确认、空地武器限制、混编有可攻击成员、采矿车禁用攻击、动画换帧、
屏幕热点和四档相机缩放、UI/暂停/结算/失焦切换，以及过期 hover_entity 不泄露迷雾敌人。
离屏视口不接管桌面指针；实际主窗口的系统指针隐藏/恢复体验仍需使用者确认。
已查看最终单选和禁用图标渲染截图；最初攻击截图也确认素材可见，最终运行保留全部截图。
初轮 after-01 的 7 项失败属于测试夹具：显式攻击误用要求框选状态的 gesture helper、
飞机首次绘制前定位未计入抬升、随机矿点与目标重叠触发正确采集优先级。
修正夹具后保留原行为断言并新增飞机真实拾取前提；运行时代码没有为这些失败改规则。

既有 input_ownership_regression 274、camera_input_regression 130、
command_transition_regression 62、dual_build_regression 70 项通过，五组共 **598 项**。
双建造回归首轮扩展模式有一次初始点击未入齐四项的失败；原因尚未确定，不能判为已修复。
仅补失败队列/状态详情及截图留证后，retry-01 / 02 / 03 三次独立运行均 70 项通过，
期间未修改业务代码。原失败报告保留，后续若重现应优先核对真实 UI 点击与布局时序。

环境：Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS；
各轮独立项目与 custom_user_dir，服务、端口、网络、DB 均为 none。
最终通过轮次源指纹稳定，运行时代码和资源一致；唯一后补差异为 dual_build_regression.gd
失败诊断信息。当前受测文件匹配最后一轮，导入及通过轮次日志无错误或警告，
真实存档哈希不变，审计时无 Godot 进程。表现状态 pending_user_visual_confirmation。
重开原启动脚本即可加载。本轮未提交或推送。

证据根：C:/Users/admin/Temp/iron-tide-cursors-20261021/，包含修前源码、素材预览、日志及 delivery-audit.json；
光标最终专项/截图：C:/Users/admin/Temp/iron-tide-cursors-after-02/reports/；
既有回归：C:/Users/admin/Temp/iron-tide-cursors-final-<suite>/reports/；
双建造重跑：C:/Users/admin/Temp/iron-tide-cursors-dual-build-retry-01（及 02、03）/reports/。

## 普通建筑与防御独立建造

两模式按 building / defense 分成两个 FIFO 通道，每通道上限 9 项，同时推进各自首项。
底层保留原聚合数组，侧栏、解锁引导、队列上限和 AI 建造等待使用分类视图；
取消退款及就绪放置保留按建筑 ID 定位。共用资金、电力及建造场，价格和耗时不变。
普通建筑先支付、防御后支付，资金不足不会重复扣款。敌方后端也支持双通道，
没有新增 AI 主动选择防御建筑的战略。截图复核发现旧工厂空闲提示混入建造页，
已隐藏该无关状态，并补入断言；兵种页继续显示真实工厂队列。

修前 before-02：66 项中 30 项失败，确认普通建筑占用首项后防御无法推进；
before-01 是测试变量类型推断失败，不作为行为复现。修后先通过 66 项，
最终双通道专项 70 项通过，包括真实鼠标下单与右键取消、两类同时推进、同类 FIFO、
独立进度与就绪提示、退款、缺钱、缺电、失去建造场、完成及放置不重复付款、
双方资金隔离与分类容量边界。容量边界用合成排队项构造，不表示正常入口允许重复 ID。

最终全部使用 Render：dual_build_regression 70、production_status_regression 66、
input_ownership_regression 274、factory_tabs_regression 192、hud_layout_regression 508、
economy_detail_regression 178、economy_ai_regression 50、unlock_options_regression 46，
合计 **1384 项通过**。已查看最终防御页截图，独立进度和提示可见；
使用者画面及操作体验仍为 pending_user_visual_confirmation。

环境：Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS；
每组独立项目和 custom_user_dir，服务、网络、端口、DB 均为 none。
八组源指纹前后稳定且使用同一版本，当前启动目录全部受测文件匹配；
导入与运行日志无错误或警告，真实玩家存档哈希未变，审计时无 Godot 进程。
复跑入口：`./tests/run-navigation-building.ps1 -Suite dual_build_regression -Render -RunRoot <新的外部目录>`。
证据根：C:/Users/admin/Temp/iron-tide-dual-build-20261021/，含修前备份与 delivery-audit.json；
修前行为报告：C:/Users/admin/Temp/iron-tide-dual-build-before-02/reports/；
最终报告及截图：C:/Users/admin/Temp/iron-tide-dual-build-final-<suite>/reports/。
从原启动脚本重开即可加载；本轮未提交或推送。

## 开火暴露位置

按用户要求，战争迷雾下实际开火向受攻击方显露开火点周围 120 世界单位，持续 3 秒，
再次开火刷新位置与时间；双方规则一致，停火恢复迷雾并保留探索记录，不追踪隐蔽撤退。
接入 Unit 实际发射（含闪避前）、Building 有效开火及光棱支援束；视野、绘制、
小地图、选取及目标有效性复用原共同判定。暂停冻结时间，失效/冷却中的开火不暴露。
超武及其它主动技能不在本批范围，详见 RA3_INTEGRATION.md“开火暴露位置”。

修前第一偏离：攻击者借助侦察共享视野成功开火，但受攻击方视野未更新，无法看到或
锁定攻击者。before-02 423 项中 144 项失败，实际开火前提断言通过，无脚本错误；
更早 before-01 是测试使用不存在的查询/电力字段，修正并重跑，不作为业务复现。
修后先通过 423 项，再补闪避、销毁清理及真实渲染，最终 fog_rules_regression 471 项通过。
覆盖两模式/双方的 MTNK、SREF、GTGCAN、GAPILL，立即暴露、范围、续时、暂停、
撤退不追踪、有效反击、到期不可选取/锁定、地形记忆和销毁后的无悬空引用清理。
既有 unit_fire_regression 188、defense_fire_regression 716、minimap_regression 61 项通过，
合计 1436 项。最后仅截图脚手改为独立 SubViewport 并等待稳定帧；三组既有回归的
运行时代码/资源与最终版本完全一致，唯一文件差异是 fog_rules_regression.gd。

已查看开火及停火截图：敌人和小地图标记随暴露出现/消失。初版根窗口截图有不完整画面，
未作为最终视觉证据；final-02 独立视口稳定渲染。效果冻结夹具中的残留炮口帧不代表
实际游戏停火后持续播放。使用者体验状态仍为 pending_user_visual_confirmation。
环境：Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS，
各组独立工程与 custom_user_dir；服务、网络、端口、DB none。各轮源指纹稳定，当前
文件匹配最终验证，日志无错误或警告；玩家存档哈希不变，审计时无 Godot 进程。
证据根：C:/Users/admin/Temp/iron-tide-fire-reveal-20261021/，含修前备份与 delivery-audit.json；
最终专项及截图：C:/Users/admin/Temp/iron-tide-fire-reveal-final-02/reports/；
既有回归：C:/Users/admin/Temp/iron-tide-fire-reveal-final-<suite>/reports/。

## 建造 / 生产开始语音

第一偏离点：EVA_Building 只接在旧的非即时落地建造流程；当前侧栏结构入队和
Building.enqueue 均未播报。现仅在己方成功入队后触发：建筑、矿车及载具 Building，
兵营与步兵 Training。沿用已有 EVA 音源、优先级及 1000ms 去重，失败 / 重复请求、
就绪建筑选址和敌方生产不触发开始语音；不修改支付、进度和队列语义。

扩展现有 audio_regression：修前 102 项中 16 项失败，分别是两模式建筑、矿车、
大兵、坦克的正确样本及混音输出检查；修后补入批量去重断言，108 项通过。
通过真实 HUD 处理入口和矿场按钮 pressed 信号触发生产，校验真实 EVA 样本身份、
WASAPI 混音 PCM，以及重复 / 缺前置 / 钱不够 / 矿车队列满 / 敌方请求的静默。
audio_lifecycle_regression 78 项、production_reason_regression 56 项亦通过，共 242 项。

环境：Windows / Godot 4.7.2；音频专项 headless WASAPI、实际墙钟推进；其余 Render
OpenGL Compatibility、固定 60 FPS。三组独立工程与 custom_user_dir；网络、端口、DB none。
三组源指纹稳定且与最终文件一致，导入及运行日志无错误或警告。
本轮未停止用户游戏；审计时原进程 13020 已结束，玩家存档哈希有变化，无法确认变化来源，
不声明玩家存档前后不变。测试均使用单独 custom_user_dir，最终无残留 Godot 进程。
需重开加载新脚本；听感状态 pending_user_visual_confirmation，
PCM 有输出不等于已经由用户确认扬声器音量及实际听感。
证据根 C:/Users/admin/Temp/iron-tide-build-voice-20261021/，含修前备份及 delivery-audit.json；
修前 / 修后音频报告为 iron-tide-build-voice-before-01 / after-01 下 reports；
既有回归为 iron-tide-build-voice-final-<suite>/reports，均位于 C:/Users/admin/Temp/。

## 矿场制造采矿车图标

矿场制造入口原为纯文字按钮，现接入现有 CMIN cameo（AHRVICON.png），
使用 60 像素宽图标和两行标题/状态；制造期间保留图标与“制造采矿车”标题，
空闲展示费用、耗时和点击提示，未就绪及制造状态沿用原规则。
只修改 HUD 表现，未修改生产、支付、退款或出厂逻辑。

复用 harvester_regression Render，两模式共 84 项断言通过，实际点击制造及取消，
验证分批支付、暂停、退款、出口受阻和出厂自动采矿。已查看 RA2 制造中截图，
图标、进度文字和取消按钮可见；表现仍为 pending_user_visual_confirmation。
Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility；独立工程及 custom_user_dir，
服务、端口、网络与数据库 none。源指纹前后稳定并与当前文件一致，日志无错误或警告，
玩家存档未改动；原游戏进程 13020 保留，没有停止或重启用户对局。
证据：C:/Users/admin/Temp/iron-tide-miner-icon-harvester-01/reports/；
审计与修前备份：C:/Users/admin/Temp/iron-tide-miner-icon-20261021/。

## 多工厂独立生产标签

两种模式共用逐工厂标签，范围和经济不变量见 RA3_INTEGRATION.md“第四批”。
新专项使用真实 HUD 鼠标点击与 Building 队列，覆盖四个兵种分类的独立下单、
进度、取消和退款、类别切换记忆、队列满不转单、施工与销毁、取消旧长按、
保留战场部队选择，以及 1280/1600 宽度多标签布局。
混合空军专项覆盖兵营飞行兵、战车厂运输机和机场战机的真实生产归属。

| 最终专项（均 Render） | 通过断言 |
|---|---:|
| factory_tabs_regression | 192 |
| production_reason_regression | 56 |
| batch_rally_regression | 40 |
| hud_layout_regression | 508 |
| unlock_navigation_regression | 58 |
| skill_hotkey_regression | 78 |
| feedback_regression | 452 |

合计 7 组、1384 项通过。开发首轮暴露进度条默认 step 导致分数进度取整，
修为连续进度；既有回归暴露空军页首次选择战车厂，错误遮盖战机停机位提示，
修为首次优先专属机场，标签显示真实建筑类型，显式选择后仍不自动转单。
上述失败记录保留，最终全部使用修后相同源码。

环境：Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS；
每组独立工程副本与 custom_user_dir；服务、网络、端口、数据库 none。
各轮源指纹稳定，最终 4834 个文件与七组验收指纹一致，实际工程导入退出 0；
导入和运行日志无 SCRIPT ERROR/ERROR/WARNING，玩家存档 SHA256 前后相同，
没有残留 Godot 进程。已查看最终 1280 宽度多标签截图，未将其当作用户体验确认。

证据总目录：`C:/Users/admin/Temp/iron-tide-factory-tabs-20261021/`，
汇总为 `delivery-audit.json`；新专项为 `C:/Users/admin/Temp/iron-tide-factory-tabs-check-03/reports/`，
六组回归为 `C:/Users/admin/Temp/iron-tide-factory-tabs-final2-<suite>/reports/`。
原启动脚本重开即读取新源码；表现状态 `pending_user_visual_confirmation`。

## 基地切栏、矿场卸货、地表矿石与 GI 部署攻击

四处第一偏离：建造场没有单位 buildable 列表，被自动切页提前返回；
矿场特殊动画未接矿车卸货状态；矿物仍为程序化高水晶；
GI 部署静止帧优先于开火序列，且仍使用 Primary 武器。
本批实现及边界见 RA3_INTEGRATION.md“第三批”。

| 最终专项 | 通过断言 |
|---|---:|
| feedback_regression，Render | 452 |
| harvester_regression，真实物理往返 | 80 |
| economy_detail_regression | 178 |
| unit_fire_regression，Render | 188 |
| building_animation_regression，Render | 246 |
| unlock_navigation_regression，Render | 58 |
| skill_hotkey_regression，Render | 78 |
| fog_rules_regression | 159 |

合计 8 组、1439 项通过。feedback 覆盖两模式、双方、实际基地点选/再次点选、
GACNST 与旧基地、手动切页保留、矿物密度及清空、卸货触发和退出、
GI 八朝向三时刻实际绘制帧、稳定锚点、实际弹道 15 点无甲伤害、
部署射程/冷却与精英武器切换。harvester 增加真实返场后触发洗矿动画断言。

首轮/次轮自动断言虽通过，截图发现 ISOTEM / UNITTEM 都造成杂色，
没有作为最终矿物验收。核对 WAE v1.9.7 YR 剧场配置后确认专用 TEMPERAT.PAL；
本地 MIX 缺此文件，补入 Advanced SHP Editor 的 RA2 调色板后重新导出。
最终反馈专项 check-03 重新验证全部 452 项并生成金矿/彩色宝石截图。
七组既有回归之后仅 resources 子目录的六张 PNG、导入信息和 provenance 改变；
其他运行时、数据及测试字节一致，最终资源由 check-03 覆盖，不将旧颜色截图当作结果。

运行环境：Windows / Godot 4.7.2 / Render 使用 RTX 5060 Ti OpenGL Compatibility /
固定 60 FPS；各轮独立工程及 custom_user_dir；服务、网络、端口、数据库 none。
每轮源指纹稳定，最终实际启动目录与 check-03 全指纹一致，玩家存档前后 SHA256 相同。
导入及运行无脚本错误；harvester 保留既有 4 个 ObjectDB 退出警告，没有把它写成无警告。

证据总目录：
`C:/Users/admin/Temp/iron-tide-feedback-20261021/`，含修前备份、控制台、导出与 delivery-audit.json。
最终反馈报告及截图：
`C:/Users/admin/Temp/iron-tide-feedback-check-03/reports/`。
七组回归：
`C:/Users/admin/Temp/iron-tide-feedback-final-<suite>/reports/`。

表现状态为 `pending_user_visual_confirmation`。原启动脚本重开直接读取源码和资源，
无需另导出 EXE；没有宣称原版可穿行矿层、增长/扩散已实现。

## 矿物数量与价值、分批卸货和多工厂加速

本批实现及明确适配边界见 RA3_INTEGRATION.md“第二批”。本地 rules.ini SHA256 为
fd1e95cea0306ea78049dc81c8cd816e18c28c496872a1ff02edd50bd082062f；独立经济导出在新目录重跑，
生成 JSON 与实际工程逐字节一致，脚本语法检查通过。完整导表入口只增加经济导出调用，本轮未全量覆盖其他配置。

新专项使用实际 Battle/Unit/Building/HUD；固定资源与时间推进用于经济断言，不替代真实移动验收。
原有 harvester 与 MCV 开局专项继续使用真实物理完成采矿、返场和入账。
覆盖两模式/双方的混装、宝石尾量、分批入账、停工后保货、继续卸货、空货不重复入账、销毁货物，
以及工厂增减、展开/施工/断电排除、缺钱暂停、退款、最终一帧精确扣款、建造场队列和矿场制造例外。

新增状态切换断言修前 170 项中 8 项失败，日志无脚本/引擎错误：
旧矿场失效但有替代矿场时，只替换 home_base 而不退出 unloading，导致原地交货；
矿点失效时只替换 resource_node 而仍保持 harvesting，导致远程取新矿。
修后更换卸货目的地恢复 to_base 并释放泊位、更换采集点恢复 to_node。
额外补入低电/需电工厂排除后，开发验证 178 项通过。
修前证据：C:/Users/admin/Temp/iron-tide-econ-detail-repro-20261021/reports。
最早 dev1 是新测试脚本 duration 类型推断错误，已停止对应隔离进程并修正，不作为业务故障或通过证据。

环境：Windows / Godot 4.7.2 / 固定 60 FPS；UI 与矿物画面使用 OpenGL Compatibility / RTX 5060 Ti；
其余逻辑专项 headless。每组使用独立项目副本与 custom_user_dir，网络/数据库/服务均为 none。
本轮证据根 C:/Users/admin/Temp/iron-tide-economy-detail-20261021。
最终 12 组共 1,471 项断言全部通过：经济细节 178、生产状态 66、出厂 82、布局 508、
批量/集结 40、迷雾/规则 159、经济完整性 52、矿车 78、AI 经济 50、MCV 开局 76、模式 83、基地恢复 99。
`delivery-audit.json` 汇总运行前后/当前源码指纹、实际工程导入、经济导出复现与隔离存储检查。
所有测试退出 0，无 SCRIPT ERROR/ERROR；实际工程导入退出 0，最终没有残留 Godot 进程。
控制台与引擎文件均纳入审计：经济完整性退出有 2 个 ObjectDB 泄漏警告，矿车 4 个、AI 经济 2 个，
作为尚未定位的退出限制保留，不因断言通过宣称已解决。

本轮开始时检测到实际游戏进程 PID 57488，随后该进程退出；玩家存档在 14:23:02 发生修改，
整轮前后哈希不同，因此不宣称玩家存档整轮未变，也不回滚该存档。
12 组测试的实际 project.godot 均启用互不重复的 CodexIronTideValidation/<id> 存储目录，
与玩家存档隔离；该检查与源码一致性均通过。修复过程未写入或覆盖玩家存档。
各组报告：C:/Users/admin/Temp/iron-tide-econ-final-<suite>-20261021/reports。
复跑入口为 `iron_tide/tests/run-navigation-building.ps1 -Suite economy_detail_regression -Render -RunRoot <新的外部目录>`；
其它专项以同名 `<suite>_regression` 执行。最终截图 `economy_detail` 报告内的 ra2-mixed-resources.png 已覆盖货舱价值与两类矿物。
颜色、货舱文案和实际卸货节奏仍为 pending_user_visual_confirmation，不写成用户已确认。

## 最新：RA3 风格指挥区、经济完整性、胜负规则与首版战争迷雾

2026-10-21 按用户最新优先级实施。SDK 与官方 UI 参考包已下载至 refs/ra3-sdk，
来源、大小、SHA256 与使用边界见 RA3_INTEGRATION.md。SDK 未安装；UI 包仅作布局参考。
Godot 运行界面保留 RA2 cameo，新增本地 SIDEC01.MIX/SIDEBAR.PAL/TOP.SHP 导出帽檐；
导出脚本 ra2pipe/ui_restore.mjs 及 assets/ra2/ui/provenance.json 记录来源和逐图哈希。

界面改为左下雷达、底部选中详情/固定命令、右侧生产，技能位于详情上方。
无选择时隐藏详情；删除重复头像，部队条继续保留逐单位头像、数量和受损血量。
矿车制造与超武按钮置于固定操作区，详细数据可滚动；生产禁用仅压暗图标，名称和具体原因保持清楚。
QWER 技能、鼠标生产、批量/取消退款、解锁条件与导航沿用既有入口。

经济第一偏离：剩余货舱只有 1 时，旧逻辑仍扣除 22 矿再将 cargo 截断，丢弃 21。
修后 extract 请求量受剩余货舱约束；负采矿请求、负时间不会创建矿物或产生负 cargo。
生产完成同时要求时间与实付费用达到目标。经济专项覆盖敌我两边、RA2/扩展两模式，
真实工厂渐进扣费、缺钱暂停、已付退款、重复取消及大步长最后一帧只生成一单位且不多扣费。
最初矿车夹具关闭了物理空间，日志有 body->get_space() 错误，不作修前验收。
改为启用矿车物理空间并停止自动 tick 后，用保留的旧运行代码再次复现：52 项中 12 项失败，
无脚本/引擎错误。baseline-repro 的旧运行源码仍与原隔离快照一致，只更新了测试夹具。

大厅新增短局/全部歼灭与战争迷雾选项。短局仍按建筑及可展开 MCV；歼灭按全部存活建筑/单位，
舱内单位也计入。双方同一检查点均覆灭返回 draw，结算只发生一次且平局不修改扩展养成。
战役保持原保护主基地规则，不继承遭遇战选项。旧台账的同时覆灭己方失败优先已由本次新规则替代。

迷雾使用双方独立的 40 世界单位网格，0.1 秒刷新；已探索地形保留，当前不可见敌军从世界和雷达隐藏。
新造敌军/建筑入场时立即按视野隐藏，避免在已探索地形上闪现一帧。
选取、光标、寻敌、锁定、开火和舰载机目标判定共用视野；未知区放置先返回需要侦察，
避免通过阻挡文案探测隐藏单位。敌方不可见进攻不再广播全军数量。
矿车只选择已探索矿点；开局对每方提供最近矿区的小范围地形情报，保证经济启动，不揭露敌军。
小地图金色表示已知但不可见矿区，青色表示当前可见；未知矿量不参与雷达更新。
三种地图、预建/MCV 两种开局检查双方矿点可发现、部署有效、敌军仍需当前视野。

环境：Windows、Godot 4.7.2、固定 60 FPS；图形专项使用 RTX 5060 Ti/OpenGL Compatibility，
逻辑专项 headless；所有测试使用项目副本及独立 user_dir，网络/服务/数据库均为 none。
本轮汇总路径：C:/Users/admin/Temp/iron-tide-ra3-foundation-20261021/delivery-audit.json。
最终串行执行 15 组共 1,754 项断言，全部通过：迷雾/规则 159、布局 508、选择/图标 314、
解锁导航 58、生产状态 66、批量/集结 40、小地图 61、经济完整性 52、技能按键 78、
基地恢复 99、AI 经济 50、矿车 78、模式规则 83、基地车开局 76、寻路/建筑 32。
各专项运行前后源码稳定，已测副本与实际启动目录当前文件逐项哈希一致；玩家存档哈希未变，
实际项目导入退出 0；最终 15 组无 SCRIPT ERROR/ERROR/WARNING，测试结束无残留 Godot 进程。
这不代表历史偶发退出 ObjectDB 泄漏已定位或修复。
早先并发运行中的选择输入失败疑似受窗口焦点干扰；最终所有专项串行重跑，保留原输入断言，
选择专项 314 项通过。失败批次不作为交付证据。最终各专项报告位于
C:/Users/admin/Temp/iron-tide-ra3-verified-<suite>-20261021/reports。
自动验证与渲染截图不等于实际手感确认，结论保留 pending_user_visual_confirmation。
原版矿价/宝石/超时空矿车、建造场收起、地形遮挡/潜隐、敌方建筑快照、视野音效裁剪和原地图格式仍未完成。

## 最新：取消生产热键，Q/W/E/R 直接释放技能

用户明确反馈技能和生产 Q/W/E/R 冲突，并要求不用建筑快捷键。
首个偏离是技能栏标注 Q/W，输入分派却要求 Shift；单按会切换生产页签。
现已取消生产页签 Q/W/E/R、B、Z/V 及 F1–F8 / Shift+F1–F8 下单入口，
删除闲置的 cameo 键盘派发和角标方法。所有生产卡与页签去掉旧热键提示，主基地提示改为点击建筑页签。
Q/W/E/R 直接调用原有技能入口，保留 Shift 组合；第五/六槽沿用 Shift+Z/V。
Ctrl/Alt/Meta 组合及键盘自动重复不误施放，文本输入焦点保留原有阻断；按键被处理后不会向战场继续传播。
技能按钮按实际槽位标注 Q/W/E/R，冷却、瞄准、确认与取消继续使用原有技能逻辑。

新增 skill_hotkey_regression 通过真实 Viewport.push_input 验证两模式：
生产页签/下单键无效，鼠标页签可用；四个隔离测试技能通过真实 Unit/Ability 执行效果并分别进入冷却，
不切页签、不触发其它槽位，文本焦点、Shift 兼容、组合键、repeat、范围技能瞄准及再次按键取消。
测试技能仅是四槽路由夹具，不改写或增加玩家可装备技能数量。
旧依赖已移除 cameo 键盘入口的测试改用卡片点击或实际禁用卡片处理函数。
批量生产回归保留容量、付款、退款、真实右键取消与长按断言，取消的热键改验无效，
长按后的继续下单改通过真实鼠标点击验证。

独立按键专项修前 73 项中 37 项失败，修后补充组合键断言为 78 项通过。
最初复用了完整选择专项并在渲染等待中停住，已限定路径停止该隔离测试，
改为独立按键夹具；该脚手失败不作为产品故障或通过证据。
最终报告根为 `C:/Users/admin/Temp/iron-tide-skill-hotkeys-20261021`，
`delivery-audit.json` 汇总最终断言、源码与玩家存档哈希、实际工程导入和各项退出警告。
环境为 Windows / Godot 4.7.2 / 固定 60 FPS；按键与国家专项 headless，
鼠标生产/解锁/布局为 OpenGL Compatibility / RTX 5060 Ti；隔离项目和独立 user_dir，
网络、服务、数据库为 none。用户目标环境操作体验仍为 `pending_user_visual_confirmation`。
最终七组 1,664 项全部通过（按键 78、国家 1,138、鼠标批量 40、导航 58、引导 62、
生产原因 56、布局 232）；运行前后及当前源码一致，玩家存档未变，实际项目导入退出 0。
无 SCRIPT ERROR/ERROR。按键 headless 退出有 2 个 ObjectDB 实例泄漏警告，保留为未解决的既有退出限制。

## 最新：RA2 遭遇战基地车开局

大厅在“遭遇战规则”旁提供“预建基地 / 基地车开局”，默认保留原预建基地。
基地车开局只对 RA2 开放；两边各一辆 AMCV，没有赠送建筑、矿车或国家赠兵。
己方初始选中基地车，敌方基地车原地待命，由实际 AI 决策展开。
小、中、大地图使用避开港口的己方出生位置，三种地图均验证双方出生点可合法展开。
开局消息说明 D 展开 → 电厂 → 矿场 → 选中矿场制造矿车的实际操作顺序。

因为保留用户定制的矿场付费造矿车，电厂 800 + 矿场 2000 + 矿车 1400，
4000 不足以建立采矿收入。MCV 选项因此将 4000 升为 8000 并禁选 4000，
选项说明及资金提示明确最低 8000；入口也做相同下限检查。切到扩展模式恢复预建基地及 4000 选项。
AI 从建造场起步时优先电厂、矿场、首辆矿车，首矿车完成前不扩军或扩科技；
全部费用通过现有生产队列支付，不额外赠款，后续沿用原有双矿车补充策略。

新增 `tests/mcv_opening_regression.gd` 验证真实大厅控件、模式切换和 1280/1600 窗口；
三种未清理随机地形/矿区的实际地图，双方从零展开、玩家逐项精确支付，
敌方真实队列支出 4200 后得到首辆矿车，再用真实 physics 完成采矿、返场和入账。
场景的无关仿真冻结，生产/AI 由专项推进；采矿段启用矿车真实物理与实际矿区，
没有用直接 deposit 调用代替矿车经济闭环。初版 76 项全部通过；最终记录在
`C:/Users/admin/Temp/iron-tide-mcv-opening-20261021/delivery-audit.json`。
该批次同时回归基地恢复、模式规则、AI 经济、寻路、矿车与解锁导航。
最终七组共 476 项全部通过，运行前后源码稳定、已测文件与当前工程一致、
玩家存档哈希未变、实际启动目录导入退出 0。无 SCRIPT ERROR/ERROR；
矿车 headless 退出仍有 4 个 ObjectDB 实例泄漏警告，其余六组无警告。
不据本轮部分无警告结果认定历史退出泄漏已解决。

Windows / Godot 4.7.2 / 固定 60 FPS；开局、恢复和解锁导航采用
OpenGL Compatibility / RTX 5060 Ti，其余 headless；隔离项目及独立 user_dir。
网络、服务、数据库为 none。当前源码比对、运行前后指纹、实际目录导入和玩家存档哈希在审计中汇总。
实际布局截图已检查；仍标记 `pending_user_visual_confirmation`，不重复要求使用者确认。
这只补齐当前盟军与定制经济规则的基地车开局，不宣称原版完整开局选项或对称地图复刻。

## 最新：基地车展开、基地恢复与遭遇战出局边界

AMCV 从本地规则的 DeploysInto=GACNST 读取转换目标；选中后通过命令栏或 D 展开。
展开前检查边界、建筑、障碍、矿点、其它地面单位和水域，包括穿过地基中部的窄水带。
只有展开基地车自身可从占地检查中排除，并允许脱离旧基地建立新建造场；
普通建筑仍受原有基地邻接要求限制。舱内、死亡、已消耗及对局结束后的单位不能展开。
失败显示原因并保留单位；成功不扣第二次费用、不触发阵亡或击杀奖励，继承生命比例，
播放现有建造场展开动画、接入通行阻挡、移除旧编队/跟随引用，并将单选交给新建筑。
多辆选中基地车逐辆处理，不因选择数组变化漏掉后面的单位。

遭遇战敌我统一使用当前短局规则：失去全部存活建筑及可展开基地车才出局。
只有建造场被毁时仍可继续，舱内基地车保留生存资格；普通坦克不能代替基地资格。
死亡及待删除对象在同帧排除，结算只发一次；双方同帧覆灭沿用己方失败优先。
战役仍要求保护主基地。已付款建筑队列在建造场缺失时暂停，恢复后继续；
同时修正了已销毁但尚未移除的建筑仍被算作生产前置的问题。

盟军 AI 在缺少建造场时，使用实际存活工厂及维修厂资格制造一辆基地车，
按原有队列分期支付，不重复下单，不把基地车编入进攻队。
已有基地车优先原地展开；受阻时在附近搜索合法且可达的位置，维持已有有效移动目标。
专项通过真实物理移动抵达再展开，并验证随后恢复建筑生产。
AI 搜索限于附近 640 世界单位，尚未实现全图重建选址或运输基地车策略。

修前能力及提前判负专项有 3 项失败。新增专项最终覆盖 99 项；
初次扩展测试的 select_unit 参数错误属于测试脚手问题，修正后重跑，未作为业务复现。
最终完整记录见缓存批次 `C:/Users/admin/Temp/iron-tide-base-recovery-20261021`。

| 专项 | 断言数 |
|---|---:|
| 基地恢复、AI 实际生产与移动、双方出局及战役边界 | 99 |
| 模式隔离、支付与结算 | 83 |
| AI 经济与生产 | 50 |
| 寻路及建筑 | 32 |
| 命令转换 | 62 |
| 运输、补弹及舰载机 | 142 |
| 科技条件与恢复提示 | 62 |
| 解锁导航 | 58 |
| 生产拒绝原因 | 56 |

环境：Windows / Godot 4.7.2 / 固定 60 FPS；基地恢复及三组 UI 专项使用
OpenGL Compatibility / RTX 5060 Ti，其余使用 headless。全部采用隔离项目及独立 custom_user_dir，
网络、服务、数据库均为 none；基础场景保留真实 actor、队列和寻路，专项清理随机障碍与矿点，
冻结无关仿真后单独推进目标逻辑，AI 移动阶段启用真实 physics。
结果、运行前后源码指纹、当前源码逐文件比对、玩家存档哈希及实际项目导入退出码
汇总在该批次 `delivery-audit.json`，各专项目录前缀为 `iron-tide-base-recovery-delivery-`。
该批次最终 644 项全部通过，源码及玩家存档未变，实际项目导入退出 0。
无 SCRIPT ERROR/ERROR；AI、寻路、命令转换 headless 退出分别有 2/2/8 个 ObjectDB 实例泄漏警告，
保留为已知未解决限制，不宣称音频/引擎退出问题已修复。

该批次尚未加入 MCV 开局（已由上方后续批次接入）；建造场收起、全部单位歼灭规则、平局和玩家规则设置仍未实现。
伤残基地车转换的生命比例、网格位置及附近选址为本工程明确适配，不宣称原版逐帧等价。
展开截图已检查，用户目标环境表现仍为 `pending_user_visual_confirmation`，按授权不重复提问。

## 最新：手动选择替代解锁路线

解锁面板现在按实际前置令牌显示可选分支，选中项带“已选”文字，
建造步骤及原目标卡片的悬停说明同步使用该选择。选择只作用于当前引导目标；
换目标或关闭清空偏好，不写存档、不购买、不取消或修改已有生产队列。
已有任一合格建筑仍直接满足科技条件，偏好不会成为额外生产门槛。

路线按当前祖先条件判断可行性，禁止先依赖同一缺失条件再绕回：
例如实验室尚未解锁时，不能选择依赖实验室的间谍卫星来代替雷达条件。
已有实验室、雷达被毁的场景中，空指部与间谍卫星均可选择。
所选分支因前置摧毁而失效时，明确提示并显示可行路线；
禁用分支悬停和点击均说明原因，过时或不在选项中的请求不会改动路线。
路线与选项共用最高 140 像素的滚动区；截图检查后增加选中文字，
避免选择标记不清及单步路线被裁成半行。小窗口继续保留生产卡片空间。

修前两模式实际入口断言 2/2 失败；新增专项最终 46/46。
覆盖真实鼠标选支、重复选择保持单选、过时/非法选择拦截、提示同步、
刷新/返回保持选择、已付队列精确保留、选择已排产项、前置摧毁后的回退说明、
实际任一替代建筑完成后的解锁、关闭清理、循环前置禁选与 1280×720 布局。
测试点击辅助会先将真实滚动区域中的控件滚入视野，再注入鼠标事件。

| 专项 | 结果 | 报告根（C:/Users/admin/Temp 下） |
|---|---|---|
| 可选科技分支 | 46/46 | `iron-tide-unlock-options-delivery-unlock_options-20261021/reports` |
| 前置导航、返回和输入边界 | 58/58 | `iron-tide-unlock-options-delivery-unlock_navigation-20261021/reports` |
| 原有条件与路线提示 | 62/62 | `iron-tide-unlock-options-delivery-unlock_guidance-20261021/reports` |
| 生产拒绝原因 | 56/56 | `iron-tide-unlock-options-delivery-production_reason-20261021/reports` |
| 批量生产、取消退款与集结 | 40/40 | `iron-tide-unlock-options-delivery-batch_rally-20261021/reports` |
| 多分辨率布局 | 232/232 | `iron-tide-unlock-options-delivery-hud_layout-20261021/reports` |

脚本汇总为 **494 项**，六组退出 0，无 SCRIPT ERROR/ERROR 和退出警告。
Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS；
均为隔离项目、独立 custom_user_dir 的渲染测试，网络/服务/数据库为 none。
`iron-tide-unlock-options-20261021/delivery-audit.json` 确认运行前后源码未变，
已测文件与当前工程一致，实际启动目录导入退出 0，原玩家存档哈希未变。
运行时只修改 hud.gd、unlock_guidance.gd、unlock_panel.gd。
路线是现有 RA2 科技规则的只读规划，不保证最低成本或最短工期，不含自动排建与 RA3 科技升级。
真实观感保持 `pending_user_visual_confirmation`，按用户要求不追加确认问题。

## 最新：解锁路线的侧栏导航

在已有只读条件提示上补齐实际入口：点击科技未解锁卡片或使用其快捷键，打开常驻解锁路线面板；
点击前置建筑切换到对应页签，滚动到目标卡片并以青色边框标出，保留返回最初单位/建筑的入口。
继续点击路线中的未解锁前置不会覆盖原目标；关闭会清除目标和高亮。
已排产、待放置、施工中状态沿用现有条件数据；前置建成后从路线移除，摧毁后重新出现。
国家不符显示具体国家及“本局无法通过建造解锁”；建造场恢复项禁用普通建筑定位。
导航只改变 HUD 页签、滚动和高亮，不调用生产、支付或选址入口。
长路线使用独立滚动区，小窗口保留生产目录空间；用户手动换页会取消待执行的滚动定位。

修前真实点击在两种模式中都没有常驻面板，入口断言 2/2 失败。
修后专项逐步补到 58 项，覆盖真实点击/快捷键、前置定位和返回、青色标记、
目标可见、队列/资金/待放置库存不变、原目标保留、条件完成/毁坏、
国家限制、关闭、手动换页与异步定位竞争、按钮实例稳定和 1280×720 长路线布局。
导航专项启用真实战场输入，只冻结仿真推进；既断言 HUD 点击不泄漏命令，也断言之后普通右键仍可移动单位。
截图来自实际导航后的 SubViewport，冻结建筑展开帧不作为建筑模型完整性的验收。

回归脚手调整：旧生产原因测试在常驻面板展开后仍立即使用上一帧按钮坐标，
已等待真实容器布局后再点击，未移除原断言。输入归属初跑有一次首局 58 项失败，
诊断复跑相同业务代码 272 项通过；未据此宣称游戏输入故障或确定其根因。
现在选择专项和导航专项显式建立合成输入所需的已聚焦前置，增加输入已启用断言；
独立镜头专项继续验证失焦、重新聚焦与暂停行为。中间失败及诊断日志保留。

| 专项 | 结果 | 报告根（C:/Users/admin/Temp 下） |
|---|---|---|
| 实际解锁导航与长路线布局 | 58/58 | `iron-tide-unlock-navigation-verified-unlock_navigation-20261021/reports` |
| 解锁条件、参考路线与提示组件 | 62/62 | `iron-tide-unlock-navigation-verified-unlock_guidance-20261021/reports` |
| 生产拒绝原因 | 56/56 | `iron-tide-unlock-navigation-verified-production_reason-20261021/reports` |
| 批量生产、取消退款、集结 | 40/40 | `iron-tide-unlock-navigation-verified-batch_rally-20261021/reports` |
| 选择和输入归属，含焦点前置 | 274/274 | `iron-tide-unlock-navigation-verified-input_ownership-20261021/reports` |
| 镜头、失焦与暂停 | 130/130 | `iron-tide-unlock-navigation-verified-camera_input-20261021/reports` |
| 多分辨率 HUD 布局 | 232/232 | `iron-tide-unlock-navigation-verified-hud_layout-20261021/reports` |

共 852 项。Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS；
七组均渲染运行，使用隔离项目及 custom_user_dir，网络、数据库与服务均为 none。
最终导入与环境核对见 `iron-tide-unlock-navigation-20261021/delivery-audit.json`。
七组均退出 0，无 SCRIPT ERROR/ERROR 或退出警告；运行前后源码未变，
已测文件与当前启动工程一致，实际目录导入退出 0，玩家存档哈希未变。
本批运行时范围为 hud.gd、unlock_guidance.gd、production_tooltip.gd 与新增 unlock_panel.gd，
不改国家资格、生产队列或战斗规则。实际视觉及操作体验保持 `pending_user_visual_confirmation`；
没有自动排建或手动选择替代科技路线，按用户要求不追加确认问题。

## 最新：科技解锁条件与建造路线提示

用户要求参考 RA3 的解锁告知方式。原提示只显示直接缺项，且没有生产建筑时会遮住其它科技要求；
例如光棱坦克仅提示需要战车工厂，不能据此看出作战实验室还缺空指部。
新增只读 unlock_guidance，读取现有 ra2_prereq、令牌组、己方建成建筑、施工与侧栏队列。
悬停先显示完整直接条件，区分已满足、未建造、施工中、排队中、建造中、待放置；
替代条件明确标注“任一”。递归给出依赖在前、共享建筑去重的一条参考路线，
优先利用已有或已排产的替代项；循环分支独立回退，无法解析时明确提示，不假装可解锁。
点击/快捷键拒绝提示补充同一参考路线。国家限制明确说明本局不能靠建造解锁。
生产提示框固定 400 像素内容宽度并自动换行；规则、价格与科技消费逻辑保持原合同。

初版 38 项提示专项在修前 29 项失败，修后通过；扩充至 62 项，加入真实建筑按钮入口、
敌方建筑排除、排队状态、替代雷达、前置毁坏后恢复路线、按钮身份和提示组件尺寸。
六张截图调用实际生产按钮的自定义提示构造器，在隔离 SubViewport 中渲染；
它们证明组件内容和排版，不冒充桌面悬停弹窗定位或使用者体验验收。

回归另发现上一批国家资格遗漏：盟军目录沿用 DOG 编号，但原始 DOG 禁止盟军国家，
ADOG 才是盟军资格来源。因此警犬被拒绝入队，旧批量生产测试在读取第三个队列项时出错。
已将当前盟军 DOG 的国家资格映射至 ADOG，保留现有单位编号、价格、模型及武器。
国家专项补入五国、双边、两种模式的警犬/工程师真实出厂与扣费：
修前 1,138 项中 65 项失败，修后全部通过；批量生产测试无需修改也恢复 40/40。
此为盟军旧编号适配，不代表苏军警犬或独立 ADOG 素材迁移完成。

| 专项 | 结果 | 报告根（C:/Users/admin/Temp 下） |
|---|---|---|
| 解锁清单、路线和提示组件 | 62/62 | `iron-tide-unlock-final-unlock_guidance-20261021/reports` |
| 国家资格、实际出厂和扣费 | 1,138/1,138 | `iron-tide-unlock-final-country-20261021/reports` |
| 生产拒绝原因 | 56/56 | `iron-tide-unlock-final-production_reason-20261021/reports` |
| 生产状态、缺钱与停工 | 66/66 | `iron-tide-unlock-final-production_status-20261021/reports` |
| 批量生产、取消退款与集结 | 40/40 | `iron-tide-unlock-final-batch_rally-20261021/reports` |
| 模式切换 | 83/83 | `iron-tide-unlock-final-rules_mode-20261021/reports` |

共 1,445 项，六组均渲染运行，退出 0，无 SCRIPT ERROR/ERROR 和退出警告。
Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS；
隔离项目与 custom_user_dir，网络、服务、数据库均为 none。
`iron-tide-unlock-20261021/delivery-audit.json` 核对各组运行前后源码未变，
已测文件与当前实际启动工程一致；实际目录导入退出 0，原玩家存档哈希未变。
运行时改动为 hud.gd、game_data.gd 和新增两个 UI 脚本，未改生产支付/队列实现。
此前其它专项中的音频退出残留警告仍未关闭；本轮无警告不等于修复该问题。
参考路线不保证最短工期或最低成本，也没有实现点击前置图标跳转、自动排建或 RA3 科技升级规则。
提示观感保持 `pending_user_visual_confirmation`，按用户要求不追加确认问题。

## 最新：盟军国家专属生产条件

第一偏离点：大厅已有五国选择，但生产入口、生产执行与 HUD 均未应用原始数据的
RequiredHouses / ForbiddenHouses / Owner，国家专属单位可跨国排队与生产。
现在 RA2 模式按本局国家快照统一校验：英国狙击手、德国坦克杀手、韩国黑鹰、法国巨炮；
韩国不能制造入侵者。建筑请求、队列执行、AI 可入队检查和卡片/快捷键提示使用同一限制。
扩展模式保留原有自由生产与国家赠送。下一局配置变化不会改动当前对局国家。

规则来自本地 data/ra2 的原始国家、单位与建筑数据，未移植参考项目实现。
运行目录尚无 AMRADR，因此美国继续使用 GAAIRC 作为共用机场入口，其国家资格参考 AMRADR；
这不代表已实现美国空降或独立空指部。敌方可读取 enemy_country，未指定时为美国；
大厅尚无敌国选择界面。苏军、完整国家倍率与占领/渗透科技不在本批范围。

初始 690 项国家矩阵在修前有 205 项失败；修后加入实际出厂、完整扣费等 148 项断言，
最终 838 项全部通过。覆盖两种模式、五个国家、敌我归属、生产拒绝不扣费、取消精确退款、
注入不合法待产项后的执行拦截、实际出厂单位与归属，以及禁用卡片和快捷键的具体国家原因。
生产原因旧专项改用德国验证坦克杀手；飞机专项分美国入侵者和韩国黑鹰场景。
扩展模式飞机专项仍用美国，避免韩国开局赠机占用一个停机位而破坏空机场夹具前提；
赠机规则和四停机位断言均保留。中间失败日志保留。

| 专项 | 结果 | 报告根（`C:\Users\admin\Temp` 下） |
|---|---|---|
| 国家资格、实际生产与 HUD，渲染模式 | 838/838 | `iron-tide-country-delivery-20261021/reports` |
| 不能生产的具体原因，渲染模式 | 56/56 | `iron-tide-country-reasons-20261021/reports` |
| 运输、飞机补弹、舰载机 | 142/142 | `iron-tide-country-logistics-delivery-20261021/reports` |
| 经济与 AI | 50/50 | `iron-tide-country-economy-20261021/reports` |
| RA2/扩展模式切换，渲染模式 | 83/83 | `iron-tide-country-modes-20261021/reports` |

共 1,169 项。Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti，固定 60 FPS；
运输与经济专项 headless，各组使用隔离项目和 custom_user_dir，网络、服务与数据库均为 none。
回归后 `iron-tide-country-20261021/delivery-audit.json` 核对全部运行资源和测试继承链与当前工程一致，
各组运行前后源码未变、退出 0、无 SCRIPT ERROR/ERROR；实际启动目录导入退出 0，玩家存档未变。
经济专项仍有 2 个 ObjectDB 退出残留警告，其余四组无该警告；此问题未关闭。
运行时仅改 game_data.gd、battle.gd、building.gd、hud.gd。
卡片灰显与提示体验为 `pending_user_visual_confirmation`，不追加确认提问。

## 最新：移动、巡逻、维修和登船的命令打断

第一偏离点：Battle 的普通移动/攻击移动/集火入口没有清理旧 Shift 队列；巡逻也带着旧队列进入往返，
因此到达新目的地后可继续旧路线。Unit 的停止/警戒/移动没有退出 repairing，物理更新仍优先走维修，
维修厂也继续按 repair_docked 分组处理；警戒未取消 logistics.boarding。停止/警戒还保留 HUD 待选目标模式。

修复：替换移动、集火和新巡逻清空旧路径队列；Shift 追加及内部逐点推进保持原有语义。
停止/警戒取消待选目标，退出维修且不触发自动驶离；新移动退出维修后执行新目的地。
警戒取消登船/卸载调度。正常维修完成仍按原逻辑回血扣费并驶离，未修改维修价格或时间。

专项由真实 Battle/HUD 命令入口、S 键和命令按钮驱动，使用真实单位物理更新、维修厂回血支付和运输逻辑。
为准确触发到达边界，路径队列/巡逻部分把单位放到已下达的目的地，再调用真实到达处理；
这部分不冒充整条路径行走验收，实际寻路和矿车往返由独立专项覆盖。
首次巡逻脚手的起终点重合，已修正位置并补充维修取消后不收费/回血、正常维修完成驶离的正向断言。
修正后的同一份 62 项脚手在修前副本中 **38 项失败**，在修后版本 **62/62 通过**；
对照保留在 `C:\Users\admin\Temp\iron-tide-command-transition-20261021/baseline-corrected`。

| 专项 | 结果 | 报告根（`C:\Users\admin\Temp` 下） |
|---|---|---|
| 命令切换，两种模式、实际键盘/按钮 | 62/62 | `iron-tide-command-transition-delivery-20261021/reports` |
| 运输、补弹、舰载机 | 142/142 | `iron-tide-command-transition-logistics-20261021/reports` |
| 寻路/编队到达与建造 | 32/32 | `iron-tide-command-transition-navigation-20261021/reports` |
| 转向、开火及连发中断边界 | 188/188 | `iron-tide-command-transition-fire-20261021/reports` |
| 矿车实际往返、手动移动与矿场制造 | 78/78 | `iron-tide-command-transition-harvester-20261021/reports` |

共 502 项。命令专项和开火组使用 OpenGL 渲染，其余 headless；Windows / Godot 4.7.2 /
Compatibility / RTX 5060 Ti / 固定 60 FPS，各组独立项目和 custom_user_dir。
网络、服务、数据库均为 none。回归后 `iron-tide-command-transition-20261021/delivery-audit.json`
确认运行前后源码不变、当前运行资源及各测试继承链一致；五组退出 0、无 SCRIPT ERROR/ERROR。
实际启动目录导入退出 0，原玩家存档未变。运行时只改 `scripts/units/unit.gd` 和 `scripts/world/battle.gd`。
无头运输与矿车组分别仍有 24/4 个 ObjectDB 退出警告，保留为未关闭问题，其余三组无该警告。
命令手感为 `pending_user_visual_confirmation`；全命令排列组合、不可达反馈和矿车所有停采语义未作完整验收。

## 最新：离开战斗时清理音频播放

详细退出日志中的残留对象是 AudioStreamWAV / AudioStreamPlaybackWAV。独立发现并修复的产品问题是：
BattleScreen 退出没有通知全局 Ra2Sfx，旧武器声音、当前 EVA、待播队列和限频记录会跨场景保留。
现在退出场景调用 `stop_all()`：停止并解除空间/全局/EVA 播放器的 stream，清空队列和限频记录；
播放器和加载缓存继续复用。音频服务本身退出时也清理播放和缓存。音量、衰减和武器规则不变。

修前生命周期专项 78 项中 35 项失败；修后 78 项全通过。覆盖 RA2 和扩展模式各三次场景创建/销毁、
暂停中销毁、实际高低优先级 EVA 排队、下一局语音/EVA 不继承旧限频、保留播放器和缓存。
复用真实 BattleScreen 的退出回调，不代表已逐个点击所有大厅/结算按钮。

| 专项 | 结果 | 报告根（`C:\Users\admin\Temp` 下） |
|---|---|---|
| 场景音频生命周期，渲染模式 | 78/78，无错误和退出警告 | `iron-tide-lifecycle-render-20261021/reports` |
| 真实 WASAPI 混音 | 50/50，无错误和退出警告 | `iron-tide-lifecycle-audio-delivery-20261021/reports` |
| 运输、飞机补弹、舰载机，无头默认驱动 | 142/142，仍有 24 个 ObjectDB 退出残留警告 | `iron-tide-lifecycle-logistics-20261021/reports` |

合计 270 个不同断言。混音测试直接采集 PCM：退出场景并排空已混音缓冲后峰值为 0，
重新播放峰值大于 0.001；此前远近衰减、全局声音、单位语音和 EVA 的混音断言保留。
新增混音脚手首次有 GDScript 局部变量类型推断错误，修正显式类型后重新运行；失败日志保留，未当作游戏故障。

**退出警告与场景残音必须分开记录**：同一运输专项在修前和修后代码上显式启用 WASAPI，
均为 142/142 且无 ObjectDB 警告；默认无声驱动下仍有残留，数量随采样变化。
这仅将现象缩小到该测试音频路径，尚未证明引擎内部根因，也未宣称本批彻底修复该警告。
对照日志位于 `iron-tide-lifecycle-20261021/before-wasapi` 和 `logistics-wasapi`，原详细日志在 `before-console.log`。

Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti；除实时混音专项外固定 60 FPS。
隔离项目及 custom_user_dir，网络/数据库/外部服务均为 none。回归后 `iron-tide-lifecycle-20261021/delivery-audit.json`
核对测试继承链和全部运行资源与当前工程一致、运行前后源码不变；实际启动目录导入退出 0，原玩家存档哈希未变。
本批运行时只改 `scripts/core/ra2_sfx.gd`、`scripts/screens/battle_screen.gd`。
实际听感仍为 `pending_user_visual_confirmation`，不追加使用者确认问题。

## 最新：数字编队召回与双按定位

修正两个第一偏离点：HUD 按编队分别保存上次按键时间，导致快速 `1、2、1` 被误判为双按；
Battle 用 `combatants` 分组区分单位和建筑，舱内或死亡动画单位退出该分组后，被误填进
`selected_building`，触发 HUD 读取 `under_construction` 等建筑属性的运行错误。

现在只对连续同一数字判定 400 ms 双按，每次先召回，双按再居中；Alt 定位不替换选择，
其它按键或文本输入中断连按。编队按对象类型区分成员，清理死亡、待删除、失去己方归属的成员；
舱内成员保留记录但不参与选择或镜头中心，卸载恢复。没有可操作成员时保留原选择。
没有新增追加编队或修改移动、战斗、运输机制。

验证批次：`C:\Users\admin\Temp\iron-tide-control-groups-20261020`。
修前原代码在纠正后的物理脚手下再次运行，`baseline-clean/result.json` 为 42 项、16 项失败，
并复现建筑属性访问错误。最初脚手将物理对象设为 PROCESS_MODE_DISABLED，产生
`body->get_space()` 额外错误；已改为激活物理空间、关闭自动推进、手动调用真实逻辑，
没有删除或放宽断言。旧日志保留，不能将该脚手错误归为游戏故障。

| 专项 | 结果 | 独立运行目录（均在 `C:\Users\admin\Temp`） |
|---|---|---|
| 编队实际按键、装载/卸载、死亡动画、建筑组、空组 | 42/42 | `iron-tide-control-groups-final-20261020/reports` |
| 镜头与焦点 | 130/130 | `iron-tide-control-groups-camera-20261020/reports` |
| 选择与 HUD 输入归属 | 272/272 | `iron-tide-control-groups-input-20261020/reports` |
| 运输、补弹与舰载机 | 142/142 | `iron-tide-control-groups-logistics-20261020/reports` |

合计 586 项。前三组以 OpenGL 渲染运行，运输组 headless；均覆盖 RA2 和扩展模式，
真实 battle.tscn/HUD/单位，SubViewport 注入键盘，冻结无关推进，手动推进真实运输/死亡入口。
Windows / Godot 4.7.2 / Compatibility / RTX 5060 Ti / 固定 60 FPS；
每组隔离源码副本和 custom_user_dir，网络、服务、数据库均为 none。
回归后审计 `delivery-audit.json`：运行前后源码未变，当前运行资源及测试继承链哈希均匹配，
四组退出 0、无 SCRIPT ERROR/ERROR；当前启动目录再次导入退出 0，原玩家存档哈希不变。
本批运行时只修改 `scripts/world/battle.gd` 和 `scripts/ui/hud.gd`。

运输组退出仍报告 **32 个 ObjectDB 未释放对象**，未定位，不能宣称无警告或已修复释放问题；
其余三组无该警告。数字编队的实际体验为 `pending_user_visual_confirmation`。
此前“移动单位残缺”仍未定位，此编队修复不作为该画面问题的完成证据。

接管阶段范围是工程接管、模式隔离、基础数值、生产扣费、寻路入口和资源恢复。
全量 RA2 对照仍未完成，剩余范围见 [RA2_PARITY.md](RA2_PARITY.md)。

| 验证 | 最终结果 | 报告 |
|---|---|---|
| 模式/生产/结算/图标 | 83/83；RA2→扩展→RA2；从无 `.godot` 缓存的副本导入并渲染 | `C:\Users\admin\Temp\iron-tide-modes-delivery-20261020\reports\result.json` |
| 寻路/海空移动域/光标/建造动画 | 36/36；包含六坦克实际移动和展开动画帧序 | `C:\Users\admin\Temp\iron-tide-navigation-delivery-20261020\reports\result.json` |
| 原始规则数据 | 50/50；隔离生成、阵营适配生成成功 | `C:\Users\admin\Temp\iron-tide-data-delivery-20261020\validate.log` |
| 资源完整性 | 1800 个导入记录均有源文件；59 张 PNG 从现有缓存恢复并逐像素核对 | `C:\Users\admin\Temp\iron-tide-rules-20261020-a\reports\texture-recovery.json` |
| 接管阶段来源审计 | 两套场景测试的源码/资源指纹与当时开发目录一致；当时玩家原存档哈希不变 | `C:\Users\admin\Temp\iron-tide-modes-delivery-20261020\reports\delivery-audit.json` |

运行环境：Windows，Godot 4.7.2，OpenGL Compatibility / RTX 5060 Ti，固定 60 FPS；
每个副本独立 `custom_user_dir_name`。网络、数据库、服务端进程均未使用。
真实场景/单位/生产逻辑参与验证；寻路测试延后敌方波次，建造测试暂停无关演员并推进真实生产/动画方法。
最后两套运行退出码均为 0，日志无 SCRIPT ERROR / ERROR。

修前证据保留：

- `iron-tide-production-before-20261020/reports/result.json`：9 个失败，复现末帧多扣费与展开时提前生产。
- `iron-tide-domains-before-20261020/reports/result.json`：6 个失败，复现敌方子节点寻路、海军流场与空军岸边吸附。
- 首次渲染回归抓到采矿光标对 Node 使用 Dictionary.get 的错误，随后添加实际光标判定断言。

最终截图位于对应 `reports` 下：`lobby-modes.png`、`building-stage-0.png` 至 `building-stage-2.png`、
`building-complete.png`。自动验证证明逻辑断言与渲染帧成立，**画面与操作手感仍为 pending_user_visual_confirmation**。
早期 headless 模式回归有退出时 2 个 ObjectDB 残留警告，最终渲染回归未出现；尚未独立定位该 headless 退出问题。

旧 Chatbox 工程保留。本目录已初始化本地 Git 分支 `codex/ra2-independent`，尚无提交、远程或发布。

## 画面与操作第一步：C01 / C02

小地图点击与绘制统一使用居中正方形；留白点击不移动镜头，已有拖拽跨入留白时钳制到地图边缘。
视野框使用实际画布变换的逆变换获取四角，并在极限缩小时裁剪到地图内。
未修改相机原有地图边界限制、战斗规则或存档逻辑。

- 修前 C01：42 项中 18 项失败，复现非正方形小地图定位偏移和留白响应。
- 修前 C02：58 项中 12 项失败，像素检查复现旋转相机的视野框错误。
- 修后：**61/61 通过**；真实 `battle.tscn` / HUD，小地图接收 `Viewport.push_input` 鼠标事件。
- 覆盖横向、纵向、正方形布局，点击/拖拽/越界松开，零旋转、正负 45°、不同缩放和超出地图的视野裁剪。

最终报告：`C:\Users\admin\Temp\iron-tide-minimap-final2-20261020\reports`。
`result.json` 保存断言；`minimap.png` 保存恢复正常 HUD 后的截图；
`outline-0.png` 至 `outline-3.png` 保存测试布局下的视野框。
Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS，
隔离副本与独立 `custom_user_dir_name`，无网络、数据库或服务依赖。
`environment-audit.json` 确认运行前后源码/资源未变，退出码 0，日志无 SCRIPT ERROR / ERROR。

最终运行实际用户目录为 `C:/Users/admin/AppData/Roaming/CodexIronTideValidation/05514090aa3d498d9136d101b8c99efd`。
普通玩家存档在 11:54:07 有更新，已不同于接管阶段旧哈希；默认日志也存在同期普通运行及旧探针输出，
不能将历史“存档未变”结论沿用到整个本轮，也未覆盖或回滚该存档。
本次最终隔离运行开始于 11:57:05，运行后普通存档修改时间仍为 11:54:07，
该阶段结束时 SHA256 为 `A127452D6E8DA6C5A2C6ED2E2D37D20DEA5E6BE0CE98C4B46A63D1B2520A11C6`。

本次为小地图专项，未重跑接管阶段的全套模式/生产/寻路测试。
截图已检查；实际点击、拖拽与视野对应感仍为 **pending_user_visual_confirmation**。

## 选择操作第二步：I01 / I02

`Battle._apply_selection` 以屏幕框选矩形的对角线长度判断点击，阈值为 14 屏幕像素，
不再受世界坐标、相机缩放和纵向投影压缩影响。移除重复点击已选单位自动施放主技能的入口，
保留双击选同类、D 部署、Shift+Q 和技能按钮的显式操作。

修前：`C:\Users\admin\Temp\iron-tide-selection-before-final-20261020\reports`，
176 项中 15 项失败，复现缩放相关误判、扩展模式误部署及冷却消耗。
修后：`C:\Users\admin\Temp\iron-tide-selection-final-20261020\reports`，
**176/176 通过**。前后测试源码相同，运行指纹唯一变化为 `scripts/world/battle.gd`。

实际 `battle.tscn` 和 HUD 置于独立 1600×900 SubViewport；
通过真实鼠标事件检查两种模式、0.5/1/2/4 倍横向缩放及对应等距纵向压缩，
覆盖小幅移动、横/纵框选、包围框选、松开、重复点击、双击同类和空地清选。
按键经过 HUD 输入链路；技能按钮检查调用其已连接的 `pressed` 信号，
不将此项表述为鼠标点击按钮命中测试。显式施放和冷却拒绝从独立初始状态验证。
无关演员暂停；真实贴图首次渲染后定位测试单位，未替代选择状态机。

Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS；
无服务、网络或数据库依赖，最终退出码 0，导入及游戏日志无 SCRIPT ERROR / ERROR，
运行前后源码/资源指纹一致。报告 `result.json` 记录实际隔离用户目录：
`C:/Users/admin/AppData/Roaming/CodexIronTideValidation/7a497b6f9dc949468e39b6c3fc884b96`。
普通玩家存档在本轮期间发生变化，不宣称其哈希保持不变，也未回滚该存档。

早期测试窗口的物理鼠标查询与注入位置不一致、测试脚本错误和贴图首帧边界未就绪，
均属于测试环境/脚手问题；不作为上述修前缺陷证据。修前最终版和修后版使用相同独立视口，
每次鼠标按下均断言事件到达战场且屏幕起点正确。
本轮未重跑全套生产/寻路或上一阶段小地图专项；各历史报告仅证明其当时版本。
操作手感状态仍为 **pending_user_visual_confirmation**。

## 选择与 UI 输入第三步：I03 / I04

Shift 状态在左键按下时记录：点击单位切换选中，框选追加，空地保留；
建筑与单位保持互斥选择。Shift 手势不参与普通双击选同类的计时链路。
HUD 的交互控件、子控件和面板留白不再启动战场选择、移动命令或镜头平移。
战场开始的左键拖拽在 HUD 松开时取消本次框选并保留原选区；
战场开始的镜头拖拽仍可跨 HUD 持续，松开后结束且不追加移动命令。

- 修前 `C:\Users\admin\Temp\iron-tide-input-baseline-20261020\reports`：
  254 项中 32 项失败，覆盖两种模式的 Shift、HUD 点击穿透、生产右键取消及跨界松开。
- 首次修后 `C:\Users\admin\Temp\iron-tide-input-after-20261020\reports`：
  相同 254 项全部通过。
- 最终 `C:\Users\admin\Temp\iron-tide-input-final-20261020\reports`：
  **270/270 通过**，增加敌军排除、HUD→战场拖拽、真实单位队列子图标取消及小地图跨界拖拽；
  包含此前 176 项选择/技能回归。

测试继续使用真实 battle/HUD、独立 1600×900 SubViewport、真实鼠标和按键输入。
图标子节点测试将现有图标临时设为 PASS，确认事件向真实父控件传播；
单位队列从真实兵营 enqueue 两个 E1，右键图标后断言恰好剩一个且没有战场移动命令。
覆盖默认“右键直接下令”和可选“右键拖图”两种设置，不更改默认设置。

Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS；
隔离项目与独立用户目录，无网络、服务或数据库依赖。
最终运行源码/资源前后指纹一致，退出码 0，导入和游戏日志无 SCRIPT ERROR / ERROR。
普通玩家存档不作为本测试输入或输出；不对同时进行的普通游戏运行作未变化保证。
本轮未重跑全量生产/寻路及小地图坐标专项，结论限于上述实际覆盖。
使用者仍需确认操作体验，状态为 **pending_user_visual_confirmation**。

## HUD 布局第四步：U01 / U02

常驻顶部收起投影参数与 GM 入口，统一放进“设置 → 视角与开发工具”；
投影按钮、Ctrl+G 和原投影热键保留，Esc 可关闭设置。
小地图和生产栏按顶部栏实际高度向下排列，保持 8 像素间隔；
右栏宽度调整为 368 像素实际内容面板宽，生产页签改成三列两行。
同步修正操作情报中已经失效的“点击已选单位施放技能”和默认右键拖图说明。

修前报告：`C:\Users\admin\Temp\iron-tide-hud-before-20261020\reports`，
初始 116 项中 42 项失败，包含参数常驻、面板越界、顶部/小地图重叠及间距不足；
该版布局测试未主动填充生产目录，不作为生产卡片布局证据。
后续补齐真实目录、既有皮肤刷新和滚动验收。

最终结果：

- `C:\Users\admin\Temp\iron-tide-hud-final-20261020\reports`：**232/232** 布局检查通过。
- `C:\Users\admin\Temp\iron-tide-hud-input-final-20261020\reports`：**270/270** 输入回归通过，
  包含 Shift、技能显式入口、HUD 鼠标归属、队列取消和小地图跨界拖拽。

布局场景为真实 battle/HUD，冻结无关演员，使用独立 SubViewport 检查
1280×720、1600×900、1920×1080、2560×1440 两种模式，随后缩回 1280×720。
验证真实生产卡片横向边界、滚动到末项、长资金/低电文字、设置展开/关闭；
设置由鼠标点击打开，关闭检查调用既有 Esc 分发目标 `armed_escape()`。
生产皮肤先通过既有 `Ra3Skin.upgrade_tree` 应用，避免只测空面板或尚未换肤的控件。
这是内部视口布局矩阵，不冒充 Windows 各种 DPI 或所有显示器的人工体验验收。

已检查最终正常 HUD、设置面板和长状态文字截图；图片位于布局报告目录，
例如 `ra2-1280x720.png`、`iron_tide-1600x900.png`、`ra2-settings.png`。
Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS，
隔离副本及用户目录，无网络、服务和数据库依赖。两个最终运行退出码均为 0，
源码/资源前后指纹一致，导入及游戏日志无 SCRIPT ERROR / ERROR。
未重跑全量生产/寻路测试。画面与操作体验仍为 **pending_user_visual_confirmation**。

## HUD 身份图标与规则标识第五步：U04 / U06

生产卡片、生产队列、选中条和详情头像共用 `UnitIcon`，
按现有 `GameData.ra2_cameo_path(id)` 取图；等比居中绘制，缺图继续使用既有兵种备用剪影。
数量、血条、受损边框和选中状态仍由同一控件绘制；生产卡片关闭血条等状态装饰，
队列保留数量，选中条继续响应血量变化。没有生成或引入新图片，也未修改图标目录映射。
控件切换身份时清空旧贴图，防止缺图对象沿用上一个头像。

RA2 的无技能栏隐藏在修前已正确，不将其当成新增修复。
本次增加顶部“RA2 对照”/“扩展模式”标识，并验证多选、切建筑和清空选区时的技能栏可见性；
扩展模式的技能按钮、快捷键和冷却回归仍通过。

修前 `C:\Users\admin\Temp\iron-tide-identity-before-20261020\reports`：
308 项中 14 项失败，表现为各处头像来源不一致、复用后未解析图标及缺少规则标识。
最终结果：

- `C:\Users\admin\Temp\iron-tide-identity-final-20261020\reports`：**312/312 通过**，
  包含此前 270 项选择与输入回归；新增控件存在后，其来源/模式文字分支也纳入断言。
- `C:\Users\admin\Temp\iron-tide-identity-layout-final-20261020\reports`：**232/232 通过**，
  重新覆盖四档视口尺寸、长资源文字、卡片边界与滚动。

实际 HUD 消费者使用 E1 验证四处同源，GAPOWR 验证建筑选中图标，
未知 ID 验证缺图回退与复用时清除旧图。血量变化断言仅针对已实现实时刷新的选中条，
不将详情头像静态采样描述成新增实时刷新。原有图标缺失范围仍由后续 V01 盘点。
截图 `ra2-identity.png` / `iron_tide-identity.png` 展示两种模式的多选与队列，
`*-fallback.png` 展示缺图备用样式。

Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / 固定 60 FPS，
真实场景与 HUD、独立 SubViewport、无关演员冻结、隔离项目与独立用户目录；
未使用网络、服务或数据库。两个最终运行退出码均为 0，源码/资源前后指纹一致，
导入及游戏日志无 SCRIPT ERROR / ERROR。未重跑全量生产/寻路测试。
图标截图已检查；最终观感仍为 **pending_user_visual_confirmation**。

## 音效位置与全局播放修复（2026-10-20）

`Ra2Sfx.play` 设置世界坐标后又将本地坐标清零，使开火声、单位回应等实际位于地图原点；
镜头远离原点后被距离衰减为零。默认 `Vector2.INF` 的全局音效也误用空间播放器。
现保留传入世界坐标，并为全局播放使用独立、最多 32 个的 `AudioStreamPlayer` 池。
空间声音仍按原 Range 衰减，EVA 调度、资源映射、音量配置和战斗规则未改。

验证命令：`.\iron_tide\tests\run-navigation-building.ps1 -Suite audio_regression`。
Windows / Godot 4.7.2 / headless 显示驱动 / WASAPI 音频驱动 / 真实时间推进；
隔离项目及用户目录，无网络、服务、端口、数据库依赖。
使用真实资源及服务入口，在相机位于 (5000, 5000) 时捕获 Master 混音 PCM：
两种模式均覆盖屏内武器、远处武器衰减、全局播放、E1 选择语音、建造完成 EVA；
另测空间播放器重复使用后的位置和未知音效安全失败。

- 修前：`C:\Users\admin\Temp\iron-tide-audio-before-20261020\reports`，34 项中 7 项失败；
  屏内武器、单位回应、全局音效及空间播放器复用场景的混音峰值均为零。
- 修后：`C:\Users\admin\Temp\iron-tide-audio-final-20261020\reports`，**34/34 通过**；
  屏内武器、单位回应、全局音效和 EVA 有非零输出，远处武器仍为零。
  导入与运行日志无错误，退出码 0，源码与资源前后指纹一致，正式音效脚本与验证副本一致。

这是音频混音输出验证，不代表扬声器或耳机的实际听感已经确认。
使用原 `iron_tide/启动游戏.bat` 重新启动后试听，状态为 **pending_user_visual_confirmation**。

## 缺图盘点与建筑放置第六步：V01 / B01

`tools/check-assets.mjs` 按 GameData 的数据合并顺序枚举单位和建筑，区分有素材、
未接入而使用占位、配置引用丢失，输出可重生成的 `ASSET_INVENTORY.md` 与 JSON 路径清单。
62 个条目中主体占位 41、图标占位 29；RA2 目录 47 项中分别为 26 和 14，
其余 15 项为历史/扩展条目。目录条目不代表都已开放生产。
已有 1800 个导入描述未发现原文件缺失，配置引用文件缺失为 0；
这不代表缺少的专用美术已经补齐。JSON 位于 `C:\Users\admin\Temp\iron-tide-assets-20261020.json`。

建筑预览、合法性检查和实际碰撞统一调用 `Building.placement_poly`，
保留原有 SHP 底盘及缺素材时的 Foundation × 0.72 回退。
占地描边在鬼影之后绘制；放置状态在现有 WORLD_HUD 标签层显示，
保持水平、16 屏幕像素字号，不被建筑遮住。合法显示“可放置”，非法显示当前原因；
无专用主体显示“占位外观”。建造菜单移除过时的“指挥中心 620 范围”说明。
没有补画或借用其他单位素材，没有更改邻接距离、水陆规则、资源消耗或建造时长。

最终运行（命令均为 `.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite>`，
需要渲染的专项加 `-Render`）：

| Suite | 结果 | 证据目录（C:\Users\admin\Temp\ 下） |
|---|---|---|
| building_preview_regression | 252/252 | iron-tide-placement-final-20261020/reports |
| navigation_building_regression | 31/31，无头 | iron-tide-placement-navigation-final-20261020/reports |
| rules_mode_regression | 83/83，无头 | iron-tide-placement-rules-20261020/reports |
| hud_layout_regression | 232/232 | iron-tide-placement-layout-20261020/reports |

放置专项覆盖两种模式、全部建筑数据的占地/物理多边形、已登记图像的实际加载、
地图越界、建筑/岩石/矿点/地面单位阻挡、水陆限制、缺邻接、资金与已付费库存，
以及真实视口鼠标放下建筑、取消保留库存。
0.5/1/2/4 倍缩放与合法/非法/缺图预览截图保存在放置报告目录；
已检查低倍与高倍文字可读性，以及占位建筑前方实体不会遮住提示。
全量船坞沿岸选址、全视角预设、所有实体美术替换仍不在本次完成范围。

首轮放置测试误复用了带“进入框选”断言的选框手势脚手；
已改用真实鼠标按下/松开，最终继续断言实际建筑、位置、资金与库存。
首次渲染寻路运行提前退出且未产出 result.json，不计通过；
随后独立无头完整重跑通过，截图由放置专项负责，不把无头结果当作渲染验收。

Windows / Godot 4.7.2 / 渲染专项使用 OpenGL Compatibility / RTX 5060 Ti，
固定 60 FPS、隔离副本与独立用户目录，无网络、服务、端口、数据库依赖。
最终四次运行退出码 0、导入与运行日志无错误、源码资源前后指纹一致。
最终观感与操作体验仍为 **pending_user_visual_confirmation**。

## 建筑就绪与生产状态第七步：B02 / B03

修前 `production_status_regression` 50 项断言中 24 项失败：
收回最后一个已武装的就绪建筑后仍保留 `armed_build`；
卡片缺少显式的就绪/选址/排队/暂停/缺钱状态，实时刷新会重新启用当前施工卡片；
单位生产缺钱或低电时仍统一显示“生产中”。
修前证据：`C:\Users\admin\Temp\iron-tide-production-status-before-20261020\reports`。

修复后，最后一件就绪库存退款时同时退出放置并刷新战场预览层；
取消另一种库存不打断当前选址，Esc 仍只取消选址，不退库存。
生产卡片复用第二行原地更新状态，保留节点身份；侧栏新增建筑队列状态摘要，
卡片利用现有两列可用宽度。既有未解锁原因保留在悬停提示中。
单位队列 ETA 按实际 `build_speed`、低电倍率及已有快速建造开关计算；
暂停、缺钱或设施离线时不显示倒计时，缺电减速和缺电停工分开显示。
没有调整收费、退款额度、生产速度或解锁规则。旧现场施工分支的独立进度条不在本次统一范围。

最终命令：`.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite>`；
前三个专项加 `-Render`。证据均在 `C:\Users\admin\Temp\`：

| Suite | 结果 | 目录 |
|---|---|---|
| production_status_regression | 66/66 | iron-tide-production-status-delivery-20261020/reports |
| hud_layout_regression | 232/232 | iron-tide-production-layout-delivery-20261020/reports |
| hud_identity_regression | 312/312 | iron-tide-production-input-delivery-20261020/reports |
| rules_mode_regression | 83/83 | iron-tide-production-rules-delivery-20261020/reports |

生产专项使用真实生产队列推进、资金暂停、具有供需缺口的低电倍率、HUD 状态更新、
建筑类型切换、退款及实际放置入口；校验双倍生产速度和低电下的 ETA，
以及 Powered 设施低电离线不显示倒计时。另覆盖按钮身份稳定和暂停恢复。
已经检查两模式缺钱、低电及就绪截图；图片位于生产专项报告目录。

Windows / Godot 4.7.2 / OpenGL Compatibility（渲染专项）/ RTX 5060 Ti /
固定 60 FPS；独立副本和用户目录，无网络、服务、端口或数据库依赖。
最终四次运行均退出 0，源码资源前后指纹一致，最终业务文件与各验证副本一致。
没有 SCRIPT ERROR / ERROR；规则专项退出时有 2 个 ObjectDB 实例未释放警告。
详细复查定位为 `AudioStreamWAV` 和 `AudioStreamPlaybackWAV`，证据在
`iron-tide-production-rules-20261020/verbose-recheck/console.log`；
该退出清理问题仍待处理，不把断言通过解释为没有任何运行告警。
表现状态保持 **pending_user_visual_confirmation**。

## 批量生产与集结点第八步：B04 / B06

修前专项 34 项中 18 项失败（两个模式各 9 项）：
Shift+F1 没有传递事件修饰键，长按后在按钮外松开会吞掉下一次快捷键；
E1 / DOG / E1 的后段覆盖了同型总数量与队首进度；
出兵依赖“附近第一座建筑”猜来源，导致使用别人的集结点，非生产生成也误继承；
旗帜函数未接入绘制，右键清除及建筑销毁清理缺失。
修前证据：`C:\Users\admin\Temp\iron-tide-batch-rally-baseline-20261020/reports`。
最初一次运行因新增测试的 GDScript 类型推断错误而未执行断言，不作为业务复现。

现在快捷键直接按自身 Shift 状态执行生产，鼠标长按去重不再干扰键盘；
更换生产面板时取消旧按住状态；同型总数累加，队首进度不被后段覆盖。
真实生产完成时传入所属工厂，地图或技能生成单位不再猜测附近集结点。
仅显示选中生产建筑的集结旗帜，以 WORLD_HUD 层固定屏幕像素绘制，并连接工厂与目标；
该直线表示目标关联，不表示实际绕障路径。右键本建筑清除自身集结点，
建筑退出场景时清理记录。补充操作提示，并消除兵营说明的横向文本溢出。
未改变生产价格、收费时机、队列容量、生产速度及敌军出兵规则。

最终命令：`.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite>`，
前四项加 `-Render`。证据均在 `C:\Users\admin\Temp\`：

| Suite | 结果 | 目录 |
|---|---|---|
| batch_rally_regression | 40/40 | iron-tide-batch-rally-delivery-20261020/reports |
| production_status_regression | 66/66 | iron-tide-batch-status-delivery-20261020/reports |
| hud_identity_regression | 312/312 | iron-tide-batch-input-delivery-20261020/reports |
| hud_layout_regression | 232/232 | iron-tide-batch-layout-delivery-20261020/reports |
| navigation_building_regression | 31/31，无头 | iron-tide-batch-navigation-delivery-20261020/reports |
| rules_mode_regression | 83/83，无头 | iron-tide-batch-rules-delivery-20261020/reports |

专项使用真实 SubViewport 鼠标/键盘入口，验证单击、Shift 快捷键、长按、
松开后的快捷键、九个容量上限、切页取消，以及右键队尾/队首的数量、进度和退款。
直接调用实际生产推进完成出兵；将两座兵营放在同一点作为来源判别的对抗夹具，
断言新兵读取自己的生产者、获得移动命令并进入真实寻路，不把重叠夹具当作合法建造场景。
清除瞬时命令标记后校验持久旗帜像素；查看了两种模式的集结旗帜截图。
该专项旗帜截图为 2 倍缩放；继承的通用报告中 zooms 字段不代表本专项覆盖四档缩放。
全地形实际到达、海空生产出口与 GM 极速建造退款不在本轮专项覆盖范围。

Windows / Godot 4.7.2 / OpenGL Compatibility（渲染专项）/ RTX 5060 Ti /
固定 60 FPS；隔离工程及独立用户目录，无网络、服务、端口或数据库依赖。
最终六项共 764 个断言通过，运行退出 0，源码与资源前后指纹一致。
无 SCRIPT ERROR / ERROR；规则专项仍有退出时 2 个 ObjectDB 实例未释放的既有警告。
最终操作手感与画面状态保持 **pending_user_visual_confirmation**。

## 建筑展开与出厂第九步：B05

修前 `building_exit_regression` 48 项中 31 项失败，证据：
`C:\Users\admin\Temp\iron-tide-building-exit-before-20261020/reports`。
展开绘制使用 buildup 图集和最终帧锚点，但命中仍使用成品图集及当前帧锚点；
门状态只看队列是否非空；陆军出口随机且不校验阻挡，舰船无水面出口时退回随机陆地。

修改后展开命中/选择中心复用当帧真实图集和固定锚点，不改变建筑物理占地。
门按临近出厂的进度打开，出厂后停留并倒放关闭；地面门与屋顶门按单位类型区分。
出口使用确定顺序，从占地外寻找合法位置，检查单位外圈的地图边界、通行域及现有单位占用。
全部受阻时保留队首和已付进度，HUD 显示“出口受阻”；解除后只生成一次，不再次收费，
完成音在实际生成后触发。侧栏建筑到达“就绪”库存时补上单次完成播报。
当前数据缺少各建筑专属出口坐标，仍采用固定方向的占地外候选点；
不把它称为逐建筑原版出口或“从门内驶出”的完整动画实现。

视觉复查发现 GAWEAP_1/2/3/4 只有 JSON，缺少对应 PNG：
使用原有 `ra2pipe/art_build.mjs anim`，从旧 Chatbox 本地
`refs/ra2pack/full/RA2.MIX` 的 `SNOW.MIX` 提取到隔离目录，
核对 source/cell/cols/count/rects/frames/shadow 与现有描述完全一致后，
只恢复这 4 张 PNG。没有整体替换规则数据或其它动画资源。
提取记录、4 张资源 SHA256、导入日志及玩家存档前后哈希在
`C:\Users\admin\Temp\iron-tide-door-assets-20261020/`。
实际工程完成编辑器无头导入，玩家 `iron_tide_meta.json` 哈希未变。

最终命令为 `.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite>`，
除 navigation / rules 外均加 `-Render`；展开/出厂专项额外加 `-FreshImport`，
证明新贴图可在不使用旧导入缓存的副本中加载。
证据均在 `C:\Users\admin\Temp\`：

| Suite | 结果 | 目录 |
|---|---|---|
| building_exit_regression | 82/82 | iron-tide-exit-detail-delivery-20261020/reports |
| batch_rally_regression | 40/40 | iron-tide-exit-rally-delivery-20261020/reports |
| production_status_regression | 66/66 | iron-tide-exit-status-delivery-20261020/reports |
| hud_identity_regression | 314/314 | iron-tide-exit-input-delivery-20261020/reports |
| hud_layout_regression | 232/232 | iron-tide-exit-layout-delivery-20261020/reports |
| navigation_building_regression | 31/31，无头 | iron-tide-exit-navigation-delivery-20261020/reports |
| rules_mode_regression | 83/83，无头 | iron-tide-exit-rules-delivery-20261020/reports |

专项覆盖两模式 15%/50%/90% 展开帧的可见像素命中与中心、落成恢复成品图集、
稳定占地、真实门资源及开/关门像素差异、空地门区分、连续生产、出口受阻、
水面与空中出口、地图边缘、单位避让、等待解除、退款和完成播报调用次数。
全阻挡/全水面通过临时改实际通行网格构造，随后恢复，不当作完整海军地图实战；
播报调用次数不等于音频设备试听通过。GM 极速建造退款仍未覆盖。
旧输入测试冻结建筑在展开第 0 帧却点击成品中心，导致 4 项失败；
现在先落成该选择夹具并新增可见像素断言，保留原来的独占选择断言。
第一次修后运行有一处 GDScript 类型推断编译错误，已修正；该次不计通过。

资源巡检增加建筑叠层及损伤变体引用：37 个引用仍缺 20 张图片，
详见 `ASSET_INVENTORY.md`。`node tools/check-assets.mjs` 因这些已登记缺图返回 1，
不能把主图/图标/展开引用缺失为 0 解释为全部资源齐全。
本轮恢复的 4 张工厂门贴图通过导入及渲染；其它缺图留待后续。

Windows / Godot 4.7.2 / OpenGL Compatibility（渲染专项）/ RTX 5060 Ti /
固定 60 FPS；隔离工程及用户目录，无网络、服务、端口、数据库依赖。
最终七项共 848 个断言通过，源码资源前后指纹一致。
最终寻路专项退出时仍有 2 个 ObjectDB 实例未释放的既有警告，未作为本轮修复项。
状态仍为 **pending_user_visual_confirmation**；需用户在实际入口确认展开、开关门、
出厂手感与完成音。

## 建筑动画缺图恢复第十步：V01

从已有本地素材恢复此前登记的 20 张建筑叠层图片。由于空指部、维修厂、
作战实验室、超时空传送仪、天气控制机和间谍卫星的主体也缺失，
同时恢复这 6 张主体，否则其动画不会进入实际建筑绘制入口。
共 26 张 PNG；没有替换既有 PNG，没有改写 INI、单位/建筑数值或动画描述 JSON。

使用现有 `ra2pipe/art_build.mjs anim` 和 `shp`，在
`C:\Users\admin\Temp\iron-tide-animation-recovery-20261020/` 隔离导出；
只将目标 26 张资源带回工程。所有候选元数据与原有 JSON 的原始字节 SHA256 完全一致。
该目录的 `source-audit.json` 记录本地 RA2.MIX、提取工具、元数据和输出 PNG 哈希，
`before-inventory.json` / `after-inventory.json` 记录前后缺口；
`save-audit.json` 证明实际工程无头编辑器导入前后玩家存档哈希未变。
本轮复用了用户旧 Chatbox 目录中的本地素材，没有下载外部美术。

恢复主体使 6 座建筑从 foundation 后备占地切换为已有算法提取的真实美术底盘，
因此额外回归放置、碰撞、寻路和出厂；绘制、预览与物理占地继续使用同一份几何。
这属于资源恢复带来的几何变化，不能只按纯贴图替换理解。

播放复核发现 GAYARD 的 productionanim 在空闲时也循环，且每次出船没有独立相位。
修前 `iron-tide-animation-baseline-20261020/reports`：244 项中 10 项失败，
均为两个模式的船坞完工动画边界。现在只在实际出兵后启动，
从第一帧播放到描述给定时长后隐藏，下一次出兵重置相位；
动画时钟不改变队列完成、扣费或单位生成时机。

最终验证命令：`.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite>`；
除 navigation / rules 外均加 `-Render`，动画专项额外加 `-FreshImport`。
证据均在 `C:\Users\admin\Temp\`：

| Suite | 结果 | 目录 |
|---|---|---|
| building_animation_regression | 246/246 | iron-tide-animation-detail-final-20261020/reports |
| building_preview_regression | 252/252 | iron-tide-animation-placement-20261020/reports |
| building_exit_regression | 82/82 | iron-tide-animation-exit-20261020/reports |
| hud_identity_regression | 314/314 | iron-tide-animation-input-20261020/reports |
| hud_layout_regression | 232/232 | iron-tide-animation-layout-20261020/reports |
| navigation_building_regression | 31/31，无头 | iron-tide-animation-navigation-20261020/reports |
| rules_mode_regression | 83/83，无头 | iron-tide-animation-rules-20261020/reports |

共 1240 项断言通过。动画专项覆盖两模式、8 座相关建筑、20 张动画的真实纹理加载、
主体与叠层画布匹配、完好/受损帧区间，以及真实绘制中有/无叠层的像素差异。
normal / special 状态截图为 1 倍缩放；通用基类报告的 zooms 字段不代表本专项覆盖四档。
船坞走真实入队与生产完成入口，断言空闲/排队不播放、完成起帧、推进、不重复出兵、
到期隐藏和下一次重播。用于造船的全水面网格是隔离夹具，不代表完整海军地图验收。
维修/卸矿的 special 状态通过既有表现入口触发，不把截图当作经济或维修机制验收。

初次测试错误地要求尚未触发的延迟像素缓存存在，产生 40 项脚手失败；
已改为验证导入纹理能够读取像素，后续修前基线只保留 10 项真正的播放问题。
1 倍缩放时受损实验室只剩少量灯光，隔点采样漏掉细节，已改为逐像素计数；
只重跑受影响动画专项，其他六项的业务源码、资源和各自执行测试保持一致。
未删除播放或像素差异断言。

`node tools/check-assets.mjs` 当前退出 0：62 个目录条目中主体占位 35、图标占位 29；
37 个建筑叠层引用缺图 0；1830 个导入描述对应原文件缺失 0。
这只覆盖当前运行目录及已有动画描述，不意味着整个 RA2 或全部美术已恢复。
其中仍有 20 个 RA2 目录主体和 15 个历史/扩展主体处于占位状态。

Windows / Godot 4.7.2 / OpenGL Compatibility（渲染专项）/ RTX 5060 Ti /
固定 60 FPS；隔离工程和用户目录，无网络、服务、端口、数据库依赖。
各运行源码资源前后指纹稳定，最终业务源码与资源匹配验证副本。
寻路专项退出时仍有 2 个 ObjectDB 实例未释放的既有警告；无 SCRIPT ERROR / ERROR。
恢复结果与动画观感仍为 **pending_user_visual_confirmation**。

## 主体资源恢复第十一步：V01（2026-10-20）

实际启动目录为 `C:\Users\admin\IronTide\iron_tide`，仍由 `启动游戏.bat` 直接加载。
从已有本地 RA2.MIX 通过现有管线重新生成候选，核对原元数据哈希后接回：

- 15 个单位：ENGINEER、JUMPJET、CLEG、SPY、CCOMAND、TANY、AMCV、CARRIER、
  AEGIS、LCRF、SHAD、DLPH、SREF、ORCA、BEAG。
- 3 个建筑：GAGAP、GASAND、GAWALL。
- 8 个 VXL 单位的配套阴影、SREF 独立炮塔；共 27 张 PNG。
- JUMPJET、CCOMAND、TANY 的 3 份动作帧表。

原有 27 份图集 JSON 与本轮生成元数据逐字节一致，未覆盖已有图像、玩法数据或运行脚本。
输出来源与哈希保存在 `C:\Users\admin\Temp\iron-tide-body-recovery-20261020\`。
原缺图导致 `RA2Art` 返回空素材并走程序化外观；恢复图片后真实主体绘制与像素点击路径生效。
3 个建筑同时从 foundation 回退占地切换为素材底盘占地，因此额外回归实际碰撞、放置与出厂。

导出工具修正两个问题：

1. `loadSequences` 读取带尾注的 section 及 `Sequence=` 显式别名；
   ROCK、CCOMAND、TANY 分别解析到 RocketeerSequence、ComandoSequence、TanyaSequence，
   解决仅凭文件名匹配而遗漏动作表的问题。
2. 无炮塔 VXL 图集增加上下留白；此前 PNG 高度只有 frameH，
   运行时却从 y=2 取 frameH 高度，源矩形越出图像底边。本轮新增 VXL 和阴影所有帧均在图内。
   该修正仅应用本轮新导出的素材，未批量覆盖其他已有图集。

NASAM 首轮候选只有底座。实际渲染截图确认缺少独立 SAM.VXL 发射架，
已把本轮新增 NASAM.png 及导入描述移到外部 `deferred-nasam/`，保留此前程序化完整外观。
GTGCAN 的本地底座找到的是 SNOW.MIX/GAGCAN.SHP，炮塔/炮管为
LOCAL.MIX/GTGCANTUR.VXL、GTGCANBARL.VXL；未在本轮启用。
两座防御建筑作为下一步完整组合任务，不能把底座文件存在记作完整外观通过。

验证命令仍为 `.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite>`。
资源专项加 `-Render -FreshImport`；放置、出厂和 HUD 加 `-Render`；
规则、寻路使用无头。最终六次运行共 **1512 项断言通过**：

| Suite | 结果 | C:\Users\admin\Temp 下的证据目录 |
|---|---|---|
| unit_art_regression | 750/750 | iron-tide-body-final-20261020/reports |
| building_preview_regression | 252/252 | iron-tide-body-placement-20261020/reports |
| building_exit_regression | 82/82 | iron-tide-body-exit-20261020/reports |
| hud_identity_regression | 314/314 | iron-tide-body-hud-20261020/reports |
| rules_mode_regression | 83/83 | iron-tide-body-rules-20261020/reports |
| navigation_building_regression | 31/31 | iron-tide-body-navigation-20261020/reports |

新专项覆盖两模式、15 单位八方向的真实绘制路径与可见像素选取、
全部图集源矩形边界、炮塔/阴影画布一致性、6 种步兵的动作区间与运行时取帧，
以及 3 建筑的主体加载、占地一致性和像素点击。
新增动作资源会启用既有延迟回收，因此通过真实 `_die` / `_physics_process` 补测：
死亡通知仅一次、立即退出战斗分组、只保留表现尸体、动画后回收。
这不代表原版动画时序、海豚动作、围墙连接帧或各兵种特殊技能已完成。
本专项冻结实际战场并摆放陆海空资源，属于视觉夹具，不是海军陆地行驶或完整对局证明。
截图为 1 倍缩放；基类报告通用 zooms 字段不代表该专项覆盖四档缩放。
首轮 `iron-tide-body-render-20261020` 的 710 项是候选检查，包含后来暂缓的 NASAM，
不计入最终通过总数。

`node tools/check-assets.mjs` 退出 0：1857 个导入描述原文件缺失 0；
主体占位 17（RA2 2 个、历史/扩展 15 个），图标占位 29；
37 个已登记建筑动画引用缺图 0，已声明载具炮塔缺图 0。
工具新增载具叠层检查，DEST/CDEST 仍为程序化阴影 2 项，不混同为阴影素材已恢复。

环境为 Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti，
渲染固定 60 FPS；各验证有独立工程与用户目录，服务/端口/数据库均为 none。
六次运行前后源码资源指纹稳定，最终再次与当前目录核对一致；
玩家原存档 SHA256 仍为 `C34545130A8C17E33798CE4E74AA569A3ED5272BA8C909C6BD7760653B45C088`。
实际启动目录编辑器导入成功，无 SCRIPT ERROR / ERROR。
规则、寻路测试退出时仍有各 2 个 ObjectDB 实例未释放的既有警告，未在本轮处理。
最终观感、比例和操作体验仍为 **pending_user_visual_confirmation**。

## 防御建筑组合第十二步：V01（2026-10-20）

巨炮 GTGCAN 与爱国者 NASAM 在实际启动目录接入完整主体组合：
底座 SHP、独立体素炮塔（巨炮含独立炮管）、32 朝向图集与固定模型原点。
来源为已有本地 MIX 的 SNOW.MIX/GAGCAN.SHP、NASAM.SHP，以及
LOCAL.MIX/GTGCANTUR.VXL、GTGCANBARL.VXL、SAM.VXL。
独立入口 `ra2pipe/defense_art.mjs` 先向外部 `IRON_TIDE_PROJECT` 生成候选；
新增 4 张 PNG 和 5 份 JSON，NASAM 原元数据经字节核对后保留。
候选、来源哈希及最终审计在 `C:\Users\admin\Temp\iron-tide-defense-recovery-20261020\`。

`BuildingTurretArt` 只负责表现：以底座画布中心、配置的 TurretAnimX/Y 和模型投影原点定位，
随既有 attack_target 选帧；断电保持末次朝向，建造展开时隐藏成品炮塔。
炮管/发射架可见像素与底座组成点击掩码，透明区域不扩大命中。
放置预览调用同一绘制器并沿用合法/非法颜色，完成建筑的占地仍只来自底座；
炮塔转向不扩大碰撞。恢复底座会使两座建筑从 foundation 回退几何切换为素材底盘几何。
`_process`、`_fire`、`receive_hit`、`is_operational` 与修改前逐段比较一致；
未修改武器、经济、模式数据和攻击计时。

首轮 400 项候选测试只验证换帧，截图发现炮口背对目标。
源模型前向为 +X，现有载具取帧约定为 -X，不能直接套用。
补充独立模型轴投影方向断言后，
`iron-tide-defense-facing-baseline-20261020/reports` 的 468 项中 64 项失败，
均为两模式、两建筑、完好/受损、八方向的炮口方向。
现通过这两个资源描述的 `facing_offset=16` 修正，不改变其他单位取帧。

最终七组共 **1980 项断言通过**。命令为
`.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite>`；
除 rules / navigation 外均加 `-Render`，证据位于 `C:\Users\admin\Temp\`：

| Suite | 结果 | 证据目录 |
|---|---|---|
| defense_art_regression | 468/468 | iron-tide-defense-acceptance-20261020/reports |
| building_preview_regression | 252/252 | iron-tide-defense-placement-20261020/reports |
| building_exit_regression | 82/82 | iron-tide-defense-exit-20261020/reports |
| unit_art_regression | 750/750 | iron-tide-defense-units-20261020/reports |
| hud_identity_regression | 314/314 | iron-tide-defense-hud-20261020/reports |
| rules_mode_regression | 83/83 | iron-tide-defense-rules-20261020/reports |
| navigation_building_regression | 31/31 | iron-tide-defense-navigation-20261020/reports |

防御专项覆盖全部 32 帧图内边界、8 个实际目标方位、完好/受损状态、
底座/炮塔 alpha 并集与世界选取、0.5/1/2/4 倍缩放的真实鼠标点击、
断电保持朝向、展开隐藏、空闲保持及完整放置预览。
绘制前后核对目标身份、目标 HP、资金、武器冷却不变。
测试冻结实际战场并手动给定目标，用于验证表现与输入；
巨炮以 ORCA 为方向夹具不表示巨炮取得了对空攻击能力。
没有把截图当作原版目标选择、射速、转速、后坐力、弹道或整局对照通过。

中途一次测试脚本类型推断失败已修正，仅属于脚手错误。
`iron-tide-defense-final-20261020` 已通过干净缓存导入和全部方向断言，
剩余两处点击失败来自四倍缩放下的首个炮管像素 `(808.72, 83.83)` 落在顶部 HUD。
界面拦截是正确行为；最终脚手从露出 HUD 的炮管像素注入点击，保留 alpha 与选择断言。
放置、出厂测试执行副本与最终目录仅有未调用的 `defense_art_regression.gd` 脚手差异；
其业务代码、资源和实际执行测试均一致，无需因无关脚手修改重复运行。

当前资源盘点退出 0：1861 个导入描述对应原文件缺失 0；
47 个 RA2 目录条目均有主体，15 个历史/扩展主体与 29 个图标仍占位；
37 个已登记建筑动画引用缺图 0、载具炮塔缺图 0、新接入两建筑炮塔组合缺失 0。
DEST/CDEST 继续使用程序化阴影。完整炮塔投影、转速、后坐力与炮口特效仍待后续对齐，
不以主体齐全宣称整个 RA2 美术或机制完成。

环境为 Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti，
渲染固定 60 FPS；每次运行独立工程和用户目录，无服务、端口或数据库依赖。
各运行前后源码资源指纹稳定，最终相关业务代码/资源/实际测试再次核对一致。
原玩家存档在任务期间发生了外部变化，不能报告“存档未变”：
开始为 `C34545130A8C17E33798CE4E74AA569A3ED5272BA8C909C6BD7760653B45C088`，
结束为 `440861A10EC7E6443436097F91280089877B785B857C11A9D18BC27BEB7EA7C4`，
修改时间为本机 15:30:02。主游戏用户目录日志另有 15:22:58 的实际战场启动记录。
所有本轮测试的配置与运行报告均确认 `OS.get_user_data_dir()` 位于独立的
`AppData/Roaming/CodexIronTideValidation/<唯一ID>`，没有消费主游戏存档；
因此该外部存档变化不使上述隔离断言失效。具体写入进程未追溯，不推定操作者；
未对原存档覆盖或回滚，保留当前内容。
实际目录编辑器导入成功，无 SCRIPT ERROR / ERROR；
寻路专项退出仍有 2 个 ObjectDB 实例未释放的既有警告，本轮未处理。
请从原 `启动游戏.bat` 重启体验，状态仍为 **pending_user_visual_confirmation**。

## 2026-10-20：生产建筑缺部件与敌方攻击不扣血

用户明确反馈满血战车工厂、矿场、维修厂缺部件，敌方攻击自己却不扣血。
本轮修前使用实际 Battle、Unit、Building、Projectile 复现：
`C:\Users\admin\Temp\iron-tide-hit-structure-baseline-20261020\reports`，
106 项断言中 50 项失败。敌方灰熊坦克命中我方后，我方 HP 不变，
爆点旁敌方坦克反而从 300 降到 235；反方向与旧扩展范围伤害也存在同一错误。

第一偏离点是投射物选择了反向的目标组。实体的 `enemy_targets` 表示“敌方可以攻击的目标”，
其中登记的是我方单位/建筑；两条范围伤害分支却将其用于我方攻击。
现仅修正 `projectile.gd` 的两处组选择，保留弹头、护甲、衰减、伤害量化和模式加成。
自动回归通过实际开火和弹道推进验证坦克对重甲扣 65、对木质电厂扣 42，
并覆盖双方、单位/建筑、同阵营保护、半径外目标、旧扩展范围伤害与直接命中。

建筑有两处独立问题：

- 原始 `art.ini` 的 `BibShape=GAWEAPBB/GAREFNBB/GADEPTBB` 没有进入成品主体，
  漏掉出厂坡道、卸矿区和维修平台。由已有本地 SNOW.MIX 读取主体和底座，
  将底座合成到对应完好、受损、阴影帧的下层，沿用同一画布与调色板。
  完好帧分别新增 2177、3100、3995 个原来透明的像素。
- 本地 `GAWEAP_1..4` 各只有四帧，实际为完好、受损及对应阴影，
  不能把 INI 中的门循环范围直接截断成四帧来播放。
  修正门结构描述为完好固定帧 0、受损固定帧 1，阴影为后两帧，
  避免满血生产时出现残缺/阴影结构。不宣称完成原版连续开门动画。

`ra2pipe/building_foundations.mjs` 用于在外部 `IRON_TIDE_PROJECT` 生成候选；
共享逻辑 `building_shapes.mjs` 也接入 `art_build.mjs` 的主体/动画导出，
避免重新导出时丢失底座或恢复错误帧。新增来源元数据供资源盘点检查。
实际更新三张主体 PNG、三份主体 JSON 和工厂动画描述。
运行时 Building 脚本与本轮开始时字节一致，但完整主体会改变可见像素锚点和底盘：
放置预览、点击、占地、出厂、寻路均已做相应回归。

最终六组 **820 项断言通过**；命令为
`.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite> -RunRoot <新外部目录>`。
前四组加 `-Render`，后两组为 headless。证据在 `C:\Users\admin\Temp\`：

| Suite | 通过 | 目录 |
|---|---|---|
| hit_structure_regression | 126 | iron-tide-hit-structure-acceptance-20261020/reports |
| building_exit_regression | 82 | iron-tide-hit-structure-exit-20261020/reports |
| building_preview_regression | 252 | iron-tide-hit-structure-preview-20261020/reports |
| building_animation_regression | 246 | iron-tide-hit-structure-animation-20261020/reports |
| navigation_building_regression | 31 | iron-tide-hit-structure-navigation-20261020/reports |
| rules_mode_regression | 83 | iron-tide-hit-structure-rules-20261020/reports |

表现专项拍摄三类满血建筑、工厂地面/空中生产结构及受损帧。
原始底座独立选出的像素 `(233,198)/(169,168)/(84,118)` 在实际导入纹理中不透明，
并通过真实建筑像素点击判定。最终截图清理了冻结伤害夹具遗留的爆炸特效；
此前 `...-fixed-...` 的 126 项已经通过，但截图存在夹具特效遮挡，不作为最终视觉样本。
专项使用默认 2 倍缩放，基类报告中的通用 zooms 列表不表示本专项覆盖全部缩放。

环境为 Windows、Godot 4.7.2、OpenGL Compatibility / RTX 5060 Ti；
独立工程副本及 `CodexIronTideValidation/<唯一ID>` 用户目录，无服务/端口/数据库依赖。
六次运行前后源码资源指纹稳定。出厂/预览与最终版本仅有未调用的
`hit_structure_regression.gd` 清理特效及截图脚手差异，其实际测试与业务资源一致。
实际启动目录编辑器导入成功，无脚本错误；Node 语法及资源盘点通过。
寻路/模式进程退出仍报告既有的 2 个 ObjectDB 泄漏警告。

备份、候选、资源报告、源码哈希和最终环境审计保存在
`C:\Users\admin\Temp\iron-tide-hit-structure-recovery-20261020\`。
主玩家存档本轮发生外部变化（`440861...EA7C4` → `219FD2...41E6F`），未覆盖或回滚；
测试配置与运行证据均确认使用独立用户目录，不把原存档变化错误报告为测试写入或“未变”。
本轮自动验证成立，实际画面与战斗体验保持 **pending_user_visual_confirmation**，
已向用户发送两道选择题，等待重启原入口后的反馈。

## 2026-10-20：矿车往返与矿场制造

用户确认：由矿场付费制造矿车，沿用现有价格/时间，每座同时一辆，完成后自动采矿；
从战车工厂移除入口。该定制生产规则同时适用于两种模式，原始 RA2 数据文件不改写。

定位与修改：

- CMIN 车体素材的车头方向与运行时取帧相差半圈，八方向修前投影点积均为 -1；
  增加 CMIN 专属 `facing_offset=4`，渲染、阴影及实际像素命中共用当前帧，
  并在 `ra2pipe/art_build.mjs` 中保留此元数据，避免重新导出丢失。
- 手动移动/指定矿点清除旧倒车与路线；自动采矿重建 A* 路径，正常行驶转向后前进。
  卸矿使用矿场前侧固定泊位，先到外侧停车转向，再进行最后约 46px 倒车；
  距泊位不超过 4px 才开始卸矿。两车共用矿场时顺序入库。
- 满载返场不再依赖矿点仍有矿；仅选择己方已运作矿场，无矿场则保留货物等待，
  不再向总部或敌方建筑卸货。去掉直接改坐标的穿碰撞“脱困”。
- 原开局固定坐标会让矿车身体与总部重叠。开局双矿车改在地形建立后使用矿场合法出口，
  数量不变；真实生成地图上的两辆车都必须完成采矿和入账。
- 矿场选择面板提供制造/取消按钮；进度扣费、缺钱暂停、取消退款、堵口等待均复用生产队列。
  成品从实际矿场出厂后直接进入采矿流程，不接战车工厂集结指令。
- 新矿车路线改变出基地的通行时序，暴露六坦克编队停车点吸附后的间距不足：
  两点仅约 25px，车辆先到位后被互相挤离。修前当前候选 5/6 到位，旧副本 6/6；
  调整障碍吸附后的槽位搜索，保留车身与到达余量。最终最小间距约 54px，
  六辆坦克在 24.72 秒同时到位，原 26px / 60 秒断言未放宽。

新增 `harvester_regression` 覆盖真实开局、连续两次采矿往返、矿枯满载返场、无矿场等待、
手动移动、两车排队，以及真实 HUD 点击、半程扣费、退款、缺钱、堵口和出厂自动采矿。
新增 `miner_heading_regression` 覆盖两模式八方向车头投影与实际纹理像素命中。
修前矿车专项 16 项中 14 项失败；修后分别验证状态/物理运动与真实渲染。
初版朝向测试越过源图片底边读取像素属于脚手错误，已按画布外透明处理，未修改贴图掩盖。

一次并行运行的长截图测试在扩展模式中停止输出，已结束该自有副本，
保留 `iron-tide-miner-final-20261020/reports`，不计为通过。
随后给专项添加固定随机种子、阶段日志及有界截图等待，并单独核对 headless 逻辑。

用户已反馈：**“正常了，只在矿场门口倒车”**。矿车行驶/倒车表现获得确认。
矿场制造入口答复为“暂时还没测试”，该按钮体验仍为 **pending_user_visual_confirmation**；
不把自动 UI 点击断言等同于使用者体验确认。

最终九组共 **1387 项断言通过**，另跑同版矿车 headless **66 项通过**。
命令仍为 `.\iron_tide\tests\run-navigation-building.ps1 -Suite <suite> -RunRoot <新外部目录>`；
下表除寻路、模式外均加 `-Render`，headless 矿车单独不加。
证据目录均位于 `C:\Users\admin\Temp\`：

| Suite | 通过 | 目录 |
|---|---|---|
| harvester_regression（渲染） | 70 | iron-tide-miner-final-traced-20261020/reports |
| harvester_regression（headless） | 66 | iron-tide-miner-final-headless-20261020/reports |
| navigation_building_regression | 32 | iron-tide-miner-nav-final-20261020/reports |
| hud_layout_regression | 232 | iron-tide-miner-hud-final-20261020/reports |
| batch_rally_regression | 40 | iron-tide-miner-batch-final-20261020/reports |
| building_exit_regression | 82 | iron-tide-miner-exit-final-20261020/reports |
| rules_mode_regression | 83 | iron-tide-miner-rules-final-20261020/reports |
| miner_heading_regression | 32 | iron-tide-miner-heading-final-v2-20261020/reports |
| unit_art_regression | 750 | iron-tide-miner-unit-art-final-20261020/reports |
| production_status_regression | 66 | iron-tide-miner-production-final-20261020/reports |

环境：Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti；无服务、端口、数据库依赖。
每个运行使用隔离工程及 `CodexIronTideValidation/<唯一ID>` 用户目录，
源目录运行前后指纹均稳定。最终再次逐文件核对：业务脚本、数据和资源与全部通过运行一致；
八项其它专项与现版唯一差异为未被它们加载的 `tests/harvester_regression.gd`
（添加固定种子、阶段日志及有界截图等待）。两个最终矿车运行与现版已登记源文件完全一致。
运行目录已完成编辑器导入，无脚本错误；Node 管线语法与资源引用检查通过。
headless 退出仍有 ObjectDB 泄漏警告（矿车 4 个、寻路/模式 2 个），不宣称已解决资源释放问题。
原玩家存档仅在最后导入前后核对，本区间哈希未变，不据此推断整轮玩家存档未改变。
最终环境审计、导入日志与备份在 `C:\Users\admin\Temp\iron-tide-miner-recovery-20261020\`。

## 2026-10-20：补齐 12 个生产与选中图标

按画面清单 V01 继续：`JUMPJET / CARRIER / DEST / AEGIS / LCRF / SHAD / DLPH /
ORCA / BEAG / GAYARD / GACSPH / GAWEAT` 的原数据已有 Cameo 名称，
本地 `CAMEO.MIX` 也含对应 SHP，但启动工程没有这些 PNG，目录艺术索引为空。
使用本地 `CAMEO.PAL` 解码第一帧，恢复 12 张 60×48 PNG；不借用其它身份素材。
`CDEST / GACNST` 源数据未指定 Cameo，继续保留占位；历史/扩展条目本轮不扩展。
总图标占位从 29 降为 17（其中 RA2 目录只剩上述 2 个）。

新增 `ra2pipe/cameo_restore.mjs` 支持 `IRON_TIDE_PROJECT` 隔离候选：
先完整读取并校验所有所需素材，再写图片及当前目录的 cameo 字段；
`assets/ra2/cameo/restoration.json` 保留来源、调色板、尺寸及源/PNG SHA-256。
再次运行恢复工具没有新增项，目录/来源记录字节未变。
复制前逐字段核对 `ra2_allied.json`：只新增 12 个 cameo 路径，原有其它字段完全一致，
未改玩法数值、生产规则或运行时脚本。已有导出器按原 Cameo 名称可重建这些图标。

验证：

| 专项 | 结果 | 报告 |
|---|---|---|
| cameo_regression，`-Render -FreshImport` | 444 项通过 | `C:\Users\admin\Temp\iron-tide-cameo-final-20261020\reports` |
| hud_layout_regression，`-Render` | 232 项通过 | `C:\Users\admin\Temp\iron-tide-cameo-layout-20261020\reports` |

第一项包含既有选择/输入/身份回归，再核对 12 个条目的映射、真实生产卡与选中条，
9 个单位的详情头像和实际生产者队列；未映射条目仍走原回退。
两模式都生成 12 图标总览供检查；布局覆盖 1280×720、1600×900、1920×1080、2560×1440。
全新缓存导入通过，原启动目录编辑器导入通过；1873 个导入描述无缺文件，资源引用无缺失。
用户随后明确确认：**“正常，图标清楚且对应正确”**，本批 12 个图标的表现验收通过。
这不代替其它建筑动画、战斗表现或矿场制造按钮的待体验确认。

环境为 Windows / Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti；
测试用独立工程及唯一 `CodexIronTideValidation` 用户目录，无服务、端口、数据库依赖。
两次运行前后源文件指纹一致。候选、原目录备份、来源报告及最终导入日志位于
`C:\Users\admin\Temp\iron-tide-cameo-recovery-20261020\`。

## 巨炮/爱国者转向与炮口 · 2026-10-20

修前第一偏离点：`BuildingTurretArt.draw()` 在绘制时把朝向直接改到目标，
但建筑发射逻辑只检查射程/冷却，炮口位置取建筑半径的 0.8 倍。
新增真实场景专项在两个模式复现 8/8 失败：目标位于侧面时，朝向尚未改变就产生弹体并消耗冷却。
证据：`C:\Users\admin\Temp\iron-tide-defense-fire-before-20261020\reports`。

现在由建筑 tick 推进共享炮塔朝向，绘制只读取；与目标误差不超过 2° 才允许发射，
成功发射后再启动冷却。GTGCAN 使用原数据 ROT=1，沿用本工程已有 15 Hz/256 阶换算为
21.09375°/s；NASAM 源数据省略 ROT，明确使用本工程缺省 ROT=8，即 168.75°/s，
该缺省不是已证实的原版数值。掉电、展开中、无目标时保持原停机规则。
目标失效、死亡、同阵营、超射程或低于最小射程均拒绝发射；NASAM 的 LandTargeting=1
接入对地过滤。原武器伤害、射程数值、射速、费用及模式边界未调整。

`ra2pipe/defense_art.mjs --anchors-only` 从现有 VXL 前端体素导出 32 方向炮口锚点：
巨炮取 GTGCANBARL 前端，SAM 取一侧发射舱，避免两舱间隙。
运行时沿用当前健康/受损底座锚点和炮塔帧投影，将像素坐标换回世界坐标，
弹体、火光和开火音效共用该起点。PNG 未重做；独立候选重导出与实际两份 JSON 字节相同。
模型点和来源保存在对应 `assets/ra2/bldturret/*.json`，普通完整导出同样生成锚点。
后坐力尚未实现，当前合成炮塔/炮管图集需要继续拆分或增加回缩帧。

| 专项 | 结果 | 报告目录（均在 `C:\Users\admin\Temp\` 下） |
|---|---|---|
| defense_fire_regression，Render | 708/708 | `iron-tide-defense-fire-first-20261020\reports` |
| defense_fire_regression，headless | 708/708 | `iron-tide-defense-fire-headless-20261020\reports` |
| defense_art_regression，Render | 468/468 | `iron-tide-defense-art-aim-20261020\reports` |
| hit_structure_regression，Render | 126/126 | `iron-tide-defense-hit-20261020\reports` |
| rules_mode_regression，headless | 83/83 | `iron-tide-defense-aim-rules-20261020\reports` |

入口：`iron_tide/tests/run-navigation-building.ps1 -Suite <上述专项> [-Render] -RunRoot <新的外部路径>`。
新增专项使用真实 battle、Building tick、Projectile 飞行/爆炸；只暂停其它演员并显式推进时间。
覆盖双方/两模式、逐帧转速上限、跨 ±180° 最短转向、对准前无弹体/不扣冷却、
一次发射/一次命中（巨炮 150、SAM 75）、同阵营不受伤、掉电和非法目标、
绘制不改变朝向、健康/受损两态各 32 朝向的独立体素投影对照。
原炮塔专项继续验证点击掩码、缩放、放置预览和展开状态。

五组运行前后源码/资源指纹均一致、退出码 0、无 SCRIPT ERROR / ERROR。
环境：Windows / Godot 4.7.2，渲染使用 OpenGL Compatibility / RTX 5060 Ti；
固定 60 FPS、独立副本和唯一 custom_user_dir，无网络、端口、数据库或服务依赖。
headless 新专项退出有 23 个 ObjectDB 残留警告，规则专项有 2 个，渲染专项未见；
此退出清理问题尚未单独定位，不能据此宣称无任何引擎警告。
备份与锚点候选：`C:\Users\admin\Temp\iron-tide-defense-fire-recovery-20261020\`。

已检查巨炮/SAM 发射截图；用户对“转向后开火”和“火光/弹体贴炮口”的选择题均回复
**“暂时没测试”**，两项继续保持 `pending_user_visual_confirmation`。
当前启动脚本直接加载本目录；重启 `C:\Users\admin\IronTide\iron_tide\启动游戏.bat` 即使用本批修改。

## 巨炮后坐与单位发射时机 · 2026-10-20

单位首个偏离点是 `_physics_process` 在 `_limit_turn` 前调用发射，
`_try_fire_ready` 又直接把瞄准方向改到目标；连发后续弹只验证实例存在。
真实 MTNK/FV 场景在两模式复现 8/8 失败，报告：
`C:\Users\admin\Temp\iron-tide-unit-fire-before2-20261020\reports`。
更早一次夹具把物理体禁用而产生 body space 错误，未作为有效复现；
完整专项也曾误保留敌方出生自带的进攻移动指令，现使用真实 `order_stop()` 固定射手。

当前先推进原有转向限速，再判断发射，带炮塔的单位误差在 2° 内才开火。
炮口方向读取限速后的姿态。新连发首弹当帧不再扣减后续弹间隔；
后续弹重新检查目标身份、血量、阵营、距离、停火/维修状态。
目标更换或失效则取消剩余连发，保留已开始的冷却；同一目标仍有效但需转向时暂停发射，
对准后续发一次。未修改单位移动速度、转速、伤害、武器冷却数值或矿车采矿实现。
明确验证范围为 MTNK、SREF、FV 的两阵营/两模式；MGTK 源数据 `move.turret=false`，
虽然存在独立炮塔素材，但其固定武器/车体朝向还需单独核对，未把它计入本批转向通过范围。

巨炮增加一张 8 个回缩位置 × 32 朝向的图集。导出器只沿模型 -X 移动炮管，
与不动的炮塔一起深度排序，原静止 PNG 保持不变。运行时读取当前姿态的锚点、炮口、
像素点击掩码；结束后回到原图。局部配置 3/3/40 帧按已有 15 Hz 换算为
0.2 秒回缩、0.2 秒停留、约 2.67 秒复位。BarrelTravel=8 在此软件渲染器中作为
8 个模型单位使用，尚未宣称与原引擎所有比例/时间量化完全等价。

资源重建：设置本地 `RA2_MIX_DIR` 与候选 `IRON_TIDE_PROJECT` 后运行
`node ra2pipe/defense_art.mjs --recoil-only`；完整导出同样包含后坐图集。
独立候选重建的 PNG/JSON 与实际文件 SHA-256 一致；两个导出模块通过 Node 语法检查。
实际启动目录完成 Godot 编辑器导入，无脚本/资源错误。

| 专项 | 结果 | 报告目录（均在 `C:\Users\admin\Temp\` 下） |
|---|---|---|
| recoil_regression，Render / FreshImport | 1092/1092 | `iron-tide-recoil-first-20261020\reports` |
| unit_fire_regression，headless | 188/188 | `iron-tide-unit-fire-final-20261020\reports` |
| defense_fire_regression，Render | 708/708 | `iron-tide-recoil-defense-fire-20261020\reports` |
| harvester_regression，headless | 66/66 | `iron-tide-recoil-harvester-20261020\reports` |
| defense_art_regression，Render | 468/468 | `iron-tide-recoil-defense-art-20261020\reports` |

入口仍为 `iron_tide/tests/run-navigation-building.ps1 -Suite <专项> [-Render] [-FreshImport] -RunRoot <新的外部路径>`。
累计 2522 项：后坐分阶段/各方向像素点击、炮座与占地不动、复位回原图；
真实单位 physics tick、转速限制、第一次开火、FV 双发完整间隔、逐发目标检查，
原重甲伤害 MTNK 65、SREF 50、FV 双发 16；真实 Projectile 飞行/爆炸负责命中。
另外覆盖上批防御塔逻辑和矿车真实往返、矿场制造、预览及点击。
渲染截图检查了巨炮原位/回缩/复位；截图夹具冻结其它演员及效果，
它们是姿态对照，不能代替玩家动态体验。

环境：Windows / Godot 4.7.2，渲染 OpenGL Compatibility / RTX 5060 Ti；
固定 60 FPS、独立工程及唯一 custom_user_dir，无网络、端口、数据库依赖。
五组均退出 0，无 SCRIPT ERROR / ERROR；headless 单位专项退出有 73 个 ObjectDB 残留警告，
矿车专项有 4 个，尚未定位该测试退出清理问题；三个渲染专项未见此警告。
各次运行前后源指纹一致，最终重新核对五组的运行时代码/资源均匹配当前启动目录。
备份、候选、实际导入日志及 `delivery-audit.json`：
`C:\Users\admin\Temp\iron-tide-recoil-recovery-20261020\`。

用户对“巨炮炮管回缩/复位”和“单位转好炮塔后开火/连发”两道选择题均回复
**“暂时没测试”**，本批继续为 `pending_user_visual_confirmation`。

## 固定武器朝向、车辆炮口与炮塔点击 · 2026-10-20

用户授权直接推进后续工作，不再逐批提问。此批修正以下路径：

- 幻影、坦克杀手原先只更新瞄准方向，车体保持不动即可向侧面开火。
  修前真实场景 40 项中 24 项失败，两种模式、双方均可复现：
  `C:\Users\admin\Temp\iron-tide-unit-muzzle-before-20261020\reports`。
  现在 RA2 地面固定武器使用车体朝向和原有 ROT；对准 2° 内才发射。
  普通移动保持行驶方向，进攻移动可停止瞄准；空军、海军、矿车不接入此车体门槛。
- 灰熊/FV/光棱/幻影/坦克杀手本地模型前端为 +X，既有取帧约定为 -X。
  五种车的主体及四张独立炮塔元数据加入半圈偏移，原始 `move.turret` 不变。
  幻影虽有分离素材，仍随车体一起转；灰熊/FV/光棱保留独立炮塔。
- 从本地 VXL 几何导出炮管前端、导弹发射器前端或光棱顶端，
  共 5 × 8 个炮口坐标；火光、光束、弹体及音效共用该坐标。
  炮塔点击采用真实绘制矩形和已缓存的图像 alpha，与主体取并集。
- 初次渲染检查发现坦克杀手原 PNG 为 818×53，
  描述文件的 100×53 帧加边距实际需要 818×57；部分源矩形越界。
  仅重建该车主体/阴影两张 PNG，保持帧描述和其它车辆 PNG。
  初次渲染结果含失败及越界错误，未计入通过证据。

`ra2pipe/unit_muzzles.mjs` 校验模型重建画布、现有元数据与 PNG 尺寸后才写入锚点。
完整 VXL 导出已接入该步骤。单独使用时，设置本地 `RA2_MIX_DIR` 与候选工程
`IRON_TIDE_PROJECT`，执行 `node ra2pipe/unit_muzzles.mjs`；
历史坦克杀手图集修复需显式增加 `--repair-tank-destroyer`，候选确认后只复制对应文件。
本批候选 16 个输出与实际文件逐字节一致，两个 Node 模块通过语法检查，
实际启动目录已完成 Godot 编辑器导入，无脚本/资源错误。

| 专项 | 结果 | 报告目录（位于 `C:\Users\admin\Temp\`） |
|---|---|---|
| unit_muzzle_regression，Render | 628/628 | `iron-tide-unit-muzzle-render2-20261020\reports` |
| unit_fire_regression，headless | 188/188 | `iron-tide-unit-muzzle-fire-20261020\reports` |
| harvester_regression，headless | 66/66 | `iron-tide-unit-muzzle-harvest-20261020\reports` |
| selection_regression，Render | 176/176 | `iron-tide-unit-muzzle-selection-20261020\reports` |
| navigation_building_regression，headless | 32/32 | `iron-tide-unit-muzzle-navigation-20261020\reports` |

累计 1090 项。新增专项覆盖固定武器真实 physics tick、转速上限、车体与武器同步、
普通移动/进攻移动、幻影 100 与坦克杀手 150 的实际重甲伤害、步兵静止瞄准、
五车八方向的独立模型投影、实际 Projectile 出生点、全帧逐像素点击与透明区域拒绝。
既有专项覆盖炮塔连发、真实采矿往返/制造、点击拖框和六坦克绕建筑到达。
内部截图检查了灰熊朝向；截图是固定姿态证据，不能替代玩家动态体验。

环境：Windows / Godot 4.7.2；渲染 OpenGL Compatibility / RTX 5060 Ti；
固定 60 FPS、独立副本与唯一 custom_user_dir，无网络/端口/数据库依赖。
五组退出码均为 0、无 SCRIPT ERROR / ERROR，运行前后指纹不变；
最终逐文件重算 SHA-256，五组报告均匹配实际启动目录。
矿车专项退出仍有 4 个 ObjectDB 残留警告，寻路专项有 2 个，属于尚未定位的退出清理问题。
备份、候选、导入日志与最终环境审计：
`C:\Users\admin\Temp\iron-tide-unit-muzzle-recovery-20261020\delivery-audit.json`。

本批表现状态为 `pending_user_visual_confirmation`，没有追加选择题或标记玩家已认可。
从 `C:\Users\admin\IronTide\iron_tide\启动游戏.bat` 重启即可加载本批修改。

## 画面、海空运输、生产经济三线整合 · 2026-10-20

用户授权“123 一起做”，沿用 Godot 独立实现、RA2/扩展模式隔离，不再追加确认问题。

本批实现：

- 重建并核对 11 套现役载具/飞机主体及阴影，补齐 DEST/CDEST 阴影并校正模型前向。
  SHAD 从本地模型的两个旋翼部件生成 4 姿态 × 8 方向图集，机身与画布稳定；
  飞机降落只降低机身，阴影保留在地面。ORCA/BEAG/HORNET 使用模型前端发射点，
  受转向限速与对准门槛约束。旋翼周期、飞机发射挂点是本工程适配，未宣称原版 HVA/FLH 精确等价。
- 新增 `UnitLogistics`：LCRF/SHAD 真实乘员装载、体积/容量检查、隐藏碰撞与独立受击、
  安全卸载及载具损毁处理。两栖网格接入 A*、编队槽位与不可达目标吸附，
  玩家命令也能跨岸。选中乘员右键载具登载，选中载具用 D 卸载。
- ORCA/BEAG 每轮连发消耗一份弹药，打完自动返场；每座机场四个停机位，生产订单也占容量。
  返场预留独立泊位、落地补弹、停电暂停、机场损毁改降；General.ReloadRate 导出为补弹计时。
  D 可主动返场。航母实际派出三架 HORNET，真实投弹伤害、回到移动母舰、甲板补弹和损失重建；
  航母武器不再直接造成代替舰载机的伤害。
- 敌我拥有独立资金与电力；盟军 AI 真实采矿回款、按工厂付费生产、科技先决检查、
  缺钱暂停、取消按实付退款、补矿车及付费扩建。已排队矿车在所有矿场间统一计数。
  扩展虫群仍保留历史孵化收入与刷兵规则。

修前/中间失败保留：

- 初次海空专项 126 项中 4 项失败：矿场的卸货泊位误计为机场容量，已按 Helipad/UnitReload 筛选。
- 移动母舰夹具原先同时下达集火和移动，集火按现行行为停车；改为出击后下达实际移动，
  新增母舰实际位移断言，回收过程仍沿真实物理移动。
- 扩展矿车测试首次暴露敌方出生矿车没有绑定生产矿场，导致空引用并污染后续场景；
  统一出生矿场绑定，夹具增加非空断言和失败清理，重新独立运行通过。
- 玩家编队目标分配原先仍使用纯海军网格，会把两栖艇陆地目标吸回水域；
  修改真实命令入口并加入陆地终点与实际跨岸断言。
- 旧防御塔测试用玩家停电模拟敌方停电，与本批独立电网冲突；改为所属方电网，
  保留停电冻结断言，新增对方停电不影响本方断言。运行时未因此退回共用电力。

最终回归全部使用当前实际启动目录的源码/资源、隔离工程和独立用户目录：

| 专项 | 通过断言 | 渲染 |
|---|---:|---|
| economy_ai_regression | 50 | headless |
| logistics_regression | 142 | headless |
| harvester_regression | 78 | headless |
| navigation_building_regression | 32 | headless |
| production_status_regression | 60 | headless |
| building_exit_regression | 66 | headless |
| batch_rally_regression | 38 | headless |
| unit_art_regression | 910 | OpenGL |
| unit_muzzle_regression | 922 | OpenGL |
| selection_regression | 176 | OpenGL |
| rules_mode_regression | 83 | headless |
| unit_fire_regression | 188 | headless |
| hit_structure_regression | 114 | headless |
| defense_fire_regression | 716 | headless |

共 **3575 项通过**。报告位于
`C:\Users\admin\Temp\iron-tide-123-<专项名>-delivery-20261020\reports`，
只有防御塔最终复跑为 `iron-tide-123-defense_fire_regression-final-20261020\reports`。
每次运行前后源指纹相同；交付前重算 4634 个运行时文件及各专项实际使用的测试继承链，
14 份报告均与当前版本匹配。48 个候选资源/元数据文件与实际目录逐字节一致。
四个 Node 导出模块语法检查、实际 Godot 编辑器导入通过；资源检查引用缺失 0、载具阴影占位 0。

环境：Windows、Godot 4.7.2、固定 60 FPS；渲染使用 OpenGL Compatibility / RTX 5060 Ti。
网络、端口、数据库为 none；回归使用每轮独立 custom_user_dir，未使用玩家实际存档目录。
最终 14 组均退出 0、无 SCRIPT ERROR/ERROR；部分 headless 进程退出仍有 ObjectDB 残留警告，
计数记录在交付审计中，清理来源尚未定位，不把此项描述为已解决。
备份、素材候选、导入日志、资源盘点与最终审计：
`C:\Users\admin\Temp\iron-tide-combined-123-20261020\delivery-audit.json`。

仍待后续：海豚完整动作、其余精确武器挂点与单位后坐力、复杂进场航线/精确停机坪、
反潜与潜浮、国家/苏军科技及更完整的 AI 战略。15 个历史/扩展主体、17 个图标占位保留。
本批没有把这些剩余差异标成完成。新增表现维持 `pending_user_visual_confirmation`；
用户已要求不再逐项提问，故只记录状态。关闭旧游戏后从原 `启动游戏.bat` 重开即可加载，
无需另行导出可执行文件。

## 海豚动作、声波表现与海军目标筛选 · 2026-10-20

本批接着处理画面/海空清单，未新增确认问题。原始 DLPH.SHP 中已有 116 个可见帧，
但没有序列表，运行时把前 8 个游动帧当成 8 个待机方向。另一个第一偏离点是单位目标筛选
只判断 AA，没有消费 MedusaProjectile 的 `AG=no`，导致神盾舰可向地面、水面和停靠飞机开火。
修前真实场景专项 278 项中 158 项失败，证据在
`C:\Users\admin\Temp\iron-tide-naval-before-20261020\reports`。

- 根据本地图片逐帧核对接入 DLPH 的游动 0–47、待机 48–55、攻击 56–103、死亡 104–115。
  导出器检查本地 art.ini 的 WalkFrames/FiringFrames 和总帧数，源布局改变时明确失败。
  使用海豚素材的屏幕北向起始顺时针朝向，待机锚点保持游动/攻击期间稳定。
- 攻击动画独立于短暂炮口闪光计时，每次发射从首帧播放完整 6 帧；死亡从首帧播放完整 12 帧再回收。
  首轮修后最后死亡帧出现浮点边界误差，加入取帧微小容差后通过。
  八方向声波起点由对应攻击首帧的前端轮廓求得并缓存，弹体和声音使用同一起点。
- IsSonic 接入独立波纹绘制，保留现有弹体速度、伤害、命中结算。
  尚未接入原版穿透和 AmbientDamage 行为，不能把本批声波表现视为完整声波武器复刻。
- 自动索敌和逐发发射共用目标类型检查：AG=no 拒绝非空中目标；
  LandTargeting=1 排除非海军地面对象。神盾只对空，海豚排除陆军与飞机。
  海豚固定武器随身体转向，对准后发射；扩展模式和 RA2 模式分别覆盖双方。

| 专项 | 最终通过 |
|---|---:|
| naval_regression，Render | 354 |
| unit_art_regression，Render | 910 |
| unit_muzzle_regression，Render | 922 |
| unit_fire_regression | 188 |
| logistics_regression | 142 |
| hit_structure_regression | 114 |
| defense_fire_regression | 716 |

共 **3346 项断言通过**。新增专项覆盖自动目标选择、显式攻击拒绝及不消耗冷却、
可攻击对象的实际弹体扣血、声波标记、全部动作帧、稳定锚点、待机/游动像素点击、
八方向嘴部轮廓、完整死亡播放和对象回收。已查看内部冻结场景截图，不以截图替代玩家动态体验。
海军专项报告为 `C:\Users\admin\Temp\iron-tide-naval-mouth-20261020\reports`；
其余为 `C:\Users\admin\Temp\iron-tide-naval-<专项名>-delivery-20261020\reports`。

环境为 Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility；固定 60 FPS，
每轮使用独立工程与 custom_user_dir；网络、端口、数据库均为 none。
运行前后指纹相同，交付审计重新核对当前运行时文件和实际测试继承链；
实际启动目录编辑器导入及两个 Node 导出模块语法检查通过。
部分 headless 退出仍有 ObjectDB 残留警告，保留在审计中，未宣称已处理清理问题。
备份、导入日志与审计位于 `C:\Users\admin\Temp\iron-tide-naval-20261020\`。
表现状态继续为 `pending_user_visual_confirmation`。原启动入口重开即可生效。

## 2026-10-20 海豚声波穿透与沿途伤害

第一偏离点在 `Projectile._physics_process`：IsSonic 原先仅改变绘制，
仍走普通追踪弹的终点爆炸路径，原始武器的 AmbientDamage 完全未被消费。
新增真实战场专项修前 416 项中 212 项失败；不是编译错误。

本批独立实现：

- 原始 SonicZap/SonicZapE 的 AmbientDamage 分别为 10/15，使用实际发射武器的弹头和数值。
  声波不额外叠加普通 Damage 终点爆炸。语义依据为本地 rules.ini 及 Ares 作者文档：
  [沿途伤害](https://ares-developers.github.io/Ares-docs/new/weapons/waves.html)、
  [普通伤害例外](https://ares-developers.github.io/Ares-docs/new/weapons/damage.html)、
  [实际发射武器取值](https://ares-developers.github.io/Ares-docs/bugfixes/type2/sonicwaveambientdamage.html)。
  未读取或翻译 Chrono Divide 派生实现。
- Godot 适配合同：初始方向固定；20 次脉冲，15 Hz；传播前沿匀速到武器射程，
  本地海豚为 6 格/330 世界像素；半宽 14 世界像素，目标以现有 radius 圆形体积参与。
  每次脉冲对当前已覆盖走廊内的目标各结算一次；目标离开后停止受伤。
  近处目标因此承受更多脉冲。补步保留逐次护甲、防御、取整、死亡和击杀结算，
  但不重建大帧期间目标的运动历史。
- 沿途异型友军可受伤；同阵营同型 TypeImmune 海豚受保护；尊重 AffectsAllies=no。
  排除发射者、空中单位、舱内单位、死亡/待删除对象，落地飞机允许受到沿途伤害。
  海豚主动索敌仍受上一批 LandTargeting 限制，误伤判定与主动选敌分别处理。
- 攻击加成使用发射快照；原目标或发射者被删除后波仍沿原方向继续。
  不保留发射者强引用；敌方击杀给存活发射者经验，友军误伤不给经验。
  波纹前沿和淡色传播路径均由真实声波状态绘制。
- 波宽、路径、传播节奏和圆形体积属于本工程独立适配，不能据此宣称原 EXE 逐帧复刻；
  潜浮/探测、墙体阻挡和原版精确几何尚未完成。

| 最终专项 | 通过断言 |
|---|---:|
| sonic_regression，Render | 464 |
| naval_regression，Render | 354 |
| unit_fire_regression | 188 |
| defense_fire_regression | 716 |
| hit_structure_regression，Render | 126 |
| logistics_regression | 142 |

共 **1990 项断言通过**。声波专项覆盖双模式/双方、普通与精英武器，
15/60/144 Hz 与一次 2 秒推进、前后排列目标、离轴/射程外/背后对象、波宽边界、
圆形船体、建筑护甲、重复分组去重、空中/落地/装载、误伤与同型保护、
攻击/防御各应用一次、目标离开、删除发射者/目标、敌我击杀经验、
AffectsAllies=no、AmbientDamage=0 和结束后不再扣血。
首轮修后剩余 4 项失败是精英升级改变测试发射者 HP，而测试错误假定仍为 10000；
改为记录升级后的发射前 HP 后通过，未以修改业务血量绕过断言。

各报告位于 `C:\Users\admin\Temp\iron-tide-sonic-<专项名>-delivery-20261020\reports`。
备份、修前/首轮输出、最终控制台输出、启动目录导入日志及 `delivery-audit.json`
位于 `C:\Users\admin\Temp\iron-tide-sonic-20261020\`。
实际声波截图为 sonic_regression 报告中的 `ra2-sonic-corridor.png`，
已人工检查波纹和传播路径；这是冻结角色的渲染夹具，不代表真实水域行军体验。

环境：Windows、Godot 4.7.2、RTX 5060 Ti/OpenGL Compatibility；固定 60 FPS，
专项显式按各测试步长调用真实弹体；六轮分别使用隔离工程和 custom_user_dir；
网络、端口、数据库均为 none。运行前后源指纹相同，最终审计核对当前全部运行时文件
及各测试继承链，均匹配；测试 Godot 进程已结束。
实际启动目录编辑器导入成功，导入前后真实用户存档哈希相同。
unit_fire / defense_fire / logistics 的控制台分别仍有 69 / 23 / 26 个 ObjectDB
退出残留警告；这些警告并未被 Godot 的 log-file 收录，审计使用保留的控制台日志，
不把它们算作已修复。
波纹与体验状态为 `pending_user_visual_confirmation`；按用户要求不弹确认题。
从原 `启动游戏.bat` 重开即加载本次源码，无需另行导出。

## 2026-10-20 镜头滚屏、跟随与输入手势

本批对应 C04/C05/C06。第一偏离点：
`edge_pan_dir` 原先在单边两端 300px 范围强制附加斜向分量，且视口外仍返回滚屏方向；
`_update_camera` 在处理手动输入前直接返回跟随分支，并未检查文字输入焦点或 HUD 鼠标归属；
中键和右键共用布尔拖图状态，无起始按键归属，也没有窗口失焦/暂停的手势清理。

修改范围为 `battle.gd`、`minimap.gd`、HUD 的暂停入口：

- 保留原滚屏速度、4px 触发带和 7px 拖拽阈值；只有同时碰到两条边才斜滚。
  视口外不滚屏；鼠标由 HUD 控件接管时不触发贴边滚屏。
- 方向键和小地图/手动定位解除跟随，避免下一帧弹回原单位；
  LineEdit/TextEdit 焦点阻止方向键驱动镜头。
- 按下中键或右键后，由起始按键独占拖图手势，异键松开不打断、不下令。
  鼠标移动事件已不包含所属按键时回收拖图状态，处理丢失松开事件。
- 实际 Window 焦点离开信号、暂停通知和 HUD 暂停入口清理框选、拖图及小地图手势；
  失焦和暂停期间拒绝新的世界鼠标输入与镜头更新。恢复后的旧松开事件不补发命令。
  保留建筑就绪库存、已选对象、武装指令以及正常右键下令的语义。

新增 `camera_input_regression` 使用真实 battle/HUD 与 Viewport 鼠标派发，
覆盖 RA2/扩展两种模式、三档视口方向边界、HUD 归属、文字焦点、解除跟随、
中右键混按、缺失松开、暂停/恢复及焦点信号。键盘用 Input.action_press/release
驱动生产代码的轮询入口；焦点用实际 Window 信号注入，没有自动操作操作系统 Alt-Tab。
初轮测试把 HUD 外侧留白当成控件、并复用了滚屏前位置，修正夹具后重新在旧版副本复跑：
同一套 **130 项，旧版 84 项失败，修后全部通过**。旧版三个运行时文件与修前备份哈希一致，
新旧使用完全相同的最终测试文件；不以早期有夹具错误的结果作为最终修前基线。

| 最终专项（均 Render） | 通过断言 |
|---|---:|
| camera_input_regression | 130 |
| input_ownership_regression，含选择继承链 | 272 |
| minimap_regression | 61 |
| batch_rally_regression | 40 |
| building_preview_regression | 276 |

共 **779 项断言通过**。镜头专项报告：
`C:\Users\admin\Temp\iron-tide-camera-final-20261020\reports`；
旧版复核：`C:\Users\admin\Temp\iron-tide-camera-baseline-verified-20261020\reports`；
其它报告：`C:\Users\admin\Temp\iron-tide-camera-<专项名>-delivery-20261020\reports`。
备份、控制台日志、实际启动目录导入结果及 `delivery-audit.json`：
`C:\Users\admin\Temp\iron-tide-camera-20261020\`。

环境为 Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS。
各轮采用独立工程和 custom_user_dir；网络、端口、数据库为 none。
五轮运行前后源指纹一致，最终核对当前运行时及测试继承链均匹配；
测试 Godot 进程已退出，实际启动目录编辑器导入成功，导入前后真实用户存档哈希一致。
本批五轮控制台无 SCRIPT ERROR、ERROR 或 WARNING；这不代表前批 headless ObjectDB 警告已修复。
镜头速度舒适度、实际窗口切换和动态手感仍为 `pending_user_visual_confirmation`，
按用户要求不追加确认题。原启动脚本重开生效。

## 2026-10-20 围墙连接、损伤层与拆毁后的通行

第一偏离点：普通建筑渲染把 GAWALL/GASAND 的帧 0/1/2 当成三档血量，
实际本地 SHP 每 16 帧是一组邻接形态，损伤组位于其后，阴影从第 48 帧开始。
原来的损伤锚点随帧改变，围墙占地又由孤立柱子的图像反推，不能稳定对齐 40 单位建造网格。
此外建筑死亡没有刷新寻路网格，已清空的占地继续阻挡移动。

- 新增独立 WallArt 适配器；本地 art.ini 的 DamageLevels 指定 GAWALL 三层、
  GASAND 两层。16 种邻接变体与损伤层分别计算，使用对应原有阴影。
  只连接同阵营、同材质、相隔一个网格的正交邻居；排除死亡、待删除和施工中的建筑。
- 墙体、放置预览和像素点击共用健康帧锚点与缩放，40×40 占地直接供放置、碰撞和寻路使用。
  新邻居落成、施工完成、死亡或移出场景后自动刷新相邻段。
- 建筑死亡通过原有事件入口延迟合并刷新通行网格，排除死亡/待删除建筑。
  多座同帧拆毁只重建一次，存活建筑保持阻挡；出售共用原有 `_die` 入口。
- SHP 导出器补充围墙布局元数据，从本地 art.ini 读取损伤层并校验帧数。
  本批只更新 GAWALL/GASAND 的 JSON，不改 PNG；辅助函数校验七张现存围墙图集，
  覆盖无围墙定义及非法帧布局，Node 语法检查通过。未执行全量素材重新导出。

初版专项 **920 项，修前 514 项失败，首轮修后 920 项通过**。
之后增加敌方连接、直接移除、施工完成、建筑死亡释放障碍和同帧合并刷新等边界，
最终专项 **936 项通过**。修前工程运行时文件与备份逐项哈希一致；
初版基线与最终增加断言的夹具分开记录，不冒充完全相同的测试集合。

| 最终专项 | 通过断言 |
|---|---:|
| wall_regression，Render | 936 |
| navigation_building_regression | 32 |
| building_preview_regression，Render | 276 |
| building_animation_regression，Render | 246 |
| hit_structure_regression，Render | 126 |
| logistics_regression | 142 |

共 **1758 项断言通过**。围墙覆盖 RA2/扩展模式、两种墙体全部 16 种连接形态、
三档血量、固定锚点、透明像素选择、真实碰撞、合法相邻放置与就绪库存消费。
已检查实际渲染器输出的预览和十字连接截图；夹具冻结角色并手动推进必要过程，
不代表玩家动态建造体验已确认。

专项报告：`C:\Users\admin\Temp\iron-tide-wall-final-20261020\reports`；
修前基线：`C:\Users\admin\Temp\iron-tide-wall-before-20261020\reports`；
其它回归：`C:\Users\admin\Temp\iron-tide-wall-<专项名>-delivery-20261020\reports`。
备份、控制台日志、导出器检查、启动目录导入与 `delivery-audit.json`：
`C:\Users\admin\Temp\iron-tide-wall-20261020\`。

环境：Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS。
六轮分别使用隔离工程和 custom_user_dir；网络、端口、数据库为 none。
前后源指纹一致，最终审计核对当前全部运行时文件和每个测试的继承链均匹配。
实际启动目录编辑器导入成功，导入前后真实存档哈希一致；
本批六轮控制台没有 SCRIPT ERROR、ERROR 或 WARNING，不据此宣称历史 ObjectDB 问题已修复。

连接方向及缩放只在默认 45°、2:1 投影下验证；其它开发投影预设、拖线连续建墙、
原版 Selectable/Repairable 等完整围墙规则不在本批范围，保留现有选择、出售和生产语义。
表现保持 `pending_user_visual_confirmation`，按用户要求不弹确认题。
从原 `启动游戏.bat` 重开即可加载。

## 2026-10-20 不可生产原因与侧栏一致性

用户截图显示 7600 资金，点击 900 造价的坦克杀手却提示资金不足，用户要求不能建造时说明原因。
独立真实场景复现发现：TNKD 的本地前置为 GAWEAP + RADAR，截图对应缺少空指部。
HUD `_unit_state` 只检查是否有可生产建筑，不检查入队所需前置；
`_queue` 将非队列满的所有入队失败归类为资金不足。HUD 的旧建筑集合还包含施工建筑，
并无条件补入建造厂，与实际科技判定来源不同。

修复范围为 Building、HUD、GameData 的前置名称格式化和 battle 的建筑拒绝说明：

- `queue_block_reason` 与实际 `enqueue` 共用判断，区分建筑被摧毁、施工中、
  不支持该单位、具体科技前置、停机位已满、矿场停工、生产队列已满。
  保留原入队边界、价格、科技前置、分期付款和容量；普通工厂缺电仍允许排队，
  运行状态由原有队列状态栏说明，没有增加必须通电才能排队的规则。
- 侧栏原地更新真实原因，完整提示可悬停查看；禁用按钮的鼠标点击与快捷键都输出原因。
  前置集合使用 battle 的存活且已建成建筑，不再用 UI 独立推测。
  资金不足说明需要、现有、差额；鼠标长按期间状态变化时也重新检查原有资金门槛。
  批量只能加入部分时说明加入数量及中止原因，费用仍随进度扣除。
- 原有生产队列失去前置后，显示缺失建筑并取消虚假的剩余时间；
  飞机在机场容量减少后显示停机位不足。建筑页与直接建造菜单均列明前置名称。
  按钮布局、名称、价格和科技表不改；长原因在紧凑卡片内可能裁切，悬停及点击日志保留全文。

初版 44 项中修前 30 项失败。首轮修后剩余 2 项是测试把新施工建筑触发的
“活跃生产建筑切换”也要求保持按钮身份；改为在活跃建筑不变、仅资金原因变化时检查身份，
没有删除此断言。最终补充部分批量、直接菜单、前置损毁后的真实停产与生产建筑缺失等边界，
56 项专项通过；初版基线和最终夹具分别保留，不声称同一套测试逐项对比。

| 最终专项 | 通过断言 |
|---|---:|
| production_reason_regression，Render | 56 |
| production_status_regression，Render | 66 |
| batch_rally_regression，Render | 40 |
| logistics_regression | 142 |
| economy_ai_regression | 50 |

合计 **354 项通过**，均覆盖 RA2/扩展模式。新专项通过真实 battle/HUD、生产入队、
Viewport 鼠标派发及快捷键入口验证，不以静态文案检查替代拒绝行为。
截图 `iron_tide-production-reasons.png` 已检查，坦克杀手显示“缺少前置：空指部”；
画面与提示易读性仍为 `pending_user_visual_confirmation`，按既有授权不再发确认题。

专项：`C:\Users\admin\Temp\iron-tide-production-reason-final-20261020\reports`；
修前：`C:\Users\admin\Temp\iron-tide-production-reason-before-20261020\reports`；
其余回归：`C:\Users\admin\Temp\iron-tide-production-reason-<专项名>-delivery-20261020\reports`。
备份、控制台、实际目录导入和 `delivery-audit.json`：
`C:\Users\admin\Temp\iron-tide-production-reason-20261020\`。

环境为 Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS，
五轮使用独立工程及 custom_user_dir；网络、端口、数据库均为 none。
源指纹前后一致，当前运行时与每个测试继承链均匹配，实际启动目录导入成功，
真实存档前后哈希一致。无 SCRIPT ERROR 或 ERROR；
AI 经济专项退出仍报告 2 个 ObjectDB 实例残留，未把该警告当成已解决。
重开原启动脚本生效，无需单独导出。

## 2026-10-20 截图碎片追查：空指部停机坪与单位显示

用户提供空指部旁紫色碎片截图，补充反馈“会移动，是单位显示残缺”。
本轮将截图能直接定位的素材问题与用户描述的移动单位问题分开：
截图这组几何形态能在 GAAIRC_A/B 原始动画和旧版独立空指部截图中对应，
本地 art.ini 明确指定 `BibShape=GAAIRCBB`，但 GAAIRC 导出元数据没有 bib，
PNG 也只有塔楼。这是已复现的静态建筑缺层；不能据此推断所有移动单位问题已解决。

范围：

- 使用本地 SNOW.MIX 的原始 GAAIRC.SHP（188×162，6 帧）与 GAAIRCBB.SHP
  （同画布，4 帧），沿用已有 BibShape 合成方法。每档主体及阴影分别补齐底座，
  健康帧增加 3951 个原先透明的像素；不改变原有主体非透明像素。
- scoped 导出入口 `node ra2pipe/building_foundations.mjs GAAIRC` 只写该建筑 PNG/JSON，
  默认导出列表和素材检查同时加入 GAAIRC，避免下一次遗漏。
  工厂门描述只在明确导出 GAWEAP 时重写，其它建筑资源未随本次命令重导。
- 现有绘制、放置预览、像素点击和占地直接消费补全后的同一张主体图。
  没有修改单位绘制源码、伤害规则、机场容量或返航时序。

同一份 hit_structure 夹具修前 136 项中 6 项失败，均为两种模式的空指部 bib、
原始底座取样像素透明度和点击命中；修后全部通过。独立原始取样点 `(140,125)` 在
旧主体中透明、在本地 BibShape 中不透明。已检查修前/修后真实渲染截图，
停机坪灯在修后落于完整底座上。

另加 `unit_composition_regression`，以紫色房色启用真实着色器，复用单位模型专项，
覆盖灰熊、步兵车、光棱、幻影、坦克杀手、入侵者、黑鹰、舰载机的八朝向、
车体与独立炮塔像素点击、炮口和实际弹体入口，以及原有固定武器转向检查。
本轮没有复现所述移动单位残缺；该反馈仍待具体单位信息，不是“自动通过即关闭”。
此专项首轮在两张单位截图后无进展，停止了已核实属于本轮隔离项目的 Godot 进程；
保留失败目录，原因尚未确定。增加逐朝向进度记录及 60 秒无断言进展退出保护后，
在新隔离目录重跑通过。没有删除原模型/点击断言，也没有以首轮部分截图充当通过证据。

| 最终专项 | 通过断言 |
|---|---:|
| hit_structure_regression，Render | 136 |
| unit_composition_regression，Render | 922 |
| building_preview_regression，Render | 276 |
| logistics_regression | 142 |

合计 **1476 项通过**。当前资源检查的缺失建筑底座、独立炮塔和引用文件均为 0；
历史/扩展主体与图标占位仍保留，没有宣称全资源补齐。

修前：`C:\Users\admin\Temp\iron-tide-airport-floor-before-20261020\reports`。
最终单位专项：`C:\Users\admin\Temp\iron-tide-airport-floor-unit_composition_regression-final-20261020\reports`；
其余报告：`C:\Users\admin\Temp\iron-tide-airport-floor-<专项名>-delivery-20261020\reports`。
原素材备份、原始地板数据、控制台、素材审计、实际导入和 `delivery-audit.json`：
`C:\Users\admin\Temp\iron-tide-sprite-diagnosis-20261020\`。

环境：Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility / 固定 60 FPS；
各轮独立工程与 custom_user_dir；网络、端口、数据库均为 none。
最终四轮源指纹前后一致，当前全部运行时及对应测试继承链匹配。
实际启动目录导入成功，真实存档前后哈希相同；最终四轮控制台无脚本错误或警告。
停机坪画面为 `pending_user_visual_confirmation`；单位残缺反馈尚未复现，
两者不得混写成整体已修复。原启动脚本重开即可加载新素材。


## 2026-10-21 指定 BGM 接入

最终当前源指纹：music_regression 33/33、music_ui_regression 24/24、audio_regression 426/426，共 483 个断言通过。隔离工程导入无脚本错误；三轮源码运行前后及交付时哈希一致。Windows / Godot 4.7.2，音频采用真实 WASAPI 混音与墙钟；UI 使用 NVIDIA OpenGL Compatibility，1600×900 和 1280×720。各轮独立 custom_user_dir，网络/数据库/服务端端口均为 none。

覆盖单曲自然结束循环、场景复用、不随战斗倍速变调、音乐音量零时武器仍可闻、EVA/单位应答压低、暂停、持久化、设置控件与原有 RA2/扩展音效。音效专项仅静音 Music 总线以独立检查 SFX 退出静音；音乐专项单独采集 Music 与 Master 混音，不以停止 SFX 规避验证。UI 实际截图检查缺文件说明和重播禁用。

指定 Rock and Awe 音频尚未获得：正式清单只指向 assets/music/rock-and-awe.mp3，缺失时安静并明确提示。测试单曲使用官方 SDK MP3 fixture，不能据此声称指定曲目已安装或实际试听通过。体验状态 pending_user_visual_confirmation。

证据：C:/Users/admin/Temp/iron-tide-bgm-20261021/{rock-music,rock-ui,rock-audio}/reports；交付审计 delivery-audit.json。真实存档相较早期基线存在变化（修改时间 17:20:43，早于最终三轮测试），原因未确认，故不宣称全程存档哈希未变；未恢复或覆盖该存档，隔离测试均使用独立 user 目录。


## 2026-10-21 选中对象攻击范围

新增纯表现 AttackRangePreview：只显示己方选中作战单位/有武器建筑，青色最大射程、橙色虚线最小射程盲区，停火/维修或建筑不运行时灰色。读取 Unit.attack_range/min_range 与 Building.attack_range/weapon.min_range，采用与命中检查相同的中心距离；随移动、卧倒和精英武器刷新。非武装/矿车/搭载/死亡/已释放对象不画，建造预览与技能瞄准时隐藏，取消选择清除；多选降低线条透明度。贴地投影只应用一次，屏幕线宽固定，层级在单位/建筑下。

attack_range_regression 46/46 通过：两模式覆盖真实射程内外判定、巨炮最小射程边界、GI 实际卧倒、精英刷新、多选、取消、死亡/搭载、敌方引用排除和断电。斜视/缩放逆变换验证世界半径，1280×720 实际渲染截图已检查。没有修改武器、伤害、索敌、战争迷雾或业务状态推进；画面体验仍为 pending_user_visual_confirmation。

环境 Windows / Godot 4.7.2 / NVIDIA OpenGL Compatibility；独立工程与 custom_user_dir，端口、网络、DB 为 none。最终源指纹前后及交付时一致。证据 C:/Users/admin/Temp/iron-tide-attack-range-20261021/check-01/reports，交付审计同父目录 delivery-audit.json。原启动脚本重开即可使用。


## 2026-10-21 美国大兵卧倒攻击滑动

修前复现：真实攻击命令入口 _issue_command_at → force_attack，在卧倒状态下仍先调用 order_move（被拒绝），随后开启显式追击。_steer_dir 虽然返回零方向，apply_separation 仍叠加邻兵分离速度；move_speed=0 又使减速归零失效。拥挤场景 60 次物理更新后位移约 5.81，后续待机累计约 26.52。两模式专项 22 项中 10 项失败，保留 before-check 原始证据。

修改 force_attack：卧倒对象仅清理旧移动指令后设置攻击目标，不下达移动、不误播“需先起身”。_process_combat 对部署状态只清零速度并转向目标，开火沿用原路径；_move_water_safe 在部署状态下禁止移动，覆盖眩晕等其他调用路径。未修改武器参数、伤害、起身方式或普通单位追击。

修后 deployed_attack_regression 22/22、command_transition_regression 62/62、unit_fire_regression 188/188，共 272 项通过。覆盖选择攻击远处目标、邻兵拥挤、射程内真实投射物伤害、普通移动拒绝、巡逻/待机固定、起身追击、卧倒步兵与坦克混编。既有指令/武器专项退出时仍有 ObjectDB 释放警告（6/40），不宣称无资源泄漏；本次专项没有该警告。

Windows / Godot 4.7.2 / headless，真实物理与投射物入口，独立复制工程及 custom_user_dir，网络/DB/端口 none。三轮源码前后稳定、交付哈希一致。证据 C:/Users/admin/Temp/iron-tide-deployed-attack-20261021/{before-check,final-check,commands,firing}/reports，delivery-audit.json 位于同父目录。逻辑回归通过，目标游戏实际操作体验待用户确认。


## 2026-10-21 镜头距离导致指令语音消失

根因：_play_group_voice 将单位世界坐标传给 play_voice，选择/移动/攻击/反馈都进入 AudioStreamPlayer2D；GI 的 Range=10 × 55=550，缩小视角后仍在屏幕内的单位可远于该距离，播放调用成功但实际混音没有语音。旧音频测试只在镜头中心验证应答，未覆盖此情形。当前未检测到运行中游戏，因此这是已独立复现并修正的代码问题，不声称已观察用户当时输出设备状态。

修前通过真实 battle.select_unit/_emit_selection、_command_move 和 force_attack 复现两模式共 8 项语音输出断言失败。修改仅将 select/move/attack/feedback 应答交给既有全局播放器，保留语音节流、音量、资源、音乐避让及生命周期；部署/死亡/武器等世界事件继续空间衰减。上一轮卧倒不移动逻辑保留。

最终 command_voice_regression 36/36、audio_regression 426/426、music_regression 33/33，共 495 项通过。使用真实 WASAPI PCM 而非 play() 计数，覆盖远距离但仍在屏幕内的选择/移动/卧倒攻击应答、反馈、死亡/武器衰减、EVA 建造播报、重复命令节流、其他单位语音及音乐避让。Rock and Awe 本体仍未获得，音乐专项沿用 SDK 音频 fixture，不能视为指定曲目已装入。

环境 Windows / Godot 4.7.2 / headless + WASAPI 墙钟，独立工程和 custom_user_dir，端口/网络/DB none。各轮源码前后和交付指纹一致。证据 C:/Users/admin/Temp/iron-tide-command-voice-20261021/{before-check,final-check,audio,music}/reports；delivery-audit.json 在同父目录。实听体验 pending_user_visual_confirmation；重启原启动脚本加载。


## 2026-10-21 移动与追击手感基础整改

用户反馈整体操作手感差并要求参考 RA2 代码，继续按已确认的 Godot 独立实现路线推进。本地参考 ts-ra2 固定 898d89188542a3028a232031ce1a0bdc7c605b6f，核对 DriveLocomotor、UnitOrderTrait 的行为职责：转向/平移、路点推进、任务替换分工。该仓库不是 EA 官方 RA2 源码，LICENSE 未许可 Chrono Divide 派生代码；本次没有翻译/复制实现。

首批修改：
- 普通地面载具在大角度变向时先转车身，再沿车头方向行驶，保留导入 ROT 上限。35° 转向门槛及连续空间速度投影是本工程适配参数，不声称原版定值。炮塔瞄准不能覆盖本帧行驶所需的车身方向。矿车/海空单位排除在这项载具转向适配之外。
- 显式集火从原本直接向目标直行，改为消费实际 A* 路线；目标移动超过一格时按最短 0.35 秒刷新，沿用地形失效与卡住重算。进入射程后停稳开火，不继续带着残余速度滑行。
- 普通停车/到达后不再持续叠加邻兵分离速度。移动中的分离仍存在；原地转向不计作卡住，避让持续时间在可平移后才继续消耗。
- 长距离编队按前排优先分配纵向槽位，同排仍就近；防止前车先停在近排堵住后车。近距离重排沿用就近分配，水陆可达性与落点间距保留。

修前有效证据 before-collision：两模式侧向开动的运动/车身方向最大差约 86.48°；停止邻近未重叠单位时漂移约 1.40；60 秒隔岩壁集火未进入射程。20 辆坦克开阔地编队都能到达，但需约 37.98 秒。首个 before-check 夹具未启用障碍物物理，不能当作隔墙碰撞证据，已保留并明确排除。

修后 ground_control_regression 20/20：同例侧滑角约 0.000005°，停止不漂移，隔壁绕路约 14.93 秒进入射程，目标移动后继续追击；20 辆编队约 13.95 秒全部到达且零车体重叠。仅为固定受控场景的模拟时间，不代表全地图、50/200 单位或全部混编路况性能。

最终当前源版本：ground_control 20、navigation_building 32、command_transition 62、unit_fire 188、deployed_attack 22、miner_heading(Render) 32、naval(Render) 354、harvester 86，共 796 项断言通过。矿车往返/制造、八向朝向、舰船武器及既有步兵卧倒行为回归通过。首次无渲染矿车专项零断言不计通过；首次无渲染海军专项因渲染器缺失失败，已使用真实渲染重跑。部分专项退出有 ObjectDB 释放警告，不宣称无资源泄漏。

环境 Windows / Godot 4.7.2；逻辑专项使用真实物理/命令入口，视觉专项使用 NVIDIA OpenGL Compatibility；独立复制工程和 custom_user_dir，网络/DB/端口 none。八轮源码前后及交付指纹一致。证据 C:/Users/admin/Temp/iron-tide-control-foundation-20261021，delivery-audit.json 标明有效与排除结果。整体体验 pending_user_visual_confirmation。窄口会车/让路、更多规模混编、完整任务队列与原版逐帧曲线仍需后续验证。


## 2026-10-21 建筑重复排队

用户反馈建筑必须造完才能继续下单。第一偏离点为 HUD 在建造/排队时强制禁用同类图标，battle.request_structure 同时拒绝相同建筑 ID。修前通过两模式真实侧栏鼠标事件复现：6 项中 4 项失败；两次重复点击均未追加，队列仅留下电厂、矿场各一份。

修改仅涉及 battle.gd 与 hud.gd：在产/等待中的同类建筑可连续左键追加，每类建筑/防御队列仍上限 9、各自 FIFO 并行推进；图标角标累加相同建筑数。右键从最后一份同类订单开始取消，仅返还该项实际投入，保留头项进度。已有就绪建筑仍左键选址，多个就绪库存逐个放置、无二次收费；就绪与排队同时存在时提示右键优先取消队列。资金、解锁和容量约束继续生效，无法追加的原因显示在悬浮说明和点击反馈中。敌方自动规划去重维持原语义。

新增 structure_queue_regression；旧 production_status 和 audio 专项原先断言禁用/拒绝重复订单，已按此次明确允许重复排队更新期望，并验证第二次成功下单的真实 EVA 样本和混音 PCM。最终专项 40、双队列 70、生产状态 60、禁用原因真实渲染 56、音频 432，共 658 项通过。范围覆盖多份同类/异类队列、数量、尾项取消、独立推进、就绪累计及放置退款、九项上限、资金拦截、解锁原因及建造语音。

环境 Windows / Godot 4.7.2；独立复制工程及 custom_user_dir，逻辑 headless、原因提示 NVIDIA OpenGL、音频 WASAPI 墙钟。网络/端口/DB none。五轮源码前后与交付当前指纹相符。证据 C:/Users/admin/Temp/iron-tide-building-queue-20261021/delivery-audit.json。初次原因专项在 headless 等待渲染信号，改用真实渲染重跑；初次音频因旧断言未成功替换主动终止，修正后重跑，均不计通过。部分专项退出仍有 ObjectDB 释放警告。操作观感与实听 pending_user_visual_confirmation；重启原启动脚本加载。


## 2026-10-21 智能自动选敌、局部让路与混编负载

用户授权继续窄口/友军让路/混编与负载工作，并新增按克制或残血自动攻击。保持 Godot 独立实现，没有复制参考引擎代码。新增 tactical_targeting.gd、local_traffic.gd，接入 unit.gd 与 building.gd；不改武器伤害、护甲表或原有玩家手动集火语义。

自动选敌：在原有可见性、空地/水域、最小射程和姿态许可后，使用当前实际武器（含部署/精英）及 CombatMath.full_damage 估算效果，综合克制效果、预计所需完整攻击轮次、生命比例和距离。可开火目标优先于射程外目标；当前目标加 0.5 保持分，合法连发中暂不自动切换。手动集火优先；停火、仅反击、战争迷雾、舱内/死亡排除继续生效。双方常规自动索敌单位与防御建筑共用；原先要求出击任务的战机/舰载机入口不变。评分是本工程独立策略，未声明原版 RA2 AI 等价，也未预测暴击/闪避或未来弹道必然命中。修前目标专项 52 项中 28 项失败；修后新增真实弹体和残血击杀断言，共 60 项通过。

交通：原先分离只扫描组前 40 个对象，可能遗漏第 41 个之后的身边友军；改为物理空间邻域查询。候选成员缓存 0.1 秒，位置和状态逐次读取，移动超过 24 像素或新命令刷新，查询带余量。迎面会车尝试靠右；空闲友军允许沿无碰撞、合法地形方向短距离侧移，单次最长 3 秒，累计偏离本次停靠起点不超过 64 像素。警戒、部署、采矿、维修、交战或已有移动指令的单位不被侧移请求改派；新命令/姿态变化清除旧让路。静止时不调用碰撞恢复造成被动位移。终点被友军占据时，仅在距原终点一格（40 像素）内且当前位置不重叠时就近停靠，不能把远处卡住当作到达。让路完成同步空闲停靠点，保留原 Shift 路点队列及主动追击。

最终 traffic_regression 使用实际 physics_frame 推进：两模式各 12 个步兵/坦克对向穿过岩壁通道，约 23.08 模拟秒全部通过；50/100/200 混编开阔地全部停稳，约 26.18/26.88/26.27 秒，最终车体重叠均为 0。相对最初槽位的最大偏移约 54.81/72.32/70.73 像素，反映允许让路和就近停靠，并非严格保持原槽位。实际海陆/矿车回归另列。早期候选通用避让导致绕圈，未交付；早期压力夹具批量手动更新未逐物理帧同步，出现的单个重叠不作为最终结果，也不把早期 193/200 或其耗时直接用于最终性能提升宣称。

负载测量为 Core Ultra 5 250K Plus（18 逻辑处理器）、Godot 4.7.2、Windows，独立 headless 实际逻辑更新墙钟，不含完整画面/HUD/音频混音，也不是持续满编压测。移动 200 单位 p95：RA2 22.93 ms、扩展 19.42 ms。combat_load_regression 在 RA2 模式分别从 20/50/100/200 单位开始实际索敌、开火、弹体命中并持续 6 模拟秒；存活数 17/43/86/167，弹体数 43/110/226/433，均有真实伤害且无友军自动目标。对应逻辑 p95 为 2.344/3.995/9.493/22.725 ms；200 单位 p99 29.254 ms、最大 43.675 ms。100 单位出现单次 161.442 ms 峰值，原因未定位。大规模性能仍需后续优化，不能声称稳定 60 FPS。

最终同一源版本 13 套、2103 项断言通过：自动选敌 60、交通 52、交战负载 8、基础手感 20、寻路/建造 32、卧倒 22、命令转换 62、单位武器 188、防御开火 716、迷雾/规则 471、矿车流程 86、矿车朝向渲染 32、海空渲染 354。源文件运行前后及交付时哈希一致。全部使用外部隔离工程及独立 custom_user_dir，网络/端口/数据库 none；渲染专项 NVIDIA RTX 5060 Ti / OpenGL Compatibility。部分专项退出仍有 ObjectDB 释放警告，不作无泄漏声明。

证据 C:/Users/admin/Temp/iron-tide-tactics-20261021/delivery-audit.json；其中显式列出最终有效运行、失败/中断/被替代候选、固定场景指标和环境。原启动脚本重开加载；实际观感/操作体验保持 pending_user_visual_confirmation。更复杂窄口、多队交叉、200 单位完整渲染和长时间交战仍不在本轮通过范围。

## 2026-10-23 盟军固有能力与攻击表现

按本机 Steam 尤复 rulesmd.ini 独立实现；原始 SHA256、操作与剩余缺口见 ALLIED_ABILITIES.md。接入工程师占领/修复/拆弹、突击队 C4、间谍伪装和四类渗透收益、IFV 乘员武器/维修与替换炮塔、超时空步兵移动恢复/持续抹除、单目标心控/释放、幻影伪装、警犬/狙击手目标域、海豹/谭雅两栖动画及光棱分裂。单位固有技能优先于扩展技能；既有重装大兵 Q/W 保留。特殊状态、阵营收益、分裂引用纳入存档，迁移两个已知旧指纹，不放宽任意版本校验。

验证过程中修正：工程师 Capturable 取错字段；狙击手原始序列缺失；IFV 连发仍读取底盘武器；存档遇到已释放 Object 的类型判断异常；普通矿车移动误走步兵传送；精英光棱递归分支重复命中。最后一项以真实晋升 SuperComet 的测试在两模式各复现一次失败，补入每次发射前重新核对共享已命中集合后通过。最初精英夹具仅改 rank，没有调用晋升刷新，不算精英覆盖证据。原始武器参数导出 51 行，再次只读导出与已安装 JSON 字节一致。

分批验证共 3877 项通过（11 个专项加 16 项存档冷进程），没有把重复执行次数累加：盟军能力 198、自动采矿 62、运输/装卸 142、存档 100 + 冷进程 16、智能选敌 60、尤复伤害 1984、GGI 技能 68、模式 83、炮口/像素/命中 954、单位开火 188、卧倒攻击 22。

- 最终交付能力/真实渲染：C:/Users/admin/Temp/iron-tide-allied-delivered-render/reports，198/198。
- 精英分裂修正后：C:/Users/admin/Temp/iron-tide-allied-final-f-{allied_abilities_regression,yr_damage_regression,unit_fire_regression}/reports，198/198、1984/1984、188/188。
- 采矿/装卸/存档：C:/Users/admin/Temp/iron-tide-allied-final-a-{auto_harvest_regression,logistics_regression,savegame_regression}/reports。
- 选敌/GGI/模式：C:/Users/admin/Temp/iron-tide-allied-final-d-{tactical_target_regression,ggi_skill_regression,rules_mode_regression}/reports。
- 炮口与卧倒：C:/Users/admin/Temp/iron-tide-allied-final-e-{unit_muzzle_regression,deployed_attack_regression}/reports。

每个有效运行均为源工程外的隔离副本、唯一 custom_user_dir，运行前后源码哈希一致。较早专项早于最终光棱去重与乘员提示缩短；没有伪称所有专项都对完全同一全树哈希重跑。去重后补跑能力、伤害、开火；纯文案缩短和本机导入后补跑能力真实渲染。Windows / Godot 4.7.2，图形为 NVIDIA RTX 5060 Ti OpenGL Compatibility；没有网络、端口或数据库依赖。

早期 unit_muzzle 测试仍按 Inviso 弹体等待飞行、普通移动不解除固守、幻影始终显示车体断言，已对照真实生产入口修正夹具；d 轮引擎退出 0 但没有 result.json，原因未确定，排除通过结果，单独 e 轮完成 954 项。其余失败/中断候选保留在各自外部目录，不能作为通过证据。

本机已执行 headless editor 导入，无脚本错误，AlliedAbilities 缓存已注册；导入前后真实 userdata 全文件哈希相同。证据 C:/Users/admin/Temp/iron-tide-allied-delivery-20261023，包含导入日志、userdata 审计、规则重导出和运行清单。13 个新增/变更运行资源共 124372 字节，复制到 C:/Users/admin/IronTide-resource-update-allied-20261023 并逐文件校验；原完整资源包未变，资源不进入 Git。

实际技能手感、音画观感仍为 pending_user_visual_confirmation；重启 C:/Users/admin/IronTide/iron_tide/启动游戏.bat 加载。驻军、桥梁、部分间谍收益、完整反潜/飞行及特殊死亡动画等仍未完成，具体边界见 ALLIED_ABILITIES.md。本轮未推送远端。

## 2026-10-23 启动旧缓存导致进入战斗黑屏

用户日志第一错误为 BattleSnapshot 及 Unit/Building/Battle 引用的 AlliedAbilities 未注册，随后 BattleScreen 依赖编译失败、new 不存在。17:56 的失败日志早于 18:00 的类缓存刷新。旧 BAT 直接运行 Godot，既不触发编辑器脚本扫描，也不更新已运行进程的类表。前一轮隔离测试均先导入，未覆盖用户直接启动且缓存陈旧的入口，是验证缺口。

启动 BAT 现在调用 launch_game.ps1：独立 headless --import 等待脚本/资源准备完成，检查退出码与 SCRIPT ERROR/ERROR 日志，成功后才启动新游戏进程。失败保留控制台和独立日志位置。玩家游戏日志及存档路径不变；不杀旧游戏进程。此处仅改启动流程，没有再改盟军玩法代码。

新增 run-startup-regression.ps1 与仅测试使用的 startup_regression.gd。外部隔离副本使用含空格路径、独立 custom_user_dir，刻意从缓存移除 AlliedAbilities 后绕过导入，复现相同编译错误和无法构造战场。随后实际执行随项目交付的 BAT -> Windows PowerShell -> 导入 -> 新游戏，在正常 main.tscn 中触发真实主菜单按钮与大厅开始遭遇战按钮，9 项检查通过：场景转换、战场/HUD/开局实体、盟军固有技能及非黑屏截图。另注入真实语法错误，验证导入失败会阻止启动。测试驱动没有加入正式 project.godot。

证据 C:/Users/admin/Temp/iron-tide-startup-cache-20261023-v1：before/、after/result.json、after/battle.png、after/godot.log、rejected-import.log、summary.json、delivery-audit.json。验证与交付的 scripts/*.gd 哈希一致；Windows / Godot 4.7.2 / NVIDIA OpenGL，网络、端口、DB none。原启动位置 PrepareOnly 也通过。用户之后已有从原目录运行的游戏进程，当前日志包含地表生成、没有先前脚本错误；不以日志代替用户画面确认。该进程锁住玩家日志，未宣称本轮 userdata 全文件哈希不变，未停止玩家游戏。实际体验 pending_user_visual_confirmation。

## 2026-10-23 维修厂车辆无法进站维修

根因：Unit.order_repair 只设置 repair_depot、停靠点及 flow field，没有清理旧的 A* 路线；_steer_dir 优先消费旧 _path_pts。实际右键己方 GADEPT 后命令成立，车辆却沿上一条移动路线停在旧目标，始终不到维修位。旧 command_transition 专项直接把车辆放到停靠点，只证明回血和中断，未覆盖真实进站。

修前有效专项 before2：两模式分别从 (900,1600) 先下达前往 (900,2200) 的命令，再右键实际可见维修厂像素；20 模拟秒后仍停在约 (899,2200)，HP 保持 284。32 项中 20 项失败，包括旧路线、光标、实际回血/扣费及合法目标边界。第一版 before 夹具的建筑在相机外，无法用绘制像素点选，因此不能作为进站根因证据；已移动测试相机并选择实际不透明像素后重现。

修正：维修命令复用正常移动指令的清理与寻路流程，清除旧路径、装载/技能动作和姿态；维修中启用卡住重寻路，到站停车，满血解除占用并驶离。仅对同阵营、存活、可行动的受损地面载具接收，排除步兵、海空军、舱内及冻结等状态。按指定停靠点距离判定实际到站，不再按建筑附近的大圆范围提前回血。资金按维修厂所属阵营扣除；零资金暂停，到账后恢复，零点几血也补满。维修厂变更归属会解除旧服务，暂停游戏不推进。右键有效目标显示维修光标，不满足条件给出提示；工程师修建筑的原有指令/光标优先级保留。

源参数已对照本机尤复 rulesmd.ini：RepairStep=8、URepairRate=.016 分钟、RepairPercent=15%，本轮不改数值。停靠仍使用当前工程既有外围维修位，不宣称已实现原版整车开上平台、维修队列或完整平台动画。

新增 repair_depot_regression 通过实际 Battle 右键分派、物理帧行驶及 Building._process 验证；不是用瞬移代替进站。两模式实际回血至 300 并驶离。command_transition 的静止建筑夹具原本未结束 buildup，又冻结处理，现显式设置为已完成建筑并断言 operational；新增专项另外保留未完工/展开阶段拒绝维修断言。完整结果及环境审计见 C:/Users/admin/Temp/iron-tide-repair-depot-delivery-20261023。表现体验仍待用户重启验证，pending_user_visual_confirmation。

最终回归：维修厂 44、命令中断 64、盟军技能 198、矿车 62、存档 100 + 冷进程 16，共 484 项通过。五轮均为外部隔离项目和独立 custom_user_dir，运行前后源码一致；交付前逐文件对照最后一轮源指纹，差异 0。环境 Windows / Godot 4.7.2 / NVIDIA OpenGL，服务、端口、网络和数据库 none。原路径 launch_game.ps1 -PrepareOnly 成功；用户重新启动原 BAT 后生效。未停止玩家进程、未主动修改玩家存档、未推送远端。

## 2026-10-23 单位生产卡片右键无法取消

根因：HUD 单位目录卡片只绑定左键生产和灰态原因提示，右键取消仅存在于下方队列小图标。新增真实鼠标事件专项，修前 102 项中 48 项失败，覆盖 RA2/扩展模式的兵营、战车工厂、机场及船坞。

单位卡片现支持右键取消当前工厂最后一个同类型订单，优先保留正在生产的队首；仅剩队首时复用 Building.cancel_at 退还实际已扣资金。空队列不转投其他工厂，不重复退款。资金不足、满队列导致卡片变灰仍可取消，原下方队列图标入口保留。只修改 HUD 输入入口与提示，不改生产计费或建筑队列规则。

unit_cancel_regression 通过 Viewport.push_input 走真实 HUD/Battle 输入，冻结物理推进但保持世界输入启用，覆盖混合类型队列、退款、工厂隔离、灰态卡片及右键不向选中部队下达移动。隔离验证使用独立 custom_user_dir，Windows / Godot 4.7.2 / NVIDIA OpenGL，无服务、端口或数据库依赖。各轮证据位于 C:/Users/admin/Temp/iron-tide-unit-cancel-final-20261023-<suite>/reports；修前失败证据位于 C:/Users/admin/Temp/iron-tide-unit-cancel-before-20261023/reports。操作体验仍为 pending_user_visual_confirmation。

最终回归：unit_cancel 110、factory_tabs 310、batch_rally 40、structure_queue 40，共 500 项通过，四轮引擎退出 0 且运行前后源码一致。交付文件对照最后一轮源指纹差异 0（随后本机导入新增的测试脚本 UID 为引擎元数据）；原启动入口 PrepareOnly 成功。未停止玩家游戏或推送远端，重启原 BAT 后生效。

## 2026-10-23 接入用户提供的 Rock and Awe

从 C:/Users/admin/Downloads/Tim Wynn - Rock and Awe.mp3 原样复制到 iron_tide/assets/music/rock-and-awe.mp3，11428257 字节，SHA256 F2BC38767B2E818AA6ED653948409BBC65B7435200AC932DD2BAD457BCBAC9C6，源/目标一致。复用现有唯一曲目配置；资源由 Git 忽略，未修改玩家音乐偏好（当前 enabled=true、volume=1.0）。

music_regression 现优先使用真实配置中的本地歌曲，缺文件的源码检出仍使用明确标识的 SDK 夹具。此次实际 Rock and Awe 解码时长 280.404 秒，33 项全部通过，包含 Music 混音总线非零 PCM、语音压低音乐、音量/开关、真实 finished 信号循环、菜单与战斗复用播放器。证据 C:/Users/admin/Temp/iron-tide-rock-and-awe-20261023/reports。Windows / Godot 4.7.2 / WASAPI Default，独立 custom_user_dir；无网络、服务、端口或数据库依赖，运行前后源码一致。原入口 PrepareOnly 通过；用户重启原 BAT 后加载歌曲。物理扬声器听感仍待用户确认，pending_user_visual_confirmation。
## 2026-10-23 美国大兵部署技能重复

根因：新增 allied_deploy 固有技能后，扩展模式仍从原配装装入 ap_deploy，技能栏真实出现“卧倒据守”和“部署/卧倒”两个入口。GGI 自定义配装也可形成同类重复。AlliedAbilities.install 现在仅对 E1/GGI 去掉运行时旧 ap_deploy，保留固有部署入口和 GGI 的独立固守；其他单位的通用部署、其他技能对象/冷却、局外配装不改写。相同安装入口已在新建单位及存档恢复后调用，旧战斗存档无需手工修改。

新增 deploy_skill_dedup_regression 通过真实配装、HUD、Q 键、BattleSaves.save_slot/read_slot 和恢复链路覆盖两模式，断言唯一入口、部署/起身、固守槽位、无关技能/冷却及部署状态保留、重复安装幂等。有效修前 before2 为 46 项中 8 项失败；before 首版测试有 GDScript 类型推断错误，已停止对应隔离进程，不能当作业务复现证据。最终证据根为 C:/Users/admin/Temp/iron-tide-deploy-dedup-final-20261023-<suite>/reports。测试使用独立 custom_user_dir，无服务、端口或数据库依赖；实际技能栏观感仍为 pending_user_visual_confirmation。

最终专项 46、重装大兵 68、技能热键 78、盟军能力 198、存档 100 及冷进程 16，共 506 项通过；五轮运行前后源码一致，引擎退出 0。Windows / Godot 4.7.2 / NVIDIA OpenGL；交付文件对照最后一轮源指纹差异 0，本机 PrepareOnly 成功。未修改玩家存档、未停止玩家游戏、未推送远端；重启原 BAT 后生效。

## 2026-10-23 建筑预约改为科技解锁

按用户最新规则，两模式建筑/防御各保留一个默认建造位，已就绪建筑仍占该类别，放置或取消后方可继续；两个类别可同时施工，单位生产队列不变。structure_queue（建筑预约）注册在现有按阵营保存的 production_technology 节点中；解锁后恢复原有每类最多 9 项订单及就绪库存不阻塞后续建造。原默认启用的 GM.unlock_production_tech 仅绕过 refinery_miner，不解锁新节点。GM 控制台新增明确的“仅本局我方”授予按钮，不改变下局默认状态。正式研究界面、研究价格/时长仍未定义，本轮没有虚构花费或自动研究条件。

HUD 与 request_structure 共用预约/容量原因；未解锁时卡片不再提示左键追加，禁造说明当前施工或等待放置及所需科技，避免把已有建筑前置误报成科技解锁。敌方使用独立科技状态。旧存档订单不删除、不退款重建；有就绪项时暂停后续计时扣款，放置/取消或解锁后继续。新节点复用原 unlocked 字段，无存档 schema 扩张。

structure_technology_regression 修前两模式均复现默认仍能预约，修后 52 项通过，包括真实卡片点击、后端拦截、同类重复、双类别并行、就绪放置/右键取消、旧队列实际存读档、等待时资金不变、GM 按钮回调、双方隔离、科技与队列存读档及下局不继承。structure_queue 和 dual_build 的原有多项队列断言保留，夹具显式解锁科技，默认锁定另由新专项覆盖。环境 Windows / Godot 4.7.2 / NVIDIA OpenGL，独立 custom_user_dir；无服务、端口或数据库依赖。最终证据根 C:/Users/admin/Temp/iron-tide-structure-tech-final-20261023-<suite>/reports。画面与操作 pending_user_visual_confirmation。
最终回归：预约科技 52、解锁后队列 40、双通道 70、禁造原因 58、AI 经济 50、单位取消 110、存档 100 + 冷进程 16，共 496 项通过。前三组证据为 final，后四组为 final2；每轮源码前后稳定，引擎退出 0，交付 scripts/ 哈希与各轮指纹均一致。本机 PrepareOnly 成功，未停止玩家进程、未修改玩家存档、未推送远端。

final/production_reason 候选在旧夹具访问建筑页 GAWEAT 时发生脚本错误，不能算通过；GAWEAT 早已属于防御分类，夹具现从真实 structure_category 定位并断言为 defense，原缺前置断言保留。只改该测试分类后重新运行 final2/production_reason 及后续三组；此前已通过的前三组运行时代码未变。
## 2026-10-23 科技树接入局外养成及实际界面

用户明确科技树属于养成。本轮新增主菜单“科技树”入口、驻防“科技树”页签及可直接打开的 technology.tscn；展示生产分支的建筑预约、矿场矿车制造，价格、效果、前置、资金缺口、永久解锁状态，以及矿车调试开关的临时状态区别。初版两项各 1200 局外军需券，价格放在 meta.json/technologies，当前均无前置、即时购买。不是局内科研倒计时，也不自动消费玩家货币。

MetaProgress 新增 unlocked_technologies 和统一 research_technology；旧档缺字段视为未解锁，其他货币/统计保留。研究重复或资金不足拒绝扣款；先写临时文件并成功替换后才报告购买成功，失败回滚本次内存扣款与解锁。已有 save() 复用临时替换并返回成功状态。开新局时仅扩展模式将永久科技冻结到我方 production_technology，敌方与 RA2 不继承；旧对局读档恢复原科技，既不追加新买科技，也不回滚局外永久解锁。本局 GM 授予和矿车调试开关继续独立。

technology_progression_regression 使用实际主菜单点击进入科技树、实际研究按钮事件，验证旧存档迁移、资金不足、扣款、重复请求、重载、存档写入失败回滚、原文件字节不变、两模式新对局消费及旧战斗恢复；另启动独立 Godot 进程验证永久字段重载和模式冻结。故意占用隔离临时路径的 WARNING 是预期失败验证，不是玩家保存失败。首轮冷进程测试有 GDScript bool 类型推断错误，停止对应隔离子进程并修正测试后重跑；首轮不算通过。

最终 technology_progression 34、structure_technology 52、rules_mode 83、savegame 100、factory_tabs 310，加存档冷进程 16，共 595 项通过，技术养成专项另包含冷进程条件检查。各轮 source_unchanged=true、引擎退出 0；交付全部受审计文件与最后一轮指纹差异 0。本机 PrepareOnly 通过。证据 C:/Users/admin/Temp/iron-tide-permanent-tech-final-20261023-<suite>/reports；technology_progression 的 technology-locked-1280.png、technology-locked-1600.png、technology-unlocked.png 已实际渲染，1280 截图已检查，按钮和页签不越界。Windows / Godot 4.7.2 / NVIDIA OpenGL，测试独立 custom_user_dir，服务/端口/数据库 none。

按用户“开界面”的要求，确认无原目录游戏进程后，通过原 Godot 引擎从正式工程打开 res://scenes/technology.tscn（PID 68760）。没有代玩家研究科技；打开游戏会按既有流程载入并正常保存养成、计入离线收益。实际界面体验仍为 pending_user_visual_confirmation，未推送远端。
## 2026-10-23 矿场完工赠送矿车

对照本机合法 YR 提取规则 rulesmd.ini [GAREFN]（第 11722 行起）的 FreeUnit=CMIN。原实现仅给地图开局配置矿车，实际新建矿场没有赠送入口。Building.notify_construction_placed 现在仅对实际新建 GAREFN 登记一次性待发 CMIN，展开完成/施工结束后复用碰撞检查出口与 spawn_unit，免费出车并绑定新矿场自动采矿；敌方真实建造也适用。不占用付费制造队列，不依赖矿场制造科技或 GM 开关。

出口受堵按 0.25 秒间隔等待；待领取单位 ID 和已领取空串保留在既有 special 存档字段中，不增加字段清单、不改变规则数据指纹。旧存档/地图预置建筑没有标记，不补发；重复完成通知、修理、出售或摧毁不能重复领取。开局两辆矿车配置保留。

refinery_gift_regression 53 项通过：真实 HUD 购买矿场、就绪放置/展开、仅扣建筑款、堵口延迟、待领取/已领取存档落盘恢复、无科技赠送而付费入口仍锁定、AI 出车、旧记录不补发、出售/摧毁边界；另外在新的 Godot 进程经实际 load_into_scene 入口载入两模式待领取存档，验证只发一次。冷进程退出有 ObjectDB 清理警告，规则断言通过且没有脚本错误。测试使用独立 custom_user_dir；Windows / Godot 4.7.2 / NVIDIA OpenGL，服务/端口/数据库 none。证据 C:/Users/admin/Temp/iron-tide-refinery-gift-20261023-v1/reports。未操作玩家存档或重启玩家游戏。
最终回归：赠车专项 53、存档 100（另冷进程 16）、卸货口交通 44、生产出口 84、AI 经济 50，共 347 项通过。生产出口首轮 4 项失败来自旧测试把开始建造 EVA_Building 与完工 EVA_ConstructionComplete 合计误认为一句；依据真实 request_structure/完成入口，将开始语音单独断言并在其后记录完工基线，原完成一次/不重复断言保留，重跑全部通过。没有修改语音业务。前两项及交通证据为 C:/Users/admin/Temp/iron-tide-refinery-gift-20261023-<suite>/reports，出口与 AI 为 C:/Users/admin/Temp/iron-tide-refinery-gift-final-20261023-<suite>/reports。

各轮引擎退出 0、source_unchanged=true；交付文件与最后一轮全量指纹差异 0（随后正式 PrepareOnly 导入生成新测试 UID 元数据）。正式启动入口 PrepareOnly 通过，未提交或推送。规则逻辑已验证；实际出车表现待用户重启原 BAT 观察，pending_user_visual_confirmation。
## 2026-10-23 视野覆盖当前武器射程

用户要求攻击范围内不再被战争迷雾遮住。原实现 Fog.rebuild 仅使用 actor.sight，未消费实际 attack_range；圆形揭露又只检查格子中心，边缘格的部分位置在射程内却不亮。按用户明确要求，两种模式、双方统一使用 max(基础视野, 当前武器射程)，无武器单位保持原视野；读取实时派生 attack_range，覆盖部署、精英武器、IFV 乘员换武器，不永久增改基础 sight、不改存档字段或数据指纹。迷雾栅格改为圆与格相交，保留 40 世界单位离散粒度。

本机 YR rulesmd.ini 的 GTGCAN Sight=10、GrandCannonWeapon Range=15，证明原版允许视野小于射程；此次“视野至少覆盖射程”属于用户指定的工程规则，不宣称原版一致。原开火暴露位置、共享视野、探索记录、0.6 秒停留和 0.6 秒淡回机制保持。

新增 weapon_vision_regression 覆盖两模式、双方、MTNK/SREF/SNIPE/E1/GGI/FV/GTGCAN/GAPILL 的边界可见性、真实目标判定、世界精灵与迷雾纹理一致性；部署、晋升、狙击手进入/离开 IFV 以及多种格内偏移下的圆周样本。354 项通过，截图 ra2-cannon-vision.png 已查看，巨炮射程圈内地形明亮。证据 C:/Users/admin/Temp/iron-tide-weapon-vision-20261023-v2/reports。v1 测试脚本存在 label 类型推断错误，仅停止该隔离运行并修正测试后重跑，v1 不算通过。

旧 fog_rules 的部分夹具用人为“射程 1000、视野 100”创造射程内不可见目标，与用户新规则冲突。改成短射程观察方与远射程攻击方，保留隐藏选取/索敌拒绝、侦察共享、开火暴露、撤离不追踪、停火过期的全部检查；短射程受击方可以锁定已暴露目标，但仍须接近才能射击。无删除断言来绕过新规则。
最终专项 354、迷雾/开火暴露/对局规则 491、射程显示 46、存档 100 及存档冷进程 16，共 1007 项通过。回归证据 C:/Users/admin/Temp/iron-tide-weapon-vision-final-20261023-<suite>/reports。全部 source_unchanged=true、引擎退出 0，交付文件对比最终全量指纹差异 0（随后 PrepareOnly 仅生成新测试 UID 元数据）。正式启动准备通过。测试环境 Windows / Godot 4.7.2 / NVIDIA OpenGL，每轮隔离 custom_user_dir；服务、端口、数据库 none。没有操作玩家存档或重启玩家游戏，没有推送。规则与目标可见性已验证，实际战场观感仍为 pending_user_visual_confirmation。
## 2026-10-23 多功能步兵车登车鼠标提示

根因：Battle._issue_order 已有乘员 request_board 入口，但 BattleCursor.resolve 未查询装载条件，原鼠标资源包也未导出 enter/enter-blocked 帧，导致可登车时仍显示 select。对照 OpenRA/ra2 mods/ra2/cursors.yaml 的帧标签（https://github.com/OpenRA/ra2/blob/master/mods/ra2/cursors.yaml），从本机合法游戏 MOUSE.SHP/MOUSEPAL.PAL 导出 enter=89 起 10 帧、enter_blocked=99 单帧，原图集已有序列顺序不变，合计 116 帧。资源仍被 Git 忽略，源码分发需同步新的 assets/ra2/cursors/mouse.png 和 mouse.json，或用更新后的 ra2pipe/cursor_art.mjs 从自己的本地游戏重新导出。

Battle.boarding_order_status 统一鼠标与右键入口：己方可见运输载具，有合格的选中乘员时显示进入；满员/类型不符显示禁止进入并给出原因，右键拒绝后不再回退为地面移动；混选仅下达合格单位登车。仅选择载具自己或无选中乘员时仍显示选择；敌方载具保持攻击；明确移动/技能/维修指令保持优先。通用运输装载 can_board 同时拒绝死亡/待删除的载具与乘员。容量、乘员变武器、卸载规则没有调整。

boarding_cursor_regression 126 项通过，真实 Viewport 鼠标悬停与右键事件，覆盖两模式 E1/GGI/ENGINEER/SNIPE、进入动画和热点、实际入舱、满员拒绝、卸载后立即恢复、错误类型、混选、自选载具、敌方载具及 UI 遮挡。ra2-enter-ifv.png 已查看，黄色进入箭头位于步兵车上。证据 C:/Users/admin/Temp/iron-tide-boarding-cursor-20261023-v1/reports。测试不接管用户鼠标，使用隔离 custom_user_dir；Windows / Godot 4.7.2 / NVIDIA OpenGL，服务/端口/数据库 none。
最终登车鼠标 126、通用鼠标 62、盟军技能 198、运输/空军后勤 142，共 528 项通过。其余回归证据 C:/Users/admin/Temp/iron-tide-boarding-cursor-final-20261023-<suite>/reports。各轮 source_unchanged=true、引擎退出 0，交付对照最终全量指纹差异 0；正式 PrepareOnly 成功，随后引擎刷新新测试 UID/光标图集导入元数据。未推送代码或资源，未操作玩家存档/鼠标或重启玩家游戏。实际光标表现仍为 pending_user_visual_confirmation。
## 2026-10-23 建造就绪页签闪烁

用户截图红框为“防御”页签，卡片已选址但没有闪烁提醒。原实现仅有世界建筑落地闪光和卡片就绪文字，生产页签没有连接就绪提示。HUD 新增建筑/防御页签金色填充与边框脉冲，每秒一轮；基于真实 structure_ready_count，选中或未选中均持续提醒，进入选址/无效放置不清除，全部放置或取消后停止。两类独立，多项就绪取消一项仍保留提醒，悬停显示就绪数。通过原 Button.draw 叠加，保留选中状态、点击、按钮身份及 RA3 皮肤，不改变队列或存档规则。

ready_tab_regression 使用真实 HUD 按钮、订单完成、鼠标切页/选址、放置与取消，并对亮暗两帧实际渲染像素做差；34 项通过，两模式截图已查看，选中防御页签的金色亮暗变化明确。首轮测试误用 Color.distance_to 导致脚本解析失败，仅停止该隔离运行；改为 RGB 差值后 v2 通过，v1 不算通过。证据 C:/Users/admin/Temp/iron-tide-ready-tab-20261023-v2/reports，包括 ra2-selected-bright.png / ra2-selected-dim.png。环境 Windows / Godot 4.7.2 / NVIDIA OpenGL，独立 custom_user_dir，服务/端口/数据库 none。纯 HUD 表现，实际观感 pending_user_visual_confirmation。

最终页签表现专项 34、独立建造/防御队列 70，共 104 项通过；后一轮证据 C:/Users/admin/Temp/iron-tide-ready-tab-final-20261023-dual_build_regression/reports。两轮 source_unchanged=true、引擎退出 0；交付对比最后全量指纹差异 0，随后 PrepareOnly 成功并生成测试 UID 元数据。没有重启玩家游戏、改写玩家存档或推送。

## 2026-10-23 生产右键先暂停、再次取消

按用户要求，对照本地 refs/ts-ra2/src/game/action/UpdateQueueAction.ts 的 Pause / Resume / Cancel 和 QueueStatus.OnHold 行为，独立实现 Godot 生产暂停；参考工程不是官方 RA2 源码，未复制或翻译其实现。建筑、防御、各工厂单位及矿场制造矿车统一：当前项目第一次右键暂停，保留订单、进度和已付费用；左键恢复同一订单，即使零资金、队列满或预约科技未解锁也不会被当作新订单拦截；再次右键取消一个匹配订单，同类从尾部取消，只有移除正在生产的订单才退还其实际付款。不同的等待项目直接取消，已完成待放置建筑直接收回。队列图标、生产卡片和矿场命令入口一致，显示已暂停及继续操作说明；建筑/防御两条队列和各工厂互不影响。

暂停字段存放于已有结构任务字典和 Building.special，不增加存档 schema 字段、不修改资源哈希合同。实际生产 tick 停止扣费、进度和出车；磁盘保存/恢复保留暂停及支付进度，旧存档缺字段默认继续。解除手动暂停不绕过原有供电、前置、资金或出口条件。

新增 production_hold_regression 44 项；unit_cancel 178、dual_build 72、structure_technology 54、factory_tabs 318、batch_rally 42、savegame 100 与冷进程 16，去除重复运行共 824 项通过。既有 UI 取消案例增加第一次暂停步骤并保留原退款、下一订单、选择和集结点断言。实测通过 Viewport.push_input 驱动真实 HUD，涵盖两模式、步兵/车辆/飞机/船舶、零资金、满队列、独立工厂、矿场技能、已就绪建筑和磁盘恢复。来源及证据：C:/Users/admin/Temp/iron-tide-production-hold-final-20261023-{hold,units,dual,technology,factories,batch-v3,save}/reports。各轮 source_unchanged=true、引擎退出 0；隔离项目与 custom_user_dir，Windows / Godot 4.7.2，渲染测试使用 NVIDIA OpenGL；服务、端口和数据库均 none。

并行运行的 batch 首轮 RA2 初始左键未入队，其余断言通过；保留失败报告，不计入通过。仅为该断言增加实际队列、生产者、禁用原因、按钮矩形与焦点诊断后，单独运行 batch-v2 / batch-v3 均为 42/42，未更改业务代码或删除断言来过关。原偶发首次点击未再复现，未宣称已确定根因。savegame 退出有 2 ObjectDB 实例泄漏警告，未出现脚本错误，存档和冷进程断言通过。实际界面观感仍为 pending_user_visual_confirmation。

## 2026-10-23 单位普攻冷却圆环

新增纯表现脚本 scripts/ui/attack_cooldown_indicator.gd，由 Battle 的现有 WORLD_HUD 血条层调用。己方有武器且可见、存活、未装载的单位，选中时常显，未选中仅在普攻冷却期间显示。圆环置于血条右侧，与左上军衔分离；固定屏幕半径 6px，等距投影和相机缩放不压扁圆环。金色弧表示剩余普攻 CD，归零时选中单位显示青色整环，未选中自动隐藏。不显示敌方冷却或无武器矿车。

直接读取 Unit._cd_timer，比例沿用实际开火的 veteran_cooldown、冷却 buff 修正。没有独立推进的 UI 倒计时，没有修改攻击、伤害、连发、弹药、存档状态或射速。该环只表示普攻计时，未承诺归零就能绕过转向、射程、装填或禁火条件；在冷却中临时改变攻速时分母按当前修正值更新。

attack_cooldown_indicator_regression 在两模式中实际调用普攻并推进真实 physics，验证满环/半环/归零、冻结时绘制不推进计时、选中/未选中、老兵与 buff、死亡/隐藏/装载/敌方/无武器排除，比较实际渲染像素，并覆盖 0.5/1/2/4 倍缩放。42 项通过；已查看 ra2-half.png，圆环在坦克血条右侧。证据 C:/Users/admin/Temp/iron-tide-attack-cd-20261023-v1/reports，source_unchanged=true、引擎退出 0；Windows / Godot 4.7.2 / NVIDIA OpenGL，隔离项目及 custom_user_dir，服务/端口/数据库 none。影响仅闭合于 HUD 绘制，未修改战斗状态推进；实际观感 pending_user_visual_confirmation。

## 2026-10-23 右侧指令栏遮挡地图边缘与滚屏

根因：Battle 同时设置 Camera2D 原生地图硬边界，又按完整窗口旋转包围盒限制相机中心；侧栏盖住的像素仍算入取景范围，菱形地图的尖角也无法充分露出。贴边滚屏只认窗口四边，侧栏左边的战场边缘没有入口。阅读 refs/ts-ra2/src/gui/screen/game/WorldView.ts 的 computeWorldViewport 与 engine/util/MapPanningHelper.ts，参考“扣除 HUD 后的可视战场参与相机限制”的行为，在 Godot 中独立实现，没有复制参考源码。

新增 camera_play_rect 按实际可见 prod_panel 左边界计算战场宽度，隐藏侧栏恢复全宽，布局/分辨率变化读取实时矩形。移除第二层原生硬裁剪，按相机投影计算地图边界、战场尺寸及 64px 操作余量，并与地图菱形相交；相机停留在交集内，地图边缘可露出、斜拖不会把整个地图拖走，整图可容纳时按对应轴居中。center_on / 跟随对准无遮挡区域中心，原鼠标锚点缩放沿用。侧栏左侧 4px 战场条可向右滚动，原 UI 输入遮挡/暂停/失焦保护保留；小地图取景框同样排除被侧栏挡住的区域。没有更改单位移动订单、地图尺寸、迷雾或存档 schema。

sidebar_camera_regression v3 434 项通过，覆盖两模式、1280×720 / 1600×900 / 2560×1440、0.45 / 1 / 3.2 缩放、正/反 45 度及正视、地图角点与边缘投影、极限右移、反复拖动的亚像素稳定、实际鼠标边缘滚屏/侧栏阻止滚屏/中键拖动，以及侧栏改宽/隐藏。已查看 ra2-right-edge.png，地图最右端停在侧栏左侧约 64px，边缘坦克完整可见。v1 曾采用允许边缘移至中央的较宽范围，截图审阅后收紧过度空白；v2 的两项极限重复拖动断言受世界零坐标附近浮点比较影响，改为严格的屏幕位移 <0.05px，保留每次实际位移证据；v2 还出现一次首模式边缘输入未滚动，增加焦点/鼠标/方向诊断后 v3 未再复现，未宣称确定该次输入偶发的根因。

既有 camera_input 130 项通过，覆盖键盘、跟随取消、右键/中键拖动、指令归属、暂停及失焦；minimap 61 项通过，保留实际 GUI 点击/拖动/外部释放与渲染轮廓断言，仅将旧整屏中心/整屏轮廓预期更新为实际无遮挡区域。合计 625 项通过。证据 C:/Users/admin/Temp/iron-tide-sidebar-camera-20261023-v3/reports 及 C:/Users/admin/Temp/iron-tide-sidebar-camera-final-20261023-{input,minimap}/reports；source_unchanged=true、引擎退出 0。Windows / Godot 4.7.2 / NVIDIA OpenGL，隔离源码与 custom_user_dir；服务、端口和数据库 none。实际操作观感仍为 pending_user_visual_confirmation。


## 2026-10-23 固定单位技能槽 Q / W / 被动 / E

按本次需求统一技能布局：Q 为单位固有主动，W 为一个玩家装配主动，接一个玩家装配被动，E 为原有特殊操作。无技能的格子保留禁用占位。撤销 R、Shift+Z/V 的额外技能入口，Q/W/E 兼容 Shift，原 D 部署快捷键保留。养成的单位改造界面仅提供 W 和被动两个装配项；Q 只读，E 不参与抽取装配。非法槽位、错误技能类型、与 Q 重复的技能及部署技能不能写入 W。

UnitSkillLayout 在运行时统一映射，原生主动优先成为 Q（例如重装大兵固守、工程师作业、间谍渗透、C4、超时空移动）；其它单位在扩展模式沿用原默认通用主动作为固有 Q。E 接卧倒/部署、伪装/模式、卸载、基地展开、战机返航或矿车自动采矿开关。没有新增伤害或技能数值。RA2 模式仍不启用扩展主动和装配被动，原生操作保持可用。

旧多槽装配读取时选取第一项符合 W 条件的技能；原始永久装配记录不因读取而覆盖，明确修改装配才写入新格式。旧战斗快照保留 Ability 对象、原冷却和生效状态，通过 ID 映射显示槽并补齐固有入口，不改存档 schema 或数据 JSON 内容指纹。混编队伍根据技能 ID 匹配，数组顺序不同也不会串放另一技能。装配保存失败回滚内存选择，成功后才通知界面刷新。

隔离真实 Godot 4.7.2 / OpenGL 验证：skill_hotkey 173、ggi_skill 68、deploy_skill_dedup 46、auto_harvest 62、allied_abilities 198、savegame 100 + 冷启动 16、rules_mode 83，共 746 项通过。包含真实键鼠入口、目标瞄准取消、文本输入与组合键保护、不同数组顺序混编、两模式固定槽/空槽、实际登车后 E 卸载、Q 固守/E 部署独立切换、养成 OptionButton 装配和磁盘读回、新单位实际消费装配、旧快照恢复及原生能力回归。数据和技能数值未改；没有涉及在线协议/服务或跨局结算规则。已查看 iron_tide-fixed-slots.png，四格顺序正确；实际显示与操作观感仍为 pending_user_visual_confirmation。

证据：C:/Users/admin/Temp/iron-tide-fixed-skills-20261023-v2/reports、iron-tide-fixed-skills-20261023-ggi-v1/reports，以及同目录下 iron-tide-fixed-skills-20261023-final-{deploy_skill_dedup_regression,auto_harvest_regression,allied_abilities_regression,savegame_regression,rules_mode_regression}/reports。每次 source_unchanged=true、引擎退出 0；项目和 custom_user_dir 隔离，服务/端口/数据库 none，未修改玩家存档。正式 launch_game.ps1 -PrepareOnly 返回 Ready，未启动或关闭玩家游戏。没有提交或推送。


## 2026-10-23 框选碰到左下角小地图时漏选

用户补充确认：从战场框选，碰到左下角小地图就选不中。根因是 Battle._input 的左键松开处理虽然接住战场开始的手势，却在 gui_get_hovered_control 非空时取消整次选择；小地图及其边框都属于 GUI，导致大框已覆盖的己方部队仍不被选中。

修复只改左键松开条件：达到原有 14px 框选阈值的战场手势，无论释放点位于小地图、边框或其它 HUD，都完成原有 _apply_selection，并在 GUI 派发前消费释放事件。未达到框选阈值、在 GUI 上释放的小幅点击仍取消；从 GUI 开始不创建战场框选，小地图自身拖动仍只移动相机，失焦/暂停取消手势规则保留。没有更改坐标投影、移动/攻击指令或存档。输入影响闭合于战场选择手势，使用真实 Viewport 输入链路专项验证。

新增 box_ui_release_regression：两模式、1280x720 / 1600x900、0.5 / 1 / 2 缩放，真实小地图与边框释放、普通/Shift 框选、框外盟军及敌军排除、跨小地图再回战场、无残留二次释放、小地图反向拖出。修前 240 项中 48 项目标断言失败，全部准确落在地图/边框释放漏选；其余输入归属正常。修后 240 项全部通过。input_ownership 278、minimap 61、camera_input 130 项通过，共 709 项。更新旧选择测试中已过时的 Q 部署预期为现行 Q 固有主动，以及生产栏首次右键暂停、第二次取消预期；保留实际施放、冷却、生产状态和输入不穿透断言。

证据：C:/Users/admin/Temp/iron-tide-box-map-20261023-before/reports；修后同目录 iron-tide-box-map-20261023-after-{box_ui_release_regression,input_ownership_regression,minimap_regression,camera_input_regression}/reports。每次均隔离源码与 custom_user_dir，Windows / Godot 4.7.2 / NVIDIA OpenGL，服务/端口/数据库 none；source_unchanged=true，修后引擎退出 0，最终业务源码与验证副本字节一致。未重启或修改玩家运行中的游戏、存档。实际鼠标操作体验 pending_user_visual_confirmation。

## 2026-10-23 机器人悬浮与地面载具移动观感

本地 Steam 尤复提取的 rulesmd.ini 确认 ROBO 为 SpeedType=Hover、Hover locomotor、Speed=10、ROT=5；
MTNK/FV/SREF/MGTK/TNKD 与 ROBO 均 Accelerates=false。旧运行时只接了 ROBO 两栖通行，绘制高度仍为 0，
未选中待机时也不持续重绘；地面载具图集只有 8 个朝向，转弯控制在 35 度边界由约 80% 速度直接切为 0。

新增 unit_hover 视觉适配，使用原规则 HoverHeight=120、HoverDampen=40%、HoverBob=.04 作为参考，
屏幕高度及时间曲线独立实现，不冒充原引擎 HoverBoost/HoverAcceleration 和完整惯性积分。
通电浮起并持续轻微起伏，断电落地；暂停/超时空冻结保持现有时序。身体、炮塔、炮口与点击判定共享高度，
地面阴影与两栖碰撞域不抬高，断电保留订单、供电恢复继续原订单，停止命令不产生漂移。
vehicle_facings.mjs 从已安装游戏源 VXL 重导 8 类载具的 32 方向车体/炮塔/阴影和炮口，
allied_ability_art.mjs 同步重导 FV 三种乘员炮塔；未改变单位速度、价格、伤害、原始 ROT 或 Accelerates。
普通坦克转弯边界改为 smoothstep 连续减速，保留原有 35 度小半径转弯范围、反向先转身、无侧滑和停稳规则。

首轮扩大到 85 度边转边走，200 单位场景出现一名 E1 无法到位；同场景修改前版本 52 项全通过，
确认是本次扩大转弯范围引入的回归，已撤销该扩大范围。最终两模式 200/200 到位，约 26.63 秒，
无停稳重叠，原来 50/100 单位、对向瓶颈、受保护固守单位及队形位置断言均保留并通过。
矿车方向旧测试曾按固定 8 帧反算，重导 32 帧后产生 30 项脚手断言失败；改成从真实图集读朝向数，
扩展到每个方向，保持模型 +X 投影和逐像素点击两项独立断言，128 项通过。headless 跳过全部图像检查的 0 项轮次不计验收。

最终专项：vehicle_motion 142、unit_muzzle 2682、ground_control 20、traffic 52、yr_robot 200、
allied_abilities 198、miner_heading 128、savegame 100，共 3522 项。涵盖真实渲染/像素点击/炮口、
原机器人攻击与供电水陆通行、实际 IFV 进出乘员换武器、绕障追击、混编交通与磁盘存档恢复。
保留已有部分测试退出的 ObjectDB 残留警告，未将其计作已修复。

证据位于 C:/Users/admin/Temp/iron-tide-vehicle-20261023-{motion-v2,muzzle-v2,ground-v2,traffic-v2,yr-robot-v2,abilities-v2,miner-render-v2,save-v2}/reports。
修前悬浮/方向专项为 iron-tide-vehicle-motion-20261023-before，失败转弯候选和原版本对照为 traffic-v1 / traffic-baseline-v1。
VXL 来源与 SHA256 审计为 iron-tide-vehicle-32-20261023-v1/source-audit.json，FV 乘员炮塔来源在 iron-tide-ifv-32-20261023-v1。
各轮独立复制工程与 custom_user_dir，Windows / Godot 4.7.2，渲染专项使用 NVIDIA OpenGL；服务、端口、数据库 none，
source_unchanged=true、最终轮引擎退出 0，未操作玩家进程或存档。已查看真实机器人悬浮截图；动态手感仍为 pending_user_visual_confirmation。

## 2026-10-23 BGM 仅开战后播放

Music 原先在任意非空场景 context（包括 menu/results）都会启动播放。现统一只允许 battle context；
进入菜单、准备或结算立即停止并重置下局播放位置，菜单重播按钮禁用且提示“开战后播放”。
战斗场景先完成 setup/restore_pending，再根据 skirmish/prepared 判断：遭遇战开局播放，战役准备阶段安静，
真实 wave_started 启动音乐；后续波次不重启曲目。准备存档与战斗中存档按恢复状态分别处理。
暂停降音量、EVA/单位语音压低 BGM、音效独立、倍速不影响音高、用户音量/开关偏好均保留。

music_regression 48 项通过，使用真实 WASAPI 混音 PCM，包含真实 MP3、静音菜单、开关重启、单曲循环、
第一波和后续波次、准备/进行中存档磁盘恢复、结算停止和实际 UI 控件。music_ui_regression 26 项通过，
覆盖 1280x720/1600x900 设置页与战场设置，已查看菜单“开战后播放”截图。共 74 项。
早期脚手失败：未播放的 Music bus 可能不产生 PCM 帧；初始静音允许空帧，实际播放仍强制检查非空 PCM；
读档会同时暂停 world 与 SceneTree，现通过真实 HUD 继续按钮恢复，不绕过该规则。失败轮原样保留。
证据：C:/Users/admin/Temp/iron-tide-battle-only-bgm-20261023-{audio-v3,ui-v1}/reports。
两轮 source_unchanged=true、退出 0，独立工程和 custom_user_dir，服务/端口/数据库 none；未修改玩家设置或存档。
音频时序与设置界面实际体验 pending_user_visual_confirmation。

## 2026-10-23 Windows 朋友试玩包

基于提交 d38dcb5，在仓库外从 Git 快照导出 Windows x86_64 release（Godot 4.7.2），
包含 EXE/PCK、启动说明、引擎许可和资源哈希清单，不包含开发存档、原始 MIX、SDK、测试或导入缓存。
试玩版独立使用 `%APPDATA%/IronTideFriends`，不读取开发版 `Iron Tide RTS` 存档。

真实 release 导出冒烟发现导入资源不能通过原始文件路径读取：Music 的 FileAccess.file_exists
导致曲目未发现，AudioStreamMP3/WAV.load_from_file 不适用于导出后重映射的音频。
改为 ResourceLoader.exists + load(...)，保留原音频缓存、音量、开战播放与生命周期规则。
此包包含 music.gd / ra2_sfx.gd 的修正，源文件哈希见包内 build-manifest.json；不是未修改的 d38dcb5 快照。

music_regression 48 项、audio_lifecycle_regression 78 项通过。
相同游戏源码/资源的 release QA 包增加临时测试 autoload，以独立 custom_user_dir 走真实菜单→大厅→遭遇战，
18 项通过，包含音乐播放、E1 语音、灰熊攻击音效、建造完成 EVA，以及源文件清单中的 1612 个 WAV 全量加载。
第一次音频遍历使用导出目录原文件名得到 0 项，改用独立源资源清单逐项加载，未将空遍历算作通过。
交付包移除 QA autoload/测试清单；最终 ZIP CRC 与解压字节核对通过，实际解压路径（含空格）运行 EXE，
正常主菜单截图检查、退出 0。已检查 QA 战场截图；跨机器体验仍待朋友实测。

证据：C:/Users/admin/Temp/iron-tide-package-20261023-d38dcb5/（导出日志、smoke、QA、最终包解压副本）；
专项证据为 C:/Users/admin/Temp/iron-tide-package-{music,audio}-20261023-v1/reports。
专项 source_unchanged 验证通过，无数据库、网络业务服务依赖；未操作开发者原存档或已有游戏进程。
最终包：C:/Users/admin/Downloads/IronTide-Windows-x64-20261023.zip，110171160 字节。
SHA256：8580a69618a919d6c4c929425651580e7ab20277d9172ea22a9bc3ac1b02948e。

## 2026-10-26 尤复突击队普通攻击与 C4

本机原版 rulesmd.ini（哈希见 ALLIED_ABILITIES.md）为武器/弹头/能力参数来源。
RA2YR_ReSource 的 CheckAndApplyBomb 仍是占位；参考 Phobos 原引擎武器选择挂钩交叉核对，
在 Godot 独立实现，不将逆向仓库当作完整原版源码或运行对照。

GHOST/TANY/PTROOP 的建筑 C4 改为普通攻击接近后安装，不占技能槽；旧存档能力数组恢复时移除旧按钮。
TANY 对载具、GHOST 对舰船选择 Sapper；GHOST 对陆地坦克仍用 MP5。
CCOMAND 对建筑用 FakeC4 直接结算武器伤害；PTROOP 对单位保持心控。
修正按目标选武器后的射程、护甲过滤、索敌、近身追击、混编右键命令以及攻击移动续行。
从本机 MOUSE.SHP 补出 C4/破坏光标。没有修改规则数据和存档格式。

使用 run-navigation-building.ps1 -Suite <suite> -Render -RunRoot <new-directory>：

| 专项 | 检查数 | 外部证据目录后缀 |
|---|---:|---|
| commando_attack_regression | 118 | c4-v3 |
| allied_abilities_regression | 198 | allied |
| skill_hotkey_regression | 173 | skills |
| savegame_regression | 100 | save |
| unit_fire_regression | 188 | fire |
| command_transition_regression | 64 | orders |
| tactical_target_regression | 60 | target |
| cursor_regression | 62 | cursor |

共 963 项通过，覆盖 RA2 与扩展模式。证据根为 C:/Users/admin/Temp/iron-tide-c4-20261026-<后缀>/reports。
各轮 source_unchanged=true、engine_exit_code=0；隔离项目、custom_user_dir；服务/端口/数据库 none。
各自运行期间输入未漂移；allied/skills/save 后仅修正新增测试脚本，最终生产代码相同。
未操作原有游戏进程、玩家设置和存档。真实入口 launch_game.ps1 -PrepareOnly 返回 Ready；git diff --check 通过。
早期 c4-v2 因新增测试局部变量无法推断类型而失败，补充 Vector2 注解后重跑；失败证据保留，不计入通过结果。

专项覆盖真实混编右键、自动索敌、接近后安装、延时摧毁、工程师拆弹、CanC4=no、固守、停止、
普通移动不被抢占、攻击移动续行、主副武器/精英分流、原版光标帧，以及旧 C4 技能数组归一化。
代码/状态通过不等于逐帧原版一致；爆破动作、光标和声音实机体验仍为 pending_user_visual_confirmation。
盟军剩余机制缺口见 ALLIED_ABILITIES.md；本轮不标为盟军全面完成。
此改动尚未重新制作朋友试玩 ZIP；2026-10-23 旧包不包含本轮修正。

## 2026-10-26 矿场制造技能在收起菜单后保留

原制造矿车按钮属于 _command_box，随单位详情父容器一起隐藏；技能栏只接受选中单位。
现把矿场制造入口移到独立 ability_panel，选中己方矿场时显示矿车图标、制造状态及暂停/取消按钮。
展开和收起共用同一入口，切换建筑/单位时清理旧引用；生产、科技门槛、扣费与退款规则不变。

refinery_skill_ui_regression 120 项通过：RA2/扩展模式、1280×720/1600×900、展开/收起、
真实 Viewport 鼠标点击制造/暂停/继续/取消、已付退款、切换矿场、回到单位技能、科技锁定原因及边界布局。
production_hold_regression 44 项通过；hud_layout_regression 584 项通过，覆盖至 2560×1440。
合计 748 项；证据目录 C:/Users/admin/Temp/iron-tide-refinery-{skill,layout}-20261026-v2/reports，
以及 C:/Users/admin/Temp/iron-tide-refinery-hold-20261026-v1/reports。
各轮 source_unchanged=true、engine_exit_code=0；独立项目和 custom_user_dir；服务/端口/数据库 none。
实际启动入口 PrepareOnly 返回 Ready，git diff --check 通过；未操作原有游戏进程、玩家设置或存档。

v1 失败保留：新测试第二座矿场尚在建成动画，补齐可生产前置；旧 HUD 测试仍用已迁移的 Q 部署，
按现行 UnitSkillLayout 的 E 特殊技能槽更新点击和热键断言，未降低行为检查。
已查看两模式 1280×720 收起状态截图，图标及制造按钮位于底部技能条；实际体验仍为
pending_user_visual_confirmation。本轮未重打朋友试玩包。

## 2026-10-26 飞行高度、航迹和朝向资源

本机 rulesmd.ini（SHA256 3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef）
提供高度、Jumpjet 速度/爬升/转向/加速及 Fly 参数；参考边界与适配细节见 ALLIED_ABILITIES.md。
七种现有空中单位使用独立 UnitFlight；生产先绑定机场/机位再处理集结命令。
高度贯穿模型、命中几何、炮口、血条与冷却圈，空中绘制层高于地面建筑。
ORCA/BEAG/HORNET/SHAD 从本机原始 VXL 生成 32 朝向，SHAD 保留四姿态旋翼。

运行 iron_tide/tests/run-navigation-building.ps1 -Suite <suite> -Render -RunRoot <独立新目录>：

| 专项 | 检查数 | 证据目录后缀 |
|---|---:|---|
| flight_motion_regression | 196 | motion-20261026-v5 |
| unit_muzzle_regression | 3546 | muzzle-20261026-v4 |
| logistics_regression | 142 | logistics-20261026-v3 |
| unit_fire_regression | 188 | fire-20261026-v3 |
| batch_rally_regression | 42 | rally-20261026-v3 |
| attack_cooldown_indicator_regression | 42 | indicator-20261026-v3 |
| factory_tabs_regression | 318 | factories-20261026-v2 |
| savegame_regression | 100 | save-20261026-v2 |

合计 4574 项通过，覆盖 RA2 与扩展模式。证据根 C:/Users/admin/Temp/iron-tide-flight-<后缀>/reports。
八轮 source_unchanged=true、engine_exit_code=0，godot.log 无 SCRIPT ERROR/ERROR；
每轮独立项目与 custom_user_dir，服务/端口/数据库 none。未操作玩家进程、设置或存档。
生产逻辑在上述各轮期间一致；后续资源修正与测试脚手修正由最后 motion/muzzle 重跑覆盖。
实际入口 launch_game.ps1 -PrepareOnly 返回 Ready，git diff --check 通过。

飞行专项覆盖原版高度/JumpjetSpeed、真实速度与机头一致、转向限速、反向目标收敛、
气球悬停/可降落、悬停攻击先转向、生产停机位、垂直起飞、起飞中实际存盘/恢复、
七种空中单位两模式，以及 32 朝向/夜鹰全部 128 姿态帧与阴影有效性。
最终资源候选与来源指纹在 C:/Users/admin/Temp/iron-tide-flight-facings-20261026-v2/source-audit.json；
19 个运行资源复制后逐个 SHA256 核对。本机 MIX 只读，未改动原版安装资源。

失败记录保留且不计入通过：motion-v3 发现 SHAD 元数据四姿态但首版生成器只有一姿态；
重生成全部旋翼帧。muzzle-v3 仍以模型半径估算高度，更新为独立原版 1500 高度预期后重跑；
motion-v4 的阴影帧检查错误访问不存在的 img 字段，改从 Texture 读图后完整重跑 v5。
已检查战机、飞行兵与夜鹰运行截图；原版精确倾斜/俯仰、停机坪模型坐标和坠机仍未完成。
实际视觉与操作手感为 pending_user_visual_confirmation；未重新制作朋友试玩 ZIP。

## 2026-10-26 矿场制造按钮头像被挤没

用户实机截图显示制造中仅有两行文字。此前只检查 Button.icon 非空，未证明最终可见；
38px 按钮的 expand_icon 与两行文字共同参与适配，头像没有独立布局空间。
现改为按钮内独立 40×30 TextureRect 与两行 Label，容器最小尺寸反馈到按钮，
子节点忽略鼠标，沿用原点击/右键处理。头像不再随 disabled 状态被按钮自动缩放。

refinery_skill_ui_regression 192 项通过，覆盖两模式、两分辨率、展开/收起、
空闲/制造/暂停的原始 CMIN 头像路径、显示尺寸、文字不重叠、按钮边界以及原生产交互。
证据：C:/Users/admin/Temp/iron-tide-refinery-portrait-20261026-v1/reports。
source_unchanged=true，engine_exit_code=0，日志无脚本错误；独立项目与用户目录，服务/DB none。
已查看 1280×720 扩展模式收起且制造中的实际渲染截图，头像可见。
PrepareOnly 返回 Ready，git diff --check 通过。实机观感仍 pending_user_visual_confirmation。

## 2026-10-26 建筑普通攻击冷却圈

AttackCooldownIndicator 增加 Building 分支并接入建筑 WORLD_HUD 绘制，
只读取真实 _cd/cooldown，不修改武器、计时或存档。沿建筑血条右端定位，屏幕尺寸固定。
己方有武器建筑冷却时显示黄色圈，选中且可运转的就绪建筑显示青色圈；
断电保留冻结的实际冷却，不显示虚假的就绪状态；未建成、无武器、敌方及不可见建筑隐藏。

attack_cooldown_indicator_regression 82 项通过（保留原 42 项单位检查），
新增两模式巨炮真实开火、半冷却像素变化、0.5/1/2/4 倍缩放、断电冻结、
支援离线、选择切换、建造/死亡/敌方/无武器边界及重绘不推进战斗检查。
证据 C:/Users/admin/Temp/iron-tide-building-cooldown-20261026-v2/reports；
source_unchanged=true、engine_exit_code=0，无脚本错误，独立项目/用户目录，服务/DB none。
v1 测试靶距 160 小于巨炮最小射程 165，未触发开火；修正夹具为 400 后完整重跑，失败证据保留。
已查看扩展模式巨炮半冷却截图；PrepareOnly Ready。纯展示改动，用户实机观感仍
pending_user_visual_confirmation；不代表新增了超级武器/技能冷却显示。

## 2026-10-26 资金不足全价仍可下单

根因：Building.enqueue/Battle.request_structure 与生产 tick 已支持分段付款，
HUD 的 _funds_block_reason、首次按钮创建和 _queue 却额外要求全部造价，
造成侧栏与矿场技能入口不一致。移除这层准入限制，资金提示改为说明扣费/等待/续造；
前置、队列容量、停机位和预约科技检查不变，未修改生产账本或存档字段。
原版参考及完整源码边界见 ALLIED_ABILITIES.md 的 FactoryClass 记录。

渲染回归顺序执行：production_reason_regression 70、production_hold_regression 72、
unit_cancel_regression 178，共 320 项通过，两模式真实鼠标入口及状态检查。
覆盖不足全款/零资金下单、零资金冻结、到账精确付完自动完成、已付款建筑零资金选址、
未付订单取消不退款、部分生产退实际已付、右键暂停/取消、手动暂停不自动恢复，
以及前置/容量/国别/建筑预约约束和暂停订单的实际磁盘存档恢复。
证据根：C:/Users/admin/Temp/iron-tide-installments-{reason-20261026-v2,hold-20261026-v3,cancel-20261026-v2}/reports。
三轮 source_unchanged=true、engine_exit_code=0，最终日志无脚本错误；隔离项目/用户目录，服务/DB none。
PrepareOnly Ready，git diff --check 通过。生产行为已通过目标入口验证，提示观感仍待用户实机确认。

早期失败保留：reason-v1 新夹具局部变量重复导致解析失败，修正后完整重跑；
hold-v1/v2 暴露旧夹具读档后全局暂停泄漏到下一模式，增加每模式运行状态隔离后重跑；
cancel-v1 并行窗口抢焦点导致输入可用性断言失败，改为顺序独立执行，未删除断言。
本轮未推送或重新制作朋友试玩包。

## 2026-10-26 左下角选中头像向上堆叠

旧 sel_strip 是固定 86px 高度的 HBox 横向滚动，最多显示 24 个头像。
现为四列 GridContainer，底边固定在小地图上方，根据头像总高度向上伸展，
上方避让情报栏和顶栏；仅超出可用高度时竖向滚动。取消前 24 个截断，
保留每单位血量/军衔、单击定位与双击同类选择。选择减少自动缩回，重选重置滚动。
UnitIcon 自带边框，移除外层重复皮肤边框，避免额外留白撑宽到技能栏。

hud_identity_regression 626、hud_layout_regression 584，共 1210 项通过。
新专项覆盖两模式、1280×720/1600×900、1/4/5/12/24/40 个单位，
四列数量、向上增长/固定底边、24 个以内无滚动、无侧向滚动、地图/技能/情报避让、
溢出末行可达、实际鼠标点击定位与减少选择后缩回；原布局覆盖至 2560×1440。
证据 C:/Users/admin/Temp/iron-tide-selection-stack-20261026-v2/reports 和
C:/Users/admin/Temp/iron-tide-selection-stack-layout-20261026-v1/reports。
两轮 source_unchanged=true、engine_exit_code=0；隔离项目/用户目录，服务/DB none。
已查看 1280×720 扩展模式 24 个头像全部向上堆叠截图。PrepareOnly Ready，git diff --check 通过。
v1 发现重复皮肤留白导致宽度溢出及末行不可达；修正后完整重跑。
旧身份测试仍断言 RA2 不显示技能，已依据当前 Q/W/E 原生部署入口更新，不修改技能实现。
用户实机观感仍 pending_user_visual_confirmation；未推送或重新打包。

## 2026-10-26 多功能步兵车车身点击卸人

pointer_deploy_target 原先只接受 deployer 步兵且排除所有载具容量，
所以 FV 已有 E/D 卸人却没有车身鼠标入口。增加已单选、存活、己方且有存活乘员的 FV，
光标与左键释放共用同一目标判断，显示已有原版 deploy 光标并调用 Unit.deploy → request_unload。
保持空车普通选择、显式指令优先、Shift/框选/快速双击同类选择，未改卸载落点和安全检查。

boarding_cursor_regression 184、deploy_pointer_regression 102，共 286 项通过。
两模式美国大兵、重装大兵、工程师、狙击手实际上车与车身左键卸载，
检查光标无副作用、乘员显形/座位清空、武器/炮塔恢复、空车光标复原，
以及晕眩、混编、显式移动、Shift、框选、快速双击边界；原步兵部署鼠标入口回归通过。
证据 C:/Users/admin/Temp/iron-tide-ifv-pointer-{unload,deploy}-20261026-v1/reports；
source_unchanged=true、engine_exit_code=0，日志无脚本错误，独立项目/用户目录，服务/DB none。
已检查载人 FV 悬停部署光标截图；PrepareOnly Ready，git diff --check 通过。
行为通过专项，光标与点击手感仍 pending_user_visual_confirmation；本轮未推送或重打包。

## 2026-10-26 飞行兵悬停浮动

JUMPJET 原始 JumpjetNoWobbles 使 UnitFlight 视觉高度在巡航时恒定，
按用户反馈增加表现浮动，保留原始运动参数。2.4 秒一周期、待机上下各 2.5px，
移动逐步减弱到 0.8px，起飞高度 0.65–1.0 区间平滑渐入，按单位种子错开相位。
只改 visual_lift，统一现有模型/拾取/炮口/血条锚点，地面坐标、订单和逻辑高度不改变。

flight_motion_regression 214 项通过：保留全部七种空中单位回归，两模式新增真实动画 tick
振幅检查、世界坐标与逻辑高度不变、速度影响、落地零偏移、错峰、实际渲染与拾取高度一致。
证据 C:/Users/admin/Temp/iron-tide-jetpack-sway-20261026-v1/reports；
source_unchanged=true、engine_exit_code=0，无脚本错误，隔离项目/用户目录，服务/DB none。
已查看浮动高点截图，保存高低两相位；PrepareOnly Ready，git diff --check 通过。
悬浮感属于表现调整，仍 pending_user_visual_confirmation；未推送或重打包。

## 2026-10-26 尤复盟军清单与战斗要塞

审计发现 GGI、ROBO、GAROBO 已接入，BFRT 此前完全缺失。本次新增独立资源/规则包、
生产前置、5 人 OpenTopped 武器与冷却、移动射击、乘员防空指令、E/鼠标卸载、
载具接触碾压、乘员视野与开火暴露、满载存档和此次新增前的精确指纹兼容。
完整范围与尚未接入的秘密科技、驻军、反潜机、墙体碾压等见 [YR_FORTRESS.md](YR_FORTRESS.md)。

本轮通过 1693 项：yr_fortress 166、boarding_cursor 194、allied_abilities 198、savegame 100、
fog_rules 491、unit_fire 188、yr_robot 202、yr_guardian 154。
专项使用原 Unit/Building/Projectile、生产队列、鼠标输入和存档入口；savegame 含冷启动进程读取。
测试均在工程外副本、独立 custom_user_dir 运行，网络/服务/端口/数据库 none。
8 轮 source_unchanged=true、engine_exit_code=0；交付复核运行代码、数据、素材指纹无漂移。
之后的差异仅为旧 fog_rules 测试的技能栏定位纠正、测试 UID 和本文档，不是运行源码替换。

证据汇总：`C:/Users/admin/Temp/iron-tide-bfrt-export-20261026-v1/regression-summary.json`。
具体 reports：

- `C:/Users/admin/Temp/iron-tide-fortress-20261026-v3/reports`
- `C:/Users/admin/Temp/iron-tide-fortress-pointer-20261026-v1/reports`
- `C:/Users/admin/Temp/iron-tide-fortress-allied_abilities_regression-20261026-v1/reports`
- `C:/Users/admin/Temp/iron-tide-fortress-savegame_regression-20261026-v1/reports`
- `C:/Users/admin/Temp/iron-tide-fortress-fog_rules_regression-20261026-v2/reports`
- `C:/Users/admin/Temp/iron-tide-fortress-unit_fire_regression-20261026-v2/reports`
- `C:/Users/admin/Temp/iron-tide-fortress-yr_robot_regression-20261026-v2/reports`
- `C:/Users/admin/Temp/iron-tide-fortress-yr_guardian_regression-20261026-v2/reports`

已查看 BFRT 32 向图集及扩展模式实际载人/卸载鼠标截图。实际工程 PrepareOnly 返回 Ready，
git diff --check 通过。候选 30 个运行资源逐字节匹配发布目录，5 个原 MIX 哈希未变，
核对结果在候选 `delivery-audit.json`。未覆盖完整基础 RA2 数据、玩家存档或试玩 ZIP。

失败过程保留：fortress v1 的断言全过，但恢复后禁用场景的物理空间尚未激活，移动探针报错；
修正测试激活/等待时序后重跑通过。fog_rules v1 仍要求矿车制造按钮位于旧 sel_panel；
按已有 refinery_skill_ui 专项及当前 HUD 的 ability_panel 更正断言后完整渲染回归通过。
最初 headless robot/guardian 退出报告资源残留，最终渲染重跑没有该输出；没有据此宣称全工程无泄漏。
画面、语音和操作感仍为 `pending_user_visual_confirmation`，本次未推送或重新打包。

## 2026-10-26 建筑正常运转时串入受损动画

用户报告光棱塔、电厂莫名显示摧毁外观。核对本机原始 artmd.ini 与已导出的 SHP：
GAPRIS_A 完好 Start=0/End=9，受损 Start=10/End=19；旧导出仅消费 LoopStart/LoopEnd，
两种状态均回退为 0–19，充能后半段必然显示受损塔头。
GAPOWR_A 实际为 0–7 完好、8–15 受损、16–31 阴影；旧完好循环为 0–8，
每轮末尾混入受损首帧，受损循环 8–16 又混入阴影。没有发现这些切帧会扣建筑生命。

新增 `ra2pipe/building_animation_ranges.mjs`，在原导出流程中读取 Start/End 后回退，
显式循环字段仍优先；按同图受损段起点截断完好区间，并处理已核实的电厂 SHP 布局。
不全局改变 LoopEnd 的口径，不改变生命值阈值、伤害、武器冷却或建筑交易规则。
同步修正当前运行元数据 10 项：GACNST、GAPOWR、GAOREP、GAAIRC、GADEPT、ATESLA、
GAYARD、GACSPH、GAWEAT、GASPYSAT。只改区间/可见帧数，未改 PNG、单位或玩法规则包。
GAWEAP 已有静态厂房分层校正保持优先；导出工具的独立边界测试通过。
50 个健康状态区间静态核验通过，元数据前后对照与来源记录在
`C:/Users/admin/Temp/iron-tide-building-animation-ranges-20261026/metadata-changes.json`。

实际 Godot 渲染回归 974 项通过：building_animation 422、defense_art 468、building_exit 84。
新增原图固定区间断言覆盖两模式、敌我双方、100%/70%/30% 血量、120 秒连续取帧，
以及真实光棱塔 `_fire()` 触发和充能后段；查看了满血电厂与光棱塔充能截图。
既有建成闪烁、受损分层、船坞出兵和出口流程保持通过。
三轮 source_unchanged=true、engine_exit_code=0，交付时全部指纹无漂移，PrepareOnly Ready。
独立项目/custom_user_dir；服务、端口、数据库、协议连接 none，未操作玩家存档。
证据汇总 `C:/Users/admin/Temp/iron-tide-building-animation-ranges-20261026/regression-summary.json`，
具体 reports 为 `iron-tide-building-healthy-animation-20261026-v3`、
`iron-tide-healthy-anim-defense_art_regression-20261026-v1`、
`iron-tide-healthy-anim-building_exit_regression-20261026-v1` 下的 reports（均位于用户 Temp）。
前两次动画探针误用了 Unit 的开火 API、以及不存在的 enemy_power_low 字段，保留失败记录；
改用实际 Building._fire 与 Battle.enemy_power.low 后完整重跑，未删除业务断言。
实机表现仍 `pending_user_visual_confirmation`；从原启动脚本重开加载新元数据。
未推送或更新旧试玩包。

## 2026-10-26 超时空军团兵目标冻结表现

根因：AlliedAbilities 只有 temporal_by 行动锁、无敌与 temporal_work 累计，以及周期射线和文字；
目标模型未接冻结材质。独立 helper temporal_visual.gd 以既有双向关联驱动蓝色凝滞、条纹和淡出，
房色 shader 默认关闭此分支；每个目标单独复制材质，取消/关联失效时恢复原材质并重绘。
进度从现有 work/max_hp 读取，不改变抹除耗时、伤害或存档格式；读档后由状态重新构建视觉。
射线色依据本机 rulesmd.ini:601 ChronoBeamColor=128,200,255；凝滞纹理是独立 Godot 适配。
目标完成抹除走原死亡清理/经验/事件，只不播放普通爆炸和倒地表现；未使用传送 WARPOUT 替代 WARPAWAY。

实际 Godot Compatibility 渲染验证 862 项：temporal_visual 74、allied_abilities 200、yr_fortress 166、building_animation 422。
覆盖两模式下步兵/坦克/建筑、共享房色隔离、基准房色 null 材质、原色像素恢复、进度淡出、
取消和孤立关联、传送恢复不误冻、抹除无倒地停留、保存恢复；既有 IFV/BFRT 与建筑动画回归通过。
查看实际冻结和半抹除截图。每轮独立项目/custom_user_dir，服务/端口/DB/协议 none，未操作玩家存档。
全部 source_unchanged=true、engine_exit_code=0；最终源文件逐项比对无漂移，原启动脚本 PrepareOnly Ready。
证据：C:/Users/admin/Temp/iron-tide-temporal-visual-20261026-v4/reports/delivery-summary.json；
其它 reports 位于同一 Temp 下 iron-tide-temporal-allied-20261026-v1、iron-tide-temporal-fortress-20261026-v1、iron-tide-temporal-building-20261026-v1。
初次探针修正 GDScript 字符串类型推断；后续像素比较发现裁剪包含攻击者转向的 42 个像素，
将裁剪收敛到目标本体后仍保持恢复像素差严格为零，失败记录保留；同时确保取消时立即重绘状态文字。
实机外观 pending_user_visual_confirmation。需关闭旧游戏，从 iron_tide/启动游戏.bat 重开。
本轮未推送、未更新旧试玩压缩包。

## 2026-10-26 全武器线迹审计与导弹尾线接入

详见 [WEAPON_LINES.md](WEAPON_LINES.md)。扫描运行态 38 条线类武器配置、14 条尾线/Trailer 弹体配置，
清单保存在专项 reports 的 ra2-weapon-audit.json / iron_tide-weapon-audit.json。
原尤复 artmd.ini 通过只读 YrSource 导出到 assets/ra2/fx/projectile_visuals.json；
导出入口 ra2pipe/projectile_visuals.mjs，未更改游戏安装内容或玩法规则表。
根因是追踪分支不记 _trail、真实 SHP 绘制后直接返回；另有尾迹缺 Iso.dir 转换。
现在记录实际移动路径，先画尾线后画弹体，按原素材分为线迹/烟迹/鱼雷尾流；每段受迷雾可见性约束。
分裂射线使用自身 beam spec，修正电弧分裂误画普通激光；补 IsRailgun 渲染与尤复前缀 ChronoBeam 蓝色识别。
伤害、弹速、追踪转向、命中、冷却和存档格式保持既有路径；最大 48 个采样点，不逐帧创建尾迹节点。

最终 Godot Compatibility 渲染/运行回归 1790 项通过：weapon_trail 222、unit_fire 188、defense_fire 716、allied_abilities 200、sonic 464。
实际发射 FV、NASAM、AEGIS、ORCA、BEAG、GGI；对比有/无尾线截图，验证真实弹体仍显示、飞行中不提前扣血、
命中仍有伤害、有界路径、迷雾段过滤、现有存档字段保存/恢复；查看爱国者尾线及多类射线/尾流截图。
既有连发/转向门槛、瞬时光棱伤害、分裂唯一目标、超时空、IFV、声波与建筑命中断言保持通过。
五轮独立项目/custom_user_dir，服务/端口/DB/协议 none，无玩家存档写入。
全部 source_unchanged=true、engine_exit_code=0、无 SCRIPT ERROR；交付源文件指纹无漂移，PrepareOnly Ready。
证据汇总：C:/Users/admin/Temp/iron-tide-weapon-trail-20261026-v4/reports/delivery-summary.json。
其余四轮位于同一 Temp 的 iron-tide-lines-final-<suite>-20261026-v1/reports。
早期专项为补迷雾检查时复用了无迷雾的旧 fixture，出现空服务引用；随后创建真实 fog 并同步 fog_of_war 配置，
避免触发存档的地图状态不匹配校验。保留失败输出，未放宽存档校验或业务断言。
实机观感 pending_user_visual_confirmation；原启动脚本重开加载。本轮未提交/推送，也未替换旧试玩包。

## 2026-10-26 飞行兵空中误播步行动画

根因在 Unit 动画路由，不是素材缺失：本地 artmd.ini [RocketeerSequence] 已有 Fly/Hover=292,6,6、
FireFly=370,6,6，但 _draw_ra2_sprite 在移动时直接选 Walk（8 起），_fire_sequence 仍选 FireUp（164 起）。
现在按既有 is_air_target（air_lift > 0.1）选择空中 Fly/Hover/FireFly；落地继续 Guard/Walk/FireUp。
只调整动作选择，原绘制锚点、悬浮幅度/高度、拾取、运动、伤害、空中死亡和存档结构不变。

flight_motion_regression 794 + deployed_attack_regression 22，共 816 项通过。
增加两模式、八方向、六种空地动作、三个帧时点的实际 _art_frame 固定原版区间断言，
以及实际开火入口选 FireFly、开火结束回 Hover；保留全部飞行/悬浮/生产起飞/高度与拾取回归。
查看了空中移动实际截图；ground 与 air 的六种状态截图均在专项 reports。
两轮 source_unchanged=true、engine_exit_code=0、无脚本错误，最终文件指纹无漂移，PrepareOnly Ready。
隔离项目和 custom_user_dir，服务/端口/DB/协议 none，未写入玩家存档。
证据：C:/Users/admin/Temp/iron-tide-rocketeer-sequence-20261026-v1/reports/delivery-summary.json；
地面部署专项 C:/Users/admin/Temp/iron-tide-rocketeer-ground-20261026-v1/reports。
实机动画 pending_user_visual_confirmation；关闭旧游戏，从原启动脚本重开。未推送或更新旧试玩包。

## 2026-10-26 矿区扩大

按“矿区再大一点”将 Battle 默认矿格阵列从 5×4 调为 6×5（目标格数 20→30）。
保持格距 46、最小间距 38、单格视觉尺寸与每片 6000 的总储量；仍裁掉水域、建筑/障碍和地图边缘的无效位置。
两模式的新地图均消费同一默认值；实际可放格数受地形裁剪，不能承诺每片实放 30 格。
存档恢复仍按记录还原已有矿点，旧布局不扩写；无需调整玩法表或存档格式。
PrepareOnly Ready；ore_passage_regression 171 项通过，覆盖真实移动订单/寻路/物理穿越矿石与宝石、
禁止建筑覆盖矿格及实体障碍边界。该脚手退出仍有 ObjectDB/resource 清理告警，不计为无错误退出日志。

初选 economy_detail_regression 为 178 项/36 失败；在外部隔离副本仅恢复 5×4 常量后，
相同 36 项断言全部复现（混装矿物、卸货等旧流程），已逐名称对比，不把经济专项标成通过，未擅改经济逻辑。
两侧新地图的既有地图断言通过；本次范围扩大未增加该专项失败。
三轮 source_unchanged=true，实际项目交付指纹无漂移；全部隔离项目/custom_user_dir，无服务、端口、DB 或协议。
证据 C:/Users/admin/Temp/iron-tide-larger-ore-20261026-v1/reports/delivery-summary.json；
基线位于 iron-tide-ore-baseline-check-20261026-v1，通行位于 iron-tide-larger-ore-passage-20261026-v1（同一 Temp）。
实机矿区大小 pending_user_visual_confirmation，新开对局生效；未推送或打包。

## 2026-10-26 飞机世界弹药显示

此前弹药只在 UnitLogistics.status 选中信息中出现。新增 aircraft_ammo_indicator.gd，在 WORLD_HUD 层的己方战机血条下
显示分格弹药条、当前/最大弹药、飞行/返航/待机、补弹百分比；无法补弹时明确“补弹暂停”，无机场时“等待机场”。
覆盖 ORCA、BEAG、HORNET 等实际 ammo_max>0 的己方空中单位，未选中也显示；敌军、隐藏/已死亡/装载单位不显示。
JUMPJET、SHAD 等无弹药限制单位及地面单位跳过。弹药沿用现有每轮齐射消费语义，不把一轮内每枚导弹算作独立弹药。
补弹进度直接读取 reload_elapsed 与现有 reload_minutes，不引入 UI 计时器，不改运动、消耗、补给或存档字段。
采用固定屏幕像素和随飞机高度移动的锚点；paint 后恢复 Iso 变换，保留血条和普攻冷却圈。

实际渲染/流程验证共 290 项：aircraft_ammo 66、logistics 142、attack_cooldown_indicator 82。
新专项覆盖未选中满弹、真实 consume_volley 后清空、实际返航入口、机场半补弹、断电暂停、补足待机、
敌军/隐藏/死亡过滤、无弹药单位过滤、重复读取不改变权威状态，比较满弹/空弹实际像素并保存各状态截图。
原返场降落、停机位、补给、航母回收和冷却圈回归通过；查看了实际补弹 50% 截图。
三轮 source_unchanged=true、engine_exit_code=0、无脚本错误；交付时输入指纹无漂移，PrepareOnly Ready。
独立项目/custom_user_dir；服务、端口、DB、协议 none，未写入玩家存档。
证据：C:/Users/admin/Temp/iron-tide-aircraft-ammo-20261026-v1/reports/delivery-summary.json；
另外两轮在同一 Temp 的 iron-tide-ammo-logistics_regression-20261026-v1 和 iron-tide-ammo-attack_cooldown_indicator_regression-20261026-v1。
实机布局 pending_user_visual_confirmation；重启原游戏入口加载。未推送或更新旧试玩包。

## 2026-10-26 集火指令结束与飞机单次出击

针对“单位像一直处于攻击模式、飞机补满又自动出击”，确认两处指令残留：Battle.force_attack 用攻击移动作为接近目标的入口，
却没有清除 attack_move；UnitLogistics.tick_return 在满弹时直接使用 resume_target 重发攻击命令。
集火现在明确清除 attack_move，目标失效时停止该次接近路线；普通移动立即清除旧目标和剩余连发，停止也取消连发。
保留自由开火姿态下射程内警戒、主动下达的攻击移动/巡逻与原有克制/残血评分；没有把所有单位改为停火或仅反击。
机场飞机一轮弹药耗尽后返航、降落、补弹、停靠；不再记录或恢复上一轮目标。resume_target 字段保留供旧存档读取，
补弹结束会丢弃其值。stop_command 将“取消旧命令”和“起飞”区分开：仅移动/攻击入口启用起飞，停止/固守不会唤醒停靠飞机。
满弹停靠不受机场随后断电影响。航母仍可在有效攻击命令下持续派出舰载机；改下普通移动后，回收飞机不再沿旧目标出动。
未改数据、伤害、资源、存档格式或默认自由开火姿态；原有闲置突击队自动接近/C4 行为仍保留。

实际 Godot 流程验证 714 项：command_transition 102、logistics 180、tactical_target 60、aircraft_ammo 66、commando_attack 118、unit_fire 188。
新断言覆盖 MTNK/E1/JUMPJET/CLEG/ORCA 显式集火与失去目标、替换移动及取消连发；ORCA/BEAG 真实起飞射击、返场、
仍存活旧目标、模拟旧字段恢复、补满后十秒停靠、停靠时停止/固守、断电、再下攻击可实际开火、空弹取消。
首轮物流回归因旧航母用例要求“改下移动后继续旧目标”而失败；新用例先断言取消后留在甲板，再经真实 force_attack 恢复，
仍验证存活飞机重用、损失补充与航母死亡清理，没有移除这些断言。
六轮 source_unchanged=true、engine_exit_code=0、无 SCRIPT ERROR，实际交付输入哈希无漂移；PrepareOnly Ready。
logistics / unit_fire 的引擎控制台退出时分别出现 9/41 个 ObjectDB、4/8 个资源清理告警，godot.log 未记录这段退出输出；
不能据此宣称全程无告警。断言及运行过程没有失败，清理告警留待独立定位。
全部独立项目/custom_user_dir；服务、端口、DB、协议 none，未触及玩家存档。
证据：C:/Users/admin/Temp/iron-tide-orders-final-20261026-v1/reports/delivery-summary.json。
关联证据在同一 Temp：iron-tide-sortie-final-20261026-v1、iron-tide-guard-final-20261026-v1、
iron-tide-command-ammo-final-20261026-v1、iron-tide-command-commando-final-20261026-v1、iron-tide-command-fire-final-20261026-v1。
实机指令手感待用户复核；重启启动游戏.bat 加载新脚本。未提交、推送或重打旧试玩包。

## 2026-10-26 星级单位识别与晋升特效

原有军衔随血条绘制，满血未选中时全部隐藏；升级仅有通用世界飘字。
新增只读 veterancy_indicator.gd，沿用已有一/二道金色 V 军衔语言，在单位血条左侧常驻固定屏幕尺寸的军衔牌。
不新增等级；仍为新兵、老兵、精英。世界血条移除重复的旧军衔绘制，编队头像军衔保持原样。
实际宣布晋升时加 1.25 秒金色扩散圈、短射线与上浮文字；原来世界飘字由随单位移动的高层 overlay 提示替代。
飞机读取真实飞行高度；隐藏、死亡、装载与未被己方看见的敌人不绘制。未见敌人的晋升不会缓存后补播。
临时特效时间使用 Node metadata，由单位真实物理 tick 推进、到时清除，不加入存档；静默恢复军衔只显示常驻牌。
未修改经验、升阶阈值、倍率、精英武器或音频选择。

真实渲染专项 veterancy_regression 114 项与 aircraft_ammo_regression 66 项通过，共 180 项。
验证实际击杀经验/晋升、满血未选中可见、晋升计时、精英双军衔、0.5/1/2/4 缩放、只读不变更属性、
装载/隐藏/死亡过滤、迷雾敌方过滤、静默恢复无闪光与飞机高度锚点；原弹药显示及补弹状态通过。
查看了 ra2-promotion.png 与 ra2-elite-zoom-1.0.png；只确认实际绘制，实机喜好 pending_user_visual_confirmation。
两轮 source_unchanged=true、engine_exit_code=0、无脚本错误/告警，交付文件指纹无漂移；PrepareOnly Ready。
隔离项目/custom_user_dir，服务、端口、DB、协议 none，未写玩家存档。未提交、推送或打包。
证据：C:/Users/admin/Temp/iron-tide-rank-visual-20261026-v1/reports/delivery-summary.json，
补充回归 C:/Users/admin/Temp/iron-tide-rank-ammo-20261026-v1/reports。

## 2026-10-26 C4 进入建筑占地、退出与红闪

用户指出未进入建筑、缺红闪。只读核对命中本地 AlliedAbilities.tick_action：以建筑外侧 approach 为目标并允许 radius+24 容差，
在原点外额外约两段半径距离即安装，且只绘制 C4 文本。源规则 C4Delay=.03（1.8 秒），rulesmd.ini SHA256
3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef。
重新核对用户指定 ReSource 本地与远端 master 均为 b01d3cf93db69aca9b5cb5054ba04e4358963828，相关入口仍是 stub；
未把返回常量函数冒充完整原版实现。来源、RA1 交叉参考与 Godot 适配边界写入 ALLIED_ABILITIES.md。

CommandoCombat 接管 C4 approach/enter/exit；实际走入目标占地后安装、原路退出，只短暂忽略该目标的碰撞。
取消进入不留碰撞豁免，不消耗或驻军人员。放置仍使用原延时/归属/拆弹路径；攻击移动退出后恢复目的地。
建筑红闪读取真实 c4_left 并独立复制房色材质，与时间抹除复用同一材质恢复链；拆弹立即恢复，爆炸清理引信和持有者。
移除 C4 漂字/倒计时文本，避免把文字误作实际红闪。新增阶段和入口存在已有 special 字典中，不变更 schema 或内容摘要。

最终专项共 440 项通过：c4_entry 48、allied_abilities 200、commando_attack 118、temporal_visual 74。
新专项验证真实步入多边形后才装药、退出、临时碰撞豁免清理、停止、原引信时间、重复安装拒绝、工程师拆弹、
实际像素红闪与强弱变化、同阵营材质隔离、实际磁盘 slot 保存/校验/恢复进入与退出阶段、加载后重建红闪和最终击杀经验。
观察 ra2-c4-red.png：原正常区域红像素 1210，强闪 9379，弱闪 1367。不能据此声明与尤复逐帧一致。
原两个专项中直接站外沿单帧安装的准备流程改为真实移动等待，保留原爆炸/拆弹/C4与Sapper区别/攻击移动断言。
首轮 commando 有 4 项旧时序失败，更新遗漏的第三处准备入口后 118 项全通过，未减少断言。
四轮 source_unchanged=true、engine_exit_code=0、无脚本错误、最终源码指纹无漂移，PrepareOnly Ready。
allied / commando 退出控制台分别有 2/6 个 ObjectDB、1/3 个资源清理告警，godot.log 未保存该段退出文本；不宣称全程无告警。
全部隔离项目/custom_user_dir，服务、端口、DB、协议 none，真实磁盘存读仅发生在本轮隔离目录；未写玩家存档。
证据：C:/Users/admin/Temp/iron-tide-c4-entry-20261026-v2/reports/delivery-summary.json。
关联轮次为同一 Temp 下 iron-tide-c4-allied-20261026-v2、iron-tide-c4-commando-20261026-v2、iron-tide-c4-temporal-20261026-v1。
实机进入动作/红闪 pending_user_visual_confirmation；重启启动游戏.bat 生效。未提交、推送或更新旧试玩包。

## 2026-10-26 海军 32 朝向与异常生产目录

范围：将用户“海军32”按海军 32 朝向继续处理，同时核对异常可生产单位。核实 DEST/AEGIS/CARRIER/LCRF
原素材仅 8 朝向；CDEST 原版 TechLevel=-1 却进入船厂名单；CCOMAND/PTROOP 没有检查 RequiresStolen*Tech。
本机 rulesmd.ini 来源和哈希见 SOURCES.md，新 production_rules.mjs 导出目录内 30 个单位的生产限制。
不重写原 combat tables、单位身份或存档 schema/hash；尚未实现秘密科技获取，不能把这些单位开放给普通兵营生产。

四种盟军 VXL 舰船重新生成 32 朝向/阴影，共十六个资源文件；海豚保持原版 SHP 八方向/完整动作。
候选输入为本机 MIX 的四个 VXL 和 unittem.pal；产物逐项核对 source-audit SHA256 一致。
GameData、Building 的下单与生产推进、HUD 目录/提示以及 UnlockGuidance 共用限制：
CDEST 移出普通目录，场景生成/模型保留；CCOMAND/PTROOP 卡片保留但锁定，注明盟军/尤里秘密科技未接入。
旧异常生产队列停止继续扣款/出兵，但仍能取消退回实付金额。普通海军、兵营、跨国家扩展模式和矿车双入口保留。
详情面板不再为秘密兵种宣称“科技条件已满足”或建议普通前置建造路线。

最终专项 2036 项：production_catalog 86、production_reason 70、factory_tabs 318、naval 1396、
savegame 100、unlock_guidance 66，均 failed=0、engine_exit_code=0、source_unchanged=true，无脚本错误。
naval 实际渲染逐朝向检查舰体/阴影非空、32 张图均不同、朝向与独立模型 +X 投影一致、锚点稳定和可选中，
并保留神盾/海豚目标域与真实伤害验证。查看了 ra2-CARRIER-32.png；这是冻结渲染夹具，不是水上寻路实测。
生产专项覆盖直接/AI can_queue 拒绝、资金不变、卡片/详情原因、已付队列冻结及准确退款、正常舰船/步兵和场景生成。
savegame 包含独立新 Godot 进程磁盘读取，全部使用隔离 custom_user_dir，未写玩家存档；服务/端口/DB/协议 none。

失败与调整：目录首轮 1 项把扩展模式误当成限制国家，修正为保留跨国家模式后通过。
unlock_guidance 首轮 6 项旧预期与后来已确认的预约科技、进度扣款规则冲突；测试显式解锁预约，断言无资金可下单且等待。
修正测试时一轮误将 void request_structure 用作布尔条件导致短路，改为分别请求并验证真实双订单；最终 66 项通过。
未削减既有队列/资金提示检查，增加预约前置断言。前五轮到交付仅此测试文件发生变化，运行时代码/数据/资源无漂移；
末轮 guidance 指纹与交付全量一致。无需重复执行未使用该测试文件的其它五个专项。

证据根均为 C:/Users/admin/Temp/：iron-tide-production-catalog-20261026-v3、iron-tide-catalog-reasons-20261026-v1、
iron-tide-catalog-factories-20261026-v2、iron-tide-naval32-20261026-v2、iron-tide-catalog-savegame-20261026-v2、
iron-tide-catalog-guidance-20261026-v3。汇总在最后一个目录 reports/delivery-summary.json。
生成候选：iron-tide-naval32-candidate-20261026-v1/source-audit.json。
实际工程 PrepareOnly Ready；实机转向/提示观感 pending_user_visual_confirmation。未提交、推送、更新旧试玩包。
后续：秘密科技渗透解锁、TANY 数量上限和更完整尤复科技树仍需单独实现；本轮不是全单位机制迁移完成。

## 2026-10-26 全单位 VXL 姿态与阴影

用户原版/现版截图不能直接证明尤复换了高清模型；ROBO 已核实为本机尤复原始 VXL。
本轮修复 HVA 头/帧/节读取、VXL span 寻址、节变换和旋转法线、共同地面阴影投射，
统一重烘 61 个单位 VXL 与 FV 三个换装炮塔，全部 32 朝向，共 317 项产物哈希与候选一致。
运行时分离车体/炮塔朝向阴影后取 alpha 并集，避免双层叠黑；缓存上限 128。
画布因阴影扩大后，点击中心改用当前车体可见像素，保留 SHP/建筑路径。
模型来源、再生成入口与未覆盖部分见 MODEL_RENDERING.md；生产目录规则不变。

最终 Godot 7534 项全部通过：model_render 336、vehicle_motion 142、unit_muzzle 3546、naval 1396、
flight_motion 794、selection 178、box_ui_release 240、unit_art 902；均使用实际渲染 runner。
另 node --test ra2pipe/vxl_lib.test.mjs 的 4 项文件布局/变换/投影/法线测试通过。
实际工程 launch_game.ps1 -PrepareOnly 返回 Ready。查看了 ROBO、SHAD 运行截图，尚无用户观感确认。

失败与修复：第一次 vehicle_motion 有 2 项悬浮车体中心不可点击，定位为透明画布中心并修复真实 art_center，
补充全模型可见中心断言后通过。通用 unit_art 首轮 16 项失败：12 项为升降高度抵消的浮点完全相等，
改用 Rect2.is_equal_approx 并记录实际矩形；4 项为飞行兵空中期待 Walk/FireUp 的旧夹具，
增加明确地面 Walk/FireUp 与空中 Fly/FireFly 双状态，不将飞行兵退回走路动画，最终增加至 902 项通过。
SHAD 旧四姿态期望改为本机 HVA 两姿态/64 帧，动画速度仍是当前适配值，非原版时序认证。

每轮 source_unchanged=true、engine_exit_code=0；最终检查八轮 godot.log 无 ERROR/WARNING/leak 匹配。
前七轮与最终交付仅 tests/unit_art_regression.gd 不同，运行时代码/数据/资源指纹全部一致；
最后一轮与交付全量一致。所有测试使用隔离项目/custom_user_dir，服务、端口、DB、协议 none，未写玩家存档。
证据根 C:/Users/admin/Temp/：iron-tide-model-render-20261026-v2、iron-tide-model-motion-20261026-v2、
iron-tide-model-muzzle-20261026-v1、iron-tide-model-naval-20261026-v1、iron-tide-model-flight-20261026-v1、
iron-tide-model-selection-20261026-v1、iron-tide-model-box-20261026-v1、iron-tide-model-art-20261026-v2。
汇总在第一个目录 reports/delivery-summary.json；候选为 iron-tide-models-20261026-candidate-v1/source-audit.json。
改动前资源/导出器备份为 iron-tide-model-render-20261026-baseline，未提交、推送或重打试玩包。

状态：pending_user_visual_confirmation。重启启动游戏.bat 可读取更新；不是原引擎像素级复刻，
原版 VPL 光照/调色、遮挡与相机仍有适配差异。步兵/建筑 SHP 及专用建筑防御炮塔未套用本次 VXL 重烘。

## 2026-10-26 精英武器与升级缺项

用户指出星级单位武器应变化。实际核实已有大部分 ElitePrimary/EliteSecondary/EliteWeaponN 路径，
本轮没有重复实现或强行给每级换枪；新专项按独立本机 INI 夹具对照 31 个目录项和 70 把关联武器。
普通/老兵保留基础武器，精英切换；覆盖 GI/GGI 部署、IFV 七类乘员及精英卸载恢复、不能训练单位拒绝经验。
具体缺口：BFRT 运行单位未装配原始 VeteranAbilities/EliteAbilities；HORNET 未装配升级属性/精英炸弹。
Unit.ensure_source_veterancy 仅对这两个单位补缺失定义；旧快照恢复同样补缺失缓存并静默刷新，保留军衔/经验。
不改数据表/存档 schema/配置摘要、不改母舰与舰载机经验传递；BFRT 无原始 ElitePrimary，保持 20mmRapid。
ROBO 的 Trainable=no 保持。Para 原始八向 MGUN 补入缺失 Anim 的回退；四类既有枪口回退在 E/别名路径继续生效，
原版显式 Anim 始终优先。修复 AlliedAbilities.weapon 对 nullable min_range 调用 float 的运行错误，缺省取 0。

最终专项 3048 项：elite_weapon 2488、veterancy 114、savegame 100、logistics 180、yr_fortress 166，均 failed=0。
前两项实际渲染，后三项 headless。精英专项逐项比较武器 ID、Damage/Range/ROF/Burst、弹头/弹体、原炮口素材；
实际灰熊/坦克杀手/IFV/HORNET 发射连发并推进到命中，对照护甲倍率、晋升加成与逐发取整，检测 VTMUZZLE/VTEXPLOD 实例。
旧 BFRT/HORNET 缺缓存状态通过隔离磁盘 save_slot/read_slot/校验后真实 restore，等级和经验不丢失，精英武器/属性重建。
既有 savegame 另在新 Godot 进程读档。实际项目 PrepareOnly Ready，五轮源码前后以及交付指纹一致。
服务/端口/DB/协议 none，全部使用隔离 custom_user_dir，未操作玩家当前游戏进程或存档。

首轮 36 项失败：18 项 HORNET 相关因 min_range=null 中断武器装配；6 项 Para 炮口配置漏接；
12 项伤害夹具漏了既有逐发 floor 量化，修正独立预期而未改伤害逻辑。修复后精英专项 2488 项通过。
logistics 退出有 9 ObjectDB/4 资源未释放告警，fortress 退出有 4 ObjectDB/2 资源告警；引擎退出码均 0，
不能宣称全程零告警，本轮不扩展为测试退出资源回收重构。
证据根 C:/Users/admin/Temp/：iron-tide-elite-weapons-20261026-v2、iron-tide-elite-ranks-20261026-v1、
iron-tide-elite-save-20261026-v1、iron-tide-elite-logistics-20261026-v1、iron-tide-elite-fortress-20261026-v1。
汇总在第一个目录 reports/delivery-summary.json。特效观感 pending_user_visual_confirmation；未提交、推送或重打试玩包。

## 2026-10-26 光棱支援、超武、情报建筑、维修平台和说明

本轮按本机 Yuri rulesmd.ini / artmd.ini 与实际 SHP/PAL 独立接入；具体玩法、来源及适配边界见 ALLIED_ABILITIES.md 和 SOURCES.md 新增小节。
光棱支援目标从敌人改为主攻塔、修正支援距离和 45 ticks 等待；超时空改为两次地图点击且原子校验落点；
闪电风暴补云层/爆炸、IonWH 对单位和建筑伤害；卫星/裂缝接入统一 fog；围墙自动付费连接；精炼收益飘字；所有目录说明及选中单位“说明”入口。
维修厂改为真实上平台、逐辆服务和驶离；等待车向门外侧停靠，修满车继续开到门外另一侧，不停在门口堵后车。复用既有 special 快照，不改存档 schema。

最终选定验证共 2235 项、全部 failed=0：support_buildings 228、repair_depot 52、savegame 110、support_visual 10、fog_rules 491、wall 936、economy_chain 216、refinery_skill_ui 192。
除 support_buildings 和 savegame 为 headless，其余使用实际 OpenGL renderer。支援覆盖两模式/双方；超武、情报、墙费、单位说明覆盖两模式。
维修专项推进真实 Unit._physics_process、碰撞、转向和费用，截图记录平台上的车辆；同一入口后车让道、前车驶离、后车继续进场均通过。
存档专项新增维修进入/退出节点引用与阶段、无持久碰撞例外、闪电风暴目标和延时；并保留新进程读档验收。
生产说明按钮经过实际 pressed 信号打开完整说明窗口；检查暗云/闪电/爆炸、超时空蓝色效果、裂缝范围真实截图，未代替用户实机确认。

过程中发现并纠正：云层 AltPalette 不可共用 ANIM.PAL；维修连续指令需清掉旧退出状态；修满仅走到门口仍会堵住下一辆，因此追加离开通道的目的地。
等待车测试最初只调用 _process_repair，遗漏真实 _physics_process 的转向推进；已使用真实物理入口，而非放宽运行逻辑。
旧 economy_chain 的 headless 模式跳过布局帧，产生 2 个状态条位置失败；使用它要求的 renderer 后 216 项通过。
旧 wall 固定坐标的随机矿点污染了“相邻格可放置”前置，失败 1 项；只清理测试场地附近随机道具，保留碰撞/放置断言，936 项通过。

服务、端口、数据库、协议入口均 none；每次测试独立 custom_user_dir，未操作玩家当前存档或停止游戏进程。每轮源码前后稳定，最终全源文件指纹与 repair_depot v6 的 source_after 相同；较早专项保留自身快照，不重写历史证据。
实际项目 launch_game.ps1 -PrepareOnly 输出 Ready；修改文件 git diff --check 通过。未提交、推送或重打包。
最终证据（C:/Users/admin/Temp/）：
- iron-support-check-20261026-v4/reports/delivery-summary.json（汇总及来源、边界）；
- iron-repair-platform-20261026-v6、iron-support-save-20261026-v2、iron-support-visual-20261026-v2；
- iron-support-final-20261026-fog_rules_regression；
- iron-support-final2-20261026-wall_regression、iron-support-final2-20261026-economy_chain_regression、iron-support-final2-20261026-refinery_skill_ui_regression。

状态 pending_user_visual_confirmation：重启 启动游戏.bat 查看。闪电风暴来源建筑被毁后的独立持续、超时空敌军/步兵规则及原版逐像素光照不包含在本轮实现中。

## 2026-10-26 双击同型限制在当前可视区域

用户要求双击全选只覆盖当前可视区域。此前 _apply_selection 直接调用全地图 select_all_of_type；现仅双击传入 visible_only=true，按实时 canvas transform 投影单位 art_center，过滤 viewport 外、不可见/死亡/乘载单位和 HUD 实际可见面板覆盖的屏幕点。HUD covers_world_pixel 使用侧栏、顶栏、小地图、日志、单位面板等实时边界，折叠/展开状态自然生效。显式 T 同型命令沿用原范围，框选与 Shift 追加路径未改。

新增 double_click_view_regression，继承原 selection_regression，通过真实 SubViewport 鼠标按下/释放入口验证两模式、1280x720/1600x900、0.5/1/2/4 倍缩放、四边出屏、侧栏/小地图/顶栏/单位面板遮挡、隐藏/死亡/乘载/敌方排除，以及下一次双击重新按当前画面筛选。保留原部署、技能、空地取消与选择手势断言。434 项通过，实际 OpenGL renderer；PrepareOnly Ready，目标 diff --check 通过，源文件前后稳定。服务/端口/DB/协议 none，独立 custom_user_dir，未操作玩家存档或关闭游戏。
证据：C:/Users/admin/Temp/iron-double-click-view-20261026-v1/reports/。未提交或推送；重启 启动游戏.bat 生效。

## 2026-10-26 原版弹药图标

按用户要求移除飞机上方的大弹药条、数量文字和补弹进度条，改用本机尤复 PIPS2.SHP 第 12 帧（6x13 原始像素）逐发显示；选中或悬停才显示，空弹不画图标，补满一发才增加一枚。显示只读取原有 UnitLogistics，不修改消耗、返航、补给和停电暂停规则。

aircraft_ammo_regression 使用实际 OpenGL renderer，94 项通过、失败 0；覆盖两模式 ORCA/BEAG/HORNET、选择/悬停、空弹、补弹与暂停、敌方/隐藏排除，以及 0.5/1/3 倍缩放的原生尺寸图标。PrepareOnly Ready，目标 diff --check 通过。证据：C:/Users/admin/Temp/iron-ammo-pips-check-20261026-v1/reports/。源码前后稳定，独立 custom_user_dir；服务、端口、数据库、协议 none，未停止玩家游戏或操作存档。未提交、推送或重新打包。

状态 pending_user_visual_confirmation：重启游戏查看实际弹药图标；截图已核对原大面板不再显示。

## 2026-10-26 Ctrl 数字编队复核

用户要求 Ctrl+数字编队。当前 HUD/Battle 已有 Ctrl+1..9、0 编组（0 对应第十组）、数字召回、双按定位、Alt+数字仅定位，本轮未修改游戏运行逻辑。实际 SubViewport 按键专项覆盖两模式，46 项通过，包含独立分组、重新编组替换成员、空选不覆盖、文本框输入隔离、死亡成员清理、建筑编组、装载期间保留/卸载后恢复。

旧 control_group_regression 有 14 个失败，诊断为测试前提过时：镜头居中已适配右栏可玩区域，不能断言 camera.position 等于目标世界点；夜鹰按 Yuri 高度/爬升参数下降，原固定 90 tick 不足。改为检查真实 canvas 投影落在可玩区域中心，并按实际高度/爬升计算下降时间上限再加一秒；加入陆地前提断言。未放宽编队、装载或相机的运行规则。原失败证据保留在 iron-control-group-20261026-check-v2。

通过证据：C:/Users/admin/Temp/iron-control-group-20261026-check-v3/reports/。实际 OpenGL renderer、引擎退出 0、源码前后稳定；独立 custom_user_dir，服务/端口/数据库/协议 none，未操作玩家存档或停止游戏。只更新测试与本交接记录，未提交或推送。

## 2026-10-26 出售建筑倒放动画

根因：Building.retire_sold 在清理生产后直接 hide/queue_free，没有播放出售序列。新增 building_sale_fx.gd，以现有原版 Buildup SHP 倒放，沿用完成帧锚点、房色材质、建筑深度和 General.BuildupTime 时长；尚在展开时从当前帧开始收起。动画独立于建筑实体，不进入生产、碰撞、建筑存档列表或死亡事件；退款、停产、供电与占地释放时机保持现状。暂停冻结动画，结束自动释放。无 Buildup 资源的对象（例如围墙）保留直接移除，不伪造坍塌爆炸。

building_actions_regression 实际 OpenGL renderer 126 项通过，两模式真实出售入口，战车厂/电厂原版倒放首帧、中段、结束截图；覆盖暂停、视觉对象不进入建筑列表、重复出售不重复退款，以及原维修、供电、寻路释放、队列清理和出售语音断言。动画专项影响只限显示对象；未修改经济、战斗或存档契约。证据：C:/Users/admin/Temp/iron-building-sale-20261026-v1/reports/。环境审计 source_unchanged=true、engine_exit_code=0；独立 custom_user_dir，服务/端口/数据库/协议 none，未操作玩家存档或停止游戏。

实际工程 PrepareOnly Ready，目标 diff --check 通过。截图已核对收起中与结束画面；状态 pending_user_visual_confirmation，重启游戏观察实际出售观感。未提交、推送或重新打包。

## 2026-10-26 建造范围可视化

用户希望类似 RA3 显示建造范围。原预览只描已有建筑底盘。新增 build_range_preview.gd：放置模式绘制浅青色覆盖区与屏幕固定宽度外边线，把多个己方已完成建筑允许的网格中心合并，内部重叠边不重复绘制。按待放建筑真实占地、40 像素吸附和 80 像素邻接距离计算；船坞保留现有四倍邻接距离。地图边缘按完整地基裁剪。源建筑/占地/类别变化才重建几何，缩放只投影；售出后收缩、完成后扩大、退出放置不再绘制。

范围只表示邻接覆盖，不代表水陆、障碍、矿点或视野检查通过；红绿鬼影仍调用真实 build_spot_ok，提示明确“青色范围内仍需空地与视野”。邻接来源过滤与距离提取为展示和判定共用纯函数，保留原来的计算规则；未扩大建造距离或放宽放置条件。

验证 348 项通过：新 build_range_regression 52 项（两模式三种建筑，每种对 2091 个网格中心与实际放置入口比对；敌方排除、施工/完工/出售、地图边界、取消、结束、缩放和船坞截图），原 building_preview_regression 296 项（实际鼠标放置、占地/碰撞、费用、阻挡、水陆等）。初版专项测试变量缺少显式类型导致解析失败，已修正，失败证据保留在 v1；无放宽断言。

证据：C:/Users/admin/Temp/iron-build-range-20261026-v2/reports/ 与 iron-build-range-placement-20261026-v1/reports/。实际 OpenGL renderer，退出 0、source_unchanged=true；隔离 custom_user_dir，服务/端口/数据库/协议 none，未停止玩家游戏或操作存档。实际工程 PrepareOnly Ready，目标 diff --check 通过。pending_user_visual_confirmation：已检查截图，实际观感需重启后体验。未提交、推送或打包。

## 2026-10-26 E 统一起立

用户要求混合站立/部署的步兵按 E 全部起立。根因：use_ability_selected 按技能 ID 对每个成员独立 toggle，站立者反而部署，且 GI/GGI 的原生 ID 不同导致混选只执行一类。现在两个原生部署技能共用目标状态：已选、存活、未乘载的原生 GI/GGI 中只要有人部署，目标为全部起立；都站立才统一部署。只调用与目标不同成员的原技能入口，保留眩晕、维修等能力限制，不强行修改状态或释放其他 E 技能。混合编队按钮显示“全部起立/全部部署”；键盘和按钮共享入口。D、其他单位的 E、Q/W 与存档未改。

两模式实际 HUD/键盘验证：ggi_skill_regression 96 项、skill_hotkey_regression 173 项，共 269 项通过。新增 GI/GGI 混选、两种选择顺序、站立领队、按钮、未选单位与 MCV 不受影响、受限成员及恢复；保留原武器、固守、盲区和伤害断言，以及其他 E 卸载等技能回归。初跑旧鼠标测试丢失窗口焦点，修正测试焦点前提后单独运行通过；旧 SHAD 2 秒登机脚手已不匹配当前原始飞行参数，改为按 height/climb 加等待余量，原登机和卸载断言保留。失败证据保留 v1。

证据：C:/Users/admin/Temp/iron-group-stand-20261026-v2/reports/、iron-group-stand-hotkeys-20261026-v2/reports/。OpenGL renderer，source_unchanged=true、退出 0；独立 custom_user_dir，服务/端口/数据库/协议 none，未操作玩家存档或停止游戏。实际工程 PrepareOnly Ready，目标 diff --check 通过。统一状态逻辑已通过真实按键验证，按钮实际观感 pending_user_visual_confirmation。未提交、推送或重打包。

## 2026-10-26 导弹弯曲轨迹与消散尾迹

用户明确指出“导弹像一根直线，缺少飞行弯曲和尾迹”。检查发现：现有二维追踪从出生即指向目标，显示未接导弹高度；SHP 恒取 frame 0，未消费 Rotates；尾迹随 Projectile 命中删除而整段消失。

本轮是表现适配：对使用原版 UseLineTrail 的追踪导弹独立增加抬升/下压曲线，以及空中目标视觉高度；尾迹记录已经显示过的位置，不随新目标位置整条重新拉直。DRAGON/MEDUSA 使用原 32 朝向帧随实际显示切线旋转。命中/超时后创建不含战斗行为的尾迹节点，按原颜色/衰减参数淡出，暂停不推进，结束自行释放；仍检查雾区可见性。烟迹/水迹保留原采样间隔；导弹光尾为 8 像素采样、最多 48 点。二维飞行、ROT、伤害、命中、弹速、光束和声波规则未改。

曲线复用已序列化但追踪导弹原来未使用的 _arc_from/_arc_to/_arc_len/_arc_h 参数，不新增 schema 字段或数据摘要。飞行中存读档恢复显示位置；旧存档已有的零曲线参数维持旧弹直到其消失，新发射导弹使用新表现。高度包络为独立 Godot 适配（sin 曲线，距离 * 0.16，限制 12..90 显示像素），不是声称复刻 YR EXE 的三维导弹物理。原 CourseLockDuration/Acceleration 的完整物理迁移不包含在本轮。

最终 1342 项断言通过：weapon_trail 328（两模式 FV/NASAM/AEGIS/ORCA/BEAG/GGI 实际武器；记录轨迹偏离端点直线 >10 显示像素、朝向帧、可见尾迹像素、雾区、命中后淡出、暂停、无重复伤害及实际存读档位置），unit_fire 188、defense_fire 716、savegame 110（含冷进程）。weapon_trail 为实际 OpenGL，其余 headless。图像已核对 FV 中段弯曲尾迹；pending_user_visual_confirmation，需重启后体验。

证据目录均位于 C:/Users/admin/Temp/：iron-missile-trajectory-20261026-v2、iron-missile-unitfire-20261026-v1、iron-missile-defense-20261026-v1、iron-missile-save-20261026-v1。每轮 source_unchanged=true、退出 0，独立 custom_user_dir；服务/端口/数据库/协议 none。当前实际工程 PrepareOnly Ready，目标 diff --check 通过，未操作玩家存档/游戏进程，未提交/推送/打包。

限制：defense_fire 控制台退出仍提示 14 ObjectDB / 5 resources 未释放；godot.log 未包含退出清理内容，现有 runner 仍输出 PASS，因此这里只认 716 项断言通过，不宣称无错误退出日志。用本轮修改前的 iron-group-stand-hotkeys-20261026-v2/project 只读源码隔离副本复测，同样出现 15 ObjectDB / 6 resources 提示（iron-missile-defense-baseline-20261026-v1/console.log），证明此类清理问题此前存在；未将其当作本轮新修复或做无关清理。

## 2026-10-26 载具转弯迟钝：空旷地滚动转弯

根因：普通地面载具原有 _align_drive_velocity 在偏角达到 35° 时停住，20–35° 区间强减速。寻路拐点和局部避让反复触发，形成停转停走。原始 ROT 上限和移动速度没有被提高；本轮不是声称已完整移植尤复 locomotor。

新增 vehicle_steering.open_corridor：仅在有远距离移动命令、局部碰撞查询新鲜、附近无其他实体，且当前/中间/目标朝向三条带车宽的导航走廊均通畅时，将滚动转弯包络放宽至 65°。拥挤、障碍和终点附近仍用原 35° / 20° 平滑减速，避免恢复曾导致 200 单位堵塞的全局 85° 策略。速度沿实际车头方向，保持 ROT 限速；掉头先转向。矿车专用卸货、飞机和舰船控制不在此次改动范围。

修前同一测试复现六类车两模式共 12 个失败：空地 60° 转向均需约 0.25 秒才开始移动。修后灰熊 60° 为 0.0167 秒，90° 从 0.5333 降到 0.2667 秒；走出 80 像素分别从 1.0667/1.35 秒降到 0.9333/1.2167 秒。这是固定 60 Hz 专项数据，不代表用户帧率或观感承诺。

最终 390 项断言通过：vehicle_turn 176（MTNK/FV/SREF/MGTK/TNKD/AMCV，两模式，60/90/180°、侧滑、ROT、停止、邻兵/障碍/终点边界）；ground_control 20（绕障、追击、20 辆编队）；traffic 52（狭道对向、50/100/200 混编到位、零重叠）；vehicle_motion 142（OpenGL 渲染、32 朝向与悬浮等既有行为）。200 单位两模式全部到位，零重叠。

证据：C:/Users/admin/Temp/iron-turning-before-20261026-v1（修前预期失败）；最终 iron-turning-after-20261026-v2、iron-turning-ground-20261026-v1、iron-turning-traffic-20261026-v1、iron-turning-motion-20261026-v1，各自 reports/result.json 与 environment-audit.json。四轮 source_unchanged=true、engine_exit_code=0，隔离 custom_user_dir；服务/端口/数据库/协议 none。实际项目 PrepareOnly Ready，目标 diff --check 通过，未停止玩家游戏、未提交/推送/打包。

退出清理限制：turn/ground 控制台有 2 ObjectDB / 1 resource 提示。ground verbose 定位为 rock-and-awe.mp3 的 AudioStreamMP3/AudioStreamPlaybackMP3（cleanup-console.log），不是转弯脚本对象；修前 ground 单次重跑未出现，不能据此声称已证明为稳定旧问题或声称日志全清。本轮未扩张修改音频清理。手感仍为 pending_user_visual_confirmation，重启实际启动入口后体验。

## 2026-10-26 部署群控改为优先开启（替代此前“有人部署就起立”规则）

用户明确更新规则：选中可部署步兵只要有人尚未部署，就统一开启各自部署姿态；只有全部已部署时才统一起立。GI/GGI 不同原生技能也视为同一组部署意图。battle.use_ability_selected 目标状态改为 any(not is_deployed)，仅切换状态不一致成员，仍经各单位原生技能执行与限制。HUD 的“全部部署/全部起立”、开关高亮及说明同步使用该规则。单个单位保持自身 toggle；其他单位 E 技能、未选中单位和 D/鼠标单兵入口不改。

ggi_skill_regression 114 与 skill_hotkey_regression 173，共 287 项断言通过，均 OpenGL 实际 HUD/输入运行。覆盖两模式、GI/GGI 两种领队顺序、全站/混合/全部署、键盘与按钮、GI 卧倒/GGI 导弹武器分别保持、同兵种混合、未选单位/MCV 不受影响、受限成员不能强行切换、解除限制后的再次按键，以及原 Q/W/E 功能。受限成员导致部分起立时，下次按 E 仍按当前混合状态优先部署，这是本次规则的直接结果。

证据：C:/Users/admin/Temp/iron-deploy-priority-20261026-v1/reports/ 和 iron-deploy-priority-hotkeys-20261026-v1/reports/。source_unchanged=true、engine_exit_code=0；隔离 custom_user_dir，服务/端口/数据库/协议 none。保留既有共享脏工作区，未操作玩家存档或停止游戏。规则自动化验证通过；按钮表现 pending_user_visual_confirmation。未提交/推送/打包。

## 2026-10-26 移动命令连线

用户要求点击移动出现 RA2 风格连线。检查发现已有落点动画，但普通移动没有连线；旧 _draw_waypoints 未被绘制入口调用，而且只连接后续队列，遗漏当前 move_target。本轮独立新增 MovementOrderPreview，只读取己方选中、存活、未乘载且有移动命令的单位，连接当前位置 → 实际接受的编队终点 → order_queue。普通移动黄绿色虚线、攻击移动橙色虚线，终点小菱形；屏幕像素线宽不随等距缩放变化，超过 8 条时降低透明度。移除无消费者的旧队列绘制函数。

专用 ORDER_PREVIEW=4091 层位于迷雾之上、游戏 HUD 之下，只显示自己已下达的命令，不读取隐藏敌方订单，不输出寻路内部拐点或改变探索/视野。改点、停止、到达、取消选中、死亡、乘载和战斗结束均从现有状态消除连线；真实移动、寻路、编队和存档结构未改。这里显示命令目标链，不声称是车辆实际绕障轨迹或原 EXE 完整复刻。

movement_order_regression 两模式共 42 项断言通过：真实右键及 Shift 输入、接受后的目标坐标、编队攻击移动、替换/清队列、起点随单位更新、非法敌方选择过滤、死亡/乘载/到达/停止/取消选中/终局清理、直接攻击过滤、绘制前后探索及可见网格不变，以及 0.5/1/2 缩放和迷雾中的实际像素差。已查看 ra2-queue-1.0.png，单位与两段绿色虚线、目标点可见；pending_user_visual_confirmation。

证据：C:/Users/admin/Temp/iron-move-lines-20261026-v2/reports/（42 项；v1 是之前 40 项版本，不替代最终证据）。source_unchanged=true、engine_exit_code=0，OpenGL，隔离 custom_user_dir；服务/端口/数据库/协议 none。实际工程 PrepareOnly Ready，目标 diff --check 通过。未停止玩家游戏、未操作玩家存档、未提交/推送/打包。

## 2026-10-26 飞行起步与直飞接近速度

本轮核对全部七种带 air 标签的单位。原版 JUMPJET 使用 ROCK.SHP，RocketeerSequence 的 Fly/Hover/FireFly 均为 8 朝向；不是漏导出 32 朝向。ORCA/BEAG/SHAD/HORNET 的 VXL 图集、阴影和武器发射点仍为 32 朝向，不用重复 SHP 帧伪装新增视角。

unit_flight.gd 独立连续运动适配修正两处：JumpjetAccel 从每逻辑帧的速度增量转换到 world/s² 时补足第二个 15 Hz 时间因子；转弯半径限速只在实际偏角超过 20° 时启用，直飞仍受真实刹车距离限制。现有巡航上限、ROT、起飞高度、军衔/扩展加速、命中和弹药契约保持。Fly 的原有 Speed 适配未重新定标，本轮不声称与原引擎物理完全一致。

修前同一专项 114 项中失败 22 项（iron-flight-speed-before-20261026-v2）。修后已升空、无加成、60 Hz 的飞行兵首秒位移从 16.38 到 87.82 world，夜鹰从 19.66 到 89.43；95% 巡航分别在 0.20 / 0.1667 秒达到。两者巡航仍为 96.68 world/s。其余五类修前直线进入接近区也错误降速；修后在刹车距离之外保持各自巡航速度。保留停车距离和速度加成断言。

最终 1292 项断言通过：flight_speed 114、flight_motion 794、logistics 180、aircraft_ammo 94、savegame 110（含冷进程）。覆盖反向掉头收敛、原 ROT 上限、速度与机头一致、起降、全部原飞行动画、浮动与点击几何、运输卸载、返场补弹和存档。flight_motion / aircraft_ammo 使用实际 OpenGL，其余 headless；飞行兵空中移动截图已查看。

证据位于 C:/Users/admin/Temp/ 下：iron-flight-speed-after-20261026-v1、iron-flight-motion-after-20261026-v1、iron-flight-logistics-20261026-v1、iron-flight-ammo-20261026-v2、iron-flight-save-20261026-v1 的 reports/。五套 source_unchanged=true、engine_exit_code=0，隔离 custom_user_dir；服务/端口/DB/协议 none。实际启动项目 PrepareOnly Ready，未停止玩家游戏或操作玩家存档。手感与表现 pending_user_visual_confirmation；未提交、推送或打包。

保留失败证据：before-v1 为测试变量推导类型错误，已显式 float 后重跑；ammo-v1 误用 headless 而等待渲染，停止该隔离测试后按 -Render 重跑 v2，不计作通过。speed 退出有 2 ObjectDB / 1 resource、logistics 有 13 ObjectDB / 6 resources 清理提示；runner 的 godot.log 不含这些控制台退出信息，因此 1292 项代表断言通过，不代表日志完全无告警。

## 2026-10-26 战斗要塞乘员升级后飞速移动

根因已通过真实入载和射击击杀复现：Unit._refresh_veteran_bonuses 每次升级调用 _apply_physics，重新添加 CollisionShape2D 并恢复地面碰撞层。已隐藏的乘员在 OpenTopped.tick 中不断跟随车体，升级后与车体重叠，move_and_slide 的穿透恢复持续推动车体。速度字段未增加，但单乘员升老兵后实际每秒移动约 1649.92 world（预期 60），单帧约 30.55（预期 1）。多个乘员与精英升级同样复现。修前专项 168 项失败 84 项，其中部分卸载失败是车辆被推出地图后的连带结果。

最小修复：升级只刷新战斗属性/武器/表现，不重新初始化物理体；碰撞体仍在 setup 创建一次，装卸由 set_stowed 管理。同时 BattleSnapshot.restore 在对象引用恢复后，以 embarked_in 为准将乘员的碰撞层/掩码归零，兼容此前已经保存的错误碰撞状态。没有调用会清除攻击目标/连发状态的 set_stowed 来修复旧存档；冷却、军衔、隐藏和运输关系保持，存档格式不变。未改战斗要塞基础速度、巡航限速或伤害配置。

最终共 598 项通过：fortress_speed 208（RA2/扩展、1/5 名乘员、真实攻击升级、精英、重复升级形状数、每帧实际位移、整秒路程、旧错误碰撞存档恢复、正常卸载及车体升级）、yr_fortress 166、savegame 110、veterancy 114。专项十六组整秒路程均为 60/预期 60，修复没有依赖单看 velocity 数值。加载旧存档后也保持正确速度，乘员仍可卸载并恢复正常地面碰撞。

证据 C:/Users/admin/Temp/：iron-fortress-speed-before-20261026-v1 为修前；最终 iron-fortress-speed-after-20261026-v1、iron-fortress-combat-20261026-v1、iron-fortress-save-20261026-v1、iron-fortress-veterancy-20261026-v1 的 reports/。四套 source_unchanged=true、engine_exit_code=0。Windows/Godot 4.7.2，veterancy 为 OpenGL、其余 headless，独立 custom_user_dir；服务/端口/DB/协议 none。实际启动项目 PrepareOnly Ready，目标 diff --check 通过，无残留本轮测试进程；未停止玩家游戏或修改玩家存档，未提交/推送/打包。

限制：fortress_speed 退出控制台有 2 ObjectDB / 1 resource 清理提示，未称日志完全无警告。自动化位移修复通过，实际游戏体验 pending_user_visual_confirmation；需重启游戏加载新代码，已有错误存档可直接读取，无需删档。测试只修改隔离存档来模拟旧错误标记，未读取或覆盖玩家实际存档。

## 2026-10-26 矿车停采与建筑堵住卸货口

用户明确是单位受阻、游戏仍可操作，不是程序死锁。修前 mining_obstruction v7 的 90 项断言中 8 项失败，在 RA2/扩展两模式复现三条原因：矿石可通行但超时空落点/卸货驶离检查仍把它视作障碍；已锁定泊位的矿车不会因新建筑堵住入口而改选矿场；自动选矿及黑名单兜底只按距离选取完全隔离的矿点。

最小修复位于 unit.gd、economy_cycle.gd、refinery_traffic.gd。矿车专用落点检查允许穿越矿石，保留地界、水体、建筑、石头和地面单位限制；通用 landing_clear 默认继续保留资源占位，矿石增长/建筑放置规则不变。等待返场每 1.5 秒复查固定入口及倒车通道的静态障碍，改选可用矿场时释放旧 FIFO、清理旧路线/倒车状态；临时车辆占用仍等待原队列。所有矿场被堵时保留货物，入口重开后恢复。选矿及兜底按寻路连通区检查可达采集范围，不把暂时不可达永久禁用。没有改变普通单位转弯速度、伤害、存档格式或矿款数值。

最终 719 项通过：mining_obstruction 116、refinery_traffic 44、economy_chain 216（OpenGL）、ore_passage 171、auto_harvest 62、savegame 110（含冷进程）。专项覆盖矿口矿石、临时车辆占用、两个矿场同时封堵/重开、旧队列释放、围墙隔离矿点及拆墙恢复；实际 CharacterBody2D 行走和路径扫掠覆盖 CMIN/MTNK/BFRT 与电厂、战车工厂、矿场、空指部。普通工厂转角未复现卡住，不据此声称所有地图布局均已排除。

只读复制玩家 slot1.itsave 到隔离 custom_user_dir，正常校验/加载后明确解除加载暂停；冻结其它单位/建筑，仅推进六辆矿车 120 模拟秒，六辆均发生实际卸货。这是有边界的存档导航诊断，不是完整对局。原存档修前后 SHA256 一致：4274FB2476179DCF44CAE9B1C4D0B7EC357DA7BF043B9DB6E0FEB3E63BB6DB62。未写入玩家存档。

证据 C:/Users/admin/Temp/ 下的 reports/：iron-mining-obstruction-after-20261026-v2、iron-mining-refinery_traffic-20261026-v1、iron-mining-economy_chain-20261026-v2、iron-mining-ore_passage-20261026-v1、iron-mining-auto_harvest-20261026-v1、iron-mining-savegame-20261026-v1。六套 source_unchanged=true、engine_exit_code=0；Windows/Godot 4.7.2，独立项目/用户目录，服务、端口、DB、协议 none。实际启动项目 PrepareOnly Ready；目标 diff --check 通过。未提交、推送或打包。

保留失败边界：economy_chain v1 误用 headless，两个 UI 几何断言未通过；按既有完整断言用 OpenGL 重跑 v2 全部通过。早期诊断 v1 的无效单位 ID、v3 的缺少 preload、v5 的冻结未完成建筑均为夹具问题；v2 存档回放未解除暂停不作为停采证据，后续 v4/v7 修正。部分回归退出有 ObjectDB/resource 清理提示（traffic 2/1、ore_passage 6/3、auto_harvest 4/2），断言通过不等于退出完全无告警。实际玩家目标场景体验仍为 pending_user_visual_confirmation；需重启游戏载入新代码。

## 2026-10-26 超时空传送仪选框与前半部错位

用户截图为 GACSPH。原始主体 SHP 只包含后方支架，前方圆顶/底座是 art.ini 的 SuperAnim=GACSPH_E（Rate=0，完好 Start=0；GACSPH_ED 指向同 SHP 的 Start=1）。原渲染虽叠加圆顶，anchor/base_diamond/hit_test/placement_poly 仍仅消费主体，因此绿框偏左后、前半部无法点击且占地缺失。修前 building_animation 专项 434 项失败 12 项，覆盖 RA2/扩展的完好/受损前部点击、选框和真实占地。

building_shapes.mjs 将固定 E 层按 [0,1,1,2,3,3] 合入六帧原始主体（后三帧为阴影），记录 baked_layers。RA2Art 加载该元数据并过滤已合成层，避免重复阴影；F/G/H 三层充能动画继续独立绘制。没有手调图片位置或改变其它建筑素材。新增 chronosphere_structure.mjs 可从本机 YR 安装只读重建，导出前验证原始 SHP/调色板与项目旧图逐字节一致；重复重建输出一致，当前 PNG SHA256 54020fd51c9a6f4b7b938bf7f2110b4291695df71dfa1d2b9d4a6062dc0056a5。

旧存档包含 _fp_poly/_depth_anchor 派生缓存，恢复 baked_layers 建筑时重算完整占地及排序锚点，与 setup 按新资源创建的碰撞形状一致；保留建筑实例位置和业务状态，不要求拆除重建。savegame 专项以过期占地/排序缓存模拟旧存档，通过真实存盘/重载及冷进程验收。

最终 834 项通过：building_animation 434（OpenGL）、building_preview 284、savegame 116。证据在 C:/Users/admin/Temp/ 的 iron-chrono-alignment-after-20261026-v3、iron-chrono-building_preview-20261026-v2、iron-chrono-savegame-20261026-v2/reports/。三套 source_unchanged=true、engine_exit_code=0，隔离用户目录；服务/端口/DB/协议 none。已查看放大且隐藏其它单位的完好建筑截图，前后底座纳入同一选框；实际用户表现仍为 pending_user_visual_confirmation。正式项目 PrepareOnly Ready，Node 语法及目标 diff --check 通过，未提交/推送/打包。

中间失败保留：alignment-after-v2 / savegame-v1 发现 SHP 元数据加载白名单未转交 baked_layers，导致重复层过滤与旧存档重算未触发；补齐真实加载入口后上述最终三套通过。原有十二项对齐断言未删减；总数 438→434 是 E 层合入主体后不再进入独立动画层健康帧循环，新增元数据/阴影去重和三个充能层断言保留。

## 2026-10-26 维修厂机械臂姿态重叠

用户截图为 GADEPT。根因是通用 idle 分支在不存在 activeanim 时放行所有层，导致 SpecialAnim A/B/C 与 IdleAnim D 同时绘制；special 状态又同时显示 A/B/C，未表达维修臂连续阶段。原始 extracted/art.ini [GADEPT_A/B/C/D] 分别是伸出、工作、收回、待机；A/C 的 End=10 注释明确是帧数，受损 Start=10 应覆盖 10..19，之前错误收缩为单帧 10。修前 building_animation 466 项中失败 24 项。

新增 repair_arm_animation.gd 独立实现 GADEPT 专用互斥状态：idle → repair_extend → repair_work → repair_retract → idle；使用已有可保存的 _anim_state/_anim_group_t，持续回血不再重启 special，伸出/收回期间中断按进度衔接。只在载具实际到达 RepairDock.pad 的 6 world 范围内设置 _repair_active，不因车辆仅发出远程维修命令就动作。回血量、间隔、花费、进出站碰撞与排队合同保持。其它建筑动画选择逻辑不改。building_animation_ranges.mjs 与 GADEPT.json 同步修正 A/C 受损帧区间，并添加 Node 原始帧语义断言。

最终 640 项通过：building_animation 466（含双模式、两健康状态、五阶段单层可见、持续循环、受损十帧及上一轮超时空传送仪对齐）、repair_depot 54（真实鼠标维修入口、到站回血/扣款、出站和下一辆进入）、savegame 120（维修动作阶段与计时存盘重载、只显示工作层、冷进程）。前两套 OpenGL，最后 headless。证据 C:/Users/admin/Temp/iron-repair-overlap-after-20261026-v1、iron-repair-overlap-depot-20261026-v1、iron-repair-overlap-save-20261026-v1 的 reports/；均 source_unchanged=true、engine_exit_code=0，独立用户目录，服务/端口/DB/协议 none。已查看待机/工作截图，只保留对应单套机械臂。正式项目 PrepareOnly Ready，目标 diff --check 与 Node 测试通过，无残留本轮 Godot 测试进程；未操作玩家存档、未提交/推送/打包。实际表现 pending_user_visual_confirmation，重启游戏加载新代码。
## 2026-10-26 空指部停机错位

原停机坐标是建筑原点周围的 44 world 方阵，没有消费原始 GAAIRC 的四个 DockingOffset，也未抵消 VXL 模型中心与底部绘制锚点的差值；返航还保留 8 world 到点容差及少量高度。修前机场专项 88 项中失败 52 项。

新增 airport_dock.gd，将本地 art.ini 停机偏移映射到现有 188x162 GAAIRC/GAAIRCBB 画布的四个停机坪，再通过当前等距投影反算位置。使用导出 VXL origins 的平均值保持导航目标稳定，实际各朝向模型中心误差在一个素材像素内。适用 GAAIRC/AMRADR 当前画布，其它机场保留原退路；航母坐标仍取舰体位置。落地消除位置容差与剩余高度，旧存档的 parked/rearming 飞机就地归位，不要求重建或删档。

四向真实返航进一步发现：同一机场已经落地的飞机仍使用空中碰撞层，阻挡从上方经过的返航机。仅在返航高度达到 0.95 时，对同机场高度不超过 0.1 的飞机临时排除本次移动碰撞，移动后立即撤销本次新增的例外；普通空中交通碰撞保持。专项验证全部例外已清理。中间 v2/v3 各 8 项失败保留：固定目标未解决该碰撞问题，不能把朝向舍入当作已证实的阻塞根因。

最终 498 项通过：airport_docking 104（RA2/扩展、ORCA/BEAG、四个独占泊位、完好/受损建筑、旧停机位置、四向真实返航和碰撞例外清理）、logistics 180、savegame 120（含冷进程）、aircraft_ammo 94。证据位于 C:/Users/admin/Temp/iron-airport-dock-after-20261026-v4、iron-airport-logistics_regression-20261026-v1、iron-airport-savegame_regression-20261026-v1、iron-airport-aircraft_ammo_regression-20261026-v1 的 reports/。机场与弹药用 OpenGL，其余 headless；Windows/Godot 4.7.2、隔离用户目录，服务/端口/DB/协议 none。四套 source_unchanged=true、engine_exit_code=0，无残留本轮测试进程。logistics 退出仍有 11 ObjectDB / 5 resource 清理提示，不称日志完全无警告。

已查看四架入侵者落位截图，正式启动项目 PrepareOnly Ready，目标 diff --check 通过；未改玩家存档，未提交/推送/打包。实际游戏表现 pending_user_visual_confirmation，重启游戏加载新代码。
## 2026-10-26 小地图视野框倾斜

用户截图中的白色取景框为斜矩形。原 minimap 将地形/单位/迷雾直接按 world XY 缩放成正方形，却把旋转等距相机的屏幕四角反算回 world，导致主画面与雷达方向不同。此次统一使用真实 Viewport canvas 的线性投影，去掉相机平移后将完整地图等比例容纳到控件。地形、水面、迷雾纹理、资源/建筑/单位标记及事件提示共用该投影；点击/拖动使用逆变换，投影菱形之外的空白不开始拖动，已有拖动越界按世界边界夹取。

取景框继续使用 camera_play_rect 排除右侧生产栏，内部四边横平竖直；缩小到视野超出地图时，沿真实地图边缘裁剪，裁剪边仍可能为斜线，这不代表再次发生方向错位。没有改主相机、单位订单、迷雾可见性规则、存档或地图内容。界面方向按此次用户反馈更新，不再沿用旧“未投影地图上的旋转视野轮廓”视觉预期。

833 项通过：minimap 159（0/正负45度、横/竖/正方形布局、独立角度/缩放几何预期、真实 GUI 点击拖动、四种姿态的水平/垂直轮廓像素、极端缩小边界）、box_ui_release 240（跨小地图框选与手势归属）、sidebar_camera 434（侧栏、边缘、缩放与居中）。证据 C:/Users/admin/Temp/iron-minimap-projection-20261026-v1、iron-minimap-box-20261026-v1、iron-minimap-sidebar-20261026-v1 的 reports/。Windows/Godot 4.7.2/OpenGL、独立项目和用户目录，服务/端口/DB/协议 none；三套 source_unchanged=true、engine_exit_code=0。已查看 minimap.png，地形呈与主画面一致的等距方向，白色取景框为矩形。正式项目 PrepareOnly Ready，目标 diff --check 通过；未操作玩家存档、未提交或推送。实际游戏表现 pending_user_visual_confirmation，重启加载新代码。
## 2026-10-26 战车工厂旗帜突然歪倒

GAWEAP_A 原始 SHP 共 60 帧，0..14 为直立正常旗帜，15..29 为受损倾斜旗帜，30..59 为阴影。既有 art.ini 区间 0..15 / 16..29 与本机 SHP 的实际分段不符，正常循环每 4.5 秒进入受损第一帧，受损循环则漏第一帧。原图第 0/14 帧矩形 (101,66,22,29)，第 15/16/29 帧为 (105,68,38,30)，已查看原始图集确认姿态分界。

仅修正 building_animation_ranges.mjs 的 GAWEAP_A 对应素材分段及正式 GAWEAP 动画描述，普通 0..14、受损 15..29、可见 frames=30；同步 GAWEAP_A 图集元数据，不修改 PNG、着色、建筑血量阈值或全局动画计时。受损姿态继续保留，未来 art_build 导出使用同一修正规则。

building_animation 新增 GAWEAP 原图导入/层画布检查、两模式两健康值跨多个周期的精确帧集合及 4.51 秒截图。修前 494 项失败 4 项，均为两个模式的正常串帧/受损缺帧；修后 v2 全部 494 项通过，包含既有超时空传送仪、维修机械臂及其它建筑动画回归。Node 区间测试也通过。证据 C:/Users/admin/Temp/iron-factory-flag-before-20261026-v1 和 iron-factory-flag-after-20261026-v2/reports/。v1 修后同样通过，但放大截图旗杆被顶栏遮挡；v2 只调整截图相机取景并完整重跑，已目视确认正常旗杆直立。

Windows/Godot 4.7.2/OpenGL、独立项目及用户目录，服务/端口/DB/协议 none；最终 source_unchanged=true、engine_exit_code=0。正式项目 PrepareOnly Ready，目标 diff --check 通过，无残留本轮测试进程；未改玩家存档、未提交或推送。实际游戏表现 pending_user_visual_confirmation，重启加载新资源描述。
## 2026-10-26 间谍停在建筑旁无法渗透

专项从四类已实现建筑（GAPOWR/GAREFN/GAPILE/GAWEAP）八个方向、两模式的 500 world 外发出右键指令。修前命令均可下达，但 64 次接近有 42 次卡住：A* 终点被吸附到建筑外的可走格，AlliedAbilities.tick_action 持续使用该路径，同时要求接近另一个精确建筑边缘点，间谍在最终路点附近来回，无法触发完成。旧能力测试直接把间谍摆到 approach 点，仅测即时收益，没有覆盖实际远处走近。

仅对 allied_infiltrate，在最后路段、距实际接近点两格以内且已到最终路点附近时切换到物理直行。其后必须实际进入目标 footprint 才消费间谍/结算收益；进入运动仅临时排除所选目标建筑碰撞，其它碰撞保留，且本帧撤销新增例外。没有新增可保存阶段/字段，也未调整全局寻路、工程师或 C4。鼠标默认渗透目标显示 enter；右键和 Q 技能保留同一动作入口。可渗透建筑目录及窃款/断电/训练数值保持，不宣称补齐研究所秘密科技等历史缺口。

最终 728 项通过：spy_infiltration 346（真实活动建筑碰撞、两模式四类建筑八向接近、进入占地后消费、正确单次收益、例外清理、物理障碍拒绝穿透、停止后不自恢复、己方/未完成目标拒绝、目标死亡取消、真实 Viewport 右键及 Q+左键入口）、allied_abilities 200、savegame 120（含冷进程）、cursor 62。原能力测试只把三处“立即结算”推进改为实际进入所需步数，原收益断言未删除。

证据 C:/Users/admin/Temp/iron-spy-before-20261026-v2（128 项失败 42）、iron-spy-after-20261026-v3、iron-spy-allied_abilities_regression-20261026-v1、iron-spy-savegame_regression-20261026-v1、iron-spy-cursor-20261026-v1 的 reports/。最终专项与 cursor 用 OpenGL，其余 headless；Windows/Godot 4.7.2、隔离项目及用户目录，服务/端口/DB/协议 none。四套 source_unchanged=true、engine_exit_code=0。allied_abilities 控制台退出有 2 ObjectDB / 1 resource 清理提示，不称完全无告警。正式项目 PrepareOnly Ready，目标 diff --check 通过；未操作玩家存档，未提交或推送。进入表现与鼠标观感 pending_user_visual_confirmation，重启加载新代码。

中间夹具失败保留：before-v1 缺少局部变量显式类型导致脚本解析失败，停止该隔离 Godot 后修正；after-v2 的 barrier 继承禁用 process_mode，使其不参与物理碰撞，继而产生已释放实例访问。v3 将建筑和障碍保持 ALWAYS，只停止它们的处理回调，真实物理边界和全部原断言通过；不把 v2 当作业务修复验收。
## 2026-10-26 点击基地显示建造范围

BuildRangePreview 支持未进入放置模式时选中已完成、存活的己方 HQ 显示青色扩建区域。沿用当前己方建筑邻接来源、BUILD_ADJ_RANGE、网格和地图边界；未拿起具体建筑时按点中心显示基础区域，拿起建筑后自动改为其真实占地及船坞四倍邻接距离。该区域是邻接提示，仍需通过占用、迷雾、水陆和生产库存等实际放置检查，未改变建造资格或扩大业务范围。

绘制入口移至 Battle._draw 中唯一一处，使基地选择和放置共用缓存/画法；上一帧仍有区域时继续请求一次重绘，清掉取消选择、基地消失或对局结束后的残留。选择单位/普通建筑、敌方基地、未完成/死亡基地时不显示；拿起建筑又取消后，若仍选着基地则恢复基础区域。

106 项通过：build_range 86（两模式真实鼠标点击基地、无需 armed_build 即生成区域、0.5/1/2 缩放、己方建筑扩张、敌方/未完成/死亡拒绝、单位切换/取消、船坞模式切换；保留原三类建筑各 2091 网格点对照实际 build_spot_ok）、ground_control 20。证据 C:/Users/admin/Temp/iron-base-selection-range-20261026-v1、iron-base-selection-ground-20261026-v1/reports/，前者 OpenGL 后者 headless；Windows/Godot 4.7.2，独立项目与用户目录，服务/端口/DB/协议 none，两套 source_unchanged=true、engine_exit_code=0。ground_control 退出有 4 ObjectDB / 2 resource 提示，不称完全无告警。

已查看 ra2-selected-base-range-1.0.png，未拿起建筑时基地周围显示青色范围；正式项目 PrepareOnly Ready，目标 diff --check 通过。未改玩家存档、未提交/推送。实际观感 pending_user_visual_confirmation，重启游戏加载。

## v0.1.1 · 2026-10-26 建造时预览新增扩展范围

BuildRangePreview 在现有青色邻接范围之外增加绿色增量区域：以当前所选建筑的真实 footprint 作为假想已完成建筑源，按同一所选建筑的占地、邻接距离和地图边界计算未来可放置中心，减去现有覆盖。船坞仍用既有海军邻接距离；它不是所有建筑共用的无条件建造区，空地、水陆、视野等仍由 build_spot_ok 决定。提示注明“按当前占地”。移动预览只更新预测缓存，不修改建筑列表、资金、队列或实际邻接源；仅在当前真实放置检查通过时显示绿色。静止光标处出现新阻挡也即时清除；取消、结束对局及返回基地选择会清除预测。未完成建筑仍不授予范围。

502 项通过：build_range 206（RA2/扩展两模式，电厂/战车工厂/船坞，移动位置、三档缩放、增量不重叠、静止光标新增/移除障碍、未完成/实际完成区域差分、实际邻接与地图边界检查、无效位置与取消；保留原选基地和每类 2091 网格检查），building_preview 296（原资源、占地、实际放置及障碍回归）。证据 C:/Users/admin/Temp/iron-build-expansion-20261026-v2/reports/ 和 iron-build-expansion-placement-20261026-v1/reports/。前者验证功能代码后才同步版本元数据，后者包含 v0.1.1；两套 Windows/Godot 4.7.2/OpenGL，隔离项目与用户目录，服务/端口/DB/协议 none；source_unchanged=true、engine_exit_code=0，无残留本轮 Godot 进程。首次专项 v1 因测试局部变量类型推断解析失败而停止，补充显式 Vector2 后 v2 完整通过，不把 v1 算通过。

已查看 ra2-expansion-GAPOWR-1.0.png，青色现有范围、绿色增量与放置说明均可见。正式项目 PrepareOnly Ready，目标 diff --check 通过。版本元数据、README 和 CHANGELOG 同步 v0.1.1；未修改玩家存档，未提交、推送或打包。实际观感 pending_user_visual_confirmation，重启加载。

## v0.1.1.1 · 2026-10-26 载具阴影出现黑色矩形

用户截图的整块半透明黑矩形可由真实单位渲染稳定复现：RA2Art.unit_shadow_texture 合成车体/炮塔阴影后仅由容量 128 的共享缓存持有，Unit._draw_ra2_sprite 使用局部 Texture2D 提交 draw_texture_rect。Canvas 绘制命令继续引用 RID，但缓存清除/淘汰后 ImageTexture 已释放；静止单位未重绘时整个纹理画布变为黑矩形。原 CPU alpha union 测试只检查贴图像素，没有覆盖绘制命令的资源生命周期。

最小修复在单位增加 _shadow_draw_texture 强引用，随当前合成阴影更新，保留到下次替换或单位释放。未扩大共享缓存上限，未修改贴图、shader、迷雾、建造范围、战斗规则或玩家存档。model_render 在真实 OpenGL 下截图当前单位、清空阴影缓存、保持单位不重绘、再次截图逐字节比较。修前 346 项中 10 项失败，涵盖两模式的 ROBO/MTNK/FV/SREF/MGTK；已查看灰熊修前截图，黑块与用户现象一致。修后 346 项全部通过，包含既有 32 朝向、完整图集、真实模型消费、阴影并集及容量限制；已查看修后同一截图，黑矩形消失，透明背景保留。

证据 C:/Users/admin/Temp/iron-shadow-eviction-before-20261026-v1/reports/、iron-shadow-eviction-after-20261026-v1/reports/。Windows/Godot 4.7.2/OpenGL，隔离项目及用户目录，服务/端口/DB/协议 none；修后 source_unchanged=true、engine_exit_code=0。正式启动入口 PrepareOnly Ready，目标 diff --check 通过。版本元数据、README、CHANGELOG 同步 v0.1.1.1，未提交/推送/打包。目标游戏实机观感仍为 pending_user_visual_confirmation，重启加载。

## v0.1.2 · 2026-10-26 点击围墙自动选择连通片

用户明确规则为“点一段墙，自动选中相连的整片围墙”。WallArt.connected_component 使用与原画面连接一致的同阵营、同种类、40 world 格、四向邻接规则，从点击段做去重遍历。只对己方完成墙段扩选；斜角、断口、敌方、不同材料、未完成段均不连接。选中按点击时的快照确定，新建或断开不自动重算整片；成员死亡/出售/失去己方归属会剔除。选中组保留原 selected_building 代表段供现有建筑 UI 使用，selected_walls 管理全部高亮与 selection_changed 载荷。切换单位（含 Shift）、清空选择时清除全组高亮；控制组保存/召回整组选墙。

HUD 显示选中段数和代表段血量说明，并提供明确的“出售所选围墙”按钮；该按钮调用原单建筑出售入口逐段检查、动画和退款。原维修/出售鼠标模式保持单目标，不因存在围墙组而扩大操作。没有改变墙体生命、碰撞、生产、邻接范围或存档格式。

1326 项通过：wall 976（含既有墙体方向/伤损/连接/碰撞/导航；新增真实 Viewport 点击、9 段闭环加分支、排除边界、所有高亮、明确批量出售按钮、编队、成员死亡/单段出售、7 段准确退款与未选对象保护），control_group 46、building_actions 126、selection 178。证据 C:/Users/admin/Temp/iron-wall-selection-20261026-v1、iron-wall-selection-groups-20261026-v1、iron-wall-selection-actions-20261026-v1、iron-wall-selection-input-20261026-v1 的 reports/。Windows/Godot 4.7.2，control_group headless，其余 OpenGL；独立项目及用户目录，服务/端口/DB/协议 none。四套 source_unchanged=true、engine_exit_code=0，无本轮残留 Godot 进程。wall 专项后同步版本元数据，其余三套包含 v0.1.2。

已查看 ra2-connected-wall-selection.png，9 段角标、段数、代表血量提示和整组出售按钮均可见。正式项目 PrepareOnly Ready，目标 diff --check 通过；版本元数据、README、CHANGELOG 已同步 v0.1.2。未操作玩家存档、未提交/推送/打包。实际操作和视觉效果 pending_user_visual_confirmation，重启加载。

## v0.1.3 · 2026-10-27 基地车展开与收起衔接

用户确认范围为动画和位置衔接，保留原 BuildupTime 速度。收起将 GACNSTMK 原版 29 帧序列倒放；MCV 实体仍按原转换入口生成，但动画未结束时暂缓移动和再次展开，移动命令保留到结束后执行。展开使用建车原位置与合法地基位置之间的平滑渲染偏移，碰撞、网格和放置限制不变。定位到 _place_building 的清场操作会推开即将被消耗的 MCV，所以必须先保存 vehicle_origin，再创建建筑；不能在创建后读取车辆位置作为动画起点。动画点击命中与图像中心共用偏移，阴影跟随当前帧落点。

transition 数据保存在已有 special 字典，未改变存档版本/字段合同。转换保留生命比例、选择、已付建造队列和基地存活规则，不进入死亡/退款路径。新增 construction_transition_regression 的真实场景覆盖非网格首帧位置、半程和末帧、重复 D、暂停、收起期间移动、移动恢复、两阶段真实磁盘存读档和旧单位无状态兼容；两种模式均覆盖。v1 测试脚手禁用节点继承导致物理空间缺失，v2 修正脚手后暴露创建地基前未捕获原位置，v3 修正正式逻辑后通过；失败结果保留，未删断言。

最终 517 项通过：construction_transition 80（OpenGL 截图）、economy_chain 218（OpenGL，包含转换和队列恢复）、base_recovery 99、savegame 120（含独立冷启动）。证据分别在 C:/Users/admin/Temp/iron-mcv-transition-20261027-v3/reports/、iron-mcv-economy-20261027-v1/reports/、iron-mcv-base-20261027-v2/reports/、iron-mcv-save-20261027-v2/reports/。Windows / Godot 4.7.2，后两套 headless；各自隔离项目与用户目录，服务/端口/DB/协议 none。四套 source_unchanged=true、engine_exit_code=0。已查看展开起点、收起中段和末段截图。正式 launch_game.ps1 -PrepareOnly 为 Ready。

本轮 8 份已结束的测试 project 副本已删除，报告及截图保留；未操作正式项目资源和玩家存档，未关闭原游戏。版本元数据、README、CHANGELOG 同步 v0.1.3；未提交、推送或打包。原生 SHP 转换序列与 VXL 车辆仍为不同素材，实际方向衔接与操作观感为 pending_user_visual_confirmation，需要重启正式游戏观察，不把截图检查当成使用者验收。

## v0.2 · 2026-10-27 尤复基础规则、局外队列与原地还击

用户选择默认原地还击（被攻击才还手，主动攻击需下令），另设警戒按钮并用尤复图标。新生成己方单位默认 return，只在射程内反击实际攻击来源；G 原地警戒，S 停止恢复默认，手动集火和攻击移动仍正常。战斗要塞乘员继承载具命令，防御建筑和敌方 AI 的主动防守不变。此行为是用户指定适配，不作为原版默认行为声明。已存在存档中的 stance 不强制覆盖。

本机 Steam 尤复 expandmd01.mix/rulesmd.ini 为数值来源，SHA256 3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef。新增 ra2pipe/yr_baseline.mjs 只读提取 51 个已接入原版对象的 Strength/Cost/Armor/BuildTimeMultiplier/Adjacent/BaseNormal 与全局生产参数，输出独立原始字段夹具并核对输入包未改动。产物 data/yr_baseline.json 在 GameData 加载结束合并，避免只改展示而未改实体。两模式原版单位建筑共用基础 HP/造价/装甲/时间；扩展模式仍应用明确购买的养成与技能。GAPOWR 基础 HP=750、建造33.6秒；MTNK 300HP、700资金、BuildTimeMultiplier=1.5、44.1秒；GAWALL100资金、WallBuildSpeedCoefficient=3、1.4秒。现行多工厂、缺电、逐步扣费、退款和每厂独立队列边界保持。

独立运行既有 yr_combat.mjs 对已覆盖的 ra2_allied/yr_allied/yr_robot 常规武器审计 changes=0；Temporal/MindControl 的 Damage 有特殊语义，单独记录，不套普通伤害公式，也不声称全单位能力已与原版完全一致。yr_damage 真正伤害/弹道矩阵通过；其测试 CAP_ 武器别名及 CommandoCombat 动态原生弹道夹具已修正，未删实际伤害断言。原版 mouse.shp 第68帧 Guard 与 mousepal.pal 导出 guard.png，来源及输出哈希在 guard-source.json，HUD 实际消费。

建造放置与范围显示共用 Adjacent/BaseNormal：默认 Adjacent2格，机枪碉堡4、围墙8、船坞12；原版 BaseNormal=no 的防御、围墙、船坞等不提供扩展来源。选基地以电厂地基显示第一座建筑的参考范围，拿起其它建筑后切到实际占地，不能称任意大半径。围墙先生产就绪，再显示现有规则可自动补齐的连线形状、段数、额外费用和资金/阻挡红格；预览和执行共用 WallArt.plan。保持原来沿四个方向搜寻距离2..5格的同种友墙连接上限，未新增自由拖拽围墙模式。生产列表按尤复常用生产与科技顺序整理，未声称逐项复制原版排序算法。

局外建筑预约保留既有9项解锁，新增II/III依次2400/4800军需券；容量1→9→18→27，建筑与防御分别计数，正在生产和已就绪均占容量。永久存档、前置购买、资金不足、不重复扣费和新局冻结快照复用原有入口；RA2不加载养成。矿场制造独立分支及调试开关保持。驻防科技树四张卡在1280×720及1600×900可完整显示。

最终9套4213项断言通过，均 source_unchanged=true、engine_exit_code=0。证据根目录 C:/Users/admin/Temp/ 下，各自 reports/ 保留：

| 套件 | 断言 | 目录 |
|---|---:|---|
| yr_baseline（真实实体、原始规则、还击/警戒按钮、墙预览/执行、局外购买重载） | 578 | iron-yr-baseline-20261027-v2 |
| rules_mode（两模式边界与显式加成） | 83 | iron-yr-modes-20261027-v1 |
| yr_damage（原始武器/装甲、晋级、直击/弹道/范围/光棱） | 1988 | iron-yr-damage-v2-20261027 |
| build_range（2091点实际放置对比、完成/拆除、选基地） | 206 | iron-yr-range-v1-20261027 |
| yr_fortress（载具命令、乘员火力、超时空、存读档） | 170 | iron-yr-fortress-v2-20261027 |
| savegame（含独立冷启动） | 120 | iron-yr-save-v1-20261027 |
| technology_progression（局外真实入口、冷进程、保存失败原子性） | 38 | iron-yr-tech-v1-20261027 |
| wall（实际放置、连接帧、连片选择、出售） | 976 | iron-yr-wall-v1-20261027 |
| structure_technology（旧队列、就绪占位、暂停/取消、双方隔离） | 54 | iron-yr-queue-v1-20261027 |

复现入口：iron_tide/tests/run-navigation-building.ps1 -Suite <套件名> -RunRoot <仓外新目录>；baseline/range/technology/wall/structure 使用 -Render，其他 headless。Windows/Godot4.7.2，隔离项目、独立用户目录，服务/端口/DB/协议 none。所有正式运行完成后，仅改范围解释注释及文档，正式 launch_game.ps1 -PrepareOnly Ready。已看真实 wall-ready/guard/technology-locked-1280 截图，实际表现仍 pending_user_visual_confirmation。yr_damage 退出标准错误流仍有59 ObjectDB/10 resources清理提示，断言通过不等于完全无引擎提示；科技测试的存档失败警告为故障注入预期。

中间失败记录保留：baseline v1四项为默认场景敌方建筑干扰目标夹具；damage v1十三项为旧CAP别名/动态弹道/旧扩展HP预期；fortress v1十九项为停止后仍默认让乘员射击的旧命令夹具及旧40秒预期。已更新为真实载具命令并新增默认停止不射击断言；墙夹具补入普通建筑范围来源，范围夹具明确BaseNormal=no不能扩展。

兼容与交接：未修改玩家文件。由于基础数值和生产规则改变，旧版本战斗存档会按既有 content_hash 规则拒绝不兼容内容；请开新局，局外养成/已研究科技保留，不放宽校验载入混合规则。版本、README和CHANGELOG同步v0.2，未提交/推送/打包。持续独立实现；仍需分别验证特殊单位能力、国家系数和原版时间量化，不能把本轮通过当作完整尤复等价。

本轮12份已结束隔离测试 project 副本已删除，保留所有成功/失败报告、原始断言和截图；释放约 4.28 GiB。删除前逐一校验绝对路径、运行审计与无对应 Godot 进程。未清理其它 Temp 内容。

## v0.2.1 · 2026-10-27 右键机场返航与尤复军衔

用户要求飞机右键机场返航，并使用 RA2/YR 军衔 icon。原右键分发没有机场分支，直接落入地面移动；原返航仅从技能/空弹路径选择已有或最近机场。现新增只读 return_slot 与 battle.airfield_order_status，共用于鼠标提示和实际指令；右键指定己方机场后原子预留该机场空泊位，再清除旧作战/移动订单并进入既有 returning 流程，满弹也能落地待机。当前机场自己的泊位优先复用；满员/未完成/不支持时保留旧指令，显示阻止进入指针和原因；多选飞机逐架占位，不能重复分配最后一席。混选非飞机不被该指令改派，飞行兵/运输直升机/航母子机不进入机场订单。Ctrl显式攻击移动保持优先，Shift未新增机场排队。自动空弹返航与航母回收继续使用原无参数 request_return 路径。

军衔使用本机 ra2md.mix/conqmd.mix/PIPS.SHP 原图与 PALETTE.PAL，新增 ra2pipe/rank_pips.mjs 可重现提取，ranks.json记录源包/调色板/输出哈希。核对 RA2YR_ReSource src/object/gap2_defs.cpp 的 TechnoClass::DrawVeterancy 绘制索引与原始帧：14=老兵单箭头(8×5)，15=精英三箭头(8×13)。ts-ra2 的13+level-1有一帧偏差，13实际为星形符号，未采用；19是另一状态标记，未作为等级图标。仅使用事实与素材，不搬运参考实现。场上常驻标记、左下头像和选中详情均使用同一原版纹理，晋升闪光、经验、加成与武器切换保持。

4套460项断言通过，Windows/Godot4.7.2，独立项目与用户目录，服务/端口/DB/协议none；各套source_unchanged=true、engine_exit_code=0。证据位于 C:/Users/admin/Temp/ 下对应 reports/：

- iron-air-order-20261027-v2：50项，OpenGL/真实Viewport右键，ORCA/BEAG两模式，满弹指定机场、悬停无副作用、满泊位保留原命令、自有泊位复用、多选竞争、未完成/敌方机场/飞行兵排除。
- iron-air-logistics-20261027-v1：180项，headless，原自动返航补弹、运输和航母回收。
- iron-rank-native-20261027-v3：126项，OpenGL，实际击杀晋级、原图像素、0.5/1/2/4倍缩放、头像/详情、迷雾/死亡/舱内隐藏和空军高度。
- iron-air-dock-20261027-v1：104项，OpenGL，ORCA/BEAG四泊位、完好/受损机场、真实四向返航、临时碰撞排除清理与旧落点归位。

复现：iron_tide/tests/run-navigation-building.ps1 -Suite airfield_order_regression|logistics_regression|veterancy_regression|airport_docking_regression -RunRoot <新仓外目录>，除logistics外加-Render。测试保留失败证据：air-order-v1为新增PNG在autoload预载入时尚未导入，改为延迟缓存加载后首次导入通过；rank-v1/v2严格RGB对比遇到既有post_grade调色和像素取整差。最终测试先保存正常调色截图，再仅在隔离截图步骤暂时隐藏调色层比较每个不透明原图像素，恢复原可见性；正式调色不改，没有放宽颜色差值。已查看正常精英三箭头截图。

未改存档结构、数值数据或玩家文件；v0.2.1相对v0.2不新增存档规则不兼容。版本/README/CHANGELOG同步，未提交、推送或打包。实际返航操作与军衔观感仍为 pending_user_visual_confirmation，重启游戏加载。

正式启动 PrepareOnly Ready、目标 diff --check 通过。本轮7份已结束测试 project 副本经绝对路径/审计/进程检查后删除，释放约 2.5 GiB；保留成功和失败报告、截图。

## 2026-10-27 v0.2.1 Windows 朋友试玩包与 Git pull

按用户要求在 codex/ra2-independent 执行 git pull --ff-only --no-recurse-submodules，远端 origin=https://gitee.com/hly972233/iron-tide.git，返回 Already up to date，HEAD=d38dcb5d8511a5b6c2302dfd9b9d5aafd6e3e4ea。本地669个状态条目保持；此次交付是包含未提交工作区的 v0.2.1，不将旧HEAD称为当前完整源码，也未替用户提交/推送。

从显式 runtime 目录建立仓外8294个文件快照并逐项SHA256，排除测试、原始游戏包、SDK、玩家存档和未使用音乐样本。导出参数复用现有 Godot4.7.2 Windows x64 release 模板，模板SHA256 d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562。交付 EXE/PCK、控制台入口、说明、Godot许可/第三方说明及 build-manifest；运行存档独立放 %APPDATA%/IronTideFriends。

实际正常 release 入口 headless通过；外部 SceneTree脚本在GUI验证中90秒超时，已仅停止该测试进程。使用上次已验证的 QA autoload 入口重新导出同源资源的独立QA包，24项通过：正常菜单→大厅→真实遭遇战、HUD/演员、非黑屏、菜单无战斗音乐/战斗BGM播放、E1语音与灰熊攻击音效、3207个源WAV全部加载、原版军衔与警戒图标、51项原版基础数据、实际存档写入及校验。APPDATA只对测试子进程指向本轮test-profile，未改开发者或已有朋友存档。最终包是QA之前的正常导出，核对PCK不含package_qa；不含验证脚本、测试资源清单或测试存档。

最终ZIP CRC通过，解压每个文件与打包源逐字节一致；从带空格的实际解压目录运行最终EXE，正常主菜单截图已查看、退出0，stderr为空。QA战场截图已查看，日志无SCRIPT ERROR/ERROR。打包前后runtime源文件哈希一致，服务/端口/DB/协议none。本机验证不替代朋友电脑的兼容性实测。

交付：C:/Users/admin/Downloads/IronTide-v0.2.1-Windows-x64-20261027.zip，113761180字节（约113.8 MB /108.5 MiB）。SHA256 7358a6cc27a72f163639fce4514ce062f2225b47116f7f7e1b6410942e46ff47，旁边.zip.sha256.txt可复核。新包未覆盖20261023旧包。证据与source-inputs位于 C:/Users/admin/Temp/iron-friends-v0.2.1-20261027/，核心报告reports/package-receipt.json、release-smoke.json、release-battle.png、unpacked-menu00000002.png，保存本轮导出/运行日志与QA脚本。

交付校验后删除本轮隔离project、QA包、重复package和解压测试副本，释放约 0.89 GiB；最终Downloads ZIP、校验文件与报告保留。


## v0.2.2 · 2026-10-27 大厅开局设置记忆

用户要求截图中开局设置具有记忆功能。lobby.gd 在构建后恢复，再连接保存信号；所有8个OptionButton及迷雾checkbox改变即保存，无需开局。新增 scripts/ui/lobby_preferences.gd，稳定业务值写入 user://lobby_preferences.cfg 的 lobby 节，通过临时文件完成写入后替换；恢复对类型和允许值逐项校验，未知字段忽略，缺失/无效字段恢复原默认。MCV最低8000、扩展只预建基地、RA2只盟军镜像保持，先修正联动控件再保存。保存失败显示金色提示且保留旧文件，下一次选择重试。文件独立于局外养成和战斗存档，恢复不修改BattleRequest中的既有对局；开始遭遇战仍由既有configure_skirmish消费UI值。

验证命令：iron_tide/tests/run-navigation-building.ps1 -Suite lobby_preferences_regression -Render -RunRoot C:/Users/admin/Temp/iron-lobby-memory-20261027-v1。真实Lobby控件信号/生命周期、逐项立即保存、返回大厅、无效/缺失/错误类型、存储失败与恢复、模式约束、对局/科技隔离、实际开局参数共48项通过；独立Godot冷进程2项通过（九项UI恢复且不配置对局），合计50项。测试未模拟替代持久逻辑，但选择动作调用控件信号，未以物理鼠标逐项操作。正常截图已查看。源码指纹source_unchanged=true，engine_exit_code=0，服务/端口/DB/协议none；用户目录CodexIronTideValidation/81d8019d5c634f1f81e2a5f6ee395799，未使用真实玩家数据。

报告：C:/Users/admin/Temp/iron-lobby-memory-20261027-v1/reports/ 下 result.json、cold-result.json、environment-audit.json、lobby-remembered.png。正式 launch_game.ps1 -PrepareOnly 返回Ready，目标diff --check通过。本轮范围是大厅偏好读写，不改战斗规则/存档生命周期，无需通用战斗全量回归。界面体验仍pending_user_visual_confirmation。当前v0.2.2未提交/推送/打包，Downloads现有v0.2.1朋友包保持原样。

本轮已结束隔离project经绝对路径、审计及进程核对后删除，释放 0.36 GiB；报告与截图保留。


## v0.2.2.1 · 2026-10-27 扩展模式基地建造范围过小

用户再次指出选基地的青色区域仍小。诊断：v0.2已按待放建筑Adjacent（电厂2格）和BaseNormal统一规则，选基地仅以电厂占地计算，未实现用户期望的宽初始基地。此次明确作为扩展模式定制：带hq标签且活着、未排队删除、已完成、BaseNormal的本方建造场提供max(待放建筑Adjacent,8格)地基间距；普通来源保留Adjacent，原版RA2模式不变，船坞原12格不缩小。8格=320世界单位，不是整片区域直径，也不宣称尤复原版基地独享8格。

build_range_preview.gd新增source_distance/placement_zones/allows_placement/zone_coverage；蓝色预览、绿色扩展与battle.build_spot_ok使用同一逐来源距离。未绕过资金、地图、当前视野、水陆、建筑/单位/矿点/障碍检查，MCV展开的原豁免保留，双方对称。卖出/死亡/变更归属后自然重算；未改原版数据、存档字段或玩家文件。局部影响闭合于建筑空间合法性，未改伤害、通用战斗状态机、结算或存档生命周期，选用范围专项及基地恢复专项。

验证：Windows/Godot4.7.2；iron_tide/tests/run-navigation-building.ps1 -Suite build_range_regression -Render -RunRoot C:/Users/admin/Temp/iron-yard-range-20261027-v2，244项通过。两模式每种常用占地2091中心预览/实际比对，单独基地每模式961中心独立80/320间距判断、内外边界、选基地与电厂预览一致、新区域真实放置、原12格保留、普通建筑无基地加成、防御/围墙/船坞不扩范围、所有权/完成/死亡变化、绿区预测兑现。v1保留失败证据：首模式窗口焦点前置过早、一个新增测试误认为已付款就绪建筑放置后under_construction=true。修正焦点时机，显式断言就绪建筑已经完成，另设未完成状态检查；未改正式输入、建成或断言阈值。已查看v2扩展模式选基地截图。

基地展开/收起与恢复：-Suite base_recovery_regression -RunRoot C:/Users/admin/Temp/iron-yard-recovery-20261027-v1，99项通过。两套合计343项，source_unchanged=true、engine_exit_code=0。玩家目录分别为CodexIronTideValidation/0530cc3f2f8544db985f50953ec99301及本轮recovery审计记录，服务/端口/DB/协议none，未使用真实玩家档。报告保留于上述各run/reports/。正式launch_game.ps1 -PrepareOnly Ready；版本/README/CHANGELOG同步v0.2.2.1。实际大小观感pending_user_visual_confirmation；未提交、推送或更新Downloads的v0.2.1朋友包。

本轮3份已结束隔离project已核对绝对路径、原始报告、源码审计与无对应进程后清除，释放 1.07 GiB；包括已修正测试的v1失败报告和截图全部保留。


## v0.2.3 · 2026-10-27 中键恢复默认缩放

用户要求按滚轮中键恢复地图默认大小。battle.gd抽取DEFAULT_VIEW_ZOOM=2.0供开局与reset_camera_zoom共用；恢复Iso.cam_zoom默认比例，保持camera.position+camera_focus_offset的可操作区域观察中心，保留现有方向/压扁设置，地图边界仍钳制，刷新相机平滑避免过渡漂移。沿用中键pan所有权：仅在本方中键松开、未越过拖动阈值且起止均世界区域时复位，右键所有权不被中键抢走，中键拖动保持原缩放。暂停/失焦取消指针状态后松开不复位。HUD通用提示新增中键说明。无战斗、生产或玩家存档数值修改；60逻辑帧方案尚未实施。

验证命令：iron_tide/tests/run-navigation-building.ps1 -Suite camera_input_regression -Render -RunRoot C:/Users/admin/Temp/iron-middle-reset-20261027-v1。Windows/Godot4.7.2，实际Viewport输入经过正式Battle/HUD，174项通过，含原边缘滚屏、键盘、UI所有权、双键冲突、失焦、暂停，以及新增两模式0.45/1/2/3.2缩放复位、按下不提前复位、观察中心/方向保留、拖动不复位、生产栏/小地图不穿透、选中及单位命令保留、待放建筑不取消/不消耗。source_unchanged=true、engine_exit_code=0，独立工程与CodexIronTideValidation用户目录（完整值见environment-audit.json），服务/端口/DB/协议none。正式PrepareOnly Ready，目标diff --check通过。复用现有专项覆盖本次局部镜头输入，不涉及游戏权威状态或存档生命周期。

报告保留于上述run/reports/result.json及environment-audit.json。版本/README/CHANGELOG同步v0.2.3；实际镜头操作手感pending_user_visual_confirmation。未提交/推送/打包，旧朋友包未更新。

本轮隔离project完成路径、审计和进程检查后删除，释放 0.36 GiB；报告保留。


## v0.2.4 · 2026-10-27 正常玩法采用60逻辑帧节奏

用户确认60帧方案，或以动员兵约1秒为节奏参考，并要求先做速度，尤复式圆圈建造进度/阵营配色留后续。BattleClock统一RULE_TICKS_PER_SECOND=15、NORMAL_TICKS_PER_SECOND=60、NORMAL_SCALE=4；开局设置Engine.time_scale=4*GM.fast_forward，工具栏/GM的×1/×2/×3以新基准解释。未锁定渲染FPS，也未改基础生产计时、价格/伤害、物理频率或存档计时单位。速度档事实参考CnCNet官方客户端工程 https://github.com/CnCNet/xna-cncnet-client/blob/develop/Docs/Migration-INI.md （60/30/15 FPS档）；本地rules.ini的E2 Cost=100、无额外BuildTimeMultiplier用于1.05秒公式对照，未声称苏军完整可生产。

Battle.setup启用新正常速度；Battle.end_battle、BattleScreen结束/退出/重开、HUD离开、保存后回大厅、BattleSaves场景切换统一leave_battle。加载对局仍从×1开始，保留原规则时间进度，不将已有存档时间乘除4。BattleScreen退出也清理时钟，防止非按钮换场景泄漏。HUD生产预估使用实际structure_work_rate或生产者build_speed/production_work_rate，再换算现实秒；空闲卡片原地更新，工具提示附当前倍速预计时间，不保留过期静态秒数。队列、建筑施工、波次、技能及增益冷却、矿车空闲提示同步换算。镜头delta在Battle._process入口单独转换，HUD持有/刷新/闪烁使用现实delta；既有音频pitch保持，未改AudioServer。实体说明中的静态机制描述不作为倒计时或实时ETA，后续文案可继续细化。

跨全局时间基准，专项之外验证完整运行中的生产→攻击/移动→胜负规则→结果界面及存读档，未将纯公式检查当作对局通过。Windows/Godot4.7.2，项目和玩家目录隔离，服务/端口/DB/协议none。命令统一 iron_tide/tests/run-navigation-building.ps1 -Suite <suite> -RunRoot <以下新目录>，带Render的套件使用OpenGL：

- battle_clock_regression -Render：C:/Users/admin/Temp/iron-clock60-20261027-v3，70项通过。该套特殊去掉--fixed-fps，使用--max-fps 60及Time.get_ticks_usec现实秒表；两模式实测规则/现实时间比3.999976与4.000172，单兵营实际E1为2.129707与2.091336秒，扣费恰好200。正常未冻结对局电厂为8.370273与8.292175秒；双方模式真实physics目标/武器造成敌军死亡、移动有效，最终通过确定性最后伤害准备触发原有短局胜利规则与结果界面，时钟回1。非自然长局AI胜负；没有声称覆盖大型军团性能。另验倍速1→2→3→1、暂停/继续、已生产进度的真实存读档、离开与失败结算。正常战场截图已查看。
- savegame_regression：C:/Users/admin/Temp/iron-clock60-save-20261027-v1，120项通过，包含子进程冷读、状态/引用恢复、结算去重与挂起流程。
- camera_input_regression -Render：C:/Users/admin/Temp/iron-clock60-camera-20261027-v1，174项通过，既有镜头/UI所有权、中键恢复/拖拽、暂停失焦行为。
- economy_integrity_regression：C:/Users/admin/Temp/iron-clock60-economy-20261027-v1，52项通过，既有双模式双方经济守恒和资源消费。

最终4套416项，每套source_unchanged=true、engine_exit_code=0，报告及独立用户目录见各run/reports/result.json与environment-audit.json。正式launch_game.ps1 -PrepareOnly Ready，目标diff --check通过。早期clock-v1保留失败证据：用SceneTree timer截取切速与资源预热期导致秒表采样不稳；新增第二座兵营触发原版0.8多厂倍率，实际约1.7秒；测试生产节点设PROCESS_ALWAYS导致暂停继续。这些是测试前置错误：改用独立现实时间循环和预热、原有单兵营、PAUSABLE后v2的58项通过；v3增加正常运行战斗和胜利路径，阈值未放宽为失败值。源规则没有为通过测试修改。

版本/README/CHANGELOG同步v0.2.4。当前更改不新增存档schema或content hash不兼容；旧档仍须满足既有规则数据兼容检查。实际快节奏、音画和ETA体验pending_user_visual_confirmation，未提交/推送/重新打包。下一步用户已表达但本轮明确延后：原版尤里风格圆形建造进度及不同阵营配色，届时先核对原图/实现事实。

6份本轮已结束隔离project经绝对路径、源码审计、结果与无对应进程核对后移除，释放 2.14 GiB；全部成功/失败报告与截图保留。


## 2026-10-27 · v0.2.4.1 生产页签排序与苏联接入准备

根因：盟军警犬运行 ID 是历史 DOG，排序表使用原版盟军 ADOG，未命中退到末尾。仅添加按 faction=allied 限定的排序别名，保留原单位身份和所有存档/资源消费。未来真正苏联 DOG 不受该别名影响。

最终 `production_catalog_regression -Render`：1240项通过，6页签 × 5盟军国家 × 2模式，真实 HUD 卡片次序、完整48张清单、生产归类、去重、秘密科技解释及退款、禁用场景/生成单位、国家限制均覆盖。报告：`C:/Users/admin/Temp/iron-catalog-order-20261027-v2/reports/`，source_unchanged=true、engine_exit_code=0，Godot日志无ERROR。查看了真实HUD步兵排序截图。v1同为1240项通过，但国家循环只改mission而未改实际消费的_countries，不作为五国覆盖证据；v2修正为实际country策略输入后重跑，源码排序规则未更改。

Windows / Godot 4.7.2 / RTX5060Ti Compatibility，隔离工程与独立custom_user_dir，无服务、DB、网络或真实用户存档写入。正式launch_game.ps1 -PrepareOnly检查及目标diff --check；视觉接受仍pending_user_visual_confirmation。

苏联只读清点工具 `ra2pipe/yr_soviet_audit.mjs` 读取本机Steam安装的rulesmd.ini/artmd.ini及MIX资源，输入哈希读取前后核验。候选报告 `C:/Users/admin/Temp/iron-soviet-intake-20261027-v1/soviet-native-inventory.json`：42个常规生产候选+8个支援形态共50项；50个主模型候选、42个普通cameo均存在。存在性不证明帧序、层偏移、炮塔、语音和技能行为已接入；报告未加入游戏数据加载。后续入口和缺口见YR_SOVIET.md。


## 2026-10-27 · v0.2.4.2 战役时钟与生产加速分离

用户反馈移动过快，明确要求快速建造之外重新对齐移动与攻击。查Phobos一手项目文档的原版战役GS4/Fast/30FPS，以及本地ROF/15、15帧规则工期消费。修正BattleClock正常倍率4→2；仅结构队列/单位工厂（含矿场技能）/后备在场施工工作倍率×2。实际消费和HUD/开门预估共用生产工作率。未重写价格、伤害、ROF、存档schema或数据content hash。完整换算与空间适配限制见BATTLE_TIMING.md。

最终5套612项：

- battle_clock_regression -Render：88项；`C:/Users/admin/Temp/iron-campaign-clock-20261027-v2/reports`。实际单调时钟下逻辑时间约2倍推进，E1仍约2.1秒完成且扣200，电厂仍约8.4秒就绪；两模式六类单位巡航位移均符合原适配速度×2，而非上一版×4。M60实际间隔0.652～0.667秒，105mm约2.011～2.027秒，GAPILL约0.867～0.885秒。真实胜负与暂停、载入退出覆盖。截图已查看。
- savegame_regression：120项；`C:/Users/admin/Temp/iron-campaign-save-20261027-v1/reports`，含独立子进程冷读与既有存档进度。
- economy_integrity_regression：52项；`C:/Users/admin/Temp/iron-campaign-economy-20261027-v1/reports`。
- economy_detail_regression：178项；`C:/Users/admin/Temp/iron-campaign-economy-detail-20261027-v2/reports`，两模式双方混装/卸载守恒、缺电、多厂与取消退款、矿场技能、建筑队列。
- camera_input_regression -Render：174项；`C:/Users/admin/Temp/iron-campaign-camera-20261027-v2/reports`。

5套均source_unchanged=true、engine_exit_code=0；结束时再次核对报告内battle_clock/building/battle/hud/project的SHA256与当前文件一致。Windows/Godot4.7.2，渲染套件RTX5060Ti Compatibility；各自隔离副本和custom_user_dir，无网络/服务/DB。真实计时专项使用--max-fps60而非fixed-fps，其他现有确定性套件沿用runner。正式launch_game.ps1 -PrepareOnly Ready。

保留早期失败证据：clock-v1新增测试局部bool推断导致脚本解析失败，按完整隔离项目路径停止其Godot子进程，显式类型修复后v2通过；economy-detail-v1旧前置未面对新宝石矿且在卸货离站尚未结束时强行准备另一采矿状态，另外固定生产采样未考虑独立倍率，共68项失败。仅更新测试转向/离站前置和生产采样时间基准，保留所有价格/守恒/生产断言，v2全过。camera-v1无头跑2项边缘滚动失败，因为产品刻意禁止headless鼠标滚屏；使用既有Render入口重跑，不改运行规则，v2全过。

当前仍需用户确认实际移动/射速与手感，pending_user_visual_confirmation；未提交、推送或更新试玩包。下轮苏联接入和圆形生产进度应沿用分离时间合同，不再用全局60逻辑帧实现快速建造。

本轮8份已结束隔离project在审计与无对应进程核对后清理，释放 2.86 GiB；成功/失败报告、日志和截图全部保留。


## 2026-10-27 · v0.2.5 自动防卫目标策略

根因：此前己方默认return，仅受击后获取目标，不能满足射程内敌军主动开火的新要求。新增defend默认姿态并在地面/飞行/武器合法性入口一致过滤；不主动选建筑，不追击，显式命令和还击仍可打建筑。原版参考不等于排除所有建筑，本项目按用户明确要求实现，详见AUTO_DEFENSE.md。保留旧档姿态；S恢复新默认。

运行命令统一iron_tide/tests/run-navigation-building.ps1 -Suite <suite> -RunRoot <root>，标Render的套件加-Render。Windows/Godot4.7.2、独立project及custom_user_dir，服务/端口/DB/协议none，不读写真实玩家存档。

| Suite | 检查数 | RunRoot（C:/Users/admin/Temp/下） |
| --- | ---: | --- |
| automatic_defense_regression | 70 | iron-auto-defense-20261027-v2 |
| yr_baseline_regression -Render | 578 | iron-auto-baseline-20261027-v1 |
| tactical_target_regression | 60 | iron-auto-targeting-20261027-v2 |
| aircraft_ammo_regression -Render | 94 | iron-auto-ammo-20261027-v2 |
| savegame_regression | 120 | iron-auto-save-20261027-v1 |
| yr_fortress_regression | 174 | iron-auto-fortress-20261027-v2 |

合计1096项断言通过，各reports/result.json及environment-audit.json保留。source_unchanged=true、engine_exit_code=0，最终unit/unit_flight/hud/battle/project文件哈希逐套与source_after一致；正式launch_game.ps1 -PrepareOnly Ready。目标、射击伤害与存读档逻辑已验证，实际手感pending_user_visual_confirmation。

限制：targeting退出控制台报告4个ObjectDB实例/2个资源未释放，fortress报告6个实例/3个资源；runner的Godot日志门禁未收录这些退出stderr，因此断言通过不等于日志全清洁。这些测试收尾资源问题未在本轮修复。

早期失败证据保留：defense-v1删除全部基地造成策略目标无基地时PathService.line_walkable越界，改成保留真实基地的测试前置后v2干净通过，未声称修复该无基地路径边界；targeting-v1敌军spawn自带attack_move，测试未先取消，修正order_stop前置后保留return-only断言通过；ammo-v1无头入口无法完成frame_post_draw，停止自身隔离进程后用Render重跑；fortress-v1旧断言要求S后被动与新规则冲突，更新为S允许合法单位防卫、清除过期手动命令，并另验证显式停火压制，v2通过。未放宽实际伤害、目标或停火断言。

本轮版本v0.2.5；未提交、推送或打包，历史共享脏工作区改动保留。

本轮10份已结束隔离project核对绝对路径、来源审计及无对应Godot进程后清理，释放 3.57 GiB；所有成功/失败报告、日志与截图保留。


## 2026-10-27 · v0.2.6 15帧战场与RA3参考生产

用户新指令明确覆盖上一版30逻辑帧战斗。BattleClock.NORMAL_SCALE=1；生产按对象独立工作率，23项同类角色的BuildTime来自本机官方SDK XML，路径/数值/指纹见tests/fixtures/ra3_production_reference.json。角色映射为项目策略；新基础秒取SDK值与旧工期较长者，其余对象降到30逻辑帧等效生产。原GameData规则、价格、存档schema、data内容不改。双方生产/在场施工/HUD消费对象倍率；细节见BATTLE_TIMING.md。

最终6套922项，全部首次运行断言通过。命令：iron_tide/tests/run-navigation-building.ps1 -Suite <suite> -RunRoot C:/Users/admin/Temp/<run>，标Render者加-Render。

| Suite | 断言 | Run |
| --- | ---: | --- |
| battle_clock_regression -Render | 328 | iron-clock15-20261027-v1 |
| economy_detail_regression | 178 | iron-clock15-economy-detail-20261027-v1 |
| savegame_regression | 120 | iron-clock15-save-20261027-v1 |
| economy_integrity_regression | 52 | iron-clock15-economy-20261027-v1 |
| camera_input_regression -Render | 174 | iron-clock15-camera-20261027-v1 |
| automatic_defense_regression | 70 | iron-clock15-defense-20261027-v1 |

Windows/Godot4.7.2、独立project和custom_user_dir；渲染套件RTX5060Ti Compatibility。服务/端口/DB/协议none，不操作真实玩家存档。各reports/result.json和environment-audit.json记录全量断言、source_unchanged=true、engine_exit_code=0；最终clock/building/battle/hud/fixture/project哈希逐套与当前源码一致，SDK全部23项输入指纹再次核验一致。正式launch_game.ps1 -PrepareOnly Ready，目标diff --check通过。

真实计时专项用--max-fps60，非fixed-fps：两模式新建/加载×1均time_scale1；6种单位实际巡航位移等于基础规则速度×现实秒。美国大兵4.991～5.024秒生产且扣200；电厂9.845～9.875秒就绪，略早于10秒是帧步进/计时起点的误差。普通大兵间隔1.329～1.333秒、灰熊4.010～4.017秒、碉堡1.733～1.750秒。保留胜负结果、暂停/退出、旧进度存读、单/多厂、断电、资金不足、取消退款、矿场制造矿车，以及上一版自动防卫实际命中；UI截图已查看。

现有测试退出告警仍在：economy_detail和automatic_defense各2个ObjectDB/1资源，economy_integrity为4个ObjectDB/2资源。退出stderr未被runner的godot.log门禁收录，断言通过不表示无资源泄漏；本轮没有顺带改测试收尾/运行资源生命周期。

版本/README/CHANGELOG/BATTLE_TIMING同步v0.2.6。实际节奏pending_user_visual_confirmation；未提交/推送/打包，旧朋友包保持不变。共享工作区既有修改均保留。

本轮6份已结束隔离project核对绝对路径、来源审计及无对应Godot进程后清理，释放 2.14 GiB；所有报告、日志与截图保留。


## 2026-10-27 · v0.2.6.1 警戒按钮无法关闭

用户截图标记G警戒按钮。确认HUD是toggle_mode，Battle.guard_selected却总调用order_guard，第二次点击被重新置为开启。将玩家入口改为全开→order_stop恢复defend，其余混合/关闭→统一order_guard；过滤无效、已死、敌方选择。保留Unit原子命令、部署状态、自动索敌规则和时间参数。HUD显示开关高亮及已开启/已关闭/部分开启提示，空选择禁用。

3套682项通过。run-navigation-building.ps1 -Suite <suite> -RunRoot <root>，Render套件加-Render：

- guard_toggle_regression -Render：34项，C:/Users/admin/Temp/iron-guard-toggle-20261027-v3。真实SubViewport鼠标点击和G/S键，单选与混合多选、卧倒E1/部署GGI保留、真实按钮状态与提示、停止移动、停火转警戒、空选择；1600×900。测试继承selection公共启动的evidence中zooms列表是通用脚手元数据，本专项未运行四种缩放，不作为缩放覆盖证据。开/关两张截图已查看。
- automatic_defense_regression：70项，C:/Users/admin/Temp/iron-guard-defense-20261027-v1。原默认目标/部署开火/旧姿态存档通过。退出stderr有2个ObjectDB/1资源释放告警，未视为零错误日志。
- yr_baseline_regression -Render：578项，C:/Users/admin/Temp/iron-guard-baseline-20261027-v1。原尤复数值、一次开启警戒、S恢复、手动攻击、反击与警戒保存加载保持。

Windows/Godot4.7.2，渲染RTX5060Ti Compatibility；独立project和custom_user_dir。无服务/端口/DB/协议及真实玩家存档操作。3套source_unchanged=true、engine_exit_code=0；报告在各reports/result.json和environment-audit.json。正式PrepareOnly Ready，目标diff --check通过。

早期失败保留：toggle-v1继承selection基类没有move_pointer，解析失败后仅停止本轮精确隔离project对应的Godot进程；改用已有input_ownership基类。v2冻结HUD自动刷新导致按钮尚未生成，2项脚本错误、零断言不是通过；v3显式调用真实HUD刷新，再经真实输入路径验证，34项全过。运行代码没有为测试降级，测试仅补齐冻结环境前置。

版本/README/CHANGELOG/AUTO_DEFENSE同步v0.2.6.1。实际使用者体验pending_user_visual_confirmation；未提交、推送或打包。

本轮5份已结束隔离project经绝对路径、来源审计与无对应进程核验后删除，释放 1.78 GiB；成功/失败报告、日志与截图保留。


## 2026-10-27 · v0.2.6.2 海豹/谭雅C4进不了部分建筑

目标系统Godot CommandoCombat。根因与修复边界见ALLIED_ABILITIES.md末节。只改C4 approach最后两格移动选择，不改共用寻路、碰撞豁免、进入/退出状态、伤害或存档schema。保留用户确认的默认防卫不主动拆建筑。原版规则以本地data/ra2/allied_capabilities.json和已有源证据为准；EA公开RA1 Infantry/Building仅作为进入建筑格、引信与闪烁的前代行为参照，非YR完整源实现，未复制。

最终4套1054项，命令iron_tide/tests/run-navigation-building.ps1 -Suite <suite> -RunRoot C:/Users/admin/Temp/<run>，Render者加-Render：

| Suite | 断言 | Run |
| --- | ---: | --- |
| c4_approach_regression | 768 | iron-c4-approach-20261027-v4 |
| c4_entry_regression -Render | 96 | iron-c4-entry-20261027-v2 |
| commando_attack_regression | 120 | iron-c4-commando-20261027-v2 |
| automatic_defense_regression | 70 | iron-c4-defense-20261027-v1 |

入口矩阵覆盖192次真实Unit._physics_process移动和碰撞：6种建筑、8方向、海豹/谭雅、RA2/扩展模式；目标位置(2107,2109)有意不对齐网格，逐例断言实际跨入多边形后装药、退出外侧、无碰撞例外遗留。表现专项真实Godot材质像素断言红闪/脉冲，工程师拆弹恢复原材质，原引信到期摧毁并记经验；进入/退出两阶段写盘恢复，两单位均覆盖。commando保留真实右键混编攻击、Sapper/FakeC4武器选择与实际伤害，默认防卫专项验证不主动拆建筑保持。

Windows/Godot4.7.2，独立project/custom_user_dir，渲染RTX5060Ti Compatibility。服务、端口、DB、协议none；未操作真实用户存档。4套source_unchanged=true、engine_exit_code=0，最终commando/unit/allied_abilities/building/project哈希与各source_after一致。正式PrepareOnly Ready，目标diff --check通过；查看iron_tide-TANY-c4-red.png确认真实建筑材质红闪。旧selection基类输出的zooms元数据不是本轮多缩放覆盖证据，本轮不声称验证四缩放。

失败与限制如实保留：approach-v1测试继承冻结父节点导致物理体无space，重复日志属于错误测试前置，仅停止该隔离project的Godot；v2启用测试体物理空间并关闭其自动推进后，64接近组合56失败，停在最终格中心；v3初修后仍8失败，因为离开终点半径即退回网格，v4补接近条件并扩至192组合全部通过。entry-v1原海豹专项48项也通过，v2扩展谭雅到96。commando-v1有12项旧默认自由开火假设失败；依据v0.2.5明确规则，用真实force_attack或显式free准备原场景，新增默认不追击断言后120项通过，没有恢复自动拆建筑行为或减少伤害断言。

approach-v4退出stderr仍有29个ObjectDB实例/8资源释放告警，runner的godot.log门禁未收录退出段；不宣称全程无日志错误，也未将测试资源收尾问题当成此C4入口修复。其它最终三套未出现同类退出警告。实际视觉接受pending_user_visual_confirmation。

版本/README/CHANGELOG同步v0.2.6.2，交接更新ALLIED_ABILITIES。未提交、推送或打包，已导出的朋友包未更新。

本轮9份已结束隔离project经绝对路径、来源审计与无对应进程核验后删除，释放 3.21 GiB；成功/失败报告、日志与截图保留。

## v0.2.7 维修图标 · 2026-10-27
指令甲板维修入口与单位命令栏 K 使用本机 Steam 尤复安装自带 RA2.MIX/SIDEC01.MIX/REPAIR.SHP 第 0 帧扳手，原 SIDEBAR.PAL；裁剪及哈希保存在 assets/ra2/ui/repair-source.json。只改图标显示，点击命令、快捷键、维修收费和状态逻辑不变。正式 launch_game.ps1 -PrepareOnly Ready，目标 diff --check 通过；已查看导出图标，实际游戏观感 pending_user_visual_confirmation。未推送或重新打包。

## v0.2.8 建筑受损火焰 · 2026-10-27
- 本机 Steam 尤复 rulesmd.ini 的 DamageFireTypes=FIRE01,FIRE02,FIRE03；AudioVisual ConditionYellow=50%、ConditionRed=25%；artmd.ini 各建筑 DamageFireOffset。原动画 Rate=450，当前动画管线换算 7.5 fps。资源和规则 SHA256 保存在 data/ra2/building_damage_fire.json，导出入口 ra2pipe/building_damage_fire.mjs。
- Building._ready 添加独立 DamageFire 子节点，原 SHP 画布中心 + 本体绘制锚点 + 原着火偏移，不继承房屋换色材质；保留橙色火焰。密度选择为本作独立表现策略：半血一半火点向上取整、四分之一血量全部火点，不宣称复刻原引擎随机着火算法。
- building_fire_regression -Render：276 断言通过。8 种建筑、RA2/扩展两模式，真实受击、50/25%边界、实际收费维修熄灭、建造/展开隐藏、冻结与暂停、原版纹理实际橙色像素增量、真实迷雾 rebuild、磁盘存读档恢复、出售和摧毁释放节点；无额外伤害和持续生成临时粒子。截图覆盖电厂、工厂、矿场、维修厂、机场、基地和光棱塔。墙无原版火点，不臆造火点。
- 证据：C:/Users/admin/Temp/iron-building-fire-20261027-v3/reports。Godot 4.7.2，RTX5060Ti Compatibility；独立 project/custom_user_dir，服务/端口/DB/协议 none；未操作玩家存档。source_unchanged=true、engine_exit_code=0；正式 PrepareOnly Ready，代码/规则/测试/版本哈希与最终回归一致，目标 diff --check 通过。继承测试基类的四缩放元数据不是本轮实际覆盖；本轮渲染为 2 倍镜头。
- 前两次失败保留：v1 测试 WeakRef 推断触发警告即错误，终止该隔离实例后显式标注类型；v2 前一模式读档会按正式约定暂停 SceneTree，影响后一模式维修，新增恢复暂停隔离并保留暂停契约断言后 v3 全通过。没有修改维修逻辑或删减断言。最终日志未见脚本/引擎错误或退出资源告警。
- 只增加表现派生状态，不新增存档字段；实际视觉验收 pending_user_visual_confirmation。未提交、推送或打包。
本轮3份已结束隔离工程副本经路径与进程核对后删除，释放 1.07 GiB；前两次失败和最终成功的报告、日志、截图均保留。

## v0.2.9 间谍实验室与窃款 · 2026-10-27
- 原始资金实现基线：C:/Users/admin/Temp/iron-spy-money-20261027-v1/reports，64断言通过；16次真正入矿场（双方、两模式、0/1/8000/12345.5余额）。原用户反向扣款现象未复现；确认实验室名单缺失是禁止进入的直接原因。
- 最终：iron-spy-money-20261027-v2 96；iron-spy-lab-20261027-v1 34；iron-spy-entry-20261027-v1 426；iron-spy-catalog-20261027-v1 1240。均位于 C:/Users/admin/Temp/<run>/reports，合计1796通过。未删减历史目录限制断言；旧“尚未接入”说明断言按新实现替换为“间谍渗透”。
- money覆盖双方方向、零余额/小数、一次HUD通知、通知时两边余额已同时生效、同步通知再推进间谍不重复结算、余额守恒、收支记录归属。lab覆盖真实右键/进入指针、路径与入内消费、统一前置校验、HUD卡片解锁、实际兵营生产、阵营不串、存读档及新对局隔离。entry含五建筑八方向非网格坐标的80次导航及围挡/停止/死亡取消、真实Q/右键输入。catalog覆盖全部页签顺序、国别、非法订单与退款等边界。
- Windows Godot4.7.2 headless；独立工程/custom_user_dir。服务、端口、DB、协议none；只写隔离存档。四套均source_unchanged=true、engine_exit_code=0，日志未见SCRIPT ERROR/ERROR或退出资源告警。基类通用zooms元数据不是本轮多缩放视觉证据。无额外完整战役主线：改动闭合于间谍动作结算、阵营科技前置和UI消费；未改胜负/通用伤害/存档格式，真实保存恢复由lab专项覆盖。
- 待查：用户反向扣款。现在可凭游戏情报条或日志[SpyTransfer]的thief/victim及前后余额定位，不能将保护性改动当成已确定根因的修复。视觉表现pending_user_visual_confirmation。未提交/推送/打包。
最终正式PrepareOnly Ready；四套回归的上述运行时代码及版本哈希与当前工程逐项一致，目标diff --check通过。
本轮5个已结束且审计通过的隔离project经绝对路径与进程核对后删除，释放 1.79 GiB，基线与最终报告/日志保留。

## v0.2.9.1 卧倒阵列绕行 · 2026-10-27
- 基线 iron-deploy-traffic-20261027-v2：272项中8项失败，所有场景规划线都穿过部署兵的碰撞圆；开阔测试仍能靠物理避让最终到达，没有复现原截图的永久卡死，不将其写成已复现事实。
- 最终 deployed_traffic_regression：iron-deploy-traffic-20261027-v4，280项通过。两模式各4场景：15名GI/GGI、开阔/建筑旁、先部署/车辆到前排40px处才部署。路径绕开碰撞圆、实际到达目标、姿态和位置不变、无友军伤害、速度不超原值、起身后解除阻挡、共享地形网格不变。
- 关联回归：iron-deploy-traffic-base-20261027-v2 52项、iron-deploy-fortress-20261027-v2 208项、iron-deploy-attack-20261027-v2 22项。合计562项通过。全部目录位于 C:/Users/admin/Temp/<run>/reports，运行入口 tests/run-navigation-building.ps1 -Suite <suite> -RunRoot <run>。
- Windows/Godot4.7.2 headless，真实Unit物理碰撞与路径消费，独立project/custom_user_dir；服务、端口、DB、协议none，未使用玩家存档。最终四套source_unchanged=true、engine_exit_code=0。第一次关联三套虽然断言通过，但运行期间其他工作修改了RA3相关文件及共享Unit/Battle，source_unchanged=false，已作废并重新运行，未覆盖这些并行工作。
- 初始专项v1只有开放场景；v2加入建筑和规划几何断言揭示8处失败；修复后的v3 272项通过；v4将途中部署从60tick改为240tick，并增加公共网格断言，280项通过。保留所有原始报告。
- 最终专项和常规traffic在退出stderr仍出现2个ObjectDB实例/1资源未释放警告；runner的godot.log未收录退出段，不能把PASS表述为无任何日志错误。该测试生命周期问题没有在本次修复。要塞速度/卧倒攻击最终退出未见同类警告。
- 修改闭合于友军部署占位、路径版本和单次寻路网格；未改通用伤害、胜负结算或存档格式。实际截图拥挤布局和操作手感 pending_user_visual_confirmation，未提交、推送或重新打包。
正式 launch_game.ps1 -PrepareOnly Ready；四套最终 source_after 与当前运行文件逐项哈希一致，目标 diff --check 通过。本轮10份已结束隔离 project 经绝对路径、审计归属与无对应进程检查后删除，释放3.57 GiB；所有报告、日志保留。

## v0.2.9.2 间谍目标指令伪装 · 2026-10-27
- 源码根因：既有allied_disguise会复制模型，但Battle.force_attack未分流SPY，battle_cursor只认普通武器；本次只接通显式目标指令并统一资格校验。原版导出data/ra2/allied_capabilities.json中SPY CanDisguise/PermaDisguise为yes；沿用项目已实现的敌方步兵限制，没有声称允许伪装坦克。
- 最终：iron-spy-disguise-20261027-v2 46项（渲染）、iron-spy-disguise-cursor-20261027-v2 62项（渲染）、iron-spy-disguise-allied-20261027-v2 200项（headless），共308通过。路径均为C:/Users/admin/Temp/<run>/reports。两模式均覆盖；专项直接走真实Battle._issue_order/force_attack，鼠标回归另走Viewport.push_input，不能将专项全部说成输入注入。专项目标显示纹理和实际截图核对通过，截图ra2-spy-disguise.png中选中蓝方间谍显示GI，红方目标保持原样，面板身份仍为SPY。
- 专项断言包括右键、显式攻击、混编不吞其他成员攻击、无伤害/无追击、GGI二次伪装、载具/友军/死亡/已上车目标拒绝、眩晕指针与动作一致、建筑渗透不变、取消旧渗透、警犬识破、磁盘保存/恢复外观。可见性由统一actor_visible_to校验；当前专项未新加迷雾伪装专项断言，鼠标旧流程保留不可见目标检查。
- v1专项误用不存在的ADOG测试ID，出现两处识破失败和Nil脚本错误；纠正为本项目DOG后v2全部通过，未改识破规则。cursor v1 headless出现4处飞行器指针坐标失败：其脚手依赖真实绘制缓存飞行高度；同一源码/同一断言-Render运行v2全通过，没有删减断言或修改飞行器实现。
- Windows/Godot4.7.2，渲染RTX5060Ti Compatibility；独立project/custom_user_dir，服务/端口/DB/协议none，未操作真实存档。最终三套source_unchanged=true、engine_exit_code=0，交付运行时代码/版本指纹一致。第一次技能综合headless退出有2个ObjectDB/1资源释放告警，最终v2及两个渲染专项未出现此告警；不宣称已修复整个工程的历史释放问题。
- 影响限于间谍显式目标指令、其资格与鼠标提示；普通战斗攻击分支保持，未改伤害、胜负结算或存档格式。用户实机体验pending_user_visual_confirmation。未提交、推送或重新打包。

最终比对发现首次技能综合完成后共享Unit与其他测试被并行更新，因此在当前Unit上重跑allied-v2 200项通过；两个渲染专项已使用相同运行时代码。无关ra3_mirage测试文件随后变化，保留并行工作，不将它视为本轮测试内容。正式PrepareOnly Ready，目标diff --check通过。
本轮6份已结束隔离project经路径/归属/进程检查后删除，约释放2.14 GiB；失败与成功报告、日志、截图均保留。

## v0.2.10 载员格 · 2026-10-27
- 原版PIPS2.SHP和PALETTE.PAL来自本机Steam安装，通过既有YrSource/SHP解码导出0～5帧，分别为empty/green/yellow/white/red/blue。源档案、调色板、每张PNG哈希和帧位保存在assets/ra2/pips/cargo/source.json；可重跑ra2pipe/transport_pips.mjs，不复制参考引擎代码。
- 最终transport_indicator_regression -Render：C:/Users/admin/Temp/iron-cargo-20261027-v2/reports，184项通过；aircraft_ammo_regression -Render：C:/Users/admin/Temp/iron-cargo-ammo-20261027-v1/reports，94项通过，合计278。初轮cargo-v1 176通过，后补车辆Size及飞机高度边界，未修改已通过运行时实现。
- 两模式四种运输单位，空载/悬停/选中、真实request_board/tick装载、工程师原规则蓝格、实际像素变化、满载、真实卸载减少、登陆艇装MTNK占多个容量格、反复读取不改乘员/卸载状态、敌方/隐藏/死亡/普通坦克排除。SHAD升空后屏幕锚点实际上移；0.5/1/3倍缩放有截图；固定8px高度断言是布局检查，不冒充各缩放逐像素一致性证明。已查看BFRT满载和SHAD载工程师截图，血条下小格清晰且不覆盖冷却圈。
- 全程Windows/Godot4.7.2、RTX5060Ti Compatibility，隔离project/custom_user_dir，服务/端口/DB/协议none；未操作用户存档。两套source_unchanged=true、engine_exit_code=0。显示读取现有状态，不增加存档字段或触达战斗伤害、胜负、业务结算；无需完整战役主线。本轮测试无SCRIPT ERROR/ERROR或退出资源告警。
- 纯表现接入，用户视觉确认pending_user_visual_confirmation；未提交/推送/打包。版本README/project/CHANGELOG同步v0.2.10。
正式PrepareOnly Ready，运行时代码与最终验收指纹一致，目标diff --check通过。清理本轮3份已结束隔离project，释放1.08 GiB；报告和截图保留。
交付版本补充：并行RA3任务已将README/project/CHANGELOG升级v0.3，保留其版本，载员需求记录仍为v0.2.10。cargo-v2已在v0.3上通过。最终指纹差异仅RA3专用ra3_unit_model.gd与其专项测试，以及ammo旧轮次版本/新增cargo测试；Ra3UnitModel.attach明确仅Ra3Mirage.ID且非headless启用，四类运输与弹药被测机型不会进入该分支。载员/弹药/共同overlay及相关Unit运行代码匹配，不宣称全仓所有文件未变化。


## 2026-10-27 · v0.3 RA3 幻影坦克实时3D与玩法接入

最终六轮合计 **1856项断言通过**：ra3_mirage headless40、render73，production_catalog1250，skill_hotkey render173，allied_abilities200，savegame120（含新进程从磁盘读取）。渲染/无图形模式部分断言重叠，不将1856称为独立案例数。

覆盖真实工厂解锁/排队/出厂、15秒建造、RA2模式隔离、Q输入与冷却、场内隐身/反隐/开火暴露/重叠/死亡、普通及精英主炮/散射、存读档模式恢复；图形专项覆盖0.03弧度连续转向、五朝向炮口与相机投影一致、模型主体命中、透明角落不拦截鼠标、显隐恢复和共享网格。查看了实际1600x900战斗截图及384px模型预览。

证据根：`refs/ra3-mirage/integration-test/final-v0.3-r2/`，各目录包含result.json、console.log、godot.log；顶层audit.json保存源码指纹和环境。所有纳入指纹的脚本、数据、场景、着色器、项目设置及RA3模型资源前后未变化；交付前再次核对一致。转换工具从原始块重建的几何语义完全一致，六张贴图字节一致；运行素材provenance哈希逐项复核。

环境：Windows / Godot4.7.2；图形轮为RTX5060Ti OpenGL Compatibility。测试工程通过目录联接使用本工作区真实源码和资源，**不是独立源码快照**；配置和用户目录独立，`CodexIronTideValidation/ra3-mirage-20261027`，未使用正式玩家存档。无网络、服务、端口或数据库。正式`launch_game.ps1 -PrepareOnly`退出0、Ready。

production_catalog无图形退出仍有4个ObjectDB/2个资源清理提示；此前同模式详细诊断为Music/EVA的AudioStream/Playback残留，未将其声称为已修复。其1250项行为断言通过。RA3专项结束已停止测试音频，最终图形、技能和存读档运行未出现脚本错误。

已知边界：原版骨架动画、SAGE原始材质/粒子程序、精英第二级散射尚未移植；当前为Godot材质/特效与规则适配。新增单位改变对局内容指纹，旧版战斗存档按现有兼容校验可能不能读取，体验本版请新开对局；未覆盖或删除玩家存档。未做大规模3D单位GPU压力验收。使用者视觉状态为`pending_user_visual_confirmation`。未提交、推送或打包。

## v0.3.1 建筑维修扳手 · 2026-10-27
- 原行为只有“维修中/等待资金”文字；新RepairIndicator派生子节点接入本机Steam WRENCH.SHP七帧和PALETTE.PAL，来源/哈希在assets/ra2/ui/repair_animation/source.json，重导出入口ra2pipe/repair_animation.mjs。帧间偏移保留；0.16秒/帧是本作表现适配，不宣称逐帧复刻原引擎计时。
- 最终动画专项iron-repair-visual-20261027-v4 150项通过（两模式、电厂/工厂/矿场/维修厂/光棱塔）；原维修/出售输入专项iron-repair-actions-20261027-v3 126项通过，合计276。证据位于C:/Users/admin/Temp/<run>/reports。覆盖真实收费回血、无钱停帧/恢复、暂停、取消、满血、施工/冻结隐藏、父可见性及释放；实际图像frame0/frame2差异验证动画，已查看最终光棱塔截图。
- 首轮并行渲染时actions-v1首模式13处输入相关失败、另一模式通过；相同源码顺序独跑actions-v2通过126项。怀疑窗口失焦干扰，不把此假设写成已证实业务根因。随后actions-v3同样126通过。视觉v1/v2截图检查显示旧建筑血条残留，初步相机归因不足；最终确认冻结测试未queue_redraw HpOverlay。v4显式重绘后血条/动画位置正确。运行时锚点也收敛为血条使用的同一Iso矩阵，避免缩放近似。
- Godot4.7.2 Windows、RTX5060Ti Compatibility；独立project/custom_user_dir，服务/端口/DB/协议none，未改用户存档。最终视觉v4与动作v3均source_unchanged=true、engine_exit_code=0，未见脚本/引擎或退出资源错误。动作v3之后只有维修标识screen_origin投影和视觉测试重绘调整；其收费/回血/输入及Building源码与交付一致，最终投影由v4渲染覆盖，不宣称动作v3全部文件与交付相同。
- 无伤害/结算/存档格式改动；动画时钟不持久化，既有repairing状态负责恢复。未另外执行存档兼容回归，不将读档动画列为本轮已测。纯表现pending_user_visual_confirmation。正式PrepareOnly Ready，目标diff --check通过；未提交、推送或打包。
本轮7份已结束隔离project核对路径/归属/进程后删除，释放2.52 GiB；包含失败轮次的报告与截图保留。


## 2026-10-27 · v0.3.2 RA3 幻影坦克原版图标、地面履带与特效

最终7轮1889项断言通过（部分覆盖重叠）：presentation渲染33、mirage无图形40/渲染73、production_catalog1250、skill_hotkey渲染173、allied_abilities200、savegame120。报告为`refs/ra3-mirage/integration-test/final-v0.3.2/`，audit.json登记源码指纹和环境；运行前后指纹一致；交付收尾运行时代码、资源和本轮7套测试仍一致，仅并行会话的未执行测试model_smoothing_regression.gd发生变化（冻结HUD定时器，独立截图测试）；不声称整个共享工作区未变化。18项原始表现资源的输出哈希与provenance一致，模型重建一致。

新增专项覆盖真实Q输入、原版图标切换和2秒冷却、原生力场网格、实际移动/转弯留下双侧轨迹、静止/传送/隐藏/真实迷雾边界、帧缓冲轨迹像素差异、普通/精英棱镜主炮和散射、生命周期及读档清理。已检查最终prism-normal.png；此前检查了力场、精英和轨迹截图。视觉状态仍为pending_user_visual_confirmation。

环境为Windows/Godot4.7.2，图形使用OpenGL Compatibility；隔离project/custom_user_dir为CodexIronTideValidation/ra3-mirage-20261027，源码/资源通过联接引用原工作区，并非独立源码快照。服务、数据库、端口、网络均none，未操作正式存档。正式launch_game.ps1 -PrepareOnly返回Ready；git diff --check通过（仅既有换行转换提示）。production_catalog退出仍有已登记的音频ObjectDB/资源清理提示，不作为本次修复项；无新脚本错误。

特效采用RA3官方试玩版的纹理/网格，在Godot中适配播放；未导入SAGE原始着色程序和骨骼动画通道，RA3武器音频、精英二级散射未在本次实现。用户最新要求先试玩再归档：保留原IronTide工作区，不归档、不删除；未提交、推送或重新打包。


## 2026-10-27 · v0.3.2 模型边缘柔化

只改单位/建筑 CanvasItem 的最近邻/线性采样选择；新增共享设置控件和持久显示偏好。未改图集、Shader、炮口、选择/碰撞和战斗规则。默认开启，设置可立即关闭。`model_smoothing` 旧存档兼容、保存/重读和双入口控件联动在隔离 user_dir 中验证。

- model_smoothing **208/208**：`C:/Users/admin/Temp/iron-smooth-20261027-v4/reports`。
- model_render **346/346**：`C:/Users/admin/Temp/iron-smooth-model-20261027-v2/reports`。
- temporal_visual **74/74**：`C:/Users/admin/Temp/iron-smooth-temporal-20261027-v1/reports`。
- 共 **628** 项断言；三轮均源指纹前后一致、Godot exit 0。后续对照中只有新增 smoothing 测试的菜单截图夹具发生调整，未改变另外两套所测运行时代码。
- 环境：Windows、Godot 4.7.2、RTX 5060 Ti / OpenGL Compatibility，隔离项目+独立 custom_user_dir，无服务/端口/数据库/协议。没有触碰玩家养成存档。
- 首轮 smoothing 200/202：两个侧栏像素差异来自 HUD 的 PROCESS_ALWAYS 换肤 Timer（0.4s），截图可见按钮底图切换；冻结测试 HUD 后完整侧栏断言保留并通过。主菜单截图后来改为真实 settings.tscn 加独立 CanvasLayer，避免被战场摄像机影响。
- model_render 首轮 346 断言通过但审计失败：运行期间新增三个 `.gd.uid`（含并行 RA3 工作），不能算稳定源快照；v2 重跑通过。
- 已查看坦克/矿车/步兵/建筑蓝绿队色原像素与柔化截图，战斗设置和主菜单开关。`comparison.png` 为 v4 原始截图等尺寸裁切并列，无额外缩放/锐化。
- 正常入口 `launch_game.ps1 -PrepareOnly` 返回 Ready；`git diff --check` 通过（既有 LF/CRLF 提示保留）。本轮仅本地更新，无提交/推送/打包。

此处理降低硬像素边缘，不会增加低分辨率源素材细节；极大放大仍有柔软感，后续真正高清需要新的渲染/素材管线。实际观感 `pending_user_visual_confirmation`；可在战斗设置即时开关比较，无需再次加载战斗。


## 2026-10-27 · v0.3.2.1 整车履带与炮口修正

用户反馈上半车身和履带错向，证实旧版“独立炮塔”的假设错误；旧投影检查仅证明手写点与相机一致，没有证明其为原版FX_Weapon。已改为原始名字哈希定位SKL挂点并统一整车变换。无RA2单位修改，伤害、射程、冷却及存档字段不变；R3MIRAGE取消虚构的独立炮塔旋转等待。

最终7轮1893项通过：presentation图形33、mirage无图形40/图形77、production1250、hotkey图形173、allied200、savegame120。报告refs/ra3-mirage/integration-test/final-v0.3.2.1-r3/；前后和交付核验源码/资源指纹一致。首次运行旧“independent turret”断言失败，修正为整车不可拆分及实际像素约束后重跑，失败证据保留。实际查看model-3d.png与prism-normal.png，整体履带拼接和顶部发射点可见。

转换器原始包围盒验证、4889顶点/3552面计数与重建文件一致；备用32方位图集与炮口同步；资源provenance已更新。Windows/Godot4.7.2/OpenGL Compatibility，测试工程同一源码联接、隔离用户目录；无服务/端口/DB/网络，未用真实存档。正式PrepareOnly Ready。生产/无图形测试退出仍出现既有ObjectDB/资源清理告警，行为断言全部通过，无新脚本错误。状态pending_user_visual_confirmation；没有提交、推送、归档或删除工作树。

## 2026-10-27 · v0.3.3 尤复式圆形建造进度、阵营主题色

改动限定 HUD 生产显示：新增 production_clock.gd；卡片头像径向遮罩、队列页脚圆形进度、工厂标签主题色。进度读取既有队列分数，不改变生产时间/收费/存档/鼠标操作。UI 控件不接收鼠标，原按钮继续处理事件。

验证共 **451 项**：
- production_clock **60/60**：`C:/Users/admin/Temp/iron-clock-20261027-v2/reports`。双模式，建筑/防御、单位、等待、缺钱、低电减速、暂停/恢复、就绪/取消、多工厂切换、数量角标、夹取边界，三个阵营真实颜色像素和顺时针遮罩象限。
- production_hold **72/72**：`C:/Users/admin/Temp/iron-clock-hold-20261027-v1/reports`。真实卡片鼠标输入，资金不足建造、首右键暂停、左键继续、再次右键取消、退款、预约与矿场技能等既有合同。
- factory_tabs **319/319**：`C:/Users/admin/Temp/iron-clock-factories-20261027-v2/reports`。独立生产页签、状态与切换、长按/批量、矿车归属、布局、销毁回退等既有路径。

Windows / Godot 4.7.2 / RTX 5060 Ti OpenGL Compatibility，Render、固定60FPS、隔离项目+独立custom_user_dir，无外部服务、端口、DB或协议；未读取/改写玩家存档。三套运行前后源指纹稳定且退出0，结束复核本次三份运行时UI文件均逐字节一致。较早两套之后并行任务只改RA3表现文件、unit.gd中RA3与伪装绘制分支顺序、project版本及RA3测试；本套原RA2实体无RA3节点，两分支顺序不改变其消费路径。最终工厂套件使用当前v0.3.3.1全量快照；未把较早两套称作相同全仓SHA。

首轮 clock 51/53，测试把50%剩余区域误写为下半部；从十二点顺时针走半圈时右半已揭开、左半仍遮罩。修正独立象限断言并增加实际配色像素/边界检查后60项通过，没有改显示算法规避失败。工厂v1的319断言通过但运行中版本号与RA3测试变化，审计拒绝；v2稳定重跑通过。

已查看 `faction-clock-preview.png` 和双模式暂停卡片截图。配色预览明确标注苏联/尤里是后续显示预留，未开放其兵表；保留RA2 cameo，圆形罩与配色为独立Godot适配，不宣称原CLOCK.SHP/引擎逐像素复刻。页面文字与数量不受遮罩覆盖，状态文字继续给出停工原因。

版本记录：本项v0.3.3；并行RA3修复已把工程推进到v0.3.3.1，予以保留，不回退版本。实际观感 `pending_user_visual_confirmation`，本地修改，未提交、推送或打包。


## 2026-10-27 · v0.3.3.1 SDK光束时长与形态过渡

用户先描述“一闪一闪”，后明确攻击部分是光束消退，并要求以官方SDK为准；没有添加交战车体反复闪隐。进一步查明Weapon.xml的ActivateLaserNugget Lifetime=1.5s（普通/精英相同），CannonNode LaserLifetime=0.5s，LaserDraw未指定FadeOutTime，XSD默认0s。先前0.3秒清除错误；本轮初拟的0.65秒自定义渐隐已撤销。保留原版双层UV滚动，主/散射宽度25/5，精英散射继承基础贴图。持续光束读取真实炮口和目标位置，渲染不产生额外伤害。

extract_visual_rules.py直接读取本地官方SDK XML及XSD，将时长、宽度、粒子寿命/初始延迟/RGB和Alpha关键帧写入data/ra3_mirage_visuals.json，并保存源文件SHA256；交付核验源哈希匹配。命中闪光25帧、火焰延迟5帧及寿命25帧、炮口闪光10帧，读取原颜色关键帧衰减至黑。Primage_Disguise寿命20～30帧，50% Alpha=1、100%=0。粒子帧按30fps适配；SAGE内部GPU程序并未移植。

正常伪装模式加入模型与现有TREE01素材双向交叉渐变，己方车体目标0.5来自SDK；0.7秒模型切换是明确标记的Godot适配值，SDK未公开该时间。状态、伤害、反隐与开火暴露计时不变，只有模型/特效绘制过渡。伪装树仍为既有RA2资源，不声称原版RA3树模型。

最终7轮1914项通过：presentation渲染54、mirage无图形40/渲染77、production1250、hotkey渲染173、allied200、savegame120。报告refs/ra3-mirage/integration-test/final-v0.3.3.1-sdk/；源码、资源运行前后及交付指纹一致。覆盖旧截断时间仍显示、原始主/散射寿命、移动时炮口/目标跟随、粒子逐渐衰减、双向形态过渡、暴露/伤害不等渐变结束才生效。已查看sdk-primary-0.75.png和idle-fade-enter.png。早先final-v0.3.3.1为用户澄清前的适配实验，不能作为最终SDK行为。

Windows/Godot4.7.2/OpenGL Compatibility；同一真实源码联接的隔离测试工程、独立user目录，无网络/端口/服务/DB，未用正式存档。PrepareOnly Ready；目标diff --check通过。既有无图形音频退出资源告警未在本次修复，未出现新脚本错误。状态pending_user_visual_confirmation。保留并行任务v0.3.3基础并升补丁v0.3.3.1，未提交、推送或归档。

## 2026-10-27 · v0.3.3.2 RA3 SDK 收尾

本轮只新增 `tools/ra3_mirage/audit_sdk.py` 及其独立失败案例测试、更新 README/版本/交接；没有改动游戏移动、攻击、生产、存档或资源内容。按用户指示，不从试玩版补资源。审计仅读取选定 SDK 与已交付运行文件，无下载、解包或模型重建。

声音核对递归展开 18 个单位/武器事件，89 个去重音频引用均未在 SDK Audio/Art 中找到可用散装文件，事件解析无未解析引用。包含共享音效，不能称为89段专属语音。11 项直接 ART include 缺失；保留动画条件、原声音参数、散射与伪装配置、死亡 OCL/COL 和 BaseCollapsingObject 继承原文结构。各死亡模块时序独立保留，没有猜测合成时长。

SDK 视觉参数真正重新生成，与当前运行 JSON 语义一致；现有 presentation 资源哈希与来源清单一致，字面运行资源引用存在，未发现引用本机 refs 输入。审计正常模式返回0但状态明确为 `native_media_incomplete`，严格素材模式按预期返回2；这不是原生语音、动画或残骸集成通过。工具7项边界测试通过，覆盖嵌套事件/注释、缺事件、循环、假素材缓存、大小写匹配、继承元数据及独立死亡时序。

本轮最终重跑：presentation 图形54、mirage 无图形40、mirage 图形77，共171项全部通过，另有7项工具测试通过。首轮后交付复查检测到另一路修改了 project.godot、ra2_art.gd 和 model_render_regression.gd，已保留其 v0.3.4 更新；旧报告标记被替代，在最新源码上重跑三项并增加 RA2 PNG/JSON 依赖指纹。没有运行玩法无关的完整生产/存档大套件；这些实现本轮未修改，上一版完整回归仍是历史证据。已查看本轮 `model-3d.png` 和 `sdk-primary-0.75.png`；实际画面仍需玩家确认，不把截图检查当玩家验收。

环境：Windows，Godot 4.7.2，图形场景 OpenGL Compatibility；既有真实源码联接测试工程 `refs/ra3-mirage/integration-test/project`，独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`，不读写正式存档，无网络/服务/DB/端口。运行前后所有登记源码/运行资源/工具指纹一致，正式 `launch_game.ps1 -PrepareOnly` 返回 Ready 后再次核对一致。无新增脚本错误；无图形场景的既有退出音频资源告警没有在本轮修复。

证据：`refs/ra3-mirage/integration-test/sdk-closeout/current-v0.3.4/runtime-audit.json`、上一级 `sdk-audit.json` 和 `sdk-strict-audit.json`。工具、文档和补丁内容留在原工作区；当前工程版本为 v0.3.4，没有回退并行更新。未提交、推送、打包、清理或归档。原版素材缺口仍在交接首页明确登记，`pending_user_visual_confirmation`。


## v0.3.4：体素表面与两倍密度图集（2026-10-27）

本轮源为 `C:/Users/admin/IronTide/iron_tide`，分支 `codex/ra2-independent`。仅处理现有 61 个 VXL 条目及其车身/炮塔层，独立表面三角形光栅化、原版 VPL 查表、原生覆盖率与 2×细节图、实际绘制适配；玩法属性、碰撞体、生产、存档与 RA3 内容没有本轮变更。

- Node 光栅化及既有 VXL/HVA 解析：9 项通过。新测试覆盖表面覆盖率、VPL 截断/颜色消费、重叠面顺序无关、32 方位/阴影投影及空模型。初次深度测试失败于共面交叠和 Float32 深度量化；改用 Float64、容差与稳定共面规则后通过，未移除该断言。
- `model_render_regression -Render`：814 项通过；76 张细节图层的载入、尺寸、全方向/姿态像素、真实绘制消费；灰熊/矿车/机器人切换原生/细节图后选择中心及炮塔矩形一致；既有阴影缓存、透明度并集与选择检查保留。
- `unit_muzzle_regression -Render`：3546 项通过；`temporal_visual_regression -Render`：74 项通过；`model_smoothing_regression -Render`：208 项通过。合计 Godot 4642 项，加 Node 9 项，共 **4651 项通过**。

最终运行目录（保留 reports，测试 project 为可删除副本）：

- `C:/Users/admin/Temp/iron-surface-model-20261027-v2/reports`
- `C:/Users/admin/Temp/iron-surface-muzzle-20261027-v1/reports`
- `C:/Users/admin/Temp/iron-surface-temporal-20261027-v1/reports`
- `C:/Users/admin/Temp/iron-surface-smoothing-20261027-v1/reports`

首轮模型回归 818 项中有 14 项失败，原报告保留于 `iron-surface-model-20261027-v1/reports`：4 项是新检查误纳入不在本批范围的巨炮/爱国者建筑炮塔；明确按 `_turret` 专用层排除后不冒称覆盖。另 10 项揭示真实阴影合并问题：原 masked blit 对半透明边缘会降低原车身覆盖率；已改逐像素 alpha max，原并集断言继续全部通过。

环境：Windows、Godot 4.7.2、RTX 5060 Ti/OpenGL Compatibility、固定 60 FPS，四套串行运行。各套使用独立复制工程与独立 custom_user_dir；无服务/网络/端口/数据库。四套前后源指纹一致，交付复查逐项与当前运行源文件哈希一致；候选 393 项导入产物与 source-audit 哈希一致。未运行完整对局规则主线：改动闭合于烘焙/绘制/原生覆盖遮罩，炮口与真实消费专项覆盖相关边界，不触达对局状态推进。

候选及可逆旧资源备份：`C:/Users/admin/Temp/iron-surface-all-20261027-v2/`（source-audit、import-audit、final-validation、before-import.zip）。旧文件压缩备份已逐项哈希校验。已检查同尺寸旧/新导出对比，以及实际蓝/绿矿车与坦克、1/2/3 倍缩放截图。代码/像素检查不替代玩家观感：外观为 **pending_user_visual_confirmation**，没有宣称原引擎完全复刻。

使用正常 `启动游戏.bat` 重开即可加载本地更新。未提交、未推送、未制作新朋友包。渲染结构与后续再生成边界见 MODEL_RENDERING.md。
本轮结束确认无测试 Godot 进程；已删除 5 份自有隔离 project 副本（约 1.85 GiB），保留成功/失败报告、截图、指纹和旧资源备份。最终实际启动目录 PrepareOnly 返回 Ready。

## v0.3.5：原版 RA3 幻影语音、骨骼、碎块（2026-10-27）

来源为 ModDB Complete Allied Art Source Pack 与 Sounds Resource Allied Vehicles；未继续使用试玩版补素材。运行接入53个原音频（50语音+3武器）、22骨骼、两段各121帧的原动作、11个COL骨骼碎块/15表面。素材哈希、作者与限制见 assets/ra3/mirage/native 的 provenance 文件及 RA3_MIRAGE_MODEL.md。

Godot PrepareOnly 返回 Ready；最终9组2079项检查全通过：native headless72 / render93、mirage headless40 / render77、presentation54、production catalog1250、skill hotkey173、allied abilities200、savegame120。另有SDK审计工具7项测试通过。新增断言检查PCM解码与播放、SDK被注释音频排除、声音状态、实际Skin/Skeleton绑定、原始炮口、动作循环、真实死亡钩子、重复死亡、24份残骸上限、时空抹除、生命周期及真实存读档清理。首轮原生截图发现UV纵轴未翻转，已修复导入器并增加逐点UV基准校验；首轮新版测试把帧末回收中的旧残骸误算为新残骸，保留无新增断言并排除已排队销毁对象，最终重跑全部通过。

证据：refs/ra3-mirage/integration-test/sdk-closeout/native-v0.3.5-final/runtime-audit.json。验证工程junction消费真实项目源码/资产，使用独立用户目录 CodexIronTideValidation/ra3-mirage-20261027；Godot4.7.2 OpenGL Compatibility，服务/端口/DB/network为none。前后源码、测试、工具及RA2/RA3 PNG/JSON/WAV哈希一致，无环境漂移，无新增运行错误。已查看native-model.png与native-wreck.png，图像检查不能替代玩家的视觉/听感验收。

边界：只影响扩展幻影表现和其声音；RA2音频路径保持。撤退语音仅注册事件，现游戏无对应指令；共享武器layer1、场开关/循环声音及EXCloakingField原动画不在所得Mirage目录。碎块使用原模型和SDK质量/时序，散落为Godot表现适配，不参与物理寻路/伤害。仍为 pending_user_visual_confirmation。原工作区保留，未提交/推送/打包/归档。

## v0.3.5.1：三辆混编移动卡顿（2026-10-27）

用户复现条件：RA3幻影与普通坦克合计三辆混编移动，Q未开启；停下恢复。只读代码与渲染对比确定主要瓶颈为 VehicleTracks：每添新痕迹就 queue_redraw，最多1600个独立 draw_polygon 在移动中反复提交。隔离掉骨骼或3D没有解决混编成本；三辆场景只隐藏轨迹即可从17.604ms降到2.935ms，物理逻辑中位数335us。

修复限定 scripts/world/vehicle_tracks.gd：两张原贴图各用一个 MultiMeshInstance2D，保留几何UV、旋转、0.8初始透明度、18秒寿命及末5秒淡出；新增轨迹最高30Hz批量更新，静止10Hz淡出/视野刷新，屏幕外不提交。仍最多1600条，原位置和采样逻辑未变，读档继续销毁整个轨迹节点。骨骼、3D模型、移动/寻路、攻击规则均未修改。实现参考 Godot 官方 MultiMesh / MultiMeshInstance2D API。

同机同脚本、1600条轨迹、三辆混编：移动帧中位数17.604→3.990ms，P95 21.248→6.638ms，物理中位数335→345us；停止中位数6.961→3.025ms。12辆混编中位数22.000→6.724ms，P95 31.002→8.065ms。前后测试都关闭垂直同步测吞吐，保持真实Godot渲染、生产Actor、寻路/移动消费者；测试用固定步长推进并关闭无关战局自动处理，不是整场长期实战FPS承诺。原运行游戏进程未被终止或修改，需要玩家重启加载新脚本。

复跑目标：res://tests/ra3_track_perf.tscn。证据在 refs/ra3-mirage/integration-test/{tracks-before,tracks-after,mixed-before,mixed-after}/；探索性单辆/12辆探针源码归入忽略的证据目录，长期只保留目标性能入口和行为回归。

最终4组287项断言全通过：vehicle_tracks20、ra3_presentation54、ra3_native93、savegame120。断言包含两批实例、原纹理、旋转/位置、GPU颜色容差内的淡出、屏外剔除、隐藏/恢复可见、1600容量、30Hz提交上限、实际存读档清理；现有原版动画/语音/残骸和Q轨迹测试保持通过。初次新测试中浮点颜色被GPU量化，改为1/255容差；手工加入fog与初始无fog开局不一致被存档校验正确拒绝，改为正式开启fog的测试场景后通过，未更改存档校验。已查看批量轨迹截图，使用者视觉/性能确认仍待反馈。

最终报告 refs/ra3-mirage/integration-test/sdk-closeout/tracks-v0.3.5.1-final/runtime-audit.json。Godot4.7.2/OpenGL Compatibility/NVIDIA5060Ti，验证工程及存档隔离沿用ra3-mirage-20261027，服务/DB/端口/network均none。真实游戏源码、RA2/RA3 PNG/JSON/WAV及测试工具前后哈希一致，无新增运行错误。当前补丁未提交、推送、打包或归档。

## v0.3.6.1 · 一击击杀光束消失

根因：Ra3Mirage.shoot 在伤害前已创建 FX，但 Ra3WeaponFx 下一帧检测到任一端死亡便 stopped=true，主目标即时死亡使主光束和散射都在首帧隐藏。改为分别跟随存活端点，死亡/释放端点保留发射时或最后有效位置；寿命仍为主束1.5s、散射0.5s。散射的迷雾起点使用实际主目标地面位置。没有修改伤害、攻击间隔、幻影场或 shader。

新增 `tests/ra3_lethal_beam_regression.tscn`：真实 `_fire_shot` 击杀载具/建筑、主次目标同时死亡、释放发射者、独立端点跟随、寿命回收。旧实现25项中10项逻辑失败。最初整屏像素比较会被死亡动画干扰，不能作为修复证据；最终将实际 beam 绘制节点放入隔离视口，分别确认5481/5476/630个光束像素，排除其他表现干扰。

最终4组276项通过（专项25、presentation54、mirage77、savegame120），无脚本/渲染错误，运行前后代码配置指纹一致。`launch_game.ps1 -PrepareOnly` Ready。最终证据 `refs/ra3-mirage/integration-test/sdk-closeout/lethal-beam-final2/audit.json`，同目录包含原场景与隔离光束截图。

环境为 Godot4.7.2/OpenGL Compatibility、隔离 validation project、CodexIronTideValidation 用户数据；无网络/DB/服务依赖，没有关闭玩家现有进程。表现为 pending_user_visual_confirmation，重启游戏后测试直接击杀及散射击杀。保留并发 v0.3.6 模型增强；本轮未推送、打包、归档。幻影场缺失原版动画的问题仍未解决。

## v0.3.6：建筑、人物、舰船与防御炮塔清晰度增强（2026-10-27）

功能记录v0.3.6；当前工程保留并发RA3补丁v0.3.6.1。源为 `C:/Users/admin/IronTide/iron_tide`，分支 `codex/ra2-independent`，沿用共享原工作区，没有回退其它未提交修改。范围是现有SHP增强、专用防御炮塔表面重烘及其真实绘制消费者，不改变单位尺寸、移动、碰撞、伤害、队列或存档规则。

111个有效SHP图集、11181帧，118个最大2048边长的裁剪页面；原始224个PNG/JSON输入哈希不变。全部29411679个原生像素位置逐个验证：原生透明格保持透明、非透明格保留覆盖、输出颜色来自原帧、无相邻帧污染；2613500个子像素实际改变。输入/输出哈希均通过。GAGREEN零尺寸占位明确跳过；SQD只有描述/特效而无有效主体PNG，未声称完成或加入兵表。

巨炮、爱国者以原VXL/VPL重烘，含巨炮8档后坐×32方位。候选239项导入文件哈希匹配；原炮塔画布/原点/炮口/后坐描述去掉新增detail字段后与导入前备份一致。v0.3.4车辆、飞机、舰船393项资源哈希仍匹配原候选，没有被旧导出器覆盖。

最终十组真实Godot图形检查共5458项，全部通过：

| 专项 | 断言数 | 最终目录后缀 |
| --- | ---: | --- |
| shp_detail | 1024 | shp-detail-20261027-v4 |
| building_animation | 494 | building-animation-20261027-v4 |
| defense_art | 472 | defense-art-20261027-v4 |
| recoil | 1092 | recoil-20261027-v3 |
| unit_art | 902 | unit-art-20261027-v3 |
| model_render | 814 | model-render-20261027-v3 |
| temporal_visual | 74 | temporal-visual-20261027-v3 |
| model_smoothing | 208 | model-smoothing-20261027-v3 |
| construction_transition | 80 | construction-transition-20261027-v3 |
| building_preview | 298 | building-preview-20261027-v3 |

目录共同前缀 `C:/Users/admin/Temp/iron-all-detail-`，结果在各自 `reports/result.json`、日志及environment-audit。调用 `tests/run-navigation-building.ps1 -Suite <专项>_regression -Render -RunRoot <新目录>`。另 `node --test ra2pipe/shp_detail.test.mjs` 的5项PNG/调色板/透明边界/不串帧/非法输入测试通过，总计5463项；像素审计规模另列，未当作断言数量相加。

专项真实消费了人物、飞行兵、海豚、建筑主体与全部动画叠层，以及VXL飞机/舰船；检查细节/原生切换出现实际像素变化、蓝/绿队色、几何/血量/选择保持、静止对象在共享页面缓存淘汰后仍显示、全方位炮塔点击、后坐炮口与冷却保持、基地展开收起与放置预览。原64MiB缓存之外，活跃对象持有当前/上一绘制页；这不是游戏总显存上限。实际效果保留原像素风，不宣称高模或原引擎逐像素复刻。

先前失败与复查：

- 新SHP测试首次误把未在当前兵表中的SQD当作可生成单位，另把JUMPJET画布中心当作可见像素；分别改为当前实际兵表与原生实像素点击，并隔离比较模型区域，避免其它动画干扰。保持实际像素变化、点击、缓存淘汰断言，未更改游戏来迎合夹具。
- 老building_animation测试用原始建造时长直接推进，未除现有production_work_rate，导致船坞提前完成后计时错位。将测试等待秒数对齐实际队列倍率，保留出厂前隐藏、出厂首帧、推进及结束等原断言；生产代码与游戏时间不变。原失败494项中的6项现全部通过。
- 早期三组运行期间并发RA3运行源码变更，旧证据不作为最终交付；已在最新源码重跑SHP、建筑动画、防御炮塔。recoil/unit_art/temporal_visual的runner全仓指纹变化仅来自独立RA3测试入口；交付复核确认运行源码、配置、素材及本轮实际消费的测试依赖一致，变化的ra3_sdk_timing_regression和ra3_mirage_regression没有运行引用、class_name或当前专项依赖。保留原source_unchanged=false与完整排除记录，不伪造原报告为全仓未变。

收尾再次发现并行任务修改了RA3专属的ra3_mirage.gd、ra3_weapon_fx.gd。已逐项读源确认：这些专项不生成R3MIRAGE，军衔/开火/幻影场入口按ID门控，RA3光束和延迟命中标记仅由其专属开火路径创建；固定核实后的两文件哈希写入审计排除清单，不泛化放行未来修改。最新工程再次PrepareOnly Ready。本次只验收RA2模型显示相关依赖，未把并发RA3玩法改动冒称已经回归；其余消费源码/资源哈希与专项一致。

最终交付审计：`C:/Users/admin/Temp/iron-shp-detail-20261027-v3/delivery-validation.json` 和 `delivery-resource-audit.json`；生成与像素审计同目录source-audit/pixel-audit。专用炮塔候选与旧资源备份 `C:/Users/admin/Temp/iron-defense-detail-20261027-v2/`。已查看实际战车工厂/人物放大画面与巨炮后坐开火截图。

环境：Windows、Godot4.7.2、OpenGL Compatibility/NVIDIA RTX5060Ti；各套串行，独立复制测试工程与custom_user_dir，固定60FPS。服务、网络、端口、数据库均none，不读写正式存档，不终止玩家游戏。正式 `launch_game.ps1 -PrepareOnly` 返回Ready，无新增脚本/渲染错误；资源与最终运行源码指纹复核通过。本轮显示改动闭合于图像生成和绘制适配，未触达对局状态推进，因此使用上述显示/选择/过渡专项，未冒称整局玩法验收。

测试副本按精确路径与进程归属核实后删除，保留reports、失败证据、截图、指纹和旧资源备份，清理记录同候选目录 `test-copy-cleanup.json` 及各报告 `copy-cleanup.json`。主工程和待玩家验收内容保留。尚未提交、推送或打包。

重启 `C:/Users/admin/IronTide/iron_tide/启动游戏.bat` 加载本地更新。外观状态为 **pending_user_visual_confirmation**；原SHP没有的五官、材质与几何细节仍需要新的高质量源素材，不把边缘增强写成高清重制已完成。


## v0.3.7：框选优先排除矿车（2026-10-27）

用户要求框选部队时不要把矿车带上。原 `_apply_selection` 对框内所有己方单位直接调用select_unit，没有候选优先级。现仅在框选分支先收集存活、未待删除、未登载的己方候选；如本次框内有非矿车，只选非矿车，否则正常选矿车。使用现有is_harvester属性，不硬编码CMIN。Shift只过滤新候选，保留旧选择；点选/Shift点选/同类选择、坐标换算、GUI手势所有权和指令入口不变。不扩张为工兵/基地车等非矿车的低优先级规则。

参考一手 [Phobos Low priority for box selection](https://phobos.readthedocs.io/en/latest/User-Interface.html#low-priority-for-box-selection)：混合框选排除低优先级、单独框选保留，Shift按追加候选判断。Godot独立实现，不声称未修改的RA2原版具有该功能，没有复制参考源码。

最终v0.3.7两组420项全通过：miner_selection_regression渲染180项，box_ui_release_regression渲染240项。前者用真实Viewport鼠标按下/移动/松开，覆盖双模式、0.5/1/2倍缩放、正反方向混选、单矿车/双矿车、敌方/死亡/舱内不压制矿车、工程师正常优先级、Shift矿车追加/保留旧矿车、点选、Shift点选、空框清空与selected视觉标志。后者覆盖两档分辨率三档缩放下小地图/框架松开、跨图返回、Shift追加及小地图拖图所有权。没有替换实际选择函数或依赖真人桌面鼠标。

证据：`C:/Users/admin/Temp/iron-miner-selection-20261027-v2/reports`、`C:/Users/admin/Temp/iron-miner-box-ui-20261027-v1/reports`。首轮v1同样180项通过，为升版前证据，不重复计数。各最终运行源码/配置/资源指纹前后一致；交付时另一路新增RA3读档迁移和独立测试。已对隔离副本逐行比较：battle_snapshot只在restore新增调用，ra3_mirage只追加ID门控的restore_native_rules；本轮场景不开读档、不生成R3MIRAGE、不消费其专项入口，已保存diff和当前哈希，不将该并行存档工作纳入本轮验收。其余实际选择消费者、配置、素材与测试依赖均与专项一致；PrepareOnly产生的新脚本UID仅属导入元数据。环境Windows/Godot4.7.2/OpenGL Compatibility/RTX5060Ti、隔离复制工程及独立用户目录，无服务、网络、端口、DB，不动正式存档。作用闭合于本地框选候选，不触达伤害、生产或对局生命周期，因此采用真实输入专项而非整场对局回归。

已保留并行v0.3.6.2内容，新需求升v0.3.7；正式启动PrepareOnly Ready。自有已结束测试project副本清理，保留reports及copy-cleanup记录。未提交、推送或打包。逻辑验证通过，实际操作手感仍为pending_user_visual_confirmation。


## 2026-10-27 · v0.3.7.1 RA3幻影SDK时序与旧档兼容

修复范围：R3MIRAGE从尤复晋升倍率分离；1.6秒普通攻击周期、固定1.5秒主束、0.1秒延迟伤害；原速度80×空间比例2.2、加速0.01秒、SDK清雾及晋升；1600价格/15秒生产；原生英雄自愈；旧存档一次性迁移。未改全局1倍速、RA2属性或原生光束Lifetime；英雄1.35秒调度是当前Godot适配公式，不声称已由零售引擎证明。

Godot PrepareOnly Ready。8组1158项通过：ra3_sdk_timing108、ra3_lethal_beam25、ra3_presentation54、ra3_mirage79、veterancy116、savegame120、battle_clock328、weapon_trail328。实测30/60/120Hz的开火周期、真实工厂14.9秒未完成/15.1秒完成与扣1600、延迟命中存读档只结算一次、英雄自愈分数计时、旧军衔/倍率迁移与幂等、RA2晋升/弹道保持，以及真实墙钟生产时长。9个本地官方SDK来源可重复生成balance JSON，游戏核心配置逐项匹配。

证据：`refs/ra3-mirage/integration-test/sdk-closeout/sdk-timing-legacy-final/audit.json`和同目录delivery-audit.json。源C:/Users/admin/IronTide/iron_tide，branch codex/ra2-independent，Godot4.7.2 OpenGL Compatibility；验证工程通过junction消费实际源码，用户目录CodexIronTideValidation/ra3-mirage-20261027，服务/网络/端口/DB均none。前后源码/数据/测试/着色器指纹一致；交付仅追加project.godot版本metadata到0.3.7.1，没有源码变化，不为版本字符串重复跑玩法回归。

失败记录保留：早期夹具目标点触发既有PathService网格越界，换到既有稳定测试坐标后无此脚本错误；未修复该通用寻路缺口。模型只改变瞄准时图形差异为1像素红通道1/255，保留PNG并将允许偏差限定为最多4个通道各1，不放宽几何/炮口断言。首次final运行期间并发版本号变化，被指纹审计拒绝；最新共同源码已重新全量通过上述8组。

本次专项覆盖范围闭合在指定单位、显式ra3_hit_delay队列和旧档ID分支；共用路径以RA2晋升、存档、时钟及弹道回归覆盖。没有声称整局/所有RA3引擎行为已复刻。尚存完整SAGE转向/受损减速、独立视觉侦测、护甲体系、英雄二级散射及幻影场原动画缺口；详见RA3_MIRAGE_MODEL.md。表现状态pending_user_visual_confirmation，重启游戏测试；未提交、推送、打包或归档。

## 2026-10-27 · v0.3.8 世界级闪电风暴

按用户最后指示，本轮只完成风暴后停止，不继续超时空或后续路线。Godot PrepareOnly已返回Ready。三组主进程605项断言通过，另两个独立进程合计28项，合计633项：lightning_storm_regression 253+冷启动12；savegame_regression 120+冷启动16；support_buildings_regression 232。风暴的两模式/双方、蓄势和落雷阶段的摧毁/出售、断电、暂停、终局、同时释放、真实Battle._process入口、15/60Hz及慢帧、旧档迁移/幂等、活来源重映射、无来源磁盘/冷启动读档均覆盖。IonWH伤害、友伤、范围与既有支援建筑/超时空限制由关联专项覆盖；通用存档保留运输、矿车、维修、生产和RA3既有迁移分支。

运行源 `C:/Users/admin/IronTide/iron_tide`，分支codex/ra2-independent，Godot4.7.2，离线headless隔离工程，服务/网络/端口/数据库均none；每组独立CodexIronTideValidation用户目录。入口 `tests/run-navigation-building.ps1 -Suite <suite> -RunRoot <外部唯一目录>`。证据：`C:/Users/admin/Temp/iron-lightning-world-20261027-v3/reports`、`iron-lightning-savegame-20261027-v1/reports`、`iron-lightning-support-20261027-v4/reports/latest-source`。后者在已隔离工程更新并核对当前共享源码后重新执行，环境审计source_unchanged=true、exit=0、errors=[]。本机原规则来源及档案哈希另存world-v3/reports/original-rules.json。报告、最小验证源码压缩包和修改前备份已保留。本轮8个复制工程的删除被自动审批以blocked by policy拒绝，未执行删除，临时project目录仍保留；未改动用户工程或其他任务的缓存。

失败记录不覆盖：world-v2的并发风暴夹具缺供电，被真实低电规则拦截；补齐电厂和成功断言后v3通过。support-v1六项墙段断言失败，回放改动前的runtime和测试也复现“必须紧贴我方建筑建造”，确认旧夹具无BaseNormal来源；仅补合法建造场前置和准入断言，没有改墙或建造范围逻辑。support-v2/v3退出时出现AudioStream/Playback残留，verbose定位为BGM与放置音效；夹具停止音频、清空音乐stream，并留150ms真实混音线程收尾后无错误，未改游戏音频服务。v4首次运行受并发RA3军衔图标改动影响，自动环境审计拒绝；latest-source已纳入最新六个相关源码/测试文件重新通过。

风暴与存档两组最初运行前后指纹稳定。之后的变动已检查：本轮仅support测试前置/退出清理；并发改动为Ra3Mirage.rank_texture辅助、两个带R3MIRAGE分支的图标消费者及独立RA3测试。风暴专项不生成R3MIRAGE，存档专项使用其他单位，新增图标方法不在其状态恢复路径；不借本轮结论验收并发RA3功能。交付指纹差异另记latest-source/delivery-audit.json，未声称旧运行的全文件指纹等于最新工作区。

本轮没有完整长局压测，也没有宣称完整复刻风暴的云层延迟、吸雷、间距、雷达干扰或光照；详见ALLIED_ABILITIES。本轮逻辑断言已通过，云层/落雷实机观感pending_user_visual_confirmation。未提交、推送、打包或归档工作树。

最终并发边界：latest-source通过之后，另一项任务又继续新增/修改RA3音频、幻影场、模型、shader、资源和独立测试。本轮风暴涉及的9个实现/测试文件再次核对，字节仍与通过快照一致；PrepareOnly再次Ready。上述633项结论属于保留的隔离验证快照，不表示之后不断变化的整个共享目录已重新全量验收。新增RA3工作未由本轮验证，delivery-audit.json明确whole_latest_shared_checkout_validation=false并列出后续差异；遵从“弄完风暴停止”，不追逐或修改另一项任务。
