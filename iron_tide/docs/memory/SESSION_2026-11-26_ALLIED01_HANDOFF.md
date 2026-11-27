# 盟军首关《Time Lapse》接续交接：CG、任务、地图、科技与 AI

## 先确认接的是哪一关

本关为《红色警戒2：尤里的复仇》美国房的盟军任务 01，零售 Steam `mapsmd03.mix / ALL01UMD.MAP`（`0x3a6f0ac2`），本轮重新计算地图 SHA-256：`dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`。不是已可玩的苏军 `yr_time_shift`，也不是已开放试玩的盟军 `yr_allied_finale`。本轮只做接续交接、原图和入口复核，不改运行时代码，不开放出击，不碰现存的并行改动或玩家档。

- 零售提取、候选地形及审计目录：`.validation/allied-ends-20261126/`，原图 `source/all01umd.map.map`，关联索引 `audit/yr_all01umd_index.json`，地图/坡面在 `bake/`。目录不保证随 Git 分发；重建命令见 [零售资料与地形](SESSION_2026-11-26_ALLIED_ENDS_RETAIL_INTAKE.md)。
- 现有运行切片：`data/ra2/allied_script_slice.json`、`scripts/world/allied_retail_script.gd`，首关只有 **9 条触发器**，尚未接首关实际 Battle；既有 137/137、冷读 39/39 为首末关切片夹具合计，不是美国首关可玩验收。参见 [脚本切片](SESSION_2026-11-26_ALLIED_RETAIL_SCRIPT_SLICE.md)。终关 [试玩接入](SESSION_2026-11-26_ALLIED_FINALE_PLAYABLE.md) 可参考实际出击、占领和快照接线，不沿用其共用 enemy、简化开场和清敌胜利。
- 本轮重新核对了 334/334 条关联触发器动作列分段（每条实际动作数与表头一致）；是资料结构检查，不代表执行语义或实机覆盖。原图还有 278 条格触发标签记录、102 队伍、91 份编组、94 套命令脚本、62 个局部变量；需按正常流程及分支判定哪些真正可到达。

## 玩家流程与原图锚点

| 玩家看到或做什么 | 零售依据、接入要求 |
|---|---|
| 从战役菜单出击，看全屏影片，再看岸炮/金门桥/航空和时光机导览 | `Basic.Intro=A01_F00e`；`Camera_Start 08A77A5C` 从 HomeCell 14 起，含 `EVA_EstablishBattlefieldControl`。桥镜头 `0972981C`、战机 `0C077BCC`、基地 `0B0246CC`、时光机 `0B022DEC`。`Load_Engineer 06C7108C` 连接玩家始发工程师队 `0D3FA93C`（`O`）。实际验出击、图外入场、何时能下令；不要直接在境内摆一队替代。 |
| 用工程师占领电厂，听到供电提示；敌人夺回、设施受袭或被拆时目标变化 | 8 座 `CAPOWR01..08` 属 PowerHouse，各 `Power=200`、`Capturable=yes`、`TechLevel=-1`、共用 `Image=CAPOWR`，不能合并成一种任务身份或混进同房 12 座普通 `GAPOWR`。`Power_Online 0691357C` 同时要求本地图局部变量 49（有任务电厂）和事件 58（全供电），不是凭电厂数量直接推进。`0617D71C` 是被攻击提示；`0617xxxx` 一系有难度及逐座损失分支，`06178D0C` 才有失败动作。实际进入门口完成工程师转属才给电；测试掉电、重占、多损失、攻击但未摧毁；不要套固定占领数。 |
| 供电后雷达换属、护住时光机，进入过去 | `0691357C` → `0BE0B26C` 雷达转属、`0A8E573C` 启动计时、`0A8EA21C` → `0C6F847C` 居中机器、`0A8E0E9C` 执行转移序列（40 号航点及一组原始动作）；计时字段须按各事件与动作的零售语义复核，不把事件字段互相相加当实际时长。`0DC53EFC` 是 Confederation 的 `TEAM_Nuke_Repair`，不赠给玩家。`0930470C` 检查变量 48，条件满足时在 `NA` 补放 `NANRCT`。快照保存时代、场景身份、编组、计时、影片断点及锁控；验证过渡前、过程中、后的独立冷读，不重生已执行对象。 |
| 谭雅进入战场，向恶魔岛进攻；损失她时仍可能有替代路线 | `Enter_Tanya 0AC85F3C` 用 `088C1A4C / PE` 三星谭雅并播游泳提示。`089B82BC` 记录死亡并启用 `0BA104BC`；在死亡和已穿越两局部变量成立后，生成 `08071C8C / CQ` 的航母替代编组，另有后续航母链。`08A3E03C` 是穿越前时光机毁坏提示动作；真正失败的 `08707A2C` 还检查时代、谭雅和关联对象/启停，必须实测组合，不能把单独谭雅死亡或看到爆炸直接判负。电厂工程师补援另查 `08E568DC` → `0908B07C`（`EN`→`EM`）→ `090AB04C`。 |
| 摧毁恶魔岛的心灵控制器，庆祝后结算 | 开局原图 Structures 记录为 Confederation `YAPPET`（46,69），而 Confederation 基地节点和 `089EC19C`／`0BD6117C` 的事件参数写 `YAPPPT`，必须分身份处理并追实际替换/重建条件；`0B8A090C` 生产启动、`0BD650AC` 启用后置检查。胜利是启用 `089ECDEC` 庆祝和 `089EC79C` 延迟结算，不是清屏，也不在穿越时提前结算。玩家提前出手、控制器重建、庆祝中存读档都要测。 |

