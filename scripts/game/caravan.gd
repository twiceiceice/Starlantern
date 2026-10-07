class_name Caravan
extends RefCounted
## The expedition column as numbers: headcount, animals, supplies and how far along
## the route its front has marched. Individuals are not simulated; views draw the crowd.

const SPEED := 2.2
## Rations eaten per person per second; a mule eats twice as much, an ox three times.
const FOOD_RATE := 1.0 / 600.0
const DESERTION_INTERVAL := 3.0

var people := 300
var mules := 40
## Draft oxen, one per wagon.
var oxen := 30
var wagons := 30
var food := 2400.0
var lost := 0
var distance := 0.0
var route := PackedVector3Array()
var hunger := 0.0
var cumulative := PackedFloat32Array()

func _init(points: PackedVector3Array = PackedVector3Array()) -> void:
	route = points
	cumulative.append(0.0)
	for i in range(1, route.size()):
		cumulative.append(cumulative[-1] + route[i - 1].distance_to(route[i]))

func length() -> float:
	return cumulative[-1] if not cumulative.is_empty() else 0.0

func point_at(at: float) -> Vector3:
	if route.is_empty(): return Vector3.ZERO
	if route.size() == 1: return route[0]
	var low := 1
	var high := route.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if cumulative[middle] < at: low = middle + 1
		else: high = middle
	var length_of_segment := cumulative[low] - cumulative[low - 1]
	return route[low - 1].lerp(route[low], clampf((at - cumulative[low - 1]) / maxf(0.001, length_of_segment), 0, 1))

func direction_at(at: float) -> Vector3:
	var direction := point_at(minf(length(), at + 0.8)) - point_at(maxf(0, at - 0.8))
	return direction.normalized() if direction.length_squared() > 0.00001 else Vector3.FORWARD

func front() -> Vector3:
	return point_at(distance)

## Moves the front toward `limit` unless the next step would leave ground `can_enter` allows.
func advance(delta: float, limit: float, can_enter: Callable) -> bool:
	var next := minf(distance + SPEED * delta, limit)
	if next <= distance or not can_enter.call(point_at(next)):
		return false
	distance = next
	return true

func daily_use() -> float:
	return (people + 2 * mules + 3 * oxen) * FOOD_RATE

func consume(delta: float) -> void:
	food = maxf(0, food - daily_use() * delta)
	if food > 0:
		hunger = 0
		return
	hunger += delta
	while hunger >= DESERTION_INTERVAL and people > 0:
		hunger -= DESERTION_INTERVAL
		lose(1)

func lose(count: int) -> void:
	var taken := mini(count, people)
	people -= taken
	lost += taken
