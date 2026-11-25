# 自动防卫 · v0.2.6.1

2026-10-27用户要求：自动攻击射程内敌军单位，不默认主动攻击建筑。这里按目标类型区分，移动单位即步兵/载具等Unit，不要求目标正在行走；防御塔作为攻击方仍正常开火。

## 参考与当前策略

[Vinifera开发者文档](https://github.com/Vinifera-Developers/Vinifera/blob/develop/docs/New-Features-and-Enhancements.md)区分来自RA2的CanPassiveAquire和CanRetaliate，分别控制自动获取目标与还击。本地refs/ts-ra2的AttackTrait和TechnoRules只读用于行为对照：自动索敌检查武器、弹药、射程、可见性和威胁条件；原版并不是绝对排除所有建筑，武装建筑可能构成威胁。本次默认排除建筑是用户指定策略，不声称完全复刻原版目标筛选；未搬运参考实现。

## 实现合同

- 新建己方Unit以及order_stop恢复defend；敌军仍使用既有free。默认只在实际武器范围内选择敌方Unit，保留雾、对空/对地、最小射程和载具乘员规则。
- _automatic_target_allowed统一用于索敌、武器合法性、地面和飞行战斗入口；防止缓存建筑目标绕过默认过滤。原始CanPassiveAquire=false时不自行索敌，还击目标例外。
- 显式攻击和攻击移动沿用既有命令；建筑正在攻击己方时，可以在还击窗口内被还击。窗口结束后默认防卫不继续追打建筑。
- 不改Building索敌，不给矿车添加武器，不移除弹药飞机/航母禁止空闲自主出击的保护。OpenTopped原逻辑继承载具姿态，无需重复实现。
- defend/free/return/none四种姿态；G/警戒按钮现在是真实开关：全部已警戒时关闭并恢复defend；混合选择时统一开启free+固守。仅操作存活己方单位，无选择不操作。关闭不改变_deployed，旧移动/攻击命令不恢复。默认防卫不追击，普通移动命令不会被自动索敌改成追击。
- 存档继续保存字符串姿态，无schema或数据content hash变更。旧档return/none尊重原值；选中后S切回新默认，不对旧档静默迁移。

## 验证与后续

automatic_defense_regression覆盖两模式默认开火、静止敌军、射程外不追击、建筑过滤/手动攻击/反击到期、攻击移动、普通移动、原生禁索敌、四态切换、保存恢复、部署E1/GGI实际造成伤害、矿车/飞机/航母例外、防御塔开火。另跑尤复基线、智能选敌、弹药、存档及要塞乘员回归。具体报告和退出告警见VERIFICATION.md。

正式启动准备Ready；实际手感pending_user_visual_confirmation。本轮只改变自动索敌策略，v0.2.4.2的战役30逻辑帧/生产60等效帧合同保持。苏联和尤复式圆形生产进度仍未在本轮实施。未提交、推送或更新朋友包。


## v0.2.6.1 警戒开关修复

根因是HUD已使用toggle_mode，但Battle.guard_selected每次仍只调用order_guard，导致点击关闭后被真实状态立即重新点亮。现在Battle.guard_selection_state统一报告无选择/关闭/混合/全开；HUD和命令使用同一判断。order_guard原子命令本身仍保持单向开启，只有玩家G/按钮入口执行开关语义。停止S继续恢复自动防卫。

guard_toggle_regression通过SubViewport.push_input实际点击图标、按G和S验证；两模式34项，覆盖两种部署步兵、三单位混合选择、开关亮灭/提示、取消移动、停火切警戒、空选择。原baseline578项及自动防卫70项保持通过。当前速度规则见BATTLE_TIMING.md（v0.2.6，15逻辑帧）；上文v0.2.5历史时间描述不再是现行配置。画面高亮截图已查看，实际使用者体验仍pending_user_visual_confirmation。
