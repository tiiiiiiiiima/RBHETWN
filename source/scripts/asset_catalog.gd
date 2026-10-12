extends RefCounted
## Source-imported forms and original texture variants. The manifest contains
## provenance and actual availability; missing forms are never claimed as imports.

const MANIFEST_PATH: String = "res://assets/imported/catalog.json"
const DSModels = preload("res://scripts/ds_model_catalog.gd")
const DocModels = preload("res://scripts/doc_model_catalog.gd")
const MonsterModels = preload("res://scripts/monster_batch_catalog.gd")
const FORMS: Array[String] = ["ball", "toy", "battle"]
static var _loaded: bool = false
static var _manifest: Dictionary = {}
static var _entries: Array[Dictionary] = []
static var _support: Array[Dictionary] = []
static var _by_identity: Dictionary = {}


static func reload() -> void:
	DSModels.reload()
	DocModels.reload()
	MonsterModels.reload()
	_loaded = false
	_manifest.clear()
	_entries.clear()
	_support.clear()
	_by_identity.clear()
	_load_manifest()


static func manifest() -> Dictionary:
	_load_manifest()
	return _manifest.duplicate(true)


static func species() -> Array[Dictionary]:
	_load_manifest()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		result.append(entry.duplicate(true))
	return result


static func support() -> Array[Dictionary]:
	_load_manifest()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _support:
		result.append(entry.duplicate(true))
	return result


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = species()
	result.append_array(support())
	return result


static func get_entry(species_name: String) -> Dictionary:
	_load_manifest()
	var identity: String = _identity(species_name)
	if not _by_identity.has(identity):
		return {}
	var entry: Dictionary = (_by_identity[identity] as Dictionary).duplicate(true)
	var donor: Dictionary = DocModels.get_entry(species_name)
	for form: String in donor.get("forms", {}):
		if form == "battle" or not entry.forms.has(form):
			entry.forms[form] = donor.forms[form].duplicate(true)
	var ds: Dictionary = DSModels.get_entry(species_name) if str(donor.get("classification", "")) != "trap" else {}
	if not ds.is_empty():
		var native_attribute: String = str(ds.get("native_attribute", ""))
		entry.forms["battle"] = DSModels.resolve(species_name, native_attribute)
	for form: String in MonsterModels.get_entry(species_name).get("forms", {}):
		entry.forms[form] = MonsterModels.get_entry(species_name).forms[form].duplicate(true)
	var animated: Dictionary = _animated_battle(species_name, "")
	if not animated.is_empty():
		entry.forms["battle"] = animated
	return entry


static func available_forms(species_name: String) -> Array[String]:
	var entry: Dictionary = get_entry(species_name)
	var result: Array[String] = []
	var forms: Dictionary = entry.get("forms", {})
	for form: String in FORMS:
		if forms.get(form) is Dictionary and _has_geometry(forms[form]):
			result.append(form)
	return result


static func available_attributes(species_name: String, form: String = "toy") -> Array[String]:
	if form == "battle":
		var animated: Dictionary = _animated_battle(species_name, "")
		if not animated.is_empty():
			if str(animated.get("source", {}).get("origin", "")) == "user_ds_nitrofs":
				return DSModels.available_attributes(species_name)
			return [str(animated.get("native_attribute", animated.get("texture_attribute", "")))]
	var improved: Array[String] = MonsterModels.available_attributes(species_name, form)
	var donor_entry: Dictionary = DocModels.get_entry(species_name)
	if form == "battle" and str(donor_entry.get("classification", "")) != "trap" and not DSModels.get_entry(species_name).is_empty():
		var native: Array[String] = DSModels.available_attributes(species_name)
		if native.is_empty():
			var attribute: String = str(DSModels.get_entry(species_name).get("native_attribute", ""))
			if not attribute.is_empty():
				native.append(attribute)
		for attribute: String in improved:
			if not native.has(attribute):
				native.append(attribute)
		return native
	var entry: Dictionary = get_entry(species_name)
	var forms: Dictionary = entry.get("forms", {})
	if not forms.get(form) is Dictionary:
		return []
	var definition: Dictionary = forms[form]
	var result: Array[String] = []
	result.append_array(improved)
	var donor: Dictionary = DocModels.resolve(species_name, form, "")
	var donor_attribute: String = str(donor.get("native_attribute", ""))
	var variants: Dictionary = definition.get("variants", {})
	var legacy_variants: Dictionary = (_by_identity.get(_identity(species_name), {}) as Dictionary).get("forms", {}).get(form, {}).get("variants", {})
	for attribute: String in ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]:
		if result.has(attribute):
			continue
		if variants.get(attribute) is Dictionary or legacy_variants.get(attribute) is Dictionary:
			result.append(attribute)
		elif donor_attribute == attribute:
			result.append(attribute)
	if result.is_empty():
		var native_attribute: String = str(definition.get("native_attribute", ""))
		if not native_attribute.is_empty():
			result.append(native_attribute)
	return result


