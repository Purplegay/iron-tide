# 尤复死亡、建筑损毁与逃生人员对照

2026-10-29，只读对照本轮读取时的v0.5.7.3运行实现；共享工作区随后另有版本更新。本轮未修改游戏逻辑、数值、资源或存档，不另升游戏版本。

## 原始来源与覆盖

读取本机Steam《红警2＋尤里的复仇》安装档案，按既有YrSource优先级消费：
- rulesmd.ini：expandmd01.mix，SHA256 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`。
- artmd.ini：ra2md.mix/localmd.mix，SHA256 `e1f0378394313c04ebbd5073f47785ee3e46f1b3c62d65724e8f3c310ee7ba31`。
- 参考仓 `refs/ra2yr-resource/src/structure/building.cpp` 的GetCrewCount/GetCrew/EjectCrew及所附反汇编只作行为查证线索；它不是官方完整源码，部分Techno函数仍返回0/null，不照搬或据此关闭功能。

可重跑只读清单：`node ra2pipe/death_audit.mjs <本机YR目录> <新audit.json>`。工具拒绝覆盖已有报告，不改游戏目录。最终本机结果为 `refs/yr-death-audit/20261029/audit-final.json`，包含原字段、死亡序列、原文注释、动画资源位置/哈希。

覆盖65步兵、79车辆、11飞行器、398建筑定义，共553条，包含场景、历史和不可生产条目，**不是当前可造单位数**。其中59建筑显式Crewed=yes，197建筑显式LeaveRubble=yes/true。字段未声明时保留缺省状态，不擅自判成false。

## 实施前确认的区别

| 事件 | 原规则/代码证据 | 当前状态 |
|---|---|---|
| 建筑普通受损 | 受损画面与逃生不是同一个入口；AudioVisual黄血50%、红血25% | 已有受损贴图、DamageFireOffset火焰；不会每次受击凭空增加部队 |
| 建筑摧毁/出售后的人员 | Crewed；AlliedCrew=E1、SovietCrew=E2、ThirdCrew=INIT；Technician=CTECH、Engineer=ENGINEER另有条件 | **没有接入生成逻辑**；retire_sold与_die均未读取crew规则 |
| 驻军建筑重伤撤离 | 是原乘员离开建筑，不是新造兵 | 当前仅CAHSE01入口，25%血量及以下evacuate；毁坏时也尝试疏散，无法落地的乘员死亡。不能当作所有建筑Crewed已实现 |
| 步兵死亡动作 | GISequence/ConSequence：Die1=134,15,0，Die2=149,15,0；另有伤害类型死亡表现 | 当前大多只选Die1，固定0.6秒，以13fps读通用_anim；除海豚特例外未归零，序列按modulo取帧，可能从中途开始、播不完整。无独立持久尸体阶段 |
| 载具死亡 | Explosion、MaxDebris、DebrisTypes/DebrisMaximums、Crewed/DeathWeapon等 | 当前主要通用Impact后删除；独立残骸节点只为RA3三单位创建。YR车辆碎片/驾驶员逃生未形成完整消费者 |
| 建筑爆炸/碎片 | Explosion列表、MinDebris/MaxDebris、DebrisAnim等 | 当前_die是通用Impact后删除，没有用这些原字段生成碎片 |
| 建筑废墟 | LeaveRubble按建筑类型配置，例如CAHSE01=yes | 当前不保留专用废墟状态；不能给所有基地建筑硬留完整烧毁模型 |
| 出售表现 | 既有反向buildup | 已实现，但出售后生成逃生兵、基地工程师规则未接；不能把反向建造当成被摧毁动画 |

## 逃生兵不是统一的40%概率

原rulesmd.ini注释明确标记 `SurvivorRate=.4` 不再使用。出售人员数量应检查售价与阵营除数：盟军500、苏联250、尤里750。`CrewEscape=50%` 的原注释明确说是**被摧毁载具**的乘员逃生概率，不能直接当作所有建筑的统一概率。

参考反汇编0x451330可见NoCrew/Crewed筛选、按阵营除数、被占领状态倍增除数及1～5数量范围；0x442D90有逐落点随机判断和落地失败处理。0x44EB10含建造场特殊人员分支。参考仓部分字段命名不可靠，具体售价调用、出售/毁坏不同概率、工程师/技师条件仍需本机对应版本二进制或原版实机核验，不能仅按字段名臆造最终算法。

已从原规则确认的例子：

| 建筑 | Crewed | 原碎片范围 |
|---|---|---|
| 盟军电厂GAPOWR | yes | 4～6 |
| 矿场GAREFN | yes | 5～10 |
| 兵营GAPILE | yes | 5～15 |
| 建造场GACNST | yes | 7～15 |
| 光棱塔ATESLA | no | 5～15 |
| 船坞GAYARD | no | 6～12 |

因此“建筑坏了应该有人跑出来”对应有条件的逃生/撤离，不应改成光棱塔、船坞等所有建筑受一点伤就生成士兵。

## 素材与调用缺口

553条规则的Explosion/DebrisAnim/DeathAnim(s)共引用29个不同动画名。当前 `assets/ra2/fx` 只有3个对应JSON清单：TWLT070、S_CLSN58、MININUKE；它们存在不表示已用于建筑死亡。其余含S_BANG48、S_BRNL58、S_TUMU60、电厂专用爆炸、各组DBRIS碎片等。

当前读取器在本机原档案中找到其中27个SHP并记录哈希；DBRIS10LG/DBRIS10SM未找到，需继续确认别名/历史无效引用/读取器覆盖，不能据此断言安装损坏。此数字仅覆盖上述显式动画字段，不等于全部InfDeath、DeathWeapon引用链或体素碎片媒体完整性。

## 实施顺序与边界

1. 先补建筑Crewed逃生：核定原算法后分别接毁坏、出售；保持队列退款、击杀经验、占领归属、未建成建筑、超时空抹除和出口被堵边界；驻军撤离与新生成crew去重。
2. 修步兵死亡序列：从首帧播放完整原序列，不循环；再按弹头InfDeath补特殊死亡类型。尸体保留时长需查原引擎，不能把RA3九秒直接套给YR。
3. 导入死亡爆炸/碎片，逐类型消费Explosion/Debris配置，处理烟火、坠落和生命周期；区分视觉碎片与DebrisDamages/DeathWeapon产生的伤害。
4. 按LeaveRubble补场景建筑废墟，并明确通行、可选、重建、存档、迷雾与清理。普通基地建筑不自动沿用RA3整套烧毁残骸。

本轮仅完成来源/消费/资源差距确认，以上尚未当作实现完成。语法检查和原GI死亡序列、电厂Crewed=yes、光棱塔Crewed=no、废弃SurvivorRate注释检查通过；不属于游戏运行或视觉验收。

## v0.5.8 实施交接（2026-10-29）

用户在上述只读对照后明确授权补充。此节替代上表的“当前状态”作为本轮交接；上表保留实施前证据。

### 原程序追加查证

本机`gamemd.exe` SHA256 `3e81a61775d2745d1dabe397325ef663cd994ffc194da4e998e3bf5d2d308600`。可重跑 `python ra2pipe/death_cpu_audit.py <gamemd.exe> <外部报告.json>`，18条匹配。仅只读文件，不启动/注入原游戏。

- 0x710B00/0x71145A确认TechnoType构造器Crewed缺省false；此前“未声明不能当false”的缺口由这个版本的原程序补证。
- 0x451330：NoCrew/Crewed、所属House阵营、占领后除数翻倍、GetRefund虚调用、整数除法、1～5限制。0x7F4F90虚表指向0x711F60，确认读取RefundPercent；本项目仍使用实际出售退款口径，未模拟原House的全部成本修正。
- 0x44EB10：未被占领的建造场有25%工程师类型分支。0x707D20：有武器时15%技师分支，其余用阵营Crew；中立/战役House例外没有一并扩张。
- 0x442D90的+0x540是C4AppliedBy，**不是出售状态**：普通随机上限2，C4上限1，占领后+6。逐可用落点抽中1才生成，生成后减剩余数量；失败落点不无限重试。
- 字段/虚表名称另交叉参考[YRpp BuildingClass](https://raw.githubusercontent.com/Phobos-developers/YRpp/master/BuildingClass.h)、[TechnoClass](https://raw.githubusercontent.com/Phobos-developers/YRpp/master/TechnoClass.h)、[RulesClass](https://raw.githubusercontent.com/Phobos-developers/YRpp/master/RulesClass.h)。InfDeath枚举对照[GeneralDefinitions](https://raw.githubusercontent.com/Phobos-developers/YRpp/master/GeneralDefinitions.h)。这些是社区SDK标注，不称官方完整源码；关键分支另由本机二进制核实。

### 已接入的消费路径

- `ra2pipe/death_assets.mjs`读取原rules/art，输出`data/ra2/death.json`及专用`assets/ra2/death/`。553种类型仅是规则查询范围，不是新增553个可造单位。36组媒体；两个原建筑DBRIS10引用仍缺资源，清单保留missing，不拿别的素材冒充。
- `building_crew.gd`由`Building._die/retire_sold`调用，普通受伤/未完成/NoCrew/中立/无Crewed不进入；正常死亡、出售均只执行一次。C4事件保留标识，占领时持久记录。原驻军疏散独立保留，不转换为额外新兵。
- 出口采用16个有界候选、现有建筑/单位/障碍/水域/边界判定；这是连续地图适配，**不是原FoundationOutside数组的一比一复原**。出口被堵时不强制叠人。出兵归原持有方，5～满血随机生命；不改队列退款、击杀奖励或短局终局。
- `Unit.receive_hit`保留InfDeath，死亡首帧归零、全序列长度/13fps并截断末帧不循环。13fps沿用项目动画时钟，未声称全部死亡时序与原引擎等价。死亡对象清除碰撞/战斗组，到期释放，GM静止标记不能阻止回收。
- `yr_death_fx.gd`消费Explosion及建筑DebrisAnim/MinDebris/MaxDebris；专用视觉随机数不扰动对局随机。原SHP/Rate/RandomRate/ExpireAnim被读取；FLAMEGUY只播放一个6帧方向段接48～107倒地段，排除后半阴影；ELECTRO保留0～3帧五轮。火焰逃跑轨迹未模拟，当前原地死亡播放。
- 碎片初速按55px/256leptons、15tick换算，重力160px/s²、最多5秒回收属于Godot视觉适配。落地播放ExpireAnim，不伪装成已实现原DebrisDamages/DeathWeapon。
- `building_rubble.gd`对有LeaveRubble和多状态SHP的当前民居使用最后可见帧；只是无碰撞、不可选、不可驻军的持久地面画面。普通基地建筑不留整座烧毁模型。原废墟地形占用/重建规则未复刻。
- 逃生专用CTECH/E2/INIT通过GameData私有fallback查询，正式目录优先，避免遮蔽后续苏联/尤里完整单位包；原生产unit_index不变，旧内容指纹不变。新存档额外校验death_rules；旧存档无此字段仍接受。逃生兵、占领标识、crew RNG和废墟位置按已有数据存档；瞬时爆炸和未播完尸体不持久化。

### 验证与仍未完成

新增`yr_death_regression`100项通过：两模式、真正receive_hit/死亡/出售入口、资金、出兵范围/归属/重复死亡、工程师、占领惩罚、禁止生成、堵出口、完整序列/特殊弹头、有限碎片生命周期、暂停、旧/新存档校验、RNG/废墟恢复。渲染截图已检查原GI倒地、原爆炸和原民居废墟可见，但最终状态仍是`pending_user_visual_confirmation`。

还未补齐：车辆TIRE/PIECE/GASTANK等体素碎块、CrewEscape驾驶员/飞行员路径、DeathWeapon与碎片溅射伤害、病毒云/变异兵连锁、原版FoundationOutside落点与完整废墟地形规则。不能据本轮宣称整个YR死亡系统已完全复刻。


## v0.5.11 车辆碎块、驾驶员和死亡溅射（2026-10-29）

### 来源与消费

- 原安装包、rules/art SHA沿用上文。`death_cpu_audit.py`增至27条：0x6F3958/3962确认车辆Crewed返回0或1名；0x7114A8确认Explodes默认false；0x7114B4确认DeathWeaponDamageModifier默认1.0；0x70258F为死亡爆炸入口；0x70D6A0/D6F1选择死亡武器和倍率；0x70D713及0x7E1738确认无武器时用Strength×0.5。地址只适用于上文已锁定的gamemd.exe，不把参考仓空函数当规则实现。
- `ra2pipe/death_voxels.mjs`从本机TIRE/PIECE/GASTANK VXL/HVA、unittem.pal和voxels.vpl独立烘焙，每种16个偏航×8个翻滚姿态。不是把完整坦克贴图裁成矩形，也不是给每辆车强制留下完整车壳。death.json保留原始字段、VXL/HVA哈希，新增死亡武器和缺失弹头映射。原SHP动画清单增至46组。
- `vehicle_crew.gd`接真实Unit._die：Crewed、CrewEscape=50%、最多1名、House阵营E1/E2/INIT以及武装类型技师分支。AMCV可逃生；CMIN、ROBO、HORNET不会凭空生成驾驶员。原乘员销毁不转成额外驾驶员。16个有限安全出口检查地图边界、建筑、障碍、单位和水域，堵死时放弃。
- `yr_vehicle_debris.gd`接车辆DebrisTypes/DebrisMaximums/MinDebris/MaxDebris；默认碎块取General的ScrapVoxelDebris，Explodes类型可取ExplosiveVoxelDebris。建筑读取正确的复数DebrisAnims，原SHP碎片也使用同一份可保存的落地记录，旧yr_death_fx不重复创建。Duration按15tick换算，速度按55/256lepton与15tick换算，Gravity=6；轮胎按Elasticity反弹，落地/到期播放ExpireAnim后移除。水中清理而不触发陆地爆炸。
- `yr_death_combat.gd`接Explodes、死亡武器及倍率、现有EXPLODES军衔能力与CausesDeathWeapon标记，使用现有Ra2Damage和receive_hit完成Verses、ProneDamage、CellSpread/PercentAtMax、量化和防御。FV仅存在DeathWeapon=CRNuke不构成普通死亡核爆；DTRUCK按Demobomb=300及其原弹头结算。无武器Explodes建筑使用DefaultDeathWeapon与原Strength/2。出售、超时空抹除不走普通死亡入口。
- 溅射覆盖敌我地面目标，AffectsAllies=no排除友军，空中和舱内单位不重复受地面溅射；已死/已释放对象先过滤。失效死亡源不会成为反击目标或继续获得军衔经验。爆炸每批最多64条，后续条目保留到下一tick，杜绝深层递归和丢尾。
- `allied_state`保存碎片位置/速度/寿命/旋转、损伤开关、RNG及待处理爆炸队列；Snapshot.restore重建独立绘制节点。所有伤害由逻辑记录驱动，不以迷雾可见性或渲染节点存在为条件；暂停、结束对局会冻结计时。死亡源释放不丢失弹头和阵营，已消耗记录先移除再触发连锁。

### 明确的Godot适配和未扩张范围

原版数值与入口门控已有证据；碎块抽样分配顺序、16个连续出口、飞机逃生人员直接落在安全地面、连续高度/固定子步积分、建筑占地边缘的范围估算、16×8渲染姿态和烟迹都是Godot适配，尚未宣称与原引擎每帧随机序列、降落伞或地图格子碰撞一致。碎片DamageRadius原字段保留，目前伤害范围使用现有CellSpread路径。未新增弹头对矿物/地形的破坏、RadLevel辐射场、尚未开放的特殊IFV爆破乘员转换、病毒云/变异连锁或原版废墟通行规则；原有RA3残骸和空中坠毁由其专用系统继续处理。

原资源仍有DBRIS10LG/SM缺失；新增检查还保留一条原AnimList文本`MININUKE - ADDED 11/30`为INVALID_ANIM，不把注释碎片猜成合法资源名。现有合法MININUKE素材不受影响。未增加可生产兵种，DTRUCK专项只用测试夹具映射原定义验证真实Unit消费。

### 交接与验证

新专项`yr_vehicle_death_regression`260项通过，覆盖两模式、实际致死入口、概率/数量/归属、Crewed禁止项、堵出口、抹除/出售、原体素媒体、弹性/寿命/暂停、水域、双方伤害/装甲/卧倒、SHP碎片、连锁队列、保存RNG及读档后一次性命中。存档测试使用实际Snapshot和校验器，不手写替代序列化。

另通过原死亡100、运输180、伤害1988、存档120、RA3补齐36项，共6套2684项；原程序27条检查通过。环境与报告路径见VERIFICATION。全程headless，没有开启或置顶游戏/控制台窗口。RA3专用gm_death_cleanup要求真实渲染，headless前置拒绝，此项未计入通过；没有为了通过删掉渲染断言。视觉状态为pending_user_visual_confirmation。

存档兼容说明：仍保留既有death_rules严格指纹校验。新增manifest内容会使带旧死亡规则指纹的存档被拒绝（提示“死亡与逃生规则版本不一致”），本轮未绕过此门禁；无该字段的更早格式仍按原兼容路径接受。测试证明的是当前规则下的中途保存／恢复，建议新开局体验新增死亡机制。
