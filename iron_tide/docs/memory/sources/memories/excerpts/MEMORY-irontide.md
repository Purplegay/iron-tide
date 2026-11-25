# IronTide 摘录：MEMORY.md

来源：C:\Users\admin\.codex\memories\MEMORY.md。原始混合文件未修改，只提取相关段落。

## 原文件第 237–312 行

# Task Group: C:\Users\admin\IronTide bridge, performance logs, hero contract and strategic sites

scope: Godot bridge movement, battle call instrumentation, unfinished E2 hero design, superweapon alerts and ore income.
applies_to: cwd=C:\Users\admin\IronTide; reuse_rule=check current checkout and version; rollout metadata cwd differs from actual IronTide work.

## Task 1: Per-battle 30-second call-count logs, successful instrumentation

### rollout_summary_files

- rollout_summaries/2026-10-20T02-50-53-w2iT-irontide_bridge_fix_performance_call_logging_hero_design.md (cwd=\\?\C:\Users\admin\KFramework_server, rollout_path=\\?\C:\Users\admin\.codex\sessions\2026\10\20\rollout-2026-10-20T10-50-53-01a15738-0ad1-7182-9e57-531f16793b2b.jsonl, updated_at=2026-11-12T05:59:14+00:00, thread_id=01a15738-0ad1-7182-9e57-531f16793b2b, actual project IronTide)

### keywords

- battle_call_log.gd, battle_call_counters.gd, performance_calls, IRON_TIDE_CALL_LOG, P95, sampled inclusive CPU

## Task 2: Cross-map bridge movement and freed collision candidates, successful

### rollout_summary_files

- rollout_summaries/2026-10-20T02-50-53-w2iT-irontide_bridge_fix_performance_call_logging_hero_design.md (cwd=\\?\C:\Users\admin\KFramework_server, rollout_path=\\?\C:\Users\admin\.codex\sessions\2026\10\20\rollout-2026-10-20T10-50-53-01a15738-0ad1-7182-9e57-531f16793b2b.jsonl, updated_at=2026-11-12T05:59:14+00:00, thread_id=01a15738-0ad1-7182-9e57-531f16793b2b, actual project IronTide)

### keywords

- _slide_across_bridge_layers, is_instance_valid, Left operand of 'is' is a previously freed instance, bridge_stale_actor_regression

## Task 3: E2 炉火 legendary contract and exclusive skills, unfinished

### rollout_summary_files

- rollout_summaries/2026-10-20T02-50-53-w2iT-irontide_bridge_fix_performance_call_logging_hero_design.md (cwd=\\?\C:\Users\admin\KFramework_server, rollout_path=\\?\C:\Users\admin\.codex\sessions\2026\10\20\rollout-2026-10-20T10-50-53-01a15738-0ad1-7182-9e57-531f16793b2b.jsonl, updated_at=2026-11-12T05:59:14+00:00, thread_id=01a15738-0ad1-7182-9e57-531f16793b2b, actual project IronTide)

### keywords

- E2, 炉火, hero_loadouts.gd, 任务契约, 0.35%, 500碎片, Auto W

## Task 4: Enemy strategic-site alert and miner income progression, successful

### rollout_summary_files

- rollout_summaries/2026-10-20T02-50-53-w2iT-irontide_bridge_fix_performance_call_logging_hero_design.md (cwd=\\?\C:\Users\admin\KFramework_server, rollout_path=\\?\C:\Users\admin\.codex\sessions\2026\10\20\rollout-2026-10-20T10-50-53-01a15738-0ad1-7182-9e57-531f16793b2b.jsonl, updated_at=2026-11-12T05:59:14+00:00, thread_id=01a15738-0ad1-7182-9e57-531f16793b2b, actual project IronTide)

### keywords

- superweapon_alert, EVA, eva_specs.json, ore_delivery, combat_context, 20级最多加10%

## User preferences

- “以后大量减少截图，没有流量了” -> prefer logs, code evidence and headless checks; minimize screenshots and use them only when visual confirmation is needed. [Task 1]
- “桥上寻路会卡死” and “其他地图也会” -> inspect shared movement/collision and test distinct bridge layouts; preserve ordinary collisions. [Task 2]
- E2 contract: 0.35% per draw or 500 shards; three objectives award both exclusive cards. The 10,000 damage objective counts E2's own damage across matches; Hard-or-higher no-E2-attack victory does not require building E2 and permits other units to attack. [Task 3]
- E2 flak passive summons two vehicles with 15-second cooldown; W shield expires after 10 seconds, and early raising while shield remains or shield break causes splash damage. [Task 3]
- “养成增加采矿车增加收益 20级最多加10%” -> retain the exact level increments and cap. [Task 4]

