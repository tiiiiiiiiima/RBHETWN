extends RefCounted
## Lazy source imports with original texture variants and explicit form fallbacks.
## The independently authored Dragonoid assets remain available as a fallback.

const AssetCatalog = preload("res://scripts/asset_catalog.gd")
const TextureVideo = preload("res://scripts/source_texture_video.gd")
const DRAGON_SCENE = preload("res://assets/models/dragonoid.glb")
const BALL_SCENE = preload("res://assets/models/dragonoid_ball.glb")
const MAX_SCENE_CACHE: int = 24
const MAX_TEXTURE_CACHE: int = 8
const DESKTOP_ACTION_CLIP: String = "ds_desktop/desktop_action"
const DESKTOP_FLOOR_PATH: String = "res://assets/ds/models/desktop_action_floor.json"
const OBSERVED_DESKTOP_ACTIONS: Dictionary = {
	"dragonoid": "Aerial forward charge",
	"gorem": "Overhead arm slam",
	"tigrerra": "Aerial leap and charge",
	"preyas": "Aerial leap and charge",
	"skyress": "Forward flight gesture",
	"hydranoid": "Neck and head roar-lunge",
	"robotallion": "Raised arm followed by a forward punch or shot gesture",
	"leonidas": "Aerial forward charge",
}
static var _scene_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _desktop_floor: Dictionary = {}


static func make_creature(parent: Node3D, species: String, attribute: String, reduced_motion: bool = false, form: String = "toy") -> Node3D:
	if not is_instance_valid(parent) or not ["toy", "battle"].has(form):
		return null
	var imported: Node3D = _make_imported(parent, species, attribute, form)
	if imported != null:
		var video: VideoStreamPlayer = imported.get_node_or_null("TextureVideo") as VideoStreamPlayer
		if video != null and reduced_motion:
			video.paused = true
		if str(imported.get_meta("actual_form", "")) == "toy" and _open_native_form(imported, reduced_motion):
			imported.set_meta("visual_states", [])
		elif str(imported.get_meta("actual_form", "")) == "battle" and bool(imported.get_meta("native_geometry", false)):
			imported.set_meta("visual_states", [])
			play_battle_animation(imported, "idle")
		else:
			_reveal(imported, reduced_motion, false)
		return imported
	if species.to_lower() != "dragonoid":
		return null
	var creature: Node3D = _instance(DRAGON_SCENE, parent, "Dragonoid", attribute)
	creature.set_meta("requested_form", form)
	creature.set_meta("actual_form", "toy")
	creature.set_meta("requested_attribute", attribute)
	creature.set_meta("texture_attribute", attribute)
	creature.set_meta("exact_attribute", true)
	_reveal(creature, reduced_motion, true)
	return creature


