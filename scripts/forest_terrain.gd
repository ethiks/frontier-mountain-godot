extends Node2D
## Procedural, editable 96x76-tile forest floor. No flattened illustration or
## new sprite art; uses geometry and approved per-object sprites.
const WORLD_TILES := Vector2i(96, 76)
const TILE_SIZE := 32.0
const WORLD_SIZE := Vector2(3072.0, 2432.0)
const CHUNK_SIZE := 384.0
const HOMESTEAD := Vector2(860.0, 760.0)
const HOME_CENTER := HOMESTEAD + Vector2(660.0, 450.0)
const YARD := HOMESTEAD + Vector2(802.0, 564.0)
const TREE_DENSITY := 0.88

var view_center := HOMESTEAD + Vector2(590.0, 355.0)
var view_size := Vector2(1280.0, 720.0)

static func hash01(ix: int, iy: int, salt: int) -> float:
	var raw: int = posmod(ix * 73856093 + iy * 19349663 + salt * 83492791, 99991)
	return float(raw) / 99991.0

static func chunk_for(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CHUNK_SIZE)), int(floor(pos.y / CHUNK_SIZE)))

func generate_forest_positions() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	# A fixed seed makes the approved forest repeatable between builds.
	# Cells preserve usable clearance between trunk collision circles.
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
				continue # the original cabin and yard remain a navigable clearing
			var species := posmod(gx * 3 + gy * 7, 4)
			entries.append({"pos": p, "type": species})
	return entries

func update_view(camera_center: Vector2, current_size: Vector2) -> void:
	view_center = camera_center
	view_size = current_size
	queue_redraw()

func _draw() -> void:
	# Ground is drawn entirely with Godot primitives; no approved art is altered.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#517b58"))
	# The homestead is a subtle grass variation, not a giant circular decal.
	draw_circle(HOME_CENTER, 423.0, Color("#5a8056"))
	_draw_path(HOMESTEAD + Vector2(705.0, 355.0), YARD + Vector2(-12.0, -18.0), 33.0)
	_draw_path(HOMESTEAD + Vector2(940.0, 390.0), YARD + Vector2(45.0, -15.0), 27.0)
	_draw_path(YARD + Vector2(-8.0, 15.0), HOME_CENTER + Vector2(-230.0, 360.0), 35.0)
	_draw_earth_pad(YARD + Vector2(0.0, -11.0), 90.0)
	# Draw detail only around the camera. On large worlds this prevents
	# geometry work scaling with world area.
	var margin := Vector2(185.0, 185.0)
	var min_pos := (view_center - view_size * 0.5 - margin).max(Vector2.ZERO)
	var max_pos := (view_center + view_size * 0.5 + margin).min(WORLD_SIZE)
	var x0 := maxi(0, int(floor(min_pos.x / 44.0)))
	var y0 := maxi(0, int(floor(min_pos.y / 44.0)))
	var x1 := int(ceil(max_pos.x / 44.0))
	var y1 := int(ceil(max_pos.y / 44.0))
	for gy in range(y0, y1):
		for gx in range(x0, x1):
			var speckle := Vector2(float(gx) * 44.0, float(gy) * 44.0)
			speckle += Vector2(hash01(gx, gy, 3) * 34.0, hash01(gx, gy, 5) * 31.0)
			if speckle.distance_to(YARD) < 93.0:
				continue
			var tone := hash01(gx, gy, 6)
			if tone < 0.28:
				draw_circle(speckle, 1.5, Color("#355c48"))
			elif tone < 0.73:
				draw_line(speckle + Vector2(-3.0, 3.0), speckle + Vector2(0.0, -5.0), Color("#81a26b"), 1.5)
				draw_line(speckle + Vector2(0.0, 3.0), speckle + Vector2(3.0, -3.0), Color("#779b65"), 1.5)
			else:
				draw_circle(speckle, 2.0, Color("#97a577"))
	# Boundary posts remain simple geometry until an approved fence pack exists.
	draw_rect(Rect2(12.0, 12.0, WORLD_SIZE.x - 24.0, WORLD_SIZE.y - 24.0), Color("#a39169"), false, 8.0)
	draw_string(ThemeDB.fallback_font, YARD + Vector2(-67, -94), "LOG DROP-OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f8e8b5"))

func _draw_earth_pad(center: Vector2, radius: float) -> void:
	# Irregular edge, drawn as geometry rather than a flattened background.
	var edge := PackedVector2Array()
	var middle := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		var wave := hash01(i, 19, 27)
		var unit := Vector2(cos(angle), sin(angle))
		edge.append(center + unit * radius * (0.91 + wave * 0.17))
		middle.append(center + unit * radius * (0.82 + wave * 0.14))
	draw_colored_polygon(edge, Color("#7e7955"))
	draw_colored_polygon(middle, Color("#a9956e"))
	for i in range(18):
		var theta := TAU * hash01(i, 17, 22)
		var distance := radius * sqrt(hash01(i, 13, 4)) * 0.72
		var dot := center + Vector2(cos(theta), sin(theta)) * distance
		draw_circle(dot, 2.0 + hash01(i, 19, 8) * 2.0, Color("#c0aa81"))

func _draw_path(start: Vector2, finish: Vector2, width: float) -> void:
	# Narrow, gently meandering earth trail with scalloped edges.
	var previous := start
	for i in range(1, 8):
		var fraction := float(i) / 7.0
		var point := start.lerp(finish, fraction)
		var turn := Vector2(sin(fraction * PI) * 17.0, sin(fraction * TAU) * 9.0)
		point += turn
		draw_line(previous, point, Color("#7f7656"), width + 5.0, true)
		draw_line(previous, point, Color("#a18f68"), width, true)
		draw_circle(previous, width * 0.5, Color("#a18f68"))
		previous = point
	draw_circle(finish, width * 0.5, Color("#a18f68"))
