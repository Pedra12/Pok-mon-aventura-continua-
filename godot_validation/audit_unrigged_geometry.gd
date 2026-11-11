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
				var bones: Variant = arrays[Mesh.ARRAY_BONES]
				var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
				var primitive_type := mesh.surface_get_primitive_type(surface_index)
				var topology_components: Array = []
				if primitive_type == Mesh.PRIMITIVE_TRIANGLES:
					topology_components = _analyze_components(vertices, arrays[Mesh.ARRAY_INDEX])
				var surface_data: Dictionary = {
					"surface": surface_index,
					"primitive_type": primitive_type,
					"primitive_is_triangles": primitive_type == Mesh.PRIMITIVE_TRIANGLES,
					"vertex_count": vertices.size(),
					"has_skin_arrays": bones is PackedInt32Array and bones.size() > 0 and weights is PackedFloat32Array and weights.size() > 0,
					"topology_components": topology_components
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


func _find_root(parent: Array[int], value: int) -> int:
	if parent[value] != value:
		parent[value] = _find_root(parent, parent[value])
	return parent[value]

func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find_root(parent, a)
	var root_b := _find_root(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a

func _analyze_components(vertices: PackedVector3Array, index_data: Variant) -> Array:
	var result: Array = []
	if vertices.is_empty():
		return result
	var triangle_indices := PackedInt32Array()
	if index_data is PackedInt32Array and not index_data.is_empty():
		triangle_indices = index_data
	else:
		for index in range(vertices.size()):
			triangle_indices.append(index)
	var parent: Array[int] = []
	for index in range(vertices.size()):
		parent.append(index)
	for start in range(0, triangle_indices.size() - 2, 3):
		var a := int(triangle_indices[start])
		var b := int(triangle_indices[start + 1])
		var c := int(triangle_indices[start + 2])
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size():
			continue
		_union(parent, a, b)
		_union(parent, b, c)
	var groups: Dictionary = {}
	for vertex_index in range(vertices.size()):
		var root_index := _find_root(parent, vertex_index)
		if not groups.has(root_index):
			groups[root_index] = {
				"vertex_count": 0,
				"triangle_count": 0,
				"min": vertices[vertex_index],
				"max": vertices[vertex_index],
				"sum": Vector3.ZERO
			}
		var group: Dictionary = groups[root_index]
		group["vertex_count"] += 1
		var current_min: Vector3 = group["min"]
		var current_max: Vector3 = group["max"]
		var current_sum: Vector3 = group["sum"]
		group["min"] = current_min.min(vertices[vertex_index])
		group["max"] = current_max.max(vertices[vertex_index])
		group["sum"] = current_sum + vertices[vertex_index]
	for start in range(0, triangle_indices.size() - 2, 3):
		var a := int(triangle_indices[start])
		var b := int(triangle_indices[start + 1])
		var c := int(triangle_indices[start + 2])
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size():
			continue
		var root_index := _find_root(parent, a)
		if groups.has(root_index):
			groups[root_index]["triangle_count"] += 1
	var roots: Array = groups.keys()
	roots.sort_custom(func(a: Variant, b: Variant) -> bool: return int(groups[a]["vertex_count"]) > int(groups[b]["vertex_count"]))
	for root_index in roots:
		var group: Dictionary = groups[root_index]
		var count := int(group["vertex_count"])
		var sum_value: Vector3 = group["sum"]
		var min_value: Vector3 = group["min"]
		var max_value: Vector3 = group["max"]
		result.append({
			"vertex_count": count,
			"triangle_count": int(group["triangle_count"]),
			"bounds_min": _vec3(min_value),
			"bounds_max": _vec3(max_value),
			"centroid": _vec3(sum_value / float(count))
		})
	return result
