extends "res://scripts/world/world_factory.gd"
## New authored region scenes. The original expedition_valley remains untouched.

var region := RegionLayout.MEADOW

func build_region(id: String) -> Node3D:
	region = id
	world = Node3D.new()
	world.name = "Windmeadow" if region == RegionLayout.MEADOW else "ForestBase"
	random.seed = 73129 if region == RegionLayout.MEADOW else 99173
	_lighting()
	_terrain()
	if region == RegionLayout.MEADOW:
		_start_camp()
		_road()
		_river()
		var herd := Node3D.new()
		herd.name = "GrazingHerds"
		herd.set_script(load("res://scripts/visuals/meadow_herd.gd"))
		world.add_child(herd)
		for i in range(6):
			_tent(Vector3(-26 if i % 2 == 0 else 26, 0, 141 + (i / 2) * 9), Color("c8af7b") if i % 2 == 0 else Color("729b9b"))
		_waypost(RegionLayout.CROSSING + Vector3(4, 0, 0), "숲으로 향하는 길\n도하 완료 후 E", Color("edc983"))
		_waypost(RegionLayout.CAMP_GATE, "길드 보급 수레\n도하 후 전진 기지로 · E", Color("d9c093"))
		_camp_prop("wagon",RegionLayout.CAMP_GATE + Vector3(0,0,-3))
		_camp_prop("dispatch",RegionLayout.CAMP_GATE + Vector3(-2.7,0,0))
		_waypost(RegionLayout.on_ground(region, Vector3(-9, 0, 120)), "바람결 초원\n북쪽 · 솔바람 도하장", Color("d9c093"))
	else:
		_base_site()
		_ruin()
		for point: Vector3 in [Vector3(-3.5, 0, 8), Vector3(3.5, 0, 8), Vector3(-4.5, 0, -7), Vector3(4.5, 0, -7)]:
			_lantern(point)
		_waypost(RegionLayout.FOREST_GATE, "길드 보급 수레\n출발 야영지로 · E", Color("d9c093"))
		_camp_prop("wagon",RegionLayout.FOREST_GATE + Vector3(-1.3,0,3.5))
		_camp_prop("dispatch",RegionLayout.FOREST_GATE + Vector3(1.5,0,3))
		for side in [-1, 1]:
			_tent(Vector3(side * 26, 0, 35), Color("819f95"))
			# Open construction plots belong to the hub rather than blocking its routes.
			for z in [7, 22]:
				var plot := Geometry.cylinder(world, Vector3(side * 20, 0.016, z), 4.5, 0.025, Color("8b896a"))
				plot.material_override = ExpeditionArt.material("stone",Color("8b896a"))
				for dx in [-3.7, 3.7]:
					Geometry.cylinder(world, Vector3(side * 20 + dx, 0.5, z + 3.7), 0.09, 1, Color("998563"))
			_waypost(Vector3(side * 20, 0, 0), "길드 확장 부지", Color("adc99d"))
	_vegetation()
	_backdrop()
	_navigation()
	return world

func _lighting() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	var sky := Sky.new()
	var gradient := ProceduralSkyMaterial.new()
	gradient.sky_top_color = Color("5387b0")
	gradient.sky_horizon_color = Color("a7c4dc")
	gradient.ground_horizon_color = Color("aebdbe")
	gradient.ground_bottom_color = Color("626e69")
	gradient.sky_curve = 0.55
	sky.sky_material = gradient
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b6c7d8")
	settings.ambient_light_energy = 0.42
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	settings.fog_enabled = true
	settings.fog_light_color = Color("aebfc9") if region == RegionLayout.MEADOW else Color("889d9d")
	settings.fog_light_energy = 0.7
	settings.fog_density = 0.0012 if region == RegionLayout.MEADOW else 0.004
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -38, 0)
	sun.light_color = Color("fff4de")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	world.add_child(sun)

