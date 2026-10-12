extends SceneTree
## Deterministic actual-scene checks for Wii opening/optional placement/refill,
## Stay, Double Stand choices and the three source-based minigame behaviors.

const Arena = preload("res://scripts/arena.gd")
const Board = preload("res://scripts/board_layout.gd")
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

func _scene_landing(owner: int, unit_index: int, slot: int) -> void:
	game._launch_ball(owner, unit_index, Arena.SLOT_POSITIONS[slot])
	game.flight_ball.position = Arena.SLOT_POSITIONS[slot] + Vector3(0, 0.44, 0)
	game._land_ball()

func _opening_checks() -> void:
	game.start_match()
	_check(game.phase == "opening" and game.rules.gates.is_empty(), "New match begins before either opening gate is placed")
	_check(game._free_slots() == Board.INITIAL_SLOTS, "Only the four central spaces are initially available")
	game._handle_action(true)
	game._skip_gate()
	_check(game.phase == "opening" and game.flight_ball == null and not game.charging, "Mandatory opening cannot be skipped or turned into a throw")
	game._place_player_gate(0)
	_check(game.rules.gates.is_empty() and game.rules.hands[0].size() == 3, "An opening card cannot be placed outside the center")
	game._place_player_gate(5)
	_check(game.phase == "place" and game.rules.gates.size() == 2 and game.rules.turn == 0, "Both players place before player one receives the first throw")
	_check(game.rules.hands[0].size() == 2 and game.rules.hands[1].size() == 2, "Opening consumes one gate from each hand")
	for slot: Variant in game.rules.gates:
		_check(Board.INITIAL_SLOTS.has(int(slot)) and not bool(game.rules.gates[slot].revealed), "Every opening gate occupies a central space and remains face down")
	var before: int = game.rules.gates.size()
	game._skip_gate()
	_check(game.phase == "aim" and game.rules.gates.size() == before and game.rules.turn == 0, "Player may skip additional placement while keeping the same turn")
	game._place_player_gate(4)
	_check(game.rules.gates.size() == before, "An aiming turn cannot place another gate")
	game.start_match()
	game._place_player_gate(5)
	_check(game._free_slots().has(4) and not game._free_slots().has(15), "Additional card spaces must adjoin the existing field orthogonally")
	game._place_player_gate(4)
	_check(game.phase == "aim" and game.rules.gates.has(4), "One legal optional card leads to aiming")
	_check(game.aim_point.is_equal_approx(Arena.SLOT_POSITIONS[4]), "Aiming retains the selected newly placed gate")
	# Model the empty-field event, leaving each player's unused hand intact.
	game.rules.gates.clear()
	for slot: int in range(Board.SLOT_COUNT):
		game.arena.remove_gate(slot)
	game._begin_player_turn()
	_check(game.phase == "opening", "An empty field requires another both-player placement")
	game._place_player_gate(5)
	_check(game.rules.gates.size() == 2 and game.rules.turn == 0, "Field refill places one gate from both hands before throwing")

func _stay_checks() -> void:
	game.start_match()
	for pair: Array in [[0, 5], [1, 6], [2, 9]]:
		_check(game.rules.place_gate(0, 0, int(pair[1])), "Stay fixture places a legal connected gate")
		game.rules.land(0, int(pair[0]), int(pair[1]))
	game._begin_player_turn()
	_check(game.phase == "stay" and game.rules.needs_stay(0), "Three standing units offer Stay at the start of their owner's turn")
	game._choose_card(1)
	_check(game.rules.stay_markers[0].get("slot", -1) == 6 and game.flight_ball == null, "Choosing Stay marks the selected unit's gate and skips throwing")
	_check(game.rules.scores == [0, 0] and game.rules.gates.has(6), "Stay does not immediately capture its gate")
	game.rules.finish_turn()
	game.rules.finish_turn()
	game._begin_player_turn()
	_check(game.rules.scores == [1, 0] and not game.rules.gates.has(6), "Surviving Stay captures at the next own turn")
	_check(game.rules.gates[5].bakugan.size() == 1 and game.rules.gates[9].bakugan.size() == 1, "Stay preserves the other standing units instead of recalling one")
	_check(game.match_stats.summary(0).captures == 1, "Stay capture appears in actual match statistics")

