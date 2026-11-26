# 首脑游戏敌军活动现场核查

只读核对本机 battles 中同一 match_id 的 quick、slot3、auto 及 auto.bak。按 ITSAVE01 内的 head_media_clock 读取任务秒，核对 s07_ai_jobs、成员引用、待产兵种、首轮进攻阶段与解放标志。约 403 秒三个房号都有待产队，约 1335 秒有尤里车辆待产，约 1455 秒有 V3、HTK 待产及两个成员引用。后两个快照均已有 head_games_freed_1 和 s07_no_yard_1。最新快照 head_attack_stage=4、head_attack_done=true。快照可以证明选队与集结，无法据此计算抵达或交火次数。

核对 scripts/world/head_games.gd 的 attackers/team 与 head_games_orders.gd 的 tick/dispatch/advance_production。首轮之后，三个房号每 125 任务秒获得一次选队机会，已有组队任务则跳过。编队有在产成员时继续等，完成后才分别执行警戒或向目标点攻击移动。battle.gd 的 _player_target 在敌军未发现玩家建造场时回退至初始集合点。未重放该局的行军轨迹，无法判断有多少队走空、堵路或中途被击毁。本次仅诊断，无运行时代码、打包或玩家存档改动。原图表与既有实机覆盖见 SESSION_2026-11-25_SOV07_SCRIPT_IMPLEMENTATION.md 和 SESSION_2026-11-25_HEAD_GAMES_HOUSES_CONTACT.md。
