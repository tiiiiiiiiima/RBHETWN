extends RefCounted
## Collision against measured, source-skinned DS rest geometry. The PC roll is
## analytic; no source ROM gameplay collision or moving DS gimmicks are inferred.

const PROFILE_PATH: String = "res://assets/ds/arenas/throw_surface_profiles.json"
const CELL_SIZE: float = 2.0
const RADIUS: float = 0.44
const SKIN: float = 0.0005
const MAX_FLOOR_STEP: float = 0.20
const BOUNCE: float = 0.35
static var _profiles: Dictionary = {}
static var _cache: Dictionary = {}

var group_id: String = ""
var bounds: Vector2 = Vector2(5.2, 4.9)
var triangles: Array[PackedVector3Array] = []
var _cells: Dictionary = {}
var _floors: Dictionary = {}
var _walls: Dictionary = {}
var _floor_cells: Dictionary = {}
var _roll_cells: Dictionary = {}
var _low: Array[Vector3] = []
var _high: Array[Vector3] = []


static func for_group(id: String):
	if _cache.has(id):
		return _cache[id]
	if _profiles.is_empty():
		var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if file == null:
			return null
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			return null
		_profiles = parsed
	var entry: Dictionary = _profiles.get("groups", {}).get(id, {})
	if entry.is_empty():
		return null
	var surface = load("res://scripts/field_surface.gd").new()
	surface.load_profile(id, entry)
	_cache[id] = surface
	return surface


func load_profile(id: String, profile: Dictionary) -> void:
	group_id = id
	var measured_bounds: Array = profile.get("center_bounds", [5.2, 4.9])
	bounds = Vector2(float(measured_bounds[0]), float(measured_bounds[1]))
	triangles.clear()
	_cells.clear()
	_floors.clear()
	_walls.clear()
	_floor_cells.clear()
	_roll_cells.clear()
	_low.clear()
	_high.clear()
	for packed: Array in profile.get("triangles", []):
		if packed.size() != 9:
			continue
		var points := PackedVector3Array([
			Vector3(packed[0], packed[1], packed[2]),
			Vector3(packed[3], packed[4], packed[5]),
			Vector3(packed[6], packed[7], packed[8]),
		])
		var cross: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
		if not points[0].is_finite() or not points[1].is_finite() or not points[2].is_finite() or cross.length_squared() < 0.00000001:
			continue
		var index: int = triangles.size()
		triangles.append(points)
		var normal: Vector3 = cross.normalized()
		var low: Vector3 = points[0].min(points[1]).min(points[2])
		var high: Vector3 = points[0].max(points[1]).max(points[2])
		_low.append(low)
		_high.append(high)
		if absf(normal.y) >= 0.80 and low.y <= MAX_FLOOR_STEP and high.y >= -MAX_FLOOR_STEP:
			_floors[index] = true
		if absf(normal.y) < 0.80:
			_walls[index] = true
		for x: int in range(floori(maxf(low.x - RADIUS, -bounds.x - RADIUS) / CELL_SIZE), floori(minf(high.x + RADIUS, bounds.x + RADIUS) / CELL_SIZE) + 1):
			for z: int in range(floori(maxf(low.z - RADIUS, -bounds.y - RADIUS) / CELL_SIZE), floori(minf(high.z + RADIUS, bounds.y + RADIUS) / CELL_SIZE) + 1):
				var key := Vector2i(x, z)
				if not _cells.has(key):
					_cells[key] = []
				_cells[key].append(index)
				if _floors.has(index):
					if not _floor_cells.has(key):
						_floor_cells[key] = []
					_floor_cells[key].append(index)
				if _walls.has(index) and low.y <= RADIUS * 2.0 + MAX_FLOOR_STEP and high.y >= -MAX_FLOOR_STEP:
					if not _roll_cells.has(key):
						_roll_cells[key] = []
					_roll_cells[key].append(index)