func _terrain() -> void:
	var area := RegionLayout.bounds(region)
	const STEP := 2.0
	var cols := int(area.size.x / STEP) + 1
	var rows := int(area.size.y / STEP) + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var stations := [START_CAMP+CampArt.WORKSHOP,START_CAMP+CampArt.KITCHEN,RegionLayout.CAMP_GATE] if region == RegionLayout.MEADOW else [BASE_SITE+CampArt.BASE_WORKSHOP,BASE_SITE+CampArt.BASE_KITCHEN]
	for row in rows:
		for col in cols:
			var x := area.position.x + col * STEP
			var z := area.position.y + row * STEP
			var h := RegionLayout.ground_y(region, x, z)
			vertices.append(Vector3(x, h, z))
			var dx := RegionLayout.ground_y(region, x + 0.1, z) - RegionLayout.ground_y(region, x - 0.1, z)
			var dz := RegionLayout.ground_y(region, x, z + 0.1) - RegionLayout.ground_y(region, x, z - 0.1)
			normals.append(Vector3(-dx, 0.2, -dz).normalized())
			var patch := (sin(x * 0.14 + sin(z * 0.03)) * cos(z * 0.09) + 1) * 0.5
			var color := Color("687c49").lerp(Color("929869"), patch) if region == RegionLayout.MEADOW else Color("56684f").lerp(Color("7c8260"), patch)
			if region == RegionLayout.MEADOW:
				color = color.lerp(Color("aa9875"), 1.0 - smoothstep(3.3, 5.8, absf(x - RegionLayout.road_x(z))))
				if absf(z) < 15: color = color.lerp(Color("969c86"), 1.0 - smoothstep(9, 16, absf(z)))
				var wear := 1.0-smoothstep(9,13,Vector2(x,z-START_CAMP.z).length()+sin(x*.5)*.45+cos(z*.8)*.4)
				color = color.lerp(Color("a69372"),wear*.9)
			else:
				var trail := 1.0 - smoothstep(2.5,4.7,absf(x + sin(z*.14)*.45))
				var clearing := 1.0 - smoothstep(8.5,13.0,Vector2(x,z-BASE_SITE.z).length())
				color = color.lerp(Color("a08d6c"),maxf(trail,clearing))
			for station: Vector3 in stations:
				var wear := 1.0-smoothstep(2.4,4.4,Vector2(x-station.x,z-station.z).length())
				color = color.lerp(Color("9a8766"),wear*.85)
			colors.append(color)
	for row in range(rows - 1):
		for col in range(cols - 1):
			var a := row * cols + col
			indices.append_array(PackedInt32Array([a, a + 1, a + cols, a + 1, a + cols + 1, a + cols]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain := MeshInstance3D.new()
	terrain.name = "RollingGround"
	terrain.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/meadow_ground.gdshader")
	terrain.material_override = material
	world.add_child(terrain)
	terrain.create_trimesh_collision()

func _road() -> void:
	var stones: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in range(72):
		var z := 140 - i * 2.1
		if z < 17: continue
		var x := RegionLayout.road_x(z) + random.randf_range(-2.0, 2.0)
		stones.append(Transform3D(Basis(Vector3.UP, random.randf() * PI).scaled(Vector3(0.6, 0.06, 0.4)), RegionLayout.on_ground(region, Vector3(x, 0.06, z)) + Vector3.UP * 0.04))
		colors.append(Color("c7c09a"))
	Geometry.instances(world, ExpeditionArt.stone_mesh(2), stones, colors).name = "TrailStones"
	for z in [112, 64, 28]:
		var x := RegionLayout.road_x(z) + 6
		_banner(RegionLayout.on_ground(region, Vector3(x, 0, z)), Color("c18e59"))

func _river() -> void:
	var water := Geometry.box(world, Vector3(0, -1.1, 0), Vector3(250, 0.06, 21), Color("5eacb2"))
	water.name = "SolwindRiver"
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; void fragment(){ float wave = sin(VERTEX.x * 0.8 + TIME * 1.6) * sin(VERTEX.z * 1.2 - TIME); ALBEDO = mix(vec3(0.21,0.49,0.53),vec3(0.48,0.72,0.69),wave * 0.25 + 0.45); ROUGHNESS = 0.3; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	water.material_override = material
	Geometry.solid_box(world, Vector3(0, -0.24, 0), Vector3(8, 0.48, 31), Color("947c57"))
	for i in range(39):
		Geometry.box(world, Vector3(0, 0.012, -15.2 + i * 0.8), Vector3(7.8, 0.025, 0.64), Color("bea372") if i % 3 else Color("ab9266"))
	for side in [-1, 1]:
		for z in [-14, -7, 0, 7, 14]:
			Geometry.cylinder(world, Vector3(side * 4, 0.7, z), 0.15, 1.5, Color("806b4a"))
		_solid(Vector3(side * 4.05, 0.74, 0), Vector3(0.17, 0.12, 30), Color("c3ac7b"))
		_banner(Vector3(side * 6, 0, 18), Color("718e9c"))
	_waypost(Vector3(-6, 0, 19), "솔바람 도하장", Color("e4d1a3"))

func _banner(at: Vector3, tint: Color) -> void:
	Geometry.cylinder(world, at + Vector3(0, 2, 0), 0.095, 4, Color("786a50"))
	var banner := Geometry.box(world, at + Vector3(0.7, 3.35, 0), Vector3(1.3, 0.8, 0.035), tint)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; uniform vec4 tint: source_color; void vertex(){ VERTEX.z += sin(TIME * 2.2 + VERTEX.x * 3.0 + MODEL_MATRIX[3].z) * (VERTEX.x + 0.7) * 0.17; } void fragment(){ ALBEDO = tint.rgb; ROUGHNESS = 0.9; }"
	material.shader = shader
	material.set_shader_parameter("tint", tint)
	banner.material_override = material

func _waypost(at: Vector3, text: String, tint: Color) -> void:
	var sign := Node3D.new()
	sign.position = at
	world.add_child(sign)
	Geometry.cylinder(sign, Vector3(0, 0.9, 0), 0.09, 1.8, Color("816b4e"))
	Geometry.box(sign, Vector3(0, 1.7, 0), Vector3(1.5, 0.55, 0.12), tint)
	var label := Geometry.label(sign, text, 2.7, Color("fff0cc"))
	label.visibility_range_end = 35

func _vegetation() -> void:
	var area := RegionLayout.bounds(region).grow(-5)
	var count := 72 if region == RegionLayout.MEADOW else 200
	for i in count:
		var x := random.randf_range(area.position.x, area.end.x)
		var z := random.randf_range(area.position.y, area.end.y)
		if region == RegionLayout.MEADOW:
			if absf(x - RegionLayout.road_x(z)) < 11 or absf(z) < 20 or Vector2(x, z - 150).length() < 37: continue
		else:
			if absf(x) < 13 or (absf(x) < 41 and z > -1): continue
		_tree(RegionLayout.on_ground(region, Vector3(x, 0, z)), random.randf_range(1.5, 2.6) if region == RegionLayout.MEADOW else random.randf_range(1.6, 3.0))
	_tree_meshes()
	var tufts: Array[Transform3D] = []
	var colors: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	for i in range(20000 if region == RegionLayout.MEADOW else 5000):
		var x := random.randf_range(area.position.x, area.end.x)
		var z := random.randf_range(area.position.y, area.end.y)
		if region == RegionLayout.MEADOW:
			if absf(x - RegionLayout.road_x(z)) < 4.5 or absf(z) < 16 or Vector2(x, z - 150).length() < 32: continue
		else:
			if absf(x) < 11 or (absf(x) < 40 and z > 0): continue
		var at := RegionLayout.on_ground(region, Vector3(x, 0, z))
		var scale := random.randf_range(0.55, 1.3)
		tufts.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale), at))
		colors.append(Color("959b61").lerp(Color("617b48"), random.randf()))
		if i % 8 == 0:
			flowers.append(Transform3D(Basis().scaled(Vector3(0.18, 0.15, 0.18)), at + Vector3.UP * 0.48))
			flower_colors.append(Color("e6cf85") if i % 3 else Color("c6b4d3"))
	var grass_mesh := SurfaceTool.new()
	grass_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		var angle := i * PI / 3
		var offset := Vector3(cos(angle), 0, sin(angle)) * 0.17
		var side := Vector3(-sin(angle), 0, cos(angle)) * 0.055
		for vertex in [offset - side, offset + side, offset * 1.8 + Vector3(0.08, 0.5 + (i % 3) * 0.13, 0.04)]:
			grass_mesh.set_normal(Vector3.UP)
			grass_mesh.add_vertex(vertex)
	var grass := Geometry.instances(world, grass_mesh.commit(), tufts, colors)
	grass.name = "WindGrass"
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/wind_grass.gdshader")
	grass.material_override = material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Geometry.instances(world, Geometry.unit_sphere(), flowers, flower_colors)
	for i in range(36):
		var x := random.randf_range(area.position.x, area.end.x)
		var z := random.randf_range(area.position.y, area.end.y)
		if absf(x) < (42 if region == RegionLayout.FOREST else 40): continue
		var at := RegionLayout.on_ground(region, Vector3(x, 0, z))
		var rock := Geometry.mesh(world, ExpeditionArt.stone_mesh(i % 3), at, Color("777e74"))
		rock.scale = Vector3(3.5, 2.3, 3)
		rock.material_override = ExpeditionArt.material("stone", Color("85897a"))

