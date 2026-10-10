class_name RuinArt
extends RefCounted
## Original masonry and overgrowth, in metres. The arena keeps its existing footprint.
## Architecture has exact mesh collision; the flat paving and small debris are visual.

static var cached_materials: Dictionary = {}

static func materials() -> Dictionary:
	if not cached_materials.is_empty(): return cached_materials
	for entry in [["stone",Color("7d8983"),.55],["trim",Color("9a9d8d"),.24],["dark",Color("454f4b"),.18]]:
		var stone := ShaderMaterial.new()
		stone.shader = load("res://assets/shaders/ruin_stone.gdshader")
		stone.set_shader_parameter("tint",entry[1])
		stone.set_shader_parameter("moss",entry[2])
		cached_materials[entry[0]] = stone
	cached_materials["root"] = ExpeditionArt.material("wood",Color("49443a"))
	cached_materials["moss"] = ExpeditionArt.material("stone",Color("455a37"))
	var rune := Geometry.material(Color("91b5a6"),.24)
	rune.roughness = .7
	cached_materials["rune"] = rune
	return cached_materials

static func _mesh(parent: Node3D, name: String, sculpt: CampArt.Sculpt, collision: bool = false) -> MeshInstance3D:
	var item := Geometry.mesh(parent,sculpt.finish(materials()),Vector3.ZERO,Color.WHITE)
	item.name = name
	item.material_override = null
	if collision: item.create_trimesh_collision()
	return item

static func block(b: CampArt.Sculpt, at: Vector3, size: Vector3, seed_value: int = 0, kind: String = "stone", frame: Basis = Basis.IDENTITY) -> void:
	# Chamfered, slightly uneven edges read as dressed stone instead of voxel cubes.
	var bevel := minf(minf(size.x,size.z)*.11,size.y*.2)
	var rings: Array = []
	for row in 4:
		var edge := row == 0 or row == 3
		var hx := size.x*.5-(bevel*.6 if edge else 0.0)
		var hz := size.z*.5-(bevel*.6 if edge else 0.0)
		var y: float = [-size.y*.5,-size.y*.5+bevel,size.y*.5-bevel,size.y*.5][row]
		var points: Array[Vector3] = []
		var outline := [Vector2(hx-bevel,hz),Vector2(hx,hz-bevel),Vector2(hx,-hz+bevel),Vector2(hx-bevel,-hz),Vector2(-hx+bevel,-hz),Vector2(-hx,-hz+bevel),Vector2(-hx,hz-bevel),Vector2(-hx+bevel,hz)]
		for i in 8:
			var chip := 1.0-.023*(sin(seed_value*1.8+i*3.7)+1.0)
			points.append(at+frame*Vector3(outline[i].x*chip,y,outline[i].y*chip))
		rings.append(points)
		if row > 0:
			for i in 8: b.quad(kind,rings[row-1][i],rings[row-1][(i+1)%8],points[(i+1)%8],points[i],.92+(seed_value%7)*.018)
	for i in range(1,7):
		ExpeditionArt._triangle(b.surface(kind),rings[3][0],rings[3][i],rings[3][i+1])
		ExpeditionArt._triangle(b.surface(kind),rings[0][0],rings[0][i+1],rings[0][i])

static func _arch(b: CampArt.Sculpt, center: Vector3, rx: float, ry: float, thickness: float, depth: float, count: int = 19) -> void:
	for i in count:
		var a := float(i)*PI/count+.009
		var c := float(i+1)*PI/count-.009
		var points: Array[Vector3] = []
		for z in [depth*.5,-depth*.5]:
			for spec in [[a,rx+thickness,ry+thickness],[c,rx+thickness,ry+thickness],[c,rx,ry],[a,rx,ry]]:
				points.append(center+Vector3(cos(spec[0])*spec[1],sin(spec[0])*spec[2],z))
		var shade := .89+float(i%5)*.034
		for face in [[0,1,2,3],[7,6,5,4],[4,5,1,0],[3,2,6,7],[4,0,3,7],[1,5,6,2]]:
			b.quad("trim",points[face[0]],points[face[1]],points[face[2]],points[face[3]],shade)

