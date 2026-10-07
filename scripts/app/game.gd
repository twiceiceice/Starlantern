extends Node3D

var region_id := RegionLayout.MEADOW
var landscape: Node3D
var region_actors: Node3D
var glow: LanternGlow
var caravan := Caravan.new(RegionLayout.route())
var director_snapshot: Dictionary = {}
var forest_workers: Array = []
var region_lights := {RegionLayout.MEADOW: LanternNetwork.new(), RegionLayout.FOREST: LanternNetwork.new()}
var cleared_guardians: Array[int] = []
var portal_unlocked := false
var changing_region := false
var restoring := false
var last_dry_position := RegionLayout.START
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
var journal_from_menu := false
var growth_return := "play"
var career := CareerProgress.new()
var missions: CareerDirector
var arts: CombatArts
@export var save_enabled := true
## Reports and respawns happen here: the start camp, then the forward base once it is built.
@export var camp_position := Vector3(0, 0, 150)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load("res://scripts/core/input_setup.gd").configure()
	gameplay = $GameWorld
	landscape = load(RegionLayout.SCENES[region_id]).instantiate()
	gameplay.add_child(landscape)
	region_actors = Node3D.new()
	gameplay.add_child(region_actors)
	light = region_lights[region_id]
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
	light.add_anchor(camp_position, 12.0)
	glow = LanternGlow.new()
	glow.light = light
	glow.show_anchor_rings = region_id == RegionLayout.FOREST
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
	_create_director()
	missions = CareerDirector.new()
	missions.progress = career
	missions.player = player
	gameplay.add_child(missions)
	missions.notice.connect(func(text: String): hud.notify(text))
	missions.contract_reported.connect(_on_contract_reported)
	arts = CombatArts.new()
	arts.player = player
	arts.career = career
	arts.missions = missions
	arts.effects = effects
	gameplay.add_child(arts)
	arts.notice.connect(func(text: String): hud.notify(text))
	arts.hit_feedback.connect(func(heavy: bool): camera_rig.bump(0.4 if heavy else 0.16))
	hud = ExpeditionHud.new()
	add_child(hud)
	hud.resume_requested.connect(resume)
	hud.restart_requested.connect(restart)
	hud.quit_requested.connect(func(): _save_checkpoint(); get_tree().quit())
	hud.journal_requested.connect(open_journal)
	hud.journal_closed.connect(close_journal)
	hud.growth_requested.connect(open_growth)
	hud.growth.closed.connect(close_growth)
	hud.growth.contract_requested.connect(_choose_career)
	hud.growth.equipment_requested.connect(_equip)
	if "--smoke" in OS.get_cmdline_user_args() or "--smoke-regions" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args(): save_enabled = false
	if save_enabled:
		var saved := ExpeditionSave.read_checkpoint()
		if not saved.is_empty(): restore_checkpoint(saved)
	get_tree().paused = true
	hud.show_menu(not started)
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke_run.call_deferred()
	if "--smoke-regions" in OS.get_cmdline_user_args():
		_smoke_regions.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _process(delta: float) -> void:
	if region_id == RegionLayout.MEADOW and not get_tree().paused:
		if RegionLayout.river_unsafe(player.position):
			player.position = last_dry_position + Vector3.UP * 0.2
			player.velocity = Vector3.ZERO
			camera_rig.position = player.position + Vector3.UP * 1.25
			hud.notify("강물은 깊습니다. 원정대의 다리를 이용하세요.")
		elif player.is_on_floor() and absf(player.position.z) > 16:
			last_dry_position = player.position
	if not get_tree().paused and expedition.stage in [Expedition.Stage.CLEARING, Expedition.Stage.RECOVERING]:
		light.burn(delta)
	if is_instance_valid(hud):
		hud.region_label.text = RegionLayout.NAMES[region_id]
		hud.update_state(player, title_text(), objective_text(), status_text(), interaction_prompt(), 0 if get_tree().paused else delta)
		hud.tactic_label.text = "K · 성장과 진로" if career.path.is_empty() else "R · %s%s  /  K 성장과 진로" % [CareerProgress.TACTICS[career.path],"  %.1f초" % arts.tactic_cooldown if arts.tactic_cooldown > 0 else " 준비",]

