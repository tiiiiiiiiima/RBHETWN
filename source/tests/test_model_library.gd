extends SceneTree
## Imported geometry/UVs, exact source skins, form selection and instance safety.

const ModelLibrary = preload("res://scripts/model_library.gd")
const AssetCatalog = preload("res://scripts/asset_catalog.gd")
const Roster = preload("res://scripts/roster.gd")
const ATTRIBUTES: Array[String] = ["Pyrus", "Aquos", "Subterra", "Haos", "Darkus", "Ventus"]
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null:
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(_meshes(child))
	return result


func _materials(meshes: Array[MeshInstance3D]) -> Array[StandardMaterial3D]:
	var result: Array[StandardMaterial3D] = []
	for instance: MeshInstance3D in meshes:
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: Material = instance.get_active_material(surface)
			if material is StandardMaterial3D and not result.has(material):
				result.append(material)
	return result


func _world_bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var result: AABB = AABB()
	var initialized: bool = false
	for instance: MeshInstance3D in meshes:
		for corner: int in range(8):
			var point: Vector3 = instance.global_transform * instance.mesh.get_aabb().get_endpoint(corner)
			if not initialized:
				result = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				result = result.expand(point)
	return result


func _has_uv_geometry(meshes: Array[MeshInstance3D]) -> bool:
	for instance: MeshInstance3D in meshes:
		if not instance.mesh is ArrayMesh:
			continue
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			if vertices.size() >= 3 and uv is PackedVector2Array and uv.size() == vertices.size():
				return true
	return false


