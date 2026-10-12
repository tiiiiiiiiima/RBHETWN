extends SceneTree
## Exercise the playable scene's deck, throw handoff and response flow.

const DuelScene = preload("res://scripts/anime_duel.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")
const Roster = preload("res://scripts/roster.gd")
const Layout = preload("res://scripts/board_layout.gd")
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
	var scene = DuelScene.new()
	scene.configure(Roster.make_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), "stadium", {"reduced_motion": true}, "straight")
	scene.auto_ai = false
	root.add_child(scene)
	await process_frame
	_check(scene._deck_panel.visible and scene.paused and not scene.started, "Entering the duel presents an editable deck before playing")
	_check(scene._gate_selectors.size() == 6 and scene._ability_selectors.size() == 10, "Loadout editor has six gate and ten ability slots")
	_check(Cards.valid_gate_loadout(scene.gate_loadout) and Cards.valid_ability_loadout(scene.ability_loadout), "Suggested loadout obeys exact counts and repeat limits")
	_check(scene.throw_style == "straight" and scene.arena.theme_id == "stadium" and scene.arena.reduced_motion, "Menu configuration carries arena, throw style and reduced motion into the duel")
	_check(scene.start_match(281).get("ok", false), "A deterministic match starts from the edited deck")
	_check(scene.rules.phase == "opening" and not scene.paused and not scene._deck_panel.visible, "Starting switches from deck editor to opening placement")
	_check(scene.rules.gate_hands[0].size() == 3 and scene.rules.ability_hands[0].size() == 5, "UI begins with the intended gate and ability hands")
	var hand_before: int = scene.rules.gate_hands[0].size()
	_check(not scene._try_place_gate(-1).get("ok", true) and scene.rules.gate_hands[0].size() == hand_before, "An off-field placement does not consume a card")
	scene.selected_gate = 0
	_check(scene._try_place_gate(5).get("ok", false), "Player places opening card through the scene action")
	_check(scene.rules.turn == 1 and scene.arena.gates.has(5), "Opening placement updates turn and visible field")
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	_check(scene.rules.phase == "turn" and scene.rules.turn == 0 and scene.arena.gates.has(6), "Opponent opening card starts the player turn")
	scene.selected_gate = -1
	_check(not scene._style_button.visible and not scene._charge_bar.visible, "Anime has no physical throw controls")
	var before: int = scene.rules.turn_serial
	_check(not scene._place_unit_on_gate(0,0,-1).get("ok",true) and scene.rules.turn_serial==before, "Invalid anime destination does not consume turn")
	scene._launch_throw(0,0,Layout.POSITIONS[5],0.75)
	_check(scene.visual_phase == "idle" and scene._flight_ball == null, "Anime placement resolves immediately with no flight or roll")
	_check(scene.rules.teams[0][0].status == "field" and scene.rules.turn == 1, "A stand displays the open form and automatically ends the throwing turn")
	_check(scene._unit_nodes.has("0:0") and scene._unit_nodes["0:0"].get_meta("actual_form", "") == "toy", "Standing creature uses the source open form")
	var battle: Dictionary = scene.rules.throw_unit(1, 0, 5)
	scene._handle_result(battle)
	_check(battle.get("ok", false) and scene.rules.phase == "battle", "Enemy stand on the occupied gate begins a strategic battle")
	_check(scene._pass_button.visible and scene._open_button.visible and scene._battle_label.text.contains("База + ворота + способности"), "Battle UI shows separate G components and response actions")
	_check(scene._unit_nodes.size() == 2, "Both battle participants remain visible on the contested gate")
	if scene.rules.battle.priority == 0:
		scene._handle_result(scene.rules.open_gate(0))
	_check(scene.rules.gates[5].revealed, "Gate owner opens the actual selected gate before passing")
	var guard: int = 0
	while scene.rules.phase == "battle" and guard < 12:
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
		guard += 1
	_check(scene.rules.phase == "turn" and scene.rules.defeated[0].size() + scene.rules.defeated[1].size() == 1, "Consecutive passes resolve the battle and permanently defeat one Bakugan")
	_check(not scene.arena.gates.has(5) and scene._unit_nodes.is_empty(), "Resolved battle removes the discarded gate and returns the winner to reserve")
	_check(scene.rules.turn == 0, "Battle completion passes the finished enemy turn back to the player")
	scene._set_paused(true)
	_check(scene.paused and scene._pause_panel.visible and not scene.charging, "Pause stops charge and exposes the pause controls")
	scene._set_paused(false)
	_check(not scene.paused and not scene._pause_panel.visible, "Resume hides pause controls")
	_check(scene.start_match(281).get("ok", false) and scene.rules.phase == "opening" and scene.rules.defeated[0].is_empty() and scene.rules.defeated[1].is_empty(), "Restart resets defeated units and field without losing the selected deck")
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene._flight_owner = 0
	scene._flight_unit = 0
	scene._finish_throw(5)
	scene._handle_result(scene.rules.throw_unit(1, 0, 6))
	scene._handle_result(scene.rules.finish_turn(1))
	scene._flight_unit = 1
	var stack: Dictionary = scene._finish_throw(5)
	_check(stack.get("event", "") == "stack" and scene.rules.gates[5].bakugan.size() == 2 and scene.rules.turn == 1, "Allied stacking completes the throwing action and preserves both field units")
	_check(scene._unit_nodes["0:0"].position != scene._unit_nodes["0:1"].position and scene._unit_nodes["0:0"].scale.x < 0.5, "Allied source models use separate positions and fit the shared card")
	scene._handle_result(scene.rules.throw_unit(1, 1, 5))
	_check(scene.rules.phase == "battle" and scene._caster_select.item_count == 2 and scene._target_select.item_count == 3, "Team battle presents each caster and both enemy and allied target choices")
	_check(scene._target_select.get_item_metadata(0).owner == 1 and scene._target_select.get_item_metadata(1).owner == 0, "Target choices preserve the selected creature's owner")
	scene._handle_result(scene.rules.open_gate(0))
	guard = 0
	while scene.rules.phase == "battle" and guard < 12:
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
		guard += 1
	_check(scene.rules.phase == "turn" and scene.rules.teams[0][0].status == "reserve" and scene.rules.teams[0][1].status == "reserve", "Winning allied participants return to reserve together after the team battle")
	scene.start_match(733)
	scene.set_process(false)
	scene.auto_ai = true
	scene.selected_gate = 0
	scene._try_place_gate(5)
	guard = 0
	while scene.rules.phase == "opening" and guard < 30:
		scene._process(0.1)
		guard += 1
	_check(scene.rules.phase == "turn" and scene.rules.turn == 0, "Timed AI completes its opening placement without blocking the player's turn")
	scene._launch_throw(0, 0, Layout.POSITIONS[5], 0.8)
	var observed: Dictionary = {}
	guard = 0
	while scene.rules.defeated[0].size() + scene.rules.defeated[1].size() == 0 and guard < 600:
		observed[scene.visual_phase] = true
		if scene.rules.phase == "battle" and int(scene.rules.battle.priority) == 0:
			var gate: Dictionary = scene.rules.gates[int(scene.rules.battle.slot)]
			if gate.owner == 0 and not gate.revealed:
				scene._handle_result(scene.rules.open_gate(0))
			else:
				scene._handle_result(scene.rules.pass_response(0))
		scene._process(0.05)
		guard += 1
	_check(not observed.has("flying") and not observed.has("rolling"), "Anime turns never use physical flying or rolling")
	_check(guard < 600 and scene.rules.defeated[0].size() + scene.rules.defeated[1].size() > 0, "Selected gates, AI placement and alternating responses complete an anime battle")
	scene.start_match(936)
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene._flight_owner = 0
	scene._flight_unit = 2
	scene._finish_throw(6)
	scene._handle_result(scene.rules.throw_unit(1, 0, 6))
	scene._handle_result(scene.rules.pass_response(1))
	scene.rules.ability_hands[0] = [Cards.get_ability("storm_breaker")]
	scene._handle_result(scene.rules.play_ability(0, 0))
	_check(scene.rules.battle.priority == 1 and not scene.rules.can_open_gate(1), "Pending Storm Breaker prevents the owner from opening its gate in response")
	scene._ai_action()
	_check(scene.rules.battle.priority == 0, "AI chooses another response when opening the owned gate is forbidden")
	guard = 0
	while scene.rules.phase == "battle" and not scene.rules.battle.chain.is_empty() and guard < 8:
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
		guard += 1
	_check(scene.rules.gates[6].nullified and not scene.rules.can_open_gate(1), "Resolved nullification keeps the unrevealed owned gate closed")
	if scene.rules.battle.priority == 0:
		scene._handle_result(scene.rules.pass_response(0))
	scene._ai_action()
	_check(scene.rules.battle.priority == 0 or scene.rules.phase != "battle", "AI advances from a permanently nullified gate instead of repeating an invalid opening")
	scene.queue_free()
	await process_frame
	# AudioServer releases stopped OGG mixer references asynchronously.
	await create_timer(0.12).timeout
	print("ANIME SCENE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
