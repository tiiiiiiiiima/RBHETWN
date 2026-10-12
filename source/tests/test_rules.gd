extends SceneTree
## General state regressions; card-specific Wii scenarios live in test_rules_06.gd.

const Rules = preload("res://scripts/match_rules.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_setup_and_reset()
	_placement_rejections()
	_throw_rejections_and_misses()
	_battle_power_and_ties()
	_landing_bonus_lifetime()
	_reserve_cycle()
	_ability_consumption()
	_match_completion()
	if failures == 0:
		print("PASS: %d deterministic rules checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d rules checks" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _fixture_gate(rules, owner: int, slot: int, color: String = "silver", boosts: Dictionary = {"Pyrus": 100, "Darkus": 80}, effect: Dictionary = {}) -> void:
	# Known test values isolate arithmetic from the sourced card database.
	rules.hands[owner][0] = {"id": "fixture_%d" % slot, "owner": owner,
		"title": "Arithmetic fixture", "color_type": color, "boosts": boosts,
		"effect": effect, "bakugan": []}
	_check(rules.place_gate(owner, 0, slot), "Fixture placement at legal slot %d" % slot)


func _setup_and_reset() -> void:
	var rules = Rules.new()
	_check(rules.scores == [0, 0] and rules.turn == 0 and rules.winner == -1, "Fresh match state")
	_check(rules.teams.size() == 2 and rules.hands[0].size() == 3 and rules.abilities[1].size() == 3, "Both sides have three balls and both card hands")
	_check(rules.available_units(0) == [0, 1, 2] and rules.available_units(-1).is_empty(), "Reserve starts complete and rejects invalid owners")
	_check(rules.make_team(2).is_empty(), "Invalid team owner is rejected")
	rules.teams[0][0]["g"] = 999
	rules.scores[0] = 2
	rules.new_match()
	_check(rules.teams[0][0]["g"] == 340 and rules.scores == [0, 0], "Reset restores isolated team balance")
	_check(rules.gates.is_empty() and rules.spent_abilities == [[], []] and rules.stay_markers == [{}, {}], "Reset clears board, discard piles and delayed markers")


func _placement_rejections() -> void:
	var rules = Rules.new()
	_check(rules.place_gate(0, 0, 5, true), "Opening gate can occupy a central spot")
	_check(rules.hands[0].size() == 2 and rules.gates[5]["owner"] == 0, "Successful placement transfers a card")
	_check(not rules.place_gate(1, 0, 5, true) and rules.hands[1].size() == 3, "Occupied placement preserves opponent hand")
	_check(rules.place_gate(1, 0, 10, true), "Second opening may use another central spot without adjacency")
	_check(not rules.place_gate(0, -1, 6) and not rules.place_gate(0, 99, 6), "Invalid hand indices preserve state")
	_check(not rules.place_gate(3, 0, 6) and not rules.place_gate(0, 0, -1) and not rules.place_gate(0, 0, 16), "Invalid owner and off-board slots rejected")
	_check(not rules.place_gate(0, 0, 0) and rules.hands[0].size() == 2, "Disconnected subsequent placement rejected")


func _throw_rejections_and_misses() -> void:
	var rules = Rules.new()
	_fixture_gate(rules, 0, 5)
	var landed: Dictionary = rules.land(0, 0, 5)
	_check(landed["event"] == "stand" and rules.teams[0][0]["used"], "Stand locks the thrown unit")
	_check(rules.land(0, 0, 5)["event"] == "invalid", "A standing unit cannot be thrown twice")
	_check(rules.land(0, 1, -1, 120)["event"] == "miss" and not rules.available_units(0).has(1), "A miss locks the ball until turn end")
	rules.finish_turn()
	_check(rules.turn == 1 and rules.available_units(0).has(1) and not rules.available_units(0).has(0), "A miss returns at turn end while a stand stays locked")
	_check(rules.land(0, 99, 5)["event"] == "invalid" and rules.land(2, 0, 5)["event"] == "invalid", "Invalid throws leave the gate untouched")
	rules.land(1, 0, 5)
	_check(rules.land(0, 2, 5)["event"] == "invalid" and not rules.teams[0][2]["used"], "Third entrant to a pending battle is rejected before consuming reserve")


func _battle_power_and_ties() -> void:
	var rules = Rules.new()
	_fixture_gate(rules, 0, 5)
	rules.land(0, 0, 5, 35)
	_check(rules.get_standing_power(5, 0) == 375 and rules.gate_bonus(5, "Pyrus") == 0, "Hidden card bonus is deferred until battle")
	var battle: Dictionary = rules.land(1, 0, 5)
	_check(battle["event"] == "battle" and battle["defender"]["owner"] == 0 and battle["challenger"]["owner"] == 1, "Opposed stand preserves landing order")
	_check(rules.get_standing_power(5, 0) == 475 and rules.get_standing_power(5, 1) == 430, "Reveal applies the appropriate attribute bonus to each landing")
	var result: Dictionary = rules.resolve_battle(5, 10, 30)
	_check(result["player_g"] == 485 and result["enemy_g"] == 460 and result["owner"] == 0, "Battle combines base, roll, gate and supplied battle extra once")
	_check(rules.scores == [1, 0] and not rules.gates.has(5), "A resolved battle captures exactly one gate")
	_check(not rules.available_units(0).has(0) and not rules.available_units(1).has(0), "Captured combatants remain spent for their landing cycle")
	_check(rules.resolve_battle(5, 999, 0)["event"] == "invalid" and rules.scores == [1, 0], "A captured gate cannot award another point")
	for first_owner in range(2):
		var tie = Rules.new()
		_fixture_gate(tie, 0, 5)
		tie.land(first_owner, 0, 5)
		tie.land(1 - first_owner, 0, 5)
		result = tie.resolve_battle(5, 0, 10)
		_check(result["player_g"] == result["enemy_g"] and result["owner"] == first_owner, "Tabletop fallback awards ties to first standing owner %d" % first_owner)


func _landing_bonus_lifetime() -> void:
	var rules = Rules.new()
	_fixture_gate(rules, 0, 5)
	var landed: Dictionary = rules.land(0, 0, 5, 55)
	_check(landed["unit"]["roll_bonus"] == 55 and rules.teams[0][0]["g"] == 340, "Collected G belongs to the landing rather than immutable roster G")
	rules.finish_turn()
	rules.finish_turn()
	_check(rules.get_standing_power(5, 0) == 395, "An uncontested landing keeps collected G across turns")
	_check(rules.get_standing_power(99, 0) == 0 and rules.get_standing_power(5, -1) == 0, "Absent and invalid power queries return zero")
	rules.new_match()
	_fixture_gate(rules, 0, 5)
	landed = rules.land(0, 0, 5, -90)
	_check(landed["unit"]["roll_bonus"] == 0, "Negative pickup G is clamped")
	var battle: Dictionary = rules.land(1, 0, 5, 999)
	_check(battle["challenger"]["roll_bonus"] == 120, "Local roll-item cap is enforced")
	var result: Dictionary = rules.resolve_battle(5, 0, 0)
	_check(result["player_g"] == 440 and result["enemy_g"] == 550, "Battle uses clamped landing bonuses")
	_check(not rules.teams[0][0].has("roll_bonus") and not rules.teams[1][0].has("sphere_damage"), "Temporary landing effects never enter the roster")


func _reserve_cycle() -> void:
	var rules = Rules.new()
	_fixture_gate(rules, 0, 5)
	rules.land(0, 0, 5)
	rules.land(0, 1, 5)
	_check(rules.available_units(0) == [2] and not rules.recycle_used(0), "Double capture keeps first two balls spent while the third remains available")
	rules.finish_turn()
	rules.finish_turn()
	_check(rules.available_units(0) == [2], "Captured balls cannot be reused just by waiting a turn")
	_fixture_gate(rules, 0, 6)
	rules.land(0, 2, 6, 120)
	_check(rules.available_units(0).is_empty() and rules.recycle_used(0), "Third successful landing unlocks the spent off-board balls")
	_check(rules.available_units(0) == [0, 1] and not rules.teams[0][0]["landed_cycle"] and rules.teams[0][2]["used"], "Recycling preserves the live standing unit and resets only returned balls")
	var battle: Dictionary = rules.land(0, 0, 6)
	_check(battle["event"] == "double_stand" and rules.scores[0] == 2, "A recycled ball can complete the next Double Stand")
	_check(not rules.teams[0][0].has("roll_bonus"), "Returned ball does not inherit prior collected power")


func _ability_consumption() -> void:
	var rules = Rules.new()
	var seen: Array[String] = []
	for _index in range(3):
		var card: Dictionary = rules.use_ability(0, 0)
		_check(not card.is_empty() and not seen.has(str(card["id"])), "An ability card is consumed only once")
		seen.append(str(card["id"]))
	_check(rules.abilities[0].is_empty() and rules.spent_abilities[0].size() == 3, "Used cards move to the discard pile")
	_check(rules.use_ability(0, 0).is_empty() and rules.abilities[1].size() == 3, "An exhausted hand does not affect the other owner")
	_check(rules.use_ability(4, 0).is_empty() and rules.use_ability(1, -1).is_empty(), "Invalid ability references are rejected")


func _match_completion() -> void:
	var rules = Rules.new()
	rules.scores[0] = 2
	_fixture_gate(rules, 0, 5)
	rules.land(0, 0, 5)
	var result: Dictionary = rules.land(0, 1, 5)
	_check(result["event"] == "double_stand" and result["winner"] == 0 and rules.scores == [3, 0], "Third captured gate completes the match")
	_check(not rules.place_gate(1, 0, 6) and rules.land(1, 0, 6)["event"] == "invalid", "Finished match rejects further placements and throws")
	_check(rules.use_ability(1, 0).is_empty() and rules.available_units(1).is_empty(), "Finished match disables card use and reserve selection")
	var previous_turn: int = rules.turn
	rules.finish_turn()
	_check(rules.turn == previous_turn, "Finished match does not advance another turn")
