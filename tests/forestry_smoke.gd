extends SceneTree
## Headless integration test for Frontier Mountain's first forestry loop.
func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> bool:
	if ok:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
	return ok

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if not _check(packed != null, "Load main scene"):
		quit(1)
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	if not _check(game.trees.size() >= 8, "Approved trees spawned"):
		quit(1)
		return
	var tree: Dictionary = game.trees[0]
	game.player_pos = tree["pos"] + Vector2(15, 8)
	for i in range(int(tree["hp"])):
		game._interact()
	if not _check(int(tree["state"]) == 1, "Chopping triggers falling"):
		quit(1)
		return
	game._animate_trees(1.0)
	if not _check(int(tree["state"]) == 2, "Falling animation completes"):
		quit(1)
		return
	game._interact()
	if not _check(int(tree["state"]) == 3 and game.ground_logs.size() >= 2, "Bucking creates approved logs"):
		quit(1)
		return
	game._interact()
	if not _check(game.carried.size() == 1, "Log pickup enters inventory"):
		quit(1)
		return
	game.player_pos = game.YARD_POSITION
	game._interact()
	if not _check(game.carried.is_empty() and game.cash > 0, "Yard unload pays species log value"):
		quit(1)
		return
	# A headless render may have no drawable framebuffer; publish only a real,
	# non-flat image captured from the game viewport.
	await process_frame
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = root.get_texture()
	if texture != null:
		var frame_image: Image = texture.get_image()
		if frame_image != null and frame_image.get_width() >= 1280 and frame_image.get_height() >= 720:
			var top_color := frame_image.get_pixel(10, 10)
			var grass_color := frame_image.get_pixel(1200, 680)
			if top_color.distance_to(grass_color) > 0.04:
				DirAccess.make_dir_recursive_absolute("res://web/screenshots")
				var result := frame_image.save_png("res://web/screenshots/forestry.png")
				if result == OK:
					print("SCREENSHOT: web/screenshots/forestry.png from Godot viewport")
			else:
				print("SCREENSHOT: headless viewport is flat; no image published")
	print("PASS: forestry gameplay integration complete")
	quit(0)
