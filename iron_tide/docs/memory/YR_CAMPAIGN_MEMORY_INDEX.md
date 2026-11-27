# 尤复战役迁移记忆索引

这是项目内战役移植资料的入口。操作流程见 [迁移技能快速入口](../skills/yr-campaign-porting/SKILL.md)（[更新交接](SESSION_2026-11-27_YR_CAMPAIGN_SKILL_FAST_START.md)），既有依据与范例见 [整关迁移规范](YR_CAMPAIGN_PORTING.md)。先读目标关最新交接，再用下面的旧记录找证据；旧试演、后续实装、数据审计及验收结论不能互相替代。每次接手都以当前菜单、Battle、配置和实际运行复核状态。本索引保留相关记录而不重写历史，也不取代单关规格。所有移植与续作都先过[任务触发器与地图 AI 双表门槛](SESSION_2026-11-27_YR_CAMPAIGN_TRIGGER_AI_GATE.md)，并走[分支验收补充](SESSION_2026-11-26_YR_CAMPAIGN_SKILL_REGRESSION_GATES.md)：双基地、替代进攻、卸载、传送演出、清剿标记与废案取证。

| 要查的内容 | 第一站 | 可复用的经验与限制 |
|---|---|---|
| 固定盖特机炮弹道 | [隐形瞬发、空地切换与旧档恢复](SESSION_2026-11-27_GATLING_INVISIBLE_PROJECTILES.md) | 六把空地枪不再画飞行圆点；保留炮口火光和命中特效。峭壁与高差阻挡未实现。 |
| 尤复资金箱拾取动画 | [零售 MONEY.SHP 与三关接入](SESSION_2026-11-27_YR_CASH_PICKUP_FX.md) | 按 `[Powerups] Money` 取动画，只在到账时从箱格单次播放；不改变箱子生成和关卡金额。 |
| 盟军 07 尤里建筑逃生 | [兵种归属修复、12 类建筑回归](SESSION_2026-11-27_ALLIED_FINALE_BUILDING_CREW.md) | 按现有房归属决定逃生兵种；含两座任务超武、两类无逃生防御塔及转属前后。 |
| 谭雅爆破载具 | [载具闪光与零售 Sapper 依据](SESSION_2026-11-27_SAPPER_VEHICLE_FLASH.md) | Sapper 用 Mechanical 即时结算；载具先短亮后播原死亡爆炸，和建筑 C4 倒计时分离。闪光时长为移植近似。 |
| 战役中立居民挡路 | [中立单位避障](SESSION_2026-11-27_CAMPAIGN_NEUTRAL_TRAFFIC.md) | 地面规划纳入可见同层实体的局部临时占位；保留任务角色与碰撞，架空桥面不套用街面规则。 |
| 苏军 01《时空转移》 | [原图触发器](SOV01_TRIGGER_INDEX.md)、[运行复核](SESSION_2026-11-26_SOV01_RUNTIME_AUDIT.md) | 验证时代切换和旋涡断点、工程师到门才转属、失厂和增援；桥边水面舰艇及潜艇用于识别描边回归。`tests/time_shift.tscn`。不与盟军首关混用。 |
| 盟军 02《好莱坞与虚荣》 | [原图触发器](HOLLYWOOD_TRIGGER_INDEX.md)、[原图字段审计](SESSION_2026-11-25_HOLLYWOOD_FIELD_AUDIT.md)、[运行复查](SESSION_2026-11-26_HOLLYWOOD_RUNTIME_REVIEW.md) | 从旧试演到零售地图替换；重点查各房、剧情人物、回收厂和支线、占领工厂、字幕、断桥及分层移动。`tests/hollywood_campaign.tscn`。原图字段盘点不算逐项执行通过。 |
| 苏军 07《首脑游戏》 | [开场解说同步](SESSION_2026-11-27_SOV07_BRIEFING_SYNC.md)、[原图触发器](SOV07_TRIGGER_INDEX.md)、[原图脚本](SESSION_2026-11-25_SOV07_SCRIPT_AUDIT.md)、[实装](SESSION_2026-11-25_SOV07_SCRIPT_IMPLEMENTATION.md)、[运行复查](SESSION_2026-11-26_SOV07_RUNTIME_REVIEW.md) | 整关模板；图外基地车到航点再展开、各房和两翼解放、占领生产、回收路线、核弹井台词条件、短片续音和连续影片断点。`tests/head_games.tscn`。共用敌方资金与 AI 选队间隔等是旧近似。 |
| 盟军 01 `ALL01UMD`《Time Lapse》 | [收尾 20 条任务、2 支地图小队与海崖重烘](SESSION_2026-11-27_ALLIED01_CLOSING.md)、[开场与增援 50 条任务、15 支地图队伍](SESSION_2026-11-27_ALLIED01_MAP65.md)、[驻军与环境 50 条任务、15 支地图队伍](SESSION_2026-11-27_ALLIED01_MAP50.md)、[上批 40 条任务与 20 支地图小队](SESSION_2026-11-27_ALLIED01_MAP40.md)、[上批 30 条任务与 16 支地图小队](SESSION_2026-11-27_ALLIED01_MAP30.md)、[上批 24 条任务与原图舰队](SESSION_2026-11-27_ALLIED01_RETAIL24.md)、[防空 AI 与生产触发器](SESSION_2026-11-27_ALLIED01_AIR_DEFENSE.md)、[装甲、地图 AI、桥梁与全图复核](SESSION_2026-11-27_ALLIED01_DRIVERS_FIELD.md)、[驻军疏散、核电站与抵达通讯](SESSION_2026-11-27_ALLIED01_TRANSITION.md)、[供电、穿越与毁机回归](SESSION_2026-11-27_ALLIED01_POWER_SEQUENCE.md)、[电厂配对接手交接](SESSION_2026-11-27_ALLIED01_PLANT_PAIRS_HANDOFF.md)、[任务驱动名单](ALL01UMD_DRIVER_INVENTORY.md)、[当前脚本漏项](SESSION_2026-11-26_ALLIED01_SCRIPT_GAPS.md)、[医院支线复核](SESSION_2026-11-26_ALLIED01_HOSPITAL.md)、[脚本核查表](ALL01UMD_SCRIPT_RECHECK.tsv)、[装甲任务 AI](SESSION_2026-11-26_ALLIED01_ARMOR_AI.md)、[装甲与谭雅阶段](SESSION_2026-11-26_ALLIED01_ARMOR_GATE.md)、[完整度复查](SESSION_2026-11-26_ALLIED01_COMPLETENESS_RECHECK.md)、[首关原图交接](SESSION_2026-11-26_ALLIED01_HANDOFF.md) | 已有可结算主线；穿越后按难度出两支装甲，清除后才派谭雅。原图触发器 334/334、本图小队 91/91 已接入。各条件的自然可达性、现场验证和既有近似见各批逐项记录。从旧存档验通关不算新开局整关验收。 |
| 盟军 07 `ALL07SMD`《脑死》 | [尤里超武就绪不发射修复](SESSION_2026-11-27_ALLIED_FINALE_SUPERWEAPONS.md)、[开场长时间锁控修复](SESSION_2026-11-27_ALLIED_FINALE_OPENING_LOCK.md)、[验收经验总结](SESSION_2026-11-27_ALLIED_FINALE_ACCEPTANCE_LESSONS.md)、[63 条行动复验](SESSION_2026-11-27_ALLIED_FINALE_AI_ACTION_FOLLOWUP.md)、[84 条 AI 加速矩阵](SESSION_2026-11-27_ALLIED_FINALE_AI_MATRIX.md)、[逐 ID 结果](ALL07SMD_AI_ACCELERATED_MATRIX.tsv)、[补充无头验收：开场、队列断点与交火](SESSION_2026-11-27_ALLIED_FINALE_HEADLESS_FOLLOWUP.md)、[最终验收门槛复核](SESSION_2026-11-27_ALLIED_FINALE_FINAL_GATE.md)、[最后五条任务](SESSION_2026-11-27_ALLIED_FINALE_LAST_FIVE.md)、[收尾 3 条任务／6 条地图 AI](SESSION_2026-11-27_ALLIED_FINALE_CLOSING.md)、[末批全部零售 ID](ALL07SMD_CLOSING_IDS.md)、[此前 30 AI／10 任务](SESSION_2026-11-27_ALLIED_FINALE_BATCH_30AI_10_DRIVERS.md)、[全部 40 个零售 ID](ALL07SMD_BATCH_30AI_10_DRIVERS_IDS.md)、[上批 25 AI／10 任务](SESSION_2026-11-27_ALLIED_FINALE_BATCH_25AI_10_DRIVERS.md)、[可玩预览](SESSION_2026-11-26_ALLIED_FINALE_PLAYABLE.md)、[影片与场景](SESSION_2026-11-26_ALLIED_FINALE_MEDIA_SCENERY.md)、[首末关差距表](SESSION_2026-11-26_ALLIED_PORT_GAP_AUDIT.md)、[首批登陆与车厂 AI](SESSION_2026-11-26_ALLIED_FINALE_ENEMY_AI.md)、[零售脚本缺项复查](SESSION_2026-11-26_ALLIED_FINALE_SCRIPT_RECHECK.md)、[开场转属及返航](SESSION_2026-11-27_ALLIED_FINALE_OPENING_TRANSFER.md)、[88 条盘点](ALL07SMD_SCRIPT_RECHECK.tsv)、[开场帐篷与旗帜显示](SESSION_2026-11-27_ALLIED_FINALE_OPENING_ART.md)、[接管后生产房色](SESSION_2026-11-27_ALLIED_FINALE_PRODUCTION_COLORS.md) | 正式任务表 88/88（含 4 条原图关闭、1 条空动作）；地图 AI 84/84 接入选队。实测范围见最新交接。逐房经济、脚本细节与实景验收仍未完成。`tests/allied_finale_playable.tscn`。 |
| 跨关地形、桥、坡 | [斜坡](YR_SLOPE_PORTING.md)、[桥梁](BRIDGE_PORTING.md)、[画面门槛](TERRAIN_PORT_GATE.md)、[全图审计](SESSION_2026-11-25_NATIVE_BRIDGE_SLOPE_AUDIT.md)、[两关复核](YR_TWO_MISSION_TERRAIN_REVIEW.md) | 零售 TMP 逐格统计、贴图告警实机同机位，以及逐桥上下层、损坏、维修、冷读为不同验收项。平面重采样/分层寻路近似单列。 |
| 战役共用入口 | [菜单选项](SESSION_2026-11-25_CAMPAIGN_PREFERENCES.md)、[难度](SESSION_2026-11-25_CAMPAIGN_DIFFICULTY.md)、[完成标记](SESSION_2026-11-26_CAMPAIGN_COMPLETION.md)、[雷达交互](SESSION_2026-11-26_CAMPAIGN_RADAR_INTERACTION.md)、[CG 收藏](SESSION_2026-11-26_CG_COLLECTION.md)、[回看进度条](SESSION_2026-11-26_CG_REPLAY_SEEK.md) | 首次默认原版配置、普通难度；后续跨关保留选择。已完成仍可出击。雷达、字幕、CG 收藏与胜利奖励分别验，勿用旧断言覆盖现行规则。 |
| 共享美术与现场互动 | [高光范例](SESSION_2026-11-25_YURI_GLOSS.md)、[尤里建筑动画层](SESSION_2026-11-25_YURI_BUILDING_ANIM_AUDIT.md)、[尤里超武待机闪烁](SESSION_2026-11-26_YURI_SUPERWEAPON_FLICKER.md)、[尤里超武提前开盖](SESSION_2026-11-27_YURI_SUPERWEAPON_LIDS.md)、[基因突变器底座缺失：6 号档复现](SESSION_2026-11-27_ALLIED_FINALE_MUTATOR_SLOT6.md)、[驻军火力](SESSION_2026-11-26_CAMPAIGN_GARRISON_FIRE.md)、[中文文案](PLAYER_FACING_COPY.md) | 游戏中验资源加载、着色、房色/描边、建筑转属和终态；单元数据或生成图集不是实际战场证据。 |

