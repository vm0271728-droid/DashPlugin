extends Node
class_name AudioManager

var sfx := AudioStreamPlayer.new()
var _step_index := 0

func _ready() -> void:
    add_child(sfx)
    sfx.volume_db = -5.0

func play_break(block_id: int) -> void:
    if block_id in [1, 2, 4, 5, 6, 10, 14]:
        _play(load("res://Audio/SFX/break_soft.wav"), -3.0, randf_range(0.94, 1.06))
    else:
        _play(load("res://Audio/SFX/break_stone.wav"), -3.0, randf_range(0.92, 1.05))

func play_place(_block_id: int) -> void:
    _play(load("res://Audio/SFX/place.wav"), -5.0, randf_range(0.95, 1.05))

func play_step(block_id: int) -> void:
    var stream := load("res://Audio/SFX/step_grass.wav") if block_id in [1, 2, 4, 5, 6, 10] else load("res://Audio/SFX/step_stone.wav")
    _play(stream, -10.0, randf_range(0.93, 1.07))

func play_ui() -> void:
    _play(load("res://Audio/SFX/ui_click.wav"), -9.0, 1.0)

func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
    if stream == null:
        return
    sfx.stream = stream
    sfx.volume_db = volume_db
    sfx.pitch_scale = pitch
    sfx.play()
