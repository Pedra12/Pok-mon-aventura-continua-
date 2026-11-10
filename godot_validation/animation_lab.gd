extends Node3D

const MODEL_FILES := [
 "amoonguss.glb","beedrill.glb","diancie_dancing_to_sweet_dreams.glb",
 "eevee_pokemon.glb","flygon_go_fest_2021.glb","hisuian_voltorb.glb",
 "ho_oh.glb","lucario.glb","magnemite.glb","mew_pokemon.glb",
 "pokemon_3ds_celebi.glb","pokemon_basic_pokeball.glb",
 "pokemon_sudowoodo_-_tree.glb","shiny_metagross.glb",
 "smoliv_fully_rigged.glb","squirtle.glb"
]
const MODEL_LABELS := [
 "Amoonguss","Beedrill","Diancie","Eevee","Flygon","Voltorb Hisui",
 "Ho-Oh","Lucario","Magnemite","Mew","Celebi","Pokébola",
 "Sudowoodo","Metagross","Smoliv","Squirtle"
]
const PROFILE_PATH := "res://config/pokemon_scale_profiles.json"

var current_model: Node3D
var current_wrapper: Node3D
var current_player: AnimationPlayer
var current_file := "flygon_go_fest_2021.glb"
var orbit_yaw := 0.0
var orbit_pitch := -0.18
var orbit_distance := 3.0
var camera_target_y := 0.5
var dragging := false
var last_pointer := Vector2.ZERO
var speed_value := 1.0
var status_label: Label
var clip_picker: OptionButton
var model_picker: OptionButton
var speed_picker: OptionButton
var play_button: Button
var profiles: Dictionary = {}

func _ready() -> void:
 _setup_world()
 _load_profiles()
 _setup_ui()
 _load_model(current_file)

func _setup_world() -> void:
 var env := WorldEnvironment.new()
 var environment := Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color(0.075, 0.095, 0.13)
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color(0.7, 0.76, 0.9)
 environment.ambient_light_energy = 0.8
 env.environment = environment
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48, -35, 0)
 sun.light_energy = 1.35
 add_child(sun)
 var floor_mesh := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(30, 30)
 floor_mesh.mesh = plane
 floor_mesh.position.y = -0.03
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color(0.19, 0.23, 0.28)
 mat.roughness = 0.92
 floor_mesh.material_override = mat
 add_child(floor_mesh)
 var camera := Camera3D.new()
 camera.name = "LabCamera"
 camera.current = true
 add_child(camera)
 _update_camera()

func _load_profiles() -> void:
 if FileAccess.file_exists(PROFILE_PATH):
  var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
  if parsed is Dictionary:
   profiles = parsed.get("pokemon", parsed.get("profiles", parsed))

func _setup_ui() -> void:
 var layer := CanvasLayer.new()
 layer.name = "LabUI"
 add_child(layer)
 var panel := PanelContainer.new()
 panel.position = Vector2(16, 16)
 panel.custom_minimum_size = Vector2(360, 0)
 layer.add_child(panel)
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation", 8)
 panel.add_child(box)
 var title := Label.new()
 title.text = "LABORATÓRIO 3D • POKÉMON"
 title.add_theme_font_size_override("font_size", 18)
 box.add_child(title)
 model_picker = OptionButton.new()
 for i in MODEL_LABELS.size():
  model_picker.add_item(MODEL_LABELS[i], i)
 model_picker.item_selected.connect(_on_model_selected)
 box.add_child(model_picker)
 clip_picker = OptionButton.new()
 clip_picker.item_selected.connect(_on_clip_selected)
 box.add_child(clip_picker)
 var controls := HBoxContainer.new()
 play_button = Button.new()
 play_button.text = "▶ Reproduzir"
 play_button.pressed.connect(_toggle_play)
 controls.add_child(play_button)
 var stop_button := Button.new()
 stop_button.text = "■ Parar"
 stop_button.pressed.connect(_stop_clip)
 controls.add_child(stop_button)
 box.add_child(controls)
 speed_picker = OptionButton.new()
 for label in ["0,25×","0,5×","1×","1,5×","2×"]:
  speed_picker.add_item(label)
 speed_picker.select(2)
 speed_picker.item_selected.connect(_on_speed_selected)
 box.add_child(speed_picker)
 status_label = Label.new()
 status_label.text = "Arraste na tela para girar a câmera."
 status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 box.add_child(status_label)
 var help := Label.new()
 help.text = "Toque/arraste fora do painel: orbitar • pinça não implementada"
 help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 box.add_child(help)

