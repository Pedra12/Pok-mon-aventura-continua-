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
    for filename in parsed["pokemon"]:
        var profile: Dictionary = parsed["pokemon"][filename]
        var packed := load("res://assets/" + filename) as PackedScene
        if packed == null:
            failures.append(filename + ": cena GLB nao carregada")
            continue

        var wrapper := Node3D.new()
        wrapper.name = String(profile["name"]).replace(" ", "_")
        wrapper.scale = Vector3.ONE * float(profile["uniform_scale"])
        var offset: Array = profile["visual_offset"]
        wrapper.position = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
        var model := packed.instantiate()
        wrapper.add_child(model)
        root.add_child(wrapper)
        await process_frame

        var bounds := _combined_world_bounds(model)
        if not bounds["valid"]:
            failures.append(filename + ": sem MeshInstance3D com geometria")
            wrapper.queue_free()
            await process_frame
            continue

        var box: AABB = bounds["aabb"]
        var center := box.position + box.size * 0.5
        var target_height := float(profile["pokedex_height_m"])
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
        results.append({
            "file": filename,
            "name": profile["name"],
            "actual_world_min": _vec3_array(box.position),
            "actual_world_max": _vec3_array(box.end),
            "actual_world_size": _vec3_array(box.size),
            "target_height": target_height,
            "wrapper_scale": float(profile["uniform_scale"]),
            "wrapper_position": offset,
            "debug_wrapper_global_transform": str(wrapper.global_transform),
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
        "method": "Instancia cada GLB dentro de um Node3D wrapper com escala e posicao do perfil; mede AABB global apos transformacao."
    }
    var out := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    if out == null:
        push_error("Nao foi possivel gravar relatorio")
        quit(1)
        return
    out.store_string(JSON.stringify(output, "\t"))
    out.close()
    print("SCALED_INSTANCE_VALIDATION=" + JSON.stringify({
        "tested": output["profiles_tested"],
        "passed": output["profiles_passed"],
        "failures": failures,
        "results": results
    }))
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
