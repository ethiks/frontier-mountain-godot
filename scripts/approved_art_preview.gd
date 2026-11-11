extends Node2D
# Approved v0.6.2a sprite animation preview. This is NOT the gameplay parity build.
const TILE_W := 84
const TILE_H := 92
const DIRECTIONS := 8
const WALK_ROWS := 4
const WALK_FPS := 7.0
const SPEED := 235.0
var facing := 4
var moving := false
var elapsed := 0.0
var player_position := Vector2(640, 365)
var joystick
var logger: Sprite2D
var status: Label
var walk_cycle := 0.0

func _ready() -> void:
    var tex := load("res://assets/approved_sprites/crops/logger-eight-way.webp") as Texture2D
    if tex == null:
        push_error("Missing approved logger-eight-way.webp; run scripts/import_approved_art.sh before Godot import.")
        return
    logger = Sprite2D.new()
    logger.texture = tex
    logger.region_enabled = true
    logger.region_rect = Rect2(4 * TILE_W, 4 * TILE_H, TILE_W, TILE_H)
    logger.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    logger.scale = Vector2(1.15, 1.15)
    add_child(logger)
    var ui := CanvasLayer.new()
    add_child(ui)
    joystick = preload("res://scripts/virtual_joystick.gd").new()
    joystick.position = Vector2(28, 505)
    ui.add_child(joystick)
    status = Label.new()
    status.position = Vector2(24, 20)
    status.add_theme_font_size_override("font_size", 23)
    ui.add_child(status)
    var hint := Label.new()
    hint.text = "APPROVED ART PREVIEW  |  Analog joystick / WASD / controller left stick"
    hint.position = Vector2(24, 55)
    ui.add_child(hint)
    var chop := Button.new()
    chop.text = "CHOP"
    chop.position = Vector2(1060, 565)
    chop.size = Vector2(150, 80)
    chop.button_down.connect(func(): _chop())
    ui.add_child(chop)

func _process(delta: float) -> void:
    if logger == null:
        return
    var movement := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1.0
    if Input.get_connected_joypads().size() > 0:
        movement += Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
    if joystick != null:
        movement += joystick.vector
    movement = movement.limit_length(1.0)
    moving = movement.length() > 0.12
    if moving:
        player_position += movement * SPEED * delta
        player_position.x = clampf(player_position.x, 70.0, 1210.0)
        player_position.y = clampf(player_position.y, 140.0, 640.0)
        facing = posmod(int(round((atan2(movement.y, movement.x) + PI / 2.0) / (PI / 4.0))), 8)
        walk_cycle += delta * WALK_FPS
    else:
        walk_cycle = 0.0
    var row := (int(walk_cycle) % WALK_ROWS) if moving else 4
    logger.region_rect = Rect2(facing * TILE_W, row * TILE_H, TILE_W, TILE_H)
    logger.position = player_position - Vector2(0, 30)
    status.text = "Frontier Mountain | Approved 8-way sprite | Facing: " + ["N","NE","E","SE","S","SW","W","NW"][facing]
    queue_redraw()

func _chop() -> void:
    # Action frame mapping follows the approved v0.6.2a source.
    if logger != null:
        logger.region_rect = Rect2(facing * TILE_W, 5 * TILE_H, TILE_W, TILE_H)

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("#4b7457"))
    for x in range(0, 1280, 64):
        for y in range(100, 720, 64):
            draw_circle(Vector2(x + 15, y + 18), 2.0, Color("#678969"))
    draw_line(Vector2(0, 104), Vector2(1280, 104), Color("#2e4b3e"), 3.0)
