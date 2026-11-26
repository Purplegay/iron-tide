# 《首脑游戏》中部混编

依据本机 mapsmd03.mix 提取的 sov07.map、rulesmd.ini 和 ts-ra2 的 ElapsedTimeCondition、RandomDelayCondition、TriggerActionType。旧项目在实验室或难度计时达到时只播 xs7so01。原图该条件启用 Combine 01/03，原声警告由 01 的会合触发。01 与 02 各一辆 FV 配 SHK，03 的补兵编组为 HTK、三名 SHK、一名 FLAKT 和一名 IVAN，对应五辆 FV。原图路点 69=94113、70=98114、71=148108。警告动作 55 是雷达事件，简单另有 17 揭开集合点。

head_games_combine.gd 用两个独立计时组表现原图流程。征用所属翼现有单位，不足时在对应建筑调用 enqueue。battle.gd 让本关工厂产物继承所属翼。乘员通过实际运输系统换乘，接入原有炮塔、变形音和武器。已会合的第一辆车触发一次语音与雷达提示。五车组整队后经 71 向玩家目标进攻。释放任一翼阻止继续组建联合队。原版 Temp House 归属、组员阵亡重组、攻击目标优先级与原图完整触发器仍属近似实现。

Godot 4.7.2 隔离 APPDATA，从战役菜单启动 tests/head_games.tscn -- --combine，11 项通过。日志 %TEMP%/IronTideS07Combine/out3、err3。验证了困难计时、工厂实付与出兵、登车、会合播报状态、磁暴车的 yr_bolt 绘制配置、五车出击时的三个 CRElectricBolt、一个 CRFlakGuyGun、一个 CRNuke。测试推进时钟并把单位移至移动目标，覆盖装卸与武器切换，尚缺自然长程寻路、三难度整场、存读档途中恢复和同镜头画面对照。后续复刻先查 Triggers/Events/Actions、TeamTypes/ScriptTypes/TaskForces，再从玩家战场验证生产到出击。