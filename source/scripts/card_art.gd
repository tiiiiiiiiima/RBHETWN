extends RefCounted
## Steam Workshop 2480698294 card art, with source provenance in cards.json.
## Art does not change GateCatalog or AbilityCatalog rules. A mismatched source
## face is always cropped to its illustration, including the default API call.
## Missing faces use the actual common card back and are identified in metadata.

const DSCards = preload("res://scripts/ds_card_catalog.gd")
const MANIFEST_PATH := "res://assets/imported/cards.json"
static var _manifest_cache: Dictionary = {}
static var _textures: Dictionary = {}


static func manifest() -> Dictionary:
	return _data().duplicate(true)


static func gate_metadata(index: int) -> Dictionary:
	return _metadata("gates", index)


static func ability_metadata(index: int) -> Dictionary:
	return _metadata("abilities", index)


static func index_for_gate_key(key: String) -> int:
	return _index_for_key("gates", key)


static func index_for_ability_key(key: String) -> int:
	return _index_for_key("abilities", key)


static func gate_texture(index: int, illustration_only: bool = false) -> Texture2D:
	return _card_texture("gates", index, illustration_only)


static func ability_texture(index: int, illustration_only: bool = false) -> Texture2D:
	return _card_texture("abilities", index, illustration_only)


static func back_texture() -> Texture2D:
	var back: Dictionary = _data().get("back", {})
	return _texture(str(back.get("path", "")))


static func _data() -> Dictionary:
	if _manifest_cache.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary and int(parsed.get("schema", 0)) == 1:
			_manifest_cache = parsed
			_apply_ds_art()
	return _manifest_cache


static func _apply_ds_art() -> void:
	# Native DS faces contain the illustration, border and card name, without
	# the console bonus table. Gameplay continues to use the verified catalogs.
	for kind: String in ["gates", "abilities"]:
		var entries: Array = _manifest_cache.get(kind, [])
		for index: int in range(entries.size()):
			if not entries[index] is Dictionary:
				continue
			var original: Dictionary = entries[index]
			var match: Dictionary = DSCards.existing_art_match(str(original.get("key", "")))
			var native: Dictionary = DSCards.metadata(str(match.get("key", "")))
			if native.is_empty() or not bool(native.get("available", false)):
				continue
			var entry: Dictionary = original.duplicate(true)
			entry["legacy_art"] = original.duplicate(true)
			entry["path"] = native["path"]
			entry["dimensions"] = native["size"]
			entry["source_origin"] = "user_ds_nitrofs"
			entry["source_card_id"] = native["source_card_id"]
			entry["source_message_index"] = native["message_index"]
			entry["source_card_name"] = native["name"]
			entry["source_description"] = native["source_description"]
			entry["source_url"] = "user_supplied_nds:B6RE"
			entry["source_sha256"] = native["sources"][0]["sha256"]
			entry["sha256"] = native["image_sha256"]
			entry.erase("pixel_sha256")
			entry.erase("illustration_pixel_sha256")
			entry["display_mode"] = "source_face"
			entry["original_card_found"] = true
			entry["printed_face_visually_checked"] = true
			entry["art_only"] = true
			entry["native_boost_table_verified"] = false
			entry["full_face_matches_console_rules"] = false
			entry["illustration_rect"] = [0, 0, native["size"][0], native["size"][1]]
			entry["transformation"] = "native_ds_decoded_face"
			entries[index] = entry
	_manifest_cache["ds_art_source"] = "res://assets/ds/source_cards.json"


static func _metadata(kind: String, index: int) -> Dictionary:
	var cards: Array = _data().get(kind, [])
	if index < 0 or index >= cards.size() or not cards[index] is Dictionary:
		return {}
	return cards[index].duplicate(true)


static func _index_for_key(kind: String, key: String) -> int:
	var cards: Array = _data().get(kind, [])
	for index in range(cards.size()):
		if cards[index] is Dictionary and str(cards[index].get("key", "")) == key:
			return index
	return -1


static func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _textures.has(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			_textures[path] = loaded
	return _textures.get(path) as Texture2D


static func _card_texture(kind: String, index: int, illustration_only: bool) -> Texture2D:
	var metadata: Dictionary = _metadata(kind, index)
	if metadata.is_empty():
		return null
	var mode: String = str(metadata.get("display_mode", ""))
	if mode == "source_back_fallback":
		return back_texture()
	var texture: Texture2D = _texture(str(metadata.get("path", "")))
	if texture == null:
		return null
	if not illustration_only and mode == "source_face":
		return texture
	var rectangle: Array = metadata.get("illustration_rect", [])
	if rectangle.size() != 4:
		return null
	var region := Rect2(float(rectangle[0]), float(rectangle[1]), float(rectangle[2]), float(rectangle[3]))
	if region.size.x <= 0.0 or region.size.y <= 0.0 or not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
		return null
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = region
	cropped.filter_clip = true
	return cropped
