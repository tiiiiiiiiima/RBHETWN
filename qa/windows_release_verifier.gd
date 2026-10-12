extends SceneTree
## Windows CI adapter of the packaged verifier: ANGLE/WARP graphics and external child-script path only.
## Game PCK, user inputs, rules, physical simulation and assertions are unchanged.
const Saves=preload("res://scripts/save_files.gd")
const Metrics=preload("res://scripts/runtime_metrics.gd")
const Store=preload("res://scripts/match_checkpoint.gd")
var output_dir: String=""
var metrics: Node
var checks: Array[Dictionary]=[]
var orchestration: bool=false
var run_id: String=""
var game: Node3D
var report: Dictionary = {"input_driven":true,"forced_landings":false,"events":[],"captures":[]}
var prefix: String = "quick"
var seen_phase: String = ""
var last_action: int = -100000
var rubbing: bool = false
var captures: Dictionary = {}
func _initialize() -> void:
	Saves.diagnostic_mode=true
	call_deferred("run")
func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
	root.push_input(event)
func key(code: int) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true
	root.push_input(event); event.pressed=false; root.push_input(event)
func capture(label: String) -> void:
	if captures.has(label): return
	captures[label]=true
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(prefix+"-"+label+".png")
	root.get_texture().get_image().save_png(path); report.captures.append(path)
