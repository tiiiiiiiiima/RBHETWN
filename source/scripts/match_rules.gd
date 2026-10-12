extends RefCounted
## Rendering-independent classic rules. Wii is the compatibility default.
## The DS profile adds authoritative action sequencing; source-backed card
## effects are independent of the presentation and desktop minigames.
## Base roster G, roll-item cap and Sphere damage formula remain local balance.
## Wii controllers retain their placement sequencing. DS enforces setup,
## the current owner, one optional placement, and one physical throw per turn.
## DS native MES confirms crossed openings, capture/Win/Move/Stay and first
## to three. Geometry, recycling, misses, ties and exact card timing retain
## explicit desktop adaptations documented in DS-RULES-AUDIT-0.12.md.
## Landed balls remain spent through captures until the three-ball cycle ends.
## Tied battles use the classic tabletop first-standing fallback.

const BoardLayout = preload("res://scripts/board_layout.gd")
const GateCatalog = preload("res://scripts/gate_catalog.gd")
const AbilityCatalog = preload("res://scripts/ability_catalog.gd")
const Effects = preload("res://scripts/battle_effects.gd")
const DSPlayableCatalog = preload("res://scripts/ds_playable_catalog.gd")

const ATTRIBUTES = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
const TARGET_SCORE: int = 3

var scores: Array[int] = [0, 0]
var turn: int = 0
var gates: Dictionary = {}
var hands: Array = []
var abilities: Array = []
var spent_abilities: Array = [[], []]
var teams: Array = []
var winner: int = -1
var turn_serial: int = 0
var stay_markers: Array[Dictionary] = [{}, {}]
var rules_profile: String = "wii"
var opening_placements: Array[bool] = [false, false]
var opening_active: bool = false
var gate_placed_this_turn: bool = false
var turn_action_taken: bool = false


func _init(profile: String = "wii") -> void:
	new_match(profile)


func make_team(owner: int) -> Array[Dictionary]:
	# Character identities are retained; statistics are intentionally demo data.
	var result: Array[Dictionary] = []
	if owner == 0:
		result.assign([
			{"id": "p0_leonidas", "name": "Leonidas", "attribute": "Pyrus", "g": 340, "used": false},
			{"id": "p0_dragonoid", "name": "Dragonoid", "attribute": "Pyrus", "g": 320, "used": false},
			{"id": "p0_griffon", "name": "Griffon", "attribute": "Ventus", "g": 300, "used": false},
		])
	elif owner == 1:
		result.assign([
			{"id": "p1_hydranoid", "name": "Hydranoid", "attribute": "Darkus", "g": 350, "used": false},
			{"id": "p1_preyas", "name": "Preyas", "attribute": "Aquos", "g": 310, "used": false},
			{"id": "p1_gorem", "name": "Gorem", "attribute": "Subterra", "g": 330, "used": false},
		])
	return result


func new_match(profile: String = "") -> void:
	if not profile.is_empty():
		rules_profile = "ds" if profile == "ds" else "wii"
	scores = [0, 0]
	turn = 0
	turn_serial = 0
	stay_markers = [{}, {}]
	winner = -1
	gates.clear()
	teams = [make_team(0), make_team(1)]
	hands = [_make_gates(0), _make_gates(1)]
	abilities = [_make_abilities(0), _make_abilities(1)]
	spent_abilities = [[], []]
	opening_placements = [false, false]
	opening_active = rules_profile == "ds"
	gate_placed_this_turn = false
	turn_action_taken = false


func begin_opening() -> bool:
	# Reopening a cleared field is explicit; it cannot reset a live placement
	# quota, an unresolved battle, or another player's pending opening card.
	if winner != -1 or not gates.is_empty():
		return false
	if rules_profile == "ds":
		if opening_active:
			for owner in range(2):
				if hands[owner].is_empty():
					opening_placements[owner] = true
			opening_active = not (opening_placements[0] and opening_placements[1])
			return true
		opening_placements = [hands[0].is_empty(), hands[1].is_empty()]
		opening_active = not (opening_placements[0] and opening_placements[1])
	return true


func pending_slot() -> int:
	for slot: Variant in gates:
		if gates[slot]["bakugan"].size() >= 2:
			return int(slot)
	return -1


func can_place_gate(owner: int, opening: bool = false) -> bool:
	if winner != -1 or not _valid_owner(owner) or hands[owner].is_empty():
		return false
	if rules_profile != "ds":
		return true
	if pending_slot() >= 0:
		return false
	if opening:
		return opening_active and not opening_placements[owner]
	for gate: Dictionary in gates.values():
		if int(gate.owner)==owner:
			return false
	return not opening_active and owner == turn and not gate_placed_this_turn and not turn_action_taken


