# IronTide RA3 Mirage handoff — 2026-10-27

Supersedes stale v0.3.2 presentation status. Work in C:\Users\admin\IronTide, branch codex/ra2-independent, even when chat cwd is KFramework. Recheck live Git state; this is a shared dirty checkout.

User authorized RA3 SDK-based implementation, Uprising assets, and cross-generation hit-count normalization while preserving Yuri target HP and other rules. Local commit 39969e9 (v0.3.9.1) contains field material corrections, entry-only disguise effect, and RA3_PRISM damage adapter. Previous 5e7e62a aligned spatial scale and beam fade. User requested a Git checkpoint; older memory prohibiting commits is superseded for this scoped work. No push/package/archive requested now.

Damage = native weapon damage * SDK PRISM armor multiplier * target baseline data.hp / corresponding RA3 baseline HP. Role mappings/fallbacks are project policy, not official equivalence. Wounds/max-HP upgrades do not change baseline damage; offense/defense/promotion stay independent. Native RA3 units bypass normalization. Base barracks 100 damage / 5 shots; Grizzly 125 / 3 shots; infantry 1 shot. Only RA3_PRISM retains fractional damage; Yuri rounding unchanged.

Field: preserve vertex colors (89 black of160), UV2, original101-frame visibility curve, native FXLightning arithmetic and ONE+ONE additive blend. Runtime D3DX audit confirmed c15=1/3, c19=0,c21=0; (0,0,5,1) is NOT simply five UV repeats. DefaultW3D disguise particle only on entry, ends on reveal; no persistent normal-mode shell.

Validation: refs/ra3-mirage/integration-test/field-damage/final/audit.json: 8 suites /2453 checks passed; shared-source fingerprints stable during run. Subsequent unrelated production_exit edits triggered mirage79 + savegame120 recheck under post-production-change/audit.json, passed. Godot4.7.2 OpenGL Compatibility/WASAPI, isolated user data, no network/DB. These prove the shared workspace, not a clean packaged checkout. Visual status remains pending_user_visual_confirmation. Do not archive/delete before user visual feedback.

Engine research: OpenSAGE W3dLaserDraw Update/BuildRenderList remain stubs. EA Generals source is older, not proof of RA3 CPU geometry/opacity. SDK Max .fx files are compiled binaries. tools/ra3_mirage/audit_field_effect.py reads original Uprising shader states on a hidden D3D9 device. CPU beam width/fade envelope and dedicated RA3 movement logic remain gaps; 0.5 beam width and .3/.1s tails are explicitly Godot adapters. Authoritative detailed handoff: docs/RA3_UPRISING_EXTRACTION.md; profile extractor tools/ra3_mirage/extract_target_profiles.py.

Current request: write this memory and git pull, preserving all unrelated dirty/untracked files. Pull outcome to be appended after execution.

Pull result: git pull --ff-only --no-recurse-submodules succeeded: Already up to date. HEAD remains 39969e97a7a97921b24c45552c4512914efecce7. Local branch is ahead4/behind0 of origin/codex/ra2-independent. All 1397 preexisting dirty/untracked file hashes remained unchanged. No push, stash, reset, merge commit, or rebase. Evidence refs/ra3-mirage/git-pull-20261027/{before,after}.json.
