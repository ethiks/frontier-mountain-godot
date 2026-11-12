extends Node2D
## Frontier Mountain 1.0 — approved artwork TileMapLayer terrain.
## All 120 32px atlas pieces are derived from the user-approved terrain board.
## Drawing ground, road and landing geometry as placeholder shapes is retired.
const WORLD_TILES := Vector2i(96, 76)
const TILE_SIZE := 32.0
const WORLD_SIZE := Vector2(3072.0, 2432.0)
const CHUNK_SIZE := 384.0
const HOMESTEAD := Vector2(860.0, 760.0)
const HOME_CENTER := HOMESTEAD + Vector2(660.0, 450.0)
const YARD := HOMESTEAD + Vector2(802.0, 564.0)
const TREE_DENSITY := 0.88
const ATLAS_TEXTURE := preload("res://assets/terrain/terrain_atlas.png")
const GROUND_VARIANTS := 4
const ROAD_START := 60
const YARD_START := 80
const DETAIL_START := 96
const PROP_START := 116
const MASK_CORNER_POS := [Vector2(0.0, 0.0), Vector2(32.0, 0.0), Vector2(32.0, 32.0), Vector2(0.0, 32.0)]

var view_center := HOMESTEAD + Vector2(590.0, 355.0)
var view_size := Vector2(1280.0, 720.0)
var tile_set_resource: TileSet
var ground_layer: TileMapLayer
var transition_layer: TileMapLayer
var paths_layer: TileMapLayer
var loading_layer: TileMapLayer
var detail_layer: TileMapLayer
var biome_noise: FastNoiseLite
var patch_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var biome_counts: Dictionary = {}
var terrain_seed: int = 4317

static func hash01(ix: int, iy: int, salt: int) -> float:
    var raw: int = posmod(ix * 73856093 + iy * 19349663 + salt * 83492791, 99991)
    return float(raw) / 99991.0

static func chunk_for(pos: Vector2) -> Vector2i:
    return Vector2i(int(floor(pos.x / CHUNK_SIZE)), int(floor(pos.y / CHUNK_SIZE)))

func _ready() -> void:
    _setup_noise()
    _setup_layers()
    _build_map()
    _setup_loading_zone_props()

func _setup_noise() -> void:
    biome_noise = FastNoiseLite.new()
    biome_noise.seed = terrain_seed
    biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    biome_noise.frequency = 0.027
    biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    biome_noise.fractal_octaves = 3
    patch_noise = FastNoiseLite.new()
    patch_noise.seed = terrain_seed + 105
    patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    patch_noise.frequency = 0.065
    detail_noise = FastNoiseLite.new()
    detail_noise.seed = terrain_seed + 237
    detail_noise.frequency = 0.084

func _setup_layers() -> void:
    tile_set_resource = TileSet.new()
    tile_set_resource.tile_size = Vector2i(32, 32)
    var source := TileSetAtlasSource.new()
    source.texture = ATLAS_TEXTURE
    source.texture_region_size = Vector2i(32, 32)
    for y in range(10):
        for x in range(12):
            source.create_tile(Vector2i(x, y))
    tile_set_resource.add_source(source, 0)
    ground_layer = _new_layer("BaseGround", 0)
    transition_layer = _new_layer("GroundTransitions", 1)
    paths_layer = _new_layer("ConnectedForestPaths", 2)
    loading_layer = _new_layer("LumberLoadingZone", 3)
    detail_layer = _new_layer("GroundDetailOverlays", 4)

func _new_layer(name: String, depth: int) -> TileMapLayer:
    var layer := TileMapLayer.new()
    layer.name = name
    layer.tile_set = tile_set_resource
    layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    layer.z_index = depth
    add_child(layer)
    return layer

func _atlas_pos(id: int) -> Vector2i:
    return Vector2i(id % 12, id / 12)

func _set_tile(layer: TileMapLayer, cell: Vector2i, tile_id: int) -> void:
    layer.set_cell(cell, 0, _atlas_pos(tile_id))

func _build_map() -> void:
    # 96x76 source tiles fit in five compact Godot TileMapLayers.
    var biomes: Array[PackedInt32Array] = []
    for y in range(WORLD_TILES.y):
        var row := PackedInt32Array()
        row.resize(WORLD_TILES.x)
        for x in range(WORLD_TILES.x):
            var cell := Vector2i(x, y)
            var p := Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)
            var biome := _biome_at(cell, p)
            row[x] = biome
            biome_counts[biome] = int(biome_counts.get(biome, 0)) + 1
            var variant := int(hash01(x, y, 84) * 4.0) % 4
            _set_tile(ground_layer, cell, biome * GROUND_VARIANTS + variant)
        biomes.append(row)
    _build_transitions(biomes)
    _build_paths_and_yard()
    _build_details(biomes)