func run() -> void:
	root.size=Vector2i(1440,900)
	output_dir=ProjectSettings.globalize_path("user://diagnostics/0.22/reports")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="): output_dir=arg.trim_prefix("--report-dir=")
		elif arg.begins_with("--qa-run-id="): run_id=arg.trim_prefix("--qa-run-id=")
	if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:
		push_error("Cannot create diagnostic report directory"); quit(1); return
	orchestration=not OS.get_cmdline_user_args().has("--single")
	if run_id.is_empty():
		run_id="%d-%d" % [int(Time.get_unix_time_from_system()*1000),OS.get_process_id()]
		if orchestration:
			var initial: FileAccess=FileAccess.open(output_dir.path_join("summary.json"),FileAccess.WRITE)
			if initial==null:
				push_error("Cannot create diagnostic summary"); quit(1); return
			initial.store_string(JSON.stringify({"passed":false,"in_progress":true,"run_id":run_id})); initial.close()
	if OS.get_cmdline_user_args().has("--resume"): prefix="resume"
	elif OS.get_cmdline_user_args().has("--checkpoint-and-exit"): prefix="save"
	if OS.get_cmdline_user_args().has("--campaign") and prefix=="quick": prefix="campaign"
	metrics=Metrics.new(); root.add_child(metrics)
	var load_started: int=Time.get_ticks_usec()
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	metrics.game=game; metrics.mark("main_ready",(Time.get_ticks_usec()-load_started)/1000.0)
	await process_frame
	game._set_rules_profile("ds"); game.selected_arena="ds_toy"
	game.preferences.ds_minigame="scratch"; game.muted=true; game._apply_settings()
	# Same quick-match button available in the menu, no rule mutations.
	if OS.get_cmdline_user_args().has("--resume"):
		mouse(game.overlay_resume.get_global_rect().get_center(),true); mouse(game.overlay_resume.get_global_rect().get_center(),false)
		report["resumed"]=state_facts()
		var prior: Variant=JSON.parse_string(FileAccess.get_file_as_string(output_dir.path_join("save.json")))
		verify(prior is Dictionary and prior.get("saved",{}).get("state_digest","")==report.resumed.state_digest,"Exact binary state matches after process restart")
	elif prefix in ["campaign","save"]:
		mouse(game.overlay_campaign.get_global_rect().get_center(),true); mouse(game.overlay_campaign.get_global_rect().get_center(),false)
		await capture("preparation")
		mouse(game.campaign_panel.start.get_global_rect().get_center(),true); mouse(game.campaign_panel.start.get_global_rect().get_center(),false)
	else:
		mouse(game.overlay_quick.get_global_rect().get_center(),true); mouse(game.overlay_quick.get_global_rect().get_center(),false)
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<210000 and game.phase!="finished":
		await process_frame
		if OS.get_cmdline_user_args().has("--checkpoint-and-exit") and game.phase in ["flying","rolling"] and game.flight_owner==0 and game.ds_sphere.elapsed>0.15:
			key(KEY_ESCAPE); await capture("paused-mid-throw")
			report["saved"]=state_facts()
			verify(Store.valid(Store.read()),"Paused flight checkpoint is valid")
			verify(game.checkpoint_error==OK,"Checkpoint write succeeded")
			write_report()
			if bool(report.passed):
				if orchestration: launch_next(["--resume"])
				game._quit_game()
			else:
				write_summary(); quit(1)
			return
		if game.phase!=seen_phase:
			seen_phase=game.phase
			report.events.append({"phase":seen_phase,"scores":game.rules.scores.duplicate(),"t":(Time.get_ticks_msec()-started)/1000.0})
			print("LIVE ",seen_phase," ",game.rules.scores," ",game.match_stats.summary(0))
			if seen_phase in ["aim","rolling","battle_ready","battle","result"]: await capture(seen_phase)
		if game.phase=="aim" and Time.get_ticks_msec()-last_action>600:
			last_action=Time.get_ticks_msec()
			var best: int = -1
			for value: Variant in game.rules.gates:
				if best<0 or int(value)>best: best=int(value)
			for value: Variant in game.rules.gates:
				if not game.rules.gates[value].bakugan.is_empty(): best=int(value); break
			game.field_map.prepare_map()
			var target: Vector2=game.field_map.get_global_transform_with_canvas()*game.field_map.world_to_map(game.arena.slot_position(best))
			mouse(target,true); mouse(target,false)
			await process_frame
			var ball: Vector2=game.arena.camera.unproject_position(game.ds_ready_ball.global_position)
			mouse(ball,true)
			var down_at: int = Time.get_ticks_msec()
			await create_timer(0.08).timeout
			var elapsed: float=maxf(0.08,(Time.get_ticks_msec()-down_at)/1000.0)
			var end: Vector2=ball-Vector2(0,clampf(elapsed*850.0*0.78,45,450))
			var motion := InputEventMouseMotion.new(); motion.position=end; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			root.push_input(motion); mouse(end,false)
		elif game.phase in ["place","double","stay"] and Time.get_ticks_msec()-last_action>600:
			last_action=Time.get_ticks_msec(); key(KEY_SPACE)
		elif game.phase=="battle_ready" and Time.get_ticks_msec()-last_action>600:
			last_action=Time.get_ticks_msec(); key(KEY_3); key(KEY_SPACE)
		elif game.phase=="battle":
			var point: Vector2=game.scratch.get_global_transform_with_canvas()*game.scratch.center()
			if not rubbing: mouse(point,true); rubbing=true
			var motion := InputEventMouseMotion.new()
			motion.position=point+Vector2(-40 if Engine.get_process_frames()%2==0 else 40,0)
			motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion)
			if game.battle_time>2.0 and not game.used_battle_abilities: key(KEY_3)
		elif rubbing:
			mouse(Vector2(1,1),false); rubbing=false
		if game.match_stats.summary(0).throws>=8 and game.rules.scores==[0,0]: break
	verify(game.phase=="finished" and game.rules.winner in [0,1],"A real full match reached its result")
	report["finished"]=game.phase=="finished"; report["winner"]=game.rules.winner
	report["scores"]=game.rules.scores; report["player_stats"]=game.match_stats.summary(0)
	report["enemy_stats"]=game.match_stats.summary(1); report["journal"]=game.journal
	if game.match_mode=="campaign": report["campaign_progress"]=game.campaign.to_dict()
	var stored: Dictionary={"wins":game.wins,"losses":game.losses,"campaign":game.campaign.to_dict()}
	game._save_profile(); verify(game.profile_error==OK,"Profile write succeeded")
	game._load_profile()
	verify(stored=={"wins":game.wins,"losses":game.losses,"campaign":game.campaign.to_dict()},"Results and rewards survive profile reload")
	verify(Store.read().is_empty(),"Completed match leaves no stale resume")
	await capture("final")
	write_report()
	if orchestration and prefix=="quick" and bool(report.passed): launch_next(["--campaign","--checkpoint-and-exit"])
	elif prefix=="resume" or not bool(report.passed): write_summary()
	game.match_id+=1; game.queue_free(); await process_frame
	quit(0 if bool(report.get("passed",false)) else 1)

