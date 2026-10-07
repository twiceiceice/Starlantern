class_name ExpeditionHud
extends CanvasLayer

signal resume_requested
signal restart_requested
signal quit_requested
signal journal_requested
signal journal_closed
signal growth_requested

const INK := Color("203c3f")
const PAPER := Color("f3e9d0")
const GOLD := Color("dfbd7d")
var root: Control
var title_label: Label
var objective_label: Label
var progress_label: Label
var health_label: Label
var health_bar: ProgressBar
var status_label: Label
var prompt_label: Label
var notice_label: Label
var dodge_label: Label
var slam_label: Label
var primary_label: Label
var tactic_label: Label
var growth: GrowthPanel
var restart_armed := false
var menu: Control
var menu_title: Label
var menu_copy: Label
var resume_button: Button
var restart_button: Button
var journal: Control
var journal_title: Label
var chapter_labels: Array[Label] = []
var chapter_details: Array[Label] = []
var journal_objective: Label
var journal_assignment: Label
var journal_record: Label
var journal_reward: Label
var journal_close_button: Button
var notice_time := 0.0
var region_label: Label
var travel_veil: ColorRect
var travel_label: Label

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/ui.tres")
	theme.default_font_size = 17
	root.theme = theme
	add_child(root)
	var heading := _panel(root, Vector2(28, 25), Vector2(310, 86))
	_label(heading, "S T A R L A N T E R N", Vector2(20, 10), Vector2(270, 20), 12, GOLD)
	_label(heading, ExpeditionCampaign.TITLE, Vector2(20, 31), Vector2(265, 37), 27, PAPER)
	var region_chip := _panel(root, Vector2(28, 119), Vector2(310, 36))
	region_label = _label(region_chip, "", Vector2(15, 5), Vector2(280, 27), 15, GOLD)
	var quest := _panel(root, Vector2(-445, 25), Vector2(417, 214), Vector2(1, 0))
	title_label = _label(quest, "", Vector2(20, 14), Vector2(372, 30), 20, GOLD)
	objective_label = _label(quest, "", Vector2(20, 51), Vector2(372, 105), 17, PAPER)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label = _label(quest, "", Vector2(20, 167), Vector2(372, 34), 14, Color("b1c6bb"))
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vital := _panel(root, Vector2(28, -119), Vector2(266, 90), Vector2(0, 1))
	health_label = _label(vital, "", Vector2(17, 10), Vector2(228, 27), 16, PAPER)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(17, 44)
	health_bar.size = Vector2(230, 9)
	health_bar.show_percentage = false
	health_bar.add_theme_font_size_override("font_size", 1)
	health_bar.add_theme_stylebox_override("background", _style(Color("142e31"), 4))
	health_bar.add_theme_stylebox_override("fill", _style(Color("b9cf8e"), 4))
	vital.add_child(health_bar)
	health_bar.size = Vector2(230, 9)
	_label(vital, "WASD 이동  ·  Shift 달리기", Vector2(17, 61), Vector2(235, 20), 12, Color("b9c9ba"))
	var skills := _panel(root, Vector2(-330, -119), Vector2(660, 90), Vector2(0.5, 1))
	_label(skills, "좌클릭 / 1", Vector2(20, 12), Vector2(150, 22), 13, GOLD)
	primary_label = _label(skills, "가로베기", Vector2(20, 36), Vector2(150, 34), 21, PAPER)
	_label(skills, "2 / Q", Vector2(190, 12), Vector2(150, 22), 13, GOLD)
	slam_label = _label(skills, "내려찍기", Vector2(190, 36), Vector2(150, 34), 21, PAPER)
	_label(skills, "Ctrl", Vector2(364, 12), Vector2(130, 22), 13, GOLD)
	dodge_label = _label(skills, "회피  2 / 2", Vector2(364, 36), Vector2(142, 34), 21, PAPER)
	_label(skills, "Space 점프\nE 상호작용", Vector2(532, 16), Vector2(110, 53), 14, Color("bed0c6"))
	var tactic_panel := _panel(root,Vector2(-330,-153),Vector2(660,28),Vector2(0.5,1))
	tactic_label = _label(tactic_panel,"K · 성장과 진로",Vector2(20,2),Vector2(620,24),14,GOLD)
	tactic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help_panel := _panel(root, Vector2(-271, -126), Vector2(243, 98), Vector2(1, 1))
	status_label = _label(help_panel, "마우스 시점 · 휠 확대\nJ 대장정 · K 성장과 진로\nR 진로 기술 · Esc 메뉴\nF11 전체 화면", Vector2(12, 7), Vector2(219, 84), 13, PAPER)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label = _label(root, "", Vector2(-400, -175), Vector2(800, 40), 22, PAPER, Vector2(0.5, 1))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_shadow_color", Color("163332"))
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	notice_label = _label(root, "", Vector2(-430, 251), Vector2(860, 58), 20, PAPER, Vector2(0.5, 0))
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_color_override("font_shadow_color", Color("163332"))
	notice_label.add_theme_constant_override("shadow_offset_y", 2)
	_build_menu()
	_build_journal()
	growth = GrowthPanel.new()
	growth.painter = self
	root.add_child(growth)
	travel_veil = ColorRect.new()
	travel_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_veil.color = Color("172d2b")
	travel_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	travel_veil.visible = false
	root.add_child(travel_veil)
	travel_label = _label(travel_veil, "", Vector2(-400, -45), Vector2(800, 90), 28, PAPER, Vector2(0.5, 0.5))
	travel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func fade_travel(text: String, out: bool) -> void:
	travel_label.text = text
	travel_veil.visible = true
	travel_veil.modulate.a = 0.0 if out else 1.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(travel_veil, "modulate:a", 1.0 if out else 0.0, 0.28)
	await tween.finished
	if not out: travel_veil.visible = false

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var veil := ColorRect.new()
	veil.color = Color(0.06, 0.12, 0.13, 0.38)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)
	var card := _panel(menu, Vector2(-310, -280), Vector2(620, 560), Vector2(0.5, 0.5))
	card.add_theme_stylebox_override("panel", _style(Color("183537")))
	_label(card, "솔바람 길드  /  제1차 별잠회랑 원정", Vector2(34, 25), Vector2(552, 28), 13, GOLD)
	menu_title = _label(card, ExpeditionCampaign.TITLE, Vector2(34, 59), Vector2(552, 52), 31, PAPER)
	menu_copy = _label(card, ExpeditionCampaign.PREMISE + "\n\n" + ExpeditionCampaign.COMMISSION, Vector2(34, 126), Vector2(552, 215), 17, Color("cedbd0"))
	menu_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume_button = _button(card, "원정에 합류", Vector2(34, 355), Vector2(552, 52), true)
	resume_button.pressed.connect(func(): resume_requested.emit())
	var journal_button := _button(card, "대장정 수첩 · J", Vector2(34, 421), Vector2(270, 43))
	journal_button.pressed.connect(func(): journal_requested.emit())
	restart_button = _button(card, "이번 원정 다시 시작", Vector2(316, 421), Vector2(270, 43))
	restart_button.pressed.connect(func():
		if restart_armed: restart_requested.emit()
		else:
			restart_armed = true
			restart_button.text = "진행 초기화 · 다시 눌러 확인"
	)
	var quit_button := _button(card, "게임 종료", Vector2(416, 480), Vector2(170, 43))
	quit_button.pressed.connect(func(): quit_requested.emit())
	var growth_button := _button(card,"성장과 진로 · K",Vector2(34,480),Vector2(365,43))
	growth_button.pressed.connect(func(): growth_requested.emit())

