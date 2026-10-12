extends RefCounted
## Verified console cards: Prima Official Game Guide (2009), pp.178–190.
## Gate bonuses/effects are original data; Russian descriptions are translations.

const COLORS = ["gold", "silver", "copper"]
const CARDS = [
	{
		"key": "gate_leonidas",
		"title": "Leonidas",
		"color_type": "gold",
		"boosts": {
			"Pyrus": 160,
			"Aquos": 140,
			"Subterra": 120,
			"Haos": 160,
			"Darkus": 120,
			"Ventus": 140
		},
		"effect": {
			"type": "character_double",
			"species": "Leonidas"
		},
		"source_page": 180,
		"serial": "VG025-GA-SM",
		"printed_rule": "Leonidas get the Gate bonus twice!",
		"description": "Золотые · стрельба\nLeonidas: бонус стихии ворот удваивается."
	},
	{
		"key": "gate_aquos_vortex",
		"title": "Aquos Vortex",
		"color_type": "silver",
		"boosts": {
			"Pyrus": 60,
			"Aquos": 150,
			"Subterra": 120,
			"Haos": 50,
			"Darkus": 20,
			"Ventus": 20
		},
		"effect": {
			"type": "none"
		},
		"source_page": 183,
		"serial": "BA244-GA-SM",
		"printed_rule": "",
		"description": "Серебряные · точность\nБонусы стихии применяются при раскрытии ворот."
	},
	{
		"key": "gate_ability_block",
		"title": "Ability Block",
		"color_type": "copper",
		"boosts": {
			"Pyrus": 20,
			"Aquos": 0,
			"Subterra": 20,
			"Haos": 0,
			"Darkus": 20,
			"Ventus": 0
		},
		"effect": {
			"type": "no_abilities"
		},
		"source_page": 187,
		"serial": "BA154-GA-SM",
		"printed_rule": "No Ability Cards may be played.",
		"description": "Медные · встряхивание\nВ этом бою нельзя играть карты способностей."
	},
	{
		"key": "gate_dragonoid",
		"title": "Dragonoid",
		"color_type": "gold",
		"boosts": {
			"Pyrus": 170,
			"Aquos": 110,
			"Subterra": 80,
			"Haos": 130,
			"Darkus": 100,
			"Ventus": 140
		},
		"effect": {
			"type": "character_double",
			"species": "Dragonoid"
		},
		"source_page": 178,
		"serial": "VG001-GA-SM",
		"printed_rule": "Dragonoids get the Gate bonus twice!",
		"description": "Золотые · стрельба\nDragonoid: бонус стихии ворот удваивается."
	},
	{
		"key": "gate_the_cliffs",
		"title": "The Cliffs",
		"color_type": "silver",
		"boosts": {
			"Pyrus": 120,
			"Aquos": 100,
			"Subterra": 150,
			"Haos": 50,
			"Darkus": 100,
			"Ventus": 50
		},
		"effect": {
			"type": "none"
		},
		"source_page": 183,
		"serial": "BA247-GA-SM",
		"printed_rule": "",
		"description": "Серебряные · точность\nБонусы стихии применяются при раскрытии ворот."
	},
	{
		"key": "gate_quick_strike",
		"title": "Quick Strike",
		"color_type": "copper",
		"boosts": {
			"Pyrus": 250,
			"Aquos": 200,
			"Subterra": 300,
			"Haos": 250,
			"Darkus": 200,
			"Ventus": 150
		},
		"effect": {
			"type": "first_standing_bonus",
			"bonus": 100
		},
		"source_page": 189,
		"serial": "BA266-GA-SM",
		"printed_rule": "The Bakugan who stood on this card first gets +100 G-Power.",
		"description": "Медные · встряхивание\nПервый вставший бакуган получает дополнительно +100 G."
	},
	{
		"key": "gate_griffon",
		"title": "Griffon",
		"color_type": "gold",
		"boosts": {
			"Pyrus": 110,
			"Aquos": 40,
			"Subterra": 120,
			"Haos": 80,
			"Darkus": 120,
			"Ventus": 120
		},
		"effect": {
			"type": "character_double",
			"species": "Griffon"
		},
		"source_page": 179,
		"serial": "VG020-GA-SM",
		"printed_rule": "Griffons get the Gate bonus twice!",
		"description": "Золотые · стрельба\nGriffon: бонус стихии ворот удваивается."
	},
	{
		"key": "gate_sunrise",
		"title": "Sunrise",
		"color_type": "silver",
		"boosts": {
			"Pyrus": 20,
			"Aquos": 20,
			"Subterra": 60,
			"Haos": 140,
			"Darkus": 120,
			"Ventus": 80
		},
		"effect": {
			"type": "none"
		},
		"source_page": 186,
		"serial": "BA202-GA-SM",
		"printed_rule": "",
		"description": "Серебряные · точность\nБонусы стихии применяются при раскрытии ворот."
	},
	{
		"key": "gate_stand_your_ground",
		"title": "Stand Your Ground",
		"color_type": "copper",
		"boosts": {
			"Pyrus": 20,
			"Aquos": 80,
			"Subterra": 140,
			"Haos": 50,
			"Darkus": 60,
			"Ventus": 110
		},
		"effect": {
			"type": "return_all_abilities_after_battle"
		},
		"source_page": 190,
		"serial": "BA156-GA-SM",
		"printed_rule": "After the battle is over, all players get all Ability Cards back into their hands.",
		"description": "Медные · встряхивание\nПосле боя оба игрока возвращают все использованные способности."
	}
]
const DEFAULT_SELECTION = [0, 1, 2]
const ENEMY_SELECTIONS = [[0, 1, 2], [3, 4, 5], [6, 7, 8]]


static func indices_for_color(color: String) -> Array[int]:
	var result: Array[int] = []
	for index in range(CARDS.size()):
		if str(CARDS[index]["color_type"]) == color:
			result.append(index)
	return result


static func minigame_type(color: String) -> String:
	return {"gold": "shooting", "silver": "timing", "copper": "shaking"}.get(color, "")


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
		card["owner"] = owner
		card["bakugan"] = []
		card["revealed"] = false
		result.append(card)
	return result


static func enemy_deck(stage: int) -> Array[Dictionary]:
	return make_deck(ENEMY_SELECTIONS[clampi(stage, 0, ENEMY_SELECTIONS.size() - 1)], 1)


static func _valid_index(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0 and value < CARDS.size()
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value == floor(value) and value >= 0 and value < CARDS.size()
	return false
