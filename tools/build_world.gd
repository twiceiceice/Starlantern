extends SceneTree

func _initialize() -> void:
	# MultiMesh instance data lives in the RenderingServer; the headless dummy server drops it.
	if DisplayServer.get_name() == "headless":
		push_error("Run build_world.gd without --headless, or trees and grass are saved empty.")
		quit(1)
		return
	var factory = load("res://scripts/world/world_factory.gd").new()
	var world: Node3D = factory.build()
	_assign_owner(world, world)
	var packed := PackedScene.new()
	var error := packed.pack(world)
	if error == OK:
		error = ResourceSaver.save(packed, "res://scenes/world/expedition_valley.tscn")
	world.free()
	print("World scene saved: ", error_string(error))
	quit(0 if error == OK else 1)

func _assign_owner(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		_assign_owner(child, root_node)
