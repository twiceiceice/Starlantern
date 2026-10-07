class_name Geometry
extends RefCounted

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result

static func mesh(parent: Node3D, resource: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = resource
	item.position = position
	item.material_override = material(color)
	parent.add_child(item)
	return item

static func box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var resource := BoxMesh.new()
	resource.size = size
	return mesh(parent, resource, position, color)

static func sphere(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var resource := SphereMesh.new()
	resource.radius = 0.5
	resource.height = 1
	resource.radial_segments = 16
	resource.rings = 8
	var item := mesh(parent, resource, position, color)
	item.scale = size
	return item

static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, color: Color, top: float = -1) -> MeshInstance3D:
	var resource := CylinderMesh.new()
	resource.bottom_radius = radius
	resource.top_radius = radius if top < 0 else top
	resource.height = height
	resource.radial_segments = 16
	return mesh(parent, resource, position, color)

static func capsule(parent: Node3D, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var resource := CapsuleMesh.new()
	resource.radius = radius
	resource.height = height
	resource.radial_segments = 16
	resource.rings = 4
	return mesh(parent, resource, position, color)

static func solid_box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	parent.add_child(body)
	box(body, Vector3.ZERO, size, color)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body

static func ring(parent: Node3D, radius: float, color: Color, thickness: float = 0.07) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 48
	shape.ring_segments = 8
	return mesh(parent, shape, Vector3(0, 0.04, 0), color)

static func label(parent: Node3D, text: String, height: float, tint: Color = Color("f4e9cf")) -> Label3D:
	var result := Label3D.new()
	result.font = load("res://assets/fonts/ui.tres")
	result.text = text
	result.font_size = 32
	result.pixel_size = 0.006
	result.position.y = height
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.modulate = tint
	result.outline_size = 6
	parent.add_child(result)
	return result

## One draw call for many copies of a mesh; per-instance colors tint a white material.
static func instances(parent: Node3D, resource: Mesh, transforms: Array[Transform3D], colors: Array[Color] = []) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = resource
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
	var item := MultiMeshInstance3D.new()
	item.multimesh = multimesh
	var tint := material(Color.WHITE)
	tint.vertex_color_use_as_albedo = true
	tint.vertex_color_is_srgb = true
	item.material_override = tint
	parent.add_child(item)
	return item

static func unit_sphere() -> SphereMesh:
	var resource := SphereMesh.new()
	resource.radius = 0.5
	resource.height = 1
	resource.radial_segments = 16
	resource.rings = 8
	return resource
