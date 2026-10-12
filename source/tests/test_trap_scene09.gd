extends SceneTree
## Exercise source trap selection, real response callbacks and mandatory actions.

const DuelScene = preload("res://scripts/anime_duel.gd")
const Roster = preload("res://scripts/roster.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")
const Traps = preload("res://scripts/anime_trap_catalog.gd")
const Layout = preload("res://scripts/board_layout.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _select_support(scene: Node3D, identity: String) -> bool:
	for option: int in range(scene._support_selector.item_count):
		if str(scene._support_selector.get_item_metadata(option)) == identity:
			scene._support_selector.select(option)
			scene._support_selector.item_selected.emit(option)
			return true
	return false


func _battle(scene: Node3D, index: int = 1, own_attribute: String = "Pyrus") -> void:
	scene.start_match(9021)
	scene.rules.gate_hands[0][0] = Cards.get_gate(own_attribute.to_lower() + "_50")
	scene.rules.gate_hands[1][0] = Cards.get_gate("aquos_50")
	scene.selected_gate = 0
	scene._try_place_gate(5)
	scene._handle_result(scene.rules.place_gate(1, 0, 6))
	scene._flight_owner = 0
	scene._flight_unit = index
	scene._finish_throw(5)
	scene._handle_result(scene.rules.throw_unit(1, 0, 5))
	scene.selected_caster = index
	scene.selected_target = 0
	scene.selected_target_owner = 1
	scene._refresh_ui()


func _resolve_chain(scene: Node3D) -> void:
	var guard: int = 0
	while scene.rules.phase == "battle" and not scene.rules.battle.chain.is_empty() and scene.rules.pending_trap_action().is_empty() and guard < 10:
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
		guard += 1


func _run() -> void:
	var scene = DuelScene.new()
	scene.configure(Roster.make_team([0, 1, 2], ["Pyrus", "Aquos", "Ventus"]), "anime_board", {"reduced_motion": true}, "straight")
	scene.auto_ai = false
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	_check(scene.selected_team[1].attribute == "Pyrus" and bool(scene.selected_team[1].attribute_locked), "Scene canonicalizes a requested Aquos Drago to its verified native Pyrus identity")
	_check(not bool(scene.selected_team[1].g_verified) and scene._team_info.text.contains("условная сила") and scene._team_info.text.contains("[url="), "Unverified debut G remains explicitly conditional beside a clickable identity source")
	_check(scene._support_selector.item_count == 18, "Preparation has seventeen proper traps and the optional empty slot")
	var all_enabled: bool = true
	var paired_found: bool = false
	for option: int in range(1, scene._support_selector.item_count):
		all_enabled = all_enabled and not scene._support_selector.is_item_disabled(option)
		paired_found = paired_found or str(scene._support_selector.get_item_metadata(option)) == "shadow_wing"
	_check(all_enabled and not paired_found, "All printed trap effects are selectable and paired Shadow Wing is outside the trap category")
	_check(_select_support(scene, "metalfencer"), "Player selects Metalfencer in its separate preparation slot")
	_check(scene.support_selection == {"id": "metalfencer", "attribute": "Pyrus"} and scene.selected_team.size() == 3, "Choosing a trap preserves the three regular team members")
	_check(scene._support_info.tooltip_text.contains("Adds Metalfencer") and scene._support_info.tooltip_text.contains("https://"), "Preparation preserves the original printed effect and source link")
	_battle(scene)
	_check(scene.rules.phase == "battle" and not scene._trap_button.disabled, "A compatible native Pyrus participant can deploy the selected trap with response priority")
	_check(not scene._trap_status.text.contains("Соперник:"), "Opponent's ready trap remains private before deployment")
	var before: int = int(scene.rules.battle_breakdown(0).total)
	scene._trap_button.pressed.emit()
	_check(scene.rules.support_slots[0].used and scene.rules.support_slots[0].status == "pending", "Trap button consumes the one-use slot and creates a response-chain node")
	_check(scene._support_nodes.has(0) and scene._support_nodes[0].get_meta("support_id", "") == "metalfencer", "Deployment displays the selected native 3D trap beside its participant")
	_check(scene._support_nodes[0].get_meta("actual_form", "") == "toy", "Deployed trap uses its source open model")
	scene.rules.ability_hands[1] = [Cards.get_ability("double_dimension")]
	_check(scene.rules.play_ability(1, 0).get("ok", false), "Opponent can counter an unanswered trap activation")
	scene._refresh_ui()
	_resolve_chain(scene)
	_check(scene.rules.support_slots[0].status == "spent" and int(scene.rules.support_slots[0].stats.countered) == 1, "Countered trap stays used and records its cancelled activation")
	_check(scene._trap_button.disabled and not scene._support_nodes.has(0), "Countered trap cannot be summoned twice and its pending model is removed")
	_check(int(scene.rules.battle_breakdown(0).total) == before, "A countered trap applies no power change")
	_check(scene.start_match(9022).get("ok", false) and not scene.rules.support_slots[0].used and scene.rules.support_slots[0].status == "ready", "Restart restores the selected trap for the new match")
	_check(int(scene.rules.support_slots[0].stats.deployments) == 0 and scene._support_nodes.is_empty(), "Restart clears support statistics and old models")
	_check(scene._trap_button.disabled and not scene.rules.can_deploy_trap(0), "Trap remains unavailable outside an anime battle")
	var config: ConfigFile = ConfigFile.new()
	_check(config.load(scene.DECK_PATH) == OK and config.get_value("deck", "support", null) == scene.support_selection, "Separate anime deck save persists the trap selection")
	_check(config.get_value("deck", "gates", []).size() == 6 and config.get_value("deck", "abilities", []).size() == 10, "Saving a trap retains the complete six/ten card loadout")
	var reloaded = DuelScene.new()
	reloaded.configure(Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Ventus"]), "anime_board", {}, "lob")
	reloaded.auto_ai = false
	root.add_child(reloaded)
	await process_frame
	reloaded.set_process(false)
	_check(reloaded.support_selection == scene.support_selection, "A fresh duel scene loads the saved separate trap slot")
	reloaded.queue_free()
	await process_frame
	_battle(scene)
	scene._trap_button.pressed.emit()
	_resolve_chain(scene)
	_check(scene.rules.support_slots[0].status == "deployed" and int(scene.rules.support_slots[0].stats.successful) == 1, "Unanswered trap resolves and records a successful effect")
	_check(int(scene.rules.battle_breakdown(0).support) == 50 and scene._battle_label.text.contains("поддержка"), "Resolved Metalfencer power appears in the separate support component")
	_check(scene._support_nodes.has(0) and scene._support_nodes[0].get_meta("support_status", "") == "deployed", "Resolved trap stays visible during the battle")
	var guard: int = 0
	while scene.rules.phase == "battle" and guard < 10:
		scene._handle_result(scene.rules.pass_response(int(scene.rules.battle.priority)))
		guard += 1
	_check(scene.rules.phase != "battle" and scene._support_nodes.is_empty(), "Battle completion clears the 3D trap without restoring its one-use slot")
	_check(scene.rules.support_slots[0].used and scene.rules.support_slots[0].status == "spent", "Successfully used trap remains spent until the next match")
	scene.queue_free()
	await process_frame
	var extra = DuelScene.new()
	extra.configure(Roster.make_anime_team([0, 1, 2], ["Pyrus", "Pyrus", "Haos"]), "anime_board", {"reduced_motion": true}, "straight")
	extra.auto_ai = false
	root.add_child(extra)
	await process_frame
	extra.set_process(false)
	_check(_select_support(extra, "hexstar"), "Player selects the source Hexstar trap")
	_battle(extra, 2, "Haos")
	extra._trap_button.pressed.emit()
	_resolve_chain(extra)
	var action: Dictionary = extra.rules.pending_trap_action()
	_check(not action.is_empty() and action.type == "roll" and int(action.owner) == 0, "Hexstar suspends the response chain for a player's real extra roll")
	_check(extra._trap_action_box.visible and extra._trap_action_incoming.item_count == 2 and extra._trap_action_destination.item_count > 0, "Mandatory roll controls offer only reserve Bakugan and eligible gate destinations")
	_check(extra._pass_button.disabled and not extra.rules.pass_response(0).get("ok", true), "A mandatory extra roll cannot be skipped through the normal pass action")
	extra.aim_slot = 5
	extra.aim_point = Layout.POSITIONS[5]
	extra.selected_unit = int(action.available_indices[0])
	extra._refresh_ui()
	var placed_index: int = extra.selected_unit
	extra._trap_action_button.pressed.emit()
	_check(extra.visual_phase == "idle" and extra._flight_ball == null, "Extra placement resolves on the selected card without a physical throw")
	_check(extra.rules.pending_trap_action().is_empty() and extra.rules.teams[0][placed_index].status == "reserve", "Placement on Hexstar's current gate returns the extra Bakugan to reserve and resumes the chain")
	_check(not extra._trap_action_box.visible and extra._flight_ball == null and extra.visual_phase == "idle", "Resolving the extra roll removes action controls and moving sphere")
	extra.queue_free()
	await process_frame
	var swap = DuelScene.new()
	swap.configure(Roster.make_anime_team([3, 4, 5], ["Darkus", "Aquos", "Subterra"]), "anime_board", {}, "lob")
	swap.auto_ai = false
	root.add_child(swap)
	await process_frame
	swap.set_process(false)
	_select_support(swap, "flash_falcon_fly")
	_battle(swap, 0, "Darkus")
	swap._trap_button.pressed.emit()
	_resolve_chain(swap)
	action = swap.rules.pending_trap_action()
	_check(not action.is_empty() and action.type == "swap" and int(action.owner) == 0, "Flash Falcon Fly first requests the player's mandatory reserve substitution")
	_check(swap._trap_action_incoming.item_count == 2 and swap._trap_action_outgoing.item_count == 1 and swap._trap_action_outgoing.visible, "Swap controls separate incoming reserve and outgoing battle participant")
	swap._trap_action_button.pressed.emit()
	action = swap.rules.pending_trap_action()
	_check(not action.is_empty() and int(action.owner) == 1 and swap.rules.teams[0][0].status == "reserve", "Player substitution returns the original participant and queues the opponent's independent choice")
	_check(swap._support_nodes.has(0), "The trap model remains visible beside the replacement participant")
	swap._ai_action()
	_check(swap.rules.pending_trap_action().is_empty() and swap.rules.teams[1][0].status == "reserve", "AI completes its own reserve replacement and resumes the suspended chain")
	_check(swap._caster_select.item_count == 1 and int(swap._caster_select.get_item_metadata(0)) != 0, "Response selectors update to the newly participating Bakugan")
	swap.queue_free()
	await process_frame
	var clone_scene = DuelScene.new()
	clone_scene.configure(Roster.make_anime_team([31, 1, 2], ["Aquos", "Pyrus", "Haos"]), "anime_board", {}, "lob")
	clone_scene.auto_ai = false
	root.add_child(clone_scene)
	await process_frame
	clone_scene.set_process(false)
	_select_support(clone_scene, "tripod_theta")
	_battle(clone_scene, 0, "Aquos")
	clone_scene.rules.teams[0][2].status = "defeated"
	clone_scene.rules.defeated[0].append(2)
	clone_scene._refresh_ui()
	_check(clone_scene._trap_choice_selectors.unit_index.visible and int(clone_scene._trap_options.unit_index) == 2, "Theta offers only actual defeated team members as copy choices")
	clone_scene._trap_button.pressed.emit()
	_resolve_chain(clone_scene)
	var copies: Array = []
	for unit: Dictionary in clone_scene.rules.battle_units(0):
		if bool(unit.get("temporary_clone", false)):
			copies.append(unit)
	_check(copies.size() == 1 and int(copies[0].base_g) == 100 and copies[0].additional_attributes.has("Ventus"), "Resolved Theta creates its printed 100 G Darkus/Ventus temporary copy")
	if copies.size() == 1:
		var key: String = "0:%d" % int(copies[0].index)
		_check(clone_scene._unit_nodes.has(key) and clone_scene._unit_nodes[key].get_meta("temporary_clone", false), "Temporary copy receives a separate 3D model outside the regular three-unit team")
		_check(clone_scene._unit_nodes[key].get_meta("actual_form", "") == "toy" and clone_scene._caster_select.item_count == 2, "The copy uses the original species' source model and appears in battle caster choices")
	_check(clone_scene.rules.teams[0].size() == 3 and clone_scene._unit_buttons.size() == 3, "Temporary copy leaves team and victory accounting at exactly three regular Bakugan")
	clone_scene.queue_free()
	await process_frame
	print("TRAP SCENE 0.9: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
