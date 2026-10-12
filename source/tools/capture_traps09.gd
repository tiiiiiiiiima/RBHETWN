extends "res://tests/test_trap_scene09.gd"
## Real GL renders of controlled battle fixtures, rather than a manual playthrough.

const OUTPUT: String = "/workspace/bakugan-pc/builds/qa-0.9"

func _capture(name: String) -> void:
	for frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png")
	print("CAPTURE %s: %s" % [name, error_string(result)])

func _make_scene(selection: Array, attributes: Array, support: String) -> Node3D:
	var scene = DuelScene.new()
	scene.configure(Roster.make_anime_team(selection, attributes), "anime_board", {"reduced_motion": true}, "straight")
	scene.auto_ai = false
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	_select_support(scene, support)
	return scene

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1440, 900)
	var scene: Node3D = await _make_scene([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"], "metalfencer")
	await _capture("anime-trap-preparation-1440")
	root.size = Vector2i(1280, 800)
	await _capture("anime-trap-preparation-1280")
	_battle(scene)
	scene._trap_button.pressed.emit()
	_resolve_chain(scene)
	await _capture("anime-trap-deployed-1280")
	scene._side_scroll.scroll_vertical = 10000
	await _capture("anime-battle-scroll-1280")
	scene.queue_free()
	await process_frame
	var extra: Node3D = await _make_scene([0, 1, 2], ["Pyrus", "Pyrus", "Haos"], "hexstar")
	_battle(extra, 2, "Haos")
	extra._trap_button.pressed.emit()
	_resolve_chain(extra)
	await _capture("anime-extra-roll-choice-1280")
	extra._trap_action_button.pressed.emit()
	extra._update_flight(0.35)
	await _capture("anime-extra-roll-flight-1280")
	extra.queue_free()
	await process_frame
	var swap: Node3D = await _make_scene([3, 4, 5], ["Darkus", "Aquos", "Subterra"], "flash_falcon_fly")
	_battle(swap, 0, "Darkus")
	swap._trap_button.pressed.emit()
	_resolve_chain(swap)
	await _capture("anime-forced-swap-1280")
	swap.queue_free()
	await process_frame
	quit()
