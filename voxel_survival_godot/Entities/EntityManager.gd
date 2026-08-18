extends Node3D
class_name EntityManager

@export var max_entities := 14
var world: WorldManager
var player: PlayerController
var day_cycle: DayNightCycle
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()

func setup(target_world: WorldManager, target_player: PlayerController, cycle: DayNightCycle) -> void:
    world = target_world
    player = target_player
    day_cycle = cycle
    _rng.seed = target_world.world_seed ^ 0xA711CE
    set_process(true)

func _process(delta: float) -> void:
    if world == null or player == null:
        return
    _spawn_timer -= delta
    if _spawn_timer > 0.0:
        return
    _spawn_timer = 1.5
    if get_child_count() >= max_entities:
        _despawn_far()
        return
    _try_spawn()

func _try_spawn() -> void:
    var angle := _rng.randf_range(0.0, TAU)
    var distance := _rng.randf_range(12.0, 28.0)
    var wx := floori(player.global_position.x + cos(angle) * distance)
    var wz := floori(player.global_position.z + sin(angle) * distance)
    var y := world.find_surface_y_loaded(wx, wz)
    if y < 0:
        return
    var top_id := world.get_block_world(Vector3i(wx, y, wz))
    if top_id == 12:
        return
    var kind := "walker" if day_cycle != null and day_cycle.is_night() and _rng.randf() < 0.62 else ("boar" if _rng.randf() < 0.48 else "grazer")
    var mob := BlockMob.new()
    mob.configure(kind, player, world)
    mob.position = Vector3(wx + 0.5, y + 1.1, wz + 0.5)
    add_child(mob)

func _despawn_far() -> void:
    for child in get_children():
        if child is Node3D and child.global_position.distance_to(player.global_position) > 48.0:
            child.queue_free()
