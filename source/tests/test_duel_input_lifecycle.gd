extends SceneTree
## Real mouse events verify modal isolation and immediate anime placement.

const Duel = preload("res://scripts/anime_duel.gd")
const Roster = preload("res://scripts/roster.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")
var scene: Node3D
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		scene.get_viewport().push_input(event, true)
		await process_frame


func _opening() -> void:
	scene.start_match(11123)
	scene.rules.gate_hands[0][0] = Cards.get_gate("pyrus_50")
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene.selected_gate = -1
	await process_frame


func _own_field_turn() -> void:
	await _opening()
	scene._place_unit_on_gate(0,0,5)
	scene._handle_result(scene.rules.throw_unit(1, 0, 6))
	scene._handle_result(scene.rules.finish_turn(1))
	await process_frame


func _run() -> void:
	scene = Duel.new()
	scene.configure(Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), "ds_pyrus", {"reduced_motion": true}, "straight")
	scene.auto_ai = false
	root.add_child(scene)
	await process_frame
	await _opening()
	scene._set_paused(true)
	var before: String = JSON.stringify(scene.rules.state_snapshot())
	await _click(scene._end_button)
	_check(JSON.stringify(scene.rules.state_snapshot()) == before, "Clicking outside the pause dialog cannot end a paused turn")
	_check(not scene._can_player_throw(), "Throw availability is false while paused")
	scene._set_paused(false)
	await _click(scene._end_button)
	_check(scene.rules.turn == 1, "Resume restores the same end-turn button's real mouse input")
	await _own_field_turn()
	scene._set_paused(true)
	before = JSON.stringify(scene.rules.state_snapshot())
	await _click(scene._unit_buttons[0])
	_check(JSON.stringify(scene.rules.state_snapshot()) == before, "A unit button outside the pause dialog cannot recall a field unit")
	await _own_field_turn()
	scene._show_deck()
	before = JSON.stringify(scene.rules.state_snapshot())
	await _click(scene._unit_buttons[0])
	_check(JSON.stringify(scene.rules.state_snapshot()) == before, "Editing the next deck blocks recall clicks behind the editor")
	await _opening()
	scene._begin_charge()
	_check(not scene.charging and scene.visual_phase=="idle" and scene._flight_ball==null and scene.rules.teams[0][0].status=="field", "Space places immediately without starting a charge or flight")
	before = JSON.stringify(scene.rules.state_snapshot())
	await _click(scene._end_button)
	_check(JSON.stringify(scene.rules.state_snapshot())==before and scene.rules.turn==1, "Placement ends the player turn once; another click cannot end the enemy turn")
	await _opening()
	var gate_button: Button = scene._hand_grid.get_child(1)
	scene._side_scroll.ensure_control_visible(gate_button)
	await process_frame
	await _click(gate_button)
	_check(not scene.charging and scene.charge == 0.0 and scene.selected_gate == 0, "Selecting a gate remains a card placement action")
	before = JSON.stringify(scene.rules.state_snapshot())
	scene._begin_charge()
	_check(JSON.stringify(scene.rules.state_snapshot())==before, "Space cannot place a Bakugan while choosing a new gate")
	await _opening()
	scene._place_unit_on_gate(0,0,5)
	scene._handle_result(scene.rules.throw_unit(1, 0, 5))
	while scene.rules.phase == "battle":
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
	await process_frame
	_check(scene.battle_presentation.is_result_playing() and scene.rules.turn == 0, "The completed enemy throw leaves a retained result before the next player turn")
	before = JSON.stringify(scene.rules.state_snapshot())
	await _click(scene._end_button)
	_check(JSON.stringify(scene.rules.state_snapshot()) == before, "Clicking end-turn during the result cannot skip the next player turn")
	_check(scene._end_button.disabled, "Result presentation visibly disables the next turn's action")
	await create_timer(1.7).timeout
	await process_frame
	_check(not scene._end_button.disabled, "The end-turn button re-enables automatically when the result ends")
	await _click(scene._end_button)
	_check(scene.rules.turn == 1, "Mouse actions work again after the result finishes")
	scene.queue_free()
	await process_frame
	print("DUEL INPUT LIFECYCLE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
