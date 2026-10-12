extends SceneTree
## Integration checks for roster UI, tournament routing and profile migration.
## Run with an isolated XDG_DATA_HOME; this scene saves normal match results.

const Roster = preload("res://scripts/roster.gd")
var game: Node3D
var failures: Array[String] = []
var checks: int = 0
const PROFILE_PATH = "user://qa_profile_03.cfg"
const LEGACY_PATH = "user://qa_profile_02.cfg"
const INVALID_PATH = "user://qa_profile_invalid.cfg"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _descendants(node: Node, kind: String) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		if child.is_class(kind):
			result.append(child)
		result.append_array(_descendants(child, kind))
	return result

func _creatures() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in _descendants(game.arena, "Node3D"):
		if node.has_meta("species") and not node.is_queued_for_deletion():
			result.append(node)
	return result

func _team_matches(selection: Array, attributes: Array) -> bool:
	if game.rules.teams.size() != 2 or game.rules.teams[0].size() != 3:
		return false
	for slot: int in range(3):
		var unit: Dictionary = game.rules.teams[0][slot]
		if unit.name != Roster.CREATURES[int(selection[slot])].name or unit.attribute != attributes[slot]:
			return false
	return true

func _capture_match(winner: int) -> void:
	# Three distinct units exercise the reserve cycle without fabricated scores.
	for unit_index: int in range(3):
		_check(game.rules.place_gate(winner, 0, 5), "Controlled central match gate is placed")
		game.rules.land(winner, unit_index, 5)
		game.rules.land(1 - winner, unit_index, 5)
		var result: Dictionary = game.rules.resolve_battle(5, 10000 if winner == 0 else 0, 10000 if winner == 1 else 0)
		_check(result.get("event", "") == "capture", "Controlled opposing landings resolve an actual capture")
	_check(game.rules.winner == winner and game.rules.scores[winner] == 3, "Rules establish the intended three-capture winner")
	game._end_match()

func _difficulty_checks(expected_min: int, expected_max: int) -> void:
	_check(game.enemy_power_range == Vector2i(expected_min, expected_max), "Tournament round supplies the intended AI bonus range")
	game.rules.place_gate(0, 0, 5)
	game.rules.land(0, 0, 5)
	game.rules.land(1, 0, 5)
	game._begin_battle(5)
	_check(game.phase == "battle_ready", "Tournament battle waits for the player to begin")
	game._start_battle_game()
	_check(game.phase == "battle" and game.ai_target_points >= expected_min and game.ai_target_points <= expected_max, "A real tournament battle uses the round's AI bonus range")
	game.start_match()
	_check(game.dragons.is_empty() and game.rules.gates.is_empty(), "Round restart clears the controlled battle and creature visuals")

func _roster_checks() -> void:
	_check(game.phase == "menu" and game.overlay.visible, "Version 0.3 scene starts at the menu")
	_check(game.selected_roster == [0, 1, 2] and game.selected_attributes == ["Pyrus", "Pyrus", "Ventus"], "Fresh profile retains the original default team")
	game.overlay_roster.pressed.emit()
	_check(game.phase == "roster", "Team selection opens its own phase")
	var options: Array[Node] = _descendants(game.roster_panel, "OptionButton")
	_check(options.size() == 6, "Team screen provides species and attribute selectors for three slots")
	for option: OptionButton in game.roster_selectors:
		_check(option.item_count == Roster.CREATURES.size() and option.is_visible_in_tree(), "Every species selector includes the complete imported roster")
	for option: OptionButton in game.attribute_selectors:
		_check(option.item_count == Roster.ATTRIBUTES.size() and option.is_visible_in_tree(), "Every attribute selector retains all six attributes")
	_check(_creatures().size() == 3, "Team selection shows three creature previews")
	# Choose an already selected creature: its old slot must receive the replaced one.
	game.roster_selectors[0].item_selected.emit(1)
	_check(game.selected_roster == [1, 0, 2], "Choosing an existing creature swaps slots without a duplicate")
	_check(game.roster_selectors[0].selected == 1 and game.roster_selectors[1].selected == 0, "Species selectors reflect both sides of the swap")
	game.roster_selectors[1].item_selected.emit(4)
	game.roster_selectors[2].item_selected.emit(5)
	_check(game.selected_roster == [1, 4, 5], "Selecting two reserve species changes the team")
	for index: int in range(Roster.ATTRIBUTES.size()):
		game.attribute_selectors[2].item_selected.emit(index)
		_check(game.selected_attributes[2] == Roster.ATTRIBUTES[index], "Team slot accepts attribute %s" % Roster.ATTRIBUTES[index])
	game.attribute_selectors[0].item_selected.emit(Roster.ATTRIBUTES.find("Aquos"))
	game.attribute_selectors[1].item_selected.emit(Roster.ATTRIBUTES.find("Darkus"))
	var saved_selection: Array = game.selected_roster.duplicate()
	var saved_attributes: Array = game.selected_attributes.duplicate()
	game._select_roster_slot(-1, 0)
	game._select_roster_slot(2, Roster.CREATURES.size())
	game._select_attribute(-1, 0)
	game._select_attribute(2, 6)
	_check(game.selected_roster == saved_selection and game.selected_attributes == saved_attributes, "Invalid selector values leave the roster unchanged")
	await process_frame
	var previews: Array[Node] = _creatures()
	_check(previews.size() == 3, "Repeated roster edits keep exactly three preview creatures")
	for slot: int in range(previews.size()):
		_check(previews[slot].get_meta("species") == Roster.CREATURES[int(saved_selection[slot])].name and previews[slot].get_meta("attribute") == saved_attributes[slot], "Preview %d reflects its selected creature and attribute" % slot)
	game._close_roster()
	await process_frame
	_check(game.phase == "menu" and game.overlay.visible, "Closing team selection returns to the menu")
	_check(_creatures().is_empty(), "Closing team selection removes all preview creatures")
	game._load_profile()
	_check(game.selected_roster == saved_selection and game.selected_attributes == saved_attributes, "Closing team selection persists its choices")
	game._open_roster()
	game._start_quick_match()
	await process_frame
	_check(_creatures().is_empty(), "Starting a match removes team previews")
	_check(game.phase == "opening" and game.match_mode == "quick", "Quick match opens card placement")
	_check(_team_matches(saved_selection, saved_attributes), "Quick match uses the selected species and attributes")
	_check(not game.tournament.active and not game.tournament.completed, "First quick match leaves tournament progress inactive")

