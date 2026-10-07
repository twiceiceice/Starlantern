class_name CharacterView
extends Node3D
## Presentation boundary: actors supply motion/action time; the shared GLB owns poses.
## Original mesh and clips are authored in art/source/characters/build_adventurer.py.

const MODEL = preload("res://assets/models/characters/expedition_adult.glb")
const AXE = preload("res://assets/models/props/expedition_axe.glb")
const HAMMER = preload("res://assets/models/props/carpenter_hammer.glb")
const LOOPS := ["Idle", "Walk", "Run", "CarryIdle", "CarryWalk", "WorkHammer"]

var body: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var tool: Node3D
var cargo: Node3D
var focus: Node3D
var coat := Color("426475")
var occupation := "hero"
var clip := ""
var magic_focus := false
var action_clock := 0.0
var previous_action := ""
var hands: CharacterHands
var feet: CharacterFeet

func _ready() -> void:
	body = MODEL.instantiate()
	add_child(body)
	skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	hands = CharacterHands.new(skeleton)
	feet = CharacterFeet.new(skeleton)
	animator = body.find_children("*", "AnimationPlayer", true, false)[0]
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in LOOPS:
		animator.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	for node in body.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with("Face"):
			node.visible = String(node.name) == "Face" + occupation.capitalize()
		if node.name == "HeroArmor":
			node.visible = occupation == "hero"
		if node.name == "WorkApron":
			node.visible = occupation == "carpenter"
		if node.name == "TravelPack":
			node.visible = occupation != "carpenter"
		for surface in node.mesh.get_surface_count():
			var original: Material = node.mesh.surface_get_material(surface)
			if original.resource_name in ["Coat", "CoatShade", "Linen", "Trousers", "Leather", "LeatherEdge"]:
				var tint: Color = original.albedo_color
				if original.resource_name == "Coat": tint = coat
				if original.resource_name == "CoatShade": tint = coat.darkened(0.28)
				var fabric := original.resource_name in ["Coat", "CoatShade", "Linen", "Trousers"]
				var surface_material := ExpeditionArt.material("canvas" if fabric else "leather", tint).duplicate()
				node.set_surface_override_material(surface, surface_material)
	var grip := _attachment("grip_r")
	tool = AXE.instantiate() if occupation == "hero" else HAMMER.instantiate()
	grip.add_child(tool)
	tool.visible = occupation in ["hero", "carpenter"]
	# Tilt the carried axe away from the boots so the head clears the ground
	# while running with bent knees. Combat supplies its own world-space path.
	tool.rotation = Vector3(-0.65 if occupation == "hero" else 0.0, PI * 0.5, PI)
	cargo = Node3D.new()
	cargo.position = Vector3(0, -0.30, 0.46)
	_attachment("chest").add_child(cargo)
	Geometry.box(cargo, Vector3.ZERO, Vector3(0.53, 0.36, 0.35), Color("765d42"))
	for x in [-0.20, 0.20]:
		Geometry.box(cargo, Vector3(x, 0, 0.181), Vector3(0.04, 0.38, 0.018), Color("b09062"))
	cargo.visible = false
	if occupation == "hero":
		focus = Node3D.new()
		grip.add_child(focus)
		Geometry.cylinder(focus, Vector3(0, 0.23, 0), 0.022, 1.2, Color("524940"))
		var gem := Geometry.sphere(focus, Vector3(0, 0.87, 0), Vector3(0.12, 0.22, 0.12), Color("9fbcc8"))
		gem.material_override = Geometry.material(Color("9fbcc8"), 0.6)
		focus.visible = false
	_play("Idle")
	animator.advance(0)

func _attachment(bone: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = bone + "_attachment"
	skeleton.add_child(attachment)
	attachment.bone_name = bone
	return attachment

func set_magic_focus(enabled: bool) -> void:
	magic_focus = enabled
	if is_instance_valid(focus):
		focus.visible = enabled and not cargo.visible
		tool.visible = not enabled and not cargo.visible

func _play(next: String, blend: float = 0.12) -> void:
	if clip == next:
		return
	clip = next
	animator.play(next, blend)

func animate(delta: float, speed: float, grounded: bool, action: String = "", progress: float = 0.0, carrying: bool = false) -> void:
	if not is_instance_valid(animator):
		return
	# Contact corrections are rebuilt each frame, never accumulated into clips.
	skeleton.reset_bone_poses()
	if action != previous_action:
		action_clock = 0
		previous_action = action
	action_clock += delta
	cargo.visible = carrying
	tool.visible = not carrying and not magic_focus and occupation in ["hero", "carpenter"]
	if is_instance_valid(focus):
		focus.visible = magic_focus and not carrying
	var next := "Idle"
	var seek_action := false
	if action == "dodge":
		next = "Dodge"
	elif action in ["slash", "slam", "bolt", "nova", "familiar"]:
		next = "Slash" if action == "slash" else ("Slam" if action == "slam" else "Cast")
		seek_action = true
	elif action == "work":
		next = "WorkHammer"
	elif not grounded:
		next = "Jump"
	elif carrying:
		next = "CarryWalk" if speed > 0.15 else "CarryIdle"
	elif speed > 0.15:
		next = "Run" if speed > 5.5 else "Walk"
	_play(next, 0.055 if seek_action else 0.12)
	if seek_action:
		# Game wind-up and visual contact remain synchronized, including haste/cancel.
		animator.advance(delta)
		animator.seek(clampf(progress, 0, 0.999) * animator.current_animation_length, true)
	elif action == "dodge":
		animator.advance(delta)
		animator.seek(minf(action_clock, animator.current_animation_length - 0.001), true)
	else:
		var rate := clampf(speed / (7.4 if next == "Run" else 4.6), 0.5, 1.5) if next in ["Walk", "Run", "CarryWalk"] else 1.0
		animator.advance(delta * rate)
		if feet.active and next in ["Walk", "Run", "CarryWalk"]:
			animator.seek(fposmod(feet.phase - 0.25, 1) * animator.current_animation_length, true)
	feet.apply(delta, speed, grounded, action)
	hands.strength = 0
	hands.grip_error = 0
	if carrying:
		hands.apply_cargo(cargo.transform)
	elif occupation == "hero" and not magic_focus and action in ["slash", "slam"]:
		hands.apply_axe(action, clampf(progress, 0, 1), tool.basis)
