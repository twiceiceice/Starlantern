class_name FollowCamera
extends Node3D

var target: ExpeditionPlayer
var yaw := 0.0
var pitch := -0.48
var distance := 8.8
var arm: SpringArm3D
var camera: Camera3D
var trauma := 0.0

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.rotation.x = pitch
	arm.collision_mask = 1
	arm.margin = 0.18
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	arm.shape = probe
	add_child(arm)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 60
	camera.far = 180
	# The initial menu pauses physics before SpringArm3D's first update.
	camera.position.z = distance
	arm.add_child(camera)
	if target:
		position = target.position + Vector3(0, 1.25, 0)

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.1, -0.12)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.6, 4, 13)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.6, 4, 13)

func _physics_process(delta: float) -> void:
	if not target:
		return
	global_position = global_position.lerp(target.global_position + Vector3(0, 1.25, 0), 1.0 - exp(-14 * delta))
	rotation.y = yaw
	arm.rotation.x = pitch
	arm.spring_length = lerpf(arm.spring_length, distance, 1.0 - exp(-10 * delta))
	target.camera_yaw = yaw
	trauma = maxf(0, trauma - delta * 2)
	camera.h_offset = sin(Time.get_ticks_msec() * 0.065) * trauma * 0.12
	camera.v_offset = cos(Time.get_ticks_msec() * 0.084) * trauma * 0.08

func bump(amount: float) -> void:
	trauma = minf(0.65, trauma + amount)
