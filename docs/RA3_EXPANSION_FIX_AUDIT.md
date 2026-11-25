# 未来坦克／炮艇确认问题修复 · v0.5.7.1

2026-10-29。官方起义为最终规则，Upheaval仅查漏；保留RA2目标血量、跨代伤害映射、独立许可和Q/W/E布局。本轮只确认以下修复，不代表所有SAGE模块已完整移植。

## 来源与静态原程序证据

EA `CnC_Modding_Support/Uprising`提交`3aad8e412961ab543192ae70f8503dc8e178e095`：`Xml/EP1/Allied/Units/AlliedFutureTank.xml`、`AlliedGunshipAircraft.xml`、`Xml/EP1/GlobalData/Weapon_EP1.xml`、`Xml/GlobalData/AttributeModifier.xml`。

本机Steam起义1.1 `Data/ra3ep1_1.1.game` SHA256 `b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b`。只读静态反汇编，没有修改或注入游戏。复查入口`tools/ra3_mirage/audit_riot_cpu.py --game <game> --output <json>`，15项绑定／指令／常量检查；这不是执行原引擎的数值oracle。

- BeamSpecialAbilityUpdate名0xc341b4，vtable 0xc5bfa8→0x7a3d60，更新接口0xc5be48→0x7ff8b0→0x7f6b80。
- 0x7e0c80端点初始化：0x7e0ea5读取SweepDistance，0x7e0eb0乘0xbf82a8中的0.5；0x7e12b3开始交替左右端点；0x7e13db检查DIAGONAL_SWEEPING，从每条起点减、向终点加forward×halfSweep。0x772170按elapsedFrames/durationFrames线性插值。
- 0x7e0b60：DamageInterval为0跳过模数门控，逐LaserState取端点，每条记录调用一次武器。结合已确认的15Hz逻辑时钟，保持15次/束，未改成渲染帧率。

## 修复及验收点

| 问题 | 当前行为 |
|---|---|
| Q过宽、漏斜向交叉 | 40/2×1.5=30世界单位半跨度。来源(1200,1200)、目标(1500,1200)：起点(1470,1230)/(1470,1170)，中点都在目标，终点(1530,1170)/(1530,1230)。显示与伤害共用函数。 |
| 死亡后继续扫射 | 停止新增发射，仅排完已发出的延迟末端事件；独立中子球／已射炮弹不被错误取消。 |
| 停用时光束与伤害脱节 | 活跃显示跟随payload.age；停用暂停结算并隐藏双束，恢复不补打停用时间。payload结束后残余光晕继续淡出。 |
| 炮艇射界外／未对准开火 | 模拟保存实际yaw/pitch，骨骼读取同一状态。侧炮±45°、180°/秒；前枪俯仰20°/秒/-30°，侧炮180°/秒/-45°。Unit._weapon_aligned实际消费，不依赖有无渲染。 |
| 机枪视野不变 | 官方AttributeMod_HarbingerGunshipVision_GunMode VISION=76%；新兵750→570，英雄937.5→712.5。切换、晋升、读档按基础值重算；保留视野至少覆盖攻击范围的用户规则。 |
| 模式语音缺失 | AudioArrayVoice原事件：交战／受击选择、Q攻击、机枪攻击。受击3秒窗口沿用已有RA3适配，不声称是原CPU常量。 |
| Multisound随机丢口令 | 不再混成一个随机池；独立导出每层，层间同时播放、层内随机取样。无layers的其余音效仍走原路径。 |

新专项含独立端点golden、真实死亡／延迟命中、停用恢复、显示时钟、真实射界、视野／语音／军衔、快照恢复和实际双层播放。两份旧炮艇表现fixture改为推进模拟后检查骨骼，未删除断言；expansion开火fixture改为真实侧向目标，仍要求双炮、弹匣末发和友军溅射成立。

证据根`refs/ra3-expansion/bug-sweep/`，运行环境与最终计数见VERIFICATION.md。同期共享工程更新了v0.5.7光照／阴影，已保留并复查相关表现。最终视觉／听感为`pending_user_visual_confirmation`。

## 不计为完成的项目

原三个炮槽独立选敌／装填、炮艇BezierProjectile/FireStraightThenCurve、MetaImpact击飞、空中Dying→触地→Collapse及坠毁战斗部、完整地形深度/HDR仍有差距。目前双炮共享目标、直线炮弹、地面碎块适配保留。Q首尾调度相位、3D包围体、停用标志映射和移动目标的大步长碰撞也仍为Godot适配；不能凭本轮测试称作原引擎完全等价。未来坦克中子球的独立飞行阶段已在v0.5.7.3补接，原程序证据与剩余几何差距见[中子球对照](RA3_NEUTRON_FLIGHT.md)。

额外旧audio_regression总套件2004项有34失败：24项依赖旧九单位yr_覆盖／GI不覆盖假设，10项依赖旧重复建筑排队／资金门禁假设。当前GameData还叠加yr_unit_voices.json、building_audio.json，默认建筑不可预约也是已确认需求。没有改该套件或将其计为通过；本次未改voice_id优先级、尤复声音配置、建筑生产逻辑。
