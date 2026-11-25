# 三个 RA3 单位完整路径检查 · v0.5.7.5

2026-10-29。本轮修复条目为 v0.5.7.5；共享工程另一路死亡／逃生功能已将当前整包版本更新为 v0.5.8，保留该版本。范围为幻影坦克 `R3MIRAGE`、未来坦克 `R3FUTURE`、先锋炮艇 `R3HARBINGER`。检查从生产、单位初始化、命令和移动，经过瞄准、开火、投射物、伤害、晋升、技能、表现，到死亡与存档。不是只按用户截图修改特效，也不是对全部 SAGE 模块已经完成移植的声明。

## 权威来源与保留规则

- 官方 EA Uprising XML：`refs/ea-modding-support/Uprising/Xml`，源提交 `3aad8e412961ab543192ae70f8503dc8e178e095`。主文件分别为 `Allied/Units/AlliedAntiVehicleVehicleTech3.xml`、`EP1/Allied/Units/AlliedFutureTank.xml`、`EP1/Allied/Units/AlliedGunshipAircraft.xml`；继续追踪 BaseObject／BaseVehicle、Weapon、Armor、ExperienceLevels、AttributeModifier、FX、粒子及关联道具。
- 原程序绑定：本机 Steam 起义 1.1 `Data/ra3ep1_1.1.game`，SHA256 `b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b`。绑定检查证明指定字段／算术，不代表完整运行原引擎。
- Upheaval 只查遗漏，不覆盖官方数值。保留已确认的跨代伤害适配、原生秒制和作战实验室兼防卫局。粒子 30 FPS、已确认的伤害 CPU 15 Hz 与 Godot 渲染频率是不同概念。

## 本轮发现与修改

1. **未来坦克漏掉原生基础回血。** 两个起义单位都声明 `Upgrade_PassiveHeal`：出生后 1 秒起，每 0.5 秒恢复 2，战斗中也有效。运行端原先只给炮艇调用。现在从各单位 XML 导出这个模块，由同一运行消费者处理；与 BaseVehicle 英雄回血 3 独立叠加。未来坦克／炮艇英雄每轮共 5，幻影英雄仍为 3。保留各自计时并经真实快照恢复。修前独立复现 31 项中 6 项失败，修后通过。
2. **RA3 经验栏军衔名称错误。** 原来英雄顶级仍显示“精英”，精英下一阶段也写“精英”。现在消费实际军衔名称，下一阶段显示“英雄”。三个 RA3 单位四级军衔、RA2 最高精英均验证。
3. **幻影测试误计阴影网格。** 新增阴影副本网格后，旧测试把它们计入车身数量，产生 5 项误报。测试改为识别实际可见层的两块车身，同时断言局部变换、骨架和 skin，不删减车身／履带一致朝向要求。
4. **致死光束测试场景串扰。** 电厂死亡新增的逃生步兵留在后续散射靶场，造成额外光束／端点断言失败；现在在用例之间清理前一场景的单位，不禁止游戏里的逃生或散射，不削减数量／端点断言。
5. **炮口未随军衔变色不是漏接依据。** 官方未来坦克主炮的 `FireFX` 与 `FireVeteranFX` 相同，英雄武器继承相同开火事件，双炮充能仍用 `EXFutureTankCharge`。英雄变体在飞行球和命中节点；本轮不擅自给炮口换色，也不提高攻击伤害。

## 来源、消费者、覆盖与差距

路径以下以 `iron_tide/scripts` 为运行代码根；专项名称对应 `iron_tide/tests/<名称>.tscn`。每项同时阅读相应源文件及消费者，自动检查仅覆盖列出的可执行断言。