func _backdrop() -> void:
	var area := RegionLayout.bounds(region)
	# Layered silhouettes beyond the playable boundary keep the horizon expansive.
	for i in range(32):
		var angle := i * TAU / 32
		var at := Vector3(sin(angle) * (area.size.x * 0.5 + 45), 2, area.get_center().y + cos(angle) * (area.size.y * 0.5 + 45))
		var h := random.randf_range(28, 62)
		var peak := Geometry.mesh(world, ExpeditionArt.stone_mesh(i % 3), at, Color("687f90").lerp(Color("8d9da6"), random.randf()))
		peak.scale = Vector3(random.randf_range(65, 100), h, random.randf_range(60, 94))
		peak.rotation.y = random.randf() * TAU
	# Steep terrain and overlapping, collidable rock shoulders form the boundary.
	# No straight wall cuts across the meadow vista.
	for edge in range(4):
		var length := area.size.y if edge < 2 else area.size.x
		for i in range(int(length / 9) + 1):
			var at := Vector3(area.position.x if edge == 0 else area.end.x, 0, area.position.y + i * 9) if edge < 2 else Vector3(area.position.x + i * 9, 0, area.position.y if edge == 2 else area.end.y)
			at.x += random.randf_range(-2, 2)
			at.z += random.randf_range(-2, 2)
			at.y = RegionLayout.ground_y(region, at.x, at.z) - random.randf_range(3, 5)
			var rock := Geometry.mesh(world, ExpeditionArt.stone_mesh(i % 3), at, Color("767e73").lerp(Color("939887"), random.randf()))
			rock.scale = Vector3(random.randf_range(20, 27), random.randf_range(11, 23), random.randf_range(20, 27))
			rock.create_trimesh_collision()

