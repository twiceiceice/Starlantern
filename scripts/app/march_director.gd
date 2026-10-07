class_name MarchDirector
extends Node3D
## Runs the march and the base construction. Each leg the player takes one quest from the
## board; its role picks which chain of MarchPlan steps the player does. NPC crews do the
## other role's chain, slower and at a cost:
##   lamplighters light a lantern step after a delay, scouts finish a visit step after a delay,
##   guards remove one guardian per delay and lose people.
## When both chains of a stretch are done the caravan marches to the checkpoint, and the
## next stretch's steps open only once it arrives.

signal departed
signal notice(text: String)
signal base_completed
signal checkpoint_reached

const SPOT_RADIUS := 19.0
const THREAT_RANGE := 14.0
const LAMPLIGHTER_DELAY := 6.0
const SCOUT_DELAY := 7.0
const GUARD_DELAY := 8.0
const GUARD_COST := 3
const VISIT_REACH := 2.5
const BUILD_RATE := 1.25
const CRATE_BUILD := 10.0
const REACH := 2.0
const BASE_CENTER := Vector3(0, 0, 16)
const RAIDER_SPOTS := [Vector3(-11, 0, 22), Vector3(11, 0, 22)]
const ROLE_CREWS := {"clear": "경비대", "light": "등불꾼"}

var expedition: Expedition
var light: LanternNetwork
var player: ExpeditionPlayer
var caravan := Caravan.new(RegionLayout.route())
var region := RegionLayout.MEADOW
var crossing_ready := false
var board := QuestBoard.new()
var plan := MarchPlan.new()
var base_center := BASE_CENTER
var crate_pile := Vector3(-5, 0, 26.5)
var drop_site := Vector3(-3.5, 0, 13.5)
var halt_reason := "choice"
var halt_time := 0.0
var advancing := false
var posts: Array[Dictionary] = []
## Per role: the open step and what it spawned ({step, enemies, spots, marker, npc_time}).
var active := {"clear": {}, "light": {}}
var march_enemies: Array[RuinGuardian] = []
var raiders: Array[RuinGuardian] = []
var caravan_view: CaravanView
var settlement: SettlementView

func _ready() -> void:
	plan.route = caravan
	caravan_view = CaravanView.new()
	caravan_view.caravan = caravan
	caravan_view.follow_terrain = region == RegionLayout.MEADOW
	caravan_view.settle_center = BASE_CENTER
	caravan_view.settled = region == RegionLayout.FOREST
	add_child(caravan_view)
	caravan_view.visible = region == RegionLayout.FOREST or expedition.stage <= Expedition.Stage.MARCH
	if region == RegionLayout.FOREST:
		settlement = SettlementView.new()
		settlement.position = BASE_CENTER
		add_child(settlement)
		if is_instance_valid(settlement): settlement.set_progress(expedition.base_progress, expedition.stage == Expedition.Stage.BASE)
		if expedition.stage == Expedition.Stage.BASE: _base_supplies()
	elif expedition.stage == Expedition.Stage.CAMP:
		_spawn_posts(caravan.route[0] + Vector3(0, 0, -3))

func _spawn_guardian(at: Vector3, title: String, health: float) -> RuinGuardian:
	var guardian := RuinGuardian.new()
	guardian.title = title
	guardian.max_health = health
	guardian.position = at + Vector3(0, 0.05, 0)
	guardian.target = player
	add_child(guardian)
	return guardian

func step_enemies(role: String) -> Array:
	return active[role].get("enemies", [])

## Unlit lantern spots of the role's open step.
func step_spots(role: String) -> Array:
	var list := []
	for spot in active[role].get("spots", []):
		if not spot.lit:
			list.append(spot.position)
	return list

# --- Simulation ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	caravan_view.moving = false
	if region == RegionLayout.MEADOW and expedition.stage >= Expedition.Stage.BASE: return
	match expedition.stage:
		Expedition.Stage.MARCH:
			if crossing_ready: return
			caravan.consume(delta)
			_march(delta)
		Expedition.Stage.BASE:
			caravan.consume(delta)
			_build(delta)
	if is_instance_valid(settlement): settlement.set_progress(expedition.base_progress, expedition.stage == Expedition.Stage.BASE)