| 系统 | 官方作用／条件 | 当前消费者 | 本轮运行覆盖 | 边界／缺口 |
| --- | --- | --- | --- | --- |
| 三单位生产与许可 | BuildCost／BuildTime、建造对象、RA3 T2/T3 | `rules/ra3_clearance.gd`、生产科技及工厂、两套单位数据 | `ra3_expansion`、`ra3_uprising`、`production_hold`、源契约 | 保留实验室兼防卫局的用户定制；不是双原版完整科技树 |
| 三单位属性与晋升 | Armor、ExperienceLevels、AttributeModifier、BaseVehicle | `units/unit.gd`、`ra3_mirage.gd`、`ra3_expansion.gd`、HUD | `ra3_rank`、`rank_icon`、`neutron_natural_rank`、`lifecycle_audit`、`veterancy` | 本轮修回血及军衔文字；不改已确认跨代伤害 |
| 幻影移动、炮塔、骨骼与履带 | Locomotor、W3D Draw、炮口与状态 | `ra3_unit_model.gd`、`ra3_bone_animation.gd`、`unit.gd` | `ra3_mirage`、`mirage_conditions`、`sdk_timing` | 悬挂／侧滑不是原 SAGE 完整实现；部分附加 FX 网格未接 |
| 幻影攻击与散射 | 主炮及 CannonNodeRegular/Veteran 链，英雄武器 | `ra3_mirage.gd`、`ra3_weapon_fx.gd`、`ra3_mirage_damage.gd` | `ra3_presentation`、`lethal_beam`、`damage_adapter`、`firing_cycle_audit` | 已有首层散射；英雄第二跳仍缺，详见下表 |
| 幻影伪装与幻影场 | Disguise、Stealth、ModelCondition／AnimationState | `ra3_cloak_visual.gd`、`ra3_mirage_fx.gd`、`ra3_unit_model.gd` | `ra3_cloak`、`field_gradient`、`mirage_conditions` | 静态树替代原环境匹配；场与受损等组合状态未完整复刻 |
| 未来坦克移动及动画 | Locomotor、JUST_BUILT、PREATTACK、炮组展开／收起 | `ra3_future_state.gd`、`ra3_future_draw.gd`、`ra3_expansion_model.gd` | `ra3_future_presentation`、`native`、`sdk_timing` | 现有明确的倒播适配保留，不当作所有原状态优先级已还原 |
| 未来坦克主炮 | Weapon_EP1、飞行 projectile、普通／英雄 neutron node | `ra3_neutron_flight.gd`、`ra3_neutron_projectile.gd`、`ra3_neutron.gd` | `ra3_neutron_flight`、`visibility`、`natural_rank`、`firing_cycle_audit` | 固定接触查询、英雄倍率、飞行无伤害及节点结束均覆盖；复杂地形／引擎空间分区仍适配 |
| 未来坦克 Q | BeamSpecialAbilityUpdate、LaserSweepWeapon、原粒子／Laser 材质 | `ra3_riot.gd`、`ra3_future_beam.gd`、`ra3_future_particles.gd` | `ra3_riot`、`future_presentation`、`future_glow`、`fx_contract` | 接近、取消、准备、扫掠、CD 与中途存档覆盖；全场景 3D 深度及 HDR 不完整 |
| 炮艇飞行及瞄准 | FixedWingLocomotor、盘旋、三个炮位朝向边界 | `ra3_gunship_flight.gd`、`ra3_gunship_aim.gd` | `ra3_gunship_flight`、`range`、`sdk_timing` | Godot 平面导航与显式瞄准容差，不等于 SAGE 飞行物理 |
| 炮艇两种武器 | 侧炮、前机枪、切换、弹匣、装填、武器姿态与音效 | `ra3_expansion.gd`、`ra3_gunship_tracer.gd`、`ra3_gunship_bullet_hit.gd` | `ra3_gunship_weapons`、`firing_cycle_audit`、`expansion_fix` | 两种模式独立弹匣已有；左右炮独立目标／弹匣及原抛射曲线仍缺 |
| 炮艇质子炮表现 | FXList、ParticleSystem、纹理与材质 | `ra3_gunship_impact.gd`、`ra3_gunship_material.gd`、`ra3_fx_resolution.gd` | `ra3_gunship_presentation`、`weapons`、`fx_contract` | 像素与范围回归不证明任意缩放下与原作逐像素一致 |
| 三单位受损、语音、残骸 | DamageStates、AudioEvent、COL 模型、SlowDeathBehavior | `ra3_damage_state.gd`、音效包、`ra3_wreck.gd`、死亡入口 | `ra3_native`、`wreck_random`、`wreck_scatter`、源契约 | 炮艇坠地前 DYING 和坠毁伤害缺失；音频存在不证明完整 SAGE 混音 |
| 存档与共用战斗入口 | 当前单位状态、技能游标、弹药、军衔、回血时钟 | `save/battle_snapshot.gd`、`snapshot_schema.gd`、`unit.gd` | `savegame`、`ra3_lifecycle_audit`、`riot`、`gm_ra3_damage` | 在本地隔离存档验证；未改玩家存档，也不是联机同步验收 |

## 初次审计发现的差距（v0.5.7.5历史状态）

**v0.5.9.1已实施后续补齐**：下表是当时发现的缺口，不是当前全部未实现清单。英雄第二跳、附加模型FX、伪装变体和退出过渡、炮艇独立炮位、曲线飞行、空中坠毁伤害和MetaImpact现已接入；来源、实际覆盖及保留的CPU／物理／表现差异见[差距补齐记录](RA3_COMPLETION.md)。

这些是主动从源码对照发现的待移植差距；本轮未伪造实现或用测试通过掩盖。

