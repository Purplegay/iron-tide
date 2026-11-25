# 未来坦克／先锋炮艇：Upheaval 全目录对照与运行差距

**v0.5.7.1更新**：Q原程序半跨度／斜向交叉、死亡与停用、炮艇实际开火射界、76%模式视野、模式与状态语音及Multisound已修，见[本轮证据](RA3_EXPANSION_FIX_AUDIT.md)。下面旧基线中对应的“未应用／未路由／CPU待查”已被该记录取代；独立炮槽、Bezier和坠毁链等未完成项仍保留。

2026-10-28，诊断基线 v0.5.6.2；后续修订 v0.5.6.3。**不是完成全量移植声明。** 用户已选择官方《起义》为最终规则，Upheaval 只用于查漏。下方基线差距保留，最新修订及证据见下一节。

## v0.5.6.3：规则来源确认与实际修订

用户确认继续采用官方起义，保留跨代伤害适配。没有采用Upheaval的1.5秒节点、UNRESISTABLE、2.4秒预充能／3.6秒装填或机枪400射程。

### 中子球零售CPU证据

本机 Steam Uprising 1.1 `Data/ra3ep1_1.1.game` SHA256 `b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b`。只读静态反汇编，没有修改／注入游戏进程；可重查入口：`tools/ra3_mirage/audit_neutron_cpu.py --game <game> --output <report.json>`。

- `0x7a8260`构造函数绑定`0xc5f130`虚表，名称函数`0x7a83c0`返回`DamageSphereUpdate`，更新虚表入口指向`0x7e2b70`。
- 原程序逻辑频率常量`0xccce90=15`；`0xbc5580`将它转换到秒转帧因子`0xcf8bb8`。这不是借用YR的15帧假设，也不等同于渲染／动画FPS。此前30Hz伤害适配不准确。
- 构造函数将`ExpansionPerSecond`除以逻辑频率；启动延迟按`UnpackTime`转整帧。`0x778b60`激活时设置RadiusMin与阶段状态。
- `0x7e2b70`先按当前半径查询对象，对每个目标提交IncrementalWeapon，再调用`0x7c55b0`。后者调用`0x7100e0`加半径、钳制到RadiusMax；到顶返回`sleep forever`，否则返回一帧。因此**不是每.25秒持续6秒，也不是扩散环只命中每目标一次**。
- 分区查询mode3的回调`0xb19240`使用XYZ距离及目标包围球。允许接触空中目标有实际CPU路径支持，不能把AI的空军免躲避标记当作伤害过滤。
- 代码将上述半径更新顺序转为19次固定逻辑查询（25→175，下一步钳制180后停止）；保留6秒节点清理寿命。展开前的FireWeaponUpdate点伤害与展开查询分开，补0.1直接命中；可序列化游标追赶跨帧事件。

静态证据检查包含8个SHA／绑定／常量断言；**不是运行原指令的数值oracle，也未启动原游戏做逐帧对照**。Godot的碰撞圆／建筑占地与SAGE包围球不同；目标移动跨大时间步时只拥有当前坐标，首次FireWeapon调度相位仍是适配。粒子XML的30帧表现采样未因逻辑常量更改；粒子实际CPU时钟和末尾数帧的表现／伤害对齐仍需另核，不把“第3秒后无伤害”扩大为逐帧视觉完全一致。

Q在DamageInterval=0时改用15Hz；双束轨迹、BeamSpecialAbility内部完整调度仍按既有Godot适配标记。旧30Hz存档游标按已消费事件时间换算，不重放已结算伤害。没有统一改变移动、建造或动画速度。

### 军衔与炮艇

对照`GlobalData/ExperienceLevels.xml`的Rank2/3/4继承及`AttributeModifier.xml`：老兵DAMAGE_MULT125%、精英HEALTH_MULT125%、英雄RANGE/VISION/SHROUD_CLEARING125%、RATE_OF_FIRE120%。三单位实际伤害链保留继承；幻影英雄还换250伤害主炮。英雄免贿赂／压制等状态未因此自动视为已接。

实际新兵／老兵／精英／英雄对同一原生未来坦克靶标，幻影单发伤害为200／250／250／312.5，炮艇双炮中心命中250／312.5／312.5／312.5。未来坦克同一时段命中按1／1.25／1.25／1.25比例；不把这段采样称作整颗球总伤害。

