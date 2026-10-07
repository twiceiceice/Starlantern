extends Node3D
## Background grazing herds, batched like the caravan; no combat or quest state.
var bodies: MultiMeshInstance3D
var heads: MultiMeshInstance3D
var legs: MultiMeshInstance3D
var ears: MultiMeshInstance3D
var homes: Array[Vector3] = []
var time := 0.0

func _ready() -> void:
	var body_frames: Array[Transform3D] = []
	var head_frames: Array[Transform3D] = []
	var leg_frames: Array[Transform3D] = []
	var ear_frames: Array[Transform3D] = []
	var fur: Array[Color] = []
	for i in range(14):
		var center := Vector3(29, 0, 78) if i < 7 else Vector3(-39, 0, 46)
		var angle := i * 2.39
		homes.append(center + Vector3(cos(angle) * (3 + i % 4), 0, sin(angle) * (3 + i % 4)))
		body_frames.append(Transform3D())
		head_frames.append(Transform3D())
		fur.append(Color("a48057").lerp(Color("d4bd91"), float(i % 4) / 3))
		for j in 4: leg_frames.append(Transform3D())
		for j in 2: ear_frames.append(Transform3D())
	bodies = Geometry.instances(self, Geometry.unit_sphere(), body_frames, fur)
	heads = Geometry.instances(self, Geometry.unit_sphere(), head_frames, fur)
	legs = Geometry.instances(self, Geometry.unit_sphere(), leg_frames)
	legs.material_override = Geometry.material(Color("7e674e"))
	ears = Geometry.instances(self, Geometry.unit_sphere(), ear_frames)
	ears.material_override = Geometry.material(Color("bb9d73"))
	_update()

func _process(delta: float) -> void:
	time += delta
	_update()

func _update() -> void:
	for i in homes.size():
		var angle := i * 2.39 + sin(time * 0.13 + i) * 0.15
		var at := RegionLayout.on_ground(RegionLayout.MEADOW, homes[i])
		var frame := Transform3D(Basis(Vector3.UP, angle), at)
		bodies.multimesh.set_instance_transform(i, frame * Transform3D(Basis().scaled(Vector3(0.8, 0.9, 1.6)), Vector3(0, 1.15, 0)))
		var graze := (sin(time * 0.55 + i) + 1) * 0.5
		var head := frame * Transform3D(Basis(Vector3.RIGHT, graze * 0.7), Vector3(0, 1.3 - graze * 0.65, -0.8))
		heads.multimesh.set_instance_transform(i, head * Transform3D(Basis().scaled(Vector3(0.4, 0.6, 0.55)), Vector3.ZERO))
		for j in 4:
			legs.multimesh.set_instance_transform(i * 4 + j, frame * Transform3D(Basis().scaled(Vector3(0.13, 0.95, 0.15)), Vector3(-0.27 if j % 2 else 0.27, 0.5, -0.5 if j < 2 else 0.5)))
		for j in 2:
			ears.multimesh.set_instance_transform(i * 2 + j, head * Transform3D(Basis(Vector3.FORWARD, -0.6 if j == 0 else 0.6).scaled(Vector3(0.13, 0.4, 0.2)), Vector3(-0.22 if j == 0 else 0.22, 0.3, 0)))
