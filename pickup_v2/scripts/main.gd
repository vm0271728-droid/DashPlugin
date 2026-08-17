extends Node3D

const TruckScript = preload("res://scripts/truck.gd")
const CameraScript = preload("res://scripts/orbit_camera.gd")
const HUDScript = preload("res://scripts/hud.gd")

var truck: PickupTruck
var camera: OrbitFollowCamera
var hud: PickupHUD
var current_test = 0
var tests = [
	{"name":"СВОБОДНАЯ ПЛОЩАДКА", "pos":Vector3(0, 0.18, -8), "yaw":0.0},
	{"name":"ДИАГОНАЛЬНЫЙ ВЫВЕС", "pos":Vector3(0, 0.20, 18), "yaw":0.0},
	{"name":"СТИРАЛЬНАЯ ДОСКА", "pos":Vector3(0, 0.18, 45), "yaw":0.0},
	{"name":"РАЗНОХОД КОЛЁС", "pos":Vector3(0, 0.20, 70), "yaw":0.0},
	{"name":"БОКОВОЙ УКЛОН", "pos":Vector3(0, 0.40, 94), "yaw":0.0},
	{"name":"РАМПА", "pos":Vector3(0, 0.20, 122), "yaw":0.0},
	{"name":"СТУПЕНИ", "pos":Vector3(0, 0.20, 151), "yaw":0.0},
	{"name":"ТЕСТ КОЛЛИЗИИ", "pos":Vector3(0, 0.20, 178), "yaw":0.0}
]

func _ready() -> void:
	_build_environment()
	_build_test_ground()
	truck = PickupTruck.new()
	truck.name = "PickupTruck"
	add_child(truck)
	camera = OrbitFollowCamera.new()
	camera.name = "OrbitCamera"
	add_child(camera)
	camera.set_target(truck)
	hud = PickupHUD.new()
	add_child(hud)
	hud.setup(truck, self)
	reset_vehicle()

func _build_environment() -> void:
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.10, 0.23, 0.38)
	sky_mat.sky_horizon_color = Color(0.58, 0.76, 0.88)
	sky_mat.ground_horizon_color = Color(0.38, 0.43, 0.41)
	sky_mat.ground_bottom_color = Color(0.08, 0.10, 0.09)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.58
	env_node.environment = env
	add_child(env_node)

	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	add_child(sun)

func _build_test_ground() -> void:
	add_box("Ground", Vector3(0, -0.25, 95), Vector3(38, 0.5, 240), Vector3.ZERO, Color(0.34, 0.39, 0.34))

	# Diagonal articulation blocks.
	add_box("Diag_L1", Vector3(-0.88, 0.16, 25.0), Vector3(0.82, 0.32, 2.5), Vector3.ZERO, Color(0.47, 0.32, 0.20))
	add_box("Diag_R1", Vector3(0.88, 0.24, 28.1), Vector3(0.82, 0.48, 2.5), Vector3.ZERO, Color(0.47, 0.32, 0.20))
	add_box("Diag_L2", Vector3(-0.88, 0.28, 31.2), Vector3(0.82, 0.56, 2.5), Vector3.ZERO, Color(0.47, 0.32, 0.20))
	add_box("Diag_R2", Vector3(0.88, 0.18, 34.3), Vector3(0.82, 0.36, 2.5), Vector3.ZERO, Color(0.47, 0.32, 0.20))

	# Washboard - low real colliders, not visual-only strips.
	for i in range(12):
		var z = 51.0 + i * 1.15
		var h = 0.10 + 0.035 * sin(float(i) * 1.7)
		add_box("Washboard_%02d" % i, Vector3(0, h * 0.5, z), Vector3(4.5, h, 0.34), Vector3.ZERO, Color(0.42, 0.42, 0.38))

	# Independent wheel-travel lane.
	for i in range(6):
		var side = -1.0 if i % 2 == 0 else 1.0
		var height = 0.26 + (i % 3) * 0.11
		add_box("Travel_%02d" % i, Vector3(side * 0.90, height * 0.5, 77.0 + i * 2.35), Vector3(0.92, height, 1.55), Vector3.ZERO, Color(0.35, 0.29, 0.23))

	# Side-slope platform: mesh and collision share the same transform.
	add_box("SideSlope", Vector3(0, 1.05, 105), Vector3(8.0, 0.45, 18.0), Vector3(0, 0, -13.0), Color(0.31, 0.36, 0.37))

	# Long approach/ramp.
	add_box("RampUp", Vector3(0, 0.86, 132), Vector3(5.6, 0.42, 10.0), Vector3(-9.5, 0, 0), Color(0.36, 0.37, 0.40))
	add_box("RampTop", Vector3(0, 1.70, 139.0), Vector3(5.6, 0.42, 5.0), Vector3.ZERO, Color(0.36, 0.37, 0.40))
	add_box("RampDown", Vector3(0, 0.86, 146.0), Vector3(5.6, 0.42, 10.0), Vector3(9.5, 0, 0), Color(0.36, 0.37, 0.40))

	# Stairs use matching box colliders; chassis/bumper can hit them too.
	for i in range(7):
		var h = 0.12 + i * 0.10
		add_box("Step_%02d" % i, Vector3(0, h * 0.5, 157.0 + i * 1.25), Vector3(4.2, h, 1.20), Vector3.ZERO, Color(0.39, 0.39, 0.41))

	# Tall wall: explicit tunnelling/collision test for CCD and compound chassis shapes.
	add_box("CollisionWall", Vector3(0, 1.0, 190.0), Vector3(7.0, 2.0, 0.70), Vector3.ZERO, Color(0.48, 0.16, 0.13))

	for idx in range(tests.size()):
		var sign = Label3D.new()
		sign.text = str(tests[idx]["name"])
		sign.font_size = 42
		sign.outline_size = 7
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var test_pos: Vector3 = tests[idx]["pos"]
		sign.position = Vector3(0, 3.1, test_pos.z + 5.5)
		add_child(sign)

func add_box(name_text: String, center: Vector3, size: Vector3, rotation_deg: Vector3, color: Color) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = name_text
	body.position = center
	body.rotation_degrees = rotation_deg
	body.collision_layer = 1
	body.collision_mask = 2
	var shape = BoxShape3D.new()
	shape.size = size
	var cs = CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.03
	box.material = material
	body.add_child(mesh)
	var pm = PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.0
	body.physics_material_override = pm
	add_child(body)
	return body

func reset_vehicle() -> void:
	if truck == null:
		return
	var t: Dictionary = tests[current_test]
	truck.release_all_controls()
	truck.freeze = true
	var spawn_pos: Vector3 = t["pos"]
	truck.global_transform = Transform3D(Basis(Vector3.UP, float(t["yaw"])), spawn_pos)
	truck.linear_velocity = Vector3.ZERO
	truck.angular_velocity = Vector3.ZERO
	truck.freeze = false
	truck.sleeping = false
	if hud != null:
		hud.set_station_name(str(t["name"]))

func next_test() -> void:
	current_test = (current_test + 1) % tests.size()
	reset_vehicle()

func _physics_process(_delta: float) -> void:
	# Desktop debug controls. On touchscreen devices the HUD owns these states,
	# so keyboard polling must not overwrite live touch presses.
	if truck == null or DisplayServer.is_touchscreen_available():
		return
	truck.set_left(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	truck.set_right(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
	truck.set_gas(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	truck.set_reverse(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	truck.set_handbrake(Input.is_key_pressed(KEY_SPACE))
