class_name CampLifeTests
extends RefCounted
## Real navigation, finite inventory and recovery through the normal save path.

static func snapshot(game) -> Dictionary:
	return {"version":2,"career":game.career.to_data(),"training":game.player.training.to_data(),
		"resources":game.expedition.resources.duplicate(),"caravan":{"people":game.caravan.people,"food":game.caravan.food},
		"journey":game.journey_data()}

static func run(game, check: Callable, frames: Callable) -> void:
	var original := snapshot(game)
	game.restore_checkpoint({"career":{},"training":{},"resources":{}})
	check.call(game.production.kits_ready and game.production.cargo == 2,"Legacy completed saves receive their two recovered loads without repeating recovery")
	game.production.restore({"started":true})
	game._sync_camp_life()
	game.production.changed.emit()
	game.caravan.food = 1000
	game.player.respawn(Vector3(0,.05,12))
	game.resume()
	var ledger: CampProduction = game.production
	var worker: ExpeditionWorker = game.workers[0]
	var light := worker.light
	worker.light = null
	worker.state = "waiting"
	worker.safe_to_work = true
	await frames.call(10)
	check.call(not worker.shipping_ready and worker.state in ["follow","waiting"],"A lit, secured recovery site still waits for the carpenter's packing crates")
	worker.state = "delivered"
	worker.light = light
	check.call(ledger.meals == 0 and ledger.shipments == 0,"Creating jobs does not grant products before NPC transport and work")
	check.call(not ledger.receive("sample_0") and ledger.cargo == 2,"Replayed recovery receipts cannot duplicate cargo")
	var ready := false
	for tick in 1800:
		await frames.call(1)
		var meal: Dictionary = ledger.jobs.cook
		if not meal.is_empty() and meal.phase == "working" and meal.progress > .5:
			ready = true
			break
	check.call(ready,"Cook physically fetches ingredients and reaches the pot around camp furniture")
	if ready:
		var meal: Dictionary = ledger.jobs.cook
		check.call(ledger.ingredients == 0 and ledger.meals == 0,"Cooking consumes one ingredient at collection and grants no meal at the pot")
		game.pause()
		var progress: float = meal.progress
		var at: Vector3 = game.camp_life.residents[1].position
		await frames.call(45)
		check.call(meal.progress == progress and game.camp_life.residents[1].position == at,"Pause freezes both camp work and resident movement")
		game.resume()
		var enemy := RuinGuardian.new()
		enemy.target = game.player
		enemy.position = RegionLayout.BASE
		game.gameplay.add_child(enemy)
		enemy.set_physics_process(false)
		await frames.call(3)
		progress = meal.progress
		await frames.call(40)
		check.call(meal.progress == progress and game.camp_life.residents[1].blocked,"A nearby enemy stops civilian work instead of allowing unsafe production")
		enemy.remove_from_group("enemies")
		enemy.queue_free()
		await frames.call(4)
		check.call(meal.progress > progress,"Civilian work resumes after the threat is removed")
		var save_path := "user://camp-life-test.json"
		var saved := snapshot(game)
		check.call(ExpeditionSave.write_checkpoint(game.career,game.player.training,game.expedition.resources,save_path,saved.caravan,saved.journey) == OK,"In-flight camp jobs serialize through the real checkpoint writer")
		var from_disk := ExpeditionSave.read_checkpoint(save_path)
		game.restore_checkpoint(from_disk)
		DirAccess.remove_absolute(save_path)
		check.call(ledger.ingredients == 0 and ledger.meals == 0 and is_equal_approx(ledger.jobs.cook.progress,meal.progress),"Reload preserves consumed ingredients and unfinished cooking without an early reward")
		check.call(game.camp_life.residents.size() == 2 and game.camp_life.residents[1].position.distance_to(at) < .2,"Reload reconstructs exactly two residents at their saved work locations")
		var before_trip := ledger.to_data()
		game.change_region(RegionLayout.MEADOW)
		await frames.call(120)
		check.call(not is_instance_valid(game.camp_life) and ledger.to_data() == before_trip,"The unloaded forest pauses camp jobs and retains their inventory")
		game.change_region(RegionLayout.FOREST)
		game.player.respawn(Vector3(0,.05,12))
		await frames.call(5)
		check.call(game.camp_life.residents.size() == 2 and ledger.receipts.size() == 2,"Returning to the forest does not duplicate residents or recovery receipts")
	for tick in 6600:
		if ledger.shipments == 2 and ledger.cooked == 3: break
		await frames.call(1)
	check.call(ledger.kits_ready and ledger.timber == 0 and game.workers.all(func(w): return w.shipping_ready),"Carpenter delivers the completed crates and unlocks the recovery crew")
	check.call(ledger.shipments == 2 and ledger.cargo == 0,"Both recovered loads are carried to the workshop and handed to the supply crew")
	check.call(ledger.cooked == 3 and ledger.meals == 3 and ledger.ingredients == 0,"Initial ingredients plus two shipments produce exactly three delivered meals")
	check.call(game.caravan.food == 1180,"Three delivered meals replenish actual caravan food exactly once each")
	await frames.call(180)
	check.call(ledger.cooked == 3 and ledger.shipments == 2,"Waiting without further materials cannot generate infinite rewards")
	game.player.respawn(CampLife.SERVING+Vector3(0,.05,.7))
	await frames.call(8)
	var stock := ledger.meals
	game.interact()
	check.call(ledger.meals == stock,"Interacting with meals at full health does not waste stock")
	game.player.health = 40
	game.interact()
	check.call(game.player.health == 75 and ledger.meals == stock-1,"E at the serving counter heals the player and consumes one real meal")
	game.player.position = RegionLayout.BASE
	check.call(not game.camp_life.eat(game.player) and ledger.meals == stock-1,"Meals cannot be consumed remotely")
	game.restore_checkpoint(original)
	game.resume()
	await frames.call(5)
