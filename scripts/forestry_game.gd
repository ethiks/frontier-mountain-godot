extends Node2D
## Frontier Mountain — normalized independent sprites and simple procedural terrain.
## No composite or pre-rendered background: the lumberjack, trees, buildings, and loading props are independent.
const ART := "res://assets/approved_sprites/crops/"
const WORLD_SIZE := Vector2(3072.0, 2432.0) # 96 x 76 tiles
const CHUNK_SIZE := 384.0
const HOMESTEAD_ORIGIN := Vector2(860.0, 760.0)
const CABIN_ENTRY := HOMESTEAD_ORIGIN + Vector2(707.0, 352.0)
const SHED_ENTRY := HOMESTEAD_ORIGIN + Vector2(962.0, 392.0)
const FRAME_W := 84
const FRAME_H := 92
const PLAYER_SPEED := 225.0
const INTERACT_RADIUS := 98.0
const LOG_CAPACITY := 4
const PLAYER_COLLISION_RADIUS := 13.0
# Subrectangles select ONLY the one complete log per approved source crop.
# The original wider files contain neighboring atlas fragments above and to the right.
const LOG_CROP_RECTS := [Rect2(4, 18, 85, 40), Rect2(0, 17, 75, 37), Rect2(0, 20, 76, 36), Rect2(0, 15, 71, 35)]
const CABIN_BLOCKER := Rect2(497.0, 222.0, 309.0, 106.0)
const SHED_BLOCKER := Rect2(887.0, 298.0, 170.0, 69.0)
const YARD_POSITION := HOMESTEAD_ORIGIN + Vector2(802.0, 564.0)
const TYPES := ["pine", "spruce", "birch", "oak"]
const HEALTH := [2, 3, 2, 4]
const VALUES := [8, 10, 12, 14]
const YIELDS := [2, 2, 2, 3]

# Canonical sprite scale table. Sizes are measured in in-world pixels at 1280x720.
# Logger standing and carrying source artwork has different internal empty padding.
# Normalize HUMAN body height while allowing the timber prop to be bigger.
const LOGGER_IDLE_SCALE := 0.575
const LOGGER_CARRY_SCALE := 0.725
const LOGGER_ACTION_SCALE := 0.640
const LOGGER_BODY_HEIGHT := 50.0
const CABIN_DOOR_HEIGHT := 51.0
const TOOL_SHED_DOOR_HEIGHT := 60.0
const TREE_HEIGHT := [223.0, 229.0, 202.0, 216.0]
const FALLEN_TRUNK_WIDTH := [174.0, 184.0, 160.0, 177.0]
const LOOSE_LOG_WIDTH := 94.0
const TREE_SPAWNS := [
    Vector2(70, 496), Vector2(280, 626), Vector2(390, 687),
    Vector2(1217, 674), Vector2(1225, 377), Vector2(1130, 540),
    Vector2(104, 696), Vector2(1052, 692)
]

var player_pos := HOMESTEAD_ORIGIN + Vector2(590.0, 500.0)
var facing := 4
var walking_clock := 0.0
var swing_clock := 0.0
var swing_kind := "chop"
var is_moving := false
var previous_action_down := false
var cash := 0
var carried: Array[int] = []
var trees: Array[Dictionary] = []
var ground_logs: Array[Dictionary] = []
var texture_cache: Dictionary = {}
var forest_chunks: Dictionary = {} # Vector2i -> Array of tree IDs
var active_chunks: Dictionary = {}
var streamed_active_chunks := 0
var chunk_refresh_timer := 0.0
var last_streamed_pos := Vector2(-99999.0, -99999.0)
var camera: Camera2D
var terrain: Node2D
var navigation_label: Label
var logger: Sprite2D
var joystick: Control
var hud: Label
var instructions: Label
var message: Label
var action_button: Button
var world_time := 0.0
var audio_engine
var mixer_panel: Panel
var music_slider: HSlider
var effects_slider: HSlider
var sound_button: Button
var mixer_button: Button
var fullscreen_button: Button
var top_panel: ColorRect
var message_text := "Chop a tree, buck the trunk, collect logs, then take them to the signed loading bay."

func _texture(name: String) -> Texture2D:
    if not texture_cache.has(name):
        texture_cache[name] = load(ART + name + ".webp") as Texture2D
    return texture_cache[name]

