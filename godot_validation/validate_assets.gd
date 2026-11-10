extends SceneTree

const ASSET_DIR := "res://assets"
const OUTPUT_PATH := "res://godot_validation_report.json"

func _initialize() -> void:
    call_deferred("_run_validation")

func _run_validation() -> void:
    var report := {
        "godot_version": Engine.get_version_info(),
        "assets": [],
        "summary": {}
    }
    var files := DirAccess.get_files_at(ASSET_DIR)
    files.sort()
    var total_meshes := 0
    var total_skeletons := 0
    var total_animations := 0
    var failures := []

    for file_name in files:
        if not file_name.to_lower().ends_with(".glb"):
            continue
        var path := ASSET_DIR.path_join(file_name)
        var entry := {
            "file": file_name,
            "loaded": false,
            "node_count": 0,
            "mesh_instances": 0,
            "skeletons": [],
            "animation_players": [],
            "errors": []
        }
        var resource := ResourceLoader.load(path)
        if resource == null or not (resource is PackedScene):
            entry["errors"].append("Nao foi possivel carregar como PackedScene")
            failures.append(file_name)
            report["assets"].append(entry)
            continue

        var instance := (resource as PackedScene).instantiate()
        if instance == null:
            entry["errors"].append("Falha ao instanciar PackedScene")
            failures.append(file_name)
            report["assets"].append(entry)
            continue

        root.add_child(instance)
        entry["loaded"] = true
        _inspect_node(instance, entry)
        total_meshes += int(entry["mesh_instances"])
        total_skeletons += entry["skeletons"].size()
        for player in entry["animation_players"]:
            total_animations += player["clips"].size()
        report["assets"].append(entry)
        instance.queue_free()
        await process_frame

    report["summary"] = {
        "files_tested": report["assets"].size(),
        "loaded": report["assets"].filter(func(x): return x["loaded"]).size(),
        "failed": failures,
        "mesh_instances": total_meshes,
        "skeletons": total_skeletons,
        "animation_clips": total_animations
    }
    var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    if output == null:
        push_error("Nao foi possivel gravar o relatorio de validacao")
        quit(1)
        return
    output.store_string(JSON.stringify(report, "\t"))
    output.close()
    print("GODOT_VALIDATION_RESULT=" + JSON.stringify(report["summary"]))
    quit(0 if failures.is_empty() else 1)

func _inspect_node(node: Node, entry: Dictionary) -> void:
    entry["node_count"] += 1
    if node is MeshInstance3D:
        entry["mesh_instances"] += 1
    if node is Skeleton3D:
        var skeleton := node as Skeleton3D
        entry["skeletons"].append({
            "name": skeleton.name,
            "bone_count": skeleton.get_bone_count()
        })
    if node is AnimationPlayer:
        var player := node as AnimationPlayer
        var clips: Array[String] = []
        for clip_name in player.get_animation_list():
            clips.append(clip_name)
        entry["animation_players"].append({
            "name": player.name,
            "clips": clips
        })
    for child in node.get_children():
        _inspect_node(child, entry)
