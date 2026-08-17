class_name PickupTruck
extends RigidBody3D

# Vehicle coordinates: +X right, +Y up, +Z forward.
# The visual GLB contains the user's pickup body plus four separately named wheels.
const WHEEL_FL = 0
const WHEEL_FR = 1
const WHEEL_RL = 2
const WHEEL_RR = 3
const WHEEL_COUNT = 4
const WHEEL_NAMES = ["wheel_FL", "wheel_FR", "wheel_RL", "wheel_RR"]
const WHEEL_X = [-0.86826, 0.86885, -0.86834, 0.86873]
const WHEEL_Z = [2.01394, 2.01394, -1.55129, -1.55129]

var wheel_radius = 0.456
var attach_y = 1.08
var rest_length = 0.62
var max_travel = 0.29
var spring_front = 50000.0
var spring_rear = 54000.0
var bump_front = 6900.0
var rebound_front = 8800.0
var bump_rear = 7400.0
var rebound_rear = 9400.0
var antiroll_front = 10500.0
var antiroll_rear = 8500.0
var tire_mu = 1.02
var corner_front = 57000.0
var corner_rear = 62000.0
var max_suspension_force = 33000.0
var brake_force = 7600.0
var handbrake_force = 6500.0
var max_steer_low = deg_to_rad(34.0)
var max_steer_high = deg_to_rad(11.0)

var left_pressed = false
var right_pressed = false
var gas_pressed = false
var reverse_pressed = false
var handbrake_pressed = false
var steering_input = 0.0
var throttle_input = 0.0
var speed_mps = 0.0
var rpm = 750.0
var grounded = 0

var visual_root: Node3D
var wheel_pivots: Array[Node3D] = []
var wheels = []

func _ready() -> void:
	mass = 2300.0
	gravity_scale = 1.0
	linear_damp = 0.03
	angular_damp = 0.28
	continuous_cd = true
	can_sleep = false
	collision_layer = 2
	collision_mask = 1
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.78, -0.12)
	var material = PhysicsMaterial.new()
	material.friction = 0.55
	material.bounce = 0.0
	physics_material_override = material
	_build_collision()
	_load_visual_model()
	for i in range(WHEEL_COUNT):
		wheels.append({
			"length": rest_length,
			"visual_length": rest_length,
			"load": 0.0,
			"steer": 0.0,
			"spin": 0.0,
			"spin_speed": 0.0,
			"contact": false
		})

func _build_collision() -> void:
	_add_box(Vector3(1.90, 0.34, 5.25), Vector3(0.0, 0.62, -0.08))
	_add_box(Vector3(1.92, 0.64, 3.45), Vector3(0.0, 1.00, -0.10))
	_add_box(Vector3(1.82, 0.78, 1.68), Vector3(0.0, 1.60, 0.62))
	_add_box(Vector3(1.96, 0.34, 0.42), Vector3(0.0, 0.75, 2.70))
	_add_box(Vector3(1.90, 0.28, 0.36), Vector3(0.0, 0.72, -2.66))

func _add_box(size: Vector3, pos: Vector3) -> void:
	var shape = BoxShape3D.new()
	shape.size = size
	var cs = CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)

func _load_visual_model() -> void:
	var scene = load("res://assets/truck.glb") as PackedScene
	if scene == null:
		push_error("SUPPLIED PICKUP MODEL FAILED TO LOAD")
		return
	visual_root = scene.instantiate() as Node3D
	visual_root.name = "SuppliedPickupVisual"
	add_child(visual_root)
	for i in range(WHEEL_COUNT):
		var pivot = Node3D.new()
		pivot.name = WHEEL_NAMES[i] + "_physics_pivot"
		pivot.position = Vector3(WHEEL_X[i], attach_y - rest_length, WHEEL_Z[i])
		visual_root.add_child(pivot)
		wheel_pivots.append(pivot)
		var wheel_node = visual_root.find_child(WHEEL_NAMES[i], true, false) as Node3D
		if wheel_node != null:
			var old_parent = wheel_node.get_parent()
			old_parent.remove_child(wheel_node)
			pivot.add_child(wheel_node)
			wheel_node.transform = Transform3D.IDENTITY
		else:
			push_warning("Wheel node missing: " + WHEEL_NAMES[i])

func set_left(value: bool) -> void:
	left_pressed = value

func set_right(value: bool) -> void:
	right_pressed = value

func set_gas(value: bool) -> void:
	gas_pressed = value

func set_reverse(value: bool) -> void:
	reverse_pressed = value

func set_handbrake(value: bool) -> void:
	handbrake_pressed = value

func release_all_controls() -> void:
	left_pressed = false
	right_pressed = false
	gas_pressed = false
	reverse_pressed = false
	handbrake_pressed = false
	steering_input = 0.0
	throttle_input = 0.0

