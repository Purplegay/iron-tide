# 苏联接入交接 · 2026-10-27

鲍里斯标定、武装直升机部署和基洛夫投弹／坠毁以 [v0.22.8.1 的更新对照](fixes/v0.22.8.1/README.md) 为准。

2026-11-02 起，已接入的苏联单位列入全量精细化，新苏联单位首次制作时同步完成局部补形、32 朝向或 SHP 动作检查及默认／2 倍实机对照。按各自原版模型决定要强化的部位。具体流程见[全量精细化制作标准](MODEL_RENDERING.md)。

v0.7（2026-11-02）开放苏俄遭遇战和苏联 AI。已接入 SMCV、NACNST、NAPOWR、NAHAND、NAREFN、HARV、NAWEAP、HTNK、E2、NADEPT 和 NALASR。继续保留Godot独立机制实现；现有扩展模式“铁幕同盟”及近似单位不代表完整尤复苏联。

哨戒炮通过规则中的 TurretAnim=LASER 读取独立体素炮塔，导出 32 个方向及每个方向的炮口。苏联建造厂主体、动画和建造序列使用相同的可换色调色板。

## v0.15 遭遇战生产目录补全 · 2026-11-02

- 主建筑和防御新增核子反应炉、工业工厂、铁幕装置、核弹发射井。工业工厂运行时，适用载具按原价的 75% 开工；已开工项目保留原报价。
- 部队新增疯狂伊文、鲍里斯、两栖运输艇、巨型乌贼和无畏级战舰。经典模式按国家开放苏俄磁能坦克、古巴恐怖分子、伊拉克辐射工兵、利比亚自爆卡车；渗透苏联作战实验室才可生产超时空伊文。大厅可直接选择四个苏联国家。
- 雷达召唤侦察机，鲍里斯指引米格空袭，无畏战舰发射可拦截导弹。三种支援对象均不进入常规建造栏。核击、辐射和空袭在 Godot 连续坐标中独立实现，飞行与预警时间尚未逐帧对照。
- 专项入口为 `iron_tide/tests/soviet_completion_regression.tscn`。覆盖双模式生产扣费与出厂、国别及渗透限制、单位武器、超武、旧版存档读回，并提供默认及两倍镜头下的实机截图。以下历史列表保留当时的接入进度。
- v0.15.0.1 将扩展单位收割者和磁暴坦克的反应堆前置接到同一座苏联核子反应炉（NANRCT）。

## 可复用清点入口

`node ra2pipe/yr_soviet_audit.mjs "<本机尤复安装目录>" "<不存在的仓库外输出目录>"`

工具使用既有YrSource，只读rulesmd.ini/artmd.ini及游戏归档，保存规则/归档指纹并复核输入未变化。当前候选报告在 `C:/Users/admin/Temp/iron-soviet-intake-20261027-v1/soviet-native-inventory.json`。全部50个主模型候选可找到，42个普通生产图标可找到；尚未验证分层、SHP帧序、VXL朝向与运行态表现，不能把存在检查称为模型接入完成。

## 常规目录候选

| 页签 | 原版 ID（接入清单，尚非最终UI排序） |
| --- | --- |
| 建筑10 | NAPOWR NAHAND NAREFN NAWEAP NARADR NAYARD NADEPT NATECH NANRCT NAINDP |
| 防御7 | NAWALL NALASR NAFLAK TESLA NABNKR NAIRON NAMISL |
| 步兵9 | E2 DOG SENGINEER FLAKT SHK IVAN TERROR DESO BORIS |
| 载具11 | HARV HTNK HTK DRON V3 TTNK DTRUCK APOC ZEP SCHP SMCV |
| 空军0 | 原版常规苏联无独立机场生产队列；ZEP/SCHP在战车工厂生产 |
| 海军5 | SAPC SUB HYD SQD DRED |

另记录NACNST、HORV、SCHD、V3ROCKET、DMISL、BPLN、SPYP、CIVAN八个展开/支援/秘密科技参考项。不能直接作为普通可生产单位加入菜单。不按Owner字段盲筛：很多盟军、尤里建筑的Owner也列出苏联，必须结合前置、Factory、RequiredHouses/ForbiddenHouses及原版ID。

## 已发现的接入边界

