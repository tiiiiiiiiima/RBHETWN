extends Node
## Original DS resources, with explicit desktop event routing.
const MANIFEST_PATH = "res://assets/ds/audio/manifest.json"
const Settings = preload("res://scripts/game_settings.gd")
const FIELD_MUSIC = {
	"ds_toy": "bgm0050", "ds_pyrus": "bgm0060", "ds_aquos": "bgm0070",
	"ds_subterra": "bgm0080", "ds_haos": "bgm0090", "ds_darkus": "bgm0100",
	"ds_ventus": "bgm0110", "ds_anime": "bgm0120", "stadium": "bgm0050",
	"canyon": "bgm0060", "glacier": "bgm0070",
}
const CUES = {
	"click":"SE_SYS_KETTEI", "cancel":"SE_SYS_CANCEL", "error":"SE_SYS_ERROR",
	"power":"SE_GAM_GPOWER_UP", "throw":"SE_GAM_SHOOT_MID", "land":"SE_GAM_BG_POPOUT",
	"miss":"SE_CNT_ENB_TOUCH_FAIL", "hit":"SE_CNT_ENB_TOUCH", "win":"SE_CNT_FINISH",
	"gate_placed":"SE_GAM_GATCARD_LAND", "gate_opened":"SE_GAM_GATCARD_OP",
	"ability":"SE_CNT_ABILI_START", "g_pickup":"SE_GAM_GET_GPOWER", "s_pickup":"SE_GAM_GET_SPOWER",
	"jump":"SE_GAM_JUMPFLOOR", "trampoline":"SE_GAM_JUMPFLOOR", "speed":"SE_GAM_DUSHFLOOR",
	"impact":"SE_CNT_GEKITOTSU", "trap":"SE_AB_NOSE", "battle":"SE_BTL_START",
	"deck":"SE_DECK_CHANGE", "switch":"SE_GAM_KEYCHANGE",
}
# Curated English cues. IDs identify source clips, not inferred character names.
const VOICE_CUES = {"ability":"vo0000", "match_start":"vo0680", "battle":"vo3210", "throw":"vo0180", "land":"vo2050", "gate_opened":"vo1040", "win":"vo0370", "lose":"vo0860"}
const VOICE_PRIORITY = {"land":10,"throw":15,"gate_placed":20,"gate_opened":20,"match_start":25,"battle":25,"ability":30,"win":50,"lose":50}
## These two self-named partner lines have story evidence. Grouping the other
## numeric files into character banks would be a guess, so no such mapping is used.
const CHARACTER_VOICES = {
	"player":{"match_start":{"clip":"vo3080","species":["leonidas"],"text":"Let's do this, Leonidas!"}},
	"chara07":{"match_start":{"clip":"vo3100","species":["vladitor","battle_axe_vladitor"],"text":"You're nothing against Vladitor!"}},
}
const CAPTIONS = {"vo0000":"Ability Card, activate!","vo0180":"Bakugan brawl!","vo0680":"Field open!","vo1040":"Gate Card, open!","vo2050":"All right!","vo3210":"Battle!","vo0370":"Yes, I won!","vo0860":"I can't believe I lost!","vo3080":"Let's do this, Leonidas!","vo3100":"You're nothing against Vladitor!"}
var manifest: Dictionary = {}
var music: AudioStreamPlayer
var voice: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var settings: Dictionary = Settings.normalize({})
var muted: bool = false
var suspended: bool = false
var music_id: String = ""
var last_effect: String = ""
var last_voice: String = ""
var voice_priority: int = 0
var effect_cursor: int = 0
var _last_cue_time: Dictionary = {}
var _library: PanelContainer
var _library_backdrop: Control
var _restore_music: String = ""
var _duck: float = 1.0
var speaker: String = ""
var speaker_unit: Dictionary = {}
var caption: Label
var caption_panel: Panel
var suppressed_voice: Dictionary = {}
var translated_captions: Dictionary={}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var text_data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ds/voice_captions_ru.json"))
	if text_data is Dictionary: translated_captions=text_data.get("captions",{})
	if FileAccess.file_exists(MANIFEST_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if data is Dictionary: manifest = data
	music = _player("OriginalMusic")
	voice = _player("OriginalVoice")
	voice.finished.connect(func(): voice_priority = 0)
	for index: int in 8:
		effects.append(_player("OriginalEffect%d" % index))
	_hook_buttons(get_parent())
	get_tree().node_added.connect(_node_added)
	configure(settings)
	var layer:=CanvasLayer.new(); layer.layer=40; add_child(layer)
	caption_panel=Panel.new(); caption_panel.position=Vector2(274,700); caption_panel.size=Vector2(892,38)
	caption_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.02,0.03,0.07,0.92); style.set_corner_radius_all(8)
	caption_panel.add_theme_stylebox_override("panel",style); layer.add_child(caption_panel)
	caption=Label.new(); caption.size=caption_panel.size; caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; caption.add_theme_font_override("font",load("res://assets/ui.ttf"))
	caption.add_theme_font_size_override("font_size",18); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption_panel.add_child(caption); caption_panel.hide()

