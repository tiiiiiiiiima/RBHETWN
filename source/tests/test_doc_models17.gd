extends SceneTree
const Catalog = preload("res://scripts/doc_model_catalog.gd")
const Assets = preload("res://scripts/asset_catalog.gd")
const Models = preload("res://scripts/model_library.gd")
const Arena = preload("res://scripts/arena.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var parent: Node3D = Node3D.new()
	root.add_child(parent)
	var native: Array = Catalog.manifest().species + Catalog.manifest().support
	var counts: Dictionary = {"battle": 0, "toy": 0, "ball": 0}
	for entry: Dictionary in native:
		for form: String in entry.forms:
			var attribute: String = str(entry.forms[form].native_attribute)
			var model: Node3D = Models.make_ball(parent, attribute, 0, false, str(entry.name)) if form == "ball" else Models.make_creature(parent, str(entry.name), attribute, true, form)
			_check(model != null, "Load native form: " + str(entry.name) + "/" + form)
			if model == null:
				continue
			counts[form] += 1
			_check(str(model.get_meta("asset_path", "")).begins_with("res://assets/doc/models/"), "Donor provenance: " + str(entry.name) + "/" + form)
			_check(str(model.get_meta("actual_form", "")) == form, "Form identity: " + str(entry.name) + "/" + form)
			_check(bool(model.get_meta("exact_attribute", false)), "Native attribute: " + str(entry.name) + "/" + form)
			_check(not model.find_children("*", "Skeleton3D", true, false).is_empty(), "Source skeleton: " + str(entry.name) + "/" + form)
			var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
			_check(not players.is_empty(), "Source motion: " + str(entry.name) + "/" + form)
			if not players.is_empty():
				var player: AnimationPlayer = players[0] as AnimationPlayer
				if form == "ball":
					_check(not player.is_playing() and is_zero_approx(player.current_animation_position), "Closed form stays at initial pose")
				elif form == "toy":
					_check(not player.is_playing() and player.current_animation_position > 0.0, "Reduced motion gives fully open source pose")
				else:
					_check(Models.play_battle_animation(model, "attack") or str(entry.classification) == "trap", "Native ability role is playable")
			model.free()
	_check(counts == {"battle": 32, "toy": 29, "ball": 29}, "All confirmed native forms load")
	_check(Assets.available_forms("Maxus Dragonoid") == ["battle"], "Composite lacks a falsely invented sphere")
	_check(Assets.available_forms("Cosmic Ingram") == ["ball", "toy"], "Cosmic toy is separate from Master battle identity")
	_check(str(Assets.resolve("Master Ingram", "battle", "Ventus").species_key) == "master_ingram", "Master identity remains distinct")
	_check(str(Assets.resolve("Dragonoid", "battle", "Pyrus").path).begins_with("res://assets/ds/"), "Animated original Drago remains distinct from Neo")
	_check(str(Assets.resolve("Fourtress", "battle", "Pyrus").path).begins_with("res://assets/ds/") and str(Assets.resolve("Fortress", "battle", "Pyrus").path).begins_with("res://assets/doc/models/"), "Fortress trap is distinct from Fourtress Bakugan")
	_check(Assets.available_attributes("Fortress", "battle") == ["Darkus"], "Fortress trap lists its native Darkus palette, distinct from Fourtress")
	_check(str(Assets.resolve("Elfin", "toy", "Pyrus").path).begins_with("res://assets/imported/"), "Other real texture variants remain available")
	_check(not Assets.resolve("Neo Dragonoid", "battle", "Aquos").exact_attribute, "Unavailable donor palette stays explicit")
	var arena: Node3D = Arena.new()
	root.add_child(arena)
	var creature: Node3D = arena.make_creature("Neo Dragonoid", "Pyrus")
	var player: AnimationPlayer = (creature.get_meta("unfold_player") as WeakRef).get_ref() as AnimationPlayer
	_check(player.is_playing(), "Standing native toy starts unfolding")
	await create_timer(0.1).timeout
	paused = true
	var before: float = player.current_animation_position
	await create_timer(0.12, true).timeout
	_check(is_equal_approx(before, player.current_animation_position), "Pause freezes native unfolding")
	paused = false
	arena.set_reduced_motion(true)
	_check(not player.is_playing() and is_equal_approx(player.current_animation_position, player.get_animation(str(player.get_meta("unfold_clip"))).length), "Changing motion setting finishes native unfolding")
	var maxus: Node3D = arena.make_creature("Maxus Helios", "Pyrus")
	_check(str(maxus.get_meta("species", "")) == "Maxus Helios" and maxus.get_meta("missing_toy_fallback", false), "Battle-only collection identity keeps its own model")
	creature.queue_free()
	maxus.queue_free()
	await process_frame
	arena.set_reduced_motion(true)
	arena.queue_free()
	parent.queue_free()
	await process_frame
	print("DOC 0.17: %d checks, %d failures; forms %s" % [checks, failures.size(), counts])
	quit(0 if failures.is_empty() else 1)
