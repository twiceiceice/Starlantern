extends Node3D

var gameplay: Node3D
var player: ExpeditionPlayer
var camera_rig: FollowCamera
var hud: ExpeditionHud
var effects: CombatEffects
var expedition := Expedition.new()
var light := LanternNetwork.new()
var workers: Array[ExpeditionWorker] = []
var director: MarchDirector
var started := false
## Reports and respawns happen here: the start camp, then the forward base once it is built.
@export var camp_position := Vector3(0, 0, 150)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load("res://scripts/core/input_setup.gd").configure()
	gameplay = $GameWorld
	player = ExpeditionPlayer.new()
	player.position = camp_position + Vector3(0, 0.05, 0)
	gameplay.add_child(player)
	player.attack_landed.connect(_resolve_attack)
	player.defeated.connect(_on_player_defeated)
	camera_rig = FollowCamera.new()
	camera_rig.name = "FollowCamera"
	camera_rig.target = player
	gameplay.add_child(camera_rig)
	effects = CombatEffects.new()
	gameplay.add_child(effects)
	# Fixed lamps match the start camp circle and the old ruin road lamps in expedition_valley.tscn.
	light.add_anchor(camp_position, 9.5)
	for point: Vector3 in [Vector3(-3.5, 0, 8), Vector3(3.5, 0, 8), Vector3(-4.5, 0, -7), Vector3(4.5, 0, -7)]:
		light.add_anchor(point, 4.5)
	var glow := LanternGlow.new()
	glow.light = light
	gameplay.add_child(glow)
	for i in range(2):
		var worker := ExpeditionWorker.new()
		worker.name = "Carpenter" if i == 0 else "Porter"
		worker.player = player
		worker.light = light
		worker.worker_id = i
		worker.job = "carpenter" if i == 0 else "porter"
		worker.position = camp_position + Vector3(-2.3 if i == 0 else 2.3, 0.05, -1.5)
		worker.work_position = Vector3(-4 if i == 0 else 4, 0, -24)
		gameplay.add_child(worker)
		worker.delivered.connect(_on_delivery)
		workers.append(worker)
	for point: Vector3 in [Vector3(-3, 0.05, -16), Vector3(3, 0.05, -21), Vector3(0, 0.05, -26)]:
		var guardian := RuinGuardian.new()
		guardian.position = point
		guardian.target = player
		gameplay.add_child(guardian)
		guardian.died.connect(_on_enemy_defeated)
		guardian.struck_player.connect(func(): camera_rig.bump(0.35))
	director = MarchDirector.new()
	director.expedition = expedition
	director.light = light
	director.player = player
	gameplay.add_child(director)
	director.departed.connect(_on_departed)
	director.base_completed.connect(_on_base_completed)
	director.notice.connect(func(text: String): hud.notify(text))
	hud = ExpeditionHud.new()
	add_child(hud)
	hud.resume_requested.connect(resume)
	hud.restart_requested.connect(restart)
	hud.quit_requested.connect(func(): get_tree().quit())
	get_tree().paused = true
	hud.show_menu(true)
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke_run.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _process(delta: float) -> void:
	if not get_tree().paused and expedition.stage in [Expedition.Stage.CLEARING, Expedition.Stage.RECOVERING]:
		light.burn(delta)
	if is_instance_valid(hud):
		hud.update_state(player, title_text(), objective_text(), status_text(), interaction_prompt(), 0 if get_tree().paused else delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused and started:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("interact") and not get_tree().paused:
		interact()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and started:
		pause()

func pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu(not started)

func resume() -> void:
	started = true
	hud.menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_release("attack")

func restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

func _marching() -> bool:
	return expedition.stage in [Expedition.Stage.CAMP, Expedition.Stage.MARCH, Expedition.Stage.BASE]

func title_text() -> String:
	return director.title() if _marching() else "03   /   이끼빛 유적"

func objective_text() -> String:
	return director.objective() if _marching() else expedition.objective(site_lit())

func status_text() -> String:
	if _marching():
		return director.status()
	var text := "원정대 %d명  ·  목재 %d  ·  별빛 조각 %d" % [director.caravan.people, expedition.resources.timber, expedition.resources.crystal]
	if light.planted:
		text += "  ·  기름 %d%%" % roundi(100 * light.fuel / light.max_fuel)
	return text

func site_lit() -> bool:
	return workers.all(func(w: ExpeditionWorker): return light.is_lit(w.work_position))

func _expedition_active() -> bool:
	return expedition.stage in [Expedition.Stage.CLEARING, Expedition.Stage.RECOVERING]

func can_plant_here() -> bool:
	if not _expedition_active() or not light.can_plant(player.global_position):
		return false
	for enemy: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) < 6:
			return false
	return true

