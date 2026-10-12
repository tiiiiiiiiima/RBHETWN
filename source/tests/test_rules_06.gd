extends SceneTree
## Sourced Wii flow scenarios, plus the explicitly documented tie fallback.

const Rules = preload("res://scripts/match_rules.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_test_geometry_and_hidden_gate()
	_test_double_stand_choices()
	_test_stay_response_window()
	_test_stay_battle_and_ko_cancellation()
	_test_stay_surviving_sphere()
	_test_stay_rejections_and_reset()
	_test_sphere_power_lifetime()
	_test_sphere_rejections()
	_test_gate_printed_effects()
	_test_blocked_and_returned_abilities()
	if failures == 0:
		print("PASS: %d Wii 0.6 rule scenario checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d Wii 0.6 rule scenario checks" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _gate(rules, owner: int, slot: int, effect: Dictionary = {}, color: String = "silver", opening: bool = false) -> void:
	rules.hands[owner][0] = {"id": "fixture_%d" % slot, "title": "Scenario fixture", "owner": owner,
		"color_type": color, "boosts": {"Pyrus": 100, "Darkus": 80, "Ventus": 40},
		"effect": effect, "bakugan": []}
	rules.place_gate(owner, 0, slot, opening)


func _three_stands(owner: int = 0):
	var rules = Rules.new()
	rules.turn = owner
	var slots: Array[int] = [5, 6, 9]
	for index in range(3):
		_gate(rules, owner, slots[index])
		rules.land(owner, index, slots[index])
	return rules


func _test_geometry_and_hidden_gate() -> void:
	var rules = Rules.new()
	_check(rules.legal_gate_slots() == [5, 6, 9, 10], "Empty field offers four central opening spots")
	_check(not rules.place_gate(0, 0, 0, true), "Opening outside the four central spots is rejected")
	_gate(rules, 0, 5, {"type": "first_standing_bonus", "bonus": 100}, "copper", true)
	_check(not rules.gates[5]["revealed"] and rules.gate_effect(5).is_empty(), "Face-down placement conceals the printed rule")
	_check(rules.legal_gate_slots().has(1) and rules.legal_gate_slots().has(4) and not rules.legal_gate_slots().has(10), "Subsequent placement is orthogonal rather than diagonal")
	_check(rules.legal_gate_slots(true).has(10) and not rules.legal_gate_slots(true).has(1), "Other player opening remains central even after the first card")
	rules.land(0, 0, 5)
	_check(not rules.gates[5]["revealed"] and rules.get_standing_power(5, 0) == 340, "Uncontested stand keeps gate hidden and does not gain battle bonus yet")
	var battle: Dictionary = rules.land(1, 0, 5)
	_check(battle["event"] == "battle" and rules.gates[5]["revealed"], "Opposed stand reveals the card before battle preparation")
	_check(battle["gate_effect"]["type"] == "first_standing_bonus", "Reveal supplies the real gate rule to the battle controller")
	var detached: Dictionary = rules.gate_effect(5)
	detached["bonus"] = 999
	_check(rules.gate_effect(5)["bonus"] == 100, "Returned rule data is detached from the gate")


func _test_double_stand_choices() -> void:
	var rules = Rules.new()
	_gate(rules, 0, 5)
	_gate(rules, 1, 6)
	rules.land(0, 0, 5, 30)
	var result: Dictionary = rules.land(0, 1, 5, 70)
	_check(result["event"] == "double_choice" and result["destinations"] == [6] and rules.scores == [0, 0], "Adjacent gate offers a Double Stand choice before awarding a capture")
	_check(rules.resolve_double(5, 10)["event"] == "invalid" and rules.gates[5]["bakugan"].size() == 2, "Diagonal or absent destination cannot remove the last thrown ball")
	result = rules.resolve_double(5, 6)
	_check(result["event"] == "stand" and result["from_slot"] == 5 and result["slot"] == 6, "Double Stand can move the last thrown ball one adjacent card")
	_check(rules.gates[5]["bakugan"][0]["index"] == 0 and rules.gates[6]["bakugan"][0]["index"] == 1, "Movement preserves the first ball and moves only the challenger")
	_check(rules.gates[6]["bakugan"][0]["roll_bonus"] == 70 and rules.available_units(0) == [2], "Moving a standing ball keeps its landing power and spends no extra throw")
	var capture = Rules.new()
	_gate(capture, 0, 5)
	_gate(capture, 1, 6)
	capture.land(0, 0, 5)
	capture.land(0, 1, 5)
	result = capture.resolve_double(5)
	_check(result["event"] == "double_stand" and capture.scores == [1, 0] and capture.gates.has(6), "The alternative Double Stand choice captures just its original gate")
	var attack = Rules.new()
	_gate(attack, 0, 5)
	_gate(attack, 1, 6)
	attack.land(1, 0, 6)
	attack.land(0, 0, 5)
	attack.land(0, 1, 5)
	result = attack.resolve_double(5, 6)
	_check(result["event"] == "battle" and result["challenger"]["index"] == 1 and result["defender"]["owner"] == 1, "Moving the last ball onto an opponent starts a battle on the destination gate")
	_check(not attack.gates[5]["revealed"] and attack.gates[6]["revealed"], "Only the destination battle reveals its card")
	var isolated = Rules.new()
	_gate(isolated, 0, 5)
	isolated.land(0, 0, 5)
	_check(isolated.land(0, 1, 5)["event"] == "double_stand", "Double Stand without an adjacent card captures directly")


func _test_stay_response_window() -> void:
	var rules = _three_stands()
	_check(rules.available_units(0).is_empty() and rules.needs_stay(0) and not rules.recycle_used(0), "Three standing balls require Stay rather than arbitrary recall or recycle")
	_check(rules.choose_stay(0, 6) and not rules.needs_stay(0), "Own turn commits one uncontested Stay card")
	_check(rules.process_stay(0).is_empty() and rules.scores == [0, 0], "Stay cannot capture on its selection turn")
	rules.finish_turn()
	_check(rules.turn == 1 and rules.turn_serial == 1 and rules.process_stay(0).is_empty(), "The opponent gets a full response turn")
	rules.finish_turn()
	var result: Dictionary = rules.process_stay(0)
	_check(result.get("event") == "stay_capture" and result.get("slot") == 6 and result.get("index") == 1, "Untouched Stay captures on the next own turn")
	_check(rules.scores == [1, 0] and not rules.gates.has(6) and rules.available_units(0).is_empty(), "Stay awards one gate but preserves the spent-ball cycle")
	_check(rules.recycle_used(0) and rules.available_units(0) == [1], "After a complete landing cycle the returned Stay ball becomes available")
	_check(rules.process_stay(0).is_empty() and rules.stay_markers[0].is_empty(), "Consumed Stay cannot score twice")
	var opponent = _three_stands(1)
	opponent.choose_stay(1, 9)
	opponent.finish_turn()
	opponent.finish_turn()
	_check(opponent.process_stay(1).get("owner") == 1 and opponent.scores == [0, 1], "Both owners receive the same full response window")


func _test_stay_battle_and_ko_cancellation() -> void:
	var rules = _three_stands()
	rules.choose_stay(0, 5)
	rules.finish_turn()
	_check(rules.land(1, 0, 5)["event"] == "battle" and rules.stay_markers[0].is_empty(), "Opposing battle cancels Stay immediately")
	rules.resolve_battle(5, 200, 0)
	rules.finish_turn()
	_check(rules.process_stay(0).is_empty() and rules.scores == [1, 0], "Battle capture cannot also award the cancelled Stay")
	var knockout = _three_stands()
	knockout.choose_stay(0, 5)
	knockout.finish_turn()
	var hit: Dictionary = knockout.apply_sphere_attack(1, 5, 999)
	_check(hit["event"] == "critical_ko" and hit["damage"] == 340 and hit["remaining_g"] == 0, "Sphere power clamps at zero and triggers Critical K.O.")
	_check(knockout.stay_markers[0].is_empty() and knockout.scores == [0, 1] and not knockout.gates.has(5), "Critical K.O. captures without battle and cancels Stay")
	knockout.finish_turn()
	_check(knockout.process_stay(0).is_empty(), "A removed Stay cannot later award a gate")


func _test_stay_surviving_sphere() -> void:
	var rules = _three_stands()
	rules.choose_stay(0, 9)
	rules.finish_turn()
	_check(rules.apply_sphere_attack(1, 9, 50)["event"] == "sphere_attack" and not rules.stay_markers[0].is_empty(), "Surviving Sphere damage keeps an uncontested Stay marker")
	# Other card capture must not clear the selected marker.
	rules.apply_sphere_attack(1, 5, 999)
	_check(not rules.stay_markers[0].is_empty(), "Capturing a different card preserves the selected Stay")
	rules.finish_turn()
	_check(rules.process_stay(0).get("event") == "stay_capture" and rules.scores == [1, 1], "Damaged but unbattled Stay captures despite unrelated scoring")


func _test_stay_rejections_and_reset() -> void:
	var rules = Rules.new()
	_check(not rules.needs_stay(-1) and not rules.choose_stay(2, 5) and rules.process_stay(2).is_empty(), "Invalid Stay owners rejected")
	_gate(rules, 0, 5)
	rules.land(0, 0, 5)
	rules.land(0, 1, -1)
	_check(not rules.needs_stay(0) and not rules.choose_stay(0, 5), "A reserve or missed ball cannot substitute for the third stand")
	rules = _three_stands()
	rules.turn = 1
	_check(not rules.choose_stay(0, 5), "Stay selection belongs to the player's own turn")
	rules.turn = 0
	_check(not rules.choose_stay(1, 5) and not rules.choose_stay(0, 99), "Stay must refer to that owner's real uncontested gate")
	rules.choose_stay(0, 5)
	_check(not rules.choose_stay(0, 9), "Committed Stay cannot be replaced")
	rules.finish_turn()
	rules.new_match()
	_check(rules.turn_serial == 0 and rules.stay_markers == [{}, {}] and rules.process_stay(0).is_empty(), "New match clears every delayed Stay marker")


func _test_sphere_power_lifetime() -> void:
	var rules = Rules.new()
	_gate(rules, 0, 5)
	rules.land(0, 0, 5, 40)
	var hit: Dictionary = rules.apply_sphere_attack(1, 5, 100)
	_check(hit["event"] == "sphere_attack" and hit["previous_g"] == 380 and hit["remaining_g"] == 280, "Sphere damages landing G including retained pickups")
	_check(rules.get_standing_power(5, 0) == 280 and not rules.gates[5]["revealed"], "A hidden card adds no attribute bonus during Sphere damage")
	_check(rules.teams[0][0]["g"] == 340 and rules.gates[5]["bakugan"][0]["g"] == 340, "Sphere leaves roster and landed base G immutable")
	rules.land(1, 0, 5)
	var result: Dictionary = rules.resolve_battle(5, 0, 0)
	_check(result["player_g"] == 380 and result["enemy_g"] == 430 and result["owner"] == 1, "Battle retains the actual damage and then applies revealed gate bonuses")
	_check(not rules.available_units(0).has(0), "A captured damaged ball stays spent until the landing cycle completes")
	var attack = Rules.new()
	_gate(attack, 1, 5)
	attack.land(1, 0, 5)
	attack.apply_sphere_attack(0, 5, 350)
	_check(attack.consume_throw(0, 1) and attack.teams[0][1]["used"] and attack.teams[0][1]["landed_cycle"], "Critical K.O. controller can consume its successful attacking throw once")
	_check(not attack.consume_throw(0, 1), "The same forceful throw cannot be consumed twice")


func _test_sphere_rejections() -> void:
	var rules = Rules.new()
	_gate(rules, 0, 5)
	_check(rules.apply_sphere_attack(1, 5, 50)["event"] == "invalid", "Empty card is not a Sphere target")
	rules.land(0, 0, 5)
	_check(rules.apply_sphere_attack(0, 5, 50)["event"] == "invalid", "Friendly stand is not a Sphere target")
	_check(rules.apply_sphere_attack(3, 5, 50)["event"] == "invalid" and rules.apply_sphere_attack(1, 99, 50)["event"] == "invalid", "Invalid attacker and absent gate rejected")
	_check(rules.apply_sphere_attack(1, 5, 0)["event"] == "invalid" and rules.apply_sphere_attack(1, 5, -1)["event"] == "invalid", "Nonpositive Sphere damage rejected")
	_check(rules.get_standing_power(5, 0) == 340, "Rejected attacks preserve standing power")
	rules.land(1, 0, 5)
	_check(rules.apply_sphere_attack(1, 5, 50)["event"] == "invalid", "A pending battle cannot be replaced with a Sphere attack")


func _test_gate_printed_effects() -> void:
	var rules = Rules.new()
	_gate(rules, 0, 5, {"type": "character_double", "species": "Leonidas"}, "gold")
	rules.land(0, 0, 5, 40)
	rules.land(1, 0, 5)
	_check(rules.gate_unit_bonus(5, rules.gates[5]["bakugan"][0]) == 200 and rules.gate_unit_bonus(5, rules.gates[5]["bakugan"][1]) == 80, "Named gold card doubles only the matching Bakugan's attribute bonus")
	var result: Dictionary = rules.resolve_battle(5, 0, 0)
	_check(result["player_g"] == 580 and result["enemy_g"] == 430, "Gold rule leaves base and collected power undoubled")
	var first = Rules.new()
	_gate(first, 0, 5, {"type": "first_standing_bonus", "bonus": 100}, "copper")
	first.land(1, 0, 5)
	first.land(0, 0, 5)
	result = first.resolve_battle(5, 0, 0)
	_check(result["player_g"] == 440 and result["enemy_g"] == 530, "Copper first-standing bonus follows arrival order rather than gate owner")
	var modes = Rules.new()
	_gate(modes, 0, 5, {}, "gold")
	_gate(modes, 0, 6, {}, "silver")
	_gate(modes, 0, 9, {}, "copper")
	_check(modes.minigame_type(5) == "shooting" and modes.minigame_type(6) == "timing" and modes.minigame_type(9) == "shaking", "Console gate colors choose the original Wii battle types")


func _test_blocked_and_returned_abilities() -> void:
	var blocked = Rules.new()
	_gate(blocked, 0, 5, {"type": "no_abilities"}, "copper")
	blocked.land(0, 0, 5)
	blocked.land(1, 0, 5)
	_check(blocked.use_ability(0, 0, 5).is_empty() and blocked.use_ability(1, 0).is_empty(), "Ability Block rejects either side and prevents callers bypassing it by omitting the slot")
	_check(blocked.abilities[0].size() == 3 and blocked.spent_abilities[0].is_empty(), "Rejected abilities stay in hand")
	var returned = Rules.new()
	returned.use_ability(0, 0)
	returned.use_ability(1, 0)
	_gate(returned, 0, 5, {"type": "return_all_abilities_after_battle"}, "copper")
	returned.land(0, 0, 5)
	returned.land(1, 0, 5)
	returned.use_ability(0, 0, 5)
	_check(returned.abilities[0].size() == 1 and returned.spent_abilities[0].size() == 2, "More than one distinct ability can be spent across battles")
	var result: Dictionary = returned.resolve_battle(5, 0, 0)
	_check(result["abilities_returned"] and returned.abilities[0].size() == 3 and returned.abilities[1].size() == 3, "Stand Your Ground returns all previously spent ability cards to both players after battle")
	_check(returned.spent_abilities == [[], []], "Returned ability cards leave both discard piles")
	var doubled = Rules.new()
	doubled.use_ability(0, 0)
	_gate(doubled, 0, 5, {"type": "return_all_abilities_after_battle"}, "copper")
	doubled.land(0, 0, 5)
	doubled.land(0, 1, 5)
	_check(doubled.abilities[0].size() == 2 and doubled.spent_abilities[0].size() == 1, "A Double Stand does not trigger a rule explicitly requiring a battle")