func _double_checks() -> void:
	game.start_match()
	game.rules.place_gate(0, 0, 5)
	game.rules.place_gate(1, 0, 6)
	_scene_landing(0, 0, 5)
	_scene_landing(0, 1, 5)
	_check(game.phase == "double" and game.rules.scores == [0, 0], "An allied Double Stand with a neighboring gate offers a choice")
	game._resolve_double(6)
	_check(game.rules.gates[5].bakugan.size() == 1 and game.rules.gates[6].bakugan.size() == 1, "Move choice keeps the first ball and moves only the most recently thrown ball")
	_check(game.rules.gates[6].bakugan[0].index == 1 and game.rules.scores == [0, 0], "Moving instead of capturing does not award a gate")
	_check(game.unit_nodes.has("0:1") and game.unit_nodes["0:1"].position.distance_to(Arena.SLOT_POSITIONS[6]) < 0.6, "The moved unit's actual board visual follows its new gate")
	var stats: Dictionary = game.match_stats.summary(0)
	_check(stats.throws == 2 and stats.hits == 2 and stats.double_stands == 0, "A pending or moved Double Stand remains two successful throws without a capture")
	game.start_match()
	game.rules.place_gate(0, 0, 5)
	game.rules.place_gate(1, 0, 6)
	_scene_landing(0, 0, 5)
	_scene_landing(0, 1, 5)
	game._resolve_double(-1)
	_check(game.rules.scores == [1, 0] and not game.rules.gates.has(5) and game.rules.gates.has(6), "Capture choice awards only the Double Stand gate")
	_check(game.unit_nodes.is_empty() and game.match_stats.summary(0).double_stands == 1, "Double capture removes both unit visuals and records one capture")

func _power_collision(speed: float) -> void:
	game._launch_ball(0, 0, Arena.SLOT_POSITIONS[5])
	game._sync_units()
	game._begin_roll()
	game._clear_pickups()
	var defender: Vector3 = game.unit_nodes["1:0"].position
	var start: Vector3 = defender + Vector3(0, 0, 0.65)
	game.roll_motion.begin(start, defender, speed, 2.8)
	game.flight_ball.position = game.roll_motion.position
	game._update_roll(0.15)

func _sphere_checks() -> void:
	game.start_match()
	game.rules.place_gate(0, 0, 5)
	game.rules.land(1, 0, 5)
	game._begin_aim(5)
	game._toggle_throw_mode()
	_check(game.powered_throw, "Power throw can be selected before aiming is released")
	_power_collision(5.4)
	_check(game.phase == "battle_ready" and game.rules.gates[5].bakugan.size() == 2, "A forceful surviving Sphere collision still leads to the opposed battle")
	var enemy: Dictionary = game._battle_breakdown(1, 0)
	_check(enemy.damage > 0 and enemy.damage < enemy.base and game.rules.teams[1][0].g == 350, "Sphere damage appears separately while the defender's base G stays unchanged")
	game.start_match()
	game.rules.teams[1][0].g = 20
	game.rules.place_gate(0, 0, 5)
	game.rules.land(1, 0, 5)
	game._begin_aim(5)
	game._toggle_throw_mode()
	_power_collision(5.4)
	_check(game.rules.scores == [1, 0] and not game.rules.gates.has(5), "A forceful depleted defender causes Critical K.O. and capture without a minigame")
	_check(game.unit_nodes.is_empty() and game.rules.teams[0][0].used, "Critical K.O. clears captured visuals and spends the attacker's throw")
	var stats: Dictionary = game.match_stats.summary(0)
	_check(stats.throws == 1 and stats.hits == 1 and stats.captures == 1 and stats.battles == 0, "Critical K.O. records exactly one successful throw and capture")
	game.start_match()
	game.rules.teams[1][0].g = 20
	game.rules.place_gate(0, 0, 5)
	game.rules.land(1, 0, 5)
	game._begin_aim(5)
	game._toggle_throw_mode()
	_power_collision(0.3)
	_check(game.phase == "battle_ready" and game.rules.scores == [0, 0] and game._battle_breakdown(1, 0).damage == 0, "A slow power-mode roll cannot cause Sphere damage or Critical K.O.")

func _practice(kind: String) -> void:
	game._start_practice(kind)
	game.rules.abilities[1].clear()
	if game.phase == "battle_ready":
		game._start_battle_game()
	game.ai_target_points = 0
	game.battle_points = 0
	game.hit_cooldown = 0.0

