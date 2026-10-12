extends SceneTree
## Battle accents must respect pause/settings/restart and remain rule-neutral.

const Presentation = preload("res://scripts/ds_battle_presentation.gd")
var checks: int = 0
var failures: Array[String] = []
var capture_dir: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "Capture " + label)


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var scene: Control = Presentation.new()
	root.add_child(scene)
	scene.configure("ds_pyrus", false)
	var state: Dictionary = {
		"key": "effects17:1", "arena_id": "ds_pyrus", "slot": 5,
		"priority": 0, "totals": [480, 450],
		"gate": {"owner": 0, "revealed": true, "title": "Ворота", "key": "pyrus_50"},
		"units": [
			{"owner": 0, "index": 0, "name": "Dragonoid", "attribute": "Pyrus"},
			{"owner": 1, "index": 0, "name": "Preyas", "attribute": "Aquos"},
		],
		"supports": [{"owner": 0, "slot": 5, "id": "baliton", "name": "Baliton", "attribute": "Subterra", "status": "deployed", "category": "trap"}],
	}
	scene.sync_battle(state)
	await process_frame
	_check(scene.actors.size() == 2, "Both source battle models remain available")
	_check(scene._support_nodes.size() == 1, "Trap remains visible while its battle model is unavailable")
	if not scene._support_nodes.is_empty():
		var support: Node3D = scene._support_nodes.values()[0]
		_check(str(support.get_meta("requested_form", "")) == "battle" and str(support.get_meta("actual_form", "")) == "battle", "Trap uses the imported DoC battle form")
	var original_state: Dictionary = state.duplicate(true)
	scene.sync_battle(state, {"event": "ability_played", "owner": 0, "title": "Способность Пайруса"})
	_check(scene._effects.get_child_count() == 1, "Ability accents its actual participant")
	var accent: Node3D = scene._effects.get_child(0)
	_check(accent.position == scene.actors["0:0"].position, "Accent originates at its actor rather than the enemy")
	_check(accent.get_meta("presentation_only", false), "Accent is separate from rule state")
	await create_timer(0.12).timeout
	scene.set_suspended(true)
	var age: float = accent.age
	await create_timer(0.12).timeout
	_check(is_instance_valid(accent) and is_equal_approx(accent.age, age), "Pause freezes the accent clock and lifetime")
	scene.set_suspended(false)
	await create_timer(0.16).timeout
	_check(is_instance_valid(accent) and accent.age > age, "Resume continues the same accent")
	await _capture("ability")
	_check(state == original_state and scene.snapshot == original_state, "Visual events leave rule snapshot and totals unchanged")
	scene.sync_battle(state, {"event": "trap_deployed", "owner": 0, "name": "Baliton"})
	_check(scene._effects.get_child_count() >= 1, "Trap deployment has a visible accent")
	await _capture("trap")
	for event_index: int in 20:
		scene.sync_battle(state, {"event": "minigame_hit", "owner": event_index % 2})
	_check(scene._effects.get_child_count() <= 8, "Repeated hits have bounded simultaneous visual cost")
	scene.configure("ds_pyrus", true)
	_check(scene._effects.get_child_count() == 0, "Reduced motion immediately removes running accents")
	scene.sync_battle(state, {"event": "ability_played", "owner": 1})
	_check(scene._effects.get_child_count() == 0, "Reduced motion suppresses new accents")
	scene.finish_battle(0, [530, 450])
	_check(scene._effects.get_child_count() == 0 and scene.is_result_playing(), "Reduced motion preserves result without moving accents")
	scene.configure("ds_pyrus", false)
	scene.finish_battle(0, [530, 450])
	_check(scene._effects.get_child_count() == 1, "Win accents the winner only")
	await create_timer(0.3).timeout
	await _capture("victory")
	scene.finish_battle(-1, [450, 450])
	_check(scene._effects.get_child_count() == 0, "Draw clears previous winner accents")
	scene.sync_battle(state, {"event": "ability_played", "owner": 0})
	scene.reset()
	_check(scene._effects.get_child_count() == 0 and scene.actors.is_empty(), "Restart removes accents and participants")
	state.key = "effects17:2"
	scene.sync_battle(state, {"event": "ability_played", "owner": 1})
	await create_timer(0.95).timeout
	await process_frame
	_check(scene._effects.get_child_count() == 0, "Transient accents expire without accumulating hidden meshes")
	state.key = "effects17:3"
	scene.sync_battle(state, {"event": "ability_played", "owner": 0})
	state.key = "effects17:4"
	scene.sync_battle(state)
	_check(scene._effects.get_child_count() == 0, "New battle discards prior visual events")
	scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("DS EFFECTS 0.17 PREPARATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
