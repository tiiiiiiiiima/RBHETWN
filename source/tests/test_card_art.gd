extends SceneTree

const Art = preload("res://scripts/card_art.gd")
const Gates = preload("res://scripts/gate_catalog.gd")
const Abilities = preload("res://scripts/ability_catalog.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	_test_manifest()
	_test_catalog(false)
	_test_catalog(true)
	_test_safe_display()
	if failures == 0:
		print("PASS: %d imported card art checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d imported card art checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_manifest() -> void:
	var data: Dictionary = Art.manifest()
	_check(int(data.get("schema", 0)) == 1, "Source manifest has the supported schema")
	_check(str(data.get("source", {}).get("workshop_id", "")) == "2480698294", "Source workshop is preserved")
	_check(data.get("gates", []).size() == Gates.CARDS.size(), "Every gate has a visual provenance entry")
	_check(data.get("abilities", []).size() == Abilities.CARDS.size(), "Every ability has a visual provenance entry")
	var back: Texture2D = Art.back_texture()
	_check(back != null and back.get_size() == Vector2(762, 1024), "Common source back loads offline at original dimensions")
	var original: Dictionary = data.get("back", {})
	_check(str(original.get("sha256", "")) == str(original.get("source_sha256", "different")), "Common source back is byte-for-byte preserved")
	data["gates"][0]["name"] = "Changed"
	_check(str(Art.gate_metadata(0).get("name", "")) == "Leonidas", "Callers cannot mutate cached source metadata")


func _test_catalog(is_ability: bool) -> void:
	var cards: Array = Abilities.CARDS if is_ability else Gates.CARDS
	for index in range(cards.size()):
		var metadata: Dictionary = Art.ability_metadata(index) if is_ability else Art.gate_metadata(index)
		var texture: Texture2D = Art.ability_texture(index) if is_ability else Art.gate_texture(index)
		var illustration: Texture2D = Art.ability_texture(index, true) if is_ability else Art.gate_texture(index, true)
		var key: String = str(cards[index]["key"])
		_check(str(metadata.get("key", "")) == key and str(metadata.get("name", "")) == str(cards[index]["title"]), "Visual mapping retains card identity for %s" % key)
		_check(texture != null and illustration != null, "Source texture and illustration load offline for %s" % key)
		var mapped_index: int = Art.index_for_ability_key(key) if is_ability else Art.index_for_gate_key(key)
		_check(mapped_index == index, "Stable gameplay key resolves to correct image for %s" % key)
		if str(metadata.get("source_origin", "")) == "user_ds_nitrofs":
			_check(str(metadata.get("source_url", "")) == "user_supplied_nds:B6RE", "Native DS art retains its user source identity")
			_check(texture.get_size() == Vector2(96, 128), "Native DS faces keep their original decoded dimensions")
			_check(str(metadata.get("source_sha256", "")).length() == 64 and str(metadata.get("sha256", "")).length() == 64, "Native DS source and image hashes are retained")
			_check(bool(metadata.get("art_only", false)) and not bool(metadata.get("native_boost_table_verified", true)), "Native artwork does not claim source numeric gate tables")
			_check(illustration is AtlasTexture and illustration.get_size() == texture.get_size(), "Native art illustration retains the actual source crop")
			_check(str(metadata.get("source_card_name", "")) == str(cards[index]["title"]), "Native art matches the selected gameplay card name")
			continue
		_check(str(metadata.get("source_url", "")).begins_with("https://steamusercontent-a.akamaihd.net/"), "Source URL is retained for %s" % key)
		_check(str(metadata.get("source_sha256", "")).length() == 64 and str(metadata.get("sha256", "")).length() == 64, "Source and shipped file hashes are retained for %s" % key)
		if not bool(metadata.get("original_card_found", false)):
			_check(str(metadata.get("display_mode", "")) == "source_back_fallback" and not str(metadata.get("fallback_reason", "")).is_empty(), "Absent face is explicitly marked as a source-back fallback for %s" % key)
			continue
		_check(bool(metadata.get("printed_face_visually_checked", false)), "Actual printed source face was visually checked for %s" % key)
		var dimensions: Array = metadata.get("dimensions", [])
		_check(dimensions.size() == 2 and int(dimensions[0]) == 842 and int(dimensions[1]) == 1122, "Source cell dimensions remain unchanged for %s" % key)
		_check(illustration is AtlasTexture, "Illustration uses an exact atlas rectangle for %s" % key)
		if illustration is AtlasTexture:
			var atlas: AtlasTexture = illustration
			_check(atlas.atlas.get_size() == Vector2(842, 1122), "Imported face keeps the full source resolution for %s" % key)
			_check(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), "Illustration crop remains inside the source face for %s" % key)
			var image: Image = atlas.atlas.get_image()
			image.convert(Image.FORMAT_RGBA8)
			var region_image: Image = image.get_region(Rect2i(atlas.region))
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(region_image.get_data())
			_check(hash.finish().hex_encode() == str(metadata.get("illustration_pixel_sha256", "")), "Runtime illustration contains the exact extracted pixels for %s" % key)


func _test_safe_display() -> void:
	for index in [3, 5, 6]:
		var metadata: Dictionary = Art.gate_metadata(index)
		var texture: Texture2D = Art.gate_texture(index)
		if str(metadata.get("source_origin", "")) == "user_ds_nitrofs":
			_check(texture.get_size() == Vector2(96, 128) and bool(metadata.get("art_only", false)), "Native DS gate face presents only the original artwork and title")
			continue
		_check(texture is AtlasTexture and str(metadata["display_mode"]) == "source_illustration", "Mismatched printed gate never exposes source rules by default")
		if texture is AtlasTexture:
			var region: Rect2 = texture.region
			_check(region.position.x >= 184 and region.end.x <= 681 and region.end.y <= 900, "Gate illustration excludes source bonus column and rules")
	_check(Art.ability_texture(0) is AtlasTexture and not bool(Art.ability_metadata(0)["full_face_matches_console_rules"]), "Battle Gate uses illustration instead of incorrect TTS effect")
	_check(Art.gate_texture(2) == Art.back_texture() and Art.ability_texture(3) == Art.back_texture(), "Missing source cards display the actual common back")
	_check(Art.gate_texture(-1) == null and Art.gate_texture(99) == null and Art.ability_texture(99) == null, "Invalid indices do not silently show a different card")
	_check(Art.index_for_gate_key("missing") == -1 and Art.index_for_ability_key("missing") == -1, "Unknown identities do not resolve to an unrelated source card")
