class_name ForestArt
extends RefCounted
## Branch silhouettes, layered evergreen crowns and pinnate ferns, shared in MultiMeshes.

static var cache: Dictionary = {}

static func foliage_material(tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/forest_foliage.gdshader")
	material.set_shader_parameter("tint",tint)
	return material

static func trunk() -> ArrayMesh:
	if cache.has("trunk"): return cache.trunk
	var b := CampArt.Sculpt.new()
	b.lathe("wood",Vector3.ZERO,[Vector2(.32,0),Vector2(.22,.6),Vector2(.17,2.5),Vector2(.12,4.2),Vector2(.028,5.7)],Basis.IDENTITY,12)
	for i in 7:
		var angle := i*TAU/7
		var outward := Vector3(cos(angle),0,sin(angle))
		b.beam("wood",Vector3(0,.47,0),outward*.64+Vector3.UP*.035,.10,.025)
	for level in 5:
		for i in 6:
			var a := i*TAU/6+level*.91
			var start := Vector3(0,1.4+level*.73,0)
			var end := start+Vector3(cos(a),.2,sin(a))*(1.23-level*.17)
			b.beam("wood",start,end,.055-level*.006,.014)
	cache.trunk = b.finish()
	return cache.trunk

static func crown() -> ArrayMesh:
	if cache.has("crown"): return cache.crown
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in 8:
		var height := 1.68+level*.51
		var radius := 1.70-level*.175
		for i in 17:
			var a := i*TAU/17+level*.43
			var c := (i+1)*TAU/17+level*.43
			var r := radius*(.93+sin(i*4.1+level)*.12)
			var rc := radius*(.93+sin((i+1)*4.1+level)*.12)
			var start := Vector3(cos(a)*r,height+sin(i*2.3)*.09,sin(a)*r)
			var end := Vector3(cos(c)*rc,height+sin((i+1)*2.3)*.09,sin(c)*rc)
			var top := Vector3(cos((a+c)*.5)*radius*.17,height+.85,sin((a+c)*.5)*radius*.17)
			var shade := Color.WHITE.darkened(.05+float((i+level)%5)*.025)
			ExpeditionArt._triangle(s,start,top,end,shade)
			ExpeditionArt._triangle(s,start,end,Vector3(0,height+.08,0),shade.darkened(.12))
	cache.crown = s.commit()
	return cache.crown

static func fern() -> ArrayMesh:
	if cache.has("fern"): return cache.fern
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in 9:
		var a := frond*TAU/9
		var outward := Vector3(sin(a),0,cos(a))
		var crosswise := Vector3(cos(a),0,-sin(a))
		var length := .70+float(frond%3)*.15
		for i in 7:
			var t := (i+.4)/7.0
			var center := outward*length*t+Vector3.UP*(sin(t*PI*.78)*.53+.02)
			var next := center+outward*.14+Vector3.UP*.025
			for side in [-1,1]:
				var leaf: Vector3 = center+crosswise*side*(.19*(1-t)+.025)+outward*.10
				ExpeditionArt._triangle(s,center,leaf,next,Color.WHITE.darkened(.04*(i%3)))
	cache.fern = s.commit()
	return cache.fern

static func draw_trees(parent: Node3D, transforms: Array[Transform3D]) -> void:
	var trunks := Geometry.instances(parent,trunk(),transforms)
	trunks.name = "ForestCedarTrunks"
	trunks.material_override = ExpeditionArt.material("wood",Color("514d41"))
	var crowns: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in transforms.size():
		crowns.append(transforms[i]*Transform3D(Basis(Vector3.UP,i*.63),Vector3.ZERO))
		colors.append(Color("b6bc9f").lerp(Color("d3ddc4"),float(i%7)/6.0))
	var canopy := Geometry.instances(parent,crown(),crowns,colors)
	canopy.name = "LayeredForestCanopy"
	canopy.material_override = foliage_material(Color("586d53"))

static func understory(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 938521
	var plants: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 750:
		var x := rng.randf_range(-39,39)
		var z := rng.randf_range(-42,8)
		# Keep the whole quest arena and construction/escort paths legible.
		if absf(x) < (12.0 if z < -10 else 7.0): continue
		var size := rng.randf_range(.65,1.30)
		plants.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),RegionLayout.on_ground(RegionLayout.FOREST,Vector3(x,0,z))))
		colors.append(Color("9fae76").lerp(Color("c1cba4"),rng.randf()))
	var ferns := Geometry.instances(parent,fern(),plants,colors)
	ferns.name = "ForestFerns"
	ferns.material_override = foliage_material(Color("6e8652"))
	ferns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Fallen branches lie beyond the walkable arena edge, not across quest routes.
	var b := CampArt.Sculpt.new()
	for side in [-1,1]:
		for i in 4:
			var at := Vector3(side*(13.2+i*.6),.18,-8-i*7)
			var end := at+Vector3(side*2.3,.03,-1.7)
			b.beam("wood",at,end,.21,.14)
			b.beam("wood",at.lerp(end,.4),at+Vector3(side*1.3,.7,-1.8),.09,.015)
	var deadwood := Geometry.mesh(parent,b.finish(),Vector3.ZERO,Color.WHITE)
	deadwood.name = "FallenBranches"
	deadwood.material_override = ExpeditionArt.material("wood",Color("514b3d"))
