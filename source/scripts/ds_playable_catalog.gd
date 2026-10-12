extends RefCounted
## Native DS G parameters and source-text effects supported by desktop rules.
## Effects not implemented in the battle engine are excluded from this catalog.

const MANIFEST_PATH := "res://assets/ds/playable_cards.json"
const ATTRIBUTES := ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
const GATE_COLORS := ["gold", "silver", "copper"]
const ABILITY_COLORS := ["red", "green", "blue"]
static var _manifest: Dictionary = {}


static func manifest() -> Dictionary:
	return _data().duplicate(true)


static func cards(kind: String = "all") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: Variant in _data().get("cards", []):
		if card is Dictionary and (kind == "all" or str(card.get("kind", "")) == kind):
			result.append(card.duplicate(true))
	return result


static func metadata(key: Variant) -> Dictionary:
	for card: Dictionary in cards():
		if str(card["key"]) == str(key) or (typeof(key) in [TYPE_INT, TYPE_FLOAT] and int(card["source_card_id"]) == int(key)):
			return card
	return {}


static func indices_for_color(kind: String, color: String) -> Array[int]:
	var result: Array[int] = []
	var entries: Array[Dictionary] = cards(kind)
	for index in range(entries.size()):
		if str(entries[index]["color_type"]) == color:
			result.append(index)
	return result


static func default_selection(kind: String, owner: int = 0) -> Array[int]:
	var ids: Array = _data().get("default_ids", {}).get(kind, [])
	var entries: Array[Dictionary] = cards(kind)
	var result: Array[int] = []
	for id: Variant in ids:
		for index in range(entries.size()):
			if int(entries[index]["source_card_id"]) == int(id):
				result.append(index)
	return result


static func normalize_selection(kind: String, selection: Array) -> Array[int]:
	var entries: Array[Dictionary] = cards(kind)
	var defaults: Array[int] = default_selection(kind)
	var colors: Array = GATE_COLORS if kind == "gate" else ABILITY_COLORS
	var result: Array[int] = []
	if kind not in ["gate", "ability"] or defaults.size() != 3:
		return result
	for slot in range(3):
		var index: int = defaults[slot]
		if selection.size() == 3 and _valid_index(selection[slot], entries.size()):
			var candidate: int = int(selection[slot])
			if str(entries[candidate]["color_type"]) == str(colors[slot]):
				index = candidate
		result.append(index)
	return result


