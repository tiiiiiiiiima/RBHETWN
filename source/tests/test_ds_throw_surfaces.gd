extends SceneTree
## Native rest-floor coverage, source obstacles, and stable analytic collision.
const FieldSurface = preload("res://scripts/field_surface.gd")
const RollMotion = preload("res://scripts/roll_motion.gd")
const ThrowMotion = preload("res://scripts/throw_motion.gd")
const Layout = preload("res://scripts/board_layout.gd")
var checks: int = 0
var failures: int = 0

class SurfaceArena extends Node3D:
	var surface: RefCounted
	func resolve_flight_segment(from: Vector3, to: Vector3) -> Dictionary:
		return surface.resolve_flight_segment(from, to)

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _fixture() -> RefCounted:
	var field: RefCounted = FieldSurface.new()
	field.load_profile("fixture", {"center_bounds": [3.0, 3.0], "triangles": [
		[-3,0,-3, 3,0,-3, 3,0,3], [-3,0,-3, 3,0,3, -3,0,3],
		[0,0,-2, 0,1,-2, 0,1,2], [0,0,-2, 0,1,2, 0,0,2],
	]})
	return field

func _run() -> void:
	for group: String in ["toy_throw", "anime_throw", "pyrus_throw", "aquos_throw", "subterra_throw", "haos_throw", "darkus_throw", "ventus_throw"]:
		var surface: RefCounted = FieldSurface.for_group(group)
		_check(surface != null and not surface.triangles.is_empty(), "Native measured profile exists: " + group)
		for slot: int in Layout.POSITIONS.size():
			var point: Vector3 = Layout.POSITIONS[slot]
			var height: float = surface.surface_height(point)
			_check(is_finite(height) and absf(height) < 0.04, "Native floor supports card %d: %s" % [slot, group])
			var grounded: Vector3 = surface.ground_point(point)
			_check(absf(grounded.y - height - 0.44) < 0.00001 and grounded.x == point.x and grounded.z == point.z, "Card grounding retains shared X/Z: " + group)
		for z: float in [-5.0, 5.0]:
			_check(is_finite(surface.surface_height(Vector3(0,0,z))), "Native floor supports launch: " + group)
		var roll: RefCounted = RollMotion.new()
		roll.configure_surface(surface)
		roll.begin(Vector3(0,0,5), Vector3(0,0,-3.3), 3.8, 4.2)
		for frame: int in 126:
			roll.step(1.0 / 30.0, Vector2(0.2,-0.8))
			_check(roll.position.is_finite() and is_finite(surface.surface_height(roll.position)) and absf(roll.position.y - surface.surface_height(roll.position) - 0.44) < 0.0001, "Roll remains on measured floor: " + group)
		var outside: Vector3 = surface.ground_point(Vector3(200,0,200))
		_check(outside.is_finite() and is_finite(surface.surface_height(outside)), "Invalid setup point projects onto native floor: " + group)
	var field: RefCounted = _fixture()
	for rate: int in [30,60,120]:
		var roll: RefCounted = RollMotion.new()
		roll.configure_surface(field)
		roll.begin(Vector3(-1,0,0), Vector3(1,0,0), 5.8, 1.0)
		for frame: int in rate:
			roll.step(1.0 / float(rate))
			_check(roll.position.x <= -0.439 and field._roll_clear(roll.position), "Thin static wall is impenetrable at %d FPS" % rate)
		_check(roll.collision_count > 0 and roll.velocity.x < 0, "Measured wall reflects with energy loss at %d FPS" % rate)
	var initial: RefCounted = RollMotion.new()
	initial.configure_surface(field)
	initial.begin(Vector3(0,10,0), Vector3(2,0,0))
	_check(field._roll_clear(initial.position) and absf(initial.position.x) >= 0.439, "Airborne wall projection starts on a clear native ground point")
	var mock := SurfaceArena.new()
	mock.surface = field
	var start := Vector3(-2,0.50,0)
	var end := Vector3(2,0.50,0)
	var direct: Dictionary = ThrowMotion.sweep_flight(mock,start,end,0.0,1.0,"straight")
	_check(direct.collided and direct.position.x < -0.43, "Full-frame straight sweep hits thin source wall")
	var lob: Dictionary = ThrowMotion.sweep_flight(mock,start,end,0.0,1.0,"lob")
	_check(not lob.collided and lob.position == end, "Full-frame lob passes above low wall instead of using one straight chord")
	mock.free()
	var pyrus: RefCounted = FieldSurface.for_group("pyrus_throw")
	var source_contact: bool = false
	for x: float in [4.5,4.7,4.9,5.1,-4.5,-4.7,-4.9,-5.1]:
		for z: float in [3.4,3.8,4.2,4.6,4.9]:
			if not pyrus._roll_clear(pyrus.ground_point(Vector3(x,0,z))):
				source_contact = true
	_check(source_contact, "Pyrus contains measured source corner obstacles, rather than a substituted Toy field")
	var native_roll: RefCounted = RollMotion.new()
	native_roll.configure_surface(pyrus)
	native_roll.begin(Vector3(4.2,0,2.8),Vector3(5.1,0,4.9),4.0,2.5)
	for frame: int in 150:
		native_roll.step(1.0 / 60.0)
	_check(native_roll.collision_count > 0 and pyrus._roll_clear(native_roll.position), "Actual Pyrus corner prop reflects a travelling sphere without penetration")
	var ventus_board := SurfaceArena.new()
	ventus_board.surface = FieldSurface.for_group("ventus_throw")
	var ventus_lob: Dictionary = ThrowMotion.sweep_flight(ventus_board,Vector3(0,0.5,5),Vector3(0,0.44,-3.3),0.0,1.0,"lob")
	var ventus_direct: Dictionary = ThrowMotion.sweep_flight(ventus_board,Vector3(0,0.5,5),Vector3(0,0.44,-3.3),0.0,1.0,"straight")
	_check(ventus_lob.collided and ventus_lob.position.y > 1.0 and not ventus_direct.collided, "Native Ventus overhang distinguishes a high lob from a direct low shot")
	ventus_board.free()
	print("DS THROW SURFACES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
