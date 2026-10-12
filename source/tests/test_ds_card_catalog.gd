extends SceneTree
## Native resource availability, distinct same-name cards, safe metadata and
## bounded texture residency for the DS collection. No gameplay effects inferred.

const Library = preload("res://scripts/ds_card_catalog.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Dictionary = Library.manifest()
	_check(str(manifest.get("provenance", {}).get("rom_game_code", "")) == "B6RE", "Supplied DS archive provenance is retained")
	_check(Library.total() == 212, "All native DS faces are available, excluding dummy card zero")
	_check(Library.total("gate") == 103 and Library.total("ability") == 97 and Library.total("other") == 12, "Original seven groups retain gate/ability/field distinctions")
	var names: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ds/messages.json"))
	var name_records: Array = names["tables"]["mes_CardName.mes"]["records"]
	var text_records: Array = names["tables"]["mes_CardText.mes"]["records"]
	var marker_count: int = 0
	for entry: Dictionary in Library.cards():
		var key: String = str(entry["key"])
		var index: int = int(entry["message_index"])
		_check(str(entry["name"]) == str(name_records[index]["text"]), "%s preserves the native MES name" % key)
		_check(str(entry["source_effect_text"]) == str(text_records[index]["text"]), "%s preserves the native MES description" % key)
		_check(not bool(entry["playable"]) and not entry.has("effect") and not entry.has("boosts"), "%s cannot silently add an inferred gameplay effect" % key)
		var native: Texture2D = Library.texture(key)
		_check(native != null and native.get_size() == Vector2(96, 128), "%s has its native packaged 96x128 face" % key)
		if native != null:
			var pixels: Image = native.get_image()
			_check(pixels != null and not pixels.is_empty(), "%s includes real image pixels" % key)
		if str(entry["description_status"]) == "control_marker_only":
			marker_count += 1
			_check(str(entry["source_description"]).is_empty() and str(entry["source_effect_text"]) == "<0xff85>", "No text is fabricated for a native marker-only description")
	_check(marker_count == 32, "All 32 silver gate marker-only descriptions remain explicit")
	_check(Library.cached_texture_count() == Library.MAX_TEXTURES, "Browsing every native face keeps only a bounded texture cache")
	var duplicate_names: Array[Dictionary] = []
	for entry: Dictionary in Library.cards("all", "mega impact"):
		if str(entry["name"]) == "Mega Impact":
			duplicate_names.append(entry)
	_check(duplicate_names.size() == 2, "The two original Mega Impact cards remain distinct")
	if duplicate_names.size() == 2:
		_check(duplicate_names[0]["key"] != duplicate_names[1]["key"] and duplicate_names[0]["source_description"] != duplicate_names[1]["source_description"], "Green species bonus and blue attribute bonus retain their own identities")
	_check(Library.existing_art_match("ability_mega_impact").get("key", "") == "ds_card_516", "Playable Gorem art maps to the green native card, avoiding the same-name blue card")
	_check(Library.cards_for_color("gold").size() == 39 and Library.cards_for_color("blue").size() == 33, "Color selection uses the original categories")
	_check(Library.cards("all", "definitely absent native card 987321").is_empty(), "Unmatched search cannot show an unrelated face")
	_check(Library.metadata("unknown").is_empty() and Library.texture("unknown") == null, "Unknown keys are safely rejected")
	var copy: Dictionary = Library.metadata("ds_card_101")
	copy["name"] = "Changed by caller"
	copy["sources"][0]["sha256"] = "changed"
	_check(str(Library.metadata("ds_card_101")["name"]) == "Dragonoid" and str(Library.metadata("ds_card_101")["sources"][0]["sha256"]).length() == 64, "Callers cannot mutate cached nested provenance")
	_check(Library.texture("ds_card_101") != null and Library.back_texture() != null, "Cache eviction permits reloading and the original back remains available")
	Library.clear_texture_cache()
	_check(Library.cached_texture_count() == 0, "Closing the collection releases cached native image references")
	print("DS card catalog: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
