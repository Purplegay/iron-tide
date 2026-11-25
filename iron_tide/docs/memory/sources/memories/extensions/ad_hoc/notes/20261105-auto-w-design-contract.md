# IronTide: every new W must include an Auto W decision

User explicit instruction on 2026-11-05: “以后每增加一个 w都要auto考虑 写入记忆”. Applies to C:\Users\admin\IronTide.

For every new or changed equipable W card, assess Auto W alongside manual casting: appropriate automatic trigger, target selection, readiness/status/visibility checks, preservation of player orders, cooldown/resource use, multi-unit performance, and save/toggle behavior. State explicitly when a skill remains manual and why. Reuse the real cast path and add boundary tests; do not silently omit Auto support or automatically enable unsafe point-target skills.

Confirmed initial policy: smoke, overdrive, focus fire, chain lightning, shock pulse, twin calibration, slope armor and mirage decoy use their individually discussed triggers. Search buoy stays manual. Reaper split fire may auto-assign a visible valid side-sector secondary target when own HP >= 80% max OR own remaining HP >= 2x secondary remaining HP, preferring lower HP; keep the primary and do not override a valid manually assigned secondary. User confirmed this numerical interpretation.

Testing remains headless/no-window; never show test windows on user's desktop. Proposed Auto W tech uses existing extension-mode research and per-unit-type preference; verify actual delivery before claiming implementation complete.
