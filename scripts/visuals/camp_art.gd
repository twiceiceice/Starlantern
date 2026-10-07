class_name CampArt
extends RefCounted
## Original near-field camp models, baked into a handful of material surfaces.
## Shared by saved region scenes, construction stages and the MultiMesh caravan.

const WORKSHOP := Vector3(-5.8, 0, -12.4)
const KITCHEN := Vector3(6.0, 0, -12.4)
const BASE_WORKSHOP := Vector3(-6.2, 0, -10.5)
const BASE_KITCHEN := Vector3(6.3, 0, -10.0)
const PALETTE := {
	"wood": Color("786049"), "cutwood": Color("aa8c62"), "darkwood": Color("514437"),
	"canvas": Color("b7a98b"), "bluecloth": Color("506d76"), "greencloth": Color("78806b"),
	"leather": Color("73503a"), "rope": Color("b8a783"), "iron": Color("393e3d"),
	"steel": Color("939992"), "clay": Color("98705a"), "stone": Color("6b6e60"),
	"coal": Color("332c29"), "ember": Color("cc663a"), "paper": Color("c7b794"),
	"food": Color("79804a"), "stew": Color("856444"), "light": Color("e8bb70")}
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

class Sculpt:
	extends RefCounted
	var surfaces := {}
	func surface(kind: String) -> SurfaceTool:
		if not surfaces.has(kind):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[kind] = s
		return surfaces[kind]
	func quad(kind: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, shade: float = 1) -> void:
		ExpeditionArt._quad(surface(kind), a, b, c, d, Color(shade, shade, shade))
	func box(kind: String, at: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
		var p: Array[Vector3] = []
		for v: Vector3 in [Vector3(-1,-1,-1), Vector3(1,-1,-1), Vector3(1,1,-1), Vector3(-1,1,-1), Vector3(-1,-1,1), Vector3(1,-1,1), Vector3(1,1,1), Vector3(-1,1,1)]:
			p.append(at + basis * (v * size * .5))
		for face in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[0,1,5,4],[3,7,6,2]]:
			quad(kind, p[face[0]], p[face[1]], p[face[2]], p[face[3]])
	func beam(kind: String, a: Vector3, b: Vector3, radius: float, end_radius: float = -1) -> void:
		var up := (b - a).normalized()
		var right := up.cross(Vector3.BACK if absf(up.y) > .9 else Vector3.UP).normalized()
		var basis := Basis(right, up, right.cross(up))
		lathe(kind, a, [Vector2(radius,0),Vector2(radius if end_radius < 0 else end_radius,a.distance_to(b))], basis, 10)
	func lathe(kind: String, at: Vector3, rows: Array, basis: Basis = Basis.IDENTITY, count: int = 20, caps: bool = true) -> void:
		for r in range(rows.size() - 1):
			for i in count:
				var a := float(i) * TAU / count
				var b := float(i + 1) * TAU / count
				var low: Vector2 = rows[r]
				var high: Vector2 = rows[r + 1]
				quad(kind, at + basis * Vector3(sin(a)*low.x,low.y,cos(a)*low.x), at + basis * Vector3(sin(b)*low.x,low.y,cos(b)*low.x), at + basis * Vector3(sin(b)*high.x,high.y,cos(b)*high.x), at + basis * Vector3(sin(a)*high.x,high.y,cos(a)*high.x), .93 + float(i % 4) * .022)
		if caps:
			for end in [0, rows.size() - 1]:
				var row: Vector2 = rows[end]
				for i in count:
					var a := float(i) * TAU / count
					var b := float(i + 1) * TAU / count
					var first := at + basis * Vector3(sin(a)*row.x,row.y,cos(a)*row.x)
					var second := at + basis * Vector3(sin(b)*row.x,row.y,cos(b)*row.x)
					ExpeditionArt._triangle(surface(kind), at + basis * Vector3(0,row.y,0), second if end == 0 else first, first if end == 0 else second)
	func ring(kind: String, at: Vector3, radius: float, thickness: float, basis: Basis = Basis.IDENTITY) -> void:
		for i in 24:
			for j in 6:
				var p: Array[Vector3] = []
				for ij: Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
					var a := ij.x * TAU / 24
					var b := ij.y * TAU / 6
					p.append(at + basis * Vector3(sin(a)*(radius+cos(b)*thickness),sin(b)*thickness,cos(a)*(radius+cos(b)*thickness)))
				quad(kind,p[0],p[1],p[2],p[3])
	func finish() -> ArrayMesh:
		var result := ArrayMesh.new()
		for kind: String in surfaces:
			surfaces[kind].set_material(CampArt.surface_material(kind))
			surfaces[kind].commit(result)
		return result

