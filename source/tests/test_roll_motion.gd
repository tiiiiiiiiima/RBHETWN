extends SceneTree
## Run: godot --headless --path . --script tests/test_roll_motion.gd

const RollMotion = preload("res://scripts/roll_motion.gd")
var failures: int = 0
var checks: int = 0


func _init() -> void:
	_test_begin()
	_test_steering()
	_test_frame_rates()
	_test_bounds()
	_test_invalid_delta_and_controls()
	_test_braking()
	_test_finish()
	_test_segment_distance()
	if failures == 0:
		print("PASS: %d ground roll checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d ground roll checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_begin() -> void:
	var roll = RollMotion.new()
	roll.begin(Vector3(1, 8, -2), Vector3(4, -4, -2), 4.0, 2.0)
	_check(roll.position == Vector3(1, 0.44, -2), "Begin puts the roll on the ground plane")
	_check(roll.velocity.is_equal_approx(Vector3(4, 0, 0)), "Begin aims horizontally toward the chosen target")
	_check(roll.elapsed == 0.0 and roll.duration == 2.0 and not roll.is_finished(), "Begin resets the roll clock")
	roll.step(0.2)
	roll.begin(Vector3.ZERO, Vector3.ZERO, -5.0, -1.0)
	_check(roll.velocity == Vector3.ZERO and roll.elapsed == 0.0 and roll.duration > 0.0, "Begin handles a coincident target and invalid speed/duration")
	roll.begin(Vector3(INF, NAN, -INF), Vector3(NAN, INF, INF), NAN, INF)
	_check(roll.position.is_finite() and roll.velocity.is_finite() and is_finite(roll.duration), "Nonfinite throw inputs cannot poison the simulation")
	roll.begin(Vector3(100, 7, -100), Vector3(-100, 9, 100), 100.0)
	_check(roll.position == Vector3(5.2, 0.44, -4.9) and roll.velocity.length() <= RollMotion.MAX_SPEED + 0.00001, "Start and speed stay within playable bounds")


func _simulate(rate: int, steering: Vector2, braking: bool = false, seconds: float = 1.0):
	var roll = RollMotion.new()
	roll.begin(Vector3(0, 0, 2), Vector3(0, 0, -4), 3.6)
	for frame in range(roundi(seconds * rate)):
		roll.step(1.0 / rate, steering, braking)
	return roll


func _test_steering() -> void:
	var straight = _simulate(60, Vector2.ZERO)
	var right = _simulate(60, Vector2.RIGHT)
	var left = _simulate(60, Vector2.LEFT)
	_check(right.position.x > straight.position.x + 1.0 and left.position.x < straight.position.x - 1.0, "Steering meaningfully changes the roll path in both directions")
	_check(is_equal_approx(right.position.x, -left.position.x), "Left and right controls are symmetric")
	var diagonal = _simulate(60, Vector2(1, -1))
	_check(diagonal.velocity.length() <= RollMotion.MAX_SPEED + 0.00001, "Combined steering cannot exceed maximum speed")
	var oversized = _simulate(60, Vector2(100, -100))
	_check(diagonal.position.distance_to(oversized.position) < 0.0001, "Oversized control input is normalized")


func _test_frame_rates() -> void:
	var reference = _simulate(120, Vector2(0.6, -0.8), false, 1.5)
	for rate in [30, 60]:
		var candidate = _simulate(rate, Vector2(0.6, -0.8), false, 1.5)
		_check(candidate.position.distance_to(reference.position) < 0.001, "%d FPS roll path matches 120 FPS" % rate)
		_check(candidate.velocity.distance_to(reference.velocity) < 0.001, "%d FPS roll speed matches 120 FPS" % rate)
	var irregular = RollMotion.new()
	irregular.begin(Vector3(0, 0, 2), Vector3(0, 0, -4), 3.6)
	for frame in range(50):
		irregular.step(0.017, Vector2(0.6, -0.8))
		irregular.step(0.013, Vector2(0.6, -0.8))
	_check(irregular.position.distance_to(reference.position) < 0.025, "Uneven frame times remain close to the reference path")


func _test_bounds() -> void:
	for sign_value in [-1.0, 1.0]:
		var roll = RollMotion.new()
		roll.begin(Vector3(5.19 * sign_value, 8, 0), Vector3(5.2 * sign_value, 0, 0), 5.8)
		roll.step(1.0 / 30.0)
		_check(absf(roll.position.x) <= 5.2 and roll.velocity.x * sign_value < 0.0, "X wall contains and reflects the roll")
		_check(absf(roll.velocity.x) < 5.8 * 0.35, "Wall collision loses energy")
		roll.begin(Vector3(0, 8, 4.89 * sign_value), Vector3(0, 0, 4.9 * sign_value), 5.8)
		roll.step(1.0 / 30.0)
		_check(absf(roll.position.z) <= 4.9 and roll.velocity.z * sign_value < 0.0, "Z wall contains and reflects the roll")
	var corner = _simulate(30, Vector2(1, -1), false, 4.2)
	_check(absf(corner.position.x) <= 5.200001 and absf(corner.position.z) <= 4.900001 and is_equal_approx(corner.position.y, 0.44), "Sustained corner steering stays on the bounded ground plane")


func _test_invalid_delta_and_controls() -> void:
	var roll = RollMotion.new()
	roll.begin(Vector3(1, 0, 1), Vector3(-1, 0, -1))
	var before_position: Vector3 = roll.position
	var before_velocity: Vector3 = roll.velocity
	for delta_value in [-1.0, 0.0, INF, NAN]:
		roll.step(delta_value, Vector2.RIGHT, true)
		_check(roll.position == before_position and roll.velocity == before_velocity and roll.elapsed == 0.0, "Invalid delta leaves every roll field unchanged")
	roll.step(0.1, Vector2(NAN, INF))
	_check(roll.position.is_finite() and roll.velocity.is_finite(), "Nonfinite steering does not propagate into the roll")


func _test_braking() -> void:
	var coast = _simulate(60, Vector2.ZERO, false, 0.4)
	var brake = _simulate(60, Vector2.ZERO, true, 0.4)
	_check(brake.velocity.length() < coast.velocity.length() * 0.25, "Braking sharply reduces speed")
	_check(brake.position.distance_to(Vector3(0, 0.44, 2)) < coast.position.distance_to(Vector3(0, 0.44, 2)), "Braking reduces distance travelled")
	_check(not brake.is_finished(), "Low speed before half a second does not end the roll early")
	for frame in range(120):
		brake.step(1.0 / 60.0, Vector2.ZERO, true)
	_check(brake.is_finished() and brake.elapsed >= 0.5 and brake.elapsed < brake.duration, "A braked roll ends after settling")


func _test_finish() -> void:
	var roll = RollMotion.new()
	roll.begin(Vector3.ZERO, Vector3(3, 0, 0), 2.0, 0.25)
	roll.step(20.0, Vector2.RIGHT)
	_check(roll.is_finished() and roll.elapsed == 0.25, "A long frame stops exactly at the configured duration")
	var last_position: Vector3 = roll.position
	var last_velocity: Vector3 = roll.velocity
	roll.step(1.0, Vector2.LEFT)
	_check(roll.position == last_position and roll.velocity == last_velocity and roll.elapsed == 0.25, "A completed roll is immutable until begin")
	roll.begin(Vector3.ZERO, Vector3.ZERO)
	roll.step(1.0)
	_check(roll.is_finished() and roll.elapsed >= 0.5 and roll.elapsed < 0.52, "A stationary throw finishes at the settling grace period")
	roll.begin(Vector3.ZERO, Vector3(3, 0, 0))
	_check(not roll.is_finished() and roll.elapsed == 0.0, "Begin reactivates a completed roll")


func _test_segment_distance() -> void:
	var a := Vector3(0, 8, 0)
	var b := Vector3(4, -8, 0)
	_check(is_equal_approx(RollMotion.segment_distance(Vector3(2, 100, 3), a, b), 3.0), "Swept proximity ignores elevation and measures perpendicular distance")
	_check(RollMotion.segment_distance(Vector3(2, 100, 0), a, b) == 0.0, "A pickup between frame endpoints is intersected")
	_check(is_equal_approx(RollMotion.segment_distance(Vector3(5, 0, 0), a, b), 1.0), "A point beyond the segment uses the nearest endpoint")
	_check(is_equal_approx(RollMotion.segment_distance(Vector3(-3, 0, 4), a, a), 5.0), "A degenerate segment reduces to point distance")
	_check(RollMotion.segment_distance(Vector3(INF, 0, 0), a, b) == INF, "Invalid horizontal pickup coordinates are safely unreachable")