下方按主题列出已有专项交接（按文件名排序；同一问题优先读后续修复）。跨主题记录只列一次。性能记录只收与战役机制或地图验收直接相关的条目，其他优化见项目性能索引。

## 三关脚本缺项复查

- [第 25 批苏一继承 AI 的房筛选和警犬编组](SESSION_2026-11-27_THREE_AI_BATCH25.md)记录了 120 条的科技与房门槛、6 条警犬原编制、原房启动依据和冷读结果。
- [第 24 批简单难度售炮与苏一继承 AI 启用核查](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH24.md)：补 `10A9144C`、售前售后冷读，余 8 条任务未接；120 条 AI 更新阻塞依据，未新增启用。
- [第 23 批首次穿越旧机归属与苏一排产一致性](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH23.md)：补 `09601D2C`，余 9 条未接；主副队预算、招募和产线票据复核。
- [第 22 批登陆队与苏一分房产线](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH22.md)：3 条任务；10 条核验后保留未接；165 条继承 AI 返城三档评估取证及分房出厂、冷读。
- [第 21 批时代收尾、返航与逐房 AI 产线](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH21.md)：14 条任务和 74 条既有 AI；任务余 13 待核验，含完整本批 ID。
- [第 20 批航母、运输败北、囚民与基地车](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH20.md)：6 条任务、1 条已有继承 AI，余 26 条待核验、1 条专用链、120 条继承规则未进入评估；含逐 ID 和冷读证据。
- [第 19 批剩余项补接：平民语音、克林特、满电和科技设施 AI](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH19.md)：14 个任务 ID、4 个继承 AI，[逐 ID 清单](THREE_TRIGGER_AI_BATCH19_IDS.md)；剩 32 条待核验、1 条专用链、120 条继承 AI 未进评估。
- [第 18 批时代收尾、三房触发与 AI 产线](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH18.md)：20条任务、73条已有AI，[逐 ID 清单](THREE_TRIGGER_AI_BATCH18_IDS.md)；任务累计635/681，待46。

