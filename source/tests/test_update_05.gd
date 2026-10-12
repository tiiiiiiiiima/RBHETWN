extends SceneTree
## Current scene integration: preparation signals, saved preferences, training,
## per-match statistics and model viewing. Requires an isolated XDG_DATA_HOME.
## Controlled landings exercise scene handlers; this is not a manual visual test.

const Arena = preload("res://scripts/arena.gd")
const GateCatalog = preload("res://scripts/gate_catalog.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const Roster = preload("res://scripts/roster.gd")
const CardArt = preload("res://scripts/card_art.gd")
const PROFILE_PATH: String = "user://qa_profile_05.cfg"
const LEGACY_PATH: String = "user://qa_profile_04_legacy.cfg"
const INVALID_PATH: String = "user://qa_profile_05_invalid.cfg"

var game: Node3D
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _escape() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._unhandled_input(event)

func _gate_checks() -> void:
	game.overlay_gates.pressed.emit()
	_check(game.phase == "gates" and game.gate_panel.visible and not game.overlay.visible, "Gate menu button opens the editor")
	_check(game.gate_selectors.size() == 3, "Gate editor has one position per color")
	for slot: int in range(3):
		var selector: OptionButton = game.gate_selectors[slot]
		_check(selector.item_count == 3 and selector.is_visible_in_tree(), "Each gate color offers three verified cards")
		for option_index: int in range(selector.item_count):
			var catalog_index: int = int(selector.get_item_metadata(option_index))
			_check(str(GateCatalog.CARDS[catalog_index].color_type) == ["gold", "silver", "copper"][slot], "Gate selector offers only its permitted color")
		selector.item_selected.emit(1)
		_check(game.gate_description_labels[slot].text.contains("Pyrus") and game.gate_description_labels[slot].text.contains("Ventus"), "Gate descriptions expose attribute bonuses")
	_check(game.selected_gate_deck == [3, 4, 5], "Alternate gold, silver and copper gates form a legal deck")
	var saved: Array = game.selected_gate_deck.duplicate()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	for slot: int in range(3):
		game.gate_art[slot].gui_input.emit(click)
		_check(game.phase == "card_view" and game.card_view_panel.visible and not game.gate_panel.visible, "Gate thumbnail opens the enlarged card viewer")
		_check(game.card_view_title.text == str(GateCatalog.CARDS[saved[slot]].title) and game.card_view_art.texture.get_size() == CardArt.gate_texture(saved[slot]).get_size(), "Gate viewer displays the selected source image and matching title")
		_check(game.card_view_description.text == game._gate_description(GateCatalog.CARDS[saved[slot]]), "Enlarged card uses the actual console-rule bonuses alongside source art")
		game._toggle_pause()
		_check(not game.paused and not paused, "Card viewing does not pause the scene")
		_escape()
		_check(game.phase == "gates" and game.gate_panel.visible and not game.card_view_panel.visible and game.selected_gate_deck == saved, "Escape returns from enlarged card to the unchanged gate deck")
	game._select_gate_slot(-1, 3)
	game._select_gate_slot(3, 4)
	game._select_gate_slot(0, 4)
	game._select_gate_slot(0, 9)
	_check(game.selected_gate_deck == saved, "Invalid or wrong-color gate edits preserve the hand")
	game._toggle_pause()
	_check(not game.paused and not paused, "Gate editing does not pause the tree")
	_escape()
	_check(game.phase == "menu" and not game.gate_panel.visible, "Escape saves and closes the gate editor")
	game._start_quick_match()
	for slot: int in range(3):
		var card: Dictionary = game.rules.hands[0][slot]
		_check(card.key == GateCatalog.CARDS[saved[slot]].key and card.owner == 0, "Quick match installs the selected gate card and owner")
	game._show_menu()

func _settings_checks() -> void:
	game.overlay_settings.pressed.emit()
	_check(game.phase == "settings" and game.settings_panel.visible, "Settings menu button opens its panel")
	_check(game.arena_selector.item_count == 4 and game.difficulty_selector.item_count == 3, "Settings expose the four environments and three difficulties")
	for index: int in range(3):
		game.arena_selector.item_selected.emit(index)
		var expected: String = ["stadium", "canyon", "glacier"][index]
		_check(game.selected_arena == expected and game.arena.theme_id == expected, "Arena selector changes the selected and visible environment")
		_check(game.arena.environment_root.get_meta("theme_id") == expected, "New theme owns matching environment geometry")
	game._select_arena(-1)
	game._select_arena(4)
	_check(game.selected_arena == "glacier", "Invalid arena indices do not replace a valid theme")
	game.volume_slider.value_changed.emit(0.35)
	_check(is_equal_approx(float(game.preferences.volume), 0.35) and game.volume_text.text.contains("35%"), "Volume slider updates saved preference and its label")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.35)), "Preference applies to the actual audio bus")
	game.muted = false
	game._set_volume(0.0)
	_check(AudioServer.is_bus_mute(0), "Zero volume mutes the audio bus")
	game._set_volume(0.65)
	_check(not AudioServer.is_bus_mute(0), "Increasing volume restores sound when mute is disabled")
	game._set_volume(2.0)
	_check(game.preferences.volume == 1.0, "Out-of-range volume is normalized before saving")
	game.motion_toggle.toggled.emit(true)
	_check(game.preferences.reduced_motion and game.arena.reduced_motion, "Motion toggle reaches arena animations")
	for index: int in range(3):
		game.difficulty_selector.item_selected.emit(index)
		_check(game.preferences.difficulty == ["easy", "normal", "hard"][index], "Difficulty selector updates the normalized preference")
		game._start_quick_match()
		_check(game.enemy_power_range == [Vector2i(60, 175), Vector2i(90, 205), Vector2i(125, 240)][index], "New quick match applies the selected AI difficulty")
		_check(game.arena.theme_id == "glacier", "Quick match uses the saved arena")
		game._open_settings()
	game._select_difficulty(1)
	game._set_volume(0.65)
	game._set_reduced_motion(true)
	_escape()
	_check(game.phase == "menu" and not game.settings_panel.visible, "Escape saves and closes settings")
	game._open_help()
	_check(game.phase == "help" and game.help_panel.visible, "Help opens the actual controls screen")
	game._toggle_pause()
	_check(not game.paused, "Help is not treated as an active match")
	_escape()
	_check(game.phase == "menu", "Help closes through the input handler")
	for stage: int in range(3):
		game.tournament.load_dict({"stage": stage, "active": true, "completed": false})
		game._continue_tournament()
		_check(game.arena.theme_id == ["stadium", "canyon", "glacier"][stage], "Tournament stages use their three corresponding environments")
		_check(game.selected_arena == "glacier", "Tournament theme does not overwrite the quick-match preference")
		for slot: int in range(3):
			_check(game.rules.hands[0][slot].key == GateCatalog.CARDS[game.selected_gate_deck[slot]].key, "Tournament retains the selected player gate hand")
	game._show_menu()