- 当前盟军警犬使用历史DOG，原版盟军是ADOG、苏联才是DOG。v0.2.4.1只修排序，未改存档身份。正式苏联接入须制定兼容迁移，同时核对生产队列、保存实体、模型/语音键、country限制与yr_baseline取值，不能直接覆盖现有DOG。
- 大厅、基地、指令甲板、矿车赠送、独立矿场技能和 AI 经济按阵营选取。HARV 装满 40 单位后经地面返回，也可在采矿期间以炮塔自卫。
- 当前生产页签由生产建筑确定，不能按飞行能力把基洛夫/直升机挪到机场；米格/V3/无畏导弹是召唤或生成物。
- 国别特色TTNK/TERROR/DTRUCK/DESO保留各自RequiredHouses；秘密科技CIVAN按真实解锁单独处理。

## 下一批实施顺序

1. 阵营与编号兼容：区分原版苏联和既有扩展单位，迁移盟军警犬身份并验证旧档；国家/开局/生产目录改为按阵营消费。
2. 可玩最小闭环：苏联基地展开收起、电厂、兵营、矿场/武装矿车、战车工厂、动员兵、防空兵、工程师、警犬、犀牛、防空履带车。价格/护甲/武器/精英武器取原版规则；模型图标语音一起接入。×1使用现行15帧战斗基准，生产独立计时。
3. 专属机制：恐怖机器人寄生与维修清除、磁暴步兵充能、疯狂伊文炸弹、辐射工兵、鲍里斯空袭、V3/无畏生成弹头、武装直升机部署、潜艇隐蔽/巨型乌贼、工业工厂、铁幕与核弹。
4. 每批跑经济生产/寻路/技能/存读档专项，并回归盟军六页签；未实现能力明确列为缺口，不能用通用技能冒充。

## v0.8 苏联支援单位与维修厂

本机尤复规则的 FLAKT、HTK 使用 Primary／Secondary 和 ElitePrimary／EliteSecondary 处理地面与空中目标。FLAKT 的前置为 NAHAND + NARADR，HTK 的前置为 NAWEAP。HTK 使用 Passengers=5、SizeLimit=2 与现有登车／卸载流程。SENGINEER 使用 Engineer=yes、苏联国家限制和原版语音映射，可执行工程作业。雷达以 NAREFN + NACNST 解锁。

NADEPT 的六个动作节在 artmd.ini 中均以 Image 指向 NADEPT_C。正常伸出 0–21、作业 22–28、收回 29–49，受损为 50–71、72–78、79–99。阴影位于后半部。两座维修厂共用既有阶段和存档计时，各自按图集和速率显示。

高射炮按本机 rulesmd.ini 的 BallisticScatter=1.0 和弹体 FlakScatter 在连续坐标中计算随机偏移。对地弹沿弧线飞行，对空弹在空中爆炸，范围伤害按对应目标域筛选。

专项入口为 soviet_reinforcements_regression。本次 46 项断言在无界面和图形渲染两种运行中通过，包含用 v0.7 实际苏联存档读取验证、工程师行进占领、载员上下车和维修臂阶段。后续警犬仍需处理盟军历史 DOG 身份。

## v0.9 苏联基地防御

常规生产目录现为 19/42，展开生成的 NACNST 单列。新增 SHK、TESLA、NAFLAK、NABNKR、NAWALL。

- 原版 rulesmd.ini 提供 ElectricBolt、AssaultBolt、CoilBolt、OPCoilBolt 和 FlakWeapon。结合参考实现的充能人数判定，正常供电需 1 人强化，低电需 2 人恢复、3 人强化。Godot 以连续距离计算 1.83 格充能范围，以 NATSLA 的 DelayedFireDelay=28 和 15 Hz 战斗时钟确定蓄电时间。
- NABNKR 使用原版 8 帧图集，前四帧分别为空堡完好／受损、驻军完好／受损，后四帧为相应阴影。驻军通过各自的 OccupyWeapon／EliteOccupyWeapon 与碉堡的五个射孔开火；单位离开后继续保留所有权。NAWALL 使用 16 种连接变体和三个损伤等级。
- 苏联 AI 在基地附近调派步兵走正常的充能／驻军指令。人数分配为项目 AI 策略。旧库中的生产队列和驻军关系通过实际存档验证。
- soviet_defense_regression 在无界面与独立图形桌面分别通过 50 项断言，覆盖生产及扣费、射击时序、正常供电／低电、驻军、补墙费用、AI、充能与乘员引用恢复、v0.7/v0.8 旧兵营解锁。画面和音效的玩家体验待确认。

