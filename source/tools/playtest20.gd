extends SceneTree
## Operate the real GUI and let the live controller/physics decide outcomes.
var game: Node3D
var report: Dictionary = {"input_driven":true,"forced_landings":false,"events":[],"captures":[]}
var prefix: String = "baseline"
var seen_phase: String = ""
var last_action: int = -100000
var rubbing: bool = false
var captures: Dictionary = {}
func _initialize() -> void:
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
	var path: String = "/workspace/bakugan-pc/builds/qa-0.20/visual/"+prefix+"-"+label+".png"
	root.get_texture().get_image().save_png(path); report.captures.append(path)
func run() -> void:
	root.size=Vector2i(1440,900)
	if OS.get_cmdline_user_args().has("--after"): prefix="updated"
	if OS.get_cmdline_user_args().has("--campaign"): prefix="campaign"
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game._set_rules_profile("ds"); game.selected_arena="ds_toy"
	game.preferences.ds_minigame="scratch"; game.muted=true; game._apply_settings()
	# Same quick-match button available in the menu, no rule mutations.
	if OS.get_cmdline_user_args().has("--resume"):
		mouse(game.overlay_resume.get_global_rect().get_center(),true); mouse(game.overlay_resume.get_global_rect().get_center(),false)
		report["resumed"]={"phase":game.phase,"position":str(game.ds_sphere.position),"velocity":str(game.ds_sphere.velocity),"scores":game.rules.scores.duplicate(),"chapter":game.campaign_chapter}
	elif prefix=="campaign":
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
			report["saved"]={"phase":game.phase,"position":str(game.ds_sphere.position),"velocity":str(game.ds_sphere.velocity),"scores":game.rules.scores.duplicate(),"chapter":game.campaign_chapter}
			FileAccess.open("res://builds/qa-0.20/campaign-pause.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			game._quit_game(); return
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
	report["finished"]=game.phase=="finished"; report["winner"]=game.rules.winner
	report["scores"]=game.rules.scores; report["player_stats"]=game.match_stats.summary(0)
	report["enemy_stats"]=game.match_stats.summary(1); report["journal"]=game.journal
	if prefix=="campaign": report["campaign_progress"]=game.campaign.to_dict()
	await capture("final")
	FileAccess.open("res://builds/qa-0.20/"+prefix+"-play.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.match_id+=1; game.queue_free(); await process_frame
	quit()
