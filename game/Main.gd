extends Node3D

const MAP_PATH := "res://assets/original_pokemon_village.glb"
const PROFILE_PATH := "res://config/pokemon_scale_profiles.json"
const POKEMON_FILES := [
    "amoonguss.glb", "beedrill.glb", "diancie_dancing_to_sweet_dreams.glb",
    "flygon_go_fest_2021.glb", "hisuian_voltorb.glb", "ho_oh.glb",
    "magnemite.glb", "pokemon_3ds_celebi.glb", "shiny_metagross.glb",
    "smoliv_fully_rigged.glb", "squirtle.glb"
]
const POKEMON_NAMES := [
    "Amoonguss", "Beedrill", "Diancie", "Flygon", "Voltorb de Hisui",
    "Ho-Oh", "Magnemite", "Celebi", "Metagross", "Smoliv", "Squirtle"
]

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var move_vector := Vector2.ZERO
var joystick_pointer := -1
var joystick_origin := Vector2.ZERO
var joystick_current := Vector2.ZERO
var touch_look_pointer := -1
var last_look := Vector2.ZERO
var yaw := 0.0
var pitch := -0.24
var joystick_radius := 82.0
var hud_layer: CanvasLayer
var joystick_base: Control
var joystick_knob: Control
var message_label: Label
var pokemon_profiles: Dictionary = {}
var nearby_pokemon: Array[Node3D] = []
var encounter_cooldown := 0.0

func _ready() -> void:
    _load_profiles()
    _build_world()
    _build_player()
    _build_camera()
    _build_hud()
    _spawn_initial_creatures()
    _set_message("Explore a vila. Encontre Pokémon pelo caminho.")

func _load_profiles() -> void:
    if FileAccess.file_exists(PROFILE_PATH):
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
        if parsed is Dictionary:
            pokemon_profiles = parsed.get("pokemon", {})

func _build_world() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.12, 0.30, 0.48)
    sky_mat.sky_horizon_color = Color(0.62, 0.76, 0.82)
    sky_mat.ground_bottom_color = Color(0.10, 0.12, 0.10)
    sky_mat.ground_horizon_color = Color(0.42, 0.48, 0.38)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env_node.environment = env
    add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

    if ResourceLoader.exists(MAP_PATH):
        var map_scene := load(MAP_PATH) as PackedScene
        if map_scene:
            var map_root := map_scene.instantiate()
            map_root.name = "PokemonVillage"
            add_child(map_root)
            _create_map_collisions(map_root)
    else:
        _set_message("ERRO: mapa original nao encontrado.")

func _create_map_collisions(root_node: Node) -> void:
    var meshes: Array[MeshInstance3D] = []
    var pending: Array[Node] = [root_node]
    while not pending.is_empty():
        var current: Node = pending.pop_back()
        if current is MeshInstance3D and current.mesh:
            meshes.append(current)
        for child in current.get_children():
            pending.append(child)
    var collision_count := 0
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var trimesh_shape := mesh_instance.mesh.create_trimesh_shape()
        if trimesh_shape == null:
            continue
        var body := StaticBody3D.new()
        body.name = "WorldCollision_" + str(collision_count + 1)
        var collision := CollisionShape3D.new()
        collision.shape = trimesh_shape
        body.add_child(collision)
        root_node.add_child(body)
        body.global_transform = mesh_instance.global_transform
        collision_count += 1
    print("MAP_COLLISION_MESHES ", collision_count, "/", meshes.size())

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Trainer"
    player.position = Vector3(0, 4, 0)
    player.floor_snap_length = 0.35
    player.floor_max_angle = deg_to_rad(48)
    add_child(player)

    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.72
    var body_mesh := MeshInstance3D.new()
    body_mesh.mesh = capsule
    body_mesh.position.y = 0.86
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.12, 0.32, 0.72)
    body_mat.roughness = 0.78
    body_mesh.material_override = body_mat
    player.add_child(body_mesh)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.24
    head_mesh.height = 0.48
    head.mesh = head_mesh
    head.position.y = 1.72
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.82, 0.62, 0.46)
    head.material_override = skin
    player.add_child(head)

    var shape := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.radius = 0.30
    capsule_shape.height = 1.65
    shape.shape = capsule_shape
    shape.position.y = 0.83
    player.add_child(shape)

