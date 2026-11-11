# Frontier Mountain — v0.6.2a migration audit (Phase 1)

Status: **source audit started; asset files recovered and checksum-verified; engine import pending**.

## Authoritative baseline
- Source: `frontier-v062a-playable.html` from Frontier Mountain Library, 372,787 bytes.
- Art: `APPROVED_ART_MANIFEST.json`, approved 2026-11-11.
- Original live browser game and the new Godot Render site are not modified by this branch.
- Rebuild target: parity with the *entire* v0.6.2a implementation, **not** the five-log Godot demo.

## Confirmed source mechanics
- World: 96×76 tiles at 32 units/tile, cabin and yard, generated terrain, clearing, multiple tree species.
- Time: 15 real-world minutes of daylight; sleeping, seasons and years.
- Logging: nearest standing/fallen/loose tree selection; chopping, felling, bucking, carrying, unloading and hauling.
- Economy: merchant, dynamic market, selling, buying, item gating, supplies, contracts, repair, production queues.
- Progression: XP, level thresholds, upgrades, permits, equipment/tool health, chainsaw, handcart, tractor, sawmill and kiln.
- Ecology: sapling planting and environmental/seasonal effects.
- UI: HUD, modal screens, inventory, quickbar, minimap, audio controls, weather and lighting.
- Persistence: browser localStorage save/load; design a versioned Godot save schema and conversion strategy.
- Audio: synthesized sound effects and audio mixer, to be ported to Godot's audio buses/players.
- Artwork: v0.6.2a integrates approved hosted WebP crops; 8-direction character facing and action rows.

## Art inventory (original PNG sheets, checksum verified)
| File | Dimensions | SHA-256 |
| --- | --- | --- |
| frontier_lumberjack_sprite_sheet.png | 1448×1086 | de876a417322c4c3a8fd966fb5e574696d99c1b8e130be528b1d45f2a90e34f8 |
| frontier_mountain_asset_sheet.png | 1448×1086 | a3c7fb7e44594c3b48106dfe9d6278beec7354598f2713c243decf9227ddbee1 |
| frontier_mountain_building_sprite_sheet.png | 1448×1086 | 77502c1ebf4a5c7d9d45d9f23e474ee4a3da756a14953fd7eb675d5f7448945c |
| frontier_mountain_logger_sprite_atlas.png | 1122×1402 | da921cee652a52165dca3db26a59cb3eed96d72dd082e17e3aba089e038846a1 |
| pixel_art_tree_felling_and_logging_atlas.png | 1122×1402 | 799d99836dc3870dc3026c4f59cad3c04992520727e0f3f7e1f78071a2ef6bb8 |

All five original source PNGs are available in the project Library. They were retrieved and independently hash-checked during audit; **they are not yet imported into this Git branch**. Existing hosted approved art: https://frontier-mountain-approved-art.onrender.com/ (58 render assets according to approved manifest). Do not substitute generated or unapproved art.

## Implementation order
1. Copy approved source sheets and validated transparent crops into `assets/approved_sprites/`; create sprite-region metadata; test nearest-neighbour rendering and transparency.
2. Port world data and camera; preserve world geometry and collision.
3. Port analog controls, eight-direction animation state machine, tool/interaction handling.
4. Port full forestry state machine and resource lifecycle.
5. Port economy, market, merchant, contracts, progression and equipment data unchanged.
6. Port production, environmental systems, UI, audio, save/load and regression tests.
7. Validate browser/mobile/controller behavior on isolated preview builds, then promote only after review.

## Acceptance gate before live promotion
- Parity matrix covering every system above.
- Automated headless Godot parse/export tests.
- Visual inspection of approved character, tree and building crops in all applicable states.
- Mobile landscape analog joystick and physical controller input checks.
- Repeated save/load and full logging → selling → upgrade → production gameplay loops.

## Release interpretation
Automatic builds for approved changes; **do not update the current live service or original game during Phase 1**. Create isolated preview infrastructure before running CI builds for this branch.
