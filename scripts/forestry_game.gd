extends Node2D
## First gameplay restoration milestone: approved artwork, logging, bucking, carrying, and sales.
## This keeps the existing analog joystick and logger atlas; no new art is introduced.
const ART = "res://assets/approved_sprites/crops/"
const FRAME_W = 84
const FRAME_H = 92
const PLAYER_SPEED = 225.0
const INTERACT_RADIUS = 94.0
const YARD_POSITION = Vector2(735, 465)
const LOG_CAPACITY = 4
const TYPES = ["pine", "spruce", "birch", "oak"]
const HEALTH = [2, 3, 2, 4]
const VALUES = [8, 10, 12, 14]
const YIELDS = [2, 2, 2, 3]
const SPAWNS = [
	Vector2(180, 235), Vector2(360, 280), Vector2(520, 210),
	Vector2(995, 220), Vector2(1140, 370), Vector2(1010, 495),
	Vector2(330, 535), Vector2(190, 465), Vector2(890, 565),
	Vector2(1090, 565)
]
var player_pos = Vector2(620, 430)
var facing = 4
var walking_clock = 0.0
var swing_clock = 0.0
var is_moving = false
var previous_action_down = false
var cash = 0
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
var world_time = 0.0
var message_text = "Walk to a tree and press CHOP. Cut the fallen trunk, collect the logs, sell at the yard."

func _texture(name: String) -> Texture2D:
	if not texture_cache.has(name):
		texture_cache[name] = load(ART + name + ".webp") as Texture2D
	return texture_cache[name]

func _ready() -> void:
	rendering = false
	_setup_world()
	_setup_player()
	_setup_ui()
	_update_hud()
	queue_redraw()

# Set no gameplay renderer dependencies on expensive shaders.
var rendering = false

func _setup_world() -> void:
	_make_scenery("cabin-day", Vector2(705, 238), 214.0)
	_make_scenery("shed", Vector2(832, 310), 114.0)
	_make_scenery("pile-0", YARD_POSITION + Vector2(-25, 8), 95.0)
	_make_scenery("bundle-0", YARD_POSITION + Vector2(68, 28), 70.0)
	for i in range(SPAWNS.size()):
		var species: int = i % TYPES.size()
		var tex: Texture2D = _texture("tree-%s-0" % TYPES[species])
		if tex == null:
			push_error("Approved tree texture missing for " + TYPES[species])
			continue
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = tex
		sprite.scale = Vector2.ONE * (102.0 / float(tex.get_width()))
		sprite.position = SPAWNS[i] - Vector2(0, 52)
		sprite.z_index = 2
		add_child(sprite)
		trees.append({
			"pos": SPAWNS[i],
			"type": species,
			"hp": HEALTH[species],
			"max_hp": HEALTH[species],
			"state": 0, # 0 standing, 1 falling, 2 down, 3 bucked
			"fall_time": 0.0,
			"sprite": sprite
		})

func _make_scenery(name: String, pos: Vector2, width: float) -> void:
	var tex: Texture2D = _texture(name)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = tex
	sprite.scale = Vector2.ONE * (width / float(tex.get_width()))
	sprite.position = pos
	sprite.z_index = 1
	add_child(sprite)

func _setup_player() -> void:
	var tex: Texture2D = _texture("logger-eight-way")
	if tex == null:
		push_error("Missing approved lumberjack atlas.")
		return
	logger = Sprite2D.new()
	logger.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logger.texture = tex
	logger.region_enabled = true
	logger.region_rect = Rect2(4 * FRAME_W, 4 * FRAME_H, FRAME_W, FRAME_H)
	logger.scale = Vector2(1.05, 1.05)
	logger.z_index = 4
	add_child(logger)