static func surface_material(kind: String) -> Material:
	if materials.has(kind): return materials[kind]
	var tint: Color = PALETTE[kind]
	var result: Material
	if kind in ["iron", "steel", "light", "ember"]:
		var metal := Geometry.material(tint, .65 if kind == "light" else (.45 if kind == "ember" else 0.0))
		metal.vertex_color_use_as_albedo = true
		metal.metallic = .55 if kind in ["iron", "steel"] else 0
		metal.roughness = .68
		result = metal
	else:
		var grain := "wood" if kind in ["wood", "cutwood", "darkwood"] else ("canvas" if kind.ends_with("cloth") or kind == "canvas" else "stone")
		result = ExpeditionArt.material(grain, tint)
	materials[kind] = result
	return result

static func _sack(b: Sculpt, at: Vector3, scale_value: float = 1, kind: String = "canvas") -> void:
	var frame := Basis().scaled(Vector3(scale_value, scale_value, scale_value*.8))
	b.lathe(kind, at, [Vector2(.18,0),Vector2(.27,.1),Vector2(.3,.33),Vector2(.255,.52),Vector2(.1,.65),Vector2(.07,.73),Vector2(.10,.79)], frame, 16)
	b.ring("rope", at + Vector3(0,.68*scale_value,0), .079*scale_value, .016*scale_value)
	b.beam("rope",at+Vector3(.09,.68,.02)*scale_value,at+Vector3(.19,.43,.15)*scale_value,.012*scale_value)

static func _barrel(b: Sculpt, at: Vector3, scale_value: float = 1) -> void:
	var basis := Basis().scaled(Vector3.ONE * scale_value)
	b.lathe("wood",at,[Vector2(.31,0),Vector2(.36,.1),Vector2(.39,.43),Vector2(.36,.79),Vector2(.31,.87)],basis,16)
	for y in [.09,.27,.63,.80]:
		var radius := .35 if y < .15 or y > .75 else .382
		b.lathe("iron",at,[Vector2(radius,y),Vector2(radius+.008,y+.043)],basis,16,false)
	for i in range(-2,3):
		var x := i * .113
		b.box("cutwood",at+Vector3(x,.877,0)*scale_value,Vector3(.104,.025,2*sqrt(.30*.30-x*x))*scale_value)
	b.lathe("darkwood",at+Vector3(.14,.894,0)*scale_value,[Vector2(.031,0),Vector2(.032,.02)],basis,10)

static func _roll(b: Sculpt, at: Vector3, length: float = .8, kind: String = "bluecloth") -> void:
	var basis := Basis(Vector3.BACK, -PI / 2)
	b.lathe(kind,at,[Vector2(.17,-length*.5),Vector2(.205,-length*.43),Vector2(.205,length*.43),Vector2(.17,length*.5)],basis)
	for x in [-length*.28,length*.28]:
		b.ring("leather",at+Vector3(x,0,0),.208,.025,basis)
	for x in [-length*.505,length*.505]:
		for r in [.07,.125,.175]: b.ring(kind,at+Vector3(x,0,0),r,.009,basis)