static func _reveal(creature: Node3D, reduced_motion: bool, articulated: bool) -> void:
	var visual_states: Array[Dictionary] = []
	if not reduced_motion and creature.is_inside_tree():
		creature.scale = Vector3.ONE * 0.18
		var unfold: Tween = creature.create_tween()
		unfold.tween_property(creature, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		visual_states.append({"tween": unfold, "node": weakref(creature), "final": {"scale": Vector3.ONE}})
		for side: int in ([-1, 1] if articulated else []):
			var pivot: Node3D = creature.find_child("WingPivot_L" if side < 0 else "WingPivot_R", true, false) as Node3D
			if pivot == null:
				continue
			pivot.rotation.z = float(side) * 0.90
			pivot.rotation.y = -float(side) * 0.25
			var deploy: Tween = pivot.create_tween()
			deploy.set_parallel(true)
			deploy.tween_property(pivot, "rotation:z", 0.0, 0.50).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			deploy.tween_property(pivot, "rotation:y", 0.0, 0.45)
			visual_states.append({"tween": deploy, "node": weakref(pivot), "final": {"rotation:z": 0.0, "rotation:y": 0.0}})
	creature.set_meta("visual_states", visual_states)


static func make_ball(parent: Node3D, attribute: String, owner: int, _reduced_motion: bool = false, species: String = "Dragonoid") -> Node3D:
	if not is_instance_valid(parent) or owner < 0 or owner > 1:
		return null
	var imported: Node3D = _make_imported(parent, species, attribute, "ball", owner)
	if imported != null:
		var video: VideoStreamPlayer = imported.get_node_or_null("TextureVideo") as VideoStreamPlayer
		if video != null:
			video.paused = _reduced_motion
		var roles: Dictionary = imported.get_meta("animation_roles", {})
		var player: AnimationPlayer = _form_player(imported)
		var opening: String = str(roles.get("open", ""))
		if player != null and not opening.is_empty() and player.has_animation(opening):
			player.play(opening)
			player.seek(0.0, true)
			player.pause()
		_normalize_closed_form(imported)
		imported.set_meta("visual_states", [])
		return imported
	if species.to_lower() != "dragonoid":
		return null
	var ball: Node3D = _instance(BALL_SCENE, parent, "DragonoidBall", attribute, owner)
	ball.set_meta("owner", owner)
	ball.set_meta("visual_states", [])
	ball.set_meta("requested_form", "ball")
	ball.set_meta("actual_form", "ball")
	ball.set_meta("requested_attribute", attribute)
	ball.set_meta("texture_attribute", attribute)
	ball.set_meta("exact_attribute", true)
	return ball


static func _normalize_closed_form(creature: Node3D) -> void:
	# Visual diameter follows the shared physical sphere, including old static
	# skins. Correct a donor's origin before rolling rotates the whole wrapper.
	for skeleton: Skeleton3D in creature.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	var bounds: AABB = visual_bounds(creature)
	var diameter: float = maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	if diameter <= 0.000001 or not bounds.size.is_finite(): return
	var factor: float = 0.88/diameter
	var model: Node3D = creature.get_child(0) as Node3D
	if model != null:
		model.scale *= factor
		model.position = (model.position-bounds.get_center())*factor
	creature.set_meta("physical_diameter",0.88)


static func clear_caches() -> void:
	_scene_cache.clear()
	_texture_cache.clear()


static func visual_bounds(creature: Node3D) -> AABB:
	# Mesh AABBs describe the bind pose, not the current source skin. Collection
	# framing must account for transformed limbs and the actual opening pose.
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var relative: Transform3D = creature.global_transform.affine_inverse()
	for candidate: Node in creature.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = candidate as MeshInstance3D
		if mesh.mesh == null:
			continue
		var skeleton: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		var skin_transforms: Array[Transform3D] = []
		if skeleton != null and mesh.skin != null:
			for bind: int in mesh.skin.get_bind_count():
				var bone: int = mesh.skin.get_bind_bone(bind)
				if bone < 0:
					bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
				skin_transforms.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: Variant = arrays[Mesh.ARRAY_BONES]
			var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			var skinned: bool = not skin_transforms.is_empty() and bones != null and not bones.is_empty()
			var influences: int = bones.size() / vertices.size() if skinned else 0
			for index: int in vertices.size():
				var point: Vector3 = vertices[index]
				if skinned:
					point = Vector3.ZERO
					for influence: int in influences:
						var offset: int = index * influences + influence
						point += (skin_transforms[bones[offset]] * vertices[index]) * weights[offset]
					point = relative * skeleton.global_transform * point
				else:
					point = relative * mesh.global_transform * point
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum) if minimum.is_finite() else AABB()


static func _form_player(creature: Node3D) -> AnimationPlayer:
	for candidate: Node in creature.find_children("*", "AnimationPlayer", true, false):
		return candidate as AnimationPlayer
	return null


static func _open_native_form(creature: Node3D, reduced_motion: bool) -> bool:
	var player: AnimationPlayer = _form_player(creature)
	var clip: String = str((creature.get_meta("animation_roles", {}) as Dictionary).get("open", ""))
	if player == null or clip.is_empty() or not player.has_animation(clip):
		return false
	if str(creature.get_meta("source", {}).get("origin", "")) == "user_doc_nitrofs":
		clip = stable_opening(player, clip)
	_set_battle_animation_loop(player, clip, Animation.LOOP_NONE)
	player.play(clip)
	player.seek(0.0, true)
	player.set_meta("unfold_clip", clip)
	creature.set_meta("unfold_player", weakref(player))
	if reduced_motion:
		finish_unfold(player)
	return true