static func _rune(b: CampArt.Sculpt, at: Vector3, size: float) -> void:
	var p := [Vector3(0,size,0),Vector3(size*.65,0,0),Vector3(0,-size,0),Vector3(-size*.65,0,0)]
	for i in 4: b.beam("rune",at+p[i],at+p[(i+1)%4],.018)
	b.beam("rune",at+Vector3(0,-size*1.25,0),at+Vector3(0,size*1.25,0),.015)

static func _pier(b: CampArt.Sculpt, at: Vector3, height: float, seed_value: int) -> void:
	block(b,at+Vector3(0,.17,0),Vector3(2.0,.34,2.1),seed_value,"trim")
	var courses := int((height-.7)/.65)
	for j in courses:
		block(b,at+Vector3(0,.35+(j+.5)*.65,0),Vector3(1.55,.63,1.62),seed_value+j)
		if j > 1 and j % 2 == 0: _rune(b,at+Vector3(0,.35+(j+.5)*.65,.825),.20)
	block(b,at+Vector3(0,height-.18,0),Vector3(1.96,.32,2.04),seed_value,"trim")
	# Slender relief ridges catch the warm entrance light.
	for x in [-.62,.62]: block(b,at+Vector3(x,height*.48,.83),Vector3(.11,height*.65,.10),seed_value,"trim")

static func navigation_footprints() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for side in [-1,1]:
		result.append(Rect2(Vector2(side*9.5-.73,-30.6),Vector2(1.46,17.2)).grow(.5))
		for z in [-29,-23,-17]: result.append(Rect2(Vector2(side*9.5-1.0,z-1.05),Vector2(2,2.1)).grow(.5))
		result.append(Rect2(Vector2(side*5.7-1.0,-12.05),Vector2(2,2.1)).grow(.5))
	result.append(Rect2(-10.1,-31.72,20.2,1.44).grow(.5))
	return result

static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "StarfallRuins"
	parent.add_child(root)
	var masonry := CampArt.Sculpt.new()
	for side in [-1,1]:
		_pier(masonry,Vector3(side*5.7,0,-11),3.66,3+side)
		# The wall has an unbroken low course and a broken upper silhouette.
		for row in 4:
			for i in 11:
				if row == 3 and (i+side+11)%4 != 0: continue
				var z := -14.1-i*1.5
				block(masonry,Vector3(side*9.5,.29+row*.57,z),Vector3(1.32,.55,1.48),i+row*3+side)
		for i in 3: _pier(masonry,Vector3(side*9.5,0,-17-i*6),3.1+float(i%2)*.65,9+i)
		# Exterior buttresses and rubble stay outside the combat/worker floor.
		for z in [-16,-24,-29]:
			block(masonry,Vector3(side*10.3,.64,z),Vector3(.85,1.28,1.5),int(abs(z)))
	for row in 5:
		for i in 13:
			block(masonry,Vector3((i-6)*1.53,.30+row*.59,-31),Vector3(1.51,.57,1.42),row*5+i)
	_pier(masonry,Vector3(-4.0,0,-31.1),3.1,5)
	_pier(masonry,Vector3(4.0,0,-31.1),3.1,7)
	_arch(masonry,Vector3(0,3.1,-31.1),3.15,3.25,.72,1.25,17)
	# The sealed descent sits behind the existing arena boundary.
	for panel in 12:
		var a := -3.15+panel*.525
		var c := a+.525
		var ah := 3.1+3.25*sqrt(maxf(0,1.0-pow(a/3.15,2)))
		var ch := 3.1+3.25*sqrt(maxf(0,1.0-pow(c/3.15,2)))
		masonry.quad("dark",Vector3(a,.1,-30.92),Vector3(c,.1,-30.92),Vector3(c,ch,-30.92),Vector3(a,ah,-30.92))
	for x in [-2.0,0.0,2.0]: block(masonry,Vector3(x,3.1,-31.05),Vector3(.06,5.4,.05),19,"trim")
	_mesh(root,"WeatheredMasonry",masonry,true)
	var arch := CampArt.Sculpt.new()
	_arch(arch,Vector3(0,3.42,-11),4.88,3.75,1.05,1.76)
	block(arch,Vector3(0,7.43,-9.98),Vector3(.8,1.05,.32),3,"stone")
	_rune(arch,Vector3(0,7.48,-9.8),.31)
	_mesh(root,"EntranceArch",arch,true)
	var overgrowth := CampArt.Sculpt.new()
	for side in [-1,1]:
		for j in 5:
			var z := -14.8-j*3.15
			var a := Vector3(side*(9.6+sin(j)*.35),2.4,z)
			var mid := Vector3(side*8.9,1.1,z+1.0)
			var end := Vector3(side*8.45,.07,z+2.0)
			overgrowth.beam("root",a,mid,.11,.075)
			overgrowth.beam("root",mid,end,.075,.019)
			for i in 4:
				block(overgrowth,a.lerp(mid,i/4.0)+Vector3(0,.03,.08),Vector3(.32,.07,.48),j+i,"moss",Basis(Vector3.UP,j*.63))
	_mesh(root,"RootsAndMoss",overgrowth)
	_paving(root)
	var caption := Geometry.label(root,"별잠회랑 · 상층 관문",8.65,Color("dfdac3"))
	caption.position.z = -11
	caption.font_size = 29
	caption.visibility_range_end = 25
	caption.no_depth_test = false
	return root

