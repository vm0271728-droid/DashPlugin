class_name PickupHUD
extends CanvasLayer

var truck: PickupTruck
var main_controller: Node
var root: Control
var speed_label: Label
var station_label: Label
var wheel_bars: Array[ProgressBar] = []
var visuals = {}
var touch_buttons = {}
var action_buttons = {}
var touch_rects = {}
var active_touch_controls = {}

func setup(p_truck: PickupTruck, p_main: Node) -> void:
	truck = p_truck
	main_controller = p_main
	_build_ui()

func _build_ui() -> void:
	for action_name in ["drive_left", "drive_right", "drive_gas", "drive_reverse", "drive_handbrake"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.resized.connect(_layout)

	var telemetry_panel = Panel.new()
	telemetry_panel.name = "TelemetryPanel"
	telemetry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(telemetry_panel)
	telemetry_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.08, 0.11, 0.78)))
	speed_label = Label.new()
	speed_label.position = Vector2(18, 12)
	speed_label.size = Vector2(305, 100)
	speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_label.add_theme_font_size_override("font_size", 20)
	telemetry_panel.add_child(speed_label)
	visuals["telemetry_panel"] = telemetry_panel

	station_label = Label.new()
	station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	station_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	station_label.add_theme_font_size_override("font_size", 24)
	station_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(station_label)

	var suspension_panel = Panel.new()
	suspension_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(suspension_panel)
	suspension_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.08, 0.11, 0.78)))
	visuals["suspension_panel"] = suspension_panel
	var title = Label.new()
	title.text = "ХОД ПОДВЕСКИ"
	title.position = Vector2(14, 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 17)
	suspension_panel.add_child(title)
	for i in range(4):
		var lbl = Label.new()
		lbl.text = ["FL", "FR", "RL", "RR"][i]
		lbl.position = Vector2(14, 37 + i * 27)
		lbl.size = Vector2(34, 22)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		suspension_panel.add_child(lbl)
		var bar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.position = Vector2(52, 40 + i * 27)
		bar.size = Vector2(132, 15)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		suspension_panel.add_child(bar)
		wheel_bars.append(bar)

	# Gameplay controls use TouchScreenButton, not mouse emulation. This guarantees
	# gas + steering + handbrake can be held simultaneously on Android.
	_create_touch_drive_button("left", "◀", Color(0.10, 0.27, 0.48, 0.90))
	_create_touch_drive_button("right", "▶", Color(0.10, 0.27, 0.48, 0.90))
	_create_touch_drive_button("reverse", "▼\nНАЗАД", Color(0.30, 0.12, 0.12, 0.90))
	_create_touch_drive_button("gas", "▲\nГАЗ", Color(0.08, 0.34, 0.58, 0.92))
	_create_touch_drive_button("handbrake", "РУЧНИК", Color(0.08, 0.13, 0.19, 0.92))
	_create_action_button("reset", "RESET")
	_create_action_button("test", "TEST")
	_layout()

func _create_touch_drive_button(key: String, text: String, color: Color) -> void:
	var visual = Panel.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_theme_stylebox_override("panel", _button_style(color))
	root.add_child(visual)
	var lbl = Label.new()
	lbl.text = text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 20)
	visual.add_child(lbl)
	visuals[key] = visual

	var touch = TouchScreenButton.new()
	touch.name = key.capitalize() + "Touch"
	touch.action = "drive_" + key
	touch.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	touch.passby_press = true
	touch.shape_centered = true
	touch.shape_visible = false
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 100)
	touch.shape = shape
	add_child(touch)
	touch_buttons[key] = touch
	touch.pressed.connect(func(): visual.modulate = Color(0.72, 0.88, 1.0, 1.0))
	touch.released.connect(func(): visual.modulate = Color.WHITE)
	match key:
		"left":
			touch.pressed.connect(func(): truck.set_left(true))
			touch.released.connect(func(): truck.set_left(false))
		"right":
			touch.pressed.connect(func(): truck.set_right(true))
			touch.released.connect(func(): truck.set_right(false))
		"gas":
			touch.pressed.connect(func(): truck.set_gas(true))
			touch.released.connect(func(): truck.set_gas(false))
		"reverse":
			touch.pressed.connect(func(): truck.set_reverse(true))
			touch.released.connect(func(): truck.set_reverse(false))
		"handbrake":
			touch.pressed.connect(func(): truck.set_handbrake(true))
			touch.released.connect(func(): truck.set_handbrake(false))

func _create_action_button(key: String, text: String) -> void:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.15, 0.21, 0.88)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.38, 0.50, 0.94)))
	root.add_child(b)
	action_buttons[key] = b
	if key == "reset":
		b.pressed.connect(func(): main_controller.reset_vehicle())
	elif key == "test":
		b.pressed.connect(func(): main_controller.next_test())

