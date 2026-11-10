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

        # Measure and calibrate the SAME imported instance under its final wrapper.
        var wrapper := Node3D.new()
        wrapper.name = String(profile["name"]).replace(" ", "_")
        var model := packed.instantiate()
        wrapper.add_child(model)
        root.add_child(wrapper)
        await process_frame
        var top_level_before: Array = []
        _collect_top_level_nodes(model, top_level_before)
        _disable_top_level_recursively(model)
        await process_frame

        var baseline_result := _combined_world_bounds(model)
        if not baseline_result["valid"]:
            failures.append(filename + ": sem MeshInstance3D com geometria")
            wrapper.queue_free()
            await process_frame
            continue
        var baseline: AABB = baseline_result["aabb"]
        if baseline.size.y <= 0.000001:
            failures.append(filename + ": altura base invalida")
            wrapper.queue_free()
            await process_frame
            continue

        var target_height := float(profile["pokedex_height_m"])
        var calibrated_scale := target_height / baseline.size.y
        wrapper.scale = Vector3.ONE * calibrated_scale
        await process_frame
        _force_update_recursive(wrapper)

        var scaled_result := _combined_world_bounds(model)
        if not scaled_result["valid"]:
            failures.append(filename + ": geometria desapareceu apos escala")
            wrapper.queue_free()
            await process_frame
            continue
        var scaled_box: AABB = scaled_result["aabb"]

        # Correct against the measured result, not an offset inferred from another instance.
        if scaled_box.size.y > 0.000001:
            var correction := target_height / scaled_box.size.y
            calibrated_scale *= correction
            wrapper.scale = Vector3.ONE * calibrated_scale
            await process_frame
            _force_update_recursive(wrapper)
            scaled_result = _combined_world_bounds(model)
            scaled_box = scaled_result["aabb"]

        var center := scaled_box.position + scaled_box.size * 0.5
        var calibrated_offset := Vector3(
            -center.x,
            -scaled_box.position.y,
            -center.z
        )
        wrapper.position = calibrated_offset
        await process_frame
        _force_update_recursive(wrapper)

        var final_result := _combined_world_bounds(model)
        if not final_result["valid"]:
            failures.append(filename + ": geometria desapareceu apos posicionamento")
            wrapper.queue_free()
            await process_frame
            continue
        var box: AABB = final_result["aabb"]
        center = box.position + box.size * 0.5
        var checks := {
            "height_matches_target": abs(box.size.y - target_height) <= HEIGHT_TOLERANCE,
            "configured_scale_matches_calibration": abs(float(profile["uniform_scale"]) - calibrated_scale) <= maxf(0.00000001, abs(calibrated_scale) * 0.002),
            "configured_offset_matches_calibration": Vector3(profile["visual_offset"][0], profile["visual_offset"][1], profile["visual_offset"][2]).distance_to(calibrated_offset) <= POSITION_TOLERANCE,
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
            "imported_root_type": model.get_class(),
            "imported_root_top_level": model is Node3D and (model as Node3D).top_level,
            "imported_root_global_transform": _transform_array((model as Node3D).global_transform) if model is Node3D else [],
            "top_level_nodes_before_normalization": top_level_before,
            "wrapper_global_transform_after_offset": _transform_array(wrapper.global_transform),
            "native_aabb_size": _vec3_array(baseline.size),
            "mesh_transform_samples_after_offset": _mesh_transform_samples(model)
        }
        results.append({
            "file": filename,
            "name": profile["name"],
            "native_aabb_min": _vec3_array(baseline.position),
            "native_aabb_max": _vec3_array(baseline.end),
            "native_aabb_size": _vec3_array(baseline.size),
            "scaled_aabb_min_before_offset": _vec3_array(scaled_box.position),
            "scaled_aabb_max_before_offset": _vec3_array(scaled_box.end),
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
        "method": "Mede, escala e posiciona a mesma instancia GLB dentro do wrapper final; corrige a escala pela altura medida apos a transformacao e calcula o offset pelo AABB escalado."
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


func _force_update_recursive(node: Node) -> void:
    if node is Node3D:
        (node as Node3D).force_update_transform()
    for child in node.get_children():
        _force_update_recursive(child)

func _mesh_transform_samples(node: Node) -> Array:
    var samples: Array = []
    _collect_mesh_samples(node, samples)
    return samples

func _collect_mesh_samples(node: Node, result: Array) -> void:
    if node is MeshInstance3D and result.size() < 40:
        var mesh_instance := node as MeshInstance3D
        var local_box := mesh_instance.get_aabb()
        var world_box := mesh_instance.global_transform * local_box
        result.append({
            "path": str(mesh_instance.get_path()),
            "top_level": mesh_instance.top_level,
            "local_position": _vec3_array(mesh_instance.position),
            "global_origin": _vec3_array(mesh_instance.global_position),
            "global_scale": _vec3_array(mesh_instance.global_basis.get_scale()),
            "local_aabb_min": _vec3_array(local_box.position),
            "world_aabb_min": _vec3_array(world_box.position),
            "world_aabb_max": _vec3_array(world_box.end)
        })
    for child in node.get_children():
        _collect_mesh_samples(child, result)

func _collect_top_level_nodes(node: Node, result: Array) -> void:
    if node is Node3D and (node as Node3D).top_level:
        result.append({"path": str(node.get_path()), "class": node.get_class(), "global_transform": _transform_array((node as Node3D).global_transform)})
    for child in node.get_children():
        _collect_top_level_nodes(child, result)

func _disable_top_level_recursively(node: Node) -> void:
    if node is Node3D and (node as Node3D).top_level:
        (node as Node3D).top_level = false
    for child in node.get_children():
        _disable_top_level_recursively(child)

func _combined_world_bounds(node: Node) -> Dictionary:
    var combined := AABB()
    var found := false
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            var box := mesh_instance.global_transform * mesh_instance.get_aabb()
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

func _transform_array(value: Transform3D) -> Array:
    return [value.origin.x, value.origin.y, value.origin.z, value.basis.x.x, value.basis.x.y, value.basis.x.z, value.basis.y.x, value.basis.y.y, value.basis.y.z, value.basis.z.x, value.basis.z.y, value.basis.z.z]
