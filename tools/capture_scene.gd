extends SceneTree
## A render-only QA runner. Start with --script res://tools/capture_scene.gd -- combat|menu|camp.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "camp"
	if mode != "menu":
		game.resume()
		if mode == "camp":
			var original_yaw: float = game.camera_rig.yaw
			var original_pitch: float = game.camera_rig.pitch
			var original_distance: float = game.camera_rig.distance
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(80, 20)
			Input.parse_input_event(motion)
			Input.flush_buffered_events()
			var look_ok: bool = game.camera_rig.yaw < original_yaw - 0.2 and game.camera_rig.pitch < original_pitch - 0.04
			var scroll := InputEventMouseButton.new()
			scroll.button_index = MOUSE_BUTTON_WHEEL_UP
			scroll.pressed = true
			Input.parse_input_event(scroll)
			Input.flush_buffered_events()
			var zoom_ok: bool = game.camera_rig.distance < original_distance
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			game.camera_rig.yaw = original_yaw
			game.camera_rig.pitch = original_pitch
			game.camera_rig.distance = original_distance
			print("NATIVE_INPUT: look=%s zoom=%s" % [look_ok, zoom_ok])
			if not look_ok or not zoom_ok:
				push_error("Native camera input check failed")
				quit(1)
				return
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mode == "combat":
		game.interact()
		game.player.position = Vector3(-3, 0.05, -13)
		game.camera_rig.position = game.player.position + Vector3(0, 1.25, 0)
		await create_timer(0.25).timeout
		var enemy: RuinGuardian = get_nodes_in_group("enemies")[0]
		enemy.clear_marker()
		enemy.begin_attack()
		game.hud.notify("붉은 원이 터지기 전에 Ctrl로 회피하세요.")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var error := root.get_texture().get_image().save_png("res://captures/%s.png" % mode)
	print("CAPTURE_%s: %s" % [mode, error_string(error)])
	quit(0 if error == OK else 1)
