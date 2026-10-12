extends RefCounted
const Store=preload("res://scripts/match_checkpoint.gd")
const Rules=preload("res://scripts/anime_duel_rules.gd")
const RULE_FIELDS: Array[String]=["turn","phase","winner","teams","gates","gate_hands","ability_hands","gate_decks","ability_decks","spent_gates","spent_abilities","defeated","battle","seed_value","turn_serial","placed_this_turn","acted_this_turn","loadouts","history","support_slots","_opening_queue","_opening_start","_serial","_own_turns","_last_card","_trap_actions","_remaining_chain","_chain_outcomes","_clone_serial"]
const MAIN_FIELDS: Array[String]=["preferences","arena_id","throw_style","selected_team","selected_unit","selected_gate","selected_caster","selected_target","selected_target_owner","selected_ability","aim_point","aim_slot","auto_ai","started","visual_phase","last_throw_slot","gate_loadout","ability_loadout","support_selection","_ai_time","_message","_journal","_trap_options"]
static func capture(duel: Node3D) -> Dictionary:
	if not duel.started or duel.rules.phase=="finished": return {}
	return {"schema":1,"release":"0.20","mode":"anime","main":Store.grab(duel,MAIN_FIELDS),"rules":Store.grab(duel.rules,RULE_FIELDS),"rng_state":duel.rules._random.state,"rng_seed":duel.rules._random.seed,"camera":duel.arena.camera.transform}
static func restore(duel: Node3D, data: Dictionary) -> bool:
	if not Store.valid(data) or not Store.compatible(duel.rules,data.rules,RULE_FIELDS): return false
	# Optional support_selection can legitimately differ from its initial null.
	var fields: Array[String]=MAIN_FIELDS.duplicate(); fields.erase("support_selection")
	if not Store.compatible(duel,data.main,fields): return false
	Store.put(duel,data.main,MAIN_FIELDS); Store.put(duel.rules,data.rules,RULE_FIELDS)
	# Gate occupants and team members share identity in this rules engine.
	for gate: Dictionary in duel.rules.gates.values():
		for index: int in gate.bakugan.size():
			var unit: Dictionary=gate.bakugan[index]
			if not bool(unit.get("temporary_clone",false)):
				gate.bakugan[index]=duel.rules.teams[int(unit.owner)][int(unit.index)]
	duel.rules._random.seed=int(data.rng_seed); duel.rules._random.state=int(data.rng_state)
	duel._deck_panel.hide(); duel._set_paused(false)
	duel._sync_field(); duel._refresh_ui(); duel._sync_camera(); duel._sync_battle_presentation()
	duel.arena.camera.transform=data.camera
	return true