static func _crate(b: Sculpt, at: Vector3, size: Vector3 = Vector3(.85,.7,.8)) -> void:
	for side in [-1,1]:
		for i in 4:
			var y := (i+.5)*size.y/4
			b.box("wood",at+Vector3(0,y,side*size.z*.5),Vector3(size.x,.94*size.y/4,.045))
			b.box("wood",at+Vector3(side*size.x*.5,y,0),Vector3(.045,.94*size.y/4,size.z))
		for x in [-size.x*.36,size.x*.36]:
			b.box("iron",at+Vector3(x,size.y*.5,side*(size.z*.5+.025)),Vector3(.038,size.y+.025,.014))
	for i in 5:
		b.box("cutwood",at+Vector3((i-2)*size.x/5,size.y,0),Vector3(size.x*.19,.04,size.z))

static func _table(b: Sculpt, at: Vector3, width: float = 2.7, height: float = .86, depth: float = .9) -> void:
	for i in 5:
		b.box("wood",at+Vector3(0,height,(i-2)*depth/5),Vector3(width,.085,depth*.19))
	for side in [-1,1]:
		for z in [-depth*.36,depth*.36]:
			b.beam("darkwood",at+Vector3(side*width*.37,.04,z*1.2),at+Vector3(side*width*.34,height-.02,z),.063)
		b.box("cutwood",at+Vector3(side*width*.35,height-.14,0),Vector3(.095,.10,depth*1.05))
	b.box("darkwood",at+Vector3(0,.24,0),Vector3(width*.72,.09,.09))

static func _awning(b: Sculpt, tint: String) -> void:
	for x in [-2.05,2.05]:
		for z in [-1.35,1.25]:
			var top := 2.25 if z > 0 else 2.6
			b.beam("wood",Vector3(x,0,z),Vector3(x,top+.15,z),.052,.036)
			b.beam("rope",Vector3(x,top,z),Vector3(x*1.1,.06,z*1.2),.012)
			b.beam("darkwood",Vector3(x*1.1,0,z*1.2),Vector3(x*1.1,.22,z*1.2),.032)
	for i in 8:
		for j in 5:
			var p: Array[Vector3] = []
			for cell: Vector2i in [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1),Vector2i(i+1,j)]:
				var u := cell.x / 8.0
				var v := cell.y / 5.0
				p.append(Vector3(lerpf(-2.12,2.12,u),lerpf(2.60,2.25,v)-sin(u*PI)*sin(v*PI)*.23,lerpf(-1.42,1.32,v)))
			b.quad(tint,p[0],p[1],p[2],p[3],.92+float(i%3)*.025)
	# Stitched valance and narrow reinforcing strips across the cloth.
	for i in 8:
		var x := -2.12+i*.53
		b.quad(tint,Vector3(x,2.25,1.32),Vector3(x,2.06+(i%2)*.035,1.34),Vector3(x+.53,2.06+((i+1)%2)*.035,1.34),Vector3(x+.53,2.25,1.32))
	for x in [-2.05,0.0,2.05]:
		b.beam("rope",Vector3(x,2.6,-1.42),Vector3(x,2.25,1.32),.009)

static func _lantern(b: Sculpt, at: Vector3) -> void:
	b.box("light",at+Vector3(0,.15,0),Vector3(.14,.26,.14))
	for y in [0.0,.30]: b.box("iron",at+Vector3(0,y,0),Vector3(.22,.045,.22))
	for x in [-.08,.08]:
		for z in [-.08,.08]: b.beam("iron",at+Vector3(x,0,z),at+Vector3(x,.31,z),.012)
	b.lathe("iron",at,[Vector2(.14,.32),Vector2(.05,.41)],Basis.IDENTITY,8)
	b.ring("iron",at+Vector3(0,.46,0),.065,.012,Basis(Vector3.RIGHT,PI/2))

