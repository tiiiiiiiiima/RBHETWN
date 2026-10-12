extends SceneTree
## Run with an actual GL renderer/display for reviewable duel screenshots.

const DuelScene = preload("res://scripts/anime_duel.gd")
const Roster = preload("res://scripts/roster.gd")
const Layout = preload("res://scripts/board_layout.gd")
const OUTPUT: String = "/workspace/bakugan-pc/builds/qa-0.8"


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var path: String = OUTPUT + "/anime-" + name + ".png"
	var error: Error = screenshot.save_png(path)
	print("CAPTURE %s: %s" % [name, error_string(error)])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1440, 900)
	var scene = DuelScene.new()
	scene.configure(Roster.make_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), "anime_board", {"reduced_motion": true}, "lob")
	scene.auto_ai = false
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	await _capture("deck")
	scene.start_match(388)
	await _capture("opening")
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene.selected_gate = -1
	scene.aim_point = Layout.POSITIONS[5]
	scene.charge = 0.7
	scene.charging = true
	scene._draw_preview()
	await _capture("lob-preview")
	scene._cycle_style()
	scene._draw_preview()
	await _capture("straight-preview")
	scene._flight_owner = 0
	scene._flight_unit = 0
	scene._finish_throw(5)
	scene._handle_result(scene.rules.throw_unit(1, 0, 5))
	scene._handle_result(scene.rules.open_gate(0))
	await _capture("battle")
	scene.start_match(389)
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene._flight_unit = 0
	scene._finish_throw(5)
	scene._handle_result(scene.rules.throw_unit(1, 0, 6))
	scene._handle_result(scene.rules.finish_turn(1))
	scene._flight_unit = 1
	scene._finish_throw(5)
	scene._handle_result(scene.rules.throw_unit(1, 1, 5))
	scene._handle_result(scene.rules.open_gate(0))
	await _capture("team-battle")
	scene._set_paused(true)
	await _capture("pause")
	scene.queue_free()
	await process_frame
	quit()
