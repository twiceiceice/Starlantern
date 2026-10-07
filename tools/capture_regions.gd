extends SceneTree
## Render fixtures only; never read or write the player's save.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	current_scene = game
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "meadow"
	if mode == "forest":
		game.restore_checkpoint({"career":{},"training":{},"resources":{}})
		game.player.position = Vector3(0, 0.1, 35)
	elif mode == "river":
		game.expedition.start()
		game.director.crossing_ready = true
		game.portal_unlocked = true
		game.caravan.distance = game.caravan.length() - 15
		game.player.position = Vector3(0, 0.1, 20)
	elif mode == "meadow":
		game.caravan.distance = 63
		game.player.position = RegionLayout.on_ground(RegionLayout.MEADOW, Vector3(-2, 0, 114)) + Vector3.UP * 0.1
	else:
		game.player.position = RegionLayout.START + Vector3(0, 0.1, -4)
	game.camera_rig.distance = 12.5
	game.camera_rig.pitch = -0.27 if mode != "forest" else -0.42
	game.camera_rig.position = game.player.position + Vector3.UP * 1.25
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var error := root.get_texture().get_image().save_png("res://captures/region_%s.png" % mode)
	print("REGION_CAPTURE ", mode, " ", error_string(error), " / draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0 if error == OK else 1)
