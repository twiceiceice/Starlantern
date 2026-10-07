class_name ExpeditionSave
extends RefCounted
const PATH := "user://expedition.json"
const VERSION := 2

static func write_checkpoint(career: CareerProgress, training: CombatTraining, resources: Dictionary, path: String = PATH, caravan: Dictionary = {}, journey: Dictionary = {}) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version":VERSION,"career":career.to_data(),"training":training.to_data(),"resources":resources,"caravan":caravan,"journey":journey}))
	file.close()
	return DirAccess.rename_absolute(temporary,path)

static func read_checkpoint(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 65536: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var data: Variant = parser.data
	if not data is Dictionary: return {}
	var version: Variant = data.get("version")
	if not (version is int or version is float) or int(version) not in [1, VERSION]: return {}
	if not data.get("career") is Dictionary or not data.get("training") is Dictionary or not data.get("resources") is Dictionary: return {}
	if data.has("journey") and not data.journey is Dictionary: return {}
	return data

static func clear_checkpoint(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		# Keep the previous expedition recoverable when the player explicitly starts afresh.
		DirAccess.copy_absolute(path,path + ".previous")
		DirAccess.remove_absolute(path)