func _biome_at(cell: Vector2i, p: Vector2) -> int:
    var home_dist := p.distance_to(HOME_CENTER)
    var n := biome_noise.get_noise_2d(float(cell.x), float(cell.y))
    var pnoise := patch_noise.get_noise_2d(float(cell.x), float(cell.y))
    if p.distance_to(YARD) < 126.0:
        return 5 # workyard compacted earth
    if home_dist < 355.0 + n * 55.0:
        return 0 # clearing grass
    if home_dist < 560.0 + n * 105.0:
        return 1 if pnoise > -0.28 else 2 # meadow and shaded edge
    var regional := n * 0.76 + pnoise * 0.24
    if regional < -0.22:
        return 3 # dense pine needles / moss
    if regional < -0.05:
        return 2 # shaded dark grass
    if regional < 0.18:
        return 4 # deciduous leaf litter
    return 1 # open meadow pockets among woodland

func _build_transitions(biomes: Array[PackedInt32Array]) -> void:
    # Transition tiles are derived from the approved 3 material pair groups.
    # Use them sparingly where two ground biomes meet, without random boxes.
    var groups := [[0, 5], [2, 3], [1, 4]]
    for y in range(1, WORLD_TILES.y - 1):
        for x in range(1, WORLD_TILES.x - 1):
            var biome: int = biomes[y][x]
            for group_idx in range(groups.size()):
                var low: int = groups[group_idx][0]
                var high: int = groups[group_idx][1]
                if biome != low and biome != high:
                    continue
                var neighbor_mask := 0
                if biomes[y - 1][x] != biome and (biomes[y - 1][x] == low or biomes[y - 1][x] == high):
                    neighbor_mask |= 1
                if biomes[y][x + 1] != biome and (biomes[y][x + 1] == low or biomes[y][x + 1] == high):
                    neighbor_mask |= 2
                if biomes[y + 1][x] != biome and (biomes[y + 1][x] == low or biomes[y + 1][x] == high):
                    neighbor_mask |= 4
                if biomes[y][x - 1] != biome and (biomes[y][x - 1] == low or biomes[y][x - 1] == high):
                    neighbor_mask |= 8
                if neighbor_mask != 0 and hash01(x, y, 57) < 0.83:
                    var transition_variant := posmod(neighbor_mask * 3 + x * 5 + y * 7, 12)
                    _set_tile(transition_layer, Vector2i(x, y), 24 + group_idx * 12 + transition_variant)
                break

func _build_paths_and_yard() -> void:
    # Marching-squares corner masks connect across tile boundaries automatically.
    # Shared corner sampling prevents visibly disconnected trail segments.
    for y in range(WORLD_TILES.y):
        for x in range(WORLD_TILES.x):
            var cell := Vector2i(x, y)
            var p := Vector2(x * TILE_SIZE, y * TILE_SIZE)
            if p.distance_to(HOME_CENTER) > 950.0:
                continue
            var path_mask := 0
            var yard_mask := 0
            for j in range(4):
                var point: Vector2 = p + MASK_CORNER_POS[j]
                var corner_x := x + (1 if j == 1 or j == 2 else 0)
                var corner_y := y + (1 if j == 2 or j == 3 else 0)
                var wiggle := (hash01(corner_x, corner_y, 90) - 0.5) * 5.0
                if _path_distance(point) < 23.0 + wiggle:
                    path_mask |= (1 << j)
                if _inside_yard(point, wiggle):
                    yard_mask |= (1 << j)
            if path_mask != 0:
                var path_variant := path_mask
                if path_mask == 15:
                    path_variant = 16 + (int(hash01(x, y, 98) * 4.0) % 4)
                _set_tile(paths_layer, cell, ROAD_START + path_variant)
            if yard_mask != 0:
                _set_tile(loading_layer, cell, YARD_START + yard_mask)

func _inside_yard(p: Vector2, wiggle: float = 0.0) -> bool:
    # A modest timber landing, not a giant oval or decorative log pile.
    var offset := (p - (YARD + Vector2(0.0, -12.0))).abs()
    var clipped_corners := (offset.x + offset.y - 154.0) * 0.72
    var metric := maxf(maxf(offset.x - 115.0, offset.y - 83.0), clipped_corners)
    return metric < wiggle

