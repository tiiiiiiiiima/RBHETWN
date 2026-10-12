extends SceneTree
## Integration regression tests for rolling, collection and landing power.
## Run: godot --headless --path . --script tests/test_update_02.gd

const Arena = preload("res://scripts/arena.gd")
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

func _pickup(position: Vector3, amount: int = 20) -> Dictionary:
	var node := Node3D.new()
	node.position = position
	game.add_child(node)
	return {"position": position, "amount": amount, "node": node, "collected": false}

func _new_match() -> void:
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	game._launch_ball(0, 0, Arena.SLOT_POSITIONS[5])

func _pickup_checks() -> void:
	_new_match()
	game.pickups.append(_pickup(Vector3(0, 0.44, 0)))
	game._collect_pickups(Vector3(-2, 0.44, 0), Vector3(2, 0.44, 0))
	_check(game.roll_bonus == 0 and not bool(game.pickups[0].collected), "Pickups cannot be collected during the flight phase")
	game._update_flight(game.flight_duration)
	game._clear_pickups()
	game.roll_bonus = 0
	game.pickups.append(_pickup(Vector3(0, 0.44, 0)))
	var collected_node: Node3D = game.pickups[0].node
	game._collect_pickups(Vector3(-2, 0.44, 0), Vector3(2, 0.44, 0))
	_check(game.roll_bonus == 20, "Swept path collects an orb between frames for 20 G")
	_check(bool(game.pickups[0].collected), "Collected pickup records its consumed state")
	_check(collected_node.is_queued_for_deletion() or not collected_node.visible, "Collected pickup visual is removed")
	game._collect_pickups(Vector3(2, 0.44, 0), Vector3(-2, 0.44, 0))
	_check(game.roll_bonus == 20, "Traversing the same pickup again adds no G")
	game._clear_pickups()
	game.pickups.append(_pickup(Vector3(0, 0.44, 2)))
	var uncollected_node: Node3D = game.pickups[0].node
	game._collect_pickups(Vector3(-2, 0.44, 0), Vector3(2, 0.44, 0))
	_check(game.roll_bonus == 20 and not bool(game.pickups[0].collected), "Pickup outside swept path is not collected")
	game._clear_pickups()
	_check(uncollected_node.is_queued_for_deletion(), "Cleanup removes an uncollected pickup visual")
	game.roll_bonus = 0
	game.pickups.append(_pickup(Vector3(0, 0.44, 0)))
	game._toggle_pause()
	game._collect_pickups(Vector3(-2, 0.44, 0), Vector3(2, 0.44, 0))
	_check(game.roll_bonus == 0 and not bool(game.pickups[0].collected), "Paused rolling cannot collect pickup G")
	game._toggle_pause()
	game._clear_pickups()
	for i in range(7):
		game.pickups.append(_pickup(Vector3(float(i) * 0.2, 0.44, 0)))
	game._collect_pickups(Vector3(-2, 0.44, 0), Vector3(2, 0.44, 0))
	_check(game.roll_bonus == 120, "Seven 20 G orbs cannot exceed the 120 G throw cap")
	var collected: int = 0
	for pickup: Dictionary in game.pickups:
		if bool(pickup.collected):
			collected += 1
	_check(collected == 7, "Every intersected pickup is consumed even at the G cap")
	game._clear_pickups()
	_check(game.pickups.is_empty(), "Pickup cleanup empties pickup bookkeeping")

func _landing_checks() -> void:
	_new_match()
	game._update_flight(game.flight_duration)
	_check(not game.pickups.is_empty(), "Entering rolling populates pickup visuals")
	var pickup_node: Node3D = game.pickups[0].node
	# Deliberately separate aim from the actual ball position: landing follows it.
	game.flight_end = Vector3(4, 0.44, 3)
	game.flight_ball.position = Arena.SLOT_POSITIONS[5] + Vector3(0, 0.44, 0)
	game.roll_bonus = 60
	game._land_ball()
	_check(game.rules.gates[5].bakugan.size() == 1, "Landing resolves actual ball position instead of old aim endpoint")
	_check(int(game.rules.gates[5].bakugan[0].roll_bonus) == 60, "Collected G is stored with the landed Bakugan")
	_check(game.pickups.is_empty(), "Landing removes throw pickup nodes and bookkeeping")
	_check(pickup_node.is_queued_for_deletion(), "Landing queues remaining pickup visuals for removal")
	_check(game.flight_ball == null and game.unit_nodes.has("0:0"), "Landed ball moves from flight to board visuals")
	game._launch_ball(1, 0, Arena.SLOT_POSITIONS[5])
	game.flight_powered = false
	_check(game.roll_bonus == 0, "Next throw starts with a fresh G bonus")
	game._update_flight(game.flight_duration)
	game.flight_ball.position = Arena.SLOT_POSITIONS[5] + Vector3(0, 0.44, 0)
	game.roll_bonus = 20
	game._land_ball()
	_check(game.phase == "battle_ready", "Opposing actual-position landing opens battle preparation")
	var player_unit: Dictionary = game.rules.teams[0][0]
	var enemy_unit: Dictionary = game.rules.teams[1][0]
	var expected_player: int = int(player_unit.g) + 2 * game.rules.gate_bonus(5, str(player_unit.attribute)) + 60
	var expected_enemy: int = int(enemy_unit.g) + game.rules.gate_bonus(5, str(enemy_unit.attribute)) + 20
	_check(game._battle_base(0) == expected_player, "Player battle base includes retained roll G")
	_check(game._battle_base(1) == expected_enemy, "Enemy battle base includes its own roll G")
	_check(game.pickups.is_empty(), "Battle landing removes the second throw's pickups")
	game.start_match()
	_check(game.roll_bonus == 0 and game.roll_time == 0.0 and game.roll_motion.elapsed == 0.0 and game.roll_motion.velocity == Vector3.ZERO, "Restart clears roll bonus, timer and motion")
	_check(game.pickups.is_empty() and game.flight_ball == null and game.unit_nodes.is_empty(), "Restart clears pickup, flight and board visuals")
	_check(game.dragons.is_empty(), "Restart clears battle creatures")

func _restart_during_roll_checks() -> void:
	_new_match()
	game.flight_duration = 0.12
	game._update_flight(game.flight_duration)
	_check(game.phase == "rolling", "Flight enters controllable rolling instead of directly landing")
	_check(game.roll_motion != null, "Rolling creates a motion state")
	game._update_roll(0.1)
	game.roll_bonus = 40
	game.start_match()
	_check(game.phase == "opening" and game.roll_time == 0.0 and game.roll_bonus == 0, "Restart during rolling resets phase, timer and G bonus")
	_check(game.roll_motion.elapsed == 0.0 and game.roll_motion.velocity == Vector3.ZERO and game.flight_ball == null and game.pickups.is_empty(), "Restart during rolling resets motion and removes ball and pickups")

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.rng.seed = 20261002
	game.muted = true
	_pickup_checks()
	_landing_checks()
	_restart_during_roll_checks()
	# Drain the old landing timers after restart before deleting the game scene.
	await create_timer(1.3).timeout
	_check(game.phase == "opening" and game.rules.gates.is_empty(), "Old landing callbacks do not advance the restarted rolling match")
	print("UPDATE 0.2 CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