func _player(title: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = title
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player

func configure(options: Dictionary, silence: bool = false) -> void:
	settings = Settings.normalize(options)
	muted = silence
	_apply_levels()

func _process(delta: float) -> void:
	var target: float = 0.45 if is_instance_valid(voice) and voice.playing and float(settings.voice_volume)>0 and not muted else 1.0
	_duck = move_toward(_duck,target,delta*4)
	_apply_levels()
	if is_instance_valid(caption_panel):
		caption_panel.visible=bool(settings.subtitles) and voice.playing and float(settings.voice_volume)>0 and not muted and not suspended and not str(translated_captions.get(last_voice,CAPTIONS.get(last_voice,""))).is_empty()
		caption.text=str(translated_captions.get(last_voice,CAPTIONS.get(last_voice,"")))

func _level(value: float) -> float:
	return -80.0 if muted or value<=0 else linear_to_db(value)

func _apply_levels() -> void:
	if is_instance_valid(music): music.volume_db = _level(float(settings.music_volume)*_duck)
	if is_instance_valid(voice): voice.volume_db = _level(float(settings.voice_volume))
	for player: AudioStreamPlayer in effects:
		player.volume_db = _level(float(settings.effects_volume)) + float(player.get_meta("cue_db",0.0))

func set_suspended(value: bool) -> void:
	suspended = value
	for player: AudioStreamPlayer in effects + [music,voice]:
		if is_instance_valid(player): player.stream_paused = value

func set_context(context: String, arena_id: String = "ds_toy") -> void:
	if is_instance_valid(_library) and _library.is_visible_in_tree(): return
	var selected: String = "bgm0000"
	match context:
		"collection", "deck", "gates", "roster", "model", "card_view", "source_cards": selected = "bgm0010"
		"settings": selected = "bgm0020"
		"help", "training_setup", "training": selected = "SEQ_BGM_TUTORIAL"
		"battle": selected = "SEQ_BTL_BGM"
		"win": selected = "bgm0250"
		"lose": selected = "bgm0260"
		"field": selected = str(FIELD_MUSIC.get(arena_id,"bgm0050"))
	play_music(selected)

func _stream(section: String, key: String) -> AudioStream:
	var entry: Dictionary = manifest.get(section,{}).get(key,{})
	var path: String = str(entry.get("path",""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	return load(path) as AudioStream

func play_music(key: String, restart: bool = false) -> bool:
	if key == music_id and not restart: return true
	var stream: AudioStream = _stream("music",key)
	if stream == null: return false
	stream = stream.duplicate()
	var entry: Dictionary = manifest.music[key]
	if stream is AudioStreamOggVorbis:
		stream.loop = bool(entry.get("loop",true))
		stream.loop_offset = float(entry.get("loop_offset_seconds",0.0))
	music_id = key
	music.stream = stream
	music.play()
	music.stream_paused = suspended
	return true

func effect(event: String, force: bool = false) -> bool:
	if suspended or muted or float(settings.effects_volume)<=0: return false
	var key: String = str(CUES.get(event,event))
	var now: int = Time.get_ticks_msec()
	if not force and now-int(_last_cue_time.get(key,-1000)) < 75: return false
	var stream: AudioStream = _stream("effects",key)
	if stream == null: return false
	_last_cue_time[key] = now
	var player: AudioStreamPlayer = effects[effect_cursor]
	for candidate: AudioStreamPlayer in effects:
		if not candidate.playing:
			player = candidate
			break
	effect_cursor = (effects.find(player)+1)%effects.size()
	player.set_meta("cue_db",float(manifest.effects[key].get("volume_db",0.0)))
	player.stream = stream
	_apply_levels()
	player.play()
	last_effect = key
	return true

func set_speaker(id: String, unit: Dictionary = {}) -> void:
	speaker=id
	speaker_unit=unit.duplicate(true)

func voice_event(event: String) -> bool:
	if not speaker.is_empty():
		var entry: Dictionary=CHARACTER_VOICES.get(speaker,{}).get(event,{})
		if entry.is_empty() or not entry.species.has(str(speaker_unit.get("species_id",speaker_unit.get("id","")))):
			suppressed_voice={"speaker":speaker,"event":event,"reason":"No verified original character route"}
			return false
		return play_voice(str(entry.clip),int(VOICE_PRIORITY.get(event,10)))
	if not VOICE_CUES.has(event): return false
	return play_voice(str(VOICE_CUES[event]),int(VOICE_PRIORITY.get(event,10)))

func play_voice(key: String, priority: int = 10) -> bool:
	if suspended or muted or float(settings.voice_volume)<=0: return false
	if voice.playing and priority<=voice_priority: return false
	var stream: AudioStream = _stream("voices",key)
	if stream == null: return false
	voice.stream = stream
	voice_priority = priority
	voice.play()
	last_voice = key
	return true

func event(cue: String) -> void:
	effect(cue)
	voice_event(cue)

func stop_transients() -> void:
	voice.stop()
	voice_priority = 0
	for player: AudioStreamPlayer in effects: player.stop()

func _hook_buttons(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_button_sound):
		node.pressed.connect(_button_sound)
	for child: Node in node.get_children(): _hook_buttons(child)

func _node_added(node: Node) -> void:
	if node is BaseButton and get_parent().is_ancestor_of(node):
		_hook_buttons(node)

func _button_sound() -> void:
	effect("click")

func open_library() -> void:
	if not is_instance_valid(_library): _build_library()
	_restore_music = music_id
	_library_backdrop.show()
	_library_backdrop.grab_focus()

func _build_library() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_library_backdrop = Control.new()
	_library_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_library_backdrop.focus_mode = Control.FOCUS_ALL
	layer.add_child(_library_backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_library_backdrop.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_library_backdrop.add_child(center)
	_library = PanelContainer.new()
	_library.custom_minimum_size = Vector2(650,330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111a2a")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	_library.add_theme_stylebox_override("panel",style)
	center.add_child(_library)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	_library.add_child(box)
	var tip := Label.new()
	tip.text = "29 тем · 254 эффекта · 326 английских реплик\nВыбери категорию и звук для прослушивания."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	var category := OptionButton.new()
	for title: String in ["Музыка", "Эффекты", "Голоса"]: category.add_item(title)
	box.add_child(category)
	var selection := OptionButton.new()
	box.add_child(selection)
	var refill := func(_index: int = 0):
		selection.clear()
		var section: String = ["music","effects","voices"][category.selected]
		var counter: int = 0
		for key: String in manifest.get(section,{}):
			var title: String = ["Тема DS","Эффект DS","Реплика"][category.selected]+" %03d" % (counter+1)
			if key=="SEQ_BTL_BGM": title = "Музыка боя DS"
			elif key=="SEQ_BGM_TUTORIAL": title = "Музыка обучения DS"
			selection.add_item(title)
			selection.set_item_metadata(counter,key)
			counter += 1
	category.item_selected.connect(refill)
	refill.call()
	var play := Button.new()
	play.text = "ПРОСЛУШАТЬ"
	box.add_child(play)
	play.pressed.connect(func():
		if selection.selected<0: return
		var key: String = str(selection.get_item_metadata(selection.selected))
		match category.selected:
			0: play_music(key,true)
			1: effect(key,true)
			2:
				voice.stop()
				play_voice(key,100)
	)
	var close := Button.new()
	close.text = "ЗАКРЫТЬ"
	box.add_child(close)
	close.pressed.connect(_close_library)
	_library_backdrop.hide()

func _close_library() -> void:
	_library_backdrop.hide()
	stop_transients()
	play_music(_restore_music)

func _exit_tree() -> void:
	# Release queued mixer playbacks before scene teardown/replacement.
	for player: AudioStreamPlayer in effects + [music,voice]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _input(event_value: InputEvent) -> void:
	if is_instance_valid(_library) and _library.is_visible_in_tree() and event_value is InputEventKey and event_value.pressed and event_value.keycode==KEY_ESCAPE:
		_close_library()
		get_viewport().set_input_as_handled()
