extends RefCounted
## Used by tools/build_world.gd. The saved scene is editable in the Godot editor.

var obstacles: Array[Rect2] = []
var world: Node3D
var random := RandomNumberGenerator.new()

## Valley layout along -Z: start camp (z 150) -> forest road (leg 1) -> pass (leg 2)
## -> forward base site (z 16) -> moss ruin (z -11..-31). Runtime systems add lanterns,
## quest posts, the caravan crowd and base buildings on top of this static ground.
const NORTH := -40.0
const SOUTH := 166.0
const START_CAMP := Vector3(0, 0, 150)
const BASE_SITE := Vector3(0, 0, 16)
var tree_spots: Array[Transform3D] = []
var tree_colors: Array[Color] = []

func build() -> Node3D:
	world = Node3D.new()
	world.name = "ExpeditionValley"
	random.seed = 73129
	_lighting()
	var depth := SOUTH - NORTH
	Geometry.solid_box(world, Vector3(0, -0.5, (SOUTH + NORTH) * 0.5), Vector3(48, 1, depth), Color("77977a"))
	Geometry.cylinder(world, START_CAMP + Vector3(0, 0.014, 0), 9.5, 0.022, Color("bdb58e"))
	Geometry.cylinder(world, BASE_SITE + Vector3(0, 0.014, 0), 9.5, 0.022, Color("c4b98f"))
	Geometry.box(world, Vector3(0, 0.025, 63), Vector3(5.6, 0.025, 166), Color("b9b191"))
	Geometry.cylinder(world, Vector3(0, 0.035, -20), 10.3, 0.025, Color("a6ad98"))
	var stones: Array[Transform3D] = []
	for i in range(78):
		var basis := Basis(Vector3.UP, random.randf_range(-0.2, 0.2)).scaled(Vector3(random.randf_range(0.8, 1.6), 0.04, 0.8))
		stones.append(Transform3D(basis, Vector3(random.randf_range(-1.5, 1.5), 0.06, 145 - i * 2)))
	var stone_colors: Array[Color] = []
	stone_colors.resize(stones.size())
	stone_colors.fill(Color("c8c6a9"))
	Geometry.instances(world, BoxMesh.new(), stones, stone_colors).name = "RoadStones"
	_start_camp()
	_base_site()
	for point: Vector3 in [Vector3(-3.5, 0, 8), Vector3(3.5, 0, 8), Vector3(-4.5, 0, -7), Vector3(4.5, 0, -7)]:
		_lantern(point)
	_ruin()
	_pass()
	_forest()
	_meadow()
	# Low border cliffs are physical boundaries; they are visible, not invisible walls.
	_solid(Vector3(-24, 1.4, (SOUTH + NORTH) * 0.5), Vector3(1, 3, depth + 1), Color("80968d"))
	_solid(Vector3(24, 1.4, (SOUTH + NORTH) * 0.5), Vector3(1, 3, depth + 1), Color("80968d"))
	_solid(Vector3(0, 1.4, NORTH), Vector3(49, 3, 1), Color("80968d"))
	_solid(Vector3(0, 1.4, SOUTH), Vector3(49, 3, 1), Color("80968d"))
	_navigation()
	return world

func _start_camp() -> void:
	_tent(START_CAMP + Vector3(-6.2, 0, 3), Color("cb9777"))
	_tent(START_CAMP + Vector3(6.5, 0, 3), Color("829eae"))
	_fire(START_CAMP + Vector3(0, 0, 5))
	_crate(START_CAMP + Vector3(-4, 0, -2))
	_crate(START_CAMP + Vector3(-5, 0, -2.6))
	_crate(START_CAMP + Vector3(5, 0, -2))
	var camp_sign := Node3D.new()
	camp_sign.position = START_CAMP + Vector3(0, 0, 7)
	world.add_child(camp_sign)
	Geometry.label(camp_sign, "별등 출발 야영지", 2.1, Color("f7e1af"))

