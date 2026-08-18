extends CharacterBody3D
class_name PlayerController

signal hotbar_changed(slots: Array[Vector2i], selected_slot: int)
signal vitals_changed(health: float, hunger: float)
signal died
signal block_broken(block_id: int)
signal block_placed(block_id: int)
signal footstep(block_id: int)

@export var move_speed := 4.7
@export var sprint_speed := 6.4
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0022
@export var touch_sensitivity := 0.0025
@export var reach := 5.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var world: WorldManager
var inventory := PlayerInventory.new()
var selected_slot := 0
var touch_move := Vector2.ZERO
var queued_touch_look := Vector2.ZERO
var touch_jump_requested := false
var mobile_attack_held := false
var camera := Camera3D.new()

var health := 20.0
var hunger := 20.0
var exhaustion := 0.0
var spawn_position := Vector3.ZERO
var _mine_target := Vector3i(999999, 999999, 999999)
var _mine_progress := 0.0
var _fall_distance := 0.0
var _was_on_floor := false
var _regen_timer := 0.0
var _starve_timer := 0.0
var _attack_cooldown := 0.0
var _last_position := Vector3.ZERO
var _step_timer := 0.0

func setup(target_world: WorldManager) -> void:
    world = target_world

func _ready() -> void:
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.80
    collider.shape = capsule
    add_child(collider)
    camera.position = Vector3(0, 0.70, 0)
    camera.current = true
    camera.fov = 72.0
    add_child(camera)
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    spawn_position = global_position
    _last_position = global_position
    hotbar_changed.emit(inventory.hotbar_snapshot(), selected_slot)
    vitals_changed.emit(health, hunger)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _apply_look(event.relative * mouse_sensitivity)
    elif event.is_action_pressed("place_block"):
        place_target_block()
    elif event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
    var grounded_before := is_on_floor()
    if not grounded_before:
        velocity.y -= gravity * delta
        if velocity.y < 0.0:
            _fall_distance += -velocity.y * delta

    var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var move_input := touch_move if touch_move.length_squared() > keyboard.length_squared() else keyboard
    var direction := (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
    var sprinting := Input.is_action_pressed("sprint") and move_input.y < -0.1 and hunger > 6.0
    var speed := sprint_speed if sprinting else move_speed
    velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
    if (Input.is_action_just_pressed("jump") or touch_jump_requested) and grounded_before:
        velocity.y = jump_velocity
        exhaustion += 0.20 if sprinting else 0.05
    touch_jump_requested = false

    if queued_touch_look != Vector2.ZERO:
        _apply_look(queued_touch_look * touch_sensitivity)
        queued_touch_look = Vector2.ZERO

    _update_mining_and_combat(delta)
    move_and_slide()

    var grounded_after := is_on_floor()
    if grounded_after and not _was_on_floor and _fall_distance > 3.0:
        take_damage(floorf(_fall_distance - 3.0))
    if grounded_after:
        _fall_distance = 0.0
    _was_on_floor = grounded_after

    var horizontal_travel := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
    if horizontal_travel > 0.0:
        exhaustion += horizontal_travel * (0.010 if sprinting else 0.002)
    if grounded_after and horizontal_travel > 0.01:
        _step_timer -= delta
        if _step_timer <= 0.0:
            var under := world.get_block_world(Vector3i(floori(global_position.x), floori(global_position.y - 1.05), floori(global_position.z))) if world != null else 3
            footstep.emit(under)
            _step_timer = 0.31 if sprinting else 0.44
    else:
        _step_timer = minf(_step_timer, 0.08)
    _last_position = global_position
    _update_hunger_and_regen(delta)

func set_touch_move(value: Vector2) -> void:
    touch_move = value.limit_length(1.0)

func add_touch_look(delta: Vector2) -> void:
    queued_touch_look += delta

func request_touch_jump() -> void:
    touch_jump_requested = true

func set_mobile_attack(held: bool) -> void:
    mobile_attack_held = held
    if not held:
        _reset_mining()

func select_hotbar_slot(slot_index: int) -> void:
    selected_slot = clampi(slot_index, 0, PlayerInventory.HOTBAR_SIZE - 1)
    hotbar_changed.emit(inventory.hotbar_snapshot(), selected_slot)

func place_target_block() -> void:
    if world == null:
        return
    var stack := inventory.get_slot(selected_slot)
    if stack.y <= 0:
        return
    var definition := world.registry.get_block(stack.x)
    if definition == null or not definition.placeable:
        return
    var hit := _raycast_world()
    if hit.is_empty():
        return
    if hit.collider != null and hit.collider.has_method("take_damage"):
        return
    var point: Vector3 = hit.position + hit.normal * 0.01
    var pos := Vector3i(floori(point.x), floori(point.y), floori(point.z))
    var player_aabb := AABB(global_position + Vector3(-0.34, -0.90, -0.34), Vector3(0.68, 1.80, 0.68))
    if player_aabb.intersects(AABB(Vector3(pos), Vector3.ONE)):
        return
    if world.set_block_world(pos, stack.x) and inventory.consume_slot(selected_slot, 1):
        block_placed.emit(stack.x)
        hotbar_changed.emit(inventory.hotbar_snapshot(), selected_slot)

func take_damage(amount: float) -> void:
    if amount <= 0.0 or health <= 0.0:
        return
    health = maxf(0.0, health - amount)
    vitals_changed.emit(health, hunger)
    if health <= 0.0:
        _die_and_respawn()

func _update_mining_and_combat(delta: float) -> void:
    var held := mobile_attack_held or Input.is_action_pressed("break_block")
    if not held or world == null:
        _reset_mining()
        return
    var hit := _raycast_world()
    if hit.is_empty():
        _reset_mining()
        return
    var collider: Object = hit.collider
    if collider != null and collider.has_method("take_damage") and not (collider is StaticBody3D):
        _reset_mining()
        if _attack_cooldown <= 0.0:
            collider.take_damage(4.0, self)
            _attack_cooldown = 0.55
            exhaustion += 0.10
        return

    var point: Vector3 = hit.position - hit.normal * 0.01
    var block_pos := Vector3i(floori(point.x), floori(point.y), floori(point.z))
    var block_id := world.get_block_world(block_pos)
    var definition := world.registry.get_block(block_id)
    if block_id == 0 or definition == null or definition.hardness < 0.0:
        _reset_mining()
        return
    if block_pos != _mine_target:
        _mine_target = block_pos
        _mine_progress = 0.0
    var break_time := maxf(0.12, definition.hardness * 0.58)
    _mine_progress += delta / break_time
    if _mine_progress >= 1.0:
        if world.set_block_world(block_pos, 0):
            inventory.add_item(definition.drop_item_id, 1)
            block_broken.emit(block_id)
            hotbar_changed.emit(inventory.hotbar_snapshot(), selected_slot)
            exhaustion += 0.025
        _reset_mining()

func _update_hunger_and_regen(delta: float) -> void:
    var changed := false
    while exhaustion >= 4.0:
        exhaustion -= 4.0
        if hunger > 0.0:
            hunger = maxf(0.0, hunger - 1.0)
            changed = true
    if hunger >= 18.0 and health < 20.0:
        _regen_timer += delta
        if _regen_timer >= 4.0:
            _regen_timer = 0.0
            health = minf(20.0, health + 1.0)
            exhaustion += 1.0
            changed = true
    else:
        _regen_timer = 0.0
    if hunger <= 0.0:
        _starve_timer += delta
        if _starve_timer >= 4.0:
            _starve_timer = 0.0
            take_damage(1.0)
    else:
        _starve_timer = 0.0
    if changed:
        vitals_changed.emit(health, hunger)

func _die_and_respawn() -> void:
    died.emit()
    global_position = spawn_position
    velocity = Vector3.ZERO
    health = 20.0
    hunger = 20.0
    exhaustion = 0.0
    vitals_changed.emit(health, hunger)

func _reset_mining() -> void:
    _mine_target = Vector3i(999999, 999999, 999999)
    _mine_progress = 0.0

func _raycast_world() -> Dictionary:
    if world == null:
        return {}
    var from := camera.global_position
    var to := from + -camera.global_transform.basis.z * reach
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(query)

func _apply_look(delta: Vector2) -> void:
    rotate_y(-delta.x)
    camera.rotation.x = clampf(camera.rotation.x - delta.y, deg_to_rad(-89.0), deg_to_rad(89.0))
