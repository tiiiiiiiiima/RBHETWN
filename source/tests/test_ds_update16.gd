extends SceneTree
const Arena = preload("res://scripts/arena.gd")
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
const Catalog = preload("res://scripts/ds_arena_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
var report_path: String = "/workspace/bakugan-pc/builds/qa-0.16/update16.json"
var fields: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path=arg.trim_prefix("--report=")
	call_deferred("_run")

func check(value: bool,description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	arena.setup()
	for theme: String in Catalog.PLAYABLE_FIELDS:
		arena.set_theme(theme)
		var fit: Dictionary = Catalog.manifest().groups[theme.trim_prefix("ds_")+"_throw"].pc_fit
		check(is_equal_approx(float(fit.target_short_floor_span),36.0),"Doubled native floor: "+theme)
		var bounds: Vector2 = arena.traversal_bounds()
		check(bounds.x>=18 and bounds.y>=18,"Source traversal bounds: "+theme)
		var launch: Vector3 = arena.launch_position(0)
		check(launch.z>8 and is_finite(arena.field_surface.surface_height(launch)),"Player starts on the enlarged native floor: "+theme)
		check(arena.launch_position(1).z < -8,"Opponent has the opposite launch lane: "+theme)
		var slot: Vector3 = arena.slot_position(5)
		check(absf(slot.x)>1.5 and absf(slot.z)>1.5,"Wider card spacing: "+theme)
		check(is_finite(arena.field_surface.surface_height(slot)),"Card remains on native ground: "+theme)
		var ball = Sphere.new()
		ball.configure_field(arena)
		ball.launch(launch,slot,0.7,"straight")
		check(ball.speed_limit==26 and ball.velocity.is_finite(),"Throw range scales with field size: "+theme)
		var outside: Vector3 = arena.clamp_aim(Vector3(10000,0,-10000))
		check(outside.x>8 and outside.z < -8 and absf(outside.x)<bounds.x and absf(outside.z)<bounds.y,"Aim reaches the expanded field with finite bounds: "+theme)
		fields[theme] = {"bounds":bounds,"launch":launch,"triangles":arena.native_surface.triangles.size(),"ceiling":arena.native_surface.collision_ceiling}
		for q: int in 4:
			var clock: float = arena.native_surface.clock
			arena.rotate_view(1)
			check(arena.camera.position.is_finite() and arena.native_surface.clock==clock,"Changing the camera cannot advance physics: "+theme)
		for frame: int in 60:
			arena.follow_sphere(Vector3(6,1,7),1.0/60.0)
		check(arena._camera_following and arena._camera_focus.z>6.9,"Camera follows the sphere: "+theme)
		arena.zoom_view(-1)
		check(arena.camera_zoom<1,"User can zoom in on a larger field: "+theme)
		arena.reset_match_field()
		check(not arena._camera_following and arena.camera_zoom==1 and arena._camera_focus==Vector3.ZERO,"New match resets camera tracking and zoom: "+theme)
	arena.set_theme("ds_haos")
	var outer_point := Vector3.ZERO
	var outer_found: bool = false
	for triangle: PackedVector3Array in arena.native_surface.triangles:
		var center: Vector3 = (triangle[0]+triangle[1]+triangle[2])/3
		var normal: Vector3 = (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
		if maxf(absf(center.x),absf(center.z))>9 and center.y>-0.4 and center.y<0.4 and absf(normal.y)>0.8:
			outer_point = center+Vector3(0,0.441,0)
			outer_found = true
			break
	check(outer_found,"Native Haos floor beyond the old eight-unit static surface remains supported")
	if outer_found:
		var outer = Sphere.new()
		outer.configure_field(arena)
		outer.launch(outer_point,outer_point,0,"straight")
		outer.velocity = Vector3.ZERO
		outer.step(1.0/30,arena,Vector2.ZERO,false,false)
		check(not outer.lost and outer.grounded,"A sphere on the expanded native floor remains playable")
	arena.set_theme("ds_toy")
	var positions: Array[Vector3] = []
	for fps: int in [30,60,120]:
		arena.reset_match_field()
		var sphere = Sphere.new()
		sphere.configure_field(arena)
		sphere.launch(arena.launch_position(0),arena.slot_position(5),0.7,"straight")
		for frame: int in fps*2:
			sphere.step(1.0/fps,arena,Vector2.ZERO,false,false)
		positions.append(sphere.position)
	check(positions[0].distance_to(positions[2])<0.001 and positions[1].distance_to(positions[2])<0.001,"Expanded field trajectories match at 30/60/120 FPS")
	arena.free()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	game._set_rules_profile("ds")
	game.selected_arena = "ds_toy"
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	game.field_map.prepare_map()
	game.field_map._process(0.11)
	check(game.field_map.visible and not game.field_map._polygons.is_empty(),"Minimap uses native floor polygons in the real game")
	var center: Vector3 = game.arena.slot_position(5)
	check(game.arena.gates[5].position.distance_to(center)<0.001,"Visible gate matches the expanded card contact position")
	check(game._gate_on_segment(center+Vector3(0,0.44,-2),center+Vector3(0,0.44,2))==5,"Sphere contacts the visible expanded card grid")
	check(game.field_map.map_to_world(game.field_map.world_to_map(center)).distance_to(Vector3(center.x,0,center.z))<0.001,"Minimap coordinates round-trip to the actual world")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.field_map.world_to_map(Vector3(12,0,-11))
	game.field_map._gui_input(event)
	check(game.aim_point.distance_to(Vector3(12,0,-11))<0.001,"Clicking the map aims beyond the old eight-unit limit")
	game.paused = true
	event.position = game.field_map.world_to_map(Vector3(-12,0,11))
	game.field_map._gui_input(event)
	check(game.aim_point.x>11,"Paused minimap cannot change the target")
	game.paused = false
	game._set_rules_profile("wii")
	game.selected_arena = "stadium"
	game.start_match()
	game.field_map._process(0.11)
	check(not game.field_map.visible and game.arena.slot_position(5).is_equal_approx(Arena.SLOT_POSITIONS[5]),"Wii preserves its card grid and hides DS navigation")
	game.queue_free()
	await process_frame
	var out: FileAccess = FileAccess.open(report_path,FileAccess.WRITE)
	out.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"fields":fields,"positions_30_60_120":positions},"\t")+"\n")
	print("DS UPDATE 0.16: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
