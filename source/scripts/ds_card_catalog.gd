extends RefCounted
## Original DS faces and English MES descriptions. Browsing adds no effects.
## Artwork/message alignment is bounded and retained in source_cards.json;
## native gameplay parameter tables are not interpreted by this catalog.

const MANIFEST_PATH := "res://assets/ds/source_cards.json"
const MAX_TEXTURES := 20
static var _manifest: Dictionary = {}
static var _by_key: Dictionary = {}
static var _textures: Dictionary = {}
static var _recent_paths: Array[String] = []


static func manifest() -> Dictionary:
	return _data().duplicate(true)


static func total(kind: String = "all") -> int:
	return cards(kind).size()


static func cards(kind: String = "all", query: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var search: String = query.strip_edges().to_lower()
	for entry: Variant in _data().get("cards", []):
		if not entry is Dictionary:
			continue
		var entry_kind: String = str(entry.get("kind", ""))
		if kind == "other" and entry_kind in ["gate", "ability"]:
			continue
		if kind not in ["all", "other", entry_kind]:
			continue
		if not search.is_empty():
			var haystack: String = "%s %s %s %s %s" % [entry.get("name", ""), entry.get("category", ""), entry.get("aliases", []), entry.get("source_description", ""), entry.get("source_card_id", "")]
			if not haystack.to_lower().contains(search):
				continue
		result.append(entry.duplicate(true))
	return result


static func cards_for_color(color: String, query: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in cards("all", query):
		if str(entry.get("color_type", "")) == color:
			result.append(entry)
	return result


static func metadata(key: String) -> Dictionary:
	_data()
	var entry: Dictionary = _by_key.get(key, {})
	return entry.duplicate(true)


static func texture(key: String) -> Texture2D:
	var entry: Dictionary = metadata(key)
	if not bool(entry.get("available", false)):
		return null
	return _texture(str(entry.get("path", "")))


static func thumbnail(key: String) -> Texture2D:
	# Native DS faces are 96x128; keeping the native texture avoids needless
	# enlargement and preserves pixel art at every zoom level.
	return texture(key)


static func back_texture(key: String = "") -> Texture2D:
	for entry: Variant in _data().get("backs", []):
		if entry is Dictionary and bool(entry.get("available", false)) and (key.is_empty() or str(entry.get("key", "")) == key):
			return _texture(str(entry.get("path", "")))
	return null


static func existing_art_match(existing_key: String) -> Dictionary:
	var entry: Dictionary = _data().get("existing_art_matches", {}).get(existing_key, {})
	return entry.duplicate(true)


static func cached_texture_count() -> int:
	return _textures.size()


static func clear_texture_cache() -> void:
	_textures.clear()
	_recent_paths.clear()


static func _data() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary and int(parsed.get("schema", 0)) == 1:
			_manifest = parsed
			for entry: Variant in _manifest.get("cards", []):
				if entry is Dictionary:
					_by_key[str(entry.get("key", ""))] = entry
	return _manifest


static func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _textures.has(path):
		_touch(path)
		return _textures[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	if not resource is Texture2D:
		return null
	while _recent_paths.size() >= MAX_TEXTURES:
		_textures.erase(_recent_paths.pop_front())
	_textures[path] = resource
	_recent_paths.append(path)
	return resource as Texture2D


static func _touch(path: String) -> void:
	_recent_paths.erase(path)
	_recent_paths.append(path)