func _unhandled_input(event: InputEvent) -> void:
	if changing_region: return
	if event.is_action_pressed("growth"):
		if hud.growth.visible: close_growth()
		else: open_growth()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tactic") and not get_tree().paused:
		arts.use_tactic()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		if hud.growth.visible: close_growth()
		if hud.journal.visible:
			close_journal()
		else:
			open_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if hud.growth.visible:
			close_growth()
			get_viewport().set_input_as_handled()
			return
		if hud.journal.visible:
			close_journal()
			get_viewport().set_input_as_handled()
			return
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(hud): _save_checkpoint()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and started:
		pause()

func pause() -> void:
	if changing_region: return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hud.journal.visible or hud.growth.visible:
		return
	hud.show_menu(not started)

func resume() -> void:
	started = true
	hud.menu.visible = false
	hud.journal.visible = false
	hud.growth.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_release("attack")

func open_journal() -> void:
	if hud.journal.visible:
		return
	journal_from_menu = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu.visible = false
	var assignment := "게시판에서 임무 하나를 고르면 다른 일은 원정대가 맡습니다."
	if not director.board.chosen.is_empty():
		assignment = "맡은 일 · " + str(director.board.quest().title)
	elif not _marching():
		assignment = "나는 입구와 기록을 조사하고, 동료들은 표본을 회수합니다."
	hud.show_journal(ExpeditionCampaign.journal(expedition, director.plan.leg, objective_text(), assignment))

func close_journal() -> void:
	hud.journal.visible = false
	if journal_from_menu:
		get_tree().paused = true
		hud.show_menu(not started)
	else:
		resume()

func restart() -> void:
	if save_enabled: ExpeditionSave.clear_checkpoint()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

func _marching() -> bool:
	return expedition.stage in [Expedition.Stage.CAMP, Expedition.Stage.MARCH, Expedition.Stage.BASE]

func title_text() -> String:
	if expedition.stage == Expedition.Stage.COMPLETE:
		return "%s · %d / 3 의뢰" % [career.title(),int(career.completed[career.path])] if not career.path.is_empty() else "진로 대장정 · 의뢰 개방"
	var chapter := ExpeditionCampaign.chapter(expedition, director.plan.leg)
	if chapter == ExpeditionCampaign.CHAPTERS.size():
		return "대장정 완료 · 별문이 열린 날"
	return "%02d   /   %s" % [chapter + 1, ExpeditionCampaign.CHAPTERS[chapter].title]

func objective_text() -> String:
	if region_id == RegionLayout.MEADOW and expedition.stage >= Expedition.Stage.BASE: return "확보한 보급로 · 자유롭게 둘러보세요\n야영지 또는 강 건너 표지판에서 E · 전진 기지로"
	if expedition.stage == Expedition.Stage.COMPLETE: return missions.objective()
	return director.objective() if _marching() else expedition.objective(site_lit())

func status_text() -> String:
	if _marching():
		return director.status()
	if expedition.stage == Expedition.Stage.COMPLETE:
		return "%s · 목재 %d · 별빛 조각 %d" % [career.title(),expedition.resources.timber, expedition.resources.crystal]
	var text := "%d명 · 기록 %s · 표본 %d/2" % [director.caravan.people, "확보" if expedition.entrance_record else "미확보", expedition.deliveries.size()]
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

func near_entrance_record() -> bool:
	return player.global_position.distance_to(ExpeditionCampaign.RECORD_POSITION) <= ExpeditionCampaign.RECORD_REACH

