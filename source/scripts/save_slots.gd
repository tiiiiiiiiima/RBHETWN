extends RefCounted
## Each slot stores one atomic, checksummed match and its progress snapshot.
const Store = preload("res://scripts/match_checkpoint.gd")
const KINDS: Array[String] = ["campaign", "free", "anime"]
const LABELS: Dictionary = {"campaign":"Кампания", "free":"Свободный матч / турнир", "anime":"Аниме-дуэль"}
const COUNT: int = 3
static func ids(kind: String) -> Array[String]:
	var result: Array[String] = []
	if kind in KINDS:
		for index: int in COUNT: result.append("%s_%d" % [kind,index+1])
	return result
static func kind(id: String) -> String:
	for value: String in KINDS:
		if ids(value).has(id): return value
	return ""
static func path(id: String) -> String:
	return "user://slots/%s.bin" % id if not kind(id).is_empty() else ""
static func record(id: String) -> Dictionary:
	if path(id).is_empty(): return {}
	var data: Dictionary = Store.read(path(id),false)
	if data.get("mode","")=="save_slot": return data
	if data.is_empty(): return {}
	return {"schema":1,"mode":"save_slot","slot":id,"saved_at":0,"match":data,"progress":{}}
static func match_data(id: String) -> Dictionary:
	return record(id).get("match",{}).duplicate(true)
static func occupied(id: String) -> bool:
	return not match_data(id).is_empty()
static func write(id: String, data: Dictionary, progress: Dictionary = {}) -> Error:
	if path(id).is_empty(): return ERR_INVALID_PARAMETER
	var expected: String = "anime" if data.get("mode","")=="anime" else "campaign" if data.get("main",{}).get("match_mode","")=="campaign" else "free"
	if not data.is_empty() and expected!=kind(id): return ERR_INVALID_DATA
	return Store.write({"schema":1,"mode":"save_slot","slot":id,"saved_at":int(Time.get_unix_time_from_system()),"match":data,"progress":progress.duplicate(true)},path(id))
static func first_empty(kind_id: String, preferred: String) -> String:
	if ids(kind_id).has(preferred) and not occupied(preferred): return preferred
	for id: String in ids(kind_id):
		if not occupied(id): return id
	return ""
static func migrate_legacy(progress: Dictionary) -> Error:
	var data: Dictionary = Store.read(Store.LEGACY_PATH)
	if data.is_empty(): return OK
	var id: String = "anime_1" if data.get("mode","")=="anime" else "campaign_1" if data.get("main",{}).get("match_mode","")=="campaign" else "free_1"
	# Retain the original file for older releases; a written empty slot is also
	# a completed migration and must never resurrect a settled legacy match.
	if not record(id).is_empty(): return OK
	return write(id,data,progress if id=="campaign_1" else {})