static func _hearth(b: Sculpt, at: Vector3) -> void:
	b.lathe("coal",at,[Vector2(.66,.018),Vector2(.62,.07)],Basis.IDENTITY,20)
	for i in 11:
		var a := i * TAU / 11
		var spot := at+Vector3(sin(a)*.71,.11,cos(a)*.71)
		b.lathe("stone",spot,[Vector2(.13,-.1),Vector2(.19,0),Vector2(.16,.14),Vector2(.08,.18)],Basis(Vector3.UP,a).scaled(Vector3(1.1,1,.85)),7)
	for i in 3:
		var v := Vector3(cos(i*PI/3),0,sin(i*PI/3))*.54
		b.beam("darkwood",at-v+Vector3.UP*(.12+i*.025),at+v+Vector3.UP*(.12+i*.025),.10)
	for i in 9:
		var a := i*2.399
		b.lathe("ember",at+Vector3(sin(a)*.28,.18,cos(a)*.28),[Vector2(.06,0),Vector2(.045,.04)],Basis.IDENTITY,7)

static func _pot(b: Sculpt, at: Vector3, radius: float = .38) -> void:
	b.lathe("iron",at,[Vector2(radius*.6,0),Vector2(radius*.94,.08),Vector2(radius,.29),Vector2(radius*.90,.45),Vector2(radius*.76,.48),Vector2(radius*.76,.43)],Basis.IDENTITY,24,false)
	b.ring("iron",at+Vector3(0,.475,0),radius*.80,.029)
	b.lathe("stew",at,[Vector2(radius*.76,.415),Vector2(radius*.76,.419)],Basis.IDENTITY,20)
	for s in [-1,1]: b.ring("iron",at+Vector3(s*radius,.33,0),.09,.02,Basis(Vector3.RIGHT,PI/2))

