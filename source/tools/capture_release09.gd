extends SceneTree
## Actual GL screenshots of canonical selection and separate model categories.

const Roster = preload("res://scripts/roster.gd")
const OUTPUT: String = "/workspace/bakugan-pc/builds/qa-0.9"

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	for frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png")
	print("CAPTURE %s: %s" % [name, error_string(result)])

func _index(id: String) -> int:
	for index: int in range(Roster.CREATURES.size()):
		if str(Roster.CREATURES[index].id) == id:
			return index
	return -1

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1440, 900)
	var menu: Node3D = load("res://main.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.set_process(false)
	menu.selected_roster = [_index("dragonoid"), _index("ingram"), _index("juggernoid")]
	menu.selected_attributes = ["Aquos", "Haos", "Aquos"]
	menu._open_roster()
	await _capture("roster-native-1440")
	root.size = Vector2i(1280, 800)
	await _capture("roster-native-1280")
	menu._select_roster_slot(0, _index("neo_dragonoid"))
	await _capture("roster-sourced-g-1280")
	menu._close_roster()
	menu._open_model(0)
	menu._set_model_category("trap")
	await _capture("collection-traps-1280")
	menu._set_model_category("support")
	await _capture("collection-paired-1280")
	menu.queue_free()
	await process_frame
	quit()
