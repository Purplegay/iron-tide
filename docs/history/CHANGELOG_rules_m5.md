# CHANGELOG — 规则迁移 第 5 批：电力系统

> 铁律：**RA2 是规则唯一事实源** · **判定几何 WYSIWYG** · **每步必须可验证**（无头自检 + 有头离屏截图 + 实测日志，跑完删临时工装）。
> 本轮口令：用户答「**上电力**」→ 承接第 4 批结尾的三选一（电力 / EVA 播报 / 老兵等级），拍板 **电力**（理由：数据已就绪、规则清晰，是「基地运营」这条线的基础设施，后续 EVA 的「电力不足」播报、超武前置都依赖它）。

---

## 1. 目标与结论

**PASS**：无头探针 **31/31 断言**；有头离屏截图 2 张（充足 / 低电对比）；editor/battle 回归 `exit=0`。

一句话：**建筑会发电、会耗电；电力不足时全阵营建造/生产变慢（1.0→0.8→0.5），且 `Powered=yes` 的防御与经济建筑离线。**

---

## 2. 事实源（RA2）

### 2.1 rules.ini 建筑 `Power=`（正=发电 / 负=耗电）与 `Powered=`（低电离线）

本轮运行时阵营共 **16 栋**建筑，其中 12 栋带电力字段：

| id | 名称 | Power= | Powered= | 说明 |
|---|---|---:|---|---|
| GAPOWR | 发电厂 | **+200** | – | 唯一电源 |
| GAREFN | 盟军矿石精炼场 | −50 | – | |
| GAOREP | 矿石精炼器 | −200 | **yes** | 低电停摆（停涓流） |
| GAPILE | 盟军兵营 | −10 | – | |
| GAWEAP | 盟军战车工厂 | −25 | – | |
| GAAIRC | 空指部 | −50 | – | |
| GADEPT | 盟军维修厂 | −25 | – | |
| GATECH | 盟军作战实验室 | −100 | – | |
| ATESLA | 光棱塔 | −75 | **yes** | 低电停火 |
| GTGCAN | 巨炮 | −100 | **yes** | 低电停火 |
| GAGAP | 裂缝产生器 | −100 | **yes** | 低电停机 |
| GASPYSAT | 间谍卫星 | −100 | **yes** | 低电停机 |

> 统计：`N=16  withPower=12  gen=1  drain=11  powered=5`（`GACNST/GAPILL/GASAND/GAWALL` 无电力字段）。1 座 GAPOWR 的 200 电力远不够，必须按需扩建发电厂——与 RA2 一致。

### 2.2 rules.ini `[General]` 电力常数（本轮实测）

```
MinLowPowerProductionSpeed=.5          ; 低电时产能速度下限（注释：applies after modifier below）
MaxLowPowerProductionSpeed=.8          ; 低电时产能速度上限（注释：so 99% power is treated as this %）
LowPowerPenaltyModifier=1              ; 惩罚倍率
WorstLowPowerBuildRateCoefficient=.1   ; （建造速率系数下界，本轮未接入，留档）
BestLowPowerBuildRateCoefficient=.2    ; （建造速率系数上界，本轮未接入，留档）
PrerequisitePower=GAPOWR               ; （建造前置电场，留档）
```

### 2.3 参考实现 `refs/ts-ra2`

- `src/game/player/trait/PowerTrait.ts` —— 电力量级（`power >= drain ? Normal : Low`）；**发电量 = Σ ceil(Power × 当前血量%)**（受损电站出力下降）。
- `src/game/trait/ProductionTrait.ts:computeLowPowerBuildSpeedModifier()` —— 低电建造系数：

```
powerRatio = 1 - min(1, power / drain)
penalty    = 0.3 * lowPowerPenaltyModifier * powerRatio / 0.15
modifier   = clamp(1 - penalty, minLowPowerProductionSpeed, maxLowPowerProductionSpeed)
```