- [第 17 批三关剧情与队伍权重](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH17.md)：74条任务、39条已有AI，[逐 ID 清单](THREE_TRIGGER_AI_BATCH17_IDS.md)；任务累计615/681，待66。

- [第 16 批苏一后段、好莱坞开场与全局 AI 集结](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH16.md)：66条任务、25条既有AI，[逐 ID 清单](THREE_TRIGGER_AI_BATCH16_IDS.md)；任务累计541/681，待140。

- [第 15 批居民与侧翼、环境音和攻势 AI](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH15.md)：68条任务、41条已有AI，[逐 ID 清单](THREE_TRIGGER_AI_BATCH15_IDS.md)；任务累计475/681，待206。

- [第 14 批好莱坞居民、维修桥与集结](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH14.md)：61条任务、22条已有AI，[逐 ID 清单](THREE_TRIGGER_AI_BATCH14_IDS.md)；任务累计407/681，待274。

- [第 13 批好莱坞侧翼增援、居民与 AI](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH13.md)：62条任务、36条既有AI条件，[逐 ID 清单](THREE_TRIGGER_AI_BATCH13_IDS.md)；任务累计346/681，待335。

- [第 12 批超武、开场队伍与《时空转移》电台](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH12.md)：43条任务、29条既有AI条件，[逐 ID 清单](THREE_TRIGGER_AI_BATCH12_IDS.md)；任务累计284/681，待397。

- [第 11 批《首脑游戏》混编、导览、结算与 AI 资金](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH11.md)：40条任务、44条既有AI条件，[逐 ID 清单](THREE_TRIGGER_AI_BATCH11_IDS.md)；任务累计241/681，待440。

- [第 10 批《首脑游戏》任务与防守 AI](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH10.md)：30条任务、12条既有AI脚本；累计201/681，待480。

- [第 9 批续做：苏一满电、失电与受袭](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH09_FOLLOWUP.md)：新增25条，本轮54条任务、24条AI动作；任务累计171/681，待510。

- [第 9 批返航、工程师与 AI 择敌](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH09.md)：29 条任务部分接入、24 条既有 AI 择敌动作；任务累计146/681，余535。

- [第 8 批供电触发与好莱坞 AI 路线](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH08.md)：8 条任务、12 条 AI 路线；累计任务117/681，余564。

- [第 7 批三图全图验收、触发与 AI](SESSION_2026-11-27_THREE_MAP_TRIGGER_AI_BATCH07.md)：零售710条建筑/灯光清单、51,510格地形、桥修冷读；触发109/681，AI 150/275进入调度或评估。

