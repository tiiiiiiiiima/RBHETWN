extends SceneTree
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
const Surface = preload("res://scripts/field_surface.gd")
const Gesture = preload("res://scripts/ds_throw_gesture.gd")
const Layout = preload("res://scripts/board_layout.gd")
const Arena = preload("res://scripts/arena.gd")
var checks: int = 0
var failures: Array[String] = []
class Fixture extends Node3D:
	var surface: RefCounted
	func resolve_flight_segment(a: Vector3,b: Vector3) -> Dictionary:
		return surface.resolve_flight_segment(a,b)
	func sphere_support(point: Vector3,_max_height: float) -> Dictionary:
		return {"height":0.0 if absf(point.x)<3 and absf(point.z)<3 else -INF,"normal":Vector3.UP}
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
func _run() -> void:
	var gesture = Gesture.new()
	gesture.begin(Vector2(100,200),0.0)
	check(gesture.finish(Vector2(100,80),0.2).valid,"Upward DS launch gesture")
	gesture.begin(Vector2(100,200),0.0)
	check(not gesture.finish(Vector2(100,190),0.01).valid,"Click/jitter cannot throw")
	gesture.begin(Vector2(100,200),0.0)
	check(not gesture.finish(Vector2(100,80),2.0).valid,"Slow drag cannot throw")
	gesture.begin(Vector2(100,200),0.0)
	check(gesture.finish(Vector2(130,200),0.1,true).valid,"Separate horizontal stroke steers")
	check(not gesture.finish(Vector2(130,200),0.2,true).valid,"A stroke produces only one impulse")
	check(is_inf(Layout.gate_contact_fraction(Vector3(0,2,-2),Vector3(0,2,2),Vector3.ZERO)),"Aerial overflight cannot stand")
	check(is_finite(Layout.gate_contact_fraction(Vector3(0,0.44,-2),Vector3(0,0.44,2),Vector3.ZERO)),"Ground segment reaches visible rectangle")
	var outside: float=Layout.card_size("ds").x*0.5+0.15
	check(is_inf(Layout.gate_contact_fraction(Vector3(outside,0.44,-2),Vector3(outside,0.44,2),Vector3.ZERO)),"Passing beside the enlarged card is a miss")
	var fixture := Fixture.new()
	root.add_child(fixture)
	fixture.surface = Surface.new()
	fixture.surface.load_profile("fixture",{"center_bounds":[3,3],"triangles":[[-3,0,-3,3,0,-3,3,0,3],[-3,0,-3,3,0,3,-3,0,3],[0,0,-3,0,3,-3,0,3,3],[0,0,-3,0,3,3,0,0,3]]})
	var final_positions: Array[Vector3] = []
	for fps: int in [30,60,120]:
		var ball = Sphere.new()
		ball.launch(Vector3(-2,0.5,0),Vector3(2,0.44,0),1,"straight")
		for frame: int in fps*2:
			ball.step(1.0/fps,fixture,Vector2.ZERO,false,false)
			check(ball.position.is_finite() and ball.position.x < -0.43,"Thin wall stops high-speed sphere at %d FPS" % fps)
		check(ball.collision_count>0,"Sphere retains physical impact")
		final_positions.append(ball.position)
	check(final_positions[0].distance_to(final_positions[2])<0.002 and final_positions[1].distance_to(final_positions[2])<0.002,"30/60/120 FPS follow same fixed-step path")
	var falling = Sphere.new()
	falling.launch(Vector3(3.5,0.5,0),Vector3(8,0.44,0),1,"straight")
	for frame: int in 360:
		falling.step(1.0/120,fixture,Vector2.ZERO,false,false)
	check(falling.lost and falling.position.y < -5,"Unsupported edge falls, with no invisible boundary wall")
	fixture.queue_free()
	var counts: Dictionary = {}
	for theme: String in ["ds_toy","ds_anime","ds_pyrus","ds_aquos","ds_subterra","ds_haos","ds_darkus","ds_ventus"]:
		var arena = Arena.new()
		root.add_child(arena)
		arena.set_theme(theme)
		check(arena.native_surface != null and not arena.native_surface.triangles.is_empty(),"Native posed triangles: "+theme)
		var initial: Array = arena.native_surface.triangles.duplicate(true)
		arena.advance_field(1.25)
		check(arena.native_surface.clock>=1.25 and arena.native_surface.refresh_count>=2,"Manual field clock: "+theme)
		counts[theme]={"triangles":arena.native_surface.triangles.size(),"joint_players":arena.native_surface._players.size(),"uv_bindings":arena.native_surface.material_motion.bindings.size(),"geometry_changed":arena.native_surface.triangles!=initial}
		if theme in ["ds_pyrus","ds_ventus"]:
			check(counts[theme].geometry_changed,"Source joint geometry moves: "+theme)
		var native_clock: float = arena.native_surface.clock
		var preview = Sphere.new()
		preview.launch(arena.launch_position(0),Vector3.ZERO,0.7)
		preview.step(0.2,arena,Vector2.ZERO,false,false)
		check(arena.native_surface.clock==native_clock,"Preview cannot advance live mechanisms: "+theme)
		arena.set_native_physics(false)
		check(arena.native_surface==null,"Anime/Wii can use frozen field: "+theme)
		arena.queue_free()
		await process_frame
	var version: String = str(ProjectSettings.get_setting("application/config/version")).trim_suffix(".0")
	var file: FileAccess = FileAccess.open("/workspace/bakugan-pc/builds/qa-"+version+"/physics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"fields":counts},"\t"))
	print("DS PHYSICS 0.13: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
