# CHANGELOG · 第 8 批：引擎整合 ts-ra2（命中判定 / 攻击特效）+ 电力牌

> 用户原始指令：**「C 然后我们引擎逻辑整合一下 ra2 那个 gitclone 的东西，现在碰撞打击感 攻击特效一坨屎」**
> 定位：**纯规则/表现层**。三条铁律照旧 —— RA2 是规则唯一事实源、判定几何 WYSIWYG、每步必须可验证。

---

## 0. 先量后改：把「一坨屎」拆成可验证的 5 条

动手前先把参考实现 `refs/ts-ra2`（GPL 参考工程，只读参考）的命中模型与本工程逐条对照，得到 5 条**事实性偏差**（不是审美问题）：

| # | 参考实现（ts-ra2） | 本工程改造前 | 后果 |
|---|---|---|---|
| 1 | `Warhead.pickExplodeAnim()`：命中动画**按伤害选档** `clamp(floor(damage/25),0,n-1)` | `Ra2Fx.play_any()` **列表随机取一项** | 步枪弹 10 伤害会摇出最大的爆炸图；重炮反而可能放小火花 → 打击感「读不出来」 |
| 2 | `Warhead.detonate()`：`PercentAtMax` 线性衰减 `lerp(dmg, pam*dmg, 距离/格数)` | 自创 `clamp(1 - d/(aoe+1)*0.5, 0.5, 1.0)` | 溅射边缘伤害与 RA2 不符（数值全错） |
| 3 | `Warhead.computeDamage()`：**每个目标各自过 Verses(护甲)** | 弹道武器把「发射时就着原目标算好的一份伤害」**照抄给溅射里所有人** | **弹道武器完全不吃护甲表**：火箭打重坦克和打步兵同伤害 → 这是「打上去没感觉」的主因 |
| 4 | `computeDamage()` 结尾：正数 `floor`、负数 `ceil` | 直接拿浮点扣血 | 伤害有小数尾巴，与 RA2 数值不齐 |
| 5 | `Warhead.computeDamage()`：`ProneDamage=` 对卧倒目标减免 | 未实现（而第 6 批刚做完「部署卧倒」） | 卧倒没有战术收益 |

外加参考实现里有、本工程完全没有的 4 个「打击感」件：**`Rocker=yes` 受击摇晃**、**`Sparky` 命中火花**、**`Bright` 命中闪光**、**`Deform`/`DeformThreshhold` 地面灼痕**。

> 结论：不是美术不够，是**命中反馈这条链路根本没接完**。故不走换美术，走「按参考实现逐条补齐」。

---

## 1. 新增：`scripts/core/ra2_damage.gd`（命中模型唯一事实源）

`class_name Ra2Damage`，纯静态。逐条对应参考实现：

| API | 对应参考实现 | 语义 |
|---|---|---|
| `PX_PER_CELL = 55.0` | — | 1 格 = 55 世界像素（探针断言与 `Ra2Sfx.PX_PER_CELL` 同值，消除二义） |
| `cells(wh)` / `percent_at_max(wh)` / `prone_damage(wh)` | `WarheadRules` | `[Warhead] CellSpread=` / `PercentAtMax=`（缺省 100%）/ `ProneDamage=`（缺省 1.0） |
| `distance_factor(dist_px, wh)` | `Warhead.detonate()` | `t = clamp((dist/PX_PER_CELL)/CellSpread); lerp(1, PercentAtMax, t)` |
| `in_spread(dist_px, wh)` | 同上 | 出圈不掉血 |
| `target_damage(base, wh, target, dist_px)` | `computeDamage()` | Verses(目标护甲) → ProneDamage → CellSpread 衰减 |
| `quantize(v)` | `computeDamage()` 结尾 | 正数 `floor`、负数 `ceil` |
| `anim_index(wh, dmg)` / `pick_impact_anim(wh, dmg)` | `pickExplodeAnim()` | `clamp(floor(dmg/25),0,n-1)`；`EMEffect=yes` 的弹头保持随机（RA2 原语义） |
| `rocking_intensity/seconds/tilt/xform` | `Vehicle.applyRocking()` + `Vehicle.ts` | 强度 `clamp(dmg/300,0,1)`、时长 `34 tick / 15 TPS`、峰值 `P = PI/4`、抛物线 `1-(2s-1)²` |
| `is_rocker/is_sparky/is_bright/deform_ratio/deform_threshold/should_deform/deform_radius_px` | `[Warhead]` 各键 | Rocker / Sparky / Bright / Deform=15% / DeformThreshhold= |

## 2. 新增：`scripts/world/decal.gd`（`class_name DecalLayer`）

