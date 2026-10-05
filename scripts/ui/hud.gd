class_name ExpeditionHud
extends CanvasLayer

signal resume_requested
signal restart_requested
signal quit_requested

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
var menu: Control
var menu_title: Label
var menu_copy: Label
var resume_button: Button
var restart_button: Button
var notice_time := 0.0

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
	_label(heading, "별등 원정기", Vector2(20, 31), Vector2(265, 37), 27, PAPER)
	var quest := _panel(root, Vector2(-445, 25), Vector2(417, 167), Vector2(1, 0))
	title_label = _label(quest, "", Vector2(20, 14), Vector2(372, 30), 20, GOLD)
	objective_label = _label(quest, "", Vector2(20, 51), Vector2(372, 55), 18, PAPER)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label = _label(quest, "", Vector2(20, 115), Vector2(372, 40), 14, Color("b1c6bb"))
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
	_label(skills, "가로베기", Vector2(20, 36), Vector2(150, 34), 21, PAPER)
	_label(skills, "2 / Q", Vector2(190, 12), Vector2(150, 22), 13, GOLD)
	slam_label = _label(skills, "내려찍기", Vector2(190, 36), Vector2(150, 34), 21, PAPER)
	_label(skills, "Ctrl", Vector2(364, 12), Vector2(130, 22), 13, GOLD)
	dodge_label = _label(skills, "회피  2 / 2", Vector2(364, 36), Vector2(142, 34), 21, PAPER)
	_label(skills, "Space 점프\nE 상호작용", Vector2(532, 16), Vector2(110, 53), 14, Color("bed0c6"))
	var help_panel := _panel(root, Vector2(-271, -112), Vector2(243, 76), Vector2(1, 1))
	status_label = _label(help_panel, "마우스 시점 · 휠 확대\nEsc 메뉴 · F11 전체 화면", Vector2(12, 9), Vector2(219, 58), 13, PAPER)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label = _label(root, "", Vector2(-400, -175), Vector2(800, 40), 22, PAPER, Vector2(0.5, 1))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_shadow_color", Color("163332"))
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	notice_label = _label(root, "", Vector2(-430, 116), Vector2(860, 58), 20, PAPER, Vector2(0.5, 0))
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_menu()

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var veil := ColorRect.new()
	veil.color = Color(0.06, 0.12, 0.13, 0.38)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)
	var card := _panel(menu, Vector2(-280, -215), Vector2(560, 430), Vector2(0.5, 0.5))
	_label(card, "THE FIRST EXPEDITION", Vector2(34, 24), Vector2(490, 28), 13, GOLD)
	menu_title = _label(card, "등불을 따라, 첫 원정", Vector2(34, 59), Vector2(490, 52), 31, PAPER)
	menu_copy = _label(card, "원정대 300명과 함께 등불을 밝히며 북쪽으로 나아가세요.\n구간마다 게시판에서 맡을 일을 하나 고르면, 나머지는 원정대가 맡습니다.\n\n붉은 원 밖으로 회피하세요. 공격 후에도 회피할 수 있어요.", Vector2(34, 121), Vector2(490, 117), 17, Color("cedbd0"))
	menu_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume_button = _button(card, "원정 시작", Vector2(34, 253), Vector2(490, 52), true)
	resume_button.pressed.connect(func(): resume_requested.emit())
	restart_button = _button(card, "이번 원정 다시 시작", Vector2(34, 319), Vector2(307, 43))
	restart_button.pressed.connect(func(): restart_requested.emit())
	var quit_button := _button(card, "게임 종료", Vector2(351, 319), Vector2(173, 43))
	quit_button.pressed.connect(func(): quit_requested.emit())
	_label(card, "Godot 기반 첫 시제품 · 캐릭터와 동작은 임시 모델", Vector2(34, 385), Vector2(490, 23), 12, Color("9cb7ad"))

func show_menu(first: bool) -> void:
	menu.visible = true
	menu_title.text = "등불을 따라, 첫 원정" if first else "등불 아래서 잠시 쉬기"
	resume_button.text = "원정 시작" if first else "계속하기"
	restart_button.disabled = first
	resume_button.grab_focus()

func update_state(player: ExpeditionPlayer, title: String, objective: String, status: String, prompt: String, delta: float) -> void:
	health_label.text = "생명                       %d / 100" % player.health
	health_bar.value = player.health
	title_label.text = title
	objective_label.text = objective
	progress_label.text = status
	dodge_label.text = "회피  %d / 2" % player.dodge_charges
	slam_label.text = "내려찍기" if player.slam_cooldown <= 0 else "내려찍기 %.1f" % player.slam_cooldown
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