func _halt(reason: String, delta: float) -> void:
	halt_time = halt_time + delta if reason == halt_reason else 0.0
	halt_reason = reason

func _march(delta: float) -> void:
	if board.chosen.is_empty():
		_halt("choice", delta)
		return
	if not advancing:
		_halt("task", delta)
		for role in MarchPlan.ROLES:
			_update_step(role, delta)
		if plan.stretch_done():
			advancing = true
			notice.emit("준비 완료! 원정대가 다음 지점으로 전진합니다.")
		return
	if caravan.distance >= plan.checkpoint() - 0.001:
		_arrive()
		return
	var threat := _nearest_threat()
	if threat:
		_halt("threat", delta)
		if halt_time >= GUARD_DELAY:
			threat.take_damage(10000, Vector3.ZERO)
			caravan.lose(GUARD_COST)
			halt_time = 0
		return
	if caravan.advance(delta, plan.checkpoint(), light.is_lit):
		_halt("", delta)
		caravan_view.moving = true
	else:
		_halt("dark", delta)

func _arrive() -> void:
	advancing = false
	if plan.leg_finished():
		_finish_leg()
		return
	plan.next_stretch()
	_open_steps()
	checkpoint_reached.emit()
	var next: Dictionary = plan.active_step(board.role())
	notice.emit("행렬이 다음 지점에 도착했습니다.  다음 일: %s" % next.get("text", "원정대 작업 대기"))

func _open_steps() -> void:
	for role in MarchPlan.ROLES:
		_activate(role)

func _activate(role: String) -> void:
	var step := plan.active_step(role)
	active[role] = {}
	if step.is_empty():
		return
	var open := {"step": step, "enemies": [], "spots": [], "marker": null, "npc_time": 0.0}
	match step.kind:
		"kill":
			for at: Vector3 in step.enemies:
				var chief: bool = step.get("chief", false)
				var guardian := _spawn_guardian(at, "파수꾼 우두머리" if chief else "길목 파수꾼", 180 if chief else 96)
				open.enemies.append(guardian)
				march_enemies.append(guardian)
		"light":
			for at: Vector3 in step.spots:
				open.spots.append({"position": at, "lit": false, "marker": _spot_marker(at)})
		"visit":
			open.marker = _visit_marker(step.at, step.text)
	active[role] = open

func _update_step(role: String, delta: float) -> void:
	var open: Dictionary = active[role]
	if open.is_empty():
		return
	var npc := role != board.role()
	var step: Dictionary = open.step
	var done := false
	match step.kind:
		"kill":
			var alive: Array = open.enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead")
			done = alive.is_empty()
			if not done and npc:
				open.npc_time += delta
				if open.npc_time >= GUARD_DELAY:
					alive[0].take_damage(10000, Vector3.ZERO)
					caravan.lose(GUARD_COST)
					open.npc_time = 0.0
					notice.emit("경비대가 파수꾼을 몰아냈습니다  ·  %d명 부상 이탈" % GUARD_COST)
		"light":
			done = open.spots.all(func(s): return s.lit)
			if not done and npc:
				open.npc_time += delta
				if open.npc_time >= LAMPLIGHTER_DELAY:
					for spot in open.spots:
						_light_spot(spot)
					notice.emit("등불꾼: %s" % step.text)
		"visit":
			if npc:
				open.npc_time += delta
				done = open.npc_time >= SCOUT_DELAY
				if done:
					notice.emit("정찰대: %s 완료" % step.text)
			else:
				done = _near(step.at, VISIT_REACH)
	if not done:
		return
	if is_instance_valid(open.marker):
		open.marker.queue_free()
	plan.complete_step(role)
	if not npc:
		var next := plan.active_step(role)
		notice.emit("완료: %s" % step.text + ("  →  다음: %s" % next.text if not next.is_empty() else ""))
	_activate(role)

