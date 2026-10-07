class_name CharacterFeet
extends RefCounted
## Distance-driven steps and world-space stance anchors, on environment layer 1.
## Visual correction only: never moves the CharacterBody or its collision shape.

const SOLE_HEIGHT := 0.117
const CYCLE_DISTANCE := 1.72
const STANCE := 0.5
var rig: Skeleton3D
var joints := {}
var phase := 0.0
var locked := {"l": false, "r": false}
var anchors := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var normals := {"l": Vector3.UP, "r": Vector3.UP}
var last_origin := Vector3.ZERO
var initialized := false
var active := false
var contact_error := 0.0
var was_moving := false
var motion_blend := 0.0
var previous_targets := {}

func _init(skeleton: Skeleton3D) -> void:
	rig = skeleton
	for side in ["l", "r"]:
		for part in ["thigh", "shin", "foot"]:
			joints[part + "_" + side] = rig.find_bone(part + "_" + side)

func apply(delta: float, speed: float, grounded: bool, action: String) -> void:
	var origin := rig.global_position
	var movement := origin - last_origin if initialized else Vector3.ZERO
	last_origin = origin
	initialized = true
	active = false
	contact_error = 0
	if not grounded or action == "dodge" or movement.length() > 1.0:
		release()
		return
	var horizontal := Vector3(movement.x, 0, movement.z)
	var moving := speed > 0.15 and horizontal.length() > 0.0001
	var direction := horizontal.normalized() if moving else rig.global_basis.z
	var running := speed > 5.5
	var reach_distance := 0.5 if running else 0.42
	var cycle_distance := 2.05 if running else CYCLE_DISTANCE
	if moving and not was_moving: phase = 0.25
	phase = fposmod(phase + horizontal.length() / cycle_distance, 1)
	motion_blend = move_toward(motion_blend, 1 if moving else 0, delta * 12)
	was_moving = moving
	var ground := {}
	for side in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		var rest := rig.to_global(Vector3(sign * 0.128, 0, 0.025))
		ground[side] = _floor(rest)
		if ground[side].is_empty():
			release()
			return
	active = true
	# Leave enough knee bend to reach planted feet without stretching straight legs.
	var hips := rig.find_bone("hips")
	var pelvis := rig.get_bone_pose_position(hips)
	var drop := lerpf(0.018, 0.205 if running else 0.14, motion_blend)
	var lower_floor: float = minf(ground.l.position.y, ground.r.position.y) - origin.y
	pelvis.y = 1 + (pelvis.y - 1) * 0.25 - drop - clampf(-lower_floor, 0, 0.12)
	rig.set_bone_pose_position(hips, pelvis)
	for side in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		var t := fposmod(phase + (0.5 if side == "r" else 0), 1)
		var rest := rig.to_global(Vector3(sign * 0.128, 0, 0.025))
		var target: Vector3
		var normal: Vector3
		var lift := 0.0
		if moving and t < STANCE:
			if not locked[side] or (anchors[side] - rest).length() > 0.72:
				var hit := _floor(rest + direction * (reach_distance - t * cycle_distance))
				if hit.is_empty(): hit = ground[side]
				anchors[side] = hit.position
				normals[side] = hit.normal
				locked[side] = true
			target = anchors[side]
			normal = normals[side]
		elif moving:
			locked[side] = false
			var swing := (t - STANCE) / (1 - STANCE)
			var reach := lerpf(-reach_distance, reach_distance, smoothstep(0, 1, swing))
			var hit := _floor(rest + direction * reach)
			if hit.is_empty(): hit = ground[side]
			target = hit.position
			normal = hit.normal
			lift = sin(swing * PI) * (0.18 if speed > 5.5 else 0.13) * motion_blend
		else:
			locked[side] = false
			target = ground[side].position
			normal = ground[side].normal
		var world_ankle := target + normal * SOLE_HEIGHT + Vector3.UP * lift
		if not moving and previous_targets.has(side):
			world_ankle = previous_targets[side].lerp(world_ankle, 1 - exp(-delta * 22))
		previous_targets[side] = world_ankle
		var ankle := rig.to_local(world_ankle)
		var local_normal := (rig.global_basis.inverse() * normal).normalized()
		var forward := Vector3.BACK.slide(local_normal).normalized()
		var basis := Basis(local_normal.cross(forward).normalized(), local_normal, forward)
		var error := LimbIK.solve(rig, joints["thigh_" + side], joints["shin_" + side], joints["foot_" + side], ankle, Vector3.BACK)
		LimbIK.orient(rig, joints["foot_" + side], basis)
		if lift < 0.001: contact_error = maxf(contact_error, error)

func release() -> void:
	locked.l = false
	locked.r = false
	phase = 0
	was_moving = false
	motion_blend = 0
	previous_targets.clear()

func _floor(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.55, at + Vector3.DOWN * 0.6, 1)
	var hit := rig.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.dot(Vector3.UP) < 0.65:
		return {}
	return hit