## Reusable knowledge

- 2026-11-17 IronTide request: instrument the complete executed function set, rank self and inclusive CPU and call counts, and optimize actual Top 10 call chains; inclusive timings overlap. Every optimization round must consult both Yuri and web Red Alert 2, recording source modules/revisions, implemented behavior, borrowed structure, IronTide differences and preserved behavior. Reverify `C:/Users/admin/IronTide/refs/ra2yr-resource` at `b01d3cf93db69aca9b5cb5054ba04e4358963828` and `ts-redalert2` at `823c6637bab9ca1edafaa022a1040ed1fc59c274`, local `.validation/ra2web-reference-20261117`. Reconstruction stubs/comments are not verified original behavior; engine smoothness is not a same-machine benchmark. [ad-hoc note]
- New five-round batch starts 0/5, separate from historical 4/5: count only behavior-checked repeated paired same-load complete-frame improvements with CPU environment checks; rejected candidates, instrumentation, microbenchmarks and noisy load differences do not count. Target six-house full-frame P95 toward 33 ms and eventually actual graphical 30 FPS, neither yet proven; compare same save/meta, scale, speed, AI and CPU policy, recording host load and simulation progress. Structural refactoring is authorized; preserve scale, AI fairness, update frequencies, unrelated work and hidden/headless validation. [ad-hoc note]
- 2026-11-16 performance handoff: `extensions/ad_hoc/notes/2026-11-16-irontide-performance-handoff.md` is the primary source for this update, separate from the older rollout below. Actual project `C:/Users/admin/IronTide`, Godot `iron_tide/`, dirty `codex/ra2-independent`; preserve unrelated work. Historical batch stopped at 4/5; the later 2026-11-17 request starts a separate 0/5 batch and 33ms remains unproven. [ad-hoc note]
- Four paired P95 rounds: fog-disc cache 104.561→88.242 / 115.729→93.954; stagger HouseAI 112.942→86.976 / 122.143→81.245; avoid redundant sight rebuild 257.350→227.970 / 243.228→238.642; autonomous target recheck 156.985→150.160 / 157.206→152.752 ms. Different round baselines cannot be compared; round 3 reverse-control average worsened. Evidence `.validation/p95-five-after-package-20261113/` and `.validation/p95-resume-20261116/report.md`. [ad-hoc note]
- If explicitly resumed, freeze current source with `run.py freeze <new-name>`; `accepted4` predates the later FX change and `base4` has only three rounds. `bench.py <base> B1 <candidate> C1 <candidate> C2 <base> B2`: same six-player `quick.itsave` plus `iron_tide_meta.json`, 60s Release headless at 1x; both P95 pairs must improve, samples ≥55s, host CPU ≥90% for ≤5%, other-process mean CPU difference ≤10 points. Keep failed evidence and do not rerun valid losses until lucky. Isolate APPDATA/LOCALAPPDATA, copy saves, serialize benchmarks and packaging; headless or truly hidden only. [ad-hoc note]
- `query-local-version` and `query-event-invalidation` passed correctness but worsened both paired full-frame P95s; local 979→842ms query savings did not improve frame results. Inspect `report.md` and `tools/PERFORMANCE.md` before retesting eliminated ideas. Inclusive diagnostic times overlap; unit draw/dynamic skin rebuilding is a potential next investigation, not a proven fix. APOC YR skin 9 has dynamic stars. Existing bridge/stale-object baseline failures remain separate. [ad-hoc note]
- AI strategy FIFO fixed starvation (simulation 24/24/24/24/0 → 16/16/16/16/16; five AIs each executed seven times in save); original user game was not saved, so identical cause unproven. `.validation/ai-strategy-fairness-20261114/report.json`. [ad-hoc note]
- RA3 Apocalypse default fire: shared per-FX emitter materials/uniforms, instance clocks independent, 30Hz accumulated TankFX updates; 50→3 muzzle materials while preserving 51 particles. Isolated Release update median 301.624→147.797ms (~51%), not full-frame P95. `apoc_fire_fx_regression`, 416/71/2012 checks passed; GPU and user visual/stutter acceptance pending. Headless `TankFX.event` skips FX, so full-match soak cannot establish visual outcome. Evidence `.validation/apoc-fire-fx-20261116/report.md`. [ad-hoc note]
- Latest historical playable package `C:/Users/admin/Downloads/IronTide-0.28.1-20261116-apoc-fire-fx.zip`, SHA256 `4889d1a547904d27e28931b5e111a2ee76d257001a8f1a1286676420fc1ce504`, included 4 rounds, AI fairness and FX; EXE 53 checks, no commit/push. Packaging needs `large-package.itsave` (≥190 buildings); performance save has 186 and must not be used to weaken the assertion. `.validation` evidence does not travel with Git; explicitly transfer selected reports/save/meta and verify hashes. [ad-hoc note]

