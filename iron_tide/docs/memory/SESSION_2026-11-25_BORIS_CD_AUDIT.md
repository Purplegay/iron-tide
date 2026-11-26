# 鲍里斯空袭冷却核对

`data/yr_soviet.json` 标注来源为本地尤复 rulesmd.ini 与 artmd.ini。AKM、AKME 的 ROF 都是 20，Flare 的 ROF 为 60。BORIS 普通和精英的 AirstrikeTeam 分别是 2、4，机型均为 BPLN，AirstrikeRechargeTime 分别为 100、50。

当前 `soviet_specials.gd` 派机时写满空袭计时，有飞机存活就保持该值，末机离场或被击落后重新设置完整时长，随后递减。`unit.gd` 对建筑读取空袭计时，对其他目标读取步枪计时。`attack_cooldown_indicator.gd` 随当前目标切换显示，因此飞机在途时蓝圈停满，换目标时圈会切换。现有 soviet_completion_regression 覆盖本项目的末机离场与步枪独立计时。

本轮为代码及规则核对。未运行原版逐帧验证起算时刻，截图无法确定具体帧处于哪一阶段。仅新增此记录。