func _build_camera() -> void:
    camera_pivot = Node3D.new()
    camera_pivot.position = player.global_position + Vector3(0, 1.45, 0)
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 2.0, 5.5)
    camera.current = true
    camera_pivot.add_child(camera)
    camera_pivot.rotation.x = pitch

func _build_hud() -> void:
    hud_layer = CanvasLayer.new()
    add_child(hud_layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud_layer.add_child(root)

    joystick_base = _make_circle_control(176, Color(0.05, 0.08, 0.12, 0.48))
    joystick_base.position = Vector2(38, 0)
    joystick_base.anchor_top = 1.0
    joystick_base.anchor_bottom = 1.0
    joystick_base.position.y = -214
    root.add_child(joystick_base)
    joystick_knob = _make_circle_control(76, Color(0.72, 0.82, 0.92, 0.78))
    joystick_knob.position = Vector2(50, 50)
    joystick_base.add_child(joystick_knob)

    var jump_button := _make_action_button("PULAR", Vector2(-112, -150), Vector2(96, 96), root)
    jump_button.pressed.connect(_jump)
    var interact_button := _make_action_button("AÇÃO", Vector2(-112, -260), Vector2(96, 96), root)
    interact_button.pressed.connect(_interact)
    var center_button := _make_action_button("CENTRO", Vector2(18, -106), Vector2(82, 82), root)
    center_button.pressed.connect(_recenter_camera)

    message_label = Label.new()
    message_label.position = Vector2(20, 18)
    message_label.size = Vector2(650, 48)
    message_label.add_theme_font_size_override("font_size", 22)
    message_label.add_theme_color_override("font_color", Color(1, 1, 1))
    message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
    message_label.add_theme_constant_override("shadow_offset_x", 2)
    message_label.add_theme_constant_override("shadow_offset_y", 2)
    root.add_child(message_label)

    var hint := Label.new()
    hint.text = "Arraste o lado direito para girar a câmera"
    hint.anchor_left = 0.5
    hint.anchor_right = 1.0
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_left = 0
    hint.offset_top = -42
    hint.offset_right = -18
    hint.offset_bottom = -12
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
    root.add_child(hint)

func _make_circle_control(diameter: float, color: Color) -> Control:
    var control := Control.new()
    control.custom_minimum_size = Vector2(diameter, diameter)
    control.size = Vector2(diameter, diameter)
    control.draw.connect(func():
        control.draw_circle(Vector2(diameter * 0.5, diameter * 0.5), diameter * 0.5, color)
    )
    control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return control

func _make_action_button(text_value: String, offset: Vector2, dimensions: Vector2, parent: Control) -> Button:
    var button := Button.new()
    button.text = text_value
    button.size = dimensions
    button.anchor_left = 1.0
    button.anchor_right = 1.0
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.position = offset
    button.add_theme_font_size_override("font_size", 18)
    parent.add_child(button)
    return button

func _spawn_initial_creatures() -> void:
    var spawn_positions := [
        Vector3(7, 0, -5), Vector3(-8, 0, -8), Vector3(13, 0, 9),
        Vector3(-15, 0, 10), Vector3(22, 0, -14), Vector3(-24, 0, -18)
    ]
    var chosen := [0, 10, 4, 9, 6, 2]
    for i in chosen.size():
        var file_name: String = POKEMON_FILES[chosen[i]]
        var full_path := "res://assets/" + file_name
        if not ResourceLoader.exists(full_path):
            continue
        var packed := load(full_path) as PackedScene
        if packed == null:
            continue
        var instance := packed.instantiate() as Node3D
        if instance == null:
            continue
        var wrapper := Node3D.new()
        wrapper.name = POKEMON_NAMES[chosen[i]]
        wrapper.add_child(instance)
        var profile: Dictionary = pokemon_profiles.get(file_name, {})
        var scale_value := float(profile.get("uniform_scale", 1.0))
        wrapper.scale = Vector3.ONE * scale_value
        var offset_data: Array = profile.get("visual_offset", [0.0, 0.0, 0.0])
        if offset_data.size() == 3:
            wrapper.position = Vector3(float(offset_data[0]), float(offset_data[1]), float(offset_data[2]))
        var creature := Node3D.new()
        creature.add_child(wrapper)
        creature.position = spawn_positions[i]
        add_child(creature)
        var animation_player := _find_animation_player(instance)
        if animation_player:
            var clips := animation_player.get_animation_list()
            if not clips.is_empty():
                animation_player.play(clips[0])
        nearby_pokemon.append(creature)

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found:
            return found
    return null

func _physics_process(delta: float) -> void:
    encounter_cooldown = maxf(0.0, encounter_cooldown - delta)
    if camera_pivot and player:
        camera_pivot.global_position = player.global_position + Vector3(0, 1.45, 0)
    var direction := Vector3(move_vector.x, 0, move_vector.y)
    direction = camera_pivot.global_transform.basis * direction
    direction.y = 0
    direction = direction.normalized()
    var speed := 4.5
    if direction.length() > 0.01:
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 12.0)
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, 18.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, 18.0 * delta)
    if not player.is_on_floor():
        player.velocity.y -= 9.8 * delta
    player.move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    # A interface processa os botoes antes deste metodo. Toques nos botoes
    # nao podem iniciar o controle de camera.
    var viewport_size := get_viewport().get_visible_rect().size
    var camera_area_bottom := viewport_size.y * 0.60

    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < viewport_size.x * 0.48 and event.position.y > viewport_size.y * 0.45:
                joystick_pointer = event.index
                joystick_origin = event.position
                joystick_current = event.position
                _update_joystick()
            elif event.position.x >= viewport_size.x * 0.48 and event.position.y < camera_area_bottom:
                touch_look_pointer = event.index
                last_look = event.position
        else:
            if event.index == joystick_pointer:
                joystick_pointer = -1
                move_vector = Vector2.ZERO
                _reset_joystick()
            if event.index == touch_look_pointer:
                touch_look_pointer = -1

    elif event is InputEventScreenDrag:
        if event.index == joystick_pointer:
            joystick_current = event.position
            _update_joystick()
        elif event.index == touch_look_pointer:
            var look_delta: Vector2 = event.position - last_look
            last_look = event.position
            _rotate_camera(look_delta)

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and event.position.x >= viewport_size.x * 0.48 and event.position.y < camera_area_bottom:
            touch_look_pointer = 999
            last_look = event.position
        elif not event.pressed:
            touch_look_pointer = -1

    elif event is InputEventMouseMotion and touch_look_pointer == 999:
        var mouse_delta: Vector2 = event.position - last_look
        last_look = event.position
        _rotate_camera(mouse_delta)