func _base_site() -> void:
	# Base buildings appear at runtime as construction progresses; reserve their ground now
	# so the saved navigation already routes around them.
	for footprint: Rect2 in [Rect2(-8.6, 16.5, 4.8, 5), Rect2(4.1, 16.5, 4.8, 5), Rect2(-6.2, 25.4, 2.4, 2.2)]:
		obstacles.append(footprint)
	var sign := Node3D.new()
	sign.position = BASE_SITE + Vector3(0, 0, 10.5)
	world.add_child(sign)
	Geometry.label(sign, "전진 기지 터", 1.6, Color("e7dfb9"))

func _ruin() -> void:
	for x: float in [-9.5, 9.5]:
		_solid(Vector3(x, 1.1, -22), Vector3(1.2, 2.2, 17), Color("748c88"))
		for z: float in [-29, -23, -17]:
			_solid(Vector3(x, 1.7, z), Vector3(1.7, 3.4, 1.7), Color("91a29a"))
	_solid(Vector3(0, 1.5, -31), Vector3(20, 3, 1.2), Color("708681"))
	for x: float in [-5.7, 5.7]:
		_solid(Vector3(x, 2.5, -11), Vector3(1.6, 5.0, 1.6), Color("95a89d"))
		Geometry.cylinder(world, Vector3(x, 5.1, -11), 1.02, 0.35, Color("b0bbab"))
	Geometry.solid_box(world, Vector3(0, 5.65, -11), Vector3(13.5, 0.55, 1.75), Color("8da399"))
	var sign := Node3D.new()
	sign.position = Vector3(0, 0, -11)
	world.add_child(sign)
	Geometry.label(sign, "별잠회랑 · 던전 입구", 6.3, Color("e7dfb9"))
	for point: Vector3 in [Vector3(-5, 0, -25), Vector3(5, 0, -26)]:
		_crystal(point)

func _pass() -> void:
	# Leg 2: rock shoulders narrow the road into a pass.
	for i in range(9):
		var z := 84 - i * 5.2
		for side: float in [-1, 1]:
			var width := random.randf_range(2.5, 4.5)
			var height := random.randf_range(2.0, 4.2)
			_solid(Vector3(side * (7.5 + width * 0.5 + random.randf_range(0, 1.5)), height * 0.5, z), Vector3(width, height, random.randf_range(3.5, 5.0)), Color("8a9b91").lerp(Color("a3ad9c"), random.randf()))
	var sign := Node3D.new()
	sign.position = Vector3(5.5, 0, 87)
	world.add_child(sign)
	Geometry.label(sign, "바람 고갯길", 2.4, Color("e7dfb9"))

func _forest() -> void:
	var sign := Node3D.new()
	sign.position = Vector3(-5.5, 0, 139)
	world.add_child(sign)
	Geometry.label(sign, "이끼 숲길", 2.4, Color("e7dfb9"))
	for i in range(150):
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := random.randf_range(NORTH + 4, SOUTH - 4)
		# Dense forest on leg 1, sparse elsewhere; the pass keeps its rocks clear.
		var near := 6.5 if z > 92 and z < 140 else 13.0
		if z > 36 and z < 88:
			near = 15.5
		if absf(z - START_CAMP.z) < 12 or absf(z - BASE_SITE.z) < 11:
			near = maxf(near, 12.5)
		_tree(Vector3(side * random.randf_range(near, 22), 0, z), random.randf_range(0.75, 1.3))
	_tree_meshes()