func entrance_record_visible() -> bool:
	if not near_entrance_record() or not player.is_on_floor() or absf(player.global_position.y) > 0.6:
		return false
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, ExpeditionCampaign.RECORD_POSITION + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func interaction_prompt() -> String:
	var travel := travel_destination()
	if not travel.is_empty(): return "E · " + ("숲의 전진 기지로 이동" if travel == RegionLayout.FOREST else "출발 야영지로 빠른 이동")
	if region_id == RegionLayout.MEADOW and player.position.distance_to(RegionLayout.CROSSING + Vector3.RIGHT * 4) < 6 and not portal_unlocked:
		return "도하 임무를 마치고 선발대가 도착하면 이동할 수 있습니다"
	if region_id == RegionLayout.MEADOW and player.position.distance_to(RegionLayout.CAMP_GATE) < 3.2 and not portal_unlocked:
		return "도하를 마치면 전진 기지로 가는 보급로가 열립니다"
	if region_id == RegionLayout.MEADOW and expedition.stage >= Expedition.Stage.BASE: return ""
	if expedition.stage == Expedition.Stage.COMPLETE: return missions.prompt()
	var march_prompt := director.prompt()
	if not march_prompt.is_empty():
		return march_prompt
	if near_entrance_record() and expedition.stage == Expedition.Stage.RECOVERING and not expedition.entrance_record:
		if not entrance_record_visible():
			return "기록판 앞의 땅에 서서 조사하세요"
		if light.is_lit(ExpeditionCampaign.RECORD_POSITION):
			return "E  ·  별잠회랑의 첫 탐사 기록 확보"
		return "E  ·  기록판을 밝힐 전진 등불 세우기"
	if player.global_position.distance_to(camp_position) > 5:
		if can_plant_here():
			return "E  ·  전진 등불 %s" % ("옮기기" if light.planted else "세우기")
		return ""
	if expedition.stage == Expedition.Stage.REPORT:
		return "E  ·  길드에 첫 탐사 기록과 표본 보고"
	if _expedition_active() and light.fuel < light.max_fuel:
		return "E  ·  등불 기름 채우기"
	return ""

func interact() -> void:
	if get_tree().paused or changing_region:
		return
	var destination := travel_destination()
	if not destination.is_empty():
		request_travel(destination)
		return
	if region_id == RegionLayout.MEADOW and expedition.stage >= Expedition.Stage.BASE: return
	if expedition.stage == Expedition.Stage.COMPLETE:
		if not missions.interact() and not career.active and missions.near_camp(): open_growth()
		return
	if director.interact():
		return
	if near_entrance_record() and expedition.stage == Expedition.Stage.RECOVERING and not expedition.entrance_record:
		if not entrance_record_visible():
			return
		if light.is_lit(ExpeditionCampaign.RECORD_POSITION):
			if expedition.collect_entrance_record():
				hud.notify("첫 탐사 기록 확보! 지하도시로 이어지는 길을 발견했습니다. J로 기록을 확인하세요.")
			return
	if player.global_position.distance_to(camp_position) > 5:
		if can_plant_here():
			var moved := light.planted
			light.plant(player.global_position)
			hud.notify("전진 등불을 옮겼습니다." if moved else "전진 등불을 세웠습니다. 빛이 닿는 곳에서 인부들이 일할 수 있습니다.")
		return
	if expedition.report():
		hud.notify("대장정 완료 · 별문이 열린 날! 선발 조사단원으로 인정받았습니다.")
		_show_delivered_supplies()
		_save_checkpoint()
		open_journal()
	elif _expedition_active() and light.fuel < light.max_fuel:
		light.refuel()
		hud.notify("등불 기름을 가득 채웠습니다.")

func _resolve_attack(origin: Vector3, facing: Vector3, definition: Dictionary) -> void:
	arts.resolve_attack(origin,facing,definition)

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
	var id := int(_enemy.get_meta("site_guardian", -1))
	if id >= 0 and id not in cleared_guardians: cleared_guardians.append(id)
	if expedition.enemy_defeated():
		_secure_site()

func _secure_site() -> void:
	for worker in workers:
		worker.secure_site()
	hud.notify("입구 확보! 전진 등불을 세우고 안쪽 기록판을 조사하세요. 인부들은 표본을 회수합니다.")

func _on_delivery(worker: ExpeditionWorker) -> void:
	if expedition.record_delivery(worker.worker_id):
		if expedition.stage == Expedition.Stage.REPORT:
			hud.notify("기록과 표본이 모두 준비되었습니다. 전진 기지에서 E로 길드에 보고하세요.")
		elif expedition.deliveries.size() == 2:
			hud.notify("표본 운반 완료. 별잠회랑 안쪽의 기록판을 조사해야 첫 탐사를 보고할 수 있습니다.")

func _on_player_defeated() -> void:
	arts.reset_effects()
	if career.active: missions.fail()
	player.respawn(camp_position + Vector3(0, 0.2, 0))
	for enemy: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		enemy.reset_encounter()
	camera_rig.position = player.position + Vector3(0, 1.25, 0)
	hud.notify("캠프로 돌아왔습니다. 남은 파수꾼이 회복했습니다.")

