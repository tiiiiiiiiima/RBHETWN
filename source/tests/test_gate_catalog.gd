extends SceneTree

const Catalog = preload("res://scripts/gate_catalog.gd")
const Rules = preload("res://scripts/match_rules.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_test_verified_cards()
	_test_color_deck()
	_test_isolation()
	_test_rules_effects()
	if failures == 0:
		print("PASS: %d verified gate catalog checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d gate catalog checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_verified_cards() -> void:
	var names: Array = ["Leonidas", "Aquos Vortex", "Ability Block", "Dragonoid", "The Cliffs", "Quick Strike", "Griffon", "Sunrise", "Stand Your Ground"]
	var expected: Array = [[160, 140, 120, 160, 120, 140], [60, 150, 120, 50, 20, 20], [20, 0, 20, 0, 20, 0], [170, 110, 80, 130, 100, 140], [120, 100, 150, 50, 100, 50], [250, 200, 300, 250, 200, 150], [110, 40, 120, 80, 120, 120], [20, 20, 60, 140, 120, 80], [20, 80, 140, 50, 60, 110]]
	_check(Catalog.CARDS.size() == names.size(), "Nine original console gates are available")
	for index in range(names.size()):
		var card: Dictionary = Catalog.CARDS[index]
		var actual: Array = []
		for attribute: String in Rules.ATTRIBUTES:
			actual.append(card["boosts"][attribute])
		_check(str(card["title"]) == names[index] and actual == expected[index], "Prima card name and complete attribute table match for %s" % names[index])
		_check(card.has_all(["serial", "source_page", "printed_rule", "description", "effect"]), "Source and translated rule remain reviewable for %s" % names[index])
	_check(Catalog.CARDS[0]["effect"] == {"type": "character_double", "species": "Leonidas"}, "Leonidas doubles its gate bonus")
	_check(Catalog.CARDS[2]["effect"] == {"type": "no_abilities"}, "Ability Block forbids abilities")
	_check(Catalog.CARDS[5]["effect"] == {"type": "first_standing_bonus", "bonus": 100}, "Quick Strike awards the first standing unit 100 G")
	_check(Catalog.CARDS[8]["effect"] == {"type": "return_all_abilities_after_battle"}, "Stand Your Ground returns abilities after battle")
	_check(Catalog.minigame_type("gold") == "shooting" and Catalog.minigame_type("silver") == "timing" and Catalog.minigame_type("copper") == "shaking", "Original gate colors select the correct three minigames")
	_check(Catalog.minigame_type("invalid").is_empty(), "Unknown color is not silently assigned a minigame")


func _test_color_deck() -> void:
	_check(Catalog.indices_for_color("gold") == [0, 3, 6] and Catalog.indices_for_color("silver") == [1, 4, 7] and Catalog.indices_for_color("copper") == [2, 5, 8], "Card chooser provides only the correct color candidates")
	_check(Catalog.normalize_selection([6.0, 7.0, 8.0]) == [6, 7, 8], "Valid JSON deck retains one gate of each color")
	_check(Catalog.normalize_selection([4, 5, 7]) == [0, 1, 2], "Old invalid-color deck migrates to legal defaults")
	_check(Catalog.normalize_selection([6, 7, 7]) == [6, 7, 2], "Wrong-color selection repairs only its slot")
	for selection: Array in [[], [0], [0, 1, 2, 3], [NAN, "1", true], [INF, null, {}]]:
		_check(Catalog.normalize_selection(selection) == [0, 1, 2], "Malformed profile selection becomes a legal three-color deck")
	for stage in range(3):
		var deck: Array[Dictionary] = Catalog.enemy_deck(stage)
		_check(deck.size() == 3 and [deck[0]["color_type"], deck[1]["color_type"], deck[2]["color_type"]] == ["gold", "silver", "copper"], "Opponent deck follows the same color rule")
	_check(Catalog.enemy_deck(-1) == Catalog.enemy_deck(0) and Catalog.enemy_deck(99) == Catalog.enemy_deck(2), "Opponent progression clamps safely")
	_check(Catalog.make_deck([], -1).is_empty() and Catalog.make_deck([], 2).is_empty(), "Invalid owners receive no gate deck")


func _test_isolation() -> void:
	var deck: Array[Dictionary] = Catalog.make_deck([3, 4, 5], 0)
	var opponent: Array[Dictionary] = Catalog.make_deck([3, 4, 5], 1)
	deck[0]["boosts"]["Pyrus"] = 999
	deck[0]["effect"]["species"] = "Changed"
	deck[0]["bakugan"].append({"owner": 0})
	_check(opponent[0]["boosts"]["Pyrus"] == 170 and Catalog.CARDS[3]["boosts"]["Pyrus"] == 170, "Each runtime gate owns its own bonus table")
	_check(opponent[0]["effect"]["species"] == "Dragonoid" and opponent[0]["bakugan"].is_empty(), "Effect and occupant mutations do not escape one gate")
	_check(deck[0]["id"] == "p0_gate_dragonoid" and opponent[0]["id"] == "p1_gate_dragonoid", "Gate identities include owner and stable source card key")


func _test_rules_effects() -> void:
	var rules = Rules.new()
	rules.hands[0] = Catalog.make_deck([3, 4, 5], 0)
	_check(rules.place_gate(0, 0, 5, true), "An original Dragonoid gate can be placed centrally")
	rules.land(0, 1, 5)
	_check(rules.gate_unit_bonus(5, rules.gates[5]["bakugan"][0]) == 0 and rules.get_standing_power(5, 0) == 320, "Hidden gate bonuses do not inflate pre-battle Sphere health")
	rules.land(1, 0, 5)
	_check(rules.gate_unit_bonus(5, rules.gates[5]["bakugan"][0]) == 340, "Matching Dragonoid receives twice the Pyrus gate bonus")
	_check(rules.gate_unit_bonus(5, rules.gates[5]["bakugan"][1]) == 100, "Unmatched opponent receives only its printed attribute bonus")
	_check(rules.minigame_type(5) == "shooting", "Gold printed gate selects shooting in the engine")
	rules = Rules.new()
	rules.hands[0] = Catalog.make_deck([0, 1, 5], 0)
	rules.place_gate(0, 2, 5, true)
	rules.land(1, 0, 5)
	rules.land(0, 0, 5)
	_check(rules.gate_unit_bonus(5, rules.gates[5]["bakugan"][0]) == 300 and rules.gate_unit_bonus(5, rules.gates[5]["bakugan"][1]) == 250, "Quick Strike adds 100 only to the first-standing unit")
