extends SceneTree
## Environment swaps preserve the match scene and field layout.

const Arena = preload("res://scripts/arena.gd")
const Catalog = preload("res://scripts/arena_catalog.gd")
const BoardLayout = preload("res://scripts/board_layout.gd")
const SourceArena = preload("res://scripts/source_arena.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _environment_count(arena: Node3D) -> int:
	var count: int = 0
	for child: Node in arena.get_children():
		if child.has_meta("theme_id") and child.name == "EnvironmentDecor":
			count += 1
	return count

func _gradient_mesh_count(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var arrays: Array = node.mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() > 0:
			count = 1
	for child: Node in node.get_children():
		count += _gradient_mesh_count(child)
	return count

func _catalog_checks() -> void:
	_check(Catalog.ENTRIES.size() == 13, "Three prototype arenas, the source board, eight DS fields and SFM field are available")
	var seen: Dictionary = {}
	for entry: Dictionary in Catalog.ENTRIES:
		seen[entry["id"]] = true
		_check(Catalog.normalize_id(entry["id"]) == entry["id"] and not entry["title"].is_empty() and not entry["description"].is_empty(), "Every arena has a valid id and readable descriptor")
		var palette: Dictionary = entry["palette"]
		for key: String in ["background", "ambient", "key", "fill", "warm", "cold", "floor", "base", "edge", "grid", "slot", "stone", "crystal"]:
			_check(palette.get(key) is Color, "Palette %s supplies Color %s" % [entry["id"], key])
	_check(seen.size() == 13 and seen.has("stadium") and seen.has("canyon") and seen.has("glacier") and seen.has("anime_board"), "All arena ids are distinct and preserve the original fields")
	for invalid: Variant in ["", "Canyon", "unknown", " stadium ", 0, 1.0, true, null, {}, []]:
		_check(Catalog.normalize_id(invalid) == "stadium", "Invalid saved arena returns to stadium: %s" % str(invalid))
	var detached: Dictionary = Catalog.get_entry("canyon")
	detached["title"] = "changed"
	detached["palette"]["floor"] = Color.BLACK
	_check(Catalog.get_entry("canyon")["title"] != "changed" and Catalog.get_entry("canyon")["palette"]["floor"] != Color.BLACK, "Arena descriptor and nested palette are isolated copies")
	_check(Catalog.get_entry("unknown")["id"] == "stadium", "Missing arena descriptor safely returns stadium")

func _theme_checks(arena: Node3D) -> void:
	var original_camera: Camera3D = arena.camera
	var camera_transform: Transform3D = original_camera.transform
	var original_world: WorldEnvironment = arena._world
	var lights: Array = [arena._key, arena._fill, arena._warm, arena._cold]
	var layout: Array[Vector3] = Arena.SLOT_POSITIONS.duplicate()
	var gate: Node3D = arena.make_gate(2, 0, "Test")
	var creature: Node3D = arena.make_creature("Gorem", "Subterra")
	creature.position = layout[2] + Vector3(0.0, 0.15, 0.0)
	var ball: Node3D = arena.make_ball("Aquos", 1)
	ball.position = Vector3(-1.0, 0.44, 1.0)
	var pickup: Node3D = arena.make_pickup(Vector3(1.0, 0.44, 0.0))
	var roots: Array[int] = []
	for id: String in ["stadium", "canyon", "glacier", "anime_board", "stadium"]:
		var old_root: Node3D = arena.environment_root
		var old_id: String = arena.theme_id
		arena.set_theme(id)
		roots.append(arena.environment_root.get_instance_id())
		_check(arena.theme_id == id and arena.environment_root.get_meta("theme_id") == id, "Theme %s updates environment identity" % id)
		_check(_environment_count(arena) == 1, "Only one environment root remains after selecting %s" % id)
		if old_id != id:
			_check(not is_instance_valid(old_root), "Previous environment geometry is released immediately")
		_check(arena.camera == original_camera and arena.camera.current and arena.camera.transform == camera_transform, "Theme selection preserves camera and framing")
		_check(arena._world == original_world and [arena._key, arena._fill, arena._warm, arena._cold] == lights, "Theme selection reuses world and lights")
		_check(arena._world.environment.background_color == Catalog.get_entry(id)["palette"]["background"], "Theme selection applies its background palette")
		_check(arena._world.environment.background_mode == (Environment.BG_SKY if id == "anime_board" else Environment.BG_COLOR), "Only the source field enables its panorama")
		_check((arena._world.environment.sky != null) == (id == "anime_board"), "Leaving the source field releases its active sky reference")
		_check(arena.gates[2] == gate and gate.get_parent() == arena and creature.get_parent() == arena and ball.get_parent() == arena and pickup.get_parent() == arena, "Theme selection preserves gates, creatures, balls and pickups")
		_check(creature.position == layout[2] + Vector3(0.0, 0.15, 0.0) and ball.position == Vector3(-1.0, 0.44, 1.0), "Theme selection does not move gameplay objects")
		_check(Arena.SLOT_POSITIONS == layout and layout.size() == BoardLayout.SLOT_COUNT, "All themes preserve the shared sixteen gameplay target positions")
		for slot: int in range(BoardLayout.SLOT_COUNT):
			var marker: MeshInstance3D = arena.environment_root.get_node("FieldSlot%d" % slot)
			_check(marker.position == layout[slot] + Vector3(0.0, 0.015, 0.0) and marker.get_meta("slot") == slot, "Theme %s displays the same field slot %d" % [id, slot])
			_check(marker.mesh.size.x < 2.1 and marker.mesh.size.z < 2.2, "Field slot %d fits inside its grid cell" % slot)
		if id == "canyon" or id == "glacier":
			_check(_gradient_mesh_count(arena.environment_root) >= 8, "Natural arenas use faceted meshes with vertex color gradients")
		if id == "anime_board":
			_source_board_checks(arena)
	_check(roots[0] != roots[1] and roots[1] != roots[2] and roots[2] != roots[3], "Different themes create separate scenery roots")
	var stable_root: Node3D = arena.environment_root
	var stable_children: int = arena.get_child_count()
	var stable_meshes: int = arena._count_meshes(arena.environment_root)
	arena.set_theme("stadium")
	arena.setup()
	_check(arena.environment_root == stable_root and arena.get_child_count() == stable_children and arena._count_meshes(arena.environment_root) == stable_meshes, "Repeating setup and the active theme creates no duplicate scenery")
	var material_count: int = arena._materials.size()
	for cycle: int in range(4):
		for id: String in ["canyon", "glacier", "anime_board", "stadium"]:
			arena.set_theme(id)
	_check(arena._materials.size() == material_count and _environment_count(arena) == 1 and arena.get_child_count() == stable_children, "Repeated theme changes keep material cache and root count bounded")
	arena.set_theme("glacier")
	arena.set_theme("not-an-arena")
	_check(arena.theme_id == "stadium", "Invalid requested theme returns to stadium")
	arena.remove_gate(2)
	creature.queue_free()
	ball.queue_free()
	pickup.queue_free()

func _source_mesh_points(node: Node) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		var bounds: AABB = instance.mesh.get_aabb()
		for corner: int in range(8):
			points.append(instance.global_transform * bounds.get_endpoint(corner))
		var arrays: Array = instance.mesh.surface_get_arrays(0)
		_check(arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() > 0, "Source board GLB retains its UV coordinates")
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		_check(material != null and material.albedo_texture != null and material.uv1_scale == SourceArena.UV_SCALE, "Source board uses native art and the recorded material UV scale")
		_check(material.albedo_color == SourceArena.SOURCE_TINT, "Source board keeps the Workshop tint")
	for child: Node in node.get_children():
		points.append_array(_source_mesh_points(child))
	return points

func _source_board_checks(arena: Node3D) -> void:
	_check(arena.environment_root.get_meta("source_available", false), "Source arena loads its imported board")
	var board: Node3D = arena.environment_root.get_node_or_null("SourceBoard") as Node3D
	_check(board != null and board.get_meta("source_origin", "") == "source_table_board", "The imported table board is identified accurately")
	if board == null:
		return
	var points: Array[Vector3] = _source_mesh_points(board)
	_check(not points.is_empty(), "Source board contains visible geometry")
	if points.is_empty():
		return
	var minimum: Vector3 = points[0]
	var maximum: Vector3 = points[0]
	for point: Vector3 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	_check((maximum - minimum).is_equal_approx(SourceArena.DIMENSIONS), "Imported floor dimensions match the shared field adaptation")
	_check(absf(maximum.y) < 0.0001 and minimum.y < -0.24, "Source board top stays on the gameplay plane without another floor")
	_check(minimum.x <= -5.58 and maximum.x >= 5.58 and minimum.z <= -5.28 and maximum.z >= 5.28, "Source floor supports the entire rolling bounds plus ball radius")
	for slot: int in range(BoardLayout.SLOT_COUNT):
		_check(not arena.environment_root.get_node("FieldSlot%d" % slot).visible, "Source field artwork remains unobscured at slot %d" % slot)
	var metadata: Dictionary = SourceArena.manifest()
	_check(metadata.get("workshop_id", "") == "3412700725" and metadata.get("board", {}).get("source_uv_preserved", false), "Source manifest records provenance and UV preservation")
	_check((arena._world.environment.sky.sky_material as PanoramaSkyMaterial).panorama != null, "Source sky loads its original panorama texture")

func _highlight_checks(arena: Node3D) -> void:
	arena.highlight_target(4)
	var original: Node3D = arena.target_highlight
	_check(original.get_parent() == arena and original.get_meta("slot") == 4 and original.position == Arena.SLOT_POSITIONS[4] + Vector3(0.0, 0.145, 0.0), "Aim highlight marks its target above the card surface")
	arena.set_theme("canyon")
	_check(not is_instance_valid(original) and arena.target_highlight.get_meta("slot") == 4 and arena.target_highlight.get_meta("theme_id") == "canyon", "Changing themes refreshes highlight color and keeps the aimed slot")
	var changed: Node3D = arena.target_highlight
	arena.highlight_target(1)
	_check(not is_instance_valid(changed) and arena.target_highlight.get_meta("slot") == 1, "Changing aim releases the previous highlight")
	arena.highlight_target(BoardLayout.SLOT_COUNT)
	_check(arena.target_highlight == null, "Off-field target clears the highlight")
	arena.highlight_legal_slots(BoardLayout.INITIAL_SLOTS)
	_check(arena.legal_highlights.get_meta("slots") == BoardLayout.INITIAL_SLOTS and arena._count_meshes(arena.legal_highlights) == 16, "Opening placement highlights the four central card footprints")
	var original_legal: Node3D = arena.legal_highlights
	arena.set_theme("glacier")
	_check(not is_instance_valid(original_legal) and arena.legal_highlights.get_meta("slots") == BoardLayout.INITIAL_SLOTS and arena.legal_highlights.get_meta("theme_id") == "glacier", "Placement highlights retain their legal slots when the theme changes")
	arena.highlight_target(0)
	arena.clear_highlights()
	arena.clear_highlights()
	_check(arena.target_highlight == null and arena.legal_highlights == null, "Highlight cleanup is idempotent")

func _card_labels(node: Node) -> Array[String]:
	var labels: Array[String] = []
	if node is Label3D:
		labels.append(node.text)
	for child: Node in node.get_children():
		labels.append_array(_card_labels(child))
	return labels

func _gate_visibility_checks(arena: Node3D) -> void:
	arena.set_reduced_motion(true)
	var secret: String = "Ability Block"
	var hidden: Node3D = arena.make_gate(5, 1, secret, false, "copper")
	var hidden_labels: Array[String] = _card_labels(hidden)
	_check(not hidden_labels.has(secret.to_upper()) and hidden_labels.has("КАРТА ЗАКРЫТА") and hidden_labels.has("GATE  06"), "A facedown card hides its identity and its color label")
	_check(hidden.position == BoardLayout.POSITIONS[5] and hidden.get_node("CardArtwork").scale == Vector3(0.82, 1.0, 0.82), "Card artwork fits its field cell without shrinking the root animation")
	var shown: Node3D = arena.make_gate(5, 1, secret, true, "copper")
	var shown_labels: Array[String] = _card_labels(shown)
	_check(shown_labels.has(secret.to_upper()) and shown_labels.has("COPPER  06") and not shown_labels.has("КАРТА ЗАКРЫТА"), "Revealing a gate shows its printed name and color")
	_check(shown.get_meta("revealed") == true and shown.scale == Vector3.ONE, "Revealed gate metadata and reduced-motion pose match its visible state")
	arena.remove_gate(5)
	arena.set_reduced_motion(false)

func _motion_checks(arena: Node3D) -> void:
	arena.set_reduced_motion(false)
	var animated_gate: Node3D = arena.make_gate(0, 0, "Motion")
	var animated_creature: Node3D = arena.make_creature("Griffon", "Ventus")
	var animated_pickup: Node3D = arena.make_pickup(Vector3.ZERO)
	_check(animated_gate.scale.x < 1.0 and animated_creature.scale.x < 0.25 and arena._visual_states.size() > 0, "Normal motion creates gate, creature and pickup visual tracks")
	arena.landing_flash(Vector3.ZERO, Color.ORANGE)
	arena.set_reduced_motion(true)
	_check(animated_gate.scale == Vector3.ONE and animated_creature.scale == Vector3.ONE and arena._visual_states.is_empty(), "Reduced motion stops existing visual tracks and opens models immediately")
	var crystal: Node3D = animated_pickup.get_node("Crystal")
	_check(crystal.rotation.y == 0.0 and crystal.scale == Vector3.ONE, "Reduced motion stops an existing pickup spin and pulse")
	var static_gate: Node3D = arena.make_gate(1, 0, "Static")
	var static_creature: Node3D = arena.make_creature("Leonidas", "Pyrus")
	var static_pickup: Node3D = arena.make_pickup(Vector3.ZERO)
	_check(static_gate.scale == Vector3.ONE and static_creature.scale == Vector3.ONE and arena._visual_states.is_empty(), "Reduced motion creates new gates and creatures directly in their final pose")
	_check(static_creature.get_meta("actual_form", "") == "toy" and static_creature.get_meta("visual_states", []).is_empty() and static_pickup.get_node("Crystal").scale == Vector3.ONE, "Reduced motion creates the source open form and a static pickup without reveal tracks")
	var before_effects: int = arena.get_child_count()
	arena.capture_effect(Vector3.ZERO, Color.ORANGE)
	arena.landing_flash(Vector3.ZERO, Color.ORANGE)
	_check(arena.get_child_count() == before_effects, "Reduced motion omits capture and landing effects")
	var ball: Node3D = arena.make_ball("Pyrus", 0, "Griffon")
	_check(ball.position == Vector3.ZERO and ball.get_parent() == arena and static_pickup.get_meta("amount") == 20, "Reduced motion preserves ball origins and pickup rewards")
	arena.remove_gate(0)
	arena.remove_gate(1)
	for node: Node3D in [animated_creature, animated_pickup, static_creature, static_pickup, ball]:
		node.queue_free()
	arena.set_reduced_motion(false)
	arena.capture_effect(Vector3(1.0, 0.0, 2.0), Color.CYAN)
	var effect: Node3D = arena.get_node("CaptureEffect")
	_check(effect.position == Vector3(1.0, 0.14, 2.0) and arena._count_meshes(effect) == 3, "Capture effect supplies three pulses at the captured gate")
	await create_timer(1.05).timeout
	_check(not is_instance_valid(effect), "Capture pulses release their effect root after completion")
	var flashes: int = 0
	for child: Node in arena.get_children():
		if child is Node3D and child.name.begins_with("@Node3D"):
			flashes += 1
	_check(flashes == 0, "Stopping a landing animation does not leave its effect root alive")

func _modeled_creature_checks(arena: Node3D) -> void:
	arena.set_reduced_motion(false)
	var creature: Node3D = arena.make_creature("Dragonoid", "Aquos")
	_check(creature.get_parent() == arena and creature.get_meta("model_origin", "") == "source_import" and creature.get_meta("actual_form", "") == "toy", "Dragonoid API instantiates its source toy GLB in the arena")
	_check(creature.get_meta("species") == "Dragonoid" and creature.get_meta("attribute") == "Aquos" and creature.get_meta("mesh_count") == arena._count_meshes(creature), "Imported creature retains species, attribute and accurate mesh metadata")
	_check(creature.scale.x < 0.25 and arena._visual_states.size() > 0, "Imported Dragonoid registers its reveal animation")
	arena.set_reduced_motion(true)
	_check(creature.scale == Vector3.ONE and arena._visual_states.is_empty(), "Reduced motion immediately finishes an imported creature reveal")
	_check(creature.get_meta("visual_states", []).is_empty() or not (creature.get_meta("visual_states", [])[0]["tween"] as Tween).is_running(), "Reduced motion stops the imported reveal tween")
	_check(creature.get_meta("exact_attribute", false) and creature.get_meta("texture_attribute", "") == "Aquos" and not str(creature.get_meta("texture_path", "")).is_empty(), "Imported Dragonoid selects its original Aquos texture")
	var static_creature: Node3D = arena.make_creature("Dragonoid", "Pyrus")
	_check(static_creature.scale == Vector3.ONE and arena._visual_states.is_empty(), "A new imported creature honors reduced motion from creation")
	var ball: Node3D = arena.make_ball("Ventus", 1, "Dragonoid")
	_check(ball.get_parent() == arena and ball.position == Vector3.ZERO and ball.get_meta("model_origin", "") == "source_import" and ball.get_meta("actual_form", "") == "ball" and ball.get_meta("owner") == 1, "Dragonoid throws use its source closed ball at the gameplay origin")
	_check(ball.get_meta("attribute") == "Ventus" and ball.get_meta("mesh_count") == arena._count_meshes(ball), "Imported ball preserves selected attribute and mesh metadata")
	var legacy_ball: Node3D = arena.make_ball("Aquos", 1)
	var griffon_ball: Node3D = arena.make_ball("Ventus", 0, "Griffon")
	_check(legacy_ball.name.begins_with("MechanicalSphere") and not legacy_ball.has_meta("model_origin"), "Legacy calls without a species keep their generic ball fallback")
	_check(griffon_ball.get_meta("model_origin", "") == "source_import" and griffon_ball.get_meta("species", "") == "Griffon" and griffon_ball.get_meta("actual_form", "") == "ball", "Griffon throws select their own closed source form")
	_check(griffon_ball.get_meta("asset_path", "") != ball.get_meta("asset_path", ""), "Distinct species use their own closed geometry")
	for node: Node3D in [creature, static_creature, ball, legacy_ball, griffon_ball]:
		node.queue_free()
	arena.set_reduced_motion(false)

func _run() -> void:
	_catalog_checks()
	var arena: Node3D = Arena.new()
	root.add_child(arena)
	arena.setup()
	_check(arena.theme_id == "stadium" and _environment_count(arena) == 1, "Fresh arena defaults to the neon stadium")
	_theme_checks(arena)
	_highlight_checks(arena)
	_gate_visibility_checks(arena)
	await _motion_checks(arena)
	_modeled_creature_checks(arena)
	var direct: Node3D = Arena.new()
	root.add_child(direct)
	direct.set_theme("glacier")
	_check(direct.theme_id == "glacier" and direct.camera != null and _environment_count(direct) == 1, "Selecting a theme before setup safely initializes the arena once")
	direct.queue_free()
	arena.queue_free()
	await process_frame
	print("ARENAS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
