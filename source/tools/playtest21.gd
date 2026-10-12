extends SceneTree
## Operate the real GUI and let the live controller/physics decide outcomes.
var game: Node3D
var report: Dictionary = {"input_driven":true,"forced_landings":false,"events":[],"captures":[]}
var prefix: String = "lesson"
var seen_phase: String = ""
var last_action: int = -100000
var rubbing: bool = false
var captures: Dictionary = {}
var gamepad: bool=false
var pad_direction: float=1.0
func _initialize() -> void:
	call_deferred("run")
func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
	root.push_input(event)
func key(code: int) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true
	root.push_input(event); event.pressed=false; root.push_input(event)
func pad(index: int,down: bool=true) -> void:
	var event:=InputEventJoypadButton.new(); event.button_index=index; event.pressed=down
	root.push_input(event)
func tap(index: int) -> void:
	pad(index,true); pad(index,false)
func axis(index: int,amount: float) -> void:
	var event:=InputEventJoypadMotion.new(); event.axis=index; event.axis_value=amount
	root.push_input(event)
func next_step() -> void:
	if gamepad: tap(JOY_BUTTON_A)
	else:
		mouse(game.tutorial.next.get_global_rect().get_center(),true); mouse(game.tutorial.next.get_global_rect().get_center(),false)
func capture(label: String) -> void:
	if captures.has(label): return
	captures[label]=true
	await RenderingServer.frame_post_draw
	var path: String = "/workspace/bakugan-pc/builds/qa-0.21/visual/"+prefix+"-"+label+".png"
	root.get_texture().get_image().save_png(path); report.captures.append(path)
func run() -> void:
	root.size=Vector2i(1440,900)
	gamepad=OS.get_cmdline_user_args().has("--gamepad")
	if gamepad: prefix="gamepad"
	if OS.get_cmdline_user_args().has("--after"): prefix="updated"
	if OS.get_cmdline_user_args().has("--campaign"): prefix="campaign"
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game._set_rules_profile("ds"); game.selected_arena="ds_toy"
	game.preferences.ds_minigame="scratch"; game.muted=true; game._apply_settings()
	game._open_settings()
	for index: int in game.settings_panel.tabs.get_tab_count():
		game.settings_panel.tabs.current_tab=index
		await process_frame
		await capture("settings-%d" % index)
	game._close_preparation()
	game._open_training()
	await capture("training-menu")
	game._start_guided_lesson()
	await capture("lesson-intro")
	next_step()
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<210000 and game.phase!="finished" and bool(game.tutorial.active):
		await process_frame
		if OS.get_cmdline_user_args().has("--checkpoint-and-exit") and game.phase in ["flying","rolling"] and game.flight_owner==0 and game.ds_sphere.elapsed>0.15:
			key(KEY_ESCAPE); await capture("paused-mid-throw")
			report["saved"]={"phase":game.phase,"position":str(game.ds_sphere.position),"velocity":str(game.ds_sphere.velocity),"scores":game.rules.scores.duplicate(),"chapter":game.campaign_chapter}
			FileAccess.open("res://builds/qa-0.21/campaign-pause.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			game._quit_game(); return
		if game.phase!=seen_phase:
			seen_phase=game.phase
			report.events.append({"phase":seen_phase,"scores":game.rules.scores.duplicate(),"t":(Time.get_ticks_msec()-started)/1000.0})
			print("LIVE ",seen_phase," ",game.rules.scores," ",game.match_stats.summary(0))
			if seen_phase in ["aim","rolling","battle_ready","battle","result"]: await capture(seen_phase)
		if game.phase=="aim" and Time.get_ticks_msec()-last_action>600:
			last_action=Time.get_ticks_msec()
			if gamepad:
				tap(JOY_BUTTON_DPAD_RIGHT); tap(JOY_BUTTON_DPAD_LEFT)
				axis(JOY_AXIS_LEFT_X,0.4)
				await create_timer(0.05).timeout
				axis(JOY_AXIS_LEFT_X,0.0)
				pad(JOY_BUTTON_A,true)
				while game.phase=="aim" and game.charge<0.73: await process_frame
				pad(JOY_BUTTON_A,false)
			else:
				key(KEY_1)
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
			last_action=Time.get_ticks_msec()
			if game.tutorial.next.visible:
				await capture("lesson-%d" % game.tutorial.step)
				next_step()
			else:
				if gamepad:
					tap(JOY_BUTTON_DPAD_RIGHT); tap(JOY_BUTTON_DPAD_RIGHT); tap(JOY_BUTTON_DPAD_LEFT)
					tap(JOY_BUTTON_A)
				else: key(KEY_3); key(KEY_SPACE)
		elif game.phase=="battle":
			if gamepad:
				if not rubbing: pad(JOY_BUTTON_A,true); rubbing=true
				var x: float=game.controls.virtual_cursor.x
				if x>game.scratch.center().x+28: pad_direction=-1.0
				elif x<game.scratch.center().x-28: pad_direction=1.0
				axis(JOY_AXIS_LEFT_X,pad_direction*0.9)
				if game.battle_time>2.0 and not game.used_battle_abilities: tap(JOY_BUTTON_DPAD_RIGHT)
			else:
				var point: Vector2=game.scratch.get_global_transform_with_canvas()*game.scratch.center()
				if not rubbing: mouse(point,true); rubbing=true
				var motion := InputEventMouseMotion.new()
				motion.position=point+Vector2(-40 if Engine.get_process_frames()%2==0 else 40,0)
				motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion)
				if game.battle_time>2.0 and not game.used_battle_abilities: key(KEY_3)
		elif game.tutorial.step==9:
			await capture("lesson-result")
			next_step()
		elif rubbing:
			if gamepad: pad(JOY_BUTTON_A,false); axis(JOY_AXIS_LEFT_X,0.0)
			else: mouse(Vector2(1,1),false)
			rubbing=false
		if game.match_stats.summary(0).throws>=8 and game.rules.scores==[0,0]: break
	report["controller_events_injected"]=gamepad; report["physical_gamepad_tested"]=false; report["tutorial_completed"]=bool(game.preferences.tutorial_completed); report["finished"]=game.phase=="finished"; report["winner"]=game.rules.winner
	report["scores"]=game.rules.scores; report["player_stats"]=game.match_stats.summary(0)
	report["enemy_stats"]=game.match_stats.summary(1); report["journal"]=game.journal
	if prefix=="campaign": report["campaign_progress"]=game.campaign.to_dict()
	await capture("final")
	FileAccess.open("res://builds/qa-0.21/"+prefix+"-play.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game._return_to_menu(); await capture("menu-final"); game.match_id+=1; game.queue_free(); await process_frame
	quit()
