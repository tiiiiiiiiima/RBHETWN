extends RefCounted
## Standalone card duel inspired by documented Bloxugan setup and card text.
## Draw sizes, response order, targeted team combat and elimination victory are local
## choices, explicitly described in docs/BLOXUGAN-COMPARISON-0.8.md.

const Catalog = preload("res://scripts/anime_card_catalog.gd")
const TrapCatalog = preload("res://scripts/anime_trap_catalog.gd")
const Board = preload("res://scripts/board_layout.gd")
const ATTRIBUTES: Array[String] = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]

var turn: int = 0
var phase: String = "opening"
var winner: int = -1
var teams: Array = [[], []]
var gates: Dictionary = {}
var gate_hands: Array = [[], []]
var ability_hands: Array = [[], []]
var gate_decks: Array = [[], []]
var ability_decks: Array = [[], []]
var spent_gates: Array = [[], []]
var spent_abilities: Array = [[], []]
var defeated: Array = [[], []]
var battle: Dictionary = {}
var seed_value: int = 1
var turn_serial: int = 0
var placed_this_turn: bool = false
var acted_this_turn: bool = false
var loadouts: Dictionary = {}
var history: Array[Dictionary] = []
var support_slots: Array = [{}, {}]

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _opening_queue: Array[int] = [0, 1]
var _opening_start: int = 0
var _serial: int = 0
var _own_turns: Array[int] = [0, 0]
var _last_card: Dictionary = {}
var _trap_actions: Array[Dictionary] = []
var _remaining_chain: Array = []
var _chain_outcomes: Array[Dictionary] = []
var _clone_serial: int = 0


func new_match(team0: Array, team1: Array, seed: int = 1, gate_loadouts: Array = [], ability_loadouts: Array = [], support_loadouts: Array = []) -> Dictionary:
	# Validate everything before replacing a running match.
	var normalized0: Array[Dictionary] = _normalize_team(team0, 0)
	var normalized1: Array[Dictionary] = _normalize_team(team1, 1)
	if normalized0.size() != 3 or normalized1.size() != 3:
		return _invalid("Для каждого игрока нужны три разных живых бакугана с допустимой стихией и G-Power.")
	var gate_ids: Array = []
	var ability_ids: Array = []
	if not gate_loadouts.is_empty() and (gate_loadouts.size() != 2 or not gate_loadouts[0] is Array or not gate_loadouts[1] is Array):
		return _invalid("Колода ворот задаётся отдельно для двух игроков.")
	if not ability_loadouts.is_empty() and (ability_loadouts.size() != 2 or not ability_loadouts[0] is Array or not ability_loadouts[1] is Array):
		return _invalid("Колода способностей задаётся отдельно для двух игроков.")
	if not support_loadouts.is_empty() and support_loadouts.size() != 2:
		return _invalid("Выбери не более одного помощника отдельно для каждого игрока.")
	var normalized_supports: Array = [{}, {}]
	for owner in range(2):
		var selected: Variant = null if support_loadouts.is_empty() else support_loadouts[owner]
		if not TrapCatalog.valid_selection(selected):
			return _invalid("Неизвестный помощник или недоступный исходный вариант стихии.")
		var support: Dictionary = TrapCatalog.normalize_selection(selected)
		if not support.is_empty():
			support.merge({"owner": owner, "status": "ready", "caster_index": -1, "slot": -1,
				"used": false, "stats": {"deployments": 0, "successful": 0, "countered": 0, "failed": 0, "cancelled_battle": 0, "turn_serial": -1}}, true)
			normalized_supports[owner] = support
	var normalized: Array = [normalized0, normalized1]
	for owner in range(2):
		var selected_gates: Array = Catalog.default_gate_loadout(normalized[owner]) if gate_loadouts.is_empty() else gate_loadouts[owner]
		var selected_abilities: Array = Catalog.default_ability_loadout(normalized[owner]) if ability_loadouts.is_empty() else ability_loadouts[owner]
		if not Catalog.valid_gate_loadout(selected_gates):
			return _invalid("Нужны шесть карт ворот с соблюдением лимита копий.")
		if not Catalog.valid_ability_loadout(selected_abilities):
			return _invalid("Нужны десять способностей с соблюдением лимита копий.")
		gate_ids.append(selected_gates.duplicate())
		ability_ids.append(selected_abilities.duplicate())

	seed_value = seed
	_random.seed = seed
	turn = 0
	phase = "opening"
	winner = -1
	turn_serial = 0
	placed_this_turn = false
	acted_this_turn = false
	teams = normalized
	gates = {}
	gate_hands = [[], []]
	ability_hands = [[], []]
	gate_decks = [[], []]
	ability_decks = [[], []]
	spent_gates = [[], []]
	spent_abilities = [[], []]
	defeated = [[], []]
	battle = {}
	history.clear()
	support_slots = normalized_supports
	_opening_queue = [0, 1]
	_opening_start = 0
	_serial = 0
	_own_turns = [0, 0]
	_last_card = {}
	_trap_actions.clear()
	_remaining_chain.clear()
	_chain_outcomes.clear()
	_clone_serial = 0
	loadouts = {"gates": gate_ids.duplicate(true), "abilities": ability_ids.duplicate(true),
		"supports": support_loadouts.duplicate(true) if not support_loadouts.is_empty() else [null, null]}
	for owner in range(2):
		for card_id: String in gate_ids[owner]:
			var gate: Dictionary = Catalog.get_gate(card_id).duplicate(true)
			gate["owner"] = owner
			gate_decks[owner].append(gate)
		for card_id: String in ability_ids[owner]:
			var ability: Dictionary = Catalog.get_ability(card_id).duplicate(true)
			ability["owner"] = owner
			ability_decks[owner].append(ability)
		_shuffle(gate_decks[owner])
		_shuffle(ability_decks[owner])
		_draw(owner, 3, 5)
	return _success("new_match", {"seed": seed_value, "loadouts": loadouts.duplicate(true)})


func legal_gate_slots() -> Array[int]:
	var result: Array[int] = []
	if winner != -1:
		return result
	for slot in range(Board.SLOT_COUNT):
		if not gates.has(slot):
			result.append(slot)
	return result


func available_units(owner: int) -> Array[int]:
	var result: Array[int] = []
	if not _valid_owner(owner) or winner != -1:
		return result
	for index in range(teams[owner].size()):
		if str(teams[owner][index].status) == "reserve":
			result.append(index)
	return result


func field_units(owner: int) -> Array[int]:
	var result: Array[int] = []
	if not _valid_owner(owner) or winner != -1:
		return result
	for index in range(teams[owner].size()):
		if str(teams[owner][index].status) == "field":
			result.append(index)
	return result


func place_gate(owner: int, hand_index: int, slot: int) -> Dictionary:
	if not _owns_action(owner) or (phase != "opening" and phase != "turn"):
		return _invalid("Сейчас нельзя ставить карту ворот.")
	if phase == "turn" and (placed_this_turn or acted_this_turn):
		return _invalid("За ход можно поставить одну карту до броска или отзыва.")
	if not legal_gate_slots().has(slot):
		return _invalid("Место ворот занято или находится вне поля.")
	if hand_index < 0 or hand_index >= gate_hands[owner].size():
		return _invalid("Такой карты ворот нет в руке.")
	var held_gate: Variant = gate_hands[owner][hand_index]
	if not held_gate is Dictionary or Catalog.get_gate(str(held_gate.get("id", ""))).is_empty():
		return _invalid("Карта ворот отсутствует в поддерживаемом каталоге.")
	var gate: Dictionary = gate_hands[owner].pop_at(hand_index)
	gate["owner"] = owner
	gate["card_id"] = str(gate.id)
	gate["revealed"] = false
	gate["nullified"] = false
	gate["effect_applied"] = false
	gate["bakugan"] = []
	gate["occupants"] = gate.bakugan
	gates[slot] = gate
	placed_this_turn = true
	var result: Dictionary = _success("gate_placed", {"owner": owner, "slot": slot, "card_id": str(gate.id)})
	if phase == "opening":
		_opening_queue.pop_front()
		if not _opening_queue.is_empty():
			turn = _opening_queue[0]
			placed_this_turn = false
		else:
			turn = _opening_start
			_start_turn(false)
			result["opening_complete"] = true
	return result


