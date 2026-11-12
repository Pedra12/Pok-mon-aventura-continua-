extends SceneTree

# Exercita play/seek/advance/stop de cada AnimationPlayer e clipe importado.
# Não avalia qualidade visual nem substitui inspeção em viewport.
const REPORT_PATH := "res://animation_playback_smoke_report.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := {
		"status": "running",
		"models_tested": 0,
		"players_tested": 0,
		"clips_tested": 0,
		"errors": [],
		"models": {}
	}
	var files := DirAccess.get_files_at("res://assets")
	for file_name in files:
		if not file_name.to_lower().ends_with(".glb"):
			continue
		var model_path := "res://assets/" + file_name
		var packed := load(model_path) as PackedScene
		if packed == null:
			report.errors.append("Falha ao carregar PackedScene: " + file_name)
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		await process_frame
		var players: Array[AnimationPlayer] = []
		_collect_players(instance, players)
		var model_result := {"players": players.size(), "clips": [], "errors": []}
		for player in players:
			for clip_name in player.get_animation_list():
				var animation := player.get_animation(clip_name)
				if animation == null:
					model_result.errors.append("Animation nula: " + clip_name)
					continue
				player.play(clip_name)
				player.seek(0.0, true)
				player.advance(0.05)
				player.seek(animation.length * 0.5, true)
				player.advance(0.05)
				player.stop()
				model_result.clips.append(clip_name)
				report.clips_tested += 1
		report.models[file_name] = model_result
		report.models_tested += 1
		report.players_tested += players.size()
		if not model_result.errors.is_empty():
			report.errors.append_array(model_result.errors)
		instance.queue_free()
		await process_frame
	report.status = "success" if report.errors.is_empty() else "failed"
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print("ANIMATION_PLAYBACK_SMOKE: ", JSON.stringify(report))
	quit(0 if report.status == "success" else 1)

func _collect_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_players(child, out)
