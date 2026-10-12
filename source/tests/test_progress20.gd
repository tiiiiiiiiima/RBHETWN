extends SceneTree
const Campaign=preload("res://scripts/campaign.gd")
const Checkpoint=preload("res://scripts/match_checkpoint.gd")
const Board=preload("res://scripts/board_layout.gd")
const AI=preload("res://scripts/tactical_ai.gd")
var checks: int=0
var failures: Array[String]=[]
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func sequence() -> void:
	for i: int in 12:
		if game.phase!="ds_scene": return
		game._step_ds_sequence(2.0)
func same_state(before: Dictionary, after: Dictionary, label: String) -> void:
	for section: String in ["rules","sphere","roll","effects","stats","rng_state"]:
		check(before[section]==after[section],label+" preserves "+section)
	for field: String in ["phase","battle_time","battle_points","ds_enemy_progress","ds_selected_chain","s_power","roll_bonus","field_damage","campaign_chapter"]:
		check(before.main[field]==after.main[field],label+" preserves "+field)
func run() -> void:
	var progress=Campaign.new()
	check(progress.coins==0 and progress.claimed.is_empty() and progress.unlocked_species==Campaign.STARTERS,"New campaign has a distinct starter collection")
	check(progress.player_team()[0].g==190 and progress.player_team()[1].g==210,"Campaign starts with observed native starter G")
	check(not progress.upgrade("serpenoid") and not progress.evolve("dragonoid"),"Development needs unlocks, points and levels")
	check(progress.record_result(false,0).is_empty() and progress.chapter==0,"Loss keeps the same chapter")
	var total: int=0
	var arenas: Dictionary={}; var tactics: Dictionary={}
	for chapter: int in 7:
		arenas[progress.stage().arena]=true; tactics[progress.stage().tactic]=true
		check(progress.enemy_team().size()==3,"Every chapter has a legal opposing team")
		var unlocked_before: Array[String]=progress.unlocked_cards.duplicate()
		var reward: Dictionary=progress.record_result(true,chapter); total+=int(reward.coins)
		check(reward.cards.size()==6 and progress.unlocked_cards.size()==unlocked_before.size()+6,"Each chapter grants six new cards rather than counting previously owned cards")
		check(not reward.is_empty() and progress.unlocked_species.has(str(reward.species)) and progress.unlocked_arenas.has(str(reward.arena)),"Chapter unlocks its advertised creature and arena")
		var old_coins: int=progress.coins
		check(progress.record_result(true,chapter).is_empty() and progress.coins==old_coins,"Same chapter reward cannot be repeated")
		var roundtrip=Campaign.new(); roundtrip.load_dict(progress.to_dict())
		if roundtrip.to_dict()!=progress.to_dict():
			for field: String in progress.to_dict():
				if roundtrip.to_dict()[field]!=progress.to_dict()[field]: print("DIFF ",field," ",roundtrip.to_dict()[field]," vs ",progress.to_dict()[field])
		check(roundtrip.to_dict()==progress.to_dict(),"Campaign progress survives a round trip")
	check(progress.completed and arenas.size()==7 and tactics.size()==7 and progress.coins==total,"Seven distinct chapters finish the campaign")
	check(progress.upgrade("dragonoid") and progress.upgrade("dragonoid"),"Unlocked creature reaches evolution level with earned currency")
	progress.team[0]="dragonoid"
	var g_before: int=progress.player_team()[0].g
	check(progress.evolve("dragonoid") and progress.team[0]=="delta_dragonoid","Evolution changes the selected creature to an existing model")
	check(progress.player_team()[0].g==g_before+60,"Evolution carries level and grants the displayed G increase")
	var roundtrip=Campaign.new(); roundtrip.load_dict(progress.to_dict())
	check(roundtrip.player_team()==progress.player_team(),"Evolved team and parameters persist")
	check(not progress.evolve("dragonoid"),"An already unlocked evolution cannot charge twice")
	check(Board.card_size("ds").x>2.7 and Board.card_size("ds").y>3.1,"DS gate footprint is enlarged")
	check(is_finite(Board.gate_contact_fraction(Vector3(1.30,0.44,0),Vector3(1.30,0.44,0),Vector3.ZERO)),"Newly visible card edge accepts a grounded sphere")
	check(not is_finite(Board.gate_contact_fraction(Vector3(1.6,0.44,0),Vector3(1.6,0.44,0),Vector3.ZERO)),"Beyond-card ground contact does not stand")
	check(not is_finite(Board.gate_contact_fraction(Vector3(0,2,0),Vector3(0,2,0),Vector3.ZERO)),"Enlarging cards does not catch an airborne sphere")
	game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false); game.muted=true
	game._set_rules_profile("ds"); game.selected_arena="ds_toy"; game.match_mode="quick"; game.start_match()
	check(game._near_ready_sphere(game.arena.camera.unproject_position(game.ds_ready_ball.global_position)),"Sphere can be grabbed by its actual projected position")
	var aim: Dictionary=Checkpoint.capture(game)
	check(Checkpoint.valid(aim),"An aim checkpoint is complete and valid")
	check(Checkpoint.write(aim,"user://qa20.bin")==OK and Checkpoint.read("user://qa20.bin")==aim,"Checksummed file preserves exact native variants")
	if not Checkpoint.valid(aim): quit(1); return
	var altered: Dictionary=aim.duplicate(true); altered.rules.turn=9
	check(not Checkpoint.valid(altered),"Invalid current owner is rejected")
	game.charge=0.73; game._launch_ball(0,0,game.arena.slot_position(28))
	for i: int in 20: game._update_ds_sphere(1.0/120.0)
	var flight: Dictionary=Checkpoint.capture(game)
	check(Checkpoint.valid(flight),"Moving sphere can be checkpointed")
	game.saved_match=flight.duplicate(true); game._show_menu(); game._resume_match()
	var restored: Dictionary=Checkpoint.capture(game)
	same_state(flight,restored,"Mid-throw resume")
	check(game.flight_ball.transform==flight.flight_transform,"Mid-throw visual orientation is preserved")
	var backup: Dictionary=flight.duplicate(true)
	check(Checkpoint.write(backup,"user://qa20.bin")==OK,"Second checkpoint retains a backup")
	FileAccess.open("user://qa20.bin",FileAccess.WRITE).store_string("truncated")
	check(Checkpoint.read("user://qa20.bin")==aim,"Corrupt primary falls back to the preceding valid checkpoint")
	Checkpoint.clear("user://qa20.bin")
	game.start_match(); game.rules.finish_turn(); game._ai_turn()
	var ai_wait: Dictionary=Checkpoint.capture(game)
	check(ai_wait.main.pending_action=="ai_choose" and ai_wait.timer_remaining>0,"AI decision wait is checkpointed")
	game.saved_match=ai_wait.duplicate(true); game._show_menu(); game._resume_match()
	check(game.pending_action=="ai_choose" and absf(game.pending_timer.time_left-float(ai_wait.timer_remaining))<0.01,"AI resume preserves its remaining delay")
	await create_timer(1.35).timeout
	check(game.phase in ["flying","rolling"] and game.flight_owner==1,"Resumed AI timer produces exactly its pending throw")
	game.start_match()
	check(game.rules.land(0,0,19).event=="stand","Result fixture has consumed its real DS throw")
	game._announce_then_advance("QA",Color.WHITE)
	var result_wait: Dictionary=Checkpoint.capture(game)
	game.saved_match=result_wait.duplicate(true); game._show_menu(); game._resume_match()
	check(game.phase=="result" and game.pending_action=="advance","Result resume retains the pending turn transition")
	await create_timer(float(result_wait.timer_remaining)+0.15).timeout
	check(game.phase!="result" and game.rules.turn==1,"Result delay advances the saved turn without repeating capture")
	game.start_match()
	game.rules.land(0,0,19); game.rules.finish_turn(); game.rules.land(1,0,19)
	game._begin_battle(19)
	var scene: Dictionary=Checkpoint.capture(game)
	game.saved_match=scene.duplicate(true); game._show_menu(); game._resume_match()
	check(game.phase==scene.main.phase and game.ds_current_event==scene.main.ds_current_event and game.ds_sequence==scene.main.ds_sequence,"Presentation scene and queued events survive resume")
	sequence(); game._start_battle_game(); sequence()
	game.ds_ai_ability=""; game.ds_ai_opportunities=3
	game.scratch.press(game.scratch.center()); game.scratch.motion(game.scratch.center()+Vector2(30,0)); game._update_ds_minigame(0.04)
	game.battle_time=2.35; game.ds_enemy_progress=42.25
	game._refresh_battle_scores()
	var battle: Dictionary=Checkpoint.capture(game)
	game.saved_match=battle.duplicate(true); game._show_menu(); game._resume_match()
	var battle_after: Dictionary=Checkpoint.capture(game)
	same_state(battle,battle_after,"Mid-minigame resume")
	check(battle.mini==battle_after.mini and not game.scratch._held,"Minigame score/timing persist and mouse starts released")
	game._set_rules_profile("wii"); game.start_match()
	game.charge=0.73; game._launch_ball(0,0,game.arena.slot_position(5)); game._update_flight(0.12)
	var wii: Dictionary=Checkpoint.capture(game)
	check(Checkpoint.valid(wii),"Wii throw has a valid checkpoint")
	game.saved_match=wii.duplicate(true); game._show_menu(); game._resume_match()
	var wii_after: Dictionary=Checkpoint.capture(game)
	check(wii.main.rules_profile==wii_after.main.rules_profile and wii.main.flight_time==wii_after.main.flight_time and wii.flight_transform==wii_after.flight_transform and wii.rules==wii_after.rules,"Wii resumes its throw and rule state")
	game._set_rules_profile("ds")
	game.match_mode="campaign"; game.campaign=Campaign.new(); game.campaign_chapter=0; game.start_match()
	game.rules.scores.assign([3,0]); game.rules.winner=0; game._end_match()
	check(game.campaign.chapter==1 and game.campaign.coins==90,"Controller win commits the first campaign reward")
	var committed: Dictionary=game.campaign.to_dict()
	game.last_recorded_match_id=-1; game._end_match()
	check(game.campaign.to_dict()==committed,"Controller settlement is idempotent")
	game._load_profile(); check(game.campaign.to_dict()==committed,"Version-nine profile retains campaign rewards")
	game._open_campaign(); check(game.campaign_panel.visible,"Campaign development screen is reachable")
	game.match_id+=1; game.queue_free(); await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}))
	var report: String="progress-packed.json" if "--packed" in OS.get_cmdline_user_args() else "progress.json"
	FileAccess.open("/workspace/bakugan-pc/builds/qa-0.20/"+report,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