- Per-battle `battle_call_log.gd` / `battle_call_counters.gd` writes `.log` and `.jsonl` every 30 wall-clock seconds under Godot user data `performance_calls`; `IRON_TIDE_CALL_LOG=0` disables it. Counts are exact for 41 registered entrypoints, CPU times sampled and inclusive; never sum overlapping parent/child estimates. P95/P99 exclude pause. Async writes include a tail on exit. [Task 1]
- Copied user save observed 346/353 units and 103/70 ms P95 in two windows, not a before/after performance claim. Logger regression passed 56 checks; overall stutter remains unresolved. [Task 1]
- `Unit._slide_across_bridge_layers` must check `is_instance_valid(other)` before `other is Unit`; reverse test failed 4/16 without guard and passed 16/16 with it; four 60-unit long/short bridge scenarios crossed. This fixes the reproduced exception, not every traffic jam. [Task 2]
- Hero feature was partially edited but interrupted and unvalidated. Check git status and current code before continuing; review contract RNG/redeem persistence, objective settlement, per-match flags, hero-only eligibility, W/passive, UI and tests. Task-1 interpretation and rank tables remain unresolved. [Task 3]
- Enemy strategic-site visibility follows living completed sites; completion alerts need actual audio resource and radar verification. Ore-delivery bonus freezes in `BattleRequest.combat_context` for new extended matches, +0.5% per level up to 10%, old matches default to 1 and classic RA2/enemy AI are unaffected. [Task 4]

## Failures and how to do differently

- A freed collision candidate caused `Left operand of 'is' is a previously freed instance` and aborted movement each frame; use validity before type testing and inject a stale candidate for causal regression. [Task 2]
- Completed construction art is not necessarily launch readiness; test construction alerts separately from launch and inspect selected audio stream. Four broader fog draw-meta failures also occurred with the feature disabled. [Task 4]



## 原文件第 807–917 行

# Task Group: C:\Users\admin\IronTide Godot RTS continuation, Yuri assets, and battle-only BGM

scope: Continue the Git-based Godot RA2-style IronTide project with locally installed Yuri resources, vehicle/hover fidelity, and battle-only audio; historical missing-input intake evidence is superseded.
applies_to: cwd=C:\Users\admin\IronTide; reuse_rule=explicitly target IronTide despite a KFramework chat cwd; recheck branch, dirty ownership, Steam inputs, and remote state before mutation or delivery.

## Task 1: RA3/Uprising completion, balance, GM lifecycle, and airborne-impact corrections, successful

### rollout_summary_files

- rollout_summaries/2026-10-27T06-15-29-noHH-irontide_ra3_xml_completeness_effects_balance_air_impact.md (cwd=\\?\C:\Users\admin\.codex\worktrees\e42f\KFramework_server, rollout_path=C:\Users\admin\.codex\archived_sessions\rollout-2026-10-27T14-15-29-01a17bff-e2b1-7400-9c20-dedc5867fd7d.jsonl, updated_at=2026-10-29T05:24:03+00:00, thread_id=01a17bff-e2b1-7400-9c20-dedc5867fd7d, work performed primarily in C:\Users\admin\IronTide)

### keywords

- RA3_PORTING.md, ra3_riot.gd, ra3_gameplay_balance.json, future_riot.structure_damage_multiplier, gm_air_motion_regression, Effects.hit_position, visual_target_lift, air_impact_regression, GM targets, R3 prefix

## Task 2: RA2/YR source intake and asset provenance, current guidance

### rollout_summary_files

- rollout_summaries/2026-10-27T06-15-29-noHH-irontide_ra3_xml_completeness_effects_balance_air_impact.md (cwd=\\?\C:\Users\admin\.codex\worktrees\e42f\KFramework_server, rollout_path=C:\Users\admin\.codex\archived_sessions\rollout-2026-10-27T14-15-29-01a17bff-e2b1-7400-9c20-dedc5867fd7d.jsonl, updated_at=2026-10-29T05:24:03+00:00, thread_id=01a17bff-e2b1-7400-9c20-dedc5867fd7d, source-authority context; detailed current inputs are in ad-hoc notes)

