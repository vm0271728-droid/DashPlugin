extends Node3D
class_name ChunkNode

var data: ChunkData
var registry: BlockRegistry
var world_getter: Callable
var collision_enabled := false

var mesh_instance := MeshInstance3D.new()
var static_body := StaticBody3D.new()
var collision_shape := CollisionShape3D.new()

static var shared_material: ShaderMaterial

func setup(chunk_data: ChunkData, block_registry: BlockRegistry, getter: Callable) -> void:
    data = chunk_data
    registry = block_registry
    world_getter = getter
    position = Vector3(data.coord.x * ChunkData.SIZE_X, 0, data.coord.y * ChunkData.SIZE_Z)
    name = "Chunk_%d_%d" % [data.coord.x, data.coord.y]
    add_child(mesh_instance)
    add_child(static_body)
    static_body.add_child(collision_shape)
    if shared_material == null:
        shared_material = ShaderMaterial.new()
        shared_material.shader = load("res://Shaders/voxel_atlas.gdshader")
        shared_material.set_shader_parameter("atlas", load("res://Assets/block_atlas.png"))

func rebuild(with_collision: bool) -> void:
    if data == null:
        return
    collision_enabled = with_collision
    var built := ChunkMesher.build(data, registry, world_getter, with_collision)
    if built.mesh.get_surface_count() > 0:
        built.mesh.surface_set_material(0, shared_material)
    mesh_instance.mesh = built.mesh
    if not with_collision or built.collision_faces.is_empty():
        collision_shape.shape = null
    else:
        var shape := ConcavePolygonShape3D.new()
        shape.backface_collision = false
        shape.set_faces(built.collision_faces)
        collision_shape.shape = shape
    data.dirty = false