- [第 6 批任务触发与地图 AI](SESSION_2026-11-27_THREE_TRIGGER_AI_BATCH06.md)：苏一 `08E4940C`、好莱坞 9 条区域警戒；[275 条 AI 台账](THREE_MISSION_AI_COVERAGE.tsv)，任务累计 108/681、待核验 573。

- [待核验触发对照第 5 批](SESSION_2026-11-27_THREE_TRIGGER_AUDIT_BATCH05.md)：苏一海战补舰、固定航点播报、登陆及替补链共 44 条；累计 108/681，待核验 573。

- [待核验触发对照第 4 批](SESSION_2026-11-27_THREE_TRIGGER_AUDIT_BATCH04.md)：零售计时驱动、侏罗纪防守提醒与四条逐 ID 核验；待核验 617。

- [待核验触发对照第 3 批](SESSION_2026-11-27_THREE_TRIGGER_AUDIT_BATCH03.md)：战斗要塞入场与延时报点、侏罗纪随机增援；待核验 621。

- [好莱坞全图预置地基对齐](SESSION_2026-11-27_HOLLYWOOD_FULL_SITE_ALIGNMENT.md)：368座原图建筑和188段墙栏逐条对位，修69座预置敌建筑的找空位偏移。

- [待核验触发对照第 2 批及回收厂错位](SESSION_2026-11-27_THREE_TRIGGER_AUDIT_BATCH02.md)：四厂原地基与标记、两段目标提醒；待核验 634。

- [待核验触发对照第 1 批](SESSION_2026-11-27_THREE_TRIGGER_AUDIT_BATCH01.md)：新增逐条标注 25 项，补首关失败/目标文字计时和第七关地面触发筛选。

- [首关副队与招募、好莱坞卡维利正片和实际追击](SESSION_2026-11-27_YR_SECONDARY_TEAMS_CARVILLE.md)：正确片源、实际拆楼与抵达、追击发令和命中；全局 AI 仍有未解释动作。

- [681 条逐 ID 触发器清单](THREE_MISSION_TRIGGER_COVERAGE.tsv) · [结算链首批接入](SESSION_2026-11-27_THREE_TRIGGER_RUNTIME_PASS.md)：三图结算分支与计时；未核验行不等同未接。

- [三关零售动作链续补](SESSION_2026-11-27_THREE_RETAlL_ACTION_CHAINS.md)：混编目标顺序与全局 AI 数据、片场延时和分房出售、居民房标记与混编字幕；仍非整关完工。

- [三关任务脚本续补](SESSION_2026-11-27_THREE_MISSIONS_SCRIPT_IMPLEMENTATION.md)：首关巡逻及混合反击、好莱坞本图36条AI入表、第七关拆厂释放居民；不是整关完工。

- [三关任务驱动定义计数与缺项口径](SESSION_2026-11-27_THREE_MISSION_SCRIPT_COUNTS.md)：681 个零售触发、458 支编队、306 套行动脚本；本图 AI 和实际漏项分开计。

- [三关设施、受袭支线与媒体复核](SESSION_2026-11-26_THREE_SPECIAL_SITES.md)：首关医院治疗、好莱坞两位演员前置、秘密实验室巨炮、媒体复跑和技能门槛。

- [三图地图验收补测与移植技能门槛](SESSION_2026-11-26_THREE_MAPS_BRIDGE_GATE.md)：十一桥头、三关断桥冷读、贴图告警归组与覆盖层验收。

- [三张零售图逐格复核与墙栏](SESSION_2026-11-26_THREE_RETAIL_MAPS_WALLS.md)：恶魔岛 23 段和缺口，补好莱坞 188 段覆层墙栏及冷读。

- [三关脚本再查：登陆队全灭、维修厂喊话、城堡受袭](SESSION_2026-11-26_THREE_CAMPAIGNS_TRIGGER_PASS3.md)：补接陆上编组全灭和挂钩真实城堡伤害；三关主线复跑。

- [三关 AI、触发、语音和 CG 复查](SESSION_2026-11-26_THREE_CAMPAIGNS_AI_MEDIA.md)：首关登陆突击队及鲍里斯报到、好莱坞六条 AI 条件和喊话、第七关生产房、11 段媒体与收藏。

- [三关零售触发补接与复查（二轮）](SESSION_2026-11-26_THREE_CAMPAIGN_TRIGGER_FOLLOWUP.md)：运输艇替补、四桥维修、回收厂资金箱与遇袭，三关间谍扣款 5%。

- [苏军第七关志愿军漏接与两关复查](SESSION_2026-11-26_SOV07_VOLUNTEER_RECHECK.md)：本关志愿军转属、雷达与生产解锁；复验好莱坞和苏军第一关。

- [好莱坞、苏军一／二关首批补接](SESSION_2026-11-26_THREE_CAMPAIGNS_SCRIPT_GAPS.md)：设施发现与维修、海战编队补援及冷读；苏军二关尚未接入出击。
- [苏军 02 `SOV02SMD` 零售逐条触发器索引](SOV02_TRIGGER_INDEX.tsv)：86 条原图定义，尚未实施或进行玩家流程验收。

- [鲍里斯攻击油桶](SESSION_2026-11-27_BORIS_BARRELS.md)：零售桶型与武器规则，普通/精英步枪及米格分流；盟军首关实战回归。

## 苏军首关