### keywords

- RA2YR_ReSource, yr_intake, yr_source, RA2.MIX, RA2MD.MIX, LANGMD.MIX, rulesmd.ini, artmd.ini, VXL, SHP

## Task 3: Independent mechanics, battle-only BGM, and current IronTide handoff

### rollout_summary_files

- rollout_summaries/2026-10-27T06-15-29-noHH-irontide_ra3_xml_completeness_effects_balance_air_impact.md (cwd=\\?\C:\Users\admin\.codex\worktrees\e42f\KFramework_server, rollout_path=C:\Users\admin\.codex\archived_sessions\rollout-2026-10-27T14-15-29-01a17bff-e2b1-7400-9c20-dedc5867fd7d.jsonl, updated_at=2026-10-29T05:24:03+00:00, thread_id=01a17bff-e2b1-7400-9c20-dedc5867fd7d, current handoff context; detailed behavior is from ad-hoc notes)

### keywords

- codex/ra2-independent, battle-only BGM, -PrepareOnly, unit_hover.gd, vehicle_facings.mjs, TNKD, attack_cooldown_indicator, SHP sockets

## Task 4: RA3/Uprising completion, balance, GM lifecycle, and airborne-impact corrections, successful

### rollout_summary_files

- rollout_summaries/2026-10-27T06-15-29-noHH-irontide_ra3_xml_completeness_effects_balance_air_impact.md (cwd=\\?\C:\Users\admin\.codex\worktrees\e42f\KFramework_server, rollout_path=C:\Users\admin\.codex\archived_sessions\rollout-2026-10-27T14-15-29-01a17bff-e2b1-7400-9c20-dedc5867fd7d.jsonl, updated_at=2026-10-29T05:24:03+00:00, thread_id=01a17bff-e2b1-7400-9c20-dedc5867fd7d, main task evidence)

### keywords

- RA3_PORTING.md, future_riot.structure_damage_multiplier, gm_stationary, visual_target_lift, air_impact_regression, R3

## User preferences

- When the request is “接管一下我这个功能” -> locate the real project/version and inspect outstanding work before broad editing; if the user says “不知道路径，你顺着这个软件查吧”, proactively search likely Desktop, Downloads, Temp, and sandbox paths. [Task 1]
- When the user supplies an external repository, audit its source/license/rule/asset coverage before choosing an integration scope; do not copy its implementation blindly. [Task 2]
- The user selected Godot and independent implementation of original mechanisms, with RA2 and expansion modes separate -> do not translate an unauthorized reference implementation wholesale; proceed directly without repeated batch-by-batch confirmation. [Task 3] [ad-hoc note]
- “bgm是战斗开始才有” -> music must play only in battle; menu, preparation, and results cannot override this through replay or music preferences. [Task 3] [ad-hoc note]
- “ra3的改动都得参考sdk” -> for every RA3 implementation, repair, or balance change, first trace the official RA3 Mod SDK XML/schema/inheritance/original assets; distinguish official evidence from Godot policy/adaptation and custom user overrides. [Task 3] [ad-hoc note]
- “我们复刻ra3的东西你得逐个分析xml干了什么，缺了的就补” -> for each RA3/Uprising unit or system, trace Includes, `inheritFrom`, overrides/replacements, defaults and references; make a field-level source → original trigger/effect → current code/resource → verification → gap mapping, and proactively fill source-confirmed omissions. [Task 3] [ad-hoc note]
- When adding RA3 units, automatically include them in GM targets through the `R3` registration/namespace rule; do not leave a manual target list that omits later units. [Task 4] [ad-hoc note]
- User requires all RA2/YR units to be refined in batches and “以后苏联制作同样执行” -> preserve original VXL/HVA/SHP silhouette, faction color, and proportions; inspect 32 directions, separate/swapped turrets, muzzle, shadow, selection alignment, and SHP actions/layers, then compare same-color/same-facing default versus 2x and actual turn/work animation. [ad-hoc note]
- Weapon cooldown UI applies across RA2/YR/RA3/Uprising: show one ring per independently reloading actual weapon/turret, only for the active weapon mode, with color following weapon type; do not infer reloads from barrel appearance or create a separate cosmetic timer. For more than five rings in one mode, ask the user for layout. [ad-hoc note]
- Every IronTide bug-fix release needs its own `docs/fixes/v<four-part-version>/README.md`; also update `docs/fixes/README.md`, `docs/CHANGELOG.md`, and the project-home entry, with actual verification and remaining visual scope. [ad-hoc note]
- “今后盟军、苏联的专属皮肤立项和重做以猎隼外骨骼的创意和完成度为基准” -> first name the unit-exclusive hero component and recognizable signature action, with primary/secondary rhythm; generic recolor plus particles is not sufficient. Inspect shape, connections, material, effect sockets, and action ending at close range; retain separate automated and player visual acceptance. [ad-hoc note]
- For the Hunter/TNKD skin, the user specified “全喷短小粗壮，焰腹贴近喷口” -> preserve the start-up order (impeller fast spin, circle, then full exhaust), short-thick exhaust proportion, and movement/turning/combat/stop state distinctions; remeasure every other chassis instead of copying TNKD coordinates. [ad-hoc note]
- For infantry/hero skin work, use the unit’s own SHP/sequences frame-by-frame for shoulder/back/joint sockets; do not copy GGI coordinates, house-color threshold, or facing table. Provide eight-facing stand/deploy comparisons and full idle evidence, including opposite commanded facings for one-direction idle. [ad-hoc note]
- “以后每增加一个 w都要auto考虑” -> every new or changed equipable W card must explicitly assess Auto W alongside manual casting: trigger, target selection, readiness/status/visibility, player-order preservation, cooldown/resource use, multi-unit performance, save/toggle behavior, and why any manual-only choice is safe. Search buoy stays manual; do not auto-enable unsafe point-target skills. [ad-hoc note]
- For a gacha skill/passive card applicable to exactly one unit type, the demo caster must use that unit’s configured model, not the triangle-head placeholder. `exclusive` means `allowed_units` length is 1; multi-unit cards are not exclusive. [ad-hoc note]
- New and existing drawable cards need recognizable application-context iconography and explicit applicability text, not arbitrary color/generic-lightning differentiation. Respect the confirmed category limits for smoke, overdrive, focus fire, armor plating, and hollow point; ownership remains shared once acquired and levels/ownership survive scope changes. [ad-hoc note]
- For stacking talents, show readable under-unit numeric stacks plus distinct layer colors in both combat and demonstrations; the display is read-only from the actual mechanism state, not a second timer or combat/save authority. [ad-hoc note]