func throw_unit(owner: int, unit_index: int, slot: int) -> Dictionary:
	if not _owns_action(owner) or phase != "turn" or acted_this_turn:
		return _invalid("Бросок доступен один раз в свой обычный ход.")
	if not available_units(owner).has(unit_index):
		return _invalid("Этот бакуган сейчас не находится в резерве.")
	if slot < -1 or slot >= Board.SLOT_COUNT:
		return _invalid("Недопустимое место броска.")
	if gates.has(slot):
		var occupants: Array = gates[slot].bakugan
		var standing_owners: Array[int] = []
		for standing: Dictionary in occupants:
			if not standing_owners.has(int(standing.owner)):
				standing_owners.append(int(standing.owner))
		if standing_owners.size() > 1:
			return _invalid("Этот бой уже начался.")
	acted_this_turn = true
	if not gates.has(slot):
		return _success("miss", {"owner": owner, "index": unit_index, "slot": slot})
	var unit: Dictionary = teams[owner][unit_index]
	unit["status"] = "field"
	unit["slot"] = slot
	unit["ability_g"] = 0
	unit["gate_effect_g"] = 0
	unit["support_g"] = 0
	unit["current_g"] = maxi(0, int(unit.base_g) + int(unit.get("permanent_support_g", 0)))
	var gate: Dictionary = gates[slot]
	gate.bakugan.append(unit)
	if gate.bakugan.size() == 1:
		return _success("stand", {"owner": owner, "index": unit_index, "slot": slot})
	var opposed: bool = false
	for standing: Dictionary in gate.bakugan:
		if int(standing.owner) != owner:
			opposed = true
			break
	if not opposed:
		return _success("stack", {"owner": owner, "index": unit_index, "slot": slot, "count": gate.bakugan.size()})
	phase = "battle"
	battle = {"slot": slot, "priority": int(gate.owner), "passes": 0, "chain": [], "throw_owner": owner}
	_last_card = {}
	var gate_outcome: Dictionary = {}
	if bool(gate.get("effect", {}).get("auto_open", false)) and not bool(gate.nullified):
		gate["revealed"] = true
		gate_outcome = _activate_gate(slot)
	_trigger_field_traps()
	return _success("battle", {"slot": slot, "priority": int(battle.priority), "totals": battle_totals(), "gate_outcome": gate_outcome})


func recall_unit(owner: int, unit_index: int) -> Dictionary:
	if not _owns_action(owner) or phase != "turn" or acted_this_turn:
		return _invalid("Отзыв расходует действие броска в свой ход.")
	if not field_units(owner).has(unit_index):
		return _invalid("Можно отозвать только своего живого бакугана с поля.")
	var unit: Dictionary = teams[owner][unit_index]
	var slot: int = int(unit.slot)
	if not gates.has(slot):
		return _invalid("Нельзя отзывать участника незавершённого боя.")
	var occupants: Array = gates[slot].bakugan
	for standing: Dictionary in occupants:
		if int(standing.owner) != owner:
			return _invalid("Нельзя отзывать участника незавершённого боя.")
	for position in range(occupants.size() - 1, -1, -1):
		if int(occupants[position].owner) == owner and int(occupants[position].index) == unit_index:
			occupants.remove_at(position)
			break
	_return_unit(unit)
	acted_this_turn = true
	return _success("recall", {"owner": owner, "index": unit_index, "slot": slot})


func finish_turn(owner: int) -> Dictionary:
	if not _owns_action(owner) or phase != "turn":
		return _invalid("Сначала заверши постановку или текущий бой.")
	turn = 1 - turn
	turn_serial += 1
	if gates.is_empty():
		_begin_opening(turn)
	else:
		_start_turn(true)
	return _success("turn_finished", {"turn": turn, "phase": phase, "turn_serial": turn_serial})


func open_gate(owner: int, caster_index: int = -1, target_index: int = -1) -> Dictionary:
	if caster_index < -1 or target_index < -1:
		return _invalid("Недопустимый индекс участника открытия ворот.")
	if not _has_priority(owner):
		return _invalid("Открыть ворота можно с приоритетом в текущем бою.")
	var slot: int = int(battle.slot)
	var gate: Dictionary = gates[slot]
	if int(gate.owner) != owner:
		return _invalid("Карту ворот открывает только её владелец.")
	if bool(gate.revealed) or bool(gate.nullified):
		return _invalid("Эти ворота уже открыты или отменены.")
	if caster_index >= 0 and _battle_unit(owner, caster_index).is_empty():
		return _invalid("Выбранный бакуган не участвует в этом бою.")
	if target_index >= 0 and _battle_unit(1 - owner, target_index).is_empty():
		return _invalid("Выбранная цель не участвует в этом бою.")
	for pending: Dictionary in battle.chain:
		if bool(pending.cancelled) or bool(pending.resolved):
			continue
		var effect: Dictionary = pending.card.effect
		if str(effect.type) == "nullify" and bool(effect.get("cannot_open_in_response", false)):
			return _invalid("Эта способность запрещает открывать ворота в ответ на её отмену.")
	gate["revealed"] = true
	var outcome: Dictionary = _activate_gate(slot, caster_index, target_index)
	if phase != "battle":
		return _success("battle_cancelled", {"owner": owner, "slot": slot, "gate_outcome": outcome, "winner": winner})
	_respond(owner)
	return _success("gate_opened", {"owner": owner, "slot": slot, "totals": battle_totals(), "gate_outcome": outcome})


func can_open_gate(owner: int) -> bool:
	if not _has_priority(owner):
		return false
	var gate: Dictionary = gates[int(battle.slot)]
	if int(gate.owner) != owner or bool(gate.revealed) or bool(gate.nullified):
		return false
	for pending: Dictionary in battle.chain:
		if bool(pending.cancelled) or bool(pending.resolved):
			continue
		var effect: Dictionary = pending.card.effect
		if str(effect.type) == "nullify" and bool(effect.get("cannot_open_in_response", false)):
			return false
	return true


func can_play_ability(owner: int, hand_index: int, caster_index: int = -1, target_index: int = -1, target_owner: int = -1) -> bool:
	return ability_error(owner, hand_index, caster_index, target_index, target_owner).is_empty()


func ability_options(owner: int, hand_index: int) -> Array[Dictionary]:
	# Preview every legal caster/target pair without consuming the card.
	var result: Array[Dictionary] = []
	if not _valid_owner(owner) or not _has_priority(owner) or hand_index<0 or hand_index>=ability_hands[owner].size():
		return result
	var card: Dictionary = ability_hands[owner][hand_index]
	var targeted: bool = str(card.get("effect",{}).get("type","")) in ["correlation","transfer","enemy_loss"]
	for caster: Dictionary in battle_units(owner):
		var targets: Array[Dictionary] = []
		if targeted:
			for target_side: int in [1-owner,owner]:
				for unit: Dictionary in battle_units(target_side):
					targets.append({"owner":target_side,"index":int(unit.index)})
		else:
			targets.append({"owner":owner,"index":int(caster.index)})
		for target: Dictionary in targets:
			if can_play_ability(owner,hand_index,int(caster.index),int(target.index),int(target.owner)):
				result.append({"caster_index":int(caster.index),"target_index":int(target.index),"target_owner":int(target.owner)})
	return result


func ability_error(owner: int, hand_index: int, caster_index: int = -1, target_index: int = -1, target_owner: int = -1) -> String:
	if caster_index < -1 or target_index < -1:
		return "Недопустимый индекс участника."
	if not _has_priority(owner):
		return "Сейчас приоритет ответа у другого игрока."
	if hand_index < 0 or hand_index >= ability_hands[owner].size():
		return "Такой способности нет в руке."
	var held_card: Variant = ability_hands[owner][hand_index]
	if not held_card is Dictionary or Catalog.get_ability(str(held_card.get("id", ""))).is_empty():
		return "Карта отсутствует в поддерживаемом каталоге."
	var card: Dictionary = ability_hands[owner][hand_index]
	var unit: Dictionary = _choose_caster(owner, card, caster_index)
	if unit.is_empty():
		return "У тебя нет участника этого боя."
	if not _compatible_ability(card, unit):
		return "Выбранному бакугану не подходит вид или стихия этой способности."
	var effect: Dictionary = card.effect
	if str(effect.type) == "correlation" and not _correlation_caster(unit, effect.pair):
		return "Нужна одна из двух указанных стихий."
	if str(effect.type) == "counter":
		var pending: Dictionary = _counter_target()
		if pending.is_empty():
			return "Нет последней ожидающей обычной способности для отмены."
	if str(effect.type) == "nullify" and bool(gates[int(battle.slot)].nullified):
		return "Ворота уже отменены."
	if target_owner != -1 and not _valid_owner(target_owner):
		return "Недопустимый владелец цели."
	var uses_target: bool = str(effect.type) in ["correlation", "transfer", "enemy_loss"]
	if uses_target and target_owner != -1 and target_index < 0:
		return "Для явно указанного владельца выбери индекс цели."
	if uses_target and target_index >= 0:
		var requested_owner: int = 1 - owner if target_owner == -1 else target_owner
		var target: Dictionary = _battle_unit(requested_owner, target_index)
		if target.is_empty():
			return "Выбранная цель не участвует в текущем бою."
		if str(effect.type) != "correlation" and requested_owner == owner:
			return "Эта способность направлена на противника."
		if requested_owner == owner and int(target.index) == int(unit.index):
			return "Корреляция требует другого бакугана в качестве союзной цели."
		if requested_owner == owner and not _correlation_valid(unit, target, effect.pair):
			return "Союзная цель корреляции должна иметь вторую указанную стихию."
	return ""


