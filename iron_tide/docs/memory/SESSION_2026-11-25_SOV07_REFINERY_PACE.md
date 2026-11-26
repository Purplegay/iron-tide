# 第七关矿场与开局攻势时间核对

零售 rulesmd.ini 的 BuildSpeed 为 0.7。GAREFN、NAREFN 各 2000，均需电力和对应建造厂，各附一辆矿车。sov07.map 未覆盖这两座建筑的耗时。

按 GameData.ra2_build_time、BattleClock.production_scale 和 Battle.structure_work_rate 静态核算，单建造厂、正常供电资金、默认一倍速下，两边基础工时同为 84。盟军矿场按 max(84/4,20) 得到 21 秒，苏军矿场按 84/2 得到 42 秒。盟军电厂为 10 秒，苏军电厂为 12.6 秒。展开后立即造电厂接矿场，纯队列耗时分别为 31 和 54.6 秒。首队在展开后第 45 任务秒出发。首笔矿款还涉及建筑放置、矿车往返等。实际交火及入账时刻待实局测量。

本次为数据和代码核查，记录入口在 scripts/rules/battle_clock.gd、scripts/world/battle.gd、scripts/world/head_games.gd。
## 修复与队列验证

BattleClock.production_scale 中 NAREFN 与 GAREFN 共用生产速度档，按各自规则造价推导工时。Godot 4.7.2 在隔离用户目录运行 tests/war_factory_timing_regression.tscn，两个模式、两个阵营的矿场与战车工厂独立开局，48/48 通过，exit 0，标准错误为空。生产卡显示 21 秒，真实建筑队列推进到 10.5 秒扣 1000，20.9 秒仍在建，21 秒可放置，共扣 2000。日志与 result.json 在 %TEMP%/IT-refinery-20261125-224543。测试逐段推进队列，范围到可放置为止；第七关首车卸矿和首轮交火仍属实局观测范围。
