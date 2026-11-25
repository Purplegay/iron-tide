# 盟军固有能力与攻击表现

## v0.5.0.7 弹丸目标生命周期（2026-10-28）

弹丸目标可能在抵达前被释放，Godot的`is`类型判断同样必须先通过`is_instance_valid`。普通范围弹仍在保存落点结算，单体与幻影延迟伤害遇到已释放目标不改打旁人，并正常结束弹丸；相关原始强制攻击友伤语义保留。新专项 `projectile_lifetime_regression` 和修复前后证据见VERIFICATION，后续不要将这三处保护退回裸类型检查。

## v0.4 特殊机制收尾（2026-10-28）

追加超时空敌军/步兵/危险落点、间谍雷达与超武重置、GI民居驻军、工程师修桥、警犬接触扑杀，以及风暴云阶段和AI特殊任务。玩法入口、原始规则、独立适配与尚未完成的完整桥梁/房屋/反潜机等内容统一见 [SPECIAL_MECHANICS.md](SPECIAL_MECHANICS.md)。以下历史记录按日期保留，早期“未接入”不覆盖该新状态；表现仍待使用者确认。

## v0.3.10 治疗标识（2026-10-27）

`scripts/ui/healing_indicator.gd` 在真实 `Unit.heal` HP增加后记录短暂metadata，持续治疗刷新1.15秒显示窗口，末尾0.2秒淡出；这覆盖原维修厂0.96秒修理间隔，避免两次实际修理之间闪灭。维修厂调用相同heal入口，原来按实际修理量扣费的顺序与数值保留。被选中与否不影响标识，屏幕固定16像素，位于血条右侧攻击CD圆圈上方18像素；纯Godot绘制绿色加号，属于RA3风格适配，不冒称原版贴图。

暂停冻结显示时间；死亡、隐藏、迷雾外和载具内乘员不显示，隐藏期间治疗不会在重新出现时重放。完整回血、零治疗和未付费的维修等待不触发。自愈、维修车和技能现有heal调用自然接入。瞬时metadata不进存档，载入不会回放旧治疗提示；没有修改采矿/卸货节奏。双模式实际回血、维修收费、迷雾、暂停及0.5/1/2/4倍缩放渲染专项为`healing_indicator_regression -Render`。运行证据见VERIFICATION；外观为 `pending_user_visual_confirmation`，不据截图写成用户已验收。

## v0.3.9.2 生产出口与受阻偏移（2026-10-27）

`ProductionExit` 统一当前盟军兵营、战车工厂、矿场和船坞的出兵点。参考本机 rules.ini 的 ExitCoord 区分门口方向，SHP 像素锚点与路径网格间隙为 Godot 独立适配；不宣称原引擎逐帧等价。未校准的旧建筑保留原后备逻辑。默认点受阻时按距离排序，在前方半圆160世界单位内偏移；不绕到本建筑背后，仍检查完整单位身体的阻挡、地图、水陆与单位重叠。机场只使用自身四个预留停机位，不能从另一座空机场“出生”。

`battle.spawn_unit` 仅为真实生产者赋出厂朝向、短距离驶离或原有集结点；矿场矿车继续自动采矿。`AirportDock` 的生产位置与返航位置共享同一模型锚点计算；`choose_home` 只在初次生产限制本机场，正常返航仍可找其它机场。没有新增存档字段。全部附近位置被堵时保留已付费队首，恢复空间只释放一次，不重复扣费或播完成语音。

专项入口：`tests/run-navigation-building.ps1 -Suite production_origin_regression -Render -RunRoot <新的外部目录>`；固定出兵点、受阻偏移、真实车辆驶离、全堵等待/解堵、机场归属及水面出生均覆盖双模式。建筑动画/批量集结旧夹具按实际 production_work_rate 换算时间，未改变生产速度。验证位置见 VERIFICATION，表现状态 `pending_user_visual_confirmation`。保留共享 RA3 改动；不在本轮提交、推送、打包或归档。

## v0.3.9 强制攻击与交接（2026-10-27）

选中单位或防御建筑后，Ctrl＋左键可以指定友军、敌军、建筑或固定地面坐标；鼠标沿用尤复攻击/禁止图标。松开 Ctrl 保留命令，S 停止，右键移动改令。攻击按钮的提示也包含该操作。Ctrl＋右键原有攻击移动保留。建造、技能选点、维修/出售和界面点击优先处理。

