extends Control
class_name SurvivalHUD

var health := 20.0
var hunger := 20.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func set_vitals(new_health: float, new_hunger: float) -> void:
    health = new_health
    hunger = new_hunger
    queue_redraw()

func _draw() -> void:
    var s := size
    var center := Vector2(s.x * 0.5, s.y * 0.5)
    draw_line(center + Vector2(-9, 0), center + Vector2(9, 0), Color(1, 1, 1, 0.9), 2.0)
    draw_line(center + Vector2(0, -9), center + Vector2(0, 9), Color(1, 1, 1, 0.9), 2.0)

    var base_y := s.y - 103.0
    var left_x := s.x * 0.5 - 294.0
    var right_x := s.x * 0.5 + 94.0
    for i in 10:
        var hp_fill := clampf(health / 2.0 - i, 0.0, 1.0)
        _draw_heart(Vector2(left_x + i * 20.0, base_y), hp_fill)
        var food_fill := clampf(hunger / 2.0 - i, 0.0, 1.0)
        _draw_food(Vector2(right_x + i * 20.0, base_y), food_fill)

func _draw_heart(pos: Vector2, fill: float) -> void:
    var pts := PackedVector2Array([pos + Vector2(0, 5), pos + Vector2(-7, -2), pos + Vector2(-5, -8), pos, pos + Vector2(5, -8), pos + Vector2(7, -2)])
    draw_colored_polygon(pts, Color(0.16, 0.02, 0.02, 0.78))
    if fill > 0.0:
        var inner := PackedVector2Array([pos + Vector2(0, 3), pos + Vector2(-5, -2), pos + Vector2(-4, -6), pos, pos + Vector2(4, -6), pos + Vector2(5, -2)])
        draw_colored_polygon(inner, Color(0.86, 0.12, 0.12, 0.92 if fill >= 1.0 else 0.50))

func _draw_food(pos: Vector2, fill: float) -> void:
    draw_circle(pos, 7.0, Color(0.12, 0.06, 0.02, 0.78))
    if fill > 0.0:
        draw_circle(pos, 5.0, Color(0.82, 0.48, 0.16, 0.92 if fill >= 1.0 else 0.50))
        draw_circle(pos + Vector2(2, -2), 1.5, Color(0.25, 0.10, 0.04, 0.8))
