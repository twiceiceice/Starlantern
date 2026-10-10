extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func _run() -> void:
	CharacterArtTests.run(self, check)
	await CharacterArtTests.contacts(self, check)
	_test_rules()
	_test_expedition()
	_test_lanterns()
	_test_caravan()
	_test_quest_board()
	_test_march_plan()
	await _test_caravan_view()
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_enabled = false
	root.add_child(game)
	current_scene = game
	await _test_journal(game)
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(10)
	await CampArtTests.run(game, check)
	var player: ExpeditionPlayer = game.player
	check(player.is_on_floor(), "Player lands on the native physics floor")
	var start := player.position
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	var traveled := start.z - player.position.z
	check(traveled > 4.0 and traveled < 5.1, "W moves forward at the configured walk speed")
	await frames(12)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(13)
	check(player.position.y > 0.7, "Jump leaves the floor")
	await frames(80)
	check(player.is_on_floor() and player.position.y < 0.1, "Jump lands without sinking through the floor")
	player.position = Vector3(2.8, 0.1, 0)
	player.velocity = Vector3.ZERO
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	check(player.position.x < 3.75, "Bridge railing blocks walking into the river")
	player.position = Vector3(3.9, 0.1, 153)
	game.camera_rig.yaw = PI / 2
	await frames(30)
	check(game.camera_rig.arm.get_hit_length() < game.camera_rig.distance - 1, "Camera spring arm shortens before a wall")
	game.camera_rig.yaw = 0
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(80, 20)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		check(game.camera_rig.yaw < -0.2 and game.camera_rig.pitch < -0.38, "Mouse motion rotates camera yaw and pitch")
	else:
		print("SKIP: captured mouse motion needs a native display; covered by capture_scene.gd")
	game.camera_rig.yaw = 0
	game.camera_rig.pitch = -0.48
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.respawn(Vector3(0, 0.1, 10))
	await frames(10)
	check(player.try_attack("slash"), "Basic attack can start")
	check(not player.try_dodge(Vector3.RIGHT), "Windup is not accidentally cancelled by dodge")
	await frames(13)
	check(player.try_dodge(Vector3.RIGHT), "Dodge cancels recovery after the attack hits")
	check(not player.take_damage(18), "Dodge invulnerability prevents damage")
	await frames(21)
	check(player.try_dodge(Vector3.LEFT), "Second dodge charge is available")
	await frames(21)
	check(not player.try_dodge(Vector3.LEFT), "Dodge cannot use a third charge")
	check(player.take_damage(18), "Damage returns after dodge invulnerability ends")
	await frames(150)
	check(player.dodge_charges >= 1, "Dodge charges recover over time")
	await _test_march(game, player)
	# Run the real expedition actors through navigation, work and delivery.
	# Workers follow only while their destination is lit; the ruin beyond the road lamps is dark.
	player.invulnerability = 100
	player.position = Vector3(0, 0.05, -20)
	await frames(360)
	for worker: ExpeditionWorker in game.workers:
		check(game.light.is_lit(worker.global_position) and worker.position.z > -12.5, "Worker stops at the edge of the light: " + worker.name)
	for enemy: RuinGuardian in get_nodes_in_group("enemies"):
		enemy.reset_encounter()
	player.respawn(Vector3(0, 0.05, -7))
	await frames(10)
	var first_guardian: RuinGuardian = get_nodes_in_group("enemies")[0]
	player.position = first_guardian.position + Vector3(0, 0, 2)
	player.camera_yaw = 0
	player.slam_cooldown = 0
	check(player.try_attack("slam"), "Heavy attack starts near a real enemy")
	await frames(25)
	check(first_guardian.health == 48, "Heavy attack applies its damage once at the impact frame")
	# The telegraph is fixed to the target location at cast time, allowing escape.
	first_guardian.clear_marker()
	first_guardian.begin_attack()
	var telegraph_center := first_guardian.marker_center
	player.position += Vector3(5, 0, 0)
	player.invulnerability = 0
	var previous_health := player.health
	await frames(60)
	check(telegraph_center.distance_to(player.position) > 3 and player.health == previous_health, "Leaving the locked ground telegraph avoids damage")
	for enemy: RuinGuardian in get_nodes_in_group("enemies"):
		enemy.take_damage(1000, Vector3.ZERO)
	check(game.expedition.stage == Expedition.Stage.RECOVERING, "Clearing the site unlocks recovery")
	await frames(600)
	for worker: ExpeditionWorker in game.workers:
		check(worker.state not in ["working", "returning", "delivered"], "Worker does not work in the dark ruin: " + worker.name)
	check("등불" in game.expedition.objective(false), "Objective asks for a forward lantern while the site is dark")
	player.position = ExpeditionCampaign.RECORD_POSITION + Vector3(0, 0.05, 2)
	player.velocity = Vector3.ZERO
	await frames(3)
	game.interact()
	check(game.light.planted and not game.expedition.entrance_record, "First interaction at a dark record plants a lantern instead of reading it")
	player.position = game.camp_position + Vector3(8, 0.05, 0)
	check(not game.light.can_plant(player.global_position), "Forward lantern cannot be planted inside the camp light")
	player.position = Vector3(0, 0.05, -24)
	await frames(2)
	check("등불" in game.interaction_prompt(), "Ruin center offers to plant the forward lantern")
	game.interact()
	check(game.light.planted and game.light.is_lit(Vector3(4, 0, -24)) and game.light.is_lit(Vector3(-4, 0, -24)), "Planted lantern lights both work sites")
	check(not game.expedition.entrance_record, "Interacting out of record range does not collect it")
	var waited := 0
	while waited < 900 and not game.workers.any(func(w): return w.state == "working"):
		await frames(10)
		waited += 10
	var dimmed: ExpeditionWorker
	for worker: ExpeditionWorker in game.workers:
		if worker.state == "working":
			dimmed = worker
	check(dimmed != null, "Workers walk into the lit ruin and start working")
	if dimmed:
		var full_radius: float = game.light.forward_radius()
		game.light.burn(game.light.max_fuel)
		check(game.light.forward_radius() < full_radius and not game.light.is_lit(dimmed.work_position), "Empty lantern shrinks away from the work site")
		await frames(2)
		var paused_progress := dimmed.progress
		await frames(90)
		check(dimmed.state == "waiting" and is_equal_approx(dimmed.progress, paused_progress), "Work pauses, keeping progress, when the light leaves it")
	player.position = game.camp_position
	await frames(2)
	check("기름" in game.interaction_prompt(), "Camp offers to refill lantern oil during the expedition")
	game.interact()
	check(is_equal_approx(game.light.fuel, game.light.max_fuel), "Camp interaction refills the forward lantern")
	await frames(2000)
	for worker: ExpeditionWorker in game.workers:
		check(worker.state == "delivered", "Worker navigates to resources, works and returns: " + worker.name)
	check(game.expedition.stage == Expedition.Stage.RECOVERING and not game.expedition.report(), "Both samples still require the player's survey before reporting")
	player.position = ExpeditionCampaign.RECORD_POSITION + Vector3(0, 1.2, 1)
	player.velocity = Vector3.ZERO
	await frames(2)
	game.interact()
	check(not game.expedition.entrance_record, "The record cannot be collected while airborne")
	player.position = ExpeditionCampaign.RECORD_POSITION + Vector3(0, 0.05, 2)
	player.velocity = Vector3.ZERO
	var obstruction := Geometry.solid_box(game.gameplay, ExpeditionCampaign.RECORD_POSITION + Vector3(0, 1, 1), Vector3(1, 2, 0.2), Color.GRAY)
	await frames(3)
	game.interact()
	check(not game.expedition.entrance_record, "The record cannot be collected through a wall")
	obstruction.queue_free()
	await frames(3)
	check("기록 확보" in game.interaction_prompt(), "The lit record advertises its survey interaction")
	game.interact()
	check(game.expedition.entrance_record and game.expedition.stage == Expedition.Stage.REPORT, "Surveying the lit record after both deliveries unlocks the report")
	player.position = Vector3(0, 0.05, -8)
	game.interact()
	check(game.expedition.stage == Expedition.Stage.REPORT, "Cannot claim rewards away from camp")
	player.position = game.camp_position
	game.interact()
	check(game.expedition.resources.timber == 12 and game.expedition.resources.crystal == 6, "Camp report grants the expedition resources")
	check(paused and game.hud.journal.visible and "대장정 완료" in game.hud.journal_title.text, "Reporting opens the completed campaign journal and pauses the game")
	game.close_journal()
	check(not paused and not game.hud.journal.visible, "Closing the ending returns to the completed world")
	game.interact()
	check(game.expedition.resources.timber == 12, "Repeated camp interaction does not duplicate rewards")
	# Pause freezes actors and their cooldowns, then resumes cleanly.
	player.slam_cooldown = 3
	game.pause()
	var paused_position := player.position
	Input.action_press("move_forward")
	await frames(15)
	check(player.position == paused_position and player.slam_cooldown == 3, "Pause freezes movement and cooldowns")
	Input.action_release("move_forward")
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(15)
	check(player.slam_cooldown < 3, "Resume restarts simulation")
	await ForestTests.run(game,check,frames)
	await CareerTests.run(game,check,frames)
	await RegionTests.run(game,check,frames)
	game.free()
	print("TEST_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print("  - ", failure)
	quit(0 if failures.is_empty() else 1)

func journal_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _test_journal(game) -> void:
	await frames(2)
	journal_key(KEY_J)
	await frames(2)
	check(paused and game.hud.journal.visible and not game.hud.menu.visible, "J opens the campaign briefing from the initial menu")
	journal_key(KEY_ESCAPE)
	await frames(2)
	check(paused and game.hud.menu.visible and not game.started, "Closing the initial journal returns to the menu without starting")
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(3)
	game.player.slam_cooldown = 3
	journal_key(KEY_J)
	await frames(2)
	var at: Vector3 = game.player.position
	var food: float = game.director.caravan.food
	Input.action_press("move_forward")
	await frames(20)
	Input.action_release("move_forward")
	check(paused and game.player.position == at and game.player.slam_cooldown == 3 and game.director.caravan.food == food, "Reading the journal freezes movement, cooldowns and caravan resources")
	check(game.expedition.stage == Expedition.Stage.CAMP and not game.expedition.entrance_record, "Reading the journal never advances the campaign or reveals its record")
	journal_key(KEY_J)
	await frames(2)
	check(not paused and not game.hud.journal.visible, "J closes the journal and resumes active play")
	game.pause()
	game.hud.journal_requested.emit()
	await frames(2)
	game.hud.journal_closed.emit()
	check(paused and game.hud.menu.visible and not game.hud.journal.visible, "Menu journal buttons preserve an existing pause")

func _test_rules() -> void:
	check(is_equal_approx(CombatRules.move_direction(Vector2(1, -1), 0).length(), 1), "Diagonal movement is normalized")
	check(CombatRules.move_direction(Vector2(0, -1), PI / 2).is_equal_approx(Vector3.LEFT), "Movement follows camera yaw")
	check(CombatRules.within_arc(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -2), 3, 110), "Attack can hit a target in front")
	check(not CombatRules.within_arc(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 2), 3, 110), "Attack cannot hit a target behind")
	check(not CombatRules.within_arc(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -4), 3, 110), "Attack respects range")
	check(not CombatRules.within_arc(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 4, -1), 3, 110), "Attack respects vertical separation")

