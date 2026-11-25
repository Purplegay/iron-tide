# IronTide 摘录：raw_memories.md

来源：C:\Users\admin\.codex\memories\raw_memories.md。原始混合文件未修改，只提取相关段落。

## 原文件第 1577–1649 行

## Thread `01a15738-0ad1-7182-9e57-531f16793b2b`
updated_at: 2026-11-12T05:59:14+00:00
cwd: \\?\C:\Users\admin\KFramework_server
rollout_path: \\?\C:\Users\admin\.codex\sessions\2026\10\20\rollout-2026-10-20T10-50-53-01a15738-0ad1-7182-9e57-531f16793b2b.jsonl
rollout_summary_file: 2026-10-20T02-50-53-w2iT-irontide_bridge_fix_performance_call_logging_hero_design.md

---
description: IronTide multi-task rollout: enemy superweapon alerts, miner-income progression, incomplete E2 hero-contract draft, bridge stale-reference fix, and per-battle performance call logs; strong default user preference to avoid screenshots and diagnose using logs/headless checks.
task: IronTide bridge navigation fix and performance instrumentation; preserve unimplemented hero-contract design and low-screenshot preference
task_group: Godot RTS game development, regression testing, performance diagnostics
 task_outcome: partial
cwd: C:\Users\admin\IronTide
keywords: IronTide, Godot 4.7.2, bridge, _slide_across_bridge_layers, is_instance_valid, freed instance, battle_call_log, battle_call_counters, performance_calls, E2, furnace_contract, screenshots, headless
---

### Task 1: Enemy superweapon alerts and visibility

task: Make completed enemy strategic sites announce detection and remain visible while alive
task_group: IronTide gameplay and fog-of-war
 task_outcome: success

Preference signals:
- No meaningful task-specific preference evidence.

Reusable knowledge:
- Detection voice definitions are in `iron_tide/data/ra2/eva_specs.json`; EVA playback/dedup and alert routing are in `iron_tide/scripts/core/ra2_sfx.gd`.
- Enemy sites are delivered via `Battle.deliver_ready_structure`; firing-time-only temporary reveal is not enough to keep a completed site visible.

Failures and how to do differently:
- An initial completion regression conflated building deployment animation with launch readiness. In related tests, separate placement/build-art progression from readiness to fire.
- Fog regression suite reported four unchanged draw-metadata assertions even after the feature was removed in an isolated copy; keep baseline failures distinct from changed-code regressions.

References:
- `superweapon_alert_regression`: 248 passed; `superweapon_sidebar_regression`: 110 passed.
- Fix documentation: `docs/fixes/v0.26.6.7/README.md`.

### Task 2: Miner-delivery income progression

task: Add permanent 20-level allied miner delivery-income upgrade, maximum +10%
task_group: IronTide meta progression and economy
 task_outcome: success

Preference signals:
- The user requested “养成增加采矿车增加收益 20级最多加10%” -> implement it as persistent progression, with 20 ranks and a hard +10% cap.

Reusable knowledge:
- Miner cargo revenue is paid in `Unit._unload_cargo`; `EconomyCycle.income_factor` applies the separate working purifier multiplier afterward.
- Freeze applicable profile bonuses in `BattleRequest.combat_context` at battle start; an older context missing the new field should default neutrally. Classic RA2 and AI income can remain separate.

Failures and how to do differently:
- None material after regression fixes.

References:
- Economy chain regression: 268 checks passed; `growth_balance`: 21 passed.
- Feature data: `iron_tide/data/meta.json` (`ore_delivery`); code: `scripts/autoload/meta_progress.gd`, `scripts/rules/match_rules.gd`, `scripts/units/unit.gd`.
- Fix documentation: `docs/fixes/v0.26.7/README.md`.

### Task 3: E2 “炉火” legendary contract and exclusive cards

task: Implement an E2 hero contract, three completion objectives, and W/passive exclusive cards
task_group: IronTide hero progression and ability systems
task_outcome: partial

Preference signals:
- User specified a 0.35% contract drop per draw or 500-shard redemption, and completion of all three objectives awards both E2-exclusive cards -> keep the contract separate from card drops and grant both only after full completion.
- User clarified the no-attack objective means Hard-or-higher victory, E2 personally has not attacked (E2 need not be built), and other units may attack -> track E2-specific attacking, not all-player combat or construction.
- User specified 10,000 damage by E2 over multiple matches -> preserve a persistent cross-match E2 damage total.
- User clarified the passive summons two AA vehicles with 15-second summon cooldown.
- User clarified W’s stance may be manually exited before the ten-second shield expires; exiting with shield remaining and shield break both trigger splash.

