extends RefCounted
## Source DS 3D battle environments. NitroFS provenance is stored per component.
## The visual stage is independent of the board's placement and roll rules.

const MANIFEST_PATH: String = "res://assets/ds/arenas/arena_manifest.json"
const ELEMENTS: Array[String] = ["pyrus", "aquos", "subterra", "haos", "darkus", "ventus", "toy", "anime"]
const PLAYABLE_FIELDS: Array[String] = ["ds_toy", "ds_anime", "ds_pyrus", "ds_aquos", "ds_subterra", "ds_haos", "ds_darkus", "ds_ventus"]
static var _manifest: Dictionary = {}
static var _scenes: Dictionary = {}
const MAX_SCENES: int = 16

static func cached_scene(path: String) -> PackedScene:
	if _scenes.has(path):
		var existing: PackedScene=_scenes[path]
		_scenes.erase(path); _scenes[path]=existing
		return existing
	var scene: PackedScene=load(path) as PackedScene
	if scene==null: return null
	while _scenes.size()>=MAX_SCENES: _scenes.erase(_scenes.keys()[0])
	_scenes[path]=scene
	return scene


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


static func stage_id_for(theme: String) -> String:
	var value: String = theme.to_lower().trim_prefix("ds_").trim_suffix("_battle").trim_suffix("_throw")
	if value in ELEMENTS:
		return value
	match value:
		"canyon": return "pyrus"
		"glacier": return "aquos"
		"anime_board": return "anime"
		_: return "toy"


static func floor_bounds(theme: String) -> Vector2:
	var fit: Dictionary = manifest().get("groups", {}).get(stage_id_for(theme)+"_throw", {}).get("pc_fit", {})
	var bounds: Dictionary = fit.get("world_floor_bounds", {})
	var low: Array = bounds.get("min", [-9,0,-9])
	var high: Array = bounds.get("max", [9,0,9])
	return Vector2(maxf(absf(float(low[0])),absf(float(high[0]))),maxf(absf(float(low[2])),absf(float(high[2]))))


static func play_bounds(theme: String) -> Vector2:
	# Pyrus SetData also contains distant camera/backdrop records. They are
	# not playable floor; frame the native platforms and nearby item lanes.
	if stage_id_for(theme)=="pyrus":
		return floor_bounds(theme)+Vector2(4,4)
	var entry: Dictionary = manifest().get("groups", {}).get(stage_id_for(theme)+"_throw", {})
	var measured: Array = entry.get("play_area", {}).get("half_extents", [])
	return Vector2(float(measured[0]),float(measured[1])) if measured.size()==2 else floor_bounds(theme)+Vector2(2,2)


static func collision_height(theme: String) -> float:
	return float(manifest().get("groups", {}).get(stage_id_for(theme)+"_throw", {}).get("play_area", {}).get("collision_ceiling", 20.0))


static func make_battle_stage(theme: String = "toy", animate: bool = true) -> Node3D:
	return _make_group(stage_id_for(theme) + "_battle", animate)


static func make_throw_stage(theme: String, _animate: bool = true) -> Node3D:
	if theme not in PLAYABLE_FIELDS:
		return null
	var group_id: String = stage_id_for(theme) + "_throw"
	var field: Node3D = _make_group(group_id, false)
	if field != null:
		field.set_meta("selected_battle_theme", theme)
		field.set_meta("throw_field_adaptation", "Native source-skinned rest geometry with measured static collision; shared PC analytic roll and card rules")
		field.set_meta("source_joint_animation_frozen", true)
		field.set_meta("visual_only_collision", false)
	return field


static func make_source_preview(group_id: String, animate: bool = true) -> Node3D:
	## Independent source preview: animation is visual only. Playable throws
	## freeze the rest geometry to match the measured static PC collision.
	return _make_group(group_id, animate)


static func _make_group(group_id: String, animate: bool) -> Node3D:
	var groups: Dictionary = manifest().get("groups", {})
	if not groups.has(group_id):
		return null
	var entry: Dictionary = groups[group_id]
	var root: Node3D = Node3D.new()
	root.name = "DSStage_" + group_id
	root.set_meta("source_origin", "user_ds_nitrofs")
	root.set_meta("ds_group_id", group_id)
	root.set_meta("native_geometry", true)
	root.set_meta("native_texture_coordinates", true)
	root.set_meta("source_rom_sha256", manifest().get("source", {}).get("rom_sha256", ""))
	root.set_meta("visual_only_collision", true)
	root.set_meta("surface_y", 0.0)
	var fit: Dictionary = entry.get("pc_fit", {})
	root.scale = Vector3.ONE * float(fit.get("uniform_scale", 1.0))
	var offset: Array = fit.get("source_offset", [0.0, 0.0, 0.0])
	root.position = Vector3(float(offset[0]), float(offset[1]), float(offset[2])) * root.scale.x
	root.set_meta("pc_fit", fit.duplicate(true))
	root.set_meta("ds_far_hint", float(fit.get("camera_far_hint", 150.0)))
	for component: Dictionary in entry.get("components", []):
		var path: String = str(component.get("path", ""))
		var packed: PackedScene = cached_scene(path)
		if packed == null:
			root.free()
			return null
		var scene: Node3D = packed.instantiate() as Node3D
		scene.name = str(component.get("id", "SourceComponent"))
		scene.set_meta("source_model", component.get("source_model", {}).get("path", ""))
		scene.set_meta("source_sha256", component.get("source_model", {}).get("sha256", ""))
		root.add_child(scene)
		_prepare(scene, animate)
	if animate:
		var uv = load("res://scripts/ds_stage_uv.gd").new()
		uv.bind_stage(root,group_id)
		root.add_child(uv)
	return root


static func _prepare(node: Node, animate: bool) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_node.mesh != null:
			for surface: int in mesh_node.mesh.get_surface_count():
				var original: Material = mesh_node.get_active_material(surface)
				if original is StandardMaterial3D:
					var material: StandardMaterial3D = original.duplicate() as StandardMaterial3D
					material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
					mesh_node.set_surface_override_material(surface, material)
	if animate and node is AnimationPlayer:
		var player: AnimationPlayer = node as AnimationPlayer
		for animation_name: String in player.get_animation_list():
			if animation_name == "RESET":
				continue
			var animation: Animation = player.get_animation(animation_name)
			if animation != null and animation.length > 0.0:
				animation.loop_mode = Animation.LOOP_LINEAR
				player.play(animation_name)
				break
	for child: Node in node.get_children():
		_prepare(child, animate)
