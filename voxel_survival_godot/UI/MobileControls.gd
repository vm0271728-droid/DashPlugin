extends Control
class_name MobileControls

signal move_changed(value: Vector2)
signal look_changed(delta: Vector2)
signal jump_pressed
signal attack_changed(held: bool)
signal place_pressed
signal hotbar_selected(slot_index: int)

var move_touch := -1
var look_touch := -1
var attack_touch := -1
var move_origin := Vector2.ZERO
var move_current := Vector2.ZERO
var selected_slot := 0
var hotbar_slots: Array[Vector2i] = []

const JOYSTICK_RADIUS := 105.0
const HOTBAR_SLOT := 62.0
const HOTBAR_GAP := 4.0

func _ready() -> void:
    set_process_input(true)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    hotbar_slots.resize(9)
    for i in 9:
        hotbar_slots[i] = Vector2i.ZERO
    queue_redraw()

func set_hotbar(slots: Array[Vector2i], selected: int) -> void:
    hotbar_slots.clear()
    for stack in slots:
        hotbar_slots.append(stack)
    selected_slot = clampi(selected, 0, 8)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_down(event.index, event.position)
        else:
            _touch_up(event.index)
    elif event is InputEventScreenDrag:
        _touch_drag(event.index, event.position, event.relative)

func _touch_down(index: int, pos: Vector2) -> void:
    var s := size
    var slot := _hotbar_slot_at(pos, s)
    if slot >= 0:
        selected_slot = slot
        hotbar_selected.emit(slot)
        queue_redraw()
        return
    if _jump_rect(s).has_point(pos):
        jump_pressed.emit()
        return
    if _attack_rect(s).has_point(pos) and attack_touch == -1:
        attack_touch = index
        attack_changed.emit(true)
        return
    if _place_rect(s).has_point(pos):
        place_pressed.emit()
        return
    if pos.x < s.x * 0.46 and move_touch == -1:
        move_touch = index
        move_origin = pos
        move_current = pos
        move_changed.emit(Vector2.ZERO)
        queue_redraw()
    elif look_touch == -1:
        look_touch = index

func _touch_up(index: int) -> void:
    if index == move_touch:
        move_touch = -1
        move_changed.emit(Vector2.ZERO)
        queue_redraw()
    if index == look_touch:
        look_touch = -1
    if index == attack_touch:
        attack_touch = -1
        attack_changed.emit(false)
        queue_redraw()

func _touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
    if index == move_touch:
        move_current = move_origin + (pos - move_origin).limit_length(JOYSTICK_RADIUS)
        var delta := (move_current - move_origin) / JOYSTICK_RADIUS
        move_changed.emit(Vector2(delta.x, delta.y))
        queue_redraw()
    elif index == look_touch:
        look_changed.emit(relative)

func _draw() -> void:
    var s := size
    if move_touch != -1:
        draw_circle(move_origin, JOYSTICK_RADIUS, Color(0.0, 0.0, 0.0, 0.24))
        draw_circle(move_current, 38.0, Color(1.0, 1.0, 1.0, 0.34))
        draw_arc(move_origin, JOYSTICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 3.0)

    _draw_action_button(_jump_rect(s), 0)
    _draw_action_button(_attack_rect(s), 1)
    _draw_action_button(_place_rect(s), 2)
    _draw_hotbar(s)

func _draw_action_button(rect: Rect2, kind: int) -> void:
    var center := rect.get_center()
    var radius := rect.size.x * 0.5
    draw_circle(center, radius, Color(0, 0, 0, 0.28))
    draw_arc(center, radius - 2.0, 0.0, TAU, 32, Color(1, 1, 1, 0.30), 2.0)
    if kind == 0:
        var pts := PackedVector2Array([center + Vector2(0, -22), center + Vector2(-17, 2), center + Vector2(-7, 2), center + Vector2(-7, 19), center + Vector2(7, 19), center + Vector2(7, 2), center + Vector2(17, 2)])
        draw_colored_polygon(pts, Color(1, 1, 1, 0.72))
    elif kind == 1:
        draw_line(center + Vector2(-19, 19), center + Vector2(16, -16), Color(1, 1, 1, 0.75), 6.0)
        draw_line(center + Vector2(7, -20), center + Vector2(21, -6), Color(1, 1, 1, 0.75), 6.0)
        draw_line(center + Vector2(-22, 8), center + Vector2(-8, 22), Color(1, 1, 1, 0.75), 6.0)
    else:
        var cube := Rect2(center - Vector2(17, 17), Vector2(34, 34))
        draw_rect(cube, Color(1, 1, 1, 0.12), true)
        draw_rect(cube, Color(1, 1, 1, 0.75), false, 3.0)

func _draw_hotbar(s: Vector2) -> void:
    var total_width := 9.0 * HOTBAR_SLOT + 8.0 * HOTBAR_GAP
    var start := Vector2((s.x - total_width) * 0.5, s.y - HOTBAR_SLOT - 20.0)
    for i in 9:
        var rect := Rect2(start + Vector2(i * (HOTBAR_SLOT + HOTBAR_GAP), 0), Vector2(HOTBAR_SLOT, HOTBAR_SLOT))
        draw_rect(rect, Color(0.03, 0.03, 0.03, 0.55), true)
        draw_rect(rect, Color(1, 1, 1, 0.78 if i == selected_slot else 0.25), false, 4.0 if i == selected_slot else 2.0)
        var stack := hotbar_slots[i] if i < hotbar_slots.size() else Vector2i.ZERO
        if stack.y > 0:
            var c := _item_color(stack.x)
            draw_rect(rect.grow(-14.0), c, true)
            draw_rect(rect.grow(-14.0), Color(0, 0, 0, 0.38), false, 2.0)
            var font := ThemeDB.fallback_font
            var label := str(stack.y)
            var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
            draw_string(font, rect.end - Vector2(text_size.x + 5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _hotbar_slot_at(pos: Vector2, s: Vector2) -> int:
    var total_width := 9.0 * HOTBAR_SLOT + 8.0 * HOTBAR_GAP
    var start := Vector2((s.x - total_width) * 0.5, s.y - HOTBAR_SLOT - 20.0)
    for i in 9:
        var rect := Rect2(start + Vector2(i * (HOTBAR_SLOT + HOTBAR_GAP), 0), Vector2(HOTBAR_SLOT, HOTBAR_SLOT))
        if rect.has_point(pos):
            return i
    return -1

static func _item_color(id: int) -> Color:
    match id:
        1: return Color("795548")
        2: return Color("6f9f45")
        3: return Color("777777")
        4: return Color("d7c58c")
        5: return Color("8a6137")
        6: return Color("4f7e39")
        7: return Color("686868")
        8: return Color("454545")
        9: return Color("947966")
        10: return Color("b9834f")
        11: return Color("cfe8e8")
        14: return Color("817b75")
        _: return Color("cccccc")

static func _jump_rect(s: Vector2) -> Rect2:
    return Rect2(s.x - 142, s.y - 190, 98, 98)

static func _attack_rect(s: Vector2) -> Rect2:
    return Rect2(s.x - 270, s.y - 302, 88, 88)

static func _place_rect(s: Vector2) -> Rect2:
    return Rect2(s.x - 150, s.y - 320, 88, 88)
