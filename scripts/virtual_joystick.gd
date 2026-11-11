extends Control
const RADIUS := 62.0
const DEADZONE := 0.12
var vector := Vector2.ZERO
var touch_id := -1
var mouse_held := false
func _ready() -> void:
    size = Vector2(180, 180)
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()
func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_id == -1:
            touch_id = event.index
            _move_knob(event.position)
            accept_event()
        elif not event.pressed and event.index == touch_id:
            touch_id = -1
            vector = Vector2.ZERO
            queue_redraw()
            accept_event()
    elif event is InputEventScreenDrag and event.index == touch_id:
        _move_knob(event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        mouse_held = event.pressed
        if mouse_held:
            _move_knob(event.position)
        else:
            vector = Vector2.ZERO
            queue_redraw()
        accept_event()
    elif event is InputEventMouseMotion and mouse_held:
        _move_knob(event.position)
        accept_event()
func _move_knob(pos: Vector2) -> void:
    var offset := (pos - size * 0.5) / RADIUS
    vector = offset.limit_length(1.0)
    if vector.length() < DEADZONE:
        vector = Vector2.ZERO
    queue_redraw()
func _draw() -> void:
    var c := size * 0.5
    draw_circle(c, 78.0, Color(0.10, 0.16, 0.17, 0.42))
    draw_arc(c, 78.0, 0.0, TAU, 64, Color(0.83, 0.88, 0.83, 0.5), 2.0)
    draw_circle(c + vector * RADIUS, 29.0, Color(0.35, 0.49, 0.50, 0.95))
    draw_arc(c + vector * RADIUS, 29.0, 0.0, TAU, 48, Color(0.9, 0.95, 0.89), 2.0)
