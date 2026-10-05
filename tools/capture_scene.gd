extends SceneTree
## Render-only QA fixtures; never used by normal launches.
## Start with --script res://tools/capture_scene.gd -- combat|menu|camp|journal|journal_march|record|discovery|complete.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_enabled = false
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
	if mode.begins_with("career_") or mode in ["escort", "magic"]:
		var career_id := mode.trim_prefix("career_") if mode.begins_with("career_") else ("warden" if mode == "escort" else "artisan")
		game.restore_checkpoint({"career":{"path":"","completed":{}},"training":{"primary":"bolt","secondary":"familiar","experience":{"arcana":6}},"resources":{"timber":12,"crystal":6}})
		game.resume()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await create_timer(0.15).timeout
		game.missions.choose(career_id,true)
		if mode.begins_with("career_"):
			game.open_growth()
			game.hud.growth.selected = career_id
			game.hud.growth.refresh()
		elif mode == "escort":
			game.player.position = game.missions.escort.position+Vector3(1.5,0.1,2)
			game.camera_rig.position = game.player.position+Vector3(0,1.25,0)
			game.arts.use_tactic()
		else:
			game.player.position = Vector3(0,0.1,-14)
			game.camera_rig.position = game.player.position+Vector3(0,1.25,0)
			game.arts.use_tactic()
			game.player.try_attack("familiar")
			await create_timer(0.4).timeout
	if mode == "journal":
		game.open_journal()
	if mode == "journal_march":
		# The longest existing quest heading and a two-line crew task exercise text wrapping.
		game.expedition.start()
		game.director.board.stage = 1
		game.director.board.chosen = "leg2_chief"
		game.director.plan.leg = 1
		game.director.plan.stretch = 1
		game.director.active.light = {"step": MarchPlan.LEGS[1].stretches[1].light[0]}
		game.open_journal()
	if mode in ["record", "discovery", "complete"]:
		# Skip the march only in this capture fixture. Integration tests play its real steps.
		game.expedition.start()
		game._on_departed()
		game.expedition.march_complete()
		game.expedition.base_build(100)
		game.director.caravan.distance = game.director.caravan.length()
		game.director.caravan_view.settled = true
		game.director._complete_base()
		for enemy: RuinGuardian in get_nodes_in_group("enemies"):
			enemy.take_damage(1000, Vector3.ZERO)
		game.player.position = ExpeditionCampaign.RECORD_POSITION + Vector3(0, 0.05, 2)
		game.camera_rig.position = game.player.position + Vector3(0, 1.25, 0)
		game.light.plant(Vector3(0, 0, -25))
		await create_timer(0.6).timeout
		game.hud.notice_time = 0
		if mode == "discovery":
			game.expedition.collect_entrance_record()
			game.open_journal()
		if mode == "complete":
			game.expedition.collect_entrance_record()
			game.expedition.record_delivery(0)
			game.expedition.record_delivery(1)
			game.player.position = game.camp_position
			game.camera_rig.position = game.player.position + Vector3(0, 1.25, 0)
			game.resume()
			game.interact()
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
