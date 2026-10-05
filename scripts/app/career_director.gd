class_name CareerDirector
extends Node3D
signal notice(text: String)
signal contract_reported
var progress: CareerProgress
var player: ExpeditionPlayer
var camp := Vector3(0,0,16)
var arena: Node3D
var enemies: Array[RuinGuardian] = []
var escort: ExpeditionEscort
var marker: Node3D
var caption: Label3D
var marker_index := 0
var survey_left := 0.0
var survey_health := 0.0
var defense_time := 0.0
var waves := 0
var hazard_time := 0.0
var hazard: Node3D
var hazard_center := Vector3.ZERO
var running_step := -1

func near_camp() -> bool:
	return player.global_position.distance_to(camp) < 5 and player.is_on_floor()

func choose(id: String, unlocked: bool) -> bool:
	if not near_camp() or not progress.choose(id, unlocked): return false
	_open_step()
	notice.emit("의뢰 수락 · %s  /  R: %s" % [progress.mission().title, CareerProgress.TACTICS[id]])
	return true

func clear_site() -> void:
	running_step = -1
	if is_instance_valid(arena):
		for foe in enemies:
			if is_instance_valid(foe):
				foe.clear_marker()
				foe.remove_from_group("enemies")
		arena.queue_free()
	enemies.clear()
	escort = null
	marker = null
	hazard = null
	survey_left = 0

func fail() -> void:
	if not progress.active: return
	progress.fail()
	clear_site()
	notice.emit("의뢰 중단. 완료한 승급은 유지됩니다. 전진 기지에서 K로 이번 의뢰를 다시 받으세요.")

func _open_step() -> void:
	clear_site()
	if not progress.active or progress.awaiting_report: return
	running_step = progress.step_index
	arena = Node3D.new()
	add_child(arena)
	marker_index = 0
	defense_time = 0
	waves = 0
	hazard_time = 3.0
	var task := progress.step()
	match task.kind:
		"kill":
			for at: Vector3 in task.points:
				_spawn_enemy(at, float(task.health), bool(task.get("boss", false)))
		"escort", "defend":
			escort = ExpeditionEscort.new()
			escort.player = player
			escort.mobile = task.kind == "escort"
			escort.wagon = int(task.get("waves", 0)) == 3
			escort.position = task.points[0] + Vector3(0,0.05,0)
			escort.destination = task.points[-1]
			arena.add_child(escort)
			escort.lost.connect(fail)
		_:
			_make_marker()

func _spawn_enemy(at: Vector3, hp: float = 110, leader: bool = false) -> void:
	var foe := RuinGuardian.new()
	foe.position = at + Vector3(0,0.05,0)
	foe.target = player
	foe.protected_target = escort
	foe.max_health = hp
	foe.boss = leader
	foe.title = "별문의 수문장" if leader else "원정 추격자"
	arena.add_child(foe)
	enemies.append(foe)

func _spawn_wave() -> void:
	waves += 1
	var z := clampf(escort.position.z - 3, -27, 4)
	_spawn_enemy(Vector3(-3,0,z), 96)
	_spawn_enemy(Vector3(3,0,z), 96)
	notice.emit("호송대 매복 · %d차! 공격해서 시선을 돌리거나 R 결계로 보호하세요." % waves)

func _living() -> Array[RuinGuardian]:
	return enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead")

func _make_marker() -> void:
	if is_instance_valid(marker): marker.queue_free()
	var task := progress.step()
	marker = Node3D.new()
	marker.position = task.points[marker_index]
	arena.add_child(marker)
	var tint := Color("9acfd4") if task.kind == "survey" else Color("e8c283")
	Geometry.cylinder(marker, Vector3(0,0.45,0), 0.4, 0.9, Color("778f8a"))
	var gem := Geometry.sphere(marker, Vector3(0,1.1,0), Vector3.ONE * 0.4, tint)
	gem.material_override = Geometry.material(tint, 0.6)
	Geometry.ring(marker, 1.2, tint)
	caption = Geometry.label(marker, "%s · %d/%d\nE 상호작용" % [task.text, marker_index + 1, task.points.size()], 2.4, tint)
	if task.get("guarded", false):
		_spawn_enemy(Vector3(clampf(marker.position.x + 2,-6,6),0,marker.position.z + 2), 132)

func can_reach_marker() -> bool:
	if not is_instance_valid(marker) or not player.is_on_floor(): return false
	if player.global_position.distance_to(marker.global_position) > 2.5 or absf(player.global_position.y) > 0.6: return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, marker.global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func prompt() -> String:
	if progress.awaiting_report and near_camp(): return "E · 길드에 의뢰 보고 · 승급과 보상"
	if not progress.active: return "E · 진로와 다음 의뢰 선택" if near_camp() else ""
	if can_reach_marker():
		if survey_left > 0: return "작업 중 %.1f초 · 움직이거나 피격되면 중단" % survey_left
		return "E · " + ("보급 부품 받기" if progress.step().kind == "supply" else "조사 / 장치 복구 시작")
	return ""