func can_finish_turn() -> bool:
	if winner != -1:
		return false
	if rules_profile != "ds":
		return true
	# With the three-ball classic cycle, an empty reserve requires recycling or
	# a committed Stay. Merely having no reserve must not let a stale result
	# callback skip the next owner's action before the controller prepares it.
	return not opening_active and pending_slot() < 0 and turn_action_taken


func _can_throw(owner: int) -> bool:
	return rules_profile != "ds" or (owner == turn and not opening_active and not turn_action_taken and pending_slot() < 0)


func available_units(owner: int) -> Array[int]:
	var result: Array[int] = []
	if not _valid_owner(owner) or winner != -1:
		return result
	for index in range(teams[owner].size()):
		if not bool(teams[owner][index]["used"]) and not _unit_on_board(owner, index):
			result.append(index)
	return result


func legal_gate_slots(opening: bool = false, owner: int = -1) -> Array[int]:
	var result: Array[int] = BoardLayout.legal_slots(gates, opening,rules_profile)
	if rules_profile == "ds" and opening and _valid_owner(owner):
		var crossed_slots: Array = BoardLayout.initial_slots("ds",owner)
		result.assign(result.filter(func(slot: int) -> bool: return crossed_slots.has(slot)))
	return result


func place_gate(owner: int, hand_index: int, slot: int, opening: bool = false) -> bool:
	if not can_place_gate(owner, opening) or not legal_gate_slots(opening, owner).has(slot):
		return false
	if hand_index < 0 or hand_index >= hands[owner].size():
		return false
	var gate: Dictionary = hands[owner][hand_index]
	hands[owner].remove_at(hand_index)
	gate["revealed"] = false
	gates[slot] = gate
	if rules_profile == "ds":
		if opening:
			opening_placements[owner] = true
			opening_active = not (opening_placements[0] and opening_placements[1])
		else:
			gate_placed_this_turn = true
	return true


func land(owner: int, unit_index: int, slot: int, roll_bonus: int = 0, field_damage: int = 0) -> Dictionary:
	if winner != -1 or not _valid_owner(owner) or not _can_throw(owner):
		return {"event": "invalid"}
	if unit_index < 0 or unit_index >= teams[owner].size():
		return {"event": "invalid"}
	if not available_units(owner).has(unit_index):
		return {"event": "invalid"}
	if gates.has(slot) and gates[slot]["bakugan"].size() >= 2:
		# A pending battle must be resolved before another unit can enter.
		return {"event": "invalid"}

	var unit: Dictionary = teams[owner][unit_index]
	unit["used"] = true
	turn_action_taken = true
	if not gates.has(slot):
		return {"event": "miss", "owner": owner, "slot": slot}

	var gate: Dictionary = gates[slot]
	unit["landed_cycle"] = true
	var landed: Dictionary = {
		"owner": owner,
		"index": unit_index,
		"name": unit["name"],
		"attribute": unit["attribute"],
		"g": unit["g"],
		"roll_bonus": clampi(roll_bonus, 0, 120),
		"sphere_damage": 0,
		"field_damage": maxi(0,field_damage),
		"motion_profile": unit.get("motion_profile", {}).duplicate(true),
	}
	return _accept_landing(slot, landed)


func _accept_landing(slot: int, landed: Dictionary) -> Dictionary:
	var gate: Dictionary = gates[slot]
	var owner: int = int(landed["owner"])
	if gate["bakugan"].is_empty():
		gate["bakugan"].append(landed)
		return {"event": "stand", "owner": owner, "slot": slot, "unit": landed}
	var defender: Dictionary = gate["bakugan"][0]
	gate["bakugan"].append(landed)
	if int(defender["owner"]) == owner:
		# DS mes_command 22-24 confirms Win/Move choices. Orthogonal movement
		# constraints remain the explicitly documented desktop adaptation.
		if not legal_double_destinations(slot).is_empty():
			return {"event": "double_choice", "owner": owner, "slot": slot,
				"unit": landed, "destinations": legal_double_destinations(slot)}
		return resolve_double(slot)
	_clear_stay_for_slot(slot)
	gate["revealed"] = true
	_apply_revealed_gate_effects(slot)
	return {"event": "battle", "slot": slot, "challenger": landed,
		"defender": defender, "gate": gate, "gate_effect": gate_effect(slot)}


