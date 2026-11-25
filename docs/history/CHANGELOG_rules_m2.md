# CHANGELOG · RA2 规则迁移 第 2 批（移动 + 攻击特效 + 采矿卡死）

> 本轮口令：**「所有单位的攻击特效 移动 都没迁移 还有我们采矿卡死的问题也得迁移」**
> 铁律不变：RA2 是规则唯一事实源 / 判定几何 WYSIWYG / 每步可验证（无头自检 + 有头离屏截图 + 实测日志）。
> 自检结果：**攻击特效 41/41 PASS · 移动 8/8 PASS · 采矿 stalls=0 FAIL=0**（见 `RA2移植_移动与特效_自检日志.txt`）。

---

## 1. 攻击特效：程序化色块 → 真实 RA2 动画 SHP

### 迁移前
- 单位/建筑开火只有**程序化炮口色块**（多边形），命中是**程序化圆圈爆炸**。
- 弹道一律是可见光点 + 拖尾；没有 `Inviso`（枪弹在 RA2 里本来就没有可见弹体）。
- `weapon.Anim` / `warhead.AnimList` / `projectile.Image` 这些 rules.ini 字段**根本没被消费**。

### 迁移后（全部读取 rules.ini / art.ini 真值）
| RA2 事实源 | 落地位置 | 说明 |
|---|---|---|
| `[Weapon] Anim=` | `unit.gd/_spawn_muzzle_fx`、`building.gd/_spawn_muzzle_fx` | 炮口火光**真实动画 SHP**；最多 8 项＝按炮塔朝向取（N=0 顺时针，8 向逐个对应）。例：`105mm → GUNFIRE`；`M60/Vulcan2 → MGUN-N,NE,E,SE,S,SW,W,NW` |
| `[Weapon] Bright=` | 同上 | `Bright=yes` → `CanvasItemMaterial.BLEND_MODE_ADD` 叠加混合（RA2 的发光弹/闪光） |
| `[Weapon] Report=` | `data/ra2/weapons.json` | 已提取备好，**音效素材未提取，本轮未接线**（列入未完成） |
| `[Warhead] AnimList=` | `projectile.gd/_spawn_ra2_impact`、`unit.gd/_spawn_impact_anim`、`building.gd/_spawn_impact_anim` | 命中动画**真实 SHP**，列表内随机取一（RA2 语义）。例：`SA→PIFFPIFF`、`AP→S_CLSN16/S_CLSN22`、`HE→8 项(含 TWLT070)`、`Electric→TSTIMPCT`、`FlakWH→SMKPUFF`；`PrismWarhead→[]`（光棱本来就没有命中动画，**照搬**） |
| `[Warhead] CellSpread=` | `game_data.gd/ra2_cell_spread` + `projectile.setup` | 溅射半径改为 `CellSpread × 55px`，**覆盖引擎手写 aoe**。例：`HE=0.5格`、`AP=0.3格`、`SA=未定义→0` |
| `[Projectile] Image=` | `projectile.gd/_draw` | 可见弹体用真实 SHP：`Cannon→120MM`、`AAHeatSeeker→DRAGON` |
| `[Projectile] Inviso=yes` | 同上 | **不画弹体**（RA2 枪弹/光束）。实测：`FlakProj`、`InvisibleLow` 均 Inviso |
| `[Projectile] Arcing=yes` | `projectile.gd/_step_arc` | **抛物线弹道**（火炮/大炮），到点才结算 |
| `[Projectile] Shadow=yes` | `projectile.gd/_draw` | 升空时画地面阴影 |
| `[Projectile] ROT=` | `projectile.gd/_step_homing` | 有限转向速率的**追踪弹**（1/256 圈 / 1/15s）。`AAHeatSeeker ROT=80`、`AAHeatSeeker2 ROT=60` |
| `[Projectile] AA=` | （第 1 批已有）`ra2_aa` → `can_hit_air` | 本轮继续沿用 |

