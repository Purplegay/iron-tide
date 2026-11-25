# 尤里的复仇 · 盟军与苏联遭遇战对照

2026-11-04。完整回归使用 v0.22.9 工作区快照，随后在 v0.22.14 的独立快照上重跑九国生产、建筑限额、渗透、战略支援、溅射和声音探针。六份结构化结果逐项一致。两次都使用独立玩家目录和无窗口 Godot 4.7.2。

规则来自本机 Steam 尤复 expandmd01.mix 内的 rulesmd.ini，SHA-256 为 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`。渗透分支另对照本地 RA2YR_ReSource 的 BuildingClass::Infiltrate；友伤和生产分流参考社区行为实现 Warhead、Production 和 TechnoRules。源码与实测分开判断，未对原版 EXE 做并排对战或逐帧校时。

## 修复进展

[v0.22.18.2 修复与回归](fixes/v0.22.18.2/README.md) 已复验下表前四项。[v0.22.19.1 修复与回归](fixes/v0.22.19.1/README.md) 已分别复验后三项。下表记录修复前的行为。

[v0.22.19.3 后续复验](fixes/v0.22.19.3/README.md) 补齐了原先超时的飞机弹药、机场指令与 C4 进出建筑三项行为检查。[v0.22.20.1 后续复验](fixes/v0.22.20.1/README.md) 已完成围墙和战略支援的行为与资源检查。至此下方历史表中五个超时专项均已取得无窗口结果，实机视觉仍待确认。

## 有对局证据的问题

| 优先级 | 现象与范围 | 复现与修复验收 |
| --- | --- | --- |
| 高 | 常规攻击把友方目标从范围伤害名单排除。涉及盟军驱逐舰、苏联 V3、无畏与基洛夫。 | 指定敌方目标，在弹着点两侧各放一辆犀牛，距中心均为 9 世界像素。友车四次均损失 0 HP，对侧敌车分别损失 31、122、220、83。四种原弹头均有 CellSpread，未指定 AffectsAllies=no。修复应覆盖普通攻击和强制攻击，同时保留明确禁止友伤的弹头及空地限制。 |
| 高 | 美军空指部与苏联雷达被间谍渗透时，只重置伞兵或侦察机充能，已经探索过的远处地形仍亮。 | 用没有当前视野的已探索点测量，两种雷达渗透后都保留已探索标志，充能由 11 降至 0。法国同模型空指部没有支援技能，能正常清除探索。原版先走雷达重罩分支；应只影响受害方，仍在视野内的区域应保留。 |
| 高 | 同一方能重复生产原版 BuildLimit=1 的建筑。 | 已拥有盟军矿石精炼器 GAOREP、超时空传送仪或天气控制器时，真实建造入口仍分别新增一张订单。精炼器收入按运行中的建筑数累加。苏联工业工厂、铁幕与核弹井已落地时能拦截重复订单，但在已解锁预约、AI 有一座就绪待放置的状态下，AI 请求入口仍接收下一张。需分别验玩家／AI、在建／就绪／落地、出售或摧毁后可重建。 |
| 高 | 同一方两座实验室可各存一发力场护盾，两个苏联雷达可连派两架侦察机。 | 两座设施同时充满。第一座释放后，第二座仍有完整的 300 秒护盾或 240 秒侦察机充能。侦察机可以立即再放；护盾在恢复供电后也可再放，期间没有推进充能。盟苏实验室均复现。应按玩家和支援类型管理充能；美国伞兵已有专门的共享控制逻辑。 |
| 中 | 占领敌方建造厂和战车工厂后，仍只能使用开局阵营的生产目录。 | 美国占苏联双厂后，犀牛被国家限制拒绝；苏俄占盟军双厂后，灰熊同样被拒绝，两个兵种也都不出现在侧栏。需要分开判断生产建筑归属与国家专属限制，保留法国巨炮等真正的国家专属条件。 |
| 中 | 偷来的科技已经记账，但当前兵营没有对应产品。 | 盟军间谍进苏联实验室后 CIVAN 的偷科技条件已经通过，盟军兵营仍拒产；苏联一侧的间谍进盟军实验室后 CCOMAND 同样被苏联兵营拒绝。探针为苏方提供间谍以单测结算。原规则给这两种单位通用 BARRACKS 前置及跨国 Owner，项目把它们各绑在单一阵营。PTROOP 的尤里实验室在仅有盟苏的普通地图没有自然来源，另列为内容范围。 |
| 中 | 两边都有开火无声；同一单位的选中和命令语音仍可能正常。 | 海豹 MP5、谭雅双枪、美国大兵入驻 IFV 后的机枪，有效武器漏传原 Report。苏联鲍里斯 AKM、普通米格 Maverick3、部署直升机 160mm 有 Report，但声音标识找不到可播放文件。六次真实武器播放入口均返回 false 并记一次 miss，美国大兵 M60 对照返回 true。需先补运行时武器字段，再补缺失的声音映射，分别验普通／精英。 |

## 检查范围

九个原版盟苏国家分别进入纯 RA2 模式，设置本阵营完整科技建筑，并为秘密兵种单独授予偷科技状态。对每张兵种卡在实际生产建筑调用 can_queue，再按本机原规则独立核对国家条件。249 个“国家 × 本阵营兵种”组合中，224 个获准、25 个被国别限制拦截，九国均与预期一致。这验证本阵营齐前置时的生产资格，跨阵营与实际获取偷科技另由上表探针覆盖。它不逐项证明每个前置被拆除后的所有排列。

55 种本阵营兵种和 38 种建筑逐项比对原规则的生命、价格与装甲，在此名单中没有发现差异。建筑数包含两座建造场；美国空指部 AMRADR 共用 GAAIRC 身份和模型。93 项均有运行时主体美术，55 种兵种及 36 种可造建筑的侧栏图标均可加载。两座展开产生的建造场没有普通生产卡。上述资源检查只验证可加载，未据此判定动作、挂点或绘制层完整。

| 阵营 | 分类 | 已查对象（运行时 ID） |
| --- | --- | --- |
| 盟军 | 盟军兵营 | 美国大兵 `E1`、重装大兵 `GGI`、警犬 `DOG`、工程师 `ENGINEER`、火箭飞行兵 `JUMPJET`、海豹部队 `GHOST`、间谍 `SPY`、超时空军团兵 `CLEG`、谭雅 `TANY`、狙击手 `SNIPE`、超时空突击队 `CCOMAND`、心灵突击队 `PTROOP` |
| 盟军 | 盟军战车工厂 | 超时空采矿车 `CMIN`、灰熊坦克 `MTNK`、多功能步兵战斗车 `FV`、机器人坦克 `ROBO`、夜鹰直升机 `SHAD`、坦克杀手 `TNKD`、光棱坦克 `SREF`、幻影坦克 `MGTK`、战斗要塞 `BFRT`、盟军机动基地车 `AMCV` |
| 盟军 | 空指部 | 入侵者战机 `ORCA`、黑鹰战机 `BEAG` |
| 盟军 | 盟军造船厂 | 两栖运输艇 `LCRF`、驱逐舰 `DEST`、海豚 `DLPH`、神盾巡洋舰 `AEGIS`、航空母舰 `CARRIER` |
| 盟军 | 建筑与防御（含展开基地） | 盟军建造场 `GACNST`、发电厂 `GAPOWR`、盟军矿石精炼场 `GAREFN`、矿石精炼器 `GAOREP`、盟军兵营 `GAPILE`、盟军战车工厂 `GAWEAP`、空指部 `GAAIRC`、盟军维修厂 `GADEPT`、盟军作战实验室 `GATECH`、机枪碉堡 `GAPILL`、光棱塔 `ATESLA`、巨炮 `GTGCAN`、盟军造船厂 `GAYARD`、超时空传送仪 `GACSPH`、天气控制机 `GAWEAT`、裂缝产生器 `GAGAP`、盟军围墙 `GAWALL`、间谍卫星 `GASPYSAT`、爱国者飞弹 `NASAM`、机器人控制中心 `GAROBO` |
| 苏联 | 苏联兵营 | 动员兵 `E2`、苏联警犬 `SOV_DOG`、苏联工程师 `SENGINEER`、防空步兵 `FLAKT`、磁暴步兵 `SHK`、疯狂伊文 `IVAN`、恐怖分子 `TERROR`、辐射工兵 `DESO`、鲍里斯 `BORIS`、超时空伊文 `CIVAN` |
| 苏联 | 苏联战车工厂 | 武装采矿车 `HARV`、犀牛坦克 `HTNK`、防空履带车 `HTK`、恐怖机器人 `DRON`、V3 火箭车 `V3`、天启坦克 `APOC`、磁能坦克 `TTNK`、自爆卡车 `DTRUCK`、基洛夫空艇 `ZEP`、武装直升机 `SCHP`、苏联机动基地车 `SMCV` |
| 苏联 | 苏联造船厂 | 苏联两栖运输艇 `SAPC`、台风级潜艇 `SUB`、海蝎 `HYD`、巨型乌贼 `SQD`、无畏级战舰 `DRED` |
| 苏联 | 建筑与防御（含展开基地） | 苏联造船厂 `NAYARD`、苏联建造厂 `NACNST`、磁能反应炉 `NAPOWR`、苏联兵营 `NAHAND`、苏联矿石精炼场 `NAREFN`、苏联战车工厂 `NAWEAP`、苏联雷达 `NARADR`、苏联作战实验室 `NATECH`、苏联维修厂 `NADEPT`、哨戒炮 `NALASR`、防空炮 `NAFLAK`、磁暴线圈 `TESLA`、战斗碉堡 `NABNKR`、苏联围墙 `NAWALL`、核子反应炉 `NANRCT`、铁幕装置 `NAIRON`、核弹发射井 `NAMISL`、工业工厂 `NAINDP` |

盟苏警犬在工程内分别为 DOG 与 SOV_DOG，原版分别为 ADOG 与 DOG。国家特殊单位、空降援军、舰载机、V3／无畏弹体、米格和侦察机应区分正常产品与派生物。RA3 扩展兵、尤里常规阵营、战役专用单位不纳入这 55 种的缺兵统计。保留项目已经选定的雷达解锁核子反应炉、建造节奏、矿场造车、AI 收入及独立生产队列。

## 回归与未验证项

共运行 79 个现有专项，63 个全部通过，11 个返回失败，5 个在 44 秒无窗口时限内未返回结果。单个套件内可以同时有逻辑与表现断言。独立探针未计入这些数量。

| 状态 | 专项 |
| --- | --- |
| 全部通过 | `airport_loss`、`allied_abilities`、`american_paradrop`、`asw`、`attack_cooldown_indicator`、`attack_range`、`automatic_defense`、`build_range`、`building_advisor`、`building_animation`、`building_exit`、`combat_load`、`commando_attack`、`construction_transition`、`country`、`defense_fire`、`deployed_attack`、`deployed_traffic`、`economy_ai`、`economy_chain`、`economy_integrity`、`elite_weapon`、`force_fire`、`fortress_speed`、`ggi_skill`、`ground_control`、`infantry_idle`、`lightning_storm`、`miner_unload`、`naval_navigation`、`production_catalog`、`production_clock`、`refinery_traffic`、`repair_depot`、`shipyard_repair`、`skirmish_coast`、`skirmish_operations`、`skirmish_strength`、`skirmish_tactics`、`sonic`、`soviet_advanced`、`soviet_air`、`soviet_completion`、`soviet_defense`、`soviet_naval`、`soviet_reinforcements`、`spy_disguise`、`spy_infiltration`、`spy_lab`、`spy_money`、`strategic_fx`、`strategic_landing`、`superweapon_alert`、`superweapon_sidebar`、`support_buildings`、`temporal_visual`、`unit_capability_audit`、`v3_rail`、`yr_damage`、`yr_death`、`yr_fortress`、`yr_guardian`、`yr_vehicle_death` |
| 含失败断言 | `construction_audio`、`flight_speed`、`fog_rules`、`harvest_fx`、`mcv_opening`、`rules_mode`、`special_mechanics`、`unit_composition`、`yr_baseline`、`yr_robot`、`yr_voice` |
| 无完整结果 | `aircraft_ammo`、`airfield_order`、`c4_entry`、`support_visual`、`wall` |

失败逐类复核如下。

- 雷达渗透的四条失败已用远处不可见的采样点和法国对照独立复现。
- 老断言仍假定双方开局资金相等、扩展机器人生产固定为 15.6 秒、队列科技用军需券购买、RA2 结算不写任何局外统计。当前实际逻辑含 AI 难度资金、不同生产时钟、战略核心科技及共享外观／生产统计，不能由这些失败直接认定战斗收益串模式。技能槽数量与平局结算的预期也需按现行设计重建夹具。
- 幻影和坦克杀手的普通移动检查要求航向误差小于 0.001 弧度。追加采样显示两者均保持移动，没有转成攻击移动，也没有开火，首步沿路点偏转约 0.031 弧度；该失败不能证明它们边走边侧射。
- 飞行速度旧套件固定七种飞机，并按常规飞机速度测试导弹和 RA3 炮艇。22 条失败涉及该名额、V3／无畏弹体和先锋炮艇；本次不能据此判定普通盟苏航空单位飞行速度错误。
- 采矿特效、真实 WASAPI 混音、像素表现及未返回完整结果的场景没有作视觉或听觉验收。声音探针能确认有效武器标识、资源解析和播放入口的返回值，不能证明用户扬声器的实际听感。
- 海豹资料行的 tech_level 与当前尤复原规则不同，但生产入口另读尤复生产规则，九国生产对照中海豹按预期可造。重装大兵和机器人坦克使用有前缀的已接入声音，不能仅凭原名查不到就判成缺音。

本轮复查原始数据在本机 `C:\Users\admin\Temp\iron-yr-both-20261104-114454-362`。可查看 `recheck/production_matrix.json`、`recheck/suspects.json`、`recheck/support.json`、`recheck/splash.json`、`recheck/techsound.json` 与 `recheck/effective_audio.json`。每个现有专项的目录内各有 summary.json 和运行日志。