func _apply_revealed_gate_effects(slot: int) -> void:
	# DS 306 says both players regain all abilities. Restoration on reveal is
	# the explicit desktop timing; native execution order is still unverified.
	if rules_profile == "ds" and str(gate_effect(slot).get("type", "")) in ["restore_abilities", "return_abilities"]:
		for owner in range(2):
			abilities[owner].append_array(spent_abilities[owner])
			spent_abilities[owner].clear()


func legal_double_destinations(slot: int) -> Array[int]:
	var result: Array[int] = []
	if not gates.has(slot):
		return result
	for destination: int in BoardLayout.neighbors(slot,rules_profile):
		if gates.has(destination) and gates[destination]["bakugan"].size() < 2:
			result.append(destination)
	return result


func resolve_double(slot: int, destination: int = -1) -> Dictionary:
	if winner != -1 or not gates.has(slot):
		return {"event": "invalid"}
	var occupants: Array = gates[slot]["bakugan"]
	if occupants.size() != 2 or int(occupants[0]["owner"]) != int(occupants[1]["owner"]):
		return {"event": "invalid"}
	var owner: int = int(occupants[1]["owner"])
	if destination == -1:
		_capture_gate(slot, owner)
		return {"event": "double_stand", "owner": owner, "slot": slot, "winner": winner}
	if not legal_double_destinations(slot).has(destination):
		return {"event": "invalid"}
	var moved: Dictionary = occupants.pop_back()
	_clear_stay_for_slot(slot)
	var result: Dictionary = _accept_landing(destination, moved)
	result["from_slot"] = slot
	result["moved"] = true
	return result


func gate_effect(slot: int) -> Dictionary:
	# Cards may carry an effect object for the caller's battle preparation.
	# No hidden effect is exposed before the opposed stand reveals the gate.
	if not gates.has(slot) or not bool(gates[slot].get("revealed", false)):
		return {}
	var effect: Variant = gates[slot].get("effect", {})
	return effect.duplicate(true) if effect is Dictionary else {}


func gate_bonus(slot: int, attribute: String) -> int:
	if not gates.has(slot) or not bool(gates[slot].get("revealed", false)):
		return 0
	return int(gates[slot]["boosts"].get(attribute, 0))


func gate_unit_bonus(slot: int, unit: Dictionary) -> int:
	if not gates.has(slot) or not bool(gates[slot].get("revealed", false)):
		return 0
	var bonus: int = gate_bonus(slot, str(unit.get("attribute", "")))
	var effect: Dictionary = gate_effect(slot)
	match str(effect.get("type", "")):
		"character_double":
			if str(unit.get("name", "")) == str(effect.get("species", "")):
				bonus *= 2
		"first_standing_bonus":
			var occupants: Array = gates[slot]["bakugan"]
			if not occupants.is_empty() and int(unit.get("owner", -1)) == int(occupants[0]["owner"]) and int(unit.get("index", -1)) == int(occupants[0]["index"]):
				bonus += int(effect.get("bonus", 100))
		"used_ability_bonus":
			var owner: int = int(unit.get("owner", -1))
			if _valid_owner(owner):
				bonus += int(effect.get("bonus", 100)) * spent_abilities[owner].size()
		"captured_gate_bonus":
			var owner: int = int(unit.get("owner", -1))
			if _valid_owner(owner):
				bonus += int(effect.get("bonus", 100)) * scores[owner]
	return bonus


func effective_printed_power(slot: int, unit: Dictionary) -> int:
	var printed: int = int(unit.get("g", 0))
	if not gates.has(slot) or not bool(gates[slot].get("revealed", false)):
		return printed
	var opponent: Dictionary = _opponent_on_gate(slot, int(unit.get("owner", -1)))
	if opponent.is_empty():
		return printed
	var effect: Dictionary = gate_effect(slot)
	match str(effect.get("type", "")):
		"double_lowest_printed":
			# A printed-G tie has no unique lowest unit. This desktop branch
			# adds no extra G until original tie behavior is verified.
			if printed < int(opponent.get("g", 0)):
				return printed * 2
		"swap_printed":
			var required: String = str(effect.get("required_attribute", effect.get("attribute", "")))
			if required.is_empty() or required == str(unit.get("attribute", "")) or required == str(opponent.get("attribute", "")):
				return int(opponent.get("g", 0))
	return printed