### 新增素材管线
- `ra2pipe/build.mjs` 新增输出 **`data/ra2/animations.json`**（53 条）：汇总所有被 `Weapon Anim=` / `Warhead AnimList=` 引用的动画名，取 art.ini 参数。
  - **帧率换算（关键口径）**：`fps = Rate / 60`，`Rate` 缺省 `900 → 15fps`。
    依据 `refs/ts-ra2`（Chrono Divide 权威实现）：`AnimProps.defaultRate = BASE_TICKS_PER_SECOND = 15`，`this.rate = art.getNumber("Rate", 60*15)/60`。实测 `RING1 Rate=300 → 5fps`、`NUKEANIM 400 → 6.67fps`。
- `ra2pipe/art_build.mjs` 新增 **`fx` 阶段**：从 MIX 提取动画 SHP → `assets/ra2/fx/<IMAGE>.png|json`（65 个动画，1.4MB）。
  - 调色板用 **`ANIM.PAL`**（动画专用，与单位/建筑的 `UNITTEM.PAL` 不同）。
  - **裁到「全动画并集包围盒」**：这样 cell 中心 == 动画内容中心，运行时只需把 cell 居中画在目标像素上，即与 RA2「动画居中于炮口/落点」一致。
  - `Shadow=yes` 的动画 SHP 后一半是黑影帧，只取前一半。
- `scripts/core/ra2_fx.gd`（新，`class_name Ra2Fx`）：动画播放器，逐帧按 `fps` 推进、播完自释放；`pick_directional()` 做 8 向挑图；`play_any()` 做 AnimList 随机。
- `scripts/core/ra2_art.gd`：新增 `fx(image)` / `fx_rect(m,frame)` / `has_fx()` + `_fx_cache`（独立于单位/建筑缓存）。
- `scripts/autoload/game_data.gd`：新增 `ra2_weapons` / `ra2_projectiles` / `ra2_animations` 加载与 `ra2_weapon()/ra2_projectile()/ra2_anim()/ra2_muzzle_anims()/ra2_muzzle_bright()/ra2_impact_anims()/ra2_cell_spread()`。

---

## 2. 移动：只有「速度标量」→ ROT / Accelerates / Crusher / MovementZone

### 迁移前
- 转向**瞬变**（`hull_angle = turret_angle = aim_dir.angle()`），坦克可以零半径原地瞬转。
- 速度是**按兵种手写的魔法系数**：步兵 `×26`、载具 `×15`、空军 `×24`（还各自 clamp）。
- `ROT / Accelerates / SpeedType / Crusher / Crushable / Weight / MovementZone` 全部**没被消费**；没有碾压。

### 迁移后
| RA2 键 | 换算（写死在 `ra2pipe/faction.mjs`，只此一处） | 落地 |
|---|---|---|
| `Speed=` | **统一口径** `px/s = Speed × MOVE_CELL_PX/3`（`MOVE_CELL_PX=45`，即社区口径「≈3 点 Speed = 1 格/秒」）。删掉 26/15/24 三个手写系数 | `move.speed`，`move.speed_units` 保留原值 |
| `ROT=` | `°/s = ROT × (360/256) × 15 = ROT × 21.09375`（`ROT` = 1/256 圈 / RA2 逻辑帧） | `move.rot`；`unit.gd/_limit_turn` 在每帧末对车体+炮塔各限速一次（不侵入各处的朝向赋值） |
| `Accelerates=` | 仅 `=yes` 才起停斜坡（`AccelerationFactor` 秒到全速） | `move.accel_time`；`unit.gd/_ramped_speed`。**盟军白名单内无单位开启**（全 rules.ini 里只有苏军 `[SUB]`/`[DLPH]` 是 yes）→ 不改变既有手感，属「照搬规则但零回归」 |
| `Crusher=` / `Crushable=` | 显式值优先；缺省 `Crushable` 按 RA2 惯例：步兵可被碾、载具不可 | `move.crusher` / `move.crushable`；`unit.gd/_crush_tick` 每 0.15s 检测，碾压可直接碾死 |
| `MovementZone=` / `SpeedType=` / `Locomotor=` / `Weight=` / `Dock=` | 原样带入运行时 | `move.*`（供后续地形/寻路用；`Dock` 已提取备用） |

