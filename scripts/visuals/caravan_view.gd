class_name CaravanView
extends Node3D
## Draws the Caravan's numbers as a long column in a handful of MultiMeshes.
## The column repeats a block: a 4-wide file of people flanked by pack mules, then
## ox-drawn wagons two abreast. It is longer than the route, so when the head reaches
## the base the tail is still leaving camp. Members whose place has not left yet wait in
## camp slots and walk out onto the road when their turn comes. Settled: parked by the base.

const BLOCKS := 6
const LANES := 4
const ROW := 0.85
const MULE_STEP := 2.8
const WAGON_STEP := 5.8
const OX_LEAD := 2.9
const GAP := 1.5
const WALK_OUT := 10.0
const COATS := [Color("9a7354"), Color("668876"), Color("7d8fb0"), Color("b0805f"), Color("8c7a9e"), Color("a99a62"), Color("6f8f8a")]
const SKIN := [Color("f2c9a0"), Color("e0b088"), Color("c99372"), Color("f5d6b8")]
const FUR := [Color("8a6a4c"), Color("6e5a48"), Color("9b8064"), Color("b39a7a")]
const CANVAS := [Color("d9c9a3"), Color("b9a07a"), Color("8f7a5c"), Color("c7b28c")]
const HIDE := [Color("7a5a40"), Color("5f4a3a"), Color("94775a")]

var caravan: Caravan
var moving := false
var settled := false
var settle_center := Vector3.ZERO
var clock := 0.0
var per_block := {}
var block_length := 0.0
var bodies: MultiMeshInstance3D
var heads: MultiMeshInstance3D
var mule_bodies: MultiMeshInstance3D
var mule_heads: MultiMeshInstance3D
var packs: MultiMeshInstance3D
var bundles: MultiMeshInstance3D
var ox_bodies: MultiMeshInstance3D
var ox_heads: MultiMeshInstance3D
var horns: MultiMeshInstance3D
var yokes: MultiMeshInstance3D
var legs: MultiMeshInstance3D
var wagons: MultiMeshInstance3D
var covers: MultiMeshInstance3D
var wheels: MultiMeshInstance3D
var mule_spots: Array[Vector3] = []
var drawn_distance := -1.0
var drawn_people := -1
var drawn_settled := false

func _ready() -> void:
	per_block = {
		"people": ceili(caravan.people / float(BLOCKS)),
		"mules": ceili(caravan.mules / float(BLOCKS)),
		"wagons": ceili(caravan.wagons / float(BLOCKS)),
	}
	block_length = _people_length() + GAP + ceili(per_block.wagons / 2.0) * WAGON_STEP + GAP
	var sphere := Geometry.unit_sphere()
	var body := CapsuleMesh.new()
	body.radius = 0.24
	body.height = 0.95
	body.radial_segments = 8
	body.rings = 2
	var leg := CylinderMesh.new()
	leg.top_radius = 0.12
	leg.bottom_radius = 0.1
	leg.height = 1.0
	leg.radial_segments = 6
	var pack := BoxMesh.new()
	pack.size = Vector3(0.42, 0.62, 0.85)
	var roll := CylinderMesh.new()
	roll.top_radius = 0.28
	roll.bottom_radius = 0.28
	roll.height = 1.25
	roll.radial_segments = 8
	var horn := CylinderMesh.new()
	horn.top_radius = 0.02
	horn.bottom_radius = 0.08
	horn.height = 0.6
	horn.radial_segments = 6
	var yoke := BoxMesh.new()
	yoke.size = Vector3(0.12, 0.12, 1.4)
	var wagon := BoxMesh.new()
	wagon.size = Vector3(1.5, 0.7, 2.4)
	var cover := CylinderMesh.new()
	cover.top_radius = 0.75
	cover.bottom_radius = 0.75
	cover.height = 2.3
	cover.radial_segments = 10
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.42
	wheel.bottom_radius = 0.42
	wheel.height = 0.12
	wheel.radial_segments = 12
	bodies = _crowd(body, caravan.people, COATS)
	heads = _crowd(sphere, caravan.people, SKIN)
	mule_bodies = _crowd(sphere, caravan.mules, FUR)
	mule_heads = _crowd(sphere, caravan.mules, FUR)
	packs = _crowd(pack, caravan.mules * 2, CANVAS)
	bundles = _crowd(roll, caravan.mules, [Color("a85b48"), Color("5f7f8f"), Color("8a8f55")])
	ox_bodies = _crowd(sphere, caravan.oxen, HIDE)
	ox_heads = _crowd(sphere, caravan.oxen, HIDE)
	horns = _crowd(horn, caravan.oxen * 2, [Color("eadfc6")])
	yokes = _crowd(yoke, caravan.oxen, [Color("6f5a40")])
	legs = _crowd(leg, (caravan.mules + caravan.oxen) * 4, [Color("5c4a3a")])
	wagons = _crowd(wagon, caravan.wagons, [Color("a5835a")])
	covers = _crowd(cover, caravan.wagons, [Color("e9dfc4"), Color("dcd0b0")])
	wheels = _crowd(wheel, caravan.wagons * 4, [Color("5c4a3a")])
	mule_spots.resize(caravan.mules)
	refresh()

