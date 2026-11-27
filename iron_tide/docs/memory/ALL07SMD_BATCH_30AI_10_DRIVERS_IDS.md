# 《脑死》本批完整零售 ID 对照

本图零售 `ALL07SMD`，对照 [任务双表](ALL07SMD_SCRIPT_RECHECK.tsv) / [AI 双表](ALL07SMD_AI_RECHECK.tsv)。以下实战均为无头夹具推进，不等于逐条自然游玩。

## 任务：10 条正式驱动（部分动作近似）

| 零售 ID | 原名 | 条件（原始 Events 字段） | 现场效果与验证范围 |
|---|---|---|---|
| 0DE26E5C | Camera_Start | `1,13,0,0` | 实际开场：初始镜头、揭雾、雷达简报与局部变量；非原镜头逐帧 |
| 0DE1124C | Send_Engineer1 | `1,13,0,1` | 实际开场：界外运输机空降 5 名工程师 |
| 06C3397C | Change_to_USSR | `1,13,0,0` | 进入开场驱动且留转属标记；Special 未整房转属，仍以工程师实际接管为准 |
| 0DE086AC | Follow_Engineers | `1,13,0,10` | 实际开场：镜头转向工程师区域；非持续跟拍 |
| 094E805C | Eva_Briefing | `1,13,0,25` | 实际开场：简报以内嵌原声播放，原图动作启用交控 |
| 0BB2E0FC | Control_Return | `1,13,0,38` | 实际开场：雷达结束且伞兵落地后播报并交还操控 |
| 0E6533EC | Control_Offline | `1,13,0,1` | 实际开场触发；未单独听验 EVA 原声 |
| 08E97BEC | Irritate_Player | `1,32,0,27` | 实际战场：无超时空传送仪不启用；拥有设施后启用挑衅 |
| 08E9757C | Irritate_Player2 | `1,13,0,0` | 实际战场：播放尤里原声并招募现有飞碟，攻击移动代替完整 ScriptType |
| 04E8103C | Arabs_Hate_Player | `1,13,0,5` | 实际战场：启用 Arabs 登陆敌对门；无预置 Arabs 对象，不复刻通用外交矩阵 |

## 地图 AI：30 条正式选队

计数比较保留本批条件 0/1 与原图 `>=` 计数阈值；0 计玩家、1 计己房是本运行层适配。难度从左到右为简单／普通／困难，1 表示启用。使用当前工厂目录、科技检查、编队和出击适配；没有逐条复刻基地防卫、原脚本择敌或权重回写。

