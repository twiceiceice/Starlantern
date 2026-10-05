class_name GrowthPanel
extends Control
signal closed
signal contract_requested(path: String)
signal equipment_requested(slot: int, action: String)
var painter
var selected := ""
var snapshot: Dictionary = {}
var path_buttons: Array[Button] = []
var mission_labels: Array[Label] = []
var mastery_labels: Array[Label] = []
var primary_picker: OptionButton
var secondary_picker: OptionButton
var status: Label
var path_title: Label
var description: Label
var story: Label
var tactic: Label
var accept_button: Button
var hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var veil := ColorRect.new()
	veil.color = Color(0.03,0.07,0.08,0.75)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var card: Panel = painter._panel(self,Vector2(-550,-385),Vector2(1100,770),Vector2(0.5,0.5))
	card.add_theme_stylebox_override("panel",painter._style(Color("183537")))
	painter._label(card,"성장과 진로",Vector2(36,24),Vector2(950,46),31,painter.PAPER)
	status = painter._label(card,"",Vector2(36,83),Vector2(1028,48),16,painter.GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(4):
		var id: String = CareerProgress.PATHS[i]
		var button: Button = painter._button(card,"",Vector2(36,145+i*88),Vector2(508,75))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): selected = id; refresh())
		path_buttons.append(button)
	path_title = painter._label(card,"",Vector2(584,143),Vector2(480,32),24,painter.PAPER)
	description = painter._label(card,"",Vector2(584,188),Vector2(480,72),17,painter.PAPER)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	painter._label(card,"진로 대장정 · 세 의뢰",Vector2(584,274),Vector2(480,26),16,painter.GOLD)
	for i in range(3):
		mission_labels.append(painter._label(card,"",Vector2(584,312+i*35),Vector2(480,30),17,painter.PAPER))
	story = painter._label(card,"",Vector2(584,431),Vector2(480,106),16,Color("bed0c6"))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accept_button = painter._button(card,"",Vector2(584,552),Vector2(480,43),true)
	accept_button.pressed.connect(func(): contract_requested.emit(selected))
	tactic = painter._label(card,"",Vector2(584,614),Vector2(480,78),15,painter.GOLD)
	tactic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	painter._label(card,"전투 기술 · 진로와 자유롭게 조합",Vector2(36,513),Vector2(508,29),17,painter.GOLD)
	painter._label(card,"좌클릭 / 1",Vector2(36,556),Vector2(120,28),15,painter.PAPER)
	painter._label(card,"2 / Q",Vector2(36,600),Vector2(120,28),15,painter.PAPER)
	primary_picker = _picker(card,Vector2(160,551),CombatTraining.PRIMARY)
	secondary_picker = _picker(card,Vector2(160,595),CombatTraining.SECONDARY)
	primary_picker.item_selected.connect(func(i): equipment_requested.emit(0,CombatTraining.PRIMARY[i]))
	secondary_picker.item_selected.connect(func(i): equipment_requested.emit(1,CombatTraining.SECONDARY[i]))
	for i in range(3): mastery_labels.append(painter._label(card,"",Vector2(36+i*170,653),Vector2(165,44),14,Color("a9d4c6")))
	hint = painter._label(card,"적에게 유효한 공격으로 숙련 · 6 / 18회에 성장\n무기·마법 피해 증가 / 소환 지속시간과 피해 증가",Vector2(36,709),Vector2(750,47),13,Color("9cb7ad"))
	var close_button: Button = painter._button(card,"닫기 · K / Esc",Vector2(820,711),Vector2(244,39))
	close_button.pressed.connect(func(): closed.emit())

func _picker(parent: Control, at: Vector2, actions: Array) -> OptionButton:
	var picker := OptionButton.new()
	picker.position = at
	picker.size = Vector2(384,36)
	picker.add_theme_font_size_override("font_size",16)
	for action in actions: picker.add_item(CombatTraining.NAMES[action])
	parent.add_child(picker)
	return picker

func show_state(data: Dictionary) -> void:
	snapshot = data
	if selected.is_empty(): selected = str(data.career.path) if not data.career.path.is_empty() else "hero"
	visible = true
	refresh()

func refresh() -> void:
	if snapshot.is_empty(): return
	var career: CareerProgress = snapshot.career
	var training: CombatTraining = snapshot.training
	status.text = "첫 원정을 완료하면 전진 기지에서 진로 의뢰를 받을 수 있습니다." if not snapshot.unlocked else "현재 · %s  |  의뢰는 한 갈래만 완주해도 최종 진로에 도달합니다." % career.title()
	if career.active: status.text += "\n진행 중 · " + str(career.mission().title)
	for i in range(4):
		var id: String = CareerProgress.PATHS[i]
		path_buttons[i].text = "  %s%s   ·   %d / 3 의뢰\n  %s" % ["● " if selected == id else "",CareerProgress.TITLES[id][2],int(career.completed[id])," → ".join(CareerProgress.TITLES[id])]
	path_title.text = str(CareerProgress.TITLES[selected][2]) + "의 길"
	description.text = CareerProgress.DESCRIPTIONS[selected]
	var completed := int(career.completed[selected])
	var quests: Array = CareerContracts.QUESTS[selected]
	for i in range(3): mission_labels[i].text = "%s  %s" % ["완료" if i < completed else "%02d" % (i+1),quests[i].title]
	story.text = str(quests[mini(completed,2)].story) if completed < 3 else "세 의뢰를 완수했습니다. 최종 칭호와 강화된 대표 기술로 다른 의뢰에도 나설 수 있습니다."
	accept_button.disabled = not snapshot.unlocked or not snapshot.at_camp or career.active or completed >= 3
	accept_button.text = "최종 진로 달성" if completed >= 3 else ("진행 중인 의뢰를 먼저 보고하세요" if career.active else ("기지에서 의뢰 받기" if not snapshot.at_camp else "의뢰 수락 · " + str(quests[completed].title)))
	if not snapshot.unlocked: accept_button.text = "첫 공통 대장정 완료 후 개방"
	tactic.text = "R · %s\n%s\n첫 보고와 최종 보고에서 지속시간·위력이 성장합니다." % [CareerProgress.TACTICS[selected],CareerProgress.TACTIC_DETAILS[selected]]
	primary_picker.select(CombatTraining.PRIMARY.find(training.primary))
	secondary_picker.select(CombatTraining.SECONDARY.find(training.secondary))
	for i in range(3):
		var school: String = ["steel","arcana","bond"][i]
		mastery_labels[i].text = "%s 숙련 %d\n%d / 18" % [CombatTraining.SCHOOL_NAMES[school],training.level(school),int(training.experience[school])]