func interaction_prompt() -> String:
	var march_prompt := director.prompt()
	if not march_prompt.is_empty():
		return march_prompt
	if player.global_position.distance_to(camp_position) > 5:
		if can_plant_here():
			return "E  ·  전진 등불 %s" % ("옮기기" if light.planted else "세우기")
		return ""
	if expedition.stage == Expedition.Stage.REPORT:
		return "E  ·  원정 보고와 자원 받기"
	if _expedition_active() and light.fuel < light.max_fuel:
		return "E  ·  등불 기름 채우기"
	return ""

func interact() -> void:
	if director.interact():
		return
	if player.global_position.distance_to(camp_position) > 5:
		if can_plant_here():
			var moved := light.planted
			light.plant(player.global_position)
			hud.notify("전진 등불을 옮겼습니다." if moved else "전진 등불을 세웠습니다. 빛이 닿는 곳에서 인부들이 일할 수 있습니다.")
		return
	if expedition.report():
		hud.notify("첫 원정 완료! 목재 +12 · 별빛 조각 +6  ·  원정대 %d명 · 식량 %d 남음" % [director.caravan.people, director.caravan.food])
		_show_delivered_supplies()
	elif _expedition_active() and light.fuel < light.max_fuel:
		light.refuel()
		hud.notify("등불 기름을 가득 채웠습니다.")

func _resolve_attack(origin: Vector3, facing: Vector3, definition: Dictionary) -> void:
	var heavy := float(definition.damage) >= 40
	effects.swing(origin, facing, heavy)
	var hits := 0
	for enemy: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		if not CombatRules.within_arc(origin, facing, enemy.global_position, definition.range, definition.angle):
			continue
		var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP, enemy.global_position + Vector3.UP, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		enemy.take_damage(definition.damage, (enemy.global_position - origin).normalized())
		effects.damage_number(enemy.global_position, definition.damage)
		hits += 1
	if hits > 0:
		camera_rig.bump(0.4 if heavy else 0.16)

func _on_departed() -> void:
	for worker in workers:
		worker.enlist()

func _on_base_completed() -> void:
	camp_position = director.base_center
	player.spawn_point = camp_position + Vector3(0, 0.2, 0)
	for worker in workers:
		worker.set_home(director.base_center + Vector3(-2.3 if worker.worker_id == 0 else 2.3, 0, -1.5))
	if expedition.stage == Expedition.Stage.RECOVERING:
		_secure_site()

func _on_enemy_defeated(_enemy: RuinGuardian) -> void:
	if expedition.enemy_defeated():
		_secure_site()

func _secure_site() -> void:
	for worker in workers:
		worker.secure_site()
	hud.notify("유적 확보! 전진 등불을 세우면 동료들이 들어와 자원을 회수합니다." if not site_lit() else "유적 확보! 동료들이 들어와 자원을 회수하기 시작합니다.")

func _on_delivery(worker: ExpeditionWorker) -> void:
	if expedition.record_delivery(worker.worker_id):
		if expedition.stage == Expedition.Stage.REPORT:
			hud.notify("모든 짐이 캠프에 도착했습니다. 돌아가서 E로 정산하세요.")

func _on_player_defeated() -> void:
	player.respawn(camp_position + Vector3(0, 0.2, 0))
	for enemy: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		enemy.reset_encounter()
	camera_rig.position = player.position + Vector3(0, 1.25, 0)
	hud.notify("캠프로 돌아왔습니다. 남은 파수꾼이 회복했습니다.")

func _show_delivered_supplies() -> void:
	for i in range(3):
		Geometry.box(gameplay, Vector3(-3.5 + i * 0.85, 0.34, 18), Vector3(0.75, 0.68, 0.75), Color("bd955e"))
	var sign := Node3D.new()
	gameplay.add_child(sign)
	sign.position = Vector3(-2.7, 1, 18)
	Geometry.label(sign, "첫 원정의 수확", 0.7)

func _smoke_run() -> void:
	# Deterministic command-line launch check; normal launches never use this path.
	resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.3).timeout
	interact()
	await get_tree().create_timer(1).timeout
	print("SMOKE_OK: world, player, camera, HUD, caravan and two workers initialized")
	get_tree().quit()

func _capture() -> void:
	resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var error := get_viewport().get_texture().get_image().save_png("res://captures/camp.png")
	print("CAPTURE: ", error_string(error))
	get_tree().quit()
