# 变更说明：局外养成（逐单位改造）+ 单位技能系统

## 1. 需求

> 「养成局外是指针对每一个单位进行改造，暂时显示定制攻击力和防御力以及技能加强；要做红警3 那种一个单位带技能的，预留一个单位能装 4 个技能 + 1 个被动，UI 要显示。」

## 2. 结论

- 局外养成从「全局等级」升级为 **逐单位改造**：每个单位独立强化 **定制火力（攻击）/ 定制装甲（防御）/ 技能强化**。
- 新增 **单位技能系统**（红警3 式）：每个单位 **4 个主动技能槽 + 1 个被动技能槽**，UI 在「驻防基地 → 单位改造」页装配，战斗中在屏幕底部技能栏显示并可释放。
- 全部改动 **永久生效**，写入存档（`unit_levels` / `unit_loadouts`）。

## 3. 数据层

| 文件 | 说明 |
|---|---|
| `data/skills.json` | **新增**。技能库：12 个主动 + 6 个被动；`slots = { active: 4, passive: 1 }`；`defaults` 为单位默认装配。 |
| `data/meta.json` | 新增 `unit_upgrades`：`slots`、3 条 `tracks`（atk / def / skill，含 `effect_per_level`、`max_level`、`cost_base`、`cost_growth`、`currency`）。 |

技能 `effect` 为数据驱动 token（`attack_buff` / `defense_buff` / `speed_buff` / `heal` / `stun` / `passive_armor` / `passive_damage` / `passive_speed` / `passive_sight` / `passive_regen` / `passive_harvest`），多个用 `+` 连接。

## 4. 代码层

| 文件 | 改动 |
|---|---|
| `scripts/units/ability.gd` | **新增**。`class_name Ability`：技能运行时（冷却、持续、激活），`setup/tick/ready/is_active/cd_frac/trigger_cooldown`。 |
| `scripts/autoload/game_data.gd` | 加载 `skills.json` → `skills / skill_slots / skill_defaults / skill_index`；新增 `get_skill()`、`skills_of_type()`。 |
| `scripts/autoload/meta_progress.gd` | 新增 `unit_levels` / `unit_loadouts` 存档字段；新增逐单位 API：`unit_upgrade_tracks / unit_slot_counts / unit_level / unit_upgrade_cost / can_buy_unit_upgrade / buy_unit_upgrade / unit_stat_bonus / unit_upgrade_summary / unit_default_loadout / unit_loadout / set_unit_skill / clear_unit_loadout`。 |
| `scripts/autoload/events.gd` | 新增信号 `meta_unit_upgraded`、`meta_loadout_changed`。 |
| `scripts/units/unit.gd` | `_init_skills()`：装配主动/被动、叠加逐单位改造加成与技能强度；`_apply_passive()`；`_tick_skills()` + `_ability_mult()` 实现限时增益；`_physics_process` 新增瘫痪（stun）与被动回血处理；新增 `use_ability / ability_info / ability_count / ability_ready / has_skill_bar / stun / _heal_around / _stun_around`。 |
| `scripts/world/battle.gd` | 新增 `use_ability_selected(slot)`、`selected_skill_unit()`。 |
| `scripts/ui/hud.gd` | 新增底部 **单位技能栏**（选中条上方，4 主动 + 1 被动）；Q/W/R/D 快捷键；冷却实时显示（仅在就绪/冷却切换时更新）。 |
| `scripts/screens/meta_screen.gd` | 新增页签「后勤 / 档位」与「单位改造」；单位改造页 = 单位列表（阵营筛选）+ 改造详情（3 条升级轨道 + 4 主动槽 + 1 被动槽 + 清空装配）。 |

## 5. 数值口径

- 逐单位改造：攻击 +3%/级（上限 12）、减伤 +2.5%/级（上限 12）、技能强度 +6%/级（上限 10，冷却同步缩短）。
- 升级花费：`cost_base × cost_growth^level`（火力/装甲 80 军需券起，技能强化 160 战略核心起）。
- 技能强度（局外「技能强化」）同时放大技能数值与缩短冷却 `cd / max(0.6, skill_power)`。
- 战斗内技能栏只对 **选中单位中第一个带技能的单位** 显示；点击按钮或 Q/W/R/D 对全部选中单位批量释放。

## 6. 验证

- 冒烟回归：`SMOKE_SUMMARY ok=159 fail=0`（上轮 122 → 本轮 +37：29 项数据/战斗技能回归 + 8 项单位改造页回归）。
- 关键断言：技能库加载、槽位 4+1、默认/自定义装配、逐单位升级使属性倍率上升、单位技能装载/释放/冷却、EMP 瘫痪冻结位移、HUD 技能栏出现、单位改造页构建与购买。
- 实拍：`iso_ability.png`（战斗技能栏）、`iso_meta_units.png`（单位改造页）。
- 导入日志无 Parse Error / SCRIPT ERROR；`import_err.txt` 0 B。