| 零售 ID | 原名 | 房 | 条件与计数 | 难度／权重 | 编队 | 验证 |
|---|---|---|---|---|---|---|
| 09592B4C | Yuri_BD_2 | YuriCountry | 1: YABRCK ≥ 1 | 1/1/1／20 | TELE ×1、YTNK ×2、VIRUS ×1、YURI ×2 | 选队接入，未逐队实测 |
| 095929FC | Yuri_BD_3 | YuriCountry | 1: YACNST ≥ 1 | 1/1/1／20 | YTNK ×2、BRUTE ×4、YURI ×2 | 选队接入，未逐队实测 |
| 0931E6FC | Africa_BD1 | Yuri2 | 1: YAPOWR ≥ 0 | 1/1/1／30 | LTNK ×3、YTNK ×2、TELE ×1 | 选队接入，未逐队实测 |
| 0931E5AC | Africa_BD2 | Yuri2 | 1: YAPOWR ≥ 0 | 1/1/1／30 | LTNK ×2、TELE ×1、MIND ×1、INIT ×3 | 选队接入，未逐队实测 |
| 0931E45C | Africa_BD3 | Yuri2 | 1: YAPOWR ≥ 0 | 1/1/1／30 | YURI ×2、TELE ×1、MIND ×1、YTNK ×3 | 选队接入，未逐队实测 |
| 0931CC3C | Africa_AntiTank2 | Yuri2 | 0: HTNK ≥ 3 | 1/1/1／50 | LTNK ×3、YTNK ×2、TELE ×1、MIND ×1 | 选队接入，未逐队实测 |
| 0931CAEC | Africa_AntiTank3 | Yuri2 | 0: SREF ≥ 2 | 1/1/1／60 | LTNK ×5、TELE ×1 | 选队接入，未逐队实测 |
| 0931C99C | Africa_AntiTank4 | Yuri2 | 0: BFRT ≥ 1 | 1/1/1／70 | BRUTE ×3、YURI ×2 | 选队接入，未逐队实测 |
| 0931C84C | Africa_BA1 | Yuri2 | 0: NASAM ≥ 1 | 1/1/1／50 | LTNK ×3、TELE ×1、MIND ×1 | 选队接入，未逐队实测 |
| 0931C6FC | Africa_BA2 | Yuri2 | 0: GATECH ≥ 1 | 1/1/1／60 | YURI ×2、YTNK ×3、LTNK ×3 | 选队接入，未逐队实测 |
| 0931C5AC | Africa_BA3 | Yuri2 | 0: ATESLA ≥ 1 | 1/1/1／50 | MIND ×1、LTNK ×3、YTNK ×2、TELE ×1 | 选队接入，未逐队实测 |
| 09FA77CC | Yuri_AntiIFV1 | YuriCountry | 0: FV ≥ 3 | 1/1/1／70 | LTNK ×4、MIND ×1、YTNK ×2 | 选队接入，未逐队实测 |
| 0931C1BC | Africa_AntiIFV1 | Yuri2 | 0: FV ≥ 3 | 1/1/1／60 | LTNK ×4、YTNK ×2、MIND ×1 | 选队接入，未逐队实测 |
| 087AD90C | Africa_AntiFlak1 | Yuri2 | 0: HTK ≥ 1 | 1/1/1／50 | LTNK ×4、YTNK ×2、MIND ×1 | 选队接入，未逐队实测 |
| 087AB06C | Africa_AntiConscript1 | Yuri2 | 0: E2 ≥ 1 | 1/1/1／40 | VIRUS ×2、INIT ×4 | 门槛、实际下单扣费、6 人出厂接令；未测抵达交火 |
| 087AE07C | Africa_AntiTesla1 | Yuri2 | 0: SHK ≥ 1 | 1/1/1／50 | YTNK ×2、VIRUS ×1 | 选队接入，未逐队实测 |
| 087CD83C | Africa_AntiV3_1 | Yuri2 | 0: V3 ≥ 1 | 1/1/1／60 | LTNK ×5、TELE ×1 | 选队接入，未逐队实测 |
| 087CD63C | Africa_AntiApoc1 | Yuri2 | 0: APOC ≥ 1 | 1/1/1／70 | BRUTE ×3、YURI ×2 | 选队接入，未逐队实测 |
| 087CF0BC | Africa_FlakCannon | Yuri2 | 0: NAFLAK ≥ 1 | 1/1/1／40 | LTNK ×3、TELE ×1、MIND ×1 | 选队接入，未逐队实测 |
| 087CF34C | Africa_SovBLab_1 | Yuri2 | 0: NATECH ≥ 1 | 1/1/1／60 | YURI ×2、YTNK ×3、LTNK ×3 | 选队接入，未逐队实测 |
| 087CFBBC | Africa_TeslaCoil_1 | Yuri2 | 0: TESLA ≥ 1 | 1/1/1／60 | MIND ×1、LTNK ×3、YTNK ×2、TELE ×1 | 选队接入，未逐队实测 |
| 0968B30C | Africa_AntiPCannon | Yuri2 | 0: ATESLA ≥ 1 | 1/1/1／500 | TELE ×3 | 选队接入，未逐队实测 |
| 091A884C | Yuri_AntiConscript_1 | YuriCountry | 0: E2 ≥ 1 | 1/1/1／30 | VIRUS ×2、INIT ×4 | 选队接入，未逐队实测 |
| 091ADA5C | Yuri_AntiShock_1 | YuriCountry | 0: SHK ≥ 1 | 1/1/1／40 | INIT ×5、YURI ×1 | 选队接入，未逐队实测 |
| 091AD90C | Yuri_AntiShock_2 | YuriCountry | 0: SHK ≥ 1 | 1/1/1／40 | YTNK ×2、VIRUS ×1 | 选队接入，未逐队实测 |
| 079CEEDC | Yuri_BA_4 | YuriCountry | 0: GAWEAP ≥ 1 | 1/1/1／500 | LTNK ×2、TELE ×2、YTNK ×2、MIND ×1 | 选队接入，未逐队实测 |
| 0A6B550C | Yuri_AntiTank_3 | YuriCountry | 1: YAPOWR ≥ 1 | 1/1/1／60 | BRUTE ×3、YTNK ×2、LTNK ×2 | 选队接入，未逐队实测 |
| 09505C9C | Yuri_AntiRT_1 | YuriCountry | 0: ROBO ≥ 5 | 1/1/1／500 | LTNK ×3、YTNK ×2 | 选队接入，未逐队实测 |
| 0950E05C | Yuri_AntiRT_2 | YuriCountry | 0: ROBO ≥ 3 | 1/1/1／70 | INIT ×6、YTNK ×2 | 选队接入，未逐队实测 |
| 0950D05C | Yuri_AntiRT_3 | YuriCountry | 0: ROBO ≥ 5 | 1/1/1／500 | INIT ×4、BRUTE ×4 | 选队接入，未逐队实测 |