func _build_journal() -> void:
	journal = Control.new()
	journal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal.visible = false
	root.add_child(journal)
	var veil := ColorRect.new()
	veil.color = Color(0.035, 0.07, 0.09, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal.add_child(veil)
	var card := _panel(journal, Vector2(-484, -360), Vector2(968, 720), Vector2(0.5, 0.5))
	card.add_theme_stylebox_override("panel", _style(Color("183537")))
	_label(card, "대장정 수첩  /  제1차 별잠회랑 원정", Vector2(36, 24), Vector2(700, 25), 13, GOLD)
	journal_title = _label(card, ExpeditionCampaign.TITLE, Vector2(36, 58), Vector2(896, 48), 32, PAPER)
	_label(card, "원정의 발자취", Vector2(36, 118), Vector2(396, 26), 16, GOLD)
	for i in range(ExpeditionCampaign.CHAPTERS.size()):
		var at := Vector2(36, 155 + i * 62)
		chapter_labels.append(_label(card, "", at, Vector2(416, 27), 18, PAPER))
		var detail := _label(card, str(ExpeditionCampaign.CHAPTERS[i].detail), at + Vector2(29, 29), Vector2(388, 30), 13, Color("9cb7ad"))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chapter_details.append(detail)
	_label(card, "우리가 북쪽으로 가는 이유", Vector2(486, 118), Vector2(444, 26), 16, GOLD)
	var premise := _label(card, ExpeditionCampaign.PREMISE + "\n\n300명의 원정대가 던전 입구를 확보하고, 다음 탐사를 위한 거점을 세우려 합니다.", Vector2(486, 155), Vector2(444, 148), 16, Color("cedbd0"))
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(card, "지금 할 일", Vector2(486, 318), Vector2(444, 26), 16, GOLD)
	journal_objective = _label(card, "", Vector2(486, 353), Vector2(444, 100), 17, PAPER)
	journal_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_assignment = _label(card, "", Vector2(486, 463), Vector2(444, 38), 13, Color("adc4b7"))
	journal_assignment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(card, "첫 탐사의 기록", Vector2(486, 514), Vector2(444, 26), 16, GOLD)
	journal_record = _label(card, "", Vector2(486, 549), Vector2(444, 80), 14, Color("cedbd0"))
	journal_record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_reward = _label(card, "", Vector2(36, 642), Vector2(600, 42), 15, GOLD)
	journal_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_close_button = _button(card, "수첩 닫기 · J / Esc", Vector2(672, 643), Vector2(260, 43), true)
	journal_close_button.pressed.connect(func(): journal_closed.emit())

func show_journal(data: Dictionary) -> void:
	journal.visible = true
	journal_title.text = "대장정 완료 · " + ExpeditionCampaign.TITLE if data.complete else ExpeditionCampaign.TITLE
	for i in range(chapter_labels.size()):
		var done := i < int(data.chapter)
		var current := i == int(data.chapter)
		var marker := "완료" if done else ("진행" if current else "%02d" % (i + 1))
		chapter_labels[i].text = "%s  %s" % [marker, ExpeditionCampaign.CHAPTERS[i].title]
		chapter_labels[i].modulate = Color.WHITE if done or current else Color(0.7, 0.8, 0.78)
		chapter_labels[i].add_theme_color_override("font_color", GOLD if current else PAPER)
		chapter_details[i].modulate.a = 1.0 if current or done else 0.7
	journal_objective.text = "첫 원정 완료. 전진 기지에서 K를 열어 진로 의뢰를 선택하세요." if data.complete else str(data.objective)
	journal_assignment.text = "길드가 당신을 ‘선발 조사단원’으로 기록했습니다." if data.complete else str(data.assignment)
	if data.complete:
		journal_record.text = ExpeditionCampaign.ENDING
	elif data.record:
		journal_record.text = ExpeditionCampaign.DISCOVERY + "\n표본 귀환 %d / 2" % int(data.deliveries)
	else:
		journal_record.text = "미확인 · 입구를 확보한 뒤, 등불로 안쪽 기록판을 밝히고 E로 조사하세요.\n인부들의 표본 귀환 %d / 2" % int(data.deliveries)
	journal_reward.text = ("받은 보상\n" if data.complete else "길드가 약속한 보상\n") + ExpeditionCampaign.REWARD
	journal_close_button.grab_focus()

func show_menu(first: bool) -> void:
	menu.visible = true
	menu_title.text = ExpeditionCampaign.TITLE if first else "별잠회랑을 향하여"
	resume_button.text = "원정에 합류" if first else "계속하기"
	restart_button.disabled = first
	restart_armed = false
	restart_button.text = "새 원정 · 진행 초기화"
	resume_button.grab_focus()

func update_state(player: ExpeditionPlayer, title: String, objective: String, status: String, prompt: String, delta: float) -> void:
	health_label.text = "생명                       %d / 100" % player.health
	health_bar.value = player.health
	title_label.text = title
	objective_label.text = objective
	progress_label.text = status
	dodge_label.text = "회피  %d / 2" % player.dodge_charges
	primary_label.text = CombatTraining.NAMES[player.training.primary]
	var skill: String = CombatTraining.NAMES[player.training.secondary]
	slam_label.text = skill if player.slam_cooldown <= 0 else "%s\n%.1f초" % [skill,player.slam_cooldown]
	slam_label.position.y = 32
	slam_label.add_theme_font_size_override("font_size",21 if player.slam_cooldown <= 0 else 16)
	prompt_label.text = prompt
	if notice_time > 0:
		notice_time -= delta
		notice_label.modulate.a = minf(1, notice_time)
	else:
		notice_label.text = ""

func notify(text: String) -> void:
	notice_label.text = text
	notice_label.modulate.a = 1
	notice_time = 4.5

func _style(color: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = Color(0.85, 0.87, 0.7, 0.18)
	style.set_border_width_all(1)
	return style

func _panel(parent: Node, at: Vector2, dimensions: Vector2, anchor: Vector2 = Vector2.ZERO) -> Panel:
	var panel := Panel.new()
	panel.anchor_left = anchor.x
	panel.anchor_right = anchor.x
	panel.anchor_top = anchor.y
	panel.anchor_bottom = anchor.y
	panel.offset_left = at.x
	panel.offset_top = at.y
	panel.offset_right = at.x + dimensions.x
	panel.offset_bottom = at.y + dimensions.y
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.18, 0.19, 0.93)))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, anchor: Vector2 = Vector2.ZERO) -> Label:
	var label := Label.new()
	label.text = text
	label.anchor_left = anchor.x
	label.anchor_right = anchor.x
	label.anchor_top = anchor.y
	label.anchor_bottom = anchor.y
	label.offset_left = at.x
	label.offset_top = at.y
	label.offset_right = at.x + dimensions.x
	label.offset_bottom = at.y + dimensions.y
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, at: Vector2, dimensions: Vector2, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 19 if primary else 16)
	var background := GOLD if primary else Color("315151")
	button.add_theme_stylebox_override("normal", _style(background, 9))
	button.add_theme_stylebox_override("hover", _style(background.lightened(0.10), 9))
	button.add_theme_stylebox_override("pressed", _style(background.darkened(0.1), 9))
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	button.add_theme_color_override("font_pressed_color", INK if primary else PAPER)
	button.add_theme_color_override("font_focus_color", INK if primary else PAPER)
	parent.add_child(button)
	return button