func choose(game, quest: String) -> bool:
	for post: Dictionary in game.director.posts:
		if post.quest == quest:
			game.player.position = post.position + Vector3(0, 0.05, 1.2)
			await frames(2)
			game.interact()
			return true
	return false

func wait_until(condition: Callable, limit: int) -> bool:
	var waited := 0
	while waited < limit and not condition.call():
		await frames(10)
		waited += 10
	return condition.call()

## Finishes the player's active step the way a player would, then lets the director notice.
func do_player_step(game, role: String) -> void:
	var director: MarchDirector = game.director
	var step: Dictionary = director.plan.active_step(role)
	match step.get("kind", ""):
		"kill":
			for enemy: RuinGuardian in director.step_enemies(role):
				if is_instance_valid(enemy):
					enemy.take_damage(1000, Vector3.ZERO)
		"light":
			for spot: Vector3 in director.step_spots(role):
				game.player.position = spot + Vector3(0, 0.05, 1)
				await frames(2)
				game.interact()
		"visit":
			game.player.position = step.at + Vector3(0, 0.05, 0.5)
	await frames(5)
	game.player.position = director.caravan.front() + Vector3(9, 0.05, 0)

## Plays one leg as `role`: does each player step, and checks the caravan marches to the
## next checkpoint between stretches before the next steps open.
func play_leg(game, role: String) -> Dictionary:
	var director: MarchDirector = game.director
	var plan: MarchPlan = director.plan
	var result := {"advanced": 0, "stretches": 0, "waited_for_arrival": true, "npc_done": true}
	var leg := plan.leg
	while plan.leg == leg and game.expedition.stage == Expedition.Stage.MARCH and not director.crossing_ready:
		var stretch := plan.stretch
		var start: float = director.caravan.distance
		var guard := 0
		while not plan.active_step(role).is_empty() and guard < 12:
			await do_player_step(game, role)
			guard += 1
		var moved := await wait_until(func(): return director.crossing_ready or plan.leg != leg or plan.stretch != stretch or game.expedition.stage != Expedition.Stage.MARCH, 4200)
		if not moved:
			result.npc_done = false
			break
		result.stretches += 1
		if director.caravan.distance > start + 1.0:
			result.advanced += 1
		if not director.crossing_ready and plan.leg == leg and absf(director.caravan.distance - plan.previous_checkpoint()) > 0.05:
			result.waited_for_arrival = false
	return result

