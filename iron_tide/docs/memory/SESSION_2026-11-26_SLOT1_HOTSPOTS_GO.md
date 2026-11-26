# 六家对战慢帧前十与 Go 风格源码导读

采用 `Focus2` 的同一份剖析。Godot 4.7.2 图形 Release，存档 1，`yr_isleland`，3 倍速，开局 381 单位、207 建筑、5 个电脑阵营。进程采样未发现其他 Godot 引擎。92 个采样帧取最慢 5 个，分别赶了 8、8、7、7、8 个逻辑步。下面按已计时范围的自身耗时排序。自身扣除了已插桩子调用，未插桩子调用仍计在其中。包含列保留全部子调用，父子项不能相加。一次调用可能提前返回。探针改变帧时序，这组数字用于追查工作量，正式性能成绩由无插桩场次提供。

|排名|函数|自身 ms/慢帧|包含 ms/慢帧|次/慢帧|自身 µs/次|
|---:|---|---:|---:|---:|---:|
|1|`Unit._physics_process`|107.25|355.78|2957.8|36.26|
|2|`Unit._refresh_target`|28.04|46.92|1148.4|24.42|
|3|`Unit._process_combat`|25.76|84.47|1954.8|13.18|
|4|`Projectile._explode`|15.06|15.99|25.4|592.86|
|5|`Unit._recompute_bonuses`|14.59|15.37|4205.4|3.47|
|6|`Battle._process`|13.43|13.98|1.0|13430.20|
|7|`Unit._weapon_domain_valid`|13.36|14.30|894.6|14.93|
|8|`FogOfWar.rebuild`|12.27|23.01|1.4|8765.57|
|9|`UnitLogistics.tick`|12.25|13.55|2381.2|5.15|
|10|`ProgressionExpansion.tick`|11.81|36.32|2957.8|3.99|

代码块用 Go 的方法、结构体指针、显式返回和 `switch` 表达。辅助方法名用中文段落解释其职责，代表原函数内部的代码段。Godot 引擎回调和节点类型仍以原脚本为准。

## 1. 单位物理步

源码 `scripts/units/unit.gd:958`。每个活动单位收到一次物理回调，慢帧可能连续赶多个物理步。前段推进定时状态、专属能力和成长，同时处理专用实体的提前退出。随后按驻军、死亡、瘫痪、部署等状态分派。普通链路推进技能及开火时钟，按计时或失效事件刷新目标，才进入后勤、移动、交战、朝向和开火。会修改单位状态、目标、速度以及姿态重绘请求。各提前退出分支执行到的子系统不同，移动或统一延迟调用前要核查这些边界。

```go
func (u *Unit) PhysicsStep(dt float64) {
    if u.TickEarlyStates(dt) || u.TickProgression(dt) {
        return
    }
    u.TickModesAndVisualState(dt)
    if u.ResolveSpecialMovementOrPassengerState(dt) {
        return
    }
    u.TickTrafficAndSkills(dt)
    if u.ShouldRefreshTarget() {
        u.RefreshTarget()
        u.ResetTargetTimer()
    }
    u.RunCurrentLogisticsOrCombat(dt)
    u.UpdateFacingAndFiring(dt)
    u.RequestPoseUpdateIfNeeded()
}
```

## 2. 索敌刷新

源码 `scripts/units/unit.gd:2146`。先处理反击、清墙、技能占用和显式命令。合法的手动目标可继续锁定，连射和特定反击路径也有自己的保留规则。自动扫描用射程上界和空间索引收集附近对象，特殊分支会用阵营组或专门候选。逐个排除越界、失效、已上车和不允许主动攻击的目标，再计算实际接触距离及武器射程，查目标域与墙体遮挡，最后按战术分数和既有平分规则定目标。射程上界只是粗筛，建筑底盘、乘员武器和潜航接触仍走正式判断。写入 `attack_target`，无目标时还可能触发充能支援判断。

```go
func (u *Unit) RefreshTarget() {
    if u.ResolvePriorityTarget() {
        return
    }
    contacts := u.GatherSearchContacts(u.SearchBounds())
    var best *Actor
    bestScore := math.Inf(-1)
    for _, target := range contacts {
        if !u.InSearchBounds(target) || !u.CanAutoAcquire(target) {
            continue
        }
        weapon, reachable := u.ResolveSearchWeaponAndReach(target)
        if !reachable || !u.CanUseWeaponOn(target, weapon) || u.CoverBlocks(target, weapon) {
            continue
        }
        score := u.TacticalScore(target, weapon)
        if u.SearchPrefers(target, score, best, bestScore) {
            best, bestScore = target, score
        }
    }
    u.AttackTarget = best
    u.TryChargeSupportWithoutTarget()
}
```

