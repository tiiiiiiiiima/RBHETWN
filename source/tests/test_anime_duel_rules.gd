extends SceneTree
## Card duel invariants: legal turns, targeted reactions, command gates and
## persistent elimination. These tests exercise outcomes, not rendered labels.

const Duel = preload("res://scripts/anime_duel_rules.gd")
const Cards = preload("res://scripts/anime_card_catalog.gd")

var checks: int = 0
var failures: Array[String] = []


func _init() -> void:
	_setup_and_atomicity()
	_turns_and_reserves()
	_hidden_gates_and_powers()
	_reaction_chains()
	_targeted_team_battles()
	_command_gates()
	_elimination_and_refill()
	print("ANIME DUEL CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _team(owner: int, names: Array = ["Leonidas", "Fourtress", "Skyress"], attributes: Array = ["Pyrus", "Haos", "Ventus"], powers: Array = [340, 300, 300]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(3):
		result.append({"id": "p%d_u%d" % [owner, index], "name": str(names[index]), "attribute": str(attributes[index]), "g": int(powers[index]), "used": false})
	return result


func _new(team0: Array = [], team1: Array = [], seed: int = 1234):
	var duel = Duel.new()
	var first: Array = _team(0) if team0.is_empty() else team0
	var second: Array = _team(1, ["Hydranoid", "Juggernoid", "Gorem"], ["Darkus", "Aquos", "Subterra"], [350, 310, 330]) if team1.is_empty() else team1
	_check(duel.new_match(first, second, seed).ok, "Valid source-compatible teams and default decks start a match")
	return duel


func _opening(duel, gate_id: String = "pyrus_50", gate_owner: int = 0) -> void:
	duel.gate_hands[0] = [Cards.get_gate(gate_id if gate_owner == 0 else "aquos_50")]
	duel.gate_hands[1] = [Cards.get_gate(gate_id if gate_owner == 1 else "aquos_50")]
	_check(duel.place_gate(0, 0, 5 if gate_owner == 0 else 0).ok and duel.place_gate(1, 0, 5 if gate_owner == 1 else 0).ok, "Both owners place opening gates in freely chosen separate slots")
	_check(duel.phase == "turn" and duel.turn == 0, "Opening completes before the first throw")


func _fight(gate_id: String = "pyrus_50", first_index: int = 0, second_index: int = 0, team0: Array = [], team1: Array = [], gate_owner: int = 0):
	var duel = _new(team0, team1)
	_opening(duel, gate_id, gate_owner)
	_check(duel.throw_unit(0, first_index, 5).event == "stand", "A valid first throw stands on its gate")
	_check(duel.finish_turn(0).ok, "Standing ends the thrower's turn")
	_check(duel.throw_unit(1, second_index, 5).event == "battle", "Opposed standing begins a card battle")
	return duel


func _two_passes(duel) -> Dictionary:
	var first: Dictionary = duel.pass_response(int(duel.battle.priority))
	_check(first.ok, "The current responder may pass once")
	return duel.pass_response(int(duel.battle.priority))


func _unchanged(duel, result: Dictionary, before: String, message: String) -> void:
	_check(not result.ok and JSON.stringify(duel.state_snapshot()) == before, message)


func _setup_and_atomicity() -> void:
	var duel = _new()
	_check(duel.gate_hands[0].size() == 3 and duel.ability_hands[0].size() == 5 and duel.gate_decks[0].size() == 3 and duel.ability_decks[0].size() == 5, "The local 3/5 initial hand is a partial draw from exact 6/10 decks")
	_check(duel.gate_hands[1].size() == 3 and duel.ability_hands[1].size() == 5, "Both initial hands have the same counts")
	var same = _new([], [], 1234)
	_check(JSON.stringify(duel.gate_hands) == JSON.stringify(same.gate_hands) and JSON.stringify(duel.ability_hands) == JSON.stringify(same.ability_hands), "Same seed reproduces the shuffled hands")
	var different = _new([], [], 5678)
	_check(JSON.stringify(duel.gate_hands) != JSON.stringify(different.gate_hands) or JSON.stringify(duel.ability_hands) != JSON.stringify(different.ability_hands), "A different seed can change the hand order")
	var before: String = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.new_match([], _team(1)), before, "An invalid new team does not replace an active match")
	_unchanged(duel, duel.new_match(_team(0), _team(1), 8, [["unknown"], []]), before, "Invalid deck lengths and identifiers are rejected without spending state")
	_unchanged(duel, duel.place_gate(1, 0, 5), before, "The wrong owner cannot place an opening gate")
	_unchanged(duel, duel.place_gate(0, 99, 5), before, "An invalid hand index cannot spend an opening card")
	_unchanged(duel, duel.throw_unit(0, 0, 5), before, "No throws are allowed before both initial cards are placed")
	_check(duel.legal_gate_slots().size() == 16, "Opening supports all sixteen nonoverlapping positions")


