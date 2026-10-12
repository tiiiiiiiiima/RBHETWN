extends SceneTree
## Repeated gameplay events must restart actions without changing another
## participant's animation or the imported source's loop and pose tracks.

const Models = preload("res://scripts/model_library.gd")
const Catalog = preload("res://scripts/ds_model_catalog.gd")
const Presentation = preload("res://scripts/ds_battle_presentation.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _player(creature: Node3D) -> AnimationPlayer:
	var result: AnimationPlayer = creature.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	result.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return result


func _run() -> void:
	var presentation: Control = Presentation.new()
	presentation._load_native_ui()
	for pair: Array in [["Delta Dragonoid II", "Delta Dragonoid"], ["Fortress", "Fourtress"], ["Battle Axe Vladitor", "Battle Ax Vladitor"]]:
		var canonical: Texture2D = presentation._portrait_texture(str(pair[1]), "Aquos")
		_check(canonical != null, "The canonical DS portrait exists: " + str(pair[1]))
		_check(presentation._portrait_texture(str(pair[0]), "Aquos") == canonical, "A supported source/model alias resolves to the same DS portrait: " + str(pair[0]))
	_check(presentation._portrait_texture("Dragonoid", "aquos") == presentation._portrait_texture("Dragonoid", "Aquos"), "Portrait palette matching follows the model resolver's case-insensitive attribute matching")
	presentation.free()
	var definition: Dictionary = Catalog.resolve("Dragonoid", "Pyrus")
	var source: Node3D = (load(str(definition.path)) as PackedScene).instantiate() as Node3D
	var source_player: AnimationPlayer = _player(source)
	var idle_name: String = str(definition.animation_roles.idle)
	var source_idle: Animation = source_player.get_animation(idle_name)
	var source_loop: Animation.LoopMode = source_idle.loop_mode
	var source_position: Vector3 = source_idle.track_get_key_value(Models._torso_position_track(source_idle), 0)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var first: Node3D = Models.make_creature(stage, "Dragonoid", "Pyrus", true, "battle")
	var second: Node3D = Models.make_creature(stage, "Dragonoid", "Pyrus", true, "battle")
	var first_player: AnimationPlayer = _player(first)
	var second_player: AnimationPlayer = _player(second)
	_check(source_idle.loop_mode == source_loop, "Starting runtime idle must preserve the native source loop")
	_check(first_player.get_animation(idle_name).loop_mode == Animation.LOOP_LINEAR, "The first participant has a looping runtime idle")
	_check(second_player.get_animation(idle_name).loop_mode == Animation.LOOP_LINEAR, "The second participant has a looping runtime idle")
	first_player.advance(0.3)
	var idle_time: float = first_player.current_animation_position
	Models.play_battle_animation(first, "idle")
	_check(is_equal_approx(first_player.current_animation_position, idle_time), "Score refresh must retain the current idle time")
	Models.play_battle_animation(second, idle_name)
	_check(second_player.get_animation(idle_name).loop_mode == Animation.LOOP_NONE, "An explicitly requested one-shot clip stops looping on its own actor")
	_check(first_player.get_animation(idle_name).loop_mode == Animation.LOOP_LINEAR, "A second participant's one-shot clip must not disable the first participant's idle loop")
	_check(source_idle.loop_mode == source_loop, "A one-shot request must preserve the imported source loop")
	_check(first_player.get_animation(idle_name) != second_player.get_animation(idle_name), "Participants own independent changed animation resources")
	_check(source_idle.track_get_key_value(Models._torso_position_track(source_idle), 0) == source_position, "Loop isolation must retain the original native trajectory")
	_check(Models.play_battle_animation(first, "attack"), "The reviewed native attack can start")
	first_player.advance(0.4)
	var advanced_time: float = first_player.current_animation_position
	_check(advanced_time > 0.3, "The first attack has progressed before a new hit")
	_check(Models.play_battle_animation(first, "attack"), "A new gameplay hit can start the same attack again")
	first_player.advance(0.0)
	_check(is_zero_approx(first_player.current_animation_position), "A repeated hit restarts the attack instead of reusing its old time")
	_check(first_player.animation_finished.get_connections().size() == 1, "Repeated actions retain exactly one idle-return connection")
	_check(Models.play_battle_animation(second, "attack"), "The other participant can attack independently")
	second_player.advance(0.2)
	first_player.advance(0.1)
	Models.play_battle_animation(first, "attack")
	first_player.advance(0.0)
	_check(is_equal_approx(second_player.current_animation_position, 0.2), "Restarting one attack must retain another participant's action time")
	var duration: float = first_player.current_animation_length
	var remaining: float = duration + 0.02
	while remaining > 0.000001:
		var step: float = minf(remaining, 1.0 / 120.0)
		first_player.advance(step)
		remaining -= step
	_check(first_player.current_animation == idle_name and first_player.is_playing(), "The restarted attack still returns to idle when it finishes")
	_check(source_idle.loop_mode == source_loop, "Completing an attack must preserve the imported source loop")
	stage.queue_free()
	source.free()
	await process_frame
	await process_frame
	print("DS VISUAL REGRESSIONS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