static func stable_opening(player: AnimationPlayer, native_name: String) -> String:
	const NAME: String = "doc_desktop/open"
	if player.has_animation(NAME):
		return NAME
	var native: Animation = player.get_animation(native_name)
	var track: int = _named_position_track(native, "sphere")
	if track < 0:
		return native_name
	var adapted: Animation = native.duplicate(true) as Animation
	var anchor: Vector3 = native.position_track_interpolate(track, 0.0)
	for key: int in adapted.track_get_key_count(track):
		var position: Vector3 = adapted.track_get_key_value(track, key)
		position.x = anchor.x
		position.z = anchor.z
		adapted.track_set_key_value(track, key, position)
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("open", adapted)
	player.add_animation_library("doc_desktop", library)
	return NAME


static func finish_unfold(player: AnimationPlayer) -> void:
	if not is_instance_valid(player):
		return
	var clip: String = str(player.get_meta("unfold_clip", ""))
	if not clip.is_empty() and player.has_animation(clip):
		player.play(clip)
		player.seek(player.get_animation(clip).length, true)
		player.pause()


static func play_battle_animation(creature: Node3D, role: String) -> bool:
	if not is_instance_valid(creature) or str(creature.get_meta("actual_form", "")) != "battle":
		return false
	var player: AnimationPlayer = creature.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		for candidate: Node in creature.find_children("*", "AnimationPlayer", true, false):
			player = candidate as AnimationPlayer
			break
	if player == null:
		return false
	var roles: Dictionary = creature.get_meta("animation_roles", {})
	var animation_name: String = str(roles.get(role, role))
	if role == "attack" and creature.has_meta("desktop_ability_floor"):
		animation_name = _doc_desktop_ability(creature, player, animation_name)
	elif role != "idle" and creature.get_meta("desktop_role_floor", {}).has(role):
		animation_name = _doc_desktop_role(creature, player, animation_name, role)
	if role == "attack" and not roles.has("attack"):
		animation_name = _desktop_action(creature, player, roles)
	if not player.has_animation(animation_name):
		return false
	if role == "idle":
		_set_battle_animation_loop(player, animation_name, Animation.LOOP_LINEAR)
		if player.current_animation == animation_name and player.is_playing():
			return true
	else:
		_set_battle_animation_loop(player, animation_name, Animation.LOOP_NONE)
		# play() keeps the current time when the same clip is already running.
		# Every hit or activation is a new action, including rapid repeats.
		if player.current_animation == animation_name:
			player.stop(true)
	_reset_doc_pose(creature)
	# The floor curve bounds actual source poses. A crossfade from a different
	# pose can bend the mesh beneath that envelope, so adapted actions cut to
	# their validated first pose instead of mixing two unrelated trajectories.
	player.play(animation_name, 0.0 if animation_name == DESKTOP_ACTION_CLIP or animation_name.begins_with("doc_desktop/") else 0.1)
	if role != "idle" and roles.has("idle") and not player.has_meta("ds_idle_connected"):
		player.set_meta("ds_idle_connected", true)
		var weak_player: WeakRef = weakref(player)
		var weak_creature: WeakRef = weakref(creature)
		var idle: String = str(roles.idle)
		player.animation_finished.connect(func(_finished: StringName):
			var live: AnimationPlayer = weak_player.get_ref() as AnimationPlayer
			if live != null and live.has_animation(idle):
				var actor: Node3D = weak_creature.get_ref() as Node3D
				if actor != null: _reset_doc_pose(actor)
				_set_battle_animation_loop(live, idle, Animation.LOOP_LINEAR)
				live.play(idle, 0.0 if str(_finished) == DESKTOP_ACTION_CLIP or str(_finished).begins_with("doc_desktop/") else 0.1)
		)
	return true


static func _reset_doc_pose(creature: Node3D) -> void:
	if str(creature.get_meta("source",{}).get("origin","")) != "user_doc_nitrofs": return
	for skeleton: Skeleton3D in creature.find_children("*","Skeleton3D",true,false):
		skeleton.reset_bone_poses()
	var model: Node3D = creature.get_child(0) as Node3D
	if model != null:
		model.position.y = float(creature.get_meta("desktop_model_floor_y",model.position.y))


