extends Node3D

var world: WorldManager
var player: PlayerController
var day_cycle: DayNightCycle
var entity_manager: EntityManager
var audio_manager: AudioManager

func _ready() -> void:
    _ensure_input_actions()

    world = WorldManager.new()
    world.name = "WorldManager"
    add_child(world)
    await get_tree().process_frame

    player = PlayerController.new()
    player.name = "Player"
    player.setup(world)
    var spawn_y := world.find_surface_y(0, 0) + 3
    player.position = Vector3(0.5, spawn_y, 0.5)
    add_child(player)
    world.set_tracking_target(player)

    _create_environment()
    _create_ui()
    _create_audio()
    _create_entities()

func _create_environment() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("78b7ee")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("c6d8e8")
    environment.ambient_light_energy = 0.78
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment_node.environment = environment
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.light_energy = 1.22
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 72.0
    add_child(sun)

    day_cycle = DayNightCycle.new()
    day_cycle.setup(environment, sun)
    add_child(day_cycle)

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var hud := SurvivalHUD.new()
    layer.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    player.vitals_changed.connect(hud.set_vitals)
    hud.set_vitals(player.health, player.hunger)

    var controls := MobileControls.new()
    layer.add_child(controls)
    controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    controls.move_changed.connect(player.set_touch_move)
    controls.look_changed.connect(player.add_touch_look)
    controls.jump_pressed.connect(player.request_touch_jump)
    controls.attack_changed.connect(player.set_mobile_attack)
    controls.place_pressed.connect(player.place_target_block)
    controls.hotbar_selected.connect(player.select_hotbar_slot)
    player.hotbar_changed.connect(controls.set_hotbar)
    controls.set_hotbar(player.inventory.hotbar_snapshot(), player.selected_slot)

func _create_audio() -> void:
    audio_manager = AudioManager.new()
    audio_manager.name = "AudioManager"
    add_child(audio_manager)
    player.block_broken.connect(audio_manager.play_break)
    player.block_placed.connect(audio_manager.play_place)
    player.footstep.connect(audio_manager.play_step)

func _create_entities() -> void:
    entity_manager = EntityManager.new()
    entity_manager.name = "EntityManager"
    add_child(entity_manager)
    entity_manager.setup(world, player, day_cycle)

func _ensure_input_actions() -> void:
    _ensure_key_action(&"move_forward", KEY_W)
    _ensure_key_action(&"move_backward", KEY_S)
    _ensure_key_action(&"move_left", KEY_A)
    _ensure_key_action(&"move_right", KEY_D)
    _ensure_key_action(&"jump", KEY_SPACE)
    _ensure_key_action(&"sprint", KEY_SHIFT)
    _ensure_mouse_action(&"break_block", MOUSE_BUTTON_LEFT)
    _ensure_mouse_action(&"place_block", MOUSE_BUTTON_RIGHT)

func _ensure_key_action(action: StringName, keycode: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).is_empty():
        var event := InputEventKey.new()
        event.physical_keycode = keycode
        InputMap.action_add_event(action, event)

func _ensure_mouse_action(action: StringName, button: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).is_empty():
        var event := InputEventMouseButton.new()
        event.button_index = button
        InputMap.action_add_event(action, event)
