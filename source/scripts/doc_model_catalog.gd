extends RefCounted
## Donor forms remain separate from Battle Brawlers DS resources and palettes.

const PATH: String = "res://assets/doc/models/model_manifest.json"
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
			for category: String in ["species", "support"]:
				for entry: Dictionary in _manifest.get(category, []):
					_by_name[_identity(str(entry.name))] = entry
					_by_name[_identity(str(entry.key))] = entry
	return _manifest


static func get_entry(species_name: String) -> Dictionary:
	manifest()
	return (_by_name.get(_identity(species_name), {}) as Dictionary).duplicate(true)


static func resolve(species_name: String, form: String, attribute: String) -> Dictionary:
	var entry: Dictionary = get_entry(species_name)
	var definition: Dictionary = (entry.get("forms", {}).get(form, {}) as Dictionary).duplicate(true)
	if definition.is_empty():
		return {}
	definition["species"] = str(entry.name)
	definition["species_key"] = str(entry.key)
	definition["actual_form"] = form
	definition["requested_form"] = form
	definition["requested_attribute"] = attribute
	definition["texture_attribute"] = str(definition.get("native_attribute", ""))
	definition["exact_attribute"] = definition.texture_attribute.to_lower() == attribute.to_lower()
	return definition


static func _identity(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")