func _nearest_threat() -> RuinGuardian:
	var best: RuinGuardian
	var best_gap := THREAT_RANGE
	var front := caravan.front()
	for enemy in march_enemies:
		if is_instance_valid(enemy) and enemy.state != "dead":
			var gap := Vector2(enemy.global_position.x - front.x, enemy.global_position.z - front.z).length()
			if gap < best_gap:
				best = enemy
				best_gap = gap
	return best

func _finish_leg() -> void:
	var leg_name: String = MarchPlan.LEGS[plan.leg].name
	board.finish_stage()
	halt_reason = "choice"
	halt_time = 0
	if plan.has_next_leg():
		plan.next_leg(false)
		notice.emit("%s 통과! 게시판에서 다음 구간의 일을 고르세요." % leg_name)
		_spawn_posts(caravan.front() + Vector3(0, 0, -2.5))
		checkpoint_reached.emit()
		return
	crossing_ready = true
	halt_reason = "crossing"
	_clear_posts()
	notice.emit("도하 완료! 다리 건너 표지판에서 E · 숲의 전진 기지로 이동합니다.")
	checkpoint_reached.emit()

func _base_supplies() -> void:
	light.add_anchor(BASE_CENTER, 9.5)
	_spawn_posts(BASE_CENTER + Vector3(0, 0, 7.5))
	var pile := Node3D.new()
	add_child(pile)
	pile.position = crate_pile
	for i in range(3):
		var crate := CampArt.place(pile, "single_crate", Vector3((i - 1) * 0.8, 0, 0), false)
		crate.scale = Vector3(.72, .7, .72)
	var top := CampArt.place(pile, "single_crate", Vector3(-0.4, .73, 0), false)
	top.scale = Vector3(.72, .7, .72)
	Geometry.label(pile, "기지 자재", 1.9, Color("f7e1af"))
	var drop := Node3D.new()
	add_child(drop)
	drop.position = drop_site
	Geometry.ring(drop, 1.1, Color("f2d28e"), 0.06)
	Geometry.label(drop, "자재 하치장", 1.3, Color("f7e1af"))

func _build(delta: float) -> void:
	if board.done():
		return
	if board.chosen.is_empty():
		_halt("choice", delta)
		return
	var alive := raiders.filter(func(r): return is_instance_valid(r) and r.state != "dead")
	if not alive.is_empty():
		_halt("raid", delta)
		if board.role() != "defend" and halt_time >= GUARD_DELAY:
			alive[0].take_damage(10000, Vector3.ZERO)
			caravan.lose(GUARD_COST)
			halt_time = 0
			notice.emit("경비대가 습격자를 막았습니다  ·  %d명 부상 이탈" % GUARD_COST)
		return
	_halt("build", delta)
	if expedition.base_build(BUILD_RATE * delta):
		_complete_base()

func _complete_base() -> void:
	board.finish_stage()
	halt_reason = ""
	settlement.set_progress(100, false)
	notice.emit("돌아올 기지가 생겼습니다! 북쪽 별잠회랑의 입구를 확보하세요.")
	base_completed.emit()
	checkpoint_reached.emit()

# --- Player interaction -------------------------------------------------------

func prompt() -> String:
	if region == RegionLayout.MEADOW and expedition.stage >= Expedition.Stage.BASE: return ""
	var post := _near_post()
	if not post.is_empty():
		var quest: Dictionary = QuestBoard.QUESTS[post.quest]
		return "E  ·  [%s] %s 맡기" % [QuestBoard.ROLE_NAMES[quest.role], quest.title]
	if not _near_spot().is_empty():
		return "E  ·  등불 자리에 등불 세우기"
	if expedition.stage == Expedition.Stage.BASE and board.role() == "carry":
		if not player.carrying and _near(crate_pile, REACH + 0.5):
			return "E  ·  기지 자재 들기"
		if player.carrying and _near(drop_site, REACH):
			return "E  ·  자재 내려놓기  (건설 +%d%%)" % CRATE_BUILD
	return ""

