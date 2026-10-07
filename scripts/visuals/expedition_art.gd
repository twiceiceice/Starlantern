class_name ExpeditionArt
extends RefCounted
## Reusable authored profiles for the mature art pass. Cache shared geometry/materials.
## Meshes are saved into region scenes; runtime props use exactly the same profiles.

static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func material(kind: String, tint: Color) -> Material:
	var key := kind + tint.to_html()
	if materials.has(key): return materials[key]
	var result := ShaderMaterial.new()
	result.shader = load("res://assets/shaders/expedition_surface.gdshader")
	result.set_shader_parameter("tint", tint)
	result.set_shader_parameter("grain", 1.0 if kind == "wood" else (2.0 if kind == "canvas" else 0.0))
	materials[key] = result
	return result

static func _triangle(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color = Color.WHITE) -> void:
	var n := (b - a).cross(c - a).normalized()
	for v in [a, c, b]: # Godot's clockwise front face, outward authored normals.
		s.set_normal(n)
		s.set_color(tint)
		s.add_vertex(v)

static func _quad(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color = Color.WHITE) -> void:
	_triangle(s, a, b, c, tint)
	_triangle(s, a, c, d, tint)

static func _profile(s: SurfaceTool, rings: Array, count: int, seed_value: float, rugged: float = 0.0) -> void:
	var previous: Array[Vector3] = []
	for row in rings:
		var points: Array[Vector3] = []
		for i in count:
			var angle := i * TAU / count
			var irregular := 1.0 + sin(i * 5.13 + seed_value) * rugged + cos(i * 3.7 + row.y * 4.1) * rugged * 0.5
			points.append(Vector3(sin(angle) * row.x * irregular + sin(row.y * 3 + seed_value) * rugged * 0.13, row.y, cos(angle) * row.z * irregular))
		if not previous.is_empty():
			for i in count:
				var j := (i + 1) % count
				var shade := Color.WHITE.darkened(0.04 + (sin(i * 3.8 + seed_value) + 1) * 0.045)
				_quad(s, previous[i], previous[j], points[j], points[i], shade)
		previous = points

static func stone_mesh(variant: int = 0) -> ArrayMesh:
	var key := "rock%d" % variant
	if meshes.has(key): return meshes[key]
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	_profile(s, [Vector3(0.24, -0.14, 0.3), Vector3(0.52, 0.06, 0.48), Vector3(0.48, 0.37, 0.44), Vector3(0.29, 0.76, 0.30), Vector3(0.05, 1.0, 0.06)], 9, variant + 0.7, 0.30)
	meshes[key] = s.commit()
	return meshes[key]

static func foliage_mesh() -> ArrayMesh:
	if meshes.has("foliage"): return meshes.foliage
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	_profile(s, [Vector3(0.025,-0.4,0.04), Vector3(0.36,-0.27,0.37), Vector3(0.52,0,0.5), Vector3(0.37,0.3,0.35), Vector3(0.13,0.46,0.14), Vector3(0.01,0.52,0.01)], 13, 8.4, 0.25)
	meshes.foliage = s.commit()
	return meshes.foliage

static func _beam(s: SurfaceTool, a: Vector3, b: Vector3, radius: float, taper: float = 1.0) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var other := axis.cross(side).normalized()
	for i in 7:
		var t := i * TAU / 7
		var t2 := (i + 1) * TAU / 7
		var offset := (side * cos(t) + other * sin(t)) * radius
		var next := (side * cos(t2) + other * sin(t2)) * radius
		_quad(s, a + offset, a + next, b + next * taper, b + offset * taper)

static func trunk_mesh() -> ArrayMesh:
	if meshes.has("trunk"): return meshes.trunk
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	_profile(s, [Vector3(.48,0,.4),Vector3(.23,.5,.23),Vector3(.17,2,.17),Vector3(.12,3.4,.11),Vector3(.03,4.2,.04)], 8, 2.5, 0.16)
	_beam(s, Vector3(0,1.8,0), Vector3(-1.15,3.0,.15), .13, .33)
	_beam(s, Vector3(0,2.35,0), Vector3(1.12,3.5,-.2), .12, .30)
	_beam(s, Vector3(0,2.9,0), Vector3(.2,3.8,.8), .10, .25)
	meshes.trunk = s.commit()
	return meshes.trunk

static func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, tint: Color) -> MeshInstance3D:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	_beam(s, a, b, radius)
	var result := Geometry.mesh(parent, s.commit(), Vector3.ZERO, tint)
	result.material_override = material("wood", tint)
	return result