func play_ability(owner: int, hand_index: int, caster_index: int = -1, target_index: int = -1, target_owner: int = -1) -> Dictionary:
	var error: String = ability_error(owner, hand_index, caster_index, target_index, target_owner)
	if not error.is_empty():
		return _invalid(error)
	var card: Dictionary = ability_hands[owner].pop_at(hand_index)
	var caster: Dictionary = _choose_caster(owner, card, caster_index)
	var target: Dictionary = _choose_target(owner, card, caster, target_index, target_owner)
	spent_abilities[owner].append(card)
	_serial += 1
	var node: Dictionary = {
		"serial": _serial, "owner": owner, "card": card,
		"cancelled": false, "resolved": false, "target_serial": -1,
		"caster_index": int(caster.index), "target_index": int(target.index), "target_owner": int(target.owner),
	}
	if str(card.effect.type) == "counter":
		node["target_serial"] = int(_counter_target().serial)
	var immediate: bool = bool(card.get("immediate", false))
	var outcomes: Array[Dictionary] = _activated_ability_supports(node)
	if immediate:
		outcomes.append(_apply_node(node))
	else:
		battle.chain.append(node)
	_last_card = {"serial": _serial, "immediate": immediate}
	_respond(owner)
	return _success("ability_played", {
		"owner": owner, "card_id": str(card.id), "title": str(card.title),
		"immediate": immediate, "outcomes": outcomes, "totals": battle_totals(),
	})


func trap_casters(owner: int) -> Array[int]:
	var result: Array[int] = []
	if not _valid_owner(owner) or support_slots[owner].is_empty():
		return result
	for unit: Dictionary in battle_units(owner):
		if TrapCatalog.compatible_caster(support_slots[owner], unit):
			result.append(int(unit.index))
	return result


func trap_choices(owner: int) -> Dictionary:
	if not _valid_owner(owner) or support_slots[owner].is_empty() or phase != "battle":
		return {}
	var effect_type: String = str(support_slots[owner].get("effect", {}).get("type", ""))
	var result: Dictionary = {}
	if effect_type == "copy_open_gate":
		var source_slots: Array[int] = []
		for slot: int in gates:
			if bool(gates[slot].revealed) and not bool(gates[slot].nullified):
				source_slots.append(slot)
		source_slots.sort()
		result["source_slots"] = source_slots
	elif effect_type == "drill_move":
		var destinations: Array[int] = []
		for slot: int in Board.neighbors(int(battle.slot)):
			if gates.has(slot):
				destinations.append(slot)
		result["destination_slots"] = destinations
	elif effect_type == "defeated_copy":
		result["defeated_indices"] = defeated[owner].duplicate()
	elif effect_type == "transfer_resolved_changes":
		var sources: Array[Dictionary] = []
		var targets: Array[Dictionary] = []
		for side in range(2):
			for unit: Dictionary in teams[side]:
				if str(unit.status) == "defeated" or int(unit.slot) == int(battle.slot):
					continue
				var change: int = int(unit.current_g) - int(unit.base_g)
				if change != 0:
					sources.append({"owner": side, "index": int(unit.index), "name": str(unit.name), "change": change})
			for unit: Dictionary in battle_units(side):
				targets.append({"owner": side, "index": int(unit.index), "name": str(unit.name)})
		result.merge({"history_sources": sources, "target_units": targets})
	return result


func pending_trap_action() -> Dictionary:
	return _trap_actions[0].duplicate(true) if not _trap_actions.is_empty() else {}


func resolve_trap_action(owner: int, options: Dictionary) -> Dictionary:
	if _trap_actions.is_empty() or phase != "battle" or int(_trap_actions[0].owner) != owner:
		return _invalid("Сейчас нет обязательного действия этого игрока.")
	var action: Dictionary = _trap_actions[0]
	var index: Variant = options.get("unit_index", -1)
	if typeof(index) != TYPE_INT or not available_units(owner).has(index):
		return _invalid("Выбери живого бакугана из резерва для обязательного действия.")
	var unit: Dictionary = teams[owner][int(index)]
	var result: Dictionary = {"owner": owner, "index": int(index), "support_id": str(action.support_id)}
	if str(action.type) == "roll":
		var slot: Variant = options.get("slot", -1)
		if typeof(slot) != TYPE_INT or int(slot) < -1 or int(slot) >= Board.SLOT_COUNT:
			return _invalid("Недопустимое место дополнительного броска.")
		result["slot"] = int(slot)
		if int(slot) == int(action.trap_slot):
			result["event"] = "trap_roll_returned"
		elif not gates.has(int(slot)):
			result["event"] = "trap_roll_miss"
		elif not action.slots.has(int(slot)):
			# Concurrent off-gate battles are outside the local single-battle mode.
			result["event"] = "trap_roll_returned"
			result["reason"] = "off_battle_opposition"
		else:
			_enter_support_unit(unit, int(slot))
			result["event"] = "trap_roll_stand"
	else:
		var outgoing: Variant = options.get("outgoing_index", -1)
		if typeof(outgoing) != TYPE_INT or not action.outgoing_indices.has(outgoing) or _battle_unit(owner, int(outgoing)).is_empty():
			return _invalid("Выбери своего участника текущего боя для замены.")
		var leaving: Dictionary = _battle_unit(owner, int(outgoing))
		gates[int(battle.slot)].bakugan.erase(leaving)
		_return_unit(leaving)
		_enter_support_unit(unit, int(battle.slot))
		result.merge({"event": "trap_swap", "outgoing_index": int(outgoing)})
	_trap_actions.pop_front()
	_sync_battle_power()
	if _trap_actions.is_empty():
		result["chain_outcome"] = _continue_chain()
	return _success(str(result.event), result)


func _enter_support_unit(unit: Dictionary, slot: int) -> void:
	unit["status"] = "field"
	unit["slot"] = slot
	unit["ability_g"] = 0
	unit["gate_effect_g"] = 0
	unit["support_g"] = 0
	unit["current_g"] = maxi(0, int(unit.base_g) + int(unit.get("permanent_support_g", 0)))
	gates[slot].bakugan.append(unit)


func can_deploy_trap(owner: int, caster_index: int = -1, target_index: int = -1, options: Dictionary = {}) -> bool:
	return trap_error(owner, caster_index, target_index, options).is_empty()


