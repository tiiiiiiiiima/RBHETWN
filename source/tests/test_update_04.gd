extends SceneTree
## Scene regressions for the Wii card subset, legal deck editing and effects.
## The old prototype drain/shield/focus expectations were removed in 0.6.

const Catalog = preload("res://scripts/ability_catalog.gd")
const GateCatalog = preload("res://scripts/gate_catalog.gd")
const PROFILE_PATH = "user://qa_profile_04.cfg"
const LEGACY_PATH = "user://qa_profile_03_legacy.cfg"
const INVALID_PATH = "user://qa_profile_04_invalid.cfg"
var game: Node3D
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _option_for(selector: OptionButton, catalog_index: int) -> int:
	for option_index: int in range(selector.item_count):
		if selector.get_item_metadata(option_index) == catalog_index:
			return option_index
	return -1

func _new_battle(selection: Array = [0, 1, 2], gate_index: int = 0, player_index: int = 0) -> void:
	game.selected_roster = [0, 1, 2]
	game.selected_attributes = ["Pyrus", "Pyrus", "Ventus"]
	game.selected_deck = selection.duplicate()
	game.selected_gate_deck = [0, 1, 2]
	game._start_quick_match()
	game.rules.abilities[1].clear()
	_check(game.rules.place_gate(0, gate_index, 5), "Controlled battle uses a legal central gate")
	game.rules.land(0, player_index, 5, 40)
	game.rules.land(1, 0, 5, 20)
	game._begin_battle(5)
	game.ai_target_points = 0
	_check(game.phase == "battle_ready" and game.battle_time == 0.0, "Opposing landings open untimed battle preparation")

func _deck_checks() -> void:
	_check(game.phase == "menu" and game.selected_deck == [0, 1, 2], "Fresh profile supplies red, green and blue abilities")
	game.overlay_deck.pressed.emit()
	_check(game.phase == "deck" and game.deck_panel.visible and not game.overlay.visible, "Deck menu opens its editor")
	_check(game.deck_selectors.size() == 3, "Ability editor has three color positions")
	for slot: int in range(3):
		var selector: OptionButton = game.deck_selectors[slot]
		_check(selector.item_count > 0 and selector.is_visible_in_tree(), "Each ability color has visible choices")
		for option_index: int in range(selector.item_count):
			var catalog_index: int = int(selector.get_item_metadata(option_index))
			_check(selector.get_item_text(option_index) == Catalog.CARDS[catalog_index].title, "Ability choice uses the catalog's printed title")
			_check(str(Catalog.CARDS[catalog_index].color_type) == ["red", "green", "blue"][slot], "Ability selector contains only its allowed color")
		var option: int = _option_for(selector, slot + 3)
		_check(option >= 0, "Each color offers the alternate Wii ability")
		if option >= 0:
			selector.item_selected.emit(option)
	_check(game.selected_deck == [3, 4, 5], "Editor selects Quick Draw, Boosted Dragon and G-Power Bump")
	for slot: int in range(3):
		_check(game.deck_description_labels[slot].text.contains(Catalog.CARDS[slot + 3].description), "Ability editor displays its printed condition")
	var saved: Array = game.selected_deck.duplicate()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	for slot: int in range(3):
		game.deck_art[slot].gui_input.emit(click)
		_check(game.phase == "card_view" and game.card_view_panel.visible and not game.deck_panel.visible and game.card_view_art.texture != null, "Ability thumbnail opens its enlarged source image")
		_check(game.card_view_title.text == str(Catalog.CARDS[saved[slot]].title) and game.card_view_description.text == str(Catalog.CARDS[saved[slot]].description), "Ability viewer retains its actual console-rule title and condition")
		var return_button: Button = null
		for child: Node in game.card_view_panel.get_children():
			if child is Button and child.text == "ВЕРНУТЬСЯ К КОЛОДЕ":
				return_button = child as Button
		_check(return_button != null, "Card viewer exposes a return-to-deck button")
		if return_button != null:
			return_button.pressed.emit()
		_check(game.phase == "deck" and game.deck_panel.visible and not game.card_view_panel.visible and game.selected_deck == saved, "Return button restores the unchanged ability editor")
	game._select_deck_slot(-1, 0)
	game._select_deck_slot(3, 0)
	game._select_deck_slot(0, 1)
	game._select_deck_slot(1, 3)
	game._select_deck_slot(2, 999)
	_check(game.selected_deck == saved, "Invalid or wrong-color edits preserve the legal deck")
	game._close_deck()
	game._load_profile()
	_check(game.phase == "menu" and game.selected_deck == saved, "Closing deck editor persists the legal selection")
	game._start_quick_match()
	for slot: int in range(3):
		_check(game.rules.abilities[0][slot].key == Catalog.CARDS[saved[slot]].key, "Quick match installs the selected actual ability")
	game._start_tournament()
	for slot: int in range(3):
		_check(game.rules.abilities[0][slot].key == Catalog.CARDS[saved[slot]].key, "Tournament retains the selected ability deck")
	game._return_to_menu()

