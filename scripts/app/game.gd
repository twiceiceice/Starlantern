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
	var discovery := DungeonDiscoveryView.new()
	discovery.expedition = expedition
	gameplay.add_child(discovery)
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
	if "--smoke" in OS.get_cmdline_user_args(): save_enabled = false
	if save_enabled:
		var saved := ExpeditionSave.read_checkpoint()
		if not saved.is_empty(): restore_checkpoint(saved)
	get_tree().paused = true
	hud.show_menu(not started)
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke_run.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _process(delta: float) -> void:
	if not get_tree().paused and expedition.stage in [Expedition.Stage.CLEARING, Expedition.Stage.RECOVERING]:
		light.burn(delta)
	if is_instance_valid(hud):
		hud.update_state(player, title_text(), objective_text(), status_text(), interaction_prompt(), 0 if get_tree().paused else delta)
		hud.tactic_label.text = "K · 성장과 진로" if career.path.is_empty() else "R · %s%s  /  K 성장과 진로" % [CareerProgress.TACTICS[career.path],"  %.1f초" % arts.tactic_cooldown if arts.tactic_cooldown > 0 else " 준비",]

func _unhandled_input(event: InputEvent) -> void:
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
	if get_tree().paused:
		return
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
	for i in range(3):
		Geometry.box(gameplay, Vector3(-3.5 + i * 0.85, 0.34, 18), Vector3(0.75, 0.68, 0.75), Color("bd955e"))
	var sign := Node3D.new()
	gameplay.add_child(sign)
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
	hud.growth.show_state({"career":career,"training":player.training,"unlocked":expedition.stage == Expedition.Stage.COMPLETE,"at_camp":missions.near_camp()})

func close_growth() -> void:
	hud.growth.visible = false
	match growth_return:
		"journal": hud.journal.visible = true
		"menu": hud.show_menu(not started)
		_: resume()

func _choose_career(id: String) -> void:
	if missions.choose(id,expedition.stage == Expedition.Stage.COMPLETE):
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
	if not save_enabled or expedition.stage != Expedition.Stage.COMPLETE: return
	var result := ExpeditionSave.write_checkpoint(career,player.training,expedition.resources,ExpeditionSave.PATH,{"people":director.caravan.people,"food":director.caravan.food})
	if result != OK: hud.notify("저장하지 못했습니다. 저장 공간과 파일 권한을 확인해 주세요.")

func restore_checkpoint(saved: Dictionary) -> void:
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
