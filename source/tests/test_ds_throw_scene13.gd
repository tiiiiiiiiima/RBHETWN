extends SceneTree
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
func button(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	return event
func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._set_rules_profile("ds")
	game.selected_arena = "ds_toy"
	game.start_match()
	check(game.ds_ready_ball != null and game.phase=="aim","Grab-ready closed Bakugan is visible")
	var point: Vector2 = game.arena.camera.unproject_position(game.ds_ready_ball.global_position)
	game._unhandled_input(button(point,true))
	check(game.ds_gesture.active,"Mouse press grabs the displayed sphere")
	game._input(button(point+Vector2(0,-5),false))
	check(game.phase=="aim" and not game.ds_gesture.active and game.flight_ball==null,"Jitter release does not throw or consume unit")
	game._unhandled_input(button(point,true))
	game.ds_gesture.began = Time.get_ticks_msec()/1000.0-0.2
	game._input(button(point+Vector2(0,-125),false))
	check(game.phase=="flying" and game.flight_ball!=null and game.ds_ready_ball==null,"Upward mouse stroke releases a physical sphere")
	check(game.flight_charge>0.5 and game.ds_sphere.velocity.is_finite(),"Gesture speed sets finite throw velocity")
	var original: Vector3 = game.ds_sphere.velocity
	game._unhandled_input(button(Vector2(700,300),true))
	game.ds_gesture.began = Time.get_ticks_msec()/1000.0-0.1
	game._input(button(Vector2(750,300),false))
	check(game.ds_sphere.velocity!=original,"A separate short stroke steers a live throw")
	original=game.ds_sphere.velocity
	game.flight_owner=1
	game._unhandled_input(button(Vector2(700,300),true))
	game._unhandled_input(button(Vector2(750,300),false))
	check(game.ds_sphere.velocity==original and not game.ds_gesture.active,"Player cannot steer the opponent sphere")
	game.flight_owner=0
	var clock: float = game.arena.native_surface.clock
	var elapsed: float = game.ds_sphere.elapsed
	game._toggle_pause()
	game._process(0.5)
	check(game.arena.native_surface.clock==clock and game.ds_sphere.elapsed==elapsed,"Pause freezes geometry and sphere together")
	game._toggle_pause()
	game.start_match()
	check(game.phase=="aim" and game.flight_ball==null and not game.ds_gesture.active,"Automatic opening on restart clears the moving sphere and captured input")
	game.queue_free()
	await process_frame
	print("DS THROW SCENE 0.13: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
