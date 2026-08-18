extends RefCounted
class_name ChunkMesher

const ATLAS_COLUMNS := 4

class MeshBuildResult:
    var mesh: ArrayMesh
    var collision_faces := PackedVector3Array()
    var quad_count: int = 0
    var vertex_count: int = 0

static func build(chunk: ChunkData, registry: BlockRegistry, world_getter: Callable, build_collision: bool = true) -> MeshBuildResult:
    var result := MeshBuildResult.new()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    _mesh_horizontal(chunk, registry, world_getter, st, result, true, build_collision)
    _mesh_horizontal(chunk, registry, world_getter, st, result, false, build_collision)
    _mesh_x_sides(chunk, registry, world_getter, st, result, true, build_collision)
    _mesh_x_sides(chunk, registry, world_getter, st, result, false, build_collision)
    _mesh_z_sides(chunk, registry, world_getter, st, result, true, build_collision)
    _mesh_z_sides(chunk, registry, world_getter, st, result, false, build_collision)

    result.mesh = st.commit() if result.vertex_count > 0 else ArrayMesh.new()
    return result

static func _mesh_horizontal(chunk: ChunkData, registry: BlockRegistry, world_getter: Callable, st: SurfaceTool, result: MeshBuildResult, top: bool, build_collision: bool) -> void:
    var width := ChunkData.SIZE_X
    var height := ChunkData.SIZE_Z
    for y in mini(ChunkData.SIZE_Y, chunk.max_non_air_y + 2):
        var mask := PackedInt32Array()
        mask.resize(width * height)
        for z in height:
            for x in width:
                var id := chunk.get_block(x, y, z)
                if id == 0:
                    continue
                var neighbor_y := y + (1 if top else -1)
                if _face_visible(chunk, registry, world_getter, x, neighbor_y, z, id):
                    mask[x + z * width] = id
        for rect in _extract_rectangles(mask, width, height):
            var x0: int = rect[0]
            var z0: int = rect[1]
            var rw: int = rect[2]
            var rh: int = rect[3]
            var id: int = rect[4]
            var plane_y := float(y + 1 if top else y)
            if top:
                _add_quad(st, result, registry, id, Vector3.UP,
                    Vector3(x0, plane_y, z0), Vector3(x0, plane_y, z0 + rh),
                    Vector3(x0 + rw, plane_y, z0 + rh), Vector3(x0 + rw, plane_y, z0), build_collision)
            else:
                _add_quad(st, result, registry, id, Vector3.DOWN,
                    Vector3(x0, plane_y, z0), Vector3(x0 + rw, plane_y, z0),
                    Vector3(x0 + rw, plane_y, z0 + rh), Vector3(x0, plane_y, z0 + rh), build_collision)

static func _mesh_x_sides(chunk: ChunkData, registry: BlockRegistry, world_getter: Callable, st: SurfaceTool, result: MeshBuildResult, positive: bool, build_collision: bool) -> void:
    var width := ChunkData.SIZE_Z
    var height := mini(ChunkData.SIZE_Y, chunk.max_non_air_y + 2)
    for x in ChunkData.SIZE_X:
        var mask := PackedInt32Array()
        mask.resize(width * height)
        for y in height:
            for z in width:
                var id := chunk.get_block(x, y, z)
                if id == 0:
                    continue
                var neighbor_x := x + (1 if positive else -1)
                if _face_visible(chunk, registry, world_getter, neighbor_x, y, z, id):
                    mask[z + y * width] = id
        for rect in _extract_rectangles(mask, width, height):
            var z0: int = rect[0]
            var y0: int = rect[1]
            var rw: int = rect[2]
            var rh: int = rect[3]
            var id: int = rect[4]
            var plane_x := float(x + 1 if positive else x)
            if positive:
                _add_quad(st, result, registry, id, Vector3.RIGHT,
                    Vector3(plane_x, y0, z0), Vector3(plane_x, y0 + rh, z0),
                    Vector3(plane_x, y0 + rh, z0 + rw), Vector3(plane_x, y0, z0 + rw), build_collision)
            else:
                _add_quad(st, result, registry, id, Vector3.LEFT,
                    Vector3(plane_x, y0, z0), Vector3(plane_x, y0, z0 + rw),
                    Vector3(plane_x, y0 + rh, z0 + rw), Vector3(plane_x, y0 + rh, z0), build_collision)

