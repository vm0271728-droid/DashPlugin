extends Node3D
class_name WorldManager

@export var world_name := "World 1"
@export var world_seed: int = 123456789
@export_range(2, 12, 1) var render_distance_chunks := 5
@export_range(1, 5, 1) var collision_distance_chunks := 2
@export_range(1, 4, 1) var chunks_generated_per_frame := 1
@export_range(1, 4, 1) var chunks_meshed_per_frame := 1

var generator: TerrainGenerator
var registry: BlockRegistry
var loaded_chunks: Dictionary = {}
var chunk_nodes: Dictionary = {}
var tracking_target: Node3D

var _generation_queue: Array[Vector2i] = []
var _rebuild_queue: Array[Vector2i] = []
var _rebuild_lookup: Dictionary = {}
var _pending_save: Dictionary = {}
var _last_center := Vector2i(99999999, 99999999)
var _stream_timer := 0.0
var _save_timer := 0.0

func _ready() -> void:
    registry = DefaultBlocks.build_registry()
    add_child(registry)
    generator = TerrainGenerator.new(world_seed)
    WorldSave.save_metadata(world_name, world_seed)
    set_process(true)

func set_tracking_target(target: Node3D) -> void:
    tracking_target = target
    _refresh_streaming(true)

func _process(delta: float) -> void:
    _stream_timer += delta
    _save_timer += delta
    if _stream_timer >= 0.12:
        _stream_timer = 0.0
        _refresh_streaming(false)
    _process_generation_queue()
    _process_rebuild_queue()
    if _save_timer >= 1.0:
        _save_timer = 0.0
        _flush_due_saves()

func request_chunk(coord: Vector2i, mesh_immediately: bool = false) -> ChunkData:
    if loaded_chunks.has(coord):
        return loaded_chunks[coord]
    var chunk := WorldSave.load_chunk(world_name, coord)
    if chunk == null:
        chunk = ChunkData.new(coord)
        generator.generate(chunk)
    loaded_chunks[coord] = chunk
    var node := ChunkNode.new()
    chunk_nodes[coord] = node
    add_child(node)
    node.setup(chunk, registry, Callable(self, "get_block_world"))
    if mesh_immediately:
        node.rebuild(true)
    else:
        queue_rebuild(coord)
    for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i(0, -1), Vector2i(0, 1)]:
        if chunk_nodes.has(coord + delta):
            queue_rebuild(coord + delta)
    return chunk

func get_block_world(pos: Vector3i) -> int:
    if pos.y < 0 or pos.y >= ChunkData.SIZE_Y:
        return 0
    var coord := _world_to_chunk(pos.x, pos.z)
    var chunk: ChunkData = loaded_chunks.get(coord)
    if chunk == null:
        return 0
    return chunk.get_block(posmod(pos.x, ChunkData.SIZE_X), pos.y, posmod(pos.z, ChunkData.SIZE_Z))

func set_block_world(pos: Vector3i, id: int) -> bool:
    if pos.y < 0 or pos.y >= ChunkData.SIZE_Y or not registry.has_block(id):
        return false
    var coord := _world_to_chunk(pos.x, pos.z)
    var chunk := request_chunk(coord)
    var lx := posmod(pos.x, ChunkData.SIZE_X)
    var lz := posmod(pos.z, ChunkData.SIZE_Z)
    if chunk.get_block(lx, pos.y, lz) == id:
        return false
    chunk.set_block(lx, pos.y, lz, id)
    queue_rebuild(coord)
    _pending_save[coord] = Time.get_ticks_msec() + 900
    if lx == 0:
        queue_rebuild(coord + Vector2i.LEFT)
    elif lx == ChunkData.SIZE_X - 1:
        queue_rebuild(coord + Vector2i.RIGHT)
    if lz == 0:
        queue_rebuild(coord + Vector2i(0, -1))
    elif lz == ChunkData.SIZE_Z - 1:
        queue_rebuild(coord + Vector2i(0, 1))
    return true

func queue_rebuild(coord: Vector2i) -> void:
    if not chunk_nodes.has(coord) or _rebuild_lookup.has(coord):
        return
    _rebuild_lookup[coord] = true
    _rebuild_queue.append(coord)

func find_surface_y(wx: int, wz: int) -> int:
    var coord := _world_to_chunk(wx, wz)
    var chunk := request_chunk(coord, true)
    var lx := posmod(wx, ChunkData.SIZE_X)
    var lz := posmod(wz, ChunkData.SIZE_Z)
    for y in range(ChunkData.SIZE_Y - 1, -1, -1):
        var id := chunk.get_block(lx, y, lz)
        if id != 0 and id != 12:
            return y
    return 0

