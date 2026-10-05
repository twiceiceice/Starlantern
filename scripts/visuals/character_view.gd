class_name CharacterView
extends Node3D
## Replaceable, procedural stand-in. Gameplay only calls the public pose methods.

var body: Node3D
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var tool: Node3D
var cargo: Node3D
var phase := 0.0
var coat := Color("477794")
var occupation := "hero"

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	var skin := Color("ecc29a")
	var hair := Color("463932")
	var leather := Color("755139")
	Geometry.capsule(body, Vector3(0, 0.98, 0), 0.34, 0.85, coat)
	Geometry.cylinder(body, Vector3(0, 0.66, 0), 0.37, 0.28, coat.darkened(0.1), 0.32)
	Geometry.sphere(body, Vector3(0, 1.66, 0.025), Vector3(0.66, 0.69, 0.59), skin)
	Geometry.sphere(body, Vector3(0, 1.89, -0.025), Vector3(0.72, 0.37, 0.65), hair)
	for offset: Vector3 in [Vector3(-0.23, 1.9, 0.22), Vector3(0.06, 1.98, 0.13), Vector3(0.28, 1.88, 0.12)]:
		Geometry.sphere(body, offset, Vector3(0.29, 0.25, 0.24), hair)
	for x: float in [-0.13, 0.13]:
		Geometry.sphere(body, Vector3(x, 1.70, 0.298), Vector3(0.055, 0.078, 0.035), Color("293534"))
		Geometry.sphere(body, Vector3(x * 1.65, 1.6, 0.258), Vector3(0.09, 0.035, 0.022), Color("d9937d"))
	Geometry.sphere(body, Vector3(0, 1.61, 0.316), Vector3(0.1, 0.1, 0.085), skin)
	Geometry.capsule(body, Vector3(0, 1.35, 0), 0.22, 0.27, Color("e8bc62"))
	Geometry.box(body, Vector3(0.13, 1.13, 0.34), Vector3(0.14, 0.37, 0.065), Color("edc675")).rotation.z = -0.15
	Geometry.sphere(body, Vector3(0, 0.98, -0.36), Vector3(0.56, 0.69, 0.3), leather)
	Geometry.box(body, Vector3(0, 1.11, -0.53), Vector3(0.41, 0.075, 0.03), Color("d1ad71"))
	arm_left = _limb(body, Vector3(-0.40, 1.22, 0), false, coat, skin)
	arm_right = _limb(body, Vector3(0.40, 1.22, 0), false, coat, skin)
	leg_left = _limb(body, Vector3(-0.18, 0.59, 0), true, Color("404f54"), leather)
	leg_right = _limb(body, Vector3(0.18, 0.59, 0), true, Color("404f54"), leather)
	tool = Node3D.new()
	tool.position = Vector3(0, -0.39, 0.12)
	arm_right.add_child(tool)
	Geometry.cylinder(tool, Vector3(0, 0.02, 0.12), 0.035, 0.86, leather).rotation.x = 0.3
	if occupation == "hero":
		Geometry.sphere(tool, Vector3(0.10, 0.43, 0), Vector3(0.51, 0.30, 0.12), Color("a2b8b5"))
		Geometry.box(tool, Vector3(0.28, 0.43, 0), Vector3(0.09, 0.28, 0.13), Color("e0e8d9"))
	elif occupation == "carpenter":
		Geometry.box(tool, Vector3(0, 0.38, 0), Vector3(0.38, 0.2, 0.22), Color("7c8e8c"))
	else:
		tool.visible = false
	cargo = Node3D.new()
	cargo.position = Vector3(0, 0.85, 0.55)
	body.add_child(cargo)
	Geometry.box(cargo, Vector3.ZERO, Vector3(0.67, 0.48, 0.45), Color("ac7b48"))
	Geometry.box(cargo, Vector3(0, 0.02, 0.24), Vector3(0.06, 0.5, 0.03), Color("e8c594"))
	cargo.visible = false

func _limb(parent: Node3D, origin: Vector3, leg: bool, cloth: Color, end: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = origin
	parent.add_child(pivot)
	Geometry.capsule(pivot, Vector3(0, -0.18, 0), 0.105 if leg else 0.11, 0.39, cloth)
	Geometry.sphere(pivot, Vector3(0, -0.40, 0.055), Vector3(0.24, 0.25, 0.36) if leg else Vector3(0.22, 0.24, 0.22), end)
	return pivot

func animate(delta: float, speed: float, grounded: bool, action: String = "", progress: float = 0.0, carrying: bool = false) -> void:
	phase += delta * (5 + speed * 1.8)
	var stride := clampf(speed / 7.0, 0, 1)
	var wave := sin(phase) * stride * 0.8
	body.position.y = absf(sin(phase)) * stride * 0.055 + sin(phase * 0.4) * 0.01
	body.rotation = Vector3.ZERO
	leg_left.rotation.x = wave if grounded else -0.45
	leg_right.rotation.x = -wave if grounded else 0.3
	arm_left.rotation = Vector3(-wave * 0.6, 0, 0.07)
	arm_right.rotation = Vector3(wave * 0.6 - 0.15, 0, -0.07)
	cargo.visible = carrying
	if carrying:
		arm_left.rotation.x = -0.9
		arm_right.rotation.x = -0.9
	if action == "slash":
		var swing := sin(progress * PI)
		body.rotation.y = lerpf(-0.6, 0.85, progress)
		arm_right.rotation = Vector3(-1.2 * swing, -1.4 + progress * 2.8, -0.65 * swing)
	elif action == "slam":
		var raise := sin(minf(progress / 0.52, 1.0) * PI * 0.5)
		arm_right.rotation.x = -2.8 * raise if progress < 0.52 else lerpf(-2.8, -0.25, minf((progress - 0.52) * 5.0, 1.0))
		arm_left.rotation.x = arm_right.rotation.x * 0.8
		body.rotation.x = -0.2 if progress < 0.52 else 0.3 * sin(progress * PI)
	elif action == "dodge":
		body.rotation.x = -0.65
		body.position.y -= 0.20
	elif action == "work":
		arm_right.rotation.x = -0.5 - absf(sin(phase)) * 1.5