> 实测（`_probe_move`）：MTNK 反向掉头 180° **用时 1.68s**，理论值 `180 / 105.469 = 1.71s` ✓；
> 一帧只转 1.7578°（=105.469/60）✓；炮塔同样限速 ✓；`E1`（无 ROT）瞬时转向 ✓；`Accelerates=false` 一帧到全速 ✓。

---

## 3. 采矿卡死：定位 → 根因 → 修复 → 复验

### 实测复现（旧代码，`_probe_harvest` 在真实 battle 场景跑 60s）
```
[PROBE] STALL @CharacterBody2D@107 st=to_node held=2.0s pos=(1099,2067) cargo=0
        vel=(-64.74,-22.07) pdelta=(0.0044,-0.0134) slide_n=1
        slide=["@StaticBody2D@93 n=(0.9937,0.1124)"]     ← 自家发电厂东面
        overlap=[[@StaticBody2D@93{side=ally,radius=22}], [@CharacterBody2D@107{side=ally,radius=15}]]
        node=@StaticBody2D@96 node_amt=5999.6
```
- 矿车想去 603px 外的矿脉，**直线奔赴**，一头顶在**自家发电厂**上：期望速度 97.6% 是**正面撞墙**分量，切向只剩 ~14.9px/s，实际每帧只挪 0.014px（0.84px/s）。
- 它**永远不会**进 `unloading`：`deliveries=0`，一直停在 `to_node`（跑到 3600 帧依然如此）。
- 附带损失：两台矿车到第一片矿脉花掉 **33s**（t=1995 才第一次 `harvesting`）。

### 根因
**采集行程没有挂寻路流场。** `_go_to()` → `_move_toward(p, use_field=true)` → `_steer_dir()` 只有在 `path_field != null` 时才用流场；而**只有修理工单**（`path_field = _field_for(_repair_dock)`）会挂流场，矿车从来不挂 → 全程直线 → 撞上建筑就楔死。
（引擎其实有完整的 `PathService` 流场，建筑占地已盖章进代价图，只是矿车没用。）

### 修复（`scripts/units/unit.gd`）
1. **挂流场（根因）**：新增 `_steer_field_to(p)`，在 `to_node` / `to_base` 两个行程里把流场指向当前目标（目标点移动 >20px 才重算，`PathService` 按格缓存，开销可忽略）；`harvesting` / `unloading` / 空闲时 `_clear_field()`。
2. **卡滞脱困（安全网）**：`_track_stuck()` 监测「本次行程最近距离」——1.2s 没有更接近目标就判定被顶住：①丢流场强制重算 ②侧向挪 9px 打破「正面顶墙＝零滑动」的死锁 ③连续 3 次仍不成 → 换目标。
3. **矿点黑名单**：`_ore_target()` 跳过 20s 内卡死过的矿点（全在黑名单时退回普通就近选择，绝不僵住）。

### 复验（同一条命令、同一张图）
```
[PROBE] stalls=0 FAIL=0
[PROBE]   @CharacterBody2D@107 deliveries=2 final=harvesting
[PROBE]   @CharacterBody2D@109 deliveries=1 final=harvesting
```
- 两台矿车**正常往返**：`to_node → harvesting → to_base → unloading(500) → to_node`。
- 第一次抵达矿脉：由 **33s → 9.2s**（t=585）。
- 抽出全部矿脉（t=2400 清零）后：**会自己改去别的矿点**（t=3225 已在最远那片），不再僵在空矿区。
- 途中还会在真·矿厂 `GAREFN` 卸矿（`_place_building` 成功、进 `unloading`）。

---

## 4. 顺带挖出并修掉的两个**真 bug**（都不是本轮引入的）

### bug ①（第 1 批遗留，严重）：`Object.get()` 传了 2 个参数 → RA2 护甲/Verses 通路**在实机里从来没生效过**
- `unit.gd` / `building.gd` 里写的是 `target.get("ra2_armor", "")`。Godot 4 的 `Object.get()` **只接受 1 个参数** → 实机开火时报
  `Invalid call. Nonexistent 'float' constructor / Expected 1 argument(s)`，并返回 `null` → `str(null)` = `"<null>"`。