static func _mesh_z_sides(chunk: ChunkData, registry: BlockRegistry, world_getter: Callable, st: SurfaceTool, result: MeshBuildResult, positive: bool, build_collision: bool) -> void:
    var width := ChunkData.SIZE_X
    var height := mini(ChunkData.SIZE_Y, chunk.max_non_air_y + 2)
    for z in ChunkData.SIZE_Z:
        var mask := PackedInt32Array()
        mask.resize(width * height)
        for y in height:
            for x in width:
                var id := chunk.get_block(x, y, z)
                if id == 0:
                    continue
                var neighbor_z := z + (1 if positive else -1)
                if _face_visible(chunk, registry, world_getter, x, y, neighbor_z, id):
                    mask[x + y * width] = id
        for rect in _extract_rectangles(mask, width, height):
            var x0: int = rect[0]
            var y0: int = rect[1]
            var rw: int = rect[2]
            var rh: int = rect[3]
            var id: int = rect[4]
            var plane_z := float(z + 1 if positive else z)
            if positive:
                _add_quad(st, result, registry, id, Vector3.BACK,
                    Vector3(x0, y0, plane_z), Vector3(x0 + rw, y0, plane_z),
                    Vector3(x0 + rw, y0 + rh, plane_z), Vector3(x0, y0 + rh, plane_z), build_collision)
            else:
                _add_quad(st, result, registry, id, Vector3.FORWARD,
                    Vector3(x0, y0, plane_z), Vector3(x0, y0 + rh, plane_z),
                    Vector3(x0 + rw, y0 + rh, plane_z), Vector3(x0 + rw, y0, plane_z), build_collision)

static func _face_visible(chunk: ChunkData, registry: BlockRegistry, world_getter: Callable, lx: int, ly: int, lz: int, current_id: int) -> bool:
    var neighbor_id: int
    if chunk.in_bounds(lx, ly, lz):
        neighbor_id = chunk.get_block(lx, ly, lz)
    else:
        var wx := chunk.coord.x * ChunkData.SIZE_X + lx
        var wz := chunk.coord.y * ChunkData.SIZE_Z + lz
        neighbor_id = world_getter.call(Vector3i(wx, ly, wz))
    if neighbor_id == 0:
        return true
    var current := registry.get_block(current_id)
    var neighbor := registry.get_block(neighbor_id)
    if neighbor == null:
        return true
    if current != null and current.transparent and neighbor_id == current_id:
        return false
    return neighbor.transparent and (current == null or not current.transparent)

static func _extract_rectangles(mask: PackedInt32Array, width: int, height: int) -> Array:
    var rects: Array = []
    for v in height:
        var u := 0
        while u < width:
            var id := mask[u + v * width]
            if id == 0:
                u += 1
                continue
            var rw := 1
            while u + rw < width and mask[u + rw + v * width] == id:
                rw += 1
            var rh := 1
            var can_extend := true
            while v + rh < height and can_extend:
                for check_u in range(u, u + rw):
                    if mask[check_u + (v + rh) * width] != id:
                        can_extend = false
                        break
                if can_extend:
                    rh += 1
            for clear_v in range(v, v + rh):
                for clear_u in range(u, u + rw):
                    mask[clear_u + clear_v * width] = 0
            rects.append([u, v, rw, rh, id])
            u += rw
    return rects

static func _add_quad(st: SurfaceTool, result: MeshBuildResult, registry: BlockRegistry, id: int, normal: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3, build_collision: bool) -> void:
    var definition := registry.get_block(id)
    var tile := definition.tile_for_normal(normal) if definition != null else 0
    var tile_uv := Vector2(float(tile % ATLAS_COLUMNS), float(tile / ATLAS_COLUMNS))
    var u_len := maxf(1.0, a.distance_to(d))
    var v_len := maxf(1.0, a.distance_to(b))
    var uvs := [Vector2(0, 0), Vector2(0, v_len), Vector2(u_len, v_len), Vector2(u_len, 0)]
    var vertices := [a, b, c, d]
    var base := result.vertex_count
    for i in 4:
        st.set_normal(normal)
        st.set_uv(uvs[i])
        st.set_uv2(tile_uv)
        st.add_vertex(vertices[i])
    st.add_index(base)
    st.add_index(base + 2)
    st.add_index(base + 1)
    st.add_index(base)
    st.add_index(base + 3)
    st.add_index(base + 2)
    if build_collision and definition != null and definition.has_collision:
        result.collision_faces.append_array(PackedVector3Array([a, b, c, a, c, d]))
    result.vertex_count += 4
    result.quad_count += 1
