# CHANGELOG —— RA2 规则迁移 第 1 批：战斗规则（护甲类别 + 弹头 Verses + 弹道防空）

日期：2026-10-11　范围：把「战斗」这一类 RA2 规则从**近似**改为**照搬 rules.ini**。

## 1. 改前 vs 改后

| | 改前（近似） | 改后（RA2 事实源） |
|---|---|---|
| 护甲 | 引擎 6 类（unarmored/light/medium/heavy/structure/air），由 `faction.mjs` 的 `ARMOR` 表**有损压缩**（flak→light、plate→medium、wood/steel/concrete→structure） | **RA2 真实 11 类**（none/flak/plate/light/medium/heavy/wood/steel/concrete/special_1/special_2），运行时新增 `ra2_armor` 字段 |
| 伤害克制 | 引擎 7×6 手写克制表 `data/combat.json` + `whType()` 按**弹头名字猜**攻击类型 | **warhead.Verses[目标护甲类别]**，逐弹头逐护甲的真实倍率（83 个弹头） |
| 防空 | `armor_multiplier(attack_type,"air") >= 0.6`（近似） | **弹道 AA 标志**（rules.ini `[Projectiles] AA=yes`），运行时新增 `ra2_aa` |
| 单位武器 | 部分**手写覆写**（SREF/TNKD/ORCA/BEAG）偏离 RA2 | 一律取 RA2 真实 `Primary=`/`Weapon1..N`（覆写表已删） |
| 建筑武器 | 手写 `DEF_WEAPON`（GAPILL/ATESLA/GTGCAN） | 取 RA2 真实 `Primary=`（build.mjs 现已提取建筑武器） |

## 2. 管线改动

- **`ra2pipe/lib/ini.mjs`**：注释解析同时剥离 `;` 与 `//`。此前 `[MirageWH]\t// Supposed to be a heat ray.` 因段头带 `//` 注释**不被识别为段头**，整段被吞进上一段 → 幻影坦克弹头 `MirageWH` 丢失。修后 `warheads` 82→83。
- **`ra2pipe/build.mjs`**：
  - 单位/建筑武器支持 `Weapon1..N`（`WeaponCount`）兜底：`[SREF]` 的 `Primary=` 被注释掉，实际用 `Weapon1=Comet`。
  - 建筑提取新增 `primary/secondary/elite_primary/elite_secondary/weapon_count`。
  - 新增 **`data/ra2/projectiles.json`**（49 条）：`aa`（防空）、`image/inviso/arcing/dropping/rot/shadow/proximity/vertical`。
  - 弹头 `Verses` 缺省槽位按 RA2 语义补 **100%**（ModEnc：未列出的护甲默认 100%）。
- **`ra2pipe/faction.mjs`**：
  - 运行时单位/建筑新增 `ra2_armor`（真实类别）。
  - 运行时武器新增 `ra2_weapon_id` / `ra2_warhead` / `ra2_projectile` / `ra2_aa`。
  - 删除 `UNIT_WEAPON_OVERRIDE` 与 `DEF_WEAPON`。
  - ROF→秒 用 **15 fps**（RA2 逻辑帧率）：`cooldown = rof/15`；射程 55px/格；冷却上限放宽到 30s（原 8s 会把巨炮/光棱等截断）。

## 3. 引擎改动

- **`scripts/autoload/game_data.gd`**：加载 `ra2/warheads.json`，新增
  `RA2_ARMOR_ORDER` / `RA2_ARMOR_LABELS` / `ENGINE_TO_RA2_ARMOR` / `RA2_TO_ENGINE_ARMOR` /
  `ra2_verse(warhead, class)`（无数据返回 -1 触发回退）/ `has_ra2_warhead` / `to_ra2_armor` / `to_engine_armor` / `ra2_armor_label`。
- **`scripts/core/combat.gd`**：
  - `raw_damage(weapon, target_armor, target_ra2_armor="")`：武器带 `ra2_warhead` 时按 Verses 结算，否则回退旧克制表。
  - 新增 `can_hit_air(weapon)`：`ra2_aa` 优先，回退旧表。
  - `full_damage(...)` 增加第 5 参 `target_ra2_armor`。
  - `describe_weapon`：RA2 武器按 11 类护甲列出「克制/弱于」并标注「可打空」。
- **`scripts/units/unit.gd`**：新增 `ra2_armor` 字段并在 `_apply_data` 读入；`can_hit_air = CombatMath.can_hit_air(weapon)`；`_fire_shot` 传入目标 `ra2_armor`。
- **`scripts/buildings/building.gd`**：同上（`ra2_armor` 字段 + 防空判定 + 伤害传入目标 `ra2_armor`）。

## 4. 兼容性（关键）

双轨并存，**旧内容不受影响**：
- RA2 单位：`armor`（旧词表，给旧路径/UI）+ `ra2_armor`（真实类别）。
- 引擎自带单位（`data/units.json`）：无 `ra2_warhead`/`ra2_armor` → 走旧克制表。
- 跨阵营交战：RA2 打自带 → `to_ra2_armor(旧词表)`；自带打 RA2 → `to_engine_armor(RA2 类别)`。

## 5. 实测证据（探针 FAIL=0，24/24 PASS）

```
OK   GameData ra2_loaded
OK   warheads loaded            n=83
OK   MirageWH present
OK   SA vs heavy = 15*0.25      got 3.750
OK   SA vs none = 15*1.0
OK   AP vs heavy = 65
OK   AP vs light < heavy
OK   legacy fallback (no warhead)
OK   unknown warhead -> fallback
OK   structure -> concrete
OK   flak -> light (engine)
OK   heavy passthrough
OK   AA flag true
OK   AA flag false
OK   legacy bullet no AA
OK   FV can hit air (IFV)       wh=HE
OK   MTNK cannot hit air
OK   MTNK ra2_armor=heavy
OK   SREF real weapon (Weapon1=Comet)   id=Comet
OK   SREF warhead CometWH
OK   GAPILL real weapon         wh=SA
OK   GAPILL ra2_armor set
OK   describe_weapon RA2        克制 木甲(×2.00) · 弱于 中甲(×0.50)
FAIL=0
```

战斗场景无头 300 帧：exit 0，无 ERROR/SCRIPT ERROR（仅既有告警：地图引用的 `GACNST` 不在运行时白名单，与本次无关）。

## 6. 结论：迁移带来的可见变化

- E1 小枪对**重甲**只造成 **25%** 伤害（旧近似为 100%）——步兵打坦克不再有效。
- **FV（IFV）现在真的能防空**（旧近似把它当"shell"，打不到空中）。
- **SREF 光棱坦克**恢复真实武器 `Comet`：对木甲 ×2.00（拆建筑强）、对中甲 ×0.50（打坦克弱）。
- **幻影坦克**弹头 `MirageWH` 找回（旧数据丢失）。
- 防御建筑（机枪塔/光棱塔/巨炮）改用真实武器数值。
