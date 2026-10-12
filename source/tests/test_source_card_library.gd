extends SceneTree
## Real source-resource availability, safe browsing and bounded memory checks.
## Run after the editor asset import with --headless --script this file.

const Library = preload("res://scripts/source_card_library.gd")
const Browser = preload("res://scripts/source_card_browser.gd")
var checks: int = 0
var failures: int = 0
var closed_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Dictionary = Library.manifest()
	_check(int(manifest.get("schema", 0)) == 1, "Source card manifest is available offline")
	_check(str(manifest.get("source", {}).get("workshop_id", "")) == "3412700725", "Collection retains the requested workshop identity")
	_check(Library.total() == 636, "All distinct referenced source cells are represented")
	_check(Library.total("gate") == 197 and Library.total("ability") == 392 and Library.total("other") == 47, "Gate, ability and special cards retain source classifications")
	var keys: Dictionary = {}
	var animated_count: int = 0
	for entry: Dictionary in Library.cards():
		var key: String = str(entry.get("key", ""))
		_check(not key.is_empty() and not keys.has(key), "Every card has a unique stable image identity")
		keys[key] = true
		_check(bool(entry.get("available", false)) and ResourceLoader.exists(str(entry.get("path", ""))), "Each source face is packaged as a local runtime resource")
		_check(not bool(entry.get("playable", true)) and not bool(entry.get("rules_verified", true)), "Imported art does not silently invent playable effects")
		_check(str(entry.get("source_sha256", "")).length() == 64 and str(entry.get("pixel_sha256", "")).length() == 64, "Every card retains source and extracted-pixel hashes")
		var grid: Array = entry.get("source_atlas_grid", [])
		var rectangle: Array = entry.get("source_cell_rect", [])
		var atlas_size: Array = entry.get("source_atlas_dimensions", [])
		_check(grid.size() == 2 and rectangle.size() == 4 and atlas_size.size() == 2, "Source cells retain auditable grid rectangles")
		if grid.size() == 2 and rectangle.size() == 4 and atlas_size.size() == 2:
			_check(Rect2(Vector2.ZERO, Vector2(atlas_size[0], atlas_size[1])).encloses(Rect2(rectangle[0], rectangle[1], rectangle[2], rectangle[3])), "Extraction remains inside the original source image")
		if bool(entry.get("source_animated", false)):
			animated_count += 1
			_check(str(entry.get("transformation", "")) == "first_video_frame_to_png" and not bool(entry.get("animation_playback", true)), "Animated uploads identify their static first-frame extraction")
	_check(animated_count == 7, "Seven animated source uploads are explicitly recorded")
	var gates: Array[Dictionary] = Library.cards("gate")
	var first_key: String = str(gates[0].get("key", ""))
	var changed: Dictionary = Library.metadata(first_key)
	changed["name"] = "Caller mutation"
	_check(str(Library.metadata(first_key).get("name", "")) != "Caller mutation", "Callers cannot mutate cached source metadata")
	_check(not Library.cards("all", "dragonoid").is_empty(), "Source names and aliases can be searched")
	_check(Library.cards("all", "definitely absent card 987321").is_empty(), "An unmatched search cannot show an unrelated card")
	_check(Library.metadata("missing").is_empty() and Library.texture("missing") == null, "Unknown source keys are safely rejected")
	Library.clear_texture_cache()
	var entries: Array[Dictionary] = Library.cards()
	for index in range(Library.MAX_TEXTURES + 3):
		var texture: Texture2D = Library.thumbnail(str(entries[index].get("key", "")))
		_check(texture != null, "Source thumbnail loads through the lazy collection cache")
		if texture != null:
			_check(texture.get_width() <= Library.THUMBNAIL_SIZE.x and texture.get_height() <= Library.THUMBNAIL_SIZE.y, "Page previews use bounded display textures while retaining native zoom assets")
	_check(Library.cached_texture_count() == Library.MAX_TEXTURES, "Paging cannot grow the texture cache beyond its bound")
	var source_texture: Texture2D = Library.texture(first_key)
	_check(source_texture != null, "A gate can be reloaded after cache eviction")
	if source_texture != null:
		var dimensions: Array = gates[0].get("dimensions", [])
		_check(source_texture.get_size() == Vector2(dimensions[0], dimensions[1]), "Runtime card texture retains the exact source crop dimensions")
	_check(Library.back_texture() != null, "Common card back is available offline")
	Library.clear_texture_cache()
	_check(Library.cached_texture_count() == 0, "Closing the collection can release its cached texture references")
	await _check_browser()
	if failures == 0:
		print("PASS: %d source card library and browser checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d source card checks failed" % [failures, checks])
		quit(1)


func _check_browser() -> void:
	var browser := Browser.new()
	get_root().add_child(browser)
	browser.closed.connect(func(): closed_count += 1)
	await process_frame
	_check(not browser.visible, "Collection does not obscure gameplay until opened")
	browser.show_browser("gate", "workshop")
	await process_frame
	_check(browser.visible and browser._matches.size() == 197, "Gate filter opens the requested source collection")
	_check(browser._grid.get_child_count() == Browser.PAGE_SIZE, "Browsing only displays one bounded page of native card textures")
	browser._change_page(1)
	_check(browser._page == 1 and browser._grid.get_child_count() == Browser.PAGE_SIZE, "Page navigation replaces the grid with the next cards")
	browser._set_query("definitely absent card 987321")
	_check(browser._grid.get_child_count() == 0 and browser._previous.disabled and browser._next.disabled, "An empty result has no stale faces or invalid navigation")
	browser._set_query("")
	var key: String = str(browser._matches[0].get("key", ""))
	browser._open_zoom(key)
	await process_frame
	_check(browser._zoom_overlay.visible and browser._zoom_image.texture != null, "Full-face view opens the actual selected card")
	var dimensions: Array = Library.metadata(key).get("dimensions", [])
	_check(browser._zoom_image.texture.get_size() == Vector2(dimensions[0], dimensions[1]), "Zoom uses the full native face instead of a thumbnail")
	browser.close_browser()
	_check(not browser.visible and not browser._zoom_overlay.visible and browser._grid.get_child_count() == 0, "Closing releases collection panels and visible textures")
	_check(closed_count == 1 and Library.cached_texture_count() == 0, "Close emits once and releases the bounded texture cache")
	browser.close_browser()
	_check(closed_count == 1, "Repeated close cannot emit duplicate gameplay resume signals")
	browser.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