func _meadow() -> void:
	var tufts: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for i in range(420):
		var x := random.randf_range(-23, 23)
		var z := random.randf_range(NORTH + 2, SOUTH - 2)
		if absf(x) < 4:
			continue
		tufts.append(Transform3D(Basis().scaled(Vector3(0.45, 0.28, 0.45)), Vector3(x, 0.15, z)))
		if i % 3 == 0:
			flowers.append(Transform3D(Basis().scaled(Vector3(0.11, 0.12, 0.11)), Vector3(x, 0.31, z)))
	var tuft_colors: Array[Color] = []
	tuft_colors.resize(tufts.size())
	tuft_colors.fill(Color("89a979"))
	Geometry.instances(world, Geometry.unit_sphere(), tufts, tuft_colors).name = "GrassTufts"
	var flower_colors: Array[Color] = []
	flower_colors.resize(flowers.size())
	flower_colors.fill(Color("e8cd88"))
	Geometry.instances(world, Geometry.unit_sphere(), flowers, flower_colors).name = "Flowers"

func _lighting() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("a6c2c1")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d4dfcf")
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	settings.fog_enabled = true
	settings.fog_light_color = Color("b5c7bb")
	settings.fog_light_energy = 0.8
	settings.fog_density = 0.008
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff4de")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	world.add_child(sun)

func _solid(position: Vector3, size: Vector3, color: Color) -> void:
	Geometry.solid_box(world, position, size, color)
	obstacles.append(Rect2(Vector2(position.x - size.x * 0.5, position.z - size.z * 0.5), Vector2(size.x, size.z)).grow(0.5))

func _tree(position: Vector3, size: float) -> void:
	var trunk := StaticBody3D.new()
	trunk.position = position
	world.add_child(trunk)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 2.2, 0.45) * size
	collider.shape = shape
	collider.position.y = 1.1 * size
	trunk.add_child(collider)
	tree_spots.append(Transform3D(Basis().scaled(Vector3.ONE * size), position))
	tree_colors.append(Color("527e69").lerp(Color("91a977"), random.randf()))
	obstacles.append(Rect2(Vector2(position.x - 0.8, position.z - 0.8), Vector2(1.6, 1.6)))

## All trees share four MultiMeshes (trunk and three leaf clusters) instead of 5 nodes each.
func _tree_meshes() -> void:
	var trunk := CylinderMesh.new()
	trunk.bottom_radius = 0.28
	trunk.top_radius = 0.18
	trunk.height = 2.4
	trunk.radial_segments = 12
	var parts := [[Vector3(0, 3.5, 0), Vector3(3.2, 3.4, 3.0), 0.0], [Vector3(-0.75, 2.7, 0.25), Vector3(2.1, 2.0, 2.0), 0.035], [Vector3(0.8, 2.8, -0.15), Vector3(2.2, 2.4, 2.1), -0.025]]
	var trunks: Array[Transform3D] = []
	var bark: Array[Color] = []
	for spot in tree_spots:
		trunks.append(spot * Transform3D(Basis(), Vector3(0, 1.2, 0)))
		bark.append(Color("827052"))
	Geometry.instances(world, trunk, trunks, bark).name = "TreeTrunks"
	for part in parts:
		var leaves: Array[Transform3D] = []
		var tints: Array[Color] = []
		for i in tree_spots.size():
			leaves.append(tree_spots[i] * Transform3D(Basis().scaled(part[1]), part[0]))
			var shade: float = part[2]
			tints.append(tree_colors[i].lightened(shade) if shade > 0 else tree_colors[i].darkened(-shade))
		Geometry.instances(world, Geometry.unit_sphere(), leaves, tints).name = "TreeLeaves"

func _tent(position: Vector3, tint: Color) -> void:
	var tent := Node3D.new()
	tent.position = position
	world.add_child(tent)
	Geometry.solid_box(tent, Vector3(0, 0.7, 0), Vector3(3.7, 1.4, 3.8), tint.darkened(0.2))
	for side: float in [-1, 1]:
		var roof := Geometry.box(tent, Vector3(side * 1.04, 1.75, 0), Vector3(2.8, 0.15, 4.2), tint)
		roof.rotation.z = -side * 0.65
	Geometry.box(tent, Vector3(0, 0.85, -1.925), Vector3(1.2, 1.7, 0.06), Color("354b4c"))
	Geometry.cylinder(tent, Vector3(0, 1.2, -2.1), 0.065, 2.5, Color("9a8056"))
	Geometry.box(tent, Vector3(0, 2.8, 0), Vector3(0.11, 0.11, 4.5), Color("725f44"))
	obstacles.append(Rect2(Vector2(position.x - 2.4, position.z - 2.5), Vector2(4.8, 5)))