## 3. 交战过程

源码 `scripts/units/unit.gd:1302`。负责当前行动决策。先恢复 AI 路线、处理反击，再把空中单位交给飞行控制。无目标和无移动命令的单位仍可能做避让或海上纠偏。地面分支结合部署、目标有效性、射程及命令决定原地跟踪、追击、继续走路或待机。主要写速度、朝向与订单状态。常规发射由同一个物理步的后续开火阶段推进。

```go
func (u *Unit) ProcessCombat(dt float64) {
    u.ResumeAIRouteIfNeeded()
    if u.ResolveCounterfireAndFace() {
        return
    }
    if u.UsesFlightCombat() {
        u.Flight.ProcessCombat(dt)
        return
    }
    if u.NoTargetAndNoOrders() {
        u.IdleAndResolveTraffic(dt)
        return
    }
    u.ResolveDeploymentPursuitOrMoveOrder(dt)
}
```

## 4. 弹体爆炸

源码 `scripts/units/projectile.gd:443`。先标记已引爆，再保存绘制高度并结算桥梁、分裂等效果。原版弹头按 `CellSpread` 与目标类型计算伤害。其他范围弹按经验公式衰减。强制打地使用落点，单位离开落点后不会被追打。单体弹直接处理当前有效目标。伤害调用可能改变目标生命状态、触发控制解除或单位死亡，所以顺序与有效性检查都重要。最后还有命中特效和弹体收尾。

```go
func (p *Projectile) Explode() {
    if p.Detonated || p.QueuedForDelete() {
        return
    }
    p.Detonated = true
    p.CaptureImpactVisualHeight()
    p.ApplyBridgeDamageAndSplitEffects()
    switch {
    case p.WarheadCellSpread() > 0:
        for _, target := range p.ImpactCandidates() {
            p.ApplyWarheadDamageIfInSpread(target)
        }
    case p.AreaRadius > 0.5:
        p.ApplyLegacyAreaDamage()
    case p.IsGroundPointShot():
        p.ApplyDamageAtImpactPoint()
    default:
        p.ApplyDirectHitAndChainIfNeeded()
    }
    p.FinishExplosion()
}
```

## 5. 重算单位属性

源码 `scripts/units/unit.gd:5577`。先按基础攻防、部署系数、训练和临时增益算基础结果。再依序应用动员兵、成长、英雄、飞机与远征倍率。熔炉特定姿态最后会覆盖移速。输入既有单位字段，也有当前规则和外部养成状态，输出是后续移动和战斗读取的攻击、防御与移速。约 3.47 微秒一次，慢帧的成本主要来自调用量。已经合入过一轮合并重算，本表仍能看到成长与技能链路的剩余调用。

```go
func (u *Unit) RecomputeBonuses() {
    u.RecomputeBaseBonuses()
    u.ApplyInfantryAttackModifier()
    u.MoveSpeed *= u.ProgressionSpeedFactor()
    u.ApplyHeroAndAircraftSpeedModifiers()
    if u.IsPlayerHouse() {
        u.MoveSpeed *= u.ExpeditionSpeedFactor()
    }
    u.ApplyFurnaceStanceLast()
}
```

## 6. 战场每帧回调

源码 `scripts/world/battle.gd:1334`。每个图形帧调用一次。负责战场级工作，包括英雄支援计时、开局指令轮询、提交单位姿态重绘、区域维修、战场音乐、攻击对象轮廓、AI 调度和选中状态维护。开局指令、区域维修和音乐有各自的时间条件。读写战场状态并扇出到多个系统，所以 13.43 ms/次无法直接归给某条语句。继续定位时应分别计重绘批次、AI 派发及其他帧服务。

```go
func (b *Battle) ProcessFrame(dt float64) {
    b.TickSupportAndOpeningOrders(dt)
    b.FlushPoseRedraws()
    b.TickAreaRepairAndMusic(dt)
    b.AttackTargetOutlines.Tick(b, dt)
    b.AIDispatch.Pump(b)
    b.RefreshInspectedActorsAndSelection()
    b.RunRemainingFrameServices(dt)
}
```

## 7. 武器目标域判断

源码 `scripts/units/unit.gd:2330`。先查目标是否有效、保护状态和阵营，再分派研磨、巨型乌贼、爆破、寄生及水下接触规则。可接收上游已解析的武器。后续分空中和地面判断，读实时目标类型，检查潜隐、当前可见性、墙体、突击队装甲倍率和弹头免疫。允许攻击某类对象与此刻能否选中该对象是两道门槛。C4 有专属分支。上轮只预计算 `AG`、`LandTargeting` 两个静态字段，回归通过但整帧门槛未过。

