extends SceneTree
## Collection source switching must never leave a face from another catalog.

const Browser = preload("res://scripts/source_card_browser.gd")
const DSCards = preload("res://scripts/ds_card_catalog.gd")
const Workshop = preload("res://scripts/source_card_library.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var browser := Browser.new()
	root.add_child(browser)
	await process_frame
	browser.show_browser()
	await process_frame
	_check(browser._source == "ds" and browser._matches.size() == 212, "Collection initially displays original DS cards")
	browser._set_kind("gate")
	_check(browser._matches.size() == 103, "DS gate filter includes gold, silver and copper cards")
	browser._set_kind("ability")
	_check(browser._matches.size() == 97, "DS ability filter includes all three original colors")
	browser._set_query("Dragonoid gets +200")
	_check(browser._matches.size() == 1, "Original effect text can find the native Boosted Dragon")
	var key: String = str(browser._matches[0].key)
	browser._open_zoom(key)
	await process_frame
	_check(browser._zoom_overlay.visible and browser._zoom_image.texture.get_size() == Vector2(96, 128), "Zoom shows the original DS face")
	_check(browser._zoom_title.text == "Boosted Dragon" and browser._zoom_description.text.begins_with("Dragonoid gets +200 G-Power."), "Zoom retains the matching original name and effect alongside gameplay information")
	_check(browser._zoom_type.text.contains("Доступна в колоде DS"), "Collection identifies the implemented DS ability")
	browser._set_source("workshop")
	await process_frame
	_check(not browser._zoom_overlay.visible and browser._zoom_image.texture == null, "Changing source clears an opened native face")
	_check(browser._matches.size() == 392 and browser._query.is_empty(), "Changing source retains the kind filter and resets the search")
	_check(DSCards.cached_texture_count() == 0, "Changing source releases the previous native texture cache")
	browser._set_kind("gate")
	key = str(browser._matches[0].key)
	browser._open_zoom(key)
	await process_frame
	var native_dimensions: Array = Workshop.metadata(key).get("dimensions", [])
	_check(native_dimensions.size() == 2 and browser._zoom_image.texture.get_size() == Vector2(native_dimensions[0], native_dimensions[1]), "Workshop source still uses its full original face")
	browser._set_source("ds")
	await process_frame
	_check(Workshop.cached_texture_count() == 0 and browser._matches.size() == 103, "Returning to DS clears the Workshop cache and restores the correct cards")
	browser._set_kind("other")
	_check(browser._matches.size() == 12, "DS battlefield cards occupy a separate source category")
	browser._set_query("absent original card 993211")
	_check(browser._grid.get_child_count() == 0 and browser._next.disabled and browser._previous.disabled, "Unmatched searches clear stale pages and navigation")
	browser.close_browser()
	_check(not browser.visible and DSCards.cached_texture_count() == 0, "Closing releases all native collection textures")
	browser.queue_free()
	await process_frame
	print("DS CARD BROWSER: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