static func tent(parent: Node3D, at: Vector3, tint: Color) -> Node3D:
	var result := Node3D.new()
	result.name = "CanvasPavilion"
	result.position = at
	parent.add_child(result)
	# Keep the original footprint so navigation, camera collisions and saves agree.
	var solid := StaticBody3D.new()
	result.add_child(solid)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.7,1.4,3.8)
	collision.shape = shape
	collision.position.y = .7
	solid.add_child(collision)
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cross_section := [Vector2(-1.96,1.32),Vector2(-1.12,1.79),Vector2(0,2.62),Vector2(1.12,1.79),Vector2(1.96,1.32)]
	for z in range(6):
		var near_z := -2.1 + z * .7
		var far_z := near_z + .7
		for i in range(cross_section.size() - 1):
			var a: Vector2 = cross_section[i]
			var b: Vector2 = cross_section[i+1]
			var sag_a := sin(z * PI / 6) * .07
			var sag_b := sin((z+1) * PI / 6) * .07
			_quad(s,Vector3(a.x,a.y-sag_a,near_z),Vector3(a.x,a.y-sag_b,far_z),Vector3(b.x,b.y-sag_b,far_z),Vector3(b.x,b.y-sag_a,near_z))
	for side in [-1,1]:
		_quad(s,Vector3(side*1.85,0,-2),Vector3(side*1.85,0,2),Vector3(side*1.96,1.32,2.1),Vector3(side*1.96,1.32,-2.1))
		# Opened canvas curtains frame a dark entrance.
		_quad(s,Vector3(side*.62,0,-2.04),Vector3(side*1.85,0,-2.04),Vector3(side*1.95,1.32,-2.1),Vector3(side*.34,2.38,-2.1))
		beam(result,Vector3(side*1.84,0,-1.95),Vector3(side*1.84,1.48,-1.95),.045,Color("64503d"))
		for z in [-1.9,1.9]:
			beam(result,Vector3(side*1.92,1.34,z),Vector3(side*2.30,.07,z+.35),.012,Color("c3ac7c"))
	_quad(s,Vector3(-1.85,0,2),Vector3(1.85,0,2),Vector3(1.96,1.32,2.1),Vector3(-1.96,1.32,2.1))
	_triangle(s,Vector3(-1.96,1.32,2.1),Vector3(1.96,1.32,2.1),Vector3(0,2.62,2.1))
	var cloth := Geometry.mesh(result,s.commit(),Vector3.ZERO,tint)
	cloth.material_override = material("canvas", Color("b2a287").lerp(tint,.22))
	Geometry.box(result,Vector3(0,.66,-1.99),Vector3(1.25,1.32,.03),Color("343933"))
	beam(result,Vector3(0,0,-2.1),Vector3(0,2.78,-2.1),.055,Color("67553c"))
	beam(result,Vector3(0,2.67,-2.25),Vector3(0,2.67,2.25),.055,Color("67553c"))
	return result

static func crate(parent: Node3D, at: Vector3) -> void:
	var body := Geometry.solid_box(parent,at+Vector3(0,.5,0),Vector3(.95,1,.95),Color("6c553c"))
	body.get_child(0).material_override = material("wood",Color("806647"))
	for side in [-1,1]:
		for y in [.12,.88]:
			var slat := Geometry.box(parent,at+Vector3(0,y,side*.491),Vector3(.99,.085,.045),Color("a18356"))
			slat.material_override = material("wood",Color("a18356"))
		for x in [-.36,.36]:
			Geometry.box(parent,at+Vector3(x,.5,side*.52),Vector3(.035,.84,.019),Color("454a45"))

static func crowd_torso() -> ArrayMesh:
	if meshes.has("crowd_body"): return meshes.crowd_body
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	_profile(s,[Vector3(.21,.77,.13),Vector3(.175,1.08,.13),Vector3(.245,1.42,.13),Vector3(.08,1.57,.07)],8,1.2)
	for x in [-.285,.285]:
		_beam(s,Vector3(x,1.44,0),Vector3(x*1.12,.95,.02),.078,.63)
	meshes.crowd_body=s.commit()
	return meshes.crowd_body

static func crowd_leg() -> ArrayMesh:
	if meshes.has("crowd_leg"): return meshes.crowd_leg
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	_profile(s,[Vector3(.075,-.94,.13),Vector3(.073,-.68,.076),Vector3(.09,-.43,.09),Vector3(.103,0,.105)],7,0)
	meshes.crowd_leg=s.commit()
	return meshes.crowd_leg