func _run() -> void:
	AssetCatalog.reload()
	var entries: Array[Dictionary] = AssetCatalog.entries()
	_check(not entries.is_empty(), "The shipped source-import manifest contains actual species")
	if entries.is_empty():
		_finish()
		return
	var host: Node3D = Node3D.new()
	root.add_child(host)
	_test_collection_boundary()
	var identities: Dictionary = {}
	for entry: Dictionary in entries:
		var species_name: String = str(entry["name"])
		_check(not identities.has(species_name), "Catalog identity is unique: " + species_name)
		identities[species_name] = true
		_check(AssetCatalog.get_entry(species_name.to_lower()).get("key") == entry.get("key"), "Case-insensitive lookup resolves " + species_name)
		_check(AssetCatalog.available_forms(species_name).has("ball") and AssetCatalog.available_forms(species_name).has("toy"), species_name + " has both source toy forms")
		for form: String in AssetCatalog.available_forms(species_name):
			var declaration: Dictionary = entry["forms"][form]
			var native_attribute: String = str(declaration.get("native_attribute", "Pyrus"))
			var source_attributes: Array = declaration.get("variants", {}).keys()
			_check(not source_attributes.is_empty() and source_attributes.has(native_attribute), "%s %s identifies an available native source skin" % [species_name, form])
			for attribute: String in ATTRIBUTES:
				var resolved: Dictionary = AssetCatalog.resolve(species_name, form, attribute)
				var has_exact: bool = source_attributes.has(attribute)
				var actual_attribute: String = attribute if has_exact else native_attribute
				_check(not resolved.is_empty() and bool(resolved.get("exact_attribute", false)) == has_exact and str(resolved.get("texture_attribute", "")) == actual_attribute, "%s %s truthfully resolves requested %s skin" % [species_name, form, attribute])
				_check(str(resolved.get("texture", "")) == str(declaration["variants"][actual_attribute]["texture"]) and ResourceLoader.exists(str(resolved.get("texture", ""))), "%s %s %s resolves an unchanged shipped native texture" % [species_name, form, attribute])
				if not has_exact:
					_check(resolved.get("requested_attribute") == attribute and resolved.get("texture_attribute") != attribute, "%s %s does not advertise its native fallback as an imported recolor" % [species_name, form])
				var expected_path: String = str(declaration["variants"][actual_attribute].get("path", declaration["path"]))
				_check(str(resolved.get("path", "")) == expected_path, "%s %s %s selects its declared attribute geometry" % [species_name, form, attribute])
			var visual: Node3D = ModelLibrary.make_ball(host, native_attribute, 0, true, species_name) if form == "ball" else ModelLibrary.make_creature(host, species_name, native_attribute, true, form)
			_check(visual != null, "%s %s instantiates from its converted source mesh" % [species_name, form])
			if visual == null:
				continue
			_check(visual.get_meta("model_origin", "") == "source_import" and visual.get_meta("actual_form", "") == form and visual.get_meta("requested_form", "") == form, "%s %s reports its actual imported form" % [species_name, form])
			var meshes: Array[MeshInstance3D] = _meshes(visual)
			_check(not meshes.is_empty() and int(visual.get_meta("mesh_count", -1)) == meshes.size(), "%s %s records complete mesh geometry" % [species_name, form])
			_check(_has_uv_geometry(meshes), "%s %s retains source UV coordinates" % [species_name, form])
			var materials: Array[StandardMaterial3D] = _materials(meshes)
			var textured: bool = false
			for material: StandardMaterial3D in materials:
				if material.albedo_texture != null:
					textured = material.albedo_texture.get_width() > 0 and material.albedo_texture.get_height() > 0 and material.albedo_color == Color.WHITE
					_check(material.albedo_texture.resource_path == declaration["variants"][native_attribute]["texture"], "%s %s actually loads its declared native image" % [species_name, form])
			_check(textured, "%s %s uses its native diffuse image without global colour tint" % [species_name, form])
			var bounds: AABB = _world_bounds(meshes)
			_check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.get_volume() > 0.00001, "%s %s has finite three-dimensional geometry" % [species_name, form])
			if form == "ball":
				_check(is_equal_approx(maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)), 0.76) and bounds.get_center().length() < 0.01, species_name + " closed source form fits its normalized extent and origin")
			elif form == "toy":
				_check(absf(bounds.position.y) < 0.01 and bounds.size.y <= 2.01 and bounds.size.x <= 2.71 and bounds.size.z <= 2.71, species_name + " open toy fits the standing scale and floor")
			_check(visual.scale.is_equal_approx(Vector3.ONE) and visual.get_meta("visual_states", []).is_empty(), "%s %s honours reduced motion" % [species_name, form])
			visual.free()
			for attribute: String in source_attributes:
				if attribute == native_attribute:
					continue
				if entry.get("introduced_version", "") != "0.8" and not declaration["variants"][attribute].has("path"):
					continue
				var alternate: Node3D = ModelLibrary.make_ball(host, attribute, 0, true, species_name) if form == "ball" else ModelLibrary.make_creature(host, species_name, attribute, true, form)
				var expected_path: String = str(declaration["variants"][attribute].get("path", declaration["path"]))
				_check(alternate != null and alternate.get_meta("exact_attribute", false) and alternate.get_meta("asset_path", "") == expected_path, "%s %s instantiates its actual %s source variant" % [species_name, form, attribute])
				if alternate != null:
					_check(_has_uv_geometry(_meshes(alternate)), "%s %s %s alternate source geometry retains its UVs" % [species_name, form, attribute])
					var loaded_native: bool = false
					for material: StandardMaterial3D in _materials(_meshes(alternate)):
						if material.albedo_texture != null:
							loaded_native = material.albedo_texture.resource_path == declaration["variants"][attribute]["texture"] and material.albedo_texture.get_width() > 0 and material.albedo_texture.get_height() > 0 and material.albedo_color == Color.WHITE
					_check(loaded_native, "%s %s %s renders its loaded native image without tint" % [species_name, form, attribute])
					alternate.free()
	_check(host.get_child_count() == 0, "Coverage checks leave no render instances alive")
	_test_fallbacks(host, str(entries[0]["name"]))
	_test_isolation(host, str(entries[0]["name"]))
	_test_native_fallbacks(host)
	await _test_reveal(host, str(entries[0]["name"]))
	for entry: Dictionary in entries:
		var species_name: String = str(entry["name"])
		if AssetCatalog.available_forms(species_name).has("battle"):
			var creature: Node3D = ModelLibrary.make_creature(host, species_name, "Pyrus", true, "battle")
			_check(creature != null and creature.get_meta("actual_form", "") == "battle", species_name + " uses its available source battle form")
			if creature != null:
				_check(_has_uv_geometry(_meshes(creature)), species_name + " source battle form retains texture UVs")
				creature.free()
	host.queue_free()
	await process_frame
	ModelLibrary.clear_caches()
	_finish()


func _test_native_fallbacks(host: Node3D) -> void:
	for entry: Dictionary in AssetCatalog.entries():
		var species_name: String = str(entry["name"])
		for form: String in AssetCatalog.available_forms(species_name):
			var declaration: Dictionary = entry["forms"][form]
			var variants: Dictionary = declaration.get("variants", {})
			for attribute: String in ATTRIBUTES:
				if variants.has(attribute):
					continue
				var visual: Node3D = ModelLibrary.make_ball(host, attribute, 0, true, species_name) if form == "ball" else ModelLibrary.make_creature(host, species_name, attribute, true, form)
				_check(visual != null and not visual.get_meta("exact_attribute", true) and visual.get_meta("texture_attribute", "") == declaration["native_attribute"], "%s %s preserves honest native fallback metadata during rendering" % [species_name, form])
				if visual != null:
					for material: StandardMaterial3D in _materials(_meshes(visual)):
						_check(material.albedo_texture != null and material.albedo_color == Color.WHITE, "%s %s native fallback remains untinted" % [species_name, form])
					visual.free()
				break


