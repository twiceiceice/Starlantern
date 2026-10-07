class_name CharacterArtTests
extends RefCounted

static func run(tree: SceneTree, check: Callable) -> void:
	var hero := CharacterView.new()
	tree.root.add_child(hero)
	var worker := CharacterView.new()
	worker.occupation = "carpenter"
	worker.coat = Color("79634a")
	tree.root.add_child(worker)
	check.call(hero.skeleton.get_bone_count() == 19, "Adult GLB imports its shared 19-joint skin")
	for name in ["Idle","Walk","Run","Jump","Slash","Slam","Dodge","WorkHammer","CarryIdle","CarryWalk","Cast"]:
		check.call(hero.animator.has_animation(name), "Adult rig imports playable clip: " + name)
	check.call(hero.tool.get_parent() is BoneAttachment3D and hero.tool.get_parent().bone_name == "grip_r", "Axe follows the actual gripping hand")
	var elbow := hero.skeleton.find_bone("forearm_r")
	for tick in 15: hero.animate(1.0/60.0, 0, true)
	var idle := hero.skeleton.get_bone_pose_rotation(elbow)
	for tick in 15: hero.animate(1.0/60.0, 0, true, "slam", .43)
	check.call(idle.angle_to(hero.skeleton.get_bone_pose_rotation(elbow)) > .10, "Attack really articulates the elbow, not just the top-level model")
	check.call(absf(hero.animator.current_animation_position - .43*.72) < .01, "Slam visual time follows gameplay progress after blending")
	for tick in 15: hero.animate(1.0/60.0, 0, true, "dodge")
	check.call(hero.clip == "Dodge" and hero.skeleton.get_bone_pose_position(hero.skeleton.find_bone("hips")).y < .9, "Dodge cancels attack and lowers the rig into an evasive stance")
	for tick in 15: hero.animate(1.0/60.0, 0, true)
	check.call(hero.clip == "Idle" and absf(hero.skeleton.get_bone_pose_position(hero.skeleton.find_bone("hips")).y-1.0) < .01, "Idle restores the pelvis after a cancelled action")
	hero.set_magic_focus(true)
	hero.animate(.2, 0, true, "", 0, true)
	check.call(hero.cargo.visible and not hero.tool.visible and not hero.focus.visible, "Carrying frees both hands even when a magic focus was equipped")
	hero.animate(.2, 0, true)
	check.call(not hero.cargo.visible and hero.focus.visible and not hero.tool.visible, "Putting down cargo restores the equipped focus")
	var hero_mesh: MeshInstance3D = hero.body.find_child("Outfit",true,false)
	var worker_mesh: MeshInstance3D = worker.body.find_child("Outfit",true,false)
	for surface in hero_mesh.mesh.get_surface_count():
		if hero_mesh.mesh.surface_get_material(surface).resource_name == "Coat":
			check.call(hero_mesh.get_active_material(surface) != worker_mesh.get_active_material(surface), "NPC cloth tint cannot overwrite the hero's shared mesh material")
	check.call(worker.body.find_child("WorkApron",true,false).visible and not hero.body.find_child("WorkApron",true,false).visible, "Carpenter and hero retain their own occupation silhouette")
	var bounds := hero_mesh.get_aabb()
	for mesh: MeshInstance3D in hero.body.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible and mesh.skin != null: bounds = bounds.merge(mesh.get_aabb())
	check.call(bounds.size.y > 1.85 and bounds.size.y < 2.05, "Imported adult is metre-scaled and fits the existing world")
	check.call(hero.body.find_child("FaceHero",true,false).visible and not hero.body.find_child("FaceCarpenter",true,false).visible, "Hero renders only its own face, avoiding overlapping heads")
	check.call(worker.body.find_child("FaceCarpenter",true,false).visible and not worker.body.find_child("HeroArmor",true,false).visible, "Carpenter has an individual face and work clothing without hero plate armor")
	hero.set_magic_focus(false)
	for action in ["slash", "slam"]:
		var error := 0.0
		var worst_progress := 0.0
		var length_error := 0.0
		for frame in range(12, 83):
			hero.animate(1.0 / 120.0, 0, true, action, frame / 100.0)
			if hero.hands.grip_error > error:
				error = hero.hands.grip_error
				worst_progress = frame / 100.0
			for side in ["l", "r"]:
				for pair in [["upper_arm_", "forearm_"], ["forearm_", "hand_"]]:
					var a := hero.skeleton.find_bone(pair[0] + side)
					var b := hero.skeleton.find_bone(pair[1] + side)
					var distance := hero.skeleton.get_bone_global_pose(a).origin.distance_to(hero.skeleton.get_bone_global_pose(b).origin)
					length_error = maxf(length_error, absf(distance - hero.skeleton.get_bone_rest(b).origin.length()))
		print("CONTACT ", action, " hand error=", error, " at progress=", worst_progress, " limb length error=", length_error)
		check.call(error < 0.035, action + " keeps both palms on the axe throughout windup, contact and follow-through")
		check.call(length_error < 0.001, action + " contact correction never stretches arms")
	hero.animate(0.2, 0, true, "", 0, true)
	check.call(hero.hands.grip_error < 0.025, "Both palms hold the cargo sides")
	hero.animate(0.2, 0, false, "dodge")
	check.call(is_zero_approx(hero.hands.strength) and not hero.feet.active, "Dodge releases the two-hand grip and ground constraints immediately")
	for tick in 15: hero.animate(1.0 / 60.0, 0, true)
	check.call(hero.skeleton.get_bone_pose_rotation(elbow).angle_to(idle) < 0.02, "Cancelling a corrected attack leaves no stale hand pose in idle")
	hero.free()
	worker.free()

