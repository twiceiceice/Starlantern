class_name CareerProgress
extends RefCounted
## One selected contract at a time; other paths never gate its completion.
const PATHS := ["hero", "warden", "explorer", "artisan"]
const TITLES := {
	"hero": ["토벌자", "정예 토벌자", "용사"],
	"warden": ["호위병", "원정 기사", "수호자"],
	"explorer": ["정찰자", "길잡이", "개척자"],
	"artisan": ["견습 기공사", "룬기공사", "룬장인"],
}
const DESCRIPTIONS := {
	"hero": "강적의 약점을 열고 별문의 위협을 끝냅니다.",
	"warden": "학자와 보급대를 지키며 모두의 귀환을 책임집니다.",
	"explorer": "흔적과 표식을 연결해 다음 원정의 길을 엽니다.",
	"artisan": "길드가 조달한 부품으로 고대 장치와 골렘을 복구합니다.",
}
const TACTICS := {"hero": "약점 낙인", "warden": "수호 결계", "explorer": "바람길", "artisan": "룬 골렘"}
const TACTIC_DETAILS := {
	"hero": "전방 10m 적에게 약점 낙인. 무기·마법·소환 피해가 50% 증가합니다.",
	"warden": "주변 7m에 결계. 자신과 호위 대상이 받는 피해를 65% 줄입니다.",
	"explorer": "회피를 충전하고 이동 속도를 45% 높이며 조사 시간을 줄입니다.",
	"artisan": "제자리에서 가까운 적을 공격하는 룬 골렘을 설치합니다.",
}
var path := ""
var completed := {"hero": 0, "warden": 0, "explorer": 0, "artisan": 0}
var active := false
var step_index := 0
var awaiting_report := false
var failed := false

func choose(id: String, campaign_complete: bool) -> bool:
	if not campaign_complete or id not in PATHS or active or int(completed[id]) >= 3:
		return false
	path = id
	active = true
	step_index = 0
	awaiting_report = false
	failed = false
	return true

func rank() -> int:
	if path.is_empty(): return 0
	return 2 if int(completed[path]) >= 3 else (1 if int(completed[path]) >= 1 else 0)

func title() -> String:
	return "선발 조사단원" if path.is_empty() else str(TITLES[path][rank()])

func mission() -> Dictionary:
	if path.is_empty() or int(completed[path]) >= 3: return {}
	return CareerContracts.QUESTS[path][int(completed[path])]

func step() -> Dictionary:
	if not active or awaiting_report: return {}
	return mission().steps[step_index]

func advance(expected_step: int) -> bool:
	if not active or awaiting_report or expected_step != step_index: return false
	step_index += 1
	awaiting_report = step_index >= mission().steps.size()
	return true

func report() -> bool:
	if not active or not awaiting_report: return false
	completed[path] = int(completed[path]) + 1
	active = false
	awaiting_report = false
	step_index = 0
	return true

func fail() -> void:
	active = false
	awaiting_report = false
	step_index = 0
	failed = true

func to_data() -> Dictionary:
	return {"path": path, "completed": completed.duplicate()}

func restore(data: Dictionary) -> void:
	path = str(data.get("path", ""))
	if path not in PATHS: path = ""
	var saved: Variant = data.get("completed", {})
	if saved is Dictionary:
		for id in PATHS:
			var amount: Variant = saved.get(id, 0)
			completed[id] = clampi(int(amount), 0, 3) if amount is float or amount is int else 0
	active = false
	awaiting_report = false
	step_index = 0
	failed = false
