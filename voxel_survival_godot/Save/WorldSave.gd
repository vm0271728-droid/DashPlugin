extends RefCounted
class_name WorldSave

const SAVE_VERSION := 3
const REGION_SIZE := 32

static func world_dir(world_name: String) -> String:
    return "user://worlds/%s" % world_name.validate_filename()

static func save_metadata(world_name: String, seed: int) -> Error:
    var dir := world_dir(world_name)
    var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
    if err != OK and err != ERR_ALREADY_EXISTS:
        return err
    var file := FileAccess.open(dir + "/level.json", FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify({"version": SAVE_VERSION, "seed": seed, "world_name": world_name}))
    return OK

static func save_chunk(world_name: String, chunk: ChunkData) -> Error:
    var path := _chunk_path(world_name, chunk.coord)
    var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
    if err != OK and err != ERR_ALREADY_EXISTS:
        return err
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()

    var runs: Array[Vector2i] = []
    if not chunk.blocks.is_empty():
        var current := chunk.blocks[0]
        var count := 1
        for i in range(1, chunk.blocks.size()):
            var value := chunk.blocks[i]
            if value == current and count < 65535:
                count += 1
            else:
                runs.append(Vector2i(current, count))
                current = value
                count = 1
        runs.append(Vector2i(current, count))

    file.store_32(SAVE_VERSION)
    file.store_32(ChunkData.VOLUME)
    file.store_32(runs.size())
    for run in runs:
        file.store_16(run.x)
        file.store_16(run.y)
    return OK

static func load_chunk(world_name: String, coord: Vector2i) -> ChunkData:
    var path := _chunk_path(world_name, coord)
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var version := file.get_32()
    var volume := file.get_32()
    if volume != ChunkData.VOLUME:
        return null
    var chunk := ChunkData.new(coord)
    if version == 2:
        for i in ChunkData.VOLUME:
            chunk.blocks[i] = int(file.get_32())
    elif version == SAVE_VERSION:
        var run_count := file.get_32()
        var cursor := 0
        for _run_i in run_count:
            var id := file.get_16()
            var count := file.get_16()
            for _j in count:
                if cursor >= ChunkData.VOLUME:
                    return null
                chunk.blocks[cursor] = id
                cursor += 1
        if cursor != ChunkData.VOLUME:
            return null
    else:
        return null
    chunk.recompute_max_non_air_y()
    chunk.dirty = false
    return chunk

static func _chunk_path(world_name: String, coord: Vector2i) -> String:
    var rx := floori(float(coord.x) / REGION_SIZE)
    var rz := floori(float(coord.y) / REGION_SIZE)
    return "%s/regions/r.%d.%d/c.%d.%d.vsc" % [world_dir(world_name), rx, rz, coord.x, coord.y]
