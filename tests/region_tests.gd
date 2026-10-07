class_name RegionTests
extends RefCounted

static func travel(game, at: Vector3, destination: String, check: Callable, frames: Callable) -> void:
	game.player.position = at + Vector3.UP * 0.08
	game.player.velocity = Vector3.ZERO
	await frames.call(3)
	check.call(game.travel_destination() == destination, "Unlocked regional sign offers the expected destination")
	game.interact()
	var waited := 0
	while game.changing_region and waited < 180:
		await frames.call(10)
		waited += 10
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check.call(not game.changing_region and game.region_id == destination, "Fast travel finishes in the requested region")

static func run(game, check: Callable, frames: Callable) -> void:
	var route := Caravan.new(RegionLayout.route())
	check.call(route.length() > 170 and route.direction_at(25).distance_to(route.direction_at(75)) > 0.3, "Meadow road bends and its local heading changes along the journey")
	check.call(RegionLayout.walk_y(RegionLayout.MEADOW, 0, 0) == 0 and RegionLayout.ground_y(RegionLayout.MEADOW, 20, 0) < -2, "Bridge deck and actual river bed have distinct collision heights")
	var completed_resources: Dictionary = game.expedition.resources.duplicate()
	var completed_training: Dictionary = game.player.training.to_data()
	game.player.health = 57
	await travel(game, RegionLayout.FOREST_GATE, RegionLayout.MEADOW, check, frames)
	check.call(game.player.health == 57 and game.expedition.stage == Expedition.Stage.COMPLETE, "Return travel preserves health and completed expedition state")
	check.call(game.workers.all(func(w): return not w.visible), "The forest workers do not appear in the returned meadow")
	check.call(game.get_tree().get_nodes_in_group("enemies").is_empty(), "Unloading the forest leaves no remote enemy actors in the meadow")
	await travel(game, RegionLayout.CAMP_GATE, RegionLayout.FOREST, check, frames)
	check.call(game.expedition.resources == completed_resources and game.player.training.to_data() == completed_training, "Round trip preserves rewards and equipment without granting duplicate supplies")
	check.call(game.director.settlement.built == 4 and game.workers.all(func(w): return w.state == "delivered"), "Built camp and returned workers survive region reconstruction")
	const PATH := "user://region-check-test.json"
	var write_error := ExpeditionSave.write_checkpoint(game.career, game.player.training, game.expedition.resources, PATH,
		{"people":game.caravan.people,"food":game.caravan.food}, game.journey_data())
	check.call(write_error == OK, "Version 2 region checkpoint writes to an isolated test path")
	var completed := ExpeditionSave.read_checkpoint(PATH)
	check.call(completed.get("version") == 2 and completed.journey.region == RegionLayout.FOREST, "JSON checkpoint records the current region")
	game.restore_checkpoint(completed)
	await frames.call(4)
	check.call(game.region_id == RegionLayout.FOREST and game.expedition.resources == completed_resources and game.player.health == 57, "Disk checkpoint reconstructs map, progress and player health")
	# Begin a separate fixture in the same game root; this does not touch the real save.
	var fresh := {"career":{},"training":{},"resources":{},"caravan":{"people":300,"food":2400},
		"journey":{"region":RegionLayout.MEADOW,"expedition":{},"director":{},"player":[0,0,150]}}
	game.restore_checkpoint(fresh)
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.position = RegionLayout.CROSSING + Vector3(4,0.05,1)
	await frames.call(3)
	check.call(game.travel_destination().is_empty(), "Reaching the bridge early cannot skip the march or unlock the next region")
	game.request_travel(RegionLayout.FOREST)
	check.call(not game.changing_region and game.region_id == RegionLayout.MEADOW, "Locked travel refuses an explicit request")
	game.player.position = game.director.posts[0].position + Vector3(0,0.1,1)
	game.director._choose("leg1_clear")
	game.director.step_enemies("clear")[0].take_damage(1000, Vector3.ZERO)
	await frames.call(5)
	game.player.position = RegionLayout.START
	game.player.training.equip(0,"bolt")
	game.caravan.people = 287
	game.caravan.food = 2117
	var distance: float = game.caravan.distance
	var before_progress: Dictionary = game.director.plan.progress.duplicate()
	check.call(ExpeditionSave.write_checkpoint(game.career,game.player.training,game.expedition.resources,PATH,
		{"people":game.caravan.people,"food":game.caravan.food},game.journey_data()) == OK, "An unfinished march is checkpointed")
	var mid := ExpeditionSave.read_checkpoint(PATH)
	game.restore_checkpoint(mid)
	await frames.call(3)
	check.call(game.expedition.stage == Expedition.Stage.MARCH and game.director.board.chosen == "leg1_clear", "Reload retains the selected march assignment")
	check.call(game.director.plan.progress == before_progress and game.director.step_enemies("clear").is_empty(), "Reload retains completed work instead of resurrecting a defeated task")
	check.call(game.caravan.people == 287 and absf(game.caravan.food - 2117) < 1 and game.caravan.distance >= distance, "Partial checkpoint retains caravan numbers and route distance")
	check.call(game.player.training.primary == "bolt", "Partial checkpoint retains the chosen combat loadout")
	# Save halfway through base construction with a partially cleared raid.
	game.restore_checkpoint(completed)
	game.expedition.stage = Expedition.Stage.BASE
	game.expedition.base_progress = 42
	game.director.board.stage = 2
	game.director.board.chosen = ""
	game.director._choose("base_defend")
	game.director.raiders[0].take_damage(1000,Vector3.ZERO)
	game.director.raiders[1].take_damage(20,Vector3.ZERO)
	var base := {"career":game.career.to_data(),"training":game.player.training.to_data(),"resources":game.expedition.resources.duplicate(),
		"caravan":{"people":game.caravan.people,"food":game.caravan.food},"journey":game.journey_data()}
	game.restore_checkpoint(base)
	await frames.call(3)
	check.call(game.expedition.base_progress == 42 and game.director.board.chosen == "base_defend", "Base construction and its selected assignment resume from a checkpoint")
	check.call(game.director.raiders.size() == 1 and game.director.raiders[0].health == 76, "Checkpoint does not resurrect a cleared raider or heal the remaining raider")
	await travel(game,RegionLayout.FOREST_GATE,RegionLayout.MEADOW,check,frames)
	var halted_food: float = game.caravan.food
	await frames.call(90)
	check.call(game.expedition.base_progress == 42 and game.caravan.food == halted_food, "Unloaded base work and supply consumption stay paused on a return visit")
	var visiting := {"career":game.career.to_data(),"training":game.player.training.to_data(),"resources":game.expedition.resources.duplicate(),
		"caravan":{"people":game.caravan.people,"food":game.caravan.food},"journey":game.journey_data()}
	game.restore_checkpoint(visiting)
	await frames.call(3)
	await travel(game,RegionLayout.CAMP_GATE,RegionLayout.FOREST,check,frames)
	check.call(game.expedition.base_progress == 42 and game.director.raiders.size() == 1 and game.director.raiders[0].health == 76, "Saving during a meadow revisit retains the unloaded base encounter")
	# Legacy version 1 is accepted through the reader, not only a direct restore call.
	var legacy: Dictionary = completed.duplicate(true)
	legacy.erase("journey")
	legacy.version = 1
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var old := ExpeditionSave.read_checkpoint(PATH)
	check.call(not old.is_empty(), "Version 1 saves remain readable")
	game.restore_checkpoint(old)
	await frames.call(3)
	check.call(game.region_id == RegionLayout.FOREST and game.expedition.stage == Expedition.Stage.COMPLETE and game.portal_unlocked, "Legacy completion opens the forest hub and return route")
	DirAccess.remove_absolute(PATH)