- [苏军 01《时空转移》](SESSION_2026-11-25_SOV01_TIME_SHIFT.md)
- [苏军第一关的坦克碾压围栏](SESSION_2026-11-26_FENCE_CRUSH.md)
- [苏军第一关恶魔岛岸崖](SESSION_2026-11-26_SOV01_ALCATRAZ_CLIFF.md)
- [第一关返回旧金山后五人无法移动（2026-11-26）](SESSION_2026-11-26_SOV01_BASE_MOVEMENT.md)
- [苏军第一关机械维修厂换边颜色](SESSION_2026-11-26_SOV01_CAMACH_COLOR.md)
- [苏军第一关《时空转移》工程师空投刷屏](SESSION_2026-11-26_SOV01_ENGINEER_AIRDROP.md)
- [苏军第一关工程师空投时序](SESSION_2026-11-26_SOV01_ENGINEER_DROP.md)
- [苏军第一关运行一致性复核](SESSION_2026-11-26_SOV01_RUNTIME_AUDIT.md)
- [苏军第一关的简报声音和时空旋涡](SESSION_2026-11-26_SOV01_TIME_VORTEX_AUDIO.md)
- [苏军第一关尤里运输艇登陆修复](SESSION_2026-11-26_SOV01_YURI_RAID_LANDING.md)
- [苏军第一关侏罗纪充能防守](SESSION_SOV01_DINO_CONTACT.md)
- [苏军第一关尤里运输艇出发时间](SESSION_SOV01_YURI_HOVER_TIMING.md)
- [苏军第一关《时空转移》原图事件索引](SOV01_TRIGGER_INDEX.md)

## 盟军好莱坞

- [指挥室关卡简报与其他盟军任务统一](SESSION_2026-11-27_HOLLYWOOD_CAMPAIGN_BRIEFING.md)

- [右上角卡维利将军通讯中文字幕](SESSION_2026-11-27_HOLLYWOOD_CARVILLE_SUBTITLE.md)
- [HOLLYWOOD_NATIVE_FIELD_INVENTORY](HOLLYWOOD_NATIVE_FIELD_INVENTORY.json)
- [HOLLYWOOD_RUNTIME_FIELD_AUDIT](HOLLYWOOD_RUNTIME_FIELD_AUDIT.json)
- [ALL02UMD 零售任务触发器逐条核对索引](HOLLYWOOD_TRIGGER_INDEX.md)
- [好莱坞占领尤里战车工厂](SESSION_2026-11-25_CAPTURED_YURI_FACTORY.md)
- [片场演员招募提示](SESSION_2026-11-25_HOLLYWOOD_ACTOR_HINT.md)
- [洛杉矶守军与片场巡逻](SESSION_2026-11-25_HOLLYWOOD_AI_PATROLS.md)
- [好莱坞全桥与引道核查](SESSION_2026-11-25_HOLLYWOOD_ALL_BRIDGES.md)
- [《好莱坞梦一场》逐栋驻军检查](SESSION_2026-11-25_HOLLYWOOD_ALL_HOUSES.md)
- [洛杉矶建筑动画与任务名册](SESSION_2026-11-25_HOLLYWOOD_ANIMATION_AND_CAST.md)
- [洛杉矶演员应答与盖特射击声](SESSION_2026-11-25_HOLLYWOOD_AUDIO.md)
- [好莱坞桥面车辆接地](SESSION_2026-11-25_HOLLYWOOD_BRIDGE_CONTACT.md)
- [好莱坞第二关车辆从桥边掉层](SESSION_2026-11-25_HOLLYWOOD_BRIDGE_MOVEMENT.md)
- [好莱坞高架桥与科技限制](SESSION_2026-11-25_HOLLYWOOD_BRIDGE_TECH.md)
- [好莱坞资金箱原版航点、实走拾取与到账](SESSION_2026-11-27_HOLLYWOOD_CASH_CRATE_FLOW.md)
- [洛杉矶资金箱拾取（历史）](SESSION_2026-11-25_HOLLYWOOD_CRATE_PICKUP.md)
- [洛杉矶战役的目标闪烁](SESSION_2026-11-25_HOLLYWOOD_CUES.md)
- [洛杉矶任务对白核对](SESSION_2026-11-25_HOLLYWOOD_DIALOGUE_AUDIT.md)
- [洛杉矶武器表现、反应炉及字段核对](SESSION_2026-11-25_HOLLYWOOD_FIELD_AUDIT.md)
- [《好莱坞与虚荣》战场通讯按右上角小地图的实际屏幕区域布局，等比例播放，跳过按钮置于框内。开场长片全屏。通过大厅任务卡进入战场验证小窗与雷达区域一致，按钮在框内，通讯自然结束后车队到场，并走通胜利结算。验证方式为 Godot 无窗口场景回归。日志位于 %TEMP%/it-hollywood-film-layout-final.log。](SESSION_2026-11-25_HOLLYWOOD_FILM_LAYOUT.md)
- [洛杉矶战役原版影片](SESSION_2026-11-25_HOLLYWOOD_FILMS.md)
- [洛杉矶战役的战争迷雾与雷达](SESSION_2026-11-25_HOLLYWOOD_FOG.md)
- [洛杉矶民房进驻与影片字幕](SESSION_2026-11-25_HOLLYWOOD_GARRISON_SUBTITLES.md)
- [好莱坞中立英雄（v0.32）](SESSION_2026-11-25_HOLLYWOOD_HEROES.md)
- [好莱坞首批尤里守军](SESSION_2026-11-25_HOLLYWOOD_INIT.md)
- [好莱坞战役情报总目标](SESSION_2026-11-25_HOLLYWOOD_OBJECTIVES.md)
- [洛杉矶矿区外观](SESSION_2026-11-25_HOLLYWOOD_ORE_ART.md)
- [《好莱坞与虚荣》逐项复核](SESSION_2026-11-25_HOLLYWOOD_PARITY.md)
- [洛杉矶回收厂居民队伍](SESSION_2026-11-25_HOLLYWOOD_QUEUE.md)
- [好莱坞尤里房色与生物反应炉](SESSION_2026-11-25_HOLLYWOOD_REACTOR_PURPLE.md)
- [好莱坞原战役入口替换](SESSION_2026-11-25_HOLLYWOOD_REPLACEMENT.md)
- [洛杉矶战役实装记录](SESSION_2026-11-25_HOLLYWOOD_RETAIL_BUILD.md)
- [洛杉矶片场人物入队后的开火姿态](SESSION_2026-11-25_HOLLYWOOD_SNIPER.md)
- [好莱坞南缘桥头竖条](SESSION_2026-11-25_HOLLYWOOD_SOUTH_BANK_ART.md)
- [好莱坞街道斜坡](SESSION_2026-11-25_HOLLYWOOD_STREET_SLOPES.md)
- [盟军第二关《好莱坞梦一场》单位状态核查](SESSION_2026-11-25_HOLLYWOOD_UNIT_STATES.md)
- [洛杉矶尤里基地](SESSION_2026-11-25_HOLLYWOOD_YURI_SITES.md)
- [好莱坞与虚荣 · 单关试演](SESSION_2026-11-25_YR_HOLLYWOOD.md)
- [盟军好莱坞关卡运行复查](SESSION_2026-11-26_HOLLYWOOD_RUNTIME_REVIEW.md)
- [苏军第七关与好莱坞：触发器索引、TMP 核对与桥梁冷读](SESSION_2026-11-26_SOV07_HOLLYWOOD_FOLLOWUP.md)

