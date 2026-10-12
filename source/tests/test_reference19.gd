extends SceneTree
const Profiles = preload("res://scripts/ds_sphere_profiles.gd")
const Sphere = preload("res://scripts/ds_sphere_motion.gd")
const Board = preload("res://scripts/board_layout.gd")
const Scratch = preload("res://scripts/ds_scratch.gd")
const Rules = preload("res://scripts/match_rules.gd")
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)
func _initialize() -> void:
	call_deferred("run")
func finish_sequence(game) -> void:
	for step: int in range(12):
		if game.phase!="ds_scene": return
		game._step_ds_sequence(2.0)
func run() -> void:
	var fast: Dictionary = Profiles.resolve({"name":"Falconeer","attribute":"Ventus","g":300})
	check(fast.verified and fast.g==210 and fast.speed==3 and fast.magnet==2,"Observed Falconeer values are used without its former demo G")
	check(not Profiles.resolve({"name":"Falconeer","attribute":"Aquos","g":300}).verified,"Unobserved variants do not inherit verified statistics")
	var a = Sphere.new(); var b = Sphere.new()
	a.configure_unit({"name":"Falconeer","attribute":"Ventus"})
	b.configure_unit({"name":"Juggernoid","attribute":"Aquos"})
	a.launch(Vector3(0,0.5,10),Vector3(0,0,5),0.7,"straight")
	var near_speed: Vector3 = a.velocity
	a.launch(Vector3(0,0.5,10),Vector3(0,0,-20),0.7,"straight")
	check(a.velocity.is_equal_approx(near_speed),"Choosing a farther point changes no launch speed")
	b.launch(Vector3(0,0.5,10),Vector3(0,0,5),0.7,"straight")
	check(a.velocity.length()>b.velocity.length(),"Speed-three Falconeer launches faster than speed-one Juggernoid")
	check(a.magnet_margin()>b.magnet_margin(),"Observed Magnet difference changes the landing margin")
	check(Board.slot_count("ds")==48 and Board.slot_count("wii")==16,"DS has its own 8-by-6 board without replacing Wii")
	check(not Board.is_adjacent(7,8,"ds") and Board.is_adjacent(7,15,"ds"),"DS adjacency never wraps the end of a row")
	check(Board.initial_slots("ds",0)==[19,20] and Board.initial_slots("ds",1)==[27,28],"Opening sides remain crossed on the DS map")
	var core = Rules.new("ds")
	check(core.place_gate(0,0,19,true) and core.place_gate(1,0,28,true),"Both native opening positions are accepted")
	check(not core.can_place_gate(0),"A standing own gate blocks a second own gate")
	check(core.land(0,0,-1).event=="miss" and core.finish_turn() and core.available_units(0).has(0),"A missed Bakugan returns for a future turn")
	var full = Rules.new("ds")
	full.place_gate(0,0,19,true); full.place_gate(1,0,28,true)
	for round_index: int in 3:
		if full.gates.is_empty():
			full.begin_opening(); full.place_gate(0,0,19,true); full.place_gate(1,0,28,true)
		var slot: int = 28 if round_index==1 else 19
		check(full.land(0,round_index,slot).event=="stand" and full.finish_turn(),"Complete DS match: first stand yields the turn")
		check(full.land(1,round_index,slot).event=="battle","Complete DS match: opponent challenges the same gate")
		check(full.resolve_battle(slot,1000,0).event=="capture" and full.scores[0]==round_index+1,"Complete DS match: each battle captures exactly one gate")
		if full.winner<0: check(full.finish_turn(),"Complete DS match: capture yields the next turn")
	check(full.winner==0 and full.scores==[3,0] and not full.finish_turn(),"Three gates finish DS and reject a stale advance")
	var rub = Scratch.new(); rub.size=Vector2(412,146); root.add_child(rub)
	rub.configure("Ventus"); rub.set_running(true)
	check(rub.symbol!=null,"Scratch displays the native attribute texture")
	rub.press(rub.center()); rub.step(0.1)
	check(rub.score==0,"Holding the cursor still earns no Scratch power")
	rub.motion(rub.center()+Vector2(30,0)); rub.step(0.1)
	check(rub.score>0,"Actual movement across the symbol earns power")
	var credited: float = rub.score
	rub.release(); rub.motion(rub.center()); rub.step(0.1)
	check(rub.score==credited,"Moving a released cursor earns no power")
	rub.set_running(false); rub.press(rub.center()); rub.motion(rub.center()+Vector2(30,0)); rub.step(1.0)
	check(rub.score==credited,"Paused and cinematic Scratch input cannot earn points")
	rub.queue_free()
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_process(false); game.muted=true
	game._load_profile("user://reference19-empty.cfg")
	game._set_rules_profile("ds"); game.selected_arena="ds_toy"; game.start_match()
	check(game.phase=="aim" and game.rules.gates.has(19) and game.rules.gates.has(28),"Automatic opening reaches the first actual throw")
	check(game.arena.slot_count()==48 and game.rules.teams[0][0].g==190 and game.rules.teams[0][1].g==210 and game.rules.teams[0][2].g==200,"Fresh DS team matches the observed 600-G starter")
	game._update_aim(0.0)
	check(game.arena.camera.position.distance_to(game.arena.launch_position(0))<6.0,"Default DS aim camera is close to the sphere")
	game.arena.zoom_view(1)
	check(game.arena.camera.position.distance_to(game.arena.launch_position(0))<6.0,"Zooming the close aim view does not jump to an overview")
	var ds_roster: Array = game.selected_roster.duplicate()
	game._set_rules_profile("wii")
	var wii_roster: Array = game.selected_roster.duplicate()
	game._set_rules_profile("ds"); game._save_profile("user://reference19-saved.cfg")
	game._load_profile("user://reference19-saved.cfg")
	check(game.selected_roster==ds_roster,"Saved DS team survives a schema-eight round trip")
	game._set_rules_profile("wii")
	check(game.selected_roster==wii_roster,"Wii team survives the same file independently")
	game._set_rules_profile("ds")
	var old := ConfigFile.new()
	old.set_value("profile","schema",7); old.set_value("profile","rules","ds")
	old.set_value("team","selection",wii_roster); old.set_value("team","attributes",["Pyrus","Pyrus","Ventus"])
	old.set_value("controls","throw_style","lob")
	old.set_value("decks_ds","gate_keys",game._ds_selection_keys("gate",game.selected_gate_deck))
	old.set_value("decks_ds","ability_keys",game._ds_selection_keys("ability",game.selected_deck))
	old.save("user://reference19-old.cfg"); game._load_profile("user://reference19-old.cfg")
	check(game.rules_profile=="ds" and game.selected_roster==wii_roster and game.throw_style=="lob","Schema-seven migration preserves the old active team and throw preference")
	check(int(game._profile_cards("gate")[game.selected_gate_deck[0]].source_card_id)==119,"Migration resolves stable DS gate identities")
	game._load_profile("user://reference19-empty.cfg"); game._set_rules_profile("ds")
	# A cleared first pair draws the next pair through the real controller.
	game.start_match(); game.rules.gates.clear(); game.rules.opening_active=false
	game._begin_opening()
	check(game.rules.gates.has(19) and game.rules.gates.has(28) and game.rules.hands[0].size()==1 and game.rules.hands[1].size()==1,"Cleared field draws exactly one remaining card from each hand")
	game.preferences.ds_auto_gates=false; game.start_match()
	check(game.phase=="opening" and game.rules.gates.is_empty(),"Manual opening remains selectable")
	game._place_player_gate(19)
	check(game.phase=="aim" and game.rules.gates.size()==2,"Manual opening completes before any throw")
	game.preferences.ds_auto_gates=true
	game._start_practice("scratch"); finish_sequence(game)
	check(game.phase=="battle_ready" and game.battle_type=="scratch","Original-style entrance sequence reaches Scratch preparation")
	var blue: int = -1
	for i: int in game.rules.abilities[0].size():
		if int(game.rules.abilities[0][i].source_card_id)==604: blue=i
	check(blue>=0,"Starter practice offers the verified Blaze card")
	game._choose_card(blue)
	check(not game.ds_selected_ability.is_empty() and game.rules.spent_abilities[0].is_empty(),"Preselection spends no card and applies no premature G")
	game._start_battle_game(); finish_sequence(game)
	check(game.phase=="battle" and game.scratch.running,"Countdown enables actual rubbing")
	var before: float = game.battle_time
	check(game._play_ability(0,blue) and game.phase=="ds_scene","Selected ability creates an interruption during Scratch")
	game._process(0.5)
	check(game.battle_time==before and not game.scratch.running and game.rules.spent_abilities[0].size()==1,"Activation freezes minigame time and consumes its card once")
	game._toggle_pause(); game._process(1.0)
	check(game.battle_time==before and game.paused,"Pausing also freezes an in-progress card scene")
	game._toggle_pause(); finish_sequence(game)
	check(game.phase=="battle" and game.scratch.running,"Ability scene resumes the same Scratch battle")
	game.battle_points=123; game.battle_time=3.0
	check(game._battle_card_context(0).current_powers==game.ds_battle.snapshot.totals,"G-swap context excludes Scratch rubbing progress")
	game.ds_ai_ability=""; game.ai_target_points=0; game.scratch.score=600
	game._update_battle(10.0)
	check(game.phase=="finished" and game.rules.scores[0]+game.rules.scores[1]==1 and not game.rules.gates.has(19),"Scratch resolves once and captures the actual gate")
	check(game.last_battle_result.has("display_powers"),"Shown G remains distinct from internal Scratch scoring")
	game._show_menu(); game._set_rules_profile("wii"); game.match_mode="quick"; game.start_match()
	check(game.arena.slot_count()==16 and game.phase=="opening","Wii retains the original prototype setup")
	game.queue_free(); await process_frame
	print("REFERENCE 0.19: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