func _crowd(resource: Mesh, count: int, palette: Array) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in count:
		transforms.append(Transform3D())
		colors.append(palette[(i * 7 + i / 3) % palette.size()])
	return Geometry.instances(self, resource, transforms, colors)

func _process(delta: float) -> void:
	if moving:
		clock += delta
	# Halted columns stand still; skip rewriting ~1500 transforms when nothing changed.
	if moving or caravan.distance != drawn_distance or caravan.people != drawn_people or settled != drawn_settled:
		refresh()

func column_length() -> float:
	return BLOCKS * block_length

func head_position() -> Vector3:
	return _person_frame(0).origin

func tail_position() -> Vector3:
	return _wagon_frame(caravan.wagons - 1).origin

func mule_position(i: int) -> Vector3:
	return mule_spots[i]

func refresh() -> void:
	drawn_distance = caravan.distance
	drawn_people = caravan.people
	drawn_settled = settled
	bodies.multimesh.visible_instance_count = caravan.people
	heads.multimesh.visible_instance_count = caravan.people
	for i in caravan.people:
		var frame := _person_frame(i)
		var bob := absf(sin(clock * 9.0 + i)) * 0.07 if moving else 0.0
		bodies.multimesh.set_instance_transform(i, frame.translated_local(Vector3(0, 0.5 + bob, 0)))
		heads.multimesh.set_instance_transform(i, frame * Transform3D(Basis().scaled(Vector3(0.4, 0.38, 0.4)), Vector3(0, 1.17 + bob, 0)))
	for i in caravan.mules:
		var frame := _mule_frame(i)
		mule_spots[i] = frame.origin
		var phase := clock * 6.5 + i * 1.7
		var bob := absf(sin(phase)) * 0.06 if moving else 0.0
		mule_bodies.multimesh.set_instance_transform(i, frame * Transform3D(Basis().scaled(Vector3(0.95, 0.95, 1.8)), Vector3(0, 1.3 + bob, 0)))
		mule_heads.multimesh.set_instance_transform(i, frame * Transform3D(Basis(Vector3.RIGHT, 0.35).scaled(Vector3(0.5, 0.55, 0.78)), Vector3(0, 1.72 + bob, -1.05)))
		for side in 2:
			var x := -0.68 if side == 0 else 0.68
			packs.multimesh.set_instance_transform(i * 2 + side, frame.translated_local(Vector3(x, 1.22 + bob, 0.05)))
		bundles.multimesh.set_instance_transform(i, frame * Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, 1.95 + bob, 0.15)))
		_legs(i * 4, frame, Vector3(0.3, 1.05, 0.6), 1.7, phase)
	for i in caravan.wagons:
		var frame := _wagon_frame(i)
		wagons.multimesh.set_instance_transform(i, frame.translated_local(Vector3(0, 0.85, 0)))
		covers.multimesh.set_instance_transform(i, frame * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.3, 0)))
		var turn := clock * 2.4 if moving else 0.0
		for w in 4:
			var at := Vector3(-0.82 if w % 2 == 0 else 0.82, 0.42, -0.8 if w < 2 else 0.8)
			wheels.multimesh.set_instance_transform(i * 4 + w, frame * Transform3D(Basis(Vector3.FORWARD, PI / 2) * Basis(Vector3.UP, turn), at))
	for i in caravan.oxen:
		var frame := _ox_frame(i)
		var phase := clock * 5.0 + i * 2.3
		var bob := absf(sin(phase)) * 0.05 if moving else 0.0
		ox_bodies.multimesh.set_instance_transform(i, frame * Transform3D(Basis().scaled(Vector3(1.35, 1.3, 2.3)), Vector3(0, 1.5 + bob, 0)))
		ox_heads.multimesh.set_instance_transform(i, frame * Transform3D(Basis().scaled(Vector3(0.78, 0.72, 0.85)), Vector3(0, 1.62 + bob, -1.35)))
		for side in 2:
			var x := -0.42 if side == 0 else 0.42
			horns.multimesh.set_instance_transform(i * 2 + side, frame * Transform3D(Basis(Vector3.FORWARD, -x * 2.2), Vector3(x * 1.25, 2.02 + bob, -1.35)))
		yokes.multimesh.set_instance_transform(i, frame.translated_local(Vector3(0, 0.95, 1.65)) if not settled else Transform3D(Basis().scaled(Vector3.ZERO), frame.origin))
		_legs((caravan.mules + i) * 4, frame, Vector3(0.45, 1.05, 0.75), 2.6, phase)