func _show_delivered_supplies() -> void:
	if region_id != RegionLayout.FOREST or region_actors.has_node("DeliveredSupplies"): return
	for i in range(3):
		Geometry.box(region_actors, Vector3(-3.5 + i * 0.85, 0.34, 18), Vector3(0.75, 0.68, 0.75), Color("bd955e"))
	var sign := Node3D.new()
	sign.name = "DeliveredSupplies"
	region_actors.add_child(sign)
	sign.position = Vector3(-2.7, 1, 18)
	Geometry.label(sign, "별잠회랑 · 첫 탐사 성과", 0.7)

func open_growth() -> void:
	if hud.growth.visible: return
	growth_return = "journal" if hud.journal.visible else ("menu" if get_tree().paused else "play")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu.visible = false
	hud.journal.visible = false
	_refresh_growth()

func _refresh_growth() -> void:
	hud.growth.show_state({"career":career,"training":player.training,"unlocked":expedition.stage == Expedition.Stage.COMPLETE,"at_camp":region_id == RegionLayout.FOREST and missions.near_camp()})

func close_growth() -> void:
	hud.growth.visible = false
	match growth_return:
		"journal": hud.journal.visible = true
		"menu": hud.show_menu(not started)
		_: resume()

func _choose_career(id: String) -> void:
	if region_id == RegionLayout.FOREST and missions.choose(id,expedition.stage == Expedition.Stage.COMPLETE):
		arts.reset_effects()
		_save_checkpoint()
	_refresh_growth()

func _equip(slot: int, action: String) -> void:
	if player.attack_name.is_empty() and not player.carrying and player.training.equip(slot,action):
		player.view.set_magic_focus(player.training.primary == "bolt")
		_save_checkpoint()
	else: hud.notify("공격 동작이나 짐 운반을 마친 뒤 기술을 바꿀 수 있습니다.")
	_refresh_growth()

func _on_contract_reported() -> void:
	expedition.resources.timber += 8
	expedition.resources.crystal += 4
	player.health = 100
	arts.reset_effects()
	_save_checkpoint()
	hud.notify("길드 보고 완료 · %s! 목재 +8 · 별빛 조각 +4. K에서 다음 의뢰를 선택하세요." % career.title())
	open_growth()

func _save_checkpoint() -> void:
	if not save_enabled or restoring or changing_region: return
	var result := ExpeditionSave.write_checkpoint(career,player.training,expedition.resources,ExpeditionSave.PATH,{"people":caravan.people,"food":caravan.food},journey_data())
	if result != OK: hud.notify("저장하지 못했습니다. 저장 공간과 파일 권한을 확인해 주세요.")

func _restore_legacy_checkpoint(saved: Dictionary) -> void:
	career.restore(saved.get("career",{}))
	player.training.restore(saved.get("training",{}))
	expedition.stage = Expedition.Stage.COMPLETE
	expedition.base_progress = 100
	expedition.remaining_enemies = 0
	expedition.entrance_record = true
	expedition.deliveries = {0:true,1:true}
	for resource in expedition.resources:
		var amount: Variant = saved.get("resources",{}).get(resource,0)
		expedition.resources[resource] = clampi(int(amount),0,100000) if amount is int or amount is float else 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.clear_marker()
		enemy.queue_free()
	director._clear_posts()
	director.board.stage = 3
	director.board.chosen = ""
	director.caravan.distance = director.caravan.length()
	var caravan_data: Variant = saved.get("caravan",{})
	if caravan_data is Dictionary:
		var people: Variant = caravan_data.get("people",300)
		var food: Variant = caravan_data.get("food",2400)
		director.caravan.people = clampi(int(people),0,300) if people is int or people is float else 300
		director.caravan.food = clampf(float(food),0,2400) if food is int or food is float else 2400
	director.caravan_view.settled = true
	director.settlement.set_progress(100,false)
	_on_base_completed()
	light.add_anchor(camp_position,9.5)
	for worker in workers:
		worker.position = worker.home
		worker.state = "delivered"
		worker._update_caption()
	player.respawn(camp_position+Vector3(0,0.05,0))
	player.view.set_magic_focus(player.training.primary == "bolt")
	camera_rig.position = player.position + Vector3(0,1.25,0)
	started = true
	_show_delivered_supplies()

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