func surface_height(point: Vector3) -> float:
	if not point.is_finite():
		return NAN
	var best: float = NAN
	for index: int in _floor_cells.get(_cell_key(point), []):
		if point.x < _low[index].x - 0.00001 or point.x > _high[index].x + 0.00001 or point.z < _low[index].z - 0.00001 or point.z > _high[index].z + 0.00001:
			continue
		var p: PackedVector3Array = triangles[index]
		var height: float = _height_at(point, p[0], p[1], p[2])
		if not is_finite(height) or absf(height) > MAX_FLOOR_STEP:
			continue
		if not is_finite(best) or absf(height) < absf(best):
			best = height
		if absf(best) < 0.000001:
			return best
	return best


func ground_point(point: Vector3, clearance: float = RADIUS) -> Vector3:
	var result: Vector3 = point
	if not result.is_finite():
		result = Vector3.ZERO
	result.x = clampf(result.x, -bounds.x, bounds.x)
	result.z = clampf(result.z, -bounds.y, bounds.y)
	var floor_y: float = surface_height(result)
	if not is_finite(floor_y):
		# Native floors can have rounded edges; their AABB is not a floor.
		# Project invalid setup/spawn positions to the nearest supported point
		# on the ray toward the verified native center.
		var outside: Vector3 = result
		var inside: Vector3 = Vector3.ZERO
		for iteration: int in range(16):
			var middle: Vector3 = inside.lerp(outside, 0.5)
			if is_finite(surface_height(middle)):
				inside = middle
			else:
				outside = middle
		result = inside
		floor_y = surface_height(result)
	result.y = (floor_y if is_finite(floor_y) else 0.0) + maxf(0.0, clearance if is_finite(clearance) else RADIUS)
	return result


func resolve_roll(from: Vector3, candidate: Vector3, velocity: Vector3) -> Dictionary:
	var position: Vector3 = candidate
	position.x = clampf(position.x, -bounds.x, bounds.x)
	position.z = clampf(position.z, -bounds.y, bounds.y)
	var output_velocity: Vector3 = velocity
	var collided: bool = false
	var current_floor: float = surface_height(position)
	var previous_floor: float = surface_height(from)
	position.y = (current_floor if is_finite(current_floor) else 0.0) + RADIUS
	if not is_finite(current_floor) or (is_finite(previous_floor) and absf(current_floor - previous_floor) > MAX_FLOOR_STEP):
		# An unsupported native ledge is an edge, rather than an invisible plane.
		position = from
		output_velocity *= -BOUNCE
		return {"position": position, "velocity": output_velocity, "collided": true}
	for iteration: int in range(4):
		var adjusted: bool = false
		for index: int in _roll_cells.get(_cell_key(position), []):
			if _box_distance_squared(position, index) >= RADIUS * RADIUS:
				continue
			var p: PackedVector3Array = triangles[index]
			var closest: Vector3 = _closest_triangle(position, p[0], p[1], p[2])
			var difference: Vector3 = position - closest
			var distance: float = difference.length()
			if distance >= RADIUS - SKIN:
				continue
			var horizontal := Vector3(difference.x, 0.0, difference.z)
			if horizontal.length_squared() < 0.00000001:
				horizontal = (p[1] - p[0]).cross(p[2] - p[0])
				horizontal.y = 0.0
				if horizontal.dot(from - closest) < 0.0:
					horizontal = -horizontal
			var normal: Vector3 = horizontal.normalized()
			# Horizontal separation includes the actual vertical distance to a
			# low edge; this does not inflate every triangle into a tall wall.
			var required: float = sqrt(maxf(0.0, RADIUS * RADIUS - difference.y * difference.y))
			position += normal * maxf(0.0, required - horizontal.length() + SKIN)
			var inward: float = output_velocity.dot(normal)
			if inward < 0.0:
				output_velocity -= normal * inward * (1.0 + BOUNCE)
			adjusted = true
			collided = true
		if not adjusted:
			break
	# A wall correction must also retain support at a nearby platform edge.
	if not is_finite(surface_height(position)):
		position = from
		output_velocity *= -BOUNCE
		collided = true
	else:
		position.y = surface_height(position) + RADIUS
	return {"position": position, "velocity": output_velocity, "collided": collided}


