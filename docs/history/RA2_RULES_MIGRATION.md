# RA2 规则迁移台账（Ledger）

> 目标：把 Iron Tide 的**规则**（非美术、非原创卡池）逐步改成**照搬 RA2**。
> 铁律：**RA2 是规则唯一事实源**；判定几何 WYSIWYG；每步可验证。
> 事实源文件：`extracted/rules.ini`（及 `art.ini`）→ 由 `ra2pipe/build.mjs` 生成 `data/ra2/*.json`（**禁止手改**）→ 由 `ra2pipe/faction.mjs` 生成运行时 `data/ra2_allied.json`。

状态图例：✅ 已迁移　⚠️ 部分/近似　❌ 未迁移

## A. 战斗（第 1 批，2026-10-11 完成）

| 规则 | RA2 事实源 | 状态 | 落地位置 |
|---|---|---|---|
| 护甲类别（11 类） | `Armor=` | ✅ | `ra2_armor`；`GameData.RA2_ARMOR_ORDER` |
| 弹头 Verses（逐弹头×逐护甲倍率） | `[Warheads] Verses=` | ✅ | `data/ra2/warheads.json`（83）；`CombatMath.raw_damage` |
| 武器数值（Damage/ROF/Range/Speed/Burst/Warhead/Projectile） | `[Weapons]` | ✅ | 运行时 `weapon.ra2_*`；ROF=15fps |
| 防空判定 | `[Projectiles] AA=` | ✅ | `ra2_aa`；`CombatMath.can_hit_air` |
| 单位武器选取 | `Primary=` / `Weapon1..N` | ✅ | build.mjs（含 SREF `Weapon1=Comet`） |
| 建筑武器选取 | `Primary=` | ✅ | build.mjs（GAPILL/ATESLA/GTGCAN 等） |

## A2. 攻击特效（第 2 批，2026-10-11 完成）

| 规则 | RA2 事实源 | 状态 | 落地位置 |
|---|---|---|---|
| 炮口火光（真动画 SHP，8 向按朝向取） | `[Weapon] Anim=` | ✅ | `data/ra2/animations.json` + `assets/ra2/fx/`；`Ra2Fx.pick_directional` |
| 火光发光 | `[Weapon] Bright=` | ✅ | 叠加混合（`BLEND_MODE_ADD`） |
| 命中动画（列表随机取一） | `[Warhead] AnimList=` | ✅ | `Ra2Fx.play_any`；`Projectile/_spawn_ra2_impact` |
| 溅射半径 | `[Warhead] CellSpread=` | ✅ | `CellSpread × 55px` 覆盖手写 aoe |
| 可见弹体外形 | `[Projectile] Image=` | ✅ | `120MM` / `DRAGON` |
| 无弹体（枪弹/光束） | `[Projectile] Inviso=yes` | ✅ | `projectile.gd/_draw` |
| 抛物线弹道 | `[Projectile] Arcing=yes` | ✅ | `projectile.gd/_step_arc` |
| 弹体地面阴影 | `[Projectile] Shadow=yes` | ✅ | `projectile.gd/_draw` |
| 追踪转向速率 | `[Projectile] ROT=` | ✅ | `_step_homing`（1/256 圈 / 1/15s） |
| 动画帧率 | `art.ini Rate=` | ✅ | `fps = Rate/60`（缺省 900→15fps，依据 `refs/ts-ra2`） |
| 武器/命中**音效** | `Report=` / `StartSound=` | ❌ | 已提取入数据；**WAV 素材未提取、未接线** |

## A3. 移动（第 2 批，2026-10-11 完成）

| 规则 | RA2 事实源 | 状态 | 备注 |
|---|---|---|---|
| 速度统一口径 | `Speed=` | ✅ | `px/s = Speed × 45/3`（≈3 Speed = 1 格/秒）；删除手写 26/15/24 |
| 转向速率（车体+炮塔） | `ROT=` | ✅ | `°/s = ROT × 21.09375`（1/256 圈/帧）；实测 180° 用 1.68s（理论 1.71s） |
| 起停斜坡 | `Accelerates=` / `AccelerationFactor` | ✅ | 仅 `=yes` 生效；盟军白名单内无单位开启（照搬且零回归） |
| 碾压步兵 | `Crusher=` / `Crushable=` | ✅ | `unit.gd/_crush_tick` |
| 可通行域/移动类型/ locomotor | `MovementZone=`/`SpeedType=`/`Locomotor=` | ⚠️ | 已带入运行时 `move.*`，地形系统未做 |
| 矿车停靠目标 | `Dock=` | ⚠️ | 已提取 `move.dock`；`_pick_home_base` 暂用 `tags:refinery`+兜底 |
| 地形/水/桥通行性 | `[TerrainTypes]` | ❌ | 未接 |