## Reusable knowledge

- Historical note: the initial non-Git/missing-YR assessment is stale. At the 2026-10-23 handoff, `C:\Users\admin\IronTide` was Git branch `codex/ra2-independent` at `8dfa8310e8a68293a689b9900a5dde39382c4ed6`, with Steam Yuri inputs and runtime resources present; treat this snapshot as recheck-required. [Task 3] [ad-hoc note]
- Card eligibility is data authority: `skills.json` `allowed_categories`/`allowed_units` determine eligibility; `scope_icon` is presentation only. `skill_scope.gd` and `UnitSkillLayout` must enforce effective-loadout compatibility. Defense-card support is not complete if it is UI-only: require real W/passive combat, cooldown, save/load, and garrison behavior, plus positive/negative eligibility tests and hidden visual checks. [ad-hoc note]
- Stacking-indicator entrypoint is `iron_tide/scripts/ui/talent_stack_indicator.gd`: segmented halo, name, and current/max with layer 1–4 cyan/green/gold/purple and dark inactive segments. It reads `tesla_reserve_stacks`, `rad_growth_stacks`, `reaper_heat[target]`, and `phase_time`; target-specific stacks must not transfer or sum on target switch. v0.25.66 passed 1,591 no-window logic assertions, but player visual confirmation remains pending. [ad-hoc note]
- Exclusive-card stage entrypoint is `iron_tide/scripts/ui/faction_card_stage.gd`, reusing `scripts/rules/skill_scope.gd`; its showcase model must be an isolated world with combat/physics off. Hide uninitialized `Ra3MirageFx` additive nodes on frozen Mirage to avoid black backgrounds. Headless checks and isolated screenshots are not player visual acceptance. [ad-hoc note]
- For Auto W, reuse the real cast path and add boundary tests. The confirmed Reaper split-fire auto policy permits a visible valid side-sector secondary only when own HP is at least 80% maximum or at least twice the secondary's remaining HP, preferring lower HP and never overriding a valid manually assigned secondary. [ad-hoc note]
- Key paths are `scripts/world/path_service.gd`, `scripts/world/battle.gd`, `scripts/units/unit.gd`, `scripts/buildings/building.gd`, and `scripts/autoload/game_data.gd`. Existing pathing includes a 40px grid, building rectangle painting, A*, flow fields, connectivity regions, and unstuck logic; building buildup uses real frame sequences but still needs gameplay/visual proof. [Task 1]
- `Ritanlisa/RA2YR_ReSource` is pinned at `b01d3cf93db69aca9b5cb5054ba04e4358963828` as a read-only reverse-engineering reference (GPL v3 plus EA terms), not official YR source. Its empty `TechnoClass::GetWeapon`, `GattlingRateUp_GattlingRateDownReset`, and `TransferSlavedUnit` implementations mean it cannot alone establish complete unit behavior. [Task 2]
- `ra2pipe/lib/yr_source.mjs` and `ra2pipe/yr_intake.mjs` scan read-only in precedence `RA2.MIX → LANGUAGE.MIX → RA2MD.MIX → LANGMD.MIX → EXPANDMD01.MIX → loose files`; outer layers override inner and loose files win. They record input hashes, refuse output overwrite, avoid runtime/save mutations, and audit Owner, price, TechLevel, weapons, Warhead/Projectile, prerequisites, SHP/VXL/HVA, Cameo, and sequences. [Task 2]
- Run `node --test ra2pipe/yr_intake.test.mjs` then `node ra2pipe/yr_intake.mjs <local-YR-dir> <new-output-dir-outside-project>`. The recorded test result is 8 passed/0 failed. Real integration needs a local legal YR directory with `ra2md.mix`, `langmd.mix`, `rulesmd.ini`, `artmd.ini`, and assets; integration order is GI/Robot Tank/Control Center, Soviet additions, then Yuri faction mechanisms, with rules/assets/production/behavior regression separately checked. [Task 2]
- The player entry is `iron_tide/启动游戏.bat` → `launch_game.ps1`; `-PrepareOnly` imports scripts/resources only and must not start, close, or write player state. Tests run from repo root via `./iron_tide/tests/run-navigation-building.ps1 -Suite <suite> [-Render] -RunRoot C:/Users/admin/Temp/<unique>` against a copied project and isolated `custom_user_dir`; do not edit audited paths during a run or terminate the player's Godot process. [Task 3] [ad-hoc note]
- `scripts/core/music.gd` permits playback only when `context == "battle"`; `battle_screen.gd` restores first, then plays for skirmish or `Events.wave_started`, without restarting later waves. `music_regression` (48) plus `music_ui_regression` (26) passed with `source_unchanged=true`; user audio/UI experience remains pending confirmation. [Task 3] [ad-hoc note]
- `unit_hover.gd` gives ROBO shared visual lift while retaining shadow/ground collision; MTNK/FV/SREF/MGTK/TNKD/ROBO/CMIN/AMCV and FV turrets use 32-direction exports. Re-export requires both `ra2pipe/vehicle_facings.mjs` and `allied_ability_art.mjs`, including PNG/JSON, shadows, and `unitweapon` muzzles. [Task 3] [ad-hoc note]
- RA3 source authority: use the official SDK first and record source file, object/field, original value, version, and required unit conversion. Do not carry RA2/Yuri 15-frame assumptions into RA3 seconds, animation FPS, or distance. The locally specified asset source is Red Alert 3: Uprising; label base-game/Uprising differences and do not silently resume demo extraction. SDK-configured/compiled assets are not full SAGE source; unknown behavior requires evidence-gap marking and, when needed, matching-version game observation. [Task 3] [ad-hoc note]
- The XML-completeness audit must cover relevant Draw/ModelCondition/AnimationState/Transition/Script, bones/muzzles, movement/turning, weapons/ammo/pre-attack, ability preparation/duration/retract/cooldown, particles/materials, sound, production, death/wreck, promotion and hero variants. Distinguish imported assets from actual runtime calls, logic validation, and user-visible acceptance; use `docs/RA3_PORTING.md` as handoff entry. [Task 3] [ad-hoc note]
- Current RA3 Mirage handoff supersedes v0.3.2: branch `codex/ra2-independent`, local checkpoint `39969e9` (v0.3.9.1), has entry-only DefaultW3D disguise, RA3_PRISM adapter, and field material corrections. Normalization is native weapon damage × SDK PRISM armor multiplier × target baseline HP / corresponding RA3 baseline HP; native RA3 units bypass it, upgrades do not alter baseline, and only RA3_PRISM keeps fractions. [Task 3] [ad-hoc note]
- The delivered RA3 Future Tank Q retains official split damage/timing; `ra3_gameplay_balance.json` applies the explicit IronTide-only `future_riot.structure_damage_multiplier = 0.5` to buildings, not to official XML, infantry/vehicle Q damage, or other weapons. `gm_stationary` suppresses orders/autofire but must not disable physics/lifecycle callbacks, or aircraft hover/death behavior breaks. [Task 4]
- Keep combat simulation planar. For airborne display effects use `Effects.hit_position` and serializable projectile `visual_target_lift`; cache the last lift before lethal/removal/save operations, and suppress terrain scorch only for airborne impacts. `air_impact_regression` passed 43 checks; final visual acceptance remains user-facing. [Task 4]
- The 2026-10-29 handoff adds YR death/crew/rubble and Allied skirmish-AI continuity: use `docs/YR_DEATH_AND_SURVIVORS_AUDIT.md`, `docs/SKIRMISH_AI.md`, `docs/RA3_COMPLETION.md`, `docs/VERIFICATION.md`, and `docs/CHANGELOG.md` as detailed entrypoints. Building crew, random state, rubble, and AI economy state are save-aware; test only in isolated `custom_user_dir` roots and never touch player saves. These historical test totals are not acceptance for later edits. [Task 3] [ad-hoc note]
- For YR deaths, 553 queried types are not 553 new buildable units; unresolved `DBRIS10LG`/`DBRIS10SM` stay missing rather than being substituted. Do not claim a complete YR death system: vehicle voxel debris, pilots, DeathWeapon/splash, mutation chains, full exit-grid behavior, and full rubble occupancy remain incomplete. [Task 3] [ad-hoc note]
- Allied AI is an IronTide strategy, not a complete YR AI interpreter: allied-only E1/GGI deployment uses real deployment/fire, maintains the two-miner economic floor before army spending, and has bounded difficulty-specific emergency aid. Treat its long-game balance and actual player experience as unconfirmed. [Task 3] [ad-hoc note]
- v0.9.2 integrated FV chassis plus four turrets, CMIN, and CMON (19 images) using `vehicle_surfaces.mjs` allied-support; Godot model/muzzle/mining/crew/miner-facing checks totalled 4,854. Continue with unrefined units; GTNK-specific Grizzly coordinates do not generalize. Detailed handoff: `docs/MODEL_RENDERING.md`, Soviet entry `docs/YR_SOVIET.md`. [ad-hoc note]
- Cooldown implementation/regression entrypoints are `iron_tide/scripts/ui/attack_cooldown_indicator.gd`, `iron_tide/tests/attack_cooldown_indicator_regression.gd`, and `iron_tide/tests/ra3_reaper_cooldown_regression.gd`. Verify firing, reload, mode switch, and save-load; Reaper has four rings, Vanguard ram/twin-gun modes two/one, and full YR Battle Fortress has six in two rows of three. [ad-hoc note]
- TNKD exoframe validation starts with actual VXL/HVA structure: the gun barrel is inside `DUMMY01`. Assemble left/right track armor and fixed fighting-compartment rangefinder once from local position/orientation, the same body 32-facing index, and projection origin. Compare host/attachment depth offline and retain only transparent overlays; do not replace original art. The repeatable entry is `ra2pipe/tnkd_exoframe.mjs`, evidence is `docs/MODEL_RENDERING.md` and `docs/tnkd-exoframe.png`; the recorded bake was byte-identical with 32 facings and 703 regression items. These coordinates do not validate other chassis, free-moving components, or SHP infantry skeletons. [ad-hoc note]
- TNKD turbine ignition uses `tnkd_exoframe.gd` in workshop and battle. On the nozzle end-face X=-26.37/Z=13.5, place a radius-5.35 flame root in the YZ plane; apply turn offset only to the tail and treat in-place turning as ignition. Existing AI impeller material crops/rotates the inner disc UV; the blue flame uses an AI texture on a local curve. `unit_showcase_regression` recorded 716 checks across workshop, move/turn/stop. [ad-hoc note]
- v0.25.21.1 sets the TNKD main-flame axial baseline to 20 model units and three outer flames at most 13; lights are selection-driven: four gun tubes heartbeat out of phase and four side lights breathe slowly, all with a soft halo. On deselect, ease frequency down for 3 seconds while color/brightness hold, then resume from current state when selected; workshop demonstrates it directly. v0.25.21.2 keeps impeller and short-thick blue flame active for aim, firing, and reload while stationary in combat, fading only when stationary and out of combat. Recorded isolated regressions: 725 then 728 checks; player visual acceptance is still pending. [ad-hoc note]
- Infantry socket rule details: calibrate socket location and body direction separately; shared one-facing idle that turns itself needs per-animation-frame attachment facing/occlusion. Walking carries gear, deploy fixes it per equipment with continuous transitions, and side view must not stack it on the weapon. GGI has 222 action frames and two 15-frame idles; Sentinel/Furnace still use E1/E2 native idle, and hero armor still derives facing from `fidx`, so their dedicated idle/per-frame turn adaptation is unimplemented. [ad-hoc note]

