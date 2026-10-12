extends SceneTree
## Verifies the real classic scene's DS presentation, input handoff and result
## lifetime. The presentation does not decide gate capture or minigame scoring.

var game: Node3D
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _click(button: Button) -> void:
	# Send actual viewport mouse events so Control hit testing and layering run.
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		game.get_viewport().push_input(event, true)
		await process_frame


func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	game.rng.seed = 100510
	game._start_practice("timing")
	await process_frame
	_check(game.phase == "battle_ready" and game.ds_battle.is_presenting(), "Opposing units open the classic DS stage before minigame input")
	_check(game.ds_battle.visible and game.battle_panel.visible, "DS stage and compact minigame are both visible")
	_check(game.dragons.is_empty(), "The board does not instantiate duplicate battle monsters")
	_check(game.ds_battle.get_rect().end.y <= game.battle_panel.position.y, "Minigame panel does not obscure the battle models")
	_check(game.action_button.visible and not game.action_button.disabled, "The existing start-battle button remains usable")
	_check(not game.rules.gates.is_empty(), "Presentation does not resolve rules before the minigame")
	await _click(game.action_button)
	_check(game.phase == "battle" and game.timing_track.visible, "An actual mouse click starts the timing minigame through the DS stage")
	var selected: int = -1
	for index in range(game.card_buttons.size()):
		if not game.card_buttons[index].disabled:
			selected = index
			break
	if selected >= 0:
		var before: int = game.rules.abilities[0].size()
		await _click(game.card_buttons[selected])
		_check(game.rules.abilities[0].size() == before - 1, "An actual mouse click plays an eligible ability while DS presentation is active")
		_check(game.ds_battle.is_presenting(), "Ability refresh retains the battle stage")
	else:
		_check(false, "Controlled practice contains an eligible ability for the click check")
	game._toggle_pause()
	var frozen: float = game.battle_time
	await create_timer(0.05, true).timeout
	_check(game.paused and not game.ds_battle.visible and game.battle_time == frozen, "Pause hides the DS stage and freezes classic battle input")
	game._toggle_pause()
	_check(not game.paused and game.ds_battle.visible and game.ds_battle.is_presenting(), "Resume restores the same battle presentation")
	game.battle_points = 10000
	game.ai_target_points = 0
	game._finish_battle()
	_check(game.phase == "finished" and not game.last_battle_result.is_empty(), "Classic rules resolve the practice capture immediately")
	_check(game.rules.gates.is_empty() and game.ds_battle.is_presenting(), "DS result keeps its participants after the captured gate is removed")
	_check(not game.overlay.visible and not game.battle_panel.visible, "Result playback is unobscured by practice and minigame panels")
	await create_timer(1.75, true).timeout
	_check(game.overlay.visible and game.overlay_start.text == "ПОВТОРИТЬ", "Practice replay controls appear after the result hold")
	game._overlay_primary()
	_check(game.phase == "battle_ready" and game.ds_battle.is_presenting(), "Practice replay resets and opens a new battle presentation")
	game._start_practice("shooting")
	game.rules.abilities[1].clear()
	await _click(game.action_button)
	_check(game.phase == "battle" and game.shooting_target.visible and not game.timing_track.visible, "Clicking start selects the shooting minigame without obstructing its targets")
	var own_target: int = game.shooting_attributes.find(str(game._battle_unit(0).attribute))
	var before_shot: int = game.battle_points
	await _click(game.shooting_targets[own_target])
	_check(game.battle_points > before_shot and game.ds_battle.is_presenting(), "A real mouse click scores a matching shooting target with the battle stage visible")
	for target: Button in game.shooting_targets:
		_check(game.battle_panel.get_global_rect().encloses(target.get_global_rect()), "Compact shooting targets stay inside the minigame panel")
		_check(target.get_global_rect().end.y <= game.battle_feedback.get_global_rect().position.y, "Shooting targets do not cover the score feedback")
	game.start_match()
	_check(not game.ds_battle.is_presenting() and not game.ds_battle.visible, "A new match clears the previous battle and result")
	game._show_menu()
	_check(game.phase == "menu" and not game.ds_battle.is_presenting(), "Returning to the menu clears the DS stage")
	game.queue_free()
	await process_frame
	print("CLASSIC DS SCENE CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
