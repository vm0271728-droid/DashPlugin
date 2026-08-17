class_name OrbitFollowCamera
extends Camera3D

var target: Node3D
var yaw = 0.0
var pitch = 0.30
var distance = 8.0
var target_height = 1.20
var touch_points = {}
var last_pinch_distance = 0.0

func _ready() -> void:
	current = true
	fov = 67.0

func set_target(node: Node3D) -> void:
	target = node

func _process(delta: float) -> void:
	if target == null:
		return
	var cp = cos(pitch)
	var offset = Vector3(sin(yaw) * cp, sin(pitch), -cos(yaw) * cp) * distance
	var desired = target.global_position + Vector3.UP * target_height + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-9.0 * delta))
	look_at(target.global_position + Vector3.UP * target_height, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
		if touch_points.size() < 2:
			last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			yaw -= event.relative.x * 0.0060
			pitch = clamp(pitch + event.relative.y * 0.0050, -0.65, 1.22)
		elif touch_points.size() >= 2:
			var values = touch_points.values()
			var p0: Vector2 = values[0]
			var p1: Vector2 = values[1]
			var pinch = p0.distance_to(p1)
			if last_pinch_distance > 0.0:
				distance = clamp(distance - (pinch - last_pinch_distance) * 0.012, 3.8, 16.0)
			last_pinch_distance = pinch
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.0060
		pitch = clamp(pitch + event.relative.y * 0.0050, -0.65, 1.22)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = max(3.8, distance - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(16.0, distance + 0.7)
