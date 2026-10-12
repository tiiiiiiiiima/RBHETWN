extends SceneTree
## Integration risks: source monsters, saved outcomes, grouped identities,
## and temporarily returning to the board for Hexstar's real additional throw.

const Duel = preload("res://scripts/anime_duel.gd")
const Roster = preload("res://scripts/roster.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")
const Traps = preload("res://scripts/anime_trap_catalog.gd")
const Board = preload("res://scripts/board_layout.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		push_error(text)


func _start_battle(scene: Node3D, unit_index: int = 1, own_attribute: String = "Pyrus") -> void:
	scene.start_match(10123)
	scene.rules.gate_hands[0][0] = Cards.get_gate(own_attribute.to_lower() + "_50")
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene._flight_owner = 0
	scene._flight_unit = unit_index
	scene._finish_throw(5)
	scene._handle_result(scene.rules.throw_unit(1, 0, 5))
	scene._handle_result(scene.rules.open_gate(0))


func _run() -> void:
	var scene: Node3D = Duel.new()
	scene.configure(Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), "ds_pyrus", {"reduced_motion": false}, "straight")
	scene.auto_ai = false
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	_start_battle(scene)
	var presentation: Control = scene.battle_presentation
	_check(presentation.visible and presentation.is_presenting(), "A contested gate opens the separate DS battle world")
	_check(presentation.viewport.own_world_3d, "Battle cameras cannot replace the throwing field camera")
	_check(presentation.actors.size() == 2, "Both participants have their own stable owner/index identity")
	var drago: Node3D = presentation.actors.get("0:1")
	_check(drago != null and str(drago.get_meta("actual_form", "")) == "battle", "Drago uses an actual monster rather than its open toy")
	_check(drago != null and str(drago.get_meta("asset_path", "")).begins_with("res://assets/monster_batch/"), "Drago's runtime geometry uses the preferred Monster batch replacement")
	if drago != null:
		var identity: int = drago.get_instance_id()
		for refresh: int in range(5):
			scene._sync_field()
		_check((presentation.actors["0:1"] as Node3D).get_instance_id() == identity, "Score refreshes preserve animated instances instead of respawning them")
	_check(presentation.snapshot.totals == scene.rules.battle_totals(), "Native G widgets receive the actual rule totals")
	_check(presentation.snapshot.gate.revealed, "Gate reveal updates the presentation's independent state")
	var time_before: float = presentation._elapsed
	scene._set_paused(true)
	await create_timer(0.08).timeout
	_check(not presentation.visible and presentation._elapsed == time_before, "Anime pause freezes the visual timeline and hides the battle world")
	scene._set_paused(false)
	_check(presentation.visible, "Resume restores the current battle")
	var saved_names: Array = presentation.snapshot.units.duplicate(true)
	var guard: int = 0
	while scene.rules.phase == "battle" and guard < 12:
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
		guard += 1
	_check(not scene.rules.gates.has(5) and scene.rules.battle.is_empty(), "Rule resolution removes the spent gate")
	_check(presentation.is_result_playing() and not presentation.actors.is_empty(), "Victory presentation keeps the native participants after rule cleanup")
	_check(presentation.snapshot.units == saved_names, "Result playback uses a retained snapshot rather than reset unit dictionaries")
	_check(not scene._can_player_throw(), "A new throw waits for the visible result to finish")
	await create_timer(1.6).timeout
	_check(not presentation.is_presenting() and presentation.actors.is_empty(), "The result returns to the throwing field and releases actors")
	_start_battle(scene)
	var group_state: Dictionary = presentation.snapshot.duplicate(true)
	var clone: Dictionary = group_state.units[0].duplicate(true)
	clone.index = -7
	clone.temporary_clone = true
	group_state.units.append(clone)
	presentation.sync_battle(group_state)
	_check(presentation.actors.size() == 3 and presentation.actors.has("0:-7"), "A temporary allied copy has a separate visual identity")
	scene._sync_battle_presentation()
	_check(presentation.actors.size() == 2, "Removed copies disappear without replacing the original participant")
	scene.selected_team = Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Haos"])
	scene.support_selection = {"id": "hexstar", "attribute": "Haos"}
	_start_battle(scene, 2, "Haos")
	if int(scene.rules.battle.priority) == 1:
		scene._handle_result(scene.rules.pass_response(1))
	scene._handle_result(scene.rules.deploy_trap(0, 2, 0, {}))
	guard = 0
	while not scene.rules.battle.get("chain", []).is_empty() and scene.rules.pending_trap_action().is_empty() and guard < 8:
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
		guard += 1
	var pending: Dictionary = scene.rules.pending_trap_action()
	_check(not pending.is_empty() and str(pending.get("type", "")) == "roll", "The actual Hexstar response creates an additional card placement")
	_check(not presentation.visible and scene._camera_battle_slot == -1, "A mandatory card choice temporarily returns to the board camera")
	if not pending.is_empty():
		scene._launch_throw(0, int(pending.available_indices[0]), Board.POSITIONS[5], 0.8)
	_check(presentation.visible, "Resolving the extra throw restores the same DS battle stage")
	scene.start_match(10124)
	_check(not presentation.is_presenting() and presentation.snapshot.is_empty(), "Restart clears the previous participants and result")
	scene.queue_free()
	await process_frame
	print("DS ANIME PRESENTATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