static func contacts(tree: SceneTree, check: Callable) -> void:
	var stage := Node3D.new()
	tree.root.add_child(stage)
	stage.position = Vector3(1000, 0, 1000)
	var floor_body := StaticBody3D.new()
	stage.add_child(floor_body)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	collider.shape = box
	collider.position.y = -0.1
	floor_body.add_child(collider)
	var hero := CharacterView.new()
	stage.add_child(hero)
	await tree.physics_frame
	await tree.physics_frame
	hero.animate(1.0 / 60.0, 0, true)
	check.call(hero.feet.active and hero.feet.contact_error < 0.015, "Resting feet reach the native physics floor")
	var stance_motion := 0.0
	var max_error := 0.0
	var previous := {}
	for frame in 90:
		hero.position.z += 4.6 / 120.0
		hero.animate(1.0 / 120.0, 4.6, true)
		max_error = maxf(max_error, hero.feet.contact_error)
		for side in ["l", "r"]:
			var foot := hero.skeleton.find_bone("foot_" + side)
			var point := hero.skeleton.to_global(hero.skeleton.get_bone_global_pose(foot).origin)
			if hero.feet.locked[side] and previous.has(side):
				stance_motion = maxf(stance_motion, point.distance_to(previous[side]))
			if hero.feet.locked[side]: previous[side] = point
			else: previous.erase(side)
	print("CONTACT walking floor error=", max_error, " planted motion=", stance_motion)
	check.call(max_error < 0.025 and stance_motion < 0.025, "Stance feet stay on the ground while the actual actor moves, without skating")
	max_error = 0
	for frame in 60:
		hero.position.z += 7.4 / 120.0
		hero.animate(1.0 / 120.0, 7.4, true)
		max_error = maxf(max_error, hero.feet.contact_error)
	check.call(max_error < 0.035, "Running at gameplay speed keeps planted feet within reach")
	for frame in 30: hero.animate(1.0 / 60.0, 0, true)
	var stopped_error := 0.0
	for side in ["l", "r"]:
		var point := hero.skeleton.get_bone_global_pose(hero.skeleton.find_bone("foot_" + side)).origin
		stopped_error = maxf(stopped_error, absf(point.y - CharacterFeet.SOLE_HEIGHT))
	check.call(stopped_error < 0.005, "Stopping settles both soles onto the floor instead of freezing a raised foot")
	hero.position.y = 0.5
	hero.animate(1.0 / 60.0, 4.6, false)
	check.call(not hero.feet.active and not hero.feet.locked.l and not hero.feet.locked.r, "Jumping releases foot locks rather than pulling airborne legs to ground")
	hero.position = Vector3(3, 0, 0)
	hero.animate(1.0 / 60.0, 0, true)
	check.call(not hero.feet.active, "A teleport discards old world-space foot anchors")
	hero.animate(1.0 / 60.0, 0, true)
	check.call(hero.feet.active and hero.feet.contact_error < 0.015, "Feet reacquire the floor after a teleport")
	floor_body.rotation.z = 0.15
	hero.position = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	for frame in 15: hero.animate(1.0 / 60.0, 0, true)
	var normal_error := 0.0
	for side in ["l", "r"]:
		var up := hero.skeleton.get_bone_global_pose(hero.skeleton.find_bone("foot_" + side)).basis.y
		normal_error = maxf(normal_error, 1 - up.dot(floor_body.global_basis.y))
	check.call(hero.feet.active and normal_error < 0.001 and hero.feet.contact_error < 0.015, "Boot soles align to a real inclined collision surface")
	stage.free()