| 单位 | 缺口与原版依据 | 当前行为 |
| --- | --- | --- |
| 幻影 | CannonNodeVeteran1 → Veteran2 → End，英雄还有二次散射 | 首层普通 5／英雄 7，未继续英雄第二层 3 个目标 |
| 幻影 | Draw 的 LIGHTNINGFX／GLOWFX／PLASMAFX 等附加网格 | 车身双网格与单独武器特效已接，附加模型 FX 未完整导入；OBBOX 是碰撞信息，不应当可见网格 |
| 幻影 | 环境相关伪装选择、完整组合状态／TRANS_FromField | 固定树、局部状态优先级；无完整昼夜车灯系统 |
| 炮艇 | 三个 WeaponSlotTurret 的独立目标与装填 | 两个侧炮共用目标及一份侧炮弹匣；前机枪模式独立 |
| 炮艇 | `AlliedGunshipAircraftWeaponProjectile.xml` 的 BezierProjectile、FIRE_STRAIGHT_THEN_CURVE、FireStraightDistance=400、FlightPathAdjustDistPerSecond=300、Indent=30/60 | 当前普通炮弹为直线位置插值，尚未复刻原分段曲线 |
| 炮艇 | SlowDeathBehavior 的 DYING → 触地 → COLLAPSE 与坠毁 warhead | 当前死亡直接进入地面分块残骸；缺空中坠毁与坠地伤害 |
| 炮艇 | MetaImpact 的冲击／击退 | 当前伤害和视觉冲击已接，原物理推力未接 |
| 共用 | 地形深度、完整碰撞／空间分区、HDR、悬挂；继承的其他 RA3 状态模块 | 混合 2D/3D 的 Godot 适配。没有相应游戏系统的原模块不能因为 XML 声明存在就称已还原 |

## 验证方法与证据

证据根：`refs/ra3-expansion/three-unit-audit/`。缓存中的完整日志、PNG、result.json 和审计指纹不提交。官方声明检查器源码保留为 `tools/ra3_mirage/audit_unit_contracts.py`，导出每个单位的父级模块顺序、属性和来源哈希；不宣称它是完整的 SAGE 继承／默认值解析器。

新增 `ra3_firing_cycle_audit_regression`：三个单位、炮艇两种武器、新兵／英雄、15／60／120 Hz，共 432 项。实际调用开火准备入口、预攻击等待及装填消费者，跨过完整弹匣；为隔离射速，生成的弹体随即清理，伤害由独立专项验证。新增 `ra3_lifecycle_audit_regression`：真实 Unit tick、独立回血时钟、快照恢复、真实 HUD，共 44 项。不是以测试重新手写一套规则替代运行消费者。

环境：Godot 4.7.2 Compatibility、WASAPI，隔离项目 `refs/ra3-mirage/integration-test/project` 的 junction 消费当前工程；独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`。网络、数据库、服务器端口均 none。用户游戏进程未停止，真实存档未改动。

初轮基线 1608 项中 5 项失败，定位为上述幻影阴影网格误计。此后曾有并发工作新增 RA2 死亡资源，导致隔离项目缺失导入；带资源错误或源码指纹漂移的中间批次不作为最终验收。最终批次在补齐隔离导入后执行，并核对前后源码／资源指纹。最终统计另见验证记录。

最终 `closure/audit.json` 共34套、2084项，零失败、零错误／泄漏、全部退出0。期间仅另一项工作的`building_rubble.gd`发生变化；其调用受LeaveRubble建筑及已有废墟记录限制，本轮不包含这些目标与记录，已核对排除。相关RA3代码／数据／测试及其余已登记消费者保持一致。完整环境和中间失败处理见[验证记录](VERIFICATION.md)。

独立来源检查：`source/contracts.json` 为 245 项配置／媒体存在性检查；neutron_cpu、neutron_flight、riot_cpu、particle_range_cpu 共 36 项原程序绑定检查。`source/laser/audit.json` 运行截取的原 CPU 算术，35 组输入／1120 项比较，最大绝对误差约 0.00000421；没有运行原游戏更新循环、相机或 GPU，不据此宣称全场景激光一致。

额外性能采样 `performance/run.log`：固定三辆混编车、1600 条履带痕迹，每阶段 240 帧，舍弃前 30 帧。静止帧时间中位 4.122 ms／P95 6.533 ms，移动 3.770／6.256 ms，隐藏痕迹移动 3.877／6.158 ms；本机该专项没有重现“移动明显更卡”。这三个记录是测量，不是带阈值的性能验收，也不代表大规模战斗、其他机器或后台负载。

图形检查覆盖实际战场截图中的双炮充能、英雄飞行球、质子炮爆点、幻影朝向与军衔 UI；它与数值／代码断言是不同证据。三单位的现有实现回归通过，不代表以上缺口已补齐，也不宣称全部原作表现逐像素相同。
