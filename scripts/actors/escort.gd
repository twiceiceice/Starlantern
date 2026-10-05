class_name ExpeditionEscort
extends CharacterBody3D
signal lost
var player: ExpeditionPlayer
var destination := Vector3.ZERO
var mobile := true
var wagon := false
var health := 100.0
var protection := 1.0
var caption: Label3D
var agent: NavigationAgent3D
var view: CharacterView
var reached := false
var stalled := ""
var repath := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	collider.shape = shape
	collider.position.y = 0.8
	add_child(collider)
	view = CharacterView.new()
	view.occupation = "porter"
	view.coat = Color("b69579")
	add_child(view)
	if wagon or not mobile:
		Geometry.box(self, Vector3(0, 0.5, -0.7), Vector3(1.6, 0.7, 1.8), Color("a88c63"))
		for x: float in [-0.85, 0.85]:
			Geometry.sphere(self, Vector3(x, 0.3, -0.7), Vector3(0.22, 0.6, 0.6), Color("665a4a"))
	caption = Geometry.label(self, "", 2.7, Color("b8e3d3"))
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.35
	agent.target_desired_distance = 0.6
	add_child(agent)

func _physics_process(delta: float) -> void:
	if health <= 0: return
	stalled = ""
	if global_position.distance_to(player.global_position) > 8: stalled = "동행자를 기다리는 중"
	for enemy: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(global_position) < 8:
			stalled = "주변의 적부터 막아 주세요"
			break
	reached = global_position.distance_to(destination) < 1.2
	velocity.x = 0
	velocity.z = 0
	if mobile and not reached and stalled.is_empty() and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
		repath -= delta
		if repath <= 0:
			agent.target_position = destination
			repath = 0.3
		var heading := global_position.direction_to(agent.get_next_path_position())
		velocity.x = heading.x * 2.4
		velocity.z = heading.z * 2.4
		view.rotation.y = lerp_angle(view.rotation.y, atan2(heading.x, heading.z), delta * 8)
	if not is_on_floor(): velocity.y -= CombatRules.GRAVITY * delta
	move_and_slide()
	view.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor())
	caption.text = "%s · %d / 100\n%s" % ["부상자 수레" if wagon else ("학자 세온" if mobile else "의무대 보급품"), health, stalled]

func take_damage(amount: float) -> bool:
	if health <= 0: return false
	health = maxf(0, health - amount * protection)
	if health <= 0: lost.emit()
	return true
