extends SceneTree
## Real menu transitions, imported collection access and legacy profile carryover.

const Roster = preload("res://scripts/roster.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var menu: Node3D = load("res://main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	_check(menu.overlay_start.text == "АНИМЕ-ДУЭЛЬ", "New primary menu entry leads to the strategic duel")
	_check(menu.overlay_quick.visible and menu.overlay_tournament.visible, "Legacy match and tournament remain directly accessible")
	_check(menu.model_species_selector.item_count == 117, "Collection includes 99 playable species and 18 support toys")
	_check(menu.roster_selectors[0].item_count == 99, "Support toys cannot occupy playable team slots")
	menu.overlay_models.pressed.emit()
	menu.model_catalog_index = 99
	menu._render_model()
	_check(menu.phase == "model" and menu.model_name.text.contains("ЛОВУШКА"), "First support toy is rendered and visibly classified")
	_check(not menu.model_form_buttons[1].disabled and menu.model_form_buttons[2].disabled, "Support toy exposes only the source forms it actually has")
	menu._close_preparation()
	menu.overlay_cards.pressed.emit()
	_check(menu.phase == "source_cards" and menu.source_card_browser.visible and not menu.overlay.visible, "Menu opens the complete card browser")
	_check(menu.source_card_browser._matches.size() == 636, "Browser contains every distinct source face")
	menu.source_card_browser.close_browser()
	_check(menu.phase == "menu" and menu.overlay.visible, "Closing the collection restores the main menu")
	menu.selected_roster = [69, 73, 95]
	menu.selected_attributes = ["Aquos", "Pyrus", "Haos"]
	menu.selected_arena = "anime_board"
	menu.throw_style = "straight"
	menu.preferences.reduced_motion = true
	menu.overlay_start.pressed.emit()
	await process_frame
	await process_frame
	var duel: Node3D = current_scene
	_check(not is_instance_valid(menu) and duel.get_script().resource_path == "res://scripts/anime_duel.gd", "Primary action replaces the old scene with the playable duel")
	_check(duel.selected_team[0].name == Roster.CREATURES[69].name and duel.selected_team[2].name == Roster.CREATURES[95].name, "Newly added species carry into the duel unchanged")
	_check(duel.arena.theme_id == "anime_board" and duel.throw_style == "straight" and duel.preferences.reduced_motion, "Arena and control preferences carry into the new mode")
	_check(duel._deck_panel.visible and not duel.started, "Entering the duel permits editing its separate six/ten card deck")
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	_check(menu.phase == "menu" and menu.selected_roster == [69, 73, 95] and menu.selected_arena == "anime_board", "Return to menu restores the saved roster and source arena")
	_check(menu.throw_style == "straight" and menu.selected_gate_deck.size() == 3 and menu.selected_deck.size() == 3, "New duel preserves the legacy three-card deck and throw preference")
	menu.overlay_quick.pressed.emit()
	_check(menu.phase == "opening" and menu.match_mode == "quick", "Legacy quick match remains playable from its own button")
	print("RELEASE 0.8: %d checks, %d failures" % [checks, failures.size()])
	menu.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