static func _paving(parent: Node3D) -> void:
	var b := CampArt.Sculpt.new()
	for row in 26:
		var z := 4.0-row*1.29
		var width := 2 if z > -10 else 6
		for col in range(-width,width+1):
			if (row*7+col+200)%11 in [0,3]: continue
			var x := col*1.28+(.59 if row%2 else -.04)
			var offset := sin(row*4.1+col*7.3)*.04
			var y := .007+absf(offset)*.16
			block(b,Vector3(x,y,z+offset),Vector3(1.18+offset,.028,1.17-offset),row*3+col+90,"stone",Basis(Vector3.UP,sin(row+col*3)*.038))
			if (row+col+100)%4 == 0:
				b.beam("dark",Vector3(x-.52,.026,z+.25),Vector3(x-.17,.027,z+.38),.007)
				b.beam("dark",Vector3(x-.17,.027,z+.38),Vector3(x-.02,.027,z+.58),.006)
	_mesh(parent,"SunkenFlagstones",b)
	var rubble := CampArt.Sculpt.new()
	for side in [-1,1]:
		for i in 16:
			var at := Vector3(side*(10.9+absf(sin(i*2.3))*1.3),.10,-12-i*1.12)
			block(rubble,at,Vector3(.4+(i%3)*.12,.24,.48),i,"stone",Basis(Vector3.UP,i*.9))
	_mesh(parent,"FallenAshlar",rubble)

static func lectern(parent: Node3D) -> void:
	var b := CampArt.Sculpt.new()
	block(b,Vector3(0,.12,0),Vector3(1.3,.24,.95),3,"trim")
	b.lathe("stone",Vector3.ZERO,[Vector2(.45,.23),Vector2(.32,.32),Vector2(.27,.65),Vector2(.40,.76)],Basis.IDENTITY,8)
	block(b,Vector3(0,.82,0),Vector3(1.12,.18,.78),9,"trim",Basis(Vector3.RIGHT,.22))
	for i in 4:
		b.box("dark",Vector3(0,.936+i*.022,-.20+i*.11),Vector3(.76-(i%3)*.10,.012,.022))
	_mesh(parent,"CarvedRecordStone",b)

static func crystal_cluster(parent: Node3D, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "MineralOutcrop"
	root.position = at
	parent.add_child(root)
	var b := CampArt.Sculpt.new()
	block(b,Vector3(0,.08,0),Vector3(1.50,.23,1.26),4,"dark")
	for i in 5:
		var center := Vector3(sin(i*2.4)*.4,.11,cos(i*2.4)*.34)
		var height := .57+(i%3)*.22
		b.lathe("rune",center,[Vector2(.17,0),Vector2(.19,height*.52),Vector2(.13,height*.75),Vector2(.005,height)],Basis(Vector3.FORWARD,(i-2)*.13),5)
	_mesh(root,"FacetedShards",b)
