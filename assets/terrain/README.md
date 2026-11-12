# Frontier Mountain — Approved Terrain Pack v1.0

**Approval:** Terrain concept board approved by the project owner on 2026-11-11.
**Engine:** Godot 4.4 / TileMapLayer. **Artwork:** 32×32 RGBA atlas, 12 columns × 10 rows = **120** addressed art tiles.

The shipping `terrain_atlas.png` was cropped, adapted and composed from the user-approved Terrain Sprite Pack v1.0 image. It does not introduce a different art style or modify the five approved character/tree/building atlases.

## Atlas indices (zero-based)
| Tile IDs | Contents | Count |
| --- | --- | ---: |
| 0–23 | 6 terrain families × 4 variants (clearing, meadow, shade, pine, deciduous, compacted) | 24 |
| 24–59 | 3 terrain transition families × 12 mask/edge variants | 36 |
| 60–79 | 16 connected path-mask shapes + 4 worn/rutted interior variations | 20 |
| 80–95 | 16 matching timber landing ground masks | 16 |
| 96–115 | 20 transparent approved details: grass, flowers, stones, moss, twigs and leaves | 20 |
| 116–119 | 4 approved timber-landing props: sign, rail, post, angled rail | 4 |

Coordinate conversion: `atlas=(tile_id % 12, floor(tile_id / 12))`. The transparent masks use the four-corner bit convention **1=NW, 2=NE, 4=SE, 8=SW** for naturally connected tile edges.

## World authoring
- `scripts/forest_terrain.gd` owns `BaseGround`, `GroundTransitions`, `ConnectedForestPaths`, `LumberLoadingZone`, and `GroundDetailOverlays` (five independent TileMapLayers).
- The world remains 96 × 76 tiles, each 32 units; noise seeds and a deterministic coordinate hash provide reproducible patches and per-biome variation.
- Path and loading masks share the same tile-corner samples, preventing broken junctions. The loading zone is empty until harvested timber is delivered; fences are nonblocking display props.
- All terrain layers have no collision shapes. Tree collision is still controlled by `forestry_game.gd` and disappears **on the final chop, before bucking**.
- Trees, cabin, tool shed, gamepad, sound, fullscreen and hauling are unchanged.
- No flattened game screenshot or painted background was used.
- The source approved artboard is retained in the ChatGPT conversation; the shipping atlas is a derivative work of that artboard.

Tested via Render's Godot headless smoke suite and live-browser screenshot captures. Pixel-art tiles use nearest-neighbour filtering.