func _turns_and_reserves() -> void:
	var duel = _new()
	_opening(duel)
	duel.gate_hands[0] = [Cards.get_gate("pyrus_70"), Cards.get_gate("ventus_70")]
	_check(duel.place_gate(0, 0, 15).ok, "An optional gate can be placed without an adjacency rule")
	var before: String = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.place_gate(0, 0, 14), before, "A second gate in the same turn is rejected atomically")
	_check(duel.throw_unit(0, 0, 5).ok, "The first creature may stand after optional placement")
	before = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.throw_unit(0, 1, 15), before, "A second throw in the same turn cannot move another creature")
	_check(duel.available_units(0) == [1, 2], "Standing creatures leave the reserve")
	duel.finish_turn(0)
	var opening_enemy_hand: int = duel.ability_hands[1].size()
	_check(opening_enemy_hand == 5, "The enemy's first normal turn does not receive an asymmetric extra initial draw")
	duel.throw_unit(1, 0, -1)
	_check(duel.available_units(1).has(0), "A missed throw keeps a living creature in reserve")
	duel.finish_turn(1)
	_check(duel.ability_hands[0].size() == 6, "A subsequent own turn draws one additional ability")
	_check(duel.recall_unit(0, 0).ok and duel.available_units(0).has(0) and duel.gates[5].bakugan.is_empty(), "Recall restores the selected field creature to reserve")
	before = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.throw_unit(0, 0, 5), before, "Recall consumes the throw action rather than allowing an immediate free rethrow")


func _hidden_gates_and_powers() -> void:
	var duel = _fight()
	_check(duel.battle_totals() == [340, 350] and not duel.gates[5].revealed, "Hidden gates provide no bonus before their owner's reveal")
	var before: String = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.open_gate(1), before, "A nonowner cannot reveal another player's gate")
	_check(duel.open_gate(0).ok and duel.battle_totals() == [390, 350], "Opening an attribute gate adds its printed bonus only to matching creatures")
	duel.ability_hands[1] = [Cards.get_ability("alpha_blaster")]
	before = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.play_ability(1, 0), before, "A species-mismatched ability cannot be consumed")
	duel.pass_response(1)
	duel.ability_hands[0] = [Cards.get_ability("alpha_blaster")]
	_check(duel.play_ability(0, 0).ok and duel.battle_totals() == [390, 350], "An ordinary ability waits in the response chain before changing power")
	_check(_two_passes(duel).event == "chain_resolved" and duel.battle_totals() == [590, 350], "The printed Leonidas boost resolves after both responders pass")
	var detail: Dictionary = duel.battle_breakdown(0)
	_check(detail.base == 340 and detail.gate == 50 and detail.ability == 200 and detail.total == 590, "The displayed total is exactly explained by base, gate and ability G")
	duel.ability_hands[0] = [Cards.get_ability("fire_tornado")]
	duel.play_ability(0, 0)
	_two_passes(duel)
	_check(duel.battle_totals() == [690, 250], "Fire Tornado transfers exactly one hundred from the selected opposing creature")
	var weak_enemy: Array = _team(1, ["Hydranoid", "Juggernoid", "Gorem"], ["Darkus", "Aquos", "Subterra"], [50, 310, 330])
	duel = _fight("pyrus_50", 0, 0, [], weak_enemy)
	duel.ability_hands[0] = [Cards.get_ability("fire_tornado")]
	duel.play_ability(0, 0)
	_two_passes(duel)
	_check(duel.battle_totals() == [390, 0], "Transfer cannot extract more G than the chosen creature actually has")
	var bounded: Dictionary = duel.battle_breakdown(1)
	_check(bounded.base + bounded.gate + bounded.ability == bounded.total and bounded.total == 0, "Zero-floor power remains fully explained without a negative total")