独立 Godot 实现通过 `ForceFire` 下令；`ForceFirePoint` 是无碰撞、不会自动索敌的可存档坐标对象。显式友伤授权保存在 actor.special，随弹药存入 splinters，实际伤害仍走原有弹头/装甲流程。改道、停止、目标死亡清除命令；友军击杀不计经验。原有防空/反潜、NoManualFire、AffectsAllies、弹药、最小射程、部署限制保留；工程师、间谍、矿车等不接受不兼容攻击。心控/超时空武器不能凭空攻击地面，本轮不扩展 C4 接触动作规则。

入口为 `battle._handle_mouse_button`；鼠标只读解析 `battle_cursor.resolve`；单位、建筑、飞机、开放式乘员复用已有攻击流程。保存白名单增加 force_fire_point，仅允许规则/数据指纹一致的旧 schema；未放宽未知数据兼容校验。测试入口 `tests/run-navigation-building.ps1 -Suite force_fire_regression -Render -RunRoot <新的外部目录>`，关联结果见 VERIFICATION。实机手感为 `pending_user_visual_confirmation`；保留其它共享改动，本轮未提交、推送、打包或归档。

2026-10-26 新增战斗要塞 BFRT，5 人车内射击、乘员武器/防空、E/鼠标卸载及载具碾压，
详见 [YR_FORTRESS.md](YR_FORTRESS.md)；含原版盟军单位目录与未完成能力清单。

2026-10-23。本页覆盖本批新增能力，优先于 RA2_PARITY.md 的历史缺口表。
实现依据本机尤复规则独立编写，不宣称原版引擎逐帧等价。两模式均保留固有能力，
扩展技能排在后面；RA2 模式仍关闭养成加成。

2026-10-26 军衔武器核对：普通/老兵保留基础武器，到精英才读取 ElitePrimary、EliteSecondary 或 EliteWeaponN。
31 个已接入盟军/舰载机目录项逐项对照本机 rulesmd.ini，包含 GI/GGI 部署、IFV 乘员换装和卸载恢复。
灰熊 105mmE、坦克杀手 SABOTE 使用双发、VTMUZZLE 炮口和 VTEXPLOD 命中；IFV HoverMissileE 四发；
光棱 SuperComet、幻影 MirageGunE、海豚 SonicZapE 等沿用已有精英路径，并非本轮才首次实现。
补齐 BFRT 缺失的 VeteranAbilities/EliteAbilities（原版无独立 ElitePrimary），以及 HORNET 的升级属性和 HornetBombE。
HORNET 普通炸弹 Damage=40/ORCAAP，精英 Damage=80/ARTYHE；保留自身经验来源，不在本轮推测或改写母舰/舰载机经验传递。
ROBO 原版 Trainable=no，不增加星级或虚构精英武器。无原始精英武器的单位不会统一换红色弹体。
Para 缺失的八向 MGUN 炮口按尤复补回；20mm/MP5/AWP/DoublePistols 的既有表现兜底在精英/别名路径继续使用，
这些兜底不宣称原引擎炮口，原始 Anim 优先。旧快照只补 BFRT/HORNET 缺失定义缓存，保留已有军衔和经验、不重放晋升特效。
客观回归与存档证据见 VERIFICATION.md；特效观感 pending_user_visual_confirmation。

## 操作

