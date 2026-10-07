extends SceneTree
## Actual engine renders of imported models; no player save is read or written.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("333f46")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b7cbda")
	settings.ambient_light_energy = 0.65
	env.environment = settings
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	stage.add_child(sun)
	Geometry.box(stage, Vector3(0, -0.08, 0), Vector3(12, 0.16, 8), Color("66675e"))
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(12, 0.16, 8)
	collider.shape = floor_shape
	collider.position.y = -0.08
	floor_body.add_child(collider)
	stage.add_child(floor_body)
	await physics_frame
	await physics_frame
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "characters"
	var portraits := mode == "portraits"
	var gait := mode in ["gait", "run"]
	var roles := ["hero", "carpenter", "porter"] if mode in ["characters", "portraits"] else ["hero", "hero", "hero", "porter"]
	if gait or mode == "strikes": roles = ["hero", "hero", "hero", "hero"]
	for i in roles.size():
		var view := CharacterView.new()
		view.occupation = roles[i]
		view.coat = [Color("426475"), Color("79634a"), Color("56604c"), Color("426475")][i]
		if gait or mode == "strikes": view.coat = Color("426475")
		view.position.x = (i - (roles.size() - 1) * 0.5) * (0.78 if portraits else 1.55)
		stage.add_child(view)
		view.rotation.y = -0.22
		if gait:
			var steps: int = [10, 21, 32, 44][i]
			var speed := 7.4 if mode == "run" else 4.6
			var movement := view.global_basis.z * speed / 120.0
			view.position -= movement * steps
			view.animate(1.0 / 120.0, 0, true)
			for tick in steps:
				view.position += movement
				view.animate(1.0 / 120.0, speed, true)
		elif mode == "strikes":
			for tick in 15:
				view.animate(1.0 / 60.0, 0, true, "slash" if i < 2 else "slam", [0.17, 0.55, 0.42, 0.5][i])
		elif mode not in ["characters", "portraits"]:
			var actions := ["slash", "slam", "dodge", ""]
			for tick in 15:
				view.animate(1.0/60.0, 0, true, actions[i], 0.47 if i == 1 else 0.32, i == 3)
		else:
			for tick in 15: view.animate(1.0/60.0, 0, true)
	var camera := Camera3D.new()
	camera.position = Vector3(0.6, 2.25, 6.3 if mode == "characters" else 7.8)
	if portraits: camera.position = Vector3(0, 1.82, 2.8)
	camera.fov = 40
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.64 if portraits else 1.04, 0))
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var error := root.get_texture().get_image().save_png("res://captures/art_%s.png" % mode)
	print("ART_CAPTURE ", mode, " ", error_string(error))
	quit(0 if error == OK else 1)
