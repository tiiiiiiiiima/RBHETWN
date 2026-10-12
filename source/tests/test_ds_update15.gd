extends SceneTree
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
const Objects = preload("res://scripts/ds_field_objects.gd")
const Arena = preload("res://scripts/arena.gd")
var checks: int = 0
var failures: Array[String] = []
var report_path: String = "/workspace/bakugan-pc/builds/qa-0.15/update.json"

class Fixture extends Node3D:
	var objects: Node3D
	func field_response(a: Vector3,b: Vector3) -> Array[Dictionary]:
		return objects.response(a,b)
	func resolve_flight_segment(_a: Vector3,b: Vector3) -> Dictionary:
		return {"position":b,"collided":false,"normal":Vector3.UP}
	func sphere_support(_point: Vector3,_height: float) -> Dictionary:
		return {"height":0.0,"normal":Vector3.UP}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
	call_deferred("_run")

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func fixture(kind: String,tilt: float = 0) -> Fixture:
	var arena := Fixture.new()
	root.add_child(arena)
	arena.objects = Objects.new()
	arena.add_child(arena.objects)
	var pad := Node3D.new()
	arena.objects.add_child(pad)
	pad.rotation.z = tilt
	arena.objects.items.append({"id":0,"kind":kind,"node":pad,"extent":Vector3(0.3,0.02,0.3),"collected":false})
	return arena