static func station_mesh(kind: String) -> ArrayMesh:
	if meshes.has(kind): return meshes[kind]
	var b := Sculpt.new()
	if kind == "workshop":
		_awning(b,"bluecloth")
		_table(b,Vector3(0,0,-.45))
		# A clamped repair plank, mallet, saw and bench plane.
		b.box("cutwood",Vector3(.12,.94,-.3),Vector3(1.8,.075,.29),Basis(Vector3.UP,.075))
		for x in [-.65,.75]:
			b.box("iron",Vector3(x,.91,-.11),Vector3(.09,.22,.08))
			b.beam("iron",Vector3(x,.70,-.11),Vector3(x,.66,.10),.016)
		b.beam("wood",Vector3(.35,1.015,-.33),Vector3(.65,1.015,-.65),.022)
		b.box("darkwood",Vector3(.36,1.015,-.34),Vector3(.20,.1,.11),Basis(Vector3.UP,.4))
		b.box("steel",Vector3(-.58,.94,-.71),Vector3(.54,.016,.13),Basis(Vector3.UP,-.25))
		b.ring("wood",Vector3(-.87,.955,-.64),.075,.025)
		b.box("darkwood",Vector3(.86,.97,-.68),Vector3(.23,.10,.12))
		b.box("steel",Vector3(.86,1.02,-.68),Vector3(.035,.04,.12),Basis(Vector3.RIGHT,.35))
		# Sawhorses and stacked cut timber stay to the side of the working aisle.
		for z in [.2,1.0]:
			for x in [-1.95,-1.35]: b.beam("wood",Vector3(x,0,z),Vector3(-1.65,.56,z),.047)
			b.box("cutwood",Vector3(-1.65,.57,z),Vector3(.85,.08,.13))
		for i in 4:
			b.box("cutwood",Vector3(-1.70+(i%2)*.22,.65+(i/2)*.105,.57),Vector3(.18,.09,1.65),Basis(Vector3.UP,.025*i))
		for r in [.37,.47]: b.ring("wood",Vector3(1.76,.50,-.60),r,.038,Basis(Vector3.RIGHT,PI/2))
		for i in 8:
			var v := Vector3(sin(i*TAU/8),cos(i*TAU/8),0)*.44
			b.beam("cutwood",Vector3(1.76,.50,-.60),Vector3(1.76,.50,-.60)+v,.024)
		_crate(b,Vector3(.7,0,-1.16),Vector3(.6,.44,.5))
		_lantern(b,Vector3(1.17,.905,-.34))
	elif kind == "kitchen":
		_awning(b,"greencloth")
		_table(b,Vector3(.3,0,-.64),2.9,.86,.75)
		_hearth(b,Vector3(-.65,0,.64))
		_pot(b,Vector3(-.65,.40,.64))
		for i in 3:
			var a := i*TAU/3+.3
			b.beam("iron",Vector3(-.65+cos(a)*.65,.04,.64+sin(a)*.65),Vector3(-.65,1.73,.64),.025)
		b.beam("iron",Vector3(-.65,1.65,.64),Vector3(-.65,.86,.64),.012)
		b.box("cutwood",Vector3(-.38,.93,-.54),Vector3(.68,.05,.43),Basis(Vector3.UP,-.12))
		b.box("steel",Vector3(-.38,.967,-.5),Vector3(.23,.009,.042),Basis(Vector3.UP,.3))
		b.box("darkwood",Vector3(-.21,.967,-.55),Vector3(.12,.035,.035),Basis(Vector3.UP,.3))
		for x in [.28,.62,.98]:
			b.lathe("clay",Vector3(x,.907,-.67),[Vector2(.065,0),Vector2(.105,.10),Vector2(.11,.13),Vector2(.095,.135),Vector2(.06,.03)],Basis.IDENTITY,16,false)
		_barrel(b,Vector3(1.57,0,.64),.88)
		_sack(b,Vector3(.9,0,.55),.9)
		_sack(b,Vector3(1.26,0,-1.17),.75,"greencloth")
		for i in 7:
			b.beam("darkwood",Vector3(1.75+(i%2)*.1,.10+(i/2)*.095,-.55),Vector3(1.75+(i%2)*.1,.10+(i/2)*.095,.02),.066)
		_lantern(b,Vector3(-1.04,.90,-.82))
	elif kind == "hearth":
		_hearth(b,Vector3.ZERO)
		for side in [-1,1]: _table(b,Vector3(side*1.75,0,0),.60,.43,1.8)
	elif kind == "cargo":
		_crate(b,Vector3(-.38,0,-.22))
		_crate(b,Vector3(.47,0,-.18),Vector3(.65,.48,.7))
		_roll(b,Vector3(-.03,.92,.16),.88)
		_sack(b,Vector3(.95,0,.36),.95)
		_sack(b,Vector3(.58,.50,-.18),.75,"greencloth")
		_barrel(b,Vector3(-.99,0,.18),.8)
		for i in 3: b.ring("rope",Vector3(.58,.045+i*.021,.86),.16-i*.015,.014)
	elif kind == "single_crate":
		_crate(b,Vector3.ZERO,Vector3(.95,1,.95))
	elif kind == "pannier":
		b.lathe("canvas",Vector3.ZERO,[Vector2(.27,-.31),Vector2(.35,-.24),Vector2(.37,.09),Vector2(.33,.26),Vector2(.28,.30)],Basis().scaled(Vector3(.58,1,1.12)),16)
		for x in [-.12,.12]:
			b.box("leather",Vector3(x,.293,0),Vector3(.035,.018,.70))
			for z in [-.37,.37]:
				b.box("leather",Vector3(x,-.01,z),Vector3(.035,.46,.017))
				b.box("iron",Vector3(x,.075,z*1.025),Vector3(.065,.07,.013))
	elif kind == "bedroll":
		_roll(b,Vector3.ZERO,1.2)
	elif kind == "dispatch":
		_table(b,Vector3.ZERO,1.8,.86,.75)
		b.box("paper",Vector3(-.28,.913,0),Vector3(.67,.01,.47),Basis(Vector3.UP,.13))
		for i in 4:
			b.beam("darkwood",Vector3(-.5+i*.12,.924,-.1+sin(i)*.06),Vector3(-.38+i*.12,.924,-.1+sin(i+1)*.06),.008)
		b.box("leather",Vector3(.38,.94,-.01),Vector3(.30,.06,.34),Basis(Vector3.UP,-.15))
		b.box("paper",Vector3(.38,.98,-.01),Vector3(.27,.012,.31),Basis(Vector3.UP,-.15))
		b.lathe("iron",Vector3(.03,.909,-.2),[Vector2(.04,0),Vector2(.044,.06),Vector2(.025,.08)],Basis.IDENTITY,12)
		b.beam("cutwood",Vector3(.03,.98,-.2),Vector3(.16,1.2,-.25),.007)
		_lantern(b,Vector3(.73,.91,-.20))
		_sack(b,Vector3(-.40,0,0),.72)
		_roll(b,Vector3(.35,.30,0),.64,"greencloth")
	elif kind == "wagon_trim":
		# Positions are relative to the caravan body's pivot, 0.85m above ground.
		for z in [-.8,.8]:
			b.beam("iron",Vector3(-.91,-.43,z),Vector3(.91,-.43,z),.055)
			for side in [-1,1]: b.ring("iron",Vector3(side*.82,-.43,z),.415,.022,Basis(Vector3.BACK,PI/2))
		for side in [-1,1]:
			for z in [-1.12,0,1.12]:
				b.box("iron",Vector3(side*.79,.01,z),Vector3(.022,.64,.066))
				for y in [-.24,.22]: b.lathe("steel",Vector3(side*.81,y,z),[Vector2(.025,0),Vector2(.025,.013)],Basis(Vector3.BACK,side*PI/2),8)
			b.beam("darkwood",Vector3(side*.52,-.22,-1.1),Vector3(side*.43,-.36,-3.03),.043)
			for z in [-1.12,0,1.12]:
				for i in 14:
					var a := i*PI/14
					var c := (i+1)*PI/14
					if side == 1: b.beam("cutwood",Vector3(cos(a)*.805,.45+sin(a)*.805,z),Vector3(cos(c)*.805,.45+sin(c)*.805,z),.012)
			b.beam("rope",Vector3(side*.80,.44,-1.12),Vector3(side*.79,-.22,1.10),.012)
	elif kind == "wagon_load":
		_crate(b,Vector3(-.31,-.27,-.42),Vector3(.62,.42,.60))
		_sack(b,Vector3(.40,-.27,.05),.86)
		_sack(b,Vector3(-.30,-.27,.72),.8,"greencloth")
		_roll(b,Vector3(.01,.20,-.32),.8)
		b.box("leather",Vector3(.32,-.01,.70),Vector3(.42,.32,.42))
		for x in [.2,.43]: b.box("rope",Vector3(x,.16,.70),Vector3(.025,.014,.44))
	meshes[kind] = b.finish()
	return meshes[kind]

