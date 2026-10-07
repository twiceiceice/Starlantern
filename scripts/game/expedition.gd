class_name Expedition
extends RefCounted
## The expedition ledger has no dependency on scene nodes or character meshes.

enum Stage { CAMP, MARCH, BASE, CLEARING, RECOVERING, REPORT, COMPLETE }
var stage: Stage = Stage.CAMP
var remaining_enemies := 3
var base_progress := 0.0
var deliveries: Dictionary = {}
var resources := {"timber": 0, "crystal": 0}
var entrance_record := false

func to_data() -> Dictionary:
	return {"stage": stage, "base_progress": base_progress, "remaining_enemies": remaining_enemies,
		"entrance_record": entrance_record, "deliveries": deliveries.keys()}

func restore(data: Dictionary) -> void:
	stage = clampi(int(data.get("stage", 0)), Stage.CAMP, Stage.COMPLETE) as Stage
	base_progress = clampf(float(data.get("base_progress", 0)), 0, 100)
	remaining_enemies = clampi(int(data.get("remaining_enemies", 3)), 0, 3)
	entrance_record = bool(data.get("entrance_record", false))
	deliveries.clear()
	for id in data.get("deliveries", []):
		if int(id) in [0, 1]: deliveries[int(id)] = true

func start() -> bool:
	if stage != Stage.CAMP:
		return false
	stage = Stage.MARCH
	return true

func march_complete() -> bool:
	if stage != Stage.MARCH:
		return false
	stage = Stage.BASE
	return true

## Returns true on the build step that finishes the base and opens the ruin.
func base_build(amount: float) -> bool:
	if stage != Stage.BASE:
		return false
	base_progress = minf(100, base_progress + amount)
	if base_progress < 100:
		return false
	stage = Stage.CLEARING if remaining_enemies > 0 else Stage.RECOVERING
	return true

func enemy_defeated() -> bool:
	remaining_enemies = maxi(0, remaining_enemies - 1)
	if remaining_enemies == 0 and stage == Stage.CLEARING:
		stage = Stage.RECOVERING
		return true
	return false

func record_delivery(worker_id: int) -> bool:
	if stage != Stage.RECOVERING or worker_id not in [0, 1] or deliveries.has(worker_id):
		return false
	deliveries[worker_id] = true
	_prepare_report()
	return true

## Both the player's survey and the crews' recovered samples belong in the report.
func collect_entrance_record() -> bool:
	if stage != Stage.RECOVERING or remaining_enemies > 0 or entrance_record:
		return false
	entrance_record = true
	_prepare_report()
	return true

func _prepare_report() -> void:
	if stage == Stage.RECOVERING and entrance_record and deliveries.size() == 2:
		stage = Stage.REPORT

func report() -> bool:
	if stage != Stage.REPORT:
		return false
	resources.timber += 12
	resources.crystal += 6
	stage = Stage.COMPLETE
	return true

func objective(site_lit := true) -> String:
	match stage:
		Stage.CAMP: return "별잠회랑 선발 원정 · 게시판에서 E로 맡을 일 고르기"
		Stage.MARCH: return "원정대와 함께 행군"
		Stage.BASE: return "전진 기지 건설  ·  %d%%" % base_progress
		Stage.CLEARING: return "별잠회랑 입구 확보  ·  파수꾼 %d / 3" % (3 - remaining_enemies)
		Stage.RECOVERING:
			if not site_lit:
				return "유적 안쪽에서 E · 전진 등불 세우기  ·  인부는 빛 안에서만 일합니다"
			if not entrance_record:
				return "입구 안쪽 기록판에서 E · 첫 탐사 기록 확보\n인부의 표본 운반 %d / 2" % deliveries.size()
			return "첫 탐사 기록 확보 · 표본 운반 %d / 2\n등불을 유지하며 조사단의 귀환을 도우세요" % deliveries.size()
		Stage.REPORT: return "전진 기지에서 E · 기록과 표본을 길드에 보고"
		Stage.COMPLETE: return "별문이 열린 날 · 대장정 완료\n별등 전진 기지와 첫 탐사 기록 확보"
	return ""