static func resolve(species_name: String, requested_form: String, attribute: String) -> Dictionary:
	if not FORMS.has(requested_form):
		return {}
	if requested_form == "battle":
		var animated: Dictionary = _animated_battle(species_name, attribute)
		if not animated.is_empty():
			return animated
	var improved: Dictionary = MonsterModels.resolve(species_name, requested_form, attribute)
	if not improved.is_empty():
		if bool(improved.exact_attribute):
			return improved
		_load_manifest()
		var legacy: Dictionary = _by_identity.get(_identity(species_name), {})
		var legacy_exact: bool = legacy.get("forms", {}).get(requested_form, {}).get("variants", {}).has(attribute)
		var ds_exact: bool = requested_form == "battle" and bool(DSModels.resolve(species_name, attribute).get("exact_attribute", false))
		if not legacy_exact and not ds_exact:
			return improved
	if requested_form == "battle":
		var support: Dictionary = DocModels.get_entry(species_name)
		if str(support.get("classification", "")) == "trap":
			return DocModels.resolve(species_name, requested_form, attribute)
		var ds: Dictionary = DSModels.resolve(species_name, attribute)
		if not ds.is_empty() and _valid_resource_path(str(ds.get("path", ""))):
			return ds
	var donor: Dictionary = DocModels.resolve(species_name, requested_form, attribute)
	if not donor.is_empty() and (bool(donor.get("exact_attribute", false)) or requested_form == "battle"):
		return donor
	var entry: Dictionary = get_entry(species_name)
	if not improved.is_empty():
		entry = (_by_identity.get(_identity(species_name), {}) as Dictionary).duplicate(true)
	if entry.is_empty():
		return {}
	var forms: Dictionary = entry.get("forms", {})
	var actual_form: String = requested_form
	if not forms.get(actual_form) is Dictionary or not _has_geometry(forms[actual_form]):
		# A toy is a useful explicit battle fallback; a ball is not an open form.
		if requested_form != "battle" or not forms.get("toy") is Dictionary or not _has_geometry(forms["toy"]):
			return {}
		actual_form = "toy"
	var definition: Dictionary = (forms[actual_form] as Dictionary).duplicate(true)
	var variants: Dictionary = definition.get("variants", {})
	var texture_attribute: String = attribute
	var exact_attribute: bool = variants.get(attribute) is Dictionary
	var native_attribute: String = str(definition.get("native_attribute", ""))
	if not exact_attribute:
		texture_attribute = native_attribute
		if not variants.get(texture_attribute) is Dictionary and not variants.is_empty():
			texture_attribute = str(variants.keys()[0])
		if variants.is_empty():
			exact_attribute = native_attribute.is_empty() or native_attribute == attribute
	var variant: Dictionary = variants.get(texture_attribute, {})
	for field: String in ["path", "texture", "texture_materials", "source"]:
		if variant.has(field):
			definition[field] = variant[field]
	if not _valid_resource_path(str(definition.get("path", ""))):
		return {}
	definition["species"] = str(entry.get("name", species_name))
	definition["species_key"] = str(entry.get("key", _identity(species_name)))
	definition["source"] = definition.get("source", entry.get("source", {}))
	definition["requested_form"] = requested_form
	definition["actual_form"] = actual_form
	definition["requested_attribute"] = attribute
	definition["texture_attribute"] = texture_attribute
	definition["exact_attribute"] = exact_attribute
	return definition


static func _animated_battle(species_name: String, attribute: String) -> Dictionary:
	# Native joint animation takes precedence over static geometry and skins.
	# A trap identity must never alias a similarly named DS creature.
	var donor: Dictionary = DocModels.get_entry(species_name)
	var candidates: Array[Dictionary] = []
	if str(donor.get("classification", "")) != "trap":
		candidates.append(DSModels.resolve(species_name, attribute))
	candidates.append(DocModels.resolve(species_name, "battle", attribute))
	for candidate: Dictionary in candidates:
		if not candidate.is_empty() and not candidate.get("animations", []).is_empty() and not candidate.get("animation_roles", {}).is_empty() and _valid_resource_path(str(candidate.get("path", ""))) and ResourceLoader.exists(str(candidate.path)):
			candidate["selection_policy"] = "animated_native_before_static"
			return candidate
	return {}


static func _load_manifest() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_warning("Imported asset manifest is not a dictionary: " + MANIFEST_PATH)
		return
	_manifest = parsed
	_register_entries(_manifest.get("species", []), false)
	_register_entries(_manifest.get("support", []), true)
	# New donor identities append without renumbering old roster/save indices.
	for category: String in ["species", "support"]:
		for entry: Dictionary in DocModels.manifest().get(category, []):
			if not _by_identity.has(_identity(str(entry.name))):
				_register_entries([entry], category == "support")


static func _register_entries(candidates: Variant, is_support: bool) -> void:
	if not candidates is Array:
		return
	for candidate: Variant in candidates:
		if not candidate is Dictionary or not candidate.get("forms") is Dictionary:
			continue
		var entry: Dictionary = candidate.duplicate(true)
		var name: String = str(entry.get("name", ""))
		if name.is_empty():
			continue
		if is_support:
			_support.append(entry)
		else:
			_entries.append(entry)
		_by_identity[_identity(name)] = entry
		_by_identity[_identity(str(entry.get("key", name)))] = entry
		var aliases: Variant = entry.get("aliases", [])
		if aliases is Array:
			for alias: Variant in aliases:
				_by_identity[_identity(str(alias))] = entry


static func _has_geometry(definition: Dictionary) -> bool:
	if _valid_resource_path(str(definition.get("path", ""))):
		return true
	var variants: Dictionary = definition.get("variants", {})
	for variant: Variant in variants.values():
		if variant is Dictionary and _valid_resource_path(str(variant.get("path", ""))):
			return true
	return false


static func _valid_resource_path(path: String) -> bool:
	return path.begins_with("res://assets/") and not path.contains("..") and not path.ends_with("/")


static func _identity(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")