Reusable knowledge:
- E2 is `



## 原文件第 2429–2522 行

## Thread `01a17bff-e2b1-7400-9c20-dedc5867fd7d`
updated_at: 2026-10-29T05:24:03+00:00
cwd: \\?\C:\Users\admin\.codex\worktrees\e42f\KFramework_server
rollout_path: C:\Users\admin\.codex\archived_sessions\rollout-2026-10-27T14-15-29-01a17bff-e2b1-7400-9c20-dedc5867fd7d.jsonl
rollout_summary_file: 2026-10-27T06-15-29-noHH-irontide_ra3_xml_completeness_effects_balance_air_impact.md

---
description: IronTide RA3/Uprising replication requires exhaustive XML/source tracing, proactive gap filling, separate gameplay balance overrides, and height-correct airborne presentation.
task: RA3 Uprising replication, Future Tank Q, GM aircraft lifecycle, airborne impact FX
 task_group: C:/Users/admin/IronTide
task_outcome: success
cwd: C:/Users/admin/IronTide
keywords: RA3, Uprising, SDK XML, XML audit, Future Tank, Q beam, ra3_riot, building damage, projectile, visual_target_lift, airborne impact, Godot, savegame
---

### Task 1: XML-complete RA3 replication

task: Establish and apply a durable requirement to analyze every relevant RA3 XML field/reference and fill confirmed implementation gaps.
task_group: RA3 source audit
 task_outcome: success

Preference signals:
- The user said: “我们复刻ra3的东西你得逐个分析xml干了什么，缺了的就补” -> always trace Includes, inheritFrom, overrides, defaults, triggers, and reference chains before claiming an RA3 feature is replicated.
- The user expects missing confirmed behavior to be proactively filled, not waiting for individual bug reports; distinguish imported assets, connected runtime behavior, automated logic checks, and user visual confirmation.

Reusable knowledge:
- Use official EA Uprising SDK/XML and installed Uprising assets as source authority. Record source file, object/field, original value, version, conversion, and evidence gaps. Do not reuse RA2/Yuri 15-frame assumptions for RA3.
- Commented/empty/included assets are not proof of intended runtime behavior; do not enable them by name alone.

References:
- `docs/RA3_PORTING.md`
- `C:/Users/admin/.codex/memories/extensions/ad_hoc/notes/20261028-164515-irontide-ra3-xml-completeness.md`

### Task 2: Future Tank Q/effects and building balance

task: Reproduce Future Tank native Q presentation, then apply a user-requested building-only balance reduction.
task_group: Future Tank / ra3_riot
 task_outcome: success

Preference signals:
- The user reported Q was “太imba了，感觉得削弱，打基地特别快” -> investigate native damage flow first, then make an explicit, isolated IronTide balance override rather than altering official XML-derived values.

Reusable knowledge:
- Official Q damage is split into 25 line damage and delayed 50 endpoint damage, with 30% non-infantry scalar and 15-second cooldown. The implementation keeps those native values and applies `data/ra3_gameplay_balance.json: future_riot.structure_damage_multiplier = 0.5` only when the target is a `Building`.
- Q glow XML intensity/lifetime values should remain intact; Godot Compatibility SDR rendering needs an explicit display-space adaptation to avoid repeated additive particle overlap becoming saturated white.

Validation:
- Q/glow checks passed 70; balance suite passed 624 checks. Tested construction-yard damage changed from 182.8125 to 91.40625 in the same complete-Q fixture.

References:
- `iron_tide/data/ra3_gameplay_balance.json`
- `iron_tide/scripts/units/ra3_riot.gd`
- `iron_tide/tests/ra3_riot_balance_regression.gd`
- `refs/ra3-expansion/riot-balance/final/audit.json`

### Task 3: GM aircraft lifecycle and wreck cleanup

task: Make GM targets behaviorally restricted without freezing aircraft/death lifecycle callbacks.
task_group: GM tools / RA3 lifecycle
 task_outcome: success

Reusable knowledge:
- `gm_stationary` should suppress ground movement/orders and auto-fire, but must not call `set_physics_process(false)`; aircraft must continue idle flight/hover and deaths must continue ticking.
- Preserve compatibility recovery for old saved targets whose physics callbacks were previously disabled.

Validation:
- `gm_air_motion_regression` passed 11 checks after an initial 5-failure baseline. Seven related suites passed 340 checks.

References:
- `iron_tide/scripts/admin/gm_unit_tools.gd`
- `iron_tide/scripts/units/unit.gd`
- `iron_tide/tests/gm_air_motion_regression.gd`
- `refs/ra3-expansion/gm-flight/final/audit.json`

### Task 4: Airborne impact presentation coordinates

task: Correct impact FX and damage-number placement for aircraft without changing combat simulation coordinates.
task_group: Projectile presentation / airborne units
 task_outcome: success

Reusable knowledge:
- Keep `target_point` and damage/collision calculations planar. For display only, use `Effects.hit_position(target)` and projectile `visual_target_lift`; cache the last known lift before lethal/removal/save operations.
- Airborne impacts must skip terrain scorch; ground impacts retain scorch behavior. This applies to projectile explosions, sparks/flashes, generic instant FX, and damage numbers.

Validation:
- Initial regression reproduced 6 coordinate failures. Final `air_impact_regression` passed 43 checks, including descending, lethal, invisible projectile, target removal, save/restore, legacy live target, and instant ground-vs-air scorch behavior. Stable related suites passed 2,632 checks.

References:
- `iron_tide/scripts/core/effects.gd` (`hit_position`)
- `iron_tide/scripts/units/projectile.gd` (`visual_target_lift`, `impact_position`)
- `iron_tide/scripts/units/projectile_visual.gd` (`target_lift`)
- `iron_tide/scripts/units/unit.gd` (`_spawn_impact_anim(..., ground_hit)`)
- `refs/ra3-expansion/air-impact/instant-confirm/audit.json`