func _test_march(game, player: ExpeditionPlayer) -> void:
	var director: MarchDirector = game.director
	var caravan: Caravan = director.caravan
	player.respawn(game.camp_position + Vector3(0, 0.05, 0))
	await frames(5)
	check(game.expedition.stage == Expedition.Stage.CAMP and director.halt_reason == "choice", "Caravan waits at camp for a quest choice")
	check(director.posts.size() == 2, "Camp board offers two quests")
	check(await choose(game, "leg1_light"), "Leg 1 offers the lantern quest")
	check(game.expedition.stage == Expedition.Stage.MARCH and director.board.role() == "light", "Choosing a quest departs on the march")
	check(director.posts.is_empty(), "Board clears once a quest is chosen")
	check(game.workers.all(func(w): return w.state != "camp"), "Named workers join the departing caravan")
	player.invulnerability = 100000
	player.position = Vector3(9, 0.05, 146)
	await frames(30)
	check(director.halt_reason == "task" and caravan.distance < 0.01, "Caravan holds at camp until the first stretch's steps are done")
	check(director.step_spots("light").size() > 0 and director.step_enemies("clear").size() > 0, "First stretch opens a lantern step and a guardian step")
	await frames(480)
	check(director.step_spots("light").size() > 0, "No NPC lights the road when lanterns are the player's quest")
	var people_before := caravan.people
	var leg1 := await play_leg(game, "light")
	check(leg1.npc_done and leg1.stretches == 3, "Leg 1 runs as three stretches of chained steps")
	check(leg1.advanced == 3, "Caravan marches forward after every stretch")
	check(leg1.waited_for_arrival, "Next steps open only once the caravan reaches the checkpoint")
	check(caravan.people < people_before, "Guards clear the unchosen guardian steps at a cost in people")
	check(director.board.stage == 1 and director.halt_reason == "choice" and director.posts.size() == 2, "Leg end halts for the next quest")
	check(not director.posts.any(func(p): return p.quest == "leg2_chief"), "Chain quest needs the chain's first part done personally")
	check(await choose(game, "leg2_clear"), "Leg 2 offers the guardian quest")
	await frames(10)
	var foes: Array = director.step_enemies("clear")
	await frames(720)
	check(foes.size() > 0 and foes.any(func(e): return is_instance_valid(e) and e.state != "dead"), "Guards do not take the player's chosen fight")
	var leg2 := await play_leg(game, "clear")
	check(leg2.npc_done and leg2.advanced == leg2.stretches and leg2.stretches == 3, "Lamplighters light leg 2 while the player fights through it")
	check(game.expedition.stage == Expedition.Stage.MARCH and director.crossing_ready and game.region_id == RegionLayout.MEADOW, "Finishing leg 2 holds at the river until the player chooses to travel")
	var old_director: WeakRef = weakref(director)
	var old_world: WeakRef = weakref(game.landscape)
	var travel_people := caravan.people
	var travel_food := caravan.food
	player.position = RegionLayout.CROSSING + Vector3(4, 0.05, 1)
	await frames(2)
	check(game.travel_destination() == RegionLayout.FOREST, "Secured crossing offers travel at the far-bank sign")
	game.interact()
	check(game.changing_region and paused, "Travel fades and pauses gameplay")
	check(await wait_until(func(): return not game.changing_region, 300), "Transition completes and resumes gameplay")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	director = game.director
	check(old_world.get_ref() == null and old_director.get_ref() == null, "Old region geometry and runtime director are unloaded")
	check(game.region_id == RegionLayout.FOREST and game.expedition.stage == Expedition.Stage.BASE, "Crossing leads to the separate forest base map")
	check(caravan.people == travel_people and absf(caravan.food - travel_food) < 1, "Travel retains expedition people and supplies without consuming time during the fade")
	check(game.light.lit_by_anchor(director.base_center), "Arrival lights the base site")
	check(director.posts.size() == 2 and director.halt_reason == "choice", "Base site offers two quests")
	check(await choose(game, "base_carry"), "Base offers the carrying quest")
	check(director.raiders.size() == 2, "Raiders appear at the base perimeter")
	var progress_before: float = game.expedition.base_progress
	await frames(120)
	check(is_equal_approx(game.expedition.base_progress, progress_before), "Construction pauses while raiders threaten the base")
	player.position = director.crate_pile + Vector3(0, 0.05, 1.2)
	await frames(2)
	check("자재" in game.interaction_prompt(), "Crate pile offers a crate")
	game.interact()
	check(player.carrying and not player.try_attack("slash"), "Carrying a crate occupies the player's hands")
	player.position = director.drop_site + Vector3(0, 0.05, 1.2)
	await frames(2)
	var before_drop: float = game.expedition.base_progress
	game.interact()
	check(not player.carrying and game.expedition.base_progress >= before_drop + 10, "Delivered crate speeds construction")
	var people_at_base := caravan.people
	check(await wait_until(func(): return game.expedition.stage == Expedition.Stage.CLEARING, 9000), "Base construction completes and opens the ruin")
	check(caravan.people < people_at_base, "Guards repel the unchosen raid at a cost")
	check(game.camp_position.distance_to(director.base_center) < 0.1, "Finished base becomes the camp for reports and respawn")
	check(game.workers.all(func(w): return w.home.distance_to(director.base_center) < 6), "Workers move their home into the base")
	check(director.board.done(), "All march and base quests are finished")
	player.invulnerability = 0

