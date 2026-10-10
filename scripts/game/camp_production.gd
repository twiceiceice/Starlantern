class_name CampProduction
extends RefCounted
## Finite, saved material transfers. Only arrival at a station advances a job.
signal changed
signal completed(kind: String)

var started := false
var kits_ready := false
var timber := 2
var ingredients := 1
var cargo := 0
var shipments := 0
var meals := 0
var cooked := 0
var receipts: Array[String] = []
var jobs := {"carpenter": {}, "cook": {}}

func start() -> void:
	if started: return
	started = true
	changed.emit()

func receive(id: String) -> bool:
	if id in receipts: return false
	receipts.append(id)
	cargo += 1
	changed.emit()
	return true

func request(role: String) -> Dictionary:
	if not started: return {}
	if not jobs[role].is_empty(): return jobs[role]
	var kind := ""
	if role == "carpenter":
		if not kits_ready and timber >= 2: kind = "crates"
		elif cargo > 0: kind = "shipment"
	elif ingredients > 0 and meals < 6: kind = "meal"
	if not kind.is_empty(): jobs[role] = {"kind":kind,"phase":"fetch","progress":0.0}
	return jobs[role]

func pickup(role: String) -> bool:
	var job: Dictionary = jobs[role]
	if job.is_empty() or job.phase != "fetch": return false
	match job.kind:
		"crates":
			if timber < 2: return false
			timber -= 2
		"shipment":
			if cargo < 1: return false
			cargo -= 1
		"meal":
			if ingredients < 1: return false
			ingredients -= 1
	job.phase = "to_work"
	changed.emit()
	return true

func finish(role: String) -> String:
	var job: Dictionary = jobs[role]
	if job.is_empty() or job.phase != "deliver": return ""
	var kind: String = job.kind
	jobs[role] = {}
	match kind:
		"crates": kits_ready = true
		"shipment":
			shipments += 1
			# Guild supply crew exchanges each packed shipment for one provision bundle.
			ingredients += 1
		"meal":
			meals += 1
			cooked += 1
	completed.emit(kind)
	changed.emit()
	return kind

func eat() -> bool:
	if meals <= 0: return false
	meals -= 1
	changed.emit()
	return true

func to_data() -> Dictionary:
	return {"started":started,"kits_ready":kits_ready,"timber":timber,"ingredients":ingredients,
		"cargo":cargo,"shipments":shipments,"meals":meals,"cooked":cooked,
		"receipts":receipts.duplicate(),"jobs":jobs.duplicate(true)}

func restore(data: Dictionary) -> void:
	started = bool(data.get("started",false))
	kits_ready = bool(data.get("kits_ready",false))
	timber = clampi(int(data.get("timber",2)),0,2)
	ingredients = clampi(int(data.get("ingredients",1)),0,50)
	cargo = clampi(int(data.get("cargo",0)),0,50)
	shipments = clampi(int(data.get("shipments",0)),0,50)
	meals = clampi(int(data.get("meals",0)),0,6)
	cooked = clampi(int(data.get("cooked",0)),0,50)
	receipts.clear()
	for id in data.get("receipts",[]):
		if id is String and id not in receipts: receipts.append(id)
	jobs = {"carpenter":{},"cook":{}}
	var saved: Dictionary = data.get("jobs",{}) if data.get("jobs",{}) is Dictionary else {}
	for role in jobs:
		var job: Variant = saved.get(role,{})
		if not job is Dictionary or job.is_empty(): continue
		var kinds := ["crates","shipment"] if role == "carpenter" else ["meal"]
		if job.get("kind","") not in kinds or job.get("phase","") not in ["fetch","to_work","working","deliver"]: continue
		jobs[role] = job.duplicate(true)
		jobs[role].progress = clampf(float(job.get("progress",0)),0,6)