func _quick_checks() -> void:
	var initial_wins: int = game.wins
	var initial_losses: int = game.losses
	var before: Dictionary = game.tournament.to_dict()
	_capture_match(0)
	_check(game.phase == "finished" and game.overlay_start.text == "СЫГРАТЬ ЕЩЁ", "Quick match finish offers replay")
	_check(game.wins == initial_wins + 1 and game.losses == initial_losses, "Quick victory records one profile win")
	game._end_match()
	_check(game.wins == initial_wins + 1 and game.tournament.to_dict() == before, "Repeated match completion cannot duplicate wins or tournament progress")
	var generation: int = game.match_id
	game._overlay_primary()
	_check(game.match_id == generation + 1 and game.phase == "opening" and game.match_mode == "quick", "Quick replay starts a fresh quick match")
	_check(game.rules.scores == [0, 0] and game.rules.winner == -1, "Quick replay clears the completed score")

func _tournament_checks() -> void:
	game._show_menu()
	game.overlay_tournament.pressed.emit()
	_check(game.match_mode == "tournament" and game.phase == "opening", "New tournament starts its opening match")
	_check(game.tournament.active and not game.tournament.completed and game.tournament.stage == 0, "New tournament initializes its progress")
	_check(_team_matches(game.selected_roster, game.selected_attributes), "Tournament uses the selected team")
	_difficulty_checks(70, 125)
	var initial_losses: int = game.losses
	var generation: int = game.match_id
	var opening_opponents: Array = game.rules.teams[1].duplicate(true)
	_capture_match(1)
	_check(game.tournament.stage == 0 and game.tournament.active, "Tournament defeat preserves the current stage")
	_check(game.losses == initial_losses + 1, "Tournament defeat records one profile loss")
	game._end_match()
	_check(game.losses == initial_losses + 1 and game.tournament.stage == 0, "Repeated defeat cannot duplicate losses")
	game._overlay_primary()
	_check(game.match_id == generation + 1 and game.phase == "opening", "Defeat primary action retries a fresh match")
	_check(game.rules.teams[1] == opening_opponents and game.tournament.stage == 0, "Retry uses the same opponents and stage")
	_capture_match(0)
	_check(game.tournament.active and game.tournament.stage == 1, "Opening victory advances to the semifinal")
	game._end_match()
	_check(game.tournament.stage == 1, "Repeated victory cannot skip the next tournament stage")
	# Persist the stage between rounds and restore it before continuing.
	game._save_profile(PROFILE_PATH)
	game.tournament.start_new()
	game._load_profile(PROFILE_PATH)
	_check(game.tournament.active and game.tournament.stage == 1, "Profile restores the next unplayed tournament stage")
	game._show_menu()
	game.overlay_tournament.pressed.emit()
	_check(game.phase == "opening" and game.match_mode == "tournament" and game.tournament.stage == 1, "Continue resumes the saved semifinal")
	_check(game.rules.teams[1] != opening_opponents and game.rules.teams[1][0].g == 370, "Semifinal uses a different, stronger demo lineup")
	_difficulty_checks(95, 150)
	var semifinal_progress: Dictionary = game.tournament.to_dict()
	# Quick mode must neither reset nor advance an in-progress tournament.
	game._start_quick_match()
	_capture_match(0)
	_check(game.tournament.to_dict() == semifinal_progress, "Quick victory preserves an active tournament checkpoint")
	game._continue_tournament()
	_capture_match(0)
	_check(game.tournament.stage == 2 and game.tournament.active, "Semifinal victory advances to the final")
	game._overlay_primary()
	_check(game.phase == "opening" and game.tournament.stage == 2, "Next-round primary action begins the final")
	_check(game.rules.teams[1][0].g == 390, "Final uses the strongest demo opponent power")
	_difficulty_checks(120, 175)
	_capture_match(0)
	_check(game.tournament.completed and not game.tournament.active and game.tournament.stage == 2, "Final victory completes the tournament")
	var final_wins: int = game.wins
	game._end_match()
	_check(game.wins == final_wins and game.tournament.completed, "Repeated final completion awards no extra win")
	game._save_profile(PROFILE_PATH)
	game.tournament.start_new()
	game._load_profile(PROFILE_PATH)
	_check(game.tournament.completed and not game.tournament.active, "Completed tournament survives a profile roundtrip")
	game._overlay_primary()
	_check(game.phase == "menu" and game.overlay.visible, "Completed tournament primary action returns to menu")
	game._start_tournament()
	_check(game.tournament.stage == 0 and game.tournament.active and not game.tournament.completed, "New tournament resets completed progress")

