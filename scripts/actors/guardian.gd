class_name RuinGuardian
extends CharacterBody3D

signal died(guardian: RuinGuardian)
signal struck_player

var target: ExpeditionPlayer
var protected_target: Node3D
var taunt_left := 0.0
var exposed_left := 0.0
var boss := false
var attack_count := 0
var attack_radius := 2.4
var windup_time := 0.95
var title := "유적 파수꾼"
var max_health := 96.0
var health := 96.0
var home := Vector3.ZERO
var state := "idle"
var timer := 0.0
var cooldown := 1.0
var marker: Node3D
var marker_center := Vector3.ZERO
var visual: Node3D
var caption: Label3D
var agent: NavigationAgent3D
var repath := 0.0
var knockback := Vector3.ZERO

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	home = global_position
	health = max_health
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.7
	collider.position.y = 0.85
	collider.shape = shape
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	Geometry.sphere(visual, Vector3(0, 0.85, 0), Vector3(1.2, 1.35, 0.92), Color("728d8c"))
	Geometry.sphere(visual, Vector3(0, 1.55, 0.03), Vector3(0.82, 0.67, 0.76), Color("a1aaa0"))
	for x: float in [-0.6, 0.6]:
		Geometry.sphere(visual, Vector3(x, 0.88, 0), Vector3(0.47, 0.8, 0.48), Color("637978"))
		Geometry.sphere(visual, Vector3(x * 0.5, 0.2, 0.12), Vector3(0.45, 0.4, 0.6), Color("536969"))
		Geometry.sphere(visual, Vector3(x * 0.25, 1.59, 0.39), Vector3(0.10, 0.08, 0.035), Color("f5ca75"))
	Geometry.cylinder(visual, Vector3(0, 1.91, 0), 0.19, 0.42, Color("a9c4a0"), 0.01)
	caption = Geometry.label(self, "%s  %d" % [title, health], 2.35, Color("f7d2ae"))
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.4
	agent.target_desired_distance = 1.65
	add_child(agent)

func _physics_process(delta: float) -> void:
	if state == "dead" or not is_instance_valid(target):
		return
	if not is_on_floor():
		velocity.y -= CombatRules.GRAVITY * delta
	velocity.x = 0
	velocity.z = 0
	cooldown = maxf(0, cooldown - delta)
	taunt_left = maxf(0, taunt_left - delta)
	exposed_left = maxf(0, exposed_left - delta)
	caption.modulate = Color("a3e6ef") if exposed_left > 0 else Color("f7d2ae")
	var victim := _victim()
	var to_player := victim.global_position - global_position
	to_player.y = 0
	var distance := to_player.length()
	if state == "windup":
		timer -= delta
		visual.scale.y = 0.8 + 0.2 * (timer / windup_time)
		marker.scale = Vector3.ONE * (0.94 + sin(timer * 30) * 0.035)
		if timer <= 0:
			for body: Node3D in [target, protected_target]:
				if not is_instance_valid(body): continue
				var offset := body.global_position - marker_center
				var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, body.global_position + Vector3.UP, 1)
				if Vector2(offset.x, offset.z).length() < attack_radius + 0.05 and absf(offset.y) < 1.2 and get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
					if body.call("take_damage", 22.0 if boss else 18.0) and body == target:
						struck_player.emit()
			clear_marker()
			state = "recover"
			timer = 0.65
	elif state == "recover":
		timer -= delta
		visual.scale.y = lerpf(visual.scale.y, 1, delta * 12)
		if timer <= 0:
			state = "idle"
			cooldown = 1.5
	elif distance < 11 and global_position.distance_to(home) < 17:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to_player.x, to_player.z), minf(1, delta * 9))
		if distance < 3.0 and cooldown <= 0:
			begin_attack()
		elif distance > 2.1:
			_move_toward(victim.global_position, delta)
	elif global_position.distance_to(home) > 1:
		_move_toward(home, delta)
	velocity.x += knockback.x
	velocity.z += knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, delta * 14)
	move_and_slide()

func _move_toward(destination: Vector3, delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) == 0:
		return
	repath -= delta
	if repath <= 0:
		agent.target_position = destination
		repath = 0.35
	if not agent.is_navigation_finished():
		var direction := global_position.direction_to(agent.get_next_path_position())
		velocity.x = direction.x * 2.7
		velocity.z = direction.z * 2.7
		visual.position.y = sin(Time.get_ticks_msec() * 0.012) * 0.05

func begin_attack() -> void:
	clear_marker()
	attack_count += 1
	attack_radius = (4.2 if attack_count % 2 == 1 else 2.0) if boss else 2.4
	windup_time = (1.3 if attack_count % 2 == 1 else 0.70) if boss else 0.95
	state = "windup"
	timer = windup_time
	marker_center = _victim().global_position
	var ground_ray := PhysicsRayQueryParameters3D.create(marker_center + Vector3.UP * 2, marker_center - Vector3.UP * 5, 1)
	var ground := get_world_3d().direct_space_state.intersect_ray(ground_ray)
	marker_center.y = float(ground.position.y) + 0.10 if not ground.is_empty() else global_position.y + 0.10
	marker = Node3D.new()
	get_parent().add_child(marker)
	marker.global_position = marker_center
	Geometry.cylinder(marker, Vector3.ZERO, attack_radius, 0.025, Color(0.9, 0.29, 0.2, 0.25))
	Geometry.ring(marker, attack_radius, Color("ee8160"), 0.06)

func _victim() -> Node3D:
	return protected_target if is_instance_valid(protected_target) and taunt_left <= 0 and float(protected_target.get("health")) > 0 else target

func clear_marker() -> void:
	if is_instance_valid(marker):
		marker.queue_free()
	marker = null

func take_damage(amount: float, direction: Vector3) -> float:
	if state == "dead":
		return 0
	amount *= 1.5 if exposed_left > 0 else 1.0
	var dealt := minf(health, amount)
	taunt_left = 5.0
	health = maxf(0, health - amount)
	knockback = direction * (6.5 if amount >= 40 else 3.0)
	caption.text = "%s  %d" % [title, health]
	var flash := create_tween()
	visual.scale = Vector3(1.12, 0.87, 1.12)
	flash.tween_property(visual, "scale", Vector3.ONE, 0.18)
	if health <= 0:
		state = "dead"
		clear_marker()
		remove_from_group("enemies")
		caption.visible = false
		died.emit(self)
		var fade := create_tween()
		fade.tween_property(visual, "scale", Vector3.ZERO, 0.35)
		fade.tween_callback(queue_free)
	return dealt

func reset_encounter() -> void:
	clear_marker()
	global_position = home
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	taunt_left = 0
	exposed_left = 0
	health = max_health
	caption.text = "%s  %d" % [title, health]
	state = "idle"
	cooldown = 2
	visual.scale = Vector3.ONE