func _ready() -> void:
    audio_engine = preload("res://scripts/legacy_audio.gd").new()
    audio_engine.name = "LegacyAudio"
    add_child(audio_engine)
    _setup_background()
    _setup_trees()
    _setup_player()
    _setup_ui()
    _update_visible_chunks(true)
    _update_hud()
    get_viewport().size_changed.connect(_on_viewport_resized)
    _on_viewport_resized()

func _setup_background() -> void:
    # Dynamic terrain, not a fixed illustration or an unapproved sprite pack.
    terrain = preload("res://scripts/forest_terrain.gd").new()
    terrain.name = "ForestTerrain"
    terrain.z_index = -100
    add_child(terrain)
    # Preserve the existing independently sized cabin and single tool shed.
    _place_prop("cabin-day", HOMESTEAD_ORIGIN + Vector2(650.0, 326.0), 340.0, 1)
    _place_prop("shed", HOMESTEAD_ORIGIN + Vector2(968.0, 365.0), 206.0, 1)

func _place_prop(name: String, foot: Vector2, width: float, depth: int) -> void:
    var tex: Texture2D = _texture(name)
    if tex == null:
        push_warning("Missing independent approved prop: " + name)
        return
    var sprite := Sprite2D.new()
    sprite.name = "Prop_" + name
    sprite.texture = tex
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var world_scale: float = width / float(tex.get_width())
    sprite.scale = Vector2.ONE * world_scale
    sprite.position = foot - Vector2(0.0, float(tex.get_height()) * world_scale * 0.5)
    sprite.z_index = int(foot.y / 10.0) # sort by ground contact
    add_child(sprite)

func _tree_scale(species: int) -> float:
    var tex: Texture2D = _texture("tree-%s-0" % TYPES[species])
    return TREE_HEIGHT[species] / float(tex.get_height()) if tex != null else 1.0

func _anchor_at_ground(sprite: Sprite2D, pos: Vector2, tex: Texture2D, scale: float) -> void:
    # Every tree stage preserves its base position while its sheet frame changes size.
    sprite.texture = tex
    sprite.scale = Vector2.ONE * scale
    sprite.position = pos - Vector2(0.0, float(tex.get_height()) * scale * 0.5)

func _setup_trees() -> void:
    # Preserve the original clearing layout relative to the lumberjack.
    for i in range(TREE_SPAWNS.size()):
        _register_tree(TREE_SPAWNS[i] + HOMESTEAD_ORIGIN, i % TYPES.size())
    # Deterministic forest across the remainder of the original 96x76 map.
    var generated: Array[Dictionary] = terrain.call("generate_forest_positions")
    for entry in generated:
        _register_tree(entry["pos"], int(entry["type"]))

func _register_tree(pos: Vector2, species: int) -> void:
    var tree: Dictionary = {
        "pos": pos, "type": species, "hp": HEALTH[species],
        "max_hp": HEALTH[species], "state": 0, "fall_time": 0.0, "sprite": null
    }
    var id := trees.size()
    trees.append(tree)
    var key := _chunk_key(pos)
    if not forest_chunks.has(key):
        forest_chunks[key] = []
    forest_chunks[key].append(id)

func _chunk_key(pos: Vector2) -> Vector2i:
    return Vector2i(int(floor(pos.x / CHUNK_SIZE)), int(floor(pos.y / CHUNK_SIZE)))

func _nearby_tree_ids(pos: Vector2) -> Array[int]:
    var result: Array[int] = []
    var cell := _chunk_key(pos)
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            var candidate := cell + Vector2i(dx, dy)
            if forest_chunks.has(candidate):
                for i in forest_chunks[candidate]:
                    result.append(int(i))
    return result

func _ensure_tree_sprite(tree: Dictionary) -> void:
    if int(tree["state"]) == 3 or is_instance_valid(tree["sprite"]):
        return
    var species: int = int(tree["type"])
    var state: int = int(tree["state"])
    var stage := 0
    if state == 1:
        stage = mini(4, 1 + int(float(tree["fall_time"]) / 0.19))
    elif state == 2:
        stage = 4
    var tex := _texture("tree-%s-%d" % [TYPES[species], stage])
    if tex == null:
        return
    var sprite := Sprite2D.new()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.z_index = int(tree["pos"].y / 10.0)
    add_child(sprite)
    var scale: float = _tree_scale(species) if state == 0 else FALLEN_TRUNK_WIDTH[species] / float(tex.get_width())
    _anchor_at_ground(sprite, tree["pos"], tex, scale)
    tree["sprite"] = sprite

