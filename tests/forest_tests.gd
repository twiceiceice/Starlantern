class_name ForestTests
extends RefCounted
## Use the running forest after the common campaign; never touch the real save.

static func run(game, check: Callable, frames: Callable) -> void:
	var player: ExpeditionPlayer = game.player
	var original_position := player.position
	var original_yaw: float = game.camera_rig.yaw
	var atmosphere := game.landscape.get_node("ForestAtmosphere") as ForestAtmosphere
	check.call(atmosphere.observer == player, "Forest lighting observes the persistent player after a region transition")
	player.position = Vector3(0,.08,-7)
	player.velocity = Vector3.ZERO
	game.camera_rig.yaw = 0
	await frames.call(8)
	Input.action_press("move_forward")
	await frames.call(85)
	Input.action_release("move_forward")
	check.call(player.position.z < -12.9 and player.is_on_floor(), "The actual player walks through the stone arch and over the sunken flagstones")
	var space := player.get_world_3d().direct_space_state
	var pier := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5.7,1.2,-8),Vector3(5.7,1.2,-14),1))
	check.call(not pier.is_empty(), "Dressed-stone entrance piers have real collision")
	var arch := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,12,-11),Vector3(0,4,-11),1))
	check.call(not arch.is_empty() and arch.position.y > 7, "The curved arch blocks the camera overhead while keeping walking headroom")
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(7,1.2,-20),Vector3(12,1.2,-20),1))
	check.call(not wall.is_empty(), "The new masonry walls retain the combat arena's physical boundary")
	var rear := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1.2,-28.8),Vector3(0,1.2,-34),1))
	check.call(not rear.is_empty(), "The sealed descent remains a boundary rather than an accidental unfinished exit")
	var nav: NavigationRegion3D = game.landscape.get_node("WalkableGround")
	for destination: Vector3 in [Vector3(-4,0,-24),Vector3(4,0,-24),Vector3(-6,0,-16),Vector3(6,0,-20),ExpeditionCampaign.RECORD_POSITION]:
		var path := NavigationServer3D.map_get_path(nav.get_navigation_map(),RegionLayout.BASE+Vector3(0,.05,-3),destination,true)
		check.call(path.size() >= 2 and path[-1].distance_to(destination) < .75, "Forest navigation still reaches worker/quest point %s" % destination)
	player.position = RegionLayout.BASE+Vector3(0,.08,-2)
	player.velocity = Vector3.ZERO
	await frames.call(100)
	var camp_energy := atmosphere.sun.light_energy
	check.call(atmosphere.depth < .04, "Returning to the forward camp restores its warmer lighting")
	player.position = Vector3(0,.08,-22)
	await frames.call(100)
	check.call(atmosphere.depth > .96 and atmosphere.sun.light_energy < camp_energy-.25, "Entering the ruin gradually changes its light without an abrupt scene switch")
	var fuel: float = game.light.fuel
	var radius: float = game.light.forward_radius()
	atmosphere.apply_depth(0.0)
	check.call(game.light.fuel == fuel and game.light.forward_radius() == radius, "Art lighting does not change lantern fuel or the gameplay safety radius")
	game.pause()
	var paused_depth := atmosphere.depth
	await frames.call(18)
	check.call(atmosphere.depth == paused_depth, "The local atmosphere respects game pause")
	game.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.position = original_position
	player.velocity = Vector3.ZERO
	game.camera_rig.yaw = original_yaw
	await frames.call(6)
