extends Node2D
const SPEED = 225.0
const TARGET = 5
var player = Vector2(640, 390)
var facing = Vector2.DOWN
var trees = []
var logs = []
var collected = 0
var win = false
var paused = false
var message = "Move to a tree and press Space / A to chop."
var held = {}
var action_pending = false
var reset_pending = false
var pause_pending = false
var hud: Label
var info: Label
func _ready():
    reset()
    var ui = CanvasLayer.new()
    add_child(ui)
    hud = Label.new()
    hud.position = Vector2(24, 16)
    hud.add_theme_font_size_override("font_size", 28)
    ui.add_child(hud)
    info = Label.new()
    info.position = Vector2(24, 58)
    info.add_theme_font_size_override("font_size", 19)
    ui.add_child(info)
    add_button(ui, "◀", Vector2(25, 585), Vector2.LEFT)
    add_button(ui, "▶", Vector2(165, 585), Vector2.RIGHT)
    add_button(ui, "▲", Vector2(95, 515), Vector2.UP)
    add_button(ui, "▼", Vector2(95, 650), Vector2.DOWN)
    add_button(ui, "CHOP / PICK", Vector2(1030, 585), Vector2.ZERO)
    add_button(ui, "RESTART", Vector2(1030, 650), Vector2.ZERO)
    add_button(ui, "PAUSE", Vector2(1090, 15), Vector2.ZERO)
func add_button(ui, label_text, pos, direction):
    var b = Button.new()
    b.text = label_text
    b.position = pos
    b.size = Vector2(150, 54) if direction == Vector2.ZERO else Vector2(65, 60)
    b.button_down.connect(func():
        if direction != Vector2.ZERO: held[label_text] = direction
        elif label_text == "CHOP / PICK": action_pending = true
        elif label_text == "RESTART": reset_pending = true
        else: pause_pending = true
    )
    b.button_up.connect(func(): held.erase(label_text))
    ui.add_child(b)
func reset():
    player = Vector2(640, 390)
    facing = Vector2.DOWN
    trees = []
    for p in [Vector2(250,230), Vector2(450,190), Vector2(720,210), Vector2(960,260), Vector2(1040,460), Vector2(380,530), Vector2(800,560)]:
        trees.append({"pos":p, "state":0, "timer":0.0, "side":1.0})
    logs = []
    collected = 0
    win = false
    paused = false
    message = "Move to a tree and press Space / A to chop."
    queue_redraw()
func _process(delta):
    if Input.is_key_pressed(KEY_R) or Input.is_joy_button_pressed(0, JOY_BUTTON_Y) or reset_pending:
        reset_pending = false
        reset()
    if Input.is_key_pressed(KEY_P) and not Input.is_key_pressed(KEY_SPACE) and not paused:
        paused = true
    if pause_pending:
        paused = not paused
        pause_pending = false
    if paused:
        message = "Paused. Tap PAUSE to resume."
    else:
        var movement = Vector2.ZERO
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1
        if Input.get_connected_joypads().size() > 0:
            movement += Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
        for d in held.values(): movement += d
        movement = movement.limit_length(1.0)
        if not win and movement.length() > 0.15:
            facing = movement.normalized()
            player += facing * SPEED * delta
            player.x = clampf(player.x, 25, 1255)
            player.y = clampf(player.y, 115, 685)
        for tree in trees:
            if tree.state == 1:
                tree.timer += delta
                if tree.timer > 0.65:
                    tree.state = 2
                    logs.append(tree.pos + Vector2(20, 18))
        if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E) or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or action_pending) and not win:
            interact()
    action_pending = false
    hud.text = "FRONTIER MOUNTAIN  |  LOGS %d / %d" % [collected, TARGET]
    info.text = message
    queue_redraw()
func interact():
    for i in range(logs.size()):
        if player.distance_to(logs[i]) < 85:
            logs.remove_at(i)
            collected += 1
            message = "Log collected!"
            if collected >= TARGET:
                win = true
                message = "SUCCESS! Five logs collected. Press R / Y to restart."
            return
    for tree in trees:
        if tree.state == 0 and player.distance_to(tree.pos) < 85:
            tree.state = 1
            tree.timer = 0.0
            tree.side = -1.0 if player.x < tree.pos.x else 1.0
            message = "Timber! Pick up the fallen log."
            return
    message = "Move closer to a tree or log."
func _draw():
    draw_rect(Rect2(0, 0, 1280, 720), Color("668c61"))
    for x in range(0, 1280, 80):
        for y in range(110, 720, 80):
            draw_circle(Vector2(x+25,y+30), 2, Color("83a376"))
    draw_rect(Rect2(565,305,135,78), Color("a17a50"))
    draw_colored_polygon(PackedVector2Array([Vector2(550,305),Vector2(632,250),Vector2(715,305)]), Color("594c40"))
    for tree in trees:
        var p = tree.pos
        if tree.state == 2:
            draw_circle(p, 12, Color("79543a"))
            continue
        var angle = 0.0
        if tree.state == 1: angle = tree.side * minf(1.0, tree.timer / 0.65) * 1.35
        var top = p + Vector2(sin(angle)*70, -cos(angle)*70)
        draw_line(p, top, Color("60402a"), 15)
        draw_circle(top, 29, Color("285d3a"))
        draw_circle(top + Vector2(-11,-8), 19, Color("387749"))
    for p in logs:
        draw_line(p+Vector2(-18,0), p+Vector2(18,0), Color("805436"), 17)
        draw_circle(p+Vector2(18,0), 8, Color("c49b66"))
    draw_circle(player+Vector2(4,9), 17, Color(0.12,0.18,0.12,0.35))
    draw_circle(player, 17, Color("d7b17a"))
    draw_circle(player+facing*11, 6, Color("34495b"))
    draw_line(player, player+facing*23, Color("e8e1c4"), 3)
