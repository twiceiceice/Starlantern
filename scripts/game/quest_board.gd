class_name QuestBoard
extends RefCounted
## One quest per stage. The quest the player takes is their role for that stage;
## the role they leave is done by the caravan's NPC crews at a cost.

const QUESTS := {
	"leg1_clear": {"title": "길목의 파수꾼 토벌", "role": "clear", "detail": "행렬을 막는 파수꾼을 직접 정리합니다.\n등불은 등불꾼이 느리게 세웁니다.", "next": "leg2_chief"},
	"leg1_light": {"title": "숲길 등불 밝히기", "role": "light", "detail": "표시된 등불 자리에 등불을 세웁니다.\n파수꾼은 경비대가 맡지만 사람을 잃습니다."},
	"leg2_clear": {"title": "고갯길 파수꾼 토벌", "role": "clear", "detail": "고갯길의 파수꾼을 직접 정리합니다.\n등불은 등불꾼이 느리게 세웁니다."},
	"leg2_chief": {"title": "연속 · 파수꾼 우두머리 추적", "role": "clear", "detail": "길목에서 본 흔적을 따라 우두머리까지 정리합니다.\n등불은 등불꾼이 느리게 세웁니다.", "chief": true},
	"leg2_light": {"title": "고갯길 등불 밝히기", "role": "light", "detail": "고갯길의 등불 자리에 등불을 세웁니다.\n파수꾼은 경비대가 맡지만 사람을 잃습니다."},
	"base_carry": {"title": "기지 자재 나르기", "role": "carry", "detail": "짐마차의 자재를 하치장으로 옮겨 건설을 앞당깁니다.\n습격은 경비대가 막지만 사람을 잃습니다."},
	"base_defend": {"title": "기지 습격 막기", "role": "defend", "detail": "기지 둘레의 습격자를 직접 막습니다.\n자재는 인부들이 천천히 옮깁니다."},
}
const STAGES := [["leg1_clear", "leg1_light"], ["leg2_clear", "leg2_light"], ["base_carry", "base_defend"]]
const ROLE_NAMES := {"clear": "토벌", "light": "등불지기", "carry": "운반", "defend": "방어"}

var stage := 0
var chosen := ""
var unlocked: Array[String] = []

func offers() -> Array:
	if done():
		return []
	var list: Array = []
	for id: String in STAGES[stage]:
		list.append(_follow_up(id))
	return list

func _follow_up(id: String) -> String:
	for next in unlocked:
		if QUESTS[next].role == QUESTS[id].role and next.begins_with(id.get_slice("_", 0)):
			return next
	return id

func choose(id: String) -> bool:
	if not chosen.is_empty() or id not in offers():
		return false
	chosen = id
	return true

func role() -> String:
	return "" if chosen.is_empty() else QUESTS[chosen].role

func quest() -> Dictionary:
	return {} if chosen.is_empty() else QUESTS[chosen]

func finish_stage() -> void:
	if QUESTS.has(chosen) and QUESTS[chosen].has("next"):
		unlocked.append(QUESTS[chosen].next)
	chosen = ""
	stage += 1

func done() -> bool:
	return stage >= STAGES.size()
