extends SceneTree
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
const Live = preload("res://scripts/ds_live_surface.gd")
const MaterialMotion = preload("res://scripts/ds_material_motion.gd")
var checks: int = 0
var failures: Array[String] = []
var report_path: String = "/workspace/bakugan-pc/builds/qa-0.14/update.json"

class Fixture extends Node3D:
	var surface: RefCounted
	func advance_field(delta: float) -> void:
		surface.advance(delta)
	func resolve_flight_segment(a: Vector3,b: Vector3) -> Dictionary:
		return surface.resolve_flight_segment(a,b)
	func sphere_support(point: Vector3,height: float) -> Dictionary:
		return surface.support(point,height)
	func separate_sphere(point: Vector3) -> Dictionary:
		return surface.separate_ball(point)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
	call_deferred("_run")

func check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func fixture(motion: Vector3) -> Fixture:
	var arena := Fixture.new()
	root.add_child(arena)
	var stage := Node3D.new()
	arena.add_child(stage)
	var component := Node3D.new()
	stage.add_child(component)
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = PlaneMesh.new()
	plate.mesh.size = Vector2(20,20)
	component.add_child(plate)
	var animation := Animation.new()
	animation.length = 10.0
	var track: int = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track,NodePath("Plate"))
	animation.position_track_insert_key(track,0,Vector3.ZERO)
	animation.position_track_insert_key(track,10,motion*10.0)
	var library := AnimationLibrary.new()
	library.add_animation("move",animation)
	var player := AnimationPlayer.new()
	player.add_animation_library("",library)
	component.add_child(player)
	arena.surface = Live.new()
	arena.surface.bind_stage(stage,"fixture")
	return arena