func _update_joystick() -> void:
    var joy_delta: Vector2 = joystick_current - joystick_origin
    if joy_delta.length() > joystick_radius:
        joy_delta = joy_delta.normalized() * joystick_radius
    move_vector = Vector2(joy_delta.x, joy_delta.y) / joystick_radius
    var local: Vector2 = joystick_base.to_local(joystick_origin)
    joystick_knob.position = local + joy_delta - joystick_knob.size * 0.5

func _reset_joystick() -> void:
    joystick_knob.position = Vector2(50, 50)

func _rotate_camera(delta: Vector2) -> void:
    yaw -= delta.x * 0.006
    pitch = clampf(pitch - delta.y * 0.004, -0.85, 0.25)
    camera_pivot.rotation = Vector3(pitch, yaw, 0)

func _jump() -> void:
    if player and player.is_on_floor():
        player.velocity.y = 5.2

func _interact() -> void:
    var nearest: Node3D
    var nearest_distance := 5.0
    for creature in nearby_pokemon:
        if not is_instance_valid(creature):
            continue
        var distance := player.global_position.distance_to(creature.global_position)
        if distance < nearest_distance:
            nearest = creature
            nearest_distance = distance
    if nearest:
        _set_message("Você encontrou " + nearest.name + "!")
    else:
        _set_message("Nenhum Pokémon por perto. Continue explorando.")

func _recenter_camera() -> void:
    yaw = 0.0
    pitch = -0.24
    camera_pivot.rotation = Vector3(pitch, yaw, 0)

func _set_message(value: String) -> void:
    if message_label:
        message_label.text = value
    else:
        print(value)