func _start_camp() -> void:
	super._start_camp()
	# Near-field silhouettes frame the camp without occupying its central route.
	for at: Vector3 in [Vector3(-17,0,144),Vector3(19,0,158),Vector3(-22,0,164)]:
		_tree(RegionLayout.on_ground(region,at),1.45)
	_camp_prop("workshop",START_CAMP+CampArt.WORKSHOP)
	_camp_prop("kitchen",START_CAMP+CampArt.KITCHEN)
	for side in [-1,1]: _camp_prop("cargo",START_CAMP+Vector3(side*6.4,0,8.6))
	_banner(START_CAMP+Vector3(-3.6,0,4),Color("465c67"))
	_banner(START_CAMP+Vector3(3.6,0,4),Color("465c67"))

func _tent(position: Vector3, tint: Color) -> void:
	ExpeditionArt.tent(world,position,tint)
	obstacles.append(Rect2(Vector2(position.x-2.4,position.z-2.5),Vector2(4.8,5)))

func _crate(position: Vector3) -> void:
	CampArt.place(world,"single_crate",position)
	obstacles.append(Rect2(Vector2(position.x-.975,position.z-.975),Vector2(1.95,1.95)))

func _camp_prop(kind: String, at: Vector3) -> void:
	CampArt.place(world,kind,at)
	obstacles.append_array(CampArt.footprints(kind,at))