func key(code: Key,pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event

func _run() -> void:
	var sampler = MaterialMotion.new()
	check(sampler._sample_colour({"values":[0,31],"step":2,"interpolation_end":2},1,true)==15,"Native alpha odd frames round down")
	check(sampler._sample_colour({"values":[0x7fff,0],"step":2,"interpolation_end":2},1)==0x3def,"RGB555 interpolation stays within each color channel")
	check(sampler._sample_colour({"values":[0,20,31],"step":4,"interpolation_end":8},3,true)==15,"Four-frame alpha interpolation")
	check(sampler._sample_colour({"values":[0,20,31,9,7],"step":4,"interpolation_end":8},9,true)==9,"Uncompressed tail frames are not divided by stride")
	check(is_equal_approx(sampler._sample({"values":[0,2,4,7,8],"step":4,"interpolation_end":8},9),7.0),"SRT native tail uses every remaining frame")
	var resting = Sphere.new()
	resting.grounded = true
	resting.velocity = Vector3.ZERO
	check(resting.jump() and resting.velocity.y>4,"Microphone action becomes a surface jump")
	check(not resting.jump(),"A second airborne press cannot fly")
	resting.grounded = true
	check(not resting.jump(),"Jump cooldown survives an immediate contact")
	resting.elapsed = 0.6
	check(resting.jump(),"Jump becomes available after landing and cooldown")
	var impact = Sphere.new()
	impact.velocity = Vector3.ZERO
	impact._impact(Vector3.RIGHT,Vector3(2,0,0))
	check(impact.velocity.x>2,"Moving wall transfers normal velocity to a stationary sphere")
	var end_positions: Array[Vector3] = []
	for fps: int in [30,60,120]:
		var arena := fixture(Vector3(2,0,0))
		var ball = Sphere.new()
		ball.launch(Vector3(0,0.441,0),Vector3.ZERO,0,"straight")
		ball.velocity = Vector3.ZERO
		ball.grounded = true
		for frame: int in fps*2:
			ball.step(1.0/fps,arena)
		end_positions.append(ball.position)
		check(ball.position.x>1.0 and ball.grounded,"Actual animated floor carries sphere at %d FPS" % fps)
		var support: Dictionary = arena.surface.support(ball.position,1.0)
		check(support.velocity.distance_to(Vector3(2,0,0))<0.001,"Skinned contact speed comes from successive native poses")
		arena.queue_free()
		await process_frame
	check(end_positions[0].distance_to(end_positions[2])<0.002 and end_positions[1].distance_to(end_positions[2])<0.002,"Moving-surface trajectory is independent of 30/60/120 FPS")
	var lift := fixture(Vector3(0,1,0))
	var lifted = Sphere.new()
	lifted.launch(Vector3(0,0.441,0),Vector3.ZERO,0,"straight")
	lifted.velocity = Vector3.ZERO
	lifted.grounded = true
	for tick: int in 120:
		lifted.step(1.0/120.0,lift)
	check(absf(lifted.position.y-1.441)<0.04 and lifted.grounded,"Moving lift supports the sphere without falling through")
	check(lifted.jump() and lifted.velocity.y>5,"Jump inherits vertical platform speed")
	lift.surface.reset_clock()
	check(lift.surface.clock==0.0 and lift.surface.support(Vector3.ZERO,1.0).velocity==Vector3.ZERO,"Reset returns platform to its first pose without stale speed")
	lift.queue_free()
	await process_frame
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	game._set_rules_profile("ds")
	game.selected_arena = "ds_darkus"
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	check(game.phase=="aim","DS input fixture begins in aim")
	var original_aim: Vector3 = game.aim_point
	var original_camera: Vector3 = game.arena.camera.position
	game.ds_gesture.begin(Vector2(500,500),0.0)
	game._unhandled_input(key(KEY_E))
	check(game.arena.view_quadrant==1 and game.arena.camera.position!=original_camera,"E rotates battlefield camera")
	check(game.aim_point==original_aim and not game.ds_gesture.active,"Camera change preserves target and cancels captured stroke")
	var right: Vector3 = game.arena.camera.global_transform.basis.x
	var steering: Vector2 = game.arena.control_direction(Vector2.RIGHT)
	check(Vector3(steering.x,0,steering.y).normalized().dot(Vector3(right.x,0,right.z).normalized())>0.999,"Steering remains relative to rotated camera")
	game._unhandled_input(key(KEY_Q))
	check(game.arena.view_quadrant==0 and game.arena.camera.position.is_equal_approx(original_camera),"Q returns to original view")
	game._handle_action(true)
	game.charge = 0.8
	game.ds_gesture.begin(Vector2(500,500),0.0)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._handle_action(false)
	check(not game.charging and game.charge==0.0 and not game.ds_gesture.active and game.phase=="aim" and game.flight_ball==null,"Window focus loss cancels input without releasing a throw")
	var motion: RefCounted = game.arena.native_surface.material_motion
	check(not motion.colour_bindings.is_empty(),"Original Darkus MAT0 tracks bind to runtime materials")
	var lightning: Dictionary = {}
	for item: Dictionary in motion.colour_bindings:
		if item.track.name=="ikazuchi1":
			lightning = item
			break
	check(not lightning.is_empty(),"Native lightning material has a source alpha track")
	if not lightning.is_empty():
		var values: Array = lightning.track.channels[4].values
		var brightest: int = values.find(values.max())
		motion.advance(0.0)
		check(lightning.material.albedo_color.a==0.0,"Lightning is absent at its native initial frame")
		motion.advance(float(brightest)/60.0+0.00001)
		check(lightning.material.albedo_color.a>0.5,"Lightning appears at the native bright frame")
		var bright_alpha: float = lightning.material.albedo_color.a
		motion.advance(float(brightest+int(lightning.frames))/60.0+0.00001)
		check(is_equal_approx(lightning.material.albedo_color.a,bright_alpha),"Native flash loop returns to the same frame")
	game.arena.advance_field(0.5)
	var before_clock: float = game.arena.native_surface.clock
	var colors: Array[Color] = []
	for item: Dictionary in motion.colour_bindings:
		colors.append(item.material.albedo_color)
	game._toggle_pause()
	game._process(0.5)
	game._unhandled_input(key(KEY_E))
	check(game.arena.native_surface.clock==before_clock and game.arena.view_quadrant==0,"Pause freezes source effects and camera control")
	for index: int in colors.size():
		check(motion.colour_bindings[index].material.albedo_color==colors[index],"Pause preserves source material state")
	game._toggle_pause()
	game.throw_style = "straight"
	game.charge = 0.7
	game._launch_ball(0,0,game.arena.ground_point(Vector3(4,0,4)))
	game.ds_sphere.grounded = true
	game.ds_sphere.velocity = Vector3.ZERO
	game.phase = "rolling"
	game._handle_action(true)
	check(game.ds_sphere.velocity.y>4 and not game.ds_sphere.grounded,"Space jumps the live player sphere instead of ending the throw")
	var jumped_velocity: Vector3 = game.ds_sphere.velocity
	game._handle_action(true)
	check(game.ds_sphere.velocity==jumped_velocity,"Repeated Space does not create airborne impulses")
	game.flight_owner = 1
	game.ds_sphere.grounded = true
	game.ds_sphere.elapsed = 1
	game._handle_action(true)
	check(game.ds_sphere.velocity==jumped_velocity,"Player cannot jump the opponent sphere")
	game.arena.rotate_view(1)
	game.start_match()
	check(game.arena.native_surface.clock==0.0 and game.arena.view_quadrant==0 and game.flight_ball==null,"Restart resets arena phase, camera, and sphere together")
	game._set_rules_profile("wii")
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	game._unhandled_input(key(KEY_E))
	check(game.arena.view_quadrant==0,"DS camera bindings do not alter Wii controls")
	game.queue_free()
	await process_frame
	var report: Dictionary = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"floor_positions_30_60_120":end_positions}
	var out: FileAccess = FileAccess.open(report_path,FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	print("DS UPDATE 0.14: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
