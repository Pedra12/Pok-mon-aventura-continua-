extends SceneTree

const TARGETS := ["eevee_pokemon.glb", "lucario.glb", "mew_pokemon.glb"]
const OUTPUT_DIR := "res://component_diagnostics"
const REPORT_PATH := "res://component_diagnostics/component_visual_report.json"
const VIEW_SIZE := Vector2i(1200, 900)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var report: Dictionary = {"status": "running", "models": {}, "errors": []}
	for file_name in TARGETS:
		var packed := load("res://assets/" + file_name) as PackedScene
		if packed == null:
			report["errors"].append("Falha ao carregar " + file_name)
			continue
		var instance := packed.instantiate()
		if instance == null:
			report["errors"].append("Falha ao instanciar " + file_name)
			continue
		var model_report: Dictionary = {"meshes": [], "views": []}
		_colorize_recursive(instance, instance, model_report)
		var viewport := SubViewport.new()
		viewport.size = VIEW_SIZE
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(instance)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.current = true
		viewport.add_child(camera)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
		light.light_energy = 1.2
		viewport.add_child(light)
		var bounds := _world_bounds(instance)
		if bounds.size.length() < 0.0001:
			report["errors"].append("Bounds vazios em " + file_name)
			viewport.queue_free()
			await process_frame
			continue
		var center: Vector3 = bounds.get_center()
		var max_dimension: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		camera.size = maxf(max_dimension * 1.35, 0.5)
		var distance: float = max_dimension * 2.5 + 1.0
		var safe_name: String = file_name.get_basename()
		var views: Array = [
			{"name": "frente", "direction": Vector3(0, 0, 1), "up": Vector3.UP},
			{"name": "lado", "direction": Vector3(1, 0, 0), "up": Vector3.UP},
			{"name": "topo", "direction": Vector3(0, 1, 0), "up": Vector3(0, 0, -1)}
		]
		for view_data in views:
			var direction: Vector3 = view_data["direction"]
			camera.position = center + direction * distance
			camera.look_at(center, view_data["up"])
			await process_frame
			await process_frame
			var image := viewport.get_texture().get_image()
			var output_path: String = OUTPUT_DIR.path_join(safe_name + "_" + str(view_data["name"]) + ".png")
			var save_error: int = image.save_png(output_path)
			if save_error != OK:
				report["errors"].append("Falha ao salvar " + output_path + " codigo=" + str(save_error))
			else:
				model_report["views"].append(output_path)
		model_report["world_bounds"] = {
			"min": _vec3(bounds.position),
			"max": _vec3(bounds.end),
			"size": _vec3(bounds.size),
			"center": _vec3(center)
		}
		report["models"][file_name] = model_report
		viewport.queue_free()
		await process_frame
	report["status"] = "success" if report["errors"].is_empty() and report["models"].size() == TARGETS.size() else "failed"
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Nao foi possivel gravar relatorio visual")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("COMPONENT_VISUAL_DIAGNOSTIC=" + JSON.stringify({"status": report["status"], "models": report["models"].size(), "errors": report["errors"]}))
	quit(0 if report["status"] == "success" else 1)

func _vec3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _world_bounds(node: Node) -> AABB:
	var found := false
	var result := AABB()
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var transformed: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			result = transformed
			found = true
	for child in node.get_children():
		var child_bounds := _world_bounds(child)
		if child_bounds.size.length() > 0.0001:
			if found:
				result = result.merge(child_bounds)
			else:
				result = child_bounds
				found = true
	return result if found else AABB()