func _smoke_regions() -> void:
	# Export QA uses the actual input-independent travel path and no player save.
	resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.2).timeout
	expedition.start()
	director.crossing_ready = true
	director.board.stage = 2
	caravan.distance = caravan.length()
	portal_unlocked = true
	var people_before := caravan.people
	var food_before := caravan.food
	player.position = RegionLayout.CROSSING + Vector3(4, 0.08, 1)
	request_travel(RegionLayout.FOREST)
	while changing_region: await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if region_id != RegionLayout.FOREST or expedition.stage != Expedition.Stage.BASE or not is_instance_valid(director.settlement) or caravan.people != people_before or absf(caravan.food - food_before) > 1:
		push_error("Exported region transition failed")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := OS.get_executable_path().get_base_dir().path_join("region-smoke.png")
		var error := get_viewport().get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Region capture failed: " + error_string(error))
			get_tree().quit(1)
			return
	print("REGIONS_SMOKE_OK: meadow -> crossing -> forest; campaign and supplies retained")
	get_tree().quit()

func _create_director() -> void:
	director = MarchDirector.new()
	director.expedition = expedition
	director.caravan = caravan
	director.region = region_id
	director.light = light
	director.player = player
	gameplay.add_child(director)
	director.departed.connect(_on_departed)
	director.base_completed.connect(_on_base_completed)
	director.notice.connect(func(text: String): hud.notify(text))
	director.checkpoint_reached.connect(_checkpoint_reached, CONNECT_DEFERRED)
	if not director_snapshot.is_empty(): director.restore_data(director_snapshot)

func _checkpoint_reached() -> void:
	if not is_instance_valid(director): return
	if director.crossing_ready: portal_unlocked = true
	_save_checkpoint()

func travel_destination() -> String:
	if not portal_unlocked and not director.crossing_ready: return ""
	if region_id == RegionLayout.FOREST:
		return RegionLayout.MEADOW if player.position.distance_to(RegionLayout.FOREST_GATE) < 3.2 else ""
	if player.position.distance_to(RegionLayout.CROSSING + Vector3.RIGHT * 4) < 3.2:
		return RegionLayout.FOREST
	if expedition.stage >= Expedition.Stage.BASE and player.position.distance_to(RegionLayout.CAMP_GATE) < 3.2:
		return RegionLayout.FOREST
	return ""

func request_travel(destination: String) -> void:
	if changing_region or destination != travel_destination() or destination.is_empty(): return
	if career.active:
		hud.notify("진행 중인 진로 의뢰를 마치고 보급 수레를 이용하세요.")
		return
	if player.carrying or not player.attack_name.is_empty() or player.dodge_left > 0:
		hud.notify("짐을 내려놓고 동작을 마친 뒤 이동하세요.")
		return
	for foe: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		if foe.state != "dead" and foe.global_position.distance_to(player.position) < 9:
			hud.notify("주변의 적을 정리한 뒤 이동할 수 있습니다.")
			return
	changing_region = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var text := "숲의 전진 기지로\n후미의 수레들이 뒤따라옵니다" if destination == RegionLayout.FOREST else "확보한 보급로를 따라\n출발 야영지로"
	await hud.fade_travel(text, true)
	var first_arrival := expedition.stage == Expedition.Stage.MARCH
	portal_unlocked = true
	if first_arrival:
		director_snapshot = director.to_data()
		expedition.march_complete()
	change_region(destination, not first_arrival)
	if first_arrival: director.caravan_view.arrival_left = 8.0
	var at := Vector3(0, 0, 44) if destination == RegionLayout.FOREST else RegionLayout.CAMP_GATE + Vector3(1.5, 0, 1)
	player.position = at + Vector3.UP * 0.08
	player.velocity = Vector3.ZERO
	player.carrying = false
	last_dry_position = player.position
	camera_rig.position = player.position + Vector3.UP * 1.25
	camera_rig.yaw = 0
	# Navigation regions are synchronized before agents resume on the new map.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await hud.fade_travel(text, false)
	changing_region = false
	_save_checkpoint()
	resume()
	hud.notify("전진 기지 도착 · 게시판에서 건설 임무를 고르세요." if first_arrival else "보급로 이동 완료 · 원정 진행을 이어갑니다.")

