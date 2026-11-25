# CHANGELOG —— 技能归属：通用技能 / 抽取技能

## 一句话

技能库正式分成两类：**通用技能**（开局人人可用，7 个）+ **抽取技能**（需消耗军需券抽取解锁，11 个，普通 / 稀有 / 史诗）。

## 为什么

之前 18 个技能对所有单位无条件开放，单位改造页可以直接随意装配，缺少「养成动力」。现在把强力的、有特色的技能放进抽取池，通用技能保证新玩家开局就有可用的技能组合。

## 数据（`data/skills.json`，version 1 → 2）

- 每个技能新增 `unlock` 字段：`base`（通用）/ `gacha`（抽取）。缺省值取 `unlock.default`（当前 = `gacha`）。
- 抽取技能新增 `rarity` 字段：`common` / `rare` / `epic`。
- 新增顶层 `unlock` 配置块：
  ```json
  "unlock": {
    "default": "gacha",
    "labels": { "base": "通用技能", "gacha": "抽取技能" },
    "draw": { "enabled": true, "name": "技能抽取", "currency": "credits", "cost": 600,
              "no_duplicate": true, "rarity_weight": { "common": 30, "rare": 12, "epic": 4 } }
  }
  ```
- `defaults`（单位默认装配）已改为**只引用通用技能**，保证任何存档开箱即用。

### 通用技能（7）
烟幕弹 `ap_smoke`、引擎超载 `ap_overdrive`、聚焦射击 `ap_focus_fire`、维修力场 `ap_repair_field`、刺刀冲锋 `ap_bayonet`、复合装甲板 `ps_armor_plating`、空尖弹 `ps_hollow_point`。

### 抽取技能（11）
- 普通：侧翼突袭 `ap_flank`、涡轮增压 `ps_turbine`
- 稀有：纳米自愈 `ap_nano_heal`、反应装甲 `ap_reactive_armor`、电磁脉冲 `ap_emp_burst`、炮火覆盖 `ap_barrage`、高级光学 `ps_optics`、强化挖掘 `ps_excavator`
- 史诗：隐匿护罩 `ap_shroud`、狂暴模式 `ap_berserk`、自愈合金 `ps_regen`

## 代码

| 文件 | 改动 |
|---|---|
| `scripts/autoload/game_data.gd` | 新增 `skill_unlock` / `skill_draw` 配置与 `skill_unlock_kind() / is_base_skill() / is_gacha_skill() / skill_rarity() / skill_unlock_label() / skills_by_unlock() / skill_draw_rules()` |
| `scripts/autoload/meta_progress.gd` | 新增 `unlocked_skills`（落盘）；`skill_unlocked() / unlock_skill() / owned_skills() / locked_skills() / owned_skill_count() / total_skill_count() / can_set_unit_skill() / unit_effective_loadout()`；抽取 `skill_draw_rules() / skill_draw_name() / skill_draw_cost() / skill_draw_currency() / skill_draw_candidates() / skill_draw_enabled() / can_draw_skill() / draw_skill()`；`set_unit_skill()` 改为返回 `bool` 并拒绝未解锁技能 |
| `scripts/autoload/events.gd` | 新增信号 `meta_skill_unlocked(skill_id)` |
| `scripts/units/unit.gd` | 接入 `MetaProgress.unit_effective_loadout()`：未解锁技能不装载 |
| `scripts/screens/meta_screen.gd` | 单位改造页新增「技能库」面板（已解锁 X/Y、未解锁清单、通用技能清单、技能抽取按钮）；装配下拉只列已解锁技能；单位列表的技能计数改用有效装配 |
| `scripts/autoload/gm.gd` / `scripts/admin/gm_console.gd` | 新增 GM 命令 `cmd_unlock_all_skills()` / `cmd_reset_skills()` 及按钮 |

## 行为约束

- **通用技能不落盘**：`unlock` 为 `base` 的技能恒为可用，存档只需记录抽取得到的技能 id。
- **未解锁即无效**：即使旧存档里装着抽取技能，`unit_effective_loadout()` 也会把它过滤成空，运行时与 UI 一致。
- **不重复抽取**：抽取池 = 未解锁的抽取技能，抽满即失去抽取入口（按钮变为「技能已全部解锁」）。
- 抽取货币 / 单价 / 权重全部走数据；军需券主要来自挂机收益。

## 验证

- 导入：无 Parse Error / SCRIPT ERROR，`MetaScreen` 正常注册。
- 冒烟：`SMOKE_SUMMARY ok=174 fail=0`（上一版 159，新增 15 项技能归属 / 抽取用例）。
- 实拍：单位改造页技能库面板（7/18、未解锁清单、抽取按钮）显示正常。

## 后续

- 抽卡单位接入时，单位也可沿用同一套 `unlock` 口径。
- 技能抽取后续可并入统一抽卡系统（保底、多抽、十连），当前为最小可用单抽实现。
