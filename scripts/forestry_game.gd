extends Node2D
## Frontier Mountain — normalized independent sprites and simple procedural terrain.
## No composite or pre-rendered background: the lumberjack, trees, buildings, and loading props are independent.
const ART := "res://assets/approved_sprites/crops/"
const FRAME_W := 84
const FRAME_H := 92
const PLAYER_SPEED := 225.0
const INTERACT_RADIUS := 98.0
const LOG_CAPACITY := 4
const PLAYER_COLLISION_RADIUS := 13.0
const CABIN_BLOCKER := Rect2(497.0, 222.0, 309.0, 106.0)
const SHED_BLOCKER := Rect2(887.0, 298.0, 170.0, 69.0)
const YARD_POSITION := Vector2(802, 564)
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

var player_pos := Vector2(347, 563)
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
var logger: Sprite2D
var joystick: Control
var hud: Label
var instructions: Label
var message: Label
var action_button: Button
var world_time := 0.0
var message_text := "Chop a tree, buck the trunk, collect logs, then take them to the signed loading bay."

func _texture(name: String) -> Texture2D:
    if not texture_cache.has(name):
        texture_cache[name] = load(ART + name + ".webp") as Texture2D
    return texture_cache[name]

func _ready() -> void:
    _setup_background()
    _setup_trees()
    _setup_player()
    _setup_ui()
    _update_hud()

func _setup_background() -> void:
    # No composite backdrop and no decorative log piles: only a cabin and a single toolshed.
    _place_prop("cabin-day", Vector2(650.0, 326.0), 340.0, 1)
    _place_prop("shed", Vector2(968.0, 365.0), 206.0, 1)

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
    for i in range(TREE_SPAWNS.size()):
        var species: int = i % TYPES.size()
        var tex := _texture("tree-%s-0" % TYPES[species])
        if tex == null:
            push_error("Missing approved tree texture: " + TYPES[species])
            continue
        var sprite := Sprite2D.new()
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.z_index = int(TREE_SPAWNS[i].y / 10.0)
        add_child(sprite)
        _anchor_at_ground(sprite, TREE_SPAWNS[i], tex, _tree_scale(species))
        trees.append({
            "pos": TREE_SPAWNS[i], "type": species,
            "hp": HEALTH[species], "max_hp": HEALTH[species],
            "state": 0, # standing -> falling -> down -> bucked
            "fall_time": 0.0, "sprite": sprite
        })

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
    var top_panel := ColorRect.new()
    top_panel.color = Color(0.05, 0.10, 0.08, 0.82)
    top_panel.size = Vector2(1280, 116)
    top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(top_panel)
    hud = _label(layer, "FRONTIER MOUNTAIN", Vector2(24, 12), 25, Color("#f8e5b1"))
    instructions = _label(layer, "Walk: joystick / WASD / controller    Act: E / SPACE / controller A", Vector2(26, 49), 15, Color("#e9e8ce"))
    message = _label(layer, message_text, Vector2(26, 77), 17, Color("#ffdc96"))
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

func _process(delta: float) -> void:
    world_time += delta
    _move_player(delta)
    _animate_trees(delta)
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
        var candidate_x := Vector2(clampf(player_pos.x + part.x, 32.0, 1248.0), player_pos.y)
        if not _collides_at(candidate_x):
            player_pos.x = candidate_x.x
        var candidate_y := Vector2(player_pos.x, clampf(player_pos.y + part.y, 161.0, 686.0))
        if not _collides_at(candidate_y):
            player_pos.y = candidate_y.y

func _collides_at(candidate: Vector2) -> bool:
    # Actor origin is between the boots. Broad solid building bases are
    # intentionally impassable until interiors and door triggers are designed.
    if CABIN_BLOCKER.grow(PLAYER_COLLISION_RADIUS).has_point(candidate):
        return true
    if SHED_BLOCKER.grow(PLAYER_COLLISION_RADIUS).has_point(candidate):
        return true
    for tree in trees:
        var tree_base: Vector2 = tree["pos"]
        var state: int = int(tree["state"])
        if state == 3: # small remaining stump, not a contaminated sprite.
            if candidate.distance_to(tree_base) < PLAYER_COLLISION_RADIUS + 9.0:
                return true
        elif state == 1 or state == 2:
            var species: int = int(tree["type"])
            var half_length: float = FALLEN_TRUNK_WIDTH[species] * 0.40
            if absf(candidate.x - tree_base.x) < half_length + PLAYER_COLLISION_RADIUS and absf(candidate.y - tree_base.y) < 20.0 + PLAYER_COLLISION_RADIUS:
                return true
        elif candidate.distance_to(tree_base) < PLAYER_COLLISION_RADIUS + 18.0:
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
        if tex != null:
            var size_scale: float = FALLEN_TRUNK_WIDTH[species] / float(tex.get_width())
            _anchor_at_ground(tree["sprite"], tree["pos"], tex, size_scale)
        if elapsed > 0.9:
            tree["state"] = 2
            _say("Timber! The trunk is down. BUCK it into logs.")

