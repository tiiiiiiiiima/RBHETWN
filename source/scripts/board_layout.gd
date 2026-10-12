extends RefCounted
## Wii compatibility geometry and a separate observed DS 8-by-6 placement map.

const SLOT_COUNT: int = 16
const GRID_WIDTH: int = 4
const INITIAL_SLOTS: Array[int] = [5, 6, 9, 10]
const DS_WIDTH: int = 8
const DS_HEIGHT: int = 6
const DS_INITIAL: Array[int] = [19,20,27,28]
const DS_CARD_SCALE: float = 1.18
const WII_CARD_SCALE: float = 0.90
const POSITIONS: Array[Vector3] = [
	Vector3(-3.15, 0.0, -3.3), Vector3(-1.05, 0.0, -3.3), Vector3(1.05, 0.0, -3.3), Vector3(3.15, 0.0, -3.3),
	Vector3(-3.15, 0.0, -1.1), Vector3(-1.05, 0.0, -1.1), Vector3(1.05, 0.0, -1.1), Vector3(3.15, 0.0, -1.1),
	Vector3(-3.15, 0.0, 1.1), Vector3(-1.05, 0.0, 1.1), Vector3(1.05, 0.0, 1.1), Vector3(3.15, 0.0, 1.1),
	Vector3(-3.15, 0.0, 3.3), Vector3(-1.05, 0.0, 3.3), Vector3(1.05, 0.0, 3.3), Vector3(3.15, 0.0, 3.3)
]

static func slot_count(profile: String = "wii") -> int:
	return DS_WIDTH*DS_HEIGHT if profile=="ds" else SLOT_COUNT

static func initial_slots(profile: String = "wii", owner: int = -1) -> Array[int]:
	if profile!="ds":
		return INITIAL_SLOTS.duplicate()
	if owner==0: return [19,20]
	if owner==1: return [27,28]
	return DS_INITIAL.duplicate()

static func position(slot: int, profile: String = "wii") -> Vector3:
	if profile!="ds":
		return POSITIONS[clampi(slot,0,SLOT_COUNT-1)]*1.10
	var index: int = clampi(slot,0,DS_WIDTH*DS_HEIGHT-1)
	# Grid size is observed; world-space spacing is a desktop fit.
	return Vector3((float(index%DS_WIDTH)-3.5)*2.15,0,(float(index/DS_WIDTH)-2.5)*2.30)

static func is_adjacent(first: int, second: int, profile: String = "wii") -> bool:
	if first < 0 or first >= slot_count(profile) or second < 0 or second >= slot_count(profile):
		return false
	var width: int = DS_WIDTH if profile=="ds" else GRID_WIDTH
	var first_row: int = first / width
	var second_row: int = second / width
	return absi(first_row - second_row) + absi(first % width - second % width) == 1

static func neighbors(slot: int, profile: String = "wii") -> Array[int]:
	var result: Array[int] = []
	for other: int in range(slot_count(profile)):
		if is_adjacent(slot, other, profile):
			result.append(other)
	return result

static func legal_slots(gates: Dictionary, opening: bool = false, profile: String = "wii") -> Array[int]:
	var result: Array[int] = []
	if opening or gates.is_empty():
		for slot: int in initial_slots(profile):
			if not gates.has(slot):
				result.append(slot)
		return result
	for slot: int in range(slot_count(profile)):
		if gates.has(slot):
			continue
		for occupied: Variant in gates:
			if typeof(occupied) == TYPE_INT and is_adjacent(slot, int(occupied), profile):
				result.append(slot)
				break
	return result

static func card_size(profile: String="ds") -> Vector2:
	return Vector2(2.38,2.65)*(DS_CARD_SCALE if profile=="ds" else WII_CARD_SCALE)

static func gate_contact_fraction(from: Vector3, to: Vector3, center: Vector3, magnet_margin: float = 0.0, profile: String="ds") -> float:
	# Rendering, preview, minimap and collision share the same footprint.
	if not from.is_finite() or not to.is_finite() or not center.is_finite():
		return INF
	var low: float = 0.0
	var high: float = 1.0
	var delta: Vector3 = to-from
	var footprint: Vector2=card_size(profile)
	var half := Vector3(footprint.x*0.5,0.07,footprint.y*0.5)
	half.x += clampf(magnet_margin,0.0,0.32)
	half.z += clampf(magnet_margin,0.0,0.32)
	var start: Vector3 = from-center-Vector3(0,0.44,0)
	for axis: int in [0,1,2]:
		if absf(delta[axis]) < 0.000001:
			if absf(start[axis]) > half[axis]:
				return INF
		else:
			var first: float = (-half[axis]-start[axis])/delta[axis]
			var last: float = (half[axis]-start[axis])/delta[axis]
			low = maxf(low,minf(first,last))
			high = minf(high,maxf(first,last))
			if low>high:
				return INF
	return low
