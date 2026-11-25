# IronTide: skill card scopes and semantic icons

User explicitly requested persistent rules on 2026-11-05. Repo: C:/Users/admin/IronTide. Follow docs/SKILL_CARD_DESIGN.md.

- Five ordinary drawable cards are category-limited, not universally compatible. Confirmed: smoke = infantry/ground vehicles; overdrive = ground vehicles/aircraft; focus fire = infantry/defense buildings; armor plating = ground vehicles/defense buildings; hollow point = infantry/aircraft. Acquisition remains gacha, owned once and shared across eligible units. Preserve acquired ownership and levels on scope changes.
- Every current and future card should have recognizable application-context iconography: vehicle silhouette, aircraft, infantry, tower, lightning for Tesla/electrical, high-tech crystal/hexagon for Future/Mirage, ship/naval, anti-air, explosives, heavy armor. Use effect badges and explicit applicability text. Do not differentiate everything with arbitrary colors or generic lightning.
- skills.json allowed_categories / allowed_units determine eligibility; scope_icon controls presentation only. Shared skill_scope.gd and UnitSkillLayout enforce UI and effective-loadout compatibility. Current 20 drawable cards covered. Defense cards need actual W/passive combat, cooldown, save/load and garrison behavior, not UI-only support.
- Reuse semantic icons in draw/training/equipment/combat and include scope in level-dependent descriptions. Add positive/negative eligibility tests and hidden visual checks. Official game rules and project custom cards remain separate.
