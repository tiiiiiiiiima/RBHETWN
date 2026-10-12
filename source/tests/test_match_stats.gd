extends SceneTree

const Stats = preload("res://scripts/match_stats.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_test_throw_summary()
	_test_battle_and_capture_summary()
	_test_independence_and_reset()
	_test_invalid_owner()
	if failures == 0:
		print("PASS: %d match statistics checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d match statistics checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_throw_summary() -> void:
	var stats = Stats.new()
	var fresh: Dictionary = stats.summary(0)
	_check(fresh.size() == 9, "Result statistics expose all nine expected totals")
	for value: Variant in fresh.values():
		_check(typeof(value) == TYPE_INT and value == 0, "Fresh match starts with integer zero statistics")
	stats.record_throw(0, true, 80)
	stats.record_throw(0, false, 20)
	stats.record_throw(0, true, 999)
	var result: Dictionary = stats.summary(0)
	_check(result["throws"] == 3 and result["hits"] == 2 and result["misses"] == 1, "Landed and missed throws share one consistent total")
	_check(result["collected_g"] == 200, "Only landed throw pickups are retained, bounded at 120 each")
	stats.record_throw(0, false, -50)
	result = stats.summary(0)
	_check(result["collected_g"] == 200 and result["misses"] == 2, "Negative collection cannot reduce totals")
	_check(result["throws"] == result["hits"] + result["misses"], "Throw accounting stays internally consistent")
	_check(stats.summary(1)["throws"] == 0 and stats.summary(1)["collected_g"] == 0, "Other owner's throws and pickups remain separate")


func _test_battle_and_capture_summary() -> void:
	var stats = Stats.new()
	stats.record_battle(0, 260, true)
	stats.record_battle(1, 125, false)
	stats.record_battle(0, -30, false)
	stats.record_battle(0, 325, 3)
	stats.record_capture(0, false)
	stats.record_capture(0, true)
	stats.record_capture(1, true)
	var result: Dictionary = stats.summary(0)
	_check(result["battles"] == 3 and result["mini_g"] == 585, "Minigame totals floor negatives and allow raw positive scores without arbitrary ceiling")
	_check(result["abilities"] == 4, "Ability count records every consumed card")
	_check(result["captures"] == 2 and result["double_stands"] == 1, "Battle capture and double stand are distinct result statistics")
	_check(stats.summary(1)["battles"] == 1 and stats.summary(1)["mini_g"] == 125 and stats.summary(1)["abilities"] == 0, "Each owner has its own minigame and ability totals")
	_check(stats.summary(1)["captures"] == 1 and stats.summary(1)["double_stands"] == 1, "Opponent double stand is counted only for opponent")
	_check(result["throws"] == 0, "Recording battle outcomes does not invent throws")


func _test_independence_and_reset() -> void:
	var first = Stats.new()
	var second = Stats.new()
	first.record_throw(0, true, 100)
	first.record_capture(0, true)
	var saved: Dictionary = first.summary(0)
	saved["throws"] = 999
	_check(first.summary(0)["throws"] == 1, "Result UI cannot mutate internal statistics through returned dictionary")
	_check(second.summary(0)["throws"] == 0, "Separate matches do not share statistic dictionaries")
	var before_reset: Dictionary = first.summary(0)
	first.reset()
	_check(before_reset["throws"] == 1 and before_reset["captures"] == 1, "Previously displayed result remains a stable snapshot after replay reset")
	for owner in range(2):
		for value: Variant in first.summary(owner).values():
			_check(value == 0, "New match reset clears both owners' transient statistics")
	first.record_battle(1, 150, true)
	_check(first.summary(0)["battles"] == 0 and first.summary(1)["battles"] == 1, "Owner dictionaries remain independent after reset")


func _test_invalid_owner() -> void:
	var stats = Stats.new()
	stats.record_throw(-1, true, 120)
	stats.record_throw(2, true, 120)
	stats.record_battle(100, 999, true)
	stats.record_capture(-20, true)
	for owner in range(2):
		_check(stats.summary(owner)["throws"] == 0 and stats.summary(owner)["battles"] == 0 and stats.summary(owner)["captures"] == 0, "Invalid recording owner cannot pollute valid owner's statistics")
	_check(stats.summary(-1) == stats.summary(2) and stats.summary(-1).size() == 9, "Invalid summary owner returns a complete zero result safely")
	var invalid: Dictionary = stats.summary(-1)
	invalid["throws"] = 9
	_check(stats.summary(-1)["throws"] == 0, "Invalid owner fallback is also an independent snapshot")
