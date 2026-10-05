class_name CombatEffects
extends Node3D

func swing(origin: Vector3, facing: Vector3, heavy: bool) -> void:
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.global_position = origin
	pivot.rotation.y = atan2(facing.x, facing.z)
	var tint := Color("efd897") if not heavy else Color("afdfd6")
	if heavy:
		var circle := Geometry.ring(pivot, 1.0, tint, 0.07)
		var tween := create_tween()
		tween.tween_property(circle, "scale", Vector3(3.4, 1, 3.4), 0.3)
		tween.tween_callback(pivot.queue_free)
	else:
		for i in range(12):
			var angle := deg_to_rad(-60 + i * 10)
			Geometry.sphere(pivot, Vector3(sin(angle) * 2, 0.9, cos(angle) * 2), Vector3(0.13, 0.075, 0.27), tint)
		var tween := create_tween()
		tween.tween_property(pivot, "scale", Vector3(1.2, 0.1, 1.2), 0.18)
		tween.tween_callback(pivot.queue_free)

func damage_number(position: Vector3, amount: float) -> void:
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.global_position = position + Vector3(0, 1.6, 0)
	Geometry.label(pivot, str(int(amount)), 0.7, Color("ffe4a9"))
	var tween := create_tween()
	tween.tween_property(pivot, "position:y", pivot.position.y + 0.8, 0.45)
	tween.tween_callback(pivot.queue_free)