func _profile_checks() -> void:
	game.selected_gate_deck = [3, 4, 5]
	game.selected_arena = "canyon"
	game.preferences = {"difficulty": "hard", "volume": 0.45, "reduced_motion": true}
	game.wins = 11
	game.losses = 7
	game._save_profile(PROFILE_PATH)
	var config: ConfigFile = ConfigFile.new()
	_check(config.load(PROFILE_PATH) == OK, "Current profile is a readable ConfigFile")
	_check(config.get_value("gates", "selection") == [3, 4, 5] and config.get_value("environment", "id") == "canyon", "Gate hand and environment are written to separate profile fields")
	_check(config.get_value("settings", "preferences") == game.preferences, "Preferences are written without losing mute compatibility")
	game.selected_gate_deck = [0, 1, 2]
	game.selected_arena = "stadium"
	game.preferences = GameSettings.normalize({})
	game._load_profile(PROFILE_PATH)
	_check(game.selected_gate_deck == [3, 4, 5] and game.selected_arena == "canyon", "Profile reload restores gate hand and arena")
	_check(game.preferences == {"difficulty": "hard", "volume": 0.45, "reduced_motion": true}, "Profile reload restores all new preferences")
	_check(game.wins == 11 and game.losses == 7, "New profile fields preserve existing results")
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("results", "wins", 5)
	legacy.set_value("results", "losses", 3)
	legacy.set_value("settings", "muted", true)
	legacy.set_value("team", "selection", [3, 4, 5])
	legacy.set_value("team", "attributes", ["Darkus", "Aquos", "Subterra"])
	legacy.set_value("deck", "selection", [3, 4, 5])
	legacy.set_value("tournament", "progress", {"stage": 1, "active": true, "completed": false})
	_check(legacy.save(LEGACY_PATH) == OK, "Creates a genuine 0.4 profile without new fields")
	game._load_profile(LEGACY_PATH)
	_check(game.selected_gate_deck == [0, 1, 2] and game.selected_arena == "stadium" and game.preferences == GameSettings.normalize({}), "Old profile receives valid defaults for all added fields")
	_check(game.selected_roster == [3, 4, 5] and game.selected_deck == [0, 1, 2] and game.wins == 5 and game.losses == 3, "Migration preserves team and results while replacing obsolete demo cards")
	_check(game.tournament.stage == 1 and game.tournament.active and game.muted, "Migration preserves the tournament checkpoint and mute flag")
	var invalid: ConfigFile = ConfigFile.new()
	invalid.set_value("gates", "selection", [1, 1, 500])
	invalid.set_value("environment", "id", "unknown")
	invalid.set_value("settings", "preferences", {"difficulty": "broken", "volume": "bad", "reduced_motion": "yes"})
	_check(invalid.save(INVALID_PATH) == OK, "Creates malformed current-profile data")
	game._load_profile(INVALID_PATH)
	_check(game.selected_gate_deck == [0, 1, 2] and game.selected_arena == "stadium", "Malformed new profile selection safely falls back")
	_check(game.preferences == GameSettings.normalize({}), "Malformed settings are normalized on scene load")
	game.selected_roster = [0, 1, 2]
	game.selected_attributes = ["Pyrus", "Pyrus", "Ventus"]
	game.selected_deck = [3, 4, 5]
	game.muted = true
	game._apply_settings()

