extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene_resource := load("res://main.tscn") as PackedScene
	if scene_resource == null:
		push_error("SMOKE_FAIL: res://main.tscn nao carregou")
		quit(1)
		return

	var game := scene_resource.instantiate()
	if game == null:
		push_error("SMOKE_FAIL: instancia da cena principal falhou")
		quit(1)
		return

	root.add_child(game)
	for frame in range(8):
		await process_frame
		await physics_frame

	var player_node := game.get("player") as CharacterBody3D
	var pokemon_node := game.get("pokemon") as Node3D
	if not is_instance_valid(player_node):
		push_error("SMOKE_FAIL: jogador nao foi criado")
		quit(1)
		return
	if not is_instance_valid(pokemon_node):
		push_error("SMOKE_FAIL: Squirtle nao foi carregado pela cena")
		quit(1)
		return

	var map_node: Node
	for child in game.get_children():
		if child is Node3D and not (child is CharacterBody3D) and _count_meshes(child) > 0:
			map_node = child
			break
	if map_node == null:
		push_error("SMOKE_FAIL: mapa original nao foi instanciado na cena")
		quit(1)
		return

	var map_meshes := _count_meshes(map_node)
	var pokemon_meshes := _count_meshes(pokemon_node)
	if map_meshes <= 0:
		push_error("SMOKE_FAIL: mapa carregou sem MeshInstance3D")
		quit(1)
		return
	if pokemon_meshes <= 0:
		push_error("SMOKE_FAIL: Squirtle carregou sem MeshInstance3D")
		quit(1)
		return

	print("SMOKE_OK main_scene=loaded map=loaded map_meshes=", map_meshes,
		" pokemon=Squirtle pokemon_meshes=", pokemon_meshes, " player=created")
	game.queue_free()
	await process_frame
	quit(0)


func _count_meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D and node.mesh != null else 0
	for child in node.get_children():
		total += _count_meshes(child)
	return total