func trap_error(owner: int, caster_index: int = -1, target_index: int = -1, options: Dictionary = {}) -> String:
	if caster_index < -1 or target_index < -1:
		return "Недопустимый индекс участника помощи."
	if not _has_priority(owner):
		return "Помощника можно вызвать только с приоритетом ответа в аниме-бою."
	var support: Dictionary = support_slots[owner]
	if support.is_empty():
		return "В отдельном слоте не выбран помощник."
	if bool(support.used) or str(support.status) != "ready":
		return "Этот помощник уже был вызван в текущем матче."
	if not bool(support.get("supported", false)):
		return "Полный эффект исходной карты этого помощника пока не реализован."
	var caster: Dictionary = _choose_trap_caster(owner, caster_index)
	if caster.is_empty() or not TrapCatalog.compatible_caster(support, caster):
		return "Нужен свой участник боя с той же стихией, что у выбранного помощника."
	if target_index >= 0 and str(support.effect.type) != "transfer_resolved_changes" and _battle_unit(1 - owner, target_index).is_empty():
		return "Выбранная цель помощи не участвует в текущем бою."
	var effect_type: String = str(support.effect.type)
	for key: String in options:
		if typeof(options[key]) != TYPE_INT:
			return "Недопустимый тип параметра эффекта ловушки."
	var choices: Dictionary = trap_choices(owner)
	var allowed_options: Array[String] = []
	match effect_type:
		"copy_open_gate":
			allowed_options = ["source_slot"]
			var sources: Array = choices.get("source_slots", [])
			if sources.is_empty():
				return "Для Балитона нужна открытая действующая карта ворот."
			if not sources.has(options.get("source_slot", sources[0])):
				return "Выбери открытые действующие ворота для копирования."
		"drill_move":
			allowed_options = ["destination_slot"]
			if options.has("destination_slot") and not choices.get("destination_slots", []).has(options.destination_slot):
				return "Хексадос перемещается только на соседнюю карту ворот."
		"defeated_copy":
			allowed_options = ["unit_index"]
			var lost: Array = choices.get("defeated_indices", [])
			if lost.is_empty():
				return "Для копии Теты нужен ранее побеждённый союзник."
			if not lost.has(options.get("unit_index", lost[0])):
				return "Выбери ранее побеждённого союзника."
		"transfer_resolved_changes":
			allowed_options = ["source_owner", "source_index", "target_owner", "target_index"]
			var sources: Array = choices.get("history_sources", [])
			if sources.is_empty():
				return "Вне боя нет живого бакугана с разрешёнными изменениями G."
			var source: Dictionary = _choice_unit(sources, int(options.get("source_owner", sources[0].owner)), int(options.get("source_index", sources[0].index)))
			if source.is_empty():
				return "Выбери исходного бакугана вне текущего боя."
			var target: Dictionary = _battle_unit(int(options.get("target_owner", owner)), int(options.get("target_index", caster.index)))
			if target.is_empty():
				return "Выбери участника боя, которому передать изменения."
	for key: String in options:
		if not allowed_options.has(key) or typeof(options[key]) != TYPE_INT:
			return "Недопустимый параметр эффекта ловушки."
	return ""


func deploy_trap(owner: int, caster_index: int = -1, target_index: int = -1, options: Dictionary = {}) -> Dictionary:
	var error: String = trap_error(owner, caster_index, target_index, options)
	if not error.is_empty():
		return _invalid(error)
	var support: Dictionary = support_slots[owner]
	var caster: Dictionary = _choose_trap_caster(owner, caster_index)
	var target: Dictionary = _battle_unit(1 - owner, target_index)
	support["used"] = true
	support["status"] = "pending"
	support["caster_index"] = int(caster.index)
	support["slot"] = int(battle.slot)
	support.stats["deployments"] = int(support.stats.deployments) + 1
	support.stats["turn_serial"] = turn_serial
	_serial += 1
	var card: Dictionary = {"id": str(support.id), "title": str(support.title),
		"effect": support.effect.duplicate(true), "type": "trap", "immediate": false}
	var node: Dictionary = {"serial": _serial, "owner": owner, "kind": "trap", "card": card,
		"cancelled": false, "resolved": false, "target_serial": -1,
		"caster_index": int(caster.index), "target_index": int(target.index), "target_owner": 1 - owner,
		"options": options.duplicate(true)}
	_fill_trap_options(node)
	if str(support.effect.type) == "copy_open_gate" and not node.options.has("source_slot"):
		node.options["source_slot"] = trap_choices(owner).source_slots[0]
	battle.chain.append(node)
	_last_card = {"serial": _serial, "immediate": false}
	_respond(owner)
	return _success("trap_played", {"owner": owner, "support_id": str(support.id),
		"title": str(support.title), "caster_index": int(caster.index), "totals": battle_totals()})


func pass_response(owner: int) -> Dictionary:
	if not _has_priority(owner):
		return _invalid("Сейчас отвечает другой игрок.")
	battle["passes"] = int(battle.passes) + 1
	battle["priority"] = 1 - owner
	if int(battle.passes) < 2:
		return _success("response_passed", {"owner": owner, "priority": int(battle.priority)})
	if not battle.chain.is_empty():
		_remaining_chain = battle.chain.duplicate()
		_chain_outcomes.clear()
		return _continue_chain()
	return _resolve_battle()


func battle_totals() -> Array[int]:
	return [int(battle_breakdown(0).total), int(battle_breakdown(1).total)]


func battle_breakdown(owner: int) -> Dictionary:
	var result: Dictionary = {"base": 0, "gate": 0, "ability": 0, "support": 0, "raw_ability": 0, "raw_gate": 0, "raw_support": 0, "total": 0}
	if not _valid_owner(owner) or phase != "battle" or battle.is_empty():
		return result
	for unit: Dictionary in battle_units(owner):
		var detail: Dictionary = battle_unit_breakdown(owner, int(unit.index))
		for key: String in ["base", "gate", "ability", "support", "raw_ability", "raw_gate", "raw_support", "total"]:
			result[key] = int(result[key]) + int(detail[key])
	return result


