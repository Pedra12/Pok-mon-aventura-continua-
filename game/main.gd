extends Node3D
# Jogo base Pokémon 3D - Godot 4.4.1
# Carrega o mapa, cria colisão automática, jogador com câmera em 3ª pessoa,
# joystick touch (esquerda), olhar (direita), botão de pulo e um Pokémon seguindo você.

const MAP_PATH := "res://assets/original_pokemon_village.glb"
const POKEMON_PATH := "res://assets/squirtle.glb"
const POKEMON_SCALE := 1.0   # aumente/diminua se o Pokémon ficar do tamanho errado
const SPEED := 6.0
const GRAVITY := 22.0
const JUMP_FORCE := 7.0

var player: CharacterBody3D
var pivot: Node3D
var cam: Camera3D
var pokemon: Node3D
var pokemon_anim: AnimationPlayer
var anim_idle := ""
var anim_walk := ""
var yaw := 0.0
var pitch := -0.3
var move_touch := -1
var look_touch := -1
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO
var jump_pressed := false
var info: Label


func _ready() -> void:
	_setup_light()
	_setup_ui()
	var map := _load_glb(MAP_PATH)
	if map == null:
		info.text = "ERRO: não achei o mapa em " + MAP_PATH + "\nCorrija MAP_PATH no main.gd"
		return
	add_child(map)
	_add_collisions(map)
	_setup_player()
	pokemon = _load_glb(POKEMON_PATH)
	if pokemon:
		pokemon.scale = Vector3.ONE * POKEMON_SCALE
		add_child(pokemon)
		_setup_pokemon_anim()
	# espera a física registrar as colisões do mapa antes de procurar o chão
	await get_tree().physics_frame
	await get_tree().physics_frame
	_place_player_on_ground(map)
	info.text = ""


func _load_glb(path: String) -> Node3D:
	var res = load(path)
	if res == null or not (res is PackedScene):
		return null
	return res.instantiate() as Node3D


func _setup_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = false  # mais leve no celular
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _add_collisions(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		node.create_trimesh_collision()
	for c in node.get_children():
		_add_collisions(c)


func _collect_aabb(node: Node, box: Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var a: AABB = node.global_transform * node.get_aabb()
		if box[0] == null:
			box[0] = a
		else:
			box[0] = box[0].merge(a)
	for c in node.get_children():
		_collect_aabb(c, box)


func _setup_player() -> void:
	player = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	player.add_child(shape)
	# visual provisório (cápsula) até você ter um modelo de treinador
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.7
	mesh.mesh = cm
	mesh.position.y = 0.85
	player.add_child(mesh)
	add_child(player)
	pivot = Node3D.new()
	pivot.top_level = true
	add_child(pivot)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0, 4.5)
	cam.current = true
	pivot.add_child(cam)


func _place_player_on_ground(map: Node3D) -> void:
	var box := [null]
	_collect_aabb(map, box)
	var center := Vector3.ZERO
	var top := 50.0
	if box[0] != null:
		var a: AABB = box[0]
		center = a.get_center()
		top = a.end.y + 20.0
	var from := Vector3(center.x, top, center.z)
	var to := Vector3(center.x, top - 5000.0, center.z)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var spawn := center + Vector3(0, 2, 0)
	if hit:
		spawn = hit.position + Vector3(0, 0.5, 0)
	player.global_position = spawn
	if pokemon:
		pokemon.global_position = spawn + Vector3(1.5, 0, 1.5)


func _setup_pokemon_anim() -> void:
	pokemon_anim = pokemon.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if pokemon_anim == null:
		return
	var names := pokemon_anim.get_animation_list()
	for n in names:
		var l := String(n).to_lower()
		if anim_idle == "" and ("wait" in l or "idle" in l):
			anim_idle = n
		if anim_walk == "" and ("walk" in l or "run" in l):
			anim_walk = n
	if anim_idle == "" and names.size() > 0:
		anim_idle = names[0]
	if anim_walk == "":
		anim_walk = anim_idle
	for n in [anim_idle, anim_walk]:
		if n != "":
			pokemon_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if anim_idle != "":
		pokemon_anim.play(anim_idle)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	info = Label.new()
	info.position = Vector2(20, 20)
	info.add_theme_font_size_override("font_size", 24)
	layer.add_child(info)
	var btn := Button.new()
	btn.text = "PULAR"
	btn.custom_minimum_size = Vector2(180, 110)
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -220
	btn.offset_right = -40
	btn.offset_top = -160
	btn.offset_bottom = -50
	btn.button_down.connect(func(): jump_pressed = true)
	layer.add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < half and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
			elif event.position.x >= half and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == move_touch:
				move_touch = -1
				move_vec = Vector2.ZERO
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			move_vec = ((event.position - move_origin) / 90.0).limit_length(1.0)
		elif event.index == look_touch:
			yaw -= event.relative.x * 0.005
			pitch = clamp(pitch - event.relative.y * 0.004, -1.2, 0.2)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		jump_pressed = true


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") + move_vec
	input = input.limit_length(1.0)
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	player.velocity.x = dir.x * SPEED
	player.velocity.z = dir.z * SPEED
	if player.is_on_floor():
		if jump_pressed:
			player.velocity.y = JUMP_FORCE
		else:
			player.velocity.y = 0.0
	else:
		player.velocity.y -= GRAVITY * delta
	jump_pressed = false
	player.move_and_slide()
	if dir.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	# câmera
	pivot.global_position = player.global_position + Vector3(0, 1.5, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)
	# Pokémon segue o jogador
	if pokemon:
		var target := player.global_position + Basis(Vector3.UP, yaw) * Vector3(1.5, 0, 2.0)
		var d := target - pokemon.global_position
		d.y = 0
		var moving := d.length() > 0.6
		if moving:
			pokemon.global_position += d.normalized() * min(d.length(), SPEED * 0.9 * delta)
			pokemon.look_at(pokemon.global_position - d, Vector3.UP)
		pokemon.global_position.y = player.global_position.y
		if pokemon_anim:
			var want := anim_walk if moving else anim_idle
			if want != "" and pokemon_anim.current_animation != want:
				pokemon_anim.play(want, 0.2)
