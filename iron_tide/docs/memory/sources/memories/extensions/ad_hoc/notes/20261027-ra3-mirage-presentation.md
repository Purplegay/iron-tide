# IronTide RA3 Mirage handoff — 2026-10-27

User explicitly requested memory and later postponed archive until testing: finish original icons, ground tracks, skill VFX and RA3 weapon VFX first. Do not archive this thread or delete any worktree before their test feedback. Current chat cwd KFramework_server is unrelated.

Actual code is C:/Users/admin/IronTide, branch codex/ra2-independent; shared dirty checkout. No separate attached IronTide worktree, changes already in original checkout. Preserve others' changes; no commit/push/package this turn.

v0.3.2: R3MIRAGE original production/portrait/Q on-off icons; Ra3WeaponFx native prism/elite textures and hit flare/fire; Ra3MirageFx native EXCloakingField and disguise meshes; VehicleTracks original EXTireTrack2/EXTnkTrack, real displacement, fog filtering, bounded expiry and snapshot cleanup. Godot adaptation, not SAGE engine/animation port. No original RA3 weapon audio or elite second scatter hop.

tools/ra3_mirage/extract_presentation.py reproduces 18 assets from official demo streams, runtime assets/ra3/mirage/presentation/presentation_provenance.json records source/output hashes. Full handoff docs/RA3_MIRAGE_MODEL.md; validation docs/VERIFICATION.md.

Final refs/ra3-mirage/integration-test/final-v0.3.2/audit.json: 7 runs, 1889 assertions, no failed assertions; source hashes unchanged during run. At handoff all runtime/assets/executed tests still match; only unrelated unexecuted tests/model_smoothing_regression.gd changed concurrently (HUD timer freeze for its screenshot fixture). New render suite 33 covers real Q, icons, cooldown, native meshes, movement/track pixel differences/fog, weapons, expiration, load cleanup. Original production suite retains known audio resource exit warnings. PrepareOnly Ready. Isolated custom user dir, source junctions (not snapshot), no network/services/DB, no formal saves used. Visual acceptance pending user; restart original iron_tide/启动游戏.bat and start new expansion match (old content fingerprint saves may reject).