func find_surface_y_loaded(wx: int, wz: int) -> int:
    var coord := _world_to_chunk(wx, wz)
    var chunk: ChunkData = loaded_chunks.get(coord)
    if chunk == null:
        return -1
    var lx := posmod(wx, ChunkData.SIZE_X)
    var lz := posmod(wz, ChunkData.SIZE_Z)
    for y in range(ChunkData.SIZE_Y - 1, -1, -1):
        var id := chunk.get_block(lx, y, lz)
        if id != 0 and id != 12:
            return y
    return -1

func _refresh_streaming(force: bool) -> void:
    if tracking_target == null:
        return
    var center := _world_to_chunk(floori(tracking_target.global_position.x), floori(tracking_target.global_position.z))
    if not force and center == _last_center:
        return
    _last_center = center
    var desired: Array[Vector2i] = []
    for dz in range(-render_distance_chunks, render_distance_chunks + 1):
        for dx in range(-render_distance_chunks, render_distance_chunks + 1):
            if dx * dx + dz * dz <= render_distance_chunks * render_distance_chunks:
                desired.append(center + Vector2i(dx, dz))
    desired.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))

    var desired_lookup: Dictionary = {}
    for coord in desired:
        desired_lookup[coord] = true
        if not loaded_chunks.has(coord) and not _generation_queue.has(coord):
            _generation_queue.append(coord)

    var unload_distance := render_distance_chunks + 2
    for coord_variant in loaded_chunks.keys().duplicate():
        var coord: Vector2i = coord_variant
        if coord.distance_squared_to(center) > unload_distance * unload_distance:
            _unload_chunk(coord)

    for coord_variant in chunk_nodes.keys():
        var coord: Vector2i = coord_variant
        var node: ChunkNode = chunk_nodes[coord]
        var should_collide := coord.distance_squared_to(center) <= collision_distance_chunks * collision_distance_chunks
        if node.collision_enabled != should_collide:
            queue_rebuild(coord)

func _process_generation_queue() -> void:
    var budget := chunks_generated_per_frame
    while budget > 0 and not _generation_queue.is_empty():
        var coord: Vector2i = _generation_queue.pop_front()
        if not loaded_chunks.has(coord):
            request_chunk(coord, false)
        budget -= 1

func _process_rebuild_queue() -> void:
    var budget := chunks_meshed_per_frame
    while budget > 0 and not _rebuild_queue.is_empty():
        var coord: Vector2i = _rebuild_queue.pop_front()
        _rebuild_lookup.erase(coord)
        var node: ChunkNode = chunk_nodes.get(coord) as ChunkNode
        if node != null:
            var with_collision := false
            if tracking_target != null:
                var center := _world_to_chunk(floori(tracking_target.global_position.x), floori(tracking_target.global_position.z))
                with_collision = coord.distance_squared_to(center) <= collision_distance_chunks * collision_distance_chunks
            node.rebuild(with_collision)
        budget -= 1

func _unload_chunk(coord: Vector2i) -> void:
    if _pending_save.has(coord):
        var chunk: ChunkData = loaded_chunks.get(coord)
        if chunk != null:
            WorldSave.save_chunk(world_name, chunk)
        _pending_save.erase(coord)
    loaded_chunks.erase(coord)
    _generation_queue.erase(coord)
    _rebuild_lookup.erase(coord)
    _rebuild_queue.erase(coord)
    var node: ChunkNode = chunk_nodes.get(coord) as ChunkNode
    if node != null:
        node.queue_free()
    chunk_nodes.erase(coord)

func _flush_due_saves() -> void:
    var now := Time.get_ticks_msec()
    for coord_variant in _pending_save.keys().duplicate():
        var coord: Vector2i = coord_variant
        if int(_pending_save[coord]) <= now:
            var chunk: ChunkData = loaded_chunks.get(coord)
            if chunk != null:
                WorldSave.save_chunk(world_name, chunk)
            _pending_save.erase(coord)

func _exit_tree() -> void:
    for coord_variant in _pending_save.keys():
        var coord: Vector2i = coord_variant
        var chunk: ChunkData = loaded_chunks.get(coord)
        if chunk != null:
            WorldSave.save_chunk(world_name, chunk)

static func _world_to_chunk(wx: int, wz: int) -> Vector2i:
    return Vector2i(floori(float(wx) / ChunkData.SIZE_X), floori(float(wz) / ChunkData.SIZE_Z))
