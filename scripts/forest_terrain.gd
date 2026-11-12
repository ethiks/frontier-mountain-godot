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

# These details are native Godot drawing primitives: no new sprite asset is
# introduced, so the five user-approved sprite sheets remain the only art pack.
# The landing and paths deliberately share an 8-bit earthy pixel palette.
const GROUND_PIXEL := 12.0
const COLOUR_GRASS := Color("#4d7653")
const COLOUR_CLEARING := Color("#5b8058")
const COLOUR_CLEARING_LIGHT := Color("#62855e")
const COLOUR_PATH_EDGE := Color("#766e50")
const COLOUR_PATH := Color("#a58c63")
const COLOUR_PATH_LIGHT := Color("#b69b70")
const COLOUR_GRAVEL := Color("#d3b889")
const COLOUR_SHADE := Color("#746548")

func update_view(camera_center: Vector2, current_size: Vector2) -> void:
	# Terrain is drawn in world coordinates. Moving the camera alone does not
	# require rebuilding thousands of tiny tiles every frame.
	if view_center.distance_to(camera_center) < 58.0 and view_size == current_size:
		return
	view_center = camera_center
	view_size = current_size
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), COLOUR_GRASS)

	# Viewport-cull pixel blocks, with an ample margin for the camera offset.
	var margin := Vector2(310.0, 330.0)
	var min_world := (view_center - view_size * 0.5 - margin).max(Vector2.ZERO)
	var max_world := (view_center + view_size * 0.5 + margin).min(WORLD_SIZE)
	var x0 := maxi(0, int(floor(min_world.x / GROUND_PIXEL)))
	var y0 := maxi(0, int(floor(min_world.y / GROUND_PIXEL)))
	var x1 := mini(int(ceil(WORLD_SIZE.x / GROUND_PIXEL)), int(ceil(max_world.x / GROUND_PIXEL)))
	var y1 := mini(int(ceil(WORLD_SIZE.y / GROUND_PIXEL)), int(ceil(max_world.y / GROUND_PIXEL)))

	for cy in range(y0, y1):
		for cx in range(x0, x1):
			var center := Vector2((float(cx) + 0.5) * GROUND_PIXEL, (float(cy) + 0.5) * GROUND_PIXEL)
			var box := Rect2(Vector2(cx, cy) * GROUND_PIXEL, Vector2.ONE * GROUND_PIXEL)
			var style := _surface_type(center, cx, cy)
			var noise := hash01(cx, cy, 17)
			if style == 0:
				var clearing_distance := center.distance_to(HOME_CENTER)
				if clearing_distance < 419.0 + (noise - 0.5) * 20.0:
					draw_rect(box, COLOUR_CLEARING_LIGHT if noise > 0.81 else COLOUR_CLEARING)
				elif noise < 0.085:
					draw_rect(box, Color("#527c55"))
				if noise > 0.85:
					_draw_grass_tuft(center, noise)
			elif style == 1:
				# Jagged, darker dirt shoulder.
				draw_rect(box, COLOUR_PATH_EDGE if noise < 0.63 else Color("#877859"))
			elif style == 2:
				draw_rect(box, COLOUR_PATH_LIGHT if noise > 0.72 else COLOUR_PATH)
				if noise < 0.115:
					draw_rect(Rect2(box.position + Vector2(3, 4), Vector2(4, 3)), COLOUR_GRAVEL)
				elif noise > 0.91:
					draw_rect(Rect2(box.position + Vector2(2, 8), Vector2(5, 2)), COLOUR_SHADE)
			elif style == 3:
				# Same path-edge colour as the road: one material throughout.
				draw_rect(box, COLOUR_PATH_EDGE if noise < 0.72 else Color("#887a59"))
			else:
				draw_rect(box, COLOUR_PATH if noise < 0.66 else COLOUR_PATH_LIGHT)
				if noise > 0.72:
					draw_rect(Rect2(box.position + Vector2(3, 4), Vector2(3, 3)), COLOUR_GRAVEL)
				elif noise < 0.10:
					draw_rect(Rect2(box.position + Vector2(7, 7), Vector2(4, 2)), COLOUR_SHADE)

	# The receiving zone is deliberately EMPTY: no log piles or lumber sprites.
	_draw_loading_zone()
	# A strong but simple visible edge for the forest map.
	draw_rect(Rect2(12.0, 12.0, WORLD_SIZE.x - 24.0, WORLD_SIZE.y - 24.0), Color("#8e7955"), false, 8.0)

