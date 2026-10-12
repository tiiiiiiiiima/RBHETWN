extends SceneTree
var output: String = "/workspace/bakugan-pc/builds/qa-0.13/visual"
var captures: Array[String] = []
var report: Dictionary = {}
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
		game._update_aim(0)
		game.arena.advance_field(1.25)
		game._draw_ds_trajectory()
		await capture(theme+"-aim")
		var before: float = game.arena.native_surface.clock
		game._toggle_pause()
		game._process(0.75)
		assert(game.arena.native_surface.clock==before,"Pause stops native field")
		game._toggle_pause()
		game.throw_style="lob"
		game.charge=0.70
		game._launch_ball(0,0,game.arena.ground_point(game.aim_point))
		game._update_ds_sphere(0.45)
		assert(game.flight_ball!=null and game.ds_sphere.position.y>0.7,"Lob is physical and airborne")
		await capture(theme+"-lob")
		game._update_ds_sphere(0.70)
		await capture(theme+"-descent")
	game._show_menu()
	game.queue_free()
	await process_frame
	var anime = load("res://anime_duel.tscn").instantiate()
	root.add_child(anime)
	await process_frame
	anime.auto_ai=false
	anime.set_process(false)
	anime.start_match(1313)
	anime.selected_gate=0
	anime._try_place_gate(5)
	anime._handle_result(anime.rules.place_gate(1,0,6))
	anime.selected_gate=-1
	anime._refresh_ui()
	await capture("anime-choose-gate")
	var invalid: Dictionary = anime._place_unit_on_gate(0,0,-1)
	assert(not invalid.get("ok",true) and anime.rules.turn==0)
	var result: Dictionary = anime._place_unit_on_gate(0,0,5)
	assert(result.get("ok",false) and anime.visual_phase=="idle" and anime._flight_ball==null)
	await capture("anime-selected-stand")
	assert(not anime._style_button.visible and not anime._charge_bar.visible)
	report={"version":ProjectSettings.get_setting("application/config/version"),"renderer":RenderingServer.get_current_rendering_method(),"frames":captures,"native_arena_count":8,"pause_verified":true,"anime_direct_placement":true,"windows_execution_tested":false}
	var file: FileAccess = FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	anime.queue_free()
	await process_frame
	quit()