## Replace only regional nodes. Character training, resources and the campaign ledger
## stay alive. The previous navigation mesh and all its enemies are removed together.
func change_region(id: String, capture_previous: bool = true) -> void:
	if not RegionLayout.SCENES.has(id): return
	if capture_previous:
		if region_id == RegionLayout.FOREST or expedition.stage <= Expedition.Stage.MARCH or director.crossing_ready and director_snapshot.is_empty():
			director_snapshot = director.to_data()
		if region_id == RegionLayout.FOREST: forest_workers = _worker_data()
	if is_instance_valid(arts): arts.reset_effects()
	if is_instance_valid(missions): missions.clear_site()
	for foe: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		foe.clear_marker()
		foe.remove_from_group("enemies")
	if is_instance_valid(director): director.free()
	if is_instance_valid(region_actors): region_actors.free()
	if is_instance_valid(glow): glow.free()
	if is_instance_valid(landscape): landscape.free()
	region_id = id
	light = region_lights[id]
	landscape = load(RegionLayout.SCENES[id]).instantiate()
	gameplay.add_child(landscape)
	region_actors = Node3D.new()
	gameplay.add_child(region_actors)
	camp_position = RegionLayout.START if id == RegionLayout.MEADOW else RegionLayout.BASE
	player.spawn_point = camp_position + Vector3.UP * 0.2
	if light.anchors.is_empty():
		light.add_anchor(camp_position, 12.0 if id == RegionLayout.MEADOW else 9.5)
		if id == RegionLayout.FOREST:
			for at in [Vector3(-3.5,0,8), Vector3(3.5,0,8), Vector3(-4.5,0,-7), Vector3(4.5,0,-7)]: light.add_anchor(at, 4.5)
	_create_director()
	glow = LanternGlow.new()
	glow.light = light
	glow.show_anchor_rings = region_id == RegionLayout.FOREST
	gameplay.add_child(glow)
	if id == RegionLayout.FOREST:
		var positions := [Vector3(-3,0.05,-16), Vector3(3,0.05,-21), Vector3(0,0.05,-26)]
		for i in positions.size():
			if i in cleared_guardians: continue
			var foe := RuinGuardian.new()
			foe.position = positions[i]
			foe.target = player
			foe.set_meta("site_guardian", i)
			region_actors.add_child(foe)
			foe.died.connect(_on_enemy_defeated)
			foe.struck_player.connect(func(): camera_rig.bump(0.35))
		var discovery := DungeonDiscoveryView.new()
		discovery.expedition = expedition
		region_actors.add_child(discovery)
		if expedition.stage == Expedition.Stage.COMPLETE: _show_delivered_supplies()
	for worker in workers:
		worker.light = light
		var present := id == RegionLayout.FOREST or expedition.stage <= Expedition.Stage.MARCH
		worker.visible = present
		worker.process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
		worker.collision_layer = 4 if present else 0
		if id == RegionLayout.FOREST:
			worker.home = camp_position + Vector3(-2.3 if worker.worker_id == 0 else 2.3, 0, -1.5)
			worker.position = worker.home + Vector3.UP * 0.05
			worker.velocity = Vector3.ZERO
			worker.enlist()
			if expedition.stage >= Expedition.Stage.RECOVERING: worker.secure_site()
	if id == RegionLayout.FOREST and not forest_workers.is_empty(): _restore_workers(forest_workers)

