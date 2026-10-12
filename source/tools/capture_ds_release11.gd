extends SceneTree
## Actual desktop GL captures; run under the provided Xvfb display.

const Duel = preload("res://scripts/anime_duel.gd")
const Roster = preload("res://scripts/roster.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")
const Models = preload("res://scripts/model_library.gd")
const OUTPUT: String = "/workspace/bakugan-pc/builds/qa-0.11"


func _initialize() -> void:
	call_deferred("_run")


func _capture(label: String) -> void:
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
	print("CAPTURE %s: %s" % [label, error_string(error)])


func _battle(scene: Node3D, team_battle: bool = false) -> void:
	scene.start_match(10123)
	scene.rules.gate_hands[0][0] = Cards.get_gate("pyrus_50")
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene._flight_owner = 0
	scene._flight_unit = 1
	scene._finish_throw(5)
	if team_battle:
		scene._handle_result(scene.rules.throw_unit(1, 0, 6))
		scene._handle_result(scene.rules.finish_turn(1))
		scene._flight_unit = 0
		scene._finish_throw(5)
		scene._handle_result(scene.rules.throw_unit(1, 1, 5))
	else:
		scene._handle_result(scene.rules.throw_unit(1, 0, 5))
	scene._handle_result(scene.rules.open_gate(0))
	scene.battle_presentation._event_time = 0.0


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1440, 900)
	var classic: Node3D = load("res://main.tscn").instantiate()
	root.add_child(classic)
	await process_frame
	classic.set_process(false)
	classic.muted = true
	classic.selected_arena = "ds_pyrus"
	classic.arena.set_theme("ds_pyrus")
	classic._start_practice("timing")
	classic.ds_battle._event_time = 0.0
	await _capture("ds-classic-battle-1440")
	root.size = Vector2i(1280, 800)
	await _capture("ds-classic-battle-1280")
	classic._start_battle_game()
	classic._battle_hit(KEY_SPACE)
	await _capture("ds-classic-action-1280")
	classic.battle_points = 10000
	classic.ai_target_points = 0
	classic._finish_battle()
	await _capture("ds-classic-result-1280")
	classic._show_menu()
	classic._open_source_cards()
	await _capture("ds-card-collection-1280")
	classic.source_card_browser._set_kind("ability")
	classic.source_card_browser._set_query("Boosted Dragon")
	classic.source_card_browser._open_zoom("ds_card_511")
	await _capture("ds-card-zoom-1280")
	classic.source_card_browser.close_browser()
	classic.queue_free()
	await process_frame
	root.size = Vector2i(1440, 900)
	var scene: Node3D = Duel.new()
	scene.configure(Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), "ds_pyrus", {"reduced_motion": false}, "straight")
	scene.auto_ai = false
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	_battle(scene)
	await _capture("ds-anime-battle-1440")
	root.size = Vector2i(1280, 800)
	await _capture("ds-anime-battle-1280")
	var drago: Node3D = scene.battle_presentation.actors.get("0:1")
	if drago != null and Models.play_battle_animation(drago, "attack"):
		var player: AnimationPlayer = drago.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var remaining: float = player.current_animation_length * 0.45
		while remaining > 0.000001:
			var step: float = minf(remaining, 1.0 / 120.0)
			player.advance(step)
			remaining -= step
		await _capture("ds-anime-native-action-1280")
		Models.play_battle_animation(drago, "idle")
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_battle(scene, true)
	await _capture("ds-team-battle-1280")
	scene._set_paused(true)
	await _capture("ds-anime-pause-1280")
	scene._set_paused(false)
	scene.queue_free()
	await process_frame
	quit()
