extends RefCounted
class_name ChunkData

const SIZE_X := 16
const SIZE_Z := 16
const SIZE_Y := 128
const VOLUME := SIZE_X * SIZE_Y * SIZE_Z

var coord := Vector2i.ZERO
var blocks := PackedInt32Array()
var sky_light := PackedByteArray()
var block_light := PackedByteArray()
var dirty := true
var max_non_air_y := 0

func _init(chunk_coord := Vector2i.ZERO) -> void:
    coord = chunk_coord
    blocks.resize(VOLUME)
    sky_light.resize(VOLUME)
    block_light.resize(VOLUME)

static func index(x: int, y: int, z: int) -> int:
    return x + SIZE_X * (z + SIZE_Z * y)

func in_bounds(x: int, y: int, z: int) -> bool:
    return x >= 0 and x < SIZE_X and y >= 0 and y < SIZE_Y and z >= 0 and z < SIZE_Z

func get_block(x: int, y: int, z: int) -> int:
    if not in_bounds(x, y, z):
        return 0
    return blocks[index(x, y, z)]

func set_block(x: int, y: int, z: int, id: int) -> void:
    if not in_bounds(x, y, z):
        return
    blocks[index(x, y, z)] = id
    if id != 0 and y > max_non_air_y:
        max_non_air_y = y
    dirty = true

func recompute_max_non_air_y() -> void:
    max_non_air_y = 0
    for y in range(SIZE_Y - 1, -1, -1):
        var found := false
        for z in SIZE_Z:
            for x in SIZE_X:
                if get_block(x, y, z) != 0:
                    max_non_air_y = y
                    found = true
                    break
            if found:
                break
        if found:
            return
