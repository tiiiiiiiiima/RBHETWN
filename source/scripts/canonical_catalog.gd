extends RefCounted
## Anime identities and source-recorded starting powers, separate from physical
## toy colours and the older Wii prototype's balance values. Unknown powers stay
## playable with a clearly identified conditional value.

const MANIFEST_PATH: String = "res://assets/imported/canonical_profiles.json"
const ATTRIBUTES: Array[String] = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
static var _loaded: bool = false
static var _manifest: Dictionary = {}
static var _profiles: Dictionary = {}
static var _issues: Array[String] = []


static func reload() -> void:
	_loaded = false
	_manifest.clear()
	_profiles.clear()
	_issues.clear()
	_load_manifest()


static func manifest() -> Dictionary:
	_load_manifest()
	return _manifest.duplicate(true)


static func profile(species_id: String) -> Dictionary:
	_load_manifest()
	var value: Variant = _profiles.get(_identity(species_id), {})
	return value.duplicate(true) if value is Dictionary else {}


static func profiles() -> Array[Dictionary]:
	_load_manifest()
	var result: Array[Dictionary] = []
	for value: Dictionary in _profiles.values():
		result.append(value.duplicate(true))
	return result


static func allowed_attributes(species_id: String) -> Array[String]:
	return _allowed_attributes(profile(species_id))


static func attribute_locked(species_id: String) -> bool:
	return _profile_locked(profile(species_id))


static func resolve(species_id: String, requested_attribute: String, fallback_g: int) -> Dictionary:
	return describe_profile(profile(species_id), requested_attribute, fallback_g)


static func describe_profile(native_profile: Dictionary, requested_attribute: String, fallback_g: int) -> Dictionary:
	# Public pure resolver also permits support categories to use their separate
	# source profiles without introducing them into the three-Bakugan roster.
	var allowed: Array[String] = _allowed_attributes(native_profile)
	var primary: String = _primary_attribute(native_profile)
	var locked: bool = _profile_locked(native_profile)
	var attribute: String = requested_attribute if allowed.has(requested_attribute) else allowed[0]
	if locked:
		attribute = primary
	var selected_power: Dictionary = _power_for_attribute(native_profile, attribute)
	var canon_g: Variant = selected_power.get("initial_g", null)
	var verified: bool = canon_g != null
	var resolved_g: int = int(canon_g) if verified else maxi(0, fallback_g)
	var source_url: String = _text(selected_power.get("g_source_url", selected_power.get("source_url", native_profile.get("source_url", ""))))
	var excerpt: String = _text(selected_power.get("g_excerpt", selected_power.get("excerpt", native_profile.get("excerpt", ""))))
	var source_confidence: String = _text(selected_power.get("g_confidence", selected_power.get("confidence", "unknown"))) if verified else "unknown"
	var native_attribute: String = _text(native_profile.get("primary_attribute", native_profile.get("native_attribute", "")))
	var unsupported_native: bool = bool(native_profile.get("unsupported_native", false)) or (bool(native_profile.get("character_bound", false)) and not native_attribute.is_empty() and not ATTRIBUTES.has(native_attribute))
	var g_note: String = "Исходная G по источнику: %d" % resolved_g if verified else "G условная: %d; исходная G не подтверждена" % resolved_g
	if verified and source_confidence == "indexed":
		g_note += " (по опубликованной выдержке)"
	if not _text(selected_power.get("variant_label", "")).is_empty():
		g_note += " · " + _text(selected_power.variant_label)
	return {
		"attribute": attribute,
		"g": resolved_g,
		"canon_g": canon_g,
		"canonical_g": canon_g,
		"g_verified": verified,
		"g_note": g_note,
		"g_source_confidence": source_confidence,
		"attribute_locked": locked,
		"attribute_verified": _attribute_is_recorded(native_profile, attribute),
		"allowed_attributes": allowed,
		"native_attribute": native_attribute,
		"unsupported_native_attribute": unsupported_native,
		"source_url": source_url,
		"excerpt": excerpt,
		"variant_label": _text(selected_power.get("variant_label", "")),
		"display_identity": _text(native_profile.get("display_identity", native_profile.get("name", ""))),
		"brawler": _text(selected_power.get("brawler", native_profile.get("brawler", ""))),
		"profile": native_profile.duplicate(true),
	}


static func issues() -> Array[String]:
	_load_manifest()
	return _issues.duplicate()


static func coverage() -> Dictionary:
	_load_manifest()
	var result: Dictionary = {"profiles": _profiles.size(), "bound": 0, "unknown_power": 0, "unsupported_native": 0, "issues": issues()}
	for native_profile: Dictionary in _profiles.values():
		var description: Dictionary = describe_profile(native_profile, _primary_attribute(native_profile), 0)
		if description.attribute_locked:
			result.bound += 1
		if not description.g_verified:
			result.unknown_power += 1
		if description.unsupported_native_attribute:
			result.unsupported_native += 1
	return result


