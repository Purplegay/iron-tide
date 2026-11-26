# 屏幕外幽浮的红色激光

敌方 DISK 在画面左侧外自动攻击画面内的 MTNK。隔离遭遇战使用项目发行运行时和真实物理步。修前命中时已创建 Beam、坦克扣血，随后画面沿预期光路检出红色的列数为 0。冻结战场直接调用开火的旧式验证则能看到红束，不能覆盖特效计时。

scripts/core/effects.gd 的 Beam 增加可选首帧保留，跳过首次 process 的衰减。scripts/units/unit.gd 在 DiskLaser/DiskLaserE 上启用。修后同场景 4 项通过，画面沿光路有 333 列检出新增红色，起点屏幕 x=-164，目标 x=241。证据在 .validation/disc-offscreen/auto 和 fixed2，包括探针、运行输出和命中帧截图。覆盖普通幽浮自动攻击地面坦克、左侧出屏及长帧。精英、对空、紫色汲取与其他方向未单测。
