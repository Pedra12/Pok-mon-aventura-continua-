extends SceneTree

const MODEL_FILES := [
    "amoonguss.glb",
    "beedrill.glb",
    "diancie_dancing_to_sweet_dreams.glb",
    "flygon_go_fest_2021.glb",
    "hisuian_voltorb.glb",
    "ho_oh.glb",
    "magnemite.glb",
    "pokemon_3ds_celebi.glb",
    "pokemon_basic_pokeball.glb",
    "pokemon_sudowoodo_-_tree.glb",
    "shiny_metagross.glb",
    "smoliv_fully_rigged.glb",
    "squirtle.glb"
]
const OUTPUT_DIR := "res://visual_previews"
const VIEW_SIZE := Vector2i(640, 640)

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var capture_count := 0
var errors: Array[String] = []
var capture_rows: Array[Dictionary] = []
var current_model_diagnostics: Dictionary = {}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _setup_viewport()
    for file_name in MODEL_FILES:
        await _capture_model(file_name)
    var report := {
        "models_requested": MODEL_FILES.size(),
        "captures_created": capture_count,
        "errors": errors,
        "captures": capture_rows
    }
    var report_path := OUTPUT_DIR + "/visual_capture_report.json"
    var report_file := FileAccess.open(report_path, FileAccess.WRITE)
    if report_file:
        report_file.store_string(JSON.stringify(report, "\t"))
        report_file.close()
    else:
        errors.append("Não foi possível gravar visual_capture_report.json")
    print("VISUAL_CAPTURE_SUMMARY ", JSON.stringify(report))
    quit(0 if errors.is_empty() and capture_count >= MODEL_FILES.size() else 1)

func _setup_viewport() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    viewport = SubViewport.new()
    viewport.size = VIEW_SIZE
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    stage = Node3D.new()
    viewport.add_child(stage)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.055, 0.07, 0.10)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.78, 0.82, 0.92)
    environment.ambient_light_energy = 0.9
    environment_node.environment = environment
    stage.add_child(environment_node)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
    key_light.light_energy = 1.45
    stage.add_child(key_light)

    var fill_light := DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-15.0, 145.0, 0.0)
    fill_light.light_energy = 0.45
    stage.add_child(fill_light)

    camera = Camera3D.new()
    camera.current = true
    camera.fov = 38.0
    stage.add_child(camera)

func _capture_model(file_name: String) -> void:
    var packed := load("res://assets/" + file_name) as PackedScene
    if packed == null:
        errors.append(file_name + ": falha ao carregar PackedScene")
        return
    var instance := packed.instantiate() as Node3D
    if instance == null:
        errors.append(file_name + ": instância não é Node3D")
        return

    var wrapper := Node3D.new()
    wrapper.add_child(instance)
    stage.add_child(wrapper)
    await process_frame
    await process_frame

    var bounds := _get_world_bounds(instance)
    if bounds.size.length() < 0.0001:
        bounds = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
    var center := bounds.get_center()
    var radius := maxf(bounds.size.length() * 0.5, 0.05)
    # Enquadramento por esfera envolvente para nao cortar asas e poses largas.
    var distance := radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.45
    camera.position = center + Vector3(radius * 0.22, radius * 0.16, distance)
    camera.look_at(center, Vector3.UP)
    camera.near = maxf(0.005, distance * 0.001)
    camera.far = maxf(100.0, distance + radius * 8.0)
    current_model_diagnostics = {
        "bounds_position": [bounds.position.x, bounds.position.y, bounds.position.z],
        "bounds_size": [bounds.size.x, bounds.size.y, bounds.size.z],
        "bounds_center": [center.x, center.y, center.z],
        "bounds_radius": radius,
        "camera_distance": distance,
        "mesh_stats": _collect_mesh_stats(instance)
    }

    var player := _find_animation_player(instance)
    if player == null or player.get_animation_list().is_empty():
        await _save_capture(file_name, "static", wrapper)
    else:
        var clips := player.get_animation_list()
        for clip_index in clips.size():
            var clip_name: String = clips[clip_index]
            var animation := player.get_animation(clip_name)
            if animation == null:
                errors.append(file_name + "/" + clip_name + ": Animation inválida")
                continue
            player.play(clip_name)
            player.seek(animation.length * 0.5, true)
            await process_frame
            await process_frame
            await _save_capture(file_name, "%02d_%s" % [clip_index + 1, _safe_name(clip_name)], wrapper)

    wrapper.queue_free()
    await process_frame