func state_facts() -> Dictionary:
	var facts: Dictionary={"phase":game.phase,"position":game.ds_sphere.position,"velocity":game.ds_sphere.velocity,"scores":game.rules.scores.duplicate(),"chapter":game.campaign_chapter,"elapsed":game.ds_sphere.elapsed,"rng_state":game.rng.state,"collected":Store.capture(game).get("field",{}).get("collected",[])}
	facts["state_digest"]=Store._digest(var_to_bytes(facts))
	facts.position=str(facts.position); facts.velocity=str(facts.velocity); facts.rng_state=str(facts.rng_state)
	return facts
func verify(value: bool,label: String) -> void:
	checks.append({"passed":value,"label":label})
	if not value: push_error(label)
func write_report() -> void:
	report["run_id"]=run_id
	report["version"]=str(ProjectSettings.get_setting("application/config/version"))
	report["metrics"]=metrics.report(); report["checks"]=checks
	report["passed"]=checks.all(func(value: Dictionary) -> bool: return value.passed)
	report["input_driven"]=true; report["forced_landings"]=false; report["forced_winner"]=false
	report["diagnostic_profile"]=ProjectSettings.globalize_path(Saves.resolve("user://profile.cfg"))
	var file: FileAccess=FileAccess.open(output_dir.path_join(prefix+".json"),FileAccess.WRITE)
	if file==null:
		report.passed=false; push_error("Cannot write diagnostic report"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RELEASE CHECK ",prefix," ",report.passed," ",report.get("scores",[]))
func launch_next(stage: Array[String]) -> void:
	var arguments: PackedStringArray=[]
	if OS.get_name()=="Linux": arguments.append_array(["--audio-driver","Dummy"])
	if OS.get_name()=="Windows":
		arguments.append_array(["--rendering-method","gl_compatibility","--rendering-driver","opengl3_angle","--audio-driver","Dummy"])
	var pack: String=OS.get_executable_path().get_basename()+".pck"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-pack="): pack=arg.trim_prefix("--qa-pack=")
	if FileAccess.file_exists(pack): arguments.append_array(["--main-pack",pack])
	else: arguments.append_array(["--path",ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--script",get_script().resource_path,"--log-file",output_dir.path_join("engine-"+("resume" if stage.has("--resume") else "save")+".log"),"--","--verify-release","--qa-pack="+pack,"--qa-run-id="+run_id,"--report-dir="+output_dir])
	arguments.append_array(stage)
	var pid: int=OS.create_process(OS.get_executable_path(),arguments)
	verify(pid>0,"Next verification process starts")
	write_report()
func write_summary() -> void:
	var stages: Dictionary={}; var passed: bool=true
	for name: String in ["quick","save","resume"]:
		var path: String=output_dir.path_join(name+".json")
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		stages[name]=value if value is Dictionary else {}
		passed=passed and bool(stages[name].get("passed",false)) and str(stages[name].get("run_id",""))==run_id
	var summary: Dictionary={"version":str(ProjectSettings.get_setting("application/config/version")),"passed":passed,"os":OS.get_name(),"windows_execution_tested":OS.get_name()=="Windows","process_restart_tested":not stages.resume.is_empty(),"physical_gamepad_tested":false,"in_progress":false,"run_id":run_id,"stages":stages}
	var file: FileAccess=FileAccess.open(output_dir.path_join("summary.json"),FileAccess.WRITE)
	if file==null: push_error("Cannot write final summary"); quit(1); return
	file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("RELEASE SUITE ",passed," · ",OS.get_name())
