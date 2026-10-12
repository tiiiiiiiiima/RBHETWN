extends RefCounted
## Original DS battle forms, native materials and named joint clips.
## Missing species and unsupported attribute palettes remain explicit.

const MANIFEST_PATH: String = "res://assets/ds/models/model_manifest.json"
const ATTRIBUTES: Array[String] = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
static var _manifest: Dictionary = {}
static var _identities: Dictionary = {}


static func reload() -> void:
	_manifest.clear()
	_identities.clear()
	manifest()


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_manifest = parsed
				var records: Dictionary = _manifest.get("species", {})
				for key: String in records:
					var entry: Dictionary = records[key]
					_register_identity(key, key)
					_register_identity(str(entry.get("name", key)), key)
					_register_identity(str(entry.get("source_name", "")), key)
				_identities["deltadragonoidii"] = "delta_dragonoid"
				_identities["battleaxevladitor"] = "battle_ax_vladitor"
	return _manifest


static func species() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in manifest().get("species", {}).values():
		result.append(entry.duplicate(true))
	return result


static func get_entry(species_name: String) -> Dictionary:
	manifest()
	var key: String = str(_identities.get(_identity(species_name), ""))
	var entry: Variant = _manifest.get("species", {}).get(key, {})
	return entry.duplicate(true) if entry is Dictionary else {}


static func available_attributes(species_name: String) -> Array[String]:
	var entry: Dictionary = get_entry(species_name)
	var variants: Dictionary = entry.get("variants", {})
	var result: Array[String] = []
	for attribute: String in ATTRIBUTES:
		if variants.has(attribute):
			result.append(attribute)
	return result


static func resolve(species_name: String, requested_attribute: String) -> Dictionary:
	var entry: Dictionary = get_entry(species_name)
	if entry.is_empty():
		return {}
	var variants: Dictionary = entry.get("variants", {})
	var attribute: String = ""
	for candidate: String in ATTRIBUTES:
		if candidate.to_lower() == requested_attribute.to_lower():
			attribute = candidate
			break
	var exact: bool = variants.has(attribute)
	var native_attribute: String = str(entry.get("native_attribute", ""))
	var variant: Dictionary = variants.get(attribute, {}) if exact else {}
	var source: Dictionary = (entry.get("source", {}) as Dictionary).duplicate(true)
	if variant.has("source_palettes"):
		source["attribute_palettes"] = variant["source_palettes"].duplicate(true)
	source["origin"] = "user_ds_nitrofs"
	source["rom_sha256"] = manifest().get("source", {}).get("rom_sha256", "")
	return {
		"path": str(variant.get("path", entry.get("path", ""))),
		"species": str(entry.get("name", species_name)),
		"species_key": str(entry.get("key", "")),
		"actual_form": "battle",
		"requested_form": "battle",
		"requested_attribute": requested_attribute,
		"texture_attribute": attribute if exact else native_attribute,
		"exact_attribute": exact,
		"transform": (entry.get("transform", {}) as Dictionary).duplicate(true),
		"animation_roles": (entry.get("animation_roles", {}) as Dictionary).duplicate(true),
		"animations": (entry.get("animations", []) as Array).duplicate(true),
		"native_geometry": true,
		"native_texture_coordinates": true,
		"source": source,
		"sha256": str(variant.get("sha256", entry.get("sha256", ""))),
	}


static func coverage() -> Dictionary:
	return (manifest().get("coverage", {}) as Dictionary).duplicate(true)


static func _identity(value: String) -> String:
	return value.to_lower().replace("_", "").replace(" ", "").replace("-", "").replace("'", "")


static func _register_identity(alias_name: String, key: String) -> void:
	var identity: String = _identity(alias_name)
	if identity.is_empty():
		return
	if not _identities.has(identity):
		_identities[identity] = key
	elif str(_identities[identity]) != key:
		# Both evolved Preyas forms use the same original MES name. A shared
		# source label cannot silently select one of their distinct geometries.
		_identities[identity] = ""