func _battle_base_power(slot: int, unit: Dictionary) -> int:
	return maxi(0, effective_printed_power(slot, unit) + int(unit.get("roll_bonus", 0)) - int(unit.get("sphere_damage", 0)) - int(unit.get("field_damage", 0)))


func _opponent_on_gate(slot: int, owner: int) -> Dictionary:
	if not _valid_owner(owner) or not _opposed_gate(slot):
		return {}
	for unit: Dictionary in gates[slot]["bakugan"]:
		if int(unit["owner"]) != owner:
			return unit
	return {}


func minigame_type(slot: int) -> String:
	if not gates.has(slot):
		return ""
	if rules_profile=="ds":
		# Scratch is the currently implemented DS game. Native selection among
		# all six games has not yet been recovered.
		return "scratch"
	match str(gates[slot].get("color_type", "")):
		"gold": return "shooting"
		"silver": return "timing"
		"copper": return "shaking"
	return ""


func get_standing_power(slot: int, owner: int) -> int:
	if not gates.has(slot) or not _valid_owner(owner):
		return 0
	var total: int = 0
	for unit: Dictionary in gates[slot]["bakugan"]:
		if int(unit["owner"]) == owner:
			total += _battle_base_power(slot, unit) + gate_unit_bonus(slot, unit)
	return total


func needs_stay(owner: int) -> bool:
	if winner != -1 or not _valid_owner(owner) or not stay_markers[owner].is_empty():
		return false
	# A used unit after a miss is not a standing unit. Pending battles are not
	# eligible either: every team member must stand alone on its own gate.
	for index in range(teams[owner].size()):
		var standing: bool = false
		for gate: Dictionary in gates.values():
			var occupants: Array = gate["bakugan"]
			if occupants.size() == 1 and int(occupants[0]["owner"]) == owner and int(occupants[0]["index"]) == index:
				standing = true
				break
		if not standing:
			return false
	return not teams[owner].is_empty()


func choose_stay(owner: int, slot: int) -> bool:
	if turn != owner or not needs_stay(owner) or not gates.has(slot) or not _can_throw(owner):
		return false
	var occupants: Array = gates[slot]["bakugan"]
	if occupants.size() != 1 or int(occupants[0]["owner"]) != owner:
		return false
	stay_markers[owner] = {
		"owner": owner, "index": int(occupants[0]["index"]), "slot": slot,
		"eligible_serial": turn_serial + (2 if turn == owner else 1),
	}
	turn_action_taken = true
	return true


func process_stay(owner: int) -> Dictionary:
	if winner != -1 or not _valid_owner(owner) or turn != owner:
		return {}
	if rules_profile == "ds" and (opening_active or turn_action_taken or pending_slot() >= 0):
		return {}
	var marker: Dictionary = stay_markers[owner]
	if marker.is_empty() or turn_serial < int(marker["eligible_serial"]):
		return {}
	var slot: int = int(marker["slot"])
	if not gates.has(slot):
		stay_markers[owner] = {}
		return {}
	var occupants: Array = gates[slot]["bakugan"]
	if occupants.size() != 1 or int(occupants[0]["owner"]) != owner or int(occupants[0]["index"]) != int(marker["index"]):
		stay_markers[owner] = {}
		return {}
	var index: int = int(marker["index"])
	_capture_gate(slot, owner)
	return {"event": "stay_capture", "owner": owner, "slot": slot, "index": index, "winner": winner}


func apply_sphere_attack(owner: int, slot: int, damage: int) -> Dictionary:
	# Numeric damage is supplied by the throw controller: the Wii manual
	# confirms the mechanic but does not specify a damage formula.
	if winner != -1 or not _valid_owner(owner) or not gates.has(slot) or damage <= 0 or not _can_throw(owner):
		return {"event": "invalid"}
	var occupants: Array = gates[slot]["bakugan"]
	if occupants.size() != 1 or int(occupants[0]["owner"]) == owner:
		return {"event": "invalid"}
	var unit: Dictionary = occupants[0]
	var previous: int = _standing_base_power(unit)
	var applied: int = mini(damage, previous)
	unit["sphere_damage"] = int(unit.get("sphere_damage", 0)) + applied
	var remaining: int = _standing_base_power(unit)
	var result: Dictionary = {
		"event": "sphere_attack", "owner": owner, "slot": slot,
		"target_owner": int(unit["owner"]), "target_index": int(unit["index"]),
		"damage": applied, "previous_g": previous, "remaining_g": remaining,
	}
	# Surviving Sphere damage alone does not cancel Stay. The documented
	# cancellation conditions are a subsequent battle or Critical K.O.
	if remaining == 0:
		_capture_gate(slot, owner)
		result["event"] = "critical_ko"
		result["winner"] = winner
	return result


