extends SceneTree
## Run: godot --headless --path . --script tests/test_throw_motion.gd

const ThrowMotion = preload("res://scripts/throw_motion.gd")
const RollMotion = preload("res://scripts/roll_motion.gd")
var failures: int = 0
var checks: int = 0


func _init() -> void:
	_test_styles()
	_test_paths()
	_test_velocity()
	_test_invalid_inputs()
	_test_roll_handoff()
	if failures == 0:
		print("PASS: %d throw trajectory checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d throw trajectory checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_styles() -> void:
	_check(ThrowMotion.normalize_style("  STRAIGHT  ") == "straight", "Style accepts case and surrounding whitespace")
	_check(ThrowMotion.normalize_style("direct") == "straight" and ThrowMotion.normalize_style("flat") == "straight", "Direct and flat select the straight throw")
	for unknown in ["lob", "high", "", "not-a-style"]:
		_check(ThrowMotion.normalize_style(unknown) == "lob", "Unknown styles safely default to a high throw")
	_check(ThrowMotion.GROUND_CLEARANCE == RollMotion.PLANE_Y, "Throw landing and ground rolling use the same sphere clearance")
	_check(ThrowMotion.flight_duration("straight") < ThrowMotion.flight_duration("lob") * 0.5, "A direct throw reaches the ground sooner than a lob")
	for style in ["lob", "straight"]:
		_check(ThrowMotion.flight_duration(style, true) < ThrowMotion.flight_duration(style), "Powered modifier shortens the chosen flight without changing its type")


func _test_paths() -> void:
	var start := Vector3(1, 0.5, 5)
	var end := Vector3(-2, ThrowMotion.GROUND_CLEARANCE, -3)
	for style in ["lob", "straight"]:
		for powered in [false, true]:
			_check(ThrowMotion.flight_position(start, end, 0.0, style, powered) == start, "Flight begins at the launch point")
			_check(ThrowMotion.flight_position(start, end, 1.0, style, powered) == end, "Flight ends exactly at the roll handoff point")
			var previous := start
			var valid_path: bool = true
			for frame in range(101):
				var t: float = float(frame) / 100.0
				var point: Vector3 = ThrowMotion.flight_position(start, end, t, style, powered)
				valid_path = valid_path and point.is_finite() and point.y >= ThrowMotion.GROUND_CLEARANCE - 0.000001
				valid_path = valid_path and point.x >= end.x and point.x <= start.x and point.z >= end.z and point.z <= start.z
				valid_path = valid_path and point.x <= previous.x and point.z <= previous.z
				previous = point
			_check(valid_path, "Every sample moves toward the target without ground penetration or horizontal overshoot")
	for powered in [false, true]:
		var lob: Vector3 = ThrowMotion.flight_position(start, end, 0.5, "lob", powered)
		var straight: Vector3 = ThrowMotion.flight_position(start, end, 0.5, "straight", powered)
		_check(lob.y > straight.y + 1.0, "High and straight throws remain visibly distinct with either power modifier")
		_check(straight.y < 0.6, "Direct throws stay close to the playing surface")
	var equal_height_start := Vector3(-3, 0.44, 2)
	var equal_height_end := Vector3(3, 0.44, -2)
	var apex: Vector3 = ThrowMotion.flight_position(equal_height_start, equal_height_end, 0.5)
	_check(is_equal_approx(apex.y, 2.64), "A normal high throw has the intended apex above the sphere clearance")
	_check(ThrowMotion.flight_position(equal_height_start, equal_height_end, 0.25).y == ThrowMotion.flight_position(equal_height_start, equal_height_end, 0.75).y, "Equal-height flights have symmetric ascent and descent")
	_check(ThrowMotion.flight_position(start, end, -10.0) == start and ThrowMotion.flight_position(start, end, 10.0) == end, "Progress is clamped before the throw can overshoot")
	var below_floor: Vector3 = ThrowMotion.flight_position(Vector3(1, -8, 2), Vector3(3, -3, 4), 1.0)
	_check(below_floor == Vector3(3, ThrowMotion.GROUND_CLEARANCE, 4), "Ground-level targets retain X/Z and lift the sphere center above the floor")


func _test_velocity() -> void:
	var start := Vector3(0, 9, 5)
	var end := Vector3(3, -9, 1)
	for style in ["lob", "straight"]:
		for powered in [false, true]:
			var low: Vector3 = ThrowMotion.initial_roll_velocity(start, end, 0.0, style, powered)
			var middle: Vector3 = ThrowMotion.initial_roll_velocity(start, end, 0.5, style, powered)
			var high: Vector3 = ThrowMotion.initial_roll_velocity(start, end, 1.0, style, powered)
			_check(low.length() < middle.length() and middle.length() < high.length(), "Charge continuously changes initial rolling speed")
			_check(is_equal_approx(middle.length(), (low.length() + high.length()) * 0.5), "Half charge is intermediate rather than a binary speed selection")
			_check(high.y == 0.0 and high.normalized().is_equal_approx(Vector3(0.6, 0, -0.8)), "Rolling velocity follows the horizontal aiming direction")
			_check(high.length() <= RollMotion.MAX_SPEED + 0.00001, "Throw velocity respects the rolling subsystem speed cap")
		var basic: Vector3 = ThrowMotion.initial_roll_velocity(start, end, 0.8, style)
		var powered: Vector3 = ThrowMotion.initial_roll_velocity(start, end, 0.8, style, true)
		_check(powered.length() > basic.length(), "Powered sphere attacks carry more ground speed for either style")
	_check(ThrowMotion.initial_roll_velocity(start, end, 0.5, "straight").length() > ThrowMotion.initial_roll_velocity(start, end, 0.5, "lob").length(), "Direct throws retain more rolling speed than high throws at equal charge")
	_check(ThrowMotion.initial_roll_velocity(Vector3(1, 8, 2), Vector3(1, -8, 2), 1.0) == Vector3.ZERO, "A vertically aligned target has no undefined horizontal heading")
	_check(ThrowMotion.initial_roll_velocity(start, end, -3.0).is_equal_approx(ThrowMotion.initial_roll_velocity(start, end, 0.0)), "Negative power clamps to minimum")
	_check(ThrowMotion.initial_roll_velocity(start, end, 3.0).is_equal_approx(ThrowMotion.initial_roll_velocity(start, end, 1.0)), "Oversized power clamps to maximum")


func _test_invalid_inputs() -> void:
	var corrupt := Vector3(INF, NAN, -INF)
	var another_corrupt := Vector3(NAN, -INF, INF)
	for progress in [NAN, INF, -INF, 0.0, 0.5, 1.0]:
		for style in ["lob", "straight"]:
			var point: Vector3 = ThrowMotion.flight_position(corrupt, another_corrupt, progress, style)
			_check(point.is_finite() and point.y >= ThrowMotion.GROUND_CLEARANCE - 0.000001, "Nonfinite input cannot poison the flight path")
	for power in [NAN, INF, -INF]:
		_check(ThrowMotion.initial_roll_velocity(corrupt, another_corrupt, power, "straight", true).is_finite(), "Nonfinite inputs cannot poison the rolling velocity")
	var enormous := Vector3(1.0e30, 1.0e30, -1.0e30)
	var opposite := -enormous
	_check(ThrowMotion.flight_position(enormous, opposite, 0.5).is_finite(), "Very large finite coordinates cannot overflow interpolation")
	_check(ThrowMotion.initial_roll_velocity(enormous, opposite, 1.0).is_finite(), "Very large finite coordinates cannot overflow velocity normalization")
	var start := Vector3(0, 0.5, 5)
	var end := Vector3(1, 0.44, -2)
	_check(ThrowMotion.flight_position(start, end, INF) == end, "An overdue flight resolves to its landing point")
	_check(ThrowMotion.flight_position(start, end, NAN) == start, "An invalid flight clock resolves to the safe launch point")


func _test_roll_handoff() -> void:
	var start := Vector3(0, 0.5, 4.5)
	var touchdown := Vector3(1, 0.44, 2)
	var target := Vector3(2, 0.44, -0.5)
	for style in ["lob", "straight"]:
		var landing: Vector3 = ThrowMotion.flight_position(start, touchdown, 1.0, style)
		var intended_velocity: Vector3 = ThrowMotion.initial_roll_velocity(landing, target, 0.7, style)
		var roll = RollMotion.new()
		roll.begin(landing, target, intended_velocity.length())
		_check(roll.position == landing and roll.velocity.is_equal_approx(intended_velocity), "Existing roll API accepts the style and charge velocity without a handoff jump")
		var previous: Vector3 = roll.position
		roll.step(1.0 / 60.0)
		_check(is_equal_approx(roll.position.y, ThrowMotion.GROUND_CLEARANCE) and roll.position.distance_to(previous) > 0.0, "The chosen throw continues into playable ground motion")
