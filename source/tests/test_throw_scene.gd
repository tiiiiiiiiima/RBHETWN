extends SceneTree
## Actual-scene checks for independent throw controls, shared previews,
## frozen launch state and compatible saved controls.

const Arena = preload("res://scripts/arena.gd")
const ThrowMotion = preload("res://scripts/throw_motion.gd")
const PROFILE_PATH: String = "user://throw_controls_test.cfg"
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


func _prepare(style: String = "lob", power: float = 0.7) -> void:
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	game.throw_style = style
	game.charge = power
	game.powered_throw = false
	game._update_cards()


func _control_checks() -> void:
	_prepare()
	_check(game.throw_style_button.visible and game.throw_mode_button.visible, "Aiming exposes separate trajectory and power buttons")
	game.throw_style_button.pressed.emit()
	_check(game.throw_style == "straight" and not game.powered_throw, "Changing trajectory does not enable sphere attacks")
	game.throw_mode_button.pressed.emit()
	_check(game.throw_style == "straight" and game.powered_throw, "Enabling sphere attacks leaves the selected trajectory intact")
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	game._unhandled_input(key)
	_check(game.throw_style == "lob" and game.powered_throw, "T changes only the trajectory")
	key.keycode = KEY_P
	game._unhandled_input(key)
	_check(game.throw_style == "lob" and not game.powered_throw, "P changes only the sphere-attack modifier")
	game.paused = true
	game._toggle_throw_style()
	game._toggle_throw_mode()
	_check(game.throw_style == "lob" and not game.powered_throw, "Paused aiming cannot change throw controls")
	game.paused = false
	game._launch_ball(0, 0, Arena.SLOT_POSITIONS[5])
	game._toggle_throw_style()
	game._toggle_throw_mode()
	_check(game.throw_style == "lob" and not game.powered_throw, "Throw controls cannot change after launch")
	_check(not game.throw_style_button.visible and not game.throw_mode_button.visible, "Throw controls hide while the sphere is moving")


func _preview_and_handoff_checks() -> void:
	var midpoint_heights: Dictionary = {}
	var velocities: Dictionary = {}
	for style in ["lob", "straight"]:
		_prepare(style, 0.67)
		game.charging = true
		game.aim_point = Arena.SLOT_POSITIONS[5]
		game._draw_trajectory()
		var vertices: PackedVector3Array = game.trajectory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var preview_midpoint: Vector3 = vertices[19]
		var preview_touchdown: Vector3 = vertices[39]
		_check(vertices.size() > 40, "Preview contains both airborne and ground segments")
		game._handle_action(false)
		_check(game.flight_style == style and is_equal_approx(game.flight_charge, 0.67), "Launch freezes the selected style and current charge")
		_check(game.flight_end.is_equal_approx(preview_touchdown), "Live flight lands at the preview's 34-percent touchdown")
		_check(game.flight_end.distance_to(game.roll_target) > 1.0, "The preview separates the airborne landing from the aimed gate")
		var duration: float = game._current_flight_duration()
		game._update_flight(duration * 0.5)
		_check(game.flight_ball.position.is_equal_approx(preview_midpoint), "Live flight follows the preview's midpoint")
		midpoint_heights[style] = game.flight_ball.position.y
		# Changing future settings must not alter this sphere in flight or rolling.
		game.throw_style = "straight" if style == "lob" else "lob"
		game.charge = 0.01
		game.powered_throw = true
		game._update_flight(duration * 0.5)
		_check(game.phase == "rolling" and game.flight_ball.position.is_equal_approx(preview_touchdown), "Flight hands off to rolling at the exact displayed landing point")
		var expected: Vector3 = ThrowMotion.initial_roll_velocity(preview_touchdown, game.roll_target, 0.67, style, false)
		_check(game.roll_motion.velocity.is_equal_approx(expected), "Rolling retains the charge, trajectory and modifier captured at launch")
		velocities[style] = game.roll_motion.velocity.length()
		_check(not game.pickups.is_empty(), "Both trajectory types retain the existing pickup phase")
	_check(float(midpoint_heights.lob) > float(midpoint_heights.straight) + 1.0, "The actual scene displays a high arc and a low direct throw")
	_check(float(velocities.straight) > float(velocities.lob), "Direct throws carry more actual ground speed at equal charge")
	_prepare("straight", 0.7)
	game.flight_duration = 0.12
	game._launch_ball(0, 0, Arena.SLOT_POSITIONS[5])
	_check(game._current_flight_duration() < 0.12, "The configurable flight duration scales the style duration")
	game._update_flight(0.12)
	_check(game.phase == "rolling", "Shortened scene-test flights still finish normally")
	game.flight_duration = 1.55


func _charge_checks() -> void:
	var speeds: Array[float] = []
	for power in [0.2, 0.5, 0.8]:
		_prepare("straight", power)
		game._launch_ball(0, 0, Arena.SLOT_POSITIONS[5])
		game._update_flight(game._current_flight_duration())
		speeds.append(game.roll_motion.velocity.length())
	_check(speeds[0] < speeds[1] and speeds[1] < speeds[2], "The actual rolling handoff responds continuously to charge")
	_prepare("lob", 0.7)
	game.charging = true
	game.charge = 0.2
	game._draw_trajectory()
	var weak_vertices: PackedVector3Array = game.trajectory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var weak_landing: Vector3 = weak_vertices[39]
	game.charge = 0.8
	game._draw_trajectory()
	var strong_vertices: PackedVector3Array = game.trajectory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(weak_landing.distance_to(strong_vertices[39]) > 0.5, "Charging updates the actual preview touchdown rather than a fixed full-field arc")


func _profile_checks() -> void:
	game._set_rules_profile("wii")
	game.throw_style = "straight"
	game.selected_roster = [3, 4, 5]
	game.selected_attributes = ["Darkus", "Aquos", "Haos"]
	game.selected_deck = [3, 4, 5]
	game._save_profile(PROFILE_PATH)
	var config := ConfigFile.new()
	_check(config.load(PROFILE_PATH) == OK and config.get_value("controls", "throw_style") == "straight", "Chosen trajectory is stored under controls.throw_style")
	_check(config.get_value("profile", "schema") == 7, "Separate DS/Wii decks migrate to schema seven while keeping compatible Wii selections")
	game.throw_style = "lob"
	game._load_profile(PROFILE_PATH)
	_check(game.throw_style == "straight" and game.selected_roster == [3, 4, 5] and game.selected_deck == [3, 4, 5], "Profile roundtrip restores controls without resetting the team or card deck")
	config.erase_section("controls")
	config.save(PROFILE_PATH)
	game._load_profile(PROFILE_PATH)
	_check(game.throw_style == "lob" and game.selected_roster == [3, 4, 5], "Existing profiles without throw controls receive a safe high-throw default")
	for invalid: Variant in ["unrecognized-style", {"value": "straight"}, 1, null]:
		config.set_value("controls", "throw_style", invalid)
		config.save(PROFILE_PATH)
		game._load_profile(PROFILE_PATH)
		_check(game.throw_style == "lob", "Invalid persisted controls cannot select an unsupported trajectory")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))


func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._set_rules_profile("wii")
	game.set_process(false)
	game.rng.seed = 20261008
	game.muted = true
	_control_checks()
	_preview_and_handoff_checks()
	_charge_checks()
	_profile_checks()
	game.queue_free()
	await process_frame
	# The asynchronous audio mixer releases queued playback references.
	await create_timer(0.12).timeout
	print("THROW SCENE CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