func _reaction_chains() -> void:
	var enemy: Array = _team(1, ["Hydranoid", "Juggernoid", "Gorem"], ["Haos", "Aquos", "Subterra"], [350, 310, 330])
	var duel = _fight("pyrus_50", 0, 0, [], enemy)
	duel.ability_hands[0] = [Cards.get_ability("alpha_blaster")]
	duel.ability_hands[1] = [Cards.get_ability("ability_counter")]
	_check(duel.play_ability(0, 0).ok and duel.play_ability(1, 0).ok, "A legal elemental counter can respond to the last pending enemy card")
	_check(_two_passes(duel).event == "chain_resolved" and duel.battle_totals() == [340, 350], "A counter resolves first and prevents the earlier boost")
	_check(duel.spent_abilities[0].size() == 1 and duel.spent_abilities[1].size() == 1, "Both played cards remain consumed even when an effect is cancelled")
	var counter_own: Array = _team(0, ["Leonidas", "Fourtress", "Skyress"], ["Haos", "Pyrus", "Ventus"], [340, 300, 300])
	duel = _fight("haos_50", 0, 0, counter_own, enemy)
	duel.ability_hands[0] = [Cards.get_ability("alpha_blaster"), Cards.get_ability("ability_counter")]
	duel.ability_hands[1] = [Cards.get_ability("ability_counter")]
	duel.play_ability(0, 0)
	duel.play_ability(1, 0)
	_check(duel.play_ability(0, 0).ok, "A responder can counter the opponent's still-pending counter")
	_two_passes(duel)
	_check(duel.battle_totals() == [540, 350], "Last-in-first-out counter resolution restores the earlier boost without spending another copy")
	var own: Array = _team(0, ["Fourtress", "Leonidas", "Skyress"], ["Haos", "Pyrus", "Ventus"], [300, 340, 300])
	duel = _fight("haos_50", 0, 0, own, enemy)
	duel.ability_hands[0] = [Cards.get_ability("face_of_rage")]
	duel.ability_hands[1] = [Cards.get_ability("ability_counter")]
	_check(duel.play_ability(0, 0).ok and duel.battle.chain.is_empty() and duel.battle_totals() == [350, 300], "Immediate Face Of Rage transfers fifty without entering the pending chain")
	var before: String = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.play_ability(1, 0), before, "A counter cannot target an immediate ability after it has resolved")
	var dark_own: Array = _team(0, ["Leonidas", "Fourtress", "Skyress"], ["Darkus", "Haos", "Ventus"], [340, 300, 300])
	duel = _fight("darkus_50", 0, 0, dark_own)
	duel.ability_hands[0] = [Cards.get_ability("grand_down")]
	duel.play_ability(0, 0)
	duel.pass_response(1)
	before = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.open_gate(0), before, "Grand Down's printed restriction prevents opening the gate in response")
	duel.pass_response(0)
	_check(duel.gates[5].nullified and duel.battle_totals() == [340, 350], "Resolving a gate nullifier prevents its attribute bonus")


