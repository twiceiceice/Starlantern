class_name LimbIK
extends RefCounted
## Analytic two-bone solver, in skeleton space. Never scales or stretches a bone.

static func solve(rig: Skeleton3D, upper: int, middle: int, end: int, target: Vector3, pole: Vector3) -> float:
	var a := rig.get_bone_global_pose(upper).origin
	var b := rig.get_bone_global_pose(middle).origin
	var c := rig.get_bone_global_pose(end).origin
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var offset := target - a
	if offset.length_squared() < 0.000001 or first < 0.001 or second < 0.001:
		return c.distance_to(target)
	var direction := offset.normalized()
	var distance := clampf(offset.length(), absf(first - second) + 0.0001, first + second - 0.0001)
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.0001:
		bend = direction.cross(Vector3.RIGHT if absf(direction.x) < 0.9 else Vector3.UP)
	bend = bend.normalized()
	var cosine := clampf((first * first + distance * distance - second * second) / (2 * first * distance), -1, 1)
	var joint := a + direction * first * cosine + bend * first * sqrt(maxf(0, 1 - cosine * cosine))
	_rotate_toward(rig, upper, b - a, joint - a)
	b = rig.get_bone_global_pose(middle).origin
	c = rig.get_bone_global_pose(end).origin
	_rotate_toward(rig, middle, c - b, a + direction * distance - b)
	return rig.get_bone_global_pose(end).origin.distance_to(target)

static func orient(rig: Skeleton3D, bone: int, basis: Basis) -> void:
	var parent := rig.get_bone_parent(bone)
	var local := basis
	if parent >= 0:
		local = rig.get_bone_global_pose(parent).basis.inverse() * basis
	rig.set_bone_pose_rotation(bone, local.orthonormalized().get_rotation_quaternion())

static func _rotate_toward(rig: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var rotation := Quaternion(from.normalized(), to.normalized())
	orient(rig, bone, Basis(rotation) * rig.get_bone_global_pose(bone).basis)
