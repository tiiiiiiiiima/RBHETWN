extends SceneTree
## Timed smoke test of the actual scene, both-player opening, throws, AI,
## captures, pause and restart callbacks. Scores are controlled so this tests
## game flow; source authenticity and minigame inputs have separate suites.

const Arena = preload("res://scripts/arena.gd")
var game: Node3D
var failures: Array[String] = []
var checks: int = 0
var seen: Dictionary = {}
var previous_phase: String = ""
var battle_entries: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _record() -> void:
	seen[game.phase] = true
	if game.phase == "battle":
		if previous_phase != "battle":
			battle_entries += 1
		game.ai_target_points = 0
		game.battle_points = 1000
	previous_phase = game.phase

func _wait_phase(expected: String, timeout_ms: int = 15000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		_record()
		if game.phase == expected:
			return true
		await process_frame
	_check(false, "Timed out waiting for %s; current=%s" % [expected, game.phase])
	return false

func _wait_unpaused(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _pause_check(timer_name: String, seconds: float = 0.12) -> void:
	var before_phase: String = game.phase
	var before: float = game.get(timer_name)
	game._toggle_pause()
	_check(game.paused and paused, "Pause sets game and tree pause flags")
	await _wait_unpaused(seconds)
	_check(game.phase == before_phase, "Pause preserves phase %s" % before_phase)
	_check(is_equal_approx(float(game.get(timer_name)), before), "Pause freezes %s" % timer_name)
	game._toggle_pause()
	_check(not game.paused and not paused, "Resume clears both pause flags")

func _prepare_throw() -> void:
	game._place_player_gate(5)
	if game.phase == "place":
		game._skip_gate()
	_check(game.phase == "aim" and game.rules.gates.size() == 2, "Both opening cards precede the first throw")

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	_check(game.phase == "menu" and game.overlay.visible, "Scene starts at menu")
	seen["menu"] = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rules="):
			game._set_rules_profile(argument.trim_prefix("--rules="))
		elif argument.begins_with("--arena="):
			game.selected_arena = argument.trim_prefix("--arena=")
	print("SMOKE PROFILE: %s; ARENA: %s" % [game.rules_profile, game.selected_arena])
	game.start_match()
	game.rng.seed = 20261006
	game.flight_duration = 0.12
	game.roll_duration = 2.8
	game.battle_duration = 0.4
	var initial_wins: int = game.wins
	var initial_losses: int = game.losses
	var paused_flight := false
	var paused_roll := false
	var paused_battle := false
	var paused_result := false
	var paused_ai := false
	var deadline: int = Time.get_ticks_msec() + (90000 if game.rules_profile=="ds" else 55000)
	while game.phase != "finished" and Time.get_ticks_msec() < deadline:
		_record()
		match game.phase:
			"opening":
				var free: Array = game._free_slots()
				_check(not free.is_empty(), "Opening offers a central gate space")
				if not free.is_empty():
					game._place_player_gate(int(free[0]))
			"place":
				game._skip_gate()
				_check(game.phase == "aim", "Optional placement can be skipped")
			"aim":
				var available: Array = game.rules.available_units(0)
				_check(not available.is_empty(), "An aiming player has an available reserve unit")
				if not available.is_empty() and not game.rules.gates.is_empty():
					var target: int = int(game.rules.gates.keys()[0])
					for slot: Variant in game.rules.gates:
						var occupants: Array = game.rules.gates[slot].bakugan
						if occupants.size() == 1:
							target = int(slot)
							if int(occupants[0].owner) == 1:
								break
					game.charge = 0.7
					game._launch_ball(0, int(available[0]), game.arena.slot_position(target))
			"stay":
				game._choose_card(0)
			"double":
				game._resolve_double(-1)
			"battle_ready":
				game.rules.abilities[1].clear()
				game._start_battle_game()
			"flying":
				if not paused_flight:
					paused_flight = true
					await _pause_check("flight_time")
			"rolling":
				if not paused_roll:
					paused_roll = true
					var roll_position: Vector3 = game.flight_ball.position
					await _pause_check("roll_time")
					_check(game.flight_ball.position.is_equal_approx(roll_position), "Pause freezes rolling position")
			"result":
				if not paused_result:
					paused_result = true
					await _pause_check("flight_time", 1.25)
			"ai":
				if not paused_ai:
					paused_ai = true
					await _pause_check("flight_time", 0.8)
			"battle":
				if not paused_battle:
					paused_battle = true
					await _pause_check("battle_time")
		await process_frame
	_record()
	print("MATCH END: phase=",game.phase," scores=",game.rules.scores)
	_check(game.phase == "finished", "Timed match reaches the result screen")
	_check(game.rules.winner == 0 and game.rules.scores[0] == 3, "Controlled player wins at exactly three captures")
	_check(game.overlay.visible and game.overlay_start.text == "СЫГРАТЬ ЕЩЁ", "Finished screen offers replay")
	_check(game.wins == initial_wins + 1 and game.losses == initial_losses, "Finished match updates profile counters once")
	for required: String in ["opening", "place", "aim", "flying", "rolling", "battle_ready", "battle", "result", "ai", "finished"]:
		_check(seen.has(required), "Visited actual phase %s" % required)
	_check(game.dragons.is_empty(), "Battle creatures are cleaned after finish")
	var old_generation: int = game.match_id
	game._overlay_primary()
	_check(game.match_id == old_generation + 1, "Replay creates a new generation")
	_check(game.rules.scores == [0, 0] and game.rules.winner == -1 and game.rules.turn == 0, "Replay resets winner, scores and turn")
	_check(game.rules.hands[0].size() == 3 and game.rules.hands[1].size() == 3, "Replay restores both gate hands before opening")
	_check(game.rules.abilities[0].size() == 3 and game.rules.abilities[1].size() == 3, "Replay restores both ability hands")
	_check(game.rules.available_units(0).size() == 3 and game.rules.available_units(1).size() == 3, "Replay restores all reserve units")
	_check(game.rules.gates.is_empty() and game.unit_nodes.is_empty() and game.dragons.is_empty() and game.flight_ball == null, "Replay clears board and flight visuals")
	_check(game.phase == "opening" and not game.overlay.visible and not game.battle_panel.visible and not game.result_banner.visible, "Replay opens the mandatory initial gate placement")
	_check(not game.paused and not paused and not game.charging and game.charge == 0.0, "Replay clears charge and pause state")
	_check(game.roll_time == 0.0 and game.roll_bonus == 0 and game.roll_motion.elapsed == 0.0 and game.roll_motion.velocity == Vector3.ZERO, "Replay clears rolling state")
	_check(game.pickups.is_empty() and game.battle_slot == -1 and game.battle_points == 0 and game.ability_points == 0, "Replay clears pickup and battle fields")
	_prepare_throw()
	game.charge = 0.7
	game._launch_ball(0, 0, game.arena.slot_position(5))
	await _wait_phase("result")
	game.start_match()
	await _wait_unpaused(1.3)
	_check(game.phase == "opening" and game.rules.turn == 0 and game.rules.gates.is_empty(), "Old result callback cannot alter a restarted match")
	_prepare_throw()
	game.charge = 0.7
	game._launch_ball(0, 0, game.arena.slot_position(5))
	await _wait_phase("ai")
	game.start_match()
	await _wait_unpaused(1.3)
	_check(game.phase == "opening" and game.rules.turn == 0 and game.rules.gates.is_empty(), "Old AI callback cannot throw in a restarted match")
	print("SMOKE CHECKS: %d; FAILURES: %d; PHASES: %s; BATTLES: %d" % [checks, failures.size(), str(seen.keys()), battle_entries])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