func _pressed(action_name: String, direct_value: bool) -> bool:
	if direct_value:
		return true
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if wheels.size() != WHEEL_COUNT:
		return
	var dt = state.step
	var tr = state.transform
	var basis = tr.basis.orthonormalized()
	var up = (basis * Vector3.UP).normalized()
	var forward = (basis * Vector3(0, 0, 1)).normalized()
	speed_mps = state.linear_velocity.dot(forward)
	var kmh = abs(speed_mps) * 3.6

	var left = _pressed("drive_left", left_pressed)
	var right = _pressed("drive_right", right_pressed)
	var gas = _pressed("drive_gas", gas_pressed)
	var reverse = _pressed("drive_reverse", reverse_pressed)
	var handbrake = _pressed("drive_handbrake", handbrake_pressed)

	var steer_target = 0.0
	if left and not right:
		steer_target = -1.0
	elif right and not left:
		steer_target = 1.0
	steering_input = move_toward(steering_input, steer_target, 4.5 * dt)

	var throttle_target = 0.0
	var service_brake = 0.0
	if gas and not reverse:
		if speed_mps < -0.7:
			service_brake = 1.0
		else:
			throttle_target = 1.0
	elif reverse and not gas:
		if speed_mps > 0.7:
			service_brake = 1.0
		elif speed_mps > -9.0:
			throttle_target = -0.72
	throttle_input = move_toward(throttle_input, throttle_target, 3.2 * dt)

	var space = state.get_space_state()
	var compressions = [0.0, 0.0, 0.0, 0.0]
	var attach_positions: Array[Vector3] = []
	grounded = 0
	var center_steer = _steer_angle(kmh)

	for i in range(WHEEL_COUNT):
		var ws = wheels[i]
		var wheel_steer = _ackermann(i, center_steer)
		ws["steer"] = wheel_steer
		var steer_basis = Basis(Vector3.UP, wheel_steer)
		var tire_forward = (basis * (steer_basis * Vector3(0, 0, 1))).normalized()
		var tire_right = (basis * (steer_basis * Vector3(1, 0, 0))).normalized()
		var attach = tr * Vector3(WHEEL_X[i], attach_y, WHEEL_Z[i])
		attach_positions.append(attach)
		var hit = _wheel_raycast(space, attach, tire_forward, up)
		if hit.is_empty():
			ws["contact"] = false
			ws["load"] = 0.0
			ws["length"] = rest_length + max_travel
			if i >= WHEEL_RL:
				ws["spin_speed"] = lerp(float(ws["spin_speed"]), throttle_input * 12.0, 0.08)
			wheels[i] = ws
			continue

		grounded += 1
		var hit_pos: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		var length = clamp(float(hit["length"]), rest_length - max_travel, rest_length + max_travel)
		var compression = max(0.0, rest_length - length)
		compressions[i] = compression
		var rel = hit_pos - tr.origin
		var point_velocity = state.get_velocity_at_local_position(rel)
		var suspension_velocity = point_velocity.dot(up)
		var spring = spring_front if i <= WHEEL_FR else spring_rear
		var damping = 0.0
		if i <= WHEEL_FR:
			damping = bump_front if suspension_velocity < 0.0 else rebound_front
		else:
			damping = bump_rear if suspension_velocity < 0.0 else rebound_rear
		var suspension_force = clamp(spring * compression - damping * suspension_velocity, 0.0, max_suspension_force)
		state.apply_force(normal * suspension_force, rel)

		var fwd = tire_forward.slide(normal)
		var side = tire_right.slide(normal)
		if fwd.length_squared() > 0.001 and side.length_squared() > 0.001:
			fwd = fwd.normalized()
			side = side.normalized()
			var long_v = point_velocity.dot(fwd)
			var side_v = point_velocity.dot(side)
			var slip_angle = atan2(side_v, abs(long_v) + 1.2)
			var corner = corner_front if i <= WHEEL_FR else corner_rear
			var lateral = -corner * slip_angle * clamp(abs(long_v) / 2.2, 0.0, 1.0)
			var longitudinal = 0.0

			# RWD only. Torque is load-limited by the friction circle below.
			if i >= WHEEL_RL and abs(throttle_input) > 0.01:
				longitudinal += _drive_force(throttle_input, abs(speed_mps)) * 0.5
			if service_brake > 0.0:
				longitudinal += -clamp(long_v * 5200.0, -brake_force, brake_force) * service_brake
			if handbrake and i >= WHEEL_RL:
				longitudinal += -clamp(long_v * 4700.0, -handbrake_force, handbrake_force)

			var rolling_limit = suspension_force * 0.018
			longitudinal += -clamp(long_v * 1000.0, -rolling_limit, rolling_limit)
			var grip = max(0.0, suspension_force * (0.58 if handbrake and i >= WHEEL_RL else tire_mu))
			var combined = Vector2(longitudinal, lateral)
			if combined.length() > grip and grip > 0.0:
				combined = combined.normalized() * grip
			state.apply_force(fwd * combined.x + side * combined.y, rel)
			ws["spin_speed"] = lerp(float(ws["spin_speed"]), long_v / wheel_radius, 0.28)

		ws["contact"] = true
		ws["load"] = suspension_force
		ws["length"] = length
		wheels[i] = ws

	_apply_antiroll(state, up, tr.origin, attach_positions, compressions, WHEEL_FL, WHEEL_FR, antiroll_front)
	_apply_antiroll(state, up, tr.origin, attach_positions, compressions, WHEEL_RL, WHEEL_RR, antiroll_rear)

	# Aerodynamic drag only removes energy.
	var velocity = state.linear_velocity
	var total_speed = velocity.length()
	if total_speed > 0.2:
		var drag = 0.5 * 1.225 * 1.05 * total_speed * total_speed
		state.apply_central_force(-velocity.normalized() * drag)

	# Approximate engine RPM purely for HUD and torque shaping.
	rpm = clamp(750.0 + abs(speed_mps) * 165.0 + abs(throttle_input) * 900.0, 750.0, 5200.0)

