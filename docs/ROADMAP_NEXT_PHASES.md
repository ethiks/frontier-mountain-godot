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

## Milestone 3: Save/load and time — DEPLOYED (2026-11-11)
- Implemented versioned JSON save/load in `user://frontier_mountain_v2.json`, with defensive validation of version, tree count, coordinates and corrupted files.
- Save data includes tree HP/state/falling progress, standing/bucked logs on the ground, player position, carried inventory, cash, day/time, tool condition, fuel, equipment tiers, contract progress and lifetime delivery stats.
- Saves occur on logging actions, sales, upgrades, resting, each day change and every ~35 seconds; manual SAVE and LOAD in the CAMP ledger.
- Continuous 15-minute day cycle, ambient dawn/dusk/night lighting and rest at the cabin to advance to a new morning.
- Saved position and world reconstruct after reload without duplicating collectible logs.
- A unified mobile-friendly HUD displays day/time, cash, tool, condition, load capacity and direction/home context.

## Milestone 4: Trader and economy — DEPLOYED (2026-11-11)
- Placed already approved trader artwork at the homestead.
- Added MARKET ledger with current per-species timber prices, deterministic daily variation, sold-log totals and an active daily species contract.
- Automatic contract payout only once on required deliveries; prices and contracts refresh at dawn or after sleeping.
- Cash is deducted on purchases; insufficient funds and maxed equipment are rejected.
- Selling still requires carrying timber to the lumber landing. Market details can be viewed elsewhere.

## Milestone 5: Equipment and expanded hauling — MECHANICS DEPLOYED (2026-11-11)
- Implemented Camp Axe, Hardened Axe, Steel Axe and Chainsaw progression, increasing chop damage.
- Cutting wears tools; repair is paid. Chainsaw consumes fuel and cannot cut when empty.
- Handcart and Timber Cart upgrades increase log capacity 4 → 8 → 12, persist in saves and are shown in the GEAR ledger.
- Core approved lumberjack animation is retained. **Visual cart/chainsaw sprites are NOT introduced**; request a dedicated new art approval pack before showing them in-game.
- Existing logging sound cues remain; chainsaw now uses its original approved sampled effect.

### Unified cross-platform UI — DEPLOYED (2026-11-11)
- Replaced the old stacked HUD with a consistent forest/timber palette, day/time/cash ribbon, information line, primary action and CAMP / MARKET / GEAR buttons.
- Touch joystick and action buttons reposition for 844×390 landscape phone and 1280×720 desktop viewports.
- Fullscreen, mute, audio mixer and manual save are available from the top ribbon.
- Keyboard: WASD/arrows move, Space/E act, M market, I gear, P camp, Esc close, F5 save, F9 load.
- Controller: left analog move, A action, Y market, X gear, B close menu, Start fullscreen (browser support permitting).
- Native Godot Button focus enables controller and keyboard menu navigation; no new UI art asset introduced.
- Headless acceptance tests cover empty/invalid saves, saved harvest restoration, market/contract payouts, day turnover, equipment, funds, and mobile controls.
- Full iOS/Android native build tests remain open; this version is a deployed Web export.

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

## Deferred art and environment work
- Tree Variability Sprite Pack v1 is saved as **pending approval**; do not integrate its age/size sprites until the user approves that pack specifically.
- Refine remaining hard-edged biome seams and path transitions in the next terrain polish pass.
- Create separately approved sprites for equipped chainsaw and carts before displaying those tools on the lumberjack or in the world.
