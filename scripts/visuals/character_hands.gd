class_name CharacterHands
extends RefCounted
## Post-animation contact layer. Gameplay still owns movement and hit timing.

var rig: Skeleton3D
var joints := {}
var grip_error := 0.0
var strength := 0.0

func _init(skeleton: Skeleton3D) -> void:
	rig = skeleton
	for side in ["l", "r"]:
		for part in ["upper_arm", "forearm", "hand", "grip"]:
			joints[part + "_" + side] = rig.find_bone(part + "_" + side)

func apply_axe(action: String, progress: float, tool_basis: Basis) -> void:
	strength = smoothstep(0, 0.12, progress) * (1 - smoothstep(0.82, 1, progress))
	grip_error = 0
	var natural := rig.get_bone_global_pose(joints.grip_r) * Transform3D(tool_basis, Vector3.ZERO)
	var keys: Array[Transform3D]
	var times: Array[float]
	if action == "slam":
		times = [0.0, 0.22, 0.42, 0.5, 0.66, 1.0]
		keys = [natural,
			_weapon(Vector3(0.13, 1.65, 0.22), Vector3(0.13, 0.94, -0.30), Vector3.RIGHT),
			_weapon(Vector3(0.11, 1.87, 0.025), Vector3(0.12, 0.90, -0.42), Vector3.RIGHT),
			_weapon(Vector3(0.06, 1.065, 0.36), Vector3(0.04, -0.93, 0.36), Vector3.RIGHT),
			_weapon(Vector3(0.08, 1.10, 0.32), Vector3(0.08, -0.96, 0.28), Vector3.RIGHT), natural]
	else:
		times = [0.0, 0.17, 0.16 / 0.52, 0.55, 0.82, 1.0]
		keys = [natural,
			_weapon(Vector3(0.18, 1.20, 0.28), Vector3(0.85, 0.20, 0.45), Vector3.UP),
			_weapon(Vector3(0.02, 1.15, 0.36), Vector3(0.20, -0.15, 0.96), Vector3.UP),
			_weapon(Vector3(-0.10, 1.20, 0.18), Vector3(-0.90, 0.10, 0.40), Vector3.UP),
			_weapon(Vector3(-0.10, 1.22, 0.15), Vector3(-0.82, 0.10, 0.45), Vector3.UP), natural]
	var desired := natural
	for i in times.size() - 1:
		if progress >= times[i] and progress <= times[i + 1]:
			var t := smoothstep(times[i], times[i + 1], progress)
			desired = keys[i].interpolate_with(keys[i + 1], t)
			break
	var right_basis := desired.basis * tool_basis.inverse()
	_hold("r", desired.origin, right_basis, strength)
	# The tool remains attached to the solved right hand. Aim the other hand at
	# the resulting handle, so unreachable animation targets cannot split grips.
	var actual := rig.get_bone_global_pose(joints.grip_r) * Transform3D(tool_basis, Vector3.ZERO)
	_hold("l", actual * Vector3(0, -0.22, 0), actual.basis * tool_basis.inverse(), strength)
	grip_error = rig.get_bone_global_pose(joints.grip_l).origin.distance_to(actual * Vector3(0, -0.22, 0))

func apply_cargo(local_cargo: Transform3D) -> void:
	strength = 1
	grip_error = 0
	var crate := rig.get_bone_global_pose(rig.find_bone("chest")) * local_cargo
	for side in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		var target: Vector3 = crate * Vector3(sign * 0.27, 0, -0.035)
		_hold(side, target, crate.basis, 1)
		grip_error = maxf(grip_error, rig.get_bone_global_pose(joints["grip_" + side]).origin.distance_to(target))

func _hold(side: String, target: Vector3, basis: Basis, weight: float) -> void:
	var hand: int = joints["hand_" + side]
	var grip: int = joints["grip_" + side]
	var current := rig.get_bone_global_pose(grip)
	var hand_basis := rig.get_bone_global_pose(hand).basis.slerp(basis, weight)
	var point := current.origin.lerp(target, weight)
	var wrist := point - hand_basis * rig.get_bone_rest(grip).origin
	var pole := Vector3(-1 if side == "l" else 1, -0.2, -0.35)
	LimbIK.solve(rig, joints["upper_arm_" + side], joints["forearm_" + side], hand, wrist, pole)
	LimbIK.orient(rig, hand, hand_basis)

func _weapon(at: Vector3, shaft: Vector3, normal: Vector3) -> Transform3D:
	at.y += rig.get_bone_pose_position(rig.find_bone("hips")).y - 1
	var y := shaft.normalized()
	var x := y.cross(normal).normalized()
	return Transform3D(Basis(x, y, x.cross(y).normalized()), at)
