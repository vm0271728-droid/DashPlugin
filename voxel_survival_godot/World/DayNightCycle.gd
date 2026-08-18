extends Node
class_name DayNightCycle

@export var day_length_seconds := 1200.0
var time_of_day := 0.32
var environment: Environment
var sun: DirectionalLight3D

func setup(target_environment: Environment, target_sun: DirectionalLight3D) -> void:
    environment = target_environment
    sun = target_sun
    set_process(true)
    _apply_lighting()

func _process(delta: float) -> void:
    if environment == null or sun == null:
        return
    time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)
    _apply_lighting()

func is_night() -> bool:
    return time_of_day < 0.22 or time_of_day > 0.78

func _apply_lighting() -> void:
    var angle := time_of_day * TAU - PI * 0.5
    sun.rotation_degrees = Vector3(rad_to_deg(angle), -35.0, 0.0)
    var sun_height := sin(angle)
    var daylight := clampf(sun_height * 1.25 + 0.25, 0.0, 1.0)
    sun.light_energy = lerpf(0.02, 1.22, daylight)
    sun.shadow_enabled = daylight > 0.08
    var night_color := Color("081323")
    var day_color := Color("78b7ee")
    var dusk_color := Color("d78368")
    var horizon := 1.0 - absf(sun_height)
    var sky := night_color.lerp(day_color, daylight)
    if daylight > 0.05 and daylight < 0.55:
        sky = sky.lerp(dusk_color, horizon * 0.28)
    environment.background_color = sky
    environment.ambient_light_color = Color("203044").lerp(Color("c6d8e8"), daylight)
    environment.ambient_light_energy = lerpf(0.24, 0.78, daylight)