func _test_caravan_view() -> void:
	var caravan := Caravan.new(PackedVector3Array([Vector3(0, 0, 146), Vector3(0, 0, 26)]))
	var view := CaravanView.new()
	view.caravan = caravan
	root.add_child(view)
	await process_frame
	check(view.column_length() > caravan.length(), "Column is longer than the route, so the tail is still leaving camp when the head arrives")
	check(view.packs.multimesh.instance_count == caravan.mules * 2 and view.bundles.multimesh.instance_count == caravan.mules, "Every pack mule carries side packs and a bundle")
	check(view.ox_bodies.multimesh.instance_count == caravan.wagons, "Each wagon has a draft ox")
	check(view.legs.multimesh.instance_count == (caravan.mules + caravan.oxen) * 4, "Animals have four legs to walk on")
	caravan.distance = 60
	view.moving = true
	view.refresh()
	var head := view.head_position()
	var tail := view.tail_position()
	check(head.distance_to(caravan.front()) < 3 and head.z < tail.z - 50, "Mid-march the column stretches back along the road")
	var on_road := 0
	for i in caravan.mules:
		var at := view.mule_position(i)
		if absf(at.x) < 4.5 and at.z < 146 and at.z > caravan.front().z:
			on_road += 1
	check(on_road > 0 and on_road < caravan.mules, "Pack mules walk inside the column while later ones are still in camp")
	var leaving := view.mule_position(on_road)
	check(leaving.z >= 140, "Members not yet on the road wait in or walk out of camp")
	view.queue_free()

