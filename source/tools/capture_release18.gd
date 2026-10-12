extends SceneTree
const Presentation = preload("res://scripts/ds_battle_presentation.gd")
var game: Node3D
var captures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func capture(name: String) -> void:
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://builds/qa-0.18/visual/"+name+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
	print("CAPTURE ",name)
func _run() -> void:
	root.size=Vector2i(1280,800)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted=true
	game._set_rules_profile("ds")
	game.selected_arena="ds_pyrus"
	game.start_match()
	game._place_player_gate(5)
	game._skip_gate()
	game.field_map.prepare_map()
	game.field_map._process(0.11)
	game._update_aim(0)
	await capture("pyrus-aim")
	game.arena.rotate_view(1)
	game.arena.rotate_view(1)
	await capture("pyrus-overview")
	game._launch_ball(0,0,game.arena.slot_position(5))
	game._update_ds_sphere(0.3)
	await capture("pyrus-throw")
	game._show_menu()
	game.hud.visible=false
	var scene: Control=Presentation.new()
	root.add_child(scene)
	scene.configure("ds_pyrus",false)
	var state: Dictionary={"key":"qa18","arena_id":"ds_pyrus","slot":5,"totals":[450,500],"priority":0,"gate":{"owner":0,"revealed":true,"title":"Ворота"},"units":[{"owner":0,"index":0,"name":"Dragonoid","attribute":"Pyrus"},{"owner":1,"index":0,"name":"Neo Dragonoid","attribute":"Pyrus"}],"supports":[]}
	scene.sync_battle(state,{"event":"ability_played","owner":1,"title":"СПОСОБНОСТЬ"})
	await create_timer(0.25).timeout
	await capture("ds-doc-animated-battle")
	scene.queue_free()
	game.queue_free()
	await process_frame
	FileAccess.open("res://builds/qa-0.18/visual/captures.json",FileAccess.WRITE).store_string(JSON.stringify(captures,"\t"))
	quit()
