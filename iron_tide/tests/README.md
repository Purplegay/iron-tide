# Navigation and building regression

Run from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1 -Render
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1 -Suite rules_mode_regression -FreshImport
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1 -Suite minimap_regression -Render
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1 -Suite selection_regression -Render
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1 -Suite input_ownership_regression -Render
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1 -Suite hud_layout_regression -Render
powershell -ExecutionPolicy Bypass -File .\tests\run-navigation-building.ps1 -Suite hud_identity_regression -Render
```

`-Godot` overrides the executable. `-RunRoot` selects a new output directory outside
the source project. The runner copies the project and imports, gives the copy a
unique user-data directory, and preserves the source project and player save.
Do not run the scene directly in the normal game project: autoloads save player
progress before the test scene starts.

The real battle scene drives movement and building production. Only enemy wave
spawning is postponed for the navigation test. The building test freezes unrelated
actors and advances the existing production/animation methods deterministically.
There is no replacement movement controller or building state machine.

Coverage:

- Friendly separation direction and progress along a detour.
- Blocked diagonal corners, routing around a blocked cell, shore snapping,
  disconnected destinations and a naval path.
- Six tanks crossing the mission map: each must finish its move order within
  60 simulated seconds, remain within 26 world units of its assigned slot, and
  have no overlapping bodies. Assertions are unchanged between candidate runs.
- Actual sidebar production, legal placement, exactly one cost payment,
  buildup availability, non-operational/operational transition and stable footprint.
- With `-Render`, four viewport images and strictly increasing buildup frame indices.
- Enemy nested-node navigation, terrain invalidation, naval flow fields and direct
  air orders across water; real harvest cursor classification.

The `rules_mode_regression` suite loads the real battle three times (RA2,
extension, RA2), with deliberately upgraded progression. It checks health, attack,
skills, deployment buffs, initial funds, country giveaways, catalogs, production
duration/payment/refunds/stalls, buildup gating and settlement isolation.
Its rendered run also captures the mode selector. `-FreshImport` starts without
the old `.godot` cache. Fingerprints include source assets.

The `minimap_regression` suite uses the real HUD minimap and dispatches mouse
events through `Viewport.push_input`. It checks landscape, portrait and square
layouts, map coordinates, clicks, drags, letterboxing and release outside the
control. Rendered checks use independent camera geometry to inspect actual
outline pixels at multiple rotations and zooms, plus map-boundary clipping.
The battle is frozen while input and camera transforms are exercised.

The `selection_regression` suite hosts the real battle and HUD in a 1600×900
SubViewport so injected mouse positions cannot race the physical desktop cursor.
Unrelated actors are frozen; production selection and HUD input remain enabled.
Both modes exercise four zoom levels, small movement versus box selection,
double clicks, repeated selection without skill use, explicit D / Shift+Q
commands, the connected skill-button signal and cooldown rejection.
Rendered checks wait for real sprite bounds before positioning the fixture.

The `input_ownership_regression` suite includes all selection checks and adds
Shift toggling/additive rectangles, empty space, enemy exclusion, building/unit
selection exclusivity, HUD blank space and child controls, real building and
unit queue cancellation, cross-boundary selection/minimap drags, and world pan
with right-drag scrolling both disabled and enabled. Queue-child checks set an
existing icon's mouse filter to PASS to exercise hoverable child propagation.

The `hud_layout_regression` suite renders the populated production HUD in both
modes at 1280×720, 1600×900, 1920×1080 and 2560×1440, then resizes back down.
It checks panel gaps, tab/card bounds, scrolling to the last card, long resource
status text, default-hidden developer controls and opening/closing settings.
It applies the existing skin updater to newly built catalog controls before
measuring, rather than measuring only the empty panel or pre-skin layout.

The `hud_identity_regression` suite includes all input ownership checks and
compares the actual production, queue, detail and selection-strip icon source.
It covers identity reuse, missing-art fallback, building icons, counts, damage,
live strip health, mode labels and skill visibility after multi-select, building
selection and clearing selection. Rendered screenshots show both modes.

Results and environment fingerprints are written under the run's `reports/`.
The temporary project and test save are retained for diagnosis. There are no
network, database or Unity dependencies. A passing screenshot check proves that
frames render; appearance and movement feel still require user review.
