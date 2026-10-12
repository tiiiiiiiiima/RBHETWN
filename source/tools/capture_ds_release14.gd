extends SceneTree
var output: String = "/workspace/bakugan-pc/builds/qa-0.14/visual"
var captures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func capture(label: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(label+".png")
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
	print("CAPTURE: ",label)
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,800)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	game._set_rules_profile("ds")
	for theme: String in ["ds_toy","ds_anime","ds_pyrus","ds_aquos","ds_subterra","ds_haos","ds_darkus","ds_ventus"]:
		game.selected_arena = theme
		game.start_match()
		game._place_player_gate(5)
		game._skip_gate()
		assert(game.phase=="aim" and game.ds_ready_ball!=null)
		game.arena.advance_field(1.25)
		game._update_aim(0)
		await capture(theme+"-aim")
		if theme=="ds_pyrus":
			for view: int in [1,2,3]:
				game._rotate_ds_view(1)
				game._update_aim(0)
				await capture("ds_pyrus-view-%d" % view)
			game._rotate_ds_view(1)
		if theme=="ds_darkus":
			game._rotate_ds_view(1)
			var motion: RefCounted = game.arena.native_surface.material_motion
			for binding: Dictionary in motion.colour_bindings:
				if binding.track.name=="ikazuchi1":
					var values: Array = binding.track.channels[4].values
					var bright: float = float(values.find(values.max()))/60.0+0.00001
					game.arena.native_surface.reset_clock()
					await capture("ds_darkus-flash-off")
					game.arena.advance_field(bright)
					assert(binding.material.albedo_color.a>0.5)
					await capture("ds_darkus-flash-on")
					break
			game._rotate_ds_view(-1)
		if theme=="ds_ventus":
			game.throw_style = "straight"
			game.charge = 0.7
			game._launch_ball(0,0,game.arena.ground_point(Vector3(4,0,4)))
			game._update_ds_sphere(0.25)
			assert(game.flight_ball!=null and game.ds_sphere.grounded)
			game._handle_action(true)
			game._update_ds_sphere(0.2)
			assert(game.flight_ball!=null and game.ds_sphere.position.y>0.8)
			await capture("ds_ventus-jump")
	game._show_menu()
	game.queue_free()
	await process_frame
	var anime = load("res://anime_duel.tscn").instantiate()
	root.add_child(anime)
	await process_frame
	anime.auto_ai = false
	anime.set_process(false)
	anime.start_match(1414)
	anime.selected_gate = 0
	anime._try_place_gate(5)
	anime._handle_result(anime.rules.place_gate(1,0,6))
	anime.selected_gate = -1
	anime._refresh_ui()
	await capture("anime-choose-gate")
	var placed: Dictionary = anime._place_unit_on_gate(0,0,5)
	assert(placed.get("ok",false) and anime.visual_phase=="idle" and anime._flight_ball==null)
	await capture("anime-selected-stand")
	var report: Dictionary = {"version":ProjectSettings.get_setting("application/config/version"),"renderer":RenderingServer.get_current_rendering_method(),"frames":captures,"native_arena_count":8,"camera_views":4,"native_alpha_verified":true,"physical_jump_verified":true,"anime_direct_placement":true,"windows_execution_tested":false}
	var file: FileAccess = FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	anime.queue_free()
	await process_frame
	quit()
