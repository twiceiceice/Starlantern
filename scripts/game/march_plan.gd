class_name MarchPlan
extends RefCounted
## The march as chained steps. Each leg is split into stretches ending at a checkpoint
## (distance along the route). Every stretch has a short chain of steps per role; the
## caravan marches to the checkpoint only when both roles' chains are done, and the next
## stretch opens when it arrives. Add content by adding stretches and steps here.
##
## Step kinds: "kill" (guardians at `enemies`), "light" (lantern spots at `spots`),
## "visit" (walk to `at`). Lantern spots must keep the road lit up to each checkpoint.

const LEGS := [
	{"name": "바람결 초원", "stretches": [
		{"end": 18.0,
			"clear": [{"kind": "kill", "text": "초원 입구의 파수꾼 정리", "enemies": [Vector3(-2, 0, 124)]}],
			"light": [{"kind": "light", "text": "초원 입구에 등불 세우기", "spots": [Vector3(0, 0, 131)]}]},
		{"end": 38.0,
			"clear": [{"kind": "visit", "text": "부서진 수레 자국 조사", "at": Vector3(-5.5, 0, 117)},
				{"kind": "kill", "text": "수레를 덮친 매복 파수꾼 정리", "enemies": [Vector3(-3, 0, 110), Vector3(3, 0, 106)]}],
			"light": [{"kind": "visit", "text": "언덕 위 옛 등불 기둥 찾기", "at": Vector3(5.5, 0, 119)},
				{"kind": "light", "text": "옛 기둥의 불씨를 길로 옮기기", "spots": [Vector3(0, 0, 115)]}]},
		{"end": 56.0,
			"clear": [{"kind": "kill", "text": "초원 굽잇길를 지키는 파수꾼 정리", "enemies": [Vector3(2, 0, 95)]}],
			"light": [{"kind": "light", "text": "초원 굽잇길에 등불 세우기", "spots": [Vector3(0, 0, 99)]}]},
	]},
	{"name": "솔바람 도하장", "stretches": [
		{"end": 75.0,
			"clear": [{"kind": "kill", "text": "강변 진입로의 파수꾼 정리", "enemies": [Vector3(-2, 0, 76)]}],
			"light": [{"kind": "light", "text": "강변 진입로에 등불 세우기", "spots": [Vector3(0, 0, 80)]}]},
		{"end": 98.0,
			"clear": [{"kind": "visit", "text": "강변의 수레 진입로 정찰", "at": Vector3(-5, 0, 62)},
				{"kind": "kill", "text": "강변의 파수꾼 둘 정리", "enemies": [Vector3(-2, 0, 55), Vector3(2.5, 0, 51)]}],
			"light": [{"kind": "light", "text": "도하장 앞 등불 자리 밝히기", "spots": [Vector3(0, 0, 64)]},
				{"kind": "light", "text": "강변에 등불 세우기", "spots": [Vector3(0, 0, 48)]}]},
		{"end": 120.0,
			"clear": [{"kind": "kill", "text": "다리를 지키는 파수꾼 정리", "enemies": [Vector3(2, 0, 31)]}],
			"light": [{"kind": "visit", "text": "안전한 도하 경로 찾기", "at": Vector3(5, 0, 40)},
				{"kind": "light", "text": "다리 앞에 등불 세우기", "spots": [Vector3(0, 0, 32)]}],
			"chief": [{"kind": "visit", "text": "우두머리의 발자국 추적", "at": Vector3(-5, 0, 41)},
				{"kind": "kill", "text": "파수꾼 우두머리 정리", "enemies": [Vector3(0, 0, 36)], "chief": true}]},
	]},
]
const ROLES := ["clear", "light"]

var route: Caravan
var leg := 0
var stretch := 0
var chief := false
var progress := {"clear": 0, "light": 0}

func _stretch() -> Dictionary:
	return LEGS[leg].stretches[stretch]

func steps(role: String) -> Array:
	var list: Array = _stretch()[role].duplicate()
	if role == "clear" and chief and _stretch().has("chief"):
		list.append_array(_stretch().chief)
	return list

func active_step(role: String) -> Dictionary:
	var list := steps(role)
	if progress[role] >= list.size(): return {}
	var step: Dictionary = list[progress[role]].duplicate(true)
	if route == null: return step
	for key in ["enemies", "spots"]:
		if step.has(key):
			for i in step[key].size(): step[key][i] = map_point(step[key][i])
	if step.has("at"): step.at = map_point(step.at)
	return step

func map_point(original: Vector3) -> Vector3:
	var along := clampf((146.0 - original.z) / 120.0, 0, 1) * route.length()
	var point := route.point_at(along)
	var side := route.direction_at(along).cross(Vector3.UP).normalized()
	return RegionLayout.on_ground(RegionLayout.MEADOW, point + side * original.x)

## Returns true when this completes the role's chain for the stretch.
func complete_step(role: String) -> bool:
	progress[role] = mini(progress[role] + 1, steps(role).size())
	return progress[role] >= steps(role).size()

func stretch_done() -> bool:
	return ROLES.all(func(role): return progress[role] >= steps(role).size())

func checkpoint() -> float:
	return _stretch().end * (route.length() / 120.0 if route != null else 1.0)

func previous_checkpoint() -> float:
	if stretch > 0:
		return LEGS[leg].stretches[stretch - 1].end * (route.length() / 120.0 if route != null else 1.0)
	if leg > 0:
		return LEGS[leg - 1].stretches[-1].end * (route.length() / 120.0 if route != null else 1.0)
	return 0.0

func leg_finished() -> bool:
	return stretch == LEGS[leg].stretches.size() - 1 and stretch_done()

func next_stretch() -> bool:
	if stretch >= LEGS[leg].stretches.size() - 1:
		return false
	stretch += 1
	progress = {"clear": 0, "light": 0}
	return true

func next_leg(with_chief: bool) -> void:
	leg += 1
	stretch = 0
	chief = with_chief
	progress = {"clear": 0, "light": 0}

func has_next_leg() -> bool:
	return leg < LEGS.size() - 1

## 1-based number of the role's active step counted across the whole leg.
func step_number(role: String) -> int:
	var before := 0
	var saved := stretch
	for i in saved:
		stretch = i
		before += steps(role).size()
	stretch = saved
	return before + mini(progress[role] + 1, steps(role).size())

func step_total(role: String) -> int:
	var total := 0
	var saved := stretch
	for i in LEGS[leg].stretches.size():
		stretch = i
		total += steps(role).size()
	stretch = saved
	return total
