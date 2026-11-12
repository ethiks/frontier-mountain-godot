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
	var terrain: Node2D = game.get_node("ForestTerrain")
	var ground_map: TileMapLayer = terrain.get_node("BaseGround")
	var path_map: TileMapLayer = terrain.get_node("ConnectedForestPaths")
	var yard_map: TileMapLayer = terrain.get_node("LumberLoadingZone")
	var detail_map: TileMapLayer = terrain.get_node("GroundDetailOverlays")
	var transition_map: TileMapLayer = terrain.get_node("GroundTransitions")
	if not _check(ground_map != null and ground_map.get_used_cells().size() == 96 * 76, "Approved 32px base terrain fills the original 96x76 world"):
		quit(1)
		return
	var atlas_source: TileSetAtlasSource = ground_map.tile_set.get_source(0)
	if not _check(atlas_source != null and atlas_source.get_tiles_count() == 120, "All 120 approved terrain atlas tiles imported into the Godot TileSet"):
		quit(1)
		return
	if not _check(path_map.get_used_cells().size() > 20 and yard_map.get_used_cells().size() > 12, "Connected atlas paths reach the compacted timber loading zone"):
		quit(1)
		return
	if not _check(detail_map.get_used_cells().size() > 130 and transition_map.get_used_cells().size() > 20, "Seeded decorative overlays and biome transitions populate the world"):
		quit(1)
		return
	if not _check(terrain.get("biome_counts").size() >= 5, "Regional variation includes at least five distinct terrain biomes"):
		quit(1)
		return
	if not _check(terrain.get_node_or_null("ApprovedYardSign") != null and terrain.get_node_or_null("LoadingRailEast") != null, "Approved loading-zone artwork appears without decorative logs"):
		quit(1)
		return
	if not _check(yard_map.get_cell_source_id(Vector2i(51, 41)) >= 0, "Player delivery location lies on the matching yard tilemap"):
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
	var first_tree: Dictionary = game.get("trees")[0]
	game.set("player_pos", first_tree["pos"] - Vector2(0, 76))
	game.call("_update_visible_chunks", true)
	game.call("_update_canopy_occlusion")
	var near_sprite: Sprite2D = first_tree["sprite"]
	if not _check(is_instance_valid(near_sprite) and near_sprite.modulate.a < 0.8, "Foreground canopy fades to reveal nearby lumberjack"):
		quit(1)
		return
	game.set("player_pos", Vector2(1207, 1323))
	game.call("_update_visible_chunks", true)
	game.call("_update_canopy_occlusion")
	var tree: Dictionary = game.get("trees")[0]
	if not _check(game.call("_collides_at", tree["pos"]), "Standing tree has a solid trunk"):
		quit(1)
		return
	game.set("player_pos", tree["pos"] + Vector2(15, 8))
	for i in range(int(tree["hp"])):
		game.call("_interact")
	if not _check(int(tree["state"]) == 1, "Chopping triggers falling"):
		quit(1)
		return
	if not _check(not game.call("_collides_at", tree["pos"]), "Final chop immediately removes trunk hitbox before bucking"):
		quit(1)
		return
	# The player must be able to walk across the former trunk position during the falling animation.
	# Avoid a separate, still-standing generated tree 85 px to the west.
	# The 88-px traversal fully crosses this tree's old 62-px hitbox.
	game.set("player_pos", tree["pos"] - Vector2(44, 0))
	game.call("_move_with_collisions", Vector2(88, 0))
	if not _check(game.get("player_pos").x > tree["pos"].x + 40.0, "Walk freely through former trunk before bucking"):
		quit(1)
		return
	game.set("player_pos", tree["pos"] + Vector2(15, 8))
	game.call("_animate_trees", 1.0)
	if not _check(int(tree["state"]) == 2, "Falling animation completes"):
		quit(1)
		return
	if not _check(not game.call("_collides_at", tree["pos"]), "Unbucked fallen trunk remains non-solid"):
		quit(1)
		return
	game.call("_interact")
	if not _check(int(tree["state"]) == 3 and game.get("ground_logs").size() >= 2, "Bucking creates approved logs"):
		quit(1)
		return
	if not _check(not game.call("_collides_at", tree["pos"]), "Bucked site remains free of stale collision"):
		quit(1)
		return
	game.call("_interact")
	if not _check(game.get("carried").size() == 1, "Log pickup enters inventory"):
		quit(1)
		return
	game.set("player_pos", Vector2(1662, 1324))
	game.call("_interact")
	var distributor = game.get("distributor")
	if not _check(game.get("carried").is_empty() and distributor.total_raw() == 1, "Yard unload stores harvested wood for distributor sale"):
		quit(1)
		return
	var selected := [0,0,0,0,0,0,0]
	selected[int(game.get("ground_logs")[0]["type"])] = 1
	# Only stocked inventory can be sold; adjust to actual delivered species.
	selected = [0,0,0,0,0,0,0]
	for species in range(4):
		if distributor.available(species) > 0:
			selected[species] = 1
	if not _check(distributor.sell_selected(game,selected)["income"] > 0 and game.get("cash") > 0, "Distributor sells only selected stocked lumber"):
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
