extends SceneTree

const Catalog = preload("res://scripts/ability_catalog.gd")
const Effects = preload("res://scripts/battle_effects.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_test_catalog_and_deck()
	_test_conditions()
	_test_combinations()
	_test_type_card()
	_test_copy_and_reset()
	if failures == 0:
		print("PASS: %d original ability and combination checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d ability checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _unit(name: String, attribute: String) -> Dictionary:
	return {"name": name, "attribute": attribute, "g": 340}


func _card(index: int, owner: int = 0) -> Dictionary:
	var card: Dictionary = Catalog.CARDS[index].duplicate(true)
	card["id"] = "p%d_%s" % [owner, card["key"]]
	return card


func _test_catalog_and_deck() -> void:
	var expected: Array = ["Battle Gate", "Alpha Blaster", "G-Power Boost", "Quick Draw", "Boosted Dragon", "G-Power Bump", "Mega Impact"]
	_check(Catalog.CARDS.size() == expected.size(), "Seven verified console abilities replace invented effects")
	for index in range(expected.size()):
		var card: Dictionary = Catalog.CARDS[index]
		_check(card["title"] == expected[index] and card.has_all(["serial", "source_page", "printed_rule", "effect", "description", "attributes"]), "Original ability %s includes source and restrictions" % expected[index])
	_check(Catalog.indices_for_color("red") == [0, 3] and Catalog.indices_for_color("green") == [1, 4, 6] and Catalog.indices_for_color("blue") == [2, 5], "Deck candidates are separated by required original colors")
	_check(Catalog.normalize_selection([3.0, 6.0, 5.0]) == [3, 6, 5], "One-red one-green one-blue JSON deck is retained")
	_check(Catalog.normalize_selection([5, 3, 4]) == [0, 1, 2], "Old wrong-color profile choices become legal defaults")
	_check(Catalog.normalize_selection([3, 5, 5]) == [3, 1, 5], "Only the wrong-color slot is repaired")
	for selection: Array in [[], [0], [0, 1, 2, 3], [NAN, "1", true], [INF, null, {}]]:
		_check(Catalog.normalize_selection(selection) == [0, 1, 2], "Malformed deck falls back to original color rule")
	var first: Array[Dictionary] = Catalog.make_deck([3, 6, 5], 0)
	var second: Array[Dictionary] = Catalog.make_deck([3, 6, 5], 1)
	first[1]["effect"]["bonus"] = 999
	_check(second[1]["effect"]["bonus"] == 200 and Catalog.CARDS[6]["effect"]["bonus"] == 200, "Dealt effects do not mutate other decks or catalog")
	for stage in range(3):
		var deck: Array[Dictionary] = Catalog.enemy_deck(stage)
		_check([deck[0]["color_type"], deck[1]["color_type"], deck[2]["color_type"]] == ["red", "green", "blue"], "Opponent deck obeys the same three-color quota")
	_check(Catalog.make_deck([], -1).is_empty() and Catalog.make_deck([], 2).is_empty(), "Invalid deck owners are rejected")


func _test_conditions() -> void:
	var leonidas: Dictionary = _unit("Leonidas", "Pyrus")
	var dragon: Dictionary = _unit("Dragonoid", "Pyrus")
	var foe: Dictionary = _unit("Hydranoid", "Darkus")
	_check(Catalog.can_play(_card(0), leonidas, foe, "timing", false) and Catalog.bonus_for(_card(0), leonidas, foe) == 100, "Battle Gate gives 100 G for differing attributes")
	_check(not Catalog.can_play(_card(0), leonidas, dragon, "timing", true), "Battle Gate cannot be spent for equal attributes")
	_check(Catalog.can_play(_card(1), leonidas, foe, "timing", true) and Catalog.bonus_for(_card(1), leonidas, foe) == 200, "Alpha Blaster gives Leonidas 200 G")
	_check(not Catalog.can_play(_card(1), dragon, foe, "timing", true), "Alpha Blaster cannot boost an unrelated creature")
	_check(Catalog.can_play(_card(4), dragon, foe, "shooting", false) and not Catalog.can_play(_card(4), leonidas, foe, "shooting", false), "Boosted Dragon works only for Dragonoid")
	_check(Catalog.can_play(_card(6), _unit("Gorem", "Subterra"), foe, "shaking", true) and not Catalog.can_play(_card(6), dragon, foe, "shaking", true), "Mega Impact works only for Gorem")
	for attribute: String in ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]:
		var unit: Dictionary = _unit("Leonidas", attribute)
		_check(Catalog.can_play(_card(2), unit, foe, "timing", false) == ["Pyrus", "Subterra", "Darkus"].has(attribute), "G-Power Boost follows its printed attribute restriction")
		_check(Catalog.can_play(_card(5), unit, foe, "timing", false) == ["Aquos", "Haos", "Ventus"].has(attribute), "G-Power Bump follows its complementary attribute restriction")
	_check(not Catalog.can_play({}, leonidas, foe, "timing", true) and not Catalog.can_play(_card(2), {}, foe, "timing", true), "Malformed cards and unknown units cannot be played")


func _test_combinations() -> void:
	var effects = Effects.new()
	var own: Dictionary = _unit("Leonidas", "Pyrus")
	var foe: Dictionary = _unit("Hydranoid", "Darkus")
	_check(effects.apply(0, _card(0), own, foe, "timing", true), "Battle Gate can open a combination")
	_check(effects.apply(0, _card(1), own, foe, "timing", false), "A second valid ability is permitted in the same battle")
	_check(effects.apply(0, _card(2), own, foe, "timing", false), "All three different valid cards can combine")
	_check(effects.extra(0, 120) == 480 and effects.counts[0] == 3 and effects.used[0], "Original ability bonuses add once alongside minigame G")
	var before: Array = effects.states.duplicate(true)
	_check(not effects.apply(0, _card(1), own, foe, "timing", true) and effects.states == before and effects.counts[0] == 3, "The same physical card cannot be replayed in one battle")
	_check(effects.apply(1, _card(2, 1), foe, own, "timing", false), "The opponent can respond with a valid ability")
	_check(effects.extra(1, 40) == 100 and effects.extra(0, -50) == 360, "Opponent bonus and clamped minigame points remain independent")
	_check(not effects.apply(-1, _card(2), own, foe) and not effects.apply(2, _card(2), own, foe), "Invalid owners cannot alter battle effects")
	_check(not effects.apply(0, _card(4), own, foe) and effects.counts[0] == 3, "Invalid species does not spend or count a card")


func _test_type_card() -> void:
	var effects = Effects.new()
	var own: Dictionary = _unit("Dragonoid", "Pyrus")
	var foe: Dictionary = _unit("Hydranoid", "Darkus")
	_check(not effects.apply(0, _card(3), own, foe, "timing", false), "Quick Draw cannot change a running minigame")
	_check(not effects.apply(0, _card(3), own, foe, "shooting", true), "Unnecessary type change is not consumed")
	_check(effects.apply(0, _card(3), own, foe, "timing", true), "Quick Draw chooses shooting during battle preparation")
	_check(effects.selected_battle_type("timing") == "shooting" and effects.extra(0, 30) == 30, "Type card changes the minigame without inventing a G bonus")
	_check(effects.apply(0, _card(4), own, foe, "shooting", true) and effects.extra(0, 30) == 230, "Type change can combine with species bonus")


func _test_copy_and_reset() -> void:
	var effects = Effects.new()
	var own: Dictionary = _unit("Leonidas", "Pyrus")
	var foe: Dictionary = _unit("Hydranoid", "Darkus")
	var card: Dictionary = _card(1)
	effects.apply(0, card, own, foe)
	card["effect"]["bonus"] = 999
	_check(effects.extra(0, 100) == 300, "Played ability snapshots numeric bonus")
	var projected = effects.copy()
	projected.apply(0, _card(2), own, foe)
	_check(projected.extra(0, 100) == 360 and effects.extra(0, 100) == 300 and effects.counts[0] == 1, "AI projection cannot mutate live combination or usage")
	_check(not projected.apply(0, _card(1), own, foe), "Simulation preserves the set of already played card IDs")
	effects.reset()
	_check(effects.counts == [0, 0] and effects.used == [false, false] and effects.extra(0, 100) == 100 and effects.selected_battle_type("shaking") == "shaking", "Next battle clears bonuses, cards and type override")
	_check(effects.apply(0, _card(1), own, foe), "A returned ability is playable again in a later battle")
