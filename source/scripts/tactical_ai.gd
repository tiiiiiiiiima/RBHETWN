extends RefCounted
## Deterministic tactics. Face-down enemy cards stay unknown to this policy.

static func choose_gate(rules, owner: int) -> int:
	if rules == null or owner < 0 or owner > 1 or rules.winner != -1:
		return -1
	var available: Array[int] = rules.available_units(owner)
	if available.is_empty() or rules.hands[owner].is_empty():
		return -1
	var best_index: int = -1
	var best_bonus: int = -2147483648
	for index in range(rules.hands[owner].size()):
		var card: Dictionary = rules.hands[owner][index]
		var total_bonus: int = 0
		for unit_index in available:
			var unit: Dictionary = rules.teams[owner][unit_index]
			total_bonus += _known_card_bonus(card, unit, true)
		if best_index == -1 or total_bonus > best_bonus:
			best_index = index
			best_bonus = total_bonus
	return best_index


static func choose_gate_slot(rules, owner: int, opening: bool = false) -> int:
	if rules == null or owner < 0 or owner > 1 or rules.winner != -1:
		return -1
	var slots: Array[int] = rules.legal_gate_slots(opening, owner)
	if slots.is_empty():
		return -1
	# Opposite each participant's launching end; deterministic nearest position.
	var best: int = slots[0]
	for slot: int in slots:
		if (owner == 0 and slot > best) or (owner == 1 and slot < best):
			best = slot
	return best


static func choose_throw(rules, owner: int, tactic: String = "balanced") -> Dictionary:
	if rules == null or owner < 0 or owner > 1 or rules.winner != -1:
		return {}
	var available: Array[int] = rules.available_units(owner)
	if available.is_empty():
		return {}
	var slots: Array = rules.gates.keys()
	slots.sort()
	var best: Dictionary = {}
	var best_category: int = -1
	var best_value: int = -2147483648
	for slot_value in slots:
		var slot: int = int(slot_value)
		var card: Dictionary = rules.gates[slot]
		var occupants: Array = card["bakugan"]
		if occupants.size() >= 2:
			continue
		var known: bool = bool(card.get("revealed", false)) or int(card.get("owner", -1)) == owner
		for unit_index in available:
			var unit: Dictionary = rules.teams[owner][unit_index]
			var candidate_power: int = int(unit["g"])
			if known:
				candidate_power += _known_card_bonus(card, unit, occupants.is_empty())
			var category: int = 0
			var value: int = candidate_power
			if not occupants.is_empty():
				if int(occupants[0]["owner"]) == owner:
					category = 2
					# A direct Double Stand is available irrespective of G.
					value = -int(unit["g"])
				else:
					category = 1
					var defender: Dictionary = occupants[0]
					var defender_power: int = maxi(0, int(defender["g"]) + int(defender.get("roll_bonus", 0)) - int(defender.get("sphere_damage", 0)))
					if known:
						defender_power += _known_card_bonus(card, defender, true)
					value = candidate_power - defender_power
					if tactic in ["pressure","offense"]: category=3
					if tactic in ["control","precision"] and value<0: category=-1
			if tactic=="counter" and not occupants.is_empty() and int(occupants[0].owner)!=owner:
				category=3 if rules.scores[1-owner]>=2 else 1
			if tactic=="precision": value+=_known_card_bonus(card,unit,true) if known else 0
			if tactic=="double" and occupants.is_empty():
				value=-int(unit.g)+(_known_card_bonus(card,unit,true) if known else 0)
			if best.is_empty() or category > best_category or (category == best_category and value > best_value):
				best = {"unit": unit_index, "slot": slot}
				best_category = category
				best_value = value
	return best


static func choose_ability(hand: Array, owner: int, effects, mini_points: int, opponent_mini: int, unit: Dictionary = {}, opponent_unit: Dictionary = {}, battle_type: String = "", preparing: bool = false, context: Dictionary = {}) -> int:
	if effects == null or owner < 0 or owner > 1 or hand.is_empty():
		return -1
	var opponent: int = 1 - owner
	var current_margin: int = effects.extra(owner, mini_points) - effects.extra(opponent, opponent_mini)
	var best_gain: int = 0
	var best_index: int = -1
	for index in range(hand.size()):
		if not hand[index] is Dictionary:
			continue
		var card: Dictionary = hand[index]
		if not effects.can_play(card, unit, opponent_unit, battle_type, preparing, context):
			continue
		var projected = effects.copy()
		if not projected.apply(owner, card, unit, opponent_unit, battle_type, preparing, context):
			continue
		var gain: int = projected.extra(owner, mini_points) - projected.extra(opponent, opponent_mini) - current_margin
		# Changing the minigame is useful only while preparing, never mid-game.
		if str(card["effect"]["type"]) == "battle_type":
			gain = 1
		if str(card.get("rules_profile",""))=="ds":
			match str(card.effect.type):
				"double_input": gain=100
				"time_break": gain=60
				"block_family": gain=20
				"redo", "level_field": gain=30 if mini_points<opponent_mini else 0
				"skip_battle":
					var powers: Array = context.get("current_powers",[0,0])
					gain=300 if int(powers[owner])>int(powers[1-owner]) else 0
		if gain > best_gain:
			best_gain = gain
			best_index = index
	return best_index


static func _known_card_bonus(card: Dictionary, unit: Dictionary, first_standing: bool) -> int:
	var bonus: int = int(card.get("boosts", {}).get(str(unit.get("attribute", "")), 0))
	var effect: Dictionary = card.get("effect", {})
	match str(effect.get("type", "")):
		"character_double":
			if str(unit.get("name", "")) == str(effect.get("species", "")):
				bonus *= 2
		"first_standing_bonus":
			if first_standing:
				bonus += int(effect.get("bonus", 100))
	return bonus