## Failures and how to do differently

- `arrived=4`, `stuck=0`, `path_left=6`, and `path_fail=0` from a six-tank probe do not prove formation pathing: two tanks had not arrived. Reproduce and explain their path/formation state rather than accepting no errors as gameplay completion. [Task 1]
- `blocked_missing_yr_inputs` is historical only; do not route new IronTide work through a missing-resource intake phase without checking current Steam inputs. [Task 2][Task 3] [ad-hoc note]
- A silent audio bus may have no PCM frames: silence checks may accept empty frames, while real playback must yield nonempty PCM. Restore save pause through `hud._toggle_pause()` because both world and SceneTree are paused. [Task 3] [ad-hoc note]
- Do not revive the failed 85° turning threshold: it caused E1 to stick in 200-unit mixed traffic. Keep the 35° small-radius boundary and 20–35° smoothstep slowdown. Do not claim ObjectDB exit warnings, actual motion feel, or hover appearance resolved until user confirmation. [Task 3] [ad-hoc note]

- The field audit preserves vertex colors (89 black of 160), UV2, the original 101-frame visibility curve, native `FXLightning` arithmetic and `ONE+ONE` blend; D3DX confirmed `c15=1/3`, `c19=0`, `c21=0`, so `(0,0,5,1)` is not five UV repeats. `tools/ra3_mirage/audit_field_effect.py` ran 8 suites/2453 checks and post-production-change Mirage/savegame rechecks passed. CPU beam envelope and dedicated movement remain Godot adapters, not official reproduction. Visual acceptance remains pending. [Task 3] [ad-hoc note]
- Do not claim a unit complete because it runs or its model imported. Do not activate an Include, commented asset, empty event, or otherwise uncalled state merely by name. Verify real call entry, state transitions, cancel/death/load boundaries; label unprovable SAGE CPU behavior as an evidence gap/Godot adaptation, and hand off missing resources item by item. Explain original-vs-user customization conflicts instead of overwriting the customization. [Task 3] [ad-hoc note]
- Do not archive/delete the shared original `C:\Users\admin\IronTide` worktree before user visual feedback. Preserve all unrelated dirt. A user-authorized local Git checkpoint is allowed for this scoped RA3 work; do not push, package, or claim original RA3 audio/elite second scatter-hop coverage. [Task 3] [ad-hoc note]
- Do not silence GM aircraft by calling `set_physics_process(false)`; do not place airborne impact visuals at ground `global_position`; and do not promote shared-source-invalidated runs as acceptance. Keep official XML values separate from SDR/display adaptations and explicit project balance overrides. [Task 4]
- Do not treat moving a window off-screen or minimizing it as isolated testing. All project tests must use no-window/background-hidden entrypoints so games, editors, terminals, browsers, dialogs, and notifications cannot steal the user’s desktop; if safe graphical isolation is unavailable, keep validation headless and mark visual work pending. [ad-hoc note]
- Do not give a stacking effect its own per-frame timer, scan the whole field, or create particles per layer: render bounded segments and the real numeric count from authoritative state. Validate stacking, consumption, expiry, stand-up, target switch, death, and load; compress demo time only from current configuration and state the demo boundary. [ad-hoc note]
- Do not let a card-stage caster run combat/physics or claim a no-window/headless run as visual approval. Actual rendering requires a separate Windows Desktop validation, and the scoped model swap does not apply to enemy targets or ordinary event symbols. [ad-hoc note]
- Do not transfer TNKD's 32-facing/projection/socket values to another vehicle, or treat the 703/716/725/728 automated checks as player appearance approval. Preserve original vehicle art and record game default-scale, workshop close-up, actual VXL/SHP action, real command transition, native muzzle, and an in-game GIF separately from visual sign-off. [ad-hoc note]
- A one-direction idle can rotate internally despite a fixed commanded direction -> derive orientation and occlusion from the animation frame, then test deploy/move/fire interruption continuity; do not infer it from GGI or E1/E2 data. [ad-hoc note]
