class_name CareerTests
extends RefCounted

static func run(game, check: Callable, frames: Callable) -> void:
	_rules(check)
	await _combat(game,check,frames)
	await _contracts(game,check,frames)
	await _save(game,check,frames)

static func _rules(check: Callable) -> void:
	var career := CareerProgress.new()
	check.call(not career.choose("hero",false) and not career.choose("missing",true),"Career selection requires the shared campaign and a known path")
	for id in CareerProgress.PATHS:
		for i in range(3):
			check.call(career.choose(id,true),"An available contract can be selected: %s %d" % [id,i])
			check.call(not career.choose(id,true) and not career.report() and not career.advance(8),"Active contracts reject reselection, early reports and out-of-order steps")
			for step in range(career.mission().steps.size()): career.advance(step)
			check.call(career.report() and not career.report(),"A contract pays once: %s %d" % [id,i])
		check.call(career.rank() == 2 and career.title() == CareerProgress.TITLES[id][2] and not career.choose(id,true),"Three contracts finish a path without needing any other path")
	var training := CombatTraining.new()
	check.call(not training.equip(0,"familiar") and not training.equip(1,"missing"),"Loadout rejects invalid actions and wrong slots")
	for primary in CombatTraining.PRIMARY:
		for secondary in CombatTraining.SECONDARY:
			check.call(training.equip(0,primary) and training.equip(1,secondary),"Weapon and spell slots freely combine: %s / %s" % [primary,secondary])
	for i in range(6): training.practice("bolt")
	check.call(training.level("arcana") == 2 and training.level("steel") == 1,"Valid practice grows only its own discipline")
	for i in range(30): training.practice("bolt")
	check.call(training.level("arcana") == 3 and training.experience.arcana == 18,"Mastery has two bounded upgrades")

static func _combat(game,check: Callable,frames: Callable) -> void:
	game.resume()
	var player: ExpeditionPlayer = game.player
	player.training = CombatTraining.new()
	player.respawn(Vector3(0,0.05,-14))
	player.camera_yaw = 0
	game.camera_rig.yaw = 0
	var foe := RuinGuardian.new()
	foe.target = player
	foe.max_health = 2000
	foe.position = Vector3(0,0.05,-22)
	game.gameplay.add_child(foe)
	foe.set_physics_process(false)
	await frames.call(5)
	player.slash_cooldown = 0
	player.try_attack("bolt")
	await frames.call(45)
	check.call(is_equal_approx(foe.health,1979) and player.training.experience.arcana == 1,"A ranged spell hits a real target and awards practice once")
	var wall := Geometry.solid_box(game.gameplay,Vector3(0,1.5,-18),Vector3(3,3,0.3),Color.GRAY)
	await frames.call(3)
	player.slash_cooldown = 0
	player.try_attack("bolt")
	await frames.call(45)
	check.call(is_equal_approx(foe.health,1979) and player.training.experience.arcana == 1,"Spells cannot damage or gain mastery through walls")
	wall.queue_free()
	await frames.call(3)
	game.career.path = "hero"
	game.arts.tactic_cooldown = 0
	check.call(game.arts.use_tactic() and foe.exposed_left > 0,"Hero tactic exposes a visible enemy")
	player.slash_cooldown = 0
	player.try_attack("bolt")
	await frames.call(45)
	check.call(is_equal_approx(foe.health,1947.5),"Hero exposure amplifies magic as well as weapons")
	game.career.path = "warden"
	game.arts.tactic_cooldown = 0
	game.arts.use_tactic()
	await frames.call(3)
	player.health = 100
	player.invulnerability = 0
	player.take_damage(18)
	check.call(is_equal_approx(player.health,93.7),"Warden field reduces actual incoming damage")
	game.arts.reset_effects()
	game.career.path = "explorer"
	game.arts.tactic_cooldown = 0
	player.dodge_charges = 0
	game.arts.use_tactic()
	await frames.call(3)
	check.call(player.dodge_charges == 2 and player.haste > 1,"Explorer tactic replenishes evasion and increases movement speed")
	game.arts.reset_effects()
	player.slam_cooldown = 0
	player.try_attack("familiar")
	await frames.call(100)
	var health_after: float = foe.health
	check.call(health_after < 1947.5 and player.training.experience.bond == 1,"A summoned familiar independently attacks and grants one practice credit")
	await frames.call(100)
	check.call(foe.health < health_after and player.training.experience.bond == 1,"Repeated familiar pulses do not farm multiple credits for one cast")
	game.career.path = "artisan"
	game.arts.tactic_cooldown = 0
	game.arts.use_tactic()
	check.call(game.arts.summons.size() == 2,"Artisan construct and freely equipped familiar coexist")
	game.open_growth()
	var cooldown: float = game.arts.tactic_cooldown
	var life: float = game.arts.summons[0].left
	await frames.call(30)
	check.call(game.arts.tactic_cooldown == cooldown and game.arts.summons[0].left == life,"Growth screen pauses tactic cooldown and summon lifetime")
	game.close_growth()
	game.arts.reset_effects()
	foe.boss = true
	foe.begin_attack()
	var first_radius := foe.attack_radius
	var first_windup := foe.windup_time
	foe.begin_attack()
	check.call(first_radius > foe.attack_radius and first_windup > foe.windup_time,"Final hero boss alternates broad slow and narrow fast telegraphs")
	foe.clear_marker()
	foe.remove_from_group("enemies")
	foe.queue_free()
	game.career.path = ""
	player.training = CombatTraining.new()
	await frames.call(3)