func _standing_base_power(unit: Dictionary) -> int:
	return maxi(0, int(unit["g"]) + int(unit.get("roll_bonus", 0)) - int(unit.get("sphere_damage", 0)) - int(unit.get("field_damage", 0)))


func use_ability(owner: int, index: int, slot: int = -1, battle_type: String = "", preparing: bool = true, context: Dictionary = {}) -> Dictionary:
	# Indices refer to the current hand; removing one card shifts later indices.
	if winner != -1 or not _valid_owner(owner):
		return {}
	if index < 0 or index >= abilities[owner].size():
		return {}
	if rules_profile == "ds":
		if slot < 0:
			slot = pending_slot()
		if not can_play_ability(owner, index, slot, battle_type, preparing, context):
			return {}
	if slot >= 0:
		if not _opposed_gate(slot) or str(gate_effect(slot).get("type", "")) == "no_abilities":
			return {}
	else:
		# Compatibility callers omit slot; they still cannot bypass Ability Block.
		for battle_slot: Variant in gates:
			if _opposed_gate(int(battle_slot)) and str(gate_effect(int(battle_slot)).get("type", "")) == "no_abilities":
				return {}
	var card: Dictionary = abilities[owner][index]
	abilities[owner].remove_at(index)
	spent_abilities[owner].append(card)
	return card


func ability_block_reason(slot: int, owner: int) -> String:
	if not _valid_owner(owner) or not _opposed_gate(slot):
		return "Способности доступны только в бою двух соперников."
	if str(gate_effect(slot).get("type", "")) == "no_abilities":
		return "Эти ворота запрещают карты способностей."
	return ""


func can_play_ability(owner: int, index: int, slot: int, battle_type: String = "", preparing: bool = true, context: Dictionary = {}) -> bool:
	if winner != -1 or not _valid_owner(owner) or index < 0 or index >= abilities[owner].size() or not ability_block_reason(slot, owner).is_empty():
		return false
	if rules_profile == "ds" and str(abilities[owner][index].get("rules_profile", "")) != "ds":
		return false
	var unit: Dictionary = {}
	var opponent: Dictionary = {}
	for occupant: Dictionary in gates[slot]["bakugan"]:
		if int(occupant["owner"]) == owner:
			unit = occupant
		else:
			opponent = occupant
	# Board ownership, scores and reserve composition always come from the
	# engine. The controller supplies the current powers and per-battle effect
	# snapshot; it cannot override gate ownership or reserve composition.
	var validated_context: Dictionary = battle_context(slot, owner)
	for field: String in ["current_powers","blocked_families","opponent_blocked_families","redo_used"]:
		if context.has(field): validated_context[field]=context[field]
	return Effects.can_play(abilities[owner][index], unit, opponent, battle_type, preparing, validated_context)


func _opposed_gate(slot: int) -> bool:
	if not gates.has(slot):
		return false
	var occupants: Array = gates[slot]["bakugan"]
	return occupants.size() == 2 and int(occupants[0]["owner"]) != int(occupants[1]["owner"])


func battle_context(slot: int, owner: int) -> Dictionary:
	if not _valid_owner(owner) or not _opposed_gate(slot):
		return {}
	var team_attributes: Array[String] = []
	var reserve_attributes: Array[String] = []
	for index in range(teams[owner].size()):
		var attribute: String = str(teams[owner][index].get("attribute", ""))
		team_attributes.append(attribute)
		if available_units(owner).has(index):
			reserve_attributes.append(attribute)
	var standing_counts: Array[int] = [0, 0]
	for gate: Dictionary in gates.values():
		for unit: Dictionary in gate["bakugan"]:
			standing_counts[int(unit["owner"])] += 1
	return {
		"owner": owner, "gate_owner": int(gates[slot].get("owner", -1)),
		"gate_color": str(gates[slot].get("color_type", "")),
		"scores": scores.duplicate(), "captured_count": scores[owner],
		"opponent_captured_count": scores[1 - owner],
		"team_attributes": team_attributes, "reserve_attributes": reserve_attributes,
		"standing_count": standing_counts[owner], "opponent_standing_count": standing_counts[1 - owner],
		"spent_ability_count": spent_abilities[owner].size(),
		"ability_multiplier": int(gate_effect(slot).get("multiplier", 2)) if str(gate_effect(slot).get("type", "")) == "ability_multiplier" else 1,
	}