func _update_visible_chunks(force: bool = false) -> void:
    if camera == null:
        return
    # Only materialize tree sprites for the visible region plus one chunk.
    # All harvested state stays in data, even when the chunk is unloaded.
    var extent := get_viewport_rect().size * 0.5 + Vector2(CHUNK_SIZE, CHUNK_SIZE)
    var visible := Rect2(player_pos - extent, extent * 2.0)
    var active := 0
    for cell in forest_chunks.keys():
        var chunk_rect := Rect2(Vector2(cell) * CHUNK_SIZE, Vector2(CHUNK_SIZE, CHUNK_SIZE))
        var should_load := chunk_rect.intersects(visible)
        var was_loaded := bool(active_chunks.get(cell, false))
        if force or was_loaded != should_load:
            for id in forest_chunks[cell]:
                var tree: Dictionary = trees[int(id)]
                if should_load:
                    _ensure_tree_sprite(tree)
                else:
                    var sprite: Sprite2D = tree["sprite"]
                    if is_instance_valid(sprite):
                        sprite.queue_free()
                    tree["sprite"] = null
            active_chunks[cell] = should_load
        if should_load:
            active += 1
    streamed_active_chunks = active
    last_streamed_pos = player_pos

func _update_camera(delta: float) -> void:
    if camera == null:
        return
    camera.position = player_pos
    chunk_refresh_timer += delta
    if chunk_refresh_timer > 0.2 and player_pos.distance_to(last_streamed_pos) > 32.0:
        chunk_refresh_timer = 0.0
        _update_visible_chunks()
    if terrain != null:
        terrain.call("update_view", player_pos, get_viewport_rect().size)

func _setup_player() -> void:
    var tex := load("res://assets/world/logger-eight-way-normalized.webp") as Texture2D
    if tex == null:
        push_error("Missing approved 8-way lumberjack sprite atlas")
        return
    logger = Sprite2D.new()
    logger.name = "Lumberjack"
    logger.texture = tex
    logger.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    logger.region_enabled = true
    logger.region_rect = Rect2(4 * FRAME_W, 0, FRAME_W, FRAME_H)
    logger.scale = Vector2.ONE * LOGGER_IDLE_SCALE
    logger.z_index = int(player_pos.y / 10.0)
    add_child(logger)
    _set_player_pose(0, LOGGER_IDLE_SCALE)
    camera = Camera2D.new()
    camera.name = "FollowCamera"
    camera.position = player_pos
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = int(WORLD_SIZE.x)
    camera.limit_bottom = int(WORLD_SIZE.y)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 5.5
    camera.offset = Vector2(0.0, -145.0) # show cabin and trail while logger stays lower on screen
    add_child(camera)
    camera.make_current()

func _set_player_pose(row: int, scale: float) -> void:
    if logger == null:
        return
    logger.region_rect = Rect2(facing * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
    logger.scale = Vector2.ONE * scale
    # Atlas alpha bottom ends at frame-local Y=89 for the complete action rows.
    # Track boots (not frame centre) against the game collision point.
    logger.position = player_pos - Vector2(0.0, (89.0 - float(FRAME_H) * 0.5) * scale)

func _label(parent: Node, txt: String, pos: Vector2, fontsize: int, color: Color) -> Label:
    var label := Label.new()
    label.text = txt
    label.position = pos
    label.add_theme_font_size_override("font_size", fontsize)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color("#101d15"))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    parent.add_child(label)
    return label

