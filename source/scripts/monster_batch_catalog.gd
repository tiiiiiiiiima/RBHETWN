extends RefCounted
## Explicit original TTS states; no fabricated rig or attribute recolouring.

const PATH: String = "res://assets/monster_batch/model_manifest.json"
const ATTRIBUTES: Array[String] = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
static var _manifest: Dictionary = {}
static var _by_name: Dictionary = {}


static func reload() -> void:
	_manifest.clear()
	_by_name.clear()


static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_manifest = parsed
			for entry: Dictionary in _manifest.get("species", []):
				_by_name[_identity(str(entry.name))] = entry
				_by_name[_identity(str(entry.key))] = entry
			_by_name["cancer"] = _by_name.get("terrorclaw", {})
			_by_name["battleaxevladitor"] = _by_name.get("battleaxvladitor", {})
	return _manifest


static func get_entry(species_name: String) -> Dictionary:
	manifest()
	return (_by_name.get(_identity(species_name), {}) as Dictionary).duplicate(true)


static func available_attributes(species_name: String, form: String) -> Array[String]:
	var variants: Dictionary = get_entry(species_name).get("forms", {}).get(form, {}).get("variants", {})
	var result: Array[String] = []
	for attribute: String in ATTRIBUTES:
		if variants.has(attribute):
			result.append(attribute)
	return result


static func resolve(species_name: String, form: String, attribute: String) -> Dictionary:
	var entry: Dictionary = get_entry(species_name)
	var definition: Dictionary = (entry.get("forms", {}).get(form, {}) as Dictionary).duplicate(true)
	if definition.is_empty():
		return {}
	var variants: Dictionary = definition.get("variants", {})
	var exact: bool = variants.has(attribute)
	var texture_attribute: String = attribute if exact else str(definition.get("native_attribute", ""))
	var variant: Dictionary = variants.get(texture_attribute, {})
	if variant.is_empty():
		return {}
	for key: String in ["path", "texture", "source"]:
		definition[key] = variant[key]
	if variant.has("texture_animation"):
		definition["texture_animation"] = variant.texture_animation
	definition["species"] = str(entry.name)
	definition["species_key"] = str(entry.key)
	definition["actual_form"] = form
	definition["requested_form"] = form
	definition["requested_attribute"] = attribute
	definition["texture_attribute"] = texture_attribute
	definition["exact_attribute"] = exact
	return definition


static func _identity(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")