func _get_world_bounds(node: Node) -> AABB:
    var found := false
    var result := AABB()
    var pending: Array[Node] = [node]
    while not pending.is_empty():
        var current: Node = pending.pop_back()
        if current is MeshInstance3D and current.mesh:
            var box: AABB = current.mesh.get_aabb() * current.global_transform
            if not found:
                result = box
                found = true
            else:
                result = result.merge(box)
        for child in current.get_children():
            pending.append(child)
    return result if found else AABB()

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found:
            return found
    return null

func _save_capture(file_name: String, suffix: String, wrapper: Node3D) -> void:
    await process_frame
    var image := viewport.get_texture().get_image()
    if image.is_empty():
        errors.append(file_name + "/" + suffix + ": viewport retornou imagem vazia")
        return
    var output_name := _safe_name(file_name.get_basename()) + "__" + suffix + ".png"
    var output_path := OUTPUT_DIR + "/" + output_name
    var result := image.save_png(output_path)
    if result != OK:
        errors.append(file_name + "/" + suffix + ": erro ao salvar PNG " + str(result))
        return
    capture_count += 1
    capture_rows.append({
        "file": file_name,
        "capture": suffix,
        "path": output_path,
        "image_size": [image.get_width(), image.get_height()],
        "model_diagnostics": current_model_diagnostics,
        "render_diagnostics": _measure_foreground(image)
    })
    print("VISUAL_CAPTURE_OK ", output_path)

func _safe_name(value: String) -> String:
    var result := value.to_lower()
    for character in [" ", "|", "/", "\\", ":", "*", "?", "\"", "<", ">", "."]:
        result = result.replace(character, "_")
    while result.contains("__"):
        result = result.replace("__", "_")
    return result.strip_edges()

func _collect_mesh_stats(node: Node) -> Dictionary:
    var count := 0
    var visible_count := 0
    var surfaces := 0
    var invalid_meshes := 0
    var pending: Array[Node] = [node]
    while not pending.is_empty():
        var current: Node = pending.pop_back()
        if current is MeshInstance3D:
            count += 1
            if current.visible and current.is_visible_in_tree():
                visible_count += 1
            if current.mesh:
                surfaces += current.mesh.get_surface_count()
            else:
                invalid_meshes += 1
        for child in current.get_children():
            pending.append(child)
    return {
        "mesh_instances": count,
        "visible_mesh_instances": visible_count,
        "surfaces": surfaces,
        "mesh_instances_without_mesh": invalid_meshes
    }

func _measure_foreground(image: Image) -> Dictionary:
    var background := image.get_pixel(0, 0)
    var min_x := image.get_width()
    var min_y := image.get_height()
    var max_x := -1
    var max_y := -1
    var foreground := 0
    for y in image.get_height():
        for x in image.get_width():
            var color := image.get_pixel(x, y)
            if color.distance_to(background) > 0.055:
                foreground += 1
                min_x = mini(min_x, x)
                min_y = mini(min_y, y)
                max_x = maxi(max_x, x)
                max_y = maxi(max_y, y)
    var bbox: Array[int] = []
    if max_x >= min_x and max_y >= min_y:
        bbox = [min_x, min_y, max_x, max_y]
    return {
        "foreground_pixels": foreground,
        "foreground_ratio": float(foreground) / float(image.get_width() * image.get_height()),
        "foreground_bbox": bbox
    }
