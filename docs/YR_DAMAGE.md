# 尤复伤害规则对照与修正

2026-10-23。当前可用单位的常规伤害以本机 Steam 尤复 `rulesmd.ini` 为对照源。没有复制参考引擎实现，也没有新增无素材/无机制的单位。

## 已定位的偏差

### 2026-10-23 追加：光束先出现、伤害后到账

光棱坦克 Comet / SuperComet 的运行时 projectile_speed=520，光棱塔 PrismShot 为 1100。原实现开火时立即绘制光束，却只把 `Inviso=yes` 用于隐藏弹体，仍按距离推进投射物，导致满射程光棱坦克约一秒后才扣血。

对照本机原始 rulesmd.ini：Comet → LargeCometP、SuperComet → SuperCometP、PrismShot → InvisibleHigh，三种 Projectile 均为 `Inviso=yes`；`IsLaser` 和 `LaserDuration` 属于光束表现，不能作为伤害等待时间。普通 InvisibleLow 枪弹也使用同一无飞行规则。

参考实现核对：

- [Phobos 的 YR Bullet hooks](https://github.com/Phobos-developers/Phobos/blob/develop/src/Ext/Bullet/Hooks.cpp) 中 `BulletClass_AI_TargetSnapChecks` 和 `BulletClass_Explode_TargetSnapChecks1/2` 单独处理 Inviso 的目标坐标吸附；[WeaponEffects hooks](https://github.com/Phobos-developers/Phobos/blob/develop/src/Ext/Techno/Hooks.WeaponEffects.cpp) 将激光绘制与投射物坐标处理分开。
- [OpenTS 的投射物机制说明](https://opents-developers.github.io/OpenTS/systems/projectile-flight/) 说明同系引擎的 Inviso 在发射时直接放到目标位置。它是 TS 的交叉参考，不冒充 RA2 官方源码。
- 用户提供的 RA2YR_ReSource 本机版本 `b01d3cf93db69aca9b5cb5054ba04e4358963828` 中 `BulletClass::MoveTo` 仍直接返回 false，`TechnoClass::Fire` 包含固定 firepower=25 和待实现弹体创建，不能据此证明原版命中时序。本次没有复制这些占位实现。

Godot 修正：真实投射物加入场景时，Inviso 在目标坐标立即调用已有弹头结算，保留每目标护甲、溅射、防御和击杀归属；增加单次引爆保护，光束消退不再影响扣血。IsSonic 仍走独立持续波动逻辑；炮弹、导弹仍飞行。这里保证没有人为距离延迟，不宣称复刻原 EXE 的逐帧对象调度。光棱碎片分裂、地形拦截和特殊抹除/控制等未完成机制不包含在本次修复内。

原始规则夹具现在额外提取 Projectile 原始字段。新增时序场景覆盖普通/精英光棱、光棱塔、GI、幻影、灰熊、IFV，双方、两种模式、100/300 距离、单位/建筑目标，以及光束消退和重复回调。修正前 1984 项中 208 项失败；修正后 1984 项全过。旧转向测试的“光棱等待飞行”预期同步纠正，转向、冷却、连发及精确伤害断言保留；负载计数包含当帧已引爆弹体。

本轮五个专项共 **2720** 项通过：伤害 1984、声波 460、晋升 80、转向开火 188、20/50/100/200 单位战斗 8。报告根 `C:/Users/admin/Temp/iron-tide-inviso-hit-20261023/`，最终目录为 `damage-final`、`sonic_regression`、`veterancy_regression`、`unit_fire_regression-final`、`combat_load_regression-final`。五次均退出码 0、运行前后源码不变，最终与当前 scripts/data/shaders 指纹复核无漂移；使用隔离工程和独立存档，无服务、端口、DB。伤害、声波、晋升测试退出仍分别报告 66/21/21 个 ObjectDB 未回收实例，未当作无告警通过。此次没有桌面实战手感确认。

### 之前的常规伤害修正

1. 混用了旧 RA2 和尤复数值：部署 GI 的 Para.Damage 为 15，尤复是 25；精英灰熊 105mmE 为 55 / ROF 75，尤复为 65 / ROF 50；精英部署 GI 的射速/射程也曾手工改动。机枪、部署机枪、穿甲、高爆等弹头的 Verses 和 ProneDamage 存在版本差异。
2. 瞬发路径先在 `CombatMath.full_damage` 算防御，再在 `receive_hit` 重复算防御。现在发射侧只提供防御前伤害，目标在实际命中时减免一次；AI 预估继续包含一次防御。
3. 炮弹按原始 Damage 重新计算每个受害者的伤害，因此仅修改预估 dmg 的扩展暴击和光棱支援会被丢弃。现在这两项进入本次射击独立的攻击倍率快照，投射物不再持有发射者可变的 bonuses 引用。目标自身的防御仍取命中时状态。
4. STRONGER 原先增加最大血量；现在 VeteranArmor=1.5 用作受伤除数，保留原始 Strength。精英能力与已有老兵能力合并，避免晋升后丢掉原有能力。整数截断仍在最终扣血时执行。

## 规则范围

- 更新当前单位、部署/精英武器、嵌套老兵武器及其所用底层武器/弹头：Damage、ROF、Range、MinimumRange、Burst、弹头绑定、11 类 Verses、CellSpread、PercentAtMax、ProneDamage。项目沿用的 15 Hz ROF 时钟和 55 px 格距是适配比例。
- 谭雅绑定尤复 HollowPoint2；RA2 模式读取尤复 Strength=200。扩展模式现有建筑三倍基础生命和额外养成/技能加成保留。例如电厂 RA2 模式为 750，扩展模式基础为 2250，不能拿两种模式的击毁发数直接比较。
- 心灵突击队的精神控制、超时空兵的抹除属于特殊状态机制，其 Damage 不等同普通 HP 扣除。现有适配尚不完整，导出审计明确列为 gaps，没有把数字改成原版就宣称机制完成。光棱支援拓扑、声波几何/脉冲、地形高度/散射、地图特殊修正也仍有独立适配边界。

### 几个无扩展加成、无防御增益的对照

| 场景 | 尤复规则推导 | 当前实际扣血检查 |
|---|---|---|
| 新兵 GI 打重装大兵 | 15 × SA 对 plate 的 80% | 12 |
| 部署 GI 打重装大兵 | 25 × SSA 对 plate 的 100% | 25 |
| 部署 GI 打已卧倒 GI | 25 × 100% × ProneDamage 80% | 20 |
| 新兵灰熊打重装大兵 | floor(65 × AP 对 plate 的 15%) | 9 |
| 精英灰熊打老兵灰熊 | floor(65 × 100% × VeteranCombat 1.1 / VeteranArmor 1.5) | 47 |

## 可重复对照

```powershell
node ra2pipe/yr_combat.mjs '<本机 YR 安装目录>' '<新的仓库外候选目录>'
```

仅向外部候选目录输出现有六份数据文件、原始规则夹具和 audit.json，不直接覆盖工程/安装目录。审计记录每项旧值、新值、来源 SHA、输入/输出文件 SHA 和特殊机制缺口；MIX 输入执行前后只读指纹核验。应用候选前再核对工程文件的原 SHA，拒绝覆盖并发修改。

原始规则 SHA256：`3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`。实际来源为本机 `expandmd01.mix` 覆盖后的 rulesmd.ini。夹具 `iron_tide/tests/fixtures/yr_damage_source.json` 从原始 INI 直接提取，测试预期不读取生产数据里的伤害倍率。

## 验证边界

`yr_damage_regression` 覆盖原始数值消费、实际发射/飞行/扣血、11 类护甲矩阵、零倍率、卧倒、精英攻击、老兵护甲、瞬发与投射物、命中前攻方倍率变化、范围衰减、友军/范围外保护、光棱支援、真实暴击，并同时运行 RA2/扩展模式及双方。其他专项覆盖晋升经验、建筑受击、声波、模式隔离、飞机/航母弹药补给、连发和目标选择；多单位对战覆盖 20/50/100/200 单位的实际自动寻敌、开火及扣血。

运行使用隔离项目、独立存档，服务/端口/数据库为 none；源文件指纹和进程退出码由现有 runner 在前后核查。测试修改了冻结场景的姿态/等级/护甲或血量，以构造边界；调用的开火、投射物、扣血和经验路径均为真实生产代码。对战负载测试是无渲染逻辑验证，不代表桌面帧率或一整局平衡验收。

本轮报告根：`C:/Users/admin/Temp/iron-tide-yr-damage-20261023/`。`candidate-scoped/audit.json` 保存应用前差异；`source-fixture/audit.json` 再对照为 0 数值差异，特殊机制 gaps 仍保留。

最终九个专项共 **2453** 条断言通过：伤害 1312、老兵 80、声波 460、建筑受击 120、模式隔离 83、对战负载 8、空海补给 142、单位开火 188、战术目标 60。九次均退出码 0、源文件前后指纹一致；最终再核对当前核心源码/原始规则夹具与报告指纹一致。20/50/100/200 单位场景均实际造成伤害且无友军自动目标；200 单位场景记录 432 发炮弹。

部分专项退出时仍报告 ObjectDB 未回收实例：老兵 21、建筑受击 9、对战负载 37、补给 4、单位开火 39、战术目标 2；这些告警未当作“无告警”结论，也未通过删除伤害断言规避。初次新增专项因局部 label 类型推断失败未能执行，停止的仅为该隔离目录的测试进程，修正后重新运行；失败日志保留于 `damage-first/`。实际一局的战斗节奏仍需玩家体验，不以无渲染专项证明完整尤复平衡。