| 单位 | 本批接入 |
|---|---|
| 美国大兵 | E 卧倒/起身，与 D 和鼠标部署共用状态 |
| 重装大兵 | Q 固守、E 部署，登上 IFV 使用尤复第 17 把武器 |
| 工程师 | Q 或右键目标：占领敌方可占领建筑、完全修复受损友方建筑，成功后消耗工程师；拆除己方目标上的 C4 不消耗工程师 |
| 海豹、谭雅、心灵突击队 | 建筑 C4 属于普通攻击，接近后跨入目标建筑占地安装，再退出；建筑在 C4Delay 倒计时内闪红，工程师可拆弹，不占 Q/W/E |
| 谭雅、海豹 | 谭雅对载具使用 Sapper；海豹对舰船使用 Sapper，对陆地坦克仍用 MP5。Sapper 是近身副武器，按原始伤害/弹头/射程/ROF 发射，不挂建筑 C4 倒计时 |
| 超时空突击队 | C4=no；对建筑使用 FakeC4 副武器直接伤害，不安装定时建筑炸药。E 保留超时空移动 |
| 间谍 | E 选择敌方步兵伪装；Q 或右键渗透矿场/电厂/兵营/战车工厂。分别窃取一半资金、使敌方断电、给予对应新生产单位老兵训练；收益由阵营持有，不依赖被渗透建筑继续存活 |
| 多功能步兵车 | 装载一名步兵，根据 IFVMode 和 Weapon/EliteWeapon 切换武器、射程、防空、连发与炮塔；E/D 卸载后恢复。工程师变维修车，右键维修受损友方地面载具，不能攻击敌人 |
| 超时空军团兵/超时空突击队 | 普通移动及固有传送技能使用合法落点传送，按距离等待恢复；集火时先移至射程附近。矿车仍保留独立返场传送流程 |
| 超时空军团兵、对应 IFV | 持续锁定冻结目标并累积抹除，不按普通 HP 伤害结算；停火、移动、装载、死亡、眩晕、丢失目标或超出射程会释放冻结 |
| 心灵突击队 | 对单位普通攻击控制一个合法地面单位，保持 HP，同步归属/目标组/AI 队伍；E 或死亡/装载时释放。心控拒绝免疫者、建筑、飞机和已受控制目标；建筑另走 C4 |
| 幻影坦克 | 静止自动伪装为本地原版 TREE01，E 开关；移动、开火、受伤显形。侦测单位或近身步兵可识破；手动指定目标仍可攻击。补入精英 MirageGunE |
| 警犬、狙击手 | 拒绝非步兵目标；警犬能识破间谍 |
| 光棱坦克 | 原始分裂武器/数量、逐目标弹头伤害、普通/精英及二级分裂光束 |
| 海豹、谭雅 | 两栖移动域及游泳、踩水、水中攻击/死亡动画 |

普通步兵开火动作统一从第一帧计时，补回狙击手缺失序列。IFV 三种替换炮塔及炮口
来自原版体素，画布扩展采用偏移对齐原车体，不裁掉较高的维修炮塔。
心控连接、持续抹除光束和恢复/C4 标识同步规则状态。

## 来源、资源和存档

- rulesmd.ini SHA256：`3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`。
- `tools/export_allied_capabilities.py` 导出 51 把相关武器、弹头/弹道和能力参数，使用 `YR_CAP_` 名称空间。输出 `iron_tide/data/ra2/allied_capabilities.json`，已随运行资源纳入 Git。
- `ra2pipe/allied_ability_art.mjs` 从本机游戏只读导出替换炮塔/炮口、TREE01 和 SNIPE 序列到新外部目录，需要既有本地解码工具。
- 单位/建筑特殊状态、阵营渗透收益和分裂弹状态进入显式存档白名单，控制双方引用与抹除进度可恢复；旧版存档补空状态，不猜造历史技能结果。
- 新存档指纹包含本批规则包，拒绝不同规则或损坏文件。测试不写玩家真实存档。
- 本机资源已导入；独立增量包为 `C:/Users/admin/IronTide-resource-update-allied-20261023`，包含 13 个运行资源和逐文件 SHA256。旧完整资源包不变，其他机器须同时应用本批代码与增量资源，再用 Godot 编辑器导入。

## 明确适配与剩余缺口

2026-10-26 C4 核对：本机原版 rulesmd.ini 中 TANY/GHOST 有 C4=yes 和 Secondary=Sapper，
PTROOP 只有 C4=yes、Primary=MindControl，CCOMAND 没有 C4=yes、Secondary=FakeC4。
Sapper 为 Damage=2500、Range=1.5、ROF=100、Mechanical 弹头；FakeC4 为 Damage=5000、ROF=10。
TANY 主武器 HollowPoint2 对载具为 0%，GHOST 的 HollowPoint 为 1%；NavalTargeting=4 选择对舰副武器。
普通攻击统一消费这些差异，不再由一个技能把所有单位、载具、建筑变成相同爆破。
自动爆破遵守视野、固守和移动订单；攻击移动在爆破后恢复目的地；旧存档恢复时移除 C4 按钮。