static func _doc_desktop_ability(creature: Node3D, player: AnimationPlayer, native_name: String) -> String:
	return _doc_desktop_role(creature, player, native_name, "attack")


static func _doc_desktop_role(creature: Node3D, player: AnimationPlayer, native_name: String, role: String) -> String:
	var adapted_name: String = "ability" if role == "attack" else role
	var ADAPTED: String = "doc_desktop/" + adapted_name
	if player.has_animation(ADAPTED):
		return ADAPTED
	var floor: Dictionary = creature.get_meta("desktop_role_floor", {}).get(role, creature.get_meta("desktop_ability_floor", {}))
	var curve: Array = floor.get("curve", [])
	if str(floor.get("source_clip", "")) != native_name or curve.is_empty() or not player.has_animation(native_name):
		return native_name
	var native: Animation = player.get_animation(native_name)
	var track: int = _torso_position_track(native)
	if track < 0:
		return native_name
	var adapted: Animation = native.duplicate(true) as Animation
	var roles: Dictionary = creature.get_meta("animation_roles", {})
	var idle: Animation = player.get_animation(str(roles.get("idle", "")))
	var idle_track: int = _torso_position_track(idle) if idle != null else -1
	var anchor: Vector3 = idle.position_track_interpolate(idle_track, 0.0) if idle_track >= 0 else native.position_track_interpolate(track, 0.0)
	for key: int in range(adapted.track_get_key_count(track) - 1, -1, -1):
		adapted.track_remove_key(track, key)
	for sample: Array in curve:
		var time: float = float(sample[0])
		var position: Vector3 = native.position_track_interpolate(track, time)
		position.x = anchor.x
		position.z = anchor.z
		if str(floor.get("floor_units","")) != "model_parent":
			position.y += float(sample[1])
		adapted.position_track_insert_key(track, time, position)
	adapted.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	adapted.loop_mode = Animation.LOOP_NONE
	if str(floor.get("floor_units","")) == "model_parent":
		var model: Node3D = creature.get_child(0) as Node3D
		var animation_root: Node = player.get_node(player.root_node)
		var lift_track: int = adapted.add_track(Animation.TYPE_VALUE)
		adapted.track_set_path(lift_track, NodePath(str(animation_root.get_path_to(model))+":position:y"))
		adapted.track_set_interpolation_type(lift_track, Animation.INTERPOLATION_LINEAR)
		for sample: Array in curve:
			adapted.track_insert_key(lift_track,float(sample[0]),float(creature.get_meta("desktop_model_floor_y",model.position.y))+float(sample[1]))
	var library: AnimationLibrary = player.get_animation_library("doc_desktop") if player.has_animation_library("doc_desktop") else AnimationLibrary.new()
	library.add_animation(adapted_name, adapted)
	if not player.has_animation_library("doc_desktop"):
		player.add_animation_library("doc_desktop", library)
	creature.set_meta("desktop_action", {"source_clip": native_name, "adaptation": floor.get("adaptation", ""), "original_event_mapping": "desktop ability event"})
	return ADAPTED


static func _set_battle_animation_loop(player: AnimationPlayer, animation_name: String, mode: Animation.LoopMode) -> void:
	var animation: Animation = player.get_animation(animation_name)
	if animation.loop_mode == mode:
		return
	var local_animations: Dictionary = player.get_meta("ds_local_animations", {})
	if not local_animations.has(animation_name):
		# PackedScene instances share native animation resources. Isolate the
		# library and the one changed clip so this actor cannot alter another
		# participant's loop or the cached source animation.
		var slash: int = animation_name.find("/")
		var library_name: String = animation_name.left(slash) if slash >= 0 else ""
		var clip_name: String = animation_name.substr(slash + 1) if slash >= 0 else animation_name
		var local_libraries: Dictionary = player.get_meta("ds_local_libraries", {})
		var library: AnimationLibrary = player.get_animation_library(library_name)
		if not local_libraries.has(library_name):
			var isolated: AnimationLibrary = AnimationLibrary.new()
			for clip: StringName in library.get_animation_list():
				isolated.add_animation(clip, library.get_animation(clip))
			player.remove_animation_library(library_name)
			player.add_animation_library(library_name, isolated)
			library = isolated
			local_libraries[library_name] = true
			player.set_meta("ds_local_libraries", local_libraries)
		animation = animation.duplicate(true) as Animation
		library.remove_animation(clip_name)
		library.add_animation(clip_name, animation)
		local_animations[animation_name] = true
		player.set_meta("ds_local_animations", local_animations)
	animation.loop_mode = mode


