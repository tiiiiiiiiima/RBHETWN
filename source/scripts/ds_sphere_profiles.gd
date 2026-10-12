extends RefCounted
## Observed native level-one variants; unobserved variants remain explicit PC fits.
const PATH := "res://assets/ds/sphere_profiles.json"
const FIELDS: Array[String] = ["speed", "defense", "control", "steering", "magnet"]
static var _manifest: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest

static func resolve(unit: Dictionary) -> Dictionary:
	var species: String = str(unit.get("species_id", unit.get("name", ""))).to_lower().replace(" ", "_")
	if species.begins_with("p0_") or species.begins_with("p1_"):
		species = species.substr(3)
	var result: Dictionary = {"level": 1, "verified": false, "g": int(unit.get("g", 0)), "frame": ""}
	var values: Array = manifest().get("fallback_statistics", [2,2,2,2,1])
	for entry: Dictionary in manifest().get("profiles", []):
		if entry.species == species and entry.attribute == str(unit.get("attribute", "")) and int(entry.level) == int(unit.get("level", 1)):
			values = entry.statistics
			result.verified = true
			result.g = int(entry.g)
			result.frame = str(entry.frame)
			break
	for index: int in FIELDS.size():
		result[FIELDS[index]] = clampi(int(values[index]), 1, 5)
	return result

static func apply_team(team: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in team:
		var unit: Dictionary = candidate.duplicate(true)
		unit["motion_profile"] = resolve(unit)
		if bool(unit.motion_profile.verified):
			unit["g"] = int(unit.motion_profile.g)
			unit["g_verified"] = true
			unit["g_note"] = "Начальные G и характеристики прочитаны в оригинале DS."
		result.append(unit)
	return result

static func describe(profile: Dictionary) -> String:
	return "СК %d · ЗЩ %d · КН %d · ПВ %d · МГ %d" % [profile.speed, profile.defense, profile.control, profile.steering, profile.magnet]

static func starter_indices(catalog: Array) -> Array[int]:
	var result: Array[int] = []
	for species: String in ["serpenoid","falconeer","juggernoid"]:
		for index: int in catalog.size():
			if str(catalog[index].id)==species:
				result.append(index)
				break
	return result