func _path_distance(point: Vector2) -> float:
    var cabin := HOMESTEAD + Vector2(705.0, 356.0)
    var shed := HOMESTEAD + Vector2(940.0, 389.0)
    var landing := YARD + Vector2(0.0, -12.0)
    var clearing_exit := HOME_CENTER + Vector2(-248.0, 405.0)
    var north_path := HOME_CENTER + Vector2(-160.0, -455.0)
    var west_path := HOME_CENTER + Vector2(-555.0, 180.0)
    var d := _segment_distance(point, cabin, cabin + Vector2(-16.0, 72.0))
    d = minf(d, _segment_distance(point, cabin + Vector2(-16.0, 72.0), landing + Vector2(-37.0, -63.0)))
    d = minf(d, _segment_distance(point, landing + Vector2(-37.0, -63.0), landing))
    d = minf(d, _segment_distance(point, shed, shed + Vector2(-43.0, 65.0)))
    d = minf(d, _segment_distance(point, shed + Vector2(-43.0, 65.0), landing + Vector2(36.0, -44.0)))
    d = minf(d, _segment_distance(point, landing + Vector2(36.0, -44.0), landing))
    d = minf(d, _segment_distance(point, landing, clearing_exit))
    d = minf(d, _segment_distance(point, clearing_exit, west_path))
    d = minf(d, _segment_distance(point, cabin + Vector2(-16.0, 72.0), north_path))
    return d

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
    var delta := b - a
    var span := delta.length_squared()
    if span <= 0.001:
        return p.distance_to(a)
    var ratio := clampf((p - a).dot(delta) / span, 0.0, 1.0)
    return p.distance_to(a + delta * ratio)

func _build_details(biomes: Array[PackedInt32Array]) -> void:
    # Sparse, region-biased detail overlays (no collision). The same approved
    # flowers, rocks, twigs and leaf litter never form a uniform global pattern.
    for y in range(1, WORLD_TILES.y - 1):
        for x in range(1, WORLD_TILES.x - 1):
            var biome: int = biomes[y][x]
            if biome == 5:
                continue
            var p := Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)
            if p.distance_to(YARD) < 152.0 or _path_distance(p) < 33.0:
                continue
            var clump := detail_noise.get_noise_2d(float(x), float(y))
            var density := 0.10 + maxf(0.0, clump) * 0.16
            if biome == 0:
                density = 0.12 + maxf(0.0, clump) * 0.11
            elif biome == 3:
                density = 0.14 + maxf(0.0, clump) * 0.15
            if hash01(x, y, 119) > density:
                continue
            var species := 0
            var variation := int(hash01(x, y, 125) * 8.0) % 8
            match biome:
                0: species = variation # grasses and flowers
                1: species = variation if variation < 5 else 12 + variation % 4
                2: species = 4 + variation
                3: species = 8 + variation
                4: species = 12 + variation
                _: species = variation
            _set_tile(detail_layer, Vector2i(x, y), DETAIL_START + species)

func _setup_loading_zone_props() -> void:
    # The four wood props are cropped from the APPROVED pack, not new art.
    # They create a small marked delivery spot without placing any loose logs.
    _add_prop("ApprovedYardSign", 116, YARD + Vector2(-136.0, -123.0), 2.5)
    _add_prop("LoadingRailWest", 117, YARD + Vector2(-95.0, 68.0), 2.2)
    _add_prop("LoadingRailEast", 117, YARD + Vector2(75.0, 68.0), 2.2)
    _add_prop("LoadingPostLeft", 118, YARD + Vector2(-99.0, 71.0), 2.0)
    _add_prop("LoadingPostRight", 118, YARD + Vector2(112.0, 71.0), 2.0)

func _add_prop(name: String, idx: int, pos: Vector2, scale_factor: float) -> void:
    var sprite := Sprite2D.new()
    sprite.name = name
    sprite.texture = ATLAS_TEXTURE
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.region_enabled = true
    var atlas_cell := _atlas_pos(idx)
    sprite.region_rect = Rect2(Vector2(atlas_cell) * 32.0, Vector2.ONE * 32.0)
    sprite.scale = Vector2.ONE * scale_factor
    sprite.position = pos - Vector2(0.0, 16.0 * scale_factor)
    sprite.z_index = 5
    add_child(sprite)

func generate_forest_positions() -> Array[Dictionary]:
    # Preserve established tree layout and tree collision logic. Region-based
    # ground generation does NOT generate or modify tree hitboxes.
    var entries: Array[Dictionary] = []
    for gy in range(1, 14):
        for gx in range(1, 18):
            if hash01(gx, gy, 13) > TREE_DENSITY:
                continue
            var p := Vector2(
                float(gx) * 165.0 + (hash01(gx, gy, 23) - 0.5) * 66.0,
                float(gy) * 176.0 + (hash01(gx, gy, 29) - 0.5) * 58.0
            )
            if p.x < 100.0 or p.y < 130.0 or p.x > WORLD_SIZE.x - 105.0 or p.y > WORLD_SIZE.y - 95.0:
                continue
            if p.distance_to(HOME_CENTER) < 590.0:
                continue
            var species := posmod(gx * 3 + gy * 7, 4)
            entries.append({"pos": p, "type": species})
    return entries

func update_view(camera_center: Vector2, current_size: Vector2) -> void:
    # TileMapLayer culls render tiles natively; camera panning needs no redraw.
    view_center = camera_center
    view_size = current_size
