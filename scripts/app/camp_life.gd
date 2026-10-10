class_name CampLife
extends Node3D
## Local camp presentation/simulation. The durable ledger lives on Game across maps.
const DEPOT := Vector3(-2.3,0,14.5)
const SERVING := Vector3(6.95,0,7.4)
const WORKSHOP := RegionLayout.BASE + CampArt.BASE_WORKSHOP
const KITCHEN := RegionLayout.BASE + CampArt.BASE_KITCHEN
var ledger: CampProduction
var residents: Array[CampResident] = []
var display: Node3D
var camp_caption: Label3D
var serving_caption: Label3D
var refresh_needed := true

func _ready() -> void:
	name = "CampLife"
	ledger.changed.connect(func(): refresh_needed = true)
	for role in ["carpenter","cook"]:
		var person := CampResident.new()
		person.name = "Seon" if role == "carpenter" else "Haru"
		person.ledger = ledger
		person.role = role
		person.depot = DEPOT
		if role == "carpenter":
			person.home = WORKSHOP+Vector3(.2,0,1.4)
			person.pickup_point = Vector3(-4.2,0,24.6)
			person.work_point = WORKSHOP+Vector3(0,0,.54)
			person.work_target = WORKSHOP+Vector3(.12,.99,-.18)
			person.delivery_point = person.pickup_point
		else:
			person.home = KITCHEN+Vector3(-.65,0,2.3)
			person.pickup_point = Vector3(4.2,0,24.6)
			person.work_point = KITCHEN+Vector3(-.65,0,1.78)
			person.work_target = KITCHEN+Vector3(-.65,.815,.64)
			person.delivery_point = SERVING
		person.position = person.home+Vector3.UP*.05
		add_child(person)
		residents.append(person)
	camp_caption = Geometry.label(self,"",1.8,Color("dcc28f"))
	camp_caption.position = DEPOT+Vector3(-.6,1.8,-1.0)
	serving_caption = Geometry.label(self,"",1.9,Color("dcc28f"))
	serving_caption.position = SERVING+Vector3(0,1.9,-.7)
	for caption in [camp_caption,serving_caption]:
		caption.font_size = 23
		caption.no_depth_test = false
		caption.visibility_range_end = 12
	_refresh()

func _process(_delta: float) -> void:
	if refresh_needed: _refresh()
	var danger := false
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(RegionLayout.BASE) < 13: danger = true; break
	for resident in residents: resident.blocked = danger

func _refresh() -> void:
	refresh_needed = false
	if is_instance_valid(display): display.free()
	display = Node3D.new()
	display.name = "MovingSupplies"
	add_child(display)
	# Stock stays on existing cargo/workshop footprints and never creates a new blocker.
	var b := CampArt.Sculpt.new()
	for i in mini(ledger.cargo,4):
		CampArt._crate(b,Vector3(-3.2+(i%2)*.65,.48*(i/2),13.7),Vector3(.6,.44,.48))
	if ledger.kits_ready and ledger.receipts.is_empty():
		for i in 2: CampArt._crate(b,Vector3(-3.2+i*.65,0,13.7),Vector3(.6,.44,.48))
	for i in mini(ledger.shipments,4):
		CampArt._crate(b,Vector3(-6.6+(i%2)*.7,1.3+(i/2)*.46,24.55),Vector3(.60,.42,.50))
	for i in mini(ledger.ingredients,3): CampArt._sack(b,Vector3(5.8+i*.37,1.32,24.55),.42)
	for i in mini(ledger.meals,6):
		var at := KITCHEN+Vector3(.40+(i%3)*.32,.91,-.40-(i/3)*.25)
		b.lathe("clay",at,[Vector2(.055,0),Vector2(.115,.11),Vector2(.108,.115)],Basis.IDENTITY,14,false)
		b.lathe("stew",at,[Vector2(.094,.085),Vector2(.094,.09)],Basis.IDENTITY,14)
	if not b.surfaces.is_empty():
		var mesh := Geometry.mesh(display,b.finish(),Vector3.ZERO,Color.WHITE)
		mesh.material_override = null
	camp_caption.text = "회수 하치장\n"+("인계 대기 %d · 출하 %d" % [ledger.cargo,ledger.shipments] if ledger.kits_ready else "목수가 회수 상자를 준비 중")
	serving_caption.text = "하루의 배식대\n식사 %d · E 체력 +35" % ledger.meals

func near_food(player: ExpeditionPlayer) -> bool:
	return player.is_on_floor() and player.position.distance_to(SERVING) < 2.0

func prompt(player: ExpeditionPlayer) -> String:
	if not near_food(player): return ""
	if residents[1].blocked: return "주변의 적을 정리하면 배식을 재개합니다"
	if ledger.meals == 0: return "취사 담당이 식자재를 가져와 식사를 준비합니다"
	if player.health >= 100: return "따뜻한 식사 %d · 지금은 체력이 충분합니다" % ledger.meals
	return "E · 따뜻한 식사 · 체력 +35 (남은 식사 %d)" % ledger.meals

func eat(player: ExpeditionPlayer) -> bool:
	if not near_food(player) or residents[1].blocked or player.health >= 100 or player.health <= 0: return false
	if ledger.meals <= 0: return false
	player.health = minf(100,player.health+35)
	return ledger.eat()
