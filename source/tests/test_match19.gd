extends SceneTree
## Controller lifecycle with prescribed landings; sphere trajectories are
## checked separately by the native-geometry repeat and physics regressions.
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> bool:
	checks += 1
	if not value: failures.append(message); push_error(message)
	return value
func sequence(game) -> void:
	for step: int in 12:
		if game.phase!="ds_scene": return
		game._step_ds_sequence(2.0)
func run() -> void:
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_process(false); game.muted=true
	game._load_profile("user://empty19.cfg"); game._set_rules_profile("ds")
	for field: String in ["ds_toy","ds_pyrus"]:
		game.selected_arena=field; game.match_mode="quick"; game.start_match()
		for round_index: int in 3:
			var slot: int = 28 if round_index==1 else 19
			if game.phase=="place": game._skip_gate()
			if not check(game.phase=="aim" and game.rules.turn==0,"Player can begin the next throw: "+field): break
			check(game.rules.gates.has(slot),"The expected gate exists: "+field)
			game._launch_ball(0,round_index,game.arena.slot_position(slot))
			game.flight_ball.position=game.arena.ground_point(game.arena.slot_position(slot))
			game._land_ball()
			check(game.phase=="result" and game.rules.gates[slot].bakugan.size()==1,"First prescribed landing stands before advancing")
			await create_timer(2.35).timeout
			if not check(game.phase=="flying" and game.flight_owner==1,"Actual delayed opponent turn launches a sphere"): break
			game.flight_ball.position=game.arena.ground_point(game.arena.slot_position(slot))
			game._land_ball(); sequence(game)
			if not check(game.phase=="battle_ready" and game.battle_type=="scratch","An opposed landing reaches Scratch preparation"): break
			game._start_battle_game(); sequence(game)
			game.ds_ai_ability=""; game.ai_target_points=0; game.scratch.score=600
			game._update_battle(10.0)
			check(game.rules.scores==[round_index+1,0] and not game.rules.gates.has(slot),"Capture updates the score and removes its source gate")
			await create_timer(2.95).timeout
			check(game.phase=="finished" if round_index==2 else game.rules.turn==0,"Result animation returns to a playable next state")
		check(game.phase=="finished" and game.rules.winner==0 and game.overlay.visible,"Three gates finish the complete controller match: "+field)
		game.start_match()
		check(game.phase=="aim" and game.rules.scores==[0,0] and game.ds_sequence.is_empty(),"Restart resets score and cinematic state")
		await create_timer(0.7).timeout
		check(game.phase=="aim" and game.rules.turn==0,"Old delayed callbacks cannot advance the restarted match")
	game.queue_free(); await process_frame
	FileAccess.open("/workspace/bakugan-pc/builds/qa-0.19/matches.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"prescribed_landings":true},"\t"))
	print("DS MATCH 0.19: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
