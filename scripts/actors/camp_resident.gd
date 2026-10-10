class_name CampResident
extends CharacterBody3D
## Two representative tradespeople. Crowd members remain inexpensive MultiMeshes.
var ledger: CampProduction
var role := "carpenter"
var home := Vector3.ZERO
var pickup_point := Vector3.ZERO
var work_point := Vector3.ZERO
var work_target := Vector3.ZERO
var delivery_point := Vector3.ZERO
var depot := Vector3.ZERO
var view: CharacterView
var agent: NavigationAgent3D
var caption: Label3D
var needs_path := true
var target := Vector3.ZERO
var last_phase := ""
var blocked := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = .29
	shape.height = 1.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = .85
	add_child(collider)
	view = CharacterView.new()
	view.occupation = role
	view.coat = Color("927152") if role == "carpenter" else Color("87937a")
	add_child(view)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = .22
	agent.target_desired_distance = .28
	add_child(agent)
	caption = Geometry.label(self,"",2.4)
	caption.visibility_range_end = 13
	caption.no_depth_test = false
	var saved: Dictionary = ledger.jobs[role]
	var at: Variant = saved.get("position",[])
	if at is Array and at.size() == 3:
		var point := Vector3(float(at[0]),float(at[1]),float(at[2]))
		if point.is_finite() and Rect2(-12,3,24,25).has_point(Vector2(point.x,point.z)):
			position = point

func _physics_process(delta: float) -> void:
	var job := ledger.request(role)
	var action := ""
	var carrying := false
	target = home
	if not job.is_empty():
		var phase: String = job.phase
		if phase != last_phase: needs_path = true; last_phase = phase
		match phase:
			"fetch": target = depot if job.kind == "shipment" else pickup_point
			"to_work", "working": target = work_point
			"deliver": target = depot if job.kind == "crates" else delivery_point
		carrying = phase in ["to_work","deliver"]
		if not blocked and Vector2(position.x-target.x,position.z-target.z).length() < .14:
			match phase:
				"fetch": ledger.pickup(role)
				"to_work": job.phase = "working"; ledger.changed.emit()
				"working":
					action = "craft" if role == "carpenter" else "cook"
					var facing := position.direction_to(work_target)
					view.rotation.y = lerp_angle(view.rotation.y,atan2(facing.x,facing.z),minf(1,delta*12))
					job.progress += delta
					if job.progress >= 6.0: job.phase = "deliver"; ledger.changed.emit()
				"deliver": ledger.finish(role)
		job.position = [position.x,position.y,position.z]
	velocity.x = 0
	velocity.z = 0
	if not blocked and action.is_empty() and Vector2(position.x-target.x,position.z-target.z).length() >= .14 and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0:
		# Stations are fixed. Replacing the path every few frames can repeatedly
		# send an off-mesh arrival back to the first point of its new path.
		if needs_path or agent.target_position != target:
			agent.target_position = target
			needs_path = false
		var next := agent.get_next_path_position()
		# Final short approach aligns palms with the station; move_and_slide still enforces furniture collision.
		if position.distance_to(target) < 1.35: next = target
		var direction := Vector3(next.x-position.x,0,next.z-position.z).normalized()
		var speed := minf(2.6,position.distance_to(target)/maxf(delta,.001))
		velocity.x = direction.x*speed
		velocity.z = direction.z*speed
		view.rotation.y = lerp_angle(view.rotation.y,atan2(direction.x,direction.z),minf(1,delta*12))
	if not is_on_floor(): velocity.y -= CombatRules.GRAVITY*delta
	move_and_slide()
	view.animate(delta,Vector2(velocity.x,velocity.z).length(),is_on_floor(),action,0,carrying)
	if not action.is_empty(): view.work_at(work_target,action)
	var task := "상자 만들 목재를 기다리는 중" if role == "carpenter" and not ledger.kits_ready else ("다음 회수품을 기다리는 중" if role == "carpenter" else "다음 식자재를 기다리는 중")
	if not job.is_empty():
		var item: String = {"crates":"회수 상자","shipment":"회수품","meal":"따뜻한 식사"}[job.kind]
		task = {"fetch":"보급품 가지러","to_work":"작업장으로 운반","working":item+" 준비 중","deliver":item+" 인계 중"}[job.phase]
	if blocked: task = "위험이 지나가길 기다리는 중"
	caption.text = ("목수 세온" if role == "carpenter" else "취사 담당 하루")+"\n"+task
