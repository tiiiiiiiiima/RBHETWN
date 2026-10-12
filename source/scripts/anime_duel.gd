extends Node3D
## Strategic anime duel with a separate deck and the shared field renderer.

const DuelRules = preload("res://scripts/anime_duel_rules.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")
const Arena = preload("res://scripts/arena.gd")
const ArenaCatalog = preload("res://scripts/arena_catalog.gd")
const Roster = preload("res://scripts/roster.gd")
const BoardLayout = preload("res://scripts/board_layout.gd")
const ThrowMotion = preload("res://scripts/throw_motion.gd")
const RollMotion = preload("res://scripts/roll_motion.gd")
const Settings = preload("res://scripts/game_settings.gd")
const Browser = preload("res://scripts/source_card_browser.gd")
const Traps = preload("res://scripts/anime_trap_catalog.gd")
const DSBattle = preload("res://scripts/ds_battle_presentation.gd")
const Controls = preload("res://scripts/control_bindings.gd")
const Avatar = preload("res://scripts/avatar_view.gd")
var controls = Controls.new()
var player_avatar: SubViewportContainer
var enemy_avatar: SubViewportContainer
var pad_select_time: float = 0.0

const Checkpoint = preload("res://scripts/match_checkpoint.gd")
const AnimeCheckpoint = preload("res://scripts/anime_checkpoint.gd")
const WHITE: Color = Color("f0f1fc")
const MUTED: Color = Color("a1acc8")
const ORANGE: Color = Color("ffae68")
const CYAN: Color = Color("65e0ff")
const PANEL: Color = Color("111a2a")
const DECK_PATH: String = "user://anime_deck.cfg"

var audio: Node
var rules = DuelRules.new()
var arena: Node3D
var preferences: Dictionary = Settings.normalize({})
var arena_id: String = "anime_board"
var throw_style: String = "lob"
var selected_team: Array = []
var selected_unit: int = 0
var selected_gate: int = -1
var selected_caster: int = -1
var selected_target: int = -1
var selected_target_owner: int = 1
var selected_ability: String = ""
var aim_point: Vector3 = Vector3.ZERO
var aim_slot: int = -1
var charge: float = 0.0
var charging: bool = false
var paused: bool = false
var auto_ai: bool = true
var started: bool = false
var visual_phase: String = "deck"
var flight_duration_scale: float = 1.0
var roll_duration: float = 3.2
var last_throw_slot: int = -1
var gate_loadout: Array = []
var ability_loadout: Array = []
var support_selection: Variant = null
var _flight_ball: Node3D
var _flight_owner: int = 0
var _flight_unit: int = 0
var _flight_start: Vector3
var _flight_end: Vector3
var _flight_target: Vector3
var _flight_style: String = "lob"
var _flight_charge: float = 0.0
var _flight_time: float = 0.0
var _flight_trap_action: bool = false
var _roll = RollMotion.new()
var _roll_previous: Vector3
var _unit_nodes: Dictionary = {}
var _support_nodes: Dictionary = {}
var _gate_signatures: Dictionary = {}
var _ai_time: float = 0.0
var _camera_battle_slot: int = -1
var _message: String = ""
var _journal: Array[String] = []
var _trajectory_cache_key: Array = []
var _trajectory: MeshInstance3D
var hud: Control
var _title: Label
var _hint: Label
var _status: Label
var _unit_buttons: Array[Button] = []
var _stand_destination: OptionButton
var _stand_button: Button
var _style_button: Button
var _charge_bar: ProgressBar
var _side_title: Label
var _battle_label: Label
var _caster_select: OptionButton
var _target_select: OptionButton
var _activate_button: Button
var _hand_grid: VBoxContainer
var _open_button: Button
var _pass_button: Button
var _end_button: Button
var _trap_button: Button
var _trap_prepare_button: Button
var _trap_status: Label
var _log: Label
var _pause_panel: PanelContainer
var _modal_blocker: ColorRect
var _result_input_locked: bool = false
var _deck_panel: PanelContainer
var _deck_error: Label
var _gate_selectors: Array[OptionButton] = []
var _ability_selectors: Array[OptionButton] = []
var _support_selector: OptionButton
var _support_attribute: OptionButton
var _support_info: Label
var _team_info: RichTextLabel
var _trap_options: Dictionary = {}
var _trap_choice_box: VBoxContainer
var _trap_choice_selectors: Dictionary = {}
var _trap_action_box: VBoxContainer
var _trap_action_incoming: OptionButton
var _trap_action_outgoing: OptionButton
var _trap_action_destination: OptionButton
var _trap_action_button: Button
var _trap_action_hint: Label
var _side_scroll: ScrollContainer
var _browser: Control
var battle_presentation: Control
var resume_data: Dictionary = {}
var save_slot: String="anime_1"
const Slots=preload("res://scripts/save_slots.gd")
var _save_clock: float = 0.0
var _saved_phase: String = ""
var _save_error: Error = OK
var _deck_save_error: Error = OK


func configure(team0: Array, selected_arena: String, options: Dictionary, style: String) -> void:
	selected_team = team0.duplicate(true)
	arena_id = ArenaCatalog.normalize_id(selected_arena)
	preferences = Settings.normalize(options)
	throw_style = ThrowMotion.normalize_style(style)


func _on_joy_connection_changed(_id: int, connected: bool) -> void:
	controls.reset()
	if not connected:
		_cancel_charge()

func _ready() -> void:
	if selected_team.size() != 3:
		selected_team = Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"])
	else:
		selected_team = Roster.canonicalize_team(selected_team)
	arena = Arena.new()
	add_child(arena)
	arena.native_physics = false
	arena.setup()
	arena.set_theme(arena_id)
	arena.set_reduced_motion(preferences.get("reduced_motion", false))
	arena.camera.h_offset = 2.2
	_trajectory = MeshInstance3D.new()
	_trajectory.name = "ThrowPreview"
	add_child(_trajectory)
	_build_ui()
	Settings.apply_graphics(get_viewport(),preferences)
	battle_presentation.viewport.scaling_3d_scale=float(preferences.render_scale)
	battle_presentation.viewport.msaa_3d=get_viewport().msaa_3d
	player_avatar=Avatar.new(); player_avatar.position=Vector2(24,573); player_avatar.size=Vector2(156,170)
	hud.add_child(player_avatar); player_avatar.show_avatar(str(preferences.avatar))
	enemy_avatar=Avatar.new(); enemy_avatar.position=Vector2(848,573); enemy_avatar.size=Vector2(156,170)
	hud.add_child(enemy_avatar); enemy_avatar.show_avatar("chara00")
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	audio = preload("res://scripts/ds_audio.gd").new()
	add_child(audio)
	audio.configure(preferences)
	audio.set_speaker(str(preferences.avatar))
	AudioServer.set_bus_mute(0,float(preferences.volume)<=0)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(float(preferences.volume),0.0001)))
	_load_deck()
	_build_deck_editor()
	_show_deck()
	get_tree().auto_accept_quit=false
	if Slots.kind(save_slot)!="anime": save_slot="anime_1"
	Checkpoint.active_slot=save_slot
	if not resume_data.is_empty():
		if not AnimeCheckpoint.restore(self,resume_data): _deck_error.text="Не удалось восстановить аниме-дуэль."
		resume_data.clear()


func _process(delta: float) -> void:
	if is_instance_valid(player_avatar):
		player_avatar.visible=started and rules.phase=="battle" and not _deck_panel.visible
		enemy_avatar.visible=player_avatar.visible
		player_avatar.set_suspended(paused or not player_avatar.visible)
		enemy_avatar.set_suspended(paused or not enemy_avatar.visible)
	pad_select_time=maxf(0.0,pad_select_time-delta)
	if started and not paused and not _deck_panel.visible and not _browser.visible and rules.turn==0 and pad_select_time<=0.0:
		var direction: Vector2=Vector2(controls.axis(JOY_AXIS_LEFT_X),controls.axis(JOY_AXIS_LEFT_Y))
		if direction.length()>float(preferences.gamepad_deadzone)+0.3:
			_pad_target(-1 if (direction.x if absf(direction.x)>absf(direction.y) else direction.y)<0 else 1)
			pad_select_time=0.25
	_save_clock+=delta
	if started and (_save_clock>=3.0 or _saved_phase!=rules.phase): _save_match()
	if is_instance_valid(audio):
		audio.set_context("deck" if _deck_panel.visible else ("collection" if _browser.visible else ("win" if rules.winner==0 else "lose") if rules.phase=="finished" else "battle" if rules.phase in ["battle","chain"] else "field"),arena_id)
	if is_instance_valid(battle_presentation):
		battle_presentation.set_suspended(paused or not started or _browser.visible or _deck_panel.visible or visual_phase in ["flying", "rolling"] or _battle_needs_board())
	if paused or not started or _browser.visible or _deck_panel.visible:
		return
	if _result_input_locked and not battle_presentation.is_result_playing():
		_refresh_ui()
	if battle_presentation.is_result_playing():
		return
	if visual_phase == "flying":
		_update_flight(delta)
		return
	if visual_phase == "rolling":
		_update_roll(delta)
		return
	if charging:
		charge = minf(1.0, charge + delta * 0.70)
		_charge_bar.value = charge * 100.0
	if _can_player_throw() and selected_gate < 0:
		_draw_preview()
	else:
		_trajectory.visible = false
	if not auto_ai or rules.phase == "finished":
		return
	var pending: Dictionary = rules.pending_trap_action()
	var acting: int = int(pending.owner) if not pending.is_empty() else int(rules.battle.get("priority", -1)) if rules.phase == "battle" else int(rules.turn)
	if acting == 1:
		_ai_time += delta
		if _ai_time >= 0.7:
			_ai_time = 0.0
			_ai_action()
	else:
		_ai_time = 0.0


func _input(event: InputEvent) -> void:
	var save_dialog: Window=get_node_or_null("SaveFailureDialog") as Window
	if save_dialog!=null and save_dialog.visible: return
	controls.record(event)
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START and started:
		_set_paused(not paused); get_viewport().set_input_as_handled(); return
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B:
		if paused: _set_paused(false); get_viewport().set_input_as_handled(); return
		if _browser.visible: _browser.close_browser(); get_viewport().set_input_as_handled(); return
	if started and not paused and not _deck_panel.visible and not _browser.visible and rules.phase in ["opening","turn"] and event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_A:
			if selected_gate>=0: _try_place_gate(aim_slot)
			else: _begin_charge()
			get_viewport().set_input_as_handled()
		elif event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
			_select_unit(posmod(selected_unit+(-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1),3))
			get_viewport().set_input_as_handled()

