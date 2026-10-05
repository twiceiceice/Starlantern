class_name SettlementView
extends Node3D
## The forward base growing with construction progress. Footprints match the ground the
## world factory reserved, so navigation already routes around every building.

var progress := 0.0
var built := 0
var progress_label: Label3D
var stages: Array[Callable] = []

func _ready() -> void:
	progress_label = Geometry.label(self, "", 3.4, Color("f7e1af"))
	progress_label.visible = false
	stages = [
		func(): _tent(Vector3(-6.2, 0, 3), Color("cb9777")),
		func(): _tent(Vector3(6.5, 0, 3), Color("829eae")),
		func(): _fire(Vector3(0, 0, 4)),
		func(): _sign(),
	]

func set_progress(value: float, building: bool) -> void:
	progress = value
	progress_label.visible = building and progress < 100
	progress_label.text = "전진 기지 건설  %d%%" % progress
	# Thresholds 25 / 50 / 75 / 100 put up the next structure.
	while built < stages.size() and progress >= (built + 1) * 100.0 / stages.size():
		stages[built].call()
		built += 1

func _tent(at: Vector3, tint: Color) -> void:
	var tent := Node3D.new()
	tent.position = at
	add_child(tent)
	Geometry.solid_box(tent, Vector3(0, 0.7, 0), Vector3(3.7, 1.4, 3.8), tint.darkened(0.2))
	for side: float in [-1, 1]:
		var roof := Geometry.box(tent, Vector3(side * 1.04, 1.75, 0), Vector3(2.8, 0.15, 4.2), tint)
		roof.rotation.z = -side * 0.65
	Geometry.box(tent, Vector3(0, 0.85, -1.925), Vector3(1.2, 1.7, 0.06), Color("354b4c"))
	Geometry.cylinder(tent, Vector3(0, 1.2, -2.1), 0.065, 2.5, Color("9a8056"))
	Geometry.box(tent, Vector3(0, 2.8, 0), Vector3(0.11, 0.11, 4.5), Color("725f44"))
	tent.scale = Vector3.ONE * 0.2
	create_tween().tween_property(tent, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)

func _fire(at: Vector3) -> void:
	Geometry.cylinder(self, at + Vector3(0, 0.09, 0), 0.95, 0.17, Color("776f5a"))
	for i in range(3):
		var ember := Geometry.sphere(self, at + Vector3((i - 1) * 0.2, 0.5, 0), Vector3(0.34, 0.9, 0.4), Color("ffbf75"))
		ember.material_override = Geometry.material(Color("ffc578"), 0.8)
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0, 1, 0)
	glow.light_color = Color("ffb85d")
	glow.light_energy = 1.4
	glow.omni_range = 7
	add_child(glow)

func _sign() -> void:
	var sign := Node3D.new()
	sign.position = Vector3(0, 0, 6)
	add_child(sign)
	Geometry.label(sign, "별등 전진 기지", 2.4, Color("f7e1af"))
	LanternGlow.post(self, Vector3(1.6, 0, 6), 2.6)