func _setup_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    top_panel = ColorRect.new()
    top_panel.color = Color(0.05, 0.10, 0.08, 0.82)
    top_panel.size = Vector2(1280, 116)
    top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(top_panel)
    hud = _label(layer, "FRONTIER MOUNTAIN", Vector2(24, 12), 25, Color("#f8e5b1"))
    instructions = _label(layer, "Walk: joystick / WASD / controller    Act: E / SPACE / controller A", Vector2(26, 49), 15, Color("#e9e8ce"))
    message = _label(layer, message_text, Vector2(26, 77), 17, Color("#ffdc96"))
    navigation_label = _label(layer, "FOREST / HOME", Vector2(26, 123), 15, Color("#efe0ba"))
    joystick = preload("res://scripts/virtual_joystick.gd").new()
    joystick.position = Vector2(24, 516)
    layer.add_child(joystick)
    action_button = Button.new()
    action_button.text = "CHOP"
    action_button.position = Vector2(1062, 576)
    action_button.size = Vector2(176, 86)
    action_button.add_theme_font_size_override("font_size", 21)
    action_button.pressed.connect(_interact)
    layer.add_child(action_button)
    sound_button = Button.new()
    sound_button.text = "SOUND"
    sound_button.position = Vector2(950, 20)
    sound_button.size = Vector2(103, 51)
    sound_button.add_theme_font_size_override("font_size", 15)
    sound_button.pressed.connect(_toggle_audio)
    layer.add_child(sound_button)
    mixer_button = Button.new()
    mixer_button.text = "MIX"
    mixer_button.position = Vector2(1063, 20)
    mixer_button.size = Vector2(75, 51)
    mixer_button.add_theme_font_size_override("font_size", 15)
    mixer_button.pressed.connect(_toggle_mixer)
    layer.add_child(mixer_button)
    fullscreen_button = Button.new()
    fullscreen_button.text = "FULLSCREEN"
    fullscreen_button.position = Vector2(1148, 20)
    fullscreen_button.size = Vector2(114, 51)
    fullscreen_button.add_theme_font_size_override("font_size", 13)
    fullscreen_button.pressed.connect(_toggle_fullscreen)
    layer.add_child(fullscreen_button)
    mixer_panel = Panel.new()
    mixer_panel.position = Vector2(878, 117)
    mixer_panel.size = Vector2(378, 222)
    mixer_panel.visible = false
    layer.add_child(mixer_panel)
    _label(mixer_panel, "AUDIO / FRONTIER MOUNTAIN", Vector2(17, 13), 16, Color("#e8d4a6"))
    _label(mixer_panel, "Music", Vector2(18, 50), 15, Color.WHITE)
    music_slider = HSlider.new()
    music_slider.position = Vector2(120, 50)
    music_slider.size = Vector2(240, 29)
    music_slider.min_value = 0.0
    music_slider.max_value = 1.0
    music_slider.step = 0.05
    music_slider.value = audio_engine.music_level
    music_slider.value_changed.connect(func(value: float): audio_engine.set_music_level(value))
    mixer_panel.add_child(music_slider)
    _label(mixer_panel, "Logging SFX", Vector2(18, 102), 15, Color.WHITE)
    effects_slider = HSlider.new()
    effects_slider.position = Vector2(120, 102)
    effects_slider.size = Vector2(240, 29)
    effects_slider.min_value = 0.0
    effects_slider.max_value = 1.0
    effects_slider.step = 0.05
    effects_slider.value = audio_engine.sfx_level
    effects_slider.value_changed.connect(func(value: float): audio_engine.set_sfx_level(value))
    mixer_panel.add_child(effects_slider)
    var test_button := Button.new()
    test_button.text = "TEST CHOP SOUND"
    test_button.position = Vector2(16, 155)
    test_button.size = Vector2(345, 49)
    test_button.pressed.connect(func(): audio_engine.play_fx("axe-chop"))
    mixer_panel.add_child(test_button)

func _toggle_audio() -> void:
    audio_engine.toggle_enabled()
    _update_hud()

func _toggle_mixer() -> void:
    mixer_panel.visible = not mixer_panel.visible
    if mixer_panel.visible:
        audio_engine.begin_audio()

func _toggle_fullscreen() -> void:
    # Browser fullscreen requires a real click/button press, not a frame tick.
    if OS.has_feature("web"):
        JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas')||document.querySelector('canvas');if(document.fullscreenElement){document.exitFullscreen();}else if(c&&c.requestFullscreen){c.requestFullscreen().catch(function(e){console.warn('Fullscreen blocked',e);});}})()")
    else:
        var current := DisplayServer.window_get_mode()
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if current == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_viewport_resized() -> void:
    var visible_size := get_viewport_rect().size
    if top_panel != null:
        top_panel.size.x = visible_size.x
    if joystick != null:
        joystick.position = Vector2(24, visible_size.y - 204)
    if action_button != null:
        action_button.position = Vector2(visible_size.x - 218, visible_size.y - 144)
    if fullscreen_button != null:
        fullscreen_button.position.x = visible_size.x - 132
    if sound_button != null:
        sound_button.position.x = visible_size.x - 330
    if mixer_button != null:
        mixer_button.position.x = visible_size.x - 217
    if mixer_panel != null:
        mixer_panel.position.x = visible_size.x - 404
    if terrain != null:
        terrain.call("update_view", player_pos, visible_size)
    _update_visible_chunks(true)

