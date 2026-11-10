extends SceneTree

const MAP_PATH := "res://assets/original_pokemon_village.glb"
const OUTPUT_PATH := "res://map_surface_analysis.json"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load(MAP_PATH) as PackedScene
    if packed == null:
        push_error("Nao foi possivel carregar o mapa: " + MAP_PATH)
        quit(1)
        return

    var map_root := packed.instantiate()
    root.add_child(map_root)
    await process_frame

    var surfaces: Array = []
    _collect_surfaces(map_root, surfaces)

    var candidates: Array = []
    for item in surfaces:
        if item["horizontal_triangles"] > 0:
            candidates.append(item)
    candidates.sort_custom(func(a, b): return a["horizontal_area"] > b["horizontal_area"])

    var output := {
        "map_file": "original_pokemon_village.glb",
        "map_preserved": true,
        "coordinate_up_axis": "Y",
        "mesh_surface_count": surfaces.size(),
        "horizontal_surface_candidates": candidates.size(),
        "surfaces": surfaces,
        "largest_horizontal_candidates": candidates.slice(0, mini(20, candidates.size())),
        "limitations": [
            "Normais e triangulos identificam superficies geometricamente horizontais, nao o uso semantico de cada objeto.",
            "Uma superficie horizontal pode ser chao, telhado, plataforma, mesa ou outro objeto.",
            "A orientacao das faces pode variar; por isso sao contabilizadas faces para cima e para baixo.",
            "Este relatorio nao cria nem altera colisores e nao modifica o GLB original."
        ]
    }

    var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Nao foi possivel gravar " + OUTPUT_PATH)
        quit(1)
        return
    file.store_string(JSON.stringify(output, "\t"))
    file.close()

    print("MAP_SURFACE_ANALYSIS meshes=", surfaces.size(),
        " horizontal_candidates=", candidates.size())
    quit(0)

func _collect_surfaces(node: Node, result: Array) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        var mesh := mesh_instance.mesh
        if mesh != null:
            for surface_index in range(mesh.get_surface_count()):
                var arrays := mesh.surface_get_arrays(surface_index)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                var up_count := 0
                var down_count := 0
                var vertical_count := 0
                var other_count := 0
                var up_area := 0.0
                var down_area := 0.0
                var horizontal_min_y := INF
                var horizontal_max_y := -INF
                var vertex_count := vertices.size()
                var triangle_count := indices.size() / 3 if indices.size() > 0 else vertex_count / 3

                for triangle_index in range(triangle_count):
                    var ia: int
                    var ib: int
                    var ic: int
                    if indices.size() > 0:
                        ia = indices[triangle_index * 3]
                        ib = indices[triangle_index * 3 + 1]
                        ic = indices[triangle_index * 3 + 2]
                    else:
                        ia = triangle_index * 3
                        ib = triangle_index * 3 + 1
                        ic = triangle_index * 3 + 2

                    if ia >= vertex_count or ib >= vertex_count or ic >= vertex_count:
                        continue

                    var a: Vector3 = mesh_instance.global_transform * vertices[ia]
                    var b: Vector3 = mesh_instance.global_transform * vertices[ib]
                    var c: Vector3 = mesh_instance.global_transform * vertices[ic]
                    var cross := (b - a).cross(c - a)
                    var twice_area := cross.length()
                    if twice_area <= 0.000001:
                        continue

                    var ny := cross.y / twice_area
                    if ny >= 0.75:
                        up_count += 1
                        up_area += twice_area * 0.5
                        horizontal_min_y = min(horizontal_min_y, min(a.y, min(b.y, c.y)))
                        horizontal_max_y = max(horizontal_max_y, max(a.y, max(b.y, c.y)))
                    elif ny <= -0.75:
                        down_count += 1
                        down_area += twice_area * 0.5
                        horizontal_min_y = min(horizontal_min_y, min(a.y, min(b.y, c.y)))
                        horizontal_max_y = max(horizontal_max_y, max(a.y, max(b.y, c.y)))
                    elif abs(ny) <= 0.25:
                        vertical_count += 1
                    else:
                        other_count += 1

                var local_aabb := mesh_instance.get_aabb()
                var world_aabb := local_aabb * mesh_instance.global_transform
                result.append({
                    "node_path": str(mesh_instance.get_path()),
                    "mesh_name": mesh_instance.name,
                    "surface_index": surface_index,
                    "triangle_count": triangle_count,
                    "upward_horizontal_triangles": up_count,
                    "downward_horizontal_triangles": down_count,
                    "vertical_triangles": vertical_count,
                    "sloped_or_other_triangles": other_count,
                    "horizontal_triangles": up_count + down_count,
                    "upward_horizontal_area": up_area,
                    "downward_horizontal_area": down_area,
                    "horizontal_area": up_area + down_area,
                    "horizontal_min_y": horizontal_min_y if up_count + down_count > 0 else null,
                    "horizontal_max_y": horizontal_max_y if up_count + down_count > 0 else null,
                    "world_aabb_min": [world_aabb.position.x, world_aabb.position.y, world_aabb.position.z],
                    "world_aabb_max": [world_aabb.end.x, world_aabb.end.y, world_aabb.end.z]
                })

    for child in node.get_children():
        _collect_surfaces(child, result)
