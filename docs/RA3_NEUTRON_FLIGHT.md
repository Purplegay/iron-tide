# 未来坦克 X-1 中子弹体 · v0.5.7.3

2026-10-29。此前 `make_shot(neutron)` 后直接调用节点伤害并把位置设为目标，漏了独立的飞行 GameObject。当前先发射原 `FXFutureProjectile02`，到达后才创建原中子节点表现并启动节点时钟。用户视觉验收状态：`pending_user_visual_confirmation`。

## 权威、继承与消费

EA Uprising XML 仓版本 `3aad8e412961ab543192ae70f8503dc8e178e095`；原程序为本机起义 `ra3ep1_1.1.game`，SHA256 `b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b`。没有用 Upheaval 修改值代替官方值。

| 来源与调用链 | 本次消费 | 验证／保留边界 |
| --- | --- | --- |
| `Weapon_EP1.xml / AlliedFutureTankNeutronScrambler` → `AlliedFutureTankNeutronWeaponProjectile` → Warhead → OCL → NeutronScramblerNode | `ra3_expansion.gd` 创建 flight 阶段；到达后切 node，原 `ra3_neutron.gd` 继续处理节点伤害 | 路上不启动节点伤害；命中一次；大步长余时交给节点。原装填、攻击范围、跨代伤害不变。 |
| `BaseProjectile.xml` → 普通弹体，移除 `NO_COLLIDE`；模型 `FXFutureProjectile02`、附着 `AlliedFutureTankProjLight` | 新 `ra3_neutron_projectile.gd` 使用已提取的原网格、纹理、材质和灯光数据 | 不绘制自制轨迹线／尾焰。Godot 独立视口灯光不能照亮其它单位；完整原生碰撞仍有差距。 |
| `BezierProjectile`: 高度 5/0，33%/66% 控制点，300 以内按距离压平，路径调整 20/s，加速度 5 | `ra3_neutron_flight.gd`：炮口起点、浅三次曲线、按弧长移动、限制移动目标末端调整 | 1.5 世界单位换算；32 段曲线采样、平面地形、目标位置／包围体接触点为 Godot 适配。不是 SAGE 全模块复刻。 |
| `AlliedFutureTank.xml`: `Upgrade_Veterancy_HEROIC` → `WEAPON_UPGRADED_02` → Vet weapon/projectile/warhead/node | 开火时冻结 `heroic`；普通／老兵／精英使用蓝紫弹体，英雄使用红粉弹体，命中节点也选择 Vet 原资源 | 原版阈值是英雄（rank 3），不是精英（rank 2）。飞行和命中实际像素差异通过检查。 |
| Vet 的 `ScriptedModelDraw` 与 `BezierProjectile` 均为 `xai:joinAction="Replace"` | Vet 使用 `FXFutureProjectile02_Vet`，不继承普通附着灯光；普通朝向飞行切线，Vet 保留自身方向 | Vet 省略 Flags 后为 schema 默认 `PING_PONG_SIDEWAYS_DRIFT`，不是继承普通的 `ORIENT_TO_FLIGHT_PATH DETONATE_CALLS_KILL`。未配置漂移量，不额外造蛇形轨迹。 |
| Node：独立 6s Lifetime；原有展开与19次范围查询 | 到达时将 node `age` 从0开始；飞行时间不挤占节点表现／伤害寿命 | 节点原有可见时钟、停伤时刻保持；目标先阵亡仍显示已发射弹体。 |

## 原程序速度证据

`audit_neutron_flight.py` 验证文件 SHA、类名字／构造器／虚表绑定和关键机器码，输出忽略目录 `refs/ra3-expansion/neutron-flight/native-audit.json`，不分发游戏程序。

- `0x7cdc20–0x7cdc44`：非零加速度时运行速度置0，否则取武器速度。
- `0x717a21–0x717a4e`：先把旧速度加入累计距离，再把模块加速度加入速度。
- `0x717a4e–0x717ba9`：沿已采样路径累计段长并插值。另有速度超过原生段长后的钳制分支；本次不把 Godot 32段几何采样当作原生分段表。
- `0x7b32e2–0x7b33d8`：短距离压平比例，高度以路径地面最高点与起终点最高值为基准。
- 原程序逻辑频率15Hz来自已验证常量 `0xccce90`；与 Godot 显示帧率独立。5 是每逻辑帧的速度增量，不能把999999武器最大速度用作每次瞬移距离，也不能另拍一个视觉速度。

原生完整调度首帧相位、地形最高点采样、碰撞／桥梁、模型包围体、移动目标接触点、HDR／跨对象照明没有因此获得完全等价证明。上述静态反汇编证据不是原引擎实机对照。

## 状态、存档与验证

新字段放入既有 projectile `splinters`：阶段、飞行时间／逻辑帧／速度／距离、地面起点／高度／终点／朝向。存档恢复使用真实 `battle_snapshot`，不保存视觉节点。旧存档没有阶段字段时继续作为原有 node，不从炮口重飞、不回放历史伤害。

新增 `ra3_neutron_flight_regression` 覆盖：零速起步、实际路上位置、曲线高度、到达前无伤害、完整伤害不变、飞行存读档、60Hz/15Hz/大步长追赶、移动目标、死亡目标、四种军衔模型／实际像素、旧节点兼容。已有节点／军衔／表现测试改为先通过真实飞行阶段到达，再核对原断言；没有删减原伤害预期来适应失败。

实际结果与命令见 [VERIFICATION](VERIFICATION.md)。证据根 `refs/ra3-expansion/neutron-flight/`；生产工程源码与资源由隔离验证工程 junction 读取，独立 `.godot` 与 `CodexIronTideValidation/ra3-mirage-20261027` 用户目录，不触碰玩家存档／进程。最终手感、颜色和原版画面相似度仍需用户复测。
