thread_id: 01a15738-0ad1-7182-9e57-531f16793b2b
updated_at: 2026-11-12T05:59:14+00:00
rollout_path: \\?\C:\Users\admin\.codex\sessions\2026\10\20\rollout-2026-10-20T10-50-53-01a15738-0ad1-7182-9e57-531f16793b2b.jsonl
cwd: \\?\C:\Users\admin\KFramework_server
git_branch: main

# IronTide rollout: strategic-site alerts, ore-income progression, unfinished hero-card design, bridge movement fix, and per-battle call logs

Rollout context: Although rollout metadata says `C:\Users\admin\KFramework_server`, substantive work was in `C:\Users\admin\IronTide\iron_tide` (Godot 4.7.2). There were five coding tasks plus a final user workflow preference. Tasks 1–2 and 4–5 were implemented and verified to varying degrees; Task 3 remains exploratory and incomplete. The user also explicitly asked to greatly reduce screenshots due to limited data.

## Task 1: Enemy strategic-superweapon detection and persistent visibility

Outcome: success.

Key steps:
- Found that fog revealed enemy superweapon positions only on launch, and the temporary launch window expired; ready enemy strategic sites were placed through the AI delivery path without a construction-complete alert.
- Added ongoing visibility derived from living, completed strategic sites, plus per-type RA2 detection EVA mappings and completion alerts/radar pings.
- Added regression coverage and v0.26.6.7 release notes.

Validation: `superweapon_alert` passed 248 checks and `superweapon_sidebar` passed 110 checks. A broader fog suite had four draw-meta assertions that also failed with the feature disabled; these were identified as baseline failures, not claimed as fixed.

Reusable knowledge: EVA mappings live in `iron_tide/data/ra2/eva_specs.json`; dispatch and queue/dedup behavior is in `iron_tide/scripts/core/ra2_sfx.gd`. When asserting that EVA audio was selected, inspect the actual stream/resource as well as the queued event; a first regression attempt incorrectly conflated completed construction art with readiness to launch.

## Task 2: Miner-delivery income progression

Outcome: success.

The user requested “养成增加采矿车增加收益 20级最多加10%”. Implemented a permanent 20-level upgrade in `iron_tide/data/meta.json`, giving +0.5% per level to allied ore-delivery value in newly started extended-rule battles, capped at +10%. It applies to partial and full unloading, and stacks multiplicatively with a working ore purifier. Classic RA2 and enemy AI income are unaffected. The match bonus is frozen in `BattleRequest.combat_context`; old matches lacking the field default to multiplier 1.

Validation: `economy_chain` passed 268 checks and `growth_balance` passed 21. Tests covered both Soviet and Allied miner IDs, mixed ore/gems, partial deliveries, purifier stacking, hard AI income, old-match defaulting, purchases/costs, and the level-20 cap. v0.26.7 release notes were added.

## Task 3: Soviet hero E2 “炉火” legendary contract and two exclusive skills

Outcome: partial / unfinished.

The user supplied a detailed design, then clarified:
- A draw has a 0.35% chance to yield a contract; alternatively exchange 500 shards to unlock the contract. Completing all three objectives awards both E2-exclusive cards.
- Objective 3: win at difficulty Hard or higher without E2 ever attacking; E2 does not need to be built, and other units may attack.
- Objective 2: E2 personally accumulates 10,000 damage across matches.
- Flak passive summons two vehicles, with 15-second summon cooldown.
- W deploys a shield and stance; the shield disappears after 10 seconds, but W can raise the unit sooner. Raising while shield remains, or shield break, triggers splash damage.

The assistant explored and partially edited code, but the rollout was interrupted by later unrelated tasks before the hero feature was completed or validated. Some draft files/edits were not validated or shipped. Do not assume the feature exists in working form. Before continuing, inspect the current checkout and `git status`; revisit hero skill eligibility, contract RNG/redeem persistence, task settlement and per-match flags, passive vehicle behavior, UI, and regression coverage. The discussion only settled the above user clarifications; details such as exact task-1 interpretation and whether all four rank tables are defined were not fully resolved in completed code.

Useful project map: hero progression is `iron_tide/scripts/rules/academy.gd`, hero equipment is `iron_tide/scripts/rules/hero_loadouts.gd` and `scripts/ui/hero_equipment.gd`, E2 is `E2` in `Academy.HEROES`, W use routes through `Unit.use_ability`, and unit special state is persisted through actor snapshots. Generic card eligibility in `scripts/units/unit_skill_layout.gd` currently has no validated hero-only behavior.

## Task 4: Bridge movement failing with stale freed collision candidates

Outcome: success for the reproduced failure; not proof that every traffic jam on every map is solved.