func _run() -> void:
	var floor := fixture("speed_pad")
	check(floor.field_response(Vector3(-2,0.44,0),Vector3(2,0.44,0)).size()==1,"Swept queries detect a thin source pad between endpoints")
	check(floor.field_response(Vector3(-2,3,0),Vector3(2,3,0)).is_empty(),"High airborne crossings do not trigger floor pads")
	check(floor.field_response(Vector3(0,-2,0),Vector3(0,-1,0)).is_empty(),"Pads cannot boost a sphere below the field")
	floor.queue_free()
	await process_frame
	var positions: Array[Vector3] = []
	for fps: int in [30,60,120]:
		var arena := fixture("speed_pad")
		var ball = Sphere.new()
		ball.launch(Vector3(0,0.441,1.2),Vector3.ZERO,0,"straight")
		ball.velocity = Vector3(0,0,-2)
		var activations: int = 0
		for frame: int in fps:
			ball.step(1.0/fps,arena)
			activations += ball.field_events.size()
		positions.append(ball.position)
		check(activations==1,"Pad activates once while crossing, at %d FPS" % fps)
		check(ball.position.z < -1,"Source arrow boosts the actual rolling sphere")
		arena.queue_free()
		await process_frame
	check(positions[0].distance_to(positions[2])<0.0001 and positions[1].distance_to(positions[2])<0.0001,"Field impulses match at 30/60/120 FPS")
	var preview_arena := fixture("speed_pad")
	var forecast = Sphere.new()
	forecast.launch(Vector3(0,0.441,0),Vector3.ZERO,0,"straight")
	forecast.velocity = Vector3(0,0,-1)
	forecast.step(1.0/120.0,preview_arena,Vector2.ZERO,false,false)
	check(forecast.field_events.size()==1 and preview_arena.objects.items[0].node.visible,"A frozen forecast includes a pad without mutating its live state")
	var live = Sphere.new()
	live.launch(Vector3(0,0.441,0),Vector3.ZERO,0,"straight")
	live.velocity = Vector3(0,0,-1)
	live.step(1.0/120.0,preview_arena)
	check(live.field_events.size()==1,"A preview does not consume the next real activation")
	preview_arena.queue_free()
	await process_frame
	var ramp := fixture("trampoline",deg_to_rad(15))
	var jumper = Sphere.new()
	jumper.launch(Vector3(0,0.441,0),Vector3.ZERO,0,"straight")
	jumper.velocity = Vector3.ZERO
	jumper.step(1.0/120.0,ramp)
	check(jumper.velocity.y>6 and jumper.velocity.x < -1 and not jumper.grounded,"Tilted source trampoline launches along its normal")
	check(jumper.field_events.size()==1 and not jumper.jump(),"A trampoline lift cannot receive a second grounded jump")
	jumper.step(1.0/120.0,ramp)
	check(jumper.field_events.is_empty(),"Continuous contact cannot retrigger the trampoline")
	ramp.queue_free()
	await process_frame
	var manifest: Dictionary = Objects.manifest()
	check(manifest.sets.size()==27 and manifest.objects.size()==6,"All decoded source sets and six native object models are packaged")
	var arena = Arena.new()
	root.add_child(arena)
	arena.setup()
	var native_counts: Dictionary = {}
	for theme: String in ["ds_toy","ds_pyrus","ds_aquos","ds_subterra","ds_haos","ds_darkus","ds_ventus","ds_anime"]:
		arena.set_theme(theme)
		for layout: int in Objects.layouts(theme).size():
			arena.set_field_layout(layout)
			var objects: Node3D = arena.field_objects
			var expected: int = 0
			for r: Dictionary in manifest.sets[objects.layout_id].records:
				if manifest.objects.has(str(r.kind)):
					expected += 1
			check(objects.items.size()==expected,"Native object counts match %s" % objects.layout_id)
			var records: Array = manifest.sets[objects.layout_id].records
			for item: Dictionary in objects.items:
				var source: Array = records[int(item.id)].position
				var point := Vector3(float(source[0]),float(source[1]),float(source[2]))
				check(item.node.global_position.distance_to(objects.to_global(point))<0.00001,"Source position shares field scale/offset")
			native_counts[objects.layout_id] = objects.items.size()
		arena.set_field_layout(0)
	arena.set_theme("ds_toy")
	arena.advance_field(1.0/60.0)
	var scroll_found: bool = false
	for item: Dictionary in arena.field_objects.material_motion.bindings:
		if item.track.name=="Material__26":
			check(absf(item.material.uv1_offset.y)<0.1 and absf(item.material.uv1_offset.y)>0.01,"Native dash texture uses fx16 units, not 128-fold scrolling")
			scroll_found = true
			break
	check(scroll_found,"Original dash SRT binds to its imported material")
	arena.queue_free()
	await process_frame
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	game._set_rules_profile("ds")
	game.selected_arena = "ds_toy"
	game.selected_field_layout = 1
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	check(game.arena.field_objects.layout_id=="SetData_00_01","Saved layout is applied to the real match")
	check(game.throw_mode_button.disabled and game.s_power==[0,0],"DS starts without free unlimited powered shots")
	game._toggle_throw_mode()
	check(not game.powered_throw,"P cannot bypass an empty S meter")
	game.s_power[0] = 99
	game._toggle_throw_mode()
	check(not game.powered_throw,"99 S is insufficient for a powered throw")
	game.s_power[0] = 100
	game._toggle_throw_mode()
	check(game.powered_throw,"Full S meter enables the next throw")
	game.charge = 0.7
	game._launch_ball(0,0,Vector3(4,0,4))
	check(game.flight_powered and game.s_power[0]==0 and not game.powered_throw,"Launching consumes 100 S once and clears the next-shot toggle")
	var source_pickups: Array = game.pickups.duplicate()
	check(not source_pickups.is_empty() and source_pickups[0].native,"DS uses source pickups instead of a target-generated crystal trail")
	var g: Dictionary = {}
	var s: Dictionary = {}
	for item: Dictionary in source_pickups:
		if item.kind=="g_power" and g.is_empty(): g=item
		if item.kind=="s_power" and s.is_empty(): s=item
	check(not g.is_empty() and not s.is_empty(),"Native layout contains separate G and S items")
	game.pickups.clear()
	game.pickups.append(g)
	game.pickups.append(s)
	game.paused = true
	game._collect_pickups(s.position,s.position)
	check(game.s_power[0]==0 and not s.collected,"Pause cannot collect S items")
	game.paused = false
	game._collect_pickups(s.position+Vector3(0,4,0),s.position+Vector3(1,4,0))
	check(game.s_power[0]==0,"Flying high over a source coin does not collect it")
	game._collect_pickups(g.position,g.position)
	check(game.roll_bonus==20 and game.s_power[0]==0 and not g.node.visible,"G item supplies this throw's G bonus")
	game._collect_pickups(s.position,s.position)
	check(game.s_power[0]==25 and game.roll_bonus==20 and not s.node.visible,"S item fills the meter without changing G")
	game._collect_pickups(s.position,s.position)
	check(game.s_power[0]==25,"Collected native item cannot pay twice")
	game._clear_pickups()
	game._spawn_pickups()
	var respawned: bool = false
	for item: Dictionary in game.pickups:
		if item.id==g.id or item.id==s.id: respawned=true
	check(not respawned and is_instance_valid(g.node),"Ending a throw preserves the shared field item state")
	game.flight_owner = 1
	var enemy_coin: Dictionary = game.pickups.filter(func(item: Dictionary) -> bool: return item.kind=="s_power")[0]
	game.pickups.clear()
	game.pickups.append(enemy_coin)
	game._collect_pickups(enemy_coin.position,enemy_coin.position)
	check(game.s_power==[25,25],"Opponent uses its own S meter")
	game._save_profile("user://layout15.cfg")
	game.selected_field_layout = 0
	game._load_profile("user://layout15.cfg")
	check(game.selected_field_layout==1,"Native layout choice survives profile save/load")
	game.arena.advance_field(0.5)
	var clock: float = game.arena.native_surface.clock
	var offset: Vector3 = game.arena.field_objects.material_motion.bindings[0].material.uv1_offset
	game._toggle_pause()
	game._process(0.5)
	check(game.arena.native_surface.clock==clock and game.arena.field_objects.material_motion.bindings[0].material.uv1_offset==offset,"Pause freezes pad animations together with native field geometry")
	game._toggle_pause()
	game.start_match()
	check(game.s_power==[0,0] and g.node.visible and s.node.visible,"New match restores native items and resets both meters")
	game._show_menu()
	game._open_help()
	await process_frame
	await process_frame
	check(game.help_body.get_parent()==game.help_scroll and game.help_scroll.get_v_scroll_bar().max_value>game.help_scroll.size.y,"Long DS rules stay readable through the help scrollbar")
	game.help_scroll.scroll_vertical = 500
	game._close_preparation()
	game._open_help()
	check(game.help_scroll.scroll_vertical==0,"Reopening help returns to its beginning")
	game._close_preparation()
	game._set_rules_profile("wii")
	game.start_match()
	check(not is_instance_valid(game.arena.field_objects),"New DS mechanisms are absent from Wii physics")
	game.queue_free()
	await process_frame
	var report: Dictionary = {"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"positions_30_60_120":positions,"native_layout_counts":native_counts}
	var out: FileAccess = FileAccess.open(report_path,FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t")+"\n")
	print("DS UPDATE 0.15: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
