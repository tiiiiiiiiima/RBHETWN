extends RefCounted
## Verified console cards: Prima Official Game Guide (2009), pp.191–199.
## Restrictions and effects follow the printed cards; labels are translations.

const COLORS = ["red", "green", "blue"]
const CARDS = [
	{
		"key": "ability_battle_gate",
		"title": "Battle Gate",
		"color_type": "red",
		"attributes": [
			"Pyrus",
			"Aquos",
			"Subterra",
			"Haos",
			"Darkus",
			"Ventus"
		],
		"effect": {
			"type": "different_attribute_bonus",
			"bonus": 100
		},
		"source_page": 191,
		"serial": "BA194-AB-SM",
		"printed_rule": "If your Bakugan’s attribute is different than opponent’s, your Bakugan gains +100 G-Power.",
		"type": "different_attribute_bonus",
		"bonus": 100,
		"drain": 0,
		"shield": false,
		"focus": 1.0,
		"description": "+100 G, если стихия бакугана отличается от стихии соперника."
	},
	{
		"key": "ability_alpha_blaster",
		"title": "Alpha Blaster",
		"color_type": "green",
		"attributes": [
			"Pyrus",
			"Aquos",
			"Subterra",
			"Haos",
			"Darkus",
			"Ventus"
		],
		"effect": {
			"type": "species_bonus",
			"species": "Leonidas",
			"bonus": 200
		},
		"source_page": 193,
		"serial": "VG027-AB-SM",
		"printed_rule": "Leonidas gets +200 G-Power.",
		"type": "species_bonus",
		"bonus": 200,
		"drain": 0,
		"shield": false,
		"focus": 1.0,
		"description": "Leonidas получает +200 G."
	},
	{
		"key": "ability_g_power_boost",
		"title": "G-Power Boost",
		"color_type": "blue",
		"attributes": [
			"Pyrus",
			"Subterra",
			"Darkus"
		],
		"effect": {
			"type": "power",
			"bonus": 60
		},
		"source_page": 197,
		"serial": "BA166-AB-SM",
		"printed_rule": "During a battle; +60 G-Power.",
		"type": "power",
		"bonus": 60,
		"drain": 0,
		"shield": false,
		"focus": 1.0,
		"description": "+60 G: только Pyrus, Subterra или Darkus."
	},
	{
		"key": "ability_quick_draw",
		"title": "Quick Draw",
		"color_type": "red",
		"attributes": [
			"Pyrus",
			"Aquos",
			"Subterra",
			"Haos",
			"Darkus",
			"Ventus"
		],
		"effect": {
			"type": "battle_type",
			"battle_type": "shooting"
		},
		"source_page": 192,
		"serial": "VG008-AB-SM",
		"printed_rule": "Allows you to select a Shooting Battle.",
		"type": "battle_type",
		"bonus": 0,
		"drain": 0,
		"shield": false,
		"focus": 1.0,
		"description": "Перед началом миниигры выбирает бой со стрельбой."
	},
	{
		"key": "ability_boosted_dragon",
		"title": "Boosted Dragon",
		"color_type": "green",
		"attributes": [
			"Pyrus",
			"Aquos",
			"Subterra",
			"Haos",
			"Darkus",
			"Ventus"
		],
		"effect": {
			"type": "species_bonus",
			"species": "Dragonoid",
			"bonus": 200
		},
		"source_page": 193,
		"serial": "VG011-AB-SM",
		"printed_rule": "Dragonoid gets +200 G-Power.",
		"type": "species_bonus",
		"bonus": 200,
		"drain": 0,
		"shield": false,
		"focus": 1.0,
		"description": "Dragonoid получает +200 G."
	},
	{
		"key": "ability_g_power_bump",
		"title": "G-Power Bump",
		"color_type": "blue",
		"attributes": [
			"Aquos",
			"Haos",
			"Ventus"
		],
		"effect": {
			"type": "power",
			"bonus": 60
		},
		"source_page": 197,
		"serial": "BA167-AB-SM",
		"printed_rule": "During a battle; +60 G-Power.",
		"type": "power",
		"bonus": 60,
		"drain": 0,
		"shield": false,
		"focus": 1.0,
		"description": "+60 G: только Aquos, Haos или Ventus."
	},
	{
		"key": "ability_mega_impact",
		"title": "Mega Impact",
		"color_type": "green",
		"attributes": [
			"Pyrus",
			"Aquos",
			"Subterra",
			"Haos",
			"Darkus",
			"Ventus"
		],
		"effect": {
			"type": "species_bonus",
			"species": "Gorem",
			"bonus": 200
		},
		"source_page": 195,
		"serial": "VG016-AB-SM",
		"printed_rule": "Gorem gets +200 G-Power.",
		"type": "species_bonus",
		"bonus": 200,
		"drain": 0,
		"shield": false,
		"focus": 1.0,
		"description": "Gorem получает +200 G."
	}
]
const DEFAULT_SELECTION = [0, 1, 2]
const ENEMY_SELECTIONS = [[0, 6, 5], [3, 4, 2], [0, 1, 2]]