func _test_march_plan() -> void:
	var plan := MarchPlan.new()
	check(plan.active_step("clear").kind == "kill" and plan.active_step("light").kind == "light", "First stretch gives each role a step")
	check(plan.complete_step("clear") and not plan.stretch_done(), "One role's finished chain still waits for the other role")
	check(plan.active_step("clear").is_empty(), "A finished chain has no active step")
	plan.complete_step("light")
	check(plan.stretch_done(), "Both chains finish the stretch")
	var first_end := plan.checkpoint()
	check(is_equal_approx(plan.previous_checkpoint(), 0) and first_end > 0, "First stretch runs from the route start")
	check(plan.next_stretch() and plan.checkpoint() > first_end and is_equal_approx(plan.previous_checkpoint(), first_end), "Next stretch moves the checkpoint forward")
	check(plan.active_step("clear").kind == "visit", "Chains continue with new step kinds")
	check(plan.step_number("clear") == 2 and plan.step_total("clear") >= 4, "Step numbers count across the whole leg")
	var guard := 0
	while guard < 20:
		guard += 1
		while not plan.active_step("clear").is_empty():
			plan.complete_step("clear")
		while not plan.active_step("light").is_empty():
			plan.complete_step("light")
		if not plan.next_stretch():
			break
	check(plan.leg_finished(), "Completing every stretch finishes the leg")
	plan.next_leg(true)
	check(plan.leg == 1 and plan.stretch == 0, "Next leg starts at its first stretch")
	var last: Array = MarchPlan.LEGS[1].stretches[-1].clear
	plan.stretch = MarchPlan.LEGS[1].stretches.size() - 1
	check(plan.steps("clear").size() > last.size() and plan.steps("clear").any(func(st): return st.get("chief", false)), "Chain quest adds the chief hunt to the leg's last stretch")

