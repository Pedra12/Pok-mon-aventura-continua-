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
    var clips_with_pose_changes := 0
    var clips_with_node_transform_changes := 0
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
            "mesh_bounds": [],
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
        if instance is Node3D:
            var root_3d := instance as Node3D
            entry["root_origin"] = _vec3_array(root_3d.global_position)
            entry["root_scale"] = _vec3_array(root_3d.global_basis.get_scale())
        var skeletons: Array[Skeleton3D] = []
        var spatial_nodes: Array[Node3D] = []
        _collect_skeletons(instance, skeletons)
        _collect_node3d(instance, spatial_nodes)
        _inspect_node(instance, entry, skeletons, spatial_nodes)
        total_meshes += int(entry["mesh_instances"])
        total_skeletons += entry["skeletons"].size()
        for player_data in entry["animation_players"]:
            total_animations += player_data["clips"].size()
            for clip in player_data["clips"]:
                if clip["changed_bones"] > 0:
                    clips_with_pose_changes += 1
                if clip["changed_nodes"] > 0:
                    clips_with_node_transform_changes += 1
        report["assets"].append(entry)
        instance.queue_free()
        await process_frame

    report["summary"] = {
        "files_tested": report["assets"].size(),
        "loaded": report["assets"].filter(func(x): return x["loaded"]).size(),
        "failed": failures,
        "mesh_instances": total_meshes,
        "skeletons": total_skeletons,
        "animation_clips": total_animations,
        "clips_with_bone_pose_changes": clips_with_pose_changes,
        "clips_with_node_transform_changes": clips_with_node_transform_changes
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

func _vec3_array(value: Vector3) -> Array:
    return [value.x, value.y, value.z]

func _collect_skeletons(node: Node, result: Array[Skeleton3D]) -> void:
    if node is Skeleton3D:
        result.append(node as Skeleton3D)
    for child in node.get_children():
        _collect_skeletons(child, result)

func _collect_node3d(node: Node, result: Array[Node3D]) -> void:
    if node is Node3D:
        result.append(node as Node3D)
    for child in node.get_children():
        _collect_node3d(child, result)

func _capture_node3d_transforms(nodes: Array[Node3D]) -> Array:
    var transforms: Array = []
    for spatial_node in nodes:
        transforms.append(spatial_node.global_transform)
    return transforms

func _capture_bone_poses(skeletons: Array[Skeleton3D]) -> Array:
    var poses: Array = []
    for skeleton in skeletons:
        skeleton.force_update_all_bone_transforms()
        for bone_index in range(skeleton.get_bone_count()):
            poses.append(skeleton.get_bone_pose(bone_index))
    return poses

func _pose_differs(a: Transform3D, b: Transform3D) -> bool:
    if a.origin.distance_to(b.origin) > 0.00001:
        return true
    if a.basis.x.distance_to(b.basis.x) > 0.00001:
        return true
    if a.basis.y.distance_to(b.basis.y) > 0.00001:
        return true
    if a.basis.z.distance_to(b.basis.z) > 0.00001:
        return true
    return false

func _inspect_node(node: Node, entry: Dictionary, skeletons: Array[Skeleton3D], spatial_nodes: Array[Node3D]) -> void:
    entry["node_count"] += 1
    if node is MeshInstance3D:
        entry["mesh_instances"] += 1
        var mesh_instance := node as MeshInstance3D
        var local_bounds := mesh_instance.get_aabb()
        var world_bounds := local_bounds * mesh_instance.global_transform
        entry["mesh_bounds"].append({
            "node_path": str(mesh_instance.get_path()),
            "local_min": _vec3_array(local_bounds.position),
            "local_max": _vec3_array(local_bounds.end),
            "local_size": _vec3_array(local_bounds.size),
            "world_min": _vec3_array(world_bounds.position),
            "world_max": _vec3_array(world_bounds.end),
            "world_size": _vec3_array(world_bounds.size)
        })
    if node is Skeleton3D:
        var skeleton := node as Skeleton3D
        entry["skeletons"].append({
            "name": skeleton.name,
            "bone_count": skeleton.get_bone_count()
        })
    if node is AnimationPlayer:
        var player := node as AnimationPlayer
        var clips: Array = []
        for clip_name in player.get_animation_list():
            var animation := player.get_animation(clip_name)
            var track_paths: Array[String] = []
            for track_index in range(animation.get_track_count()):
                track_paths.append(str(animation.track_get_path(track_index)))
            var changed_bones := 0
            var changed_nodes := 0
            if animation.length > 0.0:
                player.play(clip_name)
                player.seek(0.0, true)
                var initial_poses := _capture_bone_poses(skeletons)
                var initial_transforms := _capture_node3d_transforms(spatial_nodes)
                player.seek(animation.length * 0.5, true)
                var middle_poses := _capture_bone_poses(skeletons)
                var middle_transforms := _capture_node3d_transforms(spatial_nodes)
                var pose_count: int = mini(initial_poses.size(), middle_poses.size())
                for pose_index in range(pose_count):
                    if _pose_differs(initial_poses[pose_index], middle_poses[pose_index]):
                        changed_bones += 1
                var transform_count: int = mini(initial_transforms.size(), middle_transforms.size())
                for transform_index in range(transform_count):
                    if _pose_differs(initial_transforms[transform_index], middle_transforms[transform_index]):
                        changed_nodes += 1
                player.stop()
            clips.append({
                "name": clip_name,
                "duration_seconds": animation.length,
                "track_count": animation.get_track_count(),
                "track_paths": track_paths,
                "changed_bones": changed_bones,
                "changed_nodes": changed_nodes,
                "skeletal_pose_changes_detected": changed_bones > 0,
                "node_transform_changes_detected": changed_nodes > 0
            })
        entry["animation_players"].append({
            "name": player.name,
            "clips": clips
        })
    for child in node.get_children():
        _inspect_node(child, entry, skeletons, spatial_nodes)
