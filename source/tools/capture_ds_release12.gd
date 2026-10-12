extends SceneTree
## Capture the shipped UI and a rules-driven DS battle using a real GL renderer.

var output: String = "/workspace/bakugan-pc/builds/qa-0.12/visual"
var captures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _capture(label: String) -> void:
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(label + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	assert(error == OK, "Screenshot failed: " + path)
	captures.append(path)
	print("CAPTURE: " + label)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	game._set_rules_profile("ds")
	assert(game.rules_profile == "ds", "Native DS starter catalog must be available")
	game._show_menu()
	await _capture("ds-menu")
	game._open_settings()
	await _capture("ds-settings")
	game._open_gates()
	await _capture("ds-gate-deck")
	game._open_card_view("gates", 0)
	await _capture("ds-gate-detail")
	game._open_deck()
	await _capture("ds-ability-deck")
	game._open_source_cards()
	await _capture("ds-card-collection")
	game.source_card_browser._open_zoom("ds_card_101")
	await _capture("ds-collection-playable-gate")
	game.source_card_browser._open_zoom("ds_card_417")
	await _capture("ds-collection-unimplemented-ability")
	game.source_card_browser.close_browser()
	game._show_menu()
	game.selected_arena = "ds_toy"
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	assert(game.rules.gates.size() == 2 and not game.rules.opening_active)
	await _capture("ds-opening")
	assert(game.rules.land(0, 0, 5).get("event") == "stand")
	assert(game.rules.finish_turn())
	assert(game.rules.land(1, 0, 5).get("event") == "battle")
	game._begin_battle(5)
	await _capture("ds-gate-opened")
	for button: Button in game.card_buttons:
		assert(Rect2(Vector2.ZERO, (button.get_parent() as Control).size).encloses(button.get_rect()), "Live card text must stay inside the hand panel")
	var played: int = 0
	for opportunity: int in range(3):
		for index: int in range(game.rules.abilities[0].size()):
			if game._play_ability(0, index):
				played += 1
				break
	game._start_battle_game()
	assert(game.phase == "battle")
	await _capture("ds-abilities-in-battle")
	for button: Button in game.card_buttons:
		assert(Rect2(Vector2.ZERO, (button.get_parent() as Control).size).encloses(button.get_rect()), "Played card text must stay inside the hand panel")
	await create_timer(1.2).timeout
	await _capture("ds-battle-monsters")
	game.battle_points = 10000
	game.ai_target_points = 0
	game._finish_battle()
	await _capture("ds-result")
	var report: Dictionary = {
		"version": ProjectSettings.get_setting("application/config/version"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"frames": captures,
		"player_abilities_played": played,
		"native_ds_gate_revealed": true,
		"windows_execution_tested": false,
	}
	var file: FileAccess = FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	# Let cancelled result timers finish while the menu guards their callbacks.
	game._show_menu()
	await create_timer(1.8).timeout
	game.queue_free()
	await process_frame
	quit()
