extends SceneTree
const OUTPUT = "/workspace/bakugan-pc/builds/qa-0.17.2"
func _initialize() -> void:
	call_deferred("_run")
func _capture(name: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))
func _run() -> void:
	root.size = Vector2i(1280, 800)
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_arena = "sfm_battle_field"
	game.arena.set_theme("sfm_battle_field")
	game._show_menu()
	await _capture("menu")
	game._open_model()
	var entries: Array = game._model_entries()
	for index: int in entries.size():
		if str(entries[index].name) == "Dragonoid":
			game.model_catalog_index = index
			break
	game.model_attribute = "Pyrus"
	game.model_form = "toy"
	game._render_model()
	await _capture("dragonoid-toy")
	game.model_form = "battle"
	game._render_model()
	await _capture("dragonoid-battle")
	game.model_form = "ball"
	game._render_model()
	await _capture("dragonoid-ball")
	game._open_source_cards()
	game.source_card_browser.show_browser("gate", "monster_batch")
	await _capture("monster-gates")
	game.source_card_browser._set_kind("ability")
	await _capture("monster-abilities")
	var key: String = str(game.source_card_browser._matches[0].key)
	game.source_card_browser._open_zoom(key)
	await _capture("monster-card-zoom")
	game.queue_free()
	await process_frame
	quit()