func _model_checks() -> void:
	game._open_roster()
	_check(game.roster_previews.size() == 3, "Roster opens three current creature previews")
	var before: float = game.preview_angle
	game._set_reduced_motion(true)
	game._update_roster_rotation(1.0)
	_check(is_equal_approx(game.preview_angle, before), "Reduced motion stops automatic preview rotation")
	game._rotate_roster(0.40)
	_check(is_equal_approx(game.preview_angle, fposmod(before + 0.40, TAU)), "Manual model rotation remains available with reduced motion")
	for stand: Node3D in game.roster_previews:
		_check(is_equal_approx(stand.rotation.y, game.preview_angle), "Every roster wrapper follows the selected angle")
	game._rotate_roster(NAN)
	_check(is_equal_approx(game.preview_angle, fposmod(before + 0.40, TAU)), "Invalid rotation input does not corrupt model orientation")
	game._set_reduced_motion(false)
	before = game.preview_angle
	game._update_roster_rotation(1.0)
	_check(is_equal_approx(game.preview_angle, fposmod(before + 0.22, TAU)), "Automatic roster rotation resumes when enabled")
	for slot: int in range(3):
		game._open_model(slot)
		await process_frame
		_check(game.phase == "model" and game.model_panel.visible and not game.roster_panel.visible, "Individual model view opens its own preparation screen")
		_check(game.roster_previews.size() == 1 and game.roster_previews[0].scale.x >= 1.5 and game.roster_previews[0].scale.is_equal_approx(Vector3.ONE * game.roster_previews[0].scale.x), "Model view replaces team previews with one uniformly enlarged source model")
		var creature: Node3D = game.roster_previews[0].get_child(0) as Node3D
		_check(creature.get_meta("species") == ["Leonidas", "Dragonoid", "Griffon"][slot] and game.model_name.text.contains(str(creature.get_meta("species"))), "Model view shows the selected roster identity")
		game._toggle_pause()
		_check(not game.paused and not paused, "Model viewing does not pause the scene")
		_escape()
		await process_frame
		_check(game.phase == "roster" and game.roster_previews.size() == 3, "Escape from model view restores all team previews")
	var saved_team: Array = game.selected_roster.duplicate()
	var saved_attributes: Array = game.selected_attributes.duplicate()
	game._open_model(1)
	_check(game.model_species_selector.item_count == 117 and game.model_attribute_selector.item_count == 6, "Model gallery offers playable species, support toys and attribute selection")
	game.model_species_selector.item_selected.emit(68)
	game.model_attribute_selector.item_selected.emit(1)
	await process_frame
	var gallery_creature: Node3D = game.roster_previews[0].get_child(0) as Node3D
	_check(gallery_creature.get_meta("species", "") == str(Roster.CREATURES[68].name) and gallery_creature.get_meta("texture_attribute", "") == "Aquos", "Gallery selector signals display the final species with its actual Aquos skin")
	game.model_form_buttons[0].pressed.emit()
	await process_frame
	var closed: Node3D = game.roster_previews[0].get_child(0) as Node3D
	var closed_path: String = str(closed.get_meta("asset_path", ""))
	_check(closed.get_meta("actual_form", "") == "ball" and closed.get_meta("species", "") == str(Roster.CREATURES[68].name), "Sphere button shows the selected species' closed source geometry")
	game.model_form_buttons[1].pressed.emit()
	await process_frame
	var opened: Node3D = game.roster_previews[0].get_child(0) as Node3D
	_check(opened.get_meta("actual_form", "") == "toy" and str(opened.get_meta("asset_path", "")) != closed_path, "Open button switches to a distinct source toy geometry")
	_check(game.model_form_buttons[2].disabled and not game.model_form_buttons[2].tooltip_text.is_empty(), "Unavailable monster button is disabled with an explanation")
	game._set_model_form("battle")
	_check(game.model_form == "toy" and game.roster_previews[0].get_child(0) == opened, "Requesting an unavailable monster does not mislabel the visible toy")
	_check(game.selected_roster == saved_team and game.selected_attributes == saved_attributes, "Browsing the full catalog does not alter the saved team or attributes")
	_escape()
	await process_frame
	_check(game.phase == "roster" and game.roster_previews.size() == 3, "Escape from the full catalog restores the selected team previews")
	game._open_model(-1)
	game._open_model(3)
	_check(game.phase == "roster" and game.roster_previews.size() == 3, "Invalid model indices leave the roster view intact")
	game._close_roster()
	await process_frame
	_check(game.roster_previews.is_empty() and not game.model_panel.visible, "Closing preparation removes all preview wrappers")

