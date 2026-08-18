extends RefCounted
class_name TerrainGenerator

const SEA_LEVEL := 62

var seed: int
var height_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var continental_noise := FastNoiseLite.new()
var moisture_noise := FastNoiseLite.new()
var temperature_noise := FastNoiseLite.new()
var cave_noise := FastNoiseLite.new()
var coal_noise := FastNoiseLite.new()
var iron_noise := FastNoiseLite.new()

func _init(world_seed: int) -> void:
    seed = world_seed
    _setup_noise(height_noise, seed, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0035)
    _setup_noise(detail_noise, seed ^ 0x5EED1234, FastNoiseLite.TYPE_SIMPLEX, 0.025)
    _setup_noise(continental_noise, seed ^ 0x17A2BC91, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0012)
    _setup_noise(moisture_noise, seed ^ 0x33CC7711, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0018)
    _setup_noise(temperature_noise, seed ^ 0x4D19B22F, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0015)
    _setup_noise(cave_noise, seed ^ 0x6A09E667, FastNoiseLite.TYPE_SIMPLEX, 0.035)
    _setup_noise(coal_noise, seed ^ 0x51A3D229, FastNoiseLite.TYPE_SIMPLEX, 0.095)
    _setup_noise(iron_noise, seed ^ 0x2B992DD1, FastNoiseLite.TYPE_SIMPLEX, 0.11)

func generate(chunk: ChunkData) -> void:
    var heights := PackedInt32Array()
    heights.resize(ChunkData.SIZE_X * ChunkData.SIZE_Z)
    var forest_mask := PackedByteArray()
    forest_mask.resize(ChunkData.SIZE_X * ChunkData.SIZE_Z)

    for x in ChunkData.SIZE_X:
        for z in ChunkData.SIZE_Z:
            var wx := chunk.coord.x * ChunkData.SIZE_X + x
            var wz := chunk.coord.y * ChunkData.SIZE_Z + z
            var continental := continental_noise.get_noise_2d(wx, wz)
            var broad := height_noise.get_noise_2d(wx, wz)
            var detail := detail_noise.get_noise_2d(wx, wz)
            var moisture := moisture_noise.get_noise_2d(wx, wz)
            var temperature := temperature_noise.get_noise_2d(wx, wz)
            var mountain_boost := maxf(0.0, continental - 0.25) * 24.0
            var surface_y := clampi(int(round(SEA_LEVEL + continental * 18.0 + broad * 14.0 + detail * 3.5 + mountain_boost)), 5, ChunkData.SIZE_Y - 8)
            heights[x + z * ChunkData.SIZE_X] = surface_y

            var beach := surface_y <= SEA_LEVEL + 2
            var desert := temperature > 0.35 and moisture < -0.18
            var sandy := beach or desert
            forest_mask[x + z * ChunkData.SIZE_X] = 1 if (not sandy and moisture > -0.10 and surface_y > SEA_LEVEL) else 0

            for y in range(surface_y + 1):
                var id := 3
                if y == 0:
                    id = 13
                elif y == surface_y:
                    id = 4 if sandy else 2
                elif y >= surface_y - 3:
                    id = 4 if sandy else 1
                else:
                    id = _stone_variant(wx, y, wz)
                    if y > 18 and y < 58 and _chance(wx, y, wz, 61) < 0.017:
                        id = 14
                if y > 5 and y < surface_y - 4 and _is_cave(wx, y, wz):
                    id = 0
                chunk.set_block(x, y, z, id)

            if surface_y < SEA_LEVEL:
                for y in range(surface_y + 1, SEA_LEVEL + 1):
                    chunk.set_block(x, y, z, 12)

    _add_trees(chunk, heights, forest_mask)
    chunk.dirty = true

func _add_trees(chunk: ChunkData, heights: PackedInt32Array, forest_mask: PackedByteArray) -> void:
    # Keep trunks away from borders until cross-chunk feature placement is introduced.
    for x in range(2, ChunkData.SIZE_X - 2):
        for z in range(2, ChunkData.SIZE_Z - 2):
            var idx := x + z * ChunkData.SIZE_X
            if forest_mask[idx] == 0:
                continue
            var wx := chunk.coord.x * ChunkData.SIZE_X + x
            var wz := chunk.coord.y * ChunkData.SIZE_Z + z
            if _chance(wx, 0, wz, 911) > 0.025:
                continue
            var ground_y := heights[idx]
            var trunk_height := 4 + int(_chance(wx, ground_y, wz, 123) > 0.72)
            if ground_y + trunk_height + 3 >= ChunkData.SIZE_Y:
                continue
            for y in range(ground_y + 1, ground_y + trunk_height + 1):
                chunk.set_block(x, y, z, 5)
            var crown_y := ground_y + trunk_height
            for oy in range(-2, 3):
                var radius := 2 if oy <= 0 else 1
                for ox in range(-radius, radius + 1):
                    for oz in range(-radius, radius + 1):
                        if abs(ox) == radius and abs(oz) == radius and _chance(wx + ox, crown_y + oy, wz + oz, 77) > 0.55:
                            continue
                        var tx := x + ox
                        var ty := crown_y + oy
                        var tz := z + oz
                        if chunk.in_bounds(tx, ty, tz) and chunk.get_block(tx, ty, tz) == 0:
                            chunk.set_block(tx, ty, tz, 6)

func _stone_variant(wx: int, y: int, wz: int) -> int:
    if y < 55 and coal_noise.get_noise_3d(wx, y, wz) > 0.63:
        return 8
    if y < 42 and iron_noise.get_noise_3d(wx, y, wz) > 0.67:
        return 9
    return 3

func _is_cave(wx: int, y: int, wz: int) -> bool:
    var value := absf(cave_noise.get_noise_3d(wx, y * 0.82, wz))
    var depth_factor := clampf((62.0 - y) / 50.0, 0.0, 1.0)
    return value < lerpf(0.035, 0.075, depth_factor)

func _chance(x: int, y: int, z: int, salt: int) -> float:
    var n := int(x * 374761393 + y * 1442695041 + z * 668265263 + seed * 31 + salt * 1013)
    n = (n ^ (n >> 13)) * 1274126177
    n = n ^ (n >> 16)
    return float(abs(n % 100000)) / 100000.0

static func _setup_noise(noise: FastNoiseLite, noise_seed: int, noise_type: int, frequency: float) -> void:
    noise.seed = noise_seed
    noise.noise_type = noise_type
    noise.frequency = frequency