2026-10-26 进入/红闪修正：原实现的放置距离为建筑占地外沿再加单位半径、10 像素、动作容差，导致未接触即放置。
现在分 approach/enter/exit：普通寻路到外沿，仅对本次目标临时豁免碰撞，步入占地 8 个世界单位后才装药，再走回入口外侧。
人员不消耗、不驻军；取消进入会恢复到先前外侧位置，碰撞豁免只存在于单次 move_and_collide 调用内。
进入/退出阶段、入口和目标存入已有 special 字典，仍使用原存档 schema。重复安装不延长既有引信。
C4Delay=.03 从本机原版规则读取为 1.8 秒；建筑材质按剩余时间脉冲变红，拆弹立即恢复。默认房色共享材质不被修改，
红闪与超时空冻结共用隔离材质管理，避免两套材质互相覆盖。原 C4 文字提示移除。
这不是声明已逐行移植尤复引擎：本地及远端固定 b01d3cf9 的 Mission_Enter 返回 10，CheckAndApplyBomb 返回 0，
IsC4AnimationActive 返回 false；这些入口不能作为完整实现搬运。
[EA 公开的前代 Red Alert InfantryClass::Per_Cell_Process](https://github.com/electronicarts/CnC_Remastered_Collection/blob/master/REDALERT/INFANTRY.CPP#L853)
可核对“进入目标建筑格、设置延时和目标闪烁、向外散开”的流程，但它是 RA1，不是 YR 源码。
本项目据此作交叉参考并实现用户要求；8 像素进入深度、退出到原入口、红色混合强度及 4 Hz 节奏是 Godot 适配，未证明尤复逐帧一致。

引擎参考：用户指定的 [RA2YR_ReSource](https://github.com/Ritanlisa/RA2YR_ReSource) 是逆向重建工程，
本地 InfantryClass::CheckAndApplyBomb 仍为返回 0 的占位，不当作已还原的原版执行结果。
武器选择链与空地/护甲分流交叉核对 [Phobos 原引擎挂钩](https://github.com/Phobos-developers/Phobos/blob/develop/src/Ext/Techno/Hooks.Firing.cpp)，
只独立实现已核对的行为，不复制参考实现。光标帧依 [OpenRA 的原版 MOUSE.SHP 索引](https://github.com/OpenRA/ra2/blob/master/mods/ra2/cursors.yaml) 从本机素材提取。

- 抹除按 `Damage × 15 × 秒数` 累积到目标最大 HP；当前一个目标仅接受一个抹除者，未做多人协同加速。连续世界距离、落点与恢复计时为工程适配。
- 光棱在命中点附近选择射程内可见敌人，最多原始数量，递归排除已命中目标；原版随机选枝和全部建筑触发条件未逐帧对齐。
- 间谍尚缺雷达清图、超武重置；这些目标不会消耗间谍。v0.2.9 已接入实验室科技，见下文。
- GI 驻军、工程师桥梁修复、部署过渡、警犬完整扑咬位移仍待补；CCOMAND 科技条件已在 v0.2.9 接通。

2026-10-26 生产限制收口：CCOMAND / PTROOP 不再仅凭兵营即可普通生产，卡片说明需窃取实验室科技且渗透解锁尚未接入。
规则由本机 rulesmd.ini 独立导出的 data/yr_production.json 提供；PTROOP 使用尤复 RequiresStolenThirdTech（尤里），
不沿用旧 RA2 表 RequiresStolenSovietTech。保留单位实体、技能、地图生成及旧存档身份。
CDEST 为 TechLevel=-1 的场景海岸巡防艇，移出生产栏及船厂可造名单；已有场景实体仍可加载。
生产栏、玩家/AI 下单和旧生产队列共用限制；旧异常订单暂停但允许按实付金额取消退款。
以上为2026-10-26目录收口时状态；实验室渗透解锁于v0.2.9补齐，TANY BuildLimit和完整YR科技树仍未完成。
- IFV 17 种定义完整导出，本批覆盖已上线盟军乘员；未来苏军/尤里乘员的自爆、辐射场等不因定义存在而标为完成。
- v0.6 已接驱逐舰鱼鹰、单发深水炸弹、舰载补给／重建、失联召回和双方水下侦测。潜浮过渡、精确起降姿态与特殊死亡动画仍待做。
- 画面、声音、手感保持 `pending_user_visual_confirmation`。

## 2026-10-26 飞行高度与航迹

当前可生成空中单位共七种：ORCA、BEAG、HORNET、SHAD、JUMPJET，以及扩展单位
soviet_twinblade、swarm_winged。本轮覆盖这七种；没有把原始数据中存在但尚未接入的 ASW 等标为完成。

本机尤复 rulesmd.ini 的 [General] FlightLevel=1500，SHAD/JUMPJET 的 JumpjetHeight=500、
JumpjetSpeed=30；二者 JumpjetClimb 分别为 10/20，JumpJetTurnRate 分别为 6/10，
JumpJetAccel 分别为 12/10。ORCA/BEAG/HORNET 使用 Fly，SHAD/JUMPJET 使用 Jumpjet。
参数与用户指定 RA2YR_ReSource 的 locomotion.hpp 及
[YRpp Fly 引擎结构](https://github.com/Phobos-developers/YRpp/blob/master/FlyLocomotionClass.h)、
[Phobos Aircraft 原引擎挂钩](https://github.com/Phobos-developers/Phobos/blob/develop/src/Ext/Aircraft/Hooks.cpp)
交叉核对；这些接口和挂钩不等于完整原版飞行源码，Phobos 的可选增强行为不作为原版事实。

- UnitFlight 独立实现连续运动：旋转限速作用于实际速度方向、加速/接近减速、垂直起飞、
  普通移动抵达、悬停攻击及返航。跳跃飞行使用独立 Jumpjet 参数；BalloonHover 单位待机不落地。
- 高度不再随模型半径变化：沿既有投影适配采用 30/256 像素每 lepton，普通战机约 176px，
  夜鹰/飞行兵约 59px（1 倍缩放）。阴影留在地面，模型、命中几何、炮口、血条和冷却圈跟随高度。
- 机场生产在预留停机位生成落地飞机，再消费实际生产者集结命令；舰载机从甲板高度起飞，
  返航到达后再降落。弹药/补给/机位容量与运输乘员规则保持原入口。
- ORCA/BEAG/SHAD/HORNET 从本机 VXL 重新生成 32 朝向；2026-10-26 的全模型修正接入 HVA，SHAD 使用原始两姿态及同画布地面阴影，替代之前自行制作的四姿态循环。见 MODEL_RENDERING.md。
  对应炮口也重算。JUMPJET 使用原始 SHP 方向帧，没有伪造插值帧。
- 扩展单位没有尤复原型，保留作者速度和空中待机行为，使用悬停控制器，不冒称原版数据。

边界：转弯半径、减速曲线、固定翼垂直速度与屏幕投影属于 Godot 连续世界适配；
未声称逐帧复刻原版积分器。精确停机坪模型坐标、倾斜/俯仰体素姿态、多层地形净空、
完整坠机和反潜机仍待后续。既有四姿态旋翼为独立动画，并非原始 HVA 时序。
归一化高度、订单、速度、朝向仍沿既有存档字段保存，派生飞行参数在恢复时重建。
运行验收见 VERIFICATION.md；用户实际观感尚待确认。

后续按用户“飞行兵没有悬浮感”的反馈，为 JUMPJET 叠加独立表现浮动：2.4 秒周期，
悬停振幅 2.5px，随移动速度平滑减弱至 0.8px，各单位相位错开，起飞最后阶段渐入。
这是用户要求的 Godot 视觉适配，不改原始 JumpjetNoWobbles、500 巡航高度或寻路状态；
模型、拾取、炮口和血条共用视觉高度，地面投影留在原位，暂停时不推进动画。

## 2026-10-26 不足全款仍可下单

侧栏单位、建筑与防御生产不再要求持有全部造价；与矿场制造技能及实际生产链统一，
费用随进度支付，没钱保留进度并显示资金不足，到账自动继续。前置、国别、机位、
生产者、队列容量和建筑预约科技仍约束下单；手动暂停不会被到账自动解除。
取消只返还实际已付，已付清的就绪建筑在零资金时仍可进入放置模式。

参考 [YRpp FactoryClass](https://github.com/Phobos-developers/YRpp/blob/master/FactoryClass.h)
的 GetCostPerStep、Balance、OnHold（缺钱等待/到账恢复）及 IsManual；
本地 RA2YR_ReSource 的 factory.cpp 仍是占位，未将其当作完整原版生产实现。
本轮修改侧栏准入和说明，复用现有分段付款，不搬运原引擎代码或改动存档格式。

## 验证

### 2026-10-26 超时空冻结表现

此前 `temporal_by` 已冻结行动并阻止普通伤害，但模型只有房色材质，缺少目标本体的冻结表现。
现在 `temporal_visual.gd` 从现有双向抹除关联和 `temporal_work / max_hp` 重建蓝色凝滞、条纹和淡出。
射线色取本地 `rulesmd.ini` 的 `General.ChronoBeamColor=128,200,255`；纹理凝滞是 Godot 独立表现适配，
不声称原引擎逐像素一致，也未把传送用 `WARPOUT` 冒充抹除 `WARPAWAY`。
抹除完成仍走原有击杀、经验、乘员和事件清理，只跳过普通爆炸音效、冲击和倒地动画。

每个受影响目标使用独立材质，缓存房色不会被修改；取消、关联失效后恢复原材质并重绘。
视觉状态不进入存档，由既有抹除关联恢复；传送后的 `chrono_left` 恢复等待不会误用目标抹除外观。
默认关闭的 shader 分支保留普通单位/建筑渲染；进度驱动条纹，不使用暂停后继续运行的 `TIME`。
新增 `temporal_visual_regression` 覆盖步兵、坦克、建筑的实际渲染像素、共享材质隔离、取消和完成；
`allied_abilities_regression` 增加读档后材质恢复断言。实机表现仍为 `pending_user_visual_confirmation`。

运行 `iron_tide/tests/run-navigation-building.ps1 -Suite allied_abilities_regression -Render -RunRoot <新的外部目录>`。
专项经过真实 Unit/Battle/Logistics/Snapshot，覆盖两模式装卸、武器/模型、维修、占领/消耗、
C4、间谍收益、心控免疫/容量/释放、抹除中断/完成、传送、矿车边界、分裂伤害、
伪装/识破、游泳序列和存档。最新执行证据见 VERIFICATION.md；历史测试与静态解析不等于实战确认。

### 2026-10-26 支援建筑、超武与单位说明

- ATESLA：邻近空闲同方塔向主攻塔供能；以支援塔到主攻塔计算射程，不再画向敌人。每座增加 150% 基础伤害，最多 8 座；本机 YR 的 PrismSupportDelay=45 ticks（3 秒），以新 support_rules.json 为来源。当前为单层邻近供能适配，不宣称逐跳递归复刻。
- GACSPH：选中建筑点超武，再点己方车辆/舰船区域、最后点落点；不依赖 selected_units。半径 82.5 世界单位选区，保留相对队形；先校验所有落点，拒绝占用、越界和不适合移动域的落点，失败不扣充能。传送停止旧指令，清除维修出场残留，恢复等待 4 秒。CHRONOAR / CHRONOFD / CHRONOTG 原资源。当前仅己方非步兵非飞行器，不包含原版传送步兵死亡或敌军传送规则。
- GAWEAT：本轮天气明确指“闪电风暴超级武器”。补 WCCLOUD1/2/3 云层和 EXPLOLB 落雷爆炸；AltPalette=yes 读取 UNITTEM.PAL，普通爆炸读 ANIM.PAL，Rate 按既有 /60 适配。地面坐标仍用于迷雾判断，云层高度仅作用于绘制。雷击使用 IonWH 护甲/距离倍率与既有减伤取整，命中双方单位和建筑；已发射风暴不因断电暂停。既有风暴状态仍挂在来源建筑上，未改为独立世界级灾害；来源被毁后的持续行为不是本轮实现范围。
- GASPYSAT / GAGAP：正常运转卫星揭示本方全图；敌方已供电裂缝以 10 格半径重置可见和已探索状态；随后真实近距离侦察和开火暴露按既有规则揭示。画面、目标可见性、小地图共用 fog 数据。卫星不等于反隐。选中裂缝显示范围。
- GADEPT：普通导航到外侧入口，最后一段仅临时忽略该维修厂碰撞并驶向平台；每次 move_and_collide 后立即恢复碰撞。单平台排队，修满驶离，入口等待不收费；伤害、费用及暂停/所有权检查保留。维修进入/驶离状态复用 special，节点引用通过原快照映射，未改存档 schema。
- GAWALL：在已付费墙段放置后，自动填补同方向近距离友方墙之间最多 4 格缺口，每段按造价扣款；碰撞、资金不足即停，不跨敌墙；原 16 向连接帧保留。这是本项目的便捷铺墙规则。
- GAOREP：维持每座运行中精炼器 +25% 且多座相加；卸矿飘字新增精炼额外金额，避免误认为增加地面矿量。原矿石增长/扩散不改。
- EntityDescription 为盟军现有单位和建筑补用途、操作、限制，扩展单位保留原描述并追加角色/武器信息。生产图标 tooltip、建筑详情使用同源说明；单位名字旁“说明”按钮弹出全文，避免挤占状态/命令区域。

实际效果仍待使用者确认，状态 pending_user_visual_confirmation。客观验证见 VERIFICATION.md。


## 2026-10-27 · v0.2.6.2 C4入口末段

用户确认“有些建筑进不去，人应该进去”。复现发现CommandoCombat.tick_c4要求距精确approach点4单位以内，但Unit._go_to沿A*走到附近可行走格中心就停止，实际仍距入口20～50单位；原固定方向/格点测试漏掉这一情况。初版末段修复还在离开路点半径后退回网格，已补充“比终点更接近入口”条件，防止往返。

只在C4接近阶段、入口两格内、已是最终路段且达到终点附近或已向入口推进时切到_move_toward(..., false)。真实物理碰撞和移动域检查保持，远距离仍沿A*；进入阶段仍只临时排除本次目标建筑，其他碰撞不变。必须实际跨入footprint才设置引信，随后退出，不是驻军或消耗人员。没有新增阶段/存档字段，也没有传送到建筑或在外围直接放药。

默认defend不主动拆建筑是v0.2.5确认规则，仍有效；使用右键明确攻击建筑、攻击移动或显式自由开火。C4进入不改变谭雅对载具的Sapper、海豹对船Sapper/对坦克MP5、超时空突击队FakeC4区别。旧commando专项的自动追击/拆建筑前置已分别改成明确攻击和显式free，并补默认谭雅不追击射程外载具断言。

4套1054项断言通过：c4_approach768（两单位/两模式/电厂、战车工厂、矿场、维修厂、空指部、基地/八方向），c4_entry96（两单位红闪、脉冲、退出、停止、拆弹、爆炸、进入及退出存档恢复），commando_attack120，automatic_defense70。当前15逻辑帧下原规则引信1.8秒；并未改写原版C4Delay。C4红闪截图已查看，实际进入/退出观感pending_user_visual_confirmation。范围不宣称全部地图拥堵布局或所有建筑逐帧原版一致。

## v0.2.8 建筑受损火焰
入口 scripts/buildings/building_damage_fire.gd，由 Building._ready 创建，无战斗伤害逻辑。配置 data/ra2/building_damage_fire.json 来自本机尤复的规则与 artmd；FIRE01/02/03 原版动画保留完整画布，着火点按建筑贴图中心及 DamageFireOffset 对齐。50%血量以下起火，25%以下增加至全部火点（密度为本作独立显示策略）。无着火点的建筑不自动补造；施工/展开/冻结不显示，维修超过50%熄灭，迷雾跟随父建筑，售出/死亡一起释放。读档从既有HP重建，不保存火焰节点。building_fire_regression 渲染专项276项通过，见VERIFICATION；实际观感待使用者确认。

## v0.2.9 间谍实验室与资金结算
原版 rulesmd 的 GATECH Spyable=yes、CCOMAND RequiresStolenAlliedTech=yes（Prerequisite=BARRACKS），PTROOP RequiresStolenThirdTech=yes。目标表原先只含四种建筑，故实验室禁止进入；现增加实验室对应科技。用既有 allied_state 的 stolen_<side>_<RequiresStolen...> 保存，生产统一通过 GameData.unit_production_block_reason(id,state,side) 判定；未传对局状态仍保持锁定，禁止静态GameData跨局泄漏。GATECH的进入、实际造出CCOMAND、对方不共享、PTROOP仍锁定、目标死亡保留、磁盘存读档和新局清空均有覆盖。NATECH/YATECH的映射为未来原版建筑预留，当前未开放苏军/尤里阵营，不把其完整玩法标为已完成。

资金原实现双向64项通过，没有复现用户自渗透反扣半款。新的 Battle.transfer_spy_funds 按victim/thief一次更新双方余额，再发HUD通知，结算前consume间谍，重复同步回调不会再次窃款。allied_state.last_spy_transfer和日志[SpyTransfer]记录双方身份、金额及前后余额；本机提示区区分“窃取+”与“敌方渗透损失-”。未证明用户原现象根因，不擅自归因于普通生产扣费或声称反扣Bug已修复。

回归：spy_money 96、spy_lab 34、spy_infiltration 426（5种建筑8方向，含非网格落点）、production_catalog 1240，合计1796；详见VERIFICATION。渗透外侧最后一步沿用接近实际入口的持续推进条件，仍保持其他建筑/围墙碰撞。没有修改真实存档或打包推送；显示效果pending_user_visual_confirmation。

## v0.2.9.2 间谍普通目标指令伪装
原逻辑仅在 E/技能 allied_disguise 中提供伪装，Battle.force_attack 仍向SPY设置普通攻击目标，鼠标因无有效武器而显示禁止。现在 force_attack 按单位分流：SPY通过AlliedAbilities.use(allied_disguise)复制敌方步兵，其他成员保留原攻击流程；无有效伪装目标时不再给间谍设置追击。普通右键已有敌方目标入口自动覆盖，建筑默认指令仍先按渗透处理。
can_order统一资格：SPY存活、未上车/眩晕/冻结，目标为可见、敌方、存活且未上车的步兵。use在复制前order_stop取消旧移动、渗透和战斗目标；special.disguise只保存unit_id，现有站立/行走纹理、命中测试、队色、警犬识破与快照复用，不替换真实身份或武器。can_attack允许合法伪装目标使用现有原版攻击鼠标图标。伪装技能入口仍保留。
spy_disguise_regression覆盖两模式的真实指令分发、选区混编、模型纹理、非法目标、渗透取消、识破和磁盘存读档；截图已查看，使用者视觉确认尚未收到。关联技能及鼠标专项证据见VERIFICATION。

## v0.3.1 建筑维修动画
Building._ready添加RepairIndicator子节点，scripts/buildings/building_repair_indicator.gd独立读取repairing、repair_waiting_funds、HP、建造/冻结/暂停状态；不推进经济或回血，不新增存档状态。正常循环WRENCH七帧（0.16秒/帧为本作表现适配），缺钱停帧附等待文字，取消/满血时隐藏并重置相位。跟随父建筑可见性，只显示己方维修，不继承房色材质，层级WORLD_HUD+1。以血条同一Iso矩阵定位，原图固定屏幕像素；来源帧间offset保留，裁剪共同原点12,7。
本机Steam WRENCH.SHP/PALETTE.PAL提取器ra2pipe/repair_animation.mjs；资源及SHA256在assets/ra2/ui/repair_animation/source.json。UI维修按钮图标与鼠标动作不变。验证记录见VERIFICATION；未收到使用者视觉确认。

## v0.3.8 特殊机制第一批：世界级闪电风暴

用户暂停“盟军收尾→迷雾/长局→苏联”顺序，先做特殊机制。本节取代上文GAWEAT“状态仍挂在建筑上”的当前状态描述；其余历史验证范围不扩张。

`scripts/world/lightning_storm.gd`由Battle._process推进，权威状态放在既有allied_state.lightning_storms中。每次施放冻结规则、来源阵营、目标、弱引用、独立RNG和时序；Building只充电和发射，旧_storm_*保留为诊断/存档兼容镜像。来源被毁、被卖或失效后，不依赖建筑继续施加双方伤害；来源失效时不给已删除建筑追加经验或反击引用。低电不停止已发射风暴；暂停/结局不推进。不同风暴分别结束，来源仍在时结束后恢复充电。

从本机Steam的expandmd01.mix读取rulesmd.ini，SHA256 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`：LightningDeferment=250、LightningStormDuration=180、LightningDamage=250、LightningHitDelay=10、LightningScatterDelay=5；当前按15逻辑帧/秒。中心/散射按截止时刻顺序执行，起点包含、结束点排除；慢帧跨过蓄势边界继续消费剩余时间。当前调度共18次中心雷、36次散射雷。相同随机种子在15/60Hz及单次大步推进的伤害、随机状态、效果数量一致。此为独立Godot时序适配，不宣称等同原版云层生成后延迟落雷的逐帧行为。

保存复用Snapshot对Dictionary/WeakRef/RandomNumberGenerator的既有支持，无新存档版本或执行对象反序列化。有世界列表时以列表为准（包括空列表）；没有该键的旧档才从建筑镜像迁移，保留蓄势/已开始阶段、已过时间和两类剩余间隔。来源已消失的新档仍恢复；旧版已经丢掉来源及其风暴状态的存档无法追溯补回。随机打点可连续恢复，动画随机款式与已播放音频不要求逐帧复现。

仍未完成：云层生成到落雷的原版分阶段时序、Separation间距、雷达干扰/环境变暗、吸雷针，散射范围仍沿用既有连续地图适配，需要另对原版n×n格范围。GACSPH仍只影响己方地面车辆/舰船、非法落点整批拒绝；敌军、生物致死与传送者例外、危险落点处理待下一批。已核对[Ares Chronosphere文档](https://ares-developers.github.io/Ares-docs/new/superweapons/types/chronosphere.html)的全阵营、KillOrganic和Teleporter条目，但其中含扩展行为，不能直接当作原版引擎源码；本地RA2YR_ReSource的super_weapon.cpp相关静态方法仍为TODO。风暴参数对照[Ares LightningStorm文档](https://ares-developers.github.io/Ares-docs/new/superweapons/types/lightningstorm.html)，本机原规则优先，不翻译未许可实现。

专项覆盖双方、两模式、蓄势/落雷期间死亡或出售、暂停/结局、同时风暴、真实Battle入口、旧档迁移、磁盘读档与全新进程恢复。计时逻辑以自动断言验收；实机云层与落雷观感仍为pending_user_visual_confirmation。详细运行证据见VERIFICATION。

交接：用户随后明确要求“弄完风暴停止一下”。本批验收后停止，没有继续超时空、特殊死亡、坠机或苏联；后续启动须由用户继续指示。