炮艇`Upgrade_PassiveHeal`独立于继承的`Upgrade_HeroicHeal`：新兵即有1秒启动、每.5秒2点回血；英雄再叠加同周期3点回血。补入原先遗漏的被动模块，计时随存档保留。两武器模式保存弹匣计数及剩余冷却，切换不免费补弹；双侧炮当前仍同步发射，独立炮槽选择不同目标的原AI未完整移植。

炮台恢复官方180°/秒；前机枪20°/秒俯仰/-30°，侧炮180°/秒俯仰/-45°及±45°转向限角。原版三维炮槽射界与盘旋AI完整耦合仍为缺口；不能仅凭炮台视觉检查称为完整武器AI。

## 范围与可复查来源

- Bibber [Upheaval 1.16 源码](https://bibber.eu/downloads/ra3-upheaval-source-code/)，包 SHA256 `8bb4cea9d15d8c00f153b169b64de292873038a602e65fd5451306aa1825588f`。
- EA `CnC_Modding_Support` 的 Uprising，提交 `3aad8e412961ab543192ae70f8503dc8e178e095`。
- 扫描 `Upheaval/Data/Mod/Units/Future Tank X-1/` 和 `Harbinger Gunship/` **全部 45 份 XML**，包括仅含 Includes 的 W3X 引用文件。未来坦克 228、炮艇 181，共 **409 个根声明**。不是只抽查 WeaponTemplate。
- `tools/ra3_mirage/audit_upheaval_units.py --output refs/ra3-expansion/full-audit/xml-diff.json` 可重建逐属性／子节点对照。输入只读，不执行 MOD 构建脚本。
- 原始结构比较：131 个声明有完全相同的 EA 候选，35 个存在结构差异，243 个没有同 ID 的 EA XML 声明。最后一类主要包含 AudioFile、Texture、视频等，并不等于“缺失 243 项运行资源”。继承展开、宏求值、等价数字文本也会造成原始结构差异，不能把原始差异数当成 Bug 数。
- EA 全目录有三份非目标文件不能由标准 XML parser 解析：`Includes/GarrisonableStructureBehaviors.xml`、`Templates/Structure.xml`、`Civilian/Mykonos_MY/Buildings/MY_Boat_01b.xml`。错误保留在报告，不伪装全目录无错误。目标单位／武器／粒子文件成功解析。
- 同 ID 的 Yuriko overrides、旧武器覆写全部保留为候选。下文语义比较使用 `EP1/Allied/Units`、`EP1/Allied/Props`、`EP1/GlobalData` 的完整定义，不把覆盖片段当成完整单位。

## 首要问题：球已经消失，但伤害仍继续

真实消费链：`Unit._fire_shot → Ra3Expansion.shoot/make_shot → tick_shot(neutron)`；表现为 `ra3_future_particles.gd`。

当前实现把 `state.pulse += 0.25` 用在整个 6 秒节点寿命内，对当前半径内所有敌人反复伤害；半径在 1.35 秒后扩到 180 原单位。表现却按粒子 `InitialDelay=35帧 + Lifetime=40帧` 在 2.5 秒结束。代码还明确关掉了结束后的表现 viewport，因此不是截图偶然漏帧。

新增回归 `tests/ra3_neutron_visibility_regression.tscn` 使用实际 Battle、Future Unit、Projectile、伤害路径：让敌方未来坦克在球结束后第3秒进入中心，第4秒生命 **3000 → 2990**。2项检查中1项预期失败，退出1；球消失成立、无隐形残留伤害不成立。证据 `refs/ra3-expansion/full-audit/neutron-before/{result.json,run.log}`。这份失败不能写成通过。

### 两套原始伤害链并不相同

| 环节 | 官方起义 | Upheaval 1.16 | 当前实现问题 |
| --- | --- | --- | --- |
| 初次战斗部 | 0.1 NEUTRON＋创建节点 | 0.1 UNRESISTABLE＋创建节点 | 微量直接命中未单独消费；把节点立即放在目标地面位置 |
| 节点寿命 | LifetimeUpdate=6s | LifetimeUpdate=1.5s | 固定6s混入表现2.5s，且延续范围脉冲 |
| 展开前 | FireInterval=.25s，仅 Required WEAPON_UPGRADED_01 / Forbidden WEAPON_UPGRADED_02 | OneShot DOT：10伤害、.25s间隔、1.35s持续 | 当前没有阶段／状态门控，整6秒重复 |
| 展开阶段 | DamageSphereUpdate：1.35s展开、25→180、125/s；调用 IncrementalWeapon | 每.25s发 IncrementalWeapon；每发延迟1.35s，20伤害、Radius150、DamageSpeed100 | 当前既没有原版独立 DamageSphere 状态，也没有 Upheaval 延迟波事件队列 |
| 非步兵／友方 | 非步兵25%；武器声明同时有关系过滤与友方50%标量，需按入口解析 | 非步兵25%、友方50%；默认关系须解析继承/schema | 当前直接排除同阵营，不能声称是 Upheaval 完整关系行为 |
| 表现 | Node 35帧；展开延迟35帧、存活40帧 | 这些粒子基本相同，战斗链却改写 | 不应拿球粒子寿命替代整条伤害状态机，也不能再无条件沿用6秒范围DOT |

**修复不能只把6改成1.5或2.5。** Upheaval 的节点销毁不必等同于已调度延迟伤害全部取消；官方的节点6秒也不证明对圈内目标每.25秒重打。需要选定规则，然后让伤害事件／表现阶段共享明确时序，并覆盖晚进入、低FPS跨事件、击杀、读档和退出清理。

## 未来坦克全部模块对照

| 文件／模块 | 已接入或保留 | 差异／遗漏／边界 |
| --- | --- | --- |
| GameObject：生产、Body、Geometry、KindOf | 原生命3000、价格／时间、模型尺寸、地面分类；T3许可＋作战实验室兼防卫局为用户确认适配 | 跨游戏碰撞／单位标签并非SAGE完整KindOf解释器 |
| WeaponTemplate：普攻 | 两炮口、原声／粒子、250原射程、每3秒射击；官方PER_TARGET .1s预延迟 | Upheaval为PER_CLIP 2.4s、Clip2、FiringDuration0、Reload3.6s、PER_SHOT重选；当前没有该弹匣时序。缩小单位散布和被铁锤吸取的Leech变体未接 |
| WeaponTemplate：战斗部、OneShot、Incremental | 原NEUTRON跨代血量映射 | 首要问题见上；Upheaval改UNRESISTABLE，不能沿用仅NEUTRON的护甲键后宣称一致 |
| SpecialPowerTemplate／GameObject：Q | 距离250、15秒CD、超距接近、双束、展开／收起、读档 | 当前官方BeamSpecialAbilityUpdate：展开最少.5秒、选择时间抵扣；Upheaval是WeaponFireSpecialAbilityUpdate固定1秒展开、1秒Busy、1秒Pack＋SweepingLaserState |
| WeaponTemplate：Q命中 | 沿线25／宽5，末端50／半径5／延迟.1秒，非步兵30%，两种事件分开 | 连续30Hz调用、地面交叉端点是Godot适配；Upheaval同样未提供原引擎Sweep CPU。光束结束后的末端延迟事件与普攻的隐形范围DOT不是同一个问题 |
| GameObject：动画／ScriptedModelDraw | AIDA/BIDA、选择/取消、BATB正反播、移动、ATKE/F、预备ATKG、出厂XMOVA、骨骼炮口、充能模型 | 有些状态由手写分类选择，未执行原Lua条件解释器；Upheaval普攻装填改变会同时改变动画窗口，不能只换伤害 |
| FXList／FXParticleSystemTemplate | 发射灯、10初始球、普通／英雄光晕与展开，原纹理、材质、几何 | 生命周期脱节；EmitterSound、骨骼SphereSizeMultiplier与CPU积分并未形成统一伤害/表现时钟；地形深度、完整HDR待核 |
| Armor | 官方BaseAdvancedTankArmor解析为已有原伤害类型倍率 | Upheaval改为显式Armor列表；缺NEUTRON键不等于完全免疫，需继承/default解析。侧／后甲倍率及YR来袭伤害类型桥接不是完整RA3装甲系统 |
| ExperienceLevelTemplate | 四档经验门槛、经验奖励、英雄标识、加攻/生命/射程/射速/回血 | 不沿用YR移速提升；原Rank属性宏仍需与最终来源一起复核，而非只看经验门槛相同 |
| Locomotor | 原速度、加速、受损75%、转向、连续移动 | 悬挂、地形弹跳、轮压缩、完整倒车／路径切线不是SAGE物理复刻 |
| AudioEvent／AudioFile／Multisound | 选择、移动、攻击、生产、移动攻击；主炮、Q、切换／球音效等原零售声音 | 未完整路由选择交战／受击、撤退、移动环境循环、所有死亡/残骸声音。官方PreFireChargeUp本身无样本，不应伪造；需单独核Upheaval事件样本 |
| ObjectCreationList／Collapse／死亡FX | 原COL碎块、烧毁纹理、质量、沉降／清理；v0.5.6.6补逐骨随机扰动、随机旋转和Lifetime范围 | 随机参数来自官方，力度/重力/落地仍为Godot适配，未复刻ContactTag／完整刚体；FX_ALL_FutureTankDie全部粒子和TerrainScorch仍有缺口，见[残骸对照](RA3_WRECK_DYNAMICS_AUDIT.md) |
| Texture／W3X／PackedTextureImage | 原皮肤、骨骼、片段、损伤与烧毁纹理、按钮与头像 | 包含Only-Includes的W3X已列入扫描；原始素材存在不代表每个声明已被运行使用 |
| LogicCommand／LogicCommandSet／Button／UnitAbilityButton | 本游戏Q技能栏、选择/生产图标按用户指定交换用途 | 原RA3命令面板布局、快捷键不直接覆盖本项目Q/W/E约定 |
| UnitIntro／Video／VideoEventList | 单位介绍资料已在源码目录发现 | 原RA3视频式单位介绍未移植；不属于战斗球/武器修复的依赖 |

## 炮艇全部模块对照

| 文件／模块 | 已接入或保留 | 差异／遗漏／边界 |
| --- | --- | --- |
| GameObject：生产／Body | 原生命5000、独立T3许可、正式模型／损伤贴图 | 物理碰撞与RA3完整KindOf仍是适配 |
| WeaponSet／Toggle | 双炮槽2/3、前机枪槽1、切换子物件、炮口、保持当前命令；不落机场 | 当前弹匣用一个计数器，Q会清零，未按独立WeaponSlot建完整保存／装填状态；需防切换免费补弹，并核实原CPU切换合同 |
| WeaponTemplate：双炮 | 400射程、12发、2秒间隔／2秒装填、500弹速、30散布、伤害100／半径50／衰减30、非步兵50% | 官方最小射程50，Upheaval100；目前仍用官方50。MetaImpact击飞未完整接入。Projectile的Bezier／FireStraightThenCurve不是当前直线插值 |
| WeaponTemplate：机枪 | 10发、.1秒间隔／.5秒装填、12伤害、非建筑50%，原枪口/曳光/命中 | 官方射程300，Upheaval400且最小100／AimDelta5；当前使用官方射程300且无最小。PER_CLIP目标保持、原3D俯仰/视线判定不完整 |
| TurretSettings | v0.5.6.2按Upheaval接360转向／180俯仰／-45限角，解除IdleScan当攻击限角 | 这其实已是Upheaval值：官方前枪20俯仰／-30、侧炮180转向／MaxDeflection±45。两套来源需收敛，不能混称“都一样” |
| AttributeModifier | 源码两套都有机枪模式VISION=76% | **当前未应用**，模式切换只改武器。修复还须保留用户“实际可见至少覆盖攻击范围”的fog规则 |
| TracerModelDraw | 普通／英雄纹理、长度、宽度、颜色、分数发射率、英雄命中火花 | SweepSpeed3缺CPU算法；当前为2D投影，并非三维弹道法线复刻 |
| FXList／粒子 | 普通/英雄20项粒子参数一致，原网格、动态分辨率、纹理与着色器参数 | **英雄FXList有真实差异**：EA引用普通ProtonDist，Upheaval引用VetDist；当前随EA。上一轮“粒子定义一致”不能扩大为“整个FXList完全一样”。水面专属wake/mist、Impact_Bullet声音尚缺 |
| Armor／Experience | 现有官方护甲映射、四阶军衔、经验与英雄材质 | 完整来袭伤害分类／朝向倍率未全复刻；弹匣装填是否受ROF加成需源语义核实 |
| AI／Locomotor | 自定义连续盘旋、原CirclingRadius290／Speed80%、高度190、速度120，伤后不套坦克75% | 官方GunshipJetAIStateMachine／CirclesForAttack=false；Upheaval JetAIStateMachine／true，Fast/SlowTurnRadius50→290、TrailDistance0→250。当前自定义盘旋不等于任一完整原CPU状态机 |
| AudioEvent／AudioFile／Multisound | 常用单位语音、两武器发射／爆炸／切换音 | 机枪模式VoiceAttackSpecial覆盖未路由；移动环境、撤退、受击选择等未全路由 |
| Collapse／ObjectCreationList／死亡FX | 原碎块与烧毁纹理、沉降清理 | 当前直接在地面生成残骸，缺原空中Dying→触地→Collapse的完整高度／惯性链；原飞行死亡FX不是完全替换 |
| 模型／纹理／W3X | 原皮肤、炮台骨骼、机枪/双炮几何、受损烟火、翼尖尾迹、军衔变体 | 原可选AlliedAirPower Upgrade_01外观及策略升级未完整移植 |
| LogicCommand／Button／UnitAbilityButton／SpecialPower | 本游戏Q切武器、无额外技能冷却，用户指定图标布局 | 原命令顺序与本游戏技能格不要求完全相同；RECONSTITUTE_STORED_COMMAND保留原则已满足当前不中断命令路径 |
| UnitIntro／Video／VideoEventList | 声明已扫描 | 原介绍视频未移植 |

## 后续实施边界

### 中子球对空补查（用户补充）

用户指出：未来坦克不能正常主动锁定空军，但强制攻击产生的球可以在接触空中单位时造成伤害。两套 XML 均支持区分“主武器选敌”和“球的伤害对象”：

- EA `Weapon_EP1.xml:289` 与 Upheaval `WeaponTemplate.xml:10` 的主武器只包含 `ANTI_GROUND ANTI_STRUCTURE ANTI_WATER`。
- EA `Weapon_EP1.xml:367` 的 `AlliedFutureTankNeutronWeapon_IncrementalWeapon` 明确包含 `ANTI_AIRBORNE_INFANTRY ANTI_AIRBORNE_VEHICLE`；Upheaval 的 OneShotWeapon（第 93 行）及 IncrementalWeapon（第 125 行）同样包含这两类。
- EA `DamageSphereUpdate/ObjectFilter` 只排除桥梁相关类型，并未排除空中单位。节点第 23 行的 `AIRBORNE_TARGET` 排除属于 AI 躲避配置，不能当作伤害过滤。
- 当前 `ra3_expansion.gd` 中 neutron 分支直接跳过全部 `is_air_target()`，因此错误地禁止了球对空中目标造成伤害。此前对照遗漏这一项，现更正。

修复须保留主武器的选敌限制，将球接触空中目标的伤害判定单独处理；不能只删除空军排除后继续用二维地面距离，否则高空目标也可能被错误命中。具体球体/目标碰撞几何、飞行高度及时间阶段仍需与选定来源对齐；XML 的 AntiMask 能证明伤害类型允许对空，不能单独证明原 CPU 的三维接触算法。回归至少覆盖地面强攻后低空接触、投影重叠但高度在球外、正常选敌不主动锁空、球结束后无额外伤害。此次补查尚未修改运行逻辑。

优先修正常规普攻的阶段／伤害事件与表现同步，其次炮艇模式视野、独立弹匣、目标保持和可确认的音效／粒子引用，再补死亡链。不能将一次截图通过当作全部XML已接入，也不能把“源码声明存在”当作CPU调用次数已知。

用户已确认的跨代伤害适配、RA2目标血量、两套科技需求、作战实验室兼防卫局和Q/W/E布局继续保留。**规则选择已确认：官方起义为准，Upheaval只用于查漏**。上面的差距表是v0.5.6.2基线，已处理部分以开头v0.5.6.3记录为准；其余项保留为明确缺口。

初始诊断没有修改游戏运行逻辑；当时v0.5.6.2新专项按真实问题报失败，既有431项通过不能覆盖／抵消这个遗漏。v0.5.6.3验证另记于VERIFICATION.md。执行环境：Godot4.7.2、Compatibility、WASAPI、隔离CodexIronTideValidation目录，测试无服务／网络／DB依赖。