func _crate(position: Vector3) -> void:
	_solid(position + Vector3(0, 0.5, 0), Vector3(0.95, 1, 0.95), Color("ad8b5c"))
	for height: float in [0.16, 0.82]:
		Geometry.box(world, position + Vector3(0, height, -0.49), Vector3(0.96, 0.09, 0.06), Color("d5b77f"))

func _lantern(position: Vector3) -> void:
	Geometry.cylinder(world, position + Vector3(0, 1.05, 0), 0.06, 2.1, Color("6b6852"))
	Geometry.box(world, position + Vector3(0, 2.12, 0), Vector3(0.42, 0.1, 0.42), Color("475d55"))
	var glass := Geometry.sphere(world, position + Vector3(0, 1.86, 0), Vector3(0.24, 0.38, 0.24), Color("ffe6a1"))
	glass.material_override = Geometry.material(Color("ffe3a0"), 0.6)
	var glow := OmniLight3D.new()
	glow.position = position + Vector3(0, 1.8, 0)
	glow.light_color = Color("ffca83")
	glow.light_energy = 0.7
	glow.omni_range = 3.5
	world.add_child(glow)

func _fire(position: Vector3) -> void:
	Geometry.cylinder(world, position + Vector3(0, 0.09, 0), 0.95, 0.17, Color("776f5a"))
	for i in range(9):
		var angle := i * TAU / 9
		Geometry.sphere(world, position + Vector3(cos(angle) * 0.8, 0.16, sin(angle) * 0.8), Vector3(0.42, 0.3, 0.38), Color("929b85"))
	for i in range(3):
		var ember := Geometry.sphere(world, position + Vector3((i - 1) * 0.2, 0.5, 0), Vector3(0.34, 0.9, 0.4), Color("ffbf75"))
		ember.material_override = Geometry.material(Color("ffc578"), 0.8)
	var light := OmniLight3D.new()
	light.position = position + Vector3(0, 1, 0)
	light.light_color = Color("ffb85d")
	light.light_energy = 1.4
	light.omni_range = 7
	world.add_child(light)

func _crystal(position: Vector3) -> void:
	for i in range(4):
		var rock := Geometry.cylinder(world, position + Vector3((i % 2 - 0.5) * 0.7, 0.6, (i / 2 - 0.5) * 0.6), 0.25, 1.4, Color("b4cbd0"), 0.02)
		rock.rotation.z = (i - 1.5) * 0.14
		rock.material_override = Geometry.material(Color("acd2cf"), 0.15)
	Geometry.sphere(world, position + Vector3(0, 0.15, 0), Vector3(1.8, 0.3, 1.5), Color("6b8985"))

func _navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "WalkableGround"
	var nav := NavigationMesh.new()
	nav.agent_radius = 0.35
	var vertices := PackedVector3Array()
	const WIDTH := 47
	var depth := int(SOUTH - NORTH) - 1
	for z in range(depth):
		for x in range(WIDTH):
			vertices.append(Vector3(x - 23, 0.05, z + NORTH + 1))
	nav.vertices = vertices
	for z in range(depth - 1):
		for x in range(WIDTH - 1):
			var cell := Rect2(Vector2(x - 23, z + NORTH + 1), Vector2.ONE)
			var blocked := false
			for obstacle in obstacles:
				if cell.intersects(obstacle):
					blocked = true
					break
			if not blocked:
				var a := z * WIDTH + x
				nav.add_polygon(PackedInt32Array([a, a + WIDTH, a + WIDTH + 1, a + 1]))
	region.navigation_mesh = nav
	world.add_child(region)