## Four legs swinging in diagonal pairs about their hips.
func _legs(first: int, frame: Transform3D, hip: Vector3, thickness: float, phase: float) -> void:
	for l in 4:
		var x := -hip.x if l % 2 == 0 else hip.x
		var z := -hip.z if l < 2 else hip.z
		var swing := sin(phase + (PI if (l == 1 or l == 2) else 0.0)) * 0.45 if moving else 0.0
		var hip_frame := frame * Transform3D(Basis(Vector3.RIGHT, swing), Vector3(x, hip.y, z))
		legs.multimesh.set_instance_transform(first + l, hip_frame * Transform3D(Basis().scaled(Vector3(thickness, 1.0, thickness)), Vector3(0, -0.5, 0)))

# --- Formation ------------------------------------------------------------------

func _people_length() -> float:
	return ceili(per_block.people / float(LANES)) * ROW

func _person_frame(i: int) -> Transform3D:
	if settled:
		const PER_ROW := 22
		var row := i / PER_ROW
		return Transform3D(Basis(), settle_center + Vector3(((i % PER_ROW) - (PER_ROW - 1) * 0.5) * 0.75 + (row % 2) * 0.35, 0, 12.5 + row * 0.7))
	var k: int = i % per_block.people
	var back: float = 1.0 + (i / per_block.people) * block_length + (k / LANES) * ROW
	const CAMP_ROW := 14
	var parked := caravan.route[0] + Vector3(((i % CAMP_ROW) - (CAMP_ROW - 1) * 0.5) * 0.72, 0, -3.0 + (i / CAMP_ROW) * 0.75)
	return _formation(back, ((k % LANES) - (LANES - 1) * 0.5) * 0.75, parked, Basis())

func _mule_frame(i: int) -> Transform3D:
	var side := -1.0 if i % 2 == 0 else 1.0
	if settled:
		return Transform3D(Basis(), settle_center + Vector3(side * (14.0 + ((i / 2) % 3) * 1.4), 0, 7.5 + (i / 6) * 2.4))
	var k: int = i % per_block.mules
	var back: float = 2.0 + (i / per_block.mules) * block_length + (k / 2) * MULE_STEP
	var parked := Vector3(side * (13.5 + ((i / 2) % 3) * 1.5), 0, 141.0 + (i / 6) * 2.6)
	return _formation(back, side * 2.6, parked, Basis())

func _wagon_back(i: int) -> float:
	var k: int = i % per_block.wagons
	return 1.0 + (i / per_block.wagons) * block_length + _people_length() + GAP + (k / 2) * WAGON_STEP + OX_LEAD

func _wagon_lateral(i: int) -> float:
	return -1.2 if (i % per_block.wagons) % 2 == 0 else 1.2

func _wagon_frame(i: int) -> Transform3D:
	var side := -1.0 if i % 2 == 0 else 1.0
	if settled:
		return Transform3D(Basis(Vector3.UP, PI / 2), settle_center + Vector3(side * 10.5, 0, 9 + (i / 2) * 2.0))
	var parked := Vector3(side * (8.5 + ((i / 2) % 2) * 2.3), 0, 141.0 + (i / 4) * 2.8)
	return _formation(_wagon_back(i), _wagon_lateral(i), parked, Basis())

func _ox_frame(i: int) -> Transform3D:
	var side := -1.0 if i % 2 == 0 else 1.0
	if settled:
		return Transform3D(Basis(), settle_center + Vector3(side * 18.5, 0, 8 + (i / 2) * 2.6))
	var parked := Vector3(side * (18.5 + ((i / 2) % 2) * 1.9), 0, 141.5 + (i / 4) * 2.7)
	return _formation(_wagon_back(i) - OX_LEAD, _wagon_lateral(i), parked, Basis())

## Where a member `back` meters behind the front stands, facing along the road.
## Before its turn it waits at `parked`; for the last WALK_OUT meters it walks to the road.
func _formation(back: float, lateral: float, parked: Vector3, parked_basis: Basis) -> Transform3D:
	var ahead := (caravan.route[1] - caravan.route[0]).normalized()
	var side := ahead.cross(Vector3.UP).normalized()
	var at := caravan.distance - back
	if at >= 0:
		return Transform3D(Basis.looking_at(ahead, Vector3.UP), caravan.point_at(at) + side * lateral)
	if at <= -WALK_OUT:
		return Transform3D(parked_basis, Vector3(parked.x, 0, parked.z))
	var road := caravan.route[0] + side * lateral
	var walk := road - Vector3(parked.x, 0, parked.z)
	var spot := Vector3(parked.x, 0, parked.z).lerp(road, (at + WALK_OUT) / WALK_OUT)
	return Transform3D(Basis.looking_at(walk.normalized() if walk.length() > 0.01 else ahead, Vector3.UP), spot)
