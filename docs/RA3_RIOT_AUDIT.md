# 未来坦克 Q 接近、横扫伤害对照 · v0.5.0.9

**v0.5.7.1更正**：现已从起义1.1的BeamSpecialAbilityUpdate确认SweepDistance减半、斜向交叉起终点、线性插值和逐LaserState发射。横向范围扩大一倍的问题已修；死亡／停用时钟也已处理。当前实现、CPU地址、验证和剩余边界以[本轮审计](RA3_EXPANSION_FIX_AUDIT.md)为准，下文旧轨迹／30Hz描述保留为历史记录。

**v0.5.6.3更正**：本记录原先按30Hz处理DamageInterval=0。现已从起义1.1零售程序常量及初始化代码确认逻辑时钟15Hz，连续伤害改15次／秒，旧存档游标按事件时间迁移。下面30Hz说明为历史适配，已被[完整审计的CPU证据](RA3_UPHEAVAL_FULL_AUDIT.md)取代；轨迹与完整BeamSpecialAbility调度仍非原引擎复刻。

## 来源与优先级

1. 权威：EA `CnC_Modding_Support` 提交 `3aad8e412961ab543192ae70f8503dc8e178e095` 的 [Uprising](https://github.com/electronicarts/CnC_Modding_Support/tree/3aad8e412961ab543192ae70f8503dc8e178e095/Uprising)。本次直接读取 `Xml/EP1/Allied/Units/AlliedFutureTank.xml`、`Xml/EP1/GlobalData/Weapon_EP1.xml`、`SpecialPowerTemplates_EP1.xml` 和 `Schemas/Modules/BeamSpecialAbilityUpdate.xsd`／`SpecialAbilityUpdate.xsd`。
2. 交叉参考：[Red Alert 3: Upheaval Source Code 1.16](https://bibber.eu/downloads/ra3-upheaval-source-code/)，作者 **Bibber**。这是把起义单位移植至 RA3 的社区模组源码，不是官方引擎源码；感谢并保留作者署名。2026-10-28 按该网站实际下载流程取得 ZIP，145,311,131 字节，3623 项，SHA256 `8bb4cea9d15d8c00f153b169b64de292873038a602e65fd5451306aa1825588f`。保存于 `refs/ra3-expansion/upheaval/ra3-upheaval-source-code.zip`，仅解压目标 XML，没有运行其可执行文件或构建脚本。
3. Upheaval 对照文件位于 ZIP 中 `Upheaval/Data/Mod/Units/Future Tank X-1/{GameObject,WeaponTemplate,SpecialPowerTemplate}.xml`。不把该模组改动自动覆盖官方起义规则。官方美术包不包含这两单位的事实仍见 [特效审计](RA3_FX_AUDIT.md)。

## IronTide平衡覆盖 · v0.5.12

用户反馈Q拆基地过快，授权削弱。`data/ra3_gameplay_balance.json → future_riot.structure_damage_multiplier=0.5`是本游戏平衡参数，不是起义XML；`ra3_riot.damage`仅在目标为Building时对沿线及末端伤害各乘一次，再走原护甲／跨代血量／军衔／防御换算。没有改官方25／50伤害、非步兵30%、15Hz事件、双束扫掠或15秒冷却，也不影响普攻、炮艇或对单位伤害。技能说明从同一配置读取百分比。

同一真实基地占地与落点的完整Q新兵伤害182.8125→91.40625，英雄228.515625→114.2578125；此为本工程盟军基地1000HP的测试样本，不能当作所有落点固定扣血。专项还覆盖兵营／电厂／战车工厂、新兵／英雄、15／60／120Hz和0.4秒补帧、单位伤害不变与Q中途真实存读档。

## 定义与差异

| 项目 | 官方起义 | Upheaval 1.16 | 之前实现／本次处理 |
|---|---|---|---|
| 技能模块 | BeamSpecialAbilityUpdate，双束交叉、DIAGONAL_SWEEPING | WeaponFireSpecialAbilityUpdate＋独立 SweepingLaserState | 采用官方模块的参数，保留区别；不把社区默认水平往返轨迹当原版 CPU |
| 施放距离 | StartAbilityRange=250；FAIL_WITH_INVALID_APPROACH 的 schema 注释明确“接近后仍不在范围则取消” | StartAbilityRange=250，同一失败标记 | 之前仅超距立即拒绝、没有接近；现在选射程内可达落点，复用真实 pathfinding／order_move，到达才开始技能。不可达和中途停下不扣冷却 |
| 展开／收起 | Unpack 0.5s、选择后最低1s；Pack 1s | Unpack 1s、Pack 1s、BusyForDuration 1s | 保留官方选择时间抵扣、最低0.5s展开；接近时间计入准备，不直接照抄 Upheaval 固定1s |
| 持续／横扫量 | BeamDuration=1s，SweepDistance=40 | 激活两条 Laser 1s，Radius=40 | 地图距离统一乘1.5；显示端与伤害端共享端点函数。原斜向扫掠精确 CPU 方程仍未公开 |
| 伤害间隔 | DamageInterval 未指定；schema 默认0s，注释 continuously fires | SweepingLaserState 引用同一个 SweepWeapon | 之前误用末端 DelayTimeSeconds=0.1 为整个技能间隔；现在按固定30逻辑步／秒连续发射，独立于渲染FPS与尤复15帧。此调度为明确适配，见下方边界 |
| 沿线伤害 | LineDamageNugget=25、LineWidth=5、UseDynamicLineLength=true、OverShootDistance=0 | 同值 | 原来与末端50混在一次立即伤害中；现在独立沿线事件；以单位碰撞圆／建筑占地多边形命中，避免只测试对象中心 |
| 末端伤害 | DamageNugget=50、Radius=5、DelayTimeSeconds=0.1 | 同值 | 独立记录每次扫掠采样的末端，延迟0.1秒再结算；最后的延迟事件不能随1秒光束结束而丢掉 |
| 目标与倍率 | ENEMIES NEUTRALS，排除空中／潜航等；非步兵30%，EXPLOSIVE | 同值 | 保留友军排除，增补乘员／潜航状态排除；原始伤害继续走既定装甲和跨代血量换算，没有覆盖其它武器 |
| 冷却 | ReloadTime=15s | 同值 | 接近期间0，不可达取消0；真正展开开始15秒，保存恢复剩余时间 |

## 调用与保存

- `tools/ra3_mirage/extract_future_riot.py` 提取技能、武器、两类伤害和 schema 默认值至 `iron_tide/data/ra3_riot_rules.json`，记录5个 EA 源文件 SHA256。生成命令：`python tools/ra3_mirage/extract_future_riot.py`（使用实际已安装 Python）。
- `AlliedAbilities.use → Ra3Expansion.use → ra3_riot.request`；超距命令保留位置、接近进度，不持有容易失效的敌方对象引用。到达范围调用 begin。新移动／S 经既有 cancel 清除接近状态。
- 接近候选为施放圈内的16个位置，使用现有地形寻路；验证路径末端仍在375地图距离内。中途连续5秒没有4单位进展则取消，是 Godot 防卡死策略，不声称来自原版 CPU。
- `Projectile → Ra3Expansion.tick_shot → ra3_riot.tick_shot`：两条激光各自执行沿线和末端事件；整数游标补齐低帧率跳过的时间点，末端用其发射时刻的固定位置；场景目标按事件执行时的当前状态判定。
- `special.ra3_riot_approach` 和 `splinters.riot_next/riot_tip/riot_previous` 沿用已有通用快照编码，不新增存档格式版本。旧活动光束没有游标时从已保存年龄接续，不重打过去完整光束。`ra3_future_state` 在接近期间禁止普攻并使用已有激光移动姿态。
- 技能预览以前继承通用占位半径1；现在新建技能从同一配置读取375地图距离。

## 明确的适配边界

- EA schema 证明 DamageInterval=0 是连续执行，**不独立证明原引擎每步调用次数、首尾帧取样点和延迟队列内部实现**。当前以 RA3 30逻辑步／秒、1秒30次／束实现；这不是已反编译验证的 SAGE CPU。Upheaval 也调用原引擎模块，没有提供这段 CPU 源码。
- DIAGONAL_SWEEPING 原生三维曲线仍待确认。本次保留既有地面双束交叉路径，没有杜撰三维斜扫公式；视效端点与伤害采样端点共用函数。伤害射线仍以地面车体位置为起点，显示使用骨骼炮口；近炮口的3D高度命中不能视为已还原。
- LineWidth 按完整宽度解释（半宽用于距离判断），单位圆／建筑多边形是本游戏二维碰撞适配；无法证明与 SAGE 三维包围体逐点相同。角色快速移动时，大时间步补算使用其当前位置，不回溯未知原引擎子帧轨迹。
- 普通／英雄增益、原生装甲与用户已确认的 RA2／RA3 跨代血量换算保持。没有按观感随意降低或增加武器基础伤害。用户实机操作、命中观感仍待确认。

## 本轮验证

Godot 4.7.2 Compatibility／WASAPI，隔离项目 `refs/ra3-mirage/integration-test/project` 引用本工作区真实源码；独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`；网络、服务、数据库均为 none。

- 新增 `ra3_riot_regression` **31项**：真实超距移动至施放边界、S取消、不可达水域、无效接近、非有限及地图外坐标、精确375边界；120/60/15Hz及0.4秒步长下各束30次沿线和30次延迟末端事件、0.1秒前后伤害、建筑边缘和伤害换算、友军／空中／潜航排除、真实快照恢复伤害游标与待接近指令。
- 既有 future_presentation 58、expansion 63、savegame 120、allied_abilities 200、native 93、future_glow 12，合计 **577项通过**，七进程退出0、无脚本错误／泄漏，运行前后源码资源指纹一致。
- 证据 `refs/ra3-expansion/riot-final/audit.json` 及各场景 result.json/run.log；显示专项复查当前Q绘制链。只读源码与配置验证不能冒充起义原版实机录像比较。
- 新专项复现：先创建输出目录并设置 `IRON_TIDE_REPORT_DIR`；运行 Godot `--path refs/ra3-mirage/integration-test/project --rendering-method gl_compatibility --audio-driver WASAPI --scene res://tests/ra3_riot_regression.tscn`，同时核对退出码、日志与 result.json。

本次未提交、推送或打包；不关闭用户正在运行的游戏，须重启再进入战斗验证新代码。