代入 `modifier=1 / min=.5 / max=.8`：`prod/drain≥0.9 → 0.8`（轻微缺电即降至 80%）；`=0.75 → 0.5`；`≤0.75 → 0.5`（触底）。**照搬实现。**

---

## 3. 实现

### 3.1 数据管线

| 文件 | 改动 |
|---|---|
| `ra2pipe/build.mjs` | 建筑段新增 `o.powered = boolOf(s.keys.get('powered'), false)`（`Power=` 早已提取） |
| `ra2pipe/faction.mjs` | 建筑 entry 落 `power`（非 0 时）/`powered`（true 时）；report 追加**电力清单** |

产物：`iron_tide/data/ra2_allied.json`（16 建筑，12 带电力字段，5 个 `powered`）。

### 3.2 引擎

| 文件 | 改动 |
|---|---|
| `scripts/autoload/events.gd` | 新增 `signal power_changed(produced, drain, low)` |
| `scripts/world/battle.gd` | 新增电力段：常量 3 个、`power_produced/power_drain/power_low/_power_sig`、`_update_power()`（每帧重算、变化才发事件）、`power_build_factor()`（照搬公式）、`power_stats()`；`_process` 调 `_update_power()`；`_tick_structure_queue()` 建造计时与分帧付款**同步乘低电系数**（总花费不变、工期拉长） |
| `scripts/buildings/building.gd` | 新增 `power` / `powered` 字段与 `setup()` 读取；新增 `is_operational()`（落成 且（不需电 或 供电正常））与 `_power_build_factor()`；建造 & 生产队列乘低电系数；资金涓流受 `is_operational()` 门控；`_fire()` 加门控；`_draw()` 画「**无电**」呼吸角标 |
| `scripts/ui/power_bar.gd` | **新建** `PowerBarControl`：横向电力条，绿色=产电 / 红色=缺口，低电时外框呼吸闪烁 |
| `scripts/ui/hud.gd` | 顶栏新增「电力 x/y」标签 + 电力条；低电时标签变红并加「⚠低电」；订阅 `Events.power_changed` |
| `scripts/autoload/gm.gd` / `scripts/admin/gm_console.gd` | 新增 GM 开关 **`infinite_power`（无限电力）** |

### 3.3 关键设计决策

| 决策 | 理由 |
|---|---|
| 电力为**阵营全局**，非建筑私有 | RA2 电力是玩家级资源；防御塔是否离线由全阵营电平决定 |
| **受损电站出力下降**（ceil(Power×血量%)） | 照搬 `PowerTrait`；让「打电台」有战术意义 |
| **未落成建筑不计电力** | 本作建筑是「原地建造、落成前不工作」，故电力也按落成计（与 RA2 建筑落地即通电略有差异，按本作建造模型取齐） |
| 低电**同时拖慢计时与付款** | 保证「总花费不变、只是工期变长」，避免只拖计时导致超收资金 |
| **不接** `Worst/BestLowPowerBuildRateCoefficient` | 与 `Min/MaxLowPowerProductionSpeed` 语义重叠且参考实现未用；留档不实现 |
| `powered` 建筑仅离线其**武器/涓流**，不停其建造 | 本作生产建筑（兵营/战车工厂）本就不 `Powered`，低电通过全局系数变慢而非停摆 |
| GM `infinite_power` | 便于调试与对照（不进正常玩法） |

---

## 4. 可验证性

### 4.1 无头自检 `_probe_power.tscn`（31/31 PASS）

