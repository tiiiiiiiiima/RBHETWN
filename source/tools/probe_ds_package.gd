extends SceneTree
## Run with the exported PCK from an empty workdir, never with --path source.
## Reports source resource paths resolved through Godot import remaps.

var failures: Array[String] = []
var checks: int = 0
var paths: Dictionary = {}
var manifests: Array[String] = []
var packed_files: Array[String] = []
var counters: Dictionary = {"textures": 0, "scenes": 0, "meshes": 0, "material_textures": 0, "animation_players": 0, "animation_clips": 0, "audio_streams": 0}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _walk(directory: String) -> void:
	var access: DirAccess = DirAccess.open(directory)
	if access == null:
		_check(false, "Packed directory absent: " + directory)
		return
	for basename: String in access.get_files():
		packed_files.append(directory.path_join(basename))
	for basename: String in access.get_directories():
		if basename != "." and basename != "..":
			_walk(directory.path_join(basename))


func _gather(value: Variant) -> void:
	if value is String and (str(value).begins_with("res://assets/ds/") or str(value).begins_with("res://assets/doc/") or str(value).begins_with("res://assets/sfm/") or str(value).begins_with("res://assets/monster_batch/")):
		paths[str(value)] = true
	elif value is Dictionary:
		for key: Variant in value:
			_gather(value[key])
	elif value is Array:
		for element: Variant in value:
			_gather(element)


func _scene_counts(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		counters.meshes += 1
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		for surface: int in mesh_node.mesh.get_surface_count():
			var material: Material = mesh_node.get_active_material(surface)
			if material is StandardMaterial3D:
				var texture: Texture2D = (material as StandardMaterial3D).albedo_texture
				if texture != null:
					counters.material_textures += 1
					_check(texture.get_width() > 0 and texture.get_height() > 0, "Packed native material has a nonempty albedo texture: " + str(node.name))
	if node is AnimationPlayer:
		counters.animation_players += 1
		for animation_name: String in (node as AnimationPlayer).get_animation_list():
			if animation_name != "RESET":
				counters.animation_clips += 1
	for child: Node in node.get_children():
		_scene_counts(child)


func _run() -> void:
	var report_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
	_check(not report_path.is_empty(), "An absolute --report path is required")
	_walk("res://")
	var forbidden_paths: Array[String] = []
	for path: String in packed_files:
		var basename: String = path.get_file().to_lower()
		var extension: String = basename.get_extension()
		if extension in ["nds", "srl", "iso", "wbfs", "gcm", "cia", "3ds"] or basename.begins_with("bios") or basename.begins_with("firmware"):
			forbidden_paths.append(path)
		if (path.begins_with("res://assets/ds/") or path.begins_with("res://assets/doc/") or path.begins_with("res://assets/sfm/") or path.begins_with("res://assets/monster_batch/")) and extension == "json":
			manifests.append(path)
		if path.begins_with("res://assets/ds/") or path.begins_with("res://assets/doc/") or path.begins_with("res://assets/sfm/") or path.begins_with("res://assets/monster_batch/"):
			var source_path: String = path.trim_suffix(".import").trim_suffix(".remap")
			if source_path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bin", "ogv", "glb", "tscn"]:
				paths[source_path] = true
	_check(forbidden_paths.is_empty(), "ROM/BIOS must not ship: " + JSON.stringify(forbidden_paths))
	manifests.append("res://assets/imported/catalog.json")
	for path: String in manifests:
		_check(FileAccess.file_exists(path), "Packed manifest exists: " + path)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "Packed manifest is a dictionary: " + path)
		if parsed is Dictionary:
			_gather(parsed)
	_check(manifests.has("res://assets/ds/ui_manifest.json"), "Native DS UI manifest included")
	_check(manifests.has("res://assets/ds/arenas/arena_manifest.json"), "Native DS arena manifest included")
	_check(manifests.has("res://assets/doc/models/model_manifest.json"), "Native DoC forms manifest included")
	_check(manifests.has("res://assets/sfm/battle_field/manifest.json"), "Native SFM field manifest included")
	_check(manifests.has("res://assets/monster_batch/model_manifest.json") and manifests.has("res://assets/monster_batch/cards/manifest.json"), "Monster batch models and card manifests included")
	_check(not paths.is_empty(), "DS manifests reference native resources")
	var checked_paths: Array[String] = []
	for path: String in paths:
		if path.get_extension() == "json":
			continue
		_check(not path.contains(".."), "DS path stays inside project: " + path)
		if path.ends_with(".webp.bin"):
			_check(FileAccess.file_exists(path), "Packed card byte resource exists: " + path)
			var image: Image = Image.new()
			_check(image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and image.get_width() > 0 and image.get_height() > 0, "Packed card byte resource decodes: " + path)
			counters.textures += 1
			checked_paths.append(path)
			continue
		_check(ResourceLoader.exists(path), "Exported DS resource exists: " + path)
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_check(resource != null, "Exported DS resource loads: " + path)
		if resource is Texture2D:
			counters.textures += 1
			_check((resource as Texture2D).get_width() > 0 and (resource as Texture2D).get_height() > 0, "Native DS texture is nonempty: " + path)
		elif resource is AudioStream:
			counters.audio_streams += 1
			_check((resource as AudioStream).get_length()>0,"Packed audio is nonempty: "+path)
		elif resource is PackedScene:
			counters.scenes += 1
			var instance: Node = (resource as PackedScene).instantiate()
			_check(instance is Node3D, "Native DS 3D scene instantiates: " + path)
			root.add_child(instance)
			await process_frame
			_scene_counts(instance)
			instance.queue_free()
			await process_frame
		checked_paths.append(path)
	checked_paths.sort()
	_check(counters.textures > 0 and counters.scenes > 0 and counters.meshes > 0, "Packed native DS images and mesh scenes are present")
	_check(counters.material_textures > 0, "Packed native DS scene materials contain decoded textures")
	_check(manifests.has("res://assets/ds/audio/manifest.json") and counters.audio_streams==609,"All original DS audio streams ship in PCK")
	var report: Dictionary = {
		"version": str(ProjectSettings.get_setting("application/config/version")),
		"commandline_arguments": OS.get_cmdline_args(),
		"execution_workdir": OS.get_environment("PWD"),
		"resource_root": ProjectSettings.globalize_path("res://"),
		"workdir_has_source_project": FileAccess.file_exists(OS.get_environment("PWD").path_join("project.godot")),
		"godot": Engine.get_version_info(), "checks": checks, "failures": failures,
		"source_project_required": false, "windows_execution_tested": false,
		"packed_file_count": packed_files.size(), "ds_manifest_paths": manifests,
		"native_ds_resource_count": checked_paths.size(), "native_ds_resources": checked_paths,
		"rom_bios_files": forbidden_paths,
		"native_ds_counts": counters, "rom_bios_name_scan_passed": failures.filter(func(value: String) -> bool: return value.begins_with("ROM/BIOS")).is_empty(),
		"renderer": RenderingServer.get_current_rendering_method(),
	}
	if not report_path.is_empty():
		var output: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		if output == null:
			push_error("Could not write report: " + report_path)
			quit(1)
			return
		output.store_string(JSON.stringify(report, "\t") + "\n")
	print("DS PACKAGED RESOURCES: %d paths, %d checks, %d failures" % [checked_paths.size(), checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
