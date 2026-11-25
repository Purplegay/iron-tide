# 普通玩法第九批：海空交叉火控、拦空测距

2026-11-18。本批在当前共享分支实现 C15、T08，累计 **15/24 张普通卡、13/16 项普通天赋**，剩余 9 张卡、3 项天赋。英雄、皮肤、版本号仍由原会话负责；本批不打包、提交或推送。

## 已接入玩法

- **C15 海空交叉火控**：海蝎 HYD 史诗被动。普通对空齐射补一发对海炮，普通对水面舰船齐射补一发防空炮；最近合法可见副目标须在对应武器原有射程、射界内。伤害为该领域武器的 40/50/60/75%，共用间隔 4/3.5/3/2.5 秒。同轮只检查一次，另一领域无目标不扣间隔；不改变原主目标、移动指令、普通装填或连发。补射保留对应原生弹头、散射和命中判定、军衔及火力成长；防空 FlakProj 原本为 Inviso，即发即结算，不能用“仍在飞的弹数”判断是否发出。补射不触发其它追加攻击。对岸、潜航目标、临时复制品以及经典模式均不触发。
- **T08 拦空测距**：神盾 AEGIS 普通天赋，Lv.0～3。对同一敌机连续三轮普通直击实际造成伤害，获得两次新装填缩短 10/15/20/25%；同轮多弹最多记一次。奖励不回改已开始的装填，两轮奖励发射不预先累计下轮次数。转火、目标失效和易主清空；之前目标的迟到弹、溅射、技能、额外攻击不记数。目标引用、累计次数、在途普通弹的计数代次、剩余额度和当前装填按现有快照恢复。
- 两项均为被动机制，无新增 W 按钮或 Auto W 策略。既有护航水幕自动施放、重炮压舱手动策略不变。
- 普通池可抽取、兑换、升级和装配；神盾天赋可解锁并升级。两项均带 `expansion2`，自动进入“新！”标记流程，实际获得卡/解锁天赋后消标，预览不消标。
- 已补四档演示、独立图标和战斗状态。交叉火控展示两领域补射与共用间隔；测距展示三轮命中、两轮加速及转火清空。

## 代码入口

- `iron_tide/scripts/units/expansion_2_naval_fire.gd`：独立海军火控逻辑。只在真实普通发射时寻找副目标，不增加逐帧全场扫描；补射复用原生 Projectile 与伤害计算，不借用另一领域高伤害。
- `unit.gd`：普通发射、命中判定前调用补射入口；`progression_expansion.gd`：普通弹写入测距代次、受伤回调记数。
- `progression_expansion_2.gd`：新装填、计时、易主清理、状态与绘制接入；`progression_expansion_2.json` 为范围、稀有度与等级参数来源。
- `ui/expansion_2_demo.gd`、`ui/progression_icon.gd`：演示及图标。

## 本轮验证

源码 `C:/Users/admin/IronTide`，分支 `codex/ra2-independent`。只使用隔离 APPDATA/LOCALAPPDATA；Godot 4.7.2 直接 headless 入口，复用既有只读资源链接验证工程。服务、数据库、协议入口均未使用。GPU 使用从未激活的私有 Windows 桌面，不接管用户桌面，0 截图。

运行入口位于 `.validation/progression-expansion-2-gameplay-batch9-20261118/`：`run.py <suite>` 和 `run_gpu.py`；Python 使用 `C:/Users/admin/AppData/Local/Programs/Python/Python312/python.exe`。

| 套件 | 检查数 | 结果 |
| --- | ---: | --- |
| progression_expansion_2_naval_fire_regression | 155 | 通过 |
| progression_expansion_2_naval_regression | 197 | 通过 |
| progression_expansion_2_regression | 722 | 通过 |
| progression_new_regression | 54 | 通过 |
| final_damage_limit_regression | 124 | 通过 |
| progression_expansion_2_demo_regression，隔离 GPU | 660 | 通过 |
| 合计 | **1912** | **0 失败** |

专项覆盖四档真实发射/命中/新装填、同轮去重、两领域共用间隔、原生防空瞬时弹、最近目标和真实武器伤害、军衔及增伤、可闪避、迷雾、射程、装载/潜航/岸上排除、迟到弹/追加弹排除、经典模式、转火/死亡/易主、在途第三击与一份剩余额度读档、天赋真实购买升级及磁盘重载。

首轮测试的近邻舰船处于原生溅射范围、Inviso 弹被误当作飞行弹，以及迷雾夹具副目标超出对海射程，均按现有原生规则修正夹具后重跑；含 SCRIPT ERROR 的中间运行不计验收。最终各套件日志无 SCRIPT ERROR、ERROR 或 WARNING。GPU 返回 0，`activated:false`，输入桌面前后均为 Default；完成后无 Godot 验证进程残留。最终摘要、源码哈希和原始报告位于本轮缓存根。

未扩大为整局平衡或性能验收。演示观感为 `pending_user_visual_confirmation`。此前 `electric_cards_regression` 的间歇超时缺口继续保留，本批未用新套件代替或宣称关闭。总目标仍为 active。
