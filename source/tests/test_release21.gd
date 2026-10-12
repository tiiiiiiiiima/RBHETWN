extends SceneTree
const Settings=preload("res://scripts/game_settings.gd")
const Controls=preload("res://scripts/control_bindings.gd")
const Avatar=preload("res://scripts/avatar_view.gd")
const Mini=preload("res://scripts/ds_minigame.gd")
const Director=preload("res://scripts/ds_audio.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,title: String) -> void:
	checks+=1
	if not value: failures.append(title); push_error(title)
func event_key(code: int,pressed: bool=true) -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	return event
func run() -> void:
	var preferences: Dictionary=Settings.normalize({"volume":0.2,"difficulty":"hard"})
	check(preferences.volume==0.2 and preferences.difficulty=="hard" and preferences.frame_cap==60,"Old preferences migrate without losing sound/difficulty")
	for value: Variant in [null,{},[],true,"bad",INF,NAN]:
		var bad: Dictionary=Settings.normalize({"render_scale":value,"screen_mode":value,"bindings":value,"avatar":value})
		check(bad.render_scale==1.0 and bad.screen_mode=="window" and bad.bindings==Controls.DEFAULTS and bad.avatar=="chara00","Malformed preferences remain bounded")
	preferences.bindings.action=KEY_C
	check(Controls.remap(event_key(KEY_C),preferences).keycode==KEY_SPACE,"New physical action key maps to action")
	check(Controls.remap(event_key(KEY_SPACE),preferences).keycode==KEY_NONE,"Old action key no longer invokes action")
	var conflicts: Dictionary=Controls.DEFAULTS.duplicate(); conflicts.action=KEY_A
	check(Controls.normalize(conflicts)==Controls.DEFAULTS,"Duplicate bindings cannot create two simultaneous actions")
	var controller=Controls.new()
	var axis:=InputEventJoypadMotion.new(); axis.axis=JOY_AXIS_LEFT_X; axis.axis_value=0.1
	controller.record(axis); check(controller.movement(preferences)==Vector2.ZERO,"Configured deadzone suppresses drift")
	axis.axis_value=0.8; controller.record(axis)
	check(controller.movement(preferences).x>0.6,"Left stick gives continuous steering")
	controller.reset(); check(controller.movement(preferences)==Vector2.ZERO,"Disconnect clears held controller state")
	var mini=Mini.new(); mini.size=Vector2(412,146); root.add_child(mini)
	for mode: String in ["scratch","spin","timing","pop","trace","bound"]:
		mini.configure("Pyrus",mode); mini.set_running(true); controller.reset()
		controller.pointer_action(mini,true)
		check(mini.show_virtual_pointer and controller.virtual_active,"Controller cursor visible for "+mode)
		var before: float=mini.score
		if mode in ["scratch","spin"]:
			mini.step(0.1); check(mini.score==before,"Holding still earns no power in "+mode)
		if mode=="scratch":
			axis.axis_value=0.8; controller.record(axis); controller.move_pointer(mini,preferences,0.06); mini.step(0.06)
			check(mini.score>before,"Actual cursor movement earns Scratch progress")
		controller.pointer_action(mini,false); check(not mini._held,"Release clears mini-game hold "+mode)
	mini.queue_free()
	var avatar_entries: Dictionary=Avatar.entries()
	check(avatar_entries.size()==18,"All 18 original animated avatars imported")
	for id: String in avatar_entries:
		var view=Avatar.new(); view.size=Vector2(140,160); root.add_child(view)
		check(view.show_avatar(id),"Original joint animation loads "+id)
		check(view.player.is_playing() and view.animation_name!="RESET","Original clip actively plays "+id)
		var skeleton: Skeleton3D=view.actor.find_children("*","Skeleton3D",true,false)[0]
		view.player.advance(0.01)
		var poses: Array=[]
		for bone: int in skeleton.get_bone_count(): poses.append(skeleton.get_bone_pose(bone))
		view.player.advance(0.5)
		var changed: bool=false
		for bone: int in skeleton.get_bone_count(): changed=changed or not poses[bone].is_equal_approx(skeleton.get_bone_pose(bone))
		check(changed,"Imported skeletal poses actually change "+id)
		check(not view.show_avatar("missing"),"Absent/static avatar is rejected "+id)
		view.queue_free()
		await process_frame
	var audio=Director.new(); root.add_child(audio)
	audio.set_speaker("chara00",{"species_id":"dragonoid"})
	check(not audio.voice_event("throw") and not audio.voice.playing,"Unidentified voice is not assigned to Dan")
	audio.set_speaker("chara07",{"species_id":"vladitor"})
	check(audio.voice_event("match_start") and audio.last_voice=="vo3100","Marduk self-named partner line is routed")
	audio._process(0.1)
	check(audio.caption_panel.visible and audio.caption.text.contains("Владитор"),"Spoken line has subtitle")
	audio.stop_transients(); audio.set_speaker("chara07",{"species_id":"dragonoid"})
	check(not audio.voice_event("match_start"),"Partner-specific voice never plays for wrong Bakugan")
	audio.set_context("training"); check(audio.music_id=="SEQ_BGM_TUTORIAL","Tutorial uses recovered native named sequence")
	audio.set_context("battle"); check(audio.music_id=="SEQ_BTL_BGM","Battle uses recovered native named sequence")
	audio.set_suspended(true); audio._process(0.1)
	check(not audio.caption_panel.visible,"Pause hides voice captions")
	audio.queue_free(); await process_frame
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game._open_settings()
	game.settings_panel._capture("action")
	game.settings_panel._input(event_key(KEY_C))
	check(game.preferences.bindings.action==KEY_C,"Settings capture and persist a key")
	game.settings_panel._capture("action"); game.settings_panel._input(event_key(KEY_A))
	check(game.settings_panel.capture_action=="action" and game.preferences.bindings.action==KEY_C,"Conflict leaves capture open and prior key intact")
	game.settings_panel._input(event_key(KEY_ESCAPE))
	check(game.settings_panel.capture_action.is_empty(),"Escape cancels binding capture")
	game.preferences.bindings=Controls.DEFAULTS.duplicate()
	game._start_guided_lesson()
	check(game.match_mode=="training" and game.rules_profile=="ds" and game.tutorial.active,"First fight starts a real DS training match")
	check(not game.tutorial.permits_throw(),"Intro prevents an unexplained premature throw")
	var pad:=InputEventJoypadButton.new(); pad.button_index=JOY_BUTTON_A; pad.pressed=true
	game._input(pad)
	check(game.tutorial.step==1,"Gamepad A advances intro instead of throwing prematurely")
	game._choose_card(0)
	check(game.tutorial.step==2,"Actual unit selection advances lesson")
	game.field_map.aim_requested.emit(game.arena.slot_position(int(game.rules.gates.keys()[0])))
	check(game.tutorial.step==3 and game.tutorial.permits_throw(),"Actual aiming unlocks throwing")
	game._return_to_menu()
	check(not game.tutorial.active and not game.tutorial.visible,"Menu clears lesson without saving fake completion")
	game.preferences.bindings.action=KEY_C; game._save_profile()
	game.preferences.bindings.action=KEY_SPACE; game._load_profile()
	check(game.preferences.bindings.action==KEY_C,"Binding survives profile reload")
	game._set_rules_profile("wii"); game._start_practice("shooting"); game._start_battle_game()
	pad.button_index=JOY_BUTTON_DPAD_RIGHT; game._input(pad)
	check(game.pad_shoot_target==1,"Gamepad can select another Wii shooting target")
	pad.button_index=JOY_BUTTON_DPAD_LEFT; game._input(pad)
	var before_score: int=game.battle_points
	pad.button_index=JOY_BUTTON_A; game._input(pad)
	check(game.battle_points>before_score,"Gamepad A fires the selected Wii target")
	game.controls.reset(); game._start_practice("timing"); game._start_battle_game()
	game.battle_level=2; game.timing_sequence=2; game.rhythm_phase=0.5; game.hit_cooldown=0.0
	pad.button_index=JOY_BUTTON_LEFT_SHOULDER; game._input(pad)
	check(game.timing_sequence==2 and game.battle_points==0,"First key of simultaneous combination waits for second")
	pad.button_index=JOY_BUTTON_RIGHT_SHOULDER; game._input(pad)
	check(game.battle_points>0,"Simultaneous shoulder buttons complete timing combination")
	var swapped: Dictionary=Settings.normalize({})
	swapped.bindings.style=KEY_U; swapped.bindings.action=KEY_T
	check(Controls.hints("ПРОБЕЛ · T",swapped)=="T · U","Hint substitution does not remap the new key twice")
	game._set_rules_profile("ds"); game._start_practice("scratch")
	while game.phase=="ds_scene": game._step_ds_sequence(5.0)
	game._choose_card(2)
	check(not game.ds_selected_chain.is_empty(),"Battle UI selection creates the actual ability chain")
	game._start_battle_game()
	while game.phase=="ds_scene": game._step_ds_sequence(5.0)
	game._choose_card(2)
	check(game.used_battle_abilities and game.battle_effects.extra(0,0)>0,"Battle UI selection activates the selected ability, not an unavailable-card message")
	game._return_to_menu()
	game.match_mode="quick"; game.start_match()
	game._save_checkpoint()
	var captured_phase: String=game.phase
	game.preferences.bindings.action=KEY_V
	game._resume_match()
	check(game.preferences.bindings.action==KEY_V and game.phase==captured_phase,"Resume keeps current profile bindings and the saved gameplay phase")
	game._return_to_menu()
	game.match_id+=1; game.queue_free(); await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://builds/qa-0.21/release21-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
