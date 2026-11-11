extends SceneTree

# Auditoria estrutural focada nos 16 clipes do Flygon.
# Mede alvos de tracks, movimento de ossos e movimento da raiz.
# Nao declara qualidade visual: isso exige inspecao renderizada.
const MODEL_PATH := "res://assets/flygon_go_fest_2021.glb"
const REPORT_PATH := "res://flygon_clip_audit.json"
const FRACTIONS := [0.0, 0.25, 0.5, 0.75, 0.99]
const EPS := 0.00001

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var report := {"model": MODEL_PATH, "clips": [], "errors": []}
    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        report.errors.append("Flygon nao carregou como PackedScene")
        _finish(report)
        return
    var instance := packed.instantiate()
    root.add_child(instance)
    await process_frame
    var players: Array[AnimationPlayer] = []
    var skeletons: Array[Skeleton3D] = []
    _collect(instance, players, skeletons)
    if players.is_empty():
        report.errors.append("Nenhum AnimationPlayer encontrado")
        _finish(report)
        return
    var player := players[0]
    var names := player.get_animation_list()
    names.sort()
    for clip_name in names:
        var animation := player.get_animation(clip_name)
        if animation == null:
            report.errors.append("Clipe nulo: " + clip_name)
            continue
        var tracks: Array = []
        var targets: Dictionary = {}
        for i in range(animation.get_track_count()):
            var path := str(animation.track_get_path(i))
            var kind := animation.track_get_type(i)
            targets[path] = true
            tracks.append({
                "path": path,
                "type": kind,
                "keys": animation.track_get_key_count(i),
                "enabled": animation.track_is_enabled(i)
            })
        var bone_changes: Dictionary = {}
        var root_samples: Array = []
        if animation.length > 0.0:
            player.play(clip_name)
            player.seek(0.0, true)
            await process_frame
            var baseline := _bone_pose(skeletons)
            var root_start: Transform3D = instance.global_transform
            for fraction in FRACTIONS:
                player.seek(animation.length * fraction, true)
                await process_frame
                for key in _changed(baseline, _bone_pose(skeletons)):
                    bone_changes[key] = true
                var root_now: Transform3D = instance.global_transform
                root_samples.append({
                    "fraction": fraction,
                    "root_translation_from_start": [
                        root_now.origin.x - root_start.origin.x,
                        root_now.origin.y - root_start.origin.y,
                        root_now.origin.z - root_start.origin.z
                    ],
                    "root_rotation_changed": not root_now.basis.is_equal_approx(root_start.basis)
                })
            player.stop()
        var changed: Array = bone_changes.keys()
        changed.sort()
        var target_list: Array = targets.keys()
        target_list.sort()
        report.clips.append({
            "name": clip_name,
            "duration_seconds": animation.length,
            "track_count": animation.get_track_count(),
            "track_targets": target_list,
            "tracks": tracks,
            "bones_changed_from_start": changed,
            "root_samples": root_samples
        })
    report["summary"] = {
        "clip_count": report.clips.size(),
        "expected_clip_count": 16,
        "clip_count_matches_expected": report.clips.size() == 16,
        "clips_with_bone_motion": _count_bone_motion(report.clips),
        "clips_with_root_translation": _count_root_motion(report.clips)
    }
    if report.clips.size() != 16:
        report.errors.append("Esperados 16 clipes; encontrados %d" % report.clips.size())
    _finish(report)

func _collect(node: Node, players: Array[AnimationPlayer], skeletons: Array[Skeleton3D]) -> void:
    if node is AnimationPlayer:
        players.append(node as AnimationPlayer)
    if node is Skeleton3D:
        skeletons.append(node as Skeleton3D)
    for child in node.get_children():
        _collect(child, players, skeletons)

func _bone_pose(skeletons: Array[Skeleton3D]) -> Dictionary:
    var result := {}
    for skeleton in skeletons:
        skeleton.force_update_all_bone_transforms()
        for i in range(skeleton.get_bone_count()):
            result[str(skeleton.get_path()) + "::" + skeleton.get_bone_name(i)] = skeleton.get_bone_pose(i)
    return result

func _changed(before: Dictionary, after: Dictionary) -> Array:
    var result: Array = []
    for key in before:
        if after.has(key):
            var a: Transform3D = before[key]
            var b: Transform3D = after[key]
            if a.origin.distance_to(b.origin) > EPS or not a.basis.is_equal_approx(b.basis):
                result.append(key)
    return result

func _count_bone_motion(clips: Array) -> int:
    var total := 0
    for clip in clips:
        if not clip.bones_changed_from_start.is_empty():
            total += 1
    return total

func _count_root_motion(clips: Array) -> int:
    var total := 0
    for clip in clips:
        for sample in clip.root_samples:
            var p: Array = sample.root_translation_from_start
            if Vector3(p[0], p[1], p[2]).length() > EPS or sample.root_rotation_changed:
                total += 1
                break
    return total

func _finish(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(report, "\\t"))
        file.close()
    print("FLYGON_CLIP_AUDIT=" + JSON.stringify(report.get("summary", {})))
    quit(0 if report.get("errors", []).is_empty() else 1)