func _profile_checks() -> void:
	game.selected_roster = [3, 4, 5]
	game.selected_attributes = ["Darkus", "Aquos", "Haos"]
	game.selected_deck = [3, 4, 5]
	game.wins = 12
	game.losses = 7
	game.muted = true
	game.tournament.load_dict({"stage": 1, "active": true, "completed": false})
	game._save_profile(PROFILE_PATH)
	game.selected_deck = [0, 1, 2]
	game.tournament.start_new()
	game._load_profile(PROFILE_PATH)
	_check(game.selected_deck == [3, 4, 5], "Current profile restores a legal ability deck")
	_check(game.selected_roster == [3, 4, 5] and game.selected_attributes == ["Darkus", "Aquos", "Haos"], "Card migration preserves the selected team")
	_check(game.wins == 12 and game.losses == 7 and game.muted and game.tournament.stage == 1 and game.tournament.active, "Card migration preserves results, mute and tournament checkpoint")
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("results", "wins", 4)
	legacy.set_value("results", "losses", 2)
	legacy.set_value("team", "selection", [3, 4, 5])
	legacy.set_value("team", "attributes", ["Darkus", "Aquos", "Haos"])
	legacy.set_value("tournament", "progress", {"stage": 2, "active": true, "completed": false})
	_check(legacy.save(LEGACY_PATH) == OK, "Creates a profile before ability decks existed")
	game._load_profile(LEGACY_PATH)
	_check(game.selected_deck == [0, 1, 2], "A profile without ability cards receives a legal default deck")
	_check(game.selected_roster == [3, 4, 5] and game.wins == 4 and game.losses == 2 and game.tournament.stage == 2, "Older profile retains team, results and final checkpoint")
	var malformed: ConfigFile = ConfigFile.new()
	malformed.set_value("deck", "selection", [0, 3, 2])
	_check(malformed.save(INVALID_PATH) == OK, "Creates an old or malformed deck with two red cards")
	game._load_profile(INVALID_PATH)
	_check(game.selected_deck == Catalog.normalize_selection(game.selected_deck), "Loaded ability deck always satisfies one card of each color")
	for path: String in [PROFILE_PATH, LEGACY_PATH, INVALID_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _combination_checks() -> void:
	_new_battle()
	_check(game.battle_type == "shooting", "A Gold Gate starts Shooting Battle")
	_check(game._battle_base(0) == 700 and game._battle_base(1) == 490, "Leonidas Gate doubles only Leonidas's 160 G attribute bonus")
	for remaining: int in [2, 1, 0]:
		game._choose_card(0)
		_check(game.rules.abilities[0].size() == remaining, "Eligible ability is consumed once and a different card may follow")
	_check(game.battle_effects.extra(0, 0) == 360, "Battle Gate, Alpha Blaster and matching G-Power Boost combine to 360 G")
	game._choose_card(0)
	_check(game.battle_effects.extra(0, 0) == 360, "An exhausted hand cannot duplicate any effect")
	game._start_battle_game()
	game.ai_target_points = 0
	game._finish_battle()
	_check(game.rules.scores == [1, 0] and game.rules.teams[0][0].g == 340, "Combined effects decide the capture without changing base G")
	_check(game.match_stats.summary(0).abilities == 3, "Result statistics count all three consumed abilities")
	game.start_match()
	_check(game.battle_effects.extra(0, 0) == 0 and game.rules.abilities[0].size() == 3, "Restart restores the hand and clears every temporary effect")

func _condition_checks() -> void:
	_new_battle([0, 1, 2], 0, 1)
	game._choose_card(1)
	_check(game.rules.abilities[0].size() == 3 and game.battle_effects.extra(0, 0) == 0, "Alpha Blaster cannot be used by Dragonoid")
	_new_battle([3, 4, 5], 0, 1)
	game._choose_card(1)
	_check(game.rules.abilities[0].size() == 2 and game.battle_effects.extra(0, 0) == 200, "Boosted Dragon applies its printed 200 G to Dragonoid")
	game._choose_card(1)
	_check(game.rules.abilities[0].size() == 2, "G-Power Bump cannot be used by Pyrus")
	_new_battle([3, 4, 5], 1)
	_check(game.battle_type == "timing", "A Silver Gate starts Timing Battle")
	game._choose_card(0)
	_check(game.battle_type == "shooting" and game.rules.abilities[0].size() == 2, "Quick Draw changes battle type during preparation")
	game._start_battle_game()
	_check(game.phase == "battle" and game.shooting_target.visible and not game.timing_track.visible, "Starting the overridden battle updates the actual minigame UI")
	_new_battle([0, 1, 2], 2)
	var hand_size: int = game.rules.abilities[0].size()
	game._choose_card(0)
	game._choose_card(1)
	game._choose_card(2)
	_check(game.battle_type == "shaking" and game.rules.abilities[0].size() == hand_size and game.battle_effects.extra(0, 0) == 0, "Ability Block prevents every ability card")
	_new_battle()
	game._toggle_pause()
	game._choose_card(0)
	_check(game.rules.abilities[0].size() == 3 and game.battle_effects.extra(0, 0) == 0, "Paused preparation cannot consume an ability")
	game._toggle_pause()
	game._choose_card(-1)
	game._choose_card(99)
	_check(game.rules.abilities[0].size() == 3, "Invalid hand indices preserve all cards")

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.rng.seed = 20261004
	game.muted = true
	_deck_checks()
	_profile_checks()
	_combination_checks()
	_condition_checks()
	game.start_match()
	await create_timer(1.3).timeout
	_check(game.phase == "opening" and game.rules.gates.is_empty(), "Old battle callbacks cannot advance a restarted opening")
	game.queue_free()
	await process_frame
	print("CARD SCENE CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
