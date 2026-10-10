class_name ExpeditionWorker
extends CharacterBody3D

signal delivered(worker: ExpeditionWorker)

var player: ExpeditionPlayer
var light: LanternNetwork
var worker_id := 0
var job := "carpenter"
var state := "camp"
var work_position := Vector3.ZERO
var home := Vector3.ZERO
var view: CharacterView
var caption: Label3D
var agent: NavigationAgent3D
var progress := 0.0
var repath := 0.0
var destination := Vector3.ZERO
var safe_to_work := false
var shipping_ready := true

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	home = global_position
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.7
	shape.radius = 0.3
	collider.shape = shape
	collider.position.y = 0.85
	add_child(collider)
	view = CharacterView.new()
	view.occupation = job
	view.coat = Color("9a7354") if job == "carpenter" else Color("668876")
	add_child(view)
	caption = Geometry.label(self, "", 2.45)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.3
	agent.target_desired_distance = 0.45
	add_child(agent)
	_update_caption()

func enlist() -> void:
	if state == "camp":
		state = "follow"
		_update_caption()

func set_home(at: Vector3) -> void:
	home = at

func secure_site() -> void:
	safe_to_work = true
	progress = 0

func _lit(point: Vector3) -> bool:
	return light == null or light.is_lit(point)

func _set_state(next: String) -> void:
	if state != next:
		state = next
		repath = 0
		_update_caption()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var moving := false
	if state in ["follow", "waiting"] and safe_to_work and shipping_ready and _lit(work_position):
		_set_state("to_work")
	if state in ["follow", "waiting"]:
		# Walk with the player only while the spot beside them is lit; otherwise hold at the light's edge.
		destination = player.global_position + Vector3(-2.0 if worker_id == 0 else 2.0, 0, 2.5)
		if _lit(destination):
			_set_state("follow")
			moving = global_position.distance_to(destination) > 1.1
		else:
			_set_state("waiting")
	elif state == "to_work":
		destination = work_position
		moving = global_position.distance_to(destination) > 0.8
		if not _lit(work_position):
			_set_state("waiting")
			moving = false
		elif not moving:
			_set_state("working")
	elif state == "working":
		if not _lit(work_position):
			_set_state("waiting")
		else:
			progress += delta
			if progress >= (4.0 if job == "carpenter" else 5.5):
				_set_state("returning")
	elif state == "returning":
		destination = home
		moving = global_position.distance_to(destination) > 0.8
		if not moving:
			state = "delivered"
			_update_caption()
			delivered.emit(self)
	velocity.x = 0
	velocity.z = 0
	if moving and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
		repath -= delta
		if repath <= 0:
			agent.target_position = destination
			repath = 0.35
		if not agent.is_navigation_finished():
			var direction := global_position.direction_to(agent.get_next_path_position())
			velocity.x = direction.x * 4.3
			velocity.z = direction.z * 4.3
			view.rotation.y = lerp_angle(view.rotation.y, atan2(direction.x, direction.z), minf(1, delta * 12))
	if not is_on_floor():
		velocity.y -= CombatRules.GRAVITY * delta
	move_and_slide()
	view.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), "work" if state == "working" else "", 0, state == "returning")

func _update_caption() -> void:
	var names := {"carpenter": "목수 로아", "porter": "운반원 누리"}
	var states := {"camp": "출발 대기", "follow": "동행", "waiting": "빛을 기다리는 중", "to_work": "표본 채집장으로", "working": "탐사 표본 회수 중", "returning": "기지로 표본 운반 중", "delivered": "표본 귀환 완료"}
	caption.text = "%s\n%s" % [names[job], states[state]]
	if safe_to_work and not shipping_ready and state in ["follow","waiting"]:
		caption.text = "%s\n목수의 회수 상자를 기다리는 중" % names[job]
