extends SceneTree
func _initialize() -> void: call_deferred("_run")
func capture(label: String) -> void:
	for frame: int in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/bakugan-pc/builds/qa-0.16/"+label+".png")
func _run() -> void:
	root.size = Vector2i(1280,800)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game._open_settings()
	await capture("audio-settings-source")
	game.audio.open_library()
	await capture("audio-library-source")
	game.audio._close_library()
	game.queue_free()
	await process_frame
	quit()