func _scene_landing(owner: int, unit_index: int, slot: int, bonus: int = 0) -> void:
	game._launch_ball(owner, unit_index, Arena.SLOT_POSITIONS[slot])
	game.flight_powered = false
	game.flight_ball.position = Arena.SLOT_POSITIONS[slot] + Vector3(0.0, 0.44, 0.0)
	game.roll_bonus = bonus
	game._land_ball()

func _training_checks() -> void:
	game._open_training()
	_check(game.phase == "training_setup" and game.training_panel.visible and game.practice_selector.item_count == 3, "Training setup provides a full match and three minigames")
	game.selected_roster = [0, 1, 2]
	game.selected_attributes = ["Pyrus", "Pyrus", "Ventus"]
	game.tournament.load_dict({"stage": 1, "active": true, "completed": false})
	var progress: Dictionary = game.tournament.to_dict()
	var wins: int = game.wins
	var losses: int = game.losses
	for owner: int in [0, 1]:
		game._start_training()
		_check(game.match_mode == "training" and game.phase == "opening", "Full training starts with both-player gate preparation")
		game.rules.abilities[0].clear()
		game.rules.abilities[1].clear()
		for unit_index: int in range(3):
			_check(game.rules.place_gate(owner, 0, 5), "Controlled training uses a central gate after the previous capture")
			_scene_landing(owner, unit_index, 5, 20)
			_scene_landing(1 - owner, unit_index, 5)
			_check(game.phase == "battle_ready", "Controlled training battle waits for input")
			game._start_battle_game()
			game.battle_points = 10000 if owner == 0 else 0
			game.ai_target_points = 10000 if owner == 1 else 0
			game._finish_battle()
		game._end_match()
		_check(game.phase == "finished" and game.rules.winner == owner, "Training completes through three resolved opposing battles")
		_check(game.wins == wins and game.losses == losses and game.tournament.to_dict() == progress, "Training result preserves profile and tournament progress")
		var stats: Dictionary = game.match_stats.summary(owner)
		_check(stats.throws == 3 and stats.hits == 3 and stats.captures == 3 and stats.double_stands == 0 and stats.collected_g == 60, "Landing handlers record owner-specific throws, retained pickup G and battle captures")
		_check(game.overlay_body.text.contains("Броски:") and game.overlay_body.text.contains("Сбор:"), "Finished match displays transient statistics")
		game._end_match()
		_check(game.wins == wins and game.losses == losses, "Repeated training completion cannot affect permanent counters")
	for kind: String in ["timing", "shooting", "shaking"]:
		game._start_practice(kind)
		if game.phase == "battle_ready":
			game._start_battle_game()
		_check(game.phase == "battle" and game.battle_type == kind and game.match_mode == "practice", "Direct practice begins its requested minigame")
		_check(game.match_stats.summary(0).throws == 0 and game.match_stats.summary(0).battles == 0, "New practice clears previous statistics")
		game.ai_target_points = 0
		game.battle_points = 96
		var breakdown: Dictionary = game._battle_breakdown(0, game.battle_points)
		_check(breakdown.base == 340 and breakdown.rolling == 0 and breakdown.mini == 96, "Breakdown separates base, retained rolls and raw minigame points")
		game._refresh_battle_scores()
		_check(game.battle_detail_text.text.contains("340") and game.battle_detail_text.text.contains("мини"), "Actual battle UI displays component breakdown")
		game._finish_battle()
		_check(game.phase == "finished" and not game.last_battle_result.is_empty() and game.overlay_start.text == "ПОВТОРИТЬ", "Practice resolves the battle and offers replay")
		var stats: Dictionary = game.match_stats.summary(0)
		_check(stats.battles == 1 and stats.mini_g == 96 and stats.abilities == 0, "Practice statistics record raw score without invented ability use")
		_check(game.wins == wins and game.losses == losses and game.tournament.to_dict() == progress, "Practice result preserves profile and tournament")
		game._overlay_primary()
		if game.phase == "battle_ready":
			game._start_battle_game()
		_check(game.phase == "battle" and game.battle_type == kind and game.match_stats.summary(0).battles == 0, "Practice replay retains its minigame and resets statistics")
	game._start_practice("invalid")
	_check(game.battle_type == "timing", "Invalid practice kind safely selects timing")
	game._return_to_menu()