func _test_caravan() -> void:
	var caravan := Caravan.new(PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -60), Vector3(30, 0, -100)]))
	check(is_equal_approx(caravan.length(), 110), "Caravan route length sums its segments")
	check(caravan.point_at(85).is_equal_approx(Vector3(15, 0, -80)) and caravan.point_at(500).is_equal_approx(Vector3(30, 0, -100)), "Route points interpolate and clamp")
	check(not caravan.advance(1.0, 50, func(p: Vector3): return p.z > -1.0) and caravan.distance == 0, "Caravan will not step into unlit ground")
	for _i in range(100):
		caravan.advance(0.5, 50, func(_p): return true)
	check(is_equal_approx(caravan.distance, 50), "Caravan stops exactly at its leg limit")
	var food := caravan.food
	caravan.consume(10)
	check(is_equal_approx(food - caravan.food, (300 + 2 * 40 + 3 * 30) * Caravan.FOOD_RATE * 10), "People, mules and oxen eat every second")
	caravan.lose(4)
	check(caravan.people == 296 and caravan.lost == 4, "Losses reduce headcount")
	caravan.food = 0
	caravan.consume(9)
	check(caravan.people == 293, "Starvation makes people desert")

func _test_quest_board() -> void:
	var board := QuestBoard.new()
	check(board.offers() == ["leg1_clear", "leg1_light"], "Leg 1 offers a fight and a lantern job")
	check(not board.choose("base_carry") and board.choose("leg1_clear") and not board.choose("leg1_light"), "Only one offered quest can be taken")
	check(board.role() == "clear", "Quest decides the player's role")
	board.finish_stage()
	check("leg2_chief" in board.offers() and "leg2_clear" not in board.offers(), "Finishing a chain quest unlocks its follow-up")
	var other := QuestBoard.new()
	other.choose("leg1_light")
	other.finish_stage()
	check("leg2_clear" in other.offers(), "Without the chain, the regular quest is offered")
	other.choose("leg2_light")
	other.finish_stage()
	check(other.offers() == ["base_carry", "base_defend"] and not other.done(), "Base offers carrying or defence")
	other.choose("base_defend")
	other.finish_stage()
	check(other.done() and other.offers().is_empty(), "Board finishes after the base")

