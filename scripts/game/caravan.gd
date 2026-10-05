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

func _init(points: PackedVector3Array = PackedVector3Array()) -> void:
	route = points

func length() -> float:
	var total := 0.0
	for i in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	return total

func point_at(at: float) -> Vector3:
	if route.is_empty():
		return Vector3.ZERO
	var left := maxf(0, at)
	for i in range(1, route.size()):
		var segment := route[i - 1].distance_to(route[i])
		if left <= segment:
			return route[i - 1].lerp(route[i], left / segment)
		left -= segment
	return route[route.size() - 1]

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
