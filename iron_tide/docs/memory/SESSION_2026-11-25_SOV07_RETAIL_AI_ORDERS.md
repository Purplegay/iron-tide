# 首脑游戏零售尤里出击脚本核查

读取本机提取的 `%TEMP%/IronTide-S07-retail/sov07.map`，SHA-256 为 `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`。Basic 设置 IgnoreGlobalAITriggers=yes。本图 AITriggerTypes 给出房号、条件、初始及上下限权重和各难度开关。按规则的队伍 ID 连接 TeamType，再分别取 TaskForce 与 Script。举例的 AI_YInfantry_M01、AI_YBombard_01、AI_YDisc_01 均在 AITriggerTypesEnable 标为 yes。

* AI_YInfantry_M01 的队伍 08FFCDEC 包含 4 INIT、1 YURI、1 VIRUS，动作依次为 0,4 / 49,0 / 0,5 / 0,1。
* AI_YArmor_E01 的 4 LTNK 使用 09E4BDBC，依次为 54,0 / 53,0 / 49,0 / 0,7 / 0,5 / 0,1。
* AI_YBombard_01 对应 NATECH 数量至少一座，普通与困难开启。08CCADBC 行动表含 16,65，随后为 53,0 / 49,0 / 0,5 / 0,4 / 0,1。
* AI_YDisc_01 为 2 DISK，普通与困难开启，Script 0921D2BC 执行 54,0 / 0,9 / 46,131087 / 0,2。

`%TEMP%/hol-media-rulesmd.ini` 中 TeamDelays=2000,2500,3500，AITriggerSuccessWeightDelta=20，AITriggerFailureWeightDelta=-50。原图未覆盖 TeamDelays。上述值为配置值，原版实时时间及当局选中频率待实测。

当前 head_games_orders.gd 的 dispatch 按条件和初始权重选队，每房号一个未完成任务。advance_production 给完成的进攻队统一下达一次对 _player_target() 的攻击移动。该入口省略了原图各队脚本的目标顺序。核查范围是零售文件与移植源码，未启动原版对局或更改运行逻辑。玩家存档现场另见 SESSION_2026-11-25_SOV07_AI_SAVE_CHECK.md。