```go
func (u *Unit) WeaponDomainValid(target *Actor, cover bool, weapon *Weapon) bool {
    if !u.CheckProtectionAllianceAndSpecialTargetRules(target) {
        return false
    }
    if weapon == nil {
        weapon = u.ResolveWeapon(target)
    }
    c4 := u.CanPlantC4On(target)
    if !c4 && !u.CheckWeaponDomainAndVisibility(target, weapon) {
        return false
    }
    if !u.WorldContactVisible(target, c4) {
        return false
    }
    if c4 {
        return u.CanActAndTargetIsNotFrozen(target)
    }
    return u.CheckCoverVersesAndWarheadImmunity(target, weapon, cover)
}
```

## 8. 重建战争迷雾

源码 `scripts/world/fog_of_war.gd:757`。清理过期的留存视野和失效建筑缓存，再遍历存活的单位及建筑，按联盟汇总常规视野，叠加建筑情报、开火、侦察照相和附着单位等特殊视野。大型战场批量栅格化，达到规模门槛时已有线程池分支。最后合并地图遮罩并发布给战斗可见性消费者。移动离开的侦察足迹和临时开火暴露有各自的有效期。任何缩小重建范围的改动都要对账双方可见格和开火当步的目标有效性。

```go
func (f *FogOfWar) Rebuild() {
    f.ResetElapsedAndExpireHeldSight()
    f.ApplyGlobalIntelligence()
    batches := f.BuildAllianceSightBatches()
    scouts := f.CollectLiveActorsAndSpecialSight(batches)
    f.StampFiringReveals()
    f.RasterizeSightBatches(batches)
    f.UpdateVacatedScoutSight(scouts)
    f.PublishCombatSightWhenReady()
}
```

## 9. 单位后勤更新

源码 `scripts/units/unit_logistics.gd:161`。处理舰载机编队、登车、卸载、弹药和返航。登车要验证载具容量、相对位置、载具速度，飞行载具还要求高度和地面条件合适。登车实际修改乘员和载具两端，并可能换武器、外观和清除旧射击状态。卸载逐名执行。弹药耗尽时保留符合条件的订单并返航。布尔值在各分支表示本次后勤是否处理或占用行动，须结合调用方看。

```go
func (l *Logistics) Tick(dt float64) bool {
    l.UpdateRepairAndServiceState()
    if l.ServiceOwnsAction() {
        return true
    }
    if !l.HasActiveLogisticsWork() {
        return false
    }
    l.TickSquadron(dt)
    if done, consumed := l.UpdateBoarding(dt); done {
        return consumed
    }
    if l.Unloading {
        l.UpdateUnloading(dt)
        return true
    }
    return l.UpdateFlightServiceAndRearming(dt)
}
```

## 10. 成长扩展更新

源码 `scripts/units/progression_expansion.gd:14`。入口检查规则模式和单位状态。先推进第二代成长，临时英雄或地雷可独占本步。其余有扩展资格的单位尝试轻量空闲路径，否则运行卡牌、天赋和英雄逻辑。随后发布属性重算，并按弧光、受损等状态发出重绘。前面的逻辑能改变后续子系统读取的属性或单位存活状态。

```go
func TickProgression(u *Unit, dt float64) bool {
    if !u.CanRunProgression() {
        return false
    }
    TickSecondGeneration(u, dt)
    if u.IsTemporary() && TickTemporaryActor(u, dt) {
        return true
    }
    if !u.UsesMainProgression() {
        return false
    }
    previousArcs := u.ArcCount()
    idle := TryIdleProgression(u, dt)
    if !idle {
        TickCardsAndTalents(u, dt)
        if TickHero(u, dt) {
            return true
        }
    }
    u.RecomputeBonuses()
    if !idle || previousArcs > 0 || u.HP < u.MaxHP*0.42 {
        u.QueueRedraw()
    }
    return false
}
```

## 证据与使用范围

排序和帧数据在 `.validation/slot1-godot-20261126/current32/Focus2-rank.json` 与 `Focus2-diag/frame-components.json`，进程审计在 `Focus2-diag/host-cpu.json`。本轮读取历史诊断和当前源码，交付 Go 风格导读。热点优先级依赖这个存档、时间窗、插桩覆盖及每帧补跑的物理步数。`Unit._physics_process` 的 107.25 ms 含其余未测子调用，不能作为一个可直接消除的成本。`Projectile._explode` 是表中高单次成本、低调用量的入口。`Battle._process` 则是每图形帧一次的独立追踪入口。