## A4. 采矿（第 2 批，2026-10-11 完成）

| 问题 | 状态 | 说明 |
|---|---|---|
| **矿车卡死**（直线奔赴顶死自家建筑，永不卸矿） | ✅ | 根因：采集行程没挂寻路流场；修法：`_steer_field_to` + `_track_stuck` 脱困 + 矿点黑名单。复验 stalls=0、两台矿车正常往返 |
| 矿点耗尽自动换矿 | ✅ | 上轮 A5已有，本轮复验通过（抽干全部矿点后会去别的矿点） |
| **倒车入库**（返程一头扎进矿厂，车头朝内） | ✅ 第 6 批 | 两段式：先开到外侧「待泊位」把车身摆正，再倒车进泊位；入库段 速度·车头 = -1.00 |
| 泊位随方位漂移（矿车绕着矿厂打转） | ✅ 第 6 批 | 旧实现每帧 `_dock_point()` 重算 → 泊位跟着车转；现进入 300px 后 `_lock_dock()` **冻结**泊位 |
| 多台矿车扎堆同一堆矿 / 抢同一卸矿口 | ✅ 第 6 批 | 矿点**认领**（`ResourceNode.claim_by/release`，弱引用）+ 卸矿口占用时在待泊位等（超时 6s 强行入库，防互锁） |

## A5. 本轮修掉的两个**真 bug**（非本轮引入）

| bug | 影响 | 修法 |
|---|---|---|
| `Object.get(k, default)` 传 2 参 | Godot 4 的 `Object.get()` 只收 1 参 → 实机开火报错且返回 null；**第 1 批的「弹头 Verses 走真值」在实机里静默失效**（探针直接调 CombatMath 所以 24/24 PASS 没发现） | `var v = node.get("ra2_armor")` + 空值判断 |
| 建造场 `GACNST` 漏进白名单 | `battle.gd/_check_end` 靠 `tags:hq` 找 HQ，GACNST 缺失 → **开局第 1 帧即「败北」** | `faction.mjs/BUILDING_TAGS` 补 `GACNST:['structure','hq','production']` |

## B. 建造 / 经济

| 规则 | RA2 事实源 | 状态 | 备注 |
|---|---|---|---|
| 前置建筑（Prerequisite） | `Prerequisite=` | ✅ | `ra2_prereq` |
| 科技等级（TechLevel） | `TechLevel=` | ✅ | `tech_level` |
| 建造耗时 | `Cost` | ⚠️ | 近似 `cost/50`；RA2 真实公式更复杂 |
| 电力产出/消耗 | `Power=` | ✅ 第 5 批 | 运行时建筑 `power`（GAPOWR +200 / GAREFN −50 / ATESLA −75 …）；发电量=Σ ceil(Power×血量%) |
| 低电惩罚（产能下降 / 防御离线） | `[General] Min/MaxLowPowerProductionSpeed` | ✅ 第 5 批 | `battle.power_build_factor()`（1.0→0.8→0.5）；`Powered=yes` 建筑（GAOREP/ATESLA/GTGCAN/GAGAP/GASPYSAT）低电离线 |
| 资金/矿点/采集车 | `[Tiberium]`/矿车 | ⚠️ | 上轮 A5 已做矿点再生+自动换矿；矿车数值仍为引擎自有 |
| 维修厂进驻修理 | `RepairStep/URepairRate/RepairPercent` | ✅ | 上轮 A4 |
| 建筑建造序列（Buildup） | `art.ini Buildup=` | ✅ | 上轮 A6 |

## C. 单位 / 军事

| 规则 | RA2 事实源 | 状态 | 备注 |
|---|---|---|---|
| 生命/速度/视野/造价/科技等级 | `Strength=/Speed=/Sight=/Cost=` | ✅ | 运行时（含格→px、速度统一口径） |
| 武器开火/弹道/命中 | — | ✅ | 引擎 + A2（真实 Anim/AnimList/弹道属性） |
| 老兵等级（VeteranAbilities / EliteAbilities / VeterancyRatio） | `rules.ini` | ❌ | 引擎无老兵系统 |
| 命令集（部署/巡逻/警戒/停止/守卫/编队） | — | ⚠️ | **部署（D）第 6 批修复**并改为**单击主技能**（旧版调不存在的 `u.deploy()` → 点 D 无反应）；编队数字键上轮已有；巡逻/警戒/守卫缺 |
| 阵营（盟军/苏军/尤里） | `[Sides]`+art | ⚠️ | 仅**盟军**有运行时数据与美术 |
| 中立/民用建筑 | `[BuildingTypes]` | ⚠️ | 数据在 `buildings.json`（295），运行时未接 |
| 地形/水/桥 | `[TerrainTypes]` | ❌ | 未接 |