func _profile_checks() -> void:
	game.selected_roster = [3, 4, 5]
	game.selected_attributes = ["Darkus", "Aquos", "Haos"]
	game.wins = 17
	game.losses = 9
	game.muted = true
	game.tournament.load_dict({"stage": 1, "active": true, "completed": false})
	game._save_profile(PROFILE_PATH)
	var config := ConfigFile.new()
	_check(config.load(PROFILE_PATH) == OK, "Profile is a readable ConfigFile")
	_check(int(config.get_value("results", "wins", -1)) == 17 and int(config.get_value("results", "losses", -1)) == 9, "Version 0.3 preserves the existing result keys")
	game.selected_roster = [0, 1, 2]
	game.selected_attributes = ["Pyrus", "Pyrus", "Ventus"]
	game.wins = 0
	game.losses = 0
	game.muted = false
	game.tournament.start_new()
	game._load_profile(PROFILE_PATH)
	_check(game.selected_roster == [3, 4, 5] and game.selected_attributes == ["Darkus", "Aquos", "Haos"], "Profile restores the selected three-creature roster and attributes")
	_check(game.wins == 17 and game.losses == 9 and game.muted and AudioServer.is_bus_mute(0), "Profile restores existing counters and audio setting")
	_check(game.tournament.stage == 1 and game.tournament.active and not game.tournament.completed, "Profile restores tournament stage and activity")
	var legacy := ConfigFile.new()
	legacy.set_value("results", "wins", 4)
	legacy.set_value("results", "losses", 2)
	legacy.set_value("settings", "muted", false)
	_check(legacy.save(LEGACY_PATH) == OK, "Creates an original version 0.2 profile fixture")
	game._load_profile(LEGACY_PATH)
	_check(game.wins == 4 and game.losses == 2 and not game.muted, "Version 0.2 profile results and settings load correctly")
	_check(game.selected_roster == [0, 1, 2] and game.selected_attributes == ["Pyrus", "Pyrus", "Ventus"], "Version 0.2 profile gets the default team")
	_check(game.tournament.stage == 0 and not game.tournament.active and not game.tournament.completed, "Version 0.2 profile gets a fresh inactive tournament")
	# New-format malformed values are covered at the module level; load a file
	# with no supported sections to verify the scene's backward-compatible defaults.
	var invalid := ConfigFile.new()
	invalid.set_value("unknown", "unused", "fixture")
	_check(invalid.save(INVALID_PATH) == OK, "Creates a profile lacking supported sections")
	game._load_profile(INVALID_PATH)
	_check(game.wins == 0 and game.losses == 0 and not game.muted, "Missing result and setting sections use defaults")
	_check(game.selected_roster == [0, 1, 2] and not game.tournament.active, "Missing team and tournament sections use defaults")
	for path: String in [PROFILE_PATH, LEGACY_PATH, INVALID_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.rng.seed = 20261003
	game.muted = true
	await _roster_checks()
	_quick_checks()
	_tournament_checks()
	_profile_checks()
	# Allow preview reveals to finish after previews were removed/replaced.
	await create_timer(0.8).timeout
	game.queue_free()
	await process_frame
	print("UPDATE 0.3 CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
