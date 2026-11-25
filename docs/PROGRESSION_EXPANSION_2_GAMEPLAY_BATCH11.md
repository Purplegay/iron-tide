# 普通玩法第十一批：弹着校射、伴行维修

2026-11-18。本批实现 C16、C18，累计 **18/24 张普通卡、14/16 项普通天赋**，剩余 6 张卡、2 项天赋。英雄、皮肤、版本信息仍由原会话负责。本批没有打包、提交或推送。

## 玩法与边界

- **C16 弹着校射**：武装直升机 SCHP 史诗被动。普通部署炮直击敌人后，整枚炮弹伤害结算完成才生成半径 1.5 格、4 秒校射区，首炮不吃自己新建的区域。友方已部署直升机对区内目标的普通炮及部署炮技能伤害 +8/12/16/20%；可与传说 W「震地锚」同装，真实震地脉冲享受一份加成。起飞或收拢后不生成、不享受；已经形成的区域按固定寿命继续存在，不揭雾。每架生成间隔 6 秒，最多一个区。重叠只取同方最高值，每个区独立到期；强区结束、弱区仍在时恢复较低值，不合并时长、不刷新其它区。
- **C18 伴行维修**：灰熊 MTNK、犀牛 HTNK、多功能车 FV、防空履带车 HTK 稀有被动。自身和 2 格内至少一辆友方真实战斗地面载具连续实际同行 3 秒后，自身每秒恢复最大生命 0.5/0.7/0.9/1.1%，最多 3 秒，触发间隔 18 秒。只有移动命令、原地转向、同伴不动不计同行；停车、同伴离开或受到实际敌伤结束。矿车、镜像、步兵、空中或海军单位不计同伴。不会给同伴回血，生命不超过上限；易主清旧状态。
- 两者为被动，不新增 W 按钮或 Auto W 规则。已有震地锚的施放入口保持。数据范围、稀有度、四档描述、真实抽取/装配/存档、“新！”标记、效果图标及演示均已接入。

## 实现位置

- `iron_tide/scripts/units/expansion_2_calibration.gd`：部署形态判断、炮弹快照、伤害结算最高区域加成、弹后生成、独立区域计时和世界提示。
- `iron_tide/scripts/units/expansion_2_convoy.gd`：双方实际位移采样、邻域同伴判断、连续同行计时、自疗及受伤中断。
- `progression_expansion.gd`、`progression_expansion_2.gd`：真实开火/伤害/计时/状态；`projectile.gd` 在完整弹着伤害结算之后创建区域；`expansion_cards.gd` 与 `expansion_field_visual.gd` 复用已有世界区域入口。
- `data/progression_expansion_2.json`、`ui/expansion_2_demo.gd`、`ui/progression_icon.gd`：卡池数据、四档演示和图标。普通池回归的非法装配测试根据实际卡牌范围选择反例，保留负向断言。

## 验证

当前共享源码 `C:/Users/admin/IronTide`，分支 `codex/ra2-independent`。隔离 APPDATA/LOCALAPPDATA，使用 Godot 4.7.2 直接 headless；无服务、数据库、协议依赖。GPU 在从未激活的私有 Windows 桌面运行，0 截图。验证根 `.validation/progression-expansion-2-gameplay-batch11-20261118/`；运行 `C:/Users/admin/AppData/Local/Programs/Python/Python312/python.exe <验证根>/run.py <suite>`，演示入口 `run_gpu.py`。

| 套件 | 检查数 | 结果 |
| --- | ---: | --- |
| progression_expansion_2_support_regression | 206 | 通过 |
| progression_expansion_2_regression | 807 | 通过 |
| progression_new_regression | 59 | 通过 |
| final_damage_limit_regression | 124 | 通过 |
| progression_expansion_2_demo_regression，隔离 GPU | 796 | 通过 |
| 合计 | **1992** | **0 失败** |

专项覆盖真实部署炮首击及后续伤害、未装卡友军受益、真实震地锚装配和脉冲、起飞/收拢、半径外、不同阵营、强弱区独立到期、在途炮弹及世界区域读档、6 秒生成间隔、死亡后区域固定寿命；四兵种四档自疗、实际同行、原地转向和仅有命令、同伴静止/离开/非法类型、敌伤与友伤、生命上限、3 秒结束、18 秒再触发、准备中及治疗中快照、引用恢复和易主、经典模式隔离。最初专项中的第二架直升机落点被原生部署占地阻挡，已改用合法测试位置；步兵排除测试改为实际角色数据，不再只替换单位 ID。原断言保留，最终专项全部通过。

最终所列五套件日志无 SCRIPT ERROR、ERROR、WARNING。GPU 返回 0，`activated:false`，输入桌面前后均 Default，PID 21720 已退出；本轮 headless 已结束，未停止他人进程。最终摘要与源码 SHA256 在验证根。演示观感仍为 `pending_user_visual_confirmation`。

剩余 C04、C06、C20、C21、C22、C23，以及 T06、T16 继续实施。旧电系回归超时缺口仍未关闭，不以本批替代；完整普通池目标保持 active。
