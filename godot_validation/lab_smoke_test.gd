extends SceneTree

# Teste de runtime do proprio laboratorio: instancia cada modelo pela interface,
# confere escala/offset do perfil e inicia cada clipe encontrado.
const REPORT_PATH := "res://lab_smoke_test_report.json"
const MODEL_FILES := [
	"amoonguss.glb", "beedrill.glb", "diancie_dancing_to_sweet_dreams.glb",
	"flygon_go_fest_2021.glb", "hisuian_voltorb.glb", "ho_oh.glb",
	"magnemite.glb", "pokemon_3ds_celebi.glb", "pokemon_basic_pokeball.glb",
	"pokemon_sudowoodo_-_tree.glb", "shiny_metagross.glb",
	"smoliv_fully_rigged.glb", "squirtle.glb"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := {
		"status": "running",
		"models_tested": 0,
		"clips_started": 0,
		"errors": [],
		"models": {}
	}
	var packed := load("res://animation_lab.tscn") as PackedScene
	if packed == null:
		report.errors.append("Nao foi possivel carregar animation_lab.tscn")
		_finish(report)
		return

	var lab := packed.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame

	for file_name in MODEL_FILES:
		lab._load_model(file_name)
		await process_frame
		var model_result := {
			"loaded": lab.current_model != null,
			"scale": 0.0,
			"position": [],
			"clips": [],
			"errors": []
		}
		if lab.current_model == null:
			model_result.errors.append("Modelo nao instanciado: " + file_name)
			report.errors.append_array(model_result.errors)
			report.models[file_name] = model_result
			continue

		var profile: Dictionary = lab._get_profile(file_name)
		var expected_scale := float(profile.get("uniform_scale", 1.0))
		var expected_offset: Array = profile.get("visual_offset", [0.0, 0.0, 0.0])
		var actual_scale: float = lab.current_wrapper.scale.x
		model_result.scale = actual_scale
		model_result.position = [
			lab.current_wrapper.position.x,
			lab.current_wrapper.position.y,
			lab.current_wrapper.position.z
		]
		if absf(actual_scale - expected_scale) > 0.0001:
			model_result.errors.append("Escala divergente: esperado %.8f, recebido %.8f" % [expected_scale, actual_scale])
		if expected_offset.size() == 3:
			for axis in range(3):
				if absf(float(model_result.position[axis]) - float(expected_offset[axis])) > 0.0001:
					model_result.errors.append("Offset divergente no eixo %d" % axis)
					break

		if lab.current_player != null:
			for clip_index in range(lab.clip_picker.item_count):
				var clip_name: String = lab.clip_picker.get_item_text(clip_index)
				lab.clip_picker.select(clip_index)
				lab._play_selected_clip(true)
				await process_frame
				if lab.current_player.current_animation != clip_name:
					model_result.errors.append("Falha ao iniciar clipe: " + clip_name)
				else:
					report.clips_started += 1
					model_result.clips.append(clip_name)
				lab.current_player.stop()
		report.models[file_name] = model_result
		report.models_tested += 1
		if not model_result.errors.is_empty():
			report.errors.append(file_name + ": " + "; ".join(model_result.errors))

	report.status = "success" if report.errors.is_empty() else "failed"
	_finish(report)

func _finish(report: Dictionary) -> void:
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print("ANIMATION_LAB_RUNTIME_SMOKE: ", JSON.stringify(report))
	quit(0 if report.status == "success" else 1)