static func _desktop_action(creature: Node3D, player: AnimationPlayer, roles: Dictionary) -> String:
	## The source role table is unknown. These eight visible native motions were
	## reviewed individually and selected for the desktop duel presentation.
	var identity: String = str(creature.get_meta("species", "")).to_lower().replace(" ", "_")
	if not OBSERVED_DESKTOP_ACTIONS.has(identity):
		return ""
	if player.has_animation(DESKTOP_ACTION_CLIP):
		return DESKTOP_ACTION_CLIP
	var idle_name: String = str(roles.get("idle", ""))
	if not player.has_animation(idle_name):
		return ""
	var native_name: String = ""
	for candidate: String in player.get_animation_list():
		if candidate.ends_with("_M_10"):
			native_name = candidate
			break
	if native_name.is_empty():
		return ""
	var idle: Animation = player.get_animation(idle_name)
	var native: Animation = player.get_animation(native_name)
	var idle_track: int = _torso_position_track(idle)
	var native_track: int = _torso_position_track(native)
	if idle_track < 0 or native_track < 0:
		return ""
	var idle_position: Vector3 = idle.position_track_interpolate(idle_track, 0.0)
	var floor: Dictionary = _desktop_floor_data().get(identity, {})
	var samples: Array = floor.get("curve", [])
	if str(floor.get("native_clip", "")) != native_name or samples.is_empty():
		return ""
	var action: Animation = native.duplicate(true) as Animation
	action.resource_name = "desktop_action"
	action.loop_mode = Animation.LOOP_NONE
	for key: int in range(action.track_get_key_count(native_track) - 1, -1, -1):
		action.track_remove_key(native_track, key)
	for sample: Array in samples:
		action.position_track_insert_key(native_track, float(sample[0]), idle_position + Vector3(0.0, float(sample[1]), 0.0))
	action.track_set_interpolation_type(native_track, Animation.INTERPOLATION_LINEAR)
	# A separate instance library leaves every native animation resource intact.
	var library: AnimationLibrary = AnimationLibrary.new()
	if library.add_animation("desktop_action", action) != OK:
		return ""
	if player.add_animation_library("ds_desktop", library) != OK:
		return ""
	creature.set_meta("desktop_action", {
		"clip": DESKTOP_ACTION_CLIP,
		"source_clip": native_name,
		"observed_motion": OBSERVED_DESKTOP_ACTIONS[identity],
		"original_ds_role": "unverified",
		"adaptation": "Bip01 X/Z held at native idle; Y lifted by sampled source skin floor curve; other source tracks retained",
		"floor_curve": DESKTOP_FLOOR_PATH,
		"floor_margin": floor.get("floor_margin_godot_units", 0.025),
	})
	return DESKTOP_ACTION_CLIP