func interact() -> bool:
	if region == RegionLayout.MEADOW and expedition.stage >= Expedition.Stage.BASE: return false
	var post := _near_post()
	if not post.is_empty():
		_choose(post.quest)
		return true
	var spot := _near_spot()
	if not spot.is_empty():
		_light_spot(spot)
		return true
	if expedition.stage == Expedition.Stage.BASE and board.role() == "carry":
		if not player.carrying and _near(crate_pile, REACH + 0.5):
			player.carrying = true
			return true
		if player.carrying and _near(drop_site, REACH):
			player.carrying = false
			if expedition.base_build(CRATE_BUILD):
				_complete_base()
			return true
	return false

func _choose(id: String) -> void:
	if not board.choose(id):
		return
	_clear_posts()
	halt_time = 0
	var quest: Dictionary = QuestBoard.QUESTS[id]
	if expedition.stage == Expedition.Stage.CAMP:
		expedition.start()
		departed.emit()
	if expedition.stage == Expedition.Stage.MARCH:
		plan.chief = quest.get("chief", false)
		_open_steps()
	if expedition.stage == Expedition.Stage.BASE:
		for at: Vector3 in RAIDER_SPOTS:
			raiders.append(_spawn_guardian(at, "습격자", 96))
	checkpoint_reached.emit()
	var first: Dictionary = plan.active_step(quest.role) if expedition.stage == Expedition.Stage.MARCH else {}
	notice.emit("[%s] %s  ·  %s" % [QuestBoard.ROLE_NAMES[quest.role], quest.title, first.get("text", quest.detail.get_slice("\n", 0))])

func _light_spot(spot: Dictionary) -> void:
	if spot.lit:
		return
	spot.lit = true
	spot.marker.queue_free()
	light.add_anchor(spot.position, SPOT_RADIUS)
	LanternGlow.post(self, spot.position + Vector3(1.8, 0, 0))

func _near(at: Vector3, reach: float) -> bool:
	return Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < reach

func _near_post() -> Dictionary:
	for post in posts:
		if _near(post.position, REACH):
			return post
	return {}

func _near_spot() -> Dictionary:
	if expedition.stage != Expedition.Stage.MARCH or board.role() != "light":
		return {}
	for spot in active.light.get("spots", []):
		if not spot.lit and _near(spot.position + Vector3(1.8, 0, 0), REACH + 0.6):
			return spot
	return {}

# --- Board and markers --------------------------------------------------------

func _spawn_posts(at: Vector3) -> void:
	var offers := board.offers()
	for i in offers.size():
		var spot := RegionLayout.on_ground(region, at + Vector3(-3.2 if i == 0 else 3.2, 0, 0))
		var node := Node3D.new()
		add_child(node)
		node.position = spot
		var quest: Dictionary = QuestBoard.QUESTS[offers[i]]
		Geometry.cylinder(node, Vector3(0, 0.8, 0), 0.07, 1.6, Color("7a6247"))
		var board_color := Color("e7c98a") if quest.role in ["clear", "defend"] else Color("cfe0b8")
		Geometry.box(node, Vector3(0, 1.45, 0.02), Vector3(1.1, 0.75, 0.08), board_color)
		var caption := Geometry.label(node, "[%s]\n%s" % [QuestBoard.ROLE_NAMES[quest.role], quest.title], 2.6, Color("fff1cf"))
		caption.pixel_size = 0.01
		posts.append({"quest": offers[i], "position": spot, "node": node})

func _clear_posts() -> void:
	for post in posts:
		post.node.queue_free()
	posts.clear()

func _spot_marker(at: Vector3) -> Node3D:
	# Lantern spots sit just beside the road so the caravan never walks through the post.
	var marker := Node3D.new()
	add_child(marker)
	marker.position = at + Vector3(1.8, 0, 0)
	Geometry.cylinder(marker, Vector3(0, 0.45, 0), 0.05, 0.9, Color("7a6247"))
	Geometry.box(marker, Vector3(0.18, 0.8, 0), Vector3(0.3, 0.18, 0.03), Color("e8a066"))
	Geometry.ring(marker, 0.9, Color(1.0, 0.85, 0.55, 0.6), 0.04)
	return marker

