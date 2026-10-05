class_name ExpeditionPlayer
extends CharacterBody3D

signal attack_landed(origin: Vector3, facing: Vector3, definition: Dictionary)
signal defeated
signal action_started(action: String)

var view: CharacterView
var training := CombatTraining.new()
var protection := 1.0
var haste := 1.0
var camera_yaw := 0.0
var health := 100.0
var dodge_charges := 2
var recharge_elapsed := 0.0
var dodge_left := 0.0
var dodge_direction := Vector3.FORWARD
var invulnerability := 0.0
var attack_name := ""
var attack_elapsed := 0.0
var attack_has_hit := false
var attack_definition: Dictionary = {}
var slash_cooldown := 0.0
var slam_cooldown := 0.0
## Holding a base crate: both hands are busy, so no attacks, and walking is slower.
var carrying := false
## Where a fall out of the world returns the player; the game moves it to the built base.
var spawn_point := Vector3(0, 0.2, 150)

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.75
	collider.shape = shape
	collider.position.y = 0.88
	add_child(collider)
	view = CharacterView.new()
	view.name = "Visual"
	add_child(view)
	view.rotation.y = PI

func _physics_process(delta: float) -> void:
	slash_cooldown = maxf(0, slash_cooldown - delta)
	slam_cooldown = maxf(0, slam_cooldown - delta)
	invulnerability = maxf(0, invulnerability - delta)
	if dodge_charges < 2:
		recharge_elapsed += delta
		if recharge_elapsed >= CombatRules.DODGE_RECHARGE:
			dodge_charges += 1
			recharge_elapsed -= CombatRules.DODGE_RECHARGE
	else:
		recharge_elapsed = 0
	var direction := CombatRules.move_direction(Input.get_vector("move_left", "move_right", "move_forward", "move_back"), camera_yaw)
	if Input.is_action_just_pressed("dodge"):
		try_dodge(direction)
	if dodge_left <= 0:
		if Input.is_action_just_pressed("slam"):
			try_attack(training.secondary)
		elif Input.is_action_pressed("attack"):
			try_attack(training.primary)
	if not is_on_floor():
		velocity.y -= CombatRules.GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and dodge_left <= 0 and attack_name.is_empty():
		velocity.y = CombatRules.JUMP_SPEED
	if dodge_left > 0:
		dodge_left = maxf(0, dodge_left - delta)
		velocity.x = dodge_direction.x * CombatRules.DODGE_SPEED
		velocity.z = dodge_direction.z * CombatRules.DODGE_SPEED
	else:
		var speed := CombatRules.RUN_SPEED if Input.is_action_pressed("sprint") else CombatRules.WALK_SPEED
		speed *= haste
		if not attack_name.is_empty():
			speed *= 0.42
		elif carrying:
			speed *= 0.75
		velocity.x = move_toward(velocity.x, direction.x * speed, 35 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 35 * delta)
		if direction.length_squared() > 0.01 and attack_name.is_empty():
			view.rotation.y = lerp_angle(view.rotation.y, atan2(direction.x, direction.z), minf(1, delta * 18))
	move_and_slide()
	_advance_attack(delta)
	var action := "dodge" if dodge_left > 0 else attack_name
	var progress := attack_elapsed / float(attack_definition.get("duration", 1.0))
	view.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), action, progress, carrying)
	if global_position.y < -8:
		respawn(spawn_point)

func try_attack(action: String) -> bool:
	if action not in CombatTraining.SCHOOLS:
		return false
	if dodge_left > 0 or not attack_name.is_empty() or health <= 0 or carrying:
		return false
	var primary_action := action in CombatTraining.PRIMARY
	if (primary_action and slash_cooldown > 0) or (not primary_action and slam_cooldown > 0):
		return false
	attack_definition = training.definition(action)
	attack_name = action
	attack_elapsed = 0
	attack_has_hit = false
	view.rotation.y = camera_yaw + PI
	if not primary_action:
		slam_cooldown = attack_definition.cooldown
	else:
		slash_cooldown = attack_definition.cooldown
	action_started.emit(action)
	return true

func _advance_attack(delta: float) -> void:
	if attack_name.is_empty():
		return
	attack_elapsed += delta
	if not attack_has_hit and attack_elapsed >= float(attack_definition.windup):
		attack_has_hit = true
		attack_landed.emit(global_position, Vector3.BACK.rotated(Vector3.UP, view.rotation.y), attack_definition)
	if attack_elapsed >= float(attack_definition.duration):
		attack_name = ""

func try_dodge(direction: Vector3) -> bool:
	if dodge_charges <= 0 or dodge_left > 0 or health <= 0:
		return false
	if not attack_name.is_empty() and not attack_has_hit:
		return false
	attack_name = ""
	dodge_charges -= 1
	dodge_left = CombatRules.DODGE_DURATION
	invulnerability = CombatRules.DODGE_INVULNERABLE
	dodge_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.FORWARD.rotated(Vector3.UP, camera_yaw)
	view.rotation.y = atan2(dodge_direction.x, dodge_direction.z)
	action_started.emit("dodge")
	return true

func take_damage(amount: float) -> bool:
	if invulnerability > 0 or health <= 0:
		return false
	health = maxf(0, health - amount * protection)
	invulnerability = 0.45
	if health <= 0:
		defeated.emit()
	return true

func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	health = 100
	invulnerability = 2.0
	attack_name = ""
	dodge_left = 0
	dodge_charges = 2
	recharge_elapsed = 0