## v0.9.1.1 建筑语音

本机 evamd.ini 将苏联建筑相关事件映射到 Russian 语音，例如开始建造 csof052、暂停 csof056、取消 csof051、完工 csof048、维修 csof057、出售 csof058。当前 12 座苏联建筑的 rulesmd.ini 节均未指定 VoiceSelect。建筑操作使用玩家顾问，场景里的落地、开火和破坏音效走各自的音效入口。后续建筑批次沿用相同的顾问入口，另核对各建筑原版音效字段。

building_advisor_regression 已在苏俄和美国开局验证实际 HUD 建造、暂停／继续／取消、兵营训练、完工、维修、出售、敌方订单和俘获建筑的语音选择；无界面音频混音输出亦已采样。实际扬声器听感待玩家确认。

## v0.10 苏联高级地面部队

本批使用本机 rulesmd.ini、artmd.ini 的 NATECH、APOC、DRON、V3 与 V3ROCKET。天启的 ElitePrimary 单独替换地面炮，MammothTusk 沿用普通防空武器。DRON 的 8 朝向依次取行走 0–47、待机 48–55、扑击 56–87。发射车射程 5–18 格，火箭生命 50，普通／精英弹头基础伤害 200／400。发射器和导弹各自保存状态，抬升和落点飞行是 Godot 连续坐标适配。实验室力场半径 4 格，护盾 500 帧、断电 1000 帧，战斗时钟每秒 15 帧。

专项入口为 soviet_advanced_regression 与 construction_transition_regression。使用本批之前的苏联目录检查旧档时必须保持其他阵营和规则输入一致。

## v0.12 警犬、基洛夫与武装直升机

旧档的盟军警犬继续使用运行时 DOG，对应本机原版 ADOG。苏联警犬使用 SOV_DOG，对应原版 DOG，兵营和存档保留各自的身份。基洛夫与武装直升机都是苏联战车工厂产品，前置分别取 ZEP 的 NAWEAP + NATECH 和 SCHP 的 NAWEAP + TECH。

基洛夫的普通 BlimpBomb 与精英 BlimpBombE 使用固定投放坐标，弹体取 ZBOMB.VXL。直升机取 SCHP 飞行机体、SCHPDEPL 的 11 帧可见展开动画及 SCHD 机体与独立炮塔。空中使用 BlackHawkCannon，落地并展开完成后使用 160mm，精英状态使用各自的 Elite 武器。弹体下落插值及展开播放时间为 Godot 适配。

soviet_air_regression 覆盖实际生产与扣费、旧目录生成的存档、两种警犬、武器切换、移动目标避开落弹，以及展开中存读。无界面与隔离图形桌面均通过 37 项断言，图形回归另留 1×、2× 截图。实际手感和图像观感待玩家确认。

## v0.14 苏联造船厂、台风级潜艇与海蝎

本机 rulesmd.ini 的 NAYARD 为 4×4 水面建筑，造价 1000、生命 1500、耗电 20，前置为 PROC + POWER + NACNST。UnitRepair=yes、NumberOfDocks=1，维修使用单泊位。NAYARD_A/B/C 为日常动画，D 为生产动画，S 的三个区段用于维修。造船厂及其动画已导出带阵营重映射的 2× 图集。

SUB 造价 1000、生命 600、重甲。SubTorpedo / SubTorpedoE 射程七格，原版 DecloakToFire=no，SensorsSight=7。本项目调整为开火时上浮暴露，停火后按 CloakDelay 重新下潜。鱼雷使用 SUBT.VXL 的 32 朝向和气泡轨迹。HYD 造价 600、生命 400、重甲，要求 NAYARD + NARADR。平射炮 FlakTrackGun 为五格，防空 FlakWeapon 为十二格；精英分别切换对应 E 武器。两舰使用原 VXL/HVA 的 32 朝向、2× 表面与原语音。岸线出口偏移及舰艇连续坐标进坞为 Godot 适配。

