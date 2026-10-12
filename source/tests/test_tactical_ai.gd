extends SceneTree

const Rules = preload("res://scripts/match_rules.gd")
const Tactics = preload("res://scripts/tactical_ai.gd")
const Effects = preload("res://scripts/battle_effects.gd")
const Catalog = preload("res://scripts/ability_catalog.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_test_gate_choices()
	_test_double_and_throw_validity()
	_test_hidden_information()
	_test_ability_choices()
	if failures == 0:
		print("PASS: %d tactical AI and hidden-information checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d tactical AI checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _card(index: int, owner: int = 1) -> Dictionary:
	var card: Dictionary = Catalog.CARDS[index].duplicate(true)
	card["id"] = "p%d_%s" % [owner, card["key"]]
	return card


func _test_gate_choices() -> void:
	var rules = Rules.new()
	_check(Tactics.choose_gate(rules, 0) == 0, "Player team values Leonidas's doubled character gate bonus")
	_check(rules.legal_gate_slots(true).has(Tactics.choose_gate_slot(rules, 0, true)) and rules.legal_gate_slots(true).has(Tactics.choose_gate_slot(rules, 1, true)), "Both opening placements use legal central spaces")
	rules.place_gate(0, 0, 5, true)
	_check(rules.legal_gate_slots().has(Tactics.choose_gate_slot(rules, 1)), "Subsequent placement is orthogonally adjacent")
	var before: Array = rules.hands.duplicate(true)
	Tactics.choose_gate(rules, 1)
	_check(rules.hands == before, "Rating a gate does not consume it")
	rules.hands[1].clear()
	_check(Tactics.choose_gate(rules, 1) == -1, "Empty gate hand gives no choice")
	_check(Tactics.choose_gate(null, 0) == -1 and Tactics.choose_gate_slot(null, 0) == -1, "Invalid placement requests are safe")
	rules.winner = 0
	_check(Tactics.choose_gate(rules, 1) == -1 and Tactics.choose_gate_slot(rules, 1) == -1, "Completed match offers no placement")


func _test_double_and_throw_validity() -> void:
	var rules = Rules.new()
	_check(Tactics.choose_throw(rules, 0).is_empty(), "A field without gates has no throw target")
	rules.place_gate(0, 0, 5, true)
	rules.place_gate(1, 0, 6, true)
	rules.land(0, 0, 5)
	var choice: Dictionary = Tactics.choose_throw(rules, 0)
	_check(choice == {"unit": 2, "slot": 5}, "AI chooses Double Stand while preserving the stronger reserve ball")
	_check(rules.available_units(0).has(choice["unit"]), "Recommended unit is actually available")
	var event: Dictionary = rules.land(0, choice["unit"], choice["slot"])
	_check(event["event"] == "double_choice" and rules.scores[0] == 0, "Adjacent gate leaves the authentic capture-or-relocate choice")
	_check(rules.resolve_double(5)["event"] == "double_stand" and rules.scores[0] == 1, "Choosing capture resolves the Double Stand")
	rules = Rules.new()
	rules.place_gate(0, 0, 5, true)
	rules.land(0, 0, 5)
	rules.land(1, 0, 5)
	_check(Tactics.choose_throw(rules, 0).is_empty(), "Pending battle gate is unavailable to extra throws")
	_check(Tactics.choose_throw(null, 0).is_empty() and Tactics.choose_throw(rules, 2).is_empty(), "Invalid throw requests are safe")


func _test_hidden_information() -> void:
	var rules = Rules.new()
	rules.place_gate(0, 0, 5, true)
	rules.place_gate(0, 0, 6, true)
	rules.land(0, 0, 5)
	rules.land(0, 1, 6)
	var choice: Dictionary = Tactics.choose_throw(rules, 1)
	_check(choice == {"unit": 0, "slot": 6}, "AI prefers the weaker known defender on an enemy hidden card")
	rules.gates[5]["boosts"]["Darkus"] = 2000
	rules.gates[6]["boosts"]["Darkus"] = 0
	rules.gates[5]["effect"] = {"type": "character_double", "species": "Hydranoid"}
	_check(Tactics.choose_throw(rules, 1) == choice, "Changing hidden enemy bonuses and effects cannot alter AI choice")
	rules.gates[5]["owner"] = 1
	_check(Tactics.choose_throw(rules, 1) == {"unit": 0, "slot": 5}, "The AI may use its own face-down gate's known printed bonus")
	rules.gates[5]["owner"] = 0
	rules.gates[5]["bakugan"][0]["sphere_damage"] = 100
	_check(Tactics.choose_throw(rules, 1) == {"unit": 0, "slot": 5}, "Visible Sphere damage affects target selection without revealing cards")
	var board_before: Dictionary = rules.gates.duplicate(true)
	var teams_before: Array = rules.teams.duplicate(true)
	Tactics.choose_throw(rules, 1)
	_check(rules.gates == board_before and rules.teams == teams_before, "Throw recommendation does not mutate cards or reserve")
	for unit: Dictionary in rules.teams[1]:
		unit["used"] = true
	_check(Tactics.choose_throw(rules, 1).is_empty(), "No exhausted unit is returned as available")


func _test_ability_choices() -> void:
	var effects = Effects.new()
	var own: Dictionary = {"name": "Leonidas", "attribute": "Pyrus"}
	var foe: Dictionary = {"name": "Hydranoid", "attribute": "Darkus"}
	var hand: Array = Catalog.make_deck([0, 1, 2], 1)
	_check(Tactics.choose_ability(hand, 1, effects, 150, 150, own, foe, "timing", true) == 1, "AI prefers valid Leonidas 200 G over smaller bonuses")
	_check(effects.counts == [0, 0] and effects.extra(1, 150) == 150, "Ability projection does not spend live cards or G")
	effects.apply(1, hand[1], own, foe, "timing", true)
	_check(Tactics.choose_ability(hand, 1, effects, 150, 150, own, foe, "timing", false) == 0, "A valid second card is considered after an earlier ability")
	own["name"] = "Dragonoid"
	_check(Tactics.choose_ability([_card(1)], 1, effects, 150, 150, own, foe, "timing", true) == -1, "AI cannot spend Leonidas card on Dragonoid")
	own["attribute"] = "Aquos"
	_check(Tactics.choose_ability([_card(2), _card(5)], 1, effects, 150, 150, own, foe, "timing", false) == 1, "AI chooses only the printed-attribute-compatible blue card")
	_check(Tactics.choose_ability([_card(3)], 1, effects, 0, 0, own, foe, "timing", true) == 0, "Quick Draw is available before a non-shooting minigame")
	_check(Tactics.choose_ability([_card(3)], 1, effects, 0, 0, own, foe, "timing", false) == -1, "Quick Draw is not selected once battle is running")
	_check(Tactics.choose_ability([{}], 1, effects, 0, 0, own, foe, "timing", true) == -1, "Malformed cards are skipped")
	_check(Tactics.choose_ability([], 1, effects, 0, 0, own, foe, "timing", true) == -1 and Tactics.choose_ability(hand, -1, effects, 0, 0) == -1, "Empty hands and invalid owners are safe")