## 苏军《首脑游戏》

- [驻军进出与建筑外观](SESSION_2026-11-27_SOV07_GARRISON_POSE.md)：13 类民用建筑原版驻军帧和阴影、战斗碉堡锚点与解放回归。
- [混编替补、独立敌房经济与漏接巡查](SESSION_2026-11-26_SOV07_COMBINE_HOUSE_ECONOMY.md)：01/02 两对伤亡重组、三房余额与冷读；城堡后路雷达修正，回收厂残余动作待补。
- [磁电坦克主副武器磁力波](SESSION_2026-11-26_MAGNETRON_WAVE.md)
- [磁电坦克抬升、空中牵引与落地](SESSION_2026-11-26_MAGNETRON_LIFT.md)
- [尤里心控弧线与显示时机](SESSION_2026-11-26_YR_MIND_CONTROL_LINK.md)

- [《首脑游戏》河心城堡废墟花屏](SESSION_2026-11-25_CASTLE_RUBBLE.md)
- [首脑游戏进场、环境、探索与占领生产](SESSION_2026-11-25_HEAD_GAMES_ENTRY_PRODUCTION.md)
- [第七关房色与首轮接敌](SESSION_2026-11-25_HEAD_GAMES_HOUSES_CONTACT.md)
- [苏军第七关影像与声音](SESSION_2026-11-25_HEAD_GAMES_MEDIA.md)
- [首脑游戏核弹井与铁幕建成时的尤里广播](SESSION_2026-11-25_HEAD_GAMES_NUKE_TAUNT.md)
- [第七关字幕与雷达通讯](SESSION_2026-11-25_HEAD_GAMES_RADAR_SUBTITLE.md)
- [首脑游戏解放卡顿](SESSION_2026-11-25_HEAD_GAMES_RELEASE_PERF.md)
- [苏军第七关《首脑游戏》原图战场](SESSION_2026-11-25_HEAD_GAMES_RETAIL.md)
- [苏军第七关《首脑游戏》](SESSION_2026-11-25_HEAD_GAMES.md)
- [《首脑游戏》中部混编](SESSION_2026-11-25_S07_COMBINE.md)
- [首脑游戏全图建筑和村庄围栏](SESSION_2026-11-25_S07_RETAIL_SITES.md)
- [首脑游戏敌军活动现场核查](SESSION_2026-11-25_SOV07_AI_SAVE_CHECK.md)
- [苏军第七关夜色提亮](SESSION_2026-11-25_SOV07_BRIGHTNESS.md)
- [苏军第七关夜色](SESSION_2026-11-25_SOV07_NIGHT.md)
- [第七关矿场与开局攻势时间核对](SESSION_2026-11-25_SOV07_REFINERY_PACE.md)
- [首脑游戏零售尤里出击脚本核查](SESSION_2026-11-25_SOV07_RETAIL_AI_ORDERS.md)
- [苏军第七关原图脚本缺口](SESSION_2026-11-25_SOV07_SCRIPT_AUDIT.md)
- [首脑游戏任务脚本实装](SESSION_2026-11-25_SOV07_SCRIPT_IMPLEMENTATION.md)
- [第七关尤里战场通讯与工厂](SESSION_2026-11-25_SOV07_YURI_CLIP_CHECK.md)
- [苏军第七关《首脑游戏》运行复查](SESSION_2026-11-26_SOV07_RUNTIME_REVIEW.md)
- [苏军第七关：存档 2 的当前目标](SESSION_2026-11-26_SOV07_SLOT2_OBJECTIVE.md)
- [SOV07 零售任务触发器逐条核对索引](SOV07_TRIGGER_INDEX.md)

## 盟军首末关

- [盟军终关双基地并行建造与冷读](SESSION_2026-11-27_ALLIED_FINALE_PARALLEL_CONSTRUCTION.md)
- [盟军终关双阵营兵营独立切换、出兵与读档](SESSION_2026-11-27_ALLIED_FINALE_BARRACKS_SWITCH.md)
- [盟军终关双基地并列页签与冷热档回归](SESSION_2026-11-27_ALLIED_FINALE_BASE_TABS.md)

