class_name LanternGlow
extends Node3D
## Shows the LanternNetwork on the ground: faint rings for fixed lamps (including ones
## planted during the march), and the carried forward lantern whose ring follows its oil.

const RING := Color(1.0, 0.86, 0.55, 0.55)
var light: LanternNetwork
var drawn := 0
var forward: Node3D
var forward_ring: MeshInstance3D
var forward_glow: OmniLight3D

static func post(parent: Node3D, at: Vector3, height := 2.1) -> OmniLight3D:
	Geometry.cylinder(parent, at + Vector3(0, height * 0.5, 0), 0.06, height, Color("6b6852"))
	Geometry.box(parent, at + Vector3(0, height + 0.02, 0), Vector3(0.42, 0.1, 0.42), Color("475d55"))
	var glass := Geometry.sphere(parent, at + Vector3(0, height - 0.24, 0), Vector3(0.24, 0.38, 0.24), Color("ffe6a1"))
	glass.material_override = Geometry.material(Color("ffe3a0"), 0.7)
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0, height - 0.3, 0)
	glow.light_color = Color("ffca83")
	glow.light_energy = 0.8
	glow.omni_range = 4.0
	parent.add_child(glow)
	return glow

func _ready() -> void:
	forward = Node3D.new()
	forward.visible = false
	add_child(forward)
	forward_glow = post(forward, Vector3.ZERO, 1.5)
	# Built at unit radius and scaled, so it can track the shrinking light.
	forward_ring = Geometry.ring(forward, 1.0, Color(1.0, 0.8, 0.45, 0.8), 0.012)
	_draw_new_anchors()

func _draw_new_anchors() -> void:
	while drawn < light.anchors.size():
		var anchor: Dictionary = light.anchors[drawn]
		var marker := Node3D.new()
		add_child(marker)
		marker.position = anchor.position
		Geometry.ring(marker, anchor.radius, RING, 0.05)
		drawn += 1

func _process(_delta: float) -> void:
	_draw_new_anchors()
	forward.visible = light.planted
	if not light.planted:
		return
	var radius := light.forward_radius()
	forward.position = light.forward_position
	forward_ring.scale = Vector3(radius, 1, radius)
	forward_glow.omni_range = radius
	forward_glow.light_energy = 0.5 + light.fuel / light.max_fuel
