class_name DungeonDiscoveryView
extends Node3D
## Decorative additions to the authored level; no collision or navigation edits.
## The far beacon identifies the destination, while the lectern is a local quest target.

var expedition: Expedition
var record_caption: Label3D
var record_glow: MeshInstance3D
var portal: MeshInstance3D
var previous_stage := -1
var previous_record := false

func _ready() -> void:
	var doorway := Node3D.new()
	add_child(doorway)
	# Behind the existing rear wall: the unexplored descent is a distant landmark.
	doorway.position = Vector3(0, 7, -30.3)
	portal = Geometry.ring(doorway, 3.8, Color("8dcfc9"), 0.11)
	portal.rotation.x = PI / 2
	portal.material_override = Geometry.material(Color("8dcfc9"), 1.1)
	for i in range(5):
		var angle := i * TAU / 5 - PI / 2
		var rune := Geometry.box(doorway, Vector3(cos(angle) * 3.8, sin(angle) * 3.8, 0), Vector3(0.48, 0.48, 0.16), Color("e7d49f"))
		rune.rotation.z = angle
		rune.material_override = Geometry.material(Color("e7d49f"), 0.6)
	var beacon := Geometry.cylinder(self, Vector3(0, 21, -30.3), 0.22, 36, Color(0.55, 0.83, 0.82, 0.24), 0.05)
	beacon.material_override = Geometry.material(Color(0.55, 0.83, 0.82, 0.24), 0.5)
	var lectern := Node3D.new()
	lectern.name = "EntranceRecord"
	lectern.position = ExpeditionCampaign.RECORD_POSITION
	add_child(lectern)
	Geometry.cylinder(lectern, Vector3(0, 0.3, 0), 0.65, 0.6, Color("708681"))
	var tablet := Geometry.box(lectern, Vector3(0, 0.85, 0), Vector3(1.0, 0.14, 0.7), Color("c1cabb"))
	tablet.rotation.x = 0.22
	for i in range(3):
		Geometry.box(lectern, Vector3(0, 0.97 + i * 0.04, -0.15 + i * 0.15), Vector3(0.60 - i * 0.10, 0.025, 0.035), Color("526a68"))
	record_glow = Geometry.ring(lectern, 1.0, Color("e8cf90"), 0.04)
	record_glow.material_override = Geometry.material(Color("e8cf90"), 0.45)
	record_caption = Geometry.label(lectern, "", 2.7, Color("f4e4b6"))
	_refresh()

func _process(_delta: float) -> void:
	if previous_stage != expedition.stage or previous_record != expedition.entrance_record:
		_refresh()

func _refresh() -> void:
	previous_stage = expedition.stage
	previous_record = expedition.entrance_record
	record_caption.text = "첫 탐사 기록 · 확보" if expedition.entrance_record else "입구 기록판 · E 조사"
	record_glow.visible = expedition.stage == Expedition.Stage.RECOVERING and not expedition.entrance_record
	record_caption.visible = expedition.stage in [Expedition.Stage.CLEARING, Expedition.Stage.RECOVERING, Expedition.Stage.REPORT, Expedition.Stage.COMPLETE]