func _label(parent: Node, text: String, pos: Vector2, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.05, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = _label(layer, "FRONTIER MOUNTAIN", Vector2(23, 14), 26, Color("#f7e7bb"))
	instructions = _label(layer, "Move: analog / WASD / gamepad    Action: E / SPACE / gamepad A", Vector2(25, 51), 15, Color("#dfe7d4"))
	message = _label(layer, message_text, Vector2(25, 81), 16, Color("#ffe0a1"))
	joystick = preload("res://scripts/virtual_joystick.gd").new()
	joystick.position = Vector2(25, 510)
	layer.add_child(joystick)
	action_button = Button.new()
	action_button.text = "CHOP"
	action_button.position = Vector2(1060, 575)
	action_button.size = Vector2(177, 88)
	action_button.add_theme_font_size_override("font_size", 21)
	action_button.pressed.connect(_interact)
	layer.add_child(action_button)
	_label(layer, "YARD", Vector2(YARD_POSITION.x - 37, YARD_POSITION.y - 105), 22, Color("#fce1b0"))

func _process(delta: float) -> void:
	world_time += delta
	_move_player(delta)
	_animate_trees(delta)
	if logger != null:
		var row := 4
		if swing_clock > 0.0:
			swing_clock = maxf(0.0, swing_clock - delta)
			row = 5 if swing_clock > 0.16 else 6
		elif not carried.is_empty():
			row = 9 + (int(walking_clock * 1.5) % 2 if is_moving else 0)
		elif is_moving:
			row = int(walking_clock) % 4
		logger.region_rect = Rect2(facing * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
		logger.position = player_pos - Vector2(0, 31)
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
		player_pos += movement * PLAYER_SPEED * delta
		player_pos.x = clampf(player_pos.x, 50.0, 1230.0)
		player_pos.y = clampf(player_pos.y, 160.0, 670.0)
		facing = posmod(int(round((atan2(movement.y, movement.x) + PI / 2.0) / (PI / 4.0))), 8)
		walking_clock += delta * 7.0
	else:
		walking_clock = 0.0

func _animate_trees(delta: float) -> void:
	for tree in trees:
		if int(tree["state"]) != 1:
			continue
		tree["fall_time"] = float(tree["fall_time"]) + delta
		var species: int = int(tree["type"])
		var time: float = float(tree["fall_time"])
		var stage: int = mini(4, 1 + int(time / 0.19))
		var sprite: Sprite2D = tree["sprite"]
		var tex: Texture2D = _texture("tree-%s-%d" % [TYPES[species], stage])
		if tex != null:
			sprite.texture = tex
			sprite.scale = Vector2.ONE * (125.0 / float(tex.get_width()))
		if time > 0.9:
			tree["state"] = 2
			_say("Tree down. Press BUCK to cut the trunk into logs.")

func _nearest_tree() -> Dictionary:
	var nearest: Dictionary = {}
	var best := INTERACT_RADIUS
	for tree in trees:
		if int(tree["state"]) == 3:
			continue
		var distance := player_pos.distance_to(tree["pos"])
		if distance < best:
			best = distance
			nearest = tree
	return nearest

func _nearest_log_index() -> int:
	var best := INTERACT_RADIUS
	var nearest := -1
	for i in range(ground_logs.size()):
		var distance := player_pos.distance_to(ground_logs[i]["pos"])
		if distance < best:
			best = distance
			nearest = i
	return nearest

func _interact() -> void:
	if player_pos.distance_to(YARD_POSITION) < 100.0 and not carried.is_empty():
		var income := 0
		for species in carried:
			income += VALUES[species]
		var sold := carried.size()
		cash += income
		carried.clear()
		_say("Delivered %d logs. Earned $%d at the lumberyard." % [sold, income])
		return
	var log_index := _nearest_log_index()
	if log_index >= 0 and carried.size() < LOG_CAPACITY:
		var item: Dictionary = ground_logs[log_index]
		var sprite: Sprite2D = item["sprite"]
		sprite.queue_free()
		carried.append(int(item["type"]))
		ground_logs.remove_at(log_index)
		_say("Picked up a %s log (%d/%d carried)." % [TYPES[carried.back()], carried.size(), LOG_CAPACITY])
		return
	if log_index >= 0 and carried.size() >= LOG_CAPACITY:
		_say("Load full. Return to the lumberyard to sell.")
		return
	var tree := _nearest_tree()
	if tree.is_empty():
		_say("Approach a standing tree, fallen trunk, or the lumberyard.")
		return
	if int(tree["state"]) == 1:
		_say("The tree is falling. Stay clear.")
		return
	if int(tree["state"]) == 2:
		_buck_tree(tree)
		return
	var species: int = int(tree["type"])
	var target_delta: Vector2 = tree["pos"] - player_pos
	if target_delta.length() > 2.0:
		facing = posmod(int(round((atan2(target_delta.y, target_delta.x) + PI / 2.0) / (PI / 4.0))), 8)
	tree["hp"] = int(tree["hp"]) - 1
	swing_clock = 0.31
	if int(tree["hp"]) <= 0:
		tree["state"] = 1
		tree["fall_time"] = 0.0
		_say("TIMBER! %s is falling." % TYPES[species].capitalize())
	else:
		_say("Chopping %s... %d strikes left." % [TYPES[species], int(tree["hp"])])

func _buck_tree(tree: Dictionary) -> void:
	var species: int = int(tree["type"])
	tree["state"] = 3
	var stump: Sprite2D = tree["sprite"]
	var tex: Texture2D = _texture("tree-%s-5" % TYPES[species])
	if tex != null:
		stump.texture = tex
		stump.scale = Vector2.ONE * (57.0 / float(tex.get_width()))
		stump.position = tree["pos"] - Vector2(0, 5)
	for i in range(YIELDS[species]):
		var offset := Vector2((i - (YIELDS[species] - 1) * 0.5) * 27.0, 22.0 + (i % 2) * 12.0)
		_spawn_log(tree["pos"] + offset, species)
	swing_clock = 0.31
	_say("Bucked %s: %d logs ready to collect." % [TYPES[species], YIELDS[species]])

func _spawn_log(pos: Vector2, species: int) -> void:
	var sprite := Sprite2D.new()
	var tex: Texture2D = _texture("loose-%d" % species)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = tex
	if tex != null:
		sprite.scale = Vector2.ONE * (46.0 / float(tex.get_width()))
	sprite.position = pos
	sprite.z_index = 3
	add_child(sprite)
	ground_logs.append({"pos": pos, "type": species, "sprite": sprite})

func _update_hud() -> void:
	if hud == null:
		return
	hud.text = "FRONTIER MOUNTAIN   |   $%d   |   LOGS %d/%d   |   TREES %d" % [cash, carried.size(), LOG_CAPACITY, _standing_count()]
	if message.text != message_text:
		message.text = message_text
	if player_pos.distance_to(YARD_POSITION) < 100.0 and not carried.is_empty():
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
	draw_rect(Rect2(0, 0, 1280, 720), Color("#477457"))
	draw_rect(Rect2(0, 0, 1280, 118), Color("#2c4839"))
	for x in range(24, 1280, 65):
		for y in range(146, 720, 62):
			var wobble := Vector2(float((x * 17 + y * 11) % 23), float((x * 7 + y * 13) % 19))
			draw_circle(Vector2(x, y) + wobble, 2.5, Color("#648c60"))
	draw_rect(Rect2(565, 352, 282, 190), Color("#58764d"))
	draw_rect(Rect2(YARD_POSITION.x - 105, YARD_POSITION.y - 46, 202, 102), Color("#98835d"))
	draw_rect(Rect2(YARD_POSITION.x - 99, YARD_POSITION.y - 40, 190, 90), Color("#ac9467"))
	draw_string(ThemeDB.fallback_font, Vector2(YARD_POSITION.x - 83, YARD_POSITION.y - 59), "LOG DROP-OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f6e1ac"))
	for tree in trees:
		if int(tree["state"]) == 0 and int(tree["hp"]) < int(tree["max_hp"]):
			var base: Vector2 = tree["pos"]
			var fraction := float(tree["hp"]) / float(tree["max_hp"])
			draw_rect(Rect2(base + Vector2(-23, -132), Vector2(46, 6)), Color("#2c352b"))
			draw_rect(Rect2(base + Vector2(-22, -131), Vector2(44.0 * fraction, 4)), Color("#f4c675"))
	draw_circle(player_pos + Vector2(0, 6), 11.0, Color(0.08, 0.15, 0.12, 0.42))