func _input(event: InputEvent) -> void:
    # Unlock mobile/Web audio within a user gesture (autoplay is restricted).
    if audio_engine == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        audio_engine.begin_audio()
    elif event is InputEventScreenTouch and event.pressed:
        audio_engine.begin_audio()
    elif event is InputEventMouseButton and event.pressed:
        audio_engine.begin_audio()
    elif event is InputEventJoypadButton and event.pressed:
        audio_engine.begin_audio()
        if event.button_index == JOY_BUTTON_START:
            _toggle_fullscreen()

func _process(delta: float) -> void:
    world_time += delta
    _move_player(delta)
    _update_camera(delta)
    _animate_trees(delta)
    _update_canopy_occlusion()
    var row := 0 # Authored idle row 4 is missing its boots: use complete standing walk frame 0.
    var scale := LOGGER_IDLE_SCALE
    if swing_clock > 0.0:
        swing_clock = maxf(0.0, swing_clock - delta)
        row = 11 if swing_kind == "buck" else (5 if swing_clock > 0.16 else 6)
        scale = LOGGER_ACTION_SCALE
    elif not carried.is_empty():
        row = 9 + (int(walking_clock * 1.5) % 2 if is_moving else 0)
        scale = LOGGER_CARRY_SCALE
    elif is_moving:
        row = int(walking_clock) % 4
    _set_player_pose(row, scale)
    if logger != null:
        logger.z_index = int(player_pos.y / 10.0)
    var action_down := Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
    if action_down and not previous_action_down:
        _interact()
    previous_action_down = action_down
    _update_hud()
    queue_redraw()

func _move_player(delta: float) -> void:
    var movement := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        movement.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        movement.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        movement.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        movement.y += 1.0
    if Input.get_connected_joypads().size() > 0:
        var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
        if stick.length() > 0.13:
            movement += stick
    if joystick != null:
        movement += joystick.vector
    movement = movement.limit_length(1.0)
    is_moving = movement.length() > 0.12
    if is_moving:
        _move_with_collisions(movement * PLAYER_SPEED * delta)
        facing = posmod(int(round((atan2(movement.y, movement.x) + PI / 2.0) / (PI / 4.0))), 8)
        walking_clock += delta * 7.0
    else:
        walking_clock = 0.0

func _move_with_collisions(delta_pos: Vector2) -> void:
    # Substep movement so high-delta frames cannot tunnel through trunks or walls.
    var steps := maxi(1, int(ceil(delta_pos.length() / 7.0)))
    var part := delta_pos / float(steps)
    for index in range(steps):
        var candidate_x := Vector2(clampf(player_pos.x + part.x, 33.0, WORLD_SIZE.x - 33.0), player_pos.y)
        if not _collides_at(candidate_x):
            player_pos.x = candidate_x.x
        var candidate_y := Vector2(player_pos.x, clampf(player_pos.y + part.y, 33.0, WORLD_SIZE.y - 33.0))
        if not _collides_at(candidate_y):
            player_pos.y = candidate_y.y

func _collides_at(candidate: Vector2) -> bool:
    # Actor origin is between the boots. Broad solid building bases are
    # intentionally impassable until interiors and door triggers are designed.
    var local_pos := candidate - HOMESTEAD_ORIGIN
    if CABIN_BLOCKER.grow(PLAYER_COLLISION_RADIUS).has_point(local_pos):
        return true
    if SHED_BLOCKER.grow(PLAYER_COLLISION_RADIUS).has_point(local_pos):
        return true
    for i in _nearby_tree_ids(candidate):
        var tree: Dictionary = trees[i]
        # Tree collision exists ONLY while a tree is standing.
        # The final chop changes state to 1 immediately, releasing the old
        # trunk hitbox before the falling animation ends and before bucking.
        # Fallen timber stays visible and buckable, but is not solid.
        if int(tree["state"]) != 0:
            continue
        var tree_base: Vector2 = tree["pos"]
        if candidate.distance_to(tree_base) < PLAYER_COLLISION_RADIUS + 18.0:
            return true
    return false

