extends SceneTree

const PROFILE_PATH := "res://config/pokemon_scale_profiles.json"
const OUTPUT_PATH := "res://scaled_instance_validation.json"
const POSITION_TOLERANCE := 0.03
const HEIGHT_TOLERANCE := 0.03

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
    if file == null:
        push_error("Nao foi possivel abrir " + PROFILE_PATH)
        quit(1)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("pokemon"):
        push_error("Config de escala invalida")
        quit(1)
        return

    var results: Array = []
    var failures: Array[String] = []
    var recommendations: Dictionary = {}
    for filename in parsed["pokemon"]:
        var profile: Dictionary = parsed["pokemon"][filename]
        var packed := load("res://assets/" + filename) as PackedScene
        if packed == null:
            failures.append(filename + ": cena GLB nao carregada")
            continue

        # Measure the live imported hierarchy first, without a scale wrapper.
        var baseline_model := packed.instantiate()
        root.add_child(baseline_model)
        await process_frame
        var baseline_result := _combined_world_bounds(baseline_model)
        if not baseline_result["valid"]:
            failures.append(filename + ": sem MeshInstance3D com geometria")
            baseline_model.queue_free()
            await process_frame
            continue
        var baseline: AABB = baseline_result["aabb"]
        if baseline.size.y <= 0.000001:
            failures.append(filename + ": altura base invalida")
            baseline_model.queue_free()
            await process_frame
            continue

        var target_height := float(profile["pokedex_height_m"])
        var calibrated_scale := target_height / baseline.size.y
        var baseline_center := baseline.position + baseline.size * 0.5
        var calibrated_offset := Vector3(
            -baseline_center.x * calibrated_scale,
            -baseline.position.y * calibrated_scale,
            -baseline_center.z * calibrated_scale
        )
        baseline_model.queue_free()
        await process_frame

        var wrapper := Node3D.new()
        wrapper.name = String(profile["name"]).replace(" ", "_")
        wrapper.scale = Vector3.ONE * calibrated_scale
        wrapper.position = calibrated_offset
        var model := packed.instantiate()
        wrapper.add_child(model)
        root.add_child(wrapper)
        await process_frame
        var bounds := _combined_world_bounds(model)
        if not bounds["valid"]:
            failures.append(filename + ": geometria desapareceu apos calibracao")
            wrapper.queue_free()
            await process_frame
            continue

        var box: AABB = bounds["aabb"]
        var center := box.position + box.size * 0.5
        var checks := {
            "height_matches_target": abs(box.size.y - target_height) <= HEIGHT_TOLERANCE,
            "bottom_aligned_to_zero": abs(box.position.y) <= POSITION_TOLERANCE,
            "centered_x": abs(center.x) <= POSITION_TOLERANCE,
            "centered_z": abs(center.z) <= POSITION_TOLERANCE
        }
        var passed := true
        for key in checks:
            if not checks[key]:
                passed = false
        if not passed:
            failures.append(filename + ": " + JSON.stringify(checks))

        recommendations[filename] = {
            "uniform_scale": calibrated_scale,
            "visual_offset": _vec3_array(calibrated_offset),
            "native_aabb_min": _vec3_array(baseline.position),
            "native_aabb_max": _vec3_array(baseline.end),
            "native_aabb_size": _vec3_array(baseline.size)
        }
        results.append({
            "file": filename,
            "name": profile["name"],
            "native_aabb_min": _vec3_array(baseline.position),
            "native_aabb_max": _vec3_array(baseline.end),
            "native_aabb_size": _vec3_array(baseline.size),
            "actual_world_min": _vec3_array(box.position),
            "actual_world_max": _vec3_array(box.end),
            "actual_world_size": _vec3_array(box.size),
            "target_height": target_height,
            "calibrated_scale": calibrated_scale,
            "calibrated_offset": _vec3_array(calibrated_offset),
            "previous_scale": float(profile["uniform_scale"]),
            "previous_offset": profile["visual_offset"],
            "checks": checks,
            "passed": passed
        })
        wrapper.queue_free()
        await process_frame

    var output := {
        "profiles_tested": results.size(),
        "profiles_passed": results.filter(func(item): return item["passed"]).size(),
        "failures": failures,
        "results": results,
        "recommended_profiles": recommendations,
        "method": "Mede o AABB nativo da PackedScene instanciada e calcula escala/offset a partir dessa hierarquia real antes de validar uma segunda instancia."
    }
    var out := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    if out == null:
        push_error("Nao foi possivel gravar relatorio")
        quit(1)
        return
    out.store_string(JSON.stringify(output, "\t"))
    out.close()
    print("SCALED_INSTANCE_VALIDATION=" + JSON.stringify(output))
    quit(0 if failures.is_empty() and results.size() == parsed["pokemon"].size() else 1)

func _combined_world_bounds(node: Node) -> Dictionary:
    var combined := AABB()
    var found := false
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            var box := mesh_instance.get_aabb() * mesh_instance.global_transform
            if not found:
                combined = box
                found = true
            else:
                combined = combined.merge(box)
    for child in node.get_children():
        var child_result := _combined_world_bounds(child)
        if child_result["valid"]:
            if not found:
                combined = child_result["aabb"]
                found = true
            else:
                combined = combined.merge(child_result["aabb"])
    return {"valid": found, "aabb": combined}

func _vec3_array(value: Vector3) -> Array:
    return [value.x, value.y, value.z]