func _test_lanterns() -> void:
	var light := LanternNetwork.new()
	light.add_anchor(Vector3(0, 0, 16), 9.5)
	check(light.is_lit(Vector3(3, 0, 12)), "Anchored camp lantern lights its radius")
	check(not light.is_lit(Vector3(0, 0, -24)), "Ruin is dark without a forward lantern")
	check(light.is_lit(Vector3(0, 5, 16)), "Light ignores height")
	check(not light.burn(10) and is_equal_approx(light.fuel, light.max_fuel), "Unplanted lantern burns no oil")
	check(light.plant(Vector3(0, 0, -24)), "Forward lantern can be planted in the dark")
	check(light.is_lit(Vector3(4, 0, -24)), "Forward lantern lights nearby work")
	var full := light.forward_radius()
	light.burn(light.max_fuel * 0.5)
	check(light.forward_radius() < full and light.forward_radius() > LanternNetwork.MIN_FORWARD_RADIUS, "Half oil gives a smaller radius")
	check(light.is_lit(Vector3(3, 0, 12)), "Anchored lights do not depend on oil")
	light.burn(light.max_fuel * 10)
	check(light.fuel == 0 and is_equal_approx(light.forward_radius(), LanternNetwork.MIN_FORWARD_RADIUS), "Oil stops at zero with a minimum glow")
	check(not light.is_lit(Vector3(4, 0, -24)), "Minimum glow no longer reaches the work site")
	light.refuel()
	check(is_equal_approx(light.fuel, light.max_fuel), "Refuel fills the lantern")
	check(light.plant(Vector3(0, 0, -14)) and not light.is_lit(Vector3(4, 0, -24)), "Planting again moves the single forward lantern")
	check(not light.can_plant(Vector3(0, 0, 14)), "Cannot plant inside an anchored light")

func _test_expedition() -> void:
	var expedition := Expedition.new()
	check(not expedition.report(), "Cannot report before expedition")
	check(not expedition.collect_entrance_record(), "Cannot survey before departure")
	check(not expedition.record_delivery(0), "Cannot deliver before site is secured")
	check(expedition.start() and not expedition.start(), "Recruitment runs only once")
	check(expedition.stage == Expedition.Stage.MARCH, "Departure starts the march")
	check(not expedition.base_build(100), "Cannot build before reaching the base site")
	check(expedition.march_complete() and not expedition.march_complete(), "March completes once")
	check(not expedition.base_build(60) and expedition.stage == Expedition.Stage.BASE, "Partial construction keeps the base stage")
	check(expedition.base_build(60) and is_equal_approx(expedition.base_progress, 100), "Construction completes at 100 and caps")
	check(expedition.stage == Expedition.Stage.CLEARING, "Finished base opens the ruin")
	expedition.enemy_defeated()
	expedition.enemy_defeated()
	check(expedition.stage == Expedition.Stage.CLEARING, "Two kills do not unlock a three-enemy site")
	check(not expedition.collect_entrance_record(), "Remaining guardians prevent surveying the record")
	check(expedition.enemy_defeated(), "Final kill unlocks the site")
	check(not expedition.record_delivery(8), "Unknown worker cannot grant progress")
	check(expedition.record_delivery(0) and not expedition.record_delivery(0), "Duplicate delivery is ignored")
	check(not expedition.report(), "One delivery cannot finish the expedition")
	expedition.record_delivery(1)
	check(expedition.stage == Expedition.Stage.RECOVERING and not expedition.report(), "Deliveries alone do not complete the campaign")
	check(expedition.collect_entrance_record() and not expedition.collect_entrance_record(), "Surveying happens only once")
	check(expedition.report() and not expedition.report(), "Report is granted exactly once")
	var cleared_first := Expedition.new()
	for _i in range(3):
		cleared_first.enemy_defeated()
	cleared_first.start()
	cleared_first.march_complete()
	cleared_first.base_build(100)
	check(cleared_first.stage == Expedition.Stage.RECOVERING, "Clearing before recruitment is recoverable")
	check(cleared_first.collect_entrance_record() and not cleared_first.report(), "Survey can happen before deliveries but cannot finish alone")
	cleared_first.record_delivery(1)
	check(cleared_first.stage == Expedition.Stage.RECOVERING, "A survey and only one sample still wait for the other worker")
	cleared_first.record_delivery(0)
	check(cleared_first.stage == Expedition.Stage.REPORT and cleared_first.report(), "The last delivery unlocks reporting when the survey was done first")
