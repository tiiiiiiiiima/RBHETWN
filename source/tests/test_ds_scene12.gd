extends SceneTree
## Exercises actual profile migration, card widgets, strict DS turns and card
## application in the classic scene. Files live in this test's private user dir.

const DSCatalog = preload("res://scripts/ds_playable_catalog.gd")
const DSArt = preload("res://scripts/ds_card_catalog.gd")
const AbilityCatalog = preload("res://scripts/ability_catalog.gd")
const GateCatalog = preload("res://scripts/gate_catalog.gd")
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

func _last_selection(kind: String, profile: String) -> Array:
	var result: Array = []
	var colors: Array = ["gold", "silver", "copper"] if kind == "gate" else ["red", "green", "blue"]
	for color: String in colors:
		var indices: Array = DSCatalog.indices_for_color(kind, color) if profile == "ds" else GateCatalog.indices_for_color(color) if kind == "gate" else AbilityCatalog.indices_for_color(color)
		result.append(indices[-1])
	return result

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.get_script() == null:
		_check(false, "Actual classic scene script loads without parse errors")
		quit(1)
		return
	game.set_process(false)
	game.muted = true
	game.rng.seed = 120012
	game._load_profile("user://nonexistent-profile-12.cfg")
	_check(game.rules_profile == "ds", "Fresh profile selects the complete source-backed DS starter deck")
	_check(game.selected_deck.size() == 3 and game.selected_gate_deck.size() == 3, "Fresh DS profile has three abilities and three gates")
	game._open_settings()
	_check(game.rules_selector.item_count == 2 and game.rules_selector.selected == 0, "Settings explicitly exposes separate DS and Wii rules")
	_check(game.rules_description.text.contains("адаптированы"), "Settings identifies the PC minigame adaptation")

	var old := ConfigFile.new()
	var wii_abilities: Array = _last_selection("ability", "wii")
	var wii_gates: Array = _last_selection("gate", "wii")
	old.set_value("profile", "schema", 6)
	old.set_value("deck", "selection", wii_abilities)
	old.set_value("gates", "selection", wii_gates)
	old.set_value("results", "wins", 4)
	old.set_value("results", "losses", 2)
	old.set_value("controls", "throw_style", "straight")
	old.save("user://old-schema-12.cfg")
	game._load_profile("user://old-schema-12.cfg")
	_check(game.rules_profile == "wii", "Schema 6 remains Wii instead of interpreting old indices as DS cards")
	_check(game.selected_deck == wii_abilities and game.selected_gate_deck == wii_gates, "Migration preserves both customized Wii decks")
	_check(game.wins == 4 and game.losses == 2 and game.throw_style == "straight", "Migration preserves results and throw preference")
	game.rules_selector.item_selected.emit(0)
	_check(game.rules_profile == "ds", "The settings selector's real signal switches to the DS profile")
	game.selected_deck = _last_selection("ability", "ds")
	game.selected_gate_deck = _last_selection("gate", "ds")
	var ds_abilities: Array = game.selected_deck.duplicate()
	var ds_gates: Array = game.selected_gate_deck.duplicate()
	game._set_rules_profile("wii")
	_check(game.selected_deck == wii_abilities and game.selected_gate_deck == wii_gates, "Switching back restores Wii deck selections")
	game._set_rules_profile("ds")
	_check(game.selected_deck == ds_abilities and game.selected_gate_deck == ds_gates, "Switching again restores DS deck selections")
	game._save_profile("user://roundtrip-12.cfg")
	var saved := ConfigFile.new()
	saved.load("user://roundtrip-12.cfg")
	_check(int(saved.get_value("profile", "schema", 0)) == 7, "Separate profile decks use schema 7")
	_check(saved.get_value("deck", "selection", []) == wii_abilities, "Compatibility deck keys always remain Wii indices")
	_check(saved.get_value("decks_ds", "ability_keys", []) == game._ds_selection_keys("ability", ds_abilities), "DS abilities persist stable source identities")
	_check(saved.get_value("decks_ds", "gate_keys", []) == game._ds_selection_keys("gate", ds_gates), "DS gates persist stable source identities")
	saved.set_value("decks_ds", "abilities", [999, 998, 997])
	saved.set_value("decks_ds", "gates", [999, 998, 997])
	saved.save("user://roundtrip-12.cfg")
	game._load_profile("user://roundtrip-12.cfg")
	_check(game.rules_profile == "ds" and game.selected_deck == ds_abilities and game.selected_gate_deck == ds_gates, "Stable DS keys recover correct cards even when saved catalog indices change")
	game._set_rules_profile("wii")
	_check(game.selected_deck == wii_abilities and game.selected_gate_deck == wii_gates, "Round-trip retains the other profile's customized cards")
	game._set_rules_profile("ds")
	game.selected_deck = DSCatalog.normalize_selection("ability", [])
	game.selected_gate_deck = DSCatalog.normalize_selection("gate", [])
	game._refresh_deck_ui()
	game._refresh_gate_ui()
	for slot in range(3):
		var ability: Dictionary = DSCatalog.cards("ability")[game.selected_deck[slot]]
		var gate: Dictionary = DSCatalog.cards("gate")[game.selected_gate_deck[slot]]
		_check(game.deck_art[slot].texture == DSArt.texture(str(ability.source_key)), "Deck widget displays the selected native DS ability face")
		_check(game.gate_art[slot].texture == DSArt.texture(str(gate.source_key)), "Gate widget displays the selected native DS gate face")
		game._open_card_view("abilities", slot)
		_check(game.card_view_art.texture == DSArt.texture(str(ability.source_key)) and game.card_view_title.text == ability.title, "Ability zoom uses DS card identity and face")
	game._open_help()
	_check(game.help_title.text.ends_with("DS") and game.help_body.text.contains("адаптированы"), "DS help identifies rules and the current minigame adaptation")

	game.match_mode = "quick"
	game.start_match()
	_check(game.phase == "opening" and game.rules.rules_profile == "ds", "A real classic match starts in DS opening state")
	_check(game.rules.hands[0][0].key.begins_with("ds_card_"), "Live DS match uses source-backed gates rather than Wii aliases")
	_check(not game.rules.finish_turn(), "Controller cannot skip either opening placement")
	game._place_player_gate(5)
	_check(not game.rules.opening_active and game.rules.gates.size() == 2, "Controller completes one opening gate for each side")
	var owners: Array = []
	for gate: Dictionary in game.rules.gates.values():
		owners.append(int(gate.owner))
	_check(owners.has(0) and owners.has(1), "Opening field contains opposing owners")
	_check(game.phase == "place" and game.rules.turn == 0, "Opening resumes the original player's optional placement")
	_check(not game.rules.place_gate(1, 0, game.rules.legal_gate_slots()[0]), "Opponent cannot add a gate outside its own turn")
	var extra_slot: int = game.rules.legal_gate_slots()[0]
	game._place_player_gate(extra_slot)
	_check(game.phase == "aim" and game.rules.gate_placed_this_turn, "One optional card advances the controller to aiming")
	var hand_size: int = game.rules.hands[0].size()
	_check(not game.rules.place_gate(0, 0, game.rules.legal_gate_slots()[0]) and game.rules.hands[0].size() == hand_size, "Repeated optional placement does not consume another card")
	var first: Dictionary = game.rules.land(0, 0, 5)
	_check(str(first.event) == "stand" and game.rules.finish_turn(), "First player lands and ends one real action")
	var second: Dictionary = game.rules.land(1, 0, 5)
	_check(str(second.event) == "battle", "Opposing player landing creates a pending battle")
	game._begin_battle(5)
	var gate_key: String = str(game.rules.gates[5].source_key)
	_check(game.ds_battle._gate_face.texture == DSArt.texture(gate_key), "Battle presentation displays the revealed original DS gate")
	_check(game.arena.gates[5].get_meta("card_art", {}).get("key", "") == gate_key, "Board's revealed gate displays the same source identity")
	game._advance_turn()
	_check(game.rules.turn == 1 and game.phase == "battle_ready" and game.ds_battle.is_presenting(), "Rejected premature turn advance preserves the pending DS battle presentation")
	# Use the real Dragonoid-only native green card while Leonidas is fighting.
	# This makes the unavailable-card path mandatory, independent of defaults.
	var restricted_green: Dictionary = {}
	for card: Dictionary in DSCatalog.make_deck("ability", [], 0):
		if card.color_type == "green":
			restricted_green = card.duplicate(true)
	var dragonoid: Dictionary = DSCatalog.metadata("ds_card_511")
	_check(not dragonoid.is_empty(), "Dragonoid's source-backed restricted ability is available")
	if not dragonoid.is_empty():
		restricted_green = dragonoid.duplicate(true)
		restricted_green["owner"] = 0
		restricted_green["id"] = "p0_ds_card_511"
		game.rules.abilities[0][1] = restricted_green
	game._update_cards()
	var blocked: int = -1
	var allowed: int = -1
	for index in range(game.rules.abilities[0].size()):
		if game._ability_allowed(0, game.rules.abilities[0][index]):
			allowed = index
		else:
			blocked = index
	if blocked >= 0:
		var before: int = game.rules.abilities[0].size()
		_check(not game._play_ability(0, blocked) and game.rules.abilities[0].size() == before, "Ineligible DS ability does not consume its card")
		_check(game.card_buttons[blocked].disabled and game.card_buttons[blocked].tooltip_text.contains("Недоступно"), "Disabled card explains its unavailable condition")
	_check(blocked >= 0, "The controlled DS battle verifies a blocked native ability")
	_check(allowed >= 0, "The DS starter deck contains an eligible ability for this controlled battle")
	if allowed >= 0:
		var card: Dictionary = game.rules.abilities[0][allowed].duplicate(true)
		var before: int = game.rules.abilities[0].size()
		_check(game._play_ability(0, allowed), "A legal DS ability is applied through the actual scene")
		_check(game.rules.abilities[0].size() == before - 1 and game.rules.spent_abilities[0].has(card), "Playing a DS ability moves exactly one card to the spent pile")
		_check(game.deck_text.text.contains("Сыграно: 1"), "HUD reports the spent ability count")
		_check(game.card_buttons[-1].disabled and game.card_buttons[-1].text.contains("СЫГРАНА"), "Spent card remains readable as a disabled card instead of being shown as a Bakugan")
	game._start_battle_game()
	_check(game.phase == "battle", "DS AI evaluates source cards and starts the adapted minigame")
	_check(game.log_text.clip_text and game.log_text.max_lines_visible == 16, "Long native ability descriptions cannot extend beyond the journal panel")
	_check(game.turn_text.text == "Соперник", "Opponent's turn label fits a single line above the reserve")
	game.battle_points = 10000
	game.ai_target_points = 0
	game._finish_battle()
	_check(game.rules.scores[0] == 1 and not game.rules.gates.has(5), "The live DS battle resolves and captures one gate")
	game.match_id += 1 # Cancel the delayed next-turn callback before new practice.
	for kind: String in ["timing", "shooting", "shaking"]:
		game._start_practice(kind)
		_check(game.phase == "battle_ready" and game.rules.pending_slot() == 5 and not game.rules.opening_active, "DS practice completes valid opening and opposing turn sequence")
		_check(game.battle_type == kind, "DS practice selects the requested desktop minigame")
	# Verify source gate modifiers in the actual HUD, with controlled printed G
	# that differs from the native gate bonus. This catches adding modifiers
	# twice or retaining the original printed number in the breakdown.
	for source_id: int in [315, 322, 323]:
		var copper_index: int = -1
		var entries: Array = DSCatalog.cards("gate")
		for index in range(entries.size()):
			if int(entries[index].source_card_id) == source_id:
				copper_index = index
		_check(copper_index >= 0, "The verified printed-G modifier gate is available in the DS catalog")
		if copper_index < 0:
			continue
		game.selected_gate_deck[2] = copper_index
		game._start_practice("shaking")
		for unit: Dictionary in game.rules.gates[5].bakugan:
			unit.g = 260 if int(unit.owner) == 0 else 420
			unit.attribute = "Pyrus" if int(unit.owner) == 0 else "Darkus"
		game._refresh_battle_scores()
		var expected_player: int = 520 if source_id == 315 else 420
		var expected_enemy: int = 420 if source_id == 315 else 260
		_check(game._battle_breakdown(0, 0).base == expected_player and game._battle_breakdown(1, 0).base == expected_enemy, "Native printed-G modifier is reflected in both HUD breakdowns")
		_check(game.battle_detail_text.text.begins_with("ТЫ: база %d" % expected_player), "HUD labels show modified printed G")
		_check(game._battle_base(0) == expected_player + int(game.rules.gates[5].boosts.Pyrus), "Modified printed G and native attribute bonus contribute exactly once")
	game.match_id += 1
	# Drain the canceled result timer before destroying the actual scene.
	await create_timer(1.75).timeout
	game.queue_free()
	await process_frame
	print("DS SCENE 0.12 CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