## D. 特殊系统

| 规则 | RA2 事实源 | 状态 |
|---|---|---|
| 超武（SuperWeapons：核弹/天气/铁幕/时空） | `[SuperWeaponTypes]` | ❌ |
| 伪装/渗透（间谍/幻影/心灵控制） | `rules.ini` | ❌ |
| 音效 · 武器开火音（`Weapon Report=`） | `sound.ini` + MIX(`audio.idx`/`audio.bag`) | ✅ 第 3 批 |
| 音效 · 单位语音（`VoiceSelect/VoiceMove/VoiceAttack/VoiceFeedback/DieSound/CrushSound/DeploySound`） | `rules.ini` → `sound.ini` | ✅ 第 4 批 |
| 音效 · EVA（`eva.ini` 事件播报） | `eva.ini` + `sound.ini` | ❌ 未接 |

## G. 部署/卧倒 + 采矿（第 6 批，2026-10-12）

> 本轮不是新规则，而是两条已迁规则的**回归修复 + 手感打磨**（用户口令：大兵不能卧倒、要单点能放主技能；矿车倒车入库 + 采矿优化）。

| 规则 | RA2 事实源 | 状态 | 落地位置 |
|---|---|---|---|
| 卧倒能力 | `rules.ini [E1] Deployer=yes` | ✅ 第 6 批 | `data.deployer`（`build.mjs` 已有，`faction.mjs` 本轮补落到 `ra2_allied.json`） |
| 卧倒姿态帧 | `art.ini [GISequence] Deployed=292,1,1` | ✅ 第 6 批**回归修复** | `build.mjs::deployedFrameOf()` → `deploy_frame=292`（引擎取 292..299，图集 744 帧） |
| 卧倒战斗加成 | 本作卡池设定 | ✅ | `deploy_attack_mult=1.5` / `deploy_defense_mult=1.15` |
| 命令栏「部署 (D)」 | — | ✅ 第 6 批修复 | `battle.deploy_selected()` → `unit.deploy()`；旧版调不存在的 `u.deploy()` 静默无反应 |
| 单点释放主技能 | `skills.json ap_deploy` | ✅ 第 6 批 | `deploy()/set_deployed()/can_deploy()/is_deployed()`；radius 0 → 单击即放，无矄准两步 |
| 矿车倒车入库 | — | ✅ 第 6 批 | `_lock_dock()/_dock_stage()/_reverse_to()/_dock_occupied()`；入库段车头朝外 |
| 矿点认领分流 | — | ✅ 第 6 批 | `ResourceNode.claim_by/claim_release/claim_held_by`（弱引用）+ `_ore_target()` 优先未认领 |
| 卸矿口排队 | — | ✅ 第 6 批 | 泊位被占时在待泊位等，超时 6s 强行入库 |

**回归根因**：`deploy_frame` 曾是一次性脚本 `p7_deploy.mjs` 直接写进 JSON（不在事实源链上），第 5 批全量重产 `ra2_allied.json` 时被丢掉 → 「能部署但躺不下去」。现已按 `art.ini` 数据化，重产不再丢。

## 建议的推进顺序（下一批）

> 第 2 批已完成：**攻击特效（A2）、移动（A3）、采矿卡死（A4）**；C 表「武器开火/弹道/命中」已由 A2 补齐为 ✅。
> 第 3 批已完成：**武器开火音效**（`Weapon Report=` → 真实 RA2 WAV，与炮口火光同帧）。
> 第 4 批已完成：**单位语音**（`rules.ini Voice*` → `sound.ini` → WAV）；选中/下令/集火/反馈/部署/阵亡/碾压/建筑阵亡共 8 条事件已接线。
> 第 5 批已完成：**电力系统**（`rules.ini Power=`/`Powered=` + `[General] Min/MaxLowPowerProductionSpeed`）——产电/耗电统计、低电建造/生产变慢（1.0→0.8→0.5）、`Powered=yes` 建筑离线、HUD 电力条。
> 第 6 批已完成：**部署/卧倒修复（单点主技能）+ 矿车倒车入库/采矿优化**（见 G 节）——非新规则，两条旧规则的回归修复 + 手感。

