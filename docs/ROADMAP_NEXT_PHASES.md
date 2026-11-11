# Frontier Mountain: Next Features Roadmap
Last reviewed: 2026-11-11
Target: Godot 4.4 parity with the approved Frontier Mountain v0.6.2a browser game.

## Release principles
- Preserve the working chop → fall → buck → carry → unload loop at each milestone.
- Reuse the five approved image atlas references. Before any new visual asset is added, provide a proposed batch sprite pack for user review and approval.
- Do not replace playable assets with a flattened or static background illustration.
- Keep landscape orientation, eight-direction animation, analog movement, and the Razer Kishi controller mapping.
- Every feature includes smoke tests, a playable web build, and actual browser screenshots. Verify iOS and Android separately.
- Save compatibility is explicit and versioned.

## Milestone 1: Screen, sound and UI foundation — IMPLEMENTED
- Godot 2D stretch aspect expanded to fill available viewport.
- User-gesture-triggered FULLSCREEN control on Web and native fullscreen control on desktop.
- Original v0.6.1 "Old Growth Stillness" music, packaged locally as Ogg Vorbis.
- Eight original v0.6.1 sampled wood/tool SFX converted to Godot audio resources.
- Event binding for axe chops, falls, bucking, log pickup and delivery.
- SOUND and MIX controls with separate saved music and effect volumes.
Acceptance: all source audio resources load, mixer exists, fullscreen button exists, forestry smoke suite passes.
Known caveat: fullscreen API support differs between desktop browsers and mobile Safari; test the user-gesture button.

## Milestone 2: Larger forest, camera and collision — DEPLOYED (2026-11-11)
- Rebuilt the original 96 x 76 tile world bounds (3072 x 2432 world units).
- Added a smooth Camera2D follow camera with world-edge limits and a readable starting clearing.
- Added deterministic forest generation: 170 harvestable trees in the launch build.
- Trees are registered by 384-unit spatial chunks; their sprites instantiate near the camera
  and unload at a distance while the tree harvest state remains in game data.
- Reused the five approved sprite references; no new visual packs, flattening or billboard backdrops.
- Added procedural forest ground, grassy clearing, narrow meandering trails and a single log drop-off.
- Kept one toolshed, separately scaled cabin, solid building/trunk/fallen timber collisions,
  eight-direction movement, original logging SFX/music and fullscreen controls.
- Cabin and tool-shed proximity triggers now identify their entrances but deliberately
  do not allow wall clipping or claim that unimplemented interiors exist.
- Nearby foreground tree canopies fade to keep the lumberjack visible.
- Automated Godot smoke suite and live Chromium screenshots cover key movement and harvesting.
Remaining art gate: a dedicated reusable terrain sprite atlas needs user approval before import;
procedural ground remains temporary, as requested under the approved-art policy.

## Milestone 3: Save/load and time
- Implement versioned save game using user://; persist player, inventory, cash, harvested trees, and world seed.
- Restore 15-minute day cycle, sunrise/sunset, sleep/new day, and basic tool wear.
- HUD showing day/time, carried load, tool condition and money; responsive phone safe areas.
Acceptance: reload preserves harvest/cash and does not duplicate sold or bucked logs.

## Milestone 4: Trader and economy
- Morning trader interaction, original per-species log valuations and price fluctuations.
- Price/weight inventory listing, shop purchase and sales confirmation.
- Contract board and early repeatable delivery goals.
Acceptance: no free purchases, consistent currency and stock, contracts pay once.

## Milestone 5: Equipment and expanded hauling
- Sharpened axe, steel axe, chainsaw with fuel and wear.
- Handcart, heavy cart and hauling capacity progression, with Kishi action mapping.
- Contextual tool audio (chainsaw-rev, material handling) and UI indicators.
Acceptance: tool stats affect harvesting and carry mechanics; upgrades persist.

## Milestone 6: Timber processing
- Portable sawmill and board stacks, processing queues, sawmill speed and expenses.
- Kiln drying, fuel consumption, yield accounting, storage bins and prices.
- Original mill-load and mill-cut SFX with distance-aware attenuation.
Acceptance: wood input cannot be double-spent; processed goods conserve inventory.

## Milestone 7: Seasons, ecology, long-term progression
- Seasons, tree age/growth, saplings/planting, ridge access/permits and forestry challenges.
- Contracts and progression achievements, a minimap and balancing pass.
Acceptance: deterministic day transitions and no lost saves.

## Milestone 8: Release hardening
- Browser: resize/fullscreen, landscape, audio unlock, offline/media reload tests.
- iOS and Android: landscape safe areas, touch controls, Razer Kishi V3 Pro input, save permissions, performance and 60 FPS budget.
- Pause, accessibility settings, SFX controls and crash reports.
Acceptance: actual platform exports, not web-only emulation.
