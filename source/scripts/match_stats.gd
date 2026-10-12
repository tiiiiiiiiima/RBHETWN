extends RefCounted
## Transient statistics for one match, independent of persistent win counts.

var totals: Array[Dictionary] = []


func _init() -> void:
	reset()


func reset() -> void:
	totals = [_empty_summary(), _empty_summary()]


func record_throw(owner: int, landed: bool, roll_bonus: int) -> void:
	if not _valid_owner(owner):
		return
	var stats: Dictionary = totals[owner]
	stats["throws"] += 1
	stats["hits" if landed else "misses"] += 1
	# Wii pickups count only if the thrown Bakugan stands successfully.
	if landed:
		stats["collected_g"] += clampi(roll_bonus, 0, 120)


func record_battle(owner: int, mini_points: int, ability: Variant) -> void:
	if not _valid_owner(owner):
		return
	var stats: Dictionary = totals[owner]
	stats["battles"] += 1
	# Raw minigame points: ability power/focus must not inflate this statistic.
	stats["mini_g"] += maxi(mini_points, 0)
	if typeof(ability) == TYPE_BOOL or typeof(ability) == TYPE_INT:
		stats["abilities"] += maxi(0, int(ability))


func record_capture(owner: int, double_stand: bool) -> void:
	if not _valid_owner(owner):
		return
	var stats: Dictionary = totals[owner]
	stats["captures"] += 1
	if double_stand:
		stats["double_stands"] += 1


func summary(owner: int) -> Dictionary:
	return totals[owner].duplicate(true) if _valid_owner(owner) else _empty_summary()


func _valid_owner(owner: int) -> bool:
	return owner == 0 or owner == 1


func _empty_summary() -> Dictionary:
	return {
		"throws": 0, "hits": 0, "misses": 0, "collected_g": 0,
		"battles": 0, "mini_g": 0, "abilities": 0,
		"captures": 0, "double_stands": 0,
	}
