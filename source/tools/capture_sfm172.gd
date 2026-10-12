extends SceneTree
const Arena = preload("res://scripts/arena.gd")
const Presentation = preload("res://scripts/ds_battle_presentation.gd")
const OUTPUT = "/workspace/bakugan-pc/builds/qa-0.17.2"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 800)
	var arena: Node3D = Arena.new()
	root.add_child(arena)
	arena.set_theme("sfm_battle_field")
	for slot: int in [2, 5, 8]:
		arena.make_gate(slot, 0, "Ворота", true)
	for index: int in 4:
		if index > 0:
			arena.rotate_view(1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join("sfm-field-%d.png" % index))
	arena.queue_free()
	await process_frame
	var view: Control = Presentation.new()
	root.add_child(view)
	view.configure("sfm_battle_field", true)
	view.sync_battle({"key":"sfm172", "arena_id":"sfm_battle_field", "slot":5,"totals":[500,500], "priority":0, "gate":{"owner":0,"revealed":true,"title":"Ворота"}, "units":[{"owner":0,"index":0,"name":"Dragonoid","attribute":"Pyrus"},{"owner":1,"index":0,"name":"Hydranoid","attribute":"Darkus"}], "supports":[]}, {})
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join("sfm-battle.png"))
	view.queue_free()
	await process_frame
	quit()
