extends SceneTree
## Photographic QA of actual camp props in their gameplay regions; saves disabled.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	current_scene = game
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "overview"
	if mode == "base":
		game.restore_checkpoint({"career":{},"training":{},"resources":{}})
		game.player.position = Vector3(0,.05,8)
	else:
		game.player.position = RegionLayout.START + Vector3(0,.05,-9)
	game.hud.hide()
	var camera := Camera3D.new()
	camera.fov = 56
	game.add_child(camera)
	camera.make_current()
	var target := RegionLayout.START + Vector3(0,1,-12.5)
	match mode:
		"workshop":
			target = RegionLayout.START + CampArt.WORKSHOP + Vector3(0,1,0)
			camera.position = target + Vector3(4,2.0,5.4)
		"kitchen":
			target = RegionLayout.START + CampArt.KITCHEN + Vector3(0,1,0)
			camera.position = target + Vector3(-3.7,1.8,5.4)
		"supplies":
			target = RegionLayout.CAMP_GATE + Vector3(-1,1,-2)
			camera.position = target + Vector3(-4.7,2.0,5.7)
		"base":
			target = RegionLayout.BASE + Vector3(0,1,-2)
			camera.position = target + Vector3(17,10,-17)
		"hearth":
			target = RegionLayout.START + Vector3(0,.7,5)
			camera.position = target + Vector3(3.8,2.8,-4.5)
		_:
			camera.position = target + Vector3(12,8,14)
	camera.look_at(target)
	await create_timer(.8).timeout
	# Hide floating quest text only in this inspection fixture, like a photo mode.
	for label: Label3D in game.find_children("*","Label3D",true,false): label.hide()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var error := root.get_texture().get_image().save_png("res://captures/camp_%s.png" % mode)
	print("CAMP_CAPTURE ",mode," ",error_string(error)," / draw calls ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0 if error == OK else 1)
