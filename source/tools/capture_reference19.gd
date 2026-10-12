extends SceneTree
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
var game: Node3D
var report: Dictionary = {"captures":[],"failures":[]}
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://builds/qa-0.19/visual/"+label+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	report.captures.append(path)
	print("CAPTURE ",label)
func complete_sequence() -> void:
	for step: int in 12:
		if game.phase!="ds_scene": return
		game._step_ds_sequence(2.0)
func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	root.push_input(event)
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_process(false); game.muted=true
	game._load_profile("user://qa19-new.cfg")
	game._set_rules_profile("ds"); game.selected_arena="ds_toy"; game.start_match()
	if OS.get_cmdline_user_args().has("--extra"):
		await additional()
		return
	game._update_aim(0.0); game.field_map.prepare_map(); game.field_map._process(0.11)
	await capture("starter-chase-camera")
	var paths: Array[Vector3] = []
	for fps: int in [30,60,120]:
		game.arena.reset_match_field()
		var motion = Sphere.new()
		motion.configure_field(game.arena)
		motion.configure_unit(game.rules.teams[0][1])
		motion.launch(game.arena.launch_position(0),game.arena.slot_position(19),0.7,"straight")
		for step: int in fps*2: motion.step(1.0/fps,game.arena)
		paths.append(motion.position)
	report.native_field_repeat = {"positions":str(paths),"maximum_delta":maxf(paths[0].distance_to(paths[1]),paths[0].distance_to(paths[2]))}
	if float(report.native_field_repeat.maximum_delta)>0.01: report.failures.append("Native-field throw changes with rendering FPS")
	game._launch_ball(0,1,game.arena.slot_position(19))
	for frame: int in 30: game._update_ds_sphere(1.0/60)
	await capture("starter-rolling-camera")
	game._show_menu(); game._open_settings(); await capture("settings")
	game._close_preparation(); game.preferences.ds_auto_gates=false; game.start_match()
	game.field_map._process(0.11); await capture("manual-grid")
	game.preferences.ds_auto_gates=true
	game._start_practice("scratch")
	game._step_ds_sequence(1.0); await capture("player-entry")
	game._step_ds_sequence(1.0); game._step_ds_sequence(1.0); await capture("gate-reveal")
	complete_sequence(); await capture("scratch-preparation")
	var blue: int = game._ability_index(0,"p0_ds_604")
	for i: int in game.rules.abilities[0].size():
		if int(game.rules.abilities[0][i].source_card_id)==604: blue=i
	game._choose_card(blue); game._start_battle_game(); complete_sequence()
	var point: Vector2 = game.scratch.get_global_transform_with_canvas()*game.scratch.center()
	mouse(point,true)
	for index: int in 60:
		var event := InputEventMouseMotion.new()
		event.position=point+Vector2(-30 if index%2==0 else 30,0)
		event.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(event)
		game._update_battle(0.04)
		await process_frame
	mouse(Vector2(1,1),false)
	report.mouse_scratch_score=game.scratch.score
	if game.scratch.score<=0: report.failures.append("Real GUI rubbing failed")
	await capture("scratch-rubbing")
	game._play_ability(0,blue); await capture("ability-interruption")
	complete_sequence(); game.ds_ai_ability=""; game.ai_target_points=0; game.scratch.score=600
	game._update_battle(10.0); await capture("decisive-attack")
	await create_timer(2.9).timeout; await capture("scratch-result")
	game._show_menu(); game._set_rules_profile("ds"); game.selected_arena="ds_pyrus"; game.match_mode="quick"; game.start_match()
	game._update_aim(0); game.field_map._process(0.11); await capture("pyrus-chase")
	await additional()

func additional() -> void:
	if FileAccess.file_exists("res://builds/qa-0.19/visual/report.json"):
		var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://builds/qa-0.19/visual/report.json"))
		if saved is Dictionary: report=saved
	game._show_menu(); game._open_training(); await capture("six-games-training")
	game._close_preparation()
	game._start_practice("scratch"); complete_sequence()
	for index: int in game.rules.abilities[0].size(): game._choose_card(index)
	await capture("three-card-queue")
	for mode: String in ["spin","timing","pop","trace","bound"]:
		game._start_practice(mode); complete_sequence(); game._start_battle_game(); complete_sequence()
		game.ds_ai_ability=""; game.ai_target_points=0
		var center: Vector2=game.scratch.get_global_transform_with_canvas()*game.scratch.center()
		if mode=="spin":
			mouse(center+Vector2(40,0),true)
			for index: int in 120:
				var motion := InputEventMouseMotion.new(); motion.position=center+Vector2(40,0).rotated(float(index+1)*TAU/120)
				motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion); game._update_battle(1.0/60)
		elif mode=="timing":
			game._update_battle(1.0); mouse(center,true); mouse(center,false)
		elif mode=="pop": mouse(center,true); mouse(center,false)
		else:
			mouse(center,true)
			for index: int in 95:
				var motion := InputEventMouseMotion.new(); motion.position=game.scratch.get_global_transform_with_canvas()*game.scratch.center()
				motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion); game._update_battle(1.0/60)
		mouse(Vector2(1,1),false)
		report[mode+"_gui_score"]=game.scratch.score
		if game.scratch.score<=0: report.failures.append("Real GUI input failed: "+mode)
		await capture(mode+"-input")
	game._show_menu(); game._open_source_cards()
	game.source_card_browser._playable_toggle.button_pressed=true
	game.source_card_browser._playable_toggle.toggled.emit(true)
	await capture("playable-card-filter")
	FileAccess.open("res://builds/qa-0.19/visual/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	game.queue_free(); await process_frame
	quit(0 if report.failures.is_empty() else 1)
