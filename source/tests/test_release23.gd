extends SceneTree
const Slots=preload("res://scripts/save_slots.gd")
const Store=preload("res://scripts/match_checkpoint.gd")
const Saves=preload("res://scripts/save_files.gd")
const Campaign=preload("res://scripts/campaign.gd")
var checks: int=0
var failures: Array[String]=[]
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func sequence() -> void:
	for index: int in 12:
		if game.phase!="ds_scene": return
		game._step_ds_sequence(2.0)
func run() -> void:
	Saves.diagnostic_mode=true
	for kind: String in Slots.KINDS:
		for id: String in Slots.ids(kind): Store.clear(Slots.path(id))
	Store.clear(Store.LEGACY_PATH)
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_process(false); game.muted=true
	game._set_rules_profile("ds"); game.selected_arena="ds_toy"
	game._new_slot_game("campaign_1"); game._launch_campaign()
	var campaign_match: Dictionary=Store.capture(game)
	check(Store.valid(campaign_match),"Campaign starts with a valid real checkpoint")
	check(Slots.match_data("campaign_1")==campaign_match,"Campaign slot receives its live field")
	game._return_to_menu(); game._start_quick_match()
	check(Store.active_slot=="free_1","Quick match selects a free slot")
	check(Slots.match_data("campaign_1")==campaign_match,"Starting quick match preserves the campaign")
	var first: Dictionary=Slots.match_data("free_1")
	game._return_to_menu(); game._start_quick_match()
	check(Store.active_slot=="free_2" and Slots.match_data("free_1")==first,"A second quick match uses an empty slot instead of replacing the first")
	game._return_to_menu()
	var generation: int=game.match_id
	game._request_slot_start("quick","free_1")
	check(game.get_node("ReplaceSlotDialog").visible and game.match_id==generation,"Occupied explicit slot requires a visible replacement choice")
	var event:=InputEventKey.new(); event.keycode=KEY_ENTER; event.physical_keycode=KEY_ENTER; event.pressed=true
	game._input(event); game._unhandled_input(event)
	check(game.match_id==generation and Slots.match_data("free_1")==first,"Gameplay input under replacement dialog cannot replace a match")
	game.get_node("ReplaceSlotDialog").hide(); game.get_node("ReplaceSlotDialog").canceled.emit()
	check(game.pending_new_slot.is_empty() and Slots.match_data("free_1")==first,"Cancel retains the exact saved match")
	game._request_slot_start("quick","free_1"); game.get_node("ReplaceSlotDialog").hide()
	game.get_node("ReplaceSlotDialog").confirmed.emit()
	check(Store.active_slot=="free_1" and game.match_id>generation,"Explicit confirmation starts only the selected slot")
	check(Slots.match_data("campaign_1")==campaign_match,"Replacing a free slot preserves the campaign")
	game._return_to_menu(); game._select_campaign_slot("campaign_2")
	check(game.campaign.chapter==0 and game.campaign.coins==0,"A new campaign slot has fresh progression")
	game.campaign.coins=140; game.campaign.upgrade("serpenoid"); game._save_profile()
	var progress: Dictionary=game.campaign.to_dict()
	game._select_campaign_slot("campaign_1")
	check(game.campaign.coins==0 and game.campaign.level("serpenoid")==1,"Campaign development does not leak between slots")
	game._select_campaign_slot("campaign_2")
	check(game.campaign.to_dict()==progress,"Slot selection restores its developed campaign")
	game._load_profile(); check(game.campaign_slot=="campaign_2" and game.campaign.to_dict()==progress,"All campaign slots persist through profile reload")
	game._resume_slot("campaign_1")
	check(game.phase==campaign_match.main.phase and Store.capture(game).rules==campaign_match.rules,"Campaign resume restores its own board after other matches")
	check(Slots.match_data("free_2").main.match_mode=="quick","Campaign resume preserves another quick match")
	game.rules.land(0,0,19); game.rules.finish_turn(); game.rules.land(1,0,19)
	game._begin_battle(19); sequence(); game._start_battle_game(); sequence()
	game.ds_ai_ability=""; game.ds_ai_opportunities=3
	game.scratch.press(game.scratch.center()); game.scratch.motion(game.scratch.center()+Vector2(20,0))
	game._update_ds_minigame(0.1); game._save_checkpoint()
	var battle: Dictionary=Slots.match_data("campaign_1")
	check(battle.main.phase=="battle" and battle.mini.score>0,"Slot captures actual minigame progress")
	check(is_equal_approx(game.power_bar.value,game.scratch.advantage*100.0),"Displayed progress bar matches the actual advantage percentage")
	game._return_to_menu(); game._resume_slot("campaign_1")
	var after: Dictionary=Store.capture(game)
	check(after.main.battle_time==battle.main.battle_time and after.main.ds_enemy_progress==battle.main.ds_enemy_progress,"Resume retains both minigame timelines")
	check(after.mini==battle.mini and after.effects==battle.effects and after.rules==battle.rules,"Resume retains score, effects, hand and board")
	check(not game.scratch._held,"Resume requires a fresh press rather than retaining an old held input")
	game._return_to_menu(); game._resume_slot("free_2")
	game.charge=0.72; game._launch_ball(0,0,game.arena.slot_position(28)); game._update_ds_sphere(0.12)
	game._save_checkpoint(); var flight: Dictionary=Slots.match_data("free_2")
	game._return_to_menu(); game._resume_slot("free_2")
	var resumed: Dictionary=Store.capture(game)
	check(resumed.sphere==flight.sphere and resumed.rng_state==flight.rng_state,"Slot restores exact sphere and generator")
	check(resumed.field.camera==flight.field.camera and resumed.field.camera_state==flight.field.camera_state,"Camera transform and follow state survive resume")
	var before: Dictionary=Slots.record("free_2")
	game._update_ds_sphere(0.08); game._save_checkpoint()
	var file:=FileAccess.open(Saves.resolve(Slots.path("free_2")),FileAccess.WRITE); file.store_string("truncated"); file.close()
	check(Slots.record("free_2")==before,"Corrupt slot falls back to its own complete prior match/progress")
	check(not Slots.match_data("campaign_1").is_empty(),"Corrupt free slot does not affect campaign slot")
	check(Slots.write("../escape",{})==ERR_INVALID_PARAMETER,"Invalid slot cannot select an arbitrary filesystem path")
	check(Slots.write("anime_1",campaign_match)==ERR_INVALID_DATA,"A classic checkpoint cannot be written to an anime slot")
	game._return_to_menu(); game._resume_slot("free_1")
	game.s_power[0]=0; game.powered_throw=true; game._ds_preview_time=-1000
	game._draw_ds_trajectory(); var unaffordable: PackedVector3Array=game.trajectory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	game.powered_throw=false; game._ds_preview_time=-1000; game._draw_ds_trajectory()
	check(unaffordable==game.trajectory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Unaffordable powered throw forecasts the actual ordinary trajectory")
	game.s_power[0]=100; game.powered_throw=true; game._ds_preview_time=-1000; game._draw_ds_trajectory()
	check(unaffordable!=game.trajectory.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Available S-Power changes the predicted trajectory")
	Store.active_slot="free_3"
	var blocked: String=Saves.resolve(Slots.path("free_3")); DirAccess.make_dir_recursive_absolute(blocked)
	game._return_to_menu()
	check(game.paused and game.get_node("MenuSaveFailureDialog").visible and game.phase!="menu","Failed slot write keeps the live match behind a recovery choice")
	game.get_node("MenuSaveFailureDialog").hide(); DirAccess.remove_absolute(blocked)
	Store.active_slot="free_1"; game._toggle_pause(); game._return_to_menu()
	# Restore an old single-file campaign on a new installation.
	Store.clear(Slots.path("campaign_3")); var legacy: Dictionary=campaign_match.duplicate(true)
	Store.clear(Slots.path("campaign_1")); check(Store.write(legacy,Store.LEGACY_PATH)==OK,"Legacy fixture uses the old on-disk format")
	check(Slots.migrate_legacy(progress)==OK and Slots.match_data("campaign_1")==legacy,"Legacy match migrates to its matching category")
	check(Store.read(Store.LEGACY_PATH)==legacy,"Migration retains the old file for older releases")
	Slots.write("campaign_1",{},progress)
	check(Slots.migrate_legacy(progress)==OK and Slots.match_data("campaign_1").is_empty(),"Completed migration cannot resurrect an old match")
	# A per-slot settlement remains even after the rolling global history ends.
	game.slot_settled["campaign_1"]=str(legacy.main.match_token); game.settled_matches.clear()
	game.campaign_profiles["campaign_1"]=progress; Slots.write("campaign_1",legacy,progress)
	var previous_wins: int=game.wins
	game._open_saves(); game._resume_slot("campaign_1")
	check(Slots.match_data("campaign_1").is_empty() and game.wins==previous_wins,"Settled backup cannot reissue a result after the global token window expires")
	game._open_saves(); check(game.save_slot_panel.visible and game.save_slot_panel.buttons.size()==3,"Slot manager is reachable with three selectable slots")
	game._unhandled_input(_escape_event()); check(game.phase=="menu","Escape closes the slot manager")
	game.match_id+=1; game.queue_free(); await process_frame
	var report: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"passed":failures.is_empty(),"prescribed_rule_fixture":true,"full_physical_match":false}
	var path: String="res://builds/qa-0.23/release23-tests.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.trim_prefix("--report=")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RELEASE 0.23 ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
func _escape_event() -> InputEventKey:
	var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.physical_keycode=KEY_ESCAPE; event.pressed=true
	return event