func _timing_window_checks() -> void:
	_practice("timing")
	game.battle_streak = 4
	var initial_sequence: int = game.timing_sequence
	game._update_battle(0.25)
	_check(game.rhythm_phase >= 0.415 and game.rhythm_phase <= 0.6, "Elapsed battle time moves the Timing marker into its scoring window")
	game._update_battle(0.10)
	_check(game.battle_streak == 0 and not game.bonus_mode and game.timing_sequence == initial_sequence + 1, "Leaving a Timing window without input loses the streak and advances the sequence")
	_practice("timing")
	for ignored: int in range(5):
		game.hit_cooldown = 0.0
		game.rhythm_phase = 0.5
		game._battle_hit(KEY_SPACE)
	game._update_battle(0.25)
	game.hit_cooldown = 0.0
	var before_hit: int = game.battle_points
	game._battle_hit(KEY_SPACE)
	game._update_battle(0.10)
	_check(game.battle_streak == 6 and game.bonus_mode and game.battle_points - before_hit == 64, "A correct hit inside the elapsed window preserves bonus mode after exit and doubles the sixth hit")
	var before_miss: int = game.timing_sequence
	game._update_battle(0.45)
	game._update_battle(0.10)
	_check(game.battle_streak == 0 and not game.bonus_mode and game.timing_sequence == before_miss + 1, "The next unplayed Timing window cancels active bonus mode automatically")

func _mini_checks() -> void:
	_practice("timing")
	_check(game.battle_level == 1, "A match without captures starts minigame level one")
	for ignored: int in range(5):
		game.hit_cooldown = 0.0
		game.rhythm_phase = 0.5
		var keys: Array = game._timing_keys()
		game._battle_hit(int(keys[0]))
	_check(game.battle_streak == 5 and game.bonus_mode and game.battle_points > 0, "Five consecutive correct Timing inputs enter bonus mode")
	game.hit_cooldown = 0.0
	game.rhythm_phase = 0.0
	game._battle_hit(KEY_SPACE)
	_check(game.battle_streak == 0 and not game.bonus_mode, "A missed Timing window cancels its streak and bonus mode")
	_practice("shooting")
	for ignored: int in range(5):
		game.hit_cooldown = 0.0
		game.shooting_attributes[0] = "Pyrus"
		game._shoot_target(0)
	_check(game.battle_streak == 5 and game.bonus_mode and game.battle_points > 0, "Five own-attribute Shooting hits enter bonus mode")
	game.shooting_attributes[0] = "Darkus"
	game.hit_cooldown = 0.0
	game._shoot_target(0)
	_check(game.battle_streak == 0 and not game.bonus_mode, "Shooting another attribute cancels the streak")
	_practice("shooting")
	game.battle_level = 2
	game.shooting_attributes[0] = "gold"
	game.shooting_attributes[1] = "Pyrus"
	game.shooting_attributes[2] = "Pyrus"
	game._shoot_target(0)
	_check(game.battle_points > 0, "A level-two gold icon awards the matching attribute icons on screen")
	_practice("shaking")
	game._battle_hit(KEY_A)
	_check(game.battle_points > 0, "A valid level-one Shaking input adds G")
	game.battle_level = 2
	game.battle_points = 100
	for sample: int in range(100):
		game.battle_time = float(sample) * 0.1
		if game._shaking_stop():
			break
	_check(game._shaking_stop(), "Shaking level two contains Stop windows")
	game.hit_cooldown = 0.0
	game._battle_hit(KEY_D)
	_check(game.battle_points < 100, "Shaking during Stop loses G")
	game._start_quick_match()
	game.rules.scores.assign([1, 2])
	game.rules.place_gate(0, 0, 5)
	game.rules.land(0, 0, 5)
	game.rules.land(1, 0, 5)
	game._begin_battle(5)
	_check(game.battle_level == 3, "Highest captured-card score sets minigame level independently of AI preference")

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.rng.seed = 20261006
	game.muted = true
	_opening_checks()
	_stay_checks()
	_double_checks()
	_sphere_checks()
	_timing_window_checks()
	_mini_checks()
	game.start_match()
	await create_timer(1.3).timeout
	_check(game.phase == "opening" and game.rules.gates.is_empty(), "Expired controlled-action callbacks leave the final new opening untouched")
	game.queue_free()
	await process_frame
	print("UPDATE 0.6 SCENE CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