- [尤复盟军首末关：零售资料与地形阶段交接（未开放出击）](SESSION_2026-11-26_ALLIED_ENDS_RETAIL_INTAKE.md)
- [盟军终关：补接原版 CG、电台、目标点、雪地图建筑](SESSION_2026-11-26_ALLIED_FINALE_MEDIA_SCENERY.md)
- [盟军终关《脑死》可玩预览](SESSION_2026-11-26_ALLIED_FINALE_PLAYABLE.md)
- [尤复盟军首末关：第一批任务脚本](SESSION_2026-11-26_ALLIED_RETAIL_SCRIPT_SLICE.md)
- [盟军首关《Time Lapse》接续交接：CG、任务、地图、科技与 AI](SESSION_2026-11-26_ALLIED01_HANDOFF.md)
- [盟军首关存档 2：8/8 实档冷读与试玩终点提示](SESSION_2026-11-26_ALLIED01_SLOT2.md)
- [盟军首关 CG 收藏预览补齐](SESSION_2026-11-26_ALLIED01_CG_POSTERS.md)

## 共用战役界面、演出、生产和结算

- [五关开场交控复查与迁移技能门禁](SESSION_2026-11-27_YR_OPENING_HANDOFF_CROSSCHECK.md)：正常帧循环、自然或跳过、雷达折叠、锁控空档、首条命令。

- [苏联原版 RA2 侧栏素材提取与接入](SESSION_2026-11-20_ORIGINAL_SOVIET_UI.md)
- [战役生产栏与占领单位排序](SESSION_2026-11-25_CAMPAIGN_CATALOG.md)
- [战役指挥室第一版设计](SESSION_2026-11-25_CAMPAIGN_COMMAND_DESIGN.md)
- [战役指挥室与通关奖励](SESSION_2026-11-25_CAMPAIGN_COMMAND_IMPLEMENTATION.md)
- [战役选关与重复通关奖励](SESSION_2026-11-25_CAMPAIGN_COMMAND_REWARDS.md)
- [战役指挥室实机排版](SESSION_2026-11-25_CAMPAIGN_COMMAND_VISUAL.md)
- [战役奖励名称和图标](SESSION_2026-11-25_CAMPAIGN_CURRENCY_LABELS.md)
- [战役简报与难度增援](SESSION_2026-11-25_CAMPAIGN_DIFFICULTY.md)
- [战役阵营徽章](SESSION_2026-11-25_CAMPAIGN_FACTION_EMBLEMS.md)
- [战役出击选项记忆](SESSION_2026-11-25_CAMPAIGN_PREFERENCES.md)
- [金门大桥舰队红边回归](SESSION_2026-11-25_CAMPAIGN_RED_OUTLINE.md)
- [战术地图按地形外缘缩放](SESSION_2026-11-25_RADAR_TERRAIN_FIT.md)
- [新增 docs/YR_CAMPAIGN_LAST_BROADCAST.md，设计盟军原创三关短战役。核对 data/maps/yr_catalog.json 的 34 项与三张底图数据。尔湾有 95 条建筑记录，River Rampage 有两个出生点，建筑及桥梁记录为空，特兰西瓦尼亚有可驻军建筑类型。任务设施由关卡另行布置。方案以护送、缴获、反向广播串起剧情，成功救出两车可在第二关获得维修车。本轮交付为设计稿。关卡脚本、坐标可达性、节奏、存读档与跨关奖励待实现和实机验证。](SESSION_2026-11-25_YR_CAMPAIGN_DESIGN.md)
- [2026-11-26 · 战役选关完成标记](SESSION_2026-11-26_CAMPAIGN_COMPLETION.md)
- [战役驻军射程内开火与第七关区域警戒](SESSION_2026-11-26_CAMPAIGN_GARRISON_FIRE.md)
- [六关战役目标点与雷达标记](SESSION_2026-11-26_CAMPAIGN_OBJECTIVE_MARKS.md)
- [战役小地图互动核查](SESSION_2026-11-26_CAMPAIGN_RADAR_INPUT_AUDIT.md)
- [战役小地图：下令、地点闪烁与事件回跳](SESSION_2026-11-26_CAMPAIGN_RADAR_INTERACTION.md)
- [2026-11-27 · CG 收藏按关卡自动排序](SESSION_2026-11-27_CG_CHAPTER_ORDER.md)
- [2026-11-26 · CG 收藏进度条](SESSION_2026-11-26_CG_COLLECTION_PROGRESS.md)
- [2026-11-26 · CG 收藏](SESSION_2026-11-26_CG_COLLECTION.md)
- [2026-11-26 · CG 收藏阵营画廊实装](SESSION_2026-11-26_CG_GALLERY_IMPLEMENTATION.md)
- [2026-11-26 · CG 收藏阵营页签原型](SESSION_2026-11-26_CG_GALLERY_MOCKUP.md)
- [2026-11-26 · 战役 CG 首次收藏奖励](SESSION_2026-11-26_CG_UNLOCK_REWARDS.md)

## 共用桥坡、原生地形与路由