func _surface_type(pos: Vector2, cx: int, cy: int) -> int:
	# 0 grass, 1 trail shoulder, 2 trail interior,
	# 3 landing shoulder, 4 landing interior.
	var jitter := (hash01(cx, cy, 51) - 0.5) * 11.0
	var pad_center := YARD + Vector2(0.0, -11.0)
	var delta := (pos - pad_center).abs()
	var pad_metric := maxf(maxf(delta.x - 98.0, delta.y - 70.0), (delta.x + delta.y - 142.0) * 0.72)
	if pad_metric < -7.0 + jitter:
		return 4
	if pad_metric < 7.0 + jitter:
		return 3

	var distance := _path_distance(pos)
	if distance < 22.0 + jitter:
		return 2
	if distance < 31.0 + jitter:
		return 1
	return 0

func _path_distance(point: Vector2) -> float:
	# Winding pixel roads connect the approved cabin, single toolshed and
	# landing zone, and continue toward the surrounding forest.
	var cabin := HOMESTEAD + Vector2(705.0, 356.0)
	var toolshed := HOMESTEAD + Vector2(940.0, 389.0)
	var landing := YARD + Vector2(0.0, -12.0)
	var south_west := HOME_CENTER + Vector2(-232.0, 385.0)
	var d := _segment_distance(point, cabin, cabin + Vector2(-16.0, 75.0))
	d = minf(d, _segment_distance(point, cabin + Vector2(-16.0, 75.0), landing + Vector2(-37.0, -64.0)))
	d = minf(d, _segment_distance(point, landing + Vector2(-37.0, -64.0), landing))
	d = minf(d, _segment_distance(point, toolshed, toolshed + Vector2(-44.0, 66.0)))
	d = minf(d, _segment_distance(point, toolshed + Vector2(-44.0, 66.0), landing + Vector2(34.0, -44.0)))
	d = minf(d, _segment_distance(point, landing + Vector2(34.0, -44.0), landing))
	d = minf(d, _segment_distance(point, landing, landing + Vector2(-54.0, 67.0)))
	d = minf(d, _segment_distance(point, landing + Vector2(-54.0, 67.0), south_west))
	return d

func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var line := b - a
	var length_sq := line.length_squared()
	if length_sq <= 0.001:
		return point.distance_to(a)
	var fraction := clampf((point - a).dot(line) / length_sq, 0.0, 1.0)
	return point.distance_to(a + line * fraction)

func _draw_grass_tuft(center: Vector2, noise: float) -> void:
	# Small, square-edged pixel blades rather than vector curves.
	var p := (center / 3.0).floor() * 3.0
	var colour := Color("#8da16e") if noise > 0.94 else Color("#729363")
	draw_rect(Rect2(p + Vector2(-3.0, -3.0), Vector2(3.0, 9.0)), colour)
	draw_rect(Rect2(p + Vector2(3.0, 0.0), Vector2(3.0, 6.0)), colour)

func _draw_loading_zone() -> void:
	# Pixel-blocked timber-yard receiving bay: an empty surface, a small
	# wooden boundary and an in-world sign, not an oversized tan oval.
	var center := YARD + Vector2(0.0, -11.0)
	# Short wood edging (not collectible log art or decorative log piles).
	var left := center + Vector2(-83.0, -50.0)
	var right := center + Vector2(82.0, -50.0)
	draw_rect(Rect2(left, Vector2(12, 105)), Color("#543f30"))
	draw_rect(Rect2(left + Vector2(3, 0), Vector2(5, 103)), Color("#9d754b"))
	draw_rect(Rect2(right, Vector2(12, 105)), Color("#543f30"))
	draw_rect(Rect2(right + Vector2(3, 0), Vector2(5, 103)), Color("#a47d52"))
	# Four inset corner marks clearly identify where carried logs are sold.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := center + Vector2(sx * 57.0, sy * 41.0)
			draw_rect(Rect2(p, Vector2(12, 5)), Color("#e1c68b"))
	# Signboard fixed behind the pad; no collision or new sprite required.
	var sign_origin := center + Vector2(-79.0, -105.0)
	draw_rect(Rect2(sign_origin + Vector2(-4, -4), Vector2(165, 36)), Color("#423629"))
	draw_rect(Rect2(sign_origin, Vector2(157, 28)), Color("#926943"))
	draw_rect(Rect2(sign_origin + Vector2(3, 3), Vector2(151, 5)), Color("#bb8854"))
	draw_string(ThemeDB.fallback_font, sign_origin + Vector2(10, 22), "LOG DROP-OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f6dfad"))
