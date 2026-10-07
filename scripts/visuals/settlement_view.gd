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
		func():
			_tent(Vector3(-6.2, 0, 3), Color("cb9777"))
			CampArt.place(self,"workshop",CampArt.BASE_WORKSHOP)
			CampArt.place(self,"cargo",Vector3(-6.4,0,8.6)),
		func():
			_tent(Vector3(6.5, 0, 3), Color("829eae"))
			CampArt.place(self,"kitchen",CampArt.BASE_KITCHEN)
			CampArt.place(self,"cargo",Vector3(6.4,0,8.6)),
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
	var tent := ExpeditionArt.tent(self,at,tint)
	tent.scale = Vector3.ONE * 0.2
	create_tween().tween_property(tent, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)

func _fire(at: Vector3) -> void:
	CampArt.place(self,"hearth",at)

func _sign() -> void:
	var sign := Node3D.new()
	sign.position = Vector3(0, 0, 6)
	add_child(sign)
	Geometry.label(sign, "별등 전진 기지", 2.4, Color("f7e1af"))
	LanternGlow.post(self, Vector3(1.6, 0, 6), 2.6)
