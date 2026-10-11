extends SceneTree
const Saves=preload("res://scripts/save_files.gd")
const Avatar=preload("res://scripts/avatar_view.gd")
const Arenas=preload("res://scripts/ds_arena_catalog.gd")
const Store=preload("res://scripts/match_checkpoint.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func run() -> void:
	Saves.diagnostic_mode=false
	check(Saves.resolve("user://profile.cfg")=="user://profile.cfg","Ordinary profile path is unchanged")
	Saves.diagnostic_mode=true
	check(Saves.resolve("user://profile.cfg")=="user://diagnostics/0.22/profile.cfg","QA profile is isolated")
	check(Saves.resolve(Saves.resolve("user://profile.cfg"))==Saves.resolve("user://profile.cfg"),"QA paths never acquire a second prefix")
	check(Saves.resolve("/tmp/specified.cfg")=="/tmp/specified.cfg","Explicit external fixture paths stay intact")
	var config:=ConfigFile.new(); config.set_value("deck","gates",[1,2,3])
	check(Saves.write_config(config,"user://fixture.cfg")==OK,"First atomic config write succeeds")
	config.set_value("deck","gates",[4,5,6])
	check(Saves.write_config(config,"user://fixture.cfg")==OK,"Replacement config write succeeds")
	var backup:=ConfigFile.new(); backup.load(Saves.resolve("user://fixture.cfg")+".bak")
	check(backup.get_value("deck","gates")==[1,2,3],"Backup retains previous working deck")
	var blocker: FileAccess=FileAccess.open(Saves.resolve("user://blocked"),FileAccess.WRITE); blocker.store_string("not a directory"); blocker.close()
	check(Saves.write_config(config,"user://blocked/profile.cfg")!=OK,"A blocked parent directory reports failure")
	check(backup.get_value("deck","gates")==[1,2,3],"Failed write cannot mutate a valid backup")
	var avatar=Avatar.new(); avatar.hide(); root.add_child(avatar)
	check(avatar.show_avatar("chara00") and avatar.actor==null,"Hidden portrait defers native scene loading")
	avatar.show(); await process_frame; await process_frame
	check(is_instance_valid(avatar.player) and avatar.player.is_playing(),"Showing portrait loads its native animation")
	avatar.hide(); await process_frame
	var before: float=avatar.player.current_animation_position
	await create_timer(0.1).timeout
	check(is_equal_approx(before,avatar.player.current_animation_position),"Hidden portrait stops skeletal updates")
	avatar.show(); await process_frame; await create_timer(0.1).timeout
	check(not is_equal_approx(before,avatar.player.current_animation_position),"Reopened portrait continues animating")
	avatar.queue_free(); await process_frame
	var paths: Array[String]=[]
	for group: Dictionary in Arenas.manifest().groups.values():
		for component: Dictionary in group.components:
			if not paths.has(str(component.path)): paths.append(str(component.path))
	var first: PackedScene=Arenas.cached_scene(paths[0])
	for index: int in mini(paths.size(),Arenas.MAX_SCENES+5):
		check(Arenas.cached_scene(paths[index])!=null,"Native stage component loads "+str(index))
		check(Arenas._scenes.size()<=Arenas.MAX_SCENES,"Stage retention stays bounded "+str(index))
	var retained: Node=first.instantiate()
	check(retained is Node3D,"Eviction leaves an existing stage reference usable")
	retained.free()
	var game=load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	check(game.ds_battle._world.process_mode==Node.PROCESS_MODE_DISABLED,"Closed battle stage stops background animation")
	game.match_mode="quick"; game.start_match()
	var captured: Dictionary=Store.capture(game)
	check(Store.write(captured)==OK and Store.valid(Store.read()),"QA checkpoint works through the isolated save path")
	check(FileAccess.file_exists(Saves.resolve(Store.PATH)),"QA checkpoint uses its own directory")
	game._start_practice("scratch")
	while game.phase=="ds_scene": game._step_ds_sequence(5.0)
	check(game.ds_battle._world.process_mode!=Node.PROCESS_MODE_DISABLED,"Active battle stage resumes original animations")
	game.ds_battle.reset()
	check(game.ds_battle._world.process_mode==Node.PROCESS_MODE_DISABLED,"Finished stage releases animation processing")
	game.ds_battle.set_suspended(true); game.ds_battle.set_suspended(false)
	check(game.ds_battle._world.process_mode==Node.PROCESS_MODE_DISABLED,"Resuming a closed stage keeps its background stopped")
	game._return_to_menu(); game.match_mode="quick"; game.start_match()
	while game.phase!="aim": await process_frame
	game._handle_action(true)
	check(game.charging,"Action begins a real charge")
	Input.joy_connection_changed.emit(0,false)
	check(not game.charging and game.charge==0.0,"Device disconnect cancels charge without throwing")
	var memory: Dictionary=preload("res://scripts/runtime_metrics.gd").process_memory()
	check(memory.available and memory.peak_working_set_bytes>=memory.working_set_bytes and memory.working_set_bytes>0,"Real process memory counter returns bytes")
	game._draw_ds_trajectory(); var mesh: Mesh=game.trajectory.mesh
	game.aim_point+=Vector3(0.05,0,0)
	game._draw_ds_trajectory()
	check(game.trajectory.mesh==mesh,"Changed aim respects the 8 Hz forecast budget")
	game._ds_preview_time=-1000; game._draw_ds_trajectory()
	check(game.trajectory.mesh!=mesh,"Forecast refreshes after its time budget")
	Saves.quit_or_warn(game,[ERR_FILE_CANT_WRITE])
	check(game.paused and game.get_node("SaveFailureDialog").visible,"Write failure keeps game alive and opens a recovery choice")
	var event:=InputEventKey.new(); event.keycode=KEY_SPACE; event.physical_keycode=KEY_SPACE; event.pressed=true
	var phase: String=game.phase; game._input(event)
	check(game.phase==phase and not game.charging,"Save dialog blocks gameplay input underneath")
	game.get_node("SaveFailureDialog").hide(); game._return_to_menu(); game.match_id+=1
	game.queue_free(); await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var output: String="res://builds/qa-0.22/release22-tests.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