func safe_ground_point(point: Vector3, clearance: float = RADIUS) -> Vector3:
	var origin: Vector3 = ground_point(point, clearance)
	if _roll_clear(origin):
		return origin
	# A flight can contact a roof or an overhang. Its ground projection must
	# be checked separately instead of spawning the sphere inside a prop.
	for ring: int in range(1, 17):
		for direction: int in range(16):
			var angle: float = float(direction) * TAU / 16.0
			var candidate: Vector3 = origin + Vector3(cos(angle), 0.0, sin(angle)) * float(ring) * RADIUS * 0.5
			if absf(candidate.x) > bounds.x or absf(candidate.z) > bounds.y or not is_finite(surface_height(candidate)):
				continue
			candidate = ground_point(candidate, clearance)
			if _roll_clear(candidate):
				return candidate
	return ground_point(Vector3.ZERO, clearance)


func _roll_clear(point: Vector3) -> bool:
	if not is_finite(surface_height(point)):
		return false
	for index: int in _roll_cells.get(_cell_key(point), []):
		if _box_distance_squared(point, index) >= RADIUS * RADIUS:
			continue
		var p: PackedVector3Array = triangles[index]
		if point.distance_squared_to(_closest_triangle(point, p[0], p[1], p[2])) < (RADIUS - SKIN) * (RADIUS - SKIN):
			return false
	return true


func resolve_flight_segment(from: Vector3, to: Vector3) -> Dictionary:
	if not from.is_finite() or not to.is_finite():
		return {"position": ground_point(Vector3.ZERO), "collided": true, "normal": Vector3.UP}
	# A swept sphere samples at <= one third of its radius. Returning the
	# previous clear sample prevents penetration even across a long frame.
	var samples: int = maxi(1, ceili(from.distance_to(to) / (RADIUS / 3.0)))
	var previous: Vector3 = from
	for step: int in range(1, samples + 1):
		var candidate: Vector3 = from.lerp(to, float(step) / float(samples))
		for index: int in _nearby(candidate):
			if _box_distance_squared(candidate, index) >= RADIUS * RADIUS:
				continue
			var p: PackedVector3Array = triangles[index]
			var closest: Vector3 = _closest_triangle(candidate, p[0], p[1], p[2])
			var difference: Vector3 = candidate - closest
			if difference.length_squared() < (RADIUS - SKIN) * (RADIUS - SKIN):
				# Find the contact within the step, retaining tangential travel and
				# the unused time. A previous sample alone loses motion on ramps.
				var low: float = float(step - 1) / samples
				var high: float = float(step) / samples
				for iteration: int in 12:
					var middle: float = (low + high) * 0.5
					var probe: Vector3 = from.lerp(to, middle)
					var nearest: Vector3 = _closest_triangle(probe, p[0], p[1], p[2])
					if probe.distance_squared_to(nearest) < (RADIUS - SKIN) * (RADIUS - SKIN):
						high = middle
					else:
						low = middle
				var contact_point: Vector3 = from.lerp(to, low)
				var normal: Vector3 = (contact_point - _closest_triangle(contact_point, p[0], p[1], p[2])).normalized()
				if normal.length_squared() < 0.01:
					normal = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
					if normal.dot(from - closest) < 0.0:
						normal = -normal
				return {"position": contact_point + normal * SKIN, "collided": true, "normal": normal, "triangle_index": index, "fraction": low}
		previous = candidate
	return {"position": to, "collided": false, "normal": Vector3.ZERO}


func _nearby(point: Vector3) -> Array:
	return _cells.get(_cell_key(point), [])


static func _cell_key(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))


func _box_distance_squared(point: Vector3, index: int) -> float:
	var closest: Vector3 = point.clamp(_low[index], _high[index])
	return point.distance_squared_to(closest)


static func _height_at(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var denominator: float = (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(denominator) < 0.00000001:
		return NAN
	var first: float = ((b.z - c.z) * (point.x - c.x) + (c.x - b.x) * (point.z - c.z)) / denominator
	var second: float = ((c.z - a.z) * (point.x - c.x) + (a.x - c.x) * (point.z - c.z)) / denominator
	var third: float = 1.0 - first - second
	if first < -0.00001 or second < -0.00001 or third < -0.00001:
		return NAN
	return first * a.y + second * b.y + third * c.y


static func _closest_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	# Ericson's barycentric closest point, including all edge and vertex regions.
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = point - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = point - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = point - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denominator: float = 1.0 / (va + vb + vc)
	return a + ab * (vb * denominator) + ac * (vc * denominator)