func _fire(position: Vector3) -> void:
	_camp_prop("hearth",position)

func _base_site() -> void:
	super._base_site()
	for item in [["workshop",CampArt.BASE_WORKSHOP],["kitchen",CampArt.BASE_KITCHEN],["hearth",Vector3(0,0,4)],["cargo",Vector3(-6.4,0,8.6)],["cargo",Vector3(6.4,0,8.6)]]:
		obstacles.append_array(CampArt.footprints(item[0],BASE_SITE+item[1]))

func _tree_meshes() -> void:
	var trunks := Geometry.instances(world,ExpeditionArt.trunk_mesh(),tree_spots)
	trunks.name = "BranchingTrunks"
	trunks.material_override = ExpeditionArt.material("wood",Color("62523f"))
	var parts := [[Vector3(0,4.1,0),Vector3(3.2,2.7,2.9)], [Vector3(-1.02,3.15,.15),Vector3(2.35,1.8,2.2)], [Vector3(1.05,3.55,-.16),Vector3(2.4,2.1,2.3)], [Vector3(.15,3.75,.8),Vector3(2.1,2.0,2.0)]]
	for part in parts:
		var leaves: Array[Transform3D] = []
		var tints: Array[Color] = []
		for i in tree_spots.size():
			leaves.append(tree_spots[i]*Transform3D(Basis(Vector3.UP,i*.71).scaled(part[1]),part[0]))
			tints.append(Color("526e3f").lerp(Color("8a9053"),float(i%7)/6.0))
		Geometry.instances(world,ExpeditionArt.foliage_mesh(),leaves,tints).name="SculptedCanopy"

func _navigation() -> void:
	var area := RegionLayout.bounds(region).grow(-2)
	var step := 2.0 if region == RegionLayout.MEADOW else 1.0
	var cols := int(area.size.x / step) + 1
	var rows := int(area.size.y / step) + 1
	var vertices := PackedVector3Array()
	for row in rows:
		for col in cols:
			var x := area.position.x + col * step
			var z := area.position.y + row * step
			vertices.append(Vector3(x, RegionLayout.walk_y(region, x, z) + 0.05, z))
	var nav := NavigationMesh.new()
	nav.agent_radius = 0.35
	nav.vertices = vertices
	for row in range(rows - 1):
		for col in range(cols - 1):
			var cell := Rect2(area.position + Vector2(col, row) * step, Vector2.ONE * step)
			if RegionLayout.nav_blocked(region, cell): continue
			var blocked := false
			for obstacle in obstacles:
				if cell.intersects(obstacle):
					blocked = true
					break
			if not blocked:
				var a := row * cols + col
				var low := minf(minf(vertices[a].y, vertices[a + 1].y), minf(vertices[a + cols].y, vertices[a + cols + 1].y))
				var high := maxf(maxf(vertices[a].y, vertices[a + 1].y), maxf(vertices[a + cols].y, vertices[a + cols + 1].y))
				if high - low > step * 0.85: continue
				nav.add_polygon(PackedInt32Array([a, a + cols, a + cols + 1, a + 1]))
	var navigation := NavigationRegion3D.new()
	navigation.name = "WalkableGround"
	navigation.navigation_mesh = nav
	world.add_child(navigation)