func _animate_trees(delta: float) -> void:
    for tree in trees:
        if int(tree["state"]) != 1:
            continue
        tree["fall_time"] = float(tree["fall_time"]) + delta
        var species: int = int(tree["type"])
        var elapsed: float = float(tree["fall_time"])
        var stage: int = mini(4, 1 + int(elapsed / 0.19))
        var tex := _texture("tree-%s-%d" % [TYPES[species], stage])
        var falling_sprite: Sprite2D = tree["sprite"]
        if tex != null and is_instance_valid(falling_sprite):
            var size_scale: float = FALLEN_TRUNK_WIDTH[species] / float(tex.get_width())
            _anchor_at_ground(falling_sprite, tree["pos"], tex, size_scale)
        if elapsed > 0.9:
            tree["state"] = 2
            _say("Timber! The trunk is down. BUCK it into logs.")

func _update_canopy_occlusion() -> void:
    # In a dense forest, a nearby canopy should not conceal the lumberjack.
    # Only the relevant approved tree sprites become temporarily translucent;
    # no image assets or collision shapes are changed.
    for id in _nearby_tree_ids(player_pos):
        var tree: Dictionary = trees[id]
        var sprite: Sprite2D = tree["sprite"]
        if not is_instance_valid(sprite):
            continue
        var species: int = int(tree["type"])
        var offset: Vector2 = tree["pos"] - player_pos
        var covers_player: bool = int(tree["state"]) == 0 and offset.y > 0.0 and offset.y < TREE_HEIGHT[species] * 0.76 and absf(offset.x) < 81.0
        sprite.modulate.a = 0.46 if covers_player else 1.0

func _nearest_tree() -> Dictionary:
    var selected: Dictionary = {}
    var best := INTERACT_RADIUS
    for i in _nearby_tree_ids(player_pos):
        var tree: Dictionary = trees[i]
        if int(tree["state"]) == 3:
            continue
        var d: float = player_pos.distance_to(tree["pos"])
        if d < best:
            selected = tree
            best = d
    return selected

func _nearest_log_index() -> int:
    var best := INTERACT_RADIUS
    var selected := -1
    for i in range(ground_logs.size()):
        var d: float = player_pos.distance_to(ground_logs[i]["pos"])
        if d < best:
            best = d
            selected = i
    return selected

func _interact() -> void:
    if player_pos.distance_to(YARD_POSITION) < 110.0 and not carried.is_empty():
        var income := 0
        for species in carried:
            income += VALUES[species]
        var total := carried.size()
        cash += income
        audio_engine.play_fx("log-drop", 0.7)
        carried.clear()
        _say("Delivered %d full-size logs. Earned $%d." % [total, income])
        return
    if player_pos.distance_to(CABIN_ENTRY) < 68.0:
        _say("CABIN ENTRANCE: rest and save will unlock in the next milestone.")
        return
    if player_pos.distance_to(SHED_ENTRY) < 67.0:
        _say("TOOL SHED: equipment access will unlock in the next milestone.")
        return
    var index := _nearest_log_index()
    if index >= 0 and carried.size() < LOG_CAPACITY:
        var item: Dictionary = ground_logs[index]
        var sprite: Sprite2D = item["sprite"]
        sprite.queue_free()
        carried.append(int(item["type"]))
        audio_engine.play_fx("log-lift", 0.72)
        ground_logs.remove_at(index)
        _say("Carrying %s timber (%d/%d)." % [TYPES[carried.back()], carried.size(), LOG_CAPACITY])
        return
    if index >= 0 and carried.size() == LOG_CAPACITY:
        _say("Load full! Take the logs to the marked lumberyard.")
        return
    var tree := _nearest_tree()
    if tree.is_empty():
        _say("Approach a harvestable tree, a cut log, or the lumberyard sign.")
        return
    if int(tree["state"]) == 1:
        _say("The trunk is falling. Give it room.")
        return
    if int(tree["state"]) == 2:
        _buck_tree(tree)
        return
    var species: int = int(tree["type"])
    var direction: Vector2 = tree["pos"] - player_pos
    if direction.length() > 2.0:
        facing = posmod(int(round((atan2(direction.y, direction.x) + PI / 2.0) / (PI / 4.0))), 8)
    tree["hp"] = int(tree["hp"]) - 1
    audio_engine.play_fx("axe-chop", 0.95)
    swing_kind = "chop"
    swing_clock = 0.33
    if int(tree["hp"]) <= 0:
        tree["state"] = 1
        tree["fall_time"] = 0.0
        audio_engine.play_fx("tree-fall", 0.92)
        _say("TIMBER! %s is falling." % TYPES[species].capitalize())
    else:
        _say("%s: %d more chops." % [TYPES[species].capitalize(), int(tree["hp"])])

