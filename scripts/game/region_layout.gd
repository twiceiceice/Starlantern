class_name RegionLayout
extends RefCounted
## Shared authored geography: rendering, collision, navigation and the caravan sample
## the same terrain. Only the active region is loaded into the scene tree.

const MEADOW := "meadow"
const FOREST := "forest"
const SCENES := {MEADOW: "res://scenes/world/windmeadow.tscn", FOREST: "res://scenes/world/forest_base.tscn"}
const NAMES := {MEADOW: "01 · 바람결 초원", FOREST: "02 · 별등 전진 기지"}
const START := Vector3(0, 0, 150)
const BASE := Vector3(0, 0, 16)
const CROSSING := Vector3(0, 0, -22)
const FOREST_GATE := Vector3(5, 0, 48)
const CAMP_GATE := Vector3(-10, 0, 135)

static func bounds(region: String) -> Rect2:
	return Rect2(-125, -110, 250, 306) if region == MEADOW else Rect2(-60, -52, 120, 126)

static func road_x(z: float) -> float:
	var t := clampf((146.0 - z) / 126.0, 0, 1)
	return -22.0 * sin(t * TAU) * sin(t * PI) * smoothstep(20, 48, z)

static func road_y(z: float) -> float:
	return 3.6 * pow(sin(clampf((146 - z) / 126.0, 0, 1) * PI), 2) * smoothstep(22, 42, z)

static func ground_y(region: String, x: float, z: float) -> float:
	var area := bounds(region)
	var edge := minf(minf(x - area.position.x, area.end.x - x), minf(z - area.position.y, area.end.y - z))
	var ridge := 16.0 * (1.0 - smoothstep(0, 13, edge))
	if region == FOREST:
		# The established base, workers and career encounters share a level clearing.
		return (3.0 + 2.0 * sin(z * 0.07)) * smoothstep(40, 54, absf(x)) + ridge
	var off_road := smoothstep(5, 32, absf(x - road_x(z)))
	var hills := 5.5 + 4 * sin(x * 0.034 + z * 0.016) + 3 * cos(z * 0.041 - x * 0.021)
	var height := road_y(z) + hills * off_road
	var camp_distance := Vector2(x, z - 150).length()
	height *= smoothstep(32, 52, camp_distance)
	# A real river bed; only the bridge provides a walkable surface above the water.
	height = lerpf(-2.8, height, smoothstep(8, 17, absf(z)))
	return height + ridge

static func walk_y(region: String, x: float, z: float) -> float:
	if region == MEADOW and absf(x) <= 4.2 and absf(z) <= 16:
		return 0.0
	return ground_y(region, x, z)

static func on_ground(region: String, at: Vector3) -> Vector3:
	return Vector3(at.x, walk_y(region, at.x, at.z), at.z)

static func route() -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in range(84):
		var z := 146.0 - i * 2.0
		points.append(Vector3(road_x(z), road_y(z), z))
	return points

static func river_unsafe(at: Vector3) -> bool:
	return absf(at.z) < 11.5 and absf(at.x) > 4.0 and at.y < -0.6

static func nav_blocked(region: String, cell: Rect2) -> bool:
	return region == MEADOW and cell.intersects(Rect2(-125, -12, 250, 24)) and (cell.position.x < -3 or cell.end.x > 3)
