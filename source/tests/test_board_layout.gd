extends SceneTree
## Field adjacency and opening placement are independent of arena decoration.

const BoardLayout = preload("res://scripts/board_layout.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_check(BoardLayout.POSITIONS.size() == 16 and BoardLayout.SLOT_COUNT == 16, "The board provides sixteen shared positions")
	_check(BoardLayout.legal_slots({}) == [5, 6, 9, 10], "An empty field allows only the four central opening spaces")
	_check(BoardLayout.legal_slots({5: {}}, true) == [6, 9, 10], "The second opening placement remains in the central spaces and cannot overlap")
	_check(BoardLayout.legal_slots({5: {}}) == [1, 4, 6, 9], "Later placements must share a side with the existing card")
	_check(BoardLayout.legal_slots({5: {}, 6: {}}) == [1, 2, 4, 7, 9, 10], "The legal border around two cards contains no diagonal-only spaces")
	_check(BoardLayout.legal_slots({0: {}}) == [1, 4], "A corner card permits only its two in-bounds neighbors")
	_check(BoardLayout.neighbors(5) == [1, 4, 6, 9], "A central slot has four orthogonal neighbors")
	_check(BoardLayout.neighbors(0) == [1, 4] and BoardLayout.neighbors(15) == [11, 14], "Corner neighbors stay inside the field")
	_check(not BoardLayout.is_adjacent(3, 4), "Row wrapping does not create a side connection")
	_check(not BoardLayout.is_adjacent(5, 10) and not BoardLayout.is_adjacent(5, 0), "Diagonal slots are not adjacent")
	_check(not BoardLayout.is_adjacent(5, 5), "A slot is not adjacent to itself")
	_check(BoardLayout.neighbors(-1).is_empty() and BoardLayout.neighbors(16).is_empty() and not BoardLayout.is_adjacent(-1, 0), "Invalid slots have no legal connections")
	var full: Dictionary = {}
	for slot: int in range(BoardLayout.SLOT_COUNT):
		full[slot] = {}
	_check(BoardLayout.legal_slots(full).is_empty() and BoardLayout.legal_slots(full, true).is_empty(), "A full field has no placement spaces")
	_check(BoardLayout.legal_slots({5: {}, 6: {}, 9: {}, 10: {}}, true).is_empty(), "Occupied central spaces cannot accept another opening card")
	_check(BoardLayout.legal_slots({-1: {}, 99: {}, "5": {}}).is_empty(), "Malformed occupied keys never generate off-field connections")
	_check(BoardLayout.POSITIONS[0] == Vector3(-3.15, 0.0, -3.3) and BoardLayout.POSITIONS[15] == Vector3(3.15, 0.0, 3.3), "The shared coordinates follow row-major order")
	print("BOARD_LAYOUT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