```
POWERPROBE baseline produced=200 drain=10 low=false        ← 开局基地已含 1 发电厂
[ OK ] 数据链 GAPOWR Power=200 → 产电 +200
[ OK ] 建筑数据 power=200 / powered=false
[ OK ] 数据链 GAREFN Power=-50 → 耗电 +50
[ OK ] 200/50 供电充足 → 非低电
[ OK ] 半血 GAPOWR 出力 100（血量缩放）
[ OK ] 供电充足 → power_build_factor=1.0
POWERPROBE under-drain produced=400 drain=535 low=true
[ OK ] 产电 < 耗电 → 低电
[ OK ] ATESLA/GTGCAN/GAGAP 均 powered=true（rules.ini Powered=）
[ OK ] GAOREP Powered=yes（低电停涓流）
[ OK ] 低电 → 光棱塔 ATESLA 离线（不开火）
[ OK ] 低电 → 巨炮 GTGCAN 离线
[ OK ] 低电不影响非 Powered 电站本体运转
[ OK ] 低电 0/200 → 系数 0.5（MinLowPowerProductionSpeed）
[ OK ] 低电 100/200 → 系数 0.5
[ OK ] 低电 180/200 → 系数 0.8（MaxLowPowerProductionSpeed）
[ OK ] 低电 195/200 → 系数 0.8
[ OK ] 低电 165/200 → 中间值 0.650 ∈ (0.5,0.8)
[ OK ] 低电下结构队列 1s 只推进 0.5s（got 0.500）
[ OK ] 供电充足结构队列 1s 推进 1.0s（got 1.000）
[ OK ] 建筑侧 _power_build_factor 取到 0.5
[ OK ] GM 无限电力 → 非低电
[ OK ] GM 无限电力 → 产电补足耗电
[ OK ] 关掉 GM → 恢复低电
[ OK ] Events.power_changed 已发出（count=6）
[ OK ] HUD 电力标签已更新：'电力 400/535  ⚠低电'
[ OK ] HUD 低电时显示 ⚠低电
[ OK ] HUD 电力条进入低电态
[ OK ] 补 2 座电站 → 恢复充足
[ OK ] HUD 电力条退出低电态
POWERPROBE FINAL fails=0 events=7 produced=1000 drain=535
POWERPROBE VERDICT PASS
```

### 4.2 有头离屏截图

- `[A] 供电充足：电力 1000/735`，绿条 ~73%，建筑明亮。
- `[B] 低电：电力 0/735 ⚠低电`，整条红，光棱塔/巨炮/裂缝产生器头顶红「**无电**」角标。

### 4.3 回归

`--editor --quit` → `exit=0`；`battle.tscn --quit-after 900` → `exit=0`。

---

## 5. 改动文件清单

**管线**：`ra2pipe/build.mjs`、`ra2pipe/faction.mjs`
**引擎**：`iron_tide/scripts/autoload/events.gd`、`gm.gd`、`scripts/admin/gm_console.gd`、`scripts/world/battle.gd`、`scripts/buildings/building.gd`、`scripts/ui/power_bar.gd`(新)、`scripts/ui/hud.gd`
**数据（重产）**：`iron_tide/data/ra2_allied.json`、`iron_tide/data/ra2/buildings.json`
**文档**：本文件、`RA2_RULES_MIGRATION.md`、`RA2_PORT_ROADMAP.md`、`RA2移植_规则迁移台账.md`
**工装（已删）**：`_probe_power.gd/.tscn`、`_shot_power.gd/.tscn`、`ra2pipe/power_recon.mjs`、`_pp_*.txt`、`_shot_*.txt`、`_caps.txt`、`_mk_cmp.ps1`

---

## 6. 已知边界 / 未做

- **雷达 / 小地图**未随低电关闭（GASPYSAT 仅作为耗电与离线对象；RA2 中低电会关雷达，本作地图常显）。
- **维修（K）**未受低电影响（仅建造/生产）。
- **EVA「电力不足」播报**未接（属第 6 批 EVA）。
- `Worst/BestLowPowerBuildRateCoefficient`、`PrerequisitePower` 留档未实现。

---

## 7. 下一步候选

EVA 播报（`eva.ini` → `sound.ini`，含「电力不足 / 电力恢复」）／老兵等级／苏军阵营运行时／命令集（巡逻·警戒·守卫·停止）／地形水 + `MovementZone`／建造耗时公式／超武／命中音效（等动画 `start_sound` 数据）。