func _test_collection_boundary() -> void:
	_check(AssetCatalog.species().size() == 99, "Source species collection contains 69 existing and 30 appended playable types")
	_check(AssetCatalog.support().size() == 18 and AssetCatalog.entries().size() == 117, "The gallery exposes 18 support and trap types separately from the team roster")
	var playable_ids: Array[String] = []
	for entry: Dictionary in Roster.CREATURES:
		playable_ids.append(str(entry.id))
	for entry: Dictionary in AssetCatalog.support():
		_check(not playable_ids.has(str(entry.key)) and entry.get("classification") == "trap", "Support remains outside the three-Bakugan team roster: " + str(entry.name))
		_check(AssetCatalog.get_entry(str(entry.key)).get("name") == entry.get("name"), "Support source identity resolves through the shared model library: " + str(entry.name))
	var copy: Array[Dictionary] = AssetCatalog.support()
	copy[0]["name"] = "Changed local copy"
	_check(AssetCatalog.support()[0]["name"] != "Changed local copy", "Reading gallery support entries cannot mutate the shared import catalog")


func _test_fallbacks(host: Node3D, known_species: String) -> void:
	for owner: int in [-1, 2]:
		_check(ModelLibrary.make_ball(host, "Pyrus", owner, true, known_species) == null, "Invalid owner adds no ball")
	_check(ModelLibrary.make_creature(host, "Missing Species", "Pyrus", true) == null and ModelLibrary.make_ball(host, "Pyrus", 0, true, "Missing Species") == null, "Unknown imports create no partial visual wrappers")
	_check(AssetCatalog.resolve(known_species, "invalid form", "Pyrus").is_empty(), "Unknown form cannot masquerade as a real import")
	for entry: Dictionary in AssetCatalog.species():
		var species_name: String = str(entry["name"])
		if not AssetCatalog.available_forms(species_name).has("battle"):
			var creature: Node3D = ModelLibrary.make_creature(host, species_name, "Pyrus", true, "battle")
			_check(creature != null and creature.get_meta("requested_form", "") == "battle" and creature.get_meta("actual_form", "") == "toy", "Unavailable battle form falls back to an explicitly identified toy")
			if creature != null:
				creature.free()
			break
	var unavailable: Dictionary = AssetCatalog.resolve(known_species, "toy", "Unknown Attribute")
	_check(not bool(unavailable.get("exact_attribute", true)) and str(unavailable.get("texture_attribute", "")) != "Unknown Attribute", "Missing skin uses explicit native fallback metadata")


func _test_isolation(host: Node3D, species_name: String) -> void:
	var first: Node3D = ModelLibrary.make_creature(host, species_name, "Pyrus", true)
	var second: Node3D = ModelLibrary.make_creature(host, species_name, "Pyrus", true)
	var third: Node3D = ModelLibrary.make_creature(host, species_name, "Aquos", true)
	_check(first != null and second != null and third != null, "Repeated and different skins can coexist")
	if first == null or second == null or third == null:
		for visual: Node3D in [first, second, third]:
			if visual != null:
				visual.free()
		return
	var first_material: StandardMaterial3D = _materials(_meshes(first))[0]
	var second_material: StandardMaterial3D = _materials(_meshes(second))[0]
	var third_material: StandardMaterial3D = _materials(_meshes(third))[0]
	_check(first_material != second_material and second_material != third_material, "Instances own isolated material overrides")
	_check(first_material.albedo_texture == second_material.albedo_texture and first_material.albedo_texture != third_material.albedo_texture, "Same original skin shares its immutable image; another attribute selects another image")
	first_material.albedo_color = Color(0.2, 0.8, 0.6)
	_check(second_material.albedo_color == Color.WHITE and third_material.albedo_color == Color.WHITE, "Changing an instance leaves other source skins unchanged")
	first.free()
	second.free()
	third.free()


func _test_reveal(host: Node3D, species_name: String) -> void:
	var creature: Node3D = ModelLibrary.make_creature(host, species_name, "Pyrus")
	_check(creature != null and creature.scale.x > 0 and creature.scale.x <= 0.25, "Normal motion starts a visible open-toy reveal")
	if creature == null:
		return
	_check(not creature.get_meta("visual_states", []).is_empty(), "Reveal tracks decorative motion lifecycle")
	var removed: Node3D = ModelLibrary.make_creature(host, species_name, "Pyrus")
	if removed != null:
		removed.queue_free()
	await create_timer(0.7).timeout
	_check(creature.scale.is_equal_approx(Vector3.ONE), "Source toy reaches full scale after reveal")
	_check(removed == null or not is_instance_valid(removed), "A source model can be removed while revealing")
	creature.queue_free()
	await process_frame
	_check(host.get_child_count() == 0, "Lifecycle checks remove all source visual wrappers")


func _finish() -> void:
	print("MODEL LIBRARY: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
