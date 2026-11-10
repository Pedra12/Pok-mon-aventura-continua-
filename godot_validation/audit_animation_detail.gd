extends SceneTree

const ASSET_DIR := "res://assets"
const OUTPUT_PATH := "res://animation_detail_report.json"
const SAMPLE_FRACTIONS := [0.0, 0.25, 0.5, 0.75, 0.99]
const EPSILON := 0.00001

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var report := {
        "godot_version": Engine.get_version_info(),
        "sampling_fractions": SAMPLE_FRACTIONS,
        "assets": [],
        "summary": {}
    }
    var files := DirAccess.get_files_at(ASSET_DIR)
    files.sort()
    var total_models := 0
    var total_clips := 0
    var clips_with_bone_motion := 0
    var clips_with_node_motion := 0
    var failures: Array[String] = []

    for filename in files:
        if not filename.to_lower().ends_with(".glb"):
            continue
        total_models += 1
        var item: Dictionary = await _inspect_asset(filename)
        report["assets"].append(item)
        if not item["loaded"]:
            failures.append(filename)
        for player_data in item["animation_players"]:
            for clip in player_data["clips"]:
                total_clips += 1
                if not clip["changed_bones"].is_empty():
                    clips_with_bone_motion += 1
                if not clip["changed_nodes"].is_empty():
                    clips_with_node_motion += 1

    report["summary"] = {
        "models_tested": total_models,
        "clips_tested": total_clips,
        "clips_with_bone_motion": clips_with_bone_motion,
        "clips_with_node_motion": clips_with_node_motion,
        "failures": failures
    }
    var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    if output == null:
        push_error("Nao foi possivel gravar o relatorio detalhado")
        quit(1)
        return
    output.store_string(JSON.stringify(report, "\t"))
    output.close()
    print("ANIMATION_DETAIL_RESULT=" + JSON.stringify(report["summary"]))
    quit(0 if failures.is_empty() else 1)

func _inspect_asset(filename: String) -> Dictionary:
    var entry := {
        "file": filename,
        "loaded": false,
        "skeletons": [],
        "animation_players": [],
        "errors": []
    }
    var path := ASSET_DIR.path_join(filename)
    var resource := ResourceLoader.load(path)
    if resource == null or not (resource is PackedScene):
        entry["errors"].append("GLB nao carregou como PackedScene")
        return entry
    var instance := (resource as PackedScene).instantiate()
    if instance == null:
        entry["errors"].append("Falha ao instanciar cena")
        return entry
    root.add_child(instance)
    await process_frame
    _stop_animations(instance)
    await process_frame
    var skeletons: Array[Skeleton3D] = []
    _collect_skeletons(instance, skeletons)
    for skeleton in skeletons:
        var bones: Array = []
        for bone_index in range(skeleton.get_bone_count()):
            bones.append({
                "index": bone_index,
                "name": skeleton.get_bone_name(bone_index),
                "parent": skeleton.get_bone_parent(bone_index)
            })
        entry["skeletons"].append({
            "node_path": str(skeleton.get_path()),
            "bone_count": skeleton.get_bone_count(),
            "bones": bones
        })
    var players: Array[AnimationPlayer] = []
    _collect_players(instance, players)
    for player in players:
        var player_entry := {
            "node_path": str(player.get_path()),
            "clips": []
        }
        var names := player.get_animation_list()
        names.sort()
        for clip_name in names:
            var animation := player.get_animation(clip_name)
            if animation == null:
                continue
            var tracks: Array = []
            for track_index in range(animation.get_track_count()):
                tracks.append({
                    "path": str(animation.track_get_path(track_index)),
                    "type": _track_type_name(animation.track_get_type(track_index)),
                    "key_count": animation.track_get_key_count(track_index),
                    "enabled": animation.track_is_enabled(track_index)
                })
            var changed_bones: Dictionary = {}
            var changed_nodes: Dictionary = {}
            var sample_results: Array = []
            if animation.length > 0.0:
                player.play(clip_name)
                player.seek(0.0, true)
                await process_frame
                _force_update(instance)
                var baseline := _capture_pose(instance, skeletons)
                for fraction in SAMPLE_FRACTIONS:
                    var sample_time := animation.length * float(fraction)
                    player.seek(sample_time, true)
                    await process_frame
                    _force_update(instance)
                    var current := _capture_pose(instance, skeletons)
                    var bone_names := _changed_keys(baseline["bones"], current["bones"])
                    var node_names := _changed_keys(baseline["nodes"], current["nodes"])
                    for bone_name in bone_names:
                        changed_bones[bone_name] = true
                    for node_name in node_names:
                        changed_nodes[node_name] = true
                    sample_results.append({
                        "time_seconds": sample_time,
                        "fraction": fraction,
                        "bones_changed_from_start": bone_names,
                        "nodes_changed_from_start": node_names
                    })
                player.stop()
            var bone_list: Array = changed_bones.keys()
            bone_list.sort()
            var node_list: Array = changed_nodes.keys()
            node_list.sort()
            player_entry["clips"].append({
                "name": clip_name,
                "duration_seconds": animation.length,
                "track_count": animation.get_track_count(),
                "tracks": tracks,
                "changed_bones": bone_list,
                "changed_nodes": node_list,
                "samples": sample_results
            })
        entry["animation_players"].append(player_entry)
    entry["loaded"] = true
    instance.queue_free()
    await process_frame
    return entry

