class_name Expedition
extends RefCounted
## The expedition ledger has no dependency on scene nodes or character meshes.

enum Stage { CAMP, MARCH, BASE, CLEARING, RECOVERING, REPORT, COMPLETE }
var stage: Stage = Stage.CAMP
var remaining_enemies := 3
var base_progress := 0.0
var deliveries: Dictionary = {}
var resources := {"timber": 0, "crystal": 0}

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
	if deliveries.size() == 2:
		stage = Stage.REPORT
	return true

func report() -> bool:
	if stage != Stage.REPORT:
		return false
	resources.timber += 12
	resources.crystal += 6
	stage = Stage.COMPLETE
	return true

func objective(site_lit := true) -> String:
	match stage:
		Stage.CAMP: return "출발 게시판에서 E · 맡을 일 고르기"
		Stage.MARCH: return "원정대와 함께 행군"
		Stage.BASE: return "전진 기지 건설  ·  %d%%" % base_progress
		Stage.CLEARING: return "북쪽 유적의 파수꾼 정리  ·  %d / 3" % (3 - remaining_enemies)
		Stage.RECOVERING:
			if not site_lit:
				return "유적 안쪽에서 E · 전진 등불 세우기  ·  인부는 빛 안에서만 일합니다"
			return "인부들이 자원을 회수합니다  ·  운반 %d / 2" % deliveries.size()
		Stage.REPORT: return "캠프로 돌아가 E · 회수한 자원 정산"
		Stage.COMPLETE: return "첫 원정 완료  ·  목재 12와 별빛 조각 6 회수"
	return ""
