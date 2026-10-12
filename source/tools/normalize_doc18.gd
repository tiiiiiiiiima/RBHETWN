extends SceneTree
## Measure evaluated source skins, including the stationary desktop unfolding.
const Models = preload("res://scripts/model_library.gd")
const PATH: String = "res://assets/doc/models/model_manifest.json"
var evidence: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _pose(model: Node3D, player: AnimationPlayer, clip: String, time: float) -> AABB:
	player.play(clip)
	player.seek(time, true)
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	return Models.visual_bounds(model)

func _holder(path: String) -> Node3D:
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child((load(path) as PackedScene).instantiate())
	for player: AnimationPlayer in holder.find_children("*", "AnimationPlayer", true, false):
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return holder

func _transform(scale: float, position: Vector3) -> Dictionary:
	return {"scale": scale, "position": [position.x, position.y, position.z], "rotation_degrees": [0,0,0]}

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var backup: String = "res://builds/qa-0.18/doc-manifest-before.json"
	if not FileAccess.file_exists(backup):
		FileAccess.open(backup, FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	for entry: Dictionary in manifest.species + manifest.support:
		if entry.forms.has("toy"):
			var toy: Dictionary = entry.forms.toy
			var holder: Node3D = _holder(str(toy.path))
			var player: AnimationPlayer = holder.find_children("*", "AnimationPlayer", true, false)[0]
			var native: String = str(toy.animation_roles.open)
			var closed: AABB = _pose(holder, player, native, 0.0)
			var diameter: float = maxf(closed.size.x, maxf(closed.size.y, closed.size.z))
			assert(diameter > 0.000001 and closed.size.is_finite())
			var scale: float = 0.88 / diameter
			var center: Vector3 = closed.get_center()
			entry.forms.ball.transform = _transform(scale, -center * scale)
			entry.forms.ball.normalization = {"version": "0.18", "target_closed_diameter": 0.88, "basis": "Evaluated native opening pose at time zero", "shared_opening_scale": true}
			var clip: String = Models.stable_opening(player, native)
			var union: AABB = _pose(holder, player, clip, 0.0)
			var samples: Array = []
			for step: int in 21:
				var time: float = player.get_animation(clip).length * step / 20.0
				var bounds: AABB = _pose(holder, player, clip, time)
				union = union.merge(bounds)
				samples.append({"time":time,"minimum":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]})
			toy.transform = _transform(scale, Vector3(-center.x, -union.position.y, -center.z) * scale)
			toy.normalization = {"version":"0.18","basis":"Same evaluated closed diameter as ball; stationary native root; 21 unfolding skin samples", "shared_closed_diameter":0.88,"floor_y":0.0}
			evidence[str(entry.key)+"/opening"] = {"scale":scale,"closed":str(closed),"open_envelope":str(union),"samples":samples,"source_sha256":toy.sha256}
			holder.free()
		if entry.forms.has("battle"):
			var battle: Dictionary = entry.forms.battle
			var holder: Node3D = _holder(str(battle.path))
			var player: AnimationPlayer = holder.find_children("*", "AnimationPlayer", true, false)[0]
			var idle: String = str(battle.animation_roles.idle)
			var union: AABB = _pose(holder, player, idle, 0.0)
			for step: int in 21:
				union = union.merge(_pose(holder, player, idle, player.get_animation(idle).length * step / 20.0))
			var height: float = 3.0 if str(entry.key).begins_with("maxus_") else 2.5
			var scale: float = minf(height / union.size.y, 4.5 / maxf(union.size.x, union.size.z))
			var position := Vector3(-union.get_center().x, -union.position.y, -union.get_center().z) * scale
			battle.transform = _transform(scale, position)
			battle.normalization = {"version":"0.18","target_idle_height":height,"maximum_idle_span":4.5,"basis":"21 evaluated native idle skin samples","floor_y":0.0}
			var floors: Dictionary = {}
			for role: String in ["attack","damage"]:
				var clip: String = str(battle.animation_roles.get(role,""))
				if clip.is_empty() or not player.has_animation(clip):
					continue
				# Audit the exact stationary-root action used by the PC renderer.
				var native: Animation = player.get_animation(clip)
				var adapted: Animation = native.duplicate(true)
				var torso: int = Models._torso_position_track(native)
				var idle_animation: Animation = player.get_animation(idle)
				var idle_track: int = Models._torso_position_track(idle_animation)
				if torso >= 0 and idle_track >= 0:
					var anchor: Vector3 = idle_animation.position_track_interpolate(idle_track,0.0)
					for key: int in adapted.track_get_key_count(torso):
						var point: Vector3 = adapted.track_get_key_value(torso,key)
						point.x = anchor.x
						point.z = anchor.z
						adapted.track_set_key_value(torso,key,point)
				var library: AnimationLibrary = AnimationLibrary.new()
				library.add_animation(role,adapted)
				player.add_animation_library("audit_"+role,library)
				var audit_clip: String = "audit_"+role+"/"+role
				for skeleton: Skeleton3D in holder.find_children("*","Skeleton3D",true,false): skeleton.reset_bone_poses()
				var length: float = adapted.length
				var count: int = maxi(2, ceili(length * 60.0) + 1)
				var curve: Array = []
				var lowest: float = INF
				for sample: int in count:
					var time: float = length * sample / (count - 1.0)
					var bounds: AABB = _pose(holder, player, audit_clip, time)
					var floor: float = bounds.position.y * scale + position.y
					lowest = minf(lowest, floor)
					curve.append([time, maxf(0.0, -floor + 0.05)])
				# Use the interval's largest lift at both ends, so interpolation
				# cannot lower a fast-moving limb between the sampled poses.
				var safe_curve: Array = curve.duplicate(true)
				for sample: int in curve.size():
					for neighbor: int in range(maxi(0,sample-1),mini(curve.size(),sample+2)):
						safe_curve[sample][1] = maxf(float(safe_curve[sample][1]),float(curve[neighbor][1]))
				floors[role] = {"source_clip":clip,"curve":safe_curve,"source_minimum_y":lowest,"floor_units":"model_parent","adaptation":"Native joints retained; Bip01 X/Z anchored to idle; evaluated entire model lifted above desktop floor"}
			battle.desktop_role_floor = floors
			if floors.has("attack"):
				battle.desktop_ability_floor = floors.attack
			evidence[str(entry.key)+"/battle"] = {"scale":scale,"idle_envelope":str(union),"roles":floors.keys(),"source_sha256":battle.sha256}
			holder.free()
		print("NORMALIZED 0.18: ", entry.name)
	FileAccess.open(PATH, FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t")+"\n")
	FileAccess.open("res://builds/qa-0.18/doc-pose-normalization.json", FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t")+"\n")
	quit()
