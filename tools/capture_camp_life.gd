extends SceneTree
## Native render of the live work loop; no real save is read or written.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "workshop"
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	current_scene = game
	game.restore_checkpoint({"career":{},"training":{},"resources":{}})
	game.production.restore({"started":true})
	game._sync_camp_life()
	game.production.changed.emit()
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.position = Vector3(0,.05,12)
	var focus: CampResident = game.camp_life.residents[0 if mode == "workshop" else 1]
	var seen := false
	for tick in 6600:
		await physics_frame
		# Native focus loss normally pauses the game; this fixture must keep running.
		if paused:
			game.resume()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var job: Dictionary = game.production.jobs[focus.role]
		if mode == "overview": seen = game.production.shipments == 2 and game.production.cooked == 3
		else: seen = not job.is_empty() and job.phase == "working" and float(job.progress) > 1.1
		if seen: break
		if tick%1200 == 0: print("CAMP_PROGRESS ",game.production.to_data())
	if not seen:
		push_error("Camp residents did not reach expected state: "+str(game.production.to_data()))
		for resident in game.camp_life.residents:
			print(resident.role," at ",resident.position," destination ",resident.target," path ",resident.agent.get_current_navigation_path())
			for i in resident.get_slide_collision_count():
				var hit: KinematicCollision3D = resident.get_slide_collision(i)
				print("COLLISION ",hit.get_collider().get_path()," at ",hit.get_position()," normal ",hit.get_normal())
		quit(1)
		return
	if mode != "overview":
		game.hud.hide()
		for label: Label3D in game.find_children("*","Label3D",true,false): label.hide()
		var camera := Camera3D.new()
		game.add_child(camera)
		camera.fov = 57
		camera.position = Vector3(-2.7,2.5,9.8) if mode == "workshop" else Vector3(2.8,2.5,10.5)
		camera.look_at(focus.position+Vector3(0,.95,-.6))
		camera.make_current()
	else:
		game.player.position = Vector3(0,.05,12)
		game.camera_rig.position = game.player.position+Vector3.UP*1.25
		game.camera_rig.distance = 8.2
		game.camera_rig.pitch = -.26
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var error := root.get_texture().get_image().save_png("res://captures/camp_life_%s.png"%mode)
	print("CAMP_LIFE_CAPTURE ",mode," ",error_string(error)," ",game.production.to_data())
	quit(0 if error == OK else 1)