func interact() -> bool:
	if progress.awaiting_report and near_camp():
		if progress.report():
			clear_site()
			contract_reported.emit()
		return true
	if not progress.active or progress.awaiting_report or not can_reach_marker(): return false
	if survey_left > 0: return true
	for foe in _living():
		if foe.global_position.distance_to(player.global_position) < 5:
			notice.emit("작업장을 위협하는 적부터 막아 주세요.")
			return true
	if progress.step().kind == "supply":
		notice.emit("보급관 누리: 복구 부품을 준비했어요. 현장 작업을 부탁해요!")
		_finish_marker()
	else:
		survey_left = (1.2 if player.haste > 1 else 2.0) if progress.step().kind == "survey" else 2.5
		survey_health = player.health
	return true

func _finish_marker() -> void:
	survey_left = 0
	marker_index += 1
	if marker_index >= progress.step().points.size(): _finish_step()
	else: _make_marker()

func _finish_step() -> void:
	if not progress.advance(running_step): return
	clear_site()
	if progress.awaiting_report:
		notice.emit("의뢰 목표 완료! 전진 기지에서 E로 보고하세요.")
	else:
		_open_step.call_deferred()

func _physics_process(delta: float) -> void:
	if running_step < 0 or not progress.active or progress.awaiting_report: return
	var task := progress.step()
	if task.kind in ["escort","defend"] and waves == 0:
		# Start the encounter when the escort actually has a player beside it.
		if player.global_position.distance_to(escort.global_position) >= 8: return
		_spawn_wave()
	if task.kind == "kill":
		if _living().is_empty(): _finish_step()
	elif task.kind == "escort":
		if not is_instance_valid(escort): return
		var fraction: float = (escort.global_position.z - task.points[0].z) / (task.points[-1].z - task.points[0].z)
		if waves < int(task.waves) and fraction >= float(waves) / int(task.waves) and _living().is_empty(): _spawn_wave()
		if escort.reached and _living().is_empty() and waves >= int(task.waves): _finish_step()
	elif task.kind == "defend":
		if player.global_position.distance_to(escort.global_position) < 7: defense_time += delta
		if defense_time >= 12 and waves == 1: _spawn_wave()
		if defense_time >= float(task.seconds) and _living().is_empty(): _finish_step()
	else:
		if survey_left > 0:
			if not can_reach_marker() or player.health < survey_health or Vector2(player.velocity.x, player.velocity.z).length() > 0.2:
				survey_left = 0
				notice.emit("작업이 중단됐습니다. 안전한 위치에서 E로 다시 시작하세요.")
			else:
				survey_left -= delta
				if survey_left <= 0:
					_finish_marker()
					return
		if task.get("hazard", false): _tick_hazard(delta)

func _tick_hazard(delta: float) -> void:
	if not is_instance_valid(hazard) and player.global_position.distance_to(marker.global_position) > 12:
		hazard_time = 3.0
		return
	hazard_time -= delta
	if hazard_time <= 1.1 and not is_instance_valid(hazard):
		hazard = Node3D.new()
		arena.add_child(hazard)
		hazard_center = player.global_position
		hazard_center.y = 0.08
		hazard.global_position = hazard_center
		Geometry.ring(hazard, 2.1, Color("ec987e"))
		Geometry.cylinder(hazard, Vector3.ZERO, 2.1, 0.03, Color(0.9,0.4,0.25,0.2))
	if hazard_time <= 0:
		if player.global_position.distance_to(hazard_center) < 2.15: player.take_damage(22)
		if is_instance_valid(hazard): hazard.queue_free()
		hazard = null
		hazard_time = 4.5

func objective() -> String:
	if progress.awaiting_report: return "전진 기지에서 E · 완료한 의뢰 보고"
	if not progress.active:
		return "전진 기지에서 K · 다음 의뢰 또는 다른 진로 선택" if not progress.path.is_empty() else "전진 기지에서 K · 네 진로 중 하나 선택"
	var task := progress.step()
	var text: String = task.text
	if task.kind == "kill": text += " · 남은 적 %d" % _living().size()
	elif task.kind in ["escort", "defend"] and is_instance_valid(escort):
		text += "\n보호 대상 %d / 100" % escort.health
		if task.kind == "defend": text += " · %d / 24초" % mini(24,int(defense_time))
		elif not escort.stalled.is_empty(): text += " · " + escort.stalled
	elif is_instance_valid(marker): text += "\n표식 %d/%d · %.0fm" % [marker_index+1, task.points.size(), player.global_position.distance_to(marker.global_position)]
	return text