static func wagon_mesh() -> ArrayMesh:
	if meshes.has("wagon"): return meshes.wagon
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for level in range(5):
			var y := -.31+level*.14
			_quad(s,Vector3(side*.76,y,-1.2),Vector3(side*.76,y,1.2),Vector3(side*.76,y+.12,1.2),Vector3(side*.76,y+.12,-1.2))
		for z in [-1.16,1.16]:
			_beam(s,Vector3(side*.78,-.33,z),Vector3(side*.78,.41,z),.047)
	for z in [-1.21,1.21]:
		_quad(s,Vector3(-.75,-.32,z),Vector3(.75,-.32,z),Vector3(.75,.31,z),Vector3(-.75,.31,z))
	_quad(s,Vector3(-.75,-.32,-1.2),Vector3(.75,-.32,-1.2),Vector3(.75,-.32,1.2),Vector3(-.75,-.32,1.2))
	meshes.wagon=s.commit()
	return meshes.wagon

static func wagon_cover() -> ArrayMesh:
	if meshes.has("cover"): return meshes.cover
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The caravan rotates this +90 about X; the model therefore extends along Y.
	for i in 12:
		var a:=i*PI/12
		var b:=(i+1)*PI/12
		_quad(s,Vector3(cos(a)*.79,-1.16,-sin(a)*.79),Vector3(cos(a)*.79,1.16,-sin(a)*.79),Vector3(cos(b)*.79,1.16,-sin(b)*.79),Vector3(cos(b)*.79,-1.16,-sin(b)*.79))
	meshes.cover=s.commit()
	return meshes.cover

static func wheel_mesh() -> ArrayMesh:
	if meshes.has("wheel"): return meshes.wheel
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var a:=i*TAU/16
		var b:=(i+1)*TAU/16
		var v:=Vector3(sin(a),0,cos(a))
		var w:=Vector3(sin(b),0,cos(b))
		for side in [-1,1]:
			var off:=Vector3(0,side*.058,0)
			_quad(s,v*.42+off,w*.42+off,w*.35+off,v*.35+off)
		_quad(s,v*.42+Vector3(0,-.058,0),w*.42+Vector3(0,-.058,0),w*.42+Vector3(0,.058,0),v*.42+Vector3(0,.058,0))
		if i%2==0: _beam(s,Vector3.ZERO,v*.375,.022)
	_beam(s,Vector3(0,-.085,0),Vector3(0,.085,0),.08)
	meshes.wheel=s.commit()
	return meshes.wheel

static func animal_head() -> ArrayMesh:
	if meshes.has("animal_head"): return meshes.animal_head
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	_profile(s,[Vector3(.22,-.47,.24),Vector3(.35,-.31,.35),Vector3(.41,.10,.34),Vector3(.26,.42,.24),Vector3(.02,.49,.02)],9,1.2)
	for side in [-1,1]:
		_beam(s,Vector3(side*.25,.30,.05),Vector3(side*.39,.86,.13),.08,.2)
		# Muzzle projects towards the caravan's -Z facing direction.
		_triangle(s,Vector3(side*.28,-.20,-.24),Vector3(side*.22,-.47,-.57),Vector3(side*.24,-.05,-.47),Color("b0b1a3"))
	_quad(s,Vector3(-.22,-.47,-.57),Vector3(.22,-.47,-.57),Vector3(.24,-.05,-.47),Vector3(-.24,-.05,-.47),Color("b0b1a3"))
	meshes.animal_head=s.commit()
	return meshes.animal_head

static func animal_body() -> ArrayMesh:
	if meshes.has("animal_body"): return meshes.animal_body
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cross sections along the spine; shoulders and rump differ from a scaled ball.
	var rings := [Vector3(.15,.18,-.51),Vector3(.35,.36,-.38),Vector3(.40,.43,.04),Vector3(.34,.37,.39),Vector3(.04,.08,.52)]
	for r in range(rings.size()-1):
		var a: Vector3=rings[r]
		var b: Vector3=rings[r+1]
		for i in 10:
			var t:=i*TAU/10
			var u:=(i+1)*TAU/10
			_quad(s,Vector3(sin(t)*a.x,cos(t)*a.y,a.z),Vector3(sin(u)*a.x,cos(u)*a.y,a.z),Vector3(sin(u)*b.x,cos(u)*b.y,b.z),Vector3(sin(t)*b.x,cos(t)*b.y,b.z))
	_beam(s,Vector3(0,-.04,.45),Vector3(0,-.52,.62),.038,.5)
	meshes.animal_body=s.commit()
	return meshes.animal_body
