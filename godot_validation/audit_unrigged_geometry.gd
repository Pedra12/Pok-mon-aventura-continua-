extends SceneTree

const TARGETS := [
	"eevee_pokemon.glb",
	"lucario.glb",
	"mew_pokemon.glb"
]
const OUTPUT_PATH := "res://unrigged_geometry_report.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = {"status": "running", "models": {}, "errors": []}
	for file_name in TARGETS:
		var resource_path: String = "res://assets/" + str(file_name)
		var packed := load(resource_path) as PackedScene
		if packed == null:
			report["errors"].append("Falha ao carregar " + file_name)
			continue
		var instance := packed.instantiate()
		if instance == null:
			report["errors"].append("Falha ao instanciar " + file_name)
			continue
		root.add_child(instance)
		await process_frame
		var model_data: Dictionary = {
			"root_name": instance.name,
			"meshes": [],
			"nodes": []
		}
		_inspect_recursive(instance, instance, model_data)
		report["models"][file_name] = model_data
		instance.queue_free()
		await process_frame
	report["status"] = "success" if report["errors"].is_empty() else "failed"
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Nao foi possivel gravar auditoria geometrica")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("UNRIGGED_GEOMETRY_AUDIT=" + JSON.stringify(report))
	quit(0 if report["status"] == "success" else 1)

func _vec3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _inspect_recursive(node: Node, root_node: Node, report: Dictionary) -> void:
	if node is Node3D:
		var spatial := node as Node3D
		report["nodes"].append({
			"path": str(root_node.get_path_to(node)),
			"name": node.name,
			"position": _vec3(spatial.position),
			"rotation_degrees": _vec3(spatial.rotation_degrees),
			"scale": _vec3(spatial.scale)
		})
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh != null:
			var mesh_data: Dictionary = {
				"path": str(root_node.get_path_to(node)),
				"mesh_resource_name": mesh.resource_name,
				"surface_count": mesh.get_surface_count(),
				"surfaces": [],
				"local_aabb_min": _vec3(mesh_instance.get_aabb().position),
				"local_aabb_max": _vec3(mesh_instance.get_aabb().end),
				"world_aabb_min": _vec3((mesh_instance.global_transform * mesh_instance.get_aabb()).position),
				"world_aabb_max": _vec3((mesh_instance.global_transform * mesh_instance.get_aabb()).end)
			}
			for surface_index in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones = arrays[Mesh.ARRAY_BONES]
				var weights = arrays[Mesh.ARRAY_WEIGHTS]
				var surface_data: Dictionary = {
					"surface": surface_index,
					"vertex_count": vertices.size(),
					"has_skin_arrays": bones.size() > 0 and weights.size() > 0
				}
				if not vertices.is_empty():
					var minimum := vertices[0]
					var maximum := vertices[0]
					var sum := Vector3.ZERO
					for vertex in vertices:
						minimum = minimum.min(vertex)
						maximum = maximum.max(vertex)
						sum += vertex
					surface_data["vertex_min"] = _vec3(minimum)
					surface_data["vertex_max"] = _vec3(maximum)
					surface_data["vertex_centroid"] = _vec3(sum / float(vertices.size()))
				mesh_data["surfaces"].append(surface_data)
			report["meshes"].append(mesh_data)
	for child in node.get_children():
		_inspect_recursive(child, root_node, report)
