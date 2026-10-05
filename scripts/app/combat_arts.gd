class_name CombatArts
extends Node3D
signal notice(text: String)
signal hit_feedback(heavy: bool)
var player: ExpeditionPlayer
var career: CareerProgress
var missions: CareerDirector
var effects: CombatEffects
var tactic_cooldown := 0.0
var boon_left := 0.0
var boon_path := ""
var field: Node3D
var summons: Array[Dictionary] = []

func _clear_ray(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, to + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func resolve_attack(origin: Vector3, facing: Vector3, definition: Dictionary) -> void:
	var action := str(definition.get("action", "slash"))
	if action == "familiar":
		_spawn_summon(false)
		return
	var candidates: Array[RuinGuardian] = []
	for foe: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
		if CombatRules.within_arc(origin, facing, foe.global_position, definition.range, definition.angle) and _clear_ray(origin, foe.global_position): candidates.append(foe)
	candidates.sort_custom(func(a,b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	if action == "bolt":
		if candidates.size() > 1: candidates.resize(1)
		var end := origin + facing * float(definition.range)
		if not candidates.is_empty(): end = candidates[0].global_position
		_beam(origin + Vector3.UP, end + Vector3.UP, Color("9fdbf2"))
	else:
		effects.swing(origin, facing, action != "slash")
	for foe in candidates:
		var damage: float = foe.take_damage(float(definition.damage), (foe.global_position-origin).normalized())
		effects.damage_number(foe.global_position, damage)
	if not candidates.is_empty():
		_practice(action)
		hit_feedback.emit(float(definition.damage) >= 40)

func _practice(action: String) -> void:
	if player.training.practice(action):
		var school: String = CombatTraining.SCHOOLS[action]
		notice.emit("%s 숙련 %d단계! K에서 성장과 기술 조합을 확인하세요." % [CombatTraining.SCHOOL_NAMES[school], player.training.level(school)])

func use_tactic() -> bool:
	if career.path.is_empty() or tactic_cooldown > 0 or player.carrying or player.health <= 0 or not player.attack_name.is_empty() or player.dodge_left > 0: return false
	var rank := career.rank()
	match career.path:
		"hero":
			var found := false
			var forward := Vector3.FORWARD.rotated(Vector3.UP,player.camera_yaw)
			for foe: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
				if CombatRules.within_arc(player.global_position,forward,foe.global_position,10,150) and _clear_ray(player.global_position,foe.global_position):
					foe.exposed_left = 6 + rank * 2
					_beam(player.global_position+Vector3.UP,foe.global_position+Vector3.UP,Color("eed492"))
					found = true
			if not found:
				notice.emit("전방 10m 안의 적에게 약점 낙인을 남깁니다.")
				return false
		"warden":
			if is_instance_valid(field): field.queue_free()
			field = Node3D.new()
			add_child(field)
			field.global_position = player.global_position
			Geometry.ring(field,7,Color("92d7d6"),0.08)
			Geometry.cylinder(field,Vector3(0,0.03,0),7,0.04,Color(0.4,0.85,0.8,0.12))
			boon_left = 6 + rank * 2
			boon_path = "warden"
		"explorer":
			boon_left = 5 + rank * 2
			boon_path = "explorer"
			player.dodge_charges = 2
			effects.swing(player.global_position,Vector3.FORWARD,true)
		"artisan": _spawn_summon(true)
	tactic_cooldown = 22 - rank * 3
	notice.emit("%s · %s" % [career.title(),CareerProgress.TACTICS[career.path]])
	return true

func _spawn_summon(construct: bool) -> void:
	# Recasting replaces the same summon; the familiar and career construct can coexist.
	for i in range(summons.size()-1,-1,-1):
		if bool(summons[i].construct) == construct:
			summons[i].node.queue_free()
			summons.remove_at(i)
	var node := Node3D.new()
	add_child(node)
	node.global_position = player.global_position + Vector3(1.3 if construct else -1.3,0,0)
	if construct:
		Geometry.sphere(node,Vector3(0,0.7,0),Vector3(0.9,1.2,0.8),Color("8faea2"))
		Geometry.sphere(node,Vector3(0,1.35,0.1),Vector3.ONE * 0.5,Color("e9c17c"))
		Geometry.ring(node,0.9,Color("ecd693"))
	else:
		Geometry.sphere(node,Vector3(0,0.65,0),Vector3(0.7,0.45,0.9),Color("9cd8df"))
		Geometry.sphere(node,Vector3(0,0.9,-0.35),Vector3.ONE * 0.45,Color("c0eced"))
		for x: float in [-0.14,0.14]: Geometry.cylinder(node,Vector3(x,1.22,-0.35),0.10,0.4,Color("bbe7eb"),0.0)
	Geometry.label(node,"룬 골렘" if construct else "별여우",1.7,Color("b7e0db"))
	var level := player.training.level("bond")
	summons.append({"node":node,"construct":construct,"left":10.0+career.rank()*4 if construct else 9.0+level*2,"pulse":0.4,"trained":false,"damage":10.0+career.rank()*3 if construct else 11.0+level*2})

func _physics_process(delta: float) -> void:
	tactic_cooldown = maxf(0,tactic_cooldown-delta)
	boon_left = maxf(0,boon_left-delta)
	player.protection = 1
	player.haste = 1
	if is_instance_valid(missions.escort): missions.escort.protection = 1
	if boon_left > 0:
		if boon_path == "explorer": player.haste = 1.45
		elif boon_path == "warden" and is_instance_valid(field):
			if player.global_position.distance_to(field.global_position) < 7: player.protection = 0.35
			if is_instance_valid(missions.escort) and missions.escort.global_position.distance_to(field.global_position) < 7: missions.escort.protection = 0.35
	elif is_instance_valid(field):
		field.queue_free()
		field = null
	for i in range(summons.size()-1,-1,-1):
		var summon: Dictionary = summons[i]
		summon.left -= delta
		if summon.left <= 0:
			summon.node.queue_free()
			summons.remove_at(i)
			continue
		var node: Node3D = summon.node
		if not summon.construct: node.global_position = node.global_position.lerp(player.global_position+Vector3(-1.3,0.3,0.6),minf(1,delta*5))
		summon.pulse -= delta
		if summon.pulse > 0: continue
		summon.pulse = 1.1
		var nearest: RuinGuardian
		var distance := 10.0
		for foe: RuinGuardian in get_tree().get_nodes_in_group("enemies"):
			var gap := node.global_position.distance_to(foe.global_position)
			if gap < distance and _clear_ray(node.global_position,foe.global_position):
				distance = gap
				nearest = foe
		if nearest:
			_beam(node.global_position+Vector3.UP,nearest.global_position+Vector3.UP,Color("96d8d9"))
			var damage := nearest.take_damage(float(summon.damage),Vector3.ZERO)
			effects.damage_number(nearest.global_position,damage)
			if not summon.construct and not summon.trained:
				summon.trained = true
				_practice("familiar")

func _beam(from: Vector3, to: Vector3, tint: Color) -> void:
	var bolt := Geometry.sphere(self,from,Vector3.ONE*0.25,tint)
	bolt.material_override = Geometry.material(tint,0.7)
	var tween := create_tween()
	tween.tween_property(bolt,"global_position",to,0.13)
	tween.tween_callback(bolt.queue_free)

func reset_effects() -> void:
	boon_left = 0
	player.protection = 1
	player.haste = 1
	if is_instance_valid(missions.escort): missions.escort.protection = 1
	if is_instance_valid(field): field.queue_free()
	field = null
	for summon in summons: summon.node.queue_free()
	summons.clear()