func resolve_battle(slot: int, player_extra: int, enemy_extra: int) -> Dictionary:
	if winner != -1 or not gates.has(slot):
		return {"event": "invalid"}
	var gate: Dictionary = gates[slot]
	var occupants: Array = gate["bakugan"]
	if occupants.size() != 2 or int(occupants[0]["owner"]) == int(occupants[1]["owner"]):
		return {"event": "invalid"}
	var totals: Array[int] = [player_extra, enemy_extra]
	for unit: Dictionary in occupants:
		var owner: int = int(unit["owner"])
		totals[owner] += _battle_base_power(slot, unit) + gate_unit_bonus(slot, unit)
	var victor: int = int(occupants[0]["owner"])
	if totals[0] > totals[1]:
		victor = 0
	elif totals[1] > totals[0]:
		victor = 1
	var returned: bool = str(gate_effect(slot).get("type", "")) == "return_all_abilities_after_battle"
	if returned:
		for owner in range(2):
			abilities[owner].append_array(spent_abilities[owner])
			spent_abilities[owner].clear()
	_capture_gate(slot, victor)
	return {
		"event": "capture", "owner": victor, "slot": slot,
		"player_g": totals[0], "enemy_g": totals[1], "winner": winner,
		"abilities_returned": returned,
	}


func finish_turn() -> bool:
	if not can_finish_turn():
		return false
	# Misses return to supply; a successful landing spends that ball for its cycle.
	for owner in range(2):
		for index in range(teams[owner].size()):
			if not _unit_on_board(owner, index) and not bool(teams[owner][index].get("landed_cycle", false)):
				teams[owner][index]["used"] = false
	turn = 1 - turn
	turn_serial += 1
	gate_placed_this_turn = false
	turn_action_taken = false
	return true


func recycle_used(owner: int) -> bool:
	# Only exhausted three-ball landing cycles recycle, never an active reserve.
	if winner != -1 or not _valid_owner(owner) or not available_units(owner).is_empty():
		return false
	if rules_profile == "ds" and (owner != turn or opening_active or pending_slot() >= 0 or turn_action_taken):
		return false
	for unit: Dictionary in teams[owner]:
		if not bool(unit.get("landed_cycle", false)):
			return false
	var recycled: bool = false
	for index in range(teams[owner].size()):
		if not _unit_on_board(owner, index):
			teams[owner][index]["used"] = false
			teams[owner][index]["landed_cycle"] = false
			recycled = true
	return recycled


func mark_throw_used(owner: int, index: int, successful: bool = false) -> bool:
	# Forceful Critical K.O. can consume the throw before land() is called.
	if winner != -1 or not _valid_owner(owner) or not available_units(owner).has(index) or not _can_throw(owner):
		return false
	teams[owner][index]["used"] = true
	turn_action_taken = true
	if successful:
		teams[owner][index]["landed_cycle"] = true
	return true


func consume_throw(owner: int, index: int, landed: bool = true) -> bool:
	return mark_throw_used(owner, index, landed)


func _valid_owner(owner: int) -> bool:
	return owner == 0 or owner == 1


func _unit_on_board(owner: int, index: int) -> bool:
	for gate: Dictionary in gates.values():
		for unit: Dictionary in gate["bakugan"]:
			if int(unit["owner"]) == owner and int(unit["index"]) == index:
				return true
	return false


func _capture_gate(slot: int, owner: int) -> void:
	var gate: Dictionary = gates[slot]
	_clear_stay_for_slot(slot)
	for unit: Dictionary in gate["bakugan"]:
		teams[int(unit["owner"])][int(unit["index"])]["used"] = true
	gates.erase(slot)
	scores[owner] += 1
	if scores[owner] >= TARGET_SCORE:
		winner = owner


func _clear_stay_for_slot(slot: int) -> void:
	for owner in range(2):
		if not stay_markers[owner].is_empty() and int(stay_markers[owner]["slot"]) == slot:
			stay_markers[owner] = {}


func _make_gates(owner: int) -> Array[Dictionary]:
	if rules_profile == "ds":
		return DSPlayableCatalog.make_deck("gate", [], owner)
	return GateCatalog.make_deck(GateCatalog.DEFAULT_SELECTION, owner)


func _make_abilities(owner: int) -> Array[Dictionary]:
	if rules_profile == "ds":
		return DSPlayableCatalog.make_deck("ability", [], owner)
	return AbilityCatalog.make_deck(AbilityCatalog.DEFAULT_SELECTION, owner)
