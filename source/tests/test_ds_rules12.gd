extends SceneTree
## Authoritative DS action sequencing. Numerical fixtures isolate transitions
## from native card tables; sourced card effects have separate catalog checks.

const Rules = preload("res://scripts/match_rules.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_opening_and_turn_actions()
	_pending_battle_and_double()
	_miss_and_cycle_lifetimes()
	_sphere_and_stay_sequences()
	_complete_match()
	_reset_and_profile_isolation()
	if failures == 0:
		print("PASS: %d DS 0.12 authoritative transition checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d DS transition checks" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _state(rules) -> String:
	return JSON.stringify([rules.scores, rules.turn, rules.turn_serial, rules.gates,
		rules.hands, rules.abilities, rules.spent_abilities, rules.teams, rules.winner,
		rules.opening_placements, rules.opening_active, rules.gate_placed_this_turn,
		rules.turn_action_taken, rules.stay_markers])


func _gate(rules, owner: int, slot: int, opening: bool = false, effect: Dictionary = {}) -> void:
	rules.hands[owner][0] = {"id": "fixture_%d_%d" % [owner, slot], "owner": owner,
		"title": "Transition fixture", "color_type": "silver", "boosts": {},
		"effect": effect, "bakugan": []}
	_check(rules.place_gate(owner, 0, slot, opening), "Legal DS fixture transfers a gate")


func _setup():
	var rules = Rules.new("ds")
	_gate(rules, 0, 5, true)
	_gate(rules, 1, 10, true)
	return rules


func _pass(rules) -> void:
	_check(rules.land(rules.turn, rules.available_units(rules.turn)[0], -1).get("event") == "miss", "Response miss consumes one turn action")
	_check(rules.finish_turn(), "Completed response advances one turn")


func _opening_and_turn_actions() -> void:
	var rules = Rules.new("ds")
	_check(rules.rules_profile == "ds" and rules.opening_active, "DS match begins with engine-owned setup")
	var before: String = _state(rules)
	_check(rules.land(0, 0, 5).get("event") == "invalid" and not rules.finish_turn() and _state(rules) == before, "Throw and turn end cannot bypass opening setup")
	_check(not rules.place_gate(0, 0, 5), "Opening cannot be disguised as an optional placement")
	_gate(rules, 0, 5, true)
	before = _state(rules)
	_check(not rules.place_gate(0, 0, 10, true) and _state(rules) == before, "Repeated opening placement preserves the second card")
	_gate(rules, 1, 10, true)
	_check(not rules.opening_active and rules.opening_placements == [true, true], "Both initial cards unlock the first turn")
	before = _state(rules)
	_check(not rules.finish_turn() and rules.land(1, 0, 5).get("event") == "invalid" and not rules.place_gate(1, 0, 6) and _state(rules) == before, "Wrong owner and empty turn cannot mutate the match")
	_gate(rules, 0, 6)
	before = _state(rules)
	_check(not rules.place_gate(0, 0, 9) and _state(rules) == before, "Optional gate placement is limited to one per turn")
	_check(rules.land(0, 0, 5).get("event") == "stand", "Current owner may throw after their optional placement")
	before = _state(rules)
	_check(rules.land(0, 1, 10).get("event") == "invalid" and not rules.place_gate(0, 0, 9) and _state(rules) == before, "Second throw and post-throw placement are rejected atomically")
	_check(rules.finish_turn() and rules.turn == 1 and rules.turn_serial == 1, "Completed stand advances once and clears action quotas")
	before = _state(rules)
	_check(not rules.finish_turn() and _state(rules) == before, "A second result callback cannot skip the opponent's playable turn")


func _pending_battle_and_double() -> void:
	var rules = _setup()
	rules.land(0, 0, 5)
	rules.finish_turn()
	_check(rules.land(1, 0, 5).get("event") == "battle" and rules.pending_slot() == 5, "Opposed stand creates one pending battle")
	var before: String = _state(rules)
	_check(rules.land(1, 1, 6).get("event") == "invalid" and not rules.place_gate(1, 0, 10) and not rules.finish_turn() and not rules.recycle_used(0) and _state(rules) == before, "Pending battle freezes unrelated throws, placement, recycling and turn changes")
	_check(rules.resolve_battle(5, 1000, 0).get("event") == "capture" and rules.pending_slot() == -1 and rules.finish_turn(), "One battle resolution unlocks the challenger turn end")
	before = _state(rules)
	_check(rules.resolve_battle(5, 1000, 0).get("event") == "invalid" and _state(rules) == before, "A stale battle callback cannot capture twice")
	var doubled = _setup()
	_gate(doubled, 0, 6)
	doubled.land(0, 0, 5)
	doubled.finish_turn()
	_pass(doubled)
	_check(doubled.land(0, 1, 5).get("event") == "double_choice" and doubled.pending_slot() == 5, "DS Win/Move menu waits for a choice before capturing")
	before = _state(doubled)
	_check(not doubled.finish_turn() and doubled.land(0, 2, 6).get("event") == "invalid" and not doubled.begin_opening() and _state(doubled) == before, "Pending DS Double choice cannot add another throw or skip resolution")
	_check(doubled.resolve_double(5, 6).get("event") == "stand" and doubled.finish_turn(), "DS Move selection finishes the same physical throw")
	_check(doubled.gates[5]["bakugan"][0]["index"] == 0 and doubled.gates[6]["bakugan"][0]["index"] == 1, "DS Move preserves first standing unit and relocates only the challenger")


func _miss_and_cycle_lifetimes() -> void:
	var rules = _setup()
	_check(rules.land(0, 0, -1).get("event") == "miss" and not rules.available_units(0).has(0), "Missed unit remains unavailable during its throw turn")
	_check(rules.finish_turn() and rules.available_units(0).has(0), "Miss returns only after authoritative turn completion")
	_pass(rules)
	rules.land(0, 0, 5, 30)
	rules.finish_turn()
	_pass(rules)
	rules.land(0, 1, 5, 60)
	rules.resolve_double(5)
	rules.finish_turn()
	_check(rules.available_units(0) == [2] and not rules.recycle_used(0), "Captured units cannot recycle out of turn or before all three land")
	_pass(rules)
	_check(not rules.recycle_used(0), "Waiting through a response does not refresh an incomplete cycle")
	rules.land(0, 2, 10)
	rules.finish_turn()
	_pass(rules)
	_check(rules.recycle_used(0) and rules.available_units(0) == [0, 1], "Completed landing cycle refreshes returned balls at the owner's next turn")
	_check(rules.gates[10]["bakugan"][0]["index"] == 2 and rules.gates[10]["bakugan"][0]["roll_bonus"] == 0, "Cycle recycling preserves standing balls and does not copy earlier pickups")


func _complete_match() -> void:
	var rules = _setup()
	for pair: Array in [[5, 0], [6, 1], [9, 2]]:
		var slot: int = int(pair[0])
		var unit: int = int(pair[1])
		if not rules.gates.has(slot):
			_gate(rules, 0, slot)
		_check(rules.land(0, unit, slot).get("event") == "stand" and rules.finish_turn(), "Full round first player stands and yields")
		_check(rules.land(1, unit, slot).get("event") == "battle", "Full round second player challenges")
		var result: Dictionary = rules.resolve_battle(slot, 1000, 0)
		_check(result.get("event") == "capture" and int(result.get("owner", -1)) == 0 and rules.scores[0] == unit + 1, "Full round captures exactly one sourced card slot")
		if rules.winner < 0:
			_check(rules.finish_turn(), "Unfinished round returns control to first player")
	_check(rules.winner == 0 and rules.scores == [3, 0], "Three captures complete a match through legal alternating turns")
	var before: String = _state(rules)
	_check(not rules.finish_turn() and not rules.begin_opening() and not rules.consume_throw(0, 0) and rules.land(1, 0, 5).get("event") == "invalid" and _state(rules) == before, "Match completion rejects every stale turn, throw and setup callback")


func _sphere_and_stay_sequences() -> void:
	var critical = _setup()
	critical.land(0, 0, 5)
	critical.finish_turn()
	_check(critical.apply_sphere_attack(1, 5, 999).get("event") == "critical_ko", "A physical Sphere impact may capture before the ball stands")
	_check(critical.consume_throw(1, 0, true) and critical.turn_action_taken and critical.finish_turn(), "Critical K.O. explicitly spends its one attacking ball before turn completion")
	_check(critical.teams[1][0]["used"] and critical.teams[1][0]["landed_cycle"], "Critical K.O. preserves the attacker's successful landing cycle")
	var surviving = _setup()
	surviving.land(0, 0, 5, 20)
	surviving.finish_turn()
	_check(surviving.apply_sphere_attack(1, 5, 100).get("event") == "sphere_attack" and not surviving.turn_action_taken, "Surviving Sphere damage does not prematurely spend the still-moving throw")
	_check(surviving.land(1, 0, 5).get("event") == "battle" and not surviving.finish_turn(), "That same physical throw may stand and must finish its pending battle")
	var result: Dictionary = surviving.resolve_battle(5, 1000, 0)
	_check(int(result.get("player_g", -1)) == 1260 and surviving.finish_turn(), "Surviving Sphere loss persists exactly once through the battle")
	var stay = _setup()
	stay.land(0, 0, 5)
	stay.finish_turn()
	_pass(stay)
	_gate(stay, 0, 9)
	stay.land(0, 1, 10)
	stay.finish_turn()
	_pass(stay)
	stay.land(0, 2, 9)
	_check(stay.needs_stay(0) and not stay.choose_stay(0, 5), "Three stands cannot add a Stay action after the same turn's throw")
	stay.finish_turn()
	_pass(stay)
	var before: String = _state(stay)
	_check(not stay.finish_turn() and _state(stay) == before, "A full standing team cannot bypass its required Stay selection by skipping")
	_check(stay.choose_stay(0, 5) and stay.turn_action_taken and stay.process_stay(0).is_empty() and stay.finish_turn(), "Stay replaces the next throw and yields a complete response turn")
	_pass(stay)
	_check(stay.process_stay(0).get("event") == "stay_capture" and stay.scores == [1, 0] and not stay.turn_action_taken, "Unchallenged Stay resolves on the next own turn before its new throw")
	_check(stay.recycle_used(0) and stay.available_units(0) == [0], "Returned Stay unit becomes available only after its completed landing cycle")


func _reset_and_profile_isolation() -> void:
	var rules = _setup()
	rules.land(0, 0, 5)
	rules.new_match()
	_check(rules.rules_profile == "ds" and rules.opening_active and rules.gates.is_empty() and rules.opening_placements == [false, false] and not rules.turn_action_taken, "Restart preserves DS profile and clears all action state")
	rules.new_match("wii")
	_check(rules.rules_profile == "wii" and not rules.opening_active and rules.finish_turn(), "Explicit Wii switch retains compatibility setup behavior")
	rules.new_match("ds")
	_check(rules.rules_profile == "ds" and not rules.finish_turn(), "Switching back cannot inherit a Wii setup bypass")
