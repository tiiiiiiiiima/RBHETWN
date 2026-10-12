extends SceneTree
const Catalog = preload("res://scripts/monster_batch_catalog.gd")
const Assets = preload("res://scripts/asset_catalog.gd")
const Models = preload("res://scripts/model_library.gd")
const Library = preload("res://scripts/monster_batch_card_library.gd")
const Browser = preload("res://scripts/source_card_browser.gd")
const Roster = preload("res://scripts/roster.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	_check(Catalog.manifest().species.size() == 45 and int(Catalog.manifest().new_skeleton_animations) == 0, "All verified donor identities are registered without invented animations")
	_check(Roster.CREATURES.size() == 99, "Visual replacements do not renumber playable or saved teams")
	for entry: Dictionary in Catalog.manifest().species:
		for form: String in entry.forms:
			var definition: Dictionary = entry.forms[form]
			for attribute: String in definition.variants:
				var resolved: Dictionary = Catalog.resolve(str(entry.name), form, attribute)
				_check(str(resolved.path).begins_with("res://assets/monster_batch/") and resolved.exact_attribute, "Donor is preferred for its real attribute: %s/%s/%s" % [entry.name, form, attribute])
				_check(int(resolved.source.source_state) == {"ball":1,"toy":2,"battle":3}[form], "Toy and monster states are not confused")
				_check(FileAccess.file_exists(str(resolved.texture)), "Declared native skin ships: " + str(resolved.texture))
			var attribute: String = str(definition.native_attribute)
			var model: Node3D = Models.make_ball(host, attribute, 0, true, str(entry.name)) if form == "ball" else Models.make_creature(host, str(entry.name), attribute, true, form)
			_check(model != null, "The preferred form instantiates: " + str(entry.name) + "/" + form)
			if model == null:
				continue
			var animated: bool = not model.find_children("*","AnimationPlayer",true,false).is_empty() and form=="battle"
			_check((animated or str(model.get_meta("asset_path", "")).begins_with("res://assets/monster_batch/")) and model.get_meta("actual_form", "") == form, "Gameplay uses native animation or the actual static replacement")
			var bounds: AABB = Models.visual_bounds(model)
			_check(bounds.size.is_finite() and bounds.get_volume() > 0.00001, "Replacement has finite visual geometry")
			if form == "ball":
				_check(bounds.get_center().length() < 0.01 and absf(maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) - 0.88) < 0.01, "New sphere matches the shared physics diameter and origin")
			elif not animated:
				_check(absf(bounds.position.y) < 0.01, "Standing form rests on the card floor")
			var textured: bool = false
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				_check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] != null, "Original model UVs are retained")
				var material: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
				textured = textured or (material != null and material.albedo_texture != null and material.albedo_color == Color.WHITE)
			_check(textured, "High resolution donor skin is actually on the model")
			_check(animated or model.find_children("*", "Skeleton3D", true, false).is_empty(), "Static meshes do not advertise an original rig")
			model.free()
	_check(Assets.resolve("Fortress", "battle", "Darkus").path.begins_with("res://assets/doc/"), "DoC trap Fortress is not replaced by Fourtress")
	_check(Assets.resolve("Neo Dragonoid", "battle", "Pyrus").path.begins_with("res://assets/doc/"), "New donor does not replace absent DoC identities")
	_check(Catalog.resolve("Preyas II Angelo", "battle", "Haos").path != Catalog.resolve("Preyas II Diablo", "battle", "Pyrus").path, "The two Preyas II monster forms stay distinct")
	_check(Assets.resolve("Dragonoid", "toy", "Aquos").exact_attribute and Assets.resolve("Dragonoid", "toy", "Aquos").path.begins_with("res://assets/imported/"), "An absent donor colour keeps the actual old Aquos model")
	_check(Assets.available_attributes("Dragonoid", "toy").has("Aquos"), "Other authentic toy attribute palettes remain available")
	_check(Assets.resolve("Dragonoid", "battle", "Aquos").path.begins_with("res://assets/ds/"), "Animated DS remains preferred when selecting another requested attribute")
	if not OS.get_cmdline_user_args().has("--models-only"):
		await _cards()
	host.queue_free()
	await process_frame
	Models.clear_caches()
	print("MONSTER BATCH 0.17.2: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _cards() -> void:
	_check(Library.total() == 725, "All 725 unique card faces are available")
	_check(Library.total("gate") > 0 and Library.total("ability") > 0 and Library.total("other") > 0, "Gate, ability and characteristic images are distinguished")
	for entry: Dictionary in Library.cards():
		_check(not bool(entry.playable) and not bool(entry.rules_verified) and FileAccess.file_exists(str(entry.path)), "Art does not silently add a fan effect to playable rules")
	var browser: Control = Browser.new()
	root.add_child(browser)
	browser.show_browser("gate", "monster_batch")
	await process_frame
	_check(browser._source_selector.selected == 2 and browser._matches.size() == Library.total("gate"), "The third source displays its actual gate set")
	_check(browser._grid.get_child_count() == Browser.PAGE_SIZE, "Only a bounded card page is loaded")
	var key: String = str(browser._matches[0].key)
	browser._open_zoom(key)
	_check(browser._zoom_image.texture != null and browser._zoom_image.texture.get_width() > 224, "Zoom decodes the detailed card from packed bytes")
	browser._set_source("ds")
	_check(Library.cached_texture_count() == 0 and browser._source == "ds", "Changing source releases the high resolution images")
	browser._set_source("monster_batch")
	browser._set_kind("ability")
	browser._change_page(1)
	_check(browser._page == 1 and Library.cached_texture_count() <= Library.MAX_TEXTURES, "Paging keeps the image cache bounded")
	browser._set_query("no such MB card 786413")
	_check(browser._grid.get_child_count() == 0, "Search clears stale faces")
	browser.close_browser()
	_check(Library.cached_texture_count() == 0, "Closing releases the image cache")
	browser.queue_free()
	await process_frame