static func _vector_data(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

static func _read_vector(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array or value.size() != 3: return fallback
	for n in value:
		if not (n is float or n is int) or not is_finite(float(n)): return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _worker_data() -> Array:
	var data := []
	for worker in workers:
		data.append({"state":worker.state, "position":_vector_data(worker.position), "home":_vector_data(worker.home),
			"progress":worker.progress, "safe":worker.safe_to_work})
	return data

func _restore_workers(data: Array) -> void:
	for i in mini(data.size(), workers.size()):
		if not data[i] is Dictionary: continue
		var worker := workers[i]
		var saved: Dictionary = data[i]
		var state := str(saved.get("state", "follow"))
		worker.state = state if state in ["camp", "follow", "waiting", "to_work", "working", "returning", "delivered"] else "follow"
		worker.position = _read_vector(saved.get("position"), worker.home + Vector3.UP * 0.05)
		worker.home = _read_vector(saved.get("home"), worker.home)
		worker.progress = clampf(float(saved.get("progress", 0)), 0, 6)
		worker.safe_to_work = bool(saved.get("safe", false))
		worker.velocity = Vector3.ZERO
		worker.repath = 0
		worker._update_caption()

func journey_data() -> Dictionary:
	if region_id == RegionLayout.FOREST or expedition.stage <= Expedition.Stage.MARCH: director_snapshot = director.to_data()
	if region_id == RegionLayout.FOREST: forest_workers = _worker_data()
	var lamps := {}
	for id in region_lights:
		var network: LanternNetwork = region_lights[id]
		var anchors := []
		for anchor in network.anchors: anchors.append({"at":_vector_data(anchor.position), "radius":anchor.radius})
		lamps[id] = {"anchors":anchors, "planted":network.planted, "forward":_vector_data(network.forward_position), "fuel":network.fuel}
	return {"region":region_id, "unlocked":portal_unlocked or director.crossing_ready,
		"expedition":expedition.to_data(), "director":director_snapshot.duplicate(true), "distance":caravan.distance,
		"player":_vector_data(player.position), "health":player.health, "cleared":cleared_guardians.duplicate(),
		"workers":_worker_data() if expedition.stage <= Expedition.Stage.MARCH else forest_workers,
		"lamps":lamps}

func restore_checkpoint(saved: Dictionary) -> void:
	restoring = true
	var journey: Dictionary = saved.get("journey", {}) if saved.get("journey", {}) is Dictionary else {}
	if journey.is_empty():
		# Version 1 files represent a finished expedition. Keep that progress intact.
		portal_unlocked = true
		change_region(RegionLayout.FOREST, false)
		_restore_legacy_checkpoint(saved)
		cleared_guardians.assign([0,1,2])
		director.crossing_ready = true
		director_snapshot = director.to_data()
		restoring = false
		return
	career.restore(saved.get("career", {}))
	player.training.restore(saved.get("training", {}))
	expedition.restore(journey.get("expedition", {}) if journey.get("expedition", {}) is Dictionary else {})
	for resource in expedition.resources:
		var amount: Variant = saved.get("resources", {}).get(resource, 0)
		expedition.resources[resource] = clampi(int(amount), 0, 100000) if amount is float or amount is int else 0
	var caravan_data: Dictionary = saved.get("caravan", {}) if saved.get("caravan", {}) is Dictionary else {}
	caravan.people = clampi(int(caravan_data.get("people", 300)), 0, 300)
	caravan.food = clampf(float(caravan_data.get("food", 2400)), 0, 2400)
	caravan.distance = clampf(float(journey.get("distance", 0)), 0, caravan.length())
	portal_unlocked = bool(journey.get("unlocked", false))
	cleared_guardians.clear()
	for id in journey.get("cleared", []):
		if int(id) in [0,1,2] and int(id) not in cleared_guardians: cleared_guardians.append(int(id))
	director_snapshot = journey.get("director", {}).duplicate(true) if journey.get("director", {}) is Dictionary else {}
	forest_workers = journey.get("workers", []).duplicate(true) if journey.get("workers", []) is Array else []
	var lamps: Dictionary = journey.get("lamps", {}) if journey.get("lamps", {}) is Dictionary else {}
	for id in region_lights:
		var network: LanternNetwork = region_lights[id]
		network.anchors.clear()
		var data: Dictionary = lamps.get(id, {}) if lamps.get(id, {}) is Dictionary else {}
		for anchor in data.get("anchors", []):
			if anchor is Dictionary: network.add_anchor(_read_vector(anchor.get("at"), RegionLayout.START), clampf(float(anchor.get("radius", 9.5)), 1, 25))
		network.planted = bool(data.get("planted", false))
		network.forward_position = _read_vector(data.get("forward"), Vector3.ZERO)
		network.fuel = clampf(float(data.get("fuel", 90)), 0, network.max_fuel)
	var region := str(journey.get("region", RegionLayout.MEADOW))
	if not RegionLayout.SCENES.has(region): region = RegionLayout.MEADOW
	change_region(region, false)
	if expedition.stage <= Expedition.Stage.MARCH: _restore_workers(forest_workers)
	var at := _read_vector(journey.get("player"), camp_position)
	var area := RegionLayout.bounds(region).grow(-3)
	if not area.has_point(Vector2(at.x, at.z)) or RegionLayout.river_unsafe(at) and region == RegionLayout.MEADOW: at = camp_position
	player.position = RegionLayout.on_ground(region, at) + Vector3.UP * 0.08
	player.velocity = Vector3.ZERO
	player.health = clampf(float(journey.get("health", 100)), 1, 100)
	player.view.set_magic_focus(player.training.primary == "bolt")
	last_dry_position = player.position
	camera_rig.position = player.position + Vector3.UP * 1.25
	started = true
	restoring = false