- 后果：第 1 批「弹头 Verses 走真值」在**无头探针里 PASS**（探针直接调 `CombatMath`），但**真打起来是静默失效**的，退回引擎护甲表。
- 修法：`var t_ra2 = target.get("ra2_armor")` + 空值判断。
- **这是本轮「实机开火」检查才暴露出来的** —— 印证了「探针 PASS ≠ 实机 PASS」。
- 同类空值坑一并修掉：`float(null)`（`CellSpread` 未定义时）→ `GameData._num()`。

### bug ②（开局即「败北」）：建造场 `GACNST` 不在运行时白名单 → `_check_end` 立刻判负
- `battle.gd/_check_end`：`if _player_hq() == null: end_battle(false)`；`is_hq` 来自建筑 `tags` 含 `"hq"`。
- `GACNST` 的原始数据与美术（`assets/ra2/shp/GACNST*.png`）**都在**，只是 `ra2pipe/faction.mjs` 的 `BUILDING_TAGS` 漏了它 → 建造场不生成 → **开局第 1 帧就弹「败北」**。
- 修法：`BUILDING_TAGS` 补 `GACNST: ['structure','hq','production']`，重跑 `faction.mjs`（运行时 building 15 → 16）。
- 截图对比：修前画面被「败北」遮罩压暗；修后基地正常显示**盟军建造场**（4x4）。

---

## 5. 变更文件清单

**数据管线**
- `ra2pipe/build.mjs` — 新增 `animations.json` 输出（art.ini 动画参数 + `fps=Rate/60`）；`numOr/boolOr/asList` 辅助。
- `ra2pipe/art_build.mjs` — 新增 `fx` 阶段（ANIM.PAL 上色 + 并集包围盒裁切 + `Shadow` 半帧处理）。
- `ra2pipe/faction.mjs` — 新增 RA2 移动换算常量与 `buildMove()`（每个单位/建筑带 `move{}`）；`BUILDING_TAGS` 补 `GACNST`。

**引擎**
- `scripts/core/ra2_fx.gd`（新）— `Ra2Fx` 动画播放器。
- `scripts/core/ra2_art.gd` — `fx()` 特效动画表加载 + 缓存。
- `scripts/autoload/game_data.gd` — 武器/弹道/动画表加载与 7 个访问器；`_num()` 空值安全。
- `scripts/units/unit.gd` — `_spawn_muzzle_fx` / `_spawn_impact_anim`；`_mv/_ramped_speed/_limit_turn/_crush_tick`；`_steer_field_to/_track_stuck/_clear_field/_ore_target`（采矿修复）；修 `Object.get` 2 参数 bug。
- `scripts/units/projectile.gd` — `Image/Inviso/Arcing/Shadow/ROT` 全部落地；`CellSpread→aoe`；命中走 AnimList；空值安全。
- `scripts/buildings/building.gd` — 炮口火光 + 瞬发命中动画；修 `Object.get` 2 参数 bug。

**素材（新）**
- `iron_tide/assets/ra2/fx/*.png|json` — 65 个真实 RA2 动画（1.4MB）。
- `iron_tide/data/ra2/animations.json` — 53 条动画参数。

## 6. 本轮未完成 / 遗留
- **音效**：`Weapon Report=` / `Warhead StartSound=` 已提取进数据，但**音效素材（WAV）未提取、未接线**。
- `Weapon Anim= 8 向`目前用炮塔朝向挑图；RA2 对**步兵**是按身体朝向挑图，微差（未细分）。
- `MovementZone` / `SpeedType` / `Locomotor` 只带到运行时，**地形/水/可通行性还没做**（等地形系统）。
- `Dock=` 已提取但未用于 `_pick_home_base`（现在仍靠 `tags: refinery` + 兜底最近建筑）。
- 弹体 SHP 未按飞行方向旋转（RA2 的 `120MM`/`DRAGON` 本来也是固定朝向，属照搬）。
- 老兵等级 / 苏军运行时 / 命令集（巡逻·警戒·守卫）/ 超武 / 建造耗时公式：仍未迁移。