func _visit_marker(at: Vector3, text: String) -> Node3D:
	var marker := Node3D.new()
	add_child(marker)
	marker.position = at
	Geometry.cylinder(marker, Vector3(0, 1.1, 0), 0.05, 2.2, Color("7a6247"))
	Geometry.box(marker, Vector3(0.28, 1.95, 0), Vector3(0.5, 0.3, 0.03), Color("8fb7c9"))
	Geometry.ring(marker, VISIT_REACH - 0.4, Color(0.6, 0.85, 0.95, 0.6), 0.04)
	var caption := Geometry.label(marker, "조사 · %s" % text, 2.7, Color("dff1f7"))
	caption.pixel_size = 0.008
	return marker

# --- HUD text -----------------------------------------------------------------

func title() -> String:
	if expedition.stage == Expedition.Stage.BASE:
		return "02   /   전진 기지"
	return "01   /   행군 · %s" % MarchPlan.LEGS[plan.leg].name

func objective() -> String:
	if crossing_ready and expedition.stage == Expedition.Stage.MARCH: return "도하 완료 · 강 건너 표지판에서 E\n숲의 전진 기지로 이동 · 후미는 뒤따라 합류합니다"
	if expedition.stage == Expedition.Stage.CAMP:
		return "출발 게시판에서 E · 맡을 일 고르기\n원정대 %d명이 출발을 기다립니다" % caravan.people
	if board.chosen.is_empty():
		var where := "기지 터 도착" if expedition.stage == Expedition.Stage.BASE else "행렬 대기"
		return "%s  ·  게시판에서 E · 다음 일 고르기" % where
	var quest := board.quest()
	var head := "[%s] %s" % [QuestBoard.ROLE_NAMES[quest.role], quest.title]
	if expedition.stage == Expedition.Stage.BASE:
		var state := "습격 중 · 건설 멈춤" if halt_reason == "raid" else "건설 중"
		return "%s\n건설 %d%%  ·  %s" % [head, expedition.base_progress, state]
	var role := board.role()
	head += "  ·  단계 %d / %d" % [plan.step_number(role), plan.step_total(role)]
	if advancing:
		var state := "행렬 전진 중  →  다음 지점"
		if halt_reason == "dark":
			state = "행렬 정지 · 앞길이 어둡습니다"
		elif halt_reason == "threat":
			state = "행렬 정지 · 앞길에 파수꾼"
		return "%s\n%s" % [head, state]
	var open: Dictionary = active[role]
	if open.is_empty():
		var other := "light" if role == "clear" else "clear"
		var waiting: Dictionary = active[other].get("step", {})
		return "%s\n원정대 작업 대기 · %s: %s" % [head, ROLE_CREWS[other], waiting.get("text", "")]
	var step: Dictionary = open.step
	var tally := ""
	if step.kind == "kill":
		tally = "  %d / %d" % [open.enemies.filter(func(e): return not is_instance_valid(e) or e.state == "dead").size(), open.enemies.size()]
	elif step.kind == "light":
		tally = "  %d / %d" % [open.spots.filter(func(s): return s.lit).size(), open.spots.size()]
	return "%s\n%s%s" % [head, step.text, tally]

func status() -> String:
	return "%d명 · 짐노새 %d · 짐소 %d · 마차 %d · 식량 %d" % [caravan.people, caravan.mules, caravan.oxen, caravan.wagons, caravan.food]