func _buck_tree(tree: Dictionary) -> void:
    var species: int = int(tree["type"])
    tree["state"] = 3
    # The approved tree-%s-5 crop contains neighboring atlas fragments.
    # Hide the old tree entirely; render only sub-cropped clean approved log sprites.
    var standing_sprite: Sprite2D = tree["sprite"]
    if is_instance_valid(standing_sprite):
        standing_sprite.visible = false
    for i in range(YIELDS[species]):
        var separation := (float(i) - float(YIELDS[species] - 1) * 0.5) * 78.0
        _spawn_log(tree["pos"] + Vector2(separation, 19.0 + float(i % 2) * 14.0), species)
    audio_engine.play_fx("wood-buck", 0.68)
    swing_kind = "buck"
    swing_clock = 0.38
    _say("Bucked %s into %d scaled logs." % [TYPES[species], YIELDS[species]])

func _spawn_log(pos: Vector2, species: int) -> void:
    var tex := _texture("loose-%d" % species)
    var sprite := Sprite2D.new()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.texture = tex
    if tex != null:
        sprite.region_enabled = true
        sprite.region_filter_clip_enabled = true
        sprite.region_rect = LOG_CROP_RECTS[species]
        sprite.scale = Vector2.ONE * (LOOSE_LOG_WIDTH / LOG_CROP_RECTS[species].size.x)
    sprite.position = pos
    sprite.z_index = int(pos.y / 10.0)
    add_child(sprite)
    ground_logs.append({"pos": pos, "type": species, "sprite": sprite})

func _update_hud() -> void:
    if hud == null:
        return
    hud.text = "FRONTIER MOUNTAIN   |   $%d   |   LOGS %d/%d   |   TREES %d" % [cash, carried.size(), LOG_CAPACITY, _standing_count()]
    if message.text != message_text:
        message.text = message_text
    if navigation_label != null:
        navigation_label.text = "WILDERNESS 96 x 76  |  HOME %d tiles  |  CHUNKS %d" % [int(player_pos.distance_to(YARD_POSITION) / 32.0), streamed_active_chunks]
    if sound_button != null:
        sound_button.text = "SOUND ON" if audio_engine.enabled and audio_engine.unlocked else ("SOUND OFF" if not audio_engine.enabled else "SOUND")
    if player_pos.distance_to(YARD_POSITION) < 110.0 and not carried.is_empty():
        action_button.text = "SELL LOGS"
    elif player_pos.distance_to(CABIN_ENTRY) < 68.0:
        action_button.text = "CABIN"
    elif player_pos.distance_to(SHED_ENTRY) < 67.0:
        action_button.text = "TOOL SHED"
    elif _nearest_log_index() >= 0:
        action_button.text = "PICK UP" if carried.size() < LOG_CAPACITY else "FULL LOAD"
    else:
        var tree := _nearest_tree()
        if tree.is_empty():
            action_button.text = "ACTION"
        elif int(tree["state"]) == 2:
            action_button.text = "BUCK"
        elif int(tree["state"]) == 1:
            action_button.text = "TIMBER!"
        else:
            action_button.text = "CHOP"

func _standing_count() -> int:
    var count := 0
    for tree in trees:
        if int(tree["state"]) == 0:
            count += 1
    return count

func _say(words: String) -> void:
    message_text = words

func _draw() -> void:
    # Environment ground and paths come from the streamed terrain node.
    draw_circle(player_pos + Vector2(0.0, 3.0), 9.0, Color(0.06, 0.11, 0.07, 0.35))
    for tree_id in _nearby_tree_ids(player_pos):
        var tree: Dictionary = trees[tree_id]
        if int(tree["state"]) == 0 and int(tree["hp"]) < int(tree["max_hp"]):
            var p: Vector2 = tree["pos"]
            var ratio := float(tree["hp"]) / float(tree["max_hp"])
            draw_rect(Rect2(p + Vector2(-24, -TREE_HEIGHT[int(tree["type"])] - 8), Vector2(48, 6)), Color("#253127"))
            draw_rect(Rect2(p + Vector2(-23, -TREE_HEIGHT[int(tree["type"])] - 7), Vector2(46.0 * ratio, 4)), Color("#e8be71"))