1. ~~音效~~ ✅ **第 4 批已完成**：武器开火音（第 3 批）+ 单位语音 8 条事件（第 4 批）。剩余：EVA 播报（`eva.ini`，与单位语音不同源）。
2. ~~电力系统~~ ✅ **第 5 批已完成**：Power 产出/消耗 + 低电惩罚（建造/生产 1.0→0.8→0.5、`Powered` 建筑离线）+ HUD 电力条。
3. **EVA 播报**（`eva.ini` 事件 → `sound.ini`；含「电力不足 / 电力恢复」，与电力系统天然衔接）。
4. **老兵等级**：击杀累计 → 老兵/精英，按 `VeteranAbilities/EliteAbilities` 提升伤害/射速/HP。
5. **苏军阵营运行时**：与 `faction.mjs` 同构再出一份 `ra2_soviet.json`（需确认苏军美术是否已提取）。
6. **命令集**：巡逻/警戒/守卫/停止（⚠️ **部署（D）第 6 批已修复**并改为单击主技能）。
7. **地形/水 + `MovementZone`/`SpeedType` 通行性**，以及**建造耗时公式**与**超武**。

> 说明：本台账只记「规则」。卡池（D）、音效（E）、海军（C2）等**原创或卡素材**项不在此列。

---

## H. 星际2 化视觉（第 7 批，2026-10-12）

**定位**：纯表现层升级，不涉任何规则与判定几何（探针 20/20 断言「判定零变化」）。

| 项 | 改造前 | 改造后 |
|---|---|---|
| 地面 | 80px 硬网格 + 双色棋盘格（p25=p50=p75=0.112） | 程序化岩地：可平铺 fbm + **周期化 Voronoi 岩板** + 岩层脉络 + 颗粒（p50 0.274~0.360，sd 0.09~0.14） |
| 障碍 | 扁平多边形（0.14,0.16,0.2 描边） | **伪 3D 岩台**：轮廓不变，向上挤出岩壁（逐边四边形按法线明暗）+ 受光顶面（逐顶点着色）+ 顺光接地影 |
| 水面 | 3 块纯色矩形 | `WaterLayer`：岸砾 → 岸影（下沉感）→ 三层水色 → 动态波纹 → 岸线泡沫呼吸 → 高光 |
| 矿点 | 扁平青色圆盘 | 立体结晶簇（受光面/暗面/折射面/尖端高光/地表光晕），随储量 k 增减；采空 = 暗淡裸地 |
| 光照 | 无统一光向；单位影子垂直向下 | 统一「阳光自左上」：岩台影右下、单位/建筑接地影右偏 `r*0.34`、`Iso.shadow()` 三层软边 |
| 后期 | 无 | `post_grade.gdshader` + `PostLayer`（layer=1）：饱和度/对比/中间调提亮/暖高光冷暗部/左上阳光渐变/暗角/颗粒 |

**关键实现**：相机是 `45°+Y×0.5`，纹理采样 `v×0.5` 做各向异性补偿，屏幕上看岩板才不扁；岩台挤出用 `Iso.begin()` 直立空间，地面点 `dir(p)`、顶面点 `dir(p)-(0,h)`，挤出只在轮廓**上方** → 落点轮廓仍等于碰撞多边形。

**验证**：`_probe_v7` 20/20 PASS（碰撞多边形==所见轮廓 12/12、矿点碰撞半径 = radius×0.85、岩体物理层 layer 3、`Iso.inv_k()=2.00`、相机 zoom=2.0、`PostLayer.layer=1` 低于 HUD(20)、`WaterLayer.rects` 即逻辑水域）；`editor exit=0`。纹理生成 376ms（一次性）。

**未做**：单位/建筑位图着色（RA2 黑描边像素与 3D 感地表仍有割裂，候选：sprite grade 着色器或改走矢量画法）、地形高度与 `MovementZone`/`SpeedType`、道路/装饰岩群。


---

## I. 引擎整合 ts-ra2：命中判定与攻击特效（第 8 批）

### I.0 定位
纯规则/表现层，**判定几何零变化**。参考实现 `refs/ts-ra2` 只读参考。用户指令：「C（保留 RA3 皮肤，电力做 RA2 信息密度）然后引擎逻辑整合一下 ra2 那个 gitclone 的东西，现在碰撞打击感、攻击特效一坨屎」。

