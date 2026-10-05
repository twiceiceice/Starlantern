class_name ExpeditionCampaign
extends RefCounted
## Authored campaign presentation. Progress comes from the expedition ledger,
## never from opening the journal or advancing dialogue.

const TITLE := "별문이 열린 날"
const DESTINATION := "별잠회랑"
const RECORD_POSITION := Vector3(0, 0, -28)
const RECORD_REACH := 2.4
const PREMISE := "사흘 전, 북부 계곡의 땅이 갈라지며 지도에 없던 던전 ‘별잠회랑’이 나타났습니다. 문에서 나온 파수꾼 때문에 첫 측량대는 돌아서야 했습니다."
const COMMISSION := "솔바람 길드는 경비·장인·학자와 운반 인력 300명을 모았습니다. 숲과 고개를 건너 돌아올 기지를 세우고, 입구를 확보해 첫 탐사 기록과 표본을 길드에 전달하세요."
const DISCOVERY := "기록판에는 ‘이곳은 건물의 입구가 아니라, 지하도시의 상층 정거장’이라고 적혀 있습니다. 아래로 이어지는 길과 되돌아올 표식을 옮겨 적었습니다."
const ENDING := "첫 탐사 기록과 표본이 길드에 인계되었습니다. 별잠회랑은 지하도시로 이어지는 입구였습니다. 뒤따라온 장인과 상인들은 별등 전진 기지에 자리를 잡고, 다음 탐사를 준비합니다."
const REWARD := "목재 12 · 별빛 조각 6 · 칭호 ‘선발 조사단원’"
const CHAPTERS := [
	{"title": "300명의 출발", "detail": "출발 게시판에서 맡을 일을 하나 선택"},
	{"title": "숲을 잇는 등불", "detail": "이끼 숲길을 열고 원정대와 함께 횡단"},
	{"title": "문으로 향하는 고개", "detail": "바람 고갯길을 넘어 던전 진입로 확보"},
	{"title": "돌아올 곳을 세우다", "detail": "방어 또는 자재 운반으로 전진 기지 완성"},
	{"title": "별잠회랑의 문턱", "detail": "입구의 파수꾼 셋을 물리쳐 조사단의 길 확보"},
	{"title": "첫 탐사의 증거", "detail": "기록판 조사와 인부 두 사람의 표본 운반"},
	{"title": "별문 앞에 마을을", "detail": "전진 기지에서 첫 탐사 결과를 길드에 보고"},
]

static func chapter(expedition: Expedition, leg: int) -> int:
	match expedition.stage:
		Expedition.Stage.CAMP: return 0
		Expedition.Stage.MARCH: return 1 + clampi(leg, 0, 1)
		Expedition.Stage.BASE: return 3
		Expedition.Stage.CLEARING: return 4
		Expedition.Stage.RECOVERING: return 5
		Expedition.Stage.REPORT: return 6
		Expedition.Stage.COMPLETE: return CHAPTERS.size()
	return 0

static func journal(expedition: Expedition, leg: int, objective: String, assignment: String) -> Dictionary:
	return {
		"chapter": chapter(expedition, leg),
		"objective": objective,
		"assignment": assignment,
		"record": expedition.entrance_record,
		"deliveries": expedition.deliveries.size(),
		"complete": expedition.stage == Expedition.Stage.COMPLETE,
	}
