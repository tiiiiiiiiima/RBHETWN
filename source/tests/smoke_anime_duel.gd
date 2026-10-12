extends SceneTree
## A complete match through scene controls, live throwing and the timed AI.

const DuelScene = preload("res://scripts/anime_duel.gd")
const Roster = preload("res://scripts/roster.gd")
const Layout = preload("res://scripts/board_layout.gd")
var checks: int = 0
var failures: Array[String] = []
var player_throws: int = 0
var battle_count: int = 0
var observed_styles: Dictionary = {}
var observed_phases: Dictionary = {}
var traps_deployed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _buttons(container: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in container.get_children():
		if child is Button:
			result.append(child as Button)
	return result


func _tick(scene: Node3D, delta: float) -> void:
	# This smoke run accelerates game time. The independent DS presentation
	# must receive the same delta so its result hold does not use wall time.
	scene._process(delta)
	scene.battle_presentation._process(delta)


func _mouse_at(scene: Node3D, slot: int) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = scene.arena.camera.unproject_position(Layout.POSITIONS[slot])
	scene._unhandled_input(event)


func _place_first_gate(scene: Node3D, slot: int) -> void:
	var hands: Array[Button] = _buttons(scene._hand_grid)
	if hands.is_empty() or hands[0].disabled:
		return
	hands[0].pressed.emit()
	_mouse_at(scene, slot)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = scene.arena.camera.unproject_position(Layout.POSITIONS[slot])
	scene._unhandled_input(click)


func _launch_player(scene: Node3D, unit_index: int, slot: int) -> void:
	scene._unit_buttons[unit_index].pressed.emit()
	_mouse_at(scene,slot)
	var before: int = scene.rules.turn_serial
	scene._stand_button.pressed.emit()
	if scene.last_throw_slot==slot and scene.rules.turn_serial>=before:
		player_throws += 1


func _player_turn(scene: Node3D) -> void:
	var available: Array = scene.rules.available_units(0)
	if available.is_empty():
		for index: int in range(3):
			if scene.rules.teams[0][index].status == "field":
				scene._unit_buttons[index].pressed.emit()
				return
		scene._end_button.pressed.emit()
		return
	var chosen: int = int(available[0])
	for index: int in available:
		if int(scene.rules.teams[0][index].current_g) > int(scene.rules.teams[0][chosen].current_g):
			chosen = index
	var target_slot: int = -1
	for slot: Variant in scene.rules.gates:
		for unit: Dictionary in scene.rules.gates[slot].bakugan:
			if int(unit.owner) == 1:
				target_slot = int(slot)
				break
		if target_slot >= 0:
			break
	if target_slot < 0:
		for slot: Variant in scene.rules.gates:
			if scene.rules.gates[slot].bakugan.is_empty():
				target_slot = int(slot)
				break
	if target_slot < 0 and not scene.rules.gate_hands[0].is_empty():
		var legal: Array = scene.rules.legal_gate_slots()
		if not legal.is_empty():
			target_slot = 9 if legal.has(9) else int(legal[0])
			_place_first_gate(scene, target_slot)
	if target_slot >= 0:
		_launch_player(scene, chosen, target_slot)
	else:
		scene._end_button.pressed.emit()


func _select_response_units(scene: Node3D, caster: int, target: int) -> void:
	for option: int in range(scene._caster_select.item_count):
		if int(scene._caster_select.get_item_metadata(option)) == caster:
			scene._caster_select.select(option)
			scene._caster_select.item_selected.emit(option)
			break
	for option: int in range(scene._target_select.item_count):
		var metadata: Dictionary = scene._target_select.get_item_metadata(option)
		if int(metadata.owner) == 1 and int(metadata.index) == target:
			scene._target_select.select(option)
			scene._target_select.item_selected.emit(option)
			break


func _player_response(scene: Node3D) -> void:
	if not scene._open_button.disabled:
		scene._open_button.pressed.emit()
		return
	var enemies: Array = scene.rules.battle_units(1)
	if not enemies.is_empty():
		for caster: int in scene.rules.trap_casters(0):
			if scene.rules.can_deploy_trap(0, caster, int(enemies[0].index), scene._default_trap_options(0)):
				_select_response_units(scene, caster, int(enemies[0].index))
				if not scene._trap_button.disabled:
					scene._trap_button.pressed.emit()
					traps_deployed += 1
					return
		for index: int in range(scene.rules.ability_hands[0].size()):
			var card: Dictionary = scene.rules.ability_hands[0][index]
			if str(card.effect.type) == "counter":
				var pending_owner: int = -1
				var chain: Array = scene.rules.battle.get("chain", [])
				for position: int in range(chain.size() - 1, -1, -1):
					if not chain[position].cancelled and not chain[position].resolved:
						pending_owner = int(chain[position].owner)
						break
				if pending_owner != 1:
					continue
			for caster: int in scene.rules.ability_casters(0, index):
				for enemy: Dictionary in enemies:
					if not scene.rules.can_play_ability(0, index, caster, int(enemy.index), 1):
						continue
					_select_response_units(scene, caster, int(enemy.index))
					var buttons: Array[Button] = _buttons(scene._hand_grid)
					if index < buttons.size() and not buttons[index].disabled:
						buttons[index].pressed.emit()
						return
	if not scene._pass_button.disabled:
		scene._pass_button.pressed.emit()


func _run() -> void:
	var scene = DuelScene.new()
	scene.configure(Roster.make_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), "anime_board", {"reduced_motion": true}, "lob")
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.battle_presentation.set_process(false)
	scene.support_selection = {"id": "metalfencer", "attribute": "Pyrus"}
	_check(scene.start_match(20261008).get("ok", false), "Seeded duel starts from a legal saved or default deck")
	var original_rules = scene.rules
	var original_unit_button: Button = scene._unit_buttons[0]
	var paused_during_flight: bool = false
	var ticks: int = 0
	var previous_phase: String = "opening"
	while scene.rules.phase != "finished" and ticks < 20000:
		observed_phases[scene.visual_phase] = true
		if scene.rules.phase == "battle" and previous_phase != "battle":
			battle_count += 1
		previous_phase = scene.rules.phase
		if not paused_during_flight and scene.visual_phase == "flying":
			var position_before: Vector3 = scene._flight_ball.position
			scene._set_paused(true)
			_tick(scene, 0.75)
			_check(scene.paused and scene._pause_panel.visible and scene._flight_ball.position == position_before, "Pause freezes an actual moving sphere")
			scene._set_paused(false)
			_check(not scene.paused and not scene._pause_panel.visible, "Resume returns to the same live throw")
			paused_during_flight = true
		if scene.visual_phase not in ["flying", "rolling"]:
			if scene.rules.phase == "opening" and scene.rules.turn == 0:
				var legal: Array = scene.rules.legal_gate_slots()
				_place_first_gate(scene, 5 if legal.has(5) else int(legal[0]))
			elif scene.rules.phase == "turn" and scene.rules.turn == 0:
				_player_turn(scene)
			elif scene.rules.phase == "battle" and int(scene.rules.battle.priority) == 0:
				_player_response(scene)
		_tick(scene, 0.04)
		ticks += 1
		if ticks % 64 == 0:
			await process_frame
	_check(ticks < 20000 and scene.rules.phase == "finished" and scene.rules.winner in [0, 1], "Valid scene actions and the timed AI reach a complete match result")
	_check(not observed_phases.has("flying") and not observed_phases.has("rolling") and battle_count > 0, "The complete anime match uses selected gates and strategic battles")
	_check(scene._flight_ball==null and not scene._style_button.visible and not scene._charge_bar.visible, "Anime match exposes gate selection without physical throw controls")
	if scene.rules.phase == "finished":
		_check(scene.battle_presentation.is_result_playing() and scene._end_button.disabled, "Final result holds the restart action until its presentation finishes")
		var result_guard: int = 0
		while scene.battle_presentation.is_result_playing() and result_guard < 64:
			_tick(scene, 0.04)
			result_guard += 1
		_tick(scene, 0.04)
		_check(result_guard < 64 and not scene.battle_presentation.is_result_playing(), "The final DS result completes on the same simulated clock as the match")
		var abilities_played: int = 0
		var chains_resolved: int = 0
		var recorded_traps: int = 0
		for action: Dictionary in scene.rules.history:
			if action.get("event", "") == "ability_played":
				abilities_played += 1
			elif action.get("event", "") == "chain_resolved":
				chains_resolved += 1
			elif action.get("event", "") == "trap_played":
				recorded_traps += 1
		_check(abilities_played > 0 and chains_resolved > 0, "The complete match plays abilities and resolves actual response chains")
		_check(traps_deployed == 1 and recorded_traps >= 1 and scene.rules.support_slots[0].used, "The complete physical match deploys the separate trap once through its response button")
		_check(scene._support_nodes.is_empty(), "A completed physical match removes all deployed trap models")
		_check(scene.rules.defeated[1 - scene.rules.winner].size() == 3, "Match result follows the defeat of every opposing Bakugan")
		_check(scene._title.text.contains("ПОБЕДА") or scene._title.text.contains("ПОРАЖЕНИЕ"), "The final outcome appears in the game-over heading")
		_check(scene._end_button.visible and scene._end_button.text == "Новая дуэль" and not scene._end_button.disabled, "Game-over UI exposes an enabled restart action")
		var first_winner: int = int(scene.rules.winner)
		scene._end_button.pressed.emit()
		_check(scene.rules == original_rules and scene.rules.phase == "opening" and scene.rules.winner == -1, "Existing restart callback resets the active rules object for a new match")
		_check(scene.rules.defeated[0].is_empty() and scene.rules.defeated[1].is_empty() and scene.rules.gates.is_empty(), "Restart clears defeated units and discarded field state")
		_check(not scene.rules.support_slots[0].used and scene.rules.support_slots[0].status == "ready" and scene.support_selection.id == "metalfencer", "Full-match restart restores the selected one-use trap without changing the saved loadout")
		_check(scene._unit_nodes.is_empty() and scene._flight_ball == null and not scene.paused and not scene._pause_panel.visible, "Restart clears old models, flight and pause state")
		_place_first_gate(scene, 5)
		var opening_guard: int = 0
		while scene.rules.phase == "opening" and opening_guard < 64:
			_tick(scene, 0.04)
			opening_guard += 1
		original_unit_button.pressed.emit()
		_check(scene.rules.turn == 0 and scene.selected_unit == 0 and scene.rules.teams[0][0].status == "reserve", "The original unit-button callback operates on the restarted match")
		print("ANIME DUEL SMOKE: %d checks, %d failures, %d ticks, %d player throws, %d battles, %d abilities, %d resolved chains, winner %d" % [checks, failures.size(), ticks, player_throws, battle_count, abilities_played, chains_resolved, first_winner])
	else:
		print("ANIME DUEL SMOKE: %d checks, %d failures; timeout phase=%s visual=%s turn=%d priority=%s throws=%d battles=%d" % [checks, failures.size(), scene.rules.phase, scene.visual_phase, scene.rules.turn, scene.rules.battle.get("priority", -1), player_throws, battle_count])
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