func _targeted_team_battles() -> void:
	var own: Array = _team(0, ["Leonidas", "Fourtress", "Skyress"], ["Pyrus", "Haos", "Ventus"], [340, 300, 300])
	var duel = _new(own)
	_opening(duel)
	duel.throw_unit(0, 0, 5)
	duel.finish_turn(0)
	duel.throw_unit(1, 1, 0)
	duel.finish_turn(1)
	_check(duel.throw_unit(0, 2, 5).event == "stack" and duel.gates[5].bakugan.size() == 2, "An allied second standing forms a real team stack")
	duel.finish_turn(0)
	duel.throw_unit(1, 0, 5)
	_check(duel.battle_units(0).size() == 2 and duel.battle_totals() == [640, 350], "The battle includes and sums every stacked allied creature")
	duel.ability_hands[0] = [Cards.get_ability("fire_storm")]
	var before: String = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.play_ability(0, 0, 0, 0), before, "An explicitly wrong caster cannot consume a species-specific ability")
	_check(duel.play_ability(0, 0, 2, 0).ok, "An explicit eligible Skyress can cast from a multi-creature side")
	_two_passes(duel)
	_check(duel.battle_unit_breakdown(0, 0).ability == 0 and duel.battle_unit_breakdown(0, 2).ability == 125 and duel.battle_totals()[0] == 765, "A species boost changes only the chosen caster, while totals include its ally")
	duel.ability_hands[0] = [Cards.get_ability("correlation_ventus_pyrus")]
	_check(duel.play_ability(0, 0, 2, 0, 0).ok, "A Correlation can explicitly select its allied opposite-pair creature")
	_two_passes(duel)
	_check(duel.battle_unit_breakdown(0, 0).ability == 100 and duel.battle_unit_breakdown(0, 2).ability == 225, "Allied Correlation grants one hundred to each of its two selected creatures")
	var result: Dictionary = _two_passes(duel)
	_check(result.event == "battle_end" and result.victor == 0 and duel.defeated[1] == [0] and duel.available_units(0).has(0) and duel.available_units(0).has(2), "Team victory returns every surviving participant and permanently defeats the losing side")
	duel = _fight("pyrus_50", 0, 0, _team(0, ["Leonidas", "Fourtress", "Skyress"], ["Pyrus", "Haos", "Ventus"], [350, 300, 300]))
	result = _two_passes(duel)
	_check(result.tie and result.victor == -1 and duel.defeated[0].is_empty() and duel.defeated[1].is_empty(), "A tied team total returns both sides alive without arbitrary elimination")
	var stronger_enemy: Array = _team(1, ["Hydranoid", "Juggernoid", "Gorem"], ["Darkus", "Aquos", "Subterra"], [2000, 310, 330])
	duel = _new(own, stronger_enemy)
	_opening(duel)
	for index in range(3):
		var standing: Dictionary = duel.throw_unit(0, index, 5)
		_check(standing.ok and (standing.event == "stand" if index == 0 else standing.event == "stack"), "All three allied creatures can stand together on a gate")
		duel.finish_turn(0)
		if index < 2:
			duel.throw_unit(1, 1, -1)
			duel.finish_turn(1)
	duel.throw_unit(1, 0, 5)
	_check(duel.battle_totals() == [940, 2000] and duel.battle_units(0).size() == 3, "Triple standing contributes all three creatures to a team battle")
	result = _two_passes(duel)
	_check(result.defeated_indices == [0, 1, 2] and duel.defeated[0] == [0, 1, 2] and duel.winner == 1, "A losing triple stack eliminates every participant and correctly ends the match")