soviet_naval_regression 在经典和扩展模式从建造场放置船坞，检查海军页签、实际扣费和出港、探测、对舰及对空、精英武器、水面维修、存档生产队列，以及上版目录生成的旧档。回归沿用 naval_regression、asw_regression、repair_depot_regression 和 building_exit_regression。

## v0.15.5 米格齐射与部署决策

本机尤复 rulesmd.ini 中，BPLN 是 Fighter，Ammo=1。Maverick3 与 Maverick3E 均为 Burst=2，普通每弹基础伤害 750、射程 4 格，精英为 400、9 格且改用 ORCAAP。artmd.ini 的 BPLN.PrimaryFireFLH 为 25,100,0。参考工程 aircraft.cpp 中 Mission_Attack 的 0x418403–0x418478 在同次更新内循环开火。Godot 使用两枚独立投射物，按逻辑格折算左右挂点。标定窗口仍取 Flare 的武器周期，未做原版录像逐帧校时。

aimd.ini 中伊拉克辐射工兵编队引用 Soviet Base Defense，直升机有针对盟军与苏联基地的进攻脚本，在接敌后包含部署指令。这里沿用真实单位部署流程。DESO 用 RadEruptionWeapon 的四格范围和 RadSite 护甲倍率评估阵地。SCHP 降落后使用 160mm，精英使用 160mmE，变形中禁射。敌群评分、避友军、判断地面威胁及恢复旧命令属于 Iron Tide 的战术决策；未实现完整 ScriptType 解释器。

## v0.16 V3、巨型乌贼与碉堡科技

V3 使用本机规则的零等待、60 帧抬架、0.21 到 0.5 的俯仰比例、每帧 0.4 加速度和 768 leptons 巡航高度。发射点取 artmd.ini 的 -160,0,75。LazyCurve 使用固定瞄准点和与爬升方向相切的三次曲线，连续地图上的曲线推进是 Godot 适配。老存档中没有阶段标记的在途导弹仍按原记录走完。
巨型乌贼使用 SquidGrab／SquidGrabE 的八方向 Anim，随舰体朝向选图。抓住后先摇船，在每个摇晃周期后按武器结算一次。34 帧摇晃加 2 帧间隔来自行为参考，未对原版逐帧录像校时。
大厅的碉堡射程 I／II／III 属于 Iron Tide 的局外养成。经典模式沿用原版驻军射程；扩展模式开局冻结己方已购科技，载入旧战斗保留该局科技。满级 8.5 格，驻军仍只能对地。

## v0.16.2 核弹、铁幕与伊文

核弹使用 NAMISL 的发射偏移和四套 SuperAnim。进入 ChargedAnimTime 的最后一分钟开始蓄能，释放播放第四层。NukeCarrier / GiantNukeUp 在井口上升，NukePayload / GiantNukeDown 在指定位置下落，命中时结算原弹头的 600 基础伤害、单位装甲与距离倍率，以及 500 级辐射。弹体独立于发射井，分开导出 UNITTem 调色板机体和原版 16–31 阵营色区。Godot 采用 15 规则帧和垂直加速度的两段飞行模型，本版约 26.7 秒；这是项目适配值，尚未实机逐帧对时。老档的在途核弹沿用旧剩余时间。

铁幕对目标使用暗色脉动，既有免伤仍按 IronCurtainDuration=750 帧。与鲍里斯标定共享颜色合成，独立于建筑落成闪烁。伊文采用 BOMBCURS 原图，450 帧引信、8 帧闪烁、450 基础伤害与 IvanWH；装弹和滴答声取 soundmd。两种伊文都遵守禁止从运输载体装弹；超时空伊文使用对应传送音效，传送恢复期间不能放炸弹。普通死亡可引爆，超时空抹除和拆弹安全解除。图像、声光和引爆流程由 strategic_fx_regression 与 soviet_completion_regression 覆盖。

后续对照：本机 NAWEAP、NAHAND、NAREFN、NAPOWR、NANRCT 都配置 Spyable=yes，当前间谍命令实际拒绝这五类目标。同一探针可进入 GAWEAP。伊文炸桥维修屋目前只结算普通爆炸，桥段通行状态缺少摧毁路径。盟军 GATECH 原版配置 ForceShieldSpecial，当前运行时没有该能力。
