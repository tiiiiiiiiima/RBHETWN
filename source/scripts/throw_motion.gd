extends RefCounted
## Shared, rendering-independent throw paths for previews and moving spheres.
## The style remains independent of the powered sphere-attack modifier.

const RollMotion = preload("res://scripts/roll_motion.gd")
const GROUND_CLEARANCE: float = RollMotion.PLANE_Y
const MAX_ROLL_SPEED: float = RollMotion.MAX_SPEED
const MAX_WORLD_COORDINATE: float = 10000.0
const LOB: String = "lob"
const STRAIGHT: String = "straight"


static func normalize_style(style: String) -> String:
	match style.strip_edges().to_lower():
		"straight", "direct", "flat":
			return STRAIGHT
		_:
			return LOB


static func flight_duration(style: String = LOB, powered: bool = false) -> float:
	var duration: float = 0.58 if normalize_style(style) == STRAIGHT else 1.55
	return duration * (0.75 if powered else 1.0)


static func flight_position(start: Vector3, end: Vector3, progress: float, style: String = LOB, powered: bool = false) -> Vector3:
	var origin: Vector3 = _safe_point(start)
	var destination: Vector3 = _safe_point(end)
	var t: float = _unit_interval(progress)
	# Exact endpoints also avoid interpolation roundoff at the handoff to rolling.
	if t <= 0.0:
		return origin
	if t >= 1.0:
		return destination
	var height: float
	if normalize_style(style) == STRAIGHT:
		height = 0.04 if powered else 0.08
	else:
		height = 1.4 if powered else 2.2
	var result: Vector3 = origin.lerp(destination, t)
	# A parabola has its apex halfway through and contributes zero at both ends.
	result.y += 4.0 * t * (1.0 - t) * height
	return result


static func sweep_flight(arena: Node3D, start: Vector3, end: Vector3, from_progress: float, to_progress: float, style: String = LOB, powered: bool = false) -> Dictionary:
	var first: float = _unit_interval(from_progress)
	var last: float = maxf(first, _unit_interval(to_progress))
	var previous: Vector3 = flight_position(start, end, first, style, powered)
	if arena == null or not arena.has_method("resolve_flight_segment"):
		return {"position": flight_position(start, end, last, style, powered), "collided": false, "normal": Vector3.ZERO}
	# Sample the parabola before sweeping each chord; a long frame must not
	# replace a high lob by a low straight line through a source obstacle.
	var pieces: int = maxi(1, ceili(flight_duration(style, powered) * (last - first) * 120.0))
	for piece: int in range(1, pieces + 1):
		var progress: float = lerpf(first, last, float(piece) / float(pieces))
		var next: Vector3 = flight_position(start, end, progress, style, powered)
		var resolved: Dictionary = arena.resolve_flight_segment(previous, next)
		if bool(resolved.collided):
			return resolved
		previous = next
	return {"position": previous, "collided": false, "normal": Vector3.ZERO}


static func initial_roll_velocity(start: Vector3, end: Vector3, power: float, style: String = LOB, powered: bool = false) -> Vector3:
	var origin: Vector3 = _safe_point(start)
	var destination: Vector3 = _safe_point(end)
	var heading := Vector3(destination.x - origin.x, 0.0, destination.z - origin.z)
	if heading.length_squared() <= 0.000001:
		return Vector3.ZERO
	var fraction: float = _unit_interval(power)
	var speed: float
	if normalize_style(style) == STRAIGHT:
		speed = lerpf(2.6, 4.5, fraction)
	else:
		speed = lerpf(1.8, 3.8, fraction)
	if powered:
		speed += 1.2
	return heading.normalized() * minf(speed, MAX_ROLL_SPEED)


static func _unit_interval(value: float) -> float:
	if not is_finite(value):
		return 1.0 if value == INF else 0.0
	return clampf(value, 0.0, 1.0)


static func _safe_point(value: Vector3) -> Vector3:
	var x: float = value.x if is_finite(value.x) else 0.0
	var y: float = value.y if is_finite(value.y) else GROUND_CLEARANCE
	var z: float = value.z if is_finite(value.z) else 0.0
	# Playable coordinates are much smaller; bound corrupted save/input values
	# before Vector3 interpolation or normalization can overflow.
	return Vector3(
		clampf(x, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE),
		clampf(y, GROUND_CLEARANCE, MAX_WORLD_COORDINATE),
		clampf(z, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE)
	)
