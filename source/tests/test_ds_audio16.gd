extends SceneTree
const Director = preload("res://scripts/ds_audio.gd")
const Settings = preload("res://scripts/game_settings.gd")
var checks: int = 0
var failures: Array[String] = []
var samples_peak: float = 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _run() -> void:
	var scope := Node.new()
	root.add_child(scope)
	var audio = Director.new()
	scope.add_child(audio)
	AudioServer.set_bus_mute(0,false)
	AudioServer.set_bus_volume_db(0,-6)
	check(audio.manifest.counts == {"music":29.0,"effects":254.0,"voices":326.0},"Complete source bank counts")
	for section: String in ["music","effects","voices"]:
		for key: String in audio.manifest[section]:
			var stream: AudioStream = audio._stream(section,key)
			check(stream is AudioStreamOggVorbis and stream.get_length()>0,"Imported sound decodes: "+key)
	for key: String in Director.CUES.values(): check(audio.manifest.effects.has(key),"Mapped native cue present: "+key)
	for key: String in Director.VOICE_CUES.values(): check(audio.manifest.voices.has(key),"Curated voice present: "+key)
	audio.set_context("menu")
	check(audio.music.playing and audio.music_id=="bgm0000","Menu starts original music")
	await create_timer(0.1).timeout
	var before: float = audio.music.get_playback_position()
	audio.set_context("menu")
	check(audio.music.get_playback_position()>=before,"Same context does not restart music")
	check(audio.music.stream.loop and is_equal_approx(audio.music.stream.loop_offset,float(audio.manifest.music.bgm0000.loop_offset_seconds)),"Native intro and loop offset retained")
	for theme: String in Director.FIELD_MUSIC:
		audio.set_context("field",theme)
		check(audio.music.playing and audio.music_id==Director.FIELD_MUSIC[theme],"Field has source music: "+theme)
	audio.set_context("battle")
	check(audio.music_id=="SEQ_BTL_BGM" and audio.music.stream.loop_offset>6,"Native battle stereo intro/loop")
	audio.set_context("training")
	check(audio.music_id=="SEQ_BGM_TUTORIAL","Native tutorial music")
	check(audio.effect("gate_placed",true),"Placement has native effect")
	check(audio.voice_event("ability"),"Ability speaks original English cue")
	check(audio.music.playing and audio.voice.playing and audio.effects.any(func(p): return p.playing),"Music, effect and voice play concurrently")
	check(not audio.voice_event("throw"),"Same/lower priority cannot interrupt spoken line")
	audio.set_suspended(true)
	check(audio.music.stream_paused and audio.voice.stream_paused and audio.effects.all(func(p): return not p.playing or p.stream_paused),"Pause suspends every channel")
	check(not audio.effect("hit",true) and not audio.voice_event("win"),"Paused actions cannot emit sounds")
	audio.set_suspended(false)
	audio.configure({"music_volume":0.2,"effects_volume":0.0,"voice_volume":0.0})
	check(not audio.effect("hit",true) and not audio.play_voice("vo0000"),"Channel mute blocks new sounds")
	check(audio.voice.volume_db<=-80 and audio.effects.all(func(p): return p.volume_db<=-80),"Channel mute silences already playing sounds")
	check(audio.music.volume_db>-80,"Muted effects/voice leave music audible")
	audio.configure({},true)
	check(audio.music.volume_db<=-80,"Global silence mutes music too")
	audio.configure({})
	audio.stop_transients()
	var original_theme: String = audio.music_id
	audio.open_library()
	check(audio._library.is_visible_in_tree(),"Sound library opens inside game")
	audio.play_music("bgm0030",true)
	audio.set_context("battle")
	check(audio.music_id=="bgm0030","Game context cannot interrupt library preview")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	audio._input(escape)
	check(not audio._library.is_visible_in_tree() and audio.music_id==original_theme,"Escape closes library and restores previous music")
	var button := Button.new()
	scope.add_child(button)
	button.pressed.emit()
	check(audio.last_effect=="SE_SYS_KETTEI","New UI buttons use original confirm effect")
	check(not audio.effect("missing-source-cue",true),"Missing sounds fail safely")
	# Check actual PCM emitted by the engine, rather than only player flags.
	AudioServer.add_bus()
	var bus: int = AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"DSValidation")
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus,capture)
	audio.music.bus = "DSValidation"
	audio.play_music("SEQ_BTL_BGM")
	await create_timer(0.4).timeout
	var pcm: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	for frame: Vector2 in pcm:
		samples_peak = maxf(samples_peak,maxf(absf(frame.x),absf(frame.y)))
	check(pcm.size()>0 and samples_peak>0.0001,"Original music produces non-silent mixer PCM")
	audio.music.bus = "Master"
	AudioServer.remove_bus(bus)
	scope.queue_free()
	await process_frame
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.muted = false
	game._apply_settings()
	game._sync_audio_context()
	check(game.audio.music_id=="bgm0000","Real main menu routes music")
	game._open_settings()
	game._sync_audio_context()
	check(game.audio.music_id=="bgm0020" and game.channel_sliders.size()==3,"Settings route music and expose three channel controls")
	game._set_channel_volume(0.25,"voice_volume")
	var saved: String = "user://audio-test16.cfg"
	game._save_profile(saved)
	game.preferences = Settings.normalize({})
	game._load_profile(saved)
	check(is_equal_approx(game.preferences.voice_volume,0.25),"Channel volume persists in existing profile schema")
	game._set_rules_profile("ds")
	game.start_match()
	game.audio.stop_transients()
	game._place_player_gate(5)
	check(game.audio.last_effect=="SE_GAM_GATCARD_LAND","Real DS gate placement routes native sound")
	game._sync_audio_context()
	check(game.audio.music_id==Director.FIELD_MUSIC[str(game.arena.theme_id)],"Real DS match routes field music")
	game._toggle_pause()
	check(game.audio.suspended and game.audio.music.stream_paused,"Real game pause suspends music")
	game._toggle_pause()
	check(not game.audio.suspended,"Real game resume releases music")
	game._show_menu()
	check(not game.audio.voice.playing,"Returning to menu clears stale speech")
	game.queue_free()
	await process_frame
	var duel = load("res://anime_duel.tscn").instantiate()
	root.add_child(duel)
	duel.set_process(false)
	duel.auto_ai = false
	check(duel.audio != null and not duel.audio.suspended,"Anime preparation has an active audio director")
	duel.start_match(160)
	duel.audio.stop_transients()
	duel._handle_result({"ok":true,"event":"ability_played","owner":0,"title":"Test"})
	check(duel.audio.last_effect=="SE_CNT_ABILI_START" and not duel.audio.voice.playing and not duel.audio.suppressed_voice.is_empty(),"Anime effect plays without assigning an unidentified voice to its avatar")
	duel._set_paused(true)
	check(duel.audio.suspended,"Anime pause suspends audio")
	duel._set_paused(false)
	check(not duel.audio.suspended,"Anime resume restores audio")
	duel.queue_free()
	await process_frame
	var result: Dictionary = {"checks":checks,"failures":failures,"mixer_peak":samples_peak,"godot":Engine.get_version_info(),"windows_execution_tested":false}
	FileAccess.open("/workspace/bakugan-pc/builds/qa-0.16/audio-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("DS AUDIO 0.16: %d checks; %d failures; mixer peak %.5f" % [checks,failures.size(),samples_peak])
	quit(0 if failures.is_empty() else 1)
