extends SceneTree
## Actual game regions and lighting. These fixtures never read/write the player's save.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "gate"
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	current_scene = game
	game.restore_checkpoint({"career":{},"training":{},"resources":{}})
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.position = Vector3(0,.05,-3)
	game.player.velocity = Vector3.ZERO
	if mode == "inside" or mode == "combat": game.player.position.z = -20
	if mode == "path": game.player.position.z = 4
	if mode == "camp": game.player.position.z = 32
	game.camera_rig.position = game.player.position+Vector3.UP*1.25
	game.camera_rig.distance = 8.2
	game.camera_rig.pitch = -.18
	if mode in ["gate","inside"]:
		game.hud.hide()
		var camera := Camera3D.new()
		game.add_child(camera)
		camera.fov = 61
		camera.position = Vector3(5.8,4.2,2.5) if mode == "gate" else Vector3(7.0,4.2,-13)
		camera.look_at(Vector3(0,3.0,-16) if mode == "gate" else Vector3(0,2.5,-27))
		camera.make_current()
		for label: Label3D in game.find_children("*","Label3D",true,false): label.hide()
	await create_timer(2.0).timeout
	if mode == "combat":
		var enemy := RuinGuardian.new()
		enemy.position = game.player.position + Vector3(-2,0,-2.5)
		enemy.target = game.player
		game.region_actors.add_child(enemy)
		enemy.begin_attack()
		enemy.set_physics_process(false)
		await create_timer(.12).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var result := root.get_texture().get_image().save_png("res://captures/forest_%s.png" % mode)
	print("FOREST_CAPTURE ",mode," ",error_string(result)," / draw calls ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0 if result == OK else 1)