战损贴花层，画地面灼痕。**规则口径是 `[Warhead] Deform=`/`DeformThreshhold=`**（RA2 真实字段），落不落、落多大由 `Ra2Fx.spawn_scorch()` 决定；本文件只负责画。
- 画法与 `WaterLayer` 一致：地平面元素**裸画世界坐标**，不调 `Iso.begin()`，交给相机做 45° 旋转 + K 压扁 → 自动得到等距贴地形状。
- 形状用「8 个偏移圆叠出不规则边 + 焦黑内核 + 极少余烬」，**不用多边形** → 规避第 7 批踩过的 `canvas_item_add_polygon` 三角化失败。
- `z_index = -4`（水面上、单位下），上限 140 张；**无任何碰撞体**。

## 3. `scripts/core/ra2_fx.gd`

- 修正文档注释：`AnimList=` 由「列表里随机取一项」改为「按伤害选档」。
- 新增统一入口 **`play_impact(host, wh, dmg, pos)`**：按伤害取弹着动画 + `Sparky` 火花 + `Bright` 闪光（伤害 ≥ 50）。
- 新增 **`spawn_scorch(host, wh, dmg, pos)`**：由 `Ra2Damage.should_deform()` 决定是否落灼痕，贴花层按需创建并挂在 effects host 下。
- `play_any()` 保留，只服务 `EMEffect` 与回退路径。

## 4. `scripts/core/effects.gd`

新增两个反馈件：**`Sparks`**（放射短线，0.3s，对应 `Sparky=yes`）与 **`Flash`**（扩张白盘，0.13s，对应 `Bright=yes`）。

## 5. `scripts/core/combat.gd`

`full_damage()` 增参 `dist_px`（弹着点距离）与 `target`，在 Verses 之后、量化之前插入 **ProneDamage** 与 **CellSpread/PercentAtMax 衰减**，全部委托 `Ra2Damage`。旧调用点不传新参 → 行为向后兼容。

## 6. `scripts/units/projectile.gd`（**本批最大规则修正**）

- 新增 `base_damage = weapon.damage`（**武器 rules 原始 Damage=**，`setup()` 内取，无需改调用方）。
- `_explode()` 重写为按参考实现结算：
  - `CellSpread > 0` → 圈内**每个**目标各自 `base × Verses(它自己的护甲) × PercentAtMax衰减`，再乘攻击方加成，交 `receive_hit()`；
  - `CellSpread == 0` → 单目标同样过 Verses（**改造前弹道武器的单发也一样不吃护甲表**）；
  - 非 RA2 弹头保留原有经验衰减（向后兼容）；
  - 命中动画改为按伤害选档，并把地面灼痕落实在爆点。
- `_spawn_ra2_impact(dmg)` 改为委托 `Ra2Fx.play_impact()`。

## 7. `scripts/units/unit.gd`

- `receive_hit()` 增参 `warhead_id`；扣血前 **`Ra2Damage.quantize()`**（正 floor / 负 ceil）；命中后按 `Rocker=yes` 触发受击摇晃。
- `is_prone()`：RA2 的 Prone 状态 = 本工程的「部署据守」（第 6 批），`ProneDamage=` 据此生效。
- **受击摇晃**（纯视觉，不动判定）：`_rock_t` / `_rock_amp` / `_rock_dir` / `rock_events`，`_start_rock()` + `_rock_update()`；`_draw()` 里把「绕地表水平轴倾斜 tilt」**投影到 `Iso.begin()` 的直立绘制空间**得到 2D 仿射矩阵（`Ra2Damage.rocking_xform()`），血条/选择环不跟着摇。
  - 门控照抄参考实现的 `isVehicle()` 语义：`kind == "infantry"` / `movement_zone == "Infantry"` / 护甲类 `none` / `is_air` 一律不摇。
- `_spawn_impact_anim(at, dmg)` 改为委托 `Ra2Fx.play_impact()`；无素材才回退程序化爆炸。
- 直击（瞬发武器）路径把 `target` 传入 `full_damage()` → 直击也吃 `ProneDamage`。

## 8. `scripts/buildings/building.gd`

同上三处：`full_damage(..., dist_px=0, target)`、`_spawn_impact_anim(at, dmg)` 委托 `play_impact`、`receive_hit()` 加 `quantize`、命中回传 `ra2_warhead`。

## 9. `scripts/ui/hud.gd`（用户选项 **C**：保留 RA3 皮肤，只把电力做成 RA2 信息密度）

顶栏电力条升级为**电力牌**（一个 `VBoxContainer`）：

```
⚡ 1200 / 900          ← 产电 / 耗电（两个数字，不再含糊）
[━━━━━━━━━━━━━━━]     ← 电力条 214×14（原 150×12）
余量 +300              ← 余量；不足则「赤字 −150」
                       低电时追加 RA2 原文：电力不足 - 生产减缓
```

配色：正常绿 → 余量 < 20% 或为负琥珀 → 低电红。低电文案取 RA2 原字符串（`localization.json` 的 `TXT_LOW_POWER`）。

---

## 10. 台账偏差修正（重要）

`RA2_RULES_MIGRATION.md` 的 A2 节原先把「命中动画」记为 **✅ 已对齐（列表随机取一）**；本次核对参考实现后确认**这是偏差**，已在新 §I 节标注更正，并把实现改为**按伤害选档**。