static func collider_specs(kind: String) -> Array:
	if kind in ["workshop", "kitchen"]:
		var specs := [[Vector3(0,.45,-.53),Vector3(2.9,.90,1.05)]]
		specs.append([Vector3(0,2.43,-.05),Vector3(4.3,.14,2.78)])
		for x in [-2.05,2.05]:
			for z in [-1.35,1.25]: specs.append([Vector3(x,1.2,z),Vector3(.16,2.4,.16)])
		if kind == "workshop":
			specs.append([Vector3(-1.65,.38,.58),Vector3(.88,.76,1.8)])
			specs.append([Vector3(1.76,.52,-.60),Vector3(1.02,1.04,.14)])
		else:
			specs.append([Vector3(1.5,.4,.60),Vector3(.75,.8,.85)])
			specs.append([Vector3(-.65,.45,.64),Vector3(1.35,.90,1.35)])
		return specs
	if kind == "wagon": return [[Vector3(0,.8,0),Vector3(1.86,1.6,2.55)]]
	if kind == "cargo": return [[Vector3(-.04,.5,.25),Vector3(2.5,1,1.5)]]
	if kind == "single_crate": return [[Vector3(0,.5,0),Vector3(.99,1.04,.99)]]
	if kind == "dispatch": return [[Vector3(0,.45,0),Vector3(1.82,.91,.78)]]
	if kind == "hearth": return [[Vector3(0,.18,0),Vector3(1.38,.36,1.38)], [Vector3(-1.75,.22,0),Vector3(.65,.44,1.85)], [Vector3(1.75,.22,0),Vector3(.65,.44,1.85)]]
	return []

