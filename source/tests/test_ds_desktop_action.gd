extends SceneTree
## Desktop motion selection must retain original clips and survive pause/result.

const Models = preload("res://scripts/model_library.gd")
const Catalog = preload("res://scripts/ds_model_catalog.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		push_error(text)


func _run() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	for identity: String in Models.OBSERVED_DESKTOP_ACTIONS:
		var entry: Dictionary = Catalog.get_entry(identity)
		var attributes: Array[String] = Catalog.available_attributes(identity)
		var creature: Node3D = Models.make_creature(stage, str(entry.name), attributes[0], false, "battle")
		_check(creature != null, "Reviewed native form missing: " + identity)
		if creature == null:
			continue
		var player: AnimationPlayer = creature.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var idle_name: String = str(creature.get_meta("animation_roles", {}).idle)
		var native_name: String = ""
		for candidate: String in player.get_animation_list():
			if candidate.ends_with("_M_10"):
				native_name = candidate
		var native: Animation = player.get_animation(native_name)
		var native_track: int = Models._torso_position_track(native)
		var original_position: Vector3 = native.track_get_key_value(native_track, 0)
		_check(Models.play_battle_animation(creature, "attack"), "Observed desktop action unavailable: " + identity)
		_check(player.current_animation == Models.DESKTOP_ACTION_CLIP, "Presentation action not selected: " + identity)
		_check(player.has_animation(native_name), "Original motion was replaced: " + identity)
		_check(native.track_get_key_value(native_track, 0) == original_position, "Shared native trajectory was mutated: " + identity)
		var action: Animation = player.get_animation(Models.DESKTOP_ACTION_CLIP)
		var idle: Animation = player.get_animation(idle_name)
		var idle_track: int = Models._torso_position_track(idle)
		var expected_position: Vector3 = idle.position_track_interpolate(idle_track, 0.0)
		_check(action != native and action.length == native.length and action.get_track_count() == native.get_track_count(), "Source duration or tracks were replaced: " + identity)
		var preserved: bool = true
		for track: int in range(native.get_track_count()):
			if track == native_track:
				continue
			for key: int in range(native.track_get_key_count(track)):
				preserved = preserved and action.track_get_key_value(track, key) == native.track_get_key_value(track, key)
		_check(preserved, "Native limb/rotation motion changed: " + identity)
		var skeleton: Skeleton3D = creature.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var torso: int = skeleton.find_bone("Bip01")
		var floor: Dictionary = Models._desktop_floor_data()[identity]
		_check(bool(floor.validation.sampled_floor_pass) and bool(floor.validation.interpolated_midpoint_floor_pass), "Exhaustive source floor validation failed: " + identity)
		# Advance through real mixer steps: one oversized step still applies the
		# previous blend's value, and would not model an actual rendered frame.
		var minimum_y: float = INF
		for blend_sample: int in range(8):
			_advance_frames(player, 0.0125)
			minimum_y = minf(minimum_y, _skin_min_y(creature))
		for sample: int in range(1, 13):
			_advance_frames(player, (action.length * 0.85 - 0.1) / 12.0)
			minimum_y = minf(minimum_y, _skin_min_y(creature))
		var root_position: Vector3 = skeleton.get_bone_pose_position(torso)
		_check(absf(root_position.x - expected_position.x) < 0.001 and absf(root_position.z - expected_position.z) < 0.001, "Desktop root left its horizontal anchor: " + identity)
		_check(root_position.y >= expected_position.y, "Desktop floor correction lowered the root: " + identity)
		_check(minimum_y >= -0.002, "Animated source geometry crossed floor: %s (%f)" % [identity, minimum_y])
		player.pause()
		var paused_time: float = player.current_animation_position
		var paused_pose: Transform3D = skeleton.get_bone_global_pose(torso)
		await create_timer(0.025).timeout
		_check(player.current_animation_position == paused_time and skeleton.get_bone_global_pose(torso).is_equal_approx(paused_pose), "Pause advanced the native action: " + identity)
		player.play()
		_advance_frames(player, action.length)
		_check(player.current_animation == idle_name and player.is_playing(), "Completed desktop action did not return to idle: " + identity)
		_check(str(creature.get_meta("desktop_action", {}).get("original_ds_role", "")) == "unverified", "Desktop choice claimed a DS semantic role: " + identity)
		creature.free()
	var unreviewed: Node3D = Models.make_creature(stage, "Centipoid", "Darkus", false, "battle")
	_check(not Models.play_battle_animation(unreviewed, "attack"), "Unreviewed species was given a numeric-suffix action")
	unreviewed.free()
	stage.free()
	print("DS DESKTOP ACTION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _advance_frames(player: AnimationPlayer, duration: float) -> void:
	var remaining: float = duration
	while remaining > 0.000001:
		var step: float = minf(remaining, 1.0 / 120.0)
		player.advance(step)
		remaining -= step


func _skin_min_y(creature: Node3D) -> float:
	var result: float = INF
	for node: Node in creature.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var skeleton: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		var skin: Skin = mesh.skin
		if skeleton == null or skin == null:
			continue
		var transforms: Array[Transform3D] = []
		for bind: int in range(skin.get_bind_count()):
			var bone: int = skin.get_bind_bone(bind)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(bind))
			transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var referenced: Dictionary = {}
			for index: int in indices:
				referenced[index] = true
			var width: int = weights.size() / vertices.size()
			for index: int in referenced:
				var position: Vector3 = Vector3.ZERO
				var total_weight: float = 0.0
				for influence: int in range(width):
					var offset: int = index * width + influence
					var weight: float = weights[offset]
					if weight > 0.0:
						position += (transforms[bones[offset]] * vertices[index]) * weight
						total_weight += weight
				if total_weight > 0.0:
					result = minf(result, position.y)
	return result