func _panel_style(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.45, 0.60, 0.68, 0.35)
	return sb

func _button_style(color: Color) -> StyleBoxFlat:
	var sb = _panel_style(color)
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	return sb

func _place_touch(key: String, rect: Rect2) -> void:
	touch_rects[key] = rect
	var visual = visuals[key] as Control
	visual.position = rect.position
	visual.size = rect.size
	var touch = touch_buttons[key] as TouchScreenButton
	touch.position = rect.position + rect.size * 0.5
	var shape = touch.shape as RectangleShape2D
	shape.size = rect.size

func _layout() -> void:
	if root == null:
		return
	var s = root.size
	var ui_scale = clamp(min(s.x / 1920.0, s.y / 1080.0), 0.62, 1.15)
	var big = Vector2(118, 118) * ui_scale
	var gap = 18.0 * ui_scale
	var margin = 34.0 * ui_scale
	var y = s.y - big.y - margin
	_place_touch("left", Rect2(Vector2(margin, y), big))
	_place_touch("right", Rect2(Vector2(margin + big.x + gap, y), big))
	_place_touch("gas", Rect2(Vector2(s.x - margin - big.x, y), big))
	_place_touch("reverse", Rect2(Vector2(s.x - margin - big.x * 2.0 - gap, y), big))
	var hb_size = Vector2(150, 82) * ui_scale
	_place_touch("handbrake", Rect2(Vector2(s.x * 0.5 - hb_size.x * 0.5, s.y - hb_size.y - margin), hb_size))
	var small = Vector2(104, 58) * ui_scale
	var reset = action_buttons["reset"] as Button
	reset.size = small
	reset.position = Vector2(s.x * 0.5 - small.x - gap * 0.5, s.y - hb_size.y - small.y - margin - gap)
	var test = action_buttons["test"] as Button
	test.size = small
	test.position = Vector2(s.x * 0.5 + gap * 0.5, s.y - hb_size.y - small.y - margin - gap)
	var tp = visuals["telemetry_panel"] as Panel
	tp.position = Vector2(margin, 22 * ui_scale)
	tp.size = Vector2(325, 112) * ui_scale
	var sp = visuals["suspension_panel"] as Panel
	sp.size = Vector2(205, 158) * ui_scale
	sp.position = Vector2(s.x - margin - sp.size.x, 22 * ui_scale)
	station_label.position = Vector2(s.x * 0.5 - 250 * ui_scale, 24 * ui_scale)
	station_label.size = Vector2(500, 48) * ui_scale

func _set_drive_state(key: String, pressed: bool) -> void:
	if truck == null:
		return
	match key:
		"left": truck.set_left(pressed)
		"right": truck.set_right(pressed)
		"gas": truck.set_gas(pressed)
		"reverse": truck.set_reverse(pressed)
		"handbrake": truck.set_handbrake(pressed)
	if visuals.has(key):
		var visual = visuals[key] as CanvasItem
		visual.modulate = Color(0.72, 0.88, 1.0, 1.0) if pressed else Color.WHITE

func _input(event: InputEvent) -> void:
	# Raw touch fallback. This deliberately bypasses mouse emulation so throttle,
	# steering and handbrake keep working together on Android multitouch screens.
	if event is InputEventScreenTouch:
		if event.pressed:
			for key in ["left", "right", "reverse", "gas", "handbrake"]:
				if touch_rects.has(key) and (touch_rects[key] as Rect2).has_point(event.position):
					active_touch_controls[event.index] = key
					_set_drive_state(key, true)
					get_viewport().set_input_as_handled()
					return
		else:
			if active_touch_controls.has(event.index):
				var key: String = str(active_touch_controls[event.index])
				active_touch_controls.erase(event.index)
				_set_drive_state(key, false)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and active_touch_controls.has(event.index):
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if truck == null:
		return
	var t = truck.telemetry()
	var input_text = ("G" if bool(t["gas"]) else "-") + ("R" if bool(t["reverse"]) else "-")
	speed_label.text = "%d км/ч   •   %s\nRPM %d   •   RWD   •   %d/4 колёс\nРуль %+0.1f°   •   %s" % [
		int(round(float(t["speed_kmh"]))), str(t["gear"]), int(float(t["rpm"])), int(t["grounded"]), float(t["steering_deg"]), input_text
	]
	var susp: Array = t["suspension"]
	for i in range(min(4, susp.size())):
		wheel_bars[i].value = float(susp[i]) * 100.0

func set_station_name(text: String) -> void:
	if station_label != null:
		station_label.text = text
