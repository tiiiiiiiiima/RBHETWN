extends SceneTree
## Verify real source forms, original embedded materials, skin and joint motion.

const Catalog = preload("res://scripts/ds_model_catalog.gd")
var failures: Array[String] = []
var checked_models: int = 0
var checked_clips: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var coverage: Dictionary = Catalog.coverage()
	_expect(int(coverage.get("battle_species", 0)) >= 37, "Native battle coverage missing")
	_expect(Catalog.resolve("Dharak", "Darkus").is_empty(), "Post-DS species was assigned unrelated source geometry")
	_expect(Catalog.resolve("Siege", "Pyrus").is_empty(), "Missing Siege geometry was claimed as a DS form")
	for entry: Dictionary in Catalog.species():
		var species_name: String = str(entry.name)
		_expect(not str(entry.get("animation_roles", {}).get("idle", "")).is_empty(), "Visually verified native idle missing: " + species_name)
		_expect(not entry.get("animation_roles", {}).has("victory"), "Unverified source motion labelled as victory: " + species_name)
		var attributes: Array[String] = Catalog.available_attributes(species_name)
		_expect(not attributes.is_empty(), "No verified native material attribute: " + species_name)
		var paths: Dictionary = {}
		paths[str(entry.path)] = true
		for attribute: String in attributes:
			var definition: Dictionary = Catalog.resolve(species_name, attribute)
			_expect(str(definition.get("actual_form", "")) == "battle", "Incorrect form: " + species_name)
			_expect(bool(definition.get("exact_attribute", false)), "Native palette not resolved: " + species_name + "/" + attribute)
			_expect(str(definition.get("texture_attribute", "")) == attribute, "Wrong palette attribute: " + species_name)
			paths[str(definition.path)] = true
		for path: String in paths:
			var packed: PackedScene = load(path) as PackedScene
			_expect(packed != null, "Unable to import " + path)
			if packed == null:
				continue
			var model: Node3D = packed.instantiate() as Node3D
			root.add_child(model)
			var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
			var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
			var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
			_expect(not meshes.is_empty(), "Native geometry missing: " + path)
			_expect(not skeletons.is_empty(), "Original joint skeleton missing: " + path)
			_expect(not players.is_empty(), "Native joint clips missing: " + path)
			var native_texture_count: int = 0
			for node: Node in meshes:
				var mesh: MeshInstance3D = node as MeshInstance3D
				for surface: int in mesh.mesh.get_surface_count():
					var material: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
					if material != null and material.albedo_texture != null:
						native_texture_count += 1
						var image: Image = material.albedo_texture.get_image()
						_expect(image != null and not image.is_empty(), "Embedded texture pixels unavailable: " + path)
			_expect(native_texture_count > 0, "Embedded source textures missing: " + path)
			if not players.is_empty():
				var player: AnimationPlayer = players[0] as AnimationPlayer
				for clip: Dictionary in entry.get("animations", []):
					var clip_name: String = str(clip.name)
					_expect(player.has_animation(clip_name), "Native motion omitted: " + path + "/" + clip_name)
					if player.has_animation(clip_name):
						var animation: Animation = player.get_animation(clip_name)
						_expect(animation.length > 0.0 and animation.get_track_count() > 0, "Empty joint motion: " + path + "/" + clip_name)
						player.play(clip_name)
						player.seek(animation.length * 0.5, true)
						checked_clips += 1
			checked_models += 1
			model.free()
	var drago: Dictionary = Catalog.resolve("Dragonoid", "Pyrus")
	_expect(str(drago.get("path", "")).contains("/ds/models/"), "Drago not sourced from DS battle form")
	var mismatched: Dictionary = Catalog.resolve("Dragonoid", "Aquos")
	_expect(not bool(mismatched.get("exact_attribute", true)), "Fixed Pyrus source was falsely recoloured Aquos")
	_expect(str(mismatched.get("texture_attribute", "")) == "Pyrus", "Explicit native attribute fallback lost")
	for failure: String in failures:
		push_error(failure)
	print("DS_MODELS: %d models, %d clip playbacks, %d failures" % [checked_models, checked_clips, failures.size()])
	quit(0 if failures.is_empty() else 1)