static func _contracts(game,check: Callable,frames: Callable) -> void:
	var player: ExpeditionPlayer = game.player
	var director: CareerDirector = game.missions
	game.resume()
	player.respawn(game.camp_position+Vector3(0,0.05,0))
	await frames.call(4)
	# Real loss cancels only the active contract. It can be accepted again at the base.
	check.call(director.choose("warden",true),"Guardian contract is available at the finished base")
	await frames.call(400)
	check.call(director.waves == 0 and director.escort.health == 100,"Escort ambush waits for the player to arrive instead of killing an unattended NPC")
	player.position = director.escort.position+Vector3(1.5,0.05,0)
	await frames.call(4)
	game.arts.tactic_cooldown = 0
	game.arts.use_tactic()
	await frames.call(2)
	director.escort.take_damage(18)
	check.call(is_equal_approx(director.escort.health,93.7),"Warden's field protects the actual escort as well as the player")
	director.escort.take_damage(1000)
	check.call(not game.career.active and game.career.completed.warden == 0 and game.career.failed,"Losing an escort fails the current contract without awarding progress")
	await frames.call(4)
	game.arts.reset_effects()
	var initial_timber: int = game.expedition.resources.timber
	for id in CareerProgress.PATHS:
		for mission in range(3):
			player.respawn(game.camp_position+Vector3(0,0.05,0))
			player.invulnerability = 10000
			await frames.call(4)
			check.call(director.choose(id,true),"Accept real scene contract: %s %d" % [id,mission])
			var budget := 0
			while game.career.active and not game.career.awaiting_report and budget < 6500:
				budget += 10
				if director.running_step < 0:
					await frames.call(10)
					continue
				var task: Dictionary = game.career.step()
				for enemy in director._living(): enemy.take_damage(10000,Vector3.ZERO)
				if is_instance_valid(director.escort):
					player.position = director.escort.global_position+Vector3(1.5,0.05,0)
					player.velocity = Vector3.ZERO
				elif is_instance_valid(director.marker):
					player.position = director.marker.global_position+Vector3(0,0.05,1.3)
					player.velocity = Vector3.ZERO
					await frames.call(3)
					game.interact()
				await frames.call(10)
			check.call(game.career.awaiting_report,"Real movement, tasks and waves reach report: %s %d" % [id,mission])
			if not game.career.awaiting_report:
				print("CONTRACT_STUCK: ",id," ",mission," ",director.objective())
				director.fail()
				break
			player.position = Vector3(0,0.05,-8)
			await frames.call(3)
			game.interact()
			check.call(game.career.completed[id] == mission,"Contract report cannot be claimed away from base")
			player.position = game.camp_position+Vector3(0,0.05,0)
			await frames.call(3)
			game.interact()
			check.call(game.career.completed[id] == mission+1 and game.hud.growth.visible,"Reporting advances the selected career and shows its growth screen")
			game.close_growth()
		check.call(game.career.title() == CareerProgress.TITLES[id][2],"Final title earned by actual contracts: "+id)
	check.call(game.expedition.resources.timber == initial_timber + 12*8,"All twelve contracts grant one reward each")
	# Failure through the player's defeat also cleans up and preserves completed paths.
	game.career.completed.hero = 1
	check.call(director.choose("hero",true),"A later contract can be retried from its own checkpoint")
	game._on_player_defeated()
	check.call(not game.career.active and game.career.completed.hero == 1 and director.running_step == -1,"Player defeat preserves promotion and cleans the unfinished mission")

static func _save(game,check: Callable,frames: Callable) -> void:
	var path := "user://career-check-test.json"
	game.player.training.equip(0,"bolt")
	game.player.training.equip(1,"familiar")
	for i in range(6): game.player.training.practice("bolt")
	check.call(ExpeditionSave.write_checkpoint(game.career,game.player.training,game.expedition.resources,path) == OK,"Career checkpoint writes successfully")
	game.career.completed.hero = 2
	check.call(ExpeditionSave.write_checkpoint(game.career,game.player.training,game.expedition.resources,path) == OK,"Checkpoint atomically replaces the previous file")
	var data := ExpeditionSave.read_checkpoint(path)
	check.call(not data.is_empty(),"Checkpoint loads the supported schema")
	game.restore_checkpoint(data)
	await frames.call(4)
	check.call(game.career.completed.hero == 2 and game.career.completed.artisan == 3 and not game.career.active,"Reload retains all promotions and returns the unfinished contract to the base")
	check.call(game.player.training.primary == "bolt" and game.player.training.secondary == "familiar" and game.player.training.level("arcana") == 2,"Reload retains mixed equipment and mastery")
	check.call(game.player.global_position.distance_to(game.camp_position) < 1 and game.expedition.stage == Expedition.Stage.COMPLETE,"Reload reconstructs the completed shared campaign at the forward base")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check.call(ExpeditionSave.read_checkpoint(path).is_empty(),"Malformed save data is rejected safely")
	DirAccess.remove_absolute(path)