static func make_deck(kind: String, selection: Array, owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if owner not in [0, 1] or kind not in ["gate", "ability"]:
		return result
	var entries: Array[Dictionary] = cards(kind)
	for index: int in normalize_selection(kind, selection):
		var card: Dictionary = entries[index].duplicate(true)
		card["id"] = "p%d_%s" % [owner, card["key"]]
		card["owner"] = owner
		if kind == "gate":
			card["bakugan"] = []
			card["revealed"] = false
		result.append(card)
	return result


static func enemy_deck(kind: String, stage: int) -> Array[Dictionary]:
	var ids: Array = []
	if kind == "gate":
		ids = [[111, 215, 301], [101, 220, 315], [136, 217, 306]][clampi(stage, 0, 2)]
	elif kind == "ability":
		ids = [[405, 520, 606], [401, 511, 604], [408, 527, 602]][clampi(stage, 0, 2)]
	var entries: Array[Dictionary] = cards(kind)
	var selection: Array[int] = []
	for id: Variant in ids:
		for index in range(entries.size()):
			if int(entries[index]["source_card_id"]) == int(id):
				selection.append(index)
	return make_deck(kind, selection, 1)


static func can_play(card: Dictionary, unit: Dictionary, opponent: Dictionary, battle_type: String = "", preparing: bool = true, context: Dictionary = {}) -> bool:
	if str(card.get("rules_profile", "")) != "ds" or str(card.get("kind", "")) != "ability" or not card.get("effect") is Dictionary:
		return false
	if not card.get("attributes", []).has(str(unit.get("attribute", ""))):
		return false
	var effect: Dictionary = card["effect"]
	var family: String = str(effect.get("type",""))
	if family=="power_swap": family="swap"
	if family=="level_field": family="redo"
	if context.get("blocked_families",[]).has(family): return false
	if effect.has("own_attribute") and str(unit.get("attribute",""))!=str(effect.own_attribute): return false
	if effect.has("relationship"):
		var same: bool = str(unit.get("attribute",""))==str(opponent.get("attribute",""))
		if same!=(str(effect.relationship)=="same"): return false
	match str(effect.get("type", "")):
		"time_break", "double_input": return true
		"redo", "level_field": return not bool(context.get("redo_used",false))
		"block_family": return not context.get("opponent_blocked_families",[]).has(str(effect.family))
		"cancel_boost": return true
		"skip_battle": return not effect.has("gate_color") or str(context.get("gate_color",""))==str(effect.gate_color)
		"hand_combo", "team_combo":
			var found: Array = context.get("reserve_attributes",[]) if str(effect.type)=="hand_combo" else context.get("team_attributes",[])
			for attribute: String in effect.required_attributes:
				if not found.has(attribute): return false
			return int(effect.boosts.get(str(unit.get("attribute","")),0))>0
		"opponent_combo": return str(opponent.get("attribute",""))==str(effect.opponent_attribute) and int(effect.boosts.get(str(unit.get("attribute","")),0))>0
		"species_bonus":
			return str(unit.get("name", "")).to_lower() == str(effect.get("species", "")).to_lower()
		"attribute_power":
			return int(effect.get("boosts", {}).get(str(unit.get("attribute", "")), 0)) > 0
		"gate_owned_power":
			var owner: int = int(context.get("owner", -1))
			var gate_owner: int = int(context.get("gate_owner", -1))
			if owner not in [0, 1] or gate_owner not in [0, 1]:
				return false
			var own: bool = str(effect.get("gate_relation", "")) == "own"
			return (gate_owner == owner) == own and int(effect.get("boosts", {}).get(str(unit.get("attribute", "")), 0)) > 0
		"captured_gate_bonus":
			return int(context.get("captured_count", 0)) > 0
		"higher_opponent_printed_power":
			return int(opponent.get("g", 0)) > int(unit.get("g", 0)) and int(effect.get("boosts", {}).get(str(unit.get("attribute", "")), 0)) > 0
		"power_swap":
			if effect.has("own_attribute") and str(unit.get("attribute", "")) != str(effect["own_attribute"]):
				return false
			if effect.has("relationship"):
				var other: String = str(opponent.get("attribute", ""))
				if other.is_empty() or ((str(unit.get("attribute", "")) == other) != (str(effect["relationship"]) == "same")):
					return false
			var owner: int = int(context.get("owner", -1))
			var powers: Variant = context.get("current_powers", [])
			if owner not in [0, 1] or not powers is Array or powers.size() != 2:
				return false
			for value: Variant in powers:
				if not (typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))):
					return false
			return bool(context.get("preview_chain",false)) or int(powers[0]) != int(powers[1])
	return false


static func bonus_for(card: Dictionary, unit: Dictionary, opponent: Dictionary = {}, context: Dictionary = {}) -> int:
	if not can_play(card, unit, opponent, "", true, context):
		return 0
	var effect: Dictionary = card["effect"]
	match str(effect.get("type", "")):
		"species_bonus":
			return int(effect.get("bonus", 0))
		"attribute_power", "gate_owned_power", "higher_opponent_printed_power", "hand_combo", "team_combo", "opponent_combo":
			return int(effect.get("boosts", {}).get(str(unit.get("attribute", "")), 0))
		"captured_gate_bonus":
			return int(effect.get("bonus", 0)) * int(context.get("captured_count", 0))
	return 0


static func minigame_type(color: String) -> String:
	# Current DS implementation; this is not the native six-game selector.
	return "scratch" if GATE_COLORS.has(color) else ""


static func _valid_index(value: Variant, size: int) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0 and value < size
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value == floor(value) and value >= 0 and value < size
	return false


static func _data() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary and int(parsed.get("schema", 0)) == 1:
			_manifest = parsed
			for card: Variant in _manifest.get("cards", []):
				if not card is Dictionary:
					continue
				for field: String in ["source_card_id", "message_index", "bonus"]:
					card[field] = int(card.get(field, 0))
				for attribute: String in ATTRIBUTES:
					card["boosts"][attribute] = int(card["boosts"].get(attribute, 0))
				var effect: Dictionary = card.get("effect", {})
				for field: String in ["bonus", "multiplier"]:
					if effect.has(field):
						effect[field] = int(effect[field])
				if effect.get("boosts") is Dictionary:
					for attribute: String in ATTRIBUTES:
						effect["boosts"][attribute] = int(effect["boosts"].get(attribute, 0))
	return _manifest