### I.1 先量后改得到的 5 条事实性偏差
1. **AnimList 选档**：参考 `Warhead.pickExplodeAnim()` 是 `clamp(floor(damage/25),0,n-1)`，本工程原为**列表随机取一** → 已更正（见 I.6 台账修正）。
2. **溅射衰减**：参考为 `PercentAtMax` 线性 `lerp(dmg, pam*dmg, 距离/格数)`，本工程原为自创 `clamp(1-d/(aoe+1)*0.5, .5, 1)` → 已按参考重写。
3. **Verses 必须逐目标结算**：本工程弹道武器原把「发射时对原目标算好的一份伤害」照抄给溅射内所有人 → **弹道武器完全不吃护甲表**，已修为逐目标过 Verses。
4. **量化**：`computeDamage()` 结尾正数 `floor`、负数 `ceil` → 已在 `receive_hit()` 前补 `Ra2Damage.quantize()`。
5. **ProneDamage**：RA2 对卧倒目标减免；本工程「部署据守」即 Prone 状态 → 已接线。

### I.2 参考实现有、本工程新增的 4 个反馈件
| 件 | 数据来源 | 实现 |
|---|---|---|
| 受击摇晃 | `[Warhead] Rocker=yes` | 强度 `clamp(dmg/300,0,1)`、时长 `34 tick / 15 TPS`、峰值 `PI/4`、抛物线 `1-(2s-1)²`；投影到 `Iso.begin()` 直立空间成 2D 仿射矩阵 |
| 命中火花 | `[Warhead] Sparky=yes` | `Effects.Sparks` |
| 命中闪光 | `[Warhead] Bright=yes` | `Effects.Flash`（伤害 ≥ 50 触发） |
| 地面灼痕 | `[Warhead] Deform=` / `DeformThreshhold=` | `DecalLayer`（z_index=-4，无碰撞体） |

### I.3 新增/改动文件
- 新增 `scripts/core/ra2_damage.gd`（`class_name Ra2Damage`）：命中模型唯一事实源，逐条对应 `Warhead.computeDamage/detonate/pickExplodeAnim`、`Vehicle.applyRocking`。
- 新增 `scripts/world/decal.gd`（`class_name DecalLayer`）：战损贴花层。
- `scripts/core/ra2_fx.gd`：`play_impact()` 统一弹着入口 + `spawn_scorch()`；修正 AnimList 文档注释。
- `scripts/core/effects.gd`：`Sparks` / `Flash`。
- `scripts/core/combat.gd`：`full_damage()` 增 `dist_px` / `target`，插入 ProneDamage 与 CellSpread 衰减。
- `scripts/units/projectile.gd`：`base_damage`（武器原始 Damage=）+ `_explode()` 按参考实现逐目标结算。
- `scripts/units/unit.gd`：`receive_hit(..., warhead_id)` + 量化 + 受击摇晃 + `is_prone()`。
- `scripts/buildings/building.gd`：同上三处。
- `scripts/ui/hud.gd`：电力牌（产电/耗电/余量赤字 + RA2 原文低电提示）。

### I.4 铁律自查
- **判定几何**：`Iso.inv_k() = 2.00`（K=0.5）未动；岩体碰撞多边形未动；表现层（ground/water/decal/post）**零碰撞体**；摇晃/贴花/火花全是纯绘制。
- **可验证**：`_probe_v8` **72/72 PASS**（含完整性闸门：运行时中断即 FAIL）；`editor exit=0` / `battle exit=0`；有头离屏截图见对比图。

### I.5 未做（明确边界）
`SplashList`（水面弹着，需扩管线）、`WeaponNullifyAnim`（`[AudioVisual]` 未提取）、`InfDeath` 逐武器步兵死亡动画（数据已提取、接线留下一批）、原版 `art.ini Crater/Scorch` 贴花贴图（灼痕为程序化绘制，规则口径仍以 `Deform=` 为准）、`AffectsAllies`（按默认 no）。另：本作 rules 提取值中**无任何弹头 `Sparky=yes`**，火花能力已实现但按数据不触发，待复核管线。

### I.6 台账修正（原 A2 节）
原 A2 把「命中动画（AnimList）」记为 **✅ 已对齐 —— 列表随机取一**。经与参考实现核对，**该记载是错的**：RA2 是按伤害选档。本批已把实现改为 `clamp(floor(damage/25),0,n-1)`，并在此更正台账。A2 其余记载（`Report=/StartSound=`、弹着动画按 `Bright=` 决定是否加亮）不变。