static func indices_for_color(color: String) -> Array[int]:
	var result: Array[int] = []
	for index in range(CARDS.size()):
		if str(CARDS[index]["color_type"]) == color:
			result.append(index)
	return result


static func normalize_selection(selection: Array) -> Array[int]:
	var result: Array[int] = []
	for slot in range(3):
		var index: int = DEFAULT_SELECTION[slot]
		if selection.size() == 3 and _valid_index(selection[slot]):
			var candidate: int = int(selection[slot])
			if str(CARDS[candidate]["color_type"]) == str(COLORS[slot]):
				index = candidate
		result.append(index)
	return result


static func make_deck(selection: Array, owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if owner != 0 and owner != 1:
		return result
	for index in normalize_selection(selection):
		var card: Dictionary = CARDS[index].duplicate(true)
		card["id"] = "p%d_%s" % [owner, card["key"]]
		result.append(card)
	return result


static func enemy_deck(stage: int) -> Array[Dictionary]:
	return make_deck(ENEMY_SELECTIONS[clampi(stage, 0, ENEMY_SELECTIONS.size() - 1)], 1)


static func can_play(card: Dictionary, unit: Dictionary, opponent: Dictionary, battle_type: String, preparing: bool) -> bool:
	if not _valid_card(card) or not card["attributes"].has(str(unit.get("attribute", ""))):
		return false
	var effect: Dictionary = card["effect"]
	match str(effect["type"]):
		"power":
			return int(effect["bonus"]) > 0
		"species_bonus":
			return str(unit.get("name", "")).to_lower() == str(effect["species"]).to_lower()
		"different_attribute_bonus":
			var opponent_attribute: String = str(opponent.get("attribute", ""))
			return not opponent_attribute.is_empty() and str(unit.get("attribute", "")) != opponent_attribute
		"battle_type":
			return preparing and str(effect["battle_type"]) != battle_type
	return false


static func bonus_for(card: Dictionary, unit: Dictionary, opponent: Dictionary) -> int:
	if not can_play(card, unit, opponent, "", false):
		return 0
	return int(card["effect"].get("bonus", 0))


static func _valid_index(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0 and value < CARDS.size()
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value == floor(value) and value >= 0 and value < CARDS.size()
	return false


static func _valid_card(card: Dictionary) -> bool:
	if not card.get("effect") is Dictionary or not card.get("attributes") is Array:
		return false
	var effect: Dictionary = card["effect"]
	var kind: String = str(effect.get("type", ""))
	if kind == "battle_type":
		return ["shooting", "timing", "shaking"].has(str(effect.get("battle_type", "")))
	if not ["power", "species_bonus", "different_attribute_bonus"].has(kind):
		return false
	if typeof(effect.get("bonus")) != TYPE_INT or int(effect["bonus"]) <= 0:
		return false
	return kind != "species_bonus" or (typeof(effect.get("species")) == TYPE_STRING and not str(effect["species"]).is_empty())
