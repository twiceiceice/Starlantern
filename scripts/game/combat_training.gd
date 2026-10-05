class_name CombatTraining
extends RefCounted
## A discipline grows through successful actions, independently of career contracts.
const PRIMARY := ["slash", "bolt"]
const SECONDARY := ["slam", "nova", "familiar"]
const NAMES := {"slash": "가로베기", "slam": "내려찍기", "bolt": "별빛 화살", "nova": "서리 파동", "familiar": "별여우 소환"}
const SCHOOLS := {"slash": "steel", "slam": "steel", "bolt": "arcana", "nova": "arcana", "familiar": "bond"}
const SCHOOL_NAMES := {"steel": "무기", "arcana": "마법", "bond": "소환"}
const THRESHOLDS := [0, 6, 18]
var primary := "slash"
var secondary := "slam"
var experience := {"steel": 0, "arcana": 0, "bond": 0}

func equip(slot: int, action: String) -> bool:
	if slot == 0 and action in PRIMARY: primary = action
	elif slot == 1 and action in SECONDARY: secondary = action
	else: return false
	return true

func level(school: String) -> int:
	var xp := int(experience.get(school, 0))
	return 3 if xp >= 18 else (2 if xp >= 6 else 1)

func practice(action: String) -> bool:
	if not SCHOOLS.has(action): return false
	var school: String = SCHOOLS[action]
	var before := level(school)
	experience[school] = mini(18, int(experience[school]) + 1)
	return level(school) > before

func definition(action: String) -> Dictionary:
	var definitions := {"slash": CombatRules.SLASH, "slam": CombatRules.SLAM,
		"bolt": {"damage": 21.0, "range": 13.0, "angle": 22.0, "windup": 0.22, "duration": 0.52, "cooldown": 0.75},
		"nova": {"damage": 34.0, "range": 5.2, "angle": 360.0, "windup": 0.35, "duration": 0.75, "cooldown": 4.5},
		"familiar": {"damage": 0.0, "range": 11.0, "angle": 360.0, "windup": 0.30, "duration": 0.65, "cooldown": 14.0}}
	var result: Dictionary = definitions.get(action, CombatRules.SLASH).duplicate()
	result["action"] = action
	result.damage *= 1.0 + 0.12 * (level(SCHOOLS.get(action, "steel")) - 1)
	return result

func to_data() -> Dictionary:
	return {"primary": primary, "secondary": secondary, "experience": experience.duplicate()}

func restore(data: Dictionary) -> void:
	equip(0, str(data.get("primary", "slash")))
	equip(1, str(data.get("secondary", "slam")))
	var saved: Variant = data.get("experience", {})
	if saved is Dictionary:
		for school in experience:
			var xp: Variant = saved.get(school, 0)
			experience[school] = clampi(int(xp), 0, 18) if xp is int or xp is float else 0
