class_name LanternNetwork
extends RefCounted
## Where workers may stand and work. Fixed camp/road lamps never dim; the single
## forward lantern the player carries burns oil once planted and shrinks as it runs low.

const FORWARD_RADIUS := 8.0
const MIN_FORWARD_RADIUS := 3.0

var anchors: Array[Dictionary] = []
var planted := false
var forward_position := Vector3.ZERO
var max_fuel := 90.0
var fuel := max_fuel

func add_anchor(at: Vector3, radius: float) -> void:
	anchors.append({"position": at, "radius": radius})

func forward_radius() -> float:
	return lerpf(MIN_FORWARD_RADIUS, FORWARD_RADIUS, fuel / max_fuel)

func is_lit(point: Vector3) -> bool:
	if _within(point, forward_position, forward_radius()) and planted:
		return true
	return lit_by_anchor(point)

func lit_by_anchor(point: Vector3) -> bool:
	for anchor in anchors:
		if _within(point, anchor.position, anchor.radius):
			return true
	return false

func can_plant(at: Vector3) -> bool:
	return not lit_by_anchor(at)

## Planting again moves the one forward lantern; its remaining oil goes with it.
func plant(at: Vector3) -> bool:
	if not can_plant(at):
		return false
	planted = true
	forward_position = Vector3(at.x, 0, at.z)
	return true

func burn(seconds: float) -> bool:
	if not planted or fuel <= 0:
		return false
	fuel = maxf(0, fuel - seconds)
	return true

func refuel() -> void:
	fuel = max_fuel

static func _within(point: Vector3, center: Vector3, radius: float) -> bool:
	return Vector2(point.x - center.x, point.z - center.z).length() <= radius
