class_name ForestAtmosphere
extends Node
## A local presentation transition; never changes lantern safety or combat rules.
var observer: Node3D
var environment: Environment
var sun: DirectionalLight3D
var depth := 0.0

func _ready() -> void:
	var settings: WorldEnvironment = get_parent().get_node("RegionEnvironment")
	settings.environment = settings.environment.duplicate()
	environment = settings.environment
	sun = get_parent().get_node("RegionSun")
	apply_depth(0.0)

static func depth_at(z: float) -> float:
	return 1.0-smoothstep(-17.0,8.0,z)

func apply_depth(value: float) -> void:
	depth = clampf(value,0,1)
	environment.ambient_light_color = Color("b0bcb2").lerp(Color("819baa"),depth)
	environment.ambient_light_energy = lerpf(.40,.29,depth)
	environment.fog_light_color = Color("889b92").lerp(Color("637e88"),depth)
	environment.fog_light_energy = .64
	environment.fog_density = lerpf(.006,.014,depth)
	sun.light_color = Color("f6e3be").lerp(Color("adc8d0"),depth)
	sun.light_energy = lerpf(.77,.42,depth)

func _process(delta: float) -> void:
	if not is_instance_valid(observer): return
	apply_depth(lerpf(depth,depth_at(observer.global_position.z),1.0-exp(-2.8*delta)))
