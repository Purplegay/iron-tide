# 普通玩法第十四批：无畏级护航弹仓

2026-11-18。T16 已实现，累计 **22/24 张普通卡、16/16 项普通天赋**。剩余 C21 牵引弹头、C23 过载封条，以及历史电系专项超时的验收缺口；普通池目标继续 active。英雄、皮肤和版本由原会话维护，没有打包、提交或推送。

## 行为与接线

**护航弹仓**：无畏级每个导弹架正常补弹时长缩短 8/12/16/20%，每枚真实离架的原生 DMISL 导弹获得其当时最大耐久 30/45/60/80% 的独立护盾。抬架准备、抬升动画、双弹间隔及飞行规则不变。未离架无护盾；两枚分别生成、分别扣除；数值伤害先扣盾，溢出继续扣导弹耐久。护盾不回复，没有时间到期，也不会在读档或重复离架通知时补满。护盾耗尽仍可被击落，明确直接销毁弹体的原生行为不改变。

核心 `iron_tide/scripts/units/expansion_2_dread.gd`；`soviet_advanced.gd` 的完整弹架周期、抬架剩余时间及离架/被毁后补弹使用同一装填函数。只有真实 rack → boost 转换发放护盾，弹体保存独立标记；共享最终受伤入口吸收数值伤害。母舰死亡不撤销已有在途护盾，弹体易主不能继续使用旧阵营护盾；导弹命中和死亡仍走原生结算，没有新增破盾伤害。

舰体状态显示补弹与护盾比例，导弹显示剩余盾值并绘制护盾环/剩余量。四档演示展示未离架、分别获得盾、第一枚受损、第二枚不受影响及溢出伤害。真实天赋购买、升级、读档、新对局生效和“新！”标记接通。这是天赋被动，没有新增 W/Auto W。

## 验证

来源为共享 `C:/Users/admin/IronTide`、`codex/ra2-independent`，Godot 4.7.2，隔离 APPDATA/LOCALAPPDATA，服务、数据库及协议均为 none。根目录 `.validation/progression-expansion-2-gameplay-batch14-20261118/`；使用 `C:/Users/admin/AppData/Local/Programs/Python/Python312/python.exe <验证根>/run.py <suite>`，GPU 用 `run_gpu.py [suite]`，从未激活的私有桌面，0 截图。

| 套件 | 检查数 | 结果 |
| --- | ---: | --- |
| progression_expansion_2_dread_regression，headless | 117 | 通过 |
| progression_expansion_2_regression | 920 | 通过 |
| progression_new_regression | 66 | 通过 |
| final_damage_limit_regression | 124 | 通过 |
| progression_expansion_2_armor_regression | 321 | 通过 |
| soviet_completion_regression | 488 | 通过 |
| progression_expansion_2_demo_regression，GPU | 968 | 通过 |
| progression_expansion_2_dread_regression，GPU | 121 | 通过 |
| 合计 | **3125** | **0 失败** |

专项覆盖四档正常双弹及原始间隔、完整抬架时长、实际双架缩短补弹、精确护盾量、独立损耗、重复事件不回复、数值溢出、真实神盾导弹拦截击落、盾不改变原生地面爆炸、二进制快照中的受损盾/剩余装填/仍在架导弹、母舰死亡、弹体易主、在架被毁、经典/未解锁/V3 隔离，以及真实天赋解锁三级升级与新局消费。原生数值伤害先按现有规则整数取整，再扣可能含小数的护盾，溢出断言据此核对。关联回归保留 V3/天启上一批与苏军原生导弹行为。

GPU 两进程 50692、50744 均退出且返回 0；输入桌面前后 Default，`activated:false`。最终所列日志无 SCRIPT ERROR/ERROR/WARNING，本批验证进程已结束，摘要与源码 SHA256 保存于验证根。实际运行绘制已检查，视觉观感仍为 `pending_user_visual_confirmation`；没有把本批结果用于关闭旧电系超时缺口。