static func _allowed_attributes(native_profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var primary: String = _primary_attribute(native_profile)
	if _profile_locked(native_profile):
		result.append(primary)
		return result
	# Generic species remain selectable in their actual imported physical colours.
	# Observed anime attributes still drive provenance, not this cosmetic choice.
	var recorded: Variant = native_profile.get("attributes", [])
	if not bool(native_profile.get("character_bound", false)) or bool(native_profile.get("attribute_changer", false)):
		var physical: Variant = native_profile.get("selectable_attributes", native_profile.get("physical_attributes", []))
		if physical is Array and not physical.is_empty():
			recorded = physical
	if recorded is Array:
		for attribute: Variant in recorded:
			if attribute is String and ATTRIBUTES.has(attribute) and not result.has(attribute):
				result.append(attribute)
	if result.is_empty():
		result.assign(ATTRIBUTES)
	return result


static func _profile_locked(native_profile: Dictionary) -> bool:
	if not bool(native_profile.get("character_bound", false)) or bool(native_profile.get("attribute_changer", false)) or _primary_attribute(native_profile).is_empty():
		return false
	if bool(native_profile.get("single_element", false)):
		return true
	var attributes: Variant = native_profile.get("attributes", [])
	var known: Array[String] = []
	if attributes is Array:
		for attribute: Variant in attributes:
			if attribute is String and ATTRIBUTES.has(attribute) and not known.has(attribute):
				known.append(attribute)
	return known.size() == 1


static func _primary_attribute(native_profile: Dictionary) -> String:
	var primary: String = _text(native_profile.get("primary_attribute", native_profile.get("native_attribute", "")))
	if ATTRIBUTES.has(primary):
		return primary
	var attributes: Variant = native_profile.get("attributes", [])
	if attributes is Array and attributes.size() == 1 and attributes[0] is String and ATTRIBUTES.has(attributes[0]):
		return str(attributes[0])
	return ""


static func _power_for_attribute(native_profile: Dictionary, attribute: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var baseline: Array[Dictionary] = []
	var variants: Variant = native_profile.get("per_attribute_variants", [])
	if variants is Array:
		for variant: Variant in variants:
			if not variant is Dictionary or str(variant.get("attribute", "")) != attribute or not _has_recorded_power(variant):
				continue
			candidates.append(variant)
			if bool(variant.get("is_baseline", false)):
				baseline.append(variant)
	if not baseline.is_empty():
		candidates = baseline
	if not candidates.is_empty():
		var first_power: int = int(candidates[0].initial_g)
		for candidate: Dictionary in candidates:
			if int(candidate.initial_g) != first_power:
				# Several anime individuals of the same attribute can have different
				# powers. Never silently treat a random individual as the species.
				return {}
		return candidates[0].duplicate(true)
	var primary: String = _primary_attribute(native_profile)
	if primary == attribute and _has_recorded_power(native_profile):
		return native_profile.duplicate(true)
	return {}


static func _has_recorded_power(value: Dictionary) -> bool:
	var power: Variant = value.get("initial_g", null)
	var is_integer: bool = typeof(power) == TYPE_INT or (typeof(power) == TYPE_FLOAT and is_finite(power) and power == floor(power))
	var source_url: String = _text(value.get("g_source_url", value.get("source_url", "")))
	if not is_integer or power < 0 or not (source_url.begins_with("https://") or source_url.begins_with("http://")):
		return false
	if value.has("g_verified") and not bool(value.g_verified):
		return false
	return _text(value.get("g_confidence", value.get("confidence", "unknown"))) in ["verified", "indexed"]


static func _attribute_is_recorded(native_profile: Dictionary, attribute: String) -> bool:
	var native_source: String = _text(native_profile.get("attribute_source_url", native_profile.get("source_url", "")))
	if _valid_source(native_source) and _text(native_profile.get("attribute_confidence", native_profile.get("confidence", "unknown"))) in ["verified", "indexed"]:
		var recorded: Variant = native_profile.get("attributes", [])
		if recorded is Array and recorded.has(attribute):
			return true
	var variants: Variant = native_profile.get("per_attribute_variants", [])
	if variants is Array:
		for variant: Variant in variants:
			if variant is Dictionary and str(variant.get("attribute", "")) == attribute and _text(variant.get("attribute_confidence", variant.get("confidence", "unknown"))) in ["verified", "indexed"] and _valid_source(_text(variant.get("source_url", ""))):
				return true
	return false


static func _load_manifest() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		_issues.append("Canonical profile manifest is missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_issues.append("Canonical profile manifest is not a dictionary")
		return
	_manifest = parsed
	var candidates: Variant = _manifest.get("profiles", [])
	if not candidates is Array:
		_issues.append("Canonical profiles are not an array")
		return
	for candidate: Variant in candidates:
		if not candidate is Dictionary or _text(candidate.get("id", "")).is_empty():
			_issues.append("Canonical profile has no identity")
			continue
		var identity: String = _identity(str(candidate.id))
		if _profiles.has(identity):
			_issues.append("Duplicate canonical identity: " + str(candidate.id))
			continue
		_profiles[identity] = candidate.duplicate(true)


static func _identity(value: String) -> String:
	if value.begins_with("p0_") or value.begins_with("p1_"):
		value = value.substr(3)
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")


static func _text(value: Variant) -> String:
	return value if value is String else ""


static func _valid_source(value: String) -> bool:
	return value.begins_with("https://") or value.begins_with("http://")