## Scene-independent march checkpoint. Dead enemies and lit spots are retained so
## reloading never charges the NPC guard loss twice for the same completed work.
func to_data() -> Dictionary:
	var tasks := {}
	for role in MarchPlan.ROLES:
		var task: Dictionary = active[role]
		var health := []
		for foe in task.get("enemies", []):
			health.append(foe.health if is_instance_valid(foe) and foe.state != "dead" else 0.0)
		var lit := []
		for spot in task.get("spots", []): lit.append(spot.lit)
		tasks[role] = {"health": health, "lit": lit, "npc_time": task.get("npc_time", 0.0)}
	var raid_health := []
	for foe in raiders: raid_health.append(foe.health if is_instance_valid(foe) and foe.state != "dead" else 0.0)
	return {"board_stage": board.stage, "chosen": board.chosen, "unlocked": board.unlocked,
		"leg": plan.leg, "stretch": plan.stretch, "chief": plan.chief, "progress": plan.progress.duplicate(),
		"advancing": advancing, "crossing_ready": crossing_ready, "tasks": tasks, "raiders": raid_health}

func restore_data(data: Dictionary) -> void:
	_clear_posts()
	plan.leg = clampi(int(data.get("leg", 0)), 0, MarchPlan.LEGS.size() - 1)
	plan.stretch = clampi(int(data.get("stretch", 0)), 0, MarchPlan.LEGS[plan.leg].stretches.size() - 1)
	plan.chief = bool(data.get("chief", false))
	var progress_data: Dictionary = data.get("progress", {}) if data.get("progress", {}) is Dictionary else {}
	for role in MarchPlan.ROLES: plan.progress[role] = clampi(int(progress_data.get(role, 0)), 0, plan.steps(role).size())
	board.stage = clampi(int(data.get("board_stage", 0)), 0, 3)
	board.unlocked.clear()
	for id in data.get("unlocked", []):
		if id is String and QuestBoard.QUESTS.has(id): board.unlocked.append(id)
	var chosen: String = str(data.get("chosen", ""))
	board.chosen = chosen if chosen in board.offers() else ""
	crossing_ready = bool(data.get("crossing_ready", false))
	advancing = bool(data.get("advancing", false)) and plan.stretch_done()
	if region == RegionLayout.MEADOW and expedition.stage >= Expedition.Stage.BASE: return
	if expedition.stage == Expedition.Stage.MARCH and not crossing_ready and not board.chosen.is_empty():
		_open_steps()
		var tasks: Dictionary = data.get("tasks", {}) if data.get("tasks", {}) is Dictionary else {}
		for role in MarchPlan.ROLES:
			if active[role].is_empty(): continue
			var task: Dictionary = tasks.get(role, {}) if tasks.get(role, {}) is Dictionary else {}
			active[role]["npc_time"] = clampf(float(task.get("npc_time", 0)), 0, GUARD_DELAY)
			var health: Array = task.get("health", []) if task.get("health", []) is Array else []
			for i in mini(health.size(), active[role].get("enemies", []).size()):
				var foe: RuinGuardian = active[role].enemies[i]
				if float(health[i]) <= 0: foe.take_damage(10000, Vector3.ZERO)
				else: foe.health = clampf(float(health[i]), 1, foe.max_health)
			var lit: Array = task.get("lit", []) if task.get("lit", []) is Array else []
			for i in mini(lit.size(), active[role].get("spots", []).size()):
				if lit[i]: _light_spot(active[role].spots[i])
	elif expedition.stage == Expedition.Stage.BASE and not board.chosen.is_empty():
		var health: Array = data.get("raiders", []) if data.get("raiders", []) is Array else []
		for i in health.size():
			if i >= RAIDER_SPOTS.size(): break
			if float(health[i]) > 0:
				var foe := _spawn_guardian(RAIDER_SPOTS[i], "습격자", 96)
				foe.health = clampf(float(health[i]), 1, 96)
				raiders.append(foe)
	elif expedition.stage in [Expedition.Stage.CAMP, Expedition.Stage.MARCH, Expedition.Stage.BASE] and not crossing_ready:
		_spawn_posts((BASE_CENTER + Vector3(0, 0, 7.5)) if region == RegionLayout.FOREST else caravan.front() + Vector3(0, 0, -2.5))
	elif expedition.stage == Expedition.Stage.BASE and board.chosen.is_empty():
		_spawn_posts(BASE_CENTER + Vector3(0, 0, 7.5))