static func _desktop_floor_data() -> Dictionary:
	if _desktop_floor.is_empty():
		var file: FileAccess = FileAccess.open(DESKTOP_FLOOR_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_desktop_floor = parsed
	return _desktop_floor.get("species", {})


static func _torso_position_track(animation: Animation) -> int:
	return _named_position_track(animation, "Bip01")


static func _named_position_track(animation: Animation, bone_name: String) -> int:
	for track: int in range(animation.get_track_count()):
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var path: NodePath = animation.track_get_path(track)
		if path.get_subname_count() == 1 and str(path.get_subname(0)) == bone_name:
			return track
	return -1


static func _make_imported(parent: Node3D, species: String, attribute: String, form: String, owner: int = -1) -> Node3D:
	var definition: Dictionary = AssetCatalog.resolve(species, form, attribute)
	if definition.is_empty():
		return null
	var path: String = str(definition.get("path", ""))
	var scene: PackedScene = _scene(path)
	if scene == null:
		return null
	var model: Node3D = scene.instantiate() as Node3D
	if model == null:
		return null
	var texture_path: String = str(definition.get("texture", ""))
	var texture: Texture2D = _texture(texture_path) if not texture_path.is_empty() else null
	# A missing declared diffuse image must not produce a silently white import.
	if not texture_path.is_empty() and texture == null:
		model.free()
		return null
	var wrapper: Node3D = Node3D.new()
	var canonical: String = str(definition.get("species", species))
	wrapper.name = canonical + ("Ball" if form == "ball" else "")
	wrapper.add_child(model)
	var transform: Dictionary = definition.get("transform", {})
	if transform.has("scale"):
		model.scale *= float(transform["scale"])
	var rotation_values: Variant = transform.get("rotation_degrees", [])
	if rotation_values is Array and rotation_values.size() == 3:
		model.rotation_degrees = Vector3(float(rotation_values[0]), float(rotation_values[1]), float(rotation_values[2]))
	var position_values: Variant = transform.get("position", [])
	if position_values is Array and position_values.size() == 3:
		model.position = Vector3(float(position_values[0]), float(position_values[1]), float(position_values[2]))
	wrapper.set_meta("desktop_model_floor_y",model.position.y)
	var material_copies: Dictionary = {}
	var count: int = _prepare_imported_meshes(model, texture, definition, material_copies)
	if count == 0:
		wrapper.free()
		return null
	parent.add_child(wrapper)
	wrapper.set_meta("runtime_materials", material_copies.values())
	if definition.has("texture_animation"):
		var video: VideoStreamPlayer = TextureVideo.new()
		video.name = "TextureVideo"
		video.stream = load(str(definition.texture_animation)) as VideoStream
		video.target_materials = material_copies.values()
		wrapper.add_child(video)
	wrapper.set_meta("species", canonical)
	wrapper.set_meta("attribute", attribute)
	wrapper.set_meta("requested_attribute", attribute)
	wrapper.set_meta("texture_attribute", str(definition.get("texture_attribute", "")))
	wrapper.set_meta("exact_attribute", bool(definition.get("exact_attribute", false)))
	wrapper.set_meta("requested_form", form)
	wrapper.set_meta("actual_form", str(definition.get("actual_form", form)))
	wrapper.set_meta("native_geometry", bool(definition.get("native_geometry", false)))
	wrapper.set_meta("native_texture_coordinates", bool(definition.get("native_texture_coordinates", false)))
	wrapper.set_meta("animation_roles", definition.get("animation_roles", {}))
	if definition.has("desktop_ability_floor"):
		wrapper.set_meta("desktop_ability_floor", definition.desktop_ability_floor)
	if definition.has("desktop_role_floor"):
		wrapper.set_meta("desktop_role_floor", definition.desktop_role_floor)
	wrapper.set_meta("source_animations", definition.get("animations", []))
	wrapper.set_meta("model_origin", "source_import")
	wrapper.set_meta("source", definition.get("source", {}))
	wrapper.set_meta("asset_path", path)
	wrapper.set_meta("texture_path", texture_path)
	wrapper.set_meta("part_count", count)
	wrapper.set_meta("mesh_count", count)
	if owner >= 0:
		wrapper.set_meta("owner", owner)
	return wrapper


static func _scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		var cached: PackedScene = _scene_cache[path] as PackedScene
		_scene_cache.erase(path)
		_scene_cache[path] = cached
		return cached
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if not resource is PackedScene:
		return null
	_scene_cache[path] = resource
	if _scene_cache.size() > MAX_SCENE_CACHE:
		_scene_cache.erase(_scene_cache.keys()[0])
	return resource as PackedScene


static func _texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		var cached: Texture2D = _texture_cache[path] as Texture2D
		_texture_cache.erase(path)
		_texture_cache[path] = cached
		return cached
	if path.ends_with(".webp.bin"):
		if not FileAccess.file_exists(path):
			return null
		var image: Image = Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			return null
		image.generate_mipmaps()
		var native: ImageTexture = ImageTexture.create_from_image(image)
		native.resource_path = path
		_texture_cache[path] = native
		if _texture_cache.size() > MAX_TEXTURE_CACHE:
			_texture_cache.erase(_texture_cache.keys()[0])
		return native
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if not resource is Texture2D:
		return null
	_texture_cache[path] = resource
	if _texture_cache.size() > MAX_TEXTURE_CACHE:
		_texture_cache.erase(_texture_cache.keys()[0])
	return resource as Texture2D


static func _prepare_imported_meshes(node: Node, texture: Texture2D, definition: Dictionary, copies: Dictionary) -> int:
	var count: int = 0
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			count = 1
			var wanted: Array = definition.get("texture_materials", [])
			for surface: int in range(instance.mesh.get_surface_count()):
				var source: StandardMaterial3D = instance.get_active_material(surface) as StandardMaterial3D
				var material: StandardMaterial3D
				if source != null and copies.has(source):
					material = copies[source] as StandardMaterial3D
				else:
					material = source.duplicate(false) as StandardMaterial3D if source != null else StandardMaterial3D.new()
					if texture != null and (wanted.is_empty() or source == null or wanted.has(source.resource_name)):
						material.albedo_texture = texture
						material.albedo_color = Color.WHITE
						material.metallic = 0.0
						material.roughness = float(definition.get("roughness", 0.65))
					if bool(definition.get("double_sided", true)):
						material.cull_mode = BaseMaterial3D.CULL_DISABLED
					if source != null:
						copies[source] = material
					else:
						copies["%d:%d" % [instance.get_instance_id(), surface]] = material
				instance.set_surface_override_material(surface, material)
	for child: Node in node.get_children():
		count += _prepare_imported_meshes(child, texture, definition, copies)
	return count


static func _instance(scene: PackedScene, parent: Node3D, node_name: String, attribute: String, owner: int = -1) -> Node3D:
	var wrapper: Node3D = Node3D.new()
	wrapper.name = node_name
	var model: Node3D = scene.instantiate() as Node3D
	wrapper.add_child(model)
	parent.add_child(wrapper)
	var material_copies: Dictionary = {}
	var count: int = _prepare_meshes(model, attribute, owner, material_copies)
	# Keep materials alive until the wrapper has removed all child render instances.
	# This also prevents deferred shader inspection from seeing a released override.
	wrapper.set_meta("runtime_materials", material_copies.values())
	wrapper.set_meta("species", "Dragonoid")
	wrapper.set_meta("attribute", attribute)
	wrapper.set_meta("model_origin", "original_reference_recreation")
	wrapper.set_meta("part_count", count)
	wrapper.set_meta("mesh_count", count)
	return wrapper


static func _prepare_meshes(node: Node, attribute: String, owner: int, copies: Dictionary) -> int:
	var count: int = 0
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			count = 1
			for surface: int in range(instance.mesh.get_surface_count()):
				var source: StandardMaterial3D = instance.get_active_material(surface) as StandardMaterial3D
				if source == null:
					continue
				if not copies.has(source):
					var material: StandardMaterial3D = source.duplicate(true) as StandardMaterial3D
					match source.resource_name:
						"Shell_Red":
							material.albedo_color = _attribute_color(attribute)
						"Armor_Shadow":
							material.albedo_color = _attribute_color(attribute).darkened(0.40)
						"Owner_Accent":
							if owner >= 0:
								material.albedo_color = Color("ffbc70") if owner == 0 else Color("75d7f1")
								material.emission = material.albedo_color
					copies[source] = material
				instance.set_surface_override_material(surface, copies[source] as Material)
	for child: Node in node.get_children():
		count += _prepare_meshes(child, attribute, owner, copies)
	return count


static func _attribute_color(attribute: String) -> Color:
	match attribute.to_lower():
		"aquos", "аквос": return Color("297bce")
		"ventus", "вентус": return Color("36a37a")
		"haos", "хаос": return Color("e2d7aa")
		"darkus", "даркус": return Color("7151ba")
		"subterra", "сабтерра": return Color("b78346")
		_: return Color("cf3526")