## CG、通讯、字幕及目标点

- `a01_f00e.bik` 已定位在 `movmd03.mix`（成员 `0xf21d4216`），本轮未正式导入。原图 `Brief/Win/Lose/PostScore=<none>`，不造片尾、不用苏军简报占位。战中有两处 **动作 100**：`0B0246CC` 参数 **2**，`05E9106C` 参数 **4**。`0885DE3C` 的 **动作 21** `A01_p01` 是独立语音索引，不能当成影片文件名证据。下轮从零售视频表和容器对出实际 Bink 名、长度、声音，再查 `evamd.ini` / `soundmd.ini` 与音频索引；当前未确认两段影片文件名。
- 已定位对白键：`A01_p01`、`Mis_xA1_EvaMorePower`、`Mis_xA1_EvaPowerAttkWarn`、`Mis_xA1_EvaProtectTimeMach`、`Mis_xA1_TanyaSwimHint`、`EVA_ReinforcementsHaveArrived` 等。区分 EVA 发言、电台小窗台词和任务文字（`MISSION:GetPower`、`MISSION:Objective1`、`MISSION:Alcatraz`、`MISSION:Attack3`）；为真实音轨做中文时间轴，不拿目标文字代替字幕。
- 从游戏界面验全屏自然结束和跳过、转小窗前后的交控、雷达小窗不挡操作、短画面后长续音时画面和字幕仍在；至少在全屏中、小窗挂载前间隙、小窗续音中分别存档并独立进程冷读。CG 收藏只登记本关实际影片，核对既有进度与收录规则，不和终关互串。
- 接 `scripts/ui/campaign_objective_marks.gd` 和共用雷达入口。按阶段提供：开场只显示当前导览点 → 已被简报公开且仍需占领的任务电厂 → 被攻击电厂或守卫时光机 → 转移清掉旧时代界面标记/回跳 → 恶魔岛控制器及必要的已公开目标 → 结算撤标。原图有按航点 55 的雷达事件及 41 等导览动作，先对应原图公开条件（例如 `090AB04C` 工程师到达时指向 `EM`），持续中文菱形是项目补充，不揭雾、不当成攻击目标、不提前显示过去时代单位。测试点击定位、撤标、雷达停用和冷读重算。

## 建筑、地形、科技封锁、AI