func _throw_checks() -> void:
	for value: float in [0.2, 0.7, 0.95]:
		game._start_training()
		game._place_player_gate(5)
		game._skip_gate()
		game._handle_action(true)
		game.charge = value
		game._handle_action(false)
		_check(game.phase == "flying", "Releasing charged action starts an actual throw")
		var expected: String = "СЛАБЫЙ БРОСОК" if value < 0.62 else ("ТОЧНЫЙ БРОСОК" if value <= 0.78 else "ПЕРЕБОР СИЛЫ")
		_check(game.last_throw_quality == expected and game.instruction.text.contains(expected), "Charge quality is shown during the thrown ball's flight")
	game._start_training()
	game._place_player_gate(5)
	game._skip_gate()
	game._launch_ball(0, 0, Arena.SLOT_POSITIONS[5])
	game.flight_ball.position = Vector3(6.0, 0.44, 4.0)
	game.roll_bonus = 40
	game._land_ball()
	var stats: Dictionary = game.match_stats.summary(0)
	_check(stats.throws == 1 and stats.misses == 1 and stats.hits == 0 and stats.collected_g == 0, "A scene miss discards its collected pickup G")
	game._start_training()
	_check(game.match_stats.summary(0).throws == 0 and game.last_throw_quality.is_empty(), "Starting another match clears throw statistics and quality")
	game._return_to_menu()

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.rng.seed = 20261005
	_check(ProjectSettings.get_setting("application/config/version") == "0.9.0", "Current project declares version 0.9.0")
	_check(game.phase == "menu" and game.overlay.visible, "Current actual scene starts at the menu")
	_gate_checks()
	_settings_checks()
	_profile_checks()
	await _model_checks()
	_training_checks()
	_throw_checks()
	# All callbacks created by controlled landings must observe the changed match id.
	await create_timer(1.3).timeout
	_check(game.phase == "menu" and game.dragons.is_empty(), "Expired training callbacks cannot advance the returned menu")
	game.queue_free()
	await process_frame
	for path: String in [PROFILE_PATH, LEGACY_PATH, INVALID_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("UPDATE 0.5 CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