func _capture_pose(instance: Node, skeletons: Array[Skeleton3D]) -> Dictionary:
    var bones: Dictionary = {}
    for skeleton in skeletons:
        skeleton.force_update_all_bone_transforms()
        var skeleton_path := str(skeleton.get_path())
        for index in range(skeleton.get_bone_count()):
            bones[skeleton_path + "::" + skeleton.get_bone_name(index)] = skeleton.get_bone_pose(index)
    var nodes: Dictionary = {}
    _capture_nodes(instance, nodes)
    return {"bones": bones, "nodes": nodes}

func _capture_nodes(node: Node, result: Dictionary) -> void:
    if node is Node3D:
        var spatial := node as Node3D
        result[str(spatial.get_path())] = spatial.global_transform
    for child in node.get_children():
        _capture_nodes(child, result)

func _changed_keys(before: Dictionary, after: Dictionary) -> Array:
    var changed: Array = []
    for key in before:
        if after.has(key) and _transform_differs(before[key], after[key]):
            changed.append(key)
    changed.sort()
    return changed

func _transform_differs(a: Transform3D, b: Transform3D) -> bool:
    return a.origin.distance_to(b.origin) > EPSILON or a.basis.x.distance_to(b.basis.x) > EPSILON or a.basis.y.distance_to(b.basis.y) > EPSILON or a.basis.z.distance_to(b.basis.z) > EPSILON

func _track_type_name(track_type: int) -> String:
    match track_type:
        Animation.TYPE_VALUE: return "value"
        Animation.TYPE_POSITION_3D: return "position_3d"
        Animation.TYPE_ROTATION_3D: return "rotation_3d"
        Animation.TYPE_SCALE_3D: return "scale_3d"
        Animation.TYPE_BLEND_SHAPE: return "blend_shape"
        Animation.TYPE_METHOD: return "method"
        Animation.TYPE_BEZIER: return "bezier"
        Animation.TYPE_AUDIO: return "audio"
        Animation.TYPE_ANIMATION: return "animation"
        _: return "unknown_" + str(track_type)

func _collect_skeletons(node: Node, result: Array[Skeleton3D]) -> void:
    if node is Skeleton3D:
        result.append(node as Skeleton3D)
    for child in node.get_children():
        _collect_skeletons(child, result)

func _collect_players(node: Node, result: Array[AnimationPlayer]) -> void:
    if node is AnimationPlayer:
        result.append(node as AnimationPlayer)
    for child in node.get_children():
        _collect_players(child, result)

func _stop_animations(node: Node) -> void:
    if node is AnimationPlayer:
        (node as AnimationPlayer).stop()
    for child in node.get_children():
        _stop_animations(child)

func _force_update(node: Node) -> void:
    if node is Node3D:
        (node as Node3D).force_update_transform()
    for child in node.get_children():
        _force_update(child)