- **场景**：NEWURBAN，`LocalSize=12,5,47,100`，9400 格中 981 坡格；此前候选逐格对照零售 TMP 数据无差异。276 航点有 22 个在界外，不能裁掉脚本入口。原图 189 建筑、18 车辆、56 步兵、230 Terrain 记录、Aircraft 表空（不代表没有航空演出）。`CATIME01` 在 (91,105)、开局是 Americans；同期开场有四门 `GTGCAN`、兵营 `GAPILE`、战车工厂 `GAWEAP`、两座 `GAREFN`、`GAOREP`、`GASPYSAT`，Americans 的 Structures 未找到 `GACNST`。不要塞默认建造场或默认基地车。逐项核对任务建筑独立 ID、耐久、朝向、标签、归属和高光，而非仅检查模型出现。
- **金门桥**：标准桥 overlay 和 CABHUT 为零，不等于没有桥。BridgeHouse 七个专用建筑沿移植 u=58，v=39（界外）、42、45、48、51、54、57，依次 `CASANF14/13/12/04/11/10/09`，初始血量 256/256/256/64/64/0/64（上限 256）；`092AF4AC` 检查 `CASANF10`，`07A89E6C` → `07A89C0C` 的连锁另查标签和对象，此处不能套通用维修小屋。逐端查原图 bridge deck / 路缘、海面层、遮挡、道路终点、真实跨步越断口、脚本损毁和存读档；修复是否可用先查零售。候选坡图高差扫描 715 格，79 个告警格、16 组（`audit/yr_all01umd_texture_groups.json`），无已知回归命中不等于目检通过。逐组对照实际加载纹理、坡两端与道路，记录近似和漏验。
- **科技封锁**：Americans `TechLevel=3`（DarkBlue、IQ=0）；其他房按各自类型/级别，不用第 2 关的 10 级。`CAPOWR0*=-1` 不可造但可占，`GTGCAN=7` 已放置但不可生产／不可占领，地图改造其火力（`GrandCannonWeapon` 30 格、最小 3、伤害 150），`GASPYSAT=9` 虽不能造但已有／可转属，地图覆盖 `Radar=yes,SpySat=no,Power=-1`，不能当全开图卫星；`TANY=9`、`AMCV=10` 的零售生产门槛不挡任务直接生成。`ORCA` 本图覆盖为 3 级、用 `FALC`，仍需雷达与可用飞机生产设施，不能看等级就显示可造。`ENGINEER` 1 级依赖兵营。用 `GameData.mission_production_tech`／`mission_product_block_reason` 和真实 Battle 生产入口，同时检验卡片、可用工厂、阵营/原产国约束、前置、扣费/队列/出厂、占领与失厂后卡片及建筑落点。所需前置已占有时与“不能建造该前置”是两件事；也不要利用 `TechLevel=-1` 把地图预置物/任务援军误删。现有 `mission_tech_block_reason` 只在负等级显式写进 overrides 时拦截，本图配置勿漏填。
- **AI**：17 个房；Americans/Alliance/British 深蓝，Confederation 紫，PowerHouse/BridgeHouse 灰，French/Special/Soviet2House 深红等，关系按原图和动作转属，不按颜色判断敌友。原图 `IgnoreGlobalAITriggers=no`，本图 AITriggerTypes **0**，AITriggerTypesEnable **165 条皆 yes**；依赖零售全局 AI 表与实际房能力，不能把 165 条当已接入的波次，或因本图定义为零就关 AI。先查哪些房何时启用出击/生产、各自经济、可用队伍、队伍来源（地图现身/建队/空投/实际生产），再接 ScriptType 的航点、护送、攻击、回收及难度，验证抵达和交火、取消、失厂、目标被提前拆、各阶段冷读。原图开场、逐座电厂、航空和时代切换均有专有脚本事件，通用遭遇战 house AI 不应擅自出兵或抢占活动。

## 下一批落地与验收顺序

1. 优先做独立首关战场入口与原图两阶段状态容器：正式地图/带身份的建筑/房/舰与飞机入场，CG/语音链和开场交还控制；不触碰正在修改的苏军 `time_shift*` 和盟军 07 文件。此时仍用隐藏测试入口，不提前把首关标成完成。
2. 接电厂、工程师、雷达和时间跳转、标记、建筑与生产限制；从真实工程师右键到转属和电力净值，从 HUD 实际生产，测断电/丢厂和读档。任务世界作用和切片动作确认同一保存边界或有幂等记录。
3. 接时代切换、谭雅与替代路线、控制器、原图巡防和全局 AI 条件、失败与延迟结算。三难度各走实际玩家出击，早拆、失机、谭雅死亡、断桥、援军卡在界外都测。记录夹具推进与自然游玩差异；默认隔离无头，有头逐组场景及媒体验收先征求同意。新增单位/建筑及动画层按规范验高光，新增单位交付中文名实机截图。

复用记录：[总规范](YR_CAMPAIGN_PORTING.md)、[苏军首关运行复核](SESSION_2026-11-26_SOV01_RUNTIME_AUDIT.md)、[首脑游戏科技与媒体冷读](SESSION_2026-11-26_SOV07_RUNTIME_REVIEW.md)、[雷达续音和字幕](SESSION_2026-11-25_HEAD_GAMES_RADAR_SUBTITLE.md)、[好莱坞对白](SESSION_2026-11-25_HOLLYWOOD_DIALOGUE_AUDIT.md)、[目标点](SESSION_2026-11-26_CAMPAIGN_OBJECTIVE_MARKS.md)、[雷达操作](SESSION_2026-11-26_CAMPAIGN_RADAR_INTERACTION.md)、[好莱坞科技](SESSION_2026-11-25_HOLLYWOOD_BRIDGE_TECH.md)、[占领生产目录](SESSION_2026-11-25_CAMPAIGN_CATALOG.md)、[战役难度](SESSION_2026-11-25_CAMPAIGN_DIFFICULTY.md)、[好莱坞巡逻](SESSION_2026-11-25_HOLLYWOOD_AI_PATROLS.md)、[首脑游戏零售 AI](SESSION_2026-11-25_SOV07_RETAIL_AI_ORDERS.md)、[CG 收藏](SESSION_2026-11-26_CG_COLLECTION_PROGRESS.md)、[坡](YR_SLOPE_PORTING.md)、[桥](BRIDGE_PORTING.md)、[地形画面](TERRAIN_PORT_GATE.md)。

本轮未做引擎、图形、游戏内播放、生产、AI、逐桥通行、完整冷读或发行验证。上轮候选逐格审计和切片夹具结果仅引用为前序证据。
