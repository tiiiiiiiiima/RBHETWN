extends RefCounted
## Rendering-independent ground roll. Steering uses world X/Z coordinates.
## Small integration steps keep the controls consistent at common frame rates.

const MAX_SPEED: float = 5.8
const PLANE_Y: float = 0.44
const X_BOUND: float = 5.2
const Z_BOUND: float = 4.9
const ACCELERATION: float = 8.0
const DRAG: float = 0.5
const BRAKE_DRAG: float = 5.0
const BOUNCE: float = 0.35
const MAX_STEP: float = 1.0 / 120.0

var position: Vector3 = Vector3(0.0, PLANE_Y, 0.0)
var velocity: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var duration: float = 4.2
var travel_segments: Array[Dictionary] = []
var collision_count: int = 0
var _surface: Variant = null
var _bounds: Vector2 = Vector2(X_BOUND, Z_BOUND)


func configure_surface(surface: Variant = null) -> void:
	_surface = surface
	_bounds = surface.bounds if surface != null else Vector2(X_BOUND, Z_BOUND)


func begin(start: Vector3, target: Vector3, speed: float = 3.6, max_duration: float = 4.2) -> void:
	position = _bounded_point(start)
	if _surface != null:
		position = _surface.safe_ground_point(position, PLANE_Y)
	var destination: Vector3 = _bounded_point(target)
	var heading: Vector3 = destination - position
	heading.y = 0.0
	var safe_speed: float = clampf(speed, 0.0, MAX_SPEED) if is_finite(speed) else 3.6
	velocity = heading.normalized() * safe_speed if heading.length_squared() > 0.000001 else Vector3.ZERO
	elapsed = 0.0
	travel_segments.clear()
	collision_count = 0
	duration = max_duration if is_finite(max_duration) and max_duration > 0.0 else 4.2


func step(delta: float, steering: Vector2 = Vector2.ZERO, braking: bool = false) -> Vector3:
	travel_segments.clear()
	if not is_finite(delta) or delta <= 0.0 or is_finished():
		return position
	var control := Vector2(_finite_or_zero(steering.x), _finite_or_zero(steering.y)).limit_length(1.0)
	var acceleration := Vector3(control.x, 0.0, control.y) * ACCELERATION
	var remaining: float = minf(delta, duration - elapsed)
	var drag: float = BRAKE_DRAG if braking else DRAG
	while remaining > 0.00000001:
		var dt: float = minf(remaining, MAX_STEP)
		velocity = (velocity + acceleration * dt) * exp(-drag * dt)
		velocity = velocity.limit_length(MAX_SPEED)
		var previous: Vector3 = position
		position += velocity * dt
		if absf(position.x) > _bounds.x:
			position.x = clampf(position.x, -_bounds.x, _bounds.x)
			velocity.x *= -BOUNCE
		if absf(position.z) > _bounds.y:
			position.z = clampf(position.z, -_bounds.y, _bounds.y)
			velocity.z *= -BOUNCE
		if _surface != null:
			var resolved: Dictionary = _surface.resolve_roll(previous, position, velocity)
			position = resolved.position
			velocity = resolved.velocity
			if bool(resolved.collided):
				collision_count += 1
		else:
			position.y = PLANE_Y
		velocity.y = 0.0
		travel_segments.append({"from": previous, "to": position})
		elapsed = minf(duration, elapsed + dt)
		remaining -= dt
		if elapsed >= 0.5 and velocity.length_squared() < 0.08 * 0.08:
			break
	# Eliminate accumulated roundoff when consuming the last frame of a roll.
	if duration - elapsed < 0.0000001:
		elapsed = duration
	return position


func is_finished() -> bool:
	return elapsed >= duration or (elapsed >= 0.5 and velocity.length_squared() < 0.08 * 0.08)


static func segment_distance(point: Vector3, from: Vector3, to: Vector3) -> float:
	# Pickups and gates are tested along the whole travelled segment in X/Z.
	if not is_finite(point.x) or not is_finite(point.z) or not is_finite(from.x) or not is_finite(from.z) or not is_finite(to.x) or not is_finite(to.z):
		return INF
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var p := Vector2(point.x, point.z)
	var direction: Vector2 = b - a
	var length_squared: float = direction.length_squared()
	if length_squared <= 0.00000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(direction) / length_squared, 0.0, 1.0)
	return p.distance_to(a + direction * t)


static func _finite_or_zero(value: float) -> float:
	return value if is_finite(value) else 0.0


func _bounded_point(value: Vector3) -> Vector3:
	var result := Vector3(clampf(_finite_or_zero(value.x), -_bounds.x, _bounds.x), PLANE_Y, clampf(_finite_or_zero(value.z), -_bounds.y, _bounds.y))
	return _surface.ground_point(result, PLANE_Y) if _surface != null else result
