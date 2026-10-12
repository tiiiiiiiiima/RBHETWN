extends SceneTree
const Presentation = preload("res://scripts/ds_battle_presentation.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 800)
	var scene: Control = Presentation.new()
	root.add_child(scene)
	scene.configure("ds_pyrus", false)
	var state: Dictionary = {"key": "qa17", "arena_id": "ds_pyrus", "slot": 5, "totals": [500, 500], "priority": 0,
		"gate": {"owner": 0, "revealed": true, "title": "Ворота"},
		"units": [{"owner": 0, "index": 0, "name": "Neo Dragonoid", "attribute": "Pyrus"}, {"owner": 1, "index": 0, "name": "Percival", "attribute": "Darkus"}],
		"supports": [{"owner": 0, "slot": 5, "id": "scorpion", "name": "Scorpion", "attribute": "Pyrus", "status": "deployed", "category": "trap"}]}
	scene.sync_battle(state, {"event": "ability_played", "owner": 0, "title": "СПОСОБНОСТЬ ПАЙРУСА"})
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/bakugan-pc/builds/qa-0.17/native-battle.png")
	scene.queue_free()
	await process_frame
	quit()