The user reported: “桥上寻路会卡死，经常走不动人”, then clarified it happens on other maps too, not only the previously supplied save. Investigation reproduced `Left operand of 'is' is a previously freed instance` in `Unit._slide_across_bridge_layers`: a bridge collision candidate could be freed, yet the type test ran before validity checking, aborting movement each frame. Added `is_instance_valid(other)` before the `is Unit` test.

Validation: On long `yr_isleland` and short `yr_crctbrd` bridges, 60-unit infantry and mixed infantry/tank formations all crossed in four scenarios. The stale-candidate regression failed 4 of 16 assertions with the guard removed and passed all 16 with it. Existing `bridge_queue_regression` passed 208 checks and `native_bridge_traffic_regression` passed 30. Release v0.27.17.10. Existing deployments and live-unit collisions remain blocking; the fix does not claim arbitrary jams disappear.

Retrieval handles: `iron_tide/scripts/units/unit.gd`, `_slide_across_bridge_layers`; `iron_tide/tests/bridge_stale_actor_regression.gd`; `iron_tide/tests/bridge_crowd_regression.gd`; `iron_tide/scripts/world/path_service.gd`, `bridge_at`.

## Task 5: Per-battle performance call-count log

Outcome: success for instrumentation and the supplied-save demonstration; overall performance remains unresolved.

The user asked: “加个调用记录log，每场战斗会每30s更新一次，方便查找最多调用的地方，现在p95单位一多就一直在卡”. Added default-on per-battle `.log` and `.jsonl` records at 30 seconds of wall time. The 41 registered entrypoints include unit/building updates, combat, AI, pathfinding, fog, UI, projectiles, and effects. Entry counts are exact for registered functions; inclusive CPU time is sampled with a private jitter sequence so it does not consume gameplay RNG. Reports rank call count separately from estimated cumulative sampled time; parent and child timings overlap and must not be summed. Frame P95/P99 use a fixed 1 ms histogram; pause periods are excluded from active-frame percentiles, the maximum frame is retained, and frames beyond the histogram cap are called out. Disk writes are asynchronous and the logger writes a tail summary on result/scene exit. Existing manual performance snapshots remain available and point to the active call log.

The user’s actual supplied save was copied to isolated test storage and replayed for 65 seconds, producing two ~30-second windows plus a tail record. Window sizes were 346 and 353 units; P95 values were 103 and 70 ms. These are observations, not a before/after performance claim. The dominant estimated time was unit update, followed by building update, combat and fog; Auto W and unit skill checks were high-call-count entries. Collection on the main thread took ~0.773 ms and ~0.624 ms. No user save was modified and the run was headless/windowless.

Validation: the dedicated logger regression passed 56 checks; bridge stale-reference regression passed 16. The supplied-save demonstration wrote the expected four records and found unit calls in both windows. A 100,000-call synthetic counter check measured ~34–36 ms enabled versus ~21 ms disabled, a synthetic instrumentation overhead measurement only. Release v0.27.18; no package or commit was made.

Useful paths: `iron_tide/scripts/world/battle_call_counters.gd` (POINTS/aggregation), `battle_call_log.gd` (sampling, reporting, async persistence), `iron_tide/scripts/screens/battle_screen.gd` (lifecycle), `iron_tide/scripts/world/performance_snapshot.gd` (snapshot pointer), and `iron_tide/tests/battle_call_log_regression.gd`. Default logs go under Godot user data at `performance_calls`; `.log` is readable, `.jsonl` is the structured artifact. `IRON_TIDE_CALL_LOG=0` disables collection for a test process.

## Task 6: Reduce screenshot usage

Outcome: success; explicit user preference.

The user said: “以后大量减少截图，没有流量了” (“greatly reduce screenshots going forward; I’m out of data”). For future similar work, default to code/log evidence and headless tests. Take screenshots only when visual confirmation is genuinely necessary, and then minimize the number; do not repeatedly send images.

## References

- [1] Strategic-site fix: `docs/fixes/v0.26.6.7/README.md`; fog/alert regression counts above.
- [2] Miner training fix: `docs/fixes/v0.26.7/README.md`; economy/level-up regression counts above.
- [3] Bridge fix: `docs/fixes/v0.27.17.10/README.md` and `verification.json`.
- [4] Call-log implementation: `docs/fixes/v0.27.18/README.md` and `verification.json`; source tree `iron_tide/scripts/world/battle_call_log.gd`, `battle_call_counters.gd`.
- [5] Rollout workdir evidence: executed commands primarily used `workdir: C:/Users/admin/IronTide`, despite rollout metadata listing `C:\Users\admin\KFramework_server`.

