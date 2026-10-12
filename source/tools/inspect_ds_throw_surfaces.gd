extends SceneTree
## Export CPU-skinned source-rest throwing triangles, without editor reimports.
## godot --headless --path . --script tools/inspect_ds_throw_surfaces.gd -- output.json
const Catalog = preload("res://scripts/ds_arena_catalog.gd")
var results: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: String in ["toy_throw", "anime_throw", "pyrus_throw", "aquos_throw", "subterra_throw", "haos_throw", "darkus_throw", "ventus_throw"]:
		var entry: Dictionary = Catalog.manifest().groups[id]
		var stage := Node3D.new()
		stage.name = id
		var fit: Dictionary = entry.pc_fit
		stage.scale = Vector3.ONE * float(fit.uniform_scale)
		var offset: Array = fit.source_offset
		stage.position = Vector3(offset[0], offset[1], offset[2]) * stage.scale.x
		root.add_child(stage)
		var triangles: Array = []
		for component: Dictionary in entry.components:
			var packed: PackedScene = load(str(component.path)) as PackedScene
			assert(packed != null, "Missing source throw GLB: " + str(component.path))
			var scene: Node3D = packed.instantiate() as Node3D
			stage.add_child(scene)
			for player: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
				player.stop()
			await process_frame
			for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
				_extract(mesh, str(component.id), str(scene.get_path_to(mesh)), triangles)
		results[id] = triangles
		stage.queue_free()
		await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var destination: String = args[0] if not args.is_empty() else "/tmp/ds-throw-triangles.json"
	var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	assert(file != null, "Cannot write source triangle report")
	file.store_string(JSON.stringify(results))
	file.close()
	print("CPU-skinned rest throw groups: ", results.size(), " -> ", destination)
	quit()

func _extract(instance: MeshInstance3D, component: String, mesh_path: String, output: Array) -> void:
	var skeleton: Skeleton3D = instance.get_node_or_null(instance.skeleton) as Skeleton3D
	var skin: Skin = instance.skin
	var transforms: Array[Transform3D] = []
	if skeleton != null and skin != null:
		for bind: int in skin.get_bind_count():
			var bone: int = skin.get_bind_bone(bind)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(bind))
			assert(bone >= 0, "Unmapped source skin bone")
			transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	for surface: int in instance.mesh.get_surface_count():
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var width: int = weights.size() / vertices.size() if not vertices.is_empty() else 0
		var points := PackedVector3Array()
		for index: int in vertices.size():
			var point := Vector3.ZERO
			var total: float = 0.0
			if width > 0 and not transforms.is_empty():
				for influence: int in width:
					var offset: int = index * width + influence
					var weight: float = weights[offset]
					if weight > 0.0:
						point += (transforms[bones[offset]] * vertices[index]) * weight
						total += weight
			points.append(point if total > 0.0 else instance.global_transform * vertices[index])
		if indices.is_empty():
			for index: int in vertices.size():
				indices.append(index)
		for index: int in range(0, indices.size() - 2, 3):
			output.append({"a": _v(points[indices[index]]), "b": _v(points[indices[index + 1]]), "c": _v(points[indices[index + 2]]), "component": component, "mesh": mesh_path, "surface": surface})

static func _v(point: Vector3) -> Array:
	return [point.x, point.y, point.z]
