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
	var audio: Node = game.get_node_or_null("LegacyAudio")
	if not _check(audio != null, "Legacy audio engine instantiated"):
		quit(1)
		return
	if not _check(audio.get("samples").size() == 8, "All eight original logging effect recordings imported"):
		quit(1)
		return
	var music: AudioStreamPlayer = audio.get("music_player")
	if not _check(music != null and music.stream != null, "Original Old Growth Stillness track imported"):
		quit(1)
		return
	if not _check(game.get("fullscreen_button") != null and game.has_method("_toggle_fullscreen"), "Fullscreen button and callback available"):
		quit(1)
		return
	if not _check(game.get("music_slider") != null and game.get("effects_slider") != null, "Independent music and effect mixers available"):
		quit(1)
		return
	if not _check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Game uses fullscreen-friendly expand aspect"):
		quit(1)
		return
	if not _check(game.get("trees").size() >= 110, "Over 110 approved trees populate the larger forest"):
		quit(1)
		return
	if not _check(game.get_node_or_null("Prop_shed") != null and game.get_node_or_null("Prop_small-shed") == null, "Exactly one toolshed prop"):
		quit(1)
		return
	if not _check(game.get_node_or_null("Prop_pile-0") == null and game.get_node_or_null("Prop_bundle-0") == null, "Loading area has no decorative log props"):
		quit(1)
		return
	if not _check(game.call("_collides_at", Vector2(1510, 1030)), "Cabin footprint blocks player"):
		quit(1)
		return
	if not _check(game.call("_collides_at", Vector2(1830, 1096)), "Toolshed footprint blocks player"):
		quit(1)
		return
	if not _check(game.call("_collides_at", Vector2(1140, 1386)), "Standing tree trunk blocks player"):
		quit(1)
		return
	game.set("player_pos", Vector2(1510, 1260))
	game.call("_move_with_collisions", Vector2(0, -340))
	if not _check(game.get("player_pos").y >= 1100.0, "Swept movement cannot tunnel through cabin"):
		quit(1)
		return
	if not _check(game.get_node_or_null("ForestTerrain") != null and game.get_node_or_null("PaintedCampWorld") == null, "Procedural terrain without composite background"):
		quit(1)
		return
	var following_camera: Camera2D = game.get("camera")
	if not _check(following_camera != null and following_camera.limit_right == 3072 and following_camera.limit_bottom == 2432, "Smooth camera within 96x76 world boundaries"):
		quit(1)
		return
	if not _check(game.get("forest_chunks").size() >= 30 and game.get("streamed_active_chunks") > 0, "Spatial forest chunks generated and loaded"):
		quit(1)
		return
	if not _check(game.get("streamed_active_chunks") < game.get("forest_chunks").size(), "Offscreen forest chunks are not instantiated"):
		quit(1)
		return
	game.set("player_pos", Vector2(2840, 2060))
	game.call("_update_camera", 0.25)
	game.call("_update_visible_chunks", true)
	if not _check(following_camera.position == Vector2(2840, 2060), "Camera follows lumberjack to the eastern forest"):
		quit(1)
		return
	game.set("player_pos", Vector2(1207, 1323))
	game.call("_update_visible_chunks", true)
	var tree: Dictionary = game.get("trees")[0]
	game.set("player_pos", tree["pos"] + Vector2(15, 8))
	for i in range(int(tree["hp"])):
		game.call("_interact")
	if not _check(int(tree["state"]) == 1, "Chopping triggers falling"):
		quit(1)
		return
	game.call("_animate_trees", 1.0)
	if not _check(int(tree["state"]) == 2, "Falling animation completes"):
		quit(1)
		return
	game.call("_interact")
	if not _check(int(tree["state"]) == 3 and game.get("ground_logs").size() >= 2, "Bucking creates approved logs"):
		quit(1)
		return
	game.call("_interact")
	if not _check(game.get("carried").size() == 1, "Log pickup enters inventory"):
		quit(1)
		return
	game.set("player_pos", Vector2(1662, 1324))
	game.call("_interact")
	if not _check(game.get("carried").is_empty() and game.get("cash") > 0, "Yard unload pays species log value"):
		quit(1)
		return
	# A headless render may have no drawable framebuffer; publish only a real,
	# non-flat image captured from the game viewport.
	await process_frame
	
	var texture: ViewportTexture = root.get_texture()
	if texture != null:
		var frame_image: Image = texture.get_image()
		if frame_image != null and frame_image.get_width() >= 1280 and frame_image.get_height() >= 720:
			var top_color := frame_image.get_pixel(10, 10)
			var grass_color := frame_image.get_pixel(1200, 680)
			if (absf(top_color.r - grass_color.r) + absf(top_color.g - grass_color.g) + absf(top_color.b - grass_color.b)) > 0.04:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://web/screenshots"))
				var result := frame_image.save_png(ProjectSettings.globalize_path("res://web/screenshots/forestry.png"))
				if result == OK:
					print("SCREENSHOT: web/screenshots/forestry.png from Godot viewport")
			else:
				print("SCREENSHOT: headless viewport is flat; no image published")
	print("PASS: forestry gameplay integration complete")
	quit(0)