func battle_units(owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _valid_owner(owner) or battle.is_empty() or not gates.has(int(battle.slot)):
		return result
	for unit: Dictionary in gates[int(battle.slot)].bakugan:
		if int(unit.owner) == owner:
			result.append(unit)
	return result


func battle_unit_breakdown(owner: int, unit_index: int) -> Dictionary:
	var result: Dictionary = {"base": 0, "gate": 0, "ability": 0, "support": 0, "raw_ability": 0, "raw_gate": 0, "raw_support": 0, "total": 0}
	var unit: Dictionary = _battle_unit(owner, unit_index)
	if unit.is_empty():
		return result
	var gate: Dictionary = gates[int(battle.slot)]
	result["base"] = int(unit.base_g)
	var continuous_gate: int = 0
	if bool(gate.revealed) and not bool(gate.nullified):
		for attribute: String in _unit_attributes(unit):
			continuous_gate += int(gate.get("boosts", {}).get(attribute, 0))
		result["gate"] = continuous_gate
	result["gate"] = int(result.gate) + int(unit.get("gate_effect_g", 0))
	result["raw_gate"] = int(result.gate)
	result["raw_ability"] = int(unit.ability_g)
	result["ability"] = int(unit.ability_g)
	result["support"] = int(unit.get("support_g", 0)) + int(unit.get("permanent_support_g", 0))
	if continuous_gate > 0:
		if bool(unit.get("block_gains", false)):
			result["support"] = int(result.support) - continuous_gate
		elif bool(unit.get("double_gains", false)) or bool(unit.get("permanent_double_gains", false)):
			result["support"] = int(result.support) + continuous_gate
	result["raw_support"] = int(result.support)
	var below_zero: int = maxi(0, -int(result.base) - int(result.gate) - int(result.ability) - int(result.support))
	for component: String in ["ability", "gate", "support"]:
		var correction: int = mini(below_zero, maxi(0, -int(result[component])))
		result[component] = int(result[component]) + correction
		below_zero -= correction
	result["total"] = int(result.base) + int(result.gate) + int(result.ability) + int(result.support)
	result["name"] = str(unit.name)
	result["attribute"] = str(unit.attribute)
	return result


func ability_casters(owner: int, hand_index: int) -> Array[int]:
	var result: Array[int] = []
	if not _valid_owner(owner) or hand_index < 0 or hand_index >= ability_hands[owner].size():
		return result
	var card: Dictionary = ability_hands[owner][hand_index]
	for unit: Dictionary in battle_units(owner):
		if _compatible_ability(card, unit):
			result.append(int(unit.index))
	return result


func state_snapshot() -> Dictionary:
	# JSON-compatible public state is useful for invariant tests and debugging.
	return {
		"turn": turn, "phase": phase, "winner": winner, "teams": teams.duplicate(true),
		"gates": gates.duplicate(true), "gate_hands": gate_hands.duplicate(true),
		"ability_hands": ability_hands.duplicate(true), "gate_decks": gate_decks.duplicate(true),
		"ability_decks": ability_decks.duplicate(true), "spent_gates": spent_gates.duplicate(true),
		"spent_abilities": spent_abilities.duplicate(true), "defeated": defeated.duplicate(true),
		"battle": battle.duplicate(true), "placed_this_turn": placed_this_turn,
		"acted_this_turn": acted_this_turn, "turn_serial": turn_serial,
		"support_slots": support_slots.duplicate(true),
		"pending_trap_action": pending_trap_action(),
	}


func _apply_node(node: Dictionary) -> Dictionary:
	if str(node.get("kind", "ability")) == "trap":
		return _apply_trap_node(node)
	if bool(node.cancelled):
		node["resolved"] = true
		return {"event": "ability_cancelled", "owner": int(node.owner), "title": str(node.card.title)}
	var owner: int = int(node.owner)
	var caster_index: int = int(node.caster_index)
	var target_owner: int = int(node.target_owner)
	var target_index: int = int(node.target_index)
	var effect: Dictionary = node.card.effect
	var caster: Dictionary = _battle_unit(owner, caster_index)
	if caster.is_empty() or not _compatible_ability(node.card, caster):
		node["resolved"] = true
		return {"event": "ability_failed", "owner": owner, "title": str(node.card.title), "error": "Вид или стихия участника изменились до разрешения способности."}
	if str(effect.type) == "correlation" and target_owner == owner:
		var allied: Dictionary = _battle_unit(target_owner, target_index)
		if allied.is_empty() or not _correlation_valid(caster, allied, effect.pair):
			node["resolved"] = true
			return {"event": "ability_failed", "owner": owner, "title": str(node.card.title), "error": "Союзная цель больше не имеет второй стихии корреляции."}
	if node.has("reflection"):
		owner = int(node.reflection.owner)
		caster_index = int(node.reflection.caster_index)
		target_owner = int(node.reflection.target_owner)
		target_index = int(node.reflection.target_index)
		caster = _battle_unit(owner, caster_index)
		if caster.is_empty():
			node["resolved"] = true
			return {"event": "ability_failed", "owner": owner, "title": str(node.card.title), "error": "Участник, отражающий способность, больше не находится в бою."}
	var amount: int = int(effect.get("amount", 0))
	var result: Dictionary = {"event": "ability_resolved", "owner": owner, "title": str(node.card.title), "gain": 0, "loss": 0,
		"caster_index": caster_index, "target_owner": target_owner, "target_index": target_index}
	match str(effect.type):
		"counter":
			for pending: Dictionary in battle.chain:
				if int(pending.serial) == int(node.target_serial) and not bool(pending.resolved):
					pending["cancelled"] = true
					result["countered"] = str(pending.card.title)
		"nullify":
			gates[int(battle.slot)]["nullified"] = true
			result["gate_nullified"] = true
		"transfer":
			var transferred: int = mini(amount, int(battle_unit_breakdown(target_owner, target_index).total))
			_alter_power(target_owner, -transferred, target_index)
			_alter_power(owner, transferred, caster_index)
			result["gain"] = transferred
			result["loss"] = transferred
		"correlation":
			var target: Dictionary = _battle_unit(target_owner, target_index)
			if target_owner == owner and _correlation_valid(caster, target, effect.pair):
				amount = int(effect.get("allied_amount", 100))
				_alter_power(owner, amount, target_index)
			elif _correlation_valid(caster, target, effect.pair):
				amount = int(effect.get("opposing_amount", 150))
			_alter_power(owner, amount, caster_index)
			result["gain"] = amount
		"gain":
			if effect.has("opposing_amount") and int(gates[int(battle.slot)].owner) != owner:
				amount = int(effect.opposing_amount)
			_alter_power(owner, amount, caster_index)
			result["gain"] = amount
		"enemy_loss":
			result["loss"] = -_alter_power(target_owner, -amount, target_index)
	node["resolved"] = true
	_sync_battle_power()
	return result


func _apply_trap_node(node: Dictionary) -> Dictionary:
	var owner: int = int(node.owner)
	var support: Dictionary = support_slots[owner]
	var caster: Dictionary = _battle_unit(owner, int(node.caster_index))
	node["resolved"] = true
	var result: Dictionary = {"owner": owner, "support_id": str(support.id), "title": str(node.card.title),
		"caster_index": int(node.caster_index), "target_index": int(node.target_index)}
	if bool(node.cancelled):
		support["status"] = "spent"
		support.stats["countered"] = int(support.stats.countered) + 1
		result["event"] = "trap_cancelled"
		return result
	if caster.is_empty() or (not bool(node.get("field_trigger", false)) and not TrapCatalog.compatible_caster(support, caster)):
		support["status"] = "spent"
		support.stats["failed"] = int(support.stats.failed) + 1
		result.merge({"event": "trap_failed", "error": "Стихия участника изменилась до разрешения помощи."})
		return result
	if str(node.card.effect.type) == "copy_open_gate":
		var source_slot: int = int(node.options.source_slot)
		if not gates.has(source_slot) or not bool(gates[source_slot].revealed) or bool(gates[source_slot].nullified):
			support["status"] = "spent"
			support.stats["failed"] = int(support.stats.failed) + 1
			result.merge({"event": "trap_failed", "error": "Выбранные исходные ворота больше не действуют."})
			return result
	match str(node.card.effect.type):
		"opposite_attributes":
			var opposites: Dictionary = {"Pyrus": "Aquos", "Aquos": "Pyrus", "Haos": "Darkus", "Darkus": "Haos", "Ventus": "Subterra", "Subterra": "Ventus"}
			for side in range(2):
				for unit: Dictionary in battle_units(side):
					var converted: Array[String] = []
					for attribute: String in _unit_attributes(unit):
						converted.append(str(opposites[attribute]))
					unit["attribute"] = converted[0]
					unit["additional_attributes"] = converted.slice(1)
			result["opposite_attributes"] = true
		"forced_swap":
			for side in range(2):
				_queue_trap_action(side, "swap", str(support.id))
			result["forced_actions"] = _trap_actions.duplicate(true)
		"extra_roll_return":
			_queue_trap_action(owner, "roll", str(support.id))
			result["forced_actions"] = _trap_actions.duplicate(true)
		"drill_move":
			var amount: int = int(node.card.effect.amount) * (1 + int(support.get("moves", 0)))
			var losses: Array[Dictionary] = []
			for unit: Dictionary in battle_units(1 - owner):
				losses.append({"index": int(unit.index), "loss": -_alter_power(1 - owner, -amount, int(unit.index), "support")})
			var destination: int = int(node.options.get("destination_slot", -1))
			if gates.has(destination) and Board.is_adjacent(int(battle.slot), destination):
				support["slot"] = destination
				support["moves"] = int(support.get("moves", 0)) + 1
			result.merge({"losses": losses, "destination_slot": int(support.slot), "moves": int(support.get("moves", 0))})
		"transfer_resolved_changes":
			var source_owner: int = int(node.options.source_owner)
			var source_index: int = int(node.options.source_index)
			var target_owner: int = int(node.options.target_owner)
			var target_index: int = int(node.options.target_index)
			var source: Dictionary = teams[source_owner][source_index]
			var target: Dictionary = _battle_unit(target_owner, target_index)
			if str(source.status) == "defeated" or int(source.slot) == int(battle.slot) or target.is_empty():
				support["status"] = "spent"
				support.stats["failed"] = int(support.stats.failed) + 1
				result.merge({"event": "trap_failed", "error": "Исходный бакуган или цель передачи больше недоступны."})
				return result
			var changed: int = int(source.current_g) - int(source.base_g)
			source["permanent_support_g"] = int(source.get("permanent_support_g", 0)) - changed
			source["current_g"] = int(source.base_g)
			result["transferred_change"] = _alter_power(target_owner, changed, target_index, "support")
		"activation_drain":
			support["drained_g"] = 0
			support["target_index"] = int(node.target_index)
			result["drain_per_activation"] = int(node.card.effect.amount)
		"reflect_first":
			support["reflection_used"] = false
			result["reflection_ready"] = true
		"additional_attributes":
			for unit: Dictionary in battle_units(owner):
				if _has_attribute(unit, str(node.card.effect.from)):
					unit["additional_attributes"] = node.card.effect.attributes.duplicate()
			result["additional_attributes"] = node.card.effect.attributes.duplicate()
		"defeated_copy":
			var original: Dictionary = teams[owner][int(node.options.unit_index)]
			if str(original.status) != "defeated":
				support["status"] = "spent"
				support.stats["failed"] = int(support.stats.failed) + 1
				result.merge({"event": "trap_failed", "error": "Бакуган для копии больше не побеждён."})
				return result
			_clone_serial += 1
			var clone: Dictionary = original.duplicate(true)
			clone.merge({"id": "trap_clone_%d_%d" % [owner, _clone_serial], "index": 1000 + _clone_serial,
				"unit": 1000 + _clone_serial, "name": str(original.name) + " (копия)", "model_name": str(original.get("model_name", original.name)), "species": str(original.get("species", original.get("model_name", original.name))), "temporary_clone": true,
				"attribute": "Darkus", "original_attribute": "Darkus", "additional_attributes": ["Ventus"],
				"base_g": 100, "g": 100, "current_g": 100, "canonical_g": null, "g_verified": false,
				"g_note": "100 G — временная копия по эффекту Theta Ripple", "g_source_confidence": "printed_effect",
				"canonical_source_url": str(support.source_effect.source_url), "status": "field", "slot": int(battle.slot),
				"ability_g": 0, "gate_effect_g": 0, "support_g": 0, "permanent_support_g": 0,
				"double_gains": false, "double_losses": false, "block_gains": false, "permanent_double_gains": false}, true)
			gates[int(battle.slot)].bakugan.append(clone)
			result["clone_index"] = int(clone.index)
		"owner_highest":
			var changed: Array[Dictionary] = []
			for side in range(2):
				var highest: int = 0
				for unit: Dictionary in teams[side]:
					if str(unit.status) != "defeated":
						highest = maxi(highest, int(unit.current_g))
				for unit: Dictionary in battle_units(side):
					highest = maxi(highest, int(battle_unit_breakdown(side, int(unit.index)).total))
				for unit: Dictionary in battle_units(side):
					var previous: int = int(battle_unit_breakdown(side, int(unit.index)).total)
					_alter_power(side, highest - previous, int(unit.index), "support")
					changed.append({"owner": side, "index": int(unit.index), "before": previous, "after": highest})
			result["changed"] = changed
		"permanent_gain":
			var changed: Array[Dictionary] = []
			for unit: Dictionary in battle_units(owner):
				var species: String = str(unit.name).replace(" ", "").to_lower()
				var amount: int = int(node.card.effect.special_amount) if species == str(node.card.effect.species).to_lower() else int(node.card.effect.amount)
				var applied: int = _alter_power(owner, amount, int(unit.index), "support")
				unit["support_g"] = int(unit.support_g) - applied
				unit["permanent_support_g"] = int(unit.get("permanent_support_g", 0)) + applied
				changed.append({"owner": owner, "index": int(unit.index), "gain": applied, "permanent": true})
			result["changed"] = changed
		"double_losses":
			for unit: Dictionary in battle_units(1 - owner):
				unit["double_losses"] = true
			result["loss_multiplier"] = 2
		"double_gains":
			for unit: Dictionary in battle_units(owner):
				unit["double_gains"] = true
				if str(unit.name).replace(" ", "").to_lower() == str(node.card.effect.permanent_species).to_lower():
					unit["permanent_double_gains"] = true
			result["gain_multiplier"] = 2
		"block_gains":
			for side in range(2):
				for unit: Dictionary in battle_units(side):
					unit["block_gains"] = true
			result["gains_blocked"] = true
		"permanent_battle_changes":
			battle["permanent_changes"] = true
			result["changes_permanent"] = true
		"copy_open_gate":
			result["copied_gate"] = str(gates[int(node.options.source_slot)].title)
			result["gate_outcome"] = _copy_gate_effect(gates[int(node.options.source_slot)], owner, int(node.caster_index), int(node.target_index))
		"coin_repeat_gate":
			var tails: int = 0
			var heads: int = 0
			while tails < 2:
				if _random.randi_range(0, 1) == 1:
					heads += 1
				else:
					tails += 1
			result.merge({"heads": heads, "tails": tails})
			var copied: Dictionary = gates[int(battle.slot)].duplicate(true)
			var applications: Array[Dictionary] = []
			for repetition in range(heads):
				applications.append(_copy_gate_effect(copied, owner, int(node.caster_index), int(node.target_index)))
				if phase != "battle":
					break
			result["applications"] = applications
	support["status"] = "deployed" if phase == "battle" else "spent"
	support.stats["successful"] = int(support.stats.successful) + 1
	result["event"] = "trap_resolved"
	_sync_battle_power()
	return result


func _copy_gate_effect(source: Dictionary, owner: int, caster_index: int, target_index: int) -> Dictionary:
	var effect: Dictionary = source.get("effect", {})
	var result: Dictionary = {"type": str(effect.get("type", "attribute_gain")), "source_id": str(source.id)}
	var slot: int = int(battle.slot)
	match str(effect.get("type", "attribute_gain")):
		"attribute_gain":
			var changes: Array[Dictionary] = []
			for side in range(2):
				for unit: Dictionary in battle_units(side):
					var amount: int = 0
					for attribute: String in _unit_attributes(unit):
						amount += int(source.get("boosts", {}).get(attribute, 0))
					changes.append({"owner": side, "index": int(unit.index), "gain": _alter_power(side, amount, int(unit.index), "support_gate")})
			result["changes"] = changes
		"energy_merge":
			var first: Dictionary = gates[slot].bakugan[0]
			var last: Dictionary = gates[slot].bakugan[-1]
			var amount: int = mini(int(effect.get("amount", 125)), int(battle_unit_breakdown(int(last.owner), int(last.index)).total))
			_alter_power(int(last.owner), -amount, int(last.index), "support_gate")
			result["transferred"] = _alter_power(int(first.owner), amount, int(first.index), "support_gate")
		"hazard":
			for unit: Dictionary in gates[slot].bakugan:
				unit["attribute"] = str(effect.attribute)
				unit.erase("additional_attributes")
			result["attribute"] = str(effect.attribute)
		"delta":
			var opposing: Dictionary = _battle_unit(1 - owner, target_index)
			var caster: Dictionary = _battle_unit(owner, caster_index)
			var targeted: Dictionary = opposing if effect.get("pair", []).has(str(opposing.attribute)) else caster
			result["loss"] = -_alter_power(int(targeted.owner), -int(effect.get("amount", 200)), int(targeted.index), "support_gate")
		"peacemaker":
			_finish_support_battle()
			for unit: Dictionary in gates[slot].bakugan:
				_return_unit(unit)
			gates[slot].bakugan.clear()
			battle = {}
			_last_card = {}
			phase = "turn"
			result["returned_both"] = true
	_sync_battle_power()
	return result


func _activate_gate(slot: int, caster_index: int = -1, target_index: int = -1) -> Dictionary:
	# Command changes are resolved actions. Later nullification blocks further
	# gate actions/bonuses but does not undo an already resolved transfer/change.
	var gate: Dictionary = gates[slot]
	if bool(gate.nullified) or bool(gate.get("effect_applied", false)):
		return {}
	gate["effect_applied"] = true
	var effect: Dictionary = gate.get("effect", {})
	var result: Dictionary = {"type": str(effect.get("type", "attribute_gain")), "slot": slot}
	match str(effect.get("type", "attribute_gain")):
		"energy_merge":
			var first_unit: Dictionary = gate.bakugan[0]
			var last_unit: Dictionary = gate.bakugan[-1]
			var first: int = int(first_unit.owner)
			var last: int = int(last_unit.owner)
			var amount: int = mini(int(effect.get("amount", 125)), int(battle_unit_breakdown(last, int(last_unit.index)).total))
			_alter_power(last, -amount, int(last_unit.index), "gate")
			_alter_power(first, amount, int(first_unit.index), "gate")
			result.merge({"first_owner": first, "last_owner": last, "transferred": amount})
		"hazard":
			var attribute: String = str(effect.get("attribute", ""))
			for unit: Dictionary in gate.bakugan:
				unit["attribute"] = attribute
				unit.erase("additional_attributes")
			result["attribute"] = attribute
		"delta":
			var owner: int = int(gate.owner)
			var opposing: Dictionary = _battle_unit(1 - owner, target_index)
			var caster: Dictionary = _battle_unit(owner, caster_index)
			var targeted: Dictionary = opposing if effect.get("pair", []).has(str(opposing.attribute)) else caster
			var applied: int = -_alter_power(int(targeted.owner), -int(effect.get("amount", 200)), int(targeted.index), "gate")
			result.merge({"target_owner": int(targeted.owner), "target_index": int(targeted.index), "loss": applied})
		"peacemaker":
			_finish_support_battle()
			for unit: Dictionary in gate.bakugan:
				_return_unit(unit)
			gate.bakugan.clear()
			battle = {}
			_last_card = {}
			phase = "turn"
			result["returned_both"] = true
	_sync_battle_power()
	return result


func _alter_power(owner: int, amount: int, unit_index: int = -1, origin: String = "ability") -> int:
	var unit: Dictionary = _battle_unit(owner, unit_index)
	if unit.is_empty():
		return 0
	var card_change: bool = origin in ["ability", "gate", "support_gate"]
	if card_change and amount > 0 and bool(unit.get("block_gains", false)):
		return 0
	var total: int = int(battle_unit_breakdown(owner, int(unit.index)).total)
	var nominal: int = amount if amount >= 0 else maxi(amount, -total)
	var amplified: int = amount
	if card_change and amount > 0 and (bool(unit.get("double_gains", false)) or bool(unit.get("permanent_double_gains", false))):
		amplified *= 2
	elif card_change and amount < 0 and bool(unit.get("double_losses", false)):
		amplified *= 2
	var applied: int = amplified if amplified >= 0 else maxi(amplified, -total)
	var field: String = "ability_g"
	if origin == "gate":
		field = "gate_effect_g"
	elif origin in ["support", "support_gate"]:
		field = "support_g"
	unit[field] = int(unit.get(field, 0)) + nominal
	unit["support_g"] = int(unit.get("support_g", 0)) + applied - nominal
	unit["current_g"] = int(battle_unit_breakdown(owner, int(unit.index)).total)
	return applied


func _sync_battle_power() -> void:
	if phase != "battle":
		return
	for owner in range(2):
		for unit: Dictionary in battle_units(owner):
			unit["current_g"] = int(battle_unit_breakdown(owner, int(unit.index)).total)


func _finish_support_battle() -> void:
	if bool(battle.get("permanent_changes", false)):
		for side in range(2):
			for unit: Dictionary in battle_units(side):
				var permanent: int = int(unit.get("permanent_support_g", 0))
				unit["permanent_support_g"] = permanent + int(battle_unit_breakdown(side, int(unit.index)).total) - int(unit.base_g) - permanent
	_trap_actions.clear()
	for support: Dictionary in support_slots:
		if not support.is_empty() and str(support.get("effect", {}).get("type", "")) == "activation_drain" and int(support.get("drained_g", 0)) > 0:
			for unit: Dictionary in teams[1 - int(support.owner)]:
				if str(unit.status) == "field" and int(unit.slot) != int(battle.slot):
					unit["permanent_support_g"] = int(unit.get("permanent_support_g", 0)) + int(support.drained_g)
					unit["current_g"] = maxi(0, int(unit.base_g) + int(unit.permanent_support_g))
					support["drained_g"] = 0
					break
			support["drained_g"] = 0
		if support.is_empty() or not str(support.status) in ["pending", "deployed"]:
			continue
		if str(support.status) == "pending":
			support.stats["cancelled_battle"] = int(support.stats.cancelled_battle) + 1
		if str(support.effect.type) == "drill_move" and int(support.slot) != int(battle.slot) and gates.has(int(support.slot)):
			support["status"] = "field"
		else:
			support["status"] = "spent"
			support["slot"] = -1


func _resolve_battle() -> Dictionary:
	var slot: int = int(battle.slot)
	var totals: Array[int] = battle_totals()
	var gate: Dictionary = gates[slot]
	# A local tie returns both teams alive; no arbitrary unit is eliminated.
	var victor: int = -1
	if totals[0] > totals[1]:
		victor = 0
	elif totals[1] > totals[0]:
		victor = 1
	var loser: int = 1 - victor if victor >= 0 else -1
	var losing_indices: Array[int] = []
	_finish_support_battle()
	for unit: Dictionary in gate.bakugan:
		if bool(unit.get("temporary_clone", false)):
			unit["status"] = "removed"
			unit["slot"] = -1
			continue
		if int(unit.owner) == loser:
			unit["status"] = "defeated"
			unit["slot"] = -1
			unit["current_g"] = 0
			unit["ability_g"] = 0
			unit["gate_effect_g"] = 0
			unit["support_g"] = 0
			unit["attribute"] = str(unit.original_attribute)
			losing_indices.append(int(unit.index))
			defeated[loser].append(int(unit.index))
		else:
			_return_unit(unit)
	var spent: Dictionary = gate.duplicate(true)
	spent.erase("bakugan")
	spent.erase("occupants")
	spent_gates[int(gate.owner)].append(spent)
	gates.erase(slot)
	battle = {}
	_last_card = {}
	phase = "turn"
	if loser >= 0 and defeated[loser].size() == teams[loser].size():
		winner = victor
		phase = "finished"
	return _success("battle_end", {
		"slot": slot, "victor": victor, "owner": victor, "defeated_owner": loser,
		"defeated_index": losing_indices[0] if not losing_indices.is_empty() else -1,
		"defeated_indices": losing_indices, "totals": totals, "winner": winner, "tie": victor == -1,
	})


func _counter_target() -> Dictionary:
	if phase != "battle" or _last_card.is_empty() or bool(_last_card.get("immediate", false)):
		return {}
	for index in range(battle.chain.size() - 1, -1, -1):
		var pending: Dictionary = battle.chain[index]
		if int(pending.serial) == int(_last_card.serial) and not bool(pending.cancelled) and not bool(pending.resolved):
			return pending
	return {}


func _battle_unit(owner: int, unit_index: int = -1) -> Dictionary:
	if not _valid_owner(owner) or battle.is_empty() or not gates.has(int(battle.slot)):
		return {}
	for unit: Dictionary in gates[int(battle.slot)].bakugan:
		if int(unit.owner) == owner and (unit_index == -1 or int(unit.index) == unit_index):
			return unit
	return {}


func _choose_caster(owner: int, card: Dictionary, requested_index: int) -> Dictionary:
	if requested_index >= 0:
		return _battle_unit(owner, requested_index)
	for unit: Dictionary in battle_units(owner):
		if _compatible_ability(card, unit):
			return unit
	return {}


func _choose_trap_caster(owner: int, requested_index: int) -> Dictionary:
	if requested_index >= 0:
		return _battle_unit(owner, requested_index)
	for unit: Dictionary in battle_units(owner):
		if TrapCatalog.compatible_caster(support_slots[owner], unit):
			return unit
	return {}


func _choose_target(owner: int, card: Dictionary, caster: Dictionary, requested_index: int, requested_owner: int) -> Dictionary:
	var target_owner: int = 1 - owner if requested_owner == -1 else requested_owner
	var effect: Dictionary = card.effect
	if str(effect.type) not in ["correlation", "transfer", "enemy_loss"]:
		return _battle_unit(1 - owner)
	if requested_index >= 0:
		return _battle_unit(target_owner, requested_index)
	if str(effect.type) == "correlation":
		for candidate: Dictionary in battle_units(1 - owner):
			if _correlation_valid(caster, candidate, effect.pair):
				return candidate
		for candidate: Dictionary in battle_units(owner):
			if int(candidate.index) != int(caster.index) and _correlation_valid(caster, candidate, effect.pair):
				return candidate
	return _battle_unit(1 - owner)


func _respond(owner: int) -> void:
	battle["passes"] = 0
	battle["priority"] = 1 - owner


func _has_priority(owner: int) -> bool:
	return winner == -1 and _valid_owner(owner) and phase == "battle" and not battle.is_empty() and int(battle.priority) == owner and _trap_actions.is_empty()


func _owns_action(owner: int) -> bool:
	return winner == -1 and _valid_owner(owner) and turn == owner


func _valid_owner(owner: int) -> bool:
	return owner == 0 or owner == 1


func _return_unit(unit: Dictionary) -> void:
	if bool(unit.get("temporary_clone", false)):
		unit["status"] = "removed"
		unit["slot"] = -1
		return
	unit["status"] = "reserve"
	unit["slot"] = -1
	unit["ability_g"] = 0
	unit["gate_effect_g"] = 0
	unit["support_g"] = 0
	unit["double_gains"] = false
	unit["double_losses"] = false
	unit["block_gains"] = false
	unit["current_g"] = maxi(0, int(unit.base_g) + int(unit.get("permanent_support_g", 0)))
	unit["attribute"] = str(unit.get("original_attribute", unit.attribute))
	unit.erase("additional_attributes")


func _begin_opening(start_owner: int) -> void:
	phase = "opening"
	_opening_start = start_owner
	_opening_queue = [start_owner, 1 - start_owner]
	turn = start_owner
	placed_this_turn = false
	acted_this_turn = false
	for owner in range(2):
		if gate_hands[owner].is_empty():
			if gate_decks[owner].is_empty() and not spent_gates[owner].is_empty():
				gate_decks[owner] = spent_gates[owner].duplicate(true)
				spent_gates[owner].clear()
				_shuffle(gate_decks[owner])
			_draw(owner, 1, 0)


func _start_turn(draw_cards: bool) -> void:
	phase = "turn"
	placed_this_turn = false
	acted_this_turn = false
	if draw_cards and _own_turns[turn] > 0:
		_draw(turn, 1, 1)
	_own_turns[turn] += 1


func _draw(owner: int, gate_count: int, ability_count: int) -> void:
	for ignored in range(gate_count):
		if not gate_decks[owner].is_empty():
			gate_hands[owner].append(gate_decks[owner].pop_front())
	for ignored in range(ability_count):
		if not ability_decks[owner].is_empty():
			ability_hands[owner].append(ability_decks[owner].pop_front())


func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other: int = _random.randi_range(0, index)
		var value: Variant = values[index]
		values[index] = values[other]
		values[other] = value


func _normalize_team(input: Array, owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if input.size() != 3:
		return result
	var identities: Array[String] = []
	for index in range(input.size()):
		if not input[index] is Dictionary:
			return []
		var source: Dictionary = input[index]
		if str(source.get("category", "")) in ["trap", "support"]:
			return []
		var identity: String = str(source.get("id", ""))
		var species: String = str(source.get("name", ""))
		var attribute: String = str(source.get("attribute", ""))
		var raw_g: Variant = source.get("g", 0)
		var valid_g: bool = typeof(raw_g) == TYPE_INT or (typeof(raw_g) == TYPE_FLOAT and is_finite(raw_g) and raw_g == floor(raw_g))
		if identity.is_empty() or identities.has(identity) or species.is_empty() or not ATTRIBUTES.has(attribute) or not valid_g:
			return []
		var power: int = int(raw_g)
		if power <= 0 or power > 10000:
			return []
		identities.append(identity)
		var unit: Dictionary = source.duplicate(true)
		unit.merge({"owner": owner, "index": index, "unit": index, "status": "reserve", "slot": -1,
			"base_g": power, "current_g": power, "ability_g": 0, "gate_effect_g": 0, "support_g": 0,
			"permanent_support_g": 0, "double_gains": false, "double_losses": false, "block_gains": false,
			"permanent_double_gains": false, "original_attribute": attribute}, true)
		result.append(unit)
	return result


func _invalid(message: String) -> Dictionary:
	return {"ok": false, "event": "invalid", "error": message}


func _success(event: String, values: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "event": event}
	result.merge(values)
	history.append(result.duplicate(true))
	return result


func _continue_chain() -> Dictionary:
	while not _remaining_chain.is_empty() and phase == "battle":
		var node: Dictionary = _remaining_chain.pop_back()
		_chain_outcomes.append(_apply_node(node))
		if not _trap_actions.is_empty():
			return _success("trap_action_required", {"outcomes": _chain_outcomes.duplicate(true), "action": pending_trap_action(), "totals": battle_totals()})
	var outcomes: Array[Dictionary] = _chain_outcomes.duplicate(true)
	_remaining_chain.clear()
	_chain_outcomes.clear()
	if phase != "battle":
		return _success("battle_cancelled", {"outcomes": outcomes, "winner": winner})
	battle.chain.clear()
	battle["passes"] = 0
	battle["priority"] = int(gates[int(battle.slot)].owner)
	_last_card = {}
	return _success("chain_resolved", {"outcomes": outcomes, "totals": battle_totals(), "priority": int(battle.priority)})


func _choice_unit(values: Array, owner: int, index: int) -> Dictionary:
	for value: Dictionary in values:
		if int(value.owner) == owner and int(value.index) == index:
			return value
	return {}


func _fill_trap_options(node: Dictionary) -> void:
	var owner: int = int(node.owner)
	var choices: Dictionary = trap_choices(owner)
	match str(node.card.effect.type):
		"drill_move":
			var slots: Array = choices.get("destination_slots", [])
			node.options["destination_slot"] = int(node.options.get("destination_slot", slots[0] if not slots.is_empty() else -1))
		"defeated_copy":
			node.options["unit_index"] = int(node.options.get("unit_index", choices.defeated_indices[0]))
		"transfer_resolved_changes":
			var first: Dictionary = choices.history_sources[0]
			node.options["source_owner"] = int(node.options.get("source_owner", first.owner))
			node.options["source_index"] = int(node.options.get("source_index", first.index))
			node.options["target_owner"] = int(node.options.get("target_owner", owner))
			node.options["target_index"] = int(node.options.get("target_index", node.caster_index))


func _unit_attributes(unit: Dictionary) -> Array[String]:
	var attributes: Array[String] = [str(unit.get("attribute", ""))]
	for attribute: String in unit.get("additional_attributes", []):
		if ATTRIBUTES.has(attribute) and not attributes.has(attribute):
			attributes.append(attribute)
	return attributes


func _has_attribute(unit: Dictionary, attribute: String) -> bool:
	return _unit_attributes(unit).has(attribute)


func _compatible_ability(card: Dictionary, unit: Dictionary) -> bool:
	for attribute: String in _unit_attributes(unit):
		var form: Dictionary = unit.duplicate()
		form["attribute"] = attribute
		if Catalog.compatible_caster(card, form):
			return true
	return false


func _correlation_valid(caster: Dictionary, target: Dictionary, pair: Array) -> bool:
	for first: String in _unit_attributes(caster):
		for second: String in _unit_attributes(target):
			if first != second and pair.has(first) and pair.has(second):
				return true
	return false


func _correlation_caster(caster: Dictionary, pair: Array) -> bool:
	for attribute: String in _unit_attributes(caster):
		if pair.has(attribute):
			return true
	return false


func _queue_trap_action(owner: int, type: String, support_id: String) -> void:
	var reserve: Array[int] = available_units(owner)
	if reserve.is_empty():
		return
	var action: Dictionary = {"type": type, "owner": owner, "support_id": support_id,
		"available_indices": reserve, "trap_slot": int(battle.slot)}
	if type == "swap":
		var outgoing: Array[int] = []
		for unit: Dictionary in battle_units(owner):
			if not bool(unit.get("temporary_clone", false)):
				outgoing.append(int(unit.index))
		if outgoing.is_empty():
			return
		action["outgoing_indices"] = outgoing
	else:
		var slots: Array[int] = []
		for slot: int in gates:
			var allowed: bool = slot == int(battle.slot)
			if not allowed:
				allowed = true
				for occupant: Dictionary in gates[slot].bakugan:
					if int(occupant.owner) != owner:
						allowed = false
			if allowed:
				slots.append(slot)
		slots.sort()
		action["slots"] = slots
	_trap_actions.append(action)


func _trigger_field_traps() -> void:
	for support: Dictionary in support_slots:
		if support.is_empty() or str(support.status) != "field" or int(support.slot) != int(battle.slot):
			continue
		var owner: int = int(support.owner)
		var caster: Dictionary = _battle_unit(owner)
		if caster.is_empty():
			continue
		_serial += 1
		var node: Dictionary = {"serial": _serial, "owner": owner, "kind": "trap", "field_trigger": true,
			"card": {"id": str(support.id), "title": str(support.title), "effect": support.effect.duplicate(true), "type": "trap"},
			"cancelled": false, "resolved": false, "caster_index": int(caster.index), "target_index": int(_battle_unit(1 - owner).index),
			"target_owner": 1 - owner, "options": {}}
		support["status"] = "pending"
		_fill_trap_options(node)
		battle.chain.append(node)


func _activated_ability_supports(node: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for support: Dictionary in support_slots:
		if support.is_empty() or str(support.status) != "deployed" or int(support.slot) != int(battle.slot):
			continue
		var owner: int = int(support.owner)
		match str(support.effect.type):
			"activation_drain":
				var target: Dictionary = _battle_unit(1 - owner, int(support.get("target_index", -1)))
				if target.is_empty():
					target = _battle_unit(1 - owner)
				if not target.is_empty():
					var drained: int = -_alter_power(1 - owner, -int(support.effect.amount), int(target.index), "support")
					support["drained_g"] = int(support.get("drained_g", 0)) + drained
					events.append({"event": "trap_activation_drain", "owner": owner, "index": int(target.index), "loss": drained})
			"reflect_first":
				if bool(support.get("reflection_used", false)):
					continue
				var type: String = str(node.card.effect.type)
				var targets_owner: int = int(node.target_owner) if type in ["transfer", "enemy_loss", "correlation"] else int(node.owner)
				if targets_owner != owner or type not in ["gain", "transfer", "enemy_loss", "correlation"]:
					continue
				support["reflection_used"] = true
				# A reflection retargets the complete card onto its original caster;
				# its original activation restrictions remain the ones validated.
				if int(node.owner) != owner:
					node["reflection"] = {"owner": owner, "caster_index": int(node.target_index),
						"target_owner": int(node.owner), "target_index": int(node.caster_index)}
				events.append({"event": "trap_reflected", "owner": owner, "title": str(node.card.title)})
	return events
