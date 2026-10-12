extends SceneTree
var output: String = "/workspace/bakugan-pc/builds/qa-0.16/visual"
var captures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func capture(label: String) -> void:
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(label+".png")
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
	print("CAPTURE: ",label)
func aim(game: Node3D,theme: String,layout: int) -> void:
	game.selected_arena = theme
	game.selected_field_layout = layout
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	game.arena.advance_field(0.25)
	game.field_map.prepare_map()
	game.field_map._process(0.11)
	game._update_aim(0)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,800)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	game._set_rules_profile("ds")
	for theme: String in ["ds_toy","ds_anime","ds_pyrus","ds_aquos","ds_subterra","ds_haos","ds_darkus","ds_ventus"]:
		aim(game,theme,0)
		await capture(theme+"-native-layout-1")
	for theme: String in ["ds_pyrus","ds_haos"]:
		aim(game,theme,0)
		game.arena.rotate_view(1)
		await capture(theme+"-side-view")
		game.arena.rotate_view(1)
		await capture(theme+"-full-overview")
	for layout: int in [1,2]:
		aim(game,"ds_toy",layout)
		await capture("ds_toy-native-layout-%d" % (layout+1))
	aim(game,"ds_ventus",3)
	await capture("ds_ventus-native-layout-4")
	aim(game,"ds_toy",0)
	game.throw_style = "straight"
	game.charge = 0.7
	game._launch_ball(0,0,Vector3(4,0,4))
	var pad: Dictionary = game.arena.field_objects.items.filter(func(item: Dictionary) -> bool: return item.kind=="speed_pad")[0]
	game.ds_sphere.position = pad.node.global_position+pad.node.global_transform.basis.y.normalized()*0.44
	game.ds_sphere.velocity = -pad.node.global_transform.basis.z.normalized()*0.5
	game._update_ds_sphere(1.0/30.0)
	assert(not game.ds_sphere.field_events.is_empty())
	await capture("ds_toy-native-speed-pad")
	aim(game,"ds_toy",2)
	game._launch_ball(0,0,Vector3(4,0,4))
	pad = game.arena.field_objects.items.filter(func(item: Dictionary) -> bool: return item.kind=="trampoline")[0]
	game.ds_sphere.position = pad.node.global_position+pad.node.global_transform.basis.y.normalized()*0.44
	game.ds_sphere.velocity = Vector3.ZERO
	game._update_ds_sphere(0.15)
	assert(game.flight_ball!=null and game.ds_sphere.velocity.y>3 and not game.ds_sphere.grounded)
	await capture("ds_toy-native-trampoline")
	aim(game,"ds_toy",0)
	game._launch_ball(0,0,Vector3(4,0,4))
	for item: Dictionary in game.pickups:
		if item.kind=="s_power":
			game._collect_pickups(item.position,item.position)
	assert(game.s_power[0]==100)
	game.flight_ball.queue_free()
	game.flight_ball = null
	game._begin_aim()
	game._update_aim(0)
	await capture("ds_toy-s-meter-ready")
	aim(game,"ds_toy",0)
	game.aim_point = Vector3(16,0,-12)
	game._update_aim(0)
	await capture("ds-expanded-map-aim")
	game.arena.zoom_view(-1)
	await capture("ds-player-zoom")
	game._show_menu()
	game._open_settings()
	await capture("ds-native-layout-settings")
	game.audio.open_library()
	await capture("ds-original-audio-library")
	game.audio._close_library()
	game._close_preparation()
	game._open_help()
	await capture("ds-help-top")
	game.help_scroll.scroll_vertical = 10000
	await capture("ds-help-bottom")
	game.queue_free()
	await process_frame
	var anime = load("res://anime_duel.tscn").instantiate()
	root.add_child(anime)
	await process_frame
	anime.auto_ai = false
	anime.set_process(false)
	anime.start_match(1515)
	anime.selected_gate = 0
	anime._try_place_gate(5)
	await capture("anime-direct-placement")
	assert(not is_instance_valid(anime.arena.field_objects))
	anime.queue_free()
	await process_frame
	var report: Dictionary = {"version":ProjectSettings.get_setting("application/config/version"),"frames":captures,"native_arena_count":8,"native_object_models":5,"native_layout_count":25,"renderer":RenderingServer.get_current_rendering_method(),"anime_direct_placement":true,"windows_execution_tested":false}
	var out: FileAccess = FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t")+"\n")
	quit(0)
