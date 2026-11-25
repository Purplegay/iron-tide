# 武器尾线、射线与尾流（2026-10-26）

本轮范围为当前已经加载的武器和弹体；不新增阵营、单位或技能。

## 原因与修正

`Projectile._physics_process` 的追踪弹道分支原先提前返回，没有写入 `_trail`；
`_draw` 在绘制真实 SHP 后又直接返回，因此真实导弹既没有路径记录，也跳过尾迹绘制。
原 fallback 的轨迹坐标还未转换到 `Iso.begin` 的直立绘制空间。

现在由 `projectile_visual.gd` 按实际移动路径进行固定距离采样，最多保留 48 点；
尾迹先于真实弹体绘制，沿弯曲路径渐淡，使用 `Iso.dir` 转换。
每段两端都须在玩家当前视野中，避免尾迹透露迷雾内路径。
记录仍用既有 `_trail` 存档字段，不变更伤害、飞行速度、追踪转向、碰撞、冷却、弹头或存档格式。
瞬时光束和声波继续走各自现有结算，不能给不可见弹体额外增加实体飞行时间。

## 本地尤复来源

`ra2pipe/projectile_visuals.mjs` 只读已安装游戏的 artmd.ini 和项目现有弹体表，
生成候选 JSON，核对后放入 `iron_tide/assets/ra2/fx/projectile_visuals.json`。
其中原文 SHA256 为 `e1f0378394313c04ebbd5073f47785ee3e46f1b3c62d65724e8f3c310ee7ba31`。
不依赖未授权的参考引擎代码。

| 原素材 | 原始标志 | 当前接入 |
| --- | --- | --- |
| DRAGON | UseLineTrail=yes，216,216,255，Decrement=16 | 多功能步兵车、爱国者、部署重装大兵、战机等共用淡蓝白尾线 |
| MEDUSA | UseLineTrail=yes，208,208,208，Decrement=12 | 宙斯盾灰白尾线 |
| SUBT | Trailer=BBBLELRG | 鱼雷气泡尾流 |
| DREDMISS / MISLCHEM / NKMSLUP | DURASMOKE / SMOKEY2 / NUKEPUFF | 使用这些弹体的烟迹绘制支持 |

线颜色和衰减参数来自原始配置；采样间距、线宽、气泡和烟雾图元为独立 Godot 表现适配。
没有将后两类说成原 SHP 动画的逐像素复刻；未改变弹体朝向帧选择。
没有原始尾线/Trailer 的真实炮弹、警犬扑击等不会被统一套上导弹线。
扩展模式无贴图弹体保留程序化短尾迹。

## 射线检查

运行态扫描覆盖 38 条带 IsLaser / IsElectricBolt / IsRadBeam / IsRailgun 的武器配置，
包括普通、精英和尤复前缀版本，以及 14 条有尾线/Trailer 的弹体配置。
IsRailgun 增加渲染适配；不代表新增了可生产的轨道炮单位。
分裂弹依据自己的武器标志绘制，电弧分裂不再无条件画成房色激光。
YR_CAP_CRNeutronRifle 的 ChronoBeam 前缀识别修正为蓝色；超时空持续抹除逻辑保持不变。
既有心控、维修束、光棱支援和声波路径也已检查，不重复叠加第二条射线。

## 验证入口

`iron_tide/tests/run-navigation-building.ps1 -Suite weapon_trail_regression -Render -RunRoot <新的外部目录>`

两模式实际 FV、NASAM、AEGIS、ORCA、BEAG、GGI 发射，验证 SHP 和尾线同时产生像素、
移动中不提前扣血、命中后原伤害仍生效、有界路径、迷雾段过滤，以及存读档后的路径/样式。
额外实际绘制烟迹、气泡和四类射线。逐配置清单在该轮 reports 的 `ra2-weapon-audit.json`
及 `iron_tide-weapon-audit.json`。最终回归和环境证据见 VERIFICATION.md。
实机表现仍为 `pending_user_visual_confirmation`。
