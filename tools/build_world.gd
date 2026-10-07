extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# MultiMesh instance data lives in the RenderingServer; the headless dummy server drops it.
	if DisplayServer.get_name() == "headless":
		push_error("Run build_world.gd without --headless, or trees and grass are saved empty.")
		quit(1)
		return
	for region in [RegionLayout.MEADOW, RegionLayout.FOREST]:
		var factory = load("res://scripts/world/region_world_factory.gd").new()
		var world: Node3D = factory.build_region(region)
		_assign_owner(world, world)
		var packed := PackedScene.new()
		var error := packed.pack(world)
		if error == OK: error = ResourceSaver.save(packed, RegionLayout.SCENES[region])
		world.free()
		await process_frame
		await process_frame
		print("Region saved: ", region, " ", error_string(error))
		if error != OK:
			quit(1)
			return
	quit(0)

func _assign_owner(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		_assign_owner(child, root_node)