func _colorize_recursive(node: Node, root_node: Node, report: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var original := mesh_instance.mesh
		if original != null:
			var diagnostic_mesh := ArrayMesh.new()
			var mesh_report: Dictionary = {
				"path": str(root_node.get_path_to(node)),
				"name": str(node.name),
				"surface_count": original.get_surface_count(),
				"surfaces": []
			}
			for surface_index in range(original.get_surface_count()):
				var arrays: Array = original.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				var component_data := _component_labels(vertices, indices)
				var labels: PackedInt32Array = component_data["labels"]
				var colors := PackedColorArray()
				for vertex_index in range(vertices.size()):
					var component_id: int = labels[vertex_index]
					if component_id < 0:
						colors.append(Color(0.35, 0.35, 0.35, 1.0))
					else:
						var hue: float = fposmod(float(component_id) * 0.61803398875 + float(surface_index) * 0.137, 1.0)
						colors.append(Color.from_hsv(hue, 0.78, 0.95, 1.0))
				arrays[Mesh.ARRAY_COLOR] = colors
				diagnostic_mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface_index), arrays)
				var material := StandardMaterial3D.new()
				material.vertex_color_use_as_albedo = true
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				diagnostic_mesh.surface_set_material(surface_index, material)
				mesh_report["surfaces"].append({
					"surface": surface_index,
					"vertex_count": vertices.size(),
					"component_count": component_data["components"].size(),
					"components": component_data["components"]
				})
			mesh_instance.mesh = diagnostic_mesh
			report["meshes"].append(mesh_report)
	for child in node.get_children():
		_colorize_recursive(child, root_node, report)

func _find_root(parent: Array[int], value: int) -> int:
	if parent[value] != value:
		parent[value] = _find_root(parent, parent[value])
	return parent[value]

func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find_root(parent, a)
	var root_b := _find_root(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a

func _component_labels(vertices: PackedVector3Array, index_data: Variant) -> Dictionary:
	var labels := PackedInt32Array()
	labels.resize(vertices.size())
	labels.fill(-1)
	var result: Array = []
	if vertices.is_empty():
		return {"labels": labels, "components": result}
	var indices := PackedInt32Array()
	if index_data is PackedInt32Array and not index_data.is_empty():
		indices = index_data
	else:
		for vertex_index in range(vertices.size()):
			indices.append(vertex_index)
	var parent: Array[int] = []
	for vertex_index in range(vertices.size()):
		parent.append(vertex_index)
	for start in range(0, indices.size() - 2, 3):
		var a := int(indices[start])
		var b := int(indices[start + 1])
		var c := int(indices[start + 2])
		if a >= 0 and b >= 0 and c >= 0 and a < vertices.size() and b < vertices.size() and c < vertices.size():
			_union(parent, a, b)
			_union(parent, b, c)
	var groups: Dictionary = {}
	for vertex_index in range(vertices.size()):
		var root_index := _find_root(parent, vertex_index)
		if not groups.has(root_index):
			groups[root_index] = {"vertices": [], "triangles": 0, "min": vertices[vertex_index], "max": vertices[vertex_index], "sum": Vector3.ZERO}
		var group: Dictionary = groups[root_index]
		group["vertices"].append(vertex_index)
		group["min"] = (group["min"] as Vector3).min(vertices[vertex_index])
		group["max"] = (group["max"] as Vector3).max(vertices[vertex_index])
		group["sum"] = (group["sum"] as Vector3) + vertices[vertex_index]
	for start in range(0, indices.size() - 2, 3):
		var a := int(indices[start])
		if a >= 0 and a < vertices.size():
			var root_index := _find_root(parent, a)
			if groups.has(root_index):
				groups[root_index]["triangles"] += 1
	var roots: Array = groups.keys()
	roots.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (groups[a]["vertices"] as Array).size() > (groups[b]["vertices"] as Array).size()
	)
	for component_id in range(roots.size()):
		var group: Dictionary = groups[roots[component_id]]
		var member_vertices: Array = group["vertices"]
		var count: int = member_vertices.size()
		for vertex_index in member_vertices:
			labels[int(vertex_index)] = component_id
		var minimum: Vector3 = group["min"]
		var maximum: Vector3 = group["max"]
		var centroid: Vector3 = group["sum"] / float(count)
		result.append({
			"id": component_id,
			"vertex_count": count,
			"triangle_count": int(group["triangles"]),
			"bounds_min": _vec3(minimum),
			"bounds_max": _vec3(maximum),
			"centroid": _vec3(centroid)
		})
	return {"labels": labels, "components": result}