func _nearest_tree() -> Dictionary:
    var selected: Dictionary = {}
    var best := INTERACT_RADIUS
    for tree in trees:
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
        carried.clear()
        _say("Delivered %d full-size logs. Earned $%d." % [total, income])
        return
    var index := _nearest_log_index()
    if index >= 0 and carried.size() < LOG_CAPACITY:
        var item: Dictionary = ground_logs[index]
        var sprite: Sprite2D = item["sprite"]
        sprite.queue_free()
        carried.append(int(item["type"]))
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
    swing_kind = "chop"
    swing_clock = 0.33
    if int(tree["hp"]) <= 0:
        tree["state"] = 1
        tree["fall_time"] = 0.0
        _say("TIMBER! %s is falling." % TYPES[species].capitalize())
    else:
        _say("%s: %d more chops." % [TYPES[species].capitalize(), int(tree["hp"])])

func _buck_tree(tree: Dictionary) -> void:
    var species: int = int(tree["type"])
    tree["state"] = 3
    # The approved tree-%s-5 crop contains neighboring atlas fragments.
    # Hide the old tree entirely; display only cleaned loose-log sprites.
    var standing_sprite: Sprite2D = tree["sprite"]
    standing_sprite.visible = false
    for i in range(YIELDS[species]):
        var separation := (float(i) - float(YIELDS[species] - 1) * 0.5) * 78.0
        _spawn_log(tree["pos"] + Vector2(separation, 19.0 + float(i % 2) * 14.0), species)
    swing_kind = "buck"
    swing_clock = 0.38
    _say("Bucked %s into %d scaled logs." % [TYPES[species], YIELDS[species]])

func _spawn_log(pos: Vector2, species: int) -> void:
    var tex := load("res://assets/world/clean_logs/loose-%d.webp" % species) as Texture2D
    var sprite := Sprite2D.new()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.texture = tex
    if tex != null:
        sprite.scale = Vector2.ONE * (LOOSE_LOG_WIDTH / float(tex.get_width()))
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
    if player_pos.distance_to(YARD_POSITION) < 110.0 and not carried.is_empty():
        action_button.text = "SELL LOGS"
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
    # Simple game ground instead of a misleading painted scene containing
    # non-interactive trees, duplicate characters, buildings and lumber.
    draw_rect(Rect2(0, 0, 1280, 720), Color("#537c5b"))
    for x in range(18, 1280, 72):
        for y in range(130, 720, 66):
            var jitter := Vector2(float((x * 7 + y * 11) % 29), float((x * 11 + y * 3) % 27))
            draw_circle(Vector2(x, y) + jitter, 2.4, Color("#719266"))
            draw_circle(Vector2(x + 36, y + 24), 1.8, Color("#406c4f"))
    # An untextured compacted-earth loading pad, not a fake aerial screenshot.
    draw_circle(YARD_POSITION + Vector2(0, -13), 117.0, Color("#8e845d"))
    draw_circle(YARD_POSITION + Vector2(0, -13), 106.0, Color("#aa976d"))
    draw_string(ThemeDB.fallback_font, YARD_POSITION + Vector2(-75, -108), "LOG DROP-OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f8e8b5"))
    draw_circle(player_pos + Vector2(0.0, 3.0), 9.0, Color(0.06, 0.11, 0.07, 0.35))
    for tree in trees:
        if int(tree["state"]) == 0 and int(tree["hp"]) < int(tree["max_hp"]):
            var p: Vector2 = tree["pos"]
            var ratio := float(tree["hp"]) / float(tree["max_hp"])
            draw_rect(Rect2(p + Vector2(-24, -TREE_HEIGHT[int(tree["type"])] - 8), Vector2(48, 6)), Color("#253127"))
            draw_rect(Rect2(p + Vector2(-23, -TREE_HEIGHT[int(tree["type"])] - 7), Vector2(46.0 * ratio, 4)), Color("#e8be71"))
