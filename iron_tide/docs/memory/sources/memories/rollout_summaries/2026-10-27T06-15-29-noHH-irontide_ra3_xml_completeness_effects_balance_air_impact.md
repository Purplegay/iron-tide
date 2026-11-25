thread_id: 01a17bff-e2b1-7400-9c20-dedc5867fd7d
updated_at: 2026-10-29T05:24:03+00:00
rollout_path: C:\Users\admin\.codex\archived_sessions\rollout-2026-10-27T14-15-29-01a17bff-e2b1-7400-9c20-dedc5867fd7d.jsonl
cwd: \\?\C:\Users\admin\.codex\worktrees\e42f\KFramework_server

# IronTide RA3/Uprising replication, balancing, and airborne-impact fixes

Rollout context: Work was performed primarily in `C:/Users/admin/IronTide` (despite the rollout cwd hint naming a KFramework worktree). The user expects RA3 replication to be based on official Uprising SDK/XML/assets, with missing behavior proactively identified and implemented.

## Task 1: Establish durable RA3 XML-completeness requirement

Outcome: success

Preference signals:
- The user explicitly said: “我们复刻ra3的东西你得逐个分析xml干了什么，缺了的就补” -> future RA3 work must trace each XML object's fields, inheritance, includes, overrides, triggers, and references, then compare against code/assets and proactively fill confirmed gaps.
- The user expects clear separation between imported assets, connected runtime behavior, automated verification, and user visual confirmation.

Key steps:
- Added a durable memory note and documented the requirement in `docs/RA3_PORTING.md`.
- Required source/object/field → original effect/trigger → current implementation → verification evidence → remaining gap traceability.

Reusable knowledge:
- Official EA Uprising SDK/XML and locally installed Uprising assets are the authority. Record source files, original values, version, and unit conversions; do not apply RA2/Yuri 15-frame assumptions to RA3 seconds/FPS.
- Commented, empty, or merely included assets must not be activated by name alone. Unknown SAGE behavior must be marked as an evidence gap rather than claimed identical.

## Task 2: Future Tank/Q presentation, effects, and balance

Outcome: success

Key steps:
- Implemented and documented native Future Tank animation, Q cooldown/state transitions, dual LaserDraw beams, particle systems, heroic variants, case-insensitive SAGE asset lookup, and native timing.
- Fixed Q endpoint glow overexposure by preserving XML particle timing/size/lifetime while adapting HDR additive contribution for Godot SDR rendering.
- Added a separate IronTide balance override (`iron_tide/data/ra3_gameplay_balance.json`) reducing Q damage to buildings by 50%; official XML values remain unchanged. Infantry/vehicle damage, cooldown, range, duration, and non-Q weapons remain unchanged.
- Updated version through `v0.5.12` for the balance change.

Validation:
- Q/glow regression passed 70 checks; glow regression reproduced old saturated-white behavior and verified corrected colored glow/fade.
- Q balance regression passed 40 checks; complete Q building damage examples included 182.8125→91.40625 for a tested construction yard and 285.9375→142.96875 for a tested barracks. Full balance suite passed 624 checks.

## Task 3: GM aircraft lifecycle and RA3 wreck cleanup

Outcome: success

Key steps:
- Changed GM target handling so it suppresses movement orders/combat for ground units but does not disable engine physics/lifecycle callbacks. Aircraft targets continue native idle flight/hover behavior without firing.
- Preserved death callback recovery for old saves and verified aircraft crash/wreck lifecycle.

Validation:
- `gm_air_motion_regression`: 11 checks passed after fixing the initial 5 failures.
- Seven related suites passed 340 checks, including real GM generation, flight, save/restore, death cleanup, RA3 completion, Mirage aim, and savegame behavior.

## Task 4: Airborne impact/explosion coordinate correction

Outcome: success

Key steps:
- Root cause: projectile logic correctly tracked aircraft targets, but impact FX, damage numbers, and some instant FX used ground `global_position`/`target_point` coordinates.
- Added `Effects.hit_position`, cached projectile `visual_target_lift` in serializable splinter state, and projected impact/number positions to current or last-known aircraft height.
- Preserved authoritative planar simulation, damage, range, and collision coordinates. Airborne impacts no longer create ground scorch decals; ground impacts retain existing scorch behavior.
- Covered lethal hits, target removal, mid-flight save/restore, old live-target saves, descending aircraft, and instant weapon FX.

Validation:
- Initial airborne regression reproduced 6 failures; final `air_impact_regression` passed 43 checks.
- Stable related run passed 2,632 checks; the subsequent instant-FX addition passed 43 checks. Compatibility screenshots were inspected and showed impact FX/damage numbers near the aircraft body.
- Final visual result remains subject to user in-game confirmation.

Failures and how to do differently:
- Early validation runs were invalidated by concurrent/shared-source changes and one test harness parse error (`restore()` returns void). Use isolated projects/users, verify source fingerprints, and exclude unstable runs from acceptance evidence.
- A first glow fix relied on direct SDR additive rendering; future HDR-to-SDR adaptations should explicitly distinguish native XML intensity from display-space mapping.

References:
- `C:/Users/admin/IronTide/docs/RA3_PORTING.md`
- `C:/Users/admin/IronTide/docs/RA3_RIOT_AUDIT.md`
- `C:/Users/admin/IronTide/docs/VERIFICATION.md`
- `C:/Users/admin/IronTide/iron_tide/scripts/units/ra3_riot.gd`
- `C:/Users/admin/IronTide/iron_tide/scripts/units/projectile.gd`
- `C:/Users/admin/IronTide/iron_tide/scripts/core/effects.gd`
- `C:/Users/admin/IronTide/refs/ra3-expansion/air-impact/instant-confirm/audit.json`
