class_name CombatRules
extends RefCounted

const WALK_SPEED := 4.6
const RUN_SPEED := 7.4
const GRAVITY := 22.0
const JUMP_SPEED := 7.0
const DODGE_SPEED := 12.0
const DODGE_DURATION := 0.28
const DODGE_INVULNERABLE := 0.22
const DODGE_RECHARGE := 2.4
const SLASH := {"damage": 24.0, "range": 2.7, "angle": 115.0, "windup": 0.16, "duration": 0.52, "cooldown": 0.60}
const SLAM := {"damage": 48.0, "range": 3.5, "angle": 125.0, "windup": 0.36, "duration": 0.72, "cooldown": 3.8}

static func move_direction(input: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera_yaw).limit_length(1.0)

static func within_arc(origin: Vector3, facing: Vector3, target: Vector3, distance: float, angle: float) -> bool:
	var offset := target - origin
	if absf(offset.y) > 2.2:
		return false
	offset.y = 0
	if offset.length() > distance:
		return false
	if offset.length_squared() < 0.01:
		return true
	return facing.normalized().dot(offset.normalized()) >= cos(deg_to_rad(angle * 0.5))
