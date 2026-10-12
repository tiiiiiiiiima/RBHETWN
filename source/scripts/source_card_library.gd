extends RefCounted
## Native faces from Workshop 3412700725. This collection does not add effects
## to the playable catalogs. Texture loading is lazy and bounded for browsing.

const MANIFEST_PATH := "res://assets/imported/source_cards.json"
const MAX_TEXTURES := 20
const THUMBNAIL_SIZE := Vector2i(224, 300)
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
		var entry_kind: String = str(entry.get("kind", "unclassified"))
		if kind == "other" and entry_kind in ["gate", "ability"]:
			continue
		if kind not in ["all", "other", entry_kind]:
			continue
		if not search.is_empty():
			var haystack: String = "%s %s %s" % [entry.get("name", ""), entry.get("category", ""), entry.get("aliases", [])]
			if not haystack.to_lower().contains(search):
				continue
		result.append(entry.duplicate(true))
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
	var entry: Dictionary = metadata(key)
	if not bool(entry.get("available", false)):
		return null
	var path: String = str(entry.get("path", ""))
	var cache_key: String = path + "#thumbnail"
	if _textures.has(cache_key):
		_touch(cache_key)
		return _textures[cache_key] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	# The native face remains unchanged on disk and in the zoom API. A small
	# display texture keeps twelve large standalone faces from using 500 MB.
	var native: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if native == null:
		return null
	var image: Image = native.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	var factor: float = minf(float(THUMBNAIL_SIZE.x) / image.get_width(), float(THUMBNAIL_SIZE.y) / image.get_height())
	if factor < 1.0:
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	var result := ImageTexture.create_from_image(image)
	_cache(cache_key, result)
	return result


static func back_texture(key: String = "") -> Texture2D:
	for entry: Variant in _data().get("backs", []):
		if entry is Dictionary and bool(entry.get("available", false)) and (key.is_empty() or str(entry.get("key", "")) == key):
			return _texture(str(entry.get("path", "")))
	return null


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
	var resource: Resource = load(path)
	if not resource is Texture2D:
		return null
	_cache(path, resource as Texture2D)
	return resource as Texture2D


static func _touch(path: String) -> void:
	_recent_paths.erase(path)
	_recent_paths.append(path)


static func _cache(path: String, resource: Texture2D) -> void:
	while _recent_paths.size() >= MAX_TEXTURES:
		var oldest: String = _recent_paths.pop_front()
		_textures.erase(oldest)
	_textures[path] = resource
	_recent_paths.append(path)
