extends SceneTree
## Unit checks for selectable rosters and the three-round prototype tournament.
## Run: godot --headless --path . --script tests/test_progress.gd

const Roster = preload("res://scripts/roster.gd")
const Tournament = preload("res://scripts/tournament.gd")
var failures: int = 0
var checks: int = 0


func _init() -> void:
	_test_default_roster()
	_test_selected_roster()
	_test_invalid_roster()
	_test_roster_isolation()
	_test_opponents()
	_test_tournament_flow()
	_test_tournament_persistence()
	_test_invalid_persistence()
	if failures == 0:
		print("PASS: %d roster and tournament checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d progress checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_default_roster() -> void:
	var team: Array[Dictionary] = Roster.make_team([], [])
	_check(team.size() == 3, "Empty selection supplies three default units")
	_check(team[0] == {"id": "p0_leonidas", "name": "Leonidas", "attribute": "Pyrus", "g": 340, "used": false}, "Default first unit preserves earlier prototype roster")
	_check(team[1]["name"] == "Dragonoid" and team[1]["g"] == 320 and team[1]["attribute"] == "Pyrus", "Default second unit preserves earlier prototype roster")
	_check(team[2]["name"] == "Griffon" and team[2]["g"] == 300 and team[2]["attribute"] == "Ventus", "Default third unit preserves earlier prototype roster")
	_check(Roster.CREATURES.size() == 99 and Roster.ATTRIBUTES == ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"], "Expanded roster includes 99 creatures and exactly six logical attributes")
	_check(Roster.make_team([0, 1, 2], [], -1).is_empty() and Roster.make_team([0, 1, 2], [], 2).is_empty(), "Invalid owner cannot produce a usable team")


func _test_selected_roster() -> void:
	var selection: Array = [5, 3, 4]
	var attributes: Array = ["Haos", "Ventus", "Aquos"]
	var team: Array[Dictionary] = Roster.make_team(selection, attributes, 1)
	_check(team[0]["id"] == "p1_gorem" and team[0]["g"] == 330, "Selected order and owner appear in team identity")
	_check(team[1]["name"] == "Hydranoid" and team[1]["g"] == 350 and team[2]["name"] == "Preyas" and team[2]["g"] == 310, "Selected creatures keep their demo power")
	_check(team[0]["attribute"] == "Haos" and team[1]["attribute"] == "Ventus" and team[2]["attribute"] == "Aquos", "Each chosen attribute follows its team position")
	_check(selection == [5, 3, 4] and attributes == ["Haos", "Ventus", "Aquos"], "Building a team preserves caller selections")
	_check(Roster.normalize_selection([5.0, 3.0, 4.0]) == [5, 3, 4], "Whole JSON indices restore the intended team")
	for attribute: String in Roster.ATTRIBUTES:
		_check(Roster.normalize_attributes([attribute, attribute, attribute]) == [attribute, attribute, attribute], "Every attribute can be selected: %s" % attribute)


func _test_invalid_roster() -> void:
	var invalid_selections: Array = [
		[], [0], [0, 1], [0, 1, 2, 3], [0, 0, 1], [1, 2, 1],
		[-1, 1, 2], [0, 1, Roster.CREATURES.size()], [0, 1, 999999999], [0, 1, 2.5],
		["0", 1, 2], [false, 1, 2], [null, 1, 2], [{}, 1, 2], [NAN, 1, 2], [INF, 1, 2],
	]
	for selection: Array in invalid_selections:
		_check(Roster.normalize_selection(selection) == [0, 1, 2], "Malformed or duplicate selection resets all three indices: %s" % str(selection))
	var invalid_attributes: Array = [
		[], ["Pyrus"], ["Pyrus", "Aquos"], ["Pyrus", "Aquos", "Haos", "Ventus"],
		["Pyrus", "aquos", "Ventus"], ["Pyrus", "Unknown", "Ventus"], ["Pyrus", 3, "Ventus"],
		["Pyrus", null, "Ventus"], ["Pyrus", false, "Ventus"], ["Pyrus", {}, "Ventus"],
	]
	for attributes: Array in invalid_attributes:
		_check(Roster.normalize_attributes(attributes) == ["Pyrus", "Pyrus", "Ventus"], "Malformed attributes restore all three defaults: %s" % str(attributes))
	var team: Array[Dictionary] = Roster.make_team([0, 0, 2], ["Haos", "Aquos", "Darkus"])
	_check(team[1]["name"] == "Dragonoid" and team[0]["attribute"] == "Haos", "Invalid selection fallback preserves a valid independent attribute choice")
	team = Roster.make_team([3, 4, 5], ["Haos", "invalid", "Darkus"])
	_check(team[0]["name"] == "Hydranoid" and team[0]["attribute"] == "Pyrus" and team[2]["attribute"] == "Ventus", "Invalid attributes do not discard valid creature choices")


func _test_roster_isolation() -> void:
	var first: Array[Dictionary] = Roster.make_team([], [])
	var second: Array[Dictionary] = Roster.make_team([], [])
	first[0]["g"] = 999
	first[0]["used"] = true
	first[1]["attribute"] = "Darkus"
	_check(second[0]["g"] == 340 and not second[0]["used"] and second[1]["attribute"] == "Pyrus", "Teams from separate matches share no mutable unit state")
	_check(Roster.CREATURES[0]["g"] == 340 and Roster.make_team([], [])[0]["g"] == 340, "Modified match power cannot corrupt creature defaults")
	var selection: Array[int] = Roster.normalize_selection([])
	var attributes: Array[String] = Roster.normalize_attributes([])
	selection[0] = 5
	attributes[0] = "Haos"
	_check(Roster.normalize_selection([]) == [0, 1, 2] and Roster.normalize_attributes([]) == ["Pyrus", "Pyrus", "Ventus"], "Returned normalized arrays do not alias defaults")


func _test_opponents() -> void:
	var identities: Array = []
	for stage in range(3):
		var team: Array[Dictionary] = Roster.make_opponent(stage)
		_check(team.size() == 3, "Stage %d supplies three opponents" % stage)
		var names: Array[String] = []
		for unit: Dictionary in team:
			names.append(unit["name"])
			var base_power: int = 0
			for creature: Dictionary in Roster.CREATURES:
				if creature["name"] == unit["name"]:
					base_power = creature["g"]
			_check(unit["g"] == base_power + 20 * stage and unit["id"].begins_with("p1_") and not unit["used"], "Stage %d applies its demo power rise to %s" % [stage, unit["name"]])
			_check(Roster.ATTRIBUTES.has(unit["attribute"]), "Opponent attribute is playable")
		_check(names.size() == 3 and names[0] != names[1] and names[1] != names[2] and names[0] != names[2], "Each opponent team has unique creatures")
		identities.append(names)
	_check(identities[0] != identities[1] and identities[1] != identities[2], "Tournament rounds use different opponent lineups")
	_check(Roster.make_opponent(-10) == Roster.make_opponent(0) and Roster.make_opponent(999) == Roster.make_opponent(2), "Out-of-range opponent stages safely use nearest playable stage")
	var changed: Array[Dictionary] = Roster.make_opponent(2)
	changed[0]["g"] = -1
	changed[0]["used"] = true
	_check(Roster.make_opponent(2)[0]["g"] == 390 and not Roster.make_opponent(2)[0]["used"], "Opponent generation isolates per-match state")


func _test_tournament_flow() -> void:
	var tournament = Tournament.new()
	_check(tournament.stage == 0 and not tournament.active and not tournament.completed, "New tournament waits for an explicit start")
	_check(tournament.record_result(true) == {"advanced": false, "completed": false, "stage": 0}, "An inactive tournament cannot advance from a match result")
	var profile: Dictionary = tournament.get_stage()
	profile["enemy_min"] = 999
	_check(tournament.get_stage()["enemy_min"] == 70, "Stage profiles are independent copies")
	tournament.start_new()
	_check(tournament.active and tournament.stage == 0 and not tournament.completed, "Starting a tournament opens the qualifier")
	for stage in range(3):
		_check(tournament.stage == stage and tournament.active, "Round %d remains active before its result" % stage)
		_check(tournament.get_stage()["enemy_min"] == 70 + 25 * stage and tournament.get_stage()["enemy_max"] == 125 + 25 * stage, "Opponent battle extras escalate by round")
		var state: Dictionary = tournament.to_dict()
		_check(tournament.record_result(false) == {"advanced": false, "completed": false, "stage": stage} and tournament.to_dict() == state, "A round loss preserves progress for a retry")
		var result: Dictionary = tournament.record_result(true)
		if stage < 2:
			_check(result == {"advanced": true, "completed": false, "stage": stage + 1}, "A winning early round advances exactly once")
		else:
			_check(result == {"advanced": false, "completed": true, "stage": 2} and not tournament.active, "Final victory completes the tournament without a fourth round")
	var completed_state: Dictionary = tournament.to_dict()
	_check(tournament.record_result(true)["completed"] and tournament.to_dict() == completed_state, "Further results cannot change completed progress")
	tournament.start_new()
	_check(tournament.to_dict() == {"stage": 0, "active": true, "completed": false}, "Starting again clears completion and final-round progress")


func _test_tournament_persistence() -> void:
	for stage in range(3):
		var tournament = Tournament.new()
		tournament.load_dict({"stage": stage, "active": true, "completed": false})
		var restored = Tournament.new()
		restored.load_dict(JSON.parse_string(JSON.stringify(tournament.to_dict())))
		_check(restored.to_dict() == tournament.to_dict() and restored.get_stage() == tournament.get_stage(), "JSON save restores active round %d and its profile" % stage)
		_check(not restored.record_result(false)["advanced"] and restored.stage == stage, "Restored round can be retried after losing")
	var completed = Tournament.new()
	completed.load_dict({"stage": 0, "active": true, "completed": true})
	_check(completed.to_dict() == {"stage": 2, "active": false, "completed": true}, "Completed save always normalizes to an inactive final stage")
	var restored = Tournament.new()
	restored.load_dict(JSON.parse_string(JSON.stringify(completed.to_dict())))
	_check(restored.to_dict() == completed.to_dict(), "Completed tournament survives JSON round trip")
	var snapshot: Dictionary = restored.to_dict()
	snapshot["completed"] = false
	_check(restored.completed, "Editing a save snapshot cannot change running tournament state")


func _test_invalid_persistence() -> void:
	var tournament = Tournament.new()
	for invalid_stage: Variant in [-1, 3, 999999999, "1", true, null, {}, [], 1.5, NAN, INF]:
		tournament.load_dict({"stage": invalid_stage, "active": true, "completed": false})
		_check(tournament.stage == 0 and tournament.active and not tournament.completed, "Malformed saved stage returns to a playable qualifier: %s" % str(invalid_stage))
	for invalid_flag: Variant in ["true", "false", 0, 1, null, {}, []]:
		tournament.load_dict({"stage": 1, "active": invalid_flag, "completed": invalid_flag})
		_check(tournament.to_dict() == {"stage": 1, "active": false, "completed": false}, "Malformed boolean flags do not start or complete a tournament: %s" % str(invalid_flag))
	tournament.load_dict({"stage": 2.0, "active": true})
	_check(tournament.stage == 2 and tournament.active and not tournament.completed, "Whole JSON final-stage value accepts absent completion flag")
	tournament.load_dict({"unrelated": "old save"})
	_check(tournament.to_dict() == {"stage": 0, "active": false, "completed": false}, "Old saves without tournament keys load default inactive progress")
	tournament.start_new()
	tournament.record_result(true)
	tournament.load_dict({})
	_check(tournament.to_dict() == {"stage": 0, "active": false, "completed": false}, "Loading defaults clears any previously running progress")