- [桥梁移植交接](BRIDGE_PORTING.md)
- [Bridge bin cache: retain for further acceptance](SESSION_2026-11-23_BRIDGE_BINS.md)
- [远征第26关「破坏补给」单岸维修小屋反馈。按用户确认范围排查全部原创图，不需要具体地图名。civilian_sites.gd 的 populate 与 populate_authored 统一调用 create_crossing，两岸各建 CABHUT 绑定同一 span，开局完整时初始化一次，既有 BridgeDamage.restore 同步双屋状态。通用湖泊生成双岸预留。覆盖 coast/crossings 各2，river_delta 3、lake_ring 2、canal_city 4、ore_frontier 2、exp_fortress 3，共18座。无桥图与原版导入图不变。更新 authored_maps_regression 与 skirmish_coast_regression 断言。git diff --check 无错误；未运行完整 Godot 战场测试。没有旧战场建筑迁移，不修改玩家存档或安装包。](SESSION_2026-11-23_BRIDGE_HUT_REPORT.md)
- [建筑摧毁后的局部路线失效](SESSION_2026-11-24_TERRAIN_REFRESH.md)
- [好莱坞桥口转弯](SESSION_2026-11-25_BRIDGE_STREET_TURN.md)
- [远征第 6 关木桥反馈](SESSION_2026-11-25_HILLS_WOOD_BRIDGE_REPORT.md)
- [科技医院西北崖壁](SESSION_2026-11-25_HOSPITAL_CLIFF.md)
- [尤复全图桥坡核查](SESSION_2026-11-25_NATIVE_BRIDGE_SLOPE_AUDIT.md)
- [重算归因、实车桥层和命令冷读档](SESSION_2026-11-26_BLOCKAGE_REPATH_BRIDGE_REVIEW.md)
- [桥梁范围记录合入与原生网格重建专项](SESSION_2026-11-26_BRIDGE_BOUNDS_MERGE_NATIVE_GRID.md)
- [桥梁局部路径版本记录候选](SESSION_2026-11-26_BRIDGE_ROUTE_BOUNDS_CANDIDATE.md)
- [桥梁局部路径版本候选：带负载与固定桥段对照](SESSION_2026-11-26_BRIDGE_ROUTE_BOUNDS_FOLLOWUP.md)
- [中心九格与尤复阻塞三规则专项](SESSION_2026-11-26_CENTER_NINE_YR_BLOCKAGE.md)
- [当前合入版 P95 与桥梁恢复候选复测](SESSION_2026-11-26_CURRENT_P95_BRIDGE_RESTORE_NEXT.md)
- [原生地形网格快路径：全图矩阵与桥梁回归](SESSION_2026-11-26_NATIVE_STAMP_MATRIX_GATE.md)
- [原生通行填表快路径合入与固定断修图形对照](SESSION_2026-11-26_NATIVE_STAMP_MERGE_EVENT_AB.md)
- [路线重算：桥梁版本缺少局部记录](SESSION_2026-11-26_ROUTE_EPOCH_BRIDGE_ATTRIBUTION.md)
- [尤复三条阻塞规则接入与专项 A/B](SESSION_2026-11-26_YR_BLOCKAGE_INTEGRATION.md)
- [尤复移动阻塞与 Iron Tide 连续避让对照](SESSION_2026-11-26_YR_SEPARATION_COMPARISON.md)
- [地形移植画面验收](TERRAIN_PORT_GATE.md)
- [尤里的复仇斜坡移植](YR_SLOPE_PORTING.md)
- [两关地形纹理告警归组](YR_TWO_MISSION_TERRAIN_REVIEW.md)

## 共用原版 AI、美术、归属与现场互动

- [镭射幽浮吸电与采矿场偷款](SESSION_2026-11-26_DISK_BLACKOUT.md)：采矿场不掉血，实际转账并提示；核电站吸电触发断电，普通车厂吃激光伤害。

- [玩家界面文案](PLAYER_FACING_COPY.md)
- [遭遇战装甲小队策略](SESSION_2026-11-24_YR_AI_TEAMS.md)
- [尤里编队按任务补兵](SESSION_2026-11-24_YR_TASK_RECRUIT.md)
- [心控关系持续连线](SESSION_2026-11-25_ALL_PSYCHIC_LINES.md)
- [鲍里斯空袭冷却核对](SESSION_2026-11-25_BORIS_CD_AUDIT.md)
- [洛杉矶国际机场的占领颜色](SESSION_2026-11-25_CALA05_CAPTURE_COLOR.md)
- [机械维修厂占领涂装](SESSION_2026-11-25_CAMACH_CAPTURE_COLOR.md)
- [机械维修厂的全图维修](SESSION_2026-11-25_CAMACH_REPAIR.md)
- [科技医院的中立标识和占领涂装](SESSION_2026-11-25_CATHOSP_CAPTURE_COLOR.md)
- [洛杉矶民房驻守外观](SESSION_2026-11-25_CITY_OCCUPIED_ART.md)
- [心灵控制塔连线](SESSION_2026-11-25_PSYCHIC_TOWER_LINE.md)
- [奴隶矿工归击毁方](SESSION_2026-11-25_SLAVE_LIBERATION.md)
- [洛杉矶尤里建筑动画检测](SESSION_2026-11-25_YURI_BUILDING_ANIM_AUDIT.md)
- [《首脑游戏》尤里建筑缺层](SESSION_2026-11-25_YURI_BUILDING_LAYERS.md)
- [尤里遭遇战高光复核](SESSION_2026-11-25_YURI_GLOSS.md)
- [鲍里斯空袭恢复：Steam 尤复二进制核对（2026-11-26）](SESSION_2026-11-26_BORIS_NATIVE_RECHARGE.md)
- [通用科技医院占领颜色（2026-11-26）](SESSION_2026-11-26_CATHOSP_CAPTURE_COLOR.md)
- [2026-11-26 尤里单位死亡与飞碟坠毁](SESSION_2026-11-26_YURI_UNIT_DEATH.md)