func _command_gates() -> void:
	var duel = _fight("energy_merge")
	_check(duel.gates[5].revealed and duel.battle_totals() == [465, 225], "Energy Merge automatically opens and transfers one hundred twenty-five from last to first standing")
	_check(duel.battle_breakdown(0).gate == 125 and duel.battle_breakdown(1).gate == -125 and duel.battle_breakdown(0).ability == 0 and duel.battle_breakdown(1).ability == 0, "Command transfers appear under gate power, never under ability power")
	var before: String = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.open_gate(0), before, "An automatically opened gate cannot replay its transfer")
	duel = _fight("aquos_hazard")
	_check(duel.open_gate(0).ok and duel.teams[0][0].attribute == "Aquos" and duel.teams[1][0].attribute == "Aquos", "Hazard changes all battle participants to its printed attribute")
	duel.pass_response(1)
	duel.ability_hands[0] = [Cards.get_ability("fire_tornado"), Cards.get_ability("aqua_guardian")]
	_check(not duel.can_play_ability(0, 0), "Elemental casting checks the changed current attribute after Hazard")
	_check(duel.pass_response(0).event == "battle_end", "The second response pass completes the Hazard battle")
	_check(duel.teams[1][0].attribute == "Darkus", "Returning or defeated creatures recover their selected original attribute")
	duel = _fight("positive_delta", 0, 1)
	duel.open_gate(0)
	_check(duel.battle_totals() == [340, 110], "Positive Delta lowers a selected positive-triad opponent by two hundred")
	_check(duel.battle_breakdown(1).gate == -200 and duel.battle_breakdown(1).ability == 0, "Delta losses are attributed to their gate command")
	duel = _fight("positive_delta")
	duel.open_gate(0)
	_check(duel.battle_totals() == [140, 350], "Positive Delta penalizes the gate owner's chosen creature when the opponent is outside its printed triad")
	duel = _fight("negative_delta")
	before = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.open_gate(0, 99, 0), before, "An invalid command-gate caster does not reveal or spend priority")
	duel.open_gate(0)
	_check(duel.battle_totals() == [340, 150], "Negative Delta applies its separate negative-triad condition")
	duel = _fight("peacemaker")
	var result: Dictionary = duel.open_gate(0)
	_check(result.event == "battle_cancelled" and duel.phase == "turn" and duel.battle.is_empty() and duel.gates.has(5) and duel.gates[5].bakugan.is_empty(), "Peacemaker returns both sides alive and keeps its empty gate on the field")
	_check(duel.defeated[0].is_empty() and duel.defeated[1].is_empty() and duel.available_units(0).has(0) and duel.available_units(1).has(0), "Peacemaker does not record a false defeat or consume living reserve units")
	duel = _fight("aquos_hazard", 0, 0, [], [], 1)
	duel.pass_response(1)
	duel.ability_hands[0] = [Cards.get_ability("fire_tornado")]
	duel.play_ability(0, 0)
	duel.open_gate(1)
	result = _two_passes(duel)
	_check(result.event == "chain_resolved" and result.outcomes[0].event == "ability_failed" and duel.battle_totals() == [340, 350], "A queued elemental ability fails if Hazard removes its caster requirement before resolution")
	_check(duel.spent_abilities[0].size() == 1, "A played card stays consumed when its resolution requirements later fail")
	duel = _fight("energy_merge", 1)
	duel.ability_hands[0] = [Cards.get_ability("face_of_joy")]
	_check(duel.play_ability(0, 0).ok and duel.gates[5].nullified and duel.battle_totals() == [425, 225], "The documented local lifecycle preserves a resolved Command transfer after later nullification")
	_check(duel.battle_breakdown(0).gate == 125 and duel.battle_breakdown(0).ability == 0, "Preserved command power keeps its gate attribution after nullification")


func _elimination_and_refill() -> void:
	var strongest: Array = _team(0, ["Leonidas", "Fourtress", "Skyress"], ["Pyrus", "Haos", "Ventus"], [1500, 300, 300])
	var duel = _new(strongest)
	_opening(duel)
	for enemy_index in range(3):
		if duel.turn != 0:
			duel.finish_turn(duel.turn)
		if not duel.gates.has(5):
			duel.gate_hands[0].append(Cards.get_gate("pyrus_50"))
			duel.place_gate(0, duel.gate_hands[0].size() - 1, 5)
		duel.throw_unit(0, 0, 5)
		duel.finish_turn(0)
		duel.throw_unit(1, enemy_index, 5)
		var result: Dictionary = _two_passes(duel)
		_check(result.victor == 0 and duel.teams[1][enemy_index].status == "defeated", "Losing creatures stay defeated across later turns")
		if enemy_index < 2:
			var before: String = JSON.stringify(duel.state_snapshot())
			_unchanged(duel, duel.throw_unit(1, enemy_index, 0), before, "A defeated creature cannot be thrown again")
	_check(duel.winner == 0 and duel.phase == "finished" and duel.defeated[1].size() == 3, "Eliminating the last opposing reserve ends the local match")
	var before: String = JSON.stringify(duel.state_snapshot())
	_unchanged(duel, duel.finish_turn(duel.turn), before, "A completed match cannot continue mutating turn state")
	duel = _new()
	_opening(duel)
	duel.gates.clear()
	duel.gate_hands = [[], []]
	duel.gate_decks = [[], []]
	duel.spent_gates = [[Cards.get_gate("pyrus_50")], [Cards.get_gate("aquos_50")]]
	_check(duel.finish_turn(0).ok and duel.phase == "opening" and duel.gate_hands[0].size() == 1 and duel.gate_hands[1].size() == 1, "An empty field with exhausted hands recycles used gates only as a documented anti-stall fallback")
	_check(duel.place_gate(1, 0, 0).ok and duel.place_gate(0, 0, 15).ok and duel.phase == "turn", "Both owners can reopen a depleted field and resume normal play")