func _load_model(file_name: String) -> void:
 if current_wrapper:
  current_wrapper.queue_free()
 current_model = null
 current_wrapper = null
 current_player = null
 current_file = file_name
 var scene := load("res://assets/" + file_name) as PackedScene
 if scene == null:
  status_label.text = "Falha ao carregar: " + file_name
  return
 var instance := scene.instantiate() as Node3D
 if instance == null:
  status_label.text = "GLB não instanciou como Node3D."
  return
 current_wrapper = Node3D.new()
 current_wrapper.name = "PokemonPreviewWrapper"
 instance.name = "PokemonPreview"
 current_wrapper.add_child(instance)
 add_child(current_wrapper)
 current_model = instance
 var profile := _get_profile(file_name)
 var scale_value := float(profile.get("uniform_scale", profile.get("scale", 1.0)))
 var height_m := float(profile.get("pokedex_height_m", 1.0))
 camera_target_y = height_m * 0.5
 orbit_distance = max(2.8, height_m * 2.6)
 current_wrapper.scale = Vector3.ONE * scale_value
 var offset_data: Array = profile.get("visual_offset", [0.0, 0.0, 0.0])
 if offset_data.size() == 3:
  current_wrapper.position = Vector3(float(offset_data[0]), float(offset_data[1]), float(offset_data[2]))
 else:
  current_wrapper.position = Vector3.ZERO
 current_player = _find_animation_player(current_model)
 _populate_clips()
 _update_camera()
 status_label.text = file_name + " • escala perfil: " + str(scale_value) + " • " + ("AnimationPlayer encontrado" if current_player else "sem clipes")
 model_picker.select(MODEL_FILES.find(file_name))

func _get_profile(file_name: String) -> Dictionary:
 var profile = profiles.get(file_name, {})
 if profile is Dictionary:
  return profile
 return {}

func _find_animation_player(node: Node) -> AnimationPlayer:
 if node is AnimationPlayer:
  return node
 for child in node.get_children():
  var found := _find_animation_player(child)
  if found:
   return found
 return null

func _populate_clips() -> void:
 clip_picker.clear()
 if current_player == null:
  clip_picker.add_item("(sem AnimationPlayer)")
  clip_picker.set_item_disabled(0, true)
  play_button.disabled = true
  return
 play_button.disabled = false
 var names := current_player.get_animation_list()
 for name in names:
  clip_picker.add_item(name)
 if names.size() > 0:
  clip_picker.select(0)
  _play_selected_clip(false)

func _play_selected_clip(play_now: bool = true) -> void:
 if current_player == null or clip_picker.item_count == 0:
  return
 var clip := clip_picker.get_item_text(clip_picker.selected)
 if current_player.has_animation(clip):
  current_player.speed_scale = speed_value
  if play_now:
   current_player.play(clip)
  else:
   current_player.play(clip)
   current_player.pause()
  status_label.text = current_file + " • clipe: " + clip

func _on_model_selected(index: int) -> void:
 if index >= 0 and index < MODEL_FILES.size():
  _load_model(MODEL_FILES[index])

func _on_clip_selected(_index: int) -> void:
 _play_selected_clip(true)

func _toggle_play() -> void:
 if current_player == null or clip_picker.item_count == 0:
  return
 if current_player.is_playing():
  current_player.pause()
  play_button.text = "▶ Reproduzir"
 else:
  if current_player.current_animation.is_empty():
   _play_selected_clip(true)
  else:
   current_player.play()
  play_button.text = "Ⅱ Pausar"

func _stop_clip() -> void:
 if current_player:
  current_player.stop()
  play_button.text = "▶ Reproduzir"

func _on_speed_selected(index: int) -> void:
 var speeds := [0.25, 0.5, 1.0, 1.5, 2.0]
 speed_value = speeds[index]
 if current_player:
  current_player.speed_scale = speed_value

func _update_camera() -> void:
 var camera := get_node_or_null("LabCamera") as Camera3D
 if camera == null:
  return
 var target := Vector3(0, camera_target_y, 0)
 camera.position = target + Vector3(
  sin(orbit_yaw) * cos(orbit_pitch),
  sin(orbit_pitch),
  cos(orbit_yaw) * cos(orbit_pitch)
 ) * orbit_distance
 camera.look_at(target, Vector3.UP)

func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed:
   dragging = event.position.x > 390
   last_pointer = event.position
  else:
   dragging = false
 elif event is InputEventScreenDrag and dragging:
  _orbit(event.relative)
 elif event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_LEFT:
   dragging = event.pressed and event.position.x > 390
   last_pointer = event.position
  elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
   orbit_distance = max(1.5, orbit_distance - 0.4)
   _update_camera()
  elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
   orbit_distance = min(25.0, orbit_distance + 0.4)
   _update_camera()
 elif event is InputEventMouseMotion and dragging:
  _orbit(event.relative)

func _orbit(delta: Vector2) -> void:
 orbit_yaw -= delta.x * 0.008
 orbit_pitch = clamp(orbit_pitch + delta.y * 0.006, -1.15, 0.65)
 _update_camera()
