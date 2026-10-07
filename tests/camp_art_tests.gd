class_name CampArtTests
extends RefCounted
## Integration checks for the new physical furniture and the saved navigation.

static func run(game, check: Callable) -> void:
	var tree: SceneTree = game.get_tree()
	var player: ExpeditionPlayer = game.player
	var original_position := player.position
	var original_yaw: float = game.camera_rig.yaw
	game.camera_rig.yaw = 0
	var workshop := RegionLayout.START + CampArt.WORKSHOP
	player.position = workshop + Vector3(0,.08,2.8)
	player.velocity = Vector3.ZERO
	for tick in 8: await tree.physics_frame
	Input.action_press("move_forward")
	for tick in 60: await tree.physics_frame
	Input.action_release("move_forward")
	check.call(player.position.z > workshop.z + .25 and player.position.z < workshop.z + .75, "Player capsule stops at the actual workbench instead of passing through it")
	var query := PhysicsRayQueryParameters3D.create(workshop+Vector3(0,3.2,0),workshop+Vector3(0,1.9,0),1)
	var roof := player.get_world_3d().direct_space_state.intersect_ray(query)
	check.call(not roof.is_empty() and roof.position.y > 2.2, "Canopy has an overhead collider for the spring-arm camera")
	var navigation: NavigationRegion3D = game.landscape.get_node("WalkableGround")
	# Uncapped headless physics can outrun the server's initial background job.
	var deadline := Time.get_ticks_msec() + 3000
	while NavigationServer3D.region_get_iteration_id(navigation.get_rid()) == 0 and Time.get_ticks_msec() < deadline:
		OS.delay_msec(1)
		await tree.process_frame
	var path := NavigationServer3D.map_get_path(navigation.get_navigation_map(),workshop+Vector3(0,.05,3.5),workshop+Vector3(0,.05,-3.5),true)
	var bench := Rect2(Vector2(workshop.x-1.45,workshop.z-1.055),Vector2(2.9,1.05))
	var crosses_bench := false
	for i in range(path.size()-1):
		var samples := maxi(2,ceili(path[i].distance_to(path[i+1])/.15))
		for sample in samples:
			var point := path[i].lerp(path[i+1],float(sample)/(samples-1))
			if bench.has_point(Vector2(point.x,point.z)): crosses_bench = true
	check.call(path.size() >= 3 and not crosses_bench, "Saved NPC navigation finds a path around the workshop furniture")
	# The central road stays usable even though the detailed camp has more solids.
	player.position = RegionLayout.START + Vector3(0,.08,-9)
	player.velocity = Vector3.ZERO
	for tick in 6: await tree.physics_frame
	var start_z := player.position.z
	Input.action_press("move_forward")
	for tick in 75: await tree.physics_frame
	Input.action_release("move_forward")
	check.call(start_z-player.position.z > 5.0, "The central expedition route remains clear between the two new work areas")
	var settlement := SettlementView.new()
	settlement.position = Vector3(24,0,150)
	game.gameplay.add_child(settlement)
	settlement.set_progress(24,true)
	check.call(settlement.find_child("CampWorkshop",false,false) == null, "Unbuilt forward camp does not show its new workshop early")
	settlement.set_progress(25,true)
	check.call(settlement.find_child("CampWorkshop",false,false) != null and settlement.find_child("CampKitchen",false,false) == null, "First construction stage opens the repair area")
	settlement.set_progress(50,true)
	check.call(settlement.find_child("CampKitchen",false,false) != null, "Second construction stage opens the cooking area")
	settlement.set_progress(100,false)
	var colliders := settlement.find_children("*","CollisionShape3D",true,false).size()
	settlement.set_progress(100,false)
	check.call(settlement.built == 4 and settlement.find_children("*","CollisionShape3D",true,false).size() == colliders, "Restoring a completed camp does not duplicate furniture or collision bodies")
	settlement.queue_free()
	player.position = original_position
	player.velocity = Vector3.ZERO
	game.camera_rig.yaw = original_yaw
	for tick in 4: await tree.physics_frame
