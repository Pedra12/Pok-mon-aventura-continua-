extends SceneTree

func _initialize() -> void:
    call_deferred("_run_test")

func _run_test() -> void:
    var project_config := ConfigFile.new()
    var config_error := project_config.load("res://project.godot")
    if config_error != OK:
        push_error("SMOKE_FAIL: project.godot nao carregou")
        quit(1)
        return
    var main_path := str(project_config.get_value("application", "run/main_scene", ""))
    if main_path != "res://Main.tscn":
        push_error("SMOKE_FAIL: projeto nao aponta para Main.tscn: " + main_path)
        quit(1)
        return

    var scene_resource := load(main_path) as PackedScene
    if scene_resource == null:
        push_error("SMOKE_FAIL: cena completa nao carregou: " + main_path)
        quit(1)
        return

    var game := scene_resource.instantiate()
    root.add_child(game)
    for frame in range(12):
        await process_frame
        await physics_frame

    var player_node := game.get("player") as CharacterBody3D
    var camera_node := game.get("camera") as Camera3D
    var creatures: Array = game.get("nearby_pokemon")
    var map_node := game.get_node_or_null("PokemonVillage")

    if not is_instance_valid(player_node):
        push_error("SMOKE_FAIL: treinador nao foi criado")
        quit(1)
        return
    if not is_instance_valid(camera_node) or not camera_node.current:
        push_error("SMOKE_FAIL: camera de terceira pessoa nao esta ativa")
        quit(1)
        return
    if map_node == null:
        push_error("SMOKE_FAIL: mapa original PokemonVillage nao foi instanciado")
        quit(1)
        return

    var map_meshes := _count_meshes(map_node)
    if map_meshes < 10:
        push_error("SMOKE_FAIL: mapa sem geometria suficiente: " + str(map_meshes))
        quit(1)
        return
    if creatures.size() < 3:
        push_error("SMOKE_FAIL: menos de 3 Pokemon foram instanciados: " + str(creatures.size()))
        quit(1)
        return

    var hud_found := false
    for child in game.get_children():
        if child is CanvasLayer:
            hud_found = true
            break
    if not hud_found:
        push_error("SMOKE_FAIL: HUD mobile nao foi criado")
        quit(1)
        return

    var hud_root: Control
    var jump_found := false
    var action_found := false
    for child in game.get_children():
        if child is CanvasLayer:
            for hud_child in child.get_children():
                if hud_child is Control:
                    hud_root = hud_child
                    for control in hud_child.get_children():
                        if control is Button:
                            if control.text == "PULAR":
                                jump_found = true
                            elif control.text == "AÇÃO":
                                action_found = true
                    break
    if hud_root == null or hud_root.mouse_filter != Control.MOUSE_FILTER_IGNORE:
        push_error("SMOKE_FAIL: painel do HUD bloqueia os toques do joystick")
        quit(1)
        return
    if not jump_found or not action_found:
        push_error("SMOKE_FAIL: botoes PULAR/ACAO ausentes")
        quit(1)
        return

    game.set("move_vector", Vector2(0, -1))
    game.call("_physics_process", 0.1)
    if Vector2(player_node.velocity.x, player_node.velocity.z).length() < 0.1:
        push_error("SMOKE_FAIL: joystick nao gera velocidade de movimento")
        quit(1)
        return
    game.set("move_vector", Vector2.ZERO)

    print("GAMEPLAY_SMOKE_OK scene=Main.tscn map_meshes=", map_meshes,
        " trainer=created camera=active pokemon_spawned=", creatures.size(),
        " mobile_hud=created")
    game.queue_free()
    await process_frame
    quit(0)

func _count_meshes(node: Node) -> int:
    var total := 1 if node is MeshInstance3D and node.mesh != null else 0
    for child in node.get_children():
        total += _count_meshes(child)
    return total
