extends CharacterBody3D
class_name BlockMob

var mob_kind := "grazer"
var target: PlayerController
var world: WorldManager
var max_health := 10.0
var health := 10.0
var hostile := false
var move_speed := 1.6
var attack_damage := 2.0
var _wander_direction := Vector3.ZERO
var _wander_timer := 0.0
var _attack_timer := 0.0
var _rng := RandomNumberGenerator.new()

func configure(kind: String, target_player: PlayerController, target_world: WorldManager) -> void:
    mob_kind = kind
    target = target_player
    world = target_world
    match mob_kind:
        "boar":
            max_health = 10.0
            move_speed = 1.55
        "grazer":
            max_health = 12.0
            move_speed = 1.35
        "walker":
            max_health = 16.0
            move_speed = 1.8
            attack_damage = 2.0
            hostile = true
    health = max_health

func _ready() -> void:
    _rng.seed = int(global_position.x * 997.0 + global_position.z * 991.0 + Time.get_ticks_msec())
    _build_body()
    _choose_wander()

func _physics_process(delta: float) -> void:
    _attack_timer = maxf(0.0, _attack_timer - delta)
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    var desired := Vector3.ZERO
    if hostile and is_instance_valid(target):
        var flat := target.global_position - global_position
        flat.y = 0.0
        if flat.length() < 13.0:
            desired = flat.normalized()
            if flat.length() < 1.35 and _attack_timer <= 0.0:
                target.take_damage(attack_damage)
                _attack_timer = 1.15
    if desired == Vector3.ZERO:
        _wander_timer -= delta
        if _wander_timer <= 0.0:
            _choose_wander()
        desired = _wander_direction
    velocity.x = move_toward(velocity.x, desired.x * move_speed, 5.0 * delta)
    velocity.z = move_toward(velocity.z, desired.z * move_speed, 5.0 * delta)
    if desired.length_squared() > 0.05:
        rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1.0, delta * 6.0))
    move_and_slide()

func take_damage(amount: float, attacker: Node = null) -> void:
    health -= amount
    if attacker != null and attacker is Node3D:
        var attacker_3d: Node3D = attacker as Node3D
        var away: Vector3 = global_position - attacker_3d.global_position
        away.y = 0.0
        if away.length_squared() > 0.001:
            away = away.normalized()
            velocity += away * 3.5 + Vector3.UP * 2.2
    if health <= 0.0:
        queue_free()

func _choose_wander() -> void:
    _wander_timer = _rng.randf_range(1.4, 4.8)
    if _rng.randf() < 0.30:
        _wander_direction = Vector3.ZERO
    else:
        var angle := _rng.randf_range(0.0, TAU)
        _wander_direction = Vector3(cos(angle), 0.0, sin(angle))

func _build_body() -> void:
    var collider := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.45
    collider.shape = shape
    collider.position.y = 0.72
    add_child(collider)

    match mob_kind:
        "boar":
            _add_box(Vector3(0, 0.68, 0), Vector3(0.92, 0.62, 1.15), Color("a87460"))
            _add_box(Vector3(0, 0.72, -0.72), Vector3(0.62, 0.55, 0.55), Color("b98570"))
            for x in [-0.30, 0.30]:
                for z in [-0.34, 0.34]:
                    _add_box(Vector3(x, 0.25, z), Vector3(0.18, 0.50, 0.18), Color("6b493e"))
        "walker":
            _add_box(Vector3(0, 1.25, 0), Vector3(0.56, 0.65, 0.34), Color("4f6c58"))
            _add_box(Vector3(0, 1.72, 0), Vector3(0.50, 0.50, 0.50), Color("71836f"))
            _add_box(Vector3(-0.42, 1.22, 0), Vector3(0.20, 0.82, 0.20), Color("60765f"))
            _add_box(Vector3(0.42, 1.22, 0), Vector3(0.20, 0.82, 0.20), Color("60765f"))
            _add_box(Vector3(-0.18, 0.50, 0), Vector3(0.22, 0.95, 0.25), Color("384a46"))
            _add_box(Vector3(0.18, 0.50, 0), Vector3(0.22, 0.95, 0.25), Color("384a46"))
        _:
            _add_box(Vector3(0, 0.76, 0), Vector3(0.98, 0.72, 1.20), Color("8b7d64"))
            _add_box(Vector3(0, 0.95, -0.76), Vector3(0.60, 0.64, 0.58), Color("9c8d71"))
            for x in [-0.31, 0.31]:
                for z in [-0.37, 0.37]:
                    _add_box(Vector3(x, 0.29, z), Vector3(0.18, 0.58, 0.18), Color("554d40"))

func _add_box(pos: Vector3, box_size: Vector3, color: Color) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 1.0
    mesh_instance.material_override = mat
    add_child(mesh_instance)