func _pad_target(direction: int) -> void:
	var options: Array=rules.legal_gate_slots() if selected_gate>=0 else rules.gates.keys()
	options.sort()
	if options.is_empty(): return
	aim_slot=int(options[posmod(options.find(aim_slot)+direction,options.size())])
	aim_point=BoardLayout.POSITIONS[aim_slot]
	arena.highlight_target(aim_slot)
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey: event=Controls.remap(event,preferences)
	if _browser.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _deck_panel.visible:
			return
		_set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused or not started or _deck_panel.visible or visual_phase in ["flying", "rolling"]:
		return
	if battle_presentation.is_result_playing():
		return
	if event is InputEventKey and not event.echo:
		if event.pressed and event.keycode in [KEY_1, KEY_2, KEY_3]:
			_select_unit(int(event.keycode) - KEY_1)
		elif event.keycode == KEY_SPACE and _can_player_throw():
			if event.pressed:
				_begin_charge()
	if event is InputEventMouseMotion:
		_set_aim_from_screen(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_aim_from_screen(event.position)
		if selected_gate >= 0 and rules.phase in ["opening", "turn"] and rules.turn == 0:
			_try_place_gate(aim_slot)
		elif _can_player_throw():
			_place_unit_on_gate(0, selected_unit, aim_slot)


func start_match(seed_value: int = 0) -> Dictionary:
	_cancel_flight()
	var opponent: Array = Roster.make_anime_opponent(0)
	var seed_number: int = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	var result: Dictionary = rules.new_match(selected_team, opponent, seed_number,
		[gate_loadout, Cards.default_gate_loadout(opponent)],
		[ability_loadout, Cards.default_ability_loadout(opponent)],
		[support_selection, _default_support_selection(opponent)])
	if not result.get("ok", false):
		_deck_error.text = _friendly_error(str(result.get("error", "Неверная колода")))
		return result
	Checkpoint.active_slot=save_slot
	_save_error=Slots.write(save_slot,{})
	started = true
	audio.set_suspended(false)
	audio.stop_transients()
	audio.set_speaker(str(preferences.avatar),rules.teams[0][0])
	audio.voice_event("match_start")
	battle_presentation.reset()
	paused = false
	_modal_blocker.hide()
	visual_phase = "idle"
	selected_unit = 0
	selected_gate = 0
	selected_ability=""
	_journal.clear()
	_message = "Выбери карту ворот в руке и поставь её щелчком на свободное место."
	_deck_panel.hide()
	_pause_panel.hide()
	_save_deck()
	_sync_field()
	_refresh_ui()
	_save_match()
	return result


func _try_place_gate(slot: int) -> Dictionary:
	if _gameplay_input_blocked():
		return {"ok": false, "error": "Сейчас нельзя поставить карту ворот."}
	if slot < 0 or slot >= BoardLayout.SLOT_COUNT:
		return {"ok": false, "error": "Выбери место внутри поля."}
	var result: Dictionary = rules.place_gate(0, selected_gate, slot)
	if result.get("ok", false):
		selected_gate = -1
	_handle_result(result)
	return result


func _select_unit(index: int) -> void:
	if index < 0 or index >= 3 or _gameplay_input_blocked():
		return
	_cancel_charge()
	selected_unit = index
	selected_gate = -1
	var pending: Dictionary = rules.pending_trap_action()
	if not pending.is_empty():
		_refresh_ui()
		return
	var unit: Dictionary = rules.teams[0][index]
	if unit.get("status", "reserve") == "field" and rules.phase == "turn" and rules.turn == 0:
		var result: Dictionary = rules.recall_unit(0, index)
		if result.get("ok", false):
			_handle_result(result)
			_handle_result(rules.finish_turn(0))
	else:
		_refresh_ui()


func _cycle_style() -> void:
	if _gameplay_input_blocked():
		return
	throw_style = "straight" if throw_style == "lob" else "lob"
	_refresh_ui()


func _begin_charge() -> void:
	if selected_gate < 0 and _can_player_throw():
		_place_unit_on_gate(0, selected_unit, aim_slot)


func _place_unit_on_gate(owner: int, index: int, slot: int) -> Dictionary:
	if _gameplay_input_blocked():
		return {"ok": false, "error": "Сейчас нельзя поставить бакугана."}
	var pending: Dictionary = rules.pending_trap_action()
	var extra: bool = not pending.is_empty() and str(pending.type) == "roll" and int(pending.owner) == owner
	if not rules.gates.has(slot):
		var invalid: Dictionary = {"ok": false, "error": "Выбери выставленную карту ворот."}
		_handle_result(invalid)
		return invalid
	if extra and not pending.get("slots", []).has(slot):
		return {"ok": false, "error": "Эта карта недоступна для действия ловушки."}
	var result: Dictionary = rules.resolve_trap_action(owner, {"unit_index": index, "slot": slot}) if extra else rules.throw_unit(owner, index, slot)
	if not result.get("ok", false):
		_handle_result(result)
		return result
	last_throw_slot = slot
	selected_gate = -1
	_cancel_charge()
	visual_phase = "idle"
	_trajectory.hide()
	_handle_result(result)
	if rules.phase == "turn" and not extra:
		_handle_result(rules.finish_turn(owner))
	return result


func _launch_throw(owner: int, index: int, target: Vector3, _power: float) -> void:
	# Anime placement has no trajectory, power or random landing result.
	var slot: int = -1
	for candidate: Variant in rules.gates:
		if BoardLayout.POSITIONS[int(candidate)].distance_to(target) < 1.0:
			slot = int(candidate)
			break
	_place_unit_on_gate(owner, index, slot)


func _update_flight(delta: float) -> void:
	var duration: float = ThrowMotion.flight_duration(_flight_style) * maxf(0.01, flight_duration_scale)
	var previous_progress: float = minf(1.0, _flight_time / duration)
	_flight_time += delta
	var progress: float = minf(1.0, _flight_time / duration)
	var swept: Dictionary = ThrowMotion.sweep_flight(arena, _flight_start, _flight_end, previous_progress, progress, _flight_style)
	_flight_ball.position = swept.position
	_flight_ball.rotate_x(delta * 7.0)
	if progress >= 1.0 or bool(swept.collided):
		var velocity: Vector3 = ThrowMotion.initial_roll_velocity(_flight_ball.position, _flight_target, _flight_charge, _flight_style)
		arena.configure_roll(_roll)
		_roll.begin(_flight_ball.position, _flight_target, velocity.length(), roll_duration)
		_flight_ball.position = _roll.position
		_roll_previous = _roll.position
		visual_phase = "rolling"


func _update_roll(delta: float) -> void:
	var steering: Vector2 = Vector2.ZERO
	var braking: bool = false
	if _flight_owner == 0:
		steering = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		braking = Input.is_physical_key_pressed(KEY_SHIFT)
	else:
		var direction: Vector3 = _flight_target - _roll.position
		steering = Vector2(direction.x, direction.z).limit_length(0.5)
		braking = direction.length() < 0.7
	if _flight_owner == 0:
		steering = arena.control_direction(steering)
	_flight_ball.position = _roll.step(delta, steering, braking)
	_flight_ball.rotate_x(delta * _roll.velocity.length() * 2.0)
	var reached: int = -1
	for segment: Dictionary in _roll.travel_segments:
		reached = _gate_on_segment(segment.from, segment.to)
		if reached >= 0:
			break
	_roll_previous = _roll.position
	if reached >= 0 or _roll.is_finished():
		_finish_throw(reached)


func _gate_on_segment(start: Vector3, end: Vector3) -> int:
	var reached: int = -1
	var best_distance: float = 0.70
	for slot: Variant in rules.gates:
		var pending: Dictionary = rules.pending_trap_action()
		if not pending.is_empty() and str(pending.type) == "roll" and not pending.get("slots", []).has(int(slot)):
			continue
		var distance: float = RollMotion.segment_distance(BoardLayout.POSITIONS[int(slot)], start, end)
		if distance < best_distance:
			best_distance = distance
			reached = int(slot)
	return reached


func _finish_throw(slot: int) -> Dictionary:
	last_throw_slot = slot
	var owner: int = _flight_owner
	var extra_roll: bool = _flight_trap_action
	_cancel_flight()
	visual_phase = "idle"
	var result: Dictionary = rules.resolve_trap_action(owner, {"unit_index": _flight_unit, "slot": slot}) if extra_roll else rules.throw_unit(owner, _flight_unit, slot)
	_handle_result(result)
	if result.get("ok", false) and rules.phase == "turn" and not extra_roll:
		_handle_result(rules.finish_turn(owner))
	return result


func _cancel_flight() -> void:
	if is_instance_valid(_flight_ball):
		_flight_ball.queue_free()
	_flight_ball = null
	_flight_trap_action = false
	charging = false
	charge = 0.0


func _set_aim_from_screen(screen: Vector2) -> void:
	var origin: Vector3 = arena.camera.project_ray_origin(screen)
	var direction: Vector3 = arena.camera.project_ray_normal(screen)
	if absf(direction.y) < 0.00001:
		return
	var distance: float = (0.0 - origin.y) / direction.y
	if distance <= 0.0:
		return
	var point: Vector3 = origin + direction * distance
	aim_point = Vector3(clampf(point.x, -5.2, 5.2), 0.0, clampf(point.z, -4.9, 4.9))
	aim_slot = -1
	var nearest: float = 1.48
	for slot: int in range(BoardLayout.SLOT_COUNT):
		var d: float = Vector2(point.x - BoardLayout.POSITIONS[slot].x, point.z - BoardLayout.POSITIONS[slot].z).length()
		if d < nearest:
			nearest = d
			aim_slot = slot
	if selected_gate >= 0 and rules.phase in ["opening", "turn"] and rules.turn == 0:
		arena.highlight_legal_slots(rules.legal_gate_slots())
	elif aim_slot >= 0 and rules.gates.has(aim_slot):
		arena.highlight_target(aim_slot)
	else:
		arena.clear_highlights()


func _draw_preview() -> void:
	_trajectory.hide()


func _ai_action() -> void:
	var pending_action: Dictionary = rules.pending_trap_action()
	if not pending_action.is_empty():
		if int(pending_action.owner) == 1:
			_resolve_ai_trap_action(pending_action)
		return
	if rules.phase == "battle":
		var gate: Dictionary = rules.gates.get(int(rules.battle.get("slot", -1)), {})
		if not gate.get("revealed", false) and gate.get("owner", -1) == 1:
			var opened: Dictionary = rules.open_gate(1)
			if opened.get("ok", false):
				_handle_result(opened)
				return
		var trap_options: Dictionary = _default_trap_options(1)
		if rules.can_deploy_trap(1, -1, -1, trap_options):
			var deployed: Dictionary = rules.deploy_trap(1, -1, -1, trap_options)
			if deployed.get("ok", false):
				_handle_result(deployed)
				return
		for index: int in range(rules.ability_hands[1].size()):
			var card: Dictionary = _hand_card(rules.ability_hands[1][index], false)
			if str(card.get("effect", {}).get("type", "")) == "counter":
				var pending_owner: int = -1
				var chain: Array = rules.battle.get("chain", [])
				for position: int in range(chain.size() - 1, -1, -1):
					var pending: Dictionary = chain[position]
					if not pending.get("cancelled", false) and not pending.get("resolved", false):
						pending_owner = int(pending.get("owner", -1))
						break
				if pending_owner != 0:
					continue
			var result: Dictionary = rules.play_ability(1, index)
			if result.get("ok", false):
				_handle_result(result)
				return
		_handle_result(rules.pass_response(1))
		return
	if rules.turn != 1:
		return
	var legal: Array = rules.legal_gate_slots()
	if rules.phase == "opening":
		var slot: int = legal[0]
		if legal.has(6):
			slot = 6
		_handle_result(rules.place_gate(1, 0, slot))
		return
	var units: Array = rules.available_units(1)
	if units.is_empty():
		for index: int in range(3):
			if rules.teams[1][index].get("status", "") == "field":
				_handle_result(rules.recall_unit(1, index))
				_handle_result(rules.finish_turn(1))
				return
		_handle_result(rules.finish_turn(1))
		return
	var unit_index: int = units[0]
	for index: int in units:
		if int(rules.teams[1][index].get("current_g", 0)) > int(rules.teams[1][unit_index].get("current_g", 0)):
			unit_index = index
	var target_slot: int = -1
	for slot: Variant in rules.gates:
		var gate: Dictionary = rules.gates[slot]
		for occupant: Dictionary in gate.get("bakugan", []):
			if int(occupant.owner) == 0:
				target_slot = int(slot)
				break
		if target_slot >= 0:
			break
	if target_slot < 0:
		for slot: Variant in rules.gates:
			if rules.gates[slot].get("bakugan", []).is_empty():
				target_slot = int(slot)
				break
	if target_slot < 0 and not legal.is_empty() and not rules.gate_hands[1].is_empty():
		target_slot = legal[0]
		if legal.has(5):
			target_slot = 5
		_handle_result(rules.place_gate(1, 0, target_slot))
	if target_slot >= 0:
		_launch_throw(1, unit_index, BoardLayout.POSITIONS[target_slot], 0.80)
	else:
		_handle_result(rules.finish_turn(1))


func _can_player_throw() -> bool:
	if _gameplay_input_blocked():
		return false
	var pending: Dictionary = rules.pending_trap_action()
	if not pending.is_empty():
		return int(pending.owner) == 0 and str(pending.type) == "roll"
	return rules.phase == "turn" and rules.turn == 0 and not rules.acted_this_turn


func _gameplay_input_blocked() -> bool:
	return paused or not started or _browser.visible or _deck_panel.visible or visual_phase in ["flying", "rolling"] or battle_presentation.is_result_playing()


func _select_gate(index: int) -> void:
	if _gameplay_input_blocked() or rules.turn != 0 or not rules.phase in ["opening", "turn"]:
		return
	_cancel_charge()
	selected_gate = index
	_message = "Щёлкни по свободному месту на поле, чтобы поставить эту карту."
	_refresh_ui()


func _end_player_turn() -> void:
	if _gameplay_input_blocked():
		return
	_cancel_charge()
	if rules.phase == "finished":
		start_match()
	else:
		selected_gate = -1
		_handle_result(rules.finish_turn(0))


func _throw_available_units(owner: int) -> Array:
	var pending: Dictionary = rules.pending_trap_action()
	if not pending.is_empty():
		return pending.get("available_indices", []) if int(pending.owner) == owner and str(pending.type) == "roll" else []
	return rules.available_units(owner)


func _resolve_ai_trap_action(pending: Dictionary) -> void:
	var available: Array = pending.get("available_indices", [])
	if available.is_empty():
		return
	var incoming: int = int(available[0])
	for index: int in available:
		if int(rules.teams[1][index].current_g) > int(rules.teams[1][incoming].current_g):
			incoming = index
	if str(pending.type) == "roll":
		var slots: Array = pending.get("slots", [])
		if slots.is_empty():
			_handle_result(rules.resolve_trap_action(1, {"unit_index": incoming, "slot": -1}))
			return
		var target: int = int(slots[0])
		for slot: int in slots:
			if slot != int(rules.battle.get("slot", -1)):
				target = slot
				break
		_launch_throw(1, incoming, BoardLayout.POSITIONS[target], 0.80)
	elif str(pending.type) == "swap":
		var outgoing: Array = pending.get("outgoing_indices", [])
		if outgoing.is_empty():
			return
		var replaced: int = int(outgoing[0])
		for index: int in outgoing:
			if int(rules.battle_unit_breakdown(1, index).total) < int(rules.battle_unit_breakdown(1, replaced).total):
				replaced = index
		_handle_result(rules.resolve_trap_action(1, {"unit_index": incoming, "outgoing_index": replaced}))


func _handle_result(result: Dictionary) -> void:
	var speaking_owner: int=clampi(int(result.get("owner",rules.turn)),0,1)
	if is_instance_valid(audio): audio.set_speaker(str(preferences.avatar) if speaking_owner==0 else "chara00")
	if is_instance_valid(audio):
		if not result.get("ok",false): audio.effect("error")
		else:
			var cue: String = str(result.get("event",""))
			match cue:
				"gate_placed", "gate_opened": audio.event(cue)
				"stand", "stack", "trap_roll_stand": audio.event("land")
				"battle", "battle_started":
					audio.event("gate_opened")
					audio.event("battle")
				"ability_played": audio.event("ability")
				"trap_deployed", "trap_played", "trap_action_resolved": audio.event("trap")
				"miss", "trap_roll_miss": audio.effect("miss")
				"battle_end", "battle_resolved":
					audio.effect("win")
					audio.voice_event("win" if int(result.get("victor",-1))==0 else "lose")
				"finished": audio.voice_event("win" if rules.winner==0 else "lose")
	if not result.get("ok", false):
		_message = _friendly_error(str(result.get("error", "Это действие сейчас недоступно.")))
	else:
		var messages: Dictionary = {
			"gate_placed": "Карта ворот поставлена рубашкой вверх.",
			"gate_opened": "Ворота раскрыты: бонусы стихий применены.",
			"ability_played": "Способность добавлена в цепочку. Можно ответить своей картой.",
			"chain_resolved": "Цепочка способностей разрешена. Снова можно сыграть карту или пасовать.",
			"battle_started": "Бой начался. Владелец ворот получает первый ответ.",
			"battle": "Бой начался. Владелец ворот получает первый ответ.",
			"battle_resolved": "Бой завершён: проигравший бакуган выбывает.",
			"battle_end": "Бой завершён: проигравший бакуган выбывает.",
			"battle_cancelled": "Ворота вернули обоих бакуганов в резерв. Бой отменён.",
			"unit_recalled": "Бакуган возвращён в резерв.",
			"recall": "Бакуган возвращён в резерв.",
			"miss": "Бросок прошёл мимо карты. Бакуган остаётся в резерве.",
			"stand": "Бакуган открылся на карте ворот.",
			"stack": "Бакуган присоединился к союзнику на карте. В бою их сила складывается.",
			"turn_finished": "Ход передан сопернику.",
			"passed": "Пас. Соперник может ответить.",
			"response_passed": "Пас. Соперник может ответить.",
			"trap_deployed": "Ловушка вызвана в помощь бакугану. Соперник может ответить.",
			"trap_played": "Ловушка вызвана в помощь бакугану. Соперник может ответить.",
			"trap_action_resolved": "Действие ловушки выполнено. Бой продолжается.",
			"trap_roll_resolved": "Дополнительный бросок завершён. Бой продолжается.",
			"trap_swap_resolved": "Бакуган заменён участником из резерва.",
			"trap_action_required": "Эффект ловушки требует дополнительного броска или замены из резерва.",
			"trap_roll_returned": "Дополнительный бакуган вернулся в резерв по эффекту ловушки.",
			"trap_roll_miss": "Дополнительный бросок прошёл мимо ворот; бакуган в резерве.",
			"trap_roll_stand": "Дополнительный бакуган открылся на воротах вне текущего боя.",
			"trap_swap": "Бакуган заменён участником из резерва.",
			"finished": "Дуэль завершена.",
		}
		var event: String = str(result.get("event", ""))
		_message = str(messages.get(event, "Действие выполнено."))
		if event == "ability_played":
			_message = ("Ты: " if int(result.get("owner", 0)) == 0 else "Соперник: ") + str(result.get("title", "Способность")) + (" — действует сразу." if result.get("immediate", false) else " — можно ответить картой.")
		elif event == "battle_end" and int(result.get("victor", -1)) == -1:
			_message = "Ничья: участники живы и вернулись в резерв."
		elif event in ["trap_deployed", "trap_played"]:
			_message = ("Ты: " if int(result.get("owner", 0)) == 0 else "Соперник: ") + str(result.get("name", result.get("title", "Ловушка"))) + " — поддержка вызвана в бой."
		_journal.append(_message)
		while _journal.size() > 3:
			_journal.pop_front()
	if result.get("ok", false):
		var battle_event: String = str(result.get("event", ""))
		if battle_event in ["battle_end", "battle_resolved"]:
			battle_presentation.finish_battle(int(result.get("victor", -1)), result.get("totals", battle_presentation.snapshot.get("totals", [0, 0])))
		elif battle_event == "battle_cancelled":
			battle_presentation.reset()
		else:
			_sync_battle_presentation(result)
	_sync_field()
	_refresh_ui()
	if result.get("ok", false) and str(result.get("event", "")) in ["battle_end", "battle_cancelled", "chain_resolved"] and rules.phase == "turn":
		_handle_result(rules.finish_turn(int(rules.turn)))


func _friendly_error(error: String) -> String:
	var known: Dictionary = {
		"not_your_turn": "Сейчас ход соперника.", "wrong_phase": "Это действие сейчас недоступно.",
		"gate_already_placed": "В этот ход ты уже поставил карту ворот.",
		"throw_already_used": "В этот ход ты уже бросил или вернул бакугана.",
		"invalid_unit": "Выбери доступного бакугана из резерва.",
		"own_gate_occupied": "На этой карте уже стоит твой бакуган. Выбери другую карту.",
		"not_priority": "Сейчас право ответа у соперника.",
		"gate_not_revealed": "Сначала владелец карты должен раскрыть ворота.",
	}
	return str(known.get(error, error))


func _sync_field() -> void:
	for slot: Variant in _gate_signatures.keys():
		if not rules.gates.has(slot):
			arena.remove_gate(int(slot))
			_gate_signatures.erase(slot)
	for slot: Variant in rules.gates:
		var gate: Dictionary = rules.gates[slot]
		var signature: String = "%s:%s:%s" % [gate.get("id", ""), gate.get("owner", 0), gate.get("revealed", false)]
		if _gate_signatures.get(slot, "") != signature:
			# A neutral front carries this catalog's actual title; no unrelated
			# source face is attached to a card with different rules.
			var node: Node3D = arena.make_gate(int(slot), int(gate.owner), "", bool(gate.get("revealed", false)), "silver")
			if gate.get("revealed", false):
				_set_empty_card_title(node, str(gate.get("title", "ВОРОТА")))
			node.set_meta("anime_card_id", gate.get("id", ""))
			_gate_signatures[slot] = signature
	var alive: Dictionary = {}
	for owner: int in range(2):
		var field_units: Array = rules.teams[owner].duplicate()
		for gate: Dictionary in rules.gates.values():
			for copy: Dictionary in gate.get("bakugan", []):
				if int(copy.get("owner", -1)) == owner and bool(copy.get("temporary_clone", false)) and not field_units.has(copy):
					field_units.append(copy)
		for unit: Dictionary in field_units:
			var index: int = int(unit.index)
			if unit.get("status", "") != "field":
				continue
			var key: String = "%d:%d" % [owner, index]
			alive[key] = true
			if _unit_nodes.has(key) and str((_unit_nodes[key] as Node3D).get_meta("attribute", "")) != str(unit.attribute):
				(_unit_nodes[key] as Node3D).queue_free()
				_unit_nodes.erase(key)
			if not _unit_nodes.has(key):
				var creature: Node3D = arena.make_creature(str(unit.get("model_name", unit.name)), str(unit.attribute))
				var wrapper: Node3D = Node3D.new()
				wrapper.name = "StandingBakugan%d_%d" % [owner, index]
				arena.add_child(wrapper)
				creature.reparent(wrapper)
				for meta: StringName in creature.get_meta_list():
					wrapper.set_meta(meta, creature.get_meta(meta))
				wrapper.set_meta("temporary_clone", bool(unit.get("temporary_clone", false)))
				wrapper.set_meta("additional_attributes", unit.get("additional_attributes", []))
				_unit_nodes[key] = wrapper
			var node: Node3D = _unit_nodes[key]
			var slot: int = int(unit.get("slot", 0))
			var occupants: Array = rules.gates.get(slot, {}).get("bakugan", [])
			var own_group: Array = []
			var opposed: bool = false
			for standing: Dictionary in occupants:
				if int(standing.owner) == owner:
					own_group.append(int(standing.index))
				else:
					opposed = true
			var group_index: int = own_group.find(index)
			var spread: float = (float(group_index) - float(own_group.size() - 1) * 0.5) * 0.9
			var offset: Vector3 = Vector3((-0.64 if owner == 0 else 0.64), 0.16, spread) if opposed else Vector3(spread, 0.16, 0.0)
			node.position = arena.slot_position(slot) + offset
			node.scale = Vector3.ONE * (0.30 if own_group.size() >= 3 else 0.34 if own_group.size() == 2 else 0.40 if opposed else 0.48)
			node.rotation.y = 0.0 if owner == 0 else PI
	for key: Variant in _unit_nodes.keys():
		if not alive.has(key):
			(_unit_nodes[key] as Node3D).queue_free()
			_unit_nodes.erase(key)
	_sync_support_models()
	_sync_camera()


func _sync_support_models() -> void:
	var active: Dictionary = {}
	if started:
		for owner: int in range(2):
			var support: Dictionary = rules.support_slots[owner]
			if support.is_empty() or str(support.get("status", "")) not in ["pending", "deployed", "field"]:
				continue
			var roaming: bool = str(support.status) == "field"
			if roaming and not rules.gates.has(int(support.get("slot", -1))):
				continue
			var caster_key: String = "%d:%d" % [owner, int(support.get("caster_index", -1))]
			if not roaming and not _unit_nodes.has(caster_key):
				for unit: Dictionary in rules.battle_units(owner):
					var replacement: String = "%d:%d" % [owner, int(unit.index)]
					if _unit_nodes.has(replacement):
						caster_key = replacement
						break
			if not roaming and not _unit_nodes.has(caster_key):
				continue
			active[owner] = true
			if not _support_nodes.has(owner):
				var model: Node3D = arena.make_creature(str(support.name), str(support.attribute))
				var wrapper: Node3D = Node3D.new()
				wrapper.name = "BattleSupport%d" % owner
				arena.add_child(wrapper)
				model.reparent(wrapper)
				for meta: StringName in model.get_meta_list():
					wrapper.set_meta(meta, model.get_meta(meta))
				wrapper.set_meta("support_id", support.get("id", ""))
				wrapper.set_meta("category", support.get("category", "trap"))
				_support_nodes[owner] = wrapper
			var node: Node3D = _support_nodes[owner]
			var anchor: Vector3 = arena.slot_position(int(support.slot)) + Vector3(0.0, 0.16, 0.0) if roaming or int(support.slot) != int(rules.battle.get("slot", -1)) else (_unit_nodes[caster_key] as Node3D).position
			node.position = anchor + Vector3(-0.68 if owner == 0 else 0.68, 0.0, 0.48)
			node.scale = Vector3.ONE * 0.29
			node.rotation.y = 0.0 if owner == 0 else PI
			node.set_meta("support_status", support.status)
	for owner: Variant in _support_nodes.keys():
		if not active.has(owner):
			(_support_nodes[owner] as Node3D).queue_free()
			_support_nodes.erase(owner)


func _default_trap_options(owner: int) -> Dictionary:
	var choices: Dictionary = rules.trap_choices(owner)
	var options: Dictionary = {}
	for pair: Array in _trap_choice_fields():
		var values: Array = choices.get(pair[0], [])
		if not values.is_empty():
			options[pair[1]] = values[0]
	return _expand_trap_options(options)


func _trap_choice_fields() -> Array:
	return [["source_slots", "source_slot", "Источник: "], ["destination_slots", "destination_slot", "Куда: "], ["attributes", "attribute", "Стихия: "], ["defeated_indices", "unit_index", "Вернуть: "], ["history_sources", "history_source", "Последний эффект: "], ["target_units", "target_unit", "Кому: "]]


func _expand_trap_options(options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	var history: Variant = result.get("history_source")
	if history is Dictionary:
		result["source_owner"] = int(history.owner)
		result["source_index"] = int(history.index)
	result.erase("history_source")
	var target: Variant = result.get("target_unit")
	if target is Dictionary:
		result["target_owner"] = int(target.owner)
		result["target_index"] = int(target.index)
	result.erase("target_unit")
	return result


func _trap_choice_label(field: String, value: Variant) -> String:
	if value is Dictionary:
		var prefix: String = "Ты: " if int(value.get("owner", 0)) == 0 else "Соперник: "
		var suffix: String = " · %+d G" % int(value.change) if value.has("change") else ""
		return prefix + str(value.get("name", "Бакуган")) + suffix
	if field == "attribute":
		return str(value)
	if field == "unit_index":
		return str(rules.teams[0][int(value)].name)
	return "ворота %02d" % (int(value) + 1)


func _sync_camera() -> void:
	_sync_battle_presentation()
	var slot: int = int(rules.battle.get("slot", -1)) if rules.phase == "battle" else -1
	if _battle_needs_board():
		slot = -1
	if slot == _camera_battle_slot:
		return
	_camera_battle_slot = slot
	if slot >= 0:
		var focus: Vector3 = BoardLayout.POSITIONS[slot] + Vector3(0.0, 0.35, 0.0)
		arena.camera.h_offset = 1.1
		arena.camera.fov = 43.0
		arena.camera.look_at_from_position(focus + Vector3(5.4, 7.6, -9.0 if arena_id == "ds_pyrus" else 9.0), focus)
	else:
		arena.camera.h_offset = 2.2
		arena.camera.fov = 48.0
		arena.camera.look_at_from_position(arena.board_camera_position(), Vector3(0.0, 0.4, 0.0))


func _battle_needs_board() -> bool:
	var pending: Dictionary = rules.pending_trap_action()
	return not pending.is_empty() and str(pending.get("type", "")) == "roll"


func _sync_battle_presentation(event: Dictionary = {}) -> void:
	if not is_instance_valid(battle_presentation) or rules.phase != "battle" or rules.battle.is_empty():
		return
	var slot: int = int(rules.battle.slot)
	if not rules.gates.has(slot):
		return
	var units: Array = []
	var supports: Array = []
	for owner: int in range(2):
		units.append_array(rules.battle_units(owner).duplicate(true))
		if not rules.support_slots[owner].is_empty():
			var support: Dictionary = rules.support_slots[owner].duplicate(true)
			support["owner"] = owner
			supports.append(support)
	var state: Dictionary = {
		"key": "anime:%d" % slot, "slot": slot, "arena_id": arena_id,
		"gate": rules.gates[slot].duplicate(true), "units": units,
		"totals": rules.battle_totals(), "supports": supports,
		"priority": int(rules.battle.get("priority", -1)),
	}
	battle_presentation.sync_battle(state, event)
	battle_presentation.set_suspended(paused or visual_phase in ["flying", "rolling"] or _battle_needs_board())


func _set_empty_card_title(node: Node, title: String) -> void:
	if node is Label3D and node.text.is_empty():
		node.text = title.to_upper()
	for child: Node in node.get_children():
		_set_empty_card_title(child, title)


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_resource: Theme = Theme.new()
	theme_resource.default_font = load("res://assets/ui.ttf") as Font
	theme_resource.default_font_size = 16
	hud.theme = theme_resource
	layer.add_child(hud)
	battle_presentation = DSBattle.new()
	hud.add_child(battle_presentation)
	battle_presentation.configure(arena_id, bool(preferences.reduced_motion))
	var top: PanelContainer = _panel()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.offset_bottom = 114
	hud.add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_title = _label("АНИМЕ-ДУЭЛЬ", 27, WHITE)
	info.add_child(_title)
	_hint = _label("", 15, MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_hint)
	_status = _label("3 бакугана · 6 ворот · 10 способностей", 16, CYAN)
	row.add_child(_status)
	var collection: Button = _button("Все карты")
	collection.pressed.connect(func():
		_cancel_charge()
		_browser.show_browser()
	)
	row.add_child(collection)
	var menu: Button = _button("Пауза · Esc")
	menu.pressed.connect(func(): _set_paused(true))
	row.add_child(menu)
	var side: PanelContainer = _panel()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -355
	side.offset_right = -20
	side.offset_top = 130
	side.offset_bottom = -20
	hud.add_child(side)
	_side_scroll = ScrollContainer.new()
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(_side_scroll)
	var side_body: VBoxContainer = VBoxContainer.new()
	side_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_body.add_theme_constant_override("separation", 10)
	_side_scroll.add_child(side_body)
	_side_title = _label("ТВОЯ РУКА", 21, ORANGE)
	side_body.add_child(_side_title)
	_battle_label = _label("", 15, WHITE)
	_battle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_body.add_child(_battle_label)
	_build_trap_action_ui(side_body)
	_caster_select = OptionButton.new()
	_caster_select.fit_to_longest_item = false
	_caster_select.clip_text = true
	_caster_select.custom_minimum_size.y = 34
	_caster_select.item_selected.connect(func(index: int):
		selected_caster = int(_caster_select.get_item_metadata(index))
		_refresh_battle_choices()
		_rebuild_hands()
		_refresh_trap_ui()
	)
	side_body.add_child(_caster_select)
	_target_select = OptionButton.new()
	_target_select.fit_to_longest_item = false
	_target_select.clip_text = true
	_target_select.custom_minimum_size.y = 34
	_target_select.item_selected.connect(func(index: int):
		var target: Dictionary = _target_select.get_item_metadata(index)
		selected_target = int(target.index)
		selected_target_owner = int(target.owner)
		_rebuild_hands()
		_refresh_trap_ui()
	)
	side_body.add_child(_target_select)
	_activate_button = _button("Активировать выбранную карту")
	_activate_button.pressed.connect(_activate_selected_ability)
	side_body.add_child(_activate_button)
	var actions: HBoxContainer = HBoxContainer.new()
	side_body.add_child(actions)
	_open_button = _button("Раскрыть ворота")
	_open_button.pressed.connect(func():
		if not _gameplay_input_blocked():
			_handle_result(rules.open_gate(0, selected_caster, selected_target if selected_target_owner == 1 else -1))
	)
	actions.add_child(_open_button)
	_pass_button = _button("Пас")
	_pass_button.pressed.connect(func():
		if not _gameplay_input_blocked():
			_handle_result(rules.pass_response(0))
	)
	actions.add_child(_pass_button)
	_end_button = _button("Завершить ход")
	_end_button.pressed.connect(_end_player_turn)
	side_body.add_child(_end_button)
	_trap_status = _label("", 13, MUTED)
	_trap_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trap_status.max_lines_visible = 3
	side_body.add_child(_trap_status)
	_trap_choice_box = VBoxContainer.new()
	_trap_choice_box.add_theme_constant_override("separation", 5)
	side_body.add_child(_trap_choice_box)
	for pair: Array in _trap_choice_fields():
		var field: String = pair[1]
		var selector: OptionButton = OptionButton.new()
		selector.fit_to_longest_item = false
		selector.clip_text = true
		selector.custom_minimum_size.y = 30
		selector.item_selected.connect(func(index: int):
			_trap_options[field] = selector.get_item_metadata(index)
			_refresh_trap_ui()
		)
		selector.set_meta("prefix", pair[2])
		_trap_choice_box.add_child(selector)
		_trap_choice_selectors[field] = selector
	_trap_prepare_button = _button("Подготовить ловушку")
	_trap_prepare_button.pressed.connect(_prepare_trap)
	side_body.add_child(_trap_prepare_button)
	_trap_button = _button("Вызвать ловушку")
	_trap_button.pressed.connect(func():
		if not _gameplay_input_blocked():
			_handle_result(rules.deploy_trap(0, selected_caster, selected_target if selected_target_owner == 1 else -1, _expand_trap_options(_trap_options)))
	)
	side_body.add_child(_trap_button)
	_hand_grid = VBoxContainer.new()
	_hand_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_grid.add_theme_constant_override("separation", 8)
	side_body.add_child(_hand_grid)
	_log = _label("", 13, MUTED)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_body.add_child(_log)
	var bottom: PanelContainer = _panel()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -375
	bottom.offset_top = -176
	bottom.offset_bottom = -20
	hud.add_child(bottom)
	var bottom_body: VBoxContainer = VBoxContainer.new()
	bottom_body.add_theme_constant_override("separation", 10)
	bottom.add_child(bottom_body)
	var units: HBoxContainer = HBoxContainer.new()
	units.add_theme_constant_override("separation", 10)
	bottom_body.add_child(units)
	for index: int in range(3):
		var unit_button: Button = _button("")
		unit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_button.custom_minimum_size.y = 62
		unit_button.pressed.connect(_select_unit.bind(index))
		units.add_child(unit_button)
		_unit_buttons.append(unit_button)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	bottom_body.add_child(controls)
	_style_button = _button("Высокий бросок · T")
	_style_button.custom_minimum_size.x = 230
	_style_button.pressed.connect(_cycle_style)
	controls.add_child(_style_button)
	_charge_bar = ProgressBar.new()
	_charge_bar.custom_minimum_size = Vector2(155, 30)
	_charge_bar.show_percentage = true
	controls.add_child(_charge_bar)
	_style_button.hide()
	_charge_bar.hide()
	_stand_destination = OptionButton.new()
	_stand_destination.fit_to_longest_item = false
	_stand_destination.clip_text = true
	_stand_destination.custom_minimum_size = Vector2(220, 34)
	_stand_destination.item_selected.connect(func(index: int):
		aim_slot = int(_stand_destination.get_item_metadata(index))
		aim_point = BoardLayout.POSITIONS[aim_slot]
		arena.highlight_target(aim_slot)
	)
	controls.add_child(_stand_destination)
	_stand_button = _button("Поставить бакугана")
	_stand_button.pressed.connect(_begin_charge)
	controls.add_child(_stand_button)
	var help: Label = _label("1/2/3: бакуган\nКарта: щелчок или список · Пробел: поставить", 13, MUTED)
	controls.add_child(help)
	_browser = Browser.new()
	hud.add_child(_browser)
	_build_pause()


func _refresh_ui() -> void:
	if not started:
		return
	var owner: int = int(rules.turn)
	_result_input_locked = battle_presentation.is_result_playing()
	var titles: Dictionary = {"opening": "ПОСТАНОВКА ВОРОТ", "turn": "ТВОЙ ХОД" if owner == 0 else "ХОД СОПЕРНИКА", "battle": "БОЙ НА ВОРОТАХ", "finished": "ПОБЕДА" if rules.winner == 0 else "ПОРАЖЕНИЕ"}
	_title.text = "АНИМЕ-ДУЭЛЬ  /  " + str(titles.get(rules.phase, ""))
	_hint.text = _message
	if visual_phase == "flying":
		_hint.text = "Бакуган летит…"
	elif visual_phase == "rolling":
		_hint.text = "Направляй качение клавишами WASD. Shift помогает остановиться на карте."
	_status.text = "В строю: %d / 3  ·  Соперник: %d / 3" % [3 - rules.defeated[0].size(), 3 - rules.defeated[1].size()]
	_style_button.text = ("Высокий бросок" if throw_style == "lob" else "Прямой бросок") + " · T"
	_style_button.disabled = visual_phase in ["flying", "rolling"] or _result_input_locked
	_charge_bar.value = charge * 100.0
	_refresh_stand_destination()
	for index: int in range(3):
		var unit: Dictionary = rules.teams[0][index]
		var state: String = str(unit.get("status", "reserve"))
		var states: Dictionary = {"reserve": "В резерве", "field": "На поле · вернуть", "defeated": "Выбыл"}
		_unit_buttons[index].text = "%d  %s\n%s · %d G · %s" % [index + 1, unit.name, unit.attribute, unit.get("current_g", unit.g), states.get(state, state)]
		_unit_buttons[index].disabled = state == "defeated" or visual_phase in ["flying", "rolling"] or not _can_player_throw() or not _throw_available_units(0).has(index)
		if rules.pending_trap_action().is_empty() and rules.phase == "turn" and owner == 0 and state == "field":
			_unit_buttons[index].disabled = visual_phase in ["flying", "rolling"] or _result_input_locked
		_unit_buttons[index].modulate = ORANGE if index == selected_unit else WHITE
		_unit_buttons[index].tooltip_text = _native_unit_tooltip(unit)
	var in_battle: bool = rules.phase == "battle"
	_caster_select.visible = in_battle
	_target_select.visible = in_battle
	_activate_button.visible = in_battle
	_open_button.visible = in_battle
	_pass_button.visible = in_battle
	_end_button.visible = rules.phase == "turn" and owner == 0
	_end_button.disabled = visual_phase in ["flying", "rolling"] or _result_input_locked
	_battle_label.text = ""
	_battle_label.tooltip_text = ""
	if in_battle:
		_refresh_battle_choices()
		var priority: int = int(rules.battle.get("priority", -1))
		var gate: Dictionary = rules.gates.get(int(rules.battle.get("slot", -1)), {})
		_open_button.disabled = not rules.can_open_gate(0)
		_pass_button.disabled = priority != 0
		_side_title.text = "ТВОЙ ОТВЕТ" if priority == 0 else "ОТВЕТ СОПЕРНИКА"
		var own: Dictionary = rules.battle_breakdown(0)
		var enemy: Dictionary = rules.battle_breakdown(1)
		var gate_name: String = str(gate.get("title", "")) if gate.get("revealed", false) or gate.get("owner", 1) == 0 else "Закрытые ворота соперника"
		var effect: String = str(gate.get("description_ru", gate.get("description", ""))) if gate.get("revealed", false) or gate.get("owner", 1) == 0 else "Владелец может раскрыть карту в свой ответ."
		_battle_label.text = "%s\n%s\nТы: %d + %d + %d + %d = %d G\nСоперник: %d + %d + %d + %d = %d G\nБаза + ворота + способности + поддержка\nЦепочка: %d · два паса разрешают ответ" % [gate_name, effect, own.get("base", 0), own.get("gate", 0), own.get("ability", 0), own.get("support", 0), own.get("total", 0), enemy.get("base", 0), enemy.get("gate", 0), enemy.get("ability", 0), enemy.get("support", 0), enemy.get("total", 0), rules.battle.get("chain", []).size()]
		var pending: Array[String] = []
		for link: Dictionary in rules.battle.get("chain", []):
			var caster_index: int = int(link.get("caster_index",-1))
			var target_index: int = int(link.get("target_index",-1))
			var target_owner: int = int(link.get("target_owner",1-int(link.owner)))
			var caster: String = str(rules.teams[int(link.owner)][caster_index].name) if caster_index>=0 and caster_index<rules.teams[int(link.owner)].size() else "поле"
			var target: String = str(rules.teams[target_owner][target_index].name) if target_index>=0 and target_index<rules.teams[target_owner].size() else "поле"
			pending.append(("Ты: " if int(link.get("owner", 0)) == 0 else "Соперник: ") + str(link.get("card", {}).get("title", "Способность"))+" · "+caster+" → "+target+(" · отменена" if link.get("cancelled",false) else ""))
		if not pending.is_empty():
			_battle_label.text += "\n" + pending[-1]
		_battle_label.tooltip_text = "\n".join(pending)
	elif rules.phase == "finished":
		_side_title.text = "ДУЭЛЬ ЗАВЕРШЕНА"
		_battle_label.text = "Все бакуганы соперника выбыли." if rules.winner == 0 else "Твои бакуганы выбыли. Измени колоду и попробуй снова."
		_end_button.show()
		_end_button.text = "Новая дуэль"
		_end_button.disabled = _result_input_locked
	else:
		_side_title.text = "ТВОЯ РУКА"
		_end_button.text = "Завершить ход"
		_battle_label.text = "Ворота: %d в руке / %d в колоде\nСпособности: %d в руке / %d в колоде" % [rules.gate_hands[0].size(), rules.gate_decks[0].size(), rules.ability_hands[0].size(), rules.ability_decks[0].size()]
	_rebuild_hands()
	_refresh_trap_ui()
	_refresh_trap_action_ui()
	_log.text = "\n".join(_journal)
	if rules.phase in ["opening", "turn"] and owner == 0 and selected_gate >= 0:
		arena.highlight_legal_slots(rules.legal_gate_slots())
	elif rules.phase != "turn":
		arena.clear_highlights()


func _refresh_stand_destination() -> void:
	_stand_destination.clear()
	var pending: Dictionary = rules.pending_trap_action()
	for value: Variant in rules.gates:
		var slot: int = int(value)
		if not pending.is_empty() and str(pending.type) == "roll" and not pending.get("slots", []).has(slot):
			continue
		var gate: Dictionary = rules.gates[slot]
		var title: String = str(gate.title) if int(gate.owner) == 0 or bool(gate.get("revealed", false)) else "Закрытые ворота соперника"
		_stand_destination.add_item("%d · %s" % [slot + 1, title])
		var row: int = _stand_destination.item_count - 1
		_stand_destination.set_item_metadata(row, slot)
		if slot == aim_slot:
			_stand_destination.select(row)
	var selectable: bool = _can_player_throw() and selected_gate < 0 and _throw_available_units(0).has(selected_unit)
	if _stand_destination.item_count > 0 and not rules.gates.has(aim_slot):
		aim_slot = int(_stand_destination.get_item_metadata(0))
		aim_point = BoardLayout.POSITIONS[aim_slot]
	_stand_destination.disabled = not selectable or _stand_destination.item_count == 0
	_stand_button.disabled = _stand_destination.disabled
	if selectable and rules.gates.has(aim_slot):
		arena.highlight_target(aim_slot)


func _refresh_trap_ui() -> void:
	var in_battle: bool = rules.phase == "battle"
	var own: Dictionary = rules.support_slots[0]
	var descriptions: Array[String] = []
	var tooltips: Array[String] = []
	var states: Dictionary = {"ready": "готова", "pending": "ожидает ответа", "deployed": "в бою", "field": "на поле", "spent": "использована"}
	for owner: int in range(2):
		var support: Dictionary = rules.support_slots[owner]
		if support.is_empty():
			continue
		# Opponent preparation remains private until the support is summoned.
		if owner == 1 and str(support.get("status", "ready")) == "ready":
			continue
		descriptions.append(("Ты: " if owner == 0 else "Соперник: ") + "%s · %s · %s" % [support.get("name", "Поддержка"), support.get("attribute", ""), states.get(str(support.get("status", "")), "")])
		tooltips.append(_support_description(Traps.get_support(str(support.get("id", ""))), str(support.get("attribute", ""))))
	_trap_status.text = "\n".join(descriptions)
	_trap_status.tooltip_text = "\n\n".join(tooltips)
	_trap_status.visible = not descriptions.is_empty()
	_trap_button.visible = not own.is_empty()
	_trap_prepare_button.visible = not own.is_empty() and rules.phase=="battle"
	_trap_prepare_button.disabled = int(rules.battle.get("priority",-1))!=0 or rules.trap_casters(0).is_empty() or bool(own.get("used",false))
	_trap_button.text = "Вызвать " + str(own.get("name", "поддержку"))
	_refresh_trap_choices()
	var target: int = selected_target if selected_target_owner == 1 else -1
	var options: Dictionary = _expand_trap_options(_trap_options)
	_trap_button.disabled = not rules.can_deploy_trap(0, selected_caster, target, options)
	_trap_button.tooltip_text = rules.trap_error(0, selected_caster, target, options) if _trap_button.disabled else "Вызвать поддержку выбранному бакугану; соперник получит право ответа."
	var eligible: PackedStringArray = []
	for index: int in rules.trap_casters(0): eligible.append(str(rules.teams[0][index].name))
	_trap_prepare_button.tooltip_text = "Ловушки — только в аниме-дуэли. Совместимые участники: "+(", ".join(eligible) if not eligible.is_empty() else "нет")+"."
	_trap_button.tooltip_text += "\nСовместимые участники: "+(", ".join(eligible) if not eligible.is_empty() else "нет")+". Ловушки доступны только в аниме-дуэли."
	_trap_choice_box.visible = in_battle and not own.is_empty() and str(own.get("status", "")) == "ready" and not _trap_options.is_empty()


func _prepare_trap() -> void:
	if _gameplay_input_blocked() or rules.phase!="battle" or int(rules.battle.priority)!=0: return
	var casters: Array[int] = rules.trap_casters(0)
	if casters.is_empty(): return
	selected_ability=""
	selected_caster=casters[0]
	selected_target_owner=1
	var targets: Array[Dictionary]=rules.battle_units(1)
	selected_target=int(targets[0].index) if not targets.is_empty() else -1
	_refresh_ui()


func _refresh_trap_choices() -> void:
	var choices: Dictionary = rules.trap_choices(0) if rules.phase == "battle" else {}
	for pair: Array in _trap_choice_fields():
		var field: String = pair[1]
		var selector: OptionButton = _trap_choice_selectors[field]
		var values: Array = choices.get(pair[0], [])
		selector.clear()
		selector.visible = not values.is_empty()
		if values.is_empty():
			_trap_options.erase(field)
			continue
		for value: Variant in values:
			selector.add_item(str(selector.get_meta("prefix", "")) + _trap_choice_label(field, value))
			selector.set_item_metadata(selector.item_count - 1, value)
			if _trap_options.get(field) == value:
				selector.select(selector.item_count - 1)
		if selector.selected < 0:
			selector.select(0)
		_trap_options[field] = selector.get_item_metadata(selector.selected)


func _build_trap_action_ui(parent: VBoxContainer) -> void:
	_trap_action_box = VBoxContainer.new()
	_trap_action_box.add_theme_constant_override("separation", 6)
	parent.add_child(_trap_action_box)
	_trap_action_hint = _label("", 14, ORANGE)
	_trap_action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trap_action_box.add_child(_trap_action_hint)
	_trap_action_incoming = OptionButton.new()
	_trap_action_incoming.fit_to_longest_item = false
	_trap_action_incoming.clip_text = true
	_trap_action_incoming.custom_minimum_size.y = 34
	_trap_action_incoming.item_selected.connect(func(index: int):
		selected_unit = int(_trap_action_incoming.get_item_metadata(index))
		_refresh_ui()
	)
	_trap_action_box.add_child(_trap_action_incoming)
	_trap_action_outgoing = OptionButton.new()
	_trap_action_outgoing.fit_to_longest_item = false
	_trap_action_outgoing.clip_text = true
	_trap_action_outgoing.custom_minimum_size.y = 34
	_trap_action_box.add_child(_trap_action_outgoing)
	_trap_action_destination = OptionButton.new()
	_trap_action_destination.fit_to_longest_item = false
	_trap_action_destination.clip_text = true
	_trap_action_destination.custom_minimum_size.y = 34
	_trap_action_destination.item_selected.connect(func(index: int):
		aim_slot = int(_trap_action_destination.get_item_metadata(index))
		aim_point = BoardLayout.POSITIONS[aim_slot]
		arena.highlight_target(aim_slot)
	)
	_trap_action_box.add_child(_trap_action_destination)
	_trap_action_button = _button("")
	_trap_action_button.pressed.connect(func():
		if _gameplay_input_blocked():
			return
		var pending: Dictionary = rules.pending_trap_action()
		if pending.is_empty() or int(pending.owner) != 0:
			return
		var incoming: int = int(_trap_action_incoming.get_item_metadata(_trap_action_incoming.selected))
		if str(pending.type) == "roll":
			_launch_throw(0, incoming, aim_point, 0.80)
		else:
			var outgoing: int = int(_trap_action_outgoing.get_item_metadata(_trap_action_outgoing.selected))
			_handle_result(rules.resolve_trap_action(0, {"unit_index": incoming, "outgoing_index": outgoing}))
	)
	_trap_action_box.add_child(_trap_action_button)
	_trap_action_box.hide()


func _refresh_trap_action_ui() -> void:
	var pending: Dictionary = rules.pending_trap_action()
	_trap_action_box.visible = not pending.is_empty()
	if pending.is_empty():
		return
	var is_player: bool = int(pending.owner) == 0
	var is_roll: bool = str(pending.type) == "roll"
	_side_title.text = ("ТВОЯ ПОСТАНОВКА" if is_roll else "ТВОЯ ЗАМЕНА") if is_player else ("ПОСТАНОВКА СОПЕРНИКА" if is_roll else "ЗАМЕНА СОПЕРНИКА")
	_trap_action_hint.text = ("Выбери резервного бакугана и карту ворот, на которую он встанет." if is_roll else "Замена по эффекту ловушки: выбери резерв и того, кто вернётся с ворот.") if is_player else ("Соперник выбирает карту для дополнительной постановки." if is_roll else "Соперник выбирает замену из своего резерва.")
	_hint.text = _trap_action_hint.text
	_trap_action_incoming.visible = is_player
	_trap_action_outgoing.visible = is_player and not is_roll
	_trap_action_destination.visible = is_player and is_roll
	_trap_action_button.visible = is_player
	if not is_player:
		return
	var selected_outgoing: int = -1
	if _trap_action_outgoing.item_count > 0:
		selected_outgoing = int(_trap_action_outgoing.get_item_metadata(maxi(0, _trap_action_outgoing.selected)))
	_trap_action_incoming.clear()
	for index: int in pending.get("available_indices", []):
		var unit: Dictionary = rules.teams[0][index]
		_trap_action_incoming.add_item("Из резерва: %s · %d G" % [unit.name, unit.current_g])
		_trap_action_incoming.set_item_metadata(_trap_action_incoming.item_count - 1, index)
		if selected_unit == index:
			_trap_action_incoming.select(_trap_action_incoming.item_count - 1)
	if _trap_action_incoming.item_count > 0:
		selected_unit = int(_trap_action_incoming.get_item_metadata(maxi(0, _trap_action_incoming.selected)))
	_trap_action_outgoing.clear()
	for index: int in pending.get("outgoing_indices", []):
		var unit: Dictionary = rules.teams[0][index]
		_trap_action_outgoing.add_item("Вернуть: %s · %d G" % [unit.name, rules.battle_unit_breakdown(0, index).total])
		_trap_action_outgoing.set_item_metadata(_trap_action_outgoing.item_count - 1, index)
		if selected_outgoing == index:
			_trap_action_outgoing.select(_trap_action_outgoing.item_count - 1)
	_trap_action_destination.clear()
	for slot: int in pending.get("slots", []):
		_trap_action_destination.add_item("Цель: ворота %02d" % (slot + 1))
		_trap_action_destination.set_item_metadata(_trap_action_destination.item_count - 1, slot)
		if aim_slot == slot:
			_trap_action_destination.select(_trap_action_destination.item_count - 1)
	if is_roll and _trap_action_destination.item_count > 0 and not pending.get("slots", []).has(aim_slot):
		aim_slot = int(_trap_action_destination.get_item_metadata(0))
		aim_point = BoardLayout.POSITIONS[aim_slot]
	_trap_action_button.text = "Поставить бакугана" if is_roll else "Заменить бакугана"
	_trap_action_button.disabled = _trap_action_incoming.item_count == 0 or (not is_roll and _trap_action_outgoing.item_count == 0) or visual_phase in ["flying", "rolling"]
	if is_roll:
		_hint.text = _trap_action_hint.text


func _rebuild_hands() -> void:
	for child: Node in _hand_grid.get_children():
		_hand_grid.remove_child(child)
		child.queue_free()
	if rules.phase == "finished":
		var restart: Button = _button("Сыграть снова")
		restart.disabled = _result_input_locked
		restart.pressed.connect(func(): start_match())
		_hand_grid.add_child(restart)
		var deck: Button = _button("Изменить колоду")
		deck.pressed.connect(_show_deck)
		_hand_grid.add_child(deck)
		return
	if rules.phase in ["opening", "turn"]:
		_hand_grid.add_child(_label("КАРТЫ ВОРОТ", 14, CYAN))
		for index: int in range(rules.gate_hands[0].size()):
			var card: Dictionary = _hand_card(rules.gate_hands[0][index], true)
			var button: Button = _card_button(str(card.get("title", "Ворота")), str(card.get("description_ru", card.get("description", ""))), CYAN)
			button.disabled = rules.turn != 0 or visual_phase in ["flying", "rolling"] or _result_input_locked
			button.modulate = ORANGE if selected_gate == index else WHITE
			button.pressed.connect(_select_gate.bind(index))
			_hand_grid.add_child(button)
	_hand_grid.add_child(_label("КАРТЫ СПОСОБНОСТЕЙ", 14, ORANGE))
	for index: int in range(rules.ability_hands[0].size()):
		var card: Dictionary = _hand_card(rules.ability_hands[0][index], false)
		var button: Button = _card_button(str(card.get("title", "Способность")), str(card.get("description_ru", card.get("description", ""))), ORANGE)
		button.disabled = rules.ability_options(0,index).is_empty()
		button.modulate = CYAN if str(card.id)==selected_ability else WHITE
		button.tooltip_text += "\nВыбери карту, затем участника и цель. Кнопка активации расходует карту."
		if button.disabled and rules.phase == "battle":
			button.tooltip_text += "\n" + rules.ability_error(0, index, selected_caster, selected_target, selected_target_owner)
		button.pressed.connect(_select_ability.bind(index))
		_hand_grid.add_child(button)
	var selected: int = _selected_ability_index()
	_activate_button.disabled = selected<0 or not rules.can_play_ability(0,selected,selected_caster,selected_target,selected_target_owner)
	_activate_button.text = "Активировать: "+str(rules.ability_hands[0][selected].title) if selected>=0 else "Сначала выбери способность"
	_activate_button.tooltip_text = rules.ability_error(0,selected,selected_caster,selected_target,selected_target_owner) if selected>=0 else "Участники и цели будут отфильтрованы по выбранной карте."


func _selected_ability_index() -> int:
	for index: int in rules.ability_hands[0].size():
		if str(rules.ability_hands[0][index].id)==selected_ability: return index
	return -1


func _select_ability(index: int) -> void:
	if _gameplay_input_blocked() or rules.ability_options(0,index).is_empty(): return
	selected_ability=str(rules.ability_hands[0][index].id)
	_refresh_ui()


func _activate_selected_ability() -> void:
	var index: int = _selected_ability_index()
	if _gameplay_input_blocked() or index<0: return
	if not rules.can_play_ability(0,index,selected_caster,selected_target,selected_target_owner): return
	selected_ability=""
	_handle_result(rules.play_ability(0,index,selected_caster,selected_target,selected_target_owner))


func _refresh_battle_choices() -> void:
	var selected: int = _selected_ability_index()
	var options: Array[Dictionary] = []
	if selected>=0: options=rules.ability_options(0,selected)
	var casters: Array[int] = []
	for option: Dictionary in options:
		if not casters.has(int(option.caster_index)): casters.append(int(option.caster_index))
	_caster_select.clear()
	for unit: Dictionary in rules.battle_units(0):
		if not options.is_empty() and not casters.has(int(unit.index)): continue
		var breakdown: Dictionary = rules.battle_unit_breakdown(0, int(unit.index))
		_caster_select.add_item("Играет: %s · %d G" % [unit.name, breakdown.get("total", 0)])
		_caster_select.set_item_metadata(_caster_select.item_count - 1, int(unit.index))
		if int(unit.index) == selected_caster:
			_caster_select.select(_caster_select.item_count - 1)
	if _caster_select.item_count > 0:
		selected_caster = int(_caster_select.get_item_metadata(maxi(0, _caster_select.selected)))
	_target_select.clear()
	for owner: int in [1, 0]:
		for unit: Dictionary in rules.battle_units(owner):
			if not options.is_empty():
				var allowed: bool = false
				for option: Dictionary in options:
					if int(option.caster_index)==selected_caster and int(option.target_owner)==owner and int(option.target_index)==int(unit.index): allowed=true
				if not allowed: continue
			var breakdown: Dictionary = rules.battle_unit_breakdown(owner, int(unit.index))
			_target_select.add_item(("Цель: " if owner == 1 else "Союзник: ") + "%s · %d G" % [unit.name, breakdown.get("total", 0)])
			_target_select.set_item_metadata(_target_select.item_count - 1, {"owner": owner, "index": int(unit.index)})
			if int(unit.index) == selected_target and owner == selected_target_owner:
				_target_select.select(_target_select.item_count - 1)
	if _target_select.item_count > 0:
		var target: Dictionary = _target_select.get_item_metadata(maxi(0, _target_select.selected))
		selected_target = int(target.index)
		selected_target_owner = int(target.owner)


func _hand_card(value: Variant, gate: bool) -> Dictionary:
	if value is Dictionary:
		return value
	return Cards.get_gate(str(value)) if gate else Cards.get_ability(str(value))


func _build_pause() -> void:
	# Modal input must cover the entire viewport, including the side hand and
	# bottom units outside the centered dialog. It also backs the deck editor.
	_modal_blocker = ColorRect.new()
	_modal_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_blocker.color = Color(0.0, 0.0, 0.0, 0.45)
	_modal_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_blocker.z_index = 70
	hud.add_child(_modal_blocker)
	_modal_blocker.hide()
	_pause_panel = _panel()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -235
	_pause_panel.offset_right = 235
	_pause_panel.offset_top = -215
	_pause_panel.offset_bottom = 215
	_pause_panel.z_index = 80
	hud.add_child(_pause_panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(body)
	body.add_child(_label("ДУЭЛЬ ПРИОСТАНОВЛЕНА", 23, WHITE))
	for entry: Array in [["Продолжить", "resume"], ["Новая дуэль", "restart"], ["Изменить колоду", "deck"], ["Главное меню", "menu"]]:
		var action: String = entry[1]
		var button: Button = _button(entry[0])
		button.custom_minimum_size.y = 52
		button.pressed.connect(func():
			match action:
				"resume": _set_paused(false)
				"restart": start_match()
				"deck": _show_deck()
				"menu":
					_save_match()
					get_tree().change_scene_to_file("res://main.tscn")
		)
		body.add_child(button)
	var note: Label = _label("Уничтожь всех трёх бакуганов соперника. В бою карты играются по очереди; два паса завершают цепочку, ещё два — бой.", 15, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	_pause_panel.hide()


func _set_paused(value: bool) -> void:
	_cancel_charge()
	paused = value
	audio.set_suspended(value)
	_modal_blocker.visible = value
	battle_presentation.set_suspended(value or _battle_needs_board())
	_pause_panel.visible = value
	if value: _save_match()

func _save_match() -> void:
	_save_clock=0.0; _saved_phase=rules.phase
	if started and rules.phase=="finished":
		_save_error=Slots.write(save_slot,{}); return
	var data: Dictionary=AnimeCheckpoint.capture(self)
	if not data.is_empty(): _save_error=Slots.write(save_slot,data)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: controls.reset()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save_match(); _save_deck(); preload("res://scripts/save_files.gd").quit_or_warn(self,[_save_error,_deck_save_error])


func _cancel_charge() -> void:
	charging = false
	charge = 0.0
	_charge_bar.value = 0.0


func _load_deck() -> void:
	gate_loadout = Cards.default_gate_loadout(selected_team)
	ability_loadout = Cards.default_ability_loadout(selected_team)
	support_selection = _default_support_selection(selected_team)
	var config: ConfigFile = ConfigFile.new()
	var path: String=preload("res://scripts/save_files.gd").resolve(DECK_PATH)
	if config.load(path)!=OK and config.load(path+".bak")!=OK:
		return
	var gates: Variant = config.get_value("deck", "gates", [])
	var abilities: Variant = config.get_value("deck", "abilities", [])
	if gates is Array and Cards.valid_gate_loadout(gates):
		gate_loadout = gates
	if abilities is Array and Cards.valid_ability_loadout(abilities):
		ability_loadout = abilities
	var support: Variant = config.get_value("deck", "support", support_selection)
	if Traps.valid_selection(support):
		support_selection = _compact_support_selection(support)


func _save_deck() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("deck", "gates", gate_loadout)
	config.set_value("deck", "abilities", ability_loadout)
	config.set_value("deck", "support", support_selection)
	_deck_save_error=preload("res://scripts/save_files.gd").write_config(config,DECK_PATH)


func _build_deck_editor() -> void:
	_deck_panel = _panel()
	_deck_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_panel.offset_left = 140
	_deck_panel.offset_right = -140
	_deck_panel.offset_top = 80
	_deck_panel.offset_bottom = -70
	_deck_panel.z_index = 90
	hud.add_child(_deck_panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_deck_panel.add_child(body)
	body.add_child(_label("СОБЕРИ КОЛОДУ ДЛЯ ДУЭЛИ", 27, WHITE))
	var description: Label = _label("3 бакугана · 6 карт ворот · 10 способностей. Начальная рука: 3 ворот и 5 способностей. Подбирай способности под свою команду.", 15, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(description)
	_team_info = RichTextLabel.new()
	_team_info.bbcode_enabled = true
	_team_info.fit_content = true
	_team_info.scroll_active = false
	_team_info.custom_minimum_size.y = 66
	_team_info.add_theme_font_size_override("normal_font_size", 13)
	_team_info.add_theme_color_override("default_color", MUTED)
	_team_info.meta_clicked.connect(func(meta: Variant):
		var url: String = str(meta)
		if url.begins_with("https://"):
			OS.shell_open(url)
	)
	body.add_child(_team_info)
	_refresh_native_team_info()
	_build_support_editor(body)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	for kind: String in ["gate", "ability"]:
		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(box)
		box.add_child(_label("6 КАРТ ВОРОТ" if kind == "gate" else "10 СПОСОБНОСТЕЙ", 18, CYAN if kind == "gate" else ORANGE))
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 7)
		scroll.add_child(list)
		var catalog: Array = Cards.GATES if kind == "gate" else Cards.ABILITIES
		var count: int = 6 if kind == "gate" else 10
		for slot: int in range(count):
			var selector: OptionButton = OptionButton.new()
			selector.custom_minimum_size.y = 40
			selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for card: Dictionary in catalog:
				selector.add_item(str(card.title))
				selector.set_item_metadata(selector.item_count - 1, str(card.id))
			selector.item_selected.connect(func(_index: int): _update_deck_selection())
			list.add_child(selector)
			if kind == "gate":
				_gate_selectors.append(selector)
			else:
				_ability_selectors.append(selector)
	_deck_error = _label("", 14, ORANGE)
	body.add_child(_deck_error)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	var defaults: Button = _button("Подобрать под команду")
	defaults.pressed.connect(func():
		gate_loadout = Cards.default_gate_loadout(selected_team)
		ability_loadout = Cards.default_ability_loadout(selected_team)
		support_selection = _default_support_selection(selected_team)
		_fill_deck_selectors()
	)
	actions.add_child(defaults)
	var begin: Button = _button("Начать дуэль")
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	begin.pressed.connect(func():
		_update_deck_selection()
		start_match()
	)
	actions.add_child(begin)
	var back: Button = _button("Главное меню")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	actions.add_child(back)
	_fill_deck_selectors()


func _show_deck() -> void:
	if is_instance_valid(audio): audio.set_suspended(false)
	_cancel_charge()
	paused = true
	_modal_blocker.show()
	battle_presentation.set_suspended(true)
	_pause_panel.hide()
	_deck_panel.show()
	_fill_deck_selectors()


func _fill_deck_selectors() -> void:
	for pair: Array in [[_gate_selectors, gate_loadout], [_ability_selectors, ability_loadout]]:
		var selectors: Array = pair[0]
		var ids: Array = pair[1]
		for index: int in range(selectors.size()):
			var selector: OptionButton = selectors[index]
			for option: int in range(selector.item_count):
				if str(selector.get_item_metadata(option)) == str(ids[index]):
					selector.select(option)
					break
	_fill_support_selector()
	_update_deck_selection()


func _update_deck_selection() -> void:
	gate_loadout.clear()
	ability_loadout.clear()
	for selector: OptionButton in _gate_selectors:
		gate_loadout.append(str(selector.get_item_metadata(selector.selected)))
		var card: Dictionary = Cards.get_gate(gate_loadout[-1])
		selector.tooltip_text = str(card.get("description_ru", card.get("description", "")))
	for selector: OptionButton in _ability_selectors:
		ability_loadout.append(str(selector.get_item_metadata(selector.selected)))
		var card: Dictionary = Cards.get_ability(ability_loadout[-1])
		selector.tooltip_text = "%s\nНе более %d в колоде" % [card.get("description_ru", card.get("description", "")), card.get("limit", 3)]
	_update_support_selection()
	if Cards.valid_gate_loadout(gate_loadout) and Cards.valid_ability_loadout(ability_loadout):
		_deck_error.text = "Колода готова. Эффекты выбранной карты можно прочитать, наведя на неё курсор."
	else:
		_deck_error.text = "Проверь ограничения повторов карт. Выбери другие карты или подбор под команду."


func _build_support_editor(parent: VBoxContainer) -> void:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 5)
	parent.add_child(section)
	section.add_child(_label("БАКУГАН-ЛОВУШКА · ОТДЕЛЬНЫЙ СЛОТ ДЛЯ АНИМЕ-ДУЭЛИ", 15, CYAN))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	section.add_child(row)
	_support_selector = OptionButton.new()
	_support_selector.custom_minimum_size = Vector2(285, 35)
	_support_selector.add_item("Без поддержки")
	_support_selector.set_item_metadata(0, "")
	for support: Dictionary in Traps.supports():
		if str(support.get("category", "trap")) != "trap":
			continue
		_support_selector.add_item(str(support.name))
		_support_selector.set_item_metadata(_support_selector.item_count - 1, str(support.id))
		_support_selector.set_item_disabled(_support_selector.item_count - 1, not support.get("supported", false))
	_support_selector.item_selected.connect(func(_index: int):
		_fill_support_attributes()
		_update_support_selection()
	)
	row.add_child(_support_selector)
	_support_attribute = OptionButton.new()
	_support_attribute.custom_minimum_size = Vector2(115, 35)
	_support_attribute.item_selected.connect(func(_index: int): _update_support_selection())
	row.add_child(_support_attribute)
	var note: Label = _label("Помогает только в бою; не занимает место среди трёх бакуганов.", 13, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	_support_info = _label("", 13, MUTED)
	_support_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_support_info.max_lines_visible = 3
	section.add_child(_support_info)


func _fill_support_selector() -> void:
	var id: String = str(support_selection.get("id", "")) if support_selection is Dictionary else ""
	_support_selector.select(0)
	for option: int in range(_support_selector.item_count):
		if str(_support_selector.get_item_metadata(option)) == id:
			_support_selector.select(option)
			break
	_fill_support_attributes()


func _fill_support_attributes() -> void:
	var id: String = str(_support_selector.get_item_metadata(_support_selector.selected))
	var entry: Dictionary = Traps.get_support(id)
	var selected: String = str(support_selection.get("attribute", "")) if support_selection is Dictionary else ""
	_support_attribute.clear()
	for attribute: String in _support_attributes(entry):
		_support_attribute.add_item(attribute)
		_support_attribute.set_item_metadata(_support_attribute.item_count - 1, attribute)
		if attribute == selected:
			_support_attribute.select(_support_attribute.item_count - 1)
	if _support_attribute.item_count > 0 and _support_attribute.selected < 0:
		_support_attribute.select(0)
	_support_attribute.visible = _support_attribute.item_count > 0


func _update_support_selection() -> void:
	var id: String = str(_support_selector.get_item_metadata(_support_selector.selected))
	if id.is_empty() or _support_attribute.item_count == 0:
		support_selection = null
		_support_info.text = "Поддержка не выбрана. Её можно вызвать один раз за матч в свой ответ во время боя."
		_support_info.tooltip_text = ""
		return
	var attribute: String = str(_support_attribute.get_item_metadata(_support_attribute.selected))
	support_selection = {"id": id, "attribute": attribute}
	var entry: Dictionary = Traps.get_support(id)
	_support_info.text = _support_description(entry, attribute)
	var has_compatible: bool = false
	for unit: Dictionary in selected_team:
		if str(unit.get("attribute", "")) == attribute:
			has_compatible = true
			break
	if not has_compatible:
		_support_info.text += " В команде нет бакугана этой стихии: вызвать ловушку будет нельзя."
	_support_info.tooltip_text = _support_info.text + "\n" + str(entry.get("source_url", "")) + "\n" + str(entry.get("source_excerpt", ""))


func _support_attributes(entry: Dictionary) -> Array[String]:
	var attributes: Array[String] = []
	for attribute: Variant in entry.get("playable_attributes", entry.get("native_attributes", entry.get("attributes", []))):
		if attribute is String:
			attributes.append(attribute)
	return attributes


func _default_support_selection(team: Array) -> Variant:
	for entry: Dictionary in Traps.supports():
		if str(entry.get("category", "trap")) != "trap" or not entry.get("supported", false):
			continue
		for attribute: String in _support_attributes(entry):
			for unit: Dictionary in team:
				if str(unit.get("attribute", "")) == attribute:
					return {"id": str(entry.id), "attribute": attribute}
	return null


func _compact_support_selection(value: Variant) -> Variant:
	if not value is Dictionary or value.is_empty():
		return null
	return {"id": str(value.get("id", "")), "attribute": str(value.get("attribute", ""))}


func _support_description(entry: Dictionary, attribute: String) -> String:
	if entry.is_empty():
		return ""
	var description: String = str(entry.get("description_ru", ""))
	if description.is_empty():
		description = str(entry.get("description", ""))
	var anime_power: Variant = entry.get("anime_g")
	var power: String = "%d G в аниме." % int(anime_power) if anime_power != null else "Сила в аниме не подтверждена."
	var identity: String = "Стихия показана в аниме." if entry.get("anime_attributes", []).has(attribute) else "Стихия этой карты; в аниме не подтверждена."
	return "%s · %s. %s %s Эффект действует без собственной G. %s" % [entry.get("name", "Ловушка"), attribute, identity, power, description]


func _native_unit_tooltip(unit: Dictionary) -> String:
	var note: String = str(unit.get("g_note", "G-Power: %s" % str(unit.get("g", "неизвестна"))))
	var source: String = str(unit.get("canonical_source_url", ""))
	return "%s · %s\n%s%s" % [unit.get("name", "Бакуган"), unit.get("attribute", ""), note, ("\n" + source) if not source.is_empty() else ""]


func _refresh_native_team_info() -> void:
	var lines: Array[String] = []
	for unit: Dictionary in selected_team:
		var power: String = "%d G" % int(unit.get("g", 0))
		if not unit.get("g_verified", false):
			power += " · условная сила"
		var source: String = str(unit.get("canonical_source_url", ""))
		var provenance: String = " [url=%s]источник[/url]" % source if source.begins_with("https://") else ""
		lines.append("%s · %s · %s%s" % [unit.get("name", "Бакуган"), unit.get("attribute", ""), power, provenance])
	_team_info.text = "\n".join(lines)


func _card_button(title: String, description: String, accent: Color) -> Button:
	var button: Button = _button("")
	button.custom_minimum_size.y = 78
	button.tooltip_text = title + "\n" + description
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 9
	box.offset_right = -9
	box.offset_top = 7
	box.offset_bottom = -7
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var name: Label = _label(title, 15, accent)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	var effect: Label = _label(description, 12, WHITE)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 3
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(effect)
	return button


func _panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("354260"), 14))
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 39
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", _style(Color("1c2940"), Color("455677"), 10))
	button.add_theme_stylebox_override("hover", _style(Color("263c55"), CYAN, 10))
	button.add_theme_stylebox_override("pressed", _style(Color("173f52"), CYAN, 10))
	button.add_theme_stylebox_override("focus", _style(Color("203b50"), ORANGE, 10))
	return button


func _style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
