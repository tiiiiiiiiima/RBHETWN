extends SceneTree
## Source-model arena API and safe reveal/pickup lifecycle checks.

const Arena = preload("res://scripts/arena.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _mesh_count(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _mesh_count(child)
	return count

func _find_mesh(node: Node, type_name: String) -> bool:
	if node is MeshInstance3D and node.mesh.get_class() == type_name:
		return true
	for child: Node in node.get_children():
		if _find_mesh(child, type_name):
			return true
	return false

func _has_textured_uv_mesh(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var material: StandardMaterial3D = node.get_active_material(surface) as StandardMaterial3D
			if uv is PackedVector2Array and not uv.is_empty() and material != null and material.albedo_texture != null and material.albedo_color == Color.WHITE:
				return true
	for child: Node in node.get_children():
		if _has_textured_uv_mesh(child):
			return true
	return false

func _run() -> void:
	var arena: Node3D = Arena.new()
	root.add_child(arena)
	arena.setup()
	var initial_children: int = arena.get_child_count()
	arena.setup()
	_check(arena.get_child_count() == initial_children, "Arena setup is idempotent")
	_check(arena.camera is Camera3D and arena.camera.current, "Setup supplies active camera")
	var names: Array[String] = ["Leonidas", "Dragonoid", "Griffon", "Hydranoid", "Preyas", "Gorem"]
	var creatures: Array[Node3D] = []
	var source_paths: Dictionary = {}
	for i: int in range(names.size()):
		var creature: Node3D = arena.make_creature(names[i], ["Pyrus", "Aquos", "Ventus", "Haos", "Darkus", "Subterra"][i])
		creatures.append(creature)
		_check(creature.get_parent() == arena, "%s belongs to arena" % names[i])
		_check(creature.get_meta("species") == names[i], "%s species metadata" % names[i])
		var count: int = _mesh_count(creature)
		_check(count > 0 and _find_mesh(creature, "ArrayMesh"), "%s contains imported mesh geometry" % names[i])
		_check(creature.get_meta("part_count") == count, "%s accurate part metadata" % names[i])
		_check(creature.scale.x < 0.25, "%s starts folded" % names[i])
		_check(creature.get_meta("model_origin", "") == "source_import" and creature.get_meta("actual_form", "") == "toy", "%s uses its source open toy form" % names[i])
		_check(creature.get_meta("exact_attribute", false) and creature.get_meta("texture_attribute", "") == creature.get_meta("attribute", ""), "%s selects its original attribute skin" % names[i])
		_check(_has_textured_uv_mesh(creature), "%s preserves UVs and uses native texture without global tint" % names[i])
		source_paths[creature.get_meta("asset_path", "")] = true
	_check(source_paths.size() == 6 and not source_paths.has(""), "Original six species resolve distinct source geometries")
	var fallback: Node3D = arena.make_dragon("Pyrus")
	_check(fallback.get_meta("species") == "Dragonoid", "Legacy dragon API remains supported")
	var unknown: Node3D = arena.make_creature("Unknown", "Pyrus")
	_check(unknown.get_meta("species") == "Dragonoid", "Unknown species uses dragon fallback")
	fallback.queue_free()
	unknown.queue_free()
	var pickup: Node3D = arena.make_pickup(Vector3(1.0, 0.0, -1.0))
	_check(pickup.position == Vector3(1.0, 0.0, -1.0), "Pickup has requested field position")
	_check(pickup.get_meta("amount") == 20, "Pickup defaults to 20 G")
	_check(_find_mesh(pickup, "TorusMesh"), "Pickup has glowing halo")
	var custom_pickup: Node3D = arena.make_pickup(Vector3.ZERO, 35)
	var label_found: bool = false
	for child: Node in custom_pickup.get_children():
		if child is Label3D and child.text == "+35 G":
			label_found = true
	_check(label_found, "Pickup label matches reward")
	custom_pickup.queue_free()
	await create_timer(0.8).timeout
	for i: int in range(creatures.size()):
		_check(creatures[i].scale.is_equal_approx(Vector3.ONE), "%s completes reveal" % names[i])
		creatures[i].queue_free()
	pickup.queue_free()
	# Wait beyond reveal and pulse callbacks to catch tweens targeting freed nodes.
	await create_timer(0.7).timeout
	_check(not is_instance_valid(pickup), "Collected pickup is safely removed")
	arena.queue_free()
	await process_frame
	print("MODELS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