---

## 11. 验证（全部实测）

| 项 | 结果 |
|---|---|
| `_probe_v8` 无头探针 | **72/72 全绿，fails=0，VERDICT PASS** |
| 探针「完整性闸门」 | 新增：任何运行时错误导致断言提前中断 → 直接 FAIL（本轮正是靠它抓到两处真错，见 §12） |
| `editor exit=0`（注册 `Ra2Damage`/`DecalLayer`） | ✅ |
| `battle exit=0` | ✅ |
| 有头离屏截图 | 电力牌实时值 `⚡ 200 / 10` + `余量 +190`；同一位置 10 伤害 vs 9999 伤害弹着动画**肉眼可见不同且后者更大**；地面灼痕可见并留存 |

**探针关键断言（节选）**
```
[ OK ] HE CellSpread = 0.5 格 / AP CellSpread = 0.3 格 / SA 无溅射
[ OK ] AnimList：10 伤害 → 索引 0 ；60 → 2 ；9999 → 末位 7 ；AP 65 → 1（不再随机摇奖）
[ OK ] 溅射：爆心 100% / 半径一半 75% / 边缘 PercentAtMax 50% / 出圈不掉血
[ OK ] 量化：12.9 → 12（正 floor）；-3.2 → -3（负 ceil）
[ OK ] 同一弹头对不同护甲算出不同伤害（重甲 100.0 vs 无甲 25.0）；伤害 = 基础 × Verses(1.00)
[ OK ] 卧倒步兵吃 HE 伤害下降（100.0 → 70.0；ProneDamage = 0.7）
[ OK ] 载具被 Rocker 弹头命中 → 触发摇晃（rock_events 0 → 1）；非 Rocker 不触发；步兵不触发
[ OK ] 摇晃时长 = 34 tick / 15 TPS ≈ 2.27s；中点最大 45°
[ OK ] 伤害过阈值 → 该落灼痕；低于 DeformThreshhold → 不落；无 Deform= 的弹头（SA）不落
[ OK ] 表现层（ground/water/decal/post）无任何碰撞体（0 个）；等距投影 K 未被改动（inv_k = 2.00）
[ OK ] 电力牌显示 产电 / 耗电（当前“⚡ 200 / 10”）；显示 余量/赤字（当前“余量 +190”）
```

## 12. 本轮踩坑（记录在案）

1. **GDScript 没有 `cosf()/sinf()`** —— 只有 `cos()/sin()`（`floorf/ceilf/maxf/minf/clampf/absf/lerpf` 才有 f 变体）。编辑器 `--editor --quit` 当时没报，运行时才炸 → 说明**编译自检不能替代运行时探针**。
2. **`battle.tscn` 根节点不是世界逻辑**：根是 `scripts/screens/battle_screen.gd`（`BattleScreen`），世界逻辑在它的 `.battle` 子节点（`spawn_unit` 在这里）、HUD 在 `.hud`。探针必须经这两条路拿。
3. **`GameData.get_unit()` 返回的运行期字典里没有 `kind` / `movement_zone`**（原始 `units.json` 有，运行期索引被裁剪）→ 步兵判定只能用护甲类（`ra2_armor == "none"`）等其它信号，已按此实现门控。
4. **探针必须带完整性闸门**：GDScript 运行时错误会中断调用栈但**不会**让后续代码停摆，容易打出「假 PASS」（本轮第一版就是 `fails=0 ok=8` 的假绿）。
5. 相机每帧必须锁（否则鼠标停在窗口边缘触发边缘滚屏，截图里画面会跑掉）。

## 13. 未做 / 明确边界

- **`SplashList`（水面弹着水花）**：`rules.ini [CombatDamage] SplashList=` 未提取 → 需要扩 `ra2pipe` 管线；本轮未做，落水面仍走程序化回退。
- **`WeaponNullifyAnim`（`[AudioVisual]`，无敌/铁幕弹开特效）**：未提取。
- **`InfDeath` 逐武器步兵死亡动画**：数据已提取（`inf_death` 1..5），本工程步兵死亡目前只用 `Die1`；接线属于下一批。
- **`Sparky`**：本作 rules 提取值里**没有任何弹头是 `Sparky=yes`**（22 处全是 `no`）；能力已实现但按数据不会触发 → 待复核管线是否把缺失值默认成了 `no`。
- **原版贴花美术**：`art.ini [Animation] Crater=/Scorch=` 与 smudge SHP 未提取，故灼痕为**程序化绘制**，规则口径以 `[Warhead] Deform=` 为准。
- **`AffectsAllies`**：未提取，按 RA2 默认 `no` 处理（溅射只伤敌方）。
- 单位/建筑仍是 RA2 位图（第 7 批遗留，用户已选「先做引擎整合」）。
- 第 6 批遗留照旧：`Deploy=300,15,0` 展开/收起过渡动画、卸矿动画、`HarvestersPerRefinery` 跨厂负载均衡。