func _wheel_raycast(space: PhysicsDirectSpaceState3D, attach: Vector3, wheel_forward: Vector3, up: Vector3) -> Dictionary:
	var best = {}
	var best_length = INF
	var ray_distance = rest_length + max_travel + wheel_radius + 0.12
	for offset in [wheel_radius * 0.50, 0.0, -wheel_radius * 0.36]:
		var origin = attach + wheel_forward * float(offset) + up * 0.035
		var endpoint = origin - up * ray_distance
		var query = PhysicsRayQueryParameters3D.create(origin, endpoint, 1, [get_rid()])
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_pos: Vector3 = hit["position"]
		var projected = (attach - hit_pos).dot(up) - wheel_radius
		if projected < best_length:
			best_length = projected
			best = hit.duplicate()
			best["length"] = projected
	return best

func _apply_antiroll(state: PhysicsDirectBodyState3D, up: Vector3, origin: Vector3, attachments: Array[Vector3], compressions: Array, li: int, ri: int, stiffness: float) -> void:
	if attachments.size() != WHEEL_COUNT:
		return
	if not bool(wheels[li]["contact"]) or not bool(wheels[ri]["contact"]):
		return
	var difference = float(compressions[li]) - float(compressions[ri])
	var force = clamp(difference * stiffness, -7000.0, 7000.0)
	state.apply_force(up * force, attachments[li] - origin)
	state.apply_force(-up * force, attachments[ri] - origin)

func _steer_angle(kmh: float) -> float:
	var t = clamp(kmh / 95.0, 0.0, 1.0)
	return steering_input * lerp(max_steer_low, max_steer_high, t)

func _ackermann(index: int, center: float) -> float:
	if index >= WHEEL_RL:
		return 0.0
	if abs(center) < 0.0005:
		return center
	var wheelbase = WHEEL_Z[WHEEL_FL] - WHEEL_Z[WHEEL_RL]
	var track = WHEEL_X[WHEEL_FR] - WHEEL_X[WHEEL_FL]
	var radius = wheelbase / tan(abs(center))
	var inner = atan(wheelbase / max(0.1, radius - track * 0.5))
	var outer = atan(wheelbase / (radius + track * 0.5))
	if center < 0.0:
		return -inner if index == WHEEL_FL else -outer
	return outer if index == WHEEL_FL else inner

func _drive_force(throttle: float, speed: float) -> float:
	# Heavy pickup: broad low-end torque and deliberately restrained launch.
	var speed_factor = clamp(1.0 - speed / 47.0, 0.30, 1.0)
	var base_force = 7200.0 * speed_factor
	if throttle < 0.0:
		base_force = 5100.0
	return base_force * throttle

func _process(delta: float) -> void:
	if wheel_pivots.size() != WHEEL_COUNT or wheels.size() != WHEEL_COUNT:
		return
	for i in range(WHEEL_COUNT):
		var ws = wheels[i]
		var blend = 1.0 - exp(-25.0 * delta)
		ws["visual_length"] = lerp(float(ws["visual_length"]), float(ws["length"]), blend)
		ws["spin"] = float(ws["spin"]) + float(ws["spin_speed"]) * delta
		var pivot = wheel_pivots[i]
		pivot.position = Vector3(WHEEL_X[i], attach_y - float(ws["visual_length"]), WHEEL_Z[i])
		pivot.basis = Basis(Vector3.UP, float(ws["steer"])) * Basis(Vector3.RIGHT, float(ws["spin"]))
		wheels[i] = ws

func telemetry() -> Dictionary:
	var suspension = []
	for i in range(WHEEL_COUNT):
		var min_len = rest_length - max_travel
		var max_len = rest_length + max_travel
		var travel = 1.0 - clamp((float(wheels[i]["length"]) - min_len) / (max_len - min_len), 0.0, 1.0)
		suspension.append(travel)
	return {
		"speed_kmh": abs(speed_mps) * 3.6,
		"gear": "R" if throttle_input < -0.05 else "D",
		"rpm": rpm,
		"steering_deg": rad_to_deg(_steer_angle(abs(speed_mps) * 3.6)),
		"grounded": grounded,
		"suspension": suspension,
		"gas": _pressed("drive_gas", gas_pressed),
		"reverse": _pressed("drive_reverse", reverse_pressed),
		"left": _pressed("drive_left", left_pressed),
		"right": _pressed("drive_right", right_pressed)
	}