static func footprints(kind: String, at: Vector3) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for spec in collider_specs(kind):
		var point: Vector3 = at + spec[0]
		var size: Vector3 = spec[1]
		# Canopy ceilings stop the camera but leave headroom for walking below.
		if spec[0].y - size.y*.5 > 1.9: continue
		result.append(Rect2(Vector2(point.x-size.x*.5,point.z-size.z*.5),Vector2(size.x,size.z)).grow(.45))
	return result

static func place(parent: Node3D, kind: String, at: Vector3, solid: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Camp" + kind.capitalize()
	root.position = at
	parent.add_child(root)
	if kind == "wagon":
		var body := Geometry.mesh(root,ExpeditionArt.wagon_mesh(),Vector3(0,.85,0),Color.WHITE)
		body.material_override = ExpeditionArt.material("wood",Color("896e4f"))
		var cover := Geometry.mesh(root,ExpeditionArt.wagon_cover(),Vector3(0,1.3,0),Color.WHITE)
		cover.rotation.x = PI/2
		cover.material_override = ExpeditionArt.material("canvas",Color("bcb198"))
		for x in [-.82,.82]:
			for z in [-.8,.8]:
				var wheel := Geometry.mesh(root,ExpeditionArt.wheel_mesh(),Vector3(x,.42,z),Color.WHITE)
				wheel.rotation.z = PI/2
				wheel.material_override = ExpeditionArt.material("wood",Color("5f4b38"))
		for detail in ["wagon_trim", "wagon_load"]:
			var mesh := Geometry.mesh(root,station_mesh(detail),Vector3(0,.85,0),Color.WHITE)
			mesh.material_override = null
	else:
		var mesh := Geometry.mesh(root,station_mesh(kind),Vector3.ZERO,Color.WHITE)
		mesh.material_override = null
	if solid:
		for spec in collider_specs(kind):
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = spec[1]
			collider.shape = box
			collider.position = spec[0]
			body.add_child(collider)
			root.add_child(body)
	if kind in ["hearth", "kitchen"]:
		_fire(root, Vector3(-.65,0,.64) if kind == "kitchen" else Vector3.ZERO, kind == "kitchen")
	if kind in ["workshop", "kitchen"]:
		var label := Geometry.label(root,"목공 작업소" if kind == "workshop" else "원정 취사장",2.92,Color("cfc3a0"))
		label.font_size = 24
		label.visibility_range_end = 14
		label.no_depth_test = false
	return root

static func _fire(parent: Node3D, at: Vector3, under_pot: bool = false) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(.68,.60) if under_pot else Vector2(.85,1.0)
	var fire_material := ShaderMaterial.new()
	fire_material.shader = load("res://assets/shaders/camp_fire.gdshader")
	for angle in [0,PI/3,2*PI/3]:
		var flame := Geometry.mesh(parent,quad,at+Vector3(0,.36 if under_pot else .57,0),Color.WHITE)
		flame.rotation.y = angle
		flame.material_override = fire_material
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := OmniLight3D.new()
	glow.position = at+Vector3(0,.8,0)
	glow.light_color = Color("edac64")
	glow.light_energy = .85
	glow.omni_range = 4
	glow.shadow_enabled = false
	parent.add_child(glow)
