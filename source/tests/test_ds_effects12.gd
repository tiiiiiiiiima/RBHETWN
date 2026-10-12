extends SceneTree
## Native DS cards tested through their live engine and AI integrations.

const Rules = preload("res://scripts/match_rules.gd")
const Catalog = preload("res://scripts/ds_playable_catalog.gd")
const Effects = preload("res://scripts/battle_effects.gd")
const Tactics = preload("res://scripts/tactical_ai.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_native_decks_and_crossed_setup()
	_hidden_character_and_plain_gates()
	_printed_power_gate_effects()
	_gate_ability_block_restore_and_multiplier()
	_counter_gate_effects()
	_ability_conditions_and_consumption()
	_power_swaps_and_projection()
	if failures == 0:
		print("PASS: %d DS 0.12 native effect integration checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d DS native effect checks" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _card(id: int, owner: int = 0) -> Dictionary:
	var card: Dictionary = Catalog.metadata(id)
	card["owner"] = owner
	card["id"] = "p%d_%s" % [owner, card.get("key", "missing")]
	if str(card.get("kind", "")) == "gate":
		card["bakugan"] = []
		card["revealed"] = false
	return card


func _setup(gate_id: int, own_attribute: String = "Pyrus", other_attribute: String = "Darkus", own_name: String = "Dragonoid", own_g: int = 300, other_g: int = 500):
	var rules = Rules.new("ds")
	rules.teams[0][0].merge({"name": own_name, "attribute": own_attribute, "g": own_g}, true)
	rules.teams[1][0].merge({"name": "Hydranoid", "attribute": other_attribute, "g": other_g}, true)
	rules.hands = [[_card(gate_id)], [_card(201, 1)]]
	_check(rules.place_gate(0, 0, 5, true) and rules.place_gate(1, 0, 10, true), "Native gates use crossed legal opening positions")
	return rules


func _oppose(rules, own_roll: int = 0, other_roll: int = 0) -> void:
	_check(rules.land(0, 0, 5, own_roll).get("event") == "stand" and rules.finish_turn(), "Native gate first stand completes one turn")
	_check(rules.land(1, 0, 5, other_roll).get("event") == "battle", "Native gate reveal starts an opposed battle")


func _unit(rules, owner: int) -> Dictionary:
	for unit: Dictionary in rules.gates[5]["bakugan"]:
		if int(unit["owner"]) == owner:
			return unit
	return {}


func _context(rules, effects, owner: int, mini0: int = 0, mini1: int = 0) -> Dictionary:
	var context: Dictionary = rules.battle_context(5, owner)
	context["current_powers"] = [rules.get_standing_power(5, 0) + effects.extra(0, mini0), rules.get_standing_power(5, 1) + effects.extra(1, mini1)]
	return context


func _play(rules, effects, owner: int, id: int) -> bool:
	var card: Dictionary = _card(id, owner)
	rules.abilities[owner] = [card]
	var context: Dictionary = _context(rules, effects, owner)
	var projected = effects.copy()
	if not projected.apply(owner, card, _unit(rules, owner), _unit(rules, 1 - owner), "timing", true, context):
		return false
	if rules.use_ability(owner, 0, 5, "timing", true, context).is_empty():
		return false
	effects.states = projected.states.duplicate(true)
	effects.played_ids = projected.played_ids.duplicate(true)
	effects.counts = projected.counts.duplicate()
	effects.used = projected.used.duplicate()
	return true


func _native_decks_and_crossed_setup() -> void:
	var rules = Rules.new("ds")
	_check(rules.hands[0].size() == 3 and rules.abilities[0].size() == 3 and str(rules.hands[0][0]["rules_profile"]) == "ds", "Engine DS defaults contain native cards instead of Wii statistics")
	_check(rules.legal_gate_slots(true, 0) == [5, 6] and rules.legal_gate_slots(true, 1) == [9, 10], "DS opening puts each player's gate toward their opponent")
	var before: Array = rules.hands.duplicate(true)
	_check(not rules.place_gate(0, 0, 9, true) and not rules.place_gate(1, 0, 6, true) and rules.hands == before, "Wrong-side crossed opening rejection never consumes a card")
	_check(Tactics.choose_gate_slot(rules, 0, true) in [5, 6] and Tactics.choose_gate_slot(rules, 1, true) in [9, 10], "AI opening uses its same source-backed crossed side")
	var wii = Rules.new()
	_check(wii.legal_gate_slots(true, 0) == [5, 6, 9, 10] and str(wii.hands[0][0].get("rules_profile", "")) != "ds", "Crossed-side policy and DS numbers do not leak into Wii")


func _hidden_character_and_plain_gates() -> void:
	var dragon = _setup(101)
	dragon.land(0, 0, 5, 25)
	_check(dragon.gate_unit_bonus(5, _unit(dragon, 0)) == 0 and dragon.get_standing_power(5, 0) == 325, "Hidden DS character card does not reveal its bonus during a lone stand")
	dragon.finish_turn()
	dragon.land(1, 0, 5, 15)
	_check(dragon.gate_unit_bonus(5, _unit(dragon, 0)) == 300 and dragon.gate_unit_bonus(5, _unit(dragon, 1)) == 50, "DS Dragonoid native Pyrus 150 doubles only its matching character")
	var result: Dictionary = dragon.resolve_battle(5, 0, 0)
	_check(result.get("player_g") == 625 and result.get("enemy_g") == 565, "Native character gate retains each own roll bonus and applies original DS numbers")
	var plain = _setup(201)
	_oppose(plain)
	_check(plain.get_standing_power(5, 0) == 440 and plain.get_standing_power(5, 1) == 520, "DS Fire Pit native 140/20 gate boosts differ correctly from old console defaults")


func _printed_power_gate_effects() -> void:
	var lowest = _setup(315)
	_oppose(lowest, 45, 15)
	_check(lowest.effective_printed_power(5, _unit(lowest, 0)) == 600 and lowest.effective_printed_power(5, _unit(lowest, 1)) == 500, "Molten Rock doubles only the uniquely lower printed G")
	_check(lowest.get_standing_power(5, 0) == 715 and lowest.get_standing_power(5, 1) == 615 and lowest.teams[0][0]["g"] == 300, "Printed doubling leaves roll, gate bonuses and roster G undoubled")
	var tied = _setup(315, "Pyrus", "Darkus", "Dragonoid", 400, 400)
	_oppose(tied)
	_check(tied.effective_printed_power(5, _unit(tied, 0)) == 400 and tied.effective_printed_power(5, _unit(tied, 1)) == 400, "Explicit desktop tie fallback has no unique lowest printed-G target")
	var swapped = _setup(322)
	swapped.land(0, 0, 5, 45)
	swapped.finish_turn()
	swapped.apply_sphere_attack(1, 5, 10)
	swapped.land(1, 0, 5, 15)
	_check(swapped.effective_printed_power(5, _unit(swapped, 0)) == 500 and swapped.effective_printed_power(5, _unit(swapped, 1)) == 300, "G-Power Exchange swaps printed values without rewriting either landing")
	_check(swapped.get_standing_power(5, 0) == 595 and swapped.get_standing_power(5, 1) == 335, "Printed swap preserves each unit's own Sphere loss, collected G and attribute gate boost")
	var result: Dictionary = swapped.resolve_battle(5, 0, 0)
	_check(result.get("player_g") == 595 and result.get("enemy_g") == 335, "Resolved native swap totals equal the visible standing-power API")
	var absent = _setup(323, "Aquos", "Darkus")
	_oppose(absent)
	_check(absent.effective_printed_power(5, _unit(absent, 0)) == 300, "Flaming Wind cannot swap printed G without a Pyrus participant")
	var opponent_pyrus = _setup(323, "Aquos", "Pyrus")
	_oppose(opponent_pyrus)
	_check(opponent_pyrus.effective_printed_power(5, _unit(opponent_pyrus, 0)) == 500, "Either participant can satisfy Flaming Wind's printed Pyrus condition")


func _gate_ability_block_restore_and_multiplier() -> void:
	var blocked = _setup(301)
	_oppose(blocked)
	blocked.abilities = [[_card(511)], [_card(602, 1)]]
	var before: Array = blocked.abilities.duplicate(true)
	_check(not blocked.can_play_ability(0, 0, 5) and blocked.use_ability(0, 0, 5).is_empty() and blocked.use_ability(1, 0).is_empty() and blocked.abilities == before, "Stand Off blocks both players including an omitted-slot call")
	var restored = _setup(306)
	restored.spent_abilities = [[_card(511)], [_card(602, 1)]]
	var sizes: Array = [restored.abilities[0].size(), restored.abilities[1].size()]
	restored.land(0, 0, 5)
	_check(restored.spent_abilities[0].size() == 1, "Hidden restore gate cannot return previously spent cards early")
	restored.finish_turn()
	restored.land(1, 0, 5)
	_check(restored.spent_abilities == [[], []] and restored.abilities[0].size() == sizes[0] + 1 and restored.abilities[1].size() == sizes[1] + 1, "Stand Your Ground restores both discard piles at the declared desktop reveal timing")
	var effects = Effects.new()
	_check(_play(restored, effects, 0, 511), "A previously spent and restored native ability is usable in the new battle")
	var result: Dictionary = restored.resolve_battle(5, effects.extra(0, 0), 0)
	_check(not bool(result.get("abilities_returned", true)) and restored.spent_abilities[0].size() == 1, "DS reveal restoration is not mistakenly repeated after the same battle")
	var multiplied = _setup(314)
	_oppose(multiplied)
	effects.reset()
	_check(_play(multiplied, effects, 0, 511) and effects.extra(0, 0) == 400, "Lockdown doubles a source-backed 200-G ability bonus exactly once")
	var snapshot: Dictionary = _context(multiplied, effects, 0)
	var powers: Array = snapshot["current_powers"].duplicate()
	_check(_play(multiplied, effects, 0, 401) and multiplied.get_standing_power(5, 0) + effects.extra(0, 0) == powers[1] and multiplied.get_standing_power(5, 1) + effects.extra(1, 0) == powers[0], "Lockdown does not multiply the equal-and-opposite offsets of a G-Power Swap")


func _counter_gate_effects() -> void:
	var used = _setup(327, "Pyrus", "Darkus", "Leonidas")
	used.spent_abilities[0] = [_card(511), _card(532)]
	_oppose(used)
	_check(used.gate_unit_bonus(5, _unit(used, 0)) == 310 and used.gate_unit_bonus(5, _unit(used, 1)) == 120, "Trick Jump counts each player's own current used-ability pile")
	var effects = Effects.new()
	_check(_play(used, effects, 0, 527) and used.gate_unit_bonus(5, _unit(used, 0)) == 410, "A newly consumed ability updates Trick Jump once through the engine discard pile")
	var captured = _setup(331, "Pyrus", "Darkus", "Leonidas")
	captured.scores.assign([2, 1])
	_oppose(captured)
	_check(captured.gate_unit_bonus(5, _unit(captured, 0)) == 300 and captured.gate_unit_bonus(5, _unit(captured, 1)) == 250, "Mega Warrior uses the battle participant's capture count, not the gate owner's count")
	effects.reset()
	var count_card: Dictionary = _card(618)
	# Both count cards' eligibility is retained in the source catalog; choose
	# whichever native card admits the current participant's attribute.
	if not Catalog.can_play(count_card, _unit(captured, 0), _unit(captured, 1), "timing", true, captured.battle_context(5, 0)):
		count_card = _card(619)
	_check(_play(captured, effects, 0, int(count_card["source_card_id"])) and effects.extra(0, 0) == 100, "Native Triangle ability adds 50 G per captured card independently of the gate's 100-G term")


func _ability_conditions_and_consumption() -> void:
	var rules = _setup(201, "Aquos", "Darkus", "Leonidas")
	rules.abilities[0] = [_card(605)]
	_check(rules.use_ability(0, 0).is_empty() and rules.spent_abilities[0].is_empty(), "DS ability cannot be consumed outside an opposed battle")
	_oppose(rules)
	_check(rules.can_play_ability(0, 0, 5) and rules.use_ability(0, 0, 5).get("source_card_id") == 605, "Home Advantage can be consumed only on its owner's own gate")
	_check(rules.abilities[0].is_empty() and rules.spent_abilities[0].size() == 1 and rules.use_ability(0, 0, 5).is_empty(), "Native ability moves to the used pile once without enabling a stale replay")
	rules.abilities[1] = [_card(606, 1)]
	_check(rules.can_play_ability(1, 0, 5), "Power From Darkness recognizes an opponent-owned gate")
	rules.gates[5]["owner"] = 1
	var before: Array = rules.abilities.duplicate(true)
	_check(rules.use_ability(1, 0, 5, "timing", true, {"gate_owner": 0}).is_empty() and rules.abilities == before, "Caller-forged gate ownership cannot bypass the engine's actual card condition")
	var own: Dictionary = {"name": "Dragonoid", "attribute": "Pyrus", "g": 300}
	var opponent: Dictionary = {"name": "Hydranoid", "attribute": "Darkus", "g": 500}
	_check(Effects.bonus_for(_card(602), own, opponent) == 60 and not Effects.can_play(_card(603), own, opponent, "timing", false), "Native attribute-power cards respect their source attribute tables")
	_check(not Effects.can_play(_card(527), own, opponent, "timing", true) and Effects.can_play(_card(511), own, opponent, "timing", true), "Species ability cannot be spent on a different Bakugan")
	_check(Effects.bonus_for(_card(620), own, opponent) == 90 and not Effects.can_play(_card(620), opponent, own, "timing", true), "The Glow checks the opponent's original printed G before its attribute bonus")
	_check(not Effects.can_play({"rules_profile": "ds", "effect": null}, own, opponent, "timing", true), "Malformed DS effect data cannot cause a scripting error")


func _power_swaps_and_projection() -> void:
	var rules = _setup(201, "Pyrus", "Darkus", "Dragonoid", 100, 500)
	_oppose(rules, 25, 15)
	var effects = Effects.new()
	var context: Dictionary = _context(rules, effects, 0, 45, 70)
	var powers: Array = context["current_powers"].duplicate()
	var card: Dictionary = _card(408)
	_check(effects.apply(0, card, _unit(rules, 0), _unit(rules, 1), "timing", false, context), "Counter Swap can operate on a complete visible live-battle snapshot")
	_check(rules.get_standing_power(5, 0) + effects.extra(0, 45) == powers[1] and rules.get_standing_power(5, 1) + effects.extra(1, 70) == powers[0], "Power Swap includes original gate, retained roll, ability and current minigame totals")
	var before: Array = effects.states.duplicate(true)
	_check(not effects.apply(0, card, _unit(rules, 0), _unit(rules, 1), "timing", false, _context(rules, effects, 0)) and effects.states == before, "Same physical DS Swap card cannot be applied twice")
	_check(effects.status(1).contains("-"), "Opponent negative swap offsets remain visible in battle status")
	for bad: Variant in [[], [1], [1, 2, 3], [true, 10], [NAN, 10], [INF, 10], [2.5, 10], [3000000000, 10], "invalid"]:
		_check(not Effects.can_play(_card(401), _unit(rules, 0), _unit(rules, 1), "timing", true, {"owner": 0, "current_powers": bad}), "Invalid G snapshot is rejected without a swap or consumed card")
	_check(not Effects.can_play(_card(407), _unit(rules, 0), _unit(rules, 1), "timing", true, context), "Twin Swap requires equal attributes instead of any opposed battle")
	effects.reset()
	context = _context(rules, effects, 0)
	var choice: int = Tactics.choose_ability([_card(408), _card(511)], 0, effects, 0, 0, _unit(rules, 0), _unit(rules, 1), "timing", true, context)
	_check(choice == 0 and effects.counts == [0, 0] and effects.states[0]["power"] == 0, "AI selects the stronger native Swap without mutating the live battle")
	var projected = effects.copy()
	_check(projected.apply(0, _card(408), _unit(rules, 0), _unit(rules, 1), "timing", true, context) and effects.states[0]["power"] == 0, "AI projection isolates both sides of a native Swap")
	var same: Dictionary = _unit(rules, 1).duplicate(true)
	same["attribute"] = "Pyrus"
	_check(Effects.can_play(_card(407), _unit(rules, 0), same, "timing", true, context) and not Effects.can_play(_card(408), _unit(rules, 0), same, "timing", true, context), "Twin and Counter Swap keep their opposite printed conditions")
